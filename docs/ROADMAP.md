# Roadmap and ideas

## Built

0.1: identity, cards, safety numbers, grants, ledger, signed encrypted envelopes, two-sided
enforcement, coarsening, audit log, radio simulator, CLI demo, CI.

0.2:
- Opt-in mesh relaying with TTL and loop suppression (the route to 1000 m and beyond)
- Per-frame ephemeral keys (sender-side forward secrecy)
- SOS guardians: pre-consented emergency scope, exact position, only to people you named
- Safe walk: dead-man timer that raises the SOS if you do not check in
- Drift alerts that account for fix imprecision (no false alarms from coarse positions)
- Offline navigation with no maps: bearing and distance to a peer, breadcrumb backtrack,
  named waypoints, dead reckoning when GPS drops
- Disappearing messages
- Encrypted vault for identity, peers and consent state, with wipe
- Radio profiles and a hop calculator

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
9. Persistent revoke queue so revocations reach peers who were out of range.
10. QR pairing payload and a verified safety number screen.
11. External security review before any public release.

## Landscape (checked 2026-10-16, secondary sources)

- BLE mesh hops are about 100 m. Briar's local links are about 10 to 100 m.
- Meshtastic (LoRa) reaches about 2 to 15 km per hop with line of sight, hop limit 7.
- Bitchat 1.6 and 1.7 added store-and-forward direct messages, push-to-talk, courier drops
  and signed voice bursts.
- Sources: d-central.tech mesh protocol comparison, a dev.to write-up of Bitchat 1.6 and 1.7.
- I did not find an offline messenger that combines pre-consented SOS scope, a dead-man
  timer, precision-aware drift alerts and signed expiring grants. That is a thin-search
  observation, not proof that none exists.
