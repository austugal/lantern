# Main release validation recovery — 24 November 2026

## Scope and ownership

Inspected main `f5f5dcddbc2b19d9ffbc70e4a520c8d30077c569`, README, roadmap, recent work records, open PRs and CI. No open PR or fresh conflicting Finish Flutter Repo ownership was retrieved. The reported earlier error email concerned an Android emulator-image download failure that had already recovered; this run found a separate main-release blocker. Release readiness takes priority over new runtime work.

Work is isolated on `fix/release-validation-20261124`. The primary agent owns documentation and release-recovery checks; the attribution specialist owns only a temporary evidence appendix and read-only GitHub observations. No runtime, dependency, workflow, permission, consent or resource-bound changes are needed for the observed failure.

## Failure diagnosis

Both main workflows target the validated PR #46 merge, `60efb9a279a0984b85281d52f57a990c7fa34c36`. [Mobile attempt 1](https://github.com/austugal/lantern/actions/runs/45181646746/attempts/1) passed Flutter checks, Android compilation and installed-APK emulator tests but cancelled iOS job `137716656800`. [Desktop attempt 1](https://github.com/austugal/lantern/actions/runs/45181646552/attempts/1) passed Windows and Linux builds but cancelled macOS job `137716655047`. Publication correctly stayed skipped in both workflows.

The [iOS annotations](https://api.github.com/repos/austugal/lantern/check-runs/137716656800/annotations), response dated 13:41:55 UTC, and [desktop macOS annotations](https://api.github.com/repos/austugal/lantern/check-runs/137716655047/annotations), response dated 13:42:00 UTC, both report that a hosted runner was not acquired after multiple attempts. Each also contains three notices about macOS arm64 capacity constraints. Neither cancelled job ran build steps. This is runner acquisition failure, not evidence of a compiler or test failure. The iOS log endpoint returned BlobNotFound; annotations provide the diagnosis.

Only the two cancelled jobs were retried on unchanged source. Their downstream publication jobs remain subject to all existing gates. Successful Android/emulator, Flutter, Windows, Linux and Python results are retained rather than needlessly rerun. No source workaround, runner-label change or weaker validation was introduced.

## Verification and release status

Main logs confirm **168 Flutter tests**, **124 JVM callback checks**, **33 strict packet-decoder checks** and the bounded session-inbox fixture passed. The Android emulator log records all **13 installed-APK scenarios** and **two native integration fixtures** passing. [Python CI](https://github.com/austugal/lantern/actions/runs/45181646608) passed on Python 3.10, 3.12 and 3.13; the 3.12 log confirms **136 passing tests**, lint and strict typing. These are automated checks, not physical nearby-radio tests.

[Mobile attempt 2](https://github.com/austugal/lantern/actions/runs/45181646746/attempts/2) and [desktop attempt 2](https://github.com/austugal/lantern/actions/runs/45181646552/attempts/2) passed all required jobs and publication on 24 November. The retried iOS job `138487346185` compiled both the simulator and unsigned device app with Xcode 16.4 / Swift 6.1.2. The retried macOS desktop job `138487558658` passed 136 tests, lint, strict typing, packaging and the executable demo. Windows and Linux builds had already passed.

The [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-60efb9a279a0) published at **13:44:21 UTC** and [mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-60efb9a279a0) at **13:50:54 UTC**, both targeting the unchanged merge commit. Mobile assets include the Android testing APK, simulator app, unsigned iPhone device app and checksums. GitHub reports the APK as **158,293,744 bytes** with SHA-256 `f1d61210eeef39b61e5ae0fc49fb3ea6ebb073d572a8c8d98e2bcf4d6b0a349a`; this is release API metadata, not an independently downloaded/hash-checked artifact in this run.

The prior working previews remain available. The 6 November physical-test baseline, its APK hash and download links remain unchanged.

An independent read-only specialist review found no factual blocker in the failure diagnosis or attribution snapshot. Documentation validation checks relative links, whitespace and an unchanged runtime/test/dependency/workflow diff against the released commit. The README now gives a shorter current-capability summary and directs build history to verification. This documentation-only PR uses `[skip ci]`; it changes no released code and does not bypass the native release gates that passed above. Same-peer attempt identity, native-to-Flutter event fencing, physical-device reliability, mixed Android/iPhone operation, production signing and background delivery remain open. No independent security audit or emergency-service contact is claimed.

## Attribution

The 24 November pre-change snapshot still has **104 austugal-authored commits** and only austugal in the contributors API, while the signed-out public sidebar lists both austugal and Claude. The exact timestamps, main SHA and Support request are in the [evidence packet](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md). It remains prepared and unsent; the visible discrepancy has not been removed.
