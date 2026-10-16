# Mobile verification record

## Completed automated checks

The root [Mobile workflow](../../.github/workflows/mobile.yml) uses Flutter 3.35.7.

[Build run 38889566714](https://github.com/austugal/lantern/actions/runs/38889566714) completed:

- Dart formatting and Flutter static analysis.
- **28 automated tests**, covering the protocol, controller and mobile widgets.
- Android testing APK compilation.
- iOS simulator app compilation.
- Unsigned iOS device app compilation.

The changes were merged into `main` at `928a3c3c4bed`. Downloads are listed on the [release page](https://github.com/austugal/lantern/releases); the [main release run](https://github.com/austugal/lantern/actions/runs/38890303698) records publication status.

Local offline checks also passed: **10,019 packet checks**, direct Dart formatting/parsing, Android XML parsing and iOS plist parsing. These supplement the CI builds; they do not replace device tests.

## What the tests establish

The tests exercise explicit connection consent, rejection of unsolicited peers, malformed packet rejection, duplicate suppression, matching delivery receipts, location opt-in and expiry, stop/background handling, permission races, disappearing messages, guardian consent and timeout, timer cancellation, local-only navigation, coordinate validation, distance/bearing calculations, help dialogs and small-screen layouts.

Earlier CI found and prompted fixes for lint errors, narrow-screen overflows and off-screen test navigation. Use the successful run above rather than an earlier failed run.

## What remains untested

- Communication between two physical Android phones or two physical iPhones.
- GPS accuracy, denied permissions and lifecycle behaviour on real OS/device combinations.
- Range through walls, interference, battery use and prolonged sessions.
- Screen-reader usability and full accessibility testing on devices.
- Independent security review.

A simulator build cannot validate nearby radios. An unsigned iOS device build cannot be installed directly on an iPhone; it needs Apple signing and provisioning. Android downloads are development-signed testing APKs. Neither platform has a store release or security certification.

Use the [device checklist](DEVICE_TESTS.md). Desktop checks are recorded separately in [desktop QA](../../docs/DESKTOP-QA-2026-10-16.md).

## Published preview

Main commit `928a3c3c4bedb7747d685322e2540ae689897bf3` passed checks, Android, iOS and publication in [run 38890303698](https://github.com/austugal/lantern/actions/runs/38890303698). [Download the published developer preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-928a3c3c4bed): Android testing APK, iOS simulator ZIP, unsigned device ZIP and SHA256 checksums.
