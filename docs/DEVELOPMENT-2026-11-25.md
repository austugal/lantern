# Bounded rejected-endpoint policy — 25 November 2026

Inspected main `f73be8262559341aa095d6d0ad142809d06022b8`, README, roadmap, recent ownership records, PRs and CI. No open PR or conflicting Finish Flutter Repo ownership was found. The 24 November mobile and desktop releases passed all gates. Work is isolated on `feat/android-rejection-budget-20261125`.

## Component boundary

The [attempt-isolation contract](../mobile/docs/ANDROID-ATTEMPT-ISOLATION-2026-11-17.md) requires rejected endpoints never to be readmitted in the same generation. This standalone component stores at most 100 identifiers, never evicts them, and permanently closes all admissions when the 100th unique rejection is recorded. Duplicate rejections do not consume capacity. No reset operation exists; a future owner must create a new instance only for a new generation after explicit restart.

Identifiers are limited to 128 Java UTF-16 code units, a local defensive storage limit rather than a claimed SDK limit. Null, empty or oversized rejection identifiers close admission without being retained; invalid admission queries return false without changing state. This prevents unbounded retained identifier data. Methods synchronize individual operations; an admission query is not an atomic reservation. The future owner must serialize admission, endpoint actions and generation transitions.

[Google lifecycle callback documentation](https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/ConnectionLifecycleCallback), consulted on 25 November, exposes endpoint-based callbacks. This component makes no assumptions that stopping drains SDK callbacks. It is deliberately not wired into MainActivity: generation retirement, one-attempt ownership, event fencing, consent handling and denial/restart UI must be integrated together. Native transports, permissions and current foreground-only behavior are unchanged.

## Verification and ownership

The component specialist owns only the Java class; the test specialist owns only its JVM fixture. The primary agent owns workflow integration and documentation; the attribution specialist owns only temporary evidence. Local checks and native PR build outcomes are recorded separately. No physical-device, mixed-platform, background-delivery, signing or audit result is claimed.

The working [mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-60efb9a279a0) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-60efb9a279a0) previews and pinned physical-test baseline remain available. Support evidence is prepared and unsent.

Local verification passed **77 JVM assertions** (Java 21 compiler targeting Java 17, lint warnings treated as errors) and **136 Python tests**. The ledger fixture covers the 99/100/101 boundaries, duplicates, a 10,000-ID flood after closure, invalid and Unicode identifiers, fresh-instance isolation and eight concurrent writers. A temporary mutation that delayed closure until after 100 entries failed the capacity assertion. This is synthetic component verification, not SDK integration testing. An independent component/workflow review found no blocker. All 112 relative documentation links resolve and whitespace checks pass. CI runs the new fixture with actual JDK 17 before building the Android APK; Android/emulator, Flutter and iOS PR results remain separate gates.

The 25 November attribution snapshot still shows Claude in the signed-out sidebar despite 105 austugal-only commits and an austugal-only API response. Exact timestamps are retained in the [unsent Support evidence](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md).
