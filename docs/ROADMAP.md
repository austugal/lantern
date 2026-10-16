# Roadmap

Built (0.1): identity, cards, safety numbers, grants, ledger, envelopes, enforcement on
both ends, coarsening, audit log, radio simulator, CLI demo, CI.

Next, in order:

1. Persistence: encrypted on-disk store for identity, peers, ledger and seen ids.
2. Forward secrecy: per-session ephemeral X25519 with a symmetric ratchet.
3. Revoke retry: queue revocations and deliver on next contact, show pending state.
4. Real transport: BLE advertising and GATT, or Wi-Fi Aware, behind the `Transport` protocol.
5. Pairing UX: QR payload format and a verified safety number screen.
6. Group sharing: one grant per member with shared expiry.
7. Mobile app shell using the core through a thin binding.
8. External security review before any release to the public.
