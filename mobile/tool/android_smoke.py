"""Install and exercise the actual APK on one emulator; no radio/hardware claims.

Usage: python tool/android_smoke.py path/to/app.apk [evidence-directory]
Parser self-check only (no device): python tool/android_smoke.py --self-test
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

PACKAGE = "org.austugal.lantern"


def adb(*args: str, check: bool = True) -> bytes:
    result = subprocess.run(["adb", *args], capture_output=True, timeout=40, check=False)
    if check and result.returncode:
        raise RuntimeError(f"adb {args}: {result.stderr.decode(errors='replace')}")
    return result.stdout


def match_node(xml: str, label: str = "", class_name: str = "") -> ET.Element | None:
    for node in ET.fromstring(xml).iter("node"):
        values = (node.get("text", ""), node.get("content-desc", ""))
        if label and not any(label.casefold() in value.casefold() for value in values):
            continue
        if class_name and node.get("class") != class_name:
            continue
        if node.get("enabled", "true") == "true":
            return node
    return None


def center(node: ET.Element) -> tuple[int, int]:
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if not match:
        raise ValueError("Missing or invalid node bounds")
    left, top, right, bottom = map(int, match.groups())
    if right <= left or bottom <= top:
        raise ValueError("Node has no visible bounds")
    return (left + right) // 2, (top + bottom) // 2


def launcher_anr_close(xml: str) -> ET.Element | None:
    """Match only Android's exact Pixel Launcher ANR, never Lantern's ANR."""
    nodes = list(ET.fromstring(xml).iter("node"))
    launcher_title = any(
        n.get("package") == "android"
        and n.get("resource-id") == "android:id/alertTitle"
        and n.get("text") == "Pixel Launcher isn't responding"
        for n in nodes
    )
    if not launcher_title:
        return None
    return next(
        (
            n
            for n in nodes
            if n.get("package") == "android"
            and n.get("resource-id") == "android:id/aerr_close"
            and n.get("text") == "Close app"
        ),
        None,
    )


class Smoke:
    def __init__(self, evidence: Path):
        self.evidence = evidence
        evidence.mkdir(parents=True, exist_ok=True)
        self.steps: list[str] = []
        self.launcher_recovered = False

    def snapshot(self, name: str) -> str:
        adb("shell", "uiautomator", "dump", "/sdcard/lantern-smoke.xml")
        xml = adb("shell", "cat", "/sdcard/lantern-smoke.xml").decode()
        (self.evidence / f"{name}.xml").write_text(xml)
        (self.evidence / f"{name}.png").write_bytes(adb("exec-out", "screencap", "-p"))
        return xml

    def find(
        self, label: str = "", class_name: str = "", allow_launcher_recovery: bool = False
    ) -> ET.Element:
        # Bounded retries accommodate first-frame rendering and emulator load.
        last_error: Exception | None = None
        for _ in range(12):
            try:
                xml = self.snapshot("latest")
                close = launcher_anr_close(xml) if allow_launcher_recovery else None
                if close is not None and not self.launcher_recovered:
                    self.launcher_recovered = True
                    for extension in ("xml", "png"):
                        source = self.evidence / f"latest.{extension}"
                        (self.evidence / f"system-launcher-anr.{extension}").write_bytes(
                            source.read_bytes()
                        )
                    x, y = center(close)
                    adb("shell", "input", "tap", str(x), str(y))
                    adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity")
                    print(
                        "Recovered exact Pixel Launcher ANR once; Lantern ANRs remain failures.",
                        flush=True,
                    )
                    continue
                node = match_node(xml, label, class_name)
                if node is not None:
                    return node
            except (RuntimeError, ET.ParseError) as error:
                last_error = error
            time.sleep(1)
        raise AssertionError(f"UI not found: {label or class_name}; {last_error}")

    def tap(self, label: str = "", class_name: str = "") -> None:
        x, y = center(self.find(label, class_name))
        adb("shell", "input", "tap", str(x), str(y))

    def scroll_to(self, label: str) -> None:
        # Scroll only the current page; coordinates come from actual emulator dimensions.
        size = adb("shell", "wm", "size").decode()
        dimensions = re.findall(r"(\d+)x(\d+)", size)
        if not dimensions:
            raise AssertionError("Cannot read emulator screen dimensions")
        width, height = map(int, dimensions[-1])
        for _ in range(6):
            if match_node(self.snapshot("latest"), label) is not None:
                self.tap(label)
                return
            adb(
                "shell",
                "input",
                "swipe",
                str(width // 2),
                str(height * 3 // 4),
                str(width // 2),
                str(height // 3),
                "400",
            )
            time.sleep(1)
        raise AssertionError(f"Scrollable control not found: {label}")

    def record(self, name: str) -> None:
        self.snapshot(name)
        self.steps.append(name)
        print(f"PASS: {name}", flush=True)

    def run(self, apk: Path) -> None:
        adb("install", "-r", str(apk.resolve()))  # Deliberately no -g permission grant.
        adb("shell", "pm", "clear", PACKAGE)
        adb("logcat", "-c")
        launch = adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity")
        (self.evidence / "launch.txt").write_bytes(launch)
        if b"Error:" in launch:
            raise AssertionError(launch.decode())
        self.find("Make yourself at home", allow_launcher_recovery=True)
        self.record("01-onboarding")
        self.tap(class_name="android.widget.EditText")
        adb("shell", "input", "text", "EmulatorTester")
        adb("shell", "input", "keyevent", "KEYCODE_BACK")  # Dismiss keyboard only.
        self.tap("Make yourself at home")
        self.find("Turn on Lantern")
        self.record("02-nearby-off")
        self.tap("Field tools")
        self.find("Torch on")
        self.record("03-field-tools")
        self.tap("Open offline guide")
        self.find("Connect two phones")
        self.record("04-offline-guide")
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        self.find("Torch on")
        self.record("05-guide-dismissed")
        self.scroll_to("Web & saved pages")
        self.find("No saved pages")
        self.record("06-saved-reading-empty")
        self.tap("Browse online")
        self.find("Browse online?")
        self.record("07-browser-consent")
        self.tap("Open online browser")
        self.find("Online browser")
        # Flutter's floating field label is not exposed in this Android semantics tree.
        self.find(class_name="android.widget.EditText")
        self.find("Open website online")
        self.find("JavaScript disabled")
        self.record("08-browser-controls-no-navigation")
        # No address entered and no remote website opened by this smoke test.
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        self.find("No saved pages")
        self.record("09-browser-return")
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        # Restore the field list to its top before opening the new instruments.
        adb("shell", "input", "keyevent", "KEYCODE_MOVE_HOME")
        size = adb("shell", "wm", "size").decode()
        width, height = map(int, re.findall(r"(\d+)x(\d+)", size)[-1])
        for _ in range(4):
            adb("shell", "input", "swipe", str(width // 2), str(height // 3),
                str(width // 2), str(height * 3 // 4), "300")
        self.scroll_to("Compass · find north")
        self.find("Magnetic north")
        self.find("Start compass")
        self.record("10-compass-off")
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        self.scroll_to("Calculator & measurements")
        self.find("Calculator & measures")
        self.find("Calculate")
        self.record("11-calculator")
        if not adb("shell", "pidof", PACKAGE, check=False).strip():
            raise AssertionError("Lantern process exited")
        crashes = adb("logcat", "-d", "-b", "crash").decode(errors="replace")
        if PACKAGE in crashes:
            raise AssertionError("Lantern crash detected; inspect crash.txt")
        process_id = adb("shell", "pidof", PACKAGE).decode().strip().split()[0]
        logs = adb("logcat", "-d", f"--pid={process_id}").decode(errors="replace")
        if "Unhandled Exception:" in logs or "FATAL EXCEPTION:" in logs:
            raise AssertionError("Unhandled app exception; inspect logcat.txt")

    def finish(self, error: str | None) -> None:
        for name, args in [
            ("logcat.txt", ("logcat", "-d")),
            ("crash.txt", ("logcat", "-d", "-b", "crash")),
        ]:
            try:
                (self.evidence / name).write_bytes(adb(*args, check=False))
            except (OSError, subprocess.TimeoutExpired):
                pass
        (self.evidence / "result.json").write_text(
            json.dumps(
                {
                    "passed": error is None,
                    "system_launcher_anr_recovered": self.launcher_recovered,
                    "steps": self.steps,
                    "error": error,
                    "scope": "Single emulator APK installation, onboarding and UI navigation only",
                    "not_tested": [
                        "two-phone nearby connection",
                        "radio range",
                        "physical GPS",
                        "camera/torch hardware",
                        "iPhone",
                        "background delivery",
                    ],
                },
                indent=2,
            )
        )


def self_test() -> None:
    xml = (
        '<hierarchy><node text="Field tools" enabled="true" bounds="[10,20][110,80]"/>'
        '<node text="" content-desc="Open offline guide" enabled="true" '
        'bounds="[2,4][12,24]"/></hierarchy>'
    )
    node = match_node(xml, "field tools")
    assert node is not None and center(node) == (60, 50)
    assert match_node(xml, "offline guide") is not None
    assert match_node(xml, "missing") is None
    assert match_node(xml, class_name="android.widget.EditText") is None
    print("UI XML parser fixture passed (not an emulator test).")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        runner = Smoke(Path(sys.argv[2] if len(sys.argv) > 2 else "build/emulator-evidence"))
        error_message = None
        try:
            runner.run(Path(sys.argv[1]))
        except Exception as exc:
            error_message = str(exc)
            raise
        finally:
            runner.finish(error_message)
