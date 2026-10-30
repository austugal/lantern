# Mobile verification record

## 30 October 2026 — bounded attachment delivery status

Candidate source adds a 30-second app-receipt deadline after complete attachment submission, honest uncertainty, late-receipt recovery, callback isolation and a four-call unresolved native attachment budget across reconnects. It retains the existing transport, packet format, foreground-only behaviour and explicit media/location/notification consent. No automatic resend or attachment retry is added.

Regression tests cover final-submission timing, missing/late/wrong-peer receipts, independent deadlines, early receipts racing native completion/error/timeout, native budget across reconnects, stale session results, teardown and trimming; a conversation widget test checks the visible unconfirmed status and absence of retry. Local Dart 3.9.2 formatting and full-repository Ruff lint/format passed. Flutter analyzer/tests and Android/iOS CI results are pending; no successful execution of these new tests is claimed yet. The current validated download remains [mobile-preview-3b9a0e888990](https://github.com/austugal/lantern/releases/tag/mobile-preview-3b9a0e888990).

No physical devices, radio delivery, mixed Android–iPhone operation, background execution, production signing or independent security audit were used or established.

## 28 October 2026 — field instruments

Scope: explicit local magnetic compass, offline arithmetic, length/area/volume conversions and rectangle/box calculations. Existing opt-in GPS/true-north waypoint bearings remain separate. No new permission, transport, GPS sharing or background service is added. Primary SDK sources are recorded in [ARCHITECTURE.md](ARCHITECTURE.md).

New tests cover compass lifecycle, stale and delayed readings, bounded polling, unavailable sensors, native channel stop/clear, arithmetic precedence/errors/bounds, unit factors, geometry, small-screen enlarged text and entry from Field tools. The Android installed-APK smoke adds the compass-off and calculator screens. The completed PR and main-release checks are recorded below. Local direct Dart formatting and the extracted 148-check calculation harness passed; no physical compass accuracy, orientation, GPS or range test is claimed.

[PR #13](https://github.com/austugal/lantern/pull/13) validated source `f828ba9191e88bb2a9e7ad5ce9bbc5014c03f5c8` in [mobile run 40776050809](https://github.com/austugal/lantern/actions/runs/40776050809), then merged as `7060afce7e971fec67824e8f562510e00bf2b98c`. The main desktop package gate found Python formatting in the APK harness; [PR #14](https://github.com/austugal/lantern/pull/14) corrected only whitespace, with identical before/after Python ASTs, and merged as `3b9a0e88899008b7e72fa0f69b617b49c5a1e5c0`.

[Final main mobile run 40778887313](https://github.com/austugal/lantern/actions/runs/40778887313) passed:

- Formatting, static analysis and **130 Flutter tests**.
- Android testing APK, iOS simulator and unsigned iOS device builds.
- All **11 installed-APK navigation checks**, including the compass-off and calculator screens, on Android API 35.
- Both native integration fixtures: compass capability/Stop clearing and offline reading.

[Main desktop CI 40778887394](https://github.com/austugal/lantern/actions/runs/40778887394) passed **91 tests**, lint and strict typing on Python 3.10, 3.12 and 3.13. [Desktop packaging run 40778887458](https://github.com/austugal/lantern/actions/runs/40778887458) passed formatting, builds and executable checks on Linux, macOS and Windows.

[Download the validated mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-3b9a0e888990), published **28 October 2026 at 22:37:07 UTC**: Android testing APK, iOS simulator ZIP, unsigned iOS device ZIP and SHA256SUMS.txt. [Desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-3b9a0e888990) contains the three desktop packages.

These checks do not establish physical compass accuracy, real-device orientation or interference behaviour, GPS/radio performance, battery use, mixed Android–iPhone communication, background execution, production signing, independent security assurance or emergency-service contact. Physical checks remain pending in [DEVICE_TESTS.md](DEVICE_TESTS.md).

## 28 October 2026 — explicit foreground reconnection recovery

Scope: foreground recovery guidance over the existing native session. Background, unexpected native stop and peer connection loss clear current-session state and display a reason. Restarting discovery requires a tap; reconnecting requires fresh peer choice and confirmation. No message, request, location, guardian or check-in state is queued or restored. No native transport, permission or background execution change was included.

[PR #11](https://github.com/austugal/lantern/pull/11) validated code source `39a99c457443c7018129d76ef889373b3ca89061` in [mobile run 40697447557](https://github.com/austugal/lantern/actions/runs/40697447557) and [desktop CI run 40697445599](https://github.com/austugal/lantern/actions/runs/40697445599).

[PR #11](https://github.com/austugal/lantern/pull/11) final head `d812730f730d0d861c73c01ced78e8f0e7c540ab` passed [mobile run 40700274716](https://github.com/austugal/lantern/actions/runs/40700274716) and [desktop CI run 40700274439](https://github.com/austugal/lantern/actions/runs/40700274439), then merged as `966ecdf1c0f61233e2624f74ec804e5e8e93a2d4`. [Main release run 40703204234](https://github.com/austugal/lantern/actions/runs/40703204234) repeated the mobile checks, native builds and actual-APK emulator gate before publication. [Main desktop CI 40703204218](https://github.com/austugal/lantern/actions/runs/40703204218) and [desktop preview run 40703204474](https://github.com/austugal/lantern/actions/runs/40703204474) passed. [Download the validated preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-966ecdf1c0f6): Android testing APK, iPhone simulator ZIP, unsigned iPhone device ZIP and SHA256SUMS.txt.

- Formatting and static analysis passed; **111 Flutter tests passed**.
- Android testing APK, iPhone simulator and unsigned iPhone device builds passed.
- The Android API 35 emulator installed and exercised the actual APK successfully.
- Desktop lint, strict typing and **91 tests** passed on Python 3.10, 3.12 and 3.13.
- New coverage includes background and native-stop recovery, deliberate stop/disconnect suppression, explicit restart failure, renewed consent, late callback rejection, delayed native failure isolation and a 320-pixel-wide UI at 1.5× text scale.

The first candidate run exposed narrow-screen banner and app-title overflow. The final source shortens the notice and collapses the title at constrained widths; the full gate then passed. Automated checks did not use physical phones and do not establish real lifecycle behaviour, radio delivery, mixed Android/iPhone operation, battery use, production signing, security assurance, background messaging or emergency-service contact. Physical checks remain pending in [DEVICE_TESTS.md](DEVICE_TESTS.md).

## 27 October 2026 — bounded work-request acknowledgement

Scope: an ordinary, non-expiring text may explicitly request a human response. The connected recipient may accept or decline once, and that linked response uses the existing bounded text receipt and retry path. Unknown, late, conflicting or cross-session responses do not update a request or receive a false acknowledgement. No native transport, permission or background change was included.

[PR #9](https://github.com/austugal/lantern/pull/9) was validated on source `1c6ec9fadac7416a83ef72aef2a171c76ea4b0d6` in [mobile run 40515912420](https://github.com/austugal/lantern/actions/runs/40515912420) and [desktop CI run 40515912477](https://github.com/austugal/lantern/actions/runs/40515912477), then merged at `2baaffd3d1e2a140e2bb25167940c950e6229929`.

- Formatting and static analysis passed; **93 Flutter tests passed**.
- Android testing APK, iPhone simulator and unsigned iPhone device builds passed.
- The Android API 35 emulator installed and exercised the actual APK successfully.
- Desktop lint, strict typing and **91 tests** passed on Python 3.10, 3.12 and 3.13.
- New coverage includes strict request/response packet combinations, current-session target checks, first-decision finality, changed same-ID rejection, response receipts and retry metadata, disappearing-message exclusion, resource bounds, reconnect cleanup, stale callbacks and narrow-screen confirmation UI.

[Main release run 40518535828](https://github.com/austugal/lantern/actions/runs/40518535828) repeated the mobile checks, native builds and actual-APK emulator gate before publication. [Main desktop CI 40518535861](https://github.com/austugal/lantern/actions/runs/40518535861) and [desktop preview run 40518535910](https://github.com/austugal/lantern/actions/runs/40518535910) passed. [Download the validated preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-2baaffd3d1e2): Android testing APK, iPhone simulator ZIP, unsigned iPhone device ZIP and SHA256SUMS.txt.

These checks establish app behaviour in automated tests and an Android emulator. They cannot establish that a person completed work, physical radio delivery, battery use, mixed Android/iPhone operation, production signing or independent security assurance. Physical checks remain pending in [DEVICE_TESTS.md](DEVICE_TESTS.md).

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
