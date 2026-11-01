"""Exercise the offline evidence CLI with synthetic records, never physical devices."""

from __future__ import annotations

import json
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path
from typing import Any, cast

import pytest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "device_evidence.py"
COMMIT = "b810cdf371a52e92c3d3a5af2d964a526fcd17f9"
APK = "9c328e13fe960dccad07b7726d49c726c8504fabbc55c57d1e4119bffde2461e"
CHECK_IDS = {
    "first_launch_consent",
    "connection_verification",
    "text_both_directions",
    "text_retry",
    "photo_both_directions",
    "voice_both_directions",
    "permission_recovery",
    "range_loss",
    "background_shutdown",
    "foreground_endurance",
}


def run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )


def template() -> dict[str, Any]:
    result = run_cli("template")
    assert result.returncode == 0, result.stderr
    return cast(dict[str, Any], json.loads(result.stdout))


def complete_record() -> dict[str, Any]:
    report = template()
    report.update(
        source_commit=COMMIT,
        apk_sha256=APK,
        tester="Synthetic fixture, not a device test",
        date=date.today().isoformat(),
        two_distinct_physical_devices=True,
        environment="Synthetic offline LAN fixture",
    )
    for device in report["devices"]:
        device.update(model="Same model", os="Android 15", google_play_services="Fixture version")
    for check in report["checks"]:
        check.update(status="pass", observations="Synthetic assertion only; not physical evidence.")
    return report


def validate_text(tmp_path: Path, raw: str) -> subprocess.CompletedProcess[str]:
    path = tmp_path / "record.json"
    path.write_text(raw, encoding="utf-8")
    return run_cli("validate", str(path), "--expected-commit", COMMIT, "--expected-apk-sha256", APK)


def validate(tmp_path: Path, report: dict[str, Any]) -> subprocess.CompletedProcess[str]:
    return validate_text(tmp_path, json.dumps(report))


def test_template_is_unexecuted_and_cannot_complete_baseline(tmp_path: Path) -> None:
    report = template()
    assert report["schema_version"] == 1
    assert report["scenario"] == "android_android_foreground_baseline"
    assert report["two_distinct_physical_devices"] is False
    assert {item["id"] for item in report["checks"]} == CHECK_IDS
    assert all(item["status"] == "not_run" for item in report["checks"])
    result = validate(tmp_path, report)
    assert result.returncode == 1, result.stderr


def test_complete_report_is_explicitly_human_reported_not_release_approval(tmp_path: Path) -> None:
    result = validate(tmp_path, complete_record())
    assert result.returncode == 0, result.stderr
    output = result.stdout.lower()
    assert "human-reported" in output
    assert "not independently verified" in output
    assert "not release approval" in output


def test_same_models_reversed_labels_and_uppercase_hashes_are_valid(tmp_path: Path) -> None:
    report = complete_record()
    report["devices"].reverse()
    report["source_commit"] = COMMIT.upper()
    report["apk_sha256"] = APK.upper()
    assert validate(tmp_path, report).returncode == 0


@pytest.mark.parametrize("status", ["fail", "blocked", "not_run"])
def test_any_nonpassing_check_prevents_complete_report(tmp_path: Path, status: str) -> None:
    report = complete_record()
    report["checks"][0].update(status=status, observations="Observed limitation")
    assert validate(tmp_path, report).returncode == 1


def test_pass_without_observation_is_incomplete(tmp_path: Path) -> None:
    report = complete_record()
    report["checks"][0]["observations"] = "  "
    assert validate(tmp_path, report).returncode == 1


def test_no_physical_device_assertion_prevents_complete_report(tmp_path: Path) -> None:
    report = complete_record()
    report["devices"][0]["model"] = "Emulator fixture"
    report["two_distinct_physical_devices"] = False
    assert validate(tmp_path, report).returncode == 1


@pytest.mark.parametrize("field", ["tester", "date", "source_commit", "apk_sha256", "environment"])
def test_missing_metadata_cannot_complete_report(tmp_path: Path, field: str) -> None:
    report = complete_record()
    report[field] = ""
    assert validate(tmp_path, report).returncode == 1


def test_missing_device_version_is_incomplete(tmp_path: Path) -> None:
    report = complete_record()
    report["devices"][1]["google_play_services"] = ""
    assert validate(tmp_path, report).returncode == 1


@pytest.mark.parametrize("field", ["source_commit", "apk_sha256"])
def test_validly_shaped_but_wrong_artifact_is_rejected(tmp_path: Path, field: str) -> None:
    report = complete_record()
    report[field] = "0" * (40 if field == "source_commit" else 64)
    assert validate(tmp_path, report).returncode == 2


@pytest.mark.parametrize(
    "raw", ['{"schema_version":1,"schema_version":1}', '{"x":NaN}', '{"x":Infinity}', '{"x":1e999}']
)
def test_ambiguous_or_nonstandard_json_is_rejected(tmp_path: Path, raw: str) -> None:
    result = validate_text(tmp_path, raw)
    assert result.returncode == 2
    assert "Traceback" not in result.stderr


@pytest.mark.parametrize("scope", ["report", "device", "check"])
def test_unknown_fields_are_rejected_at_each_schema_boundary(tmp_path: Path, scope: str) -> None:
    report = complete_record()
    target = (
        report if scope == "report" else report["devices" if scope == "device" else "checks"][0]
    )
    target["unexpected"] = "ignored fields must not silently change meaning"
    assert validate(tmp_path, report).returncode == 2


def test_duplicate_check_or_device_identity_is_rejected(tmp_path: Path) -> None:
    report = complete_record()
    report["checks"][-1] = dict(report["checks"][0])
    assert validate(tmp_path, report).returncode == 2
    report = complete_record()
    report["devices"][1]["label"] = "A"
    assert validate(tmp_path, report).returncode == 2


def test_wrong_types_dates_statuses_and_scenarios_are_rejected(tmp_path: Path) -> None:
    for field, value in [
        ("schema_version", True),
        ("two_distinct_physical_devices", "true"),
        ("date", "2026-02-30"),
        ("date", (date.today() + timedelta(days=1)).isoformat()),
        ("scenario", "android_iphone"),
    ]:
        report = complete_record()
        report[field] = value
        assert validate(tmp_path, report).returncode == 2, (field, value)
    report = complete_record()
    report["checks"][0]["status"] = "certified"
    assert validate(tmp_path, report).returncode == 2


def test_oversized_and_excessively_nested_inputs_fail_without_traceback(tmp_path: Path) -> None:
    for raw in [json.dumps(complete_record()) + " " * 65536, "[" * 1500 + "0" + "]" * 1500]:
        result = validate_text(tmp_path, raw)
        assert result.returncode == 2
        assert "Traceback" not in result.stderr


def test_observations_remain_inert_text(tmp_path: Path) -> None:
    report = complete_record()
    marker = tmp_path / "must-not-exist"
    report["checks"][0]["observations"] = (
        f"$(touch {marker}) `touch {marker}` __import__('os').system('touch {marker}')"
    )
    assert validate(tmp_path, report).returncode == 0
    assert not marker.exists()
