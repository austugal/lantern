#!/usr/bin/env python3
"""Prepare and check bounded, human-reported two-Android-phone baseline records.

This tool reads local JSON only. It cannot establish that a physical test occurred,
verify a device or installed binary, or approve a release.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any

MAX_REPORT_BYTES = 65_536
MAX_TEXT_LENGTH = 2_000
SCENARIO = "android_android_foreground_baseline"
CHECK_IDS = (
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
)
STATUSES = {"not_run", "pass", "fail", "blocked"}
REPORT_KEYS = {
    "schema_version",
    "scenario",
    "source_commit",
    "apk_sha256",
    "tester",
    "date",
    "two_distinct_physical_devices",
    "environment",
    "devices",
    "checks",
}
DISCLAIMER = (
    "Human-reported baseline only; not independently verified. "
    "This is not release approval or completion of the full DEVICE_TESTS checklist."
)


def make_template() -> dict[str, Any]:
    """Return an unexecuted scaffold; empty fields never constitute a passing record."""
    return {
        "schema_version": 1,
        "scenario": SCENARIO,
        "source_commit": "",
        "apk_sha256": "",
        "tester": "",
        "date": "",
        "two_distinct_physical_devices": False,
        "environment": "",
        "devices": [
            {"label": label, "model": "", "os": "", "google_play_services": ""}
            for label in ("A", "B")
        ],
        "checks": [
            {"id": identifier, "status": "not_run", "observations": ""} for identifier in CHECK_IDS
        ],
    }


def _object(value: object, keys: set[str], field: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise ValueError(f"{field} must be an object with exactly: {', '.join(sorted(keys))}")
    return value


def _text(value: object, field: str) -> str:
    if not isinstance(value, str) or len(value) > MAX_TEXT_LENGTH:
        raise ValueError(f"{field} must be text of at most {MAX_TEXT_LENGTH} characters")
    return value


def _expected_hash(value: str, digits: int, field: str) -> str:
    if not isinstance(value, str) or re.fullmatch(rf"[0-9a-fA-F]{{{digits}}}", value) is None:
        raise ValueError(f"{field} must contain exactly {digits} hexadecimal characters")
    return value.lower()


def validate_report(report: object, expected_commit: str, expected_apk_sha256: str) -> list[str]:
    """Return incomplete/failed reasons; raise ValueError for invalid records.

    Expected hashes are caller-supplied comparison values, not trusted provenance
    discovered by this tool. A structurally complete record remains self-reported.
    """
    commit = _expected_hash(expected_commit, 40, "expected commit")
    apk = _expected_hash(expected_apk_sha256, 64, "expected APK SHA-256")
    record = _object(report, REPORT_KEYS, "report")
    if type(record["schema_version"]) is not int or record["schema_version"] != 1:
        raise ValueError("schema_version must be integer 1")
    if record["scenario"] != SCENARIO:
        raise ValueError(f"scenario must be {SCENARIO}")

    incomplete: list[str] = []
    for field, digits, expected in (("source_commit", 40, commit), ("apk_sha256", 64, apk)):
        value = _text(record[field], field)
        if not value:
            incomplete.append(f"{field} is missing")
        elif _expected_hash(value, digits, field) != expected:
            raise ValueError(f"{field} does not match the expected artifact")

    for field in ("tester", "environment"):
        if not _text(record[field], field).strip():
            incomplete.append(f"{field} is missing")

    stamp = _text(record["date"], "date")
    if not stamp:
        incomplete.append("date is missing")
    else:
        if re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", stamp) is None:
            raise ValueError("date must use YYYY-MM-DD")
        try:
            observed_date = date.fromisoformat(stamp)
        except ValueError as exc:
            raise ValueError("date is not a valid calendar date") from exc
        if observed_date > date.today():
            raise ValueError("date cannot be in the future")

    if type(record["two_distinct_physical_devices"]) is not bool:
        raise ValueError("two_distinct_physical_devices must be a boolean")
    if not record["two_distinct_physical_devices"]:
        incomplete.append("two distinct physical devices have not been confirmed by the tester")

    devices = record["devices"]
    if not isinstance(devices, list) or len(devices) != 2:
        raise ValueError("devices must contain exactly two records")
    labels: set[str] = set()
    for index, entry in enumerate(devices):
        device = _object(entry, {"label", "model", "os", "google_play_services"}, "device")
        label = _text(device["label"], f"devices[{index}].label")
        if label not in {"A", "B"} or label in labels:
            raise ValueError("devices must use labels A and B exactly once")
        labels.add(label)
        for field in ("model", "os", "google_play_services"):
            if not _text(device[field], f"device {label} {field}").strip():
                incomplete.append(f"device {label} {field} is missing")

    checks = record["checks"]
    if not isinstance(checks, list) or len(checks) != len(CHECK_IDS):
        raise ValueError(f"checks must contain exactly {len(CHECK_IDS)} records")
    identifiers: set[str] = set()
    for entry in checks:
        check = _object(entry, {"id", "status", "observations"}, "check")
        identifier = _text(check["id"], "check id")
        if identifier not in CHECK_IDS or identifier in identifiers:
            raise ValueError("checks must contain every required id exactly once")
        identifiers.add(identifier)
        status = _text(check["status"], f"{identifier} status")
        if status not in STATUSES:
            raise ValueError(f"{identifier} has an unknown status")
        observations = _text(check["observations"], f"{identifier} observations")
        if status != "pass":
            incomplete.append(f"{identifier}: {status}")
        if status != "not_run" and not observations.strip():
            incomplete.append(f"{identifier}: observations are missing")
    return incomplete


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _nonfinite(value: str) -> None:
    raise ValueError(f"non-finite JSON number is not allowed: {value}")


def _finite_float(value: str) -> float:
    number = float(value)
    if not math.isfinite(number):
        raise ValueError("non-finite JSON number is not allowed")
    return number


def load_report(path: Path) -> object:
    """Read at most the fixed byte budget, rejecting ambiguous or excessive JSON."""
    with path.open("rb") as stream:
        raw = stream.read(MAX_REPORT_BYTES + 1)
    if len(raw) > MAX_REPORT_BYTES:
        raise ValueError(f"report exceeds {MAX_REPORT_BYTES} bytes")
    try:
        return json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=_pairs,
            parse_constant=_nonfinite,
            parse_float=_finite_float,
        )
    except (UnicodeError, json.JSONDecodeError, RecursionError) as exc:
        raise ValueError("report must be bounded, valid UTF-8 JSON") from exc


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("template", help="print an unexecuted JSON scaffold")
    validate = commands.add_parser("validate", help="check a local human-reported baseline record")
    validate.add_argument("file", type=Path)
    validate.add_argument("--expected-commit", required=True)
    validate.add_argument("--expected-apk-sha256", required=True)
    args = parser.parse_args(argv)
    if args.command == "template":
        print(json.dumps(make_template(), indent=2, allow_nan=False))
        return 0
    try:
        reasons = validate_report(
            load_report(args.file), args.expected_commit, args.expected_apk_sha256
        )
    except (OSError, ValueError, RecursionError) as exc:
        print(f"Invalid record: {exc}", file=sys.stderr)
        print(DISCLAIMER, file=sys.stderr)
        return 2
    print(DISCLAIMER)
    if reasons:
        print("Baseline record incomplete or contains unsuccessful checks:")
        for reason in reasons:
            print(f"- {reason}")
        return 1
    print("Reported baseline checks complete. All required checks are reported as passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
