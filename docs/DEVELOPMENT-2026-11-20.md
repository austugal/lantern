# Established-peer initiation guard — 20 November 2026

Inspected main `b490f9b3d19fcfa60ed9a1b8529377042cb99603`, README, roadmap, current work records, open PRs and CI. No open PR or fresh competing ownership for this callback slice was found; Finish Flutter Repo context describes earlier work rather than a current overlapping change. Isolated branch: `fix/android-connected-initiation-20261120`.

## Preserved release

Main runtime `8be0e3ec3bea4fb3b670ac2c4b9e05aa3e0a52ab` passed [mobile CI](https://github.com/austugal/lantern/actions/runs/44532773346), [desktop CI](https://github.com/austugal/lantern/actions/runs/44532772774) and [Python CI](https://github.com/austugal/lantern/actions/runs/44532772645). The [mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-8be0e3ec3bea) published on 19 November at 13:38:46 UTC; the [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-8be0e3ec3bea) published at 13:23:53 UTC. No failing release needs repair. The pinned 6 November physical-test baseline stays unchanged.

## Bounded implementation

A repeated initiation for an established Android peer previously returned REJECT, invoking rejectConnection on that endpoint. The gate now returns IGNORE for the running, current-generation connected owner before rejection or consent side effects. It does not accept a new connection, replace a peer name/code, renew the invitation timer or emit another invitation. Other endpoints still reject while connected; normal pending initiation still proceeds.

[Google lifecycle documentation](https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/ConnectionLifecycleCallback) was consulted on 20 November for initiation, endpoint identity and acceptance semantics. The defensive regression injects repeated callbacks; it does not establish that physical devices exhibit this sequence. Transport and SDK versions are unchanged.

The primary agent owns the policy and documentation. A test specialist owns only the JVM fixture; a separate reviewer checks policy and MainActivity read-only. An attribution specialist owns a temporary evidence appendix only, with no outreach.

## Verification and remaining gates

**110 JVM callback checks passed** (87 retained, 23 added), including a baseline-negative regression: the old helper fails because it rejects the established owner. The fixed helper preserves endpoint ownership, pending state, name, emitted consent code and timer/event counters. Existing pending, unrelated, stopped and old-generation rules remain covered. Local compilation uses OpenJDK 21 with Java 17 source/target and warnings treated as errors; Android CI uses JDK 17 with --release 17. All **136 Python tests passed**. Native Android/emulator, Flutter and both iOS builds remain separate PR gates.

This is only the established-connection initiation rule. Duplicate pending initiation, registration collisions, same-peer retries, discovery retirement and native/Flutter generation fencing remain open. Consent, location/media/notification permissions, bounded resources and foreground-only behavior are unchanged. No new physical-device, background, mixed-platform, signing or audit claim is made.

Read-only review found no blocking issue for this slice. The guard identifies an established endpoint, not an SDK attempt; a genuine concurrent same-endpoint attempt cannot be distinguished. Registration collision handling remains deferred to the coordinated contract.
