# Development record — 28 October 2026

## Coordination and scope

Base inspected: `main` at `1e987d15220545ecb583dbad33c9d1c99ab326b1`. GitHub listed no open PRs or issues. The latest mobile, Android-emulator and desktop releases were successful, and the dated development records showed no overlapping active work. Legacy branches, including `finish/desktop-release`, were not modified.

The bounded milestone is explicit foreground reconnection recovery over the existing controller and user interface. It does not change Google Nearby Connections, Apple Multipeer Connectivity, permissions, native lifecycle code or desktop source. Primary SDK research was therefore not required for a transport change; Android–iPhone communication remains separate work.

## File ownership

- Controller specialist: `mobile/lib/src/controller.dart`.
- UI specialist: `mobile/lib/src/app.dart`.
- Regression-test specialist: `mobile/test/controller_test.dart` and `mobile/test/reconnect_widget_test.dart`.
- Reliability reviewer: read-only race, consent, privacy, lifecycle and accessibility review.
- Integrator: documentation, CI evidence, release verification and contributor attribution evidence.

## Acceptance boundary

- Background, unexpected native stop and peer connection loss produce an accurate visible reason.
- Nothing reconnects automatically. Restarting stopped discovery requires a user tap; connecting still requires fresh peer choice and confirmation.
- Messages, requests, sharing, guardian and check-in state remain cleared and are never queued by recovery.
- A failed explicit restart remains visible for retry or dismissal.
- Delayed failures from a prior native request, accept, reject, stop or disconnect cannot alter a newer session.
- No background operation, persistence, new transport, permission expansion or desktop behaviour is added.

## Validation

Local checks passed: Dart 3.9.2 formatting for the changed mobile files; clean diff checks; and the unchanged desktop suite with 91 tests, Ruff, formatting and strict mypy. A read-only specialist review found no remaining blocking session, consent, privacy or accessibility issue. The managed local Flutter bootstrap was stopped after automatic approval review rejected its attempted cloud metadata request, so executable Flutter validation used GitHub Actions.

[PR #11](https://github.com/austugal/lantern/pull/11) validated code source `39a99c457443c7018129d76ef889373b3ca89061`. [Mobile run 40697447557](https://github.com/austugal/lantern/actions/runs/40697447557) passed formatting, analysis, all 111 Flutter tests, Android and both iOS builds, and the actual-APK Android emulator gate. [Desktop CI 40697445599](https://github.com/austugal/lantern/actions/runs/40697445599) passed on Python 3.10, 3.12 and 3.13.

An earlier candidate run exposed a small-screen overflow at 320 pixels and 1.5× text scale. The app title and recovery copy were corrected before the successful run above. These automated checks do not establish physical-phone lifecycle behaviour, radio reliability, mixed Android/iPhone interoperability, battery use, production signing, background execution, independent security review or emergency-service contact.

## Contributor display evidence

On 28 October 2026, the live repository homepage still showed two contributors, `austugal` and `claude`, although the default branch, REST contributors endpoint and Insights contributor data showed only `austugal`. Fetching all public refs found two legacy Claude-authored commits still reachable from old branches and GitHub-managed pull-request head refs, while neither is reachable from `main` or current release tags. The exact support packet records both the clean default branch and those legacy refs; the sidebar entry is not claimed removed.
