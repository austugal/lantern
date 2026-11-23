# Android transfer-error ownership — 22 November 2026

Inspected main `294bf337a8b9f99ace303fbaef75ed76e16fe5bb`, README, roadmap, active records, open PRs and CI. No open PR or fresh conflicting Finish Flutter Repo ownership was found. Work is isolated on `fix/android-transfer-error-ownership-20261122`.

## Release baseline

The latest runtime `008645ebcb65aa29dd86349045450234b2a033d7` passed [mobile](https://github.com/austugal/lantern/actions/runs/44911277672), [desktop](https://github.com/austugal/lantern/actions/runs/44911277691) and [Python](https://github.com/austugal/lantern/actions/runs/44911277682) CI. The [mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-008645ebcb65) published on 21 November at 14:13:26 UTC, and the [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-008645ebcb65) at 13:57:25 UTC. No failed release needs repair. The pinned 6 November physical baseline remains unchanged.

## Bounded change

MainActivity previously emitted a generic payload-transfer failure when only discovery generation matched. Flutter accepts generic error events before its endpoint check, so an unrelated endpoint could overwrite the visible error. A shared ownsPayload predicate now requires a running session, current generation and non-null matching connected endpoint before data admission or a FAILURE notice. The data predicate is equivalent to the existing Kotlin guard for its non-null endpoint. Other transfer statuses still emit no generic failure. Current-peer failures remain visible; no endpoint rejection, disconnect or state mutation is introduced.

[Google PayloadCallback documentation](https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/PayloadCallback), consulted on 22 November, identifies transfer updates by sending/receiving endpoint and covers incoming and outgoing transfers. This supports endpoint ownership checks but does not prove a physical delayed-callback sequence. SDK versions and transport adapters are unchanged.

## Verification and ownership

The primary agent owns the helper, MainActivity and docs. A specialist owns only the JVM regression fixture, a read-only reviewer checked native and Flutter handling, and an attribution specialist owns only a temporary evidence appendix. All **136 Python tests passed**. **124 JVM callback checks passed** (110 retained, 14 added). A temporary helper using the old epoch-only transfer policy fails at `late transfer failure emitted after disconnect`; this is a policy-mutation comparison, not compilation of the original helper, which lacked ownsPayload. Java 17 source/target compilation on OpenJDK 21 treated warnings as errors. Android APK/emulator, Flutter and both iOS builds remain separate PR gates.

The reviewer found no blocker for this narrow change. Same-peer reconnection within one generation can still alias callbacks. Events accepted before a later ownership change are not fenced at Flutter delivery; payload IDs are not correlated to individual messages here. Generic lifecycle errors intentionally emitted after pending clears are untouched. Send method failures, receipt deadlines, consent, resource bounds and foreground-only behavior remain unchanged. No physical, mixed-platform, background, signing or audit claim is added.
