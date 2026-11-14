# Android invitation ownership — 12 November 2026

## Baseline and ownership

Inspected current main `0b73e672202f56eb065d9ee49f70c629cd115f4c`, README, roadmap, active development records, open PRs and CI. There were no open PRs or competing source changes identified in Finish Flutter Repo. Main Android/emulator, iOS simulator/unsigned-device, Python and desktop checks passed; the prior dependency-download failure is resolved. The published [mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-0b73e672202f) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-0b73e672202f) previews remain available.

Work is isolated on `fix/android-invitation-ownership-20261112`. Implementation and documentation are owned by the primary agent; the regression specialist owns only `mobile/tool/ConnectionCallbackGateCheck.java`; attribution review is read-only.

## Bounded reliability change

The outbound request failure previously cleared pending state whenever its discovery generation matched. Cancel/retry can create a new invitation without restarting discovery, including reusing the same endpoint. A delayed failure from the old request could therefore erase the new invitation.

Capture the existing invitation generation alongside the discovery generation, then clear pending state only when both tokens, endpoint and running state still match. Reuse that predicate for the existing invitation timeout. A request failure still completes its original Flutter method result. Initiation refreshes invitation generation, so a failure belonging to the previous request phase cannot erase the consent-phase invitation. No timeout, transport, SDK, permission or consent change is introduced.

Primary documentation reviewed: [Google Nearby connection management](https://developers.google.com/nearby/connections/android/manage-connections), 12 November 2026. This establishes API semantics, not real-device callback ordering.

## Verification and limits

- 33 JVM callback checks passed, including 14 new same-peer retry, other-peer, restarted-session, stopped-session and missing-endpoint checks. Compiled with warnings as errors using Java 17 source/target on OpenJDK 21; CI uses JDK 17.
- All 136 Python tests passed.
- Android APK/emulator, Flutter and iOS checks remain required PR gates; local results do not imply those builds passed.
- No new physical-device, production-signing, security-audit, background-execution or Android–iPhone interoperability result. The physical baseline stays pinned to the 6 November APK.

Read-only review confirmed Dart request errors are guarded by its operation epoch and invitation/connection state. One pre-existing limitation remains: connection-result/disconnect lifecycle callbacks capture the discovery generation rather than a per-attempt token, so late same-peer lifecycle callbacks within one discovery session need a separate design and regression milestone. This fix isolates request failures and invitation timeouts only.

The contributor API and main authorship show only austugal, but the rendered owner-view sidebar still shows Claude. The dated [Support evidence](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md) is prepared and unsent; no removed-contributor claim is made.
