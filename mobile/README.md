# Lantern for Android and iPhone

**A nearby conversation, with sharing you control.**

Lantern mobile is a real Flutter app with native Android and iPhone connections. It is a development preview for two people together in person, including colleagues in hotels, events and other workplaces.

**[Get the mobile preview downloads](https://github.com/austugal/lantern/releases)** · [All Lantern versions](../README.md)

## Install

| Device | Current download |
| --- | --- |
| Android | Install the **testing APK**. It is development-signed, not a Play Store release. Google Play services and Android 7+ are required. |
| iPhone | The app compiles for iOS 13+. A **simulator app** runs on a Mac; an **unsigned device app** needs Apple signing/provisioning before it can run on an iPhone. No TestFlight or App Store release is available yet. |

Android testing builds can use different debug keys. Replacing an existing install may require uninstalling it first. These builds are for testing, not production deployment.

## Use it in six steps

1. Install on two devices of the **same platform**. Android and iPhone do not connect to each other in this version.
2. Choose display names, keep both apps open, enable Wi-Fi/Bluetooth and turn on Lantern.
3. Select the other person. On Android, compare the pairing code on both phones before both accept. On iPhone, confirm the invitation with the person before accepting; names alone are not verified identities.
4. Open **Conversation** and send a message. **Delivered** means a receipt came back from the other app.
5. Use **Share location for 15 minutes** only when you want to share coordinates. Stop it at any time.
6. Open **Field tools** for expiry, local navigation and guardian check-ins. Tap help beside a feature for a short explanation.

No internet service is needed for the nearby conversation. Initial installation requires downloads. Radio range depends on the devices and surroundings; there is no kilometre-range guarantee.

### Unconfirmed text and retry

Text submission has a 10-second deadline. After submission, the app waits up to 30 seconds for the other app's receipt. **Delivery unconfirmed** means a receipt is missing; the text may already have arrived. A late matching receipt changes the status to **Delivered**.

For ordinary text, tap **Retry message**, read the warning and confirm **Retry now**. The same ID is reused, with at most three submissions total per message in the current connection. The receiver remembers accepted text IDs until the connection ends, so retrying does not display another copy. Retry does not mean the recipient read or accepted a work request. Disappearing messages and attachments cannot be retried with this control. Disconnecting, backgrounding or restarting clears the conversation; messages are never queued for automatic reconnection.

At most eight text submissions can await receipts at once. If a native send never completes, it stays counted toward a separate eight-call limit even after reconnecting; wait for it to finish or restart Lantern. Each connection accepts at most 1,024 distinct incoming text IDs, then asks you to reconnect. These bounds prevent an unlimited retry queue. This behaviour is included in the [current validated preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-2baaffd3d1e2).

### Request acknowledgement

For an ordinary text work request, choose **Request acknowledgement** before sending. The connected recipient can choose **Accept request** or **Decline request** once. Their linked response is a separate ordinary text, so it has its own app receipt and the same explicit retry limits. **Delivered** still means app receipt; **Accepted by colleague** means the peer tapped Accept. It does not mean the task is complete.

Acknowledgement is unavailable while message expiry is enabled and does not apply to attachments. It works only in the current one-peer foreground connection; disconnecting clears the request and response. There is no durable assignment queue, escalation, group dispatch or supervisor dashboard.

## Features

| Control | What it does |
| --- | --- |
| Nearby discovery | Finds participating Lantern peers after you turn it on. Nothing connects automatically. |
| Conversation | Sends text and emojis over the native encrypted connection; shows receipts and failures. Ordinary non-expiring text can request one Accept/Decline response. Text is limited to 1,000 characters. |
| Photos | Select a photo or use the camera, review it, then send. Images are resized and re-encoded before transfer. |
| Voice messages | Record up to 30 seconds, review and send. Received audio plays only when tapped. These are recordings, not live calls. |
| Local notifications | Optional generic alerts after a message arrives. They work without internet over an active nearby session; there is no background or remote push delivery. |
| Torch / SOS flash | Steady light or repeated three-short, three-long, three-short flashes, with Stop. Requires a working phone flash; backgrounding switches it off. This does not contact anyone. |
| Message expiry | Removes messages after 1 minute, 5 minutes, 15 minutes or 1 hour, if enabled. Screenshots and modified clients cannot be prevented. |
| Location sharing | Sends your position only after separate consent, for up to 15 minutes. Old received positions disappear after 30 seconds without an update. |
| Local GPS | Records a private breadcrumb trail and named waypoints in memory. Starting local GPS does not transmit coordinates. |
| Navigation | Shows straight-line distance and a true-north bearing to a waypoint, trail start or shared position. This is not a safe route or obstacle check. |
| Map & find me | Optional online street map; save a basic area around you for offline use or import a bounded GeoJSON map. |
| I need help — find me | Review and send a one-time coordinate, GPS accuracy and fix time to your connected colleague. Review the receipt in Conversation. |
| Guardian request | Asks the currently connected person to accept alerts. An unanswered request expires after 35 seconds. |
| Check-in timer | Sends an assistance alert if it expires while the same accepted guardian remains connected and both apps stay open. |
| Assistance alert | Submits an alert to the accepted guardian. It does not automatically include coordinates and does not confirm receipt or a human response. |
| Web & saved pages | Open HTTPS websites with internet. Explicitly download public page text, then open it offline. JavaScript is disabled; interactive sites may not work. |
| Help | Explains a control without activating its function. It is help text, not AI. |

Location sharing and guardian consent are separate. A guardian alert does not override your location choices.

### Prepare an offline map

Open **Field tools → Map & find me**, start local GPS, then choose **Save nearby area offline** while internet is available. Confirm the request to download roads, building outlines and landmarks within about 500 metres. It replaces the previously saved area. Check the map before an outage. You can delete it from the map screen. The downloaded area persists on your phone; it is not an encrypted vault. Downloads can fail or be rate-limited, and this basic map has no routing, live hazards or rescue information. [Map instructions and provider details](../docs/MAPS.md).

### Save web reading before an outage

Open **Field tools → Web & saved pages → Browse online**, confirm, and enter an HTTPS website address. Choose **Download public text offline** and confirm. Return to the saved list to read it without internet. Up to 20 text snapshots are stored on this device; images, video, forms and working websites are not saved. Saved text may become outdated and is not additionally encrypted by Lantern. Delete individual pages or all saved reading when finished. Browser cookies/cache are cleared separately in the online browser.

Offline mode cannot fetch new websites. Websites receive online requests; JavaScript is disabled and camera/microphone permission requests are denied. This is a basic reader, not a full replacement for Safari or Chrome.

## What happens when I close or lock the app?

The connection stops, location sharing stops, the check-in timer is cancelled and the conversation is cleared. Opening the app again does not silently reconnect or restart sharing. There is **no background rescue monitoring**. If an active session was interrupted, Lantern shows why it stopped and says that nothing was queued. Tap **Turn on Lantern** to restart discovery, then choose and confirm the person again. A failed restart stays visible so you can retry or dismiss it.

Your display name is saved. Conversation messages and attachments are held in memory; temporary audio playback/recording files are cleaned up by the app. Local trails and waypoints are held in memory until cleared or the app closes; stopping GPS clears the current fix but retains the trail. **Clear trail** removes the trail and waypoints.

Opening the camera, photo picker or phone settings can background Lantern and disconnect it. Reconnect before sending a selected attachment. Camera, microphone and notification permission prompts appear only when you use those features. You can review permissions in phone settings. Attachments are limited to 1 MiB each, incomplete transfers expire, and media retained in the conversation is capped.

## Connections and limits

| Pair | Supported now? |
| --- | --- |
| Android ↔ Android | Yes, through Google Nearby Connections |
| iPhone ↔ iPhone | Yes, through Apple Multipeer Connectivity |
| Android ↔ iPhone | No |
| Mobile ↔ desktop | No; desktop uses a separate protocol |
| Groups or multi-hop relays | No; one connected peer per mobile session |

No mobile LoRa bridge, encrypted evidence vault, voice calls, online/local conversational AI or telephone integration is included. The app does not access locked Wi-Fi networks, other people's phones or private accounts. Keep another way to contact emergency services.

Android's permission prompts may include Location for nearby discovery. Granting that OS permission does **not** start coordinate sharing. Android also requires Google Play services; the app is not dependency-free.

## Security

Encryption comes from Google Nearby or Apple Multipeer Connectivity. Android provides a pairing-code comparison. The iPhone flow does not provide an independent cryptographic identity comparison; verify the invitation in person.

There is no Lantern account server, advertising or application analytics integration. Online street maps use OpenStreetMap tiles only after you enable them; the provider sees your IP address and viewed region. Saving a nearby map sends the chosen GPS coordinate to Overpass after confirmation. Google's Nearby SDK may collect diagnostics under Google's policies. A recipient can copy information; stopping sharing cannot erase copies already made. No independent audit or security certification is claimed.

## Verified builds

Flutter analysis and **111 automated tests passed**. GitHub Actions compiled the Android testing APK, iOS simulator app and unsigned iOS device app. [Verification details](docs/VERIFICATION.md).

The Android emulator also passed APK installation/navigation and a native browser/offline-reader fixture. These checks do not test physical radios, real-device GPS, battery life or real-world range. Complete the [two-phone acceptance checklist](docs/DEVICE_TESTS.md) before relying on a deployment.

## Build from source

Use Flutter **3.35.7**, Java 17 and Android SDK API 36. iOS requires macOS, Xcode and CocoaPods.

```sh
cd mobile
flutter pub get
flutter analyze
flutter test --coverage
flutter build apk --debug
# macOS only:
flutter build ios --simulator --debug
flutter build ios --release --no-codesign
```

The platform projects are included. Do not use `flutter create --overwrite`: it would replace native transport code and permissions. For an iPhone installation, open `ios/Runner.xcworkspace`, select your Apple signing team and build to the device.

The authoritative workflow is [../.github/workflows/mobile.yml](../.github/workflows/mobile.yml). Release signing, provisioning and store submission are not configured. [Architecture and SDK references](docs/ARCHITECTURE.md).

Application code: MIT. Flutter platform scaffolding retains its [BSD license](docs/FLUTTER-LICENSE).

Copyright © 2026 Tiago Fitas (austugal). See [MIT License](LICENSE).

Offline web downloads fetch the public HTTPS page separately, without the browser’s cookies or signed-in session. Saved text may differ from what the browser displays; browser logins are not reused and content generated by scripts is not supported. The full address is requested again, so private or token-bearing links can still return sensitive text. The download is bounded and parsed as inert text, with no scripts executed.
