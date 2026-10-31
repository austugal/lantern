# Mobile interoperability and background delivery

Engineering plan, reviewed 16 October 2026; SDK feasibility re-evaluated 31 October 2026. **These are proposed changes, not implemented capabilities.**

## Current boundary

The mobile Android adapter uses Google Nearby Connections; the iPhone adapter uses Apple Multipeer Connectivity. They do not communicate with each other. Both are foreground-only and support one accepted peer. The desktop transport is separate. A successful native build does not demonstrate physical radio interoperability, range or reliability.

## SDK evaluation completed, implementation remains gated

See the [31 October source-backed SDK evaluation](../mobile/docs/NEARBY-SWIFT-EVALUATION-2026-10-31.md) and [adapter/acceptance contract](../mobile/docs/NEARBY-ADAPTER-CONTRACT.md). Current Google setup guidance and upstream Apple-medium documentation disagree; dependency resolution also needs an explicit transitive lock. Treat the migration below as an experimental proposal, with separate LAN/hotspot/no-access-point hardware results, not a ready replacement. The existing release is preserved.

## Next milestone: one protocol across Android and iPhone

Replace the iPhone Multipeer adapter with a pinned, reviewed version of Google's `google/nearby` Swift Package. Google documents Android–iOS interoperability. Retain Android's existing adapter and the Flutter `NearbyTransport` interface, controller and bounded packet format.

Implementation tasks:

- Use matching service ID `org.austugal.lantern.v1` and point-to-point strategy on both platforms.
- Translate Swift discovery, verification, connection, disconnect and byte-payload callbacks into the existing method/event channels.
- Require both users to compare and accept the SDK's verification code before any application payload. Display names are not identities. Do not copy the documentation's automatic-accept example into the production consent flow.
- Preserve one-peer limits, invitation deadlines, generation checks, packet bounds, attachment limits and foreground shutdown.
- Configure Bluetooth/local-network usage descriptions and the SDK-derived Bonjour service type. Add Wi-Fi Information and Hotspot Configuration entitlements only when the chosen transport media require them; validate Apple provisioning for those capabilities.
- Request permissions after a clear user action. Do not enable coordinate sharing when granting transport permissions.
- Explain how to enable Bluetooth/Wi-Fi manually: Google's announced late-2026 Nearby change removes automatic radio enablement.
- Update compatibility text only after the physical acceptance gates pass. Until then label the new adapter experimental.

### Acceptance gates

Use a signed physical iPhone and physical Android phone, including the intended supported OS versions. Record device models, OS versions, SDK revision and results.

1. Disconnect internet access, manually enable the required radios, and discover/request from each platform in turn.
2. Confirm matching verification codes; exercise rejection, mismatch, timeout and revoked permissions. No application data may arrive before mutual acceptance.
3. Exchange text, photo and voice attachments in both directions. Confirm receipts correspond to completed validated delivery, not submission to a radio API.
4. Interrupt transfers, disconnect, reconnect and change peers. No stale chunks, locations or receipts may cross sessions.
5. Check expiration, malformed packets, maximum sizes and repeated transfers against existing resource limits.
6. Run a 30-minute foreground session, then lock/background each phone and verify the documented stop/reconnect behavior.
7. Test representative hotel walls/floors and shared Wi-Fi with client isolation. Record measured results; do not infer kilometre coverage from simulator tests.

An iOS simulator can test UI and compilation, but does not satisfy these radio gates. iPhone installation requires Apple signing/provisioning.

## Subsequent milestone: explicit Android background sessions

Move connection ownership out of `FlutterActivity` into a user-started foreground session service with a retained Flutter engine/controller or an equivalently tested service-owned protocol implementation. Show a persistent notification with a Stop action. Validate the appropriate foreground-service type and permissions against Android's connected-device and remote-messaging requirements.

Merely removing `onStop()` is insufficient: the present native adapter belongs to the activity and the Dart controller deliberately resets when backgrounded. Keep camera, microphone and location stopped unless separately authorized for an explicitly supported feature. Do not automatically restart a consented session after reboot or process death.

Gates: screen-off delivery, notification Stop, revoked permissions, process termination, battery saver, representative manufacturer power management, foreground restoration and bounded message buffering. Report delivery failures honestly; a foreground service is not a guarantee against process termination or radio loss.

## iPhone background boundary

Ordinary iOS networking does not provide unlimited background execution. Do not advertise dependable offline background receiving based on sockets, background task scheduling or local notification permission. Preserve the foreground limitation until a supported design is demonstrated on hardware.

A bounded, expiring resend queue on reconnection is a useful separate feature; it requires explicit recipient/session binding and secure storage decisions before persisting sensitive messages. Internet-backed APNs delivery would be another product capability, not offline background delivery. Do not use unrelated audio/location modes to keep a messaging app alive.

## Optional later LAN fallback

A shared-Wi-Fi/hotspot transport could serve mixed phones independently of the native proximity adapters. It needs authenticated encrypted sessions and explicit pairing; do not add plaintext sockets or invent a cryptographic handshake. Hotel access-point client isolation may prevent connectivity. This is larger than unifying the existing Nearby adapters and does not remove iPhone signing or background restrictions.

## Primary references

- [Google Nearby: Android–iOS communication](https://developers.google.com/nearby)
- [Nearby Swift setup, permissions and entitlements](https://developers.google.com/nearby/connections/swift/get-started)
- [Nearby Swift connection verification](https://developers.google.com/nearby/connections/swift/manage-connections)
- [Upcoming Nearby radio-management changes](https://android-developers.googleblog.com/2026/07/upcoming-changes-nearby-connections-api.html)
- [Android foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- [Android Bluetooth background communication](https://developer.android.com/develop/connectivity/bluetooth/ble/background)
- [Apple networking API and suspension guidance](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api)
- [Apple local-network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
