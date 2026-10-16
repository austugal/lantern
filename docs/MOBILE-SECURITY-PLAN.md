# Mobile and field-tool direction

Design proposal, 16 October 2026. Items below are NOT implemented by this document.
The working release remains a desktop preview. No APK or security certification is claimed.

## Product

Android first: an installable signed APK, with an AAB for eventual Play distribution.
iOS requires its own signed build and lifecycle validation. Bundle runtime dependencies;
require neither a cloud account nor package installation on the user's phone. Offline
operation does not eliminate dependencies on the OS, radio drivers or cryptographic code.

Keep the Python desktop reference separate until a reviewed mobile implementation can
pass the same consent, expiry, replay and delivery tests. Do not combine two incompatible
Flutter/Python protocols under one product claim. Define versioned test vectors first.

## Communication choices

- Existing LAN/hotspot: retain as a baseline and a testable fallback.
- Native Wi-Fi Direct / BLE: evaluate for Android without Google Play services; discovery
  must be explicit and time-limited, and only paired Lantern peers receive data.
- Nearby Connections: supports offline encrypted links and mutual acceptance, but its
  Play services SDK collects usage analytics controlled through device settings. It is
  not a zero-dependency or unconditional no-telemetry solution.
- LoRa: optional external hardware bridge, not a phone-only range setting. Preserve
  application encryption across the bridge; account for packet size, airtime, loss,
  fragmentation, bandwidth and local radio rules. No kilometre guarantee.
- Store-and-forward: proposed bounded encrypted queues with expiry, duplicate suppression,
  acknowledgments and explicit relay permission. Never silently retain expired location.

## Security engineering

Publish a threat model rather than a 'military-grade' or unhackable claim. Use minimal,
pinned, maintained dependencies; produce an SBOM, reproducible builds where practical,
signed updates and dependency review. GitHub popularity or agent skills are not evidence
of security. Review source and licences before integration; do not execute fetched skills.

On Android, use Keystore hardware backing where supported and verify its actual security
level. Do not assume every algorithm or device supports secure-element keys. A rooted or
compromised OS may still misuse keys or read plaintext while the app is unlocked.

A reviewed ratcheting protocol is a prerequisite for stronger forward-secrecy claims.
libsignal is a reference candidate, not a drop-in commitment: its maintainers explicitly
state third-party use is unsupported and APIs may change. Assess licensing and maintenance.
Do not invent or advertise post-quantum security by composing unreviewed primitives.

Release gates: real Android device pairs, loss/reordering, sleep/restart, background limits,
permission denial, replay/fuzz tests, secure backup policy, signed updates, and independent
security assessment. The present core has only partial forward secrecy.

## Useful field and investigation features to develop

1. Case notebook: user-supplied observations, source URLs, capture times, and file hashes.
   Hashes detect changes; they do not establish that observations are true or legally admissible.
2. Evidence export: signed manifests and explicit redaction; no automatic sensitive uploads.
3. Team check-ins and consenting asset/person beacons: visible sharing state and expiry.
4. Verified team roster, key-change warnings and lost-device revocation.
5. Offline maps from licensed local datasets; freshness and positional uncertainty shown.
6. Communication diagnostics: distinguish configured route, submitted packet, app receipt
   and human acknowledgment. No false 'connected' or rescue assurance.
7. Public-source research notes and citation management; no identifier-based person tracking,
   account intrusion, covert collection, phone exploitation or Wi-Fi password bypass.
8. OTA updates means authenticated software updates to one's own devices, not access to
   arbitrary nearby phones. 'OPA' is ambiguous and does not identify an implementation.

## Primary references consulted

- https://developers.google.com/nearby/connections/overview
- https://developer.android.com/privacy-and-security/keystore
- https://github.com/signalapp/libsignal
- https://github.com/jedisct1/libsodium
- https://meshtastic.org/docs/overview/encryption/
- https://www.briarproject.org/how-it-works/

These projects illustrate approaches, not endorsements of Lantern's security. Meshtastic's
published default channel key is not private; its own encryption documentation describes
version-dependent authentication and metadata limitations. Do not present a LoRa bridge as
secure solely because its link has encryption.
