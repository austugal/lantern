# Architecture

Flutter owns UI, profile persistence, packet validation, invitation state, delivery receipts, foreground location consent and bounded media assembly. The native adapters expose MethodChannel `org.austugal.lantern/nearby` and EventChannel `org.austugal.lantern/events`.

- Methods: `start(name)`, `stop`, `request(id)`, `accept(id)`, `reject(id)`, `disconnect(id)`, `send(id, data)`.
- Events: `found`, `lost`, `invitation` (name and Android pairing code), `connected`, `disconnected`, `data`, `error`, `stopped`.

Android uses Google Nearby Connections with `P2P_POINT_TO_POINT`. iOS currently uses an encrypted (`required`) Apple `MCSession` and the `lantern-v1` Bonjour service. These are separate protocols: Android–iPhone and mobile–desktop interoperability are not implemented. Migrating iOS to Google Nearby is a proposal in [Mobile next steps](../../docs/MOBILE-NEXT-STEPS.md), not the current implementation.

Native generation/session guards reject callbacks from old sessions. Native background hooks stop nearby sessions independently of Dart. Discovery and connection require an explicit user action; the app does not discover or access arbitrary phones without participation.

## Wire contract v1

UTF-8 JSON, maximum 8,192 bytes. Envelope: `v` = 1, `kind`, random 128-bit hexadecimal `id`, object `body`. Endpoint identity comes from the transport, never from a JSON sender field. Only the connected endpoint may deliver application payloads.

| Kind | Body | Meaning |
| --- | --- | --- |
| `text` | `text` (1–1,000 characters), optional `ttl` | Chat message |
| `attachmentStart` | `mime`, `size`, `chunks`, optional `ttl` | Announces bounded photo/voice transfer |
| `attachmentChunk` | `transfer`, `index`, base64 `data` | One chunk of announced transfer |
| `ack` | `id` of original message/transfer | Peer app received text or completed validated attachment; not a human read receipt |
| `location` | finite, bounded `lat`, `lon`, `accuracy` | Latest foreground GPS fix |
| `locationStop` | empty body sent by app | Discard sender's last coordinate |
| `guardianRequest` | empty object | Ask current peer to act as guardian |
| `guardianResponse` | Boolean `accepted` | Explicit guardian response |
| `guardianAlert` | empty object | Check-in alert to an accepting guardian; no automatic coordinate attachment |

Optional message lifetimes are 60, 300, 900 or 3,600 seconds. Receiver expiry starts at receipt, so it is not globally synchronized deletion. Non-text packet deduplication retains 512 IDs. Accepted text IDs have a separate non-evicting session ledger capped at 1,024: accepted duplicates receive another receipt without another displayed message, even after history trimming. At capacity new text is rejected without a receipt and the UI asks for reconnection. Notes are memory-only, limited to 200 entries and 8 MiB of attachment bytes; disconnect clears the conversation. Recipients can retain screenshots or other copies.

### Bounded text delivery

Native text submission times out visibly after 10 seconds. Successful submission starts a 30-second app-receipt deadline. Timeout or failure is unconfirmed delivery, not proof that the peer did not receive the message. Matching receipts win over late native completions and errors and can resolve an unconfirmed note. A note's draft clears when it is admitted, so another Send tap cannot silently create a second ID from the same retained composer text.

Manual retry is restricted to retained, failed, non-disappearing text in the current foreground connection. It reuses the original ID and text, requires UI confirmation, and permits three submissions total. Relative-TTL packets are excluded so retry cannot restart disappearance. There is no automatic resend, persistence, background retry or cross-session queue.

At most eight text attempts await submission or receipts, and at most eight real native text calls may remain unresolved across the controller's lifetime. A timeout cannot cancel an underlying platform call; reconnect does not reset this latter budget. A real completion frees its slot. Session generations and attempt identities guard callbacks; disconnect, expiry, trimming and disposal cancel attempt deadlines. This changes no native transport or wire contract.

## Media boundary

Attachments are limited to 1 MiB each, 4,096-byte decoded chunks and at most 256 chunks. Supported MIME types are JPEG, PNG and M4A (`audio/mp4`). The receiver accepts at most two incomplete transfers, validates each index and expected chunk length, discards conflicting duplicates and expires incomplete transfers after 120 seconds or the message lifetime. Session reset clears assembly buffers and invalidates outgoing transfers. Receipts follow complete reassembly and validation.

