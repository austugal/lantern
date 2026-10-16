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
- Radio range is not measured here. Mesh tests use simulated distances. The desktop
  transport uses an existing private LAN; no BLE or LoRa adapter is included.
- Dead reckoning drifts. Precision degrades with distance travelled until a GPS fix returns.
- Disappearing messages rely on the receiving client. A modified client can keep them.
- Metadata is visible. Sender and recipient fingerprints and frame types are in clear text
  in the envelope, so a nearby observer can see that two devices are talking.
- Trust on first use. A substituted card at pairing time defeats everything. Compare the
  safety number out loud or on screen after pairing.
- Clock trust. Expiry uses the local clock. A device whose clock is rolled back honours
  expired grants. Receivers should treat the clock as part of their trusted base.
- Revocation is best effort over a lossy radio. The grantor stops sending immediately, but
  a disconnected receiver may keep data until reconnect or expiry. The desktop retries
  revocations while the peer remains paired. Unpairing prevents further retries.
- Receivers can screenshot or copy anything they are shown. Consent controls what is sent,
  not what the other person does with it.
- The desktop persists replay identifiers and the ledger in its encrypted vault. A crash
  can lose changes since the last save. Core-only callers must arrange their own persistence.
- No external review has been done.

## Desktop boundaries

The local service binds to IPv4 loopback, checks Host/Origin and a secret token,
bounds requests, and serves bundled assets under a restrictive CSP. The token is
kept in same-tab session storage so reloading works; it is not a vault key.
A compromised browser, extension, OS or local account is outside this protection.
Python cannot guarantee erasure of key or message copies from RAM. A receiver can
retain any received content. Windows filesystem ACLs require platform verification;
POSIX mode 0600 must not be interpreted as a portable Windows ACL guarantee.

The timer is an experimental convenience. It cannot run through process exit or
sleep and does not send stale coordinates. No delivery, rescue or human-response
guarantee is made. Use only one running process per profile directory.
