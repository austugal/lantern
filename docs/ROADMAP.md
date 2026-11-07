# Roadmap and ideas

## Desktop core and simulator foundations

These entries describe the original Python core. They do not establish mobile hardware capabilities or measured radio range.

0.1: identity, cards, safety numbers, grants, ledger, signed encrypted envelopes, two-sided
enforcement, coarsening, audit log, radio simulator, CLI demo, CI.

0.2:
- Opt-in mesh relaying with TTL and loop suppression in the radio simulator
- Per-frame ephemeral keys (partial forward secrecy; no double ratchet)
- SOS guardians: pre-consented emergency scope, reported position, only to people you named
- Safe walk: dead-man timer that raises the SOS if you do not check in
- Drift alerts that account for fix imprecision (no false alarms from coarse positions)
- Offline navigation with no maps: bearing and distance to a peer, breadcrumb backtrack,
  named waypoints, dead reckoning when GPS drops
- Disappearing messages
- Encrypted vault for identity, peers and consent state, with wipe
- Radio profiles and a hop calculator

## 0.3 desktop preview

- Real UDP transport between explicitly paired LAN endpoints.
- Local browser interface, signed invitations and safety-number confirmation.
- Encrypted app receipts for messages, alerts and revocations.
- Persistent revocation retry queue while the peer remains paired.
- Foreground location sharing, fresh-fix checks and expiry cleanup.
- Encrypted profile, source launchers and desktop packaging workflow.

BLE and LoRa ranges are not validated by this project. The mesh range test is a
simulation only; desktop UDP does not provide hardware mesh discovery or routing.

## Mobile delivery priorities

Lantern is still a developer preview. A successful release is a milestone, not completion of the product.

The mobile media/maps milestone adds photo and voice attachments, emoji entry, optional generic notifications, torch/SOS, online maps, saved basic offline areas and explicit Find me help messages. Validation evidence belongs in [mobile verification](../mobile/docs/VERIFICATION.md); real-device gates remain separate.

1. **Physical-device reliability:** run the documented two-phone permission, lifecycle, attachment, map, torch and range checks. Record models, OS versions and observed results.
2. **Android–iPhone communication:** resolve the documented Nearby Swift dependency and locking gates, then implement and build the shared adapter before physical mixed-phone acceptance testing. Preserve the working release until every gate passes.
3. **Background behaviour:** implement the completed Android foreground-session contract with explicit opt-in and visible Stop controls, then pass emulator and physical two-Android-phone gates. Treat iOS suspension separately; do not advertise continuous offline background delivery without evidence. Online push would require a separate service and connectivity.
4. **Workplace reliability:** request cancellation or handover, group/channel design, delivery-failure recovery and battery testing. A receipt is not task acceptance or independently verified completion.
5. **Release readiness:** stable signing, reproducible dependency locking, Apple provisioning, store/privacy declarations, accessibility checks and independent security review.
6. **Optional assistant:** keep bundled offline guidance; evaluate local or online AI separately with explicit data boundaries, costs and controls. No AI model or telephone service is currently active.

Development coordination: inspect current PRs and CI before starting a milestone; assign separate file ownership to collaborating agents. Never duplicate an active workstream. Publish only the exact validated source, update the evidence and keep capability limits visible. Scheduled continuation advances a bounded milestone per run; it does not imply uninterrupted background execution.

### 26 October 2026: bounded text retry

Released and validated: 10-second submission and 30-second receipt deadlines, explicit same-session ordinary-text retry with three submissions total, stable IDs, a bounded accepted-text ledger and late-callback guards. Disappearing messages and media remain outside retry. No automatic reconnection, new transport, background operation or human job acceptance was added. See [verification](../mobile/docs/VERIFICATION.md) and [development record](DEVELOPMENT-2026-10-26.md). Physical reliability and mixed Android/iPhone communication remain open priorities.

### 27 October 2026: bounded work-request acknowledgement

Released and validated: a sender can mark an ordinary, non-expiring text as requiring a response. The connected recipient can accept or decline once; the linked response uses the existing bounded text delivery, receipt and retry path. Unknown, late and conflicting responses are rejected without a false receipt. This is current-session acknowledgement only, not job completion, assignment, escalation or dispatch. Native transports, permissions and background behaviour remain unchanged. See [mobile verification](../mobile/docs/VERIFICATION.md) and [development record](DEVELOPMENT-2026-10-27.md).

### 28 October 2026: explicit foreground reconnection recovery

