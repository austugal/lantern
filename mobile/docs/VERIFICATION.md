# Mobile verification record

## 3 November 2026 — Android foreground-session design gate

The [implementation contract](ANDROID-FOREGROUND-SESSION-CONTRACT-2026-11-03.md) records the Android platform requirements and Lantern product limits that must be satisfied before foreground-session code is added. It follows the primary Android foreground-service, notification and stopping guidance and Google's Nearby Connections permission documentation, alongside a current-code lifecycle audit.

The first candidate is Android-only and explicitly enabled after one verified peer connects. Its service must be non-exported, `connectedDevice`, `START_NOT_STICKY` and bounded to 30 minutes. It may hold complete byte payloads from that exact peer only, in volatile memory, capped at 32 payloads and 256 KiB. Overflow disconnects. It sends no application receipt until resumed Dart code validates and accepts a packet. Notification permission, an in-app Stop control and a notification Stop action are required. There is no automatic start, restart, discovery, reconnection, retry or disk persistence. Location, navigation, check-ins, media, compass and torch continue to stop on background; iPhone remains foreground-only.

This is a documentation and implementation-gate milestone. No Android service or permission was added, no transport or application behaviour changed, and the current validated mobile and desktop previews remain unchanged. Documentation validation includes `git diff --check` and the repository-relative Markdown link check. The existing 3 November main mobile, Python and desktop runs below remain the current application evidence. No physical phone, Android-to-iPhone communication, background execution, production signing, measured battery behaviour or security audit was established.

## 3 November 2026 — bounded work-request completion status

The released scope permits a current foreground request to move from waiting to Accepted or Declined, then from a delivered acceptance to one terminal Completed or Unable status. Each linked response uses the existing bounded text receipt, explicit retry, stable-ID and resource-limit path. Unknown, conflicting, repeated, cross-session or out-of-order transitions do not update the request or receive a false app receipt.

The statuses are human-reported button taps, not independent proof that work occurred or that a supervisor approved it. Disconnecting or backgrounding clears the in-memory request and responses. This slice changes no native transport, platform permission, persistent queue, group capability, production signing or background execution.

Local Dart 3.9.2 formatting, 10,019 standalone packet checks, Ruff lint/format, strict mypy and all 126 Python tests passed. A separate read-only review found no blocker.

