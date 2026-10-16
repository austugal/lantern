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
2. **Android–iPhone communication:** evaluate Google's cross-platform Nearby Swift SDK against the existing Android adapter, including matching verification codes and consent on both phones. Preserve the working release until builds and physical mixed-phone tests pass.
3. **Background behaviour:** design a user-started Android foreground session with a visible Stop control. Treat iOS suspension separately; do not advertise continuous offline background delivery without evidence. Online push would require a separate service and connectivity.
4. **Workplace reliability:** explicit retry/reconnection, job acknowledgement, group/channel design, delivery failure handling and battery testing. A receipt is not task acceptance.
5. **Release readiness:** stable signing, reproducible dependency locking, Apple provisioning, store/privacy declarations, accessibility checks and independent security review.
6. **Optional assistant:** keep bundled offline guidance; evaluate local or online AI separately with explicit data boundaries, costs and controls. No AI model or telephone service is currently active.

Development coordination: inspect current PRs and CI before starting a milestone; assign separate file ownership to collaborating agents. Never duplicate an active workstream. Publish only the exact validated source, update the evidence and keep capability limits visible. Scheduled continuation advances a bounded milestone per run; it does not imply uninterrupted background execution.

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
7. LoRa bridge transport (Meshtastic-class hardware) for 2 to 15 km hops.
8. Full ratchet for forward secrecy on both sides.
9. Reliable message retransmission and reconnect negotiation.
10. QR invitation exchange (text invitations and safety-number screen are implemented).
11. External security review before a production release.
