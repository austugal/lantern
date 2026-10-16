#!/usr/bin/env bash
# Runs inside the emulator action with mobile/ as the working directory.
set -euo pipefail
mkdir -p build/emulator-evidence
# First test the exact downloaded APK before Flutter rebuilds a test application.
# Collect both results even when one fails, so one CI run retains all diagnostics.
smoke_status=0
python3 tool/android_smoke.py build/emulator-apk/app-debug.apk build/emulator-evidence \
  || smoke_status=$?
# Integration builds use a different debug keystore; remove the downloaded APK first.
cleanup_status=0
adb uninstall org.austugal.lantern > build/emulator-evidence/uninstall.txt 2>&1 \
  || cleanup_status=$?
# Native browser/saved-reading fixture supplied by integration_test.
# pipefail ensures a failed native integration test fails the publication gate.
webview_status=0
flutter test integration_test/web_capture_test.dart -d emulator-5554 --reporter expanded \
  2>&1 | tee build/emulator-evidence/webview-integration.txt || webview_status=$?
printf '{"apk_smoke_exit":%s,"webview_integration_exit":%s,"uninstall_exit":%s}\n' \
  "$smoke_status" "$webview_status" "$cleanup_status" > build/emulator-evidence/check-exits.json
if (( smoke_status != 0 || webview_status != 0 || cleanup_status != 0 )); then
  echo "Emulator checks failed: APK smoke=$smoke_status; WebView fixture=$webview_status; uninstall=$cleanup_status"
  exit 1
fi
