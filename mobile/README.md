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

## Features

| Control | What it does |
| --- | --- |
| Nearby discovery | Finds participating Lantern peers after you turn it on. Nothing connects automatically. |
| Conversation | Sends up to 1,000 characters per message over the native encrypted connection; shows receipts and failures. |
| Message expiry | Removes messages after 1 minute, 5 minutes, 15 minutes or 1 hour, if enabled. Screenshots and modified clients cannot be prevented. |
| Location sharing | Sends your position only after separate consent, for up to 15 minutes. Old received positions disappear after 30 seconds without an update. |
| Local GPS | Records a private breadcrumb trail and named waypoints in memory. Starting local GPS does not transmit coordinates. |
| Navigation | Shows straight-line distance and a true-north bearing to a waypoint, trail start or shared position. There are no maps, obstacle checks or road routes. |
| Guardian request | Asks the currently connected person to accept alerts. An unanswered request expires after 35 seconds. |
| Check-in timer | Sends an assistance alert if it expires while the same accepted guardian remains connected and both apps stay open. |
| Assistance alert | Submits an alert to the accepted guardian. It does not automatically include coordinates and does not confirm receipt or a human response. |
| Help | Explains a control without activating its function. It is help text, not AI. |

Location sharing and guardian consent are separate. A guardian alert does not override your location choices.

## What happens when I close or lock the app?

The connection stops, location sharing stops, the check-in timer is cancelled and the conversation is cleared. Opening the app again does not silently reconnect or restart sharing. There is **no background rescue monitoring**.

Only your display name is saved. Messages and coordinates are held in memory. Local trails and waypoints are also held in memory until cleared or the app closes; stopping GPS clears the current fix but retains the trail. **Clear trail** removes the trail and waypoints.

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

There is no Lantern account server, advertising, map provider or application analytics integration. Google's Nearby SDK may collect diagnostics under Google's policies. A recipient can copy information; stopping sharing cannot erase copies already made. No independent audit or security certification is claimed.

## Verified builds

Flutter analysis and **28 automated tests passed**. GitHub Actions compiled the Android testing APK, iOS simulator app and unsigned iOS device app. [Verification details](docs/VERIFICATION.md).

These checks do not test physical radios, real-device GPS, battery life or real-world range. Complete the [two-phone acceptance checklist](docs/DEVICE_TESTS.md) before relying on a deployment.

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
