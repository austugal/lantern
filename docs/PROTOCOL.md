# Wire protocol, version 1

All frames are canonical JSON (sorted keys, no whitespace), at most 16 KiB.

## Envelope

| Field | Meaning |
| --- | --- |
| `v` | Protocol version, currently `1` |
| `t` | `grant`, `revoke`, `msg`, `loc` or `sos` |
| `from`, `to` | Sender and recipient fingerprints |
| `id` | 24 hex characters, random, used for replay rejection |
| `ts` | Sender clock, integer seconds |
| `e` | Sender's ephemeral X25519 public key for this frame, base64 |
| `n` | 12 byte ChaCha20-Poly1305 nonce, base64 |
| `c` | Ciphertext of the canonical JSON body, base64 |
| `s` | Ed25519 signature over `"lantern/env/1" + canonical(all fields except s)` |

The AEAD associated data is the canonical JSON of `v, t, from, to, id, ts, e`.

## Keys

Fingerprint: first 32 hex characters of `SHA-256("lantern/fp/1" + sign_pub + kx_pub)`.
Frame key: `HKDF-SHA256(X25519(static, static) || X25519(ephemeral, peer_static), salt = sorted fingerprints joined, info = "lantern/key/2")`.
The sender discards the ephemeral secret after sending, so a later compromise of the sender
cannot decrypt frames it already sent. A compromise of the receiver's static key still can.

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
| `msg` | `{text, ttl?}` | The receiver has a live `MESSAGE` grant issued to the sender, text is 1 to 2000 characters |
| `sos` | `{lat, lon, prec, note}` | The receiver holds a live `SOS` grant from the sender. `note` is at most 200 characters |
| `loc` | `{gid, lat, lon, prec}` | The receiver holds a live `LOCATION` grant from the sender, `gid` matches, `prec` is not finer than the grant |

## Grant

`{id, scope, grantor, grantee, iat, exp, prec, key, sig}` where `sig` is an Ed25519
signature by the grantor over `"lantern/grant/1" + canonical(body without sig)`.

## Mesh packets

When a direct send fails, the sender floods a wrapper so nearby devices can carry it:

`{"m": 1, "ttl": n, "to": fingerprint, "id": frame id, "f": base64 frame}`

A device that is the destination processes the inner frame normally. A device that has
opted in to relaying and sees `ttl > 1` rebroadcasts it with `ttl - 1`. Everyone else drops
it. Packet ids are remembered so floods terminate. `ttl` is capped at 16 and defaults to 8.
Relays see the destination fingerprint and the packet size, never the content.

## Disappearing messages

`ttl` on a `msg` asks the receiver to delete the message after that many seconds (1 second
to 7 days). The receiver's `purge_expired()` honours it. A modified client can ignore it.