Validated source now distinguishes background interruption, unexpected native shutdown and peer connection loss. A visible notice says that nothing was queued, routes the user to Nearby and requires an explicit restart when discovery stopped. The user must choose and confirm a peer again; messages, requests, location sharing, guardian state and check-ins remain cleared. Delayed failures from an earlier native request or consent action cannot alter a newer session. This adds no automatic reconnect, persistence, transport change or background execution. See [mobile verification](../mobile/docs/VERIFICATION.md) and [development record](DEVELOPMENT-2026-10-28.md).

### Field instruments: compass and offline calculations

Released and validated: an explicit local magnetic compass, arithmetic calculator, length/area/volume conversions and rectangle/box calculations from entered dimensions. Existing GPS position and true-north point bearings remain separate and opt-in. Sensor accuracy, real-device orientation and interference testing remain pending; no camera ranging or calibrated screen ruler is claimed. Build and test status is recorded in [mobile verification](../mobile/docs/VERIFICATION.md).

### 29 October 2026: PR formatting gate

The release-readiness milestone adds `ruff format --check .` to PR CI before typing and tests, so the Python formatting failure previously found only during desktop packaging is checked before merge. Application source, transports, permissions and background behaviour are unchanged. The validated field-instruments release is preserved. See [development record](DEVELOPMENT-2026-10-29.md).

### 30 October 2026: bounded attachment delivery status

