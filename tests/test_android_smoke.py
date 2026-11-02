"""Fresh-install contract for APK checks; no emulator or hardware is simulated."""

from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from unittest.mock import call, patch

from mobile.tool.android_smoke import PACKAGE, Smoke

REGISTERED = f"package:{PACKAGE}\n".encode()


class AndroidSmokeStartupTests(TestCase):
    def setUp(self) -> None:
        self.directory = TemporaryDirectory(prefix="lantern-smoke-fixture-")
        self.addCleanup(self.directory.cleanup)
        self.runner = Smoke(Path(self.directory.name))
        self.apk = Path(self.directory.name) / "test.apk"
        self.apk.write_bytes(b"fixture only; never installed")

    def test_fresh_install_has_no_data_clear_or_permission_grant(self) -> None:
        responses = [b"", b"", b"Success\n", REGISTERED]
        with patch("mobile.tool.android_smoke.adb", side_effect=responses) as device:
            self.runner.install_fresh(self.apk)
        self.assertEqual(
            device.call_args_list,
            [
                call("shell", "pm", "list", "packages", PACKAGE),
                call("logcat", "-c"),
                call("install", str(self.apk.resolve())),
                call("shell", "pm", "list", "packages", PACKAGE),
            ],
        )
        self.assertEqual((self.runner.evidence / "install.txt").read_bytes(), b"Success\n")

    def test_existing_install_is_preserved_and_fails_before_mutation(self) -> None:
        with patch("mobile.tool.android_smoke.adb", return_value=REGISTERED) as device:
            with self.assertRaisesRegex(AssertionError, "will not be cleared"):
                self.runner.install_fresh(self.apk)
        device.assert_called_once_with("shell", "pm", "list", "packages", PACKAGE)

    def test_package_variant_is_not_confused_with_the_main_package(self) -> None:
        responses = [f"package:{PACKAGE}.beta\n".encode(), b"", b"Success", REGISTERED]
        with patch("mobile.tool.android_smoke.adb", side_effect=responses):
            self.runner.install_fresh(self.apk)

    def test_failed_package_query_is_not_treated_as_a_fresh_device(self) -> None:
        with patch(
            "mobile.tool.android_smoke.adb", side_effect=RuntimeError("device offline")
        ) as device:
            with self.assertRaisesRegex(RuntimeError, "device offline"):
                self.runner.install_fresh(self.apk)
        device.assert_called_once_with("shell", "pm", "list", "packages", PACKAGE)

    def test_installer_failure_stops_without_retry_or_launch(self) -> None:
        with patch(
            "mobile.tool.android_smoke.adb",
            side_effect=[b"", b"", RuntimeError("install failed")],
        ) as device:
            with self.assertRaisesRegex(RuntimeError, "install failed"):
                self.runner.run(self.apk)
        self.assertEqual(device.call_count, 3)
        self.assertEqual(device.call_args, call("install", str(self.apk.resolve())))

    def test_unregistered_apk_is_not_launched(self) -> None:
        with patch(
            "mobile.tool.android_smoke.adb", side_effect=[b"", b"", b"Success\n", b""]
        ) as device:
            with self.assertRaisesRegex(AssertionError, "not registered"):
                self.runner.run(self.apk)
        self.assertEqual(device.call_count, 4)

    def test_activity_launch_error_still_fails(self) -> None:
        responses = [b"", b"", b"Success", REGISTERED, b"Error: no activity"]
        with patch("mobile.tool.android_smoke.adb", side_effect=responses) as device:
            with self.assertRaisesRegex(AssertionError, "no activity"):
                self.runner.run(self.apk)
        self.assertEqual(device.call_count, 5)

    def test_app_startup_failure_is_not_hidden_by_reinstallation_or_relaunch(self) -> None:
        responses = [b"", b"", b"Success", REGISTERED, b"Status: ok"]
        with (
            patch("mobile.tool.android_smoke.adb", side_effect=responses) as device,
            patch.object(self.runner, "find", side_effect=AssertionError("app did not start")),
        ):
            with self.assertRaisesRegex(AssertionError, "app did not start"):
                self.runner.run(self.apk)
        self.assertEqual(device.call_count, 5)
        self.assertEqual(
            device.call_args,
            call("shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity"),
        )
