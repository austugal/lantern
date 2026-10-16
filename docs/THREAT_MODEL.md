# Threat model

## Protected

| Threat | Mitigation |
| --- | --- |
| Stranger messages or tracks you | Unpaired frames dropped, every action needs a live grant |
| Over-sharing precision | Sender-side coarsening plus receiver-side rejection |
| Forgotten sharing | Mandatory expiry, 24 hour location cap |
| Changing your mind | Revocation, panic button, unpairing |
| Forged or altered frames | Ed25519 signature over the full envelope |
| Eavesdropping on content | ChaCha20-Poly1305, per-frame key from static and ephemeral X25519 |
| Sender device compromised later | Ephemeral keys are discarded, so already sent frames stay sealed |
| Phone seized or lost | Vault: scrypt plus ChaCha20-Poly1305, 0600 file, wipe on demand |
| Silent emergency broadcast to strangers | SOS only reaches guardians who hold a live SOS grant from you |
| Relays reading traffic | Relays carry ciphertext and are opt-in |
| Replay | Random frame id, 300 second window, bounded seen-set |
| Malformed input crashing a device | All parsing wrapped, frames rejected and audited |

## Not protected (known limits)

- Partial forward secrecy only. Compromise of a receiver's static key decrypts traffic
  captured earlier. A full ratchet is on the roadmap.
- Relays learn the destination fingerprint, packet size and timing. Floods are visible to
  anyone listening. A relay can drop packets (denial of service) but cannot alter them.
- Radio range is physical. One BLE hop is roughly 100 m. 1000 m needs about ten relay hops
  or a longer range radio such as LoRa. The code cannot extend a radio.
- Dead reckoning drifts. Precision degrades with distance travelled until a GPS fix returns.
- Disappearing messages rely on the receiving client. A modified client can keep them.
- Metadata is visible. Sender and recipient fingerprints and frame types are in clear text
  in the envelope, so a nearby observer can see that two devices are talking.
- Trust on first use. A substituted card at pairing time defeats everything. Compare the
  safety number out loud or on screen after pairing.
- Clock trust. Expiry uses the local clock. A device whose clock is rolled back honours
  expired grants. Receivers should treat the clock as part of their trusted base.
- Revocation is best effort over a lossy radio. The grantor stops sending immediately, but
  a receiver out of range will not hear the revoke until the grant expires. This is why
  expiry is mandatory.
- Receivers can screenshot or copy anything they are shown. Consent controls what is sent,
  not what the other person does with it.
- Replay memory and the ledger are in RAM only. Restarting a node forgets seen ids.
- No external review has been done.
