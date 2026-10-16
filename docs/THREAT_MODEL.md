# Threat model

## Protected

| Threat | Mitigation |
| --- | --- |
| Stranger messages or tracks you | Unpaired frames dropped, every action needs a live grant |
| Over-sharing precision | Sender-side coarsening plus receiver-side rejection |
| Forgotten sharing | Mandatory expiry, 24 hour location cap |
| Changing your mind | Revocation, panic button, unpairing |
| Forged or altered frames | Ed25519 signature over the full envelope |
| Eavesdropping on content | ChaCha20-Poly1305 with an X25519 derived key |
| Replay | Random frame id, 300 second window, bounded seen-set |
| Malformed input crashing a device | All parsing wrapped, frames rejected and audited |

## Not protected (known limits)

- No forward secrecy. Keys are static X25519 pairs. If a device is compromised, past
  captured traffic for that pairing can be decrypted. A ratchet is on the roadmap.
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