Merged through [PR #17](https://github.com/austugal/lantern/pull/17), this milestone extends workplace delivery-failure handling to photos and voice notes: a 30-second app-receipt deadline after complete submission, visible uncertainty, late-receipt recovery, old-session callback guards and a four-call unresolved-native budget retained across reconnects. No attachment retry, protocol/transport change, new permission or background capability is added. PR formatting, analysis, 147 Flutter tests, Android/iOS builds, 11 APK navigation checks, both native fixtures and desktop CI passed. Main repeated all gates and published [mobile-preview-b810cdf371a5](https://github.com/austugal/lantern/releases/tag/mobile-preview-b810cdf371a5) on 30 October; the previous release remains available. See [development record](DEVELOPMENT-2026-10-30.md) and [verification](../mobile/docs/VERIFICATION.md).

### 31 October 2026: cross-platform SDK feasibility evaluation

Completed a source-backed comparison of Nearby Swift against the current Android/iPhone adapters, with an [SDK evaluation](../mobile/docs/NEARBY-SWIFT-EVALUATION-2026-10-31.md) and [method/consent mapping and physical acceptance matrix](../mobile/docs/NEARBY-ADAPTER-CONTRACT.md). Upstream radio-medium documentation disagrees and transitive dependency locking remains a gate. This completes the evaluation slice of priority 2, not Android–iPhone implementation or hardware validation. The 30 October release remains unchanged. Physical same-platform baseline testing remains the first hardware priority.

### 1 November 2026: physical baseline evidence tooling

An offline [record validator](DEVICE-EVIDENCE.md) prepares and checks a bounded two-Android-phone communication/lifecycle baseline. It distinguishes incomplete, failed and malformed records, compares artifact fields with supplied expected values and labels success as human-reported, not independently verified. This is preparation for priority 1, not completed physical testing or a release approval. No mobile transport, permission or app behavior changes. The current mobile preview is preserved. Validation results are recorded in [the development record](DEVELOPMENT-2026-11-01.md).

## Longer-term ideas

1. Consent receipts. A signed log, readable by you, of every grant given, used and revoked,
   so you can see exactly who saw where you were, and when.
2. Proximity-gated reveal. Positions are only revealed once both people are within a set
   distance, so a rendezvous works without either side exposing a trail beforehand.
3. Duress passphrase. A second passphrase opens a decoy vault and silently triggers the SOS.
4. Store-and-forward carry. Devices hold frames for absent peers and hand them over on
   contact (spray-and-wait), so messages cross gaps with no live path.
5. Battery-aware relaying. A relay budget that stops forwarding below a charge level, and
   prefers plugged-in devices.
6. Push-to-talk voice bursts, signed per sender.
7. External LoRa radio support: the MeshCore companion preview adds short channel text via BLE. Physical radio testing, direct-message support and broader integration remain open; no hop range is claimed.
8. Full ratchet for forward secrecy on both sides.
9. Reliable message retransmission and reconnect negotiation.
10. QR invitation exchange (text invitations and safety-number screen are implemented).
11. External security review before a production release.

### 1 November 2026: MeshCore companion and ownership changes

Released through [PR #22](https://github.com/austugal/lantern/pull/22): optional MeshCore BLE companion channel text and explicit inbox reads, plus proprietary terms for new original work and preserved legacy/third-party licences. 165 Flutter tests, Android/iOS builds, 13 installed-APK checks, both native fixtures and all desktop gates passed. [Setup and hardware gates](../mobile/docs/MESHCORE.md) and [release evidence](DEVELOPMENT-MESHCORE-2026-11-01.md) distinguish software validation from physical-radio testing, which remains unexecuted.

### 2 November 2026: Android APK startup reliability

[PR #24](https://github.com/austugal/lantern/pull/24) removes the test-helper data-clear/launch race behind the earlier failure email. A fresh install and exact package check replace data clearing; all 13 APK navigation gates and genuine-failure checks remain. Eight regression cases bring Python coverage to 126 tests, with the existing 165 Flutter tests and native/desktop checks passing. This is test infrastructure, with no phone application, permission or radio change. See [the development record](DEVELOPMENT-2026-11-02.md).

### 3 November 2026: bounded work-request completion status

Released through [PR #26](https://github.com/austugal/lantern/pull/26): a current foreground request can move from Accept/Decline to one final Completed/Unable status after a delivered acceptance. Every linked status uses the existing receipt, explicit retry and resource limits; invalid or out-of-order transitions receive no false acknowledgement. Statuses remain human-reported taps, clear with the session and do not prove task completion or supervisor approval. The full Flutter, Android, iOS, installed-APK, native-fixture and desktop gates passed, and matching [mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-ae0b65b85f6f) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-ae0b65b85f6f) previews were published. No persistence, transport, permission, group, signing or background capability was added. See [the development record](DEVELOPMENT-WORK-STATUS-2026-11-03.md).

### 3 November 2026: Android foreground-session design gate

The [Android foreground-session contract](../mobile/docs/ANDROID-FOREGROUND-SESSION-CONTRACT-2026-11-03.md) defines the smallest safe implementation slice before native work begins: explicit opt-in after one-peer verification, a private persistent notification and two Stop controls, `connectedDevice` service ownership, a 30-minute maximum, volatile buffering capped at 32 payloads and 256 KiB, and no application receipt before Dart validation. Location, media, check-ins, compass and torch still stop on background; iPhone remains foreground-only. This completes the design gate only. No service, permission, transport, runtime behaviour or background-delivery claim was added, and physical-device testing remains pending.

### 4 November 2026: downloaded APK integrity for physical-test records

The [offline baseline validator](DEVICE-EVIDENCE.md) can now hash a supplied downloaded APK before accepting a record. Chunked reads, a 512 MiB limit and mismatch rejection bind the local artifact to the independently supplied expected digest. This advances preparation for the physical reliability priority; it does not establish installation, signing, security or physical test results. Mobile transports and platform lifecycle behaviour are unchanged.

### 5 November 2026: Android session inbox

Implemented the [foreground-session contract's](../mobile/docs/ANDROID-FOREGROUND-SESSION-CONTRACT-2026-11-03.md) volatile inbox as a standalone Android component. It accepts bytes for one endpoint and one session generation, with limits of 32 payloads and 256 KiB total. A mismatch or overflow closes the inbox and drops its queued data. The operation does not issue a receipt. Service ownership, explicit opt-in, notification and Stop controls, lifecycle integration and two-phone validation are still pending. Neither mobile transport changed.

### 6 November 2026: Android inbox lifetime

The inbox now checks a fixed 30-minute lifetime before accepting or returning bytes, and when its owner checks whether it is closed. Traffic does not renew it. The Android clock counts time asleep. Expiry clears queued packets at the next access; an idle inbox does not wake the phone or stop a service. A service owner must still enforce expiry while idle, disconnect the peer and remove the notification. See the [verification record](../mobile/docs/VERIFICATION.md). The current phone app remains foreground-only.

### 7 November 2026: validated expiry and physical-baseline handoff

PR #31 completed the inbox expiry component after Android, iOS, Flutter and Python validation. Download links and the physical-baseline instructions now pin the fully published 6 November inbox-capacity build and its checked APK digest. That baseline predates expiry; it remains deliberately stable for hardware testing. This is a software-validation milestone, not a physical baseline pass. Service ownership and idle timeout enforcement remain required before background sessions. See [verification](../mobile/docs/VERIFICATION.md).
