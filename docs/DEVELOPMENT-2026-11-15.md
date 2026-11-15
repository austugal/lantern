# Native disconnect ownership — 15 November 2026

Inspected main `256856940167481a131ff95bcc096390bd6eb52b`, README, roadmap, development records, open PRs and CI. No open PR or newly active competing Finish Flutter Repo source work was found. Main mobile run 43598540201, desktop run 43598540222 and Python run 43598540197 passed. Published [mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-97b11baacd4d) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-97b11baacd4d) previews remain available. The physical baseline stays pinned to the earlier 6 November APK.

## Bounded change

The Android onDisconnected callback checked discovery generation but emitted an event even without ownership of the endpoint. Flutter already rejects unrelated endpoint events. Add the same ownership boundary before native cleanup/emission: current generation, running session, non-null endpoint matching pending or connected. A real current-peer disconnect still clears its matching state and emits once; a duplicate after cleanup emits nothing. No SDK, transport, permissions, consent flow or resource limit changes.

Primary [Google ConnectionLifecycleCallback documentation](https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/ConnectionLifecycleCallback) checked 15 November identifies the disconnected endpoint but supplies no attempt identifier. Therefore this patch does not claim to distinguish late same-peer callbacks from a newer attempt within one discovery generation. That separate design remains pending.

Implementation and docs are owned by the primary agent on isolated branch `fix/android-disconnect-ownership-20261115`; the test specialist owns only ConnectionCallbackGateCheck.java; attribution review is read-only. Synthetic JVM checks cover state cleanup and event counts for valid disconnects, unrelated peers, duplicates, stopped/old sessions and missing endpoints. Native Android/iOS CI remains required before merge. No new physical-phone, production-signing, background, security-audit or mixed-platform validation occurred.

Local verification: **53 JVM callback checks** (33 retained and 20 new) passed with Java 17 source/target on OpenJDK 21 and warnings treated as errors. **136 Python tests passed**. Native Android/iOS builds remain PR gates; these local checks do not establish physical callback ordering.
