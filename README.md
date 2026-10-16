# Lantern

Consent-first offline nearby messaging and location sharing for people together in person.

Lantern is the core library: identity, consent, encryption, the wire protocol and a
radio simulator. It has no network, cloud or account. Two devices that have met in
person can message and share location over any short-range link, and nothing happens
unless the other person has said yes, for a limited time, and can say no at any moment.

## Rules the code enforces

1. Pairing is in person. You exchange signed cards (QR, tap, NFC). Unpaired frames are dropped.
2. Every action needs a live grant. A message needs the recipient's `MESSAGE` grant.
   A location share needs your own `LOCATION` grant to that person.
3. Grants always expire. Location grants cap at 24 hours, message grants at 30 days.
4. Precision is a grant property. Your device snaps your position to a grid (minimum 10 m)
   before it leaves the device. The receiver rejects anything finer than the grant.
5. Revocation is immediate on both sides. The viewer discards your last known position.
6. Both ends enforce. A sender that skips its own checks is still refused by the receiver.
7. Panic button: `revoke_all()` revokes everything you have issued and notifies peers.
8. Hostile input never raises. Bad frames are rejected and written to the audit log.
9. Emergencies are pre-consented. SOS only reaches guardians you named in advance.
10. Relaying is opt-in. Relays carry ciphertext they cannot read.

## Features

- Range: one BLE hop is about 100 m. Opt-in relays chain hops, so about ten reach 1000 m
  (`hops_needed(100, 1000) == 10`). A LoRa transport would cover kilometres per hop.
  Radio physics sets the limit, not the code.
- SOS guardians and a safe-walk dead-man timer
- Offline navigation with no maps: bearing and distance to a peer, breadcrumb backtrack,
  waypoints, dead reckoning
- Drift alerts for groups that never fire on coarse fixes
- Disappearing messages
- Encrypted vault with wipe

## Quick start

```bash
pip install -e ".[dev]"
python -m lantern demo
pytest
```

```python
from lantern import Identity, LanternNode, LoopbackHub, Scope

hub = LoopbackHub(range_m=30)
ida, idb = Identity("alice"), Identity("bob")
alice = LanternNode(ida, hub.endpoint(ida.fp, 0, 0))
bob = LanternNode(idb, hub.endpoint(idb.fp, 5, 0))

alice.add_peer(bob.card())  # in-person card exchange
bob.add_peer(alice.card())

bob.grant(alice.fp, Scope.MESSAGE)  # bob lets alice message him
alice.send_message(bob.fp, "hi")  # without the grant this raises ConsentError

alice.grant(bob.fp, Scope.LOCATION, ttl_s=900, precision_m=100)
alice.share_location(bob.fp, 38.7223, -9.1393)
alice.revoke_all()  # bob's copy of your position is gone
```

## Layout

| Path | Purpose |
| --- | --- |
| `src/lantern/identity.py` | Ed25519 and X25519 keys, signed cards, safety numbers |
| `src/lantern/consent.py` | Signed, expiring, revocable grants and the ledger |
| `src/lantern/node.py` | Enforcement point, encrypted signed envelopes, audit log |
| `src/lantern/location.py` | Coarsening and distance |
| `src/lantern/transport.py` | `Transport` protocol and range-limited `LoopbackHub` |
| `src/lantern/geo.py` | Bearing, distance, trail backtrack, waypoints, dead reckoning |
| `src/lantern/safety.py` | SOS alerts, safe walk, drift detection |
| `src/lantern/vault.py` | Encrypted persistence and wipe |
| `docs/PROTOCOL.md` | Wire format |
| `docs/THREAT_MODEL.md` | What this does and does not protect |
| `docs/ROADMAP.md` | What is not built yet |

## Status

Version 0.2. The protocol core is complete and tested. There is no real radio
transport and no mobile app yet. See `docs/ROADMAP.md`. The design has
had no external security review. Do not rely on it for safety critical use.
