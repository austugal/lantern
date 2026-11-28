# Foreground lifecycle validation repair — 28 November 2026

Inspected main `ed5a2a2f55819a54eaf1d106ba4ae65168b06137`, README, roadmap, active records, open PRs and CI. PR #51 owns this work; no fresh conflicting Finish Flutter Repo ownership was retrieved. Work is isolated on `fix/foreground-validation-20261128`, based on PR head `a53491fcb31f013d571a4b96eaf9e13564b300c2`, and updates that existing PR rather than duplicating it.

## Observed failure

[Mobile run 46007265911](https://github.com/austugal/lantern/actions/runs/46007265911) passed Android APK compilation, iOS simulator and unsigned device builds, and Flutter checks. [Python CI](https://github.com/austugal/lantern/actions/runs/46007265903) passed. Emulator job `140536862426` failed with `APK smoke=0; WebView fixture=0; uninstall=0; lifecycle=1`.

Downloaded artifact `15203816045` (Android-emulator-evidence) contains the decisive `lifecycle-instrumentation.txt`: `:app:checkDebugAndroidTestAarMetadata` could not resolve runner 1.7.0 because consistent resolution inherited a strict 1.2.0 constraint from `debugRuntimeClasspath`. The lifecycle tests never executed. This is a test dependency graph failure, not evidence that a lifecycle assertion or nearby radio failed.

## Repair and validation

Keep the production foreground guards and both instrumentation assertions unchanged. Align debug/test dependencies rather than dropping instrumentation. Stream the lifecycle log through tee while retaining pipefail and the separate exit status, so future errors are visible in ordinary job logs as well as artifacts.

All 136 Python tests passed locally. A stubbed execution of the actual emulator script passed four cases: success, Gradle failure, Flutter build failure and Flutter fixture failure. It verified failure propagation, separate JSON statuses and lifecycle log retention. Shell syntax and whitespace checks passed. These checks do not compile or execute Android instrumentation; fresh native CI remains required before merge.

The dependency specialist owns only app Gradle configuration. The primary agent owns script diagnostics, docs and PR update; the attribution specialist owns only temporary evidence. No native transport, consent, permission, background capability, location/media behavior or resource bounds change in this repair.

The [working mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-441b27b8636b) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-441b27b8636b) previews and pinned physical baseline are preserved. No physical-device, mixed-platform, production-signing or security-audit claim is added. The 28 November API/history still show only austugal across 107 commits, while the signed-out sidebar retains Claude; the [Support evidence](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md) is updated and unsent.

Primary-source review: [Flutter 3.35.7 integration_test Gradle configuration](https://github.com/flutter/flutter/blob/3.35.7/packages/integration_test/android/build.gradle.kts) exposes runner `1.2+`, rules `1.2+` and Espresso `3.2+` through API dependencies. [Gradle consistent resolution](https://docs.gradle.org/current/userguide/dependency_resolution_consistency.html) explains the inherited version constraints. The repair applies the same pinned core 1.7.0, ext.junit 1.3.0 and runner 1.7.0 list to both debugImplementation and androidTestImplementation. The specialist checked Google Maven POM alignment for monitor/storage transitives. Release declarations and the production foreground guards are unchanged. This is a proposed graph repair until fresh CI resolves and executes it.
