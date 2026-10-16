# Architecture

Flutter owns UI, profile persistence, packet validation, invitation state, delivery receipts and foreground location consent. The native adapters expose a MethodChannel (`org.austugal.lantern/nearby`) and EventChannel (`org.austugal.lantern/events`).

Methods: start(name), stop, request(id), accept(id), reject(id), disconnect(id), send(id, data).
Events: found, lost, invitation (name and Android pairing code), connected, disconnected, data, error, stopped.

Android uses `P2P_POINT_TO_POINT` Google Nearby Connections. iOS uses an encrypted (`required`) MCSession and the `lantern-v1` Bonjour service. These are separate protocols, not cross-platform interoperable transports. All native callbacks and Flutter state changes are bounded to the current session. Native background hooks stop the radio session independently of Dart.

## Wire contract v1

UTF-8 JSON, maximum 8,192 bytes. Envelope: `v` = 1, `kind`, random 128-bit hexadecimal `id`, object `body`.

| Kind | Body | Meaning |
| --- | --- | --- |
| text | text (1–1,000 characters) | Chat message |
| ack | id (original message ID) | Peer app received text, not a human read receipt |
| location | lat, lon, accuracy (finite, bounded numbers) | Latest foreground GPS fix |
| locationStop | empty object | Discard the sender's last coordinate |

Endpoint identity comes from the transport, never a JSON sender field. Only the connected endpoint may deliver payloads. Messages have a bounded 512-ID deduplication window and 200-note in-memory view. GPS updates are throttled to at most one every three seconds and requested after 10 metres of movement; old coordinates expire, including when stationary. No automatic resend or offline message queue is implemented.

Location authorization has a generation guard: a permission response arriving after stop, backgrounding or disconnect cannot resume sharing. Sharing stops after 15 minutes. A stopped sender cannot erase a recipient's screenshots or external copies.

## Identity boundary

Android's system-provided authentication digits must be compared before accepting. iOS invitation consent and encrypted transport do not authenticate a display name. Do not claim verified iPhone identity or use this MVP for sensitive/high-risk communication. A future interoperable transport and authenticated key comparison require their own design and two-device tests.

## Primary references

- https://developers.google.com/nearby/connections/android/get-started
- https://developers.google.com/nearby/connections/android/manage-connections
- https://developers.google.com/nearby/connections/android/exchange-data
- https://developer.apple.com/documentation/multipeerconnectivity
- https://developer.apple.com/documentation/multipeerconnectivity/mcsession
- https://pub.dev/packages/geolocator
- https://pub.dev/packages/shared_preferences
