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

Direct Dart formatting, diff checks and a standalone extracted 148-check calculation harness passed. Local Flutter bootstrap was not retried after the earlier automatic approval review rejection of its metadata request. Flutter tests and Android/iOS compilation are delegated to CI. Exact results and PR/release evidence will be recorded once completed. Physical magnetometer direction/accuracy, screen rotation on phones and interference behavior remain pending, as do the existing radio/GPS/battery/signing gates.
