# Mobile verification record

## 27 October 2026 — bounded work-request acknowledgement source milestone

Scope: an ordinary, non-expiring text may explicitly request a human response. The connected recipient may accept or decline once, and that linked response uses the existing bounded text receipt and retry path. Unknown, late, conflicting or cross-session responses must not update a request or receive a false acknowledgement. No native transport, permission or background change is included.

Regression and CI evidence will be recorded here before the milestone is marked validated. Tests target strict packet combinations, response opt-in, current-session target checks, one final human decision, duplicate suppression, ordinary delivery receipts/retry for the response, disappearing-message exclusion and disconnect cleanup.

Local checks passed: Dart 3.9.2 formatting for all mobile library/test/tool files, standalone protocol analysis, a strict request/response packet smoke test, and the unchanged desktop suite (91 tests, Ruff and strict mypy). The Flutter suite and native builds remain PR validation gates.

These checks cannot establish that a person completed work, physical radio delivery, mixed Android/iPhone operation, production signing or security assurance. The [26 October validated release](https://github.com/austugal/lantern/releases/tag/mobile-preview-2c05cf8828df) remains the working download until this exact source passes PR and release validation.

## 26 October 2026 — bounded text retry

Scope: ordinary text only, 10-second native submission deadline, 30-second receipt deadline, explicit same-ID retry up to three submissions, bounded session duplicate records and unresolved native-call accounting. No native transport, permission or background changes were made.

[PR #7](https://github.com/austugal/lantern/pull/7) was validated in [run 40335605064](https://github.com/austugal/lantern/actions/runs/40335605064) and merged at `2c05cf8828df6ddb48eac3243fea58b4a06dba79`.

- Formatting and static analysis passed; **83 Flutter tests passed**.
- Android testing APK, iPhone simulator and unsigned iPhone device builds passed.
- The actual Android API 35 emulator installed and exercised the APK successfully.
- Desktop lint, strict typing and **91 tests** passed on Python 3.10, 3.12 and 3.13 in [run 40335605021](https://github.com/austugal/lantern/actions/runs/40335605021).

The new tests cover missing and late receipts, native deadlines, unchanged retry IDs, the three-submission limit, stale completion races, same-endpoint reconnection, both eight-operation budgets, receiver-history trimming, mixed-traffic deduplication and the 1,024-ID receive limit. Manual retry deliberately excludes relative-expiry text and media.

[Main release run 40338496400](https://github.com/austugal/lantern/actions/runs/40338496400) passed the same checks, native builds, actual-APK emulator gate and publication. [Download the validated preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-2c05cf8828df): Android testing APK, iPhone simulator ZIP, unsigned iPhone device ZIP and SHA256SUMS.txt.

These checks cannot establish radio delivery, battery use, mixed-platform operation, production signing or an independent security audit. Physical checks remain pending in [DEVICE_TESTS.md](DEVICE_TESTS.md).

## Mobile 0.3.0 web reading

[Validation run 38902303778](https://github.com/austugal/lantern/actions/runs/38902303778) passed on source `1308ce82b57a160dd4c28df4264e143b848fd54d`, merged through PR #6 at `e99ac83ace6f9eebc33a463515239559f1420420`.

- Formatting and static analysis passed; **67 Flutter tests passed**.
- Android APK, iPhone simulator and unsigned iPhone device builds passed.
- Actual Android API 35 emulator: APK installation and all nine onboarding/navigation/browser checks passed, with no app crash detected.
- Native integration test passed: page scripts remained disabled, bounded fixture text was parsed, saved and rendered using Flutter without a WebView. The deterministic download fixture makes no external website request.
- Emulator screenshots, UI XML and logs are in the run’s **Android-emulator-evidence** artifact (14-day retention).

Earlier test runs found an Android WebView extraction limitation, a test selector mismatch and a Pixel Launcher system ANR. The app now downloads text separately without browser cookies; the test matches actual Android semantics and handles only the exact system-launcher dialog. App crashes still fail the gate.

This establishes automated emulator behaviour, not physical radio reliability, arbitrary website compatibility or independent security certification. Real websites, physical phones and iPhone runtime testing remain required.

[Main release run 38904352555](https://github.com/austugal/lantern/actions/runs/38904352555) passed all checks, native builds, emulator tests and publication. [Download mobile 0.3.0](https://github.com/austugal/lantern/releases/tag/mobile-preview-e99ac83ace6f): Android testing APK, iPhone simulator ZIP, unsigned iPhone device ZIP and SHA256SUMS.txt.

## Mobile 0.2.0 media and maps

[Validation run 38893649362](https://github.com/austugal/lantern/actions/runs/38893649362) passed on source `13fd0ce75d70e85ac43ad25249f70154936c3033`:

- Formatting and Flutter analysis: no issues.
- **53 automated tests passed.**
- Android testing APK compiled.
- iOS simulator and unsigned device apps compiled.
- Desktop CI passed for the same changes.

The source was merged through PR #5 at `adfd2c230f06e763ae72861c846b5298caabe8f9`. New checks cover attachment bounds and cleanup, torch timing/cancellation, notification channel arguments, photo resizing, emoji entry and offline-map parsing. Actual camera, microphone, torch, notifications, map downloads and mixed OS lifecycle behaviour still need physical-device testing.

[Main release run 38894662274](https://github.com/austugal/lantern/actions/runs/38894662274) passed all checks, native builds and publication. [Download mobile 0.2.0](https://github.com/austugal/lantern/releases/tag/mobile-preview-adfd2c230f06): Android testing APK, iOS simulator ZIP, unsigned iOS device ZIP and SHA256SUMS.txt.

## Earlier preview evidence

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
