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


def validate_with_apk(
    tmp_path: Path, report: dict[str, Any], apk_file: Path, expected_digest: str
) -> subprocess.CompletedProcess[str]:
    path = tmp_path / "record.json"
    path.write_text(json.dumps(report), encoding="utf-8")
    return run_cli(
        "validate",
        str(path),
        "--expected-commit",
        COMMIT,
        "--expected-apk-sha256",
        expected_digest,
        "--apk-file",
        str(apk_file),
    )


def test_apk_file_matches_digest_without_claiming_installed_verification(tmp_path: Path) -> None:
    import hashlib

    data = b"Synthetic bytes only, not an APK or a device test.\n" * 30000
    artifact = tmp_path / "testing.apk"
    artifact.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    report = complete_record()
    report["apk_sha256"] = digest
    result = validate_with_apk(tmp_path, report, artifact, digest.upper())
    assert result.returncode == 0, result.stderr
    assert "sha-256 verified" in result.stdout.lower()
    assert "not independently verified" in result.stdout.lower()
    assert "not release approval" in result.stdout.lower()


def test_apk_file_mismatch_is_invalid_even_when_report_hash_matches(tmp_path: Path) -> None:
    artifact = tmp_path / "testing.apk"
    artifact.write_bytes(b"Bytes do not match the report's declared digest")
    result = validate_with_apk(tmp_path, complete_record(), artifact, APK)
    assert result.returncode == 2
    assert "Traceback" not in result.stderr
    assert "sha-256 verified" not in result.stdout.lower()


@pytest.mark.parametrize("kind", ["missing", "directory", "empty"])
def test_unusable_apk_file_is_invalid_without_traceback(tmp_path: Path, kind: str) -> None:
    artifact = tmp_path / "testing.apk"
    if kind == "directory":
        artifact.mkdir()
    elif kind == "empty":
        artifact.write_bytes(b"")
    result = validate_with_apk(tmp_path, complete_record(), artifact, APK)
    assert result.returncode == 2
    assert "Traceback" not in result.stderr
    assert "sha-256 verified" not in result.stdout.lower()


def test_matching_apk_cannot_turn_unexecuted_report_into_pass(tmp_path: Path) -> None:
    import hashlib

    artifact = tmp_path / "testing.apk"
    artifact.write_bytes(b"Synthetic fixture")
    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
    result = validate_with_apk(tmp_path, template(), artifact, digest)
    assert result.returncode == 1, result.stderr
    assert "not release approval" in result.stdout.lower()


def test_oversized_apk_file_is_rejected_at_configured_bound(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    import hashlib
    import importlib.util

    spec = importlib.util.spec_from_file_location("device_evidence_apk_test", TOOL)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, "MAX_APK_BYTES", 8)
    artifact = tmp_path / "testing.apk"
    data = b"123456789"
    artifact.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    report = complete_record()
    report["apk_sha256"] = digest
    record = tmp_path / "record.json"
    record.write_text(json.dumps(report), encoding="utf-8")
    result = module.main(
        [
            "validate",
            str(record),
            "--expected-commit",
            COMMIT,
            "--expected-apk-sha256",
            digest,
            "--apk-file",
            str(artifact),
        ]
    )
    assert result == 2
    output = capsys.readouterr()
    assert "Traceback" not in output.err
    assert "sha-256 verified" not in output.out.lower()


def test_apk_symlink_is_rejected_without_following_target(tmp_path: Path) -> None:
    import hashlib

    target = tmp_path / "target.apk"
    data = b"Synthetic fixture"
    target.write_bytes(data)
    link = tmp_path / "link.apk"
    try:
        link.symlink_to(target)
    except (OSError, NotImplementedError):
        pytest.skip("Creating symlinks is unavailable in this environment")
    digest = hashlib.sha256(data).hexdigest()
    report = complete_record()
    report["apk_sha256"] = digest
    result = validate_with_apk(tmp_path, report, link, digest)
    assert result.returncode == 2
    assert "regular file" in result.stderr
    assert "sha-256 verified" not in result.stdout.lower()


def test_apk_modified_during_hashing_is_rejected(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    import hashlib
    import importlib.util

    spec = importlib.util.spec_from_file_location("device_evidence_mutation_test", TOOL)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    artifact = tmp_path / "testing.apk"
    data = b"Synthetic fixture"
    artifact.write_bytes(data)
    original_read = module.os.read
    changed = False

    def mutate_after_read(descriptor: int, size: int) -> bytes:
        nonlocal changed
        chunk: bytes = original_read(descriptor, size)
        if chunk and not changed:
            changed = True
            with artifact.open("ab") as output:
                output.write(b"changed")
        return chunk

    monkeypatch.setattr(module.os, "read", mutate_after_read)
    with pytest.raises(ValueError, match="changed during hashing"):
        module.verify_apk_file(artifact, hashlib.sha256(data).hexdigest())
