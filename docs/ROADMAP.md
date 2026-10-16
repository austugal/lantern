# Roadmap and ideas

## Built

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

## Ideas not built yet

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