[PR #26](https://github.com/austugal/lantern/pull/26) validated head `2e8f10f9296728c4df3c6fdd6e84e4fad58cceb0` and merged as `ae0b65b85f6fc68a8c29b13ca2de1244284ef817`, with identical tree `f3432b3205bc061599767e6a9babecea7c1fa55a`. [PR mobile run 41648787264](https://github.com/austugal/lantern/actions/runs/41648787264) passed formatting, analysis, **168 Flutter tests**, Android APK, iOS simulator and unsigned-device builds, **13 installed-APK scenarios** and **two native fixtures**. [PR Python CI 41648787420](https://github.com/austugal/lantern/actions/runs/41648787420) passed on Python 3.10/3.12/3.13.

[Main mobile run 41652190175](https://github.com/austugal/lantern/actions/runs/41652190175) passed every gate and publication on attempt 3. Attempt 1 hit `No space left on device` in the GitHub-hosted runner's own diagnostic log. Attempt 2 passed Android compilation but SDK Manager received an `unknown archive` while installing the emulator system image, before Lantern launched. The targeted emulator retry used unchanged source and passed all 13 APK checks and both native fixtures. [Main Python CI 41652190243](https://github.com/austugal/lantern/actions/runs/41652190243) and [desktop builds/publication 41652190315](https://github.com/austugal/lantern/actions/runs/41652190315) also passed.

[Mobile preview `mobile-preview-ae0b65b85f6f`](https://github.com/austugal/lantern/releases/tag/mobile-preview-ae0b65b85f6f) was published 3 November 2026 at 14:45:49 UTC. The Android testing APK digest is `f5ad4e33d6cf93d9827db6001deca3ed0e44447389fc1ea4d33e056c5abb0b00`; iOS simulator and unsigned-device archives are attached. The matching [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-ae0b65b85f6f) contains Windows, Linux and macOS packages.

No physical phone, radio delivery, mixed Android-iPhone operation, background execution, production signing, independent security audit or independently verified work completion was established.

## 2 November 2026 — Android APK smoke startup repair

[PR #24](https://github.com/austugal/lantern/pull/24) validated head `f15459352a7ababc375376d2a3131e875e3b1757` and merged as `a59edf05c3bccb712775a8a7abc8f5b98e166f85`, with identical tree `51b643ce5aa39c1862d2691a093678ec055d085d`. The APK helper now requires a fresh emulator without Lantern installed, installs without replacement or permission grants, and checks the exact registered package before launch. It no longer clears app data immediately before startup. Existing installations and genuine install/launch/app failures still stop the gate.

[PR mobile validation](https://github.com/austugal/lantern/actions/runs/41462939265) passed formatting/analysis, **165 Flutter tests**, Android APK, iOS simulator and unsigned-device builds, **13 actual-APK navigation checks** and **two native fixtures**. The repaired emulator gate passed on its first attempt. [PR Python CI](https://github.com/austugal/lantern/actions/runs/41462940344) passed **126 tests** on Python 3.10/3.12/3.13, including eight startup regression cases; [PR desktop packages](https://github.com/austugal/lantern/actions/runs/41462939616) passed on Linux, Windows and macOS.

[Main mobile run 41466114554](https://github.com/austugal/lantern/actions/runs/41466114554) repeated all mobile gates successfully, including all 13 APK navigation checks and both native fixtures on the first attempt. [Main Python CI](https://github.com/austugal/lantern/actions/runs/41466114604) and [desktop packages](https://github.com/austugal/lantern/actions/runs/41466114536) also passed. [Mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-a59edf05c3bc), published 2 November at 15:12:06 UTC, and [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-a59edf05c3bc) both target `a59edf05c3bccb712775a8a7abc8f5b98e166f85`. The published Android APK's GitHub SHA-256 digest is `a7379adc261d28bfcf8a4f01cb95901518cc3d26cfaa34ac1e0a5ec2b9e30922`. At publication on 2 November, download links and the physical-baseline artifact example referred to this release.

Phone application code, radio behaviour, permissions and licence terms are unchanged. Physical phones/radios remain untested; the iPhone device archive still requires Apple signing and provisioning. See [the repair record](../../docs/DEVELOPMENT-2026-11-02.md).

## 1 November 2026 — MeshCore companion and ownership milestone

[PR #22](https://github.com/austugal/lantern/pull/22) merged validated head `14ca1561536fc91706911a9c272c41c7a05a3a35` as `d9538c0445a2a78063c2e42a5ba488da2c204e06`, with identical tree `e533edffb98a5a06968d32c6d100f6fc2a17cb58`. [PR mobile validation](https://github.com/austugal/lantern/actions/runs/41324733436) passed **165 Flutter tests**, formatting/analysis, Android APK, iOS simulator and unsigned device builds, **13 navigation checks on the actual APK** and **two native fixtures**. The new radio/ownership screens were opened without starting BLE discovery. [Python CI](https://github.com/austugal/lantern/actions/runs/41324733321) passed all **118 tests** on three Python versions; [desktop packaging](https://github.com/austugal/lantern/actions/runs/41324733365) passed Linux/Windows/macOS and executable checks.

[Main mobile run 41326475834](https://github.com/austugal/lantern/actions/runs/41326475834) passed 165 tests, both platform builds, 13 APK checks, two native fixtures and publication. The first emulator attempt failed before onboarding with the launcher visible and no app crash; a targeted retry passed without source or gate changes. [Published mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-d9538c0445a2), 1 November at 16:56:54 UTC, includes the Android testing APK, simulator and unsigned-device ZIPs, licence notices and checksums. The exact published APK digest is `23531cdee9a7ddeca69c92d96edd58831c515483218b1d344800632b09faa50b`. [Main Python CI](https://github.com/austugal/lantern/actions/runs/41326475941) and [desktop packages/publication](https://github.com/austugal/lantern/actions/runs/41326475869) passed; the [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-d9538c0445a2) is also available.

The mode is a bounded MeshCore channel-text client requiring external LoRa hardware. No physical BLE pairing, MTU/notification behaviour, real radio delivery/range/battery or real-iPhone operation was tested. Inbox consumption and unsupported message types are disclosed before reads. The licence change preserves prior MIT grants and third-party terms; no registration was verified or filed by this workflow. See [protocol/setup limits](MESHCORE.md), [development evidence](../../docs/DEVELOPMENT-MESHCORE-2026-11-01.md) and [unexecuted physical tests](DEVICE_TESTS.md).

## 1 November 2026 — physical baseline preparation tool

[Offline evidence tooling](../../docs/DEVICE-EVIDENCE.md) now prepares and validates human-reported two-Android-phone baseline records. It checks bounded JSON/schema, required observations and artifact fields against supplied expected hashes; it does not operate phones, verify installed binaries or prove that a test occurred. The full device checklist remains unexecuted. No Android/iPhone app code, SDK, permission, entitlement or background behavior changed.

[PR #20](https://github.com/austugal/lantern/pull/20) passed [Python CI 41314763843](https://github.com/austugal/lantern/actions/runs/41314763843): 118 tests across Python 3.10/3.12/3.13, including 27 new synthetic CLI cases. [Desktop packaging 41314763839](https://github.com/austugal/lantern/actions/runs/41314763839) passed all three platforms after the GitHub macOS 14 brownout was addressed by pinning macOS 15. [Main CI 41314937847](https://github.com/austugal/lantern/actions/runs/41314937847) repeated all 118 tests on three Python versions; [main desktop packaging 41314937712](https://github.com/austugal/lantern/actions/runs/41314937712) passed Linux/Windows/macOS 15 builds, executable checks and publication. Details are in [the development record](../../docs/DEVELOPMENT-2026-11-01.md). These are tooling checks, not new physical-device or Flutter execution. Existing mobile Android/iOS/emulator run 41068600810 remains green on the unchanged [30 October preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-b810cdf371a5); its 147 Flutter tests remain prior release evidence.


## 31 October 2026 — SDK evaluation only

Reviewed main `275d9801dd5a6b9c833faa51a4ef12da758ee321`, both native adapters, channel contract, current Google SDK documentation and upstream package/source. The [evaluation](NEARBY-SWIFT-EVALUATION-2026-10-31.md) and [adapter contract](NEARBY-ADAPTER-CONTRACT.md) distinguish documented APIs, inspected source, proposed mapping and unexecuted physical gates. No SDK was installed or compiled; no transport, app source, dependency, entitlement or permission changed.

Inspected existing mobile CI run [41068600810](https://github.com/austugal/lantern/actions/runs/41068600810), desktop CI [41068600774](https://github.com/austugal/lantern/actions/runs/41068600774) and packaging [41068601103](https://github.com/austugal/lantern/actions/runs/41068601103): all successful on release source `b810cdf371a52e92c3d3a5af2d964a526fcd17f9`. Its 147 Flutter tests, native builds, emulator checks and 91 desktop tests are previous release evidence, not new tests run for this evaluation. Markdown/link/scope checks and specialist review validate this documentation milestone. No new binary release is needed.

## 30 October 2026 — bounded attachment delivery status

Validated source adds a 30-second app-receipt deadline after complete attachment submission, honest uncertainty, late-receipt recovery, callback isolation and a four-call unresolved native attachment budget across reconnects. It retains the existing transport, packet format, foreground-only behaviour and explicit media/location/notification consent. No automatic resend or attachment retry is added.

Regression tests cover final-submission timing, missing/late/wrong-peer receipts, independent deadlines, early receipts racing native completion/error/timeout, native budget across reconnects, stale session results, teardown and trimming; a conversation widget test checks the visible unconfirmed status and absence of retry. Local Dart 3.9.2 formatting and full-repository Ruff lint/format passed. A read-only specialist review found no blocker.

[PR #17](https://github.com/austugal/lantern/pull/17) validated head `bc352f927a4f2fabf1aa51b450d4c0ba9650854e` in [mobile run 41066100434](https://github.com/austugal/lantern/actions/runs/41066100434) and [desktop CI 41066100401](https://github.com/austugal/lantern/actions/runs/41066100401), then merged as `b810cdf371a52e92c3d3a5af2d964a526fcd17f9`. The merge and validated head have the identical tree `5b7bb97139810d85ff9c05d94b9b3cb61144fafd`.

- Formatting, static analysis and **147 Flutter tests** passed, including **17 new cases**.
- Android APK, iOS simulator and unsigned iOS device builds passed.
- All **11 installed-APK navigation checks** and **both native integration fixtures** passed on Android API 35. The PR smoke result is true and all check exit codes are zero; no system launcher ANR recovery was needed.
- Desktop lint, formatting, strict typing and **91 tests** passed on Python 3.10, 3.12 and 3.13.

[Main mobile run 41068600810](https://github.com/austugal/lantern/actions/runs/41068600810) passed every gate again: clean analysis, all 147 tests, Android/iOS builds, all 11 installed-APK navigation checks, both native fixtures and publication. [Main desktop CI 41068600774](https://github.com/austugal/lantern/actions/runs/41068600774) and [desktop packaging 41068601103](https://github.com/austugal/lantern/actions/runs/41068601103) passed. [Desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-b810cdf371a5), published 30 October at 14:05:53 UTC, contains Linux, macOS and Windows packages. [Download the validated mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-b810cdf371a5), published **30 October 2026 at 14:19:52 UTC**: Android testing APK, iOS simulator ZIP, unsigned iOS device ZIP and SHA256SUMS.txt. All four assets are uploaded and target the validated merge commit. Previous releases remain available.

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
