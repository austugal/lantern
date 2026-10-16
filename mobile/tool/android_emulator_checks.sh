#!/usr/bin/env bash
# Runs inside the emulator action with mobile/ as the working directory.
set -euo pipefail
mkdir -p build/emulator-evidence
# First test the exact downloaded APK before Flutter rebuilds a test application.
python3 tool/android_smoke.py build/emulator-apk/app-debug.apk build/emulator-evidence
# Real system WebView fixture: page JavaScript disabled, explicit text extraction.
# pipefail ensures a failed native integration test fails the publication gate.
flutter test integration_test/web_capture_test.dart -d emulator-5554 --reporter expanded \
  2>&1 | tee build/emulator-evidence/webview-integration.txt
