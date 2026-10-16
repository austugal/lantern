# Wire protocol, version 1

All frames are canonical JSON (sorted keys, no whitespace), at most 16 KiB.

## Envelope

| Field | Meaning |
| --- | --- |
| `v` | Protocol version, currently `1` |
| `t` | `grant`, `revoke`, `msg` or `loc` |
| `from`, `to` | Sender and recipient fingerprints |
| `id` | 24 hex characters, random, used for replay rejection |
| `ts` | Sender clock, integer seconds |
| `n` | 12 byte ChaCha20-Poly1305 nonce, base64 |
| `c` | Ciphertext of the canonical JSON body, base64 |
| `s` | Ed25519 signature over `"lantern/env/1" + canonical(all fields except s)` |

The AEAD associated data is the canonical JSON of `v, t, from, to, id, ts`.

## Keys

Fingerprint: first 32 hex characters of `SHA-256("lantern/fp/1" + sign_pub + kx_pub)`.
Session key: `HKDF-SHA256(X25519(my_kx, peer_kx), salt = sorted fingerprints joined, info = "lantern/key/1")`.

## Receive order

1. Size limit, JSON parse, version.
2. Recipient matches, sender is paired.
3. Signature verifies against the paired card.
4. Timestamp within 300 seconds of the local clock.
5. `id` not seen before.
6. AEAD decrypts.
7. Consent check for the frame type (below).

## Bodies and checks

| Type | Body | Receiver accepts only if |
| --- | --- | --- |
| `grant` | `{grant}` | Grant signature valid, grantor is the sender, grantee is the receiver, key matches the paired card, not expired |
| `revoke` | `{id}` | The receiver holds that grant and the sender issued it |
| `msg` | `{text}` | The receiver has a live `MESSAGE` grant issued to the sender, text is 1 to 2000 characters |
| `loc` | `{gid, lat, lon, prec}` | The receiver holds a live `LOCATION` grant from the sender, `gid` matches, `prec` is not finer than the grant |

## Grant

`{id, scope, grantor, grantee, iat, exp, prec, key, sig}` where `sig` is an Ed25519
signature by the grantor over `"lantern/grant/1" + canonical(body without sig)`.
