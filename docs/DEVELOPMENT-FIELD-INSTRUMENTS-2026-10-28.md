# Field instruments — 28 October 2026

User-requested scope: north compass, location and practical digital tools. Base main: `16a23587e61387ecad0de847f0f1d86f0802ec42`. No open PRs at start; prior reconnect release and desktop/mobile checks were green. Work isolated on `feat/mobile-field-instruments`; prior worktree left intact.

## Ownership and implementation

- Native compass specialist: Android MainActivity.kt and iOS AppDelegate.swift.
- Dart compass specialist: compass.dart and compass_test.dart.
- Calculator/measurement specialist: measurement_tools.dart and measurement_tools_test.dart.
- Read-only reliability reviewer: native north reference/orientation, lifecycle, privacy, inputs and tests.
- Integrator: app routes, built-in guidance, native integration/installed-APK coverage and documentation.

The compass is magnetic north, with no automatic GPS/location sharing. Sensors stop on inactive/background/page exit and need explicit restart. Stale/invalid/unreliable headings are hidden; outstanding reads cannot multiply. Arithmetic is length/depth bounded without evaluation; measurements use entered dimensions and fixed unit conversions, not camera ranging or a calibrated screen ruler. Existing GPS coordinates, accuracy and waypoint distances remain opt-in and unchanged.

Review corrected a missing brace lint and added transport-reply latency to heading freshness, with a regression test. Native source research links are in mobile/docs/ARCHITECTURE.md. Desktop source and nearby transports are unchanged.

## Validation boundary

Direct Dart formatting, diff checks and a standalone extracted 148-check calculation harness passed. Local Flutter bootstrap was not retried after the earlier automatic approval review rejection of its metadata request. Flutter tests and Android/iOS compilation ran in CI; the completed results are recorded below. Physical magnetometer direction/accuracy, screen rotation on phones and interference behavior remain pending, as do the existing radio/GPS/battery/signing gates.

## Completed release evidence

[PR #13](https://github.com/austugal/lantern/pull/13) validated source `f828ba9191e88bb2a9e7ad5ce9bbc5014c03f5c8` in [mobile run 40776050809](https://github.com/austugal/lantern/actions/runs/40776050809), then merged as `7060afce7e971fec67824e8f562510e00bf2b98c`. The main desktop package gate found Python formatting in the APK harness; [PR #14](https://github.com/austugal/lantern/pull/14) corrected only whitespace, with identical before/after Python ASTs, and merged as `3b9a0e88899008b7e72fa0f69b617b49c5a1e5c0`.

[Final main mobile run 40778887313](https://github.com/austugal/lantern/actions/runs/40778887313) passed:

- Formatting, static analysis and **130 Flutter tests**.
- Android testing APK, iOS simulator and unsigned iOS device builds.
- All **11 installed-APK navigation checks**, including the compass-off and calculator screens, on Android API 35.
- Both native integration fixtures: compass capability/Stop clearing and offline reading.

[Main desktop CI 40778887394](https://github.com/austugal/lantern/actions/runs/40778887394) passed **91 tests**, lint and strict typing on Python 3.10, 3.12 and 3.13. [Desktop packaging run 40778887458](https://github.com/austugal/lantern/actions/runs/40778887458) passed formatting, builds and executable checks on Linux, macOS and Windows.

[Download the validated mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-3b9a0e888990), published **28 October 2026 at 22:37:07 UTC**: Android testing APK, iOS simulator ZIP, unsigned iOS device ZIP and SHA256SUMS.txt. [Desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-3b9a0e888990) contains the three desktop packages.

These checks do not establish physical compass accuracy, real-device orientation or interference behaviour, GPS/radio performance, battery use, mixed Android–iPhone communication, background execution, production signing, independent security assurance or emergency-service contact. Physical checks remain pending in [physical-device checklist](../mobile/docs/DEVICE_TESTS.md).

At Tiago's explicit request, [CONTRIBUTORS.md](../CONTRIBUTORS.md) credits ChatGPT (OpenAI) for AI assistance. That credit is separate from GitHub's generated account sidebar.