Image checks bound width/height to 2,048 pixels and total pixels to 4,000,000. Container signatures and selected header fields are checked before rendering/playback. **This is not complete media-decoder validation or malware scanning.** Platform/Flutter decoders remain a trust boundary and must be kept updated.

Photo capture/gallery selection is explicit. The app requests resized input, rejects inputs over 20 MiB, re-encodes selected photos and bounds the outgoing result to 1 MiB. Voice recording requests microphone access and stops after 30 seconds. Sending a draft requires confirmation for the current recipient; using an external picker may background the app and disconnect the session.

Conversation bytes and drafts are held in memory, but native picking/recording/playback use temporary files. Cleanup is best-effort and does not promise forensic erasure after crashes or process termination. No encrypted media vault is implemented.

## Location, maps and external requests

Local GPS/navigation is separate from sharing. Permission grants do not start coordinate transmission. Sharing has a generation guard against delayed permission responses after stop, disconnect or backgrounding, a 15-minute limit, and a three-second send throttle. Location streams request a 10-metre movement filter; the receiver expires stale coordinates after 30 seconds. GPS precision is not radio range, and indoor fixes may be poor or unavailable.

Maps are optional external data sources, not part of the nearby transport:

- Online OpenStreetMap tiles load only after the user enables them. The provider receives the request IP address and viewed map region.
- Saving an approximately 500-metre area requires confirmation before sending the selected coordinates to `overpass-api.de`. The request fetches basic roads, building outlines and landmarks. Downloads have a 30-second overall deadline and a 5 MiB response limit.
- Imported/saved GeoJSON supports bounded Point, LineString and Polygon geometry: at most 5 MiB, 5,000 features and 50,000 points, with finite valid coordinates.
- One saved area persists in app storage until replaced or deleted. **It is not an encrypted vault** and reveals the saved area. Disappearing-message settings do not delete saved maps.

GPS markers and downloaded map geometry do not provide routing, live hazards, traffic, guaranteed coverage or rescue dispatch. Maps may be incomplete or outdated. The offline guide is bundled keyword-based guidance, not a remote AI service.

## Device channel and permission boundary

Separate MethodChannel `org.austugal.lantern/device` exposes `setTorch(enabled)`, `requestNotifications`, `notifyMessage`, `clearNotifications` and `openAppSettings`.

Camera/torch, microphone and notification permission requests occur on use, not at startup. Camera, autofocus, flash and microphone hardware are optional in the Android manifest. Delayed torch permission grants cannot reactivate it after cancellation/backgrounding. Dart serializes torch writes and SOS timing; native lifecycle hooks independently attempt to turn the torch off. Hardware unavailability is reported. The visual SOS pattern does not contact emergency services.

Local notifications contain only a generic new-message notice, without sender, text or coordinates. Notification authorization does not maintain a radio connection or add remote push delivery. **There is no background message receiving or background notification delivery guarantee:** notifications can only be submitted after a message arrives during the active session. Native alerts respect operating-system permission/settings.

## Identity and security boundary

Android's SDK authentication digits must be compared before accepting. iOS invitation consent and encrypted Multipeer transport do not authenticate a display name. Do not claim verified iPhone identities, independent security certification or suitability for high-risk communications.

There is no application account server or application analytics integration. Google Nearby remains a third-party dependency subject to Google's diagnostics policies. Online maps introduce explicit external requests. Encryption protects the transport, not a compromised or unlocked endpoint or copies made by the recipient.

## Primary references

- https://developers.google.com/nearby/connections/android/get-started
- https://developers.google.com/nearby/connections/android/manage-connections
- https://developers.google.com/nearby/connections/android/exchange-data
- https://developer.apple.com/documentation/multipeerconnectivity
- https://developer.android.com/reference/android/hardware/camera2/CameraManager
- https://developer.android.com/develop/ui/views/notifications/notification-permission
- https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
- https://pub.dev/packages/image_picker
- https://pub.dev/packages/record
- https://pub.dev/packages/geolocator
- https://pub.dev/packages/shared_preferences
