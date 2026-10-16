# Lantern

**Be here. Stay together.** Consent-first, offline nearby messaging and optional foreground location sharing for people together in person.

Flutter app with real native transports, not simulated peers. Early device-testing MVP; physical-radio acceptance checks are still required before release.

## What is implemented

- Saved display name; discovery starts only when you turn Lantern on.
- Nearby discovery and one-to-one conversations. Both people choose the connection.
- Android: Google Nearby Connections, with matching-code confirmation on both phones.
- iPhone: encrypted Apple Multipeer Connectivity and explicit invitation acceptance. Display names are **not authenticated identities**; confirm the invitation in person.
- Text messages (1,000 characters), delivery receipts, visible failures and duplicate suppression.
- Separate consent for precise location sharing, with a visible stop control and a 15-minute limit.
- Backgrounding, disconnecting or switching off ends sharing and clears the local conversation.
- Received coordinates expire after 30 seconds without another update. Coordinates and accuracy are shown; no map or distance estimate is fabricated.
- Bounded, versioned packets; unknown endpoints and malformed messages are ignored.

## Compatibility

| Pair | This version |
| --- | --- |
| Android ↔ Android | Google Play services required; Android 7+ |
| iPhone ↔ iPhone | iOS 13+; Multipeer Connectivity |
| Android ↔ iPhone | Not supported by these adapters |
| Browser / desktop | No nearby transport |

Keep both apps open and Wi-Fi/Bluetooth enabled. Internet is not needed for an established nearby conversation, but installation and dependency downloads need internet. Range depends on hardware and surroundings. Android permission prompts can include Location because Nearby discovery needs it; **granting the permission does not start coordinate sharing**.

## Run

Use Flutter **3.35.7**, Java 17 and the Android SDK (API 36), or macOS with Xcode/CocoaPods for iOS.

```sh
flutter pub get
flutter run
```

The Android and iOS projects are included. Do not regenerate them with `flutter create --overwrite`; that would replace the transport code and permissions.

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
flutter build apk --debug
# macOS only:
flutter build ios --simulator --debug
```

GitHub Actions runs checks, builds the Android debug APK and iOS simulator app, and uploads build artifacts. A simulator build validates compilation, **not nearby radios**. To install on an iPhone, select your signing team in `ios/Runner.xcworkspace` and build to your device. Release signing, store submission and provisioning are intentionally not configured. Android release builds require your own signing configuration; CI distributes debug testing builds only.

## Try it with two phones

1. Install on two devices of the same platform and choose distinct display names.
2. Turn on Lantern on both. Grant the prompted permissions.
3. Select the other phone. On Android, compare the pairing code on both screens before both accept. On iPhone, accept the invitation on the receiving phone after confirming with the person.
4. Open **Conversation**, send a message, and verify **Delivered** appears only after the peer acknowledges it.
5. Choose **Share location for 15 minutes**, confirm, then verify coordinates on the other phone. Stop sharing and verify they disappear.
6. Lock a phone or switch apps. Connections and local messages should clear, and location sharing should stop.

Run the complete [device acceptance checklist](docs/DEVICE_TESTS.md) before treating this as release-ready.

## Privacy and security boundaries

Only the display name is persisted by Lantern. Messages, endpoint identifiers and coordinates remain in memory for the current session, bounded to 200 displayed messages. There is no account server, map provider, advertising or application analytics integration. Android's Google Nearby SDK can collect diagnostics under Google's own policies.

Transport encryption is provided by Google Nearby / Apple Multipeer. The iOS flow does **not** provide a cryptographic identity comparison. A recipient can copy messages or locations, and local disconnect cannot erase their copies. This app is not an emergency, rescue, covert tracking or long-range mesh service. The app does not relay messages through third parties or send in the background.

See [architecture and protocol](docs/ARCHITECTURE.md) for implementation boundaries and primary SDK references.

## Implementation status

The initial remote contained only this project's one-line README; the Copilot Windows worktree was never pushed. This implementation is independently rebuilt from the handoff. Local Flutter dependency setup was blocked by automatic approval review after attempting a cloud metadata connection; offline Dart formatting was available. The connected GitHub integration rejected branch creation with HTTP 403 (Resource not accessible by integration), so no remote branch, PR or CI run was created. Automated Flutter tests/builds remain unverified; physical device checks remain manual. The supplied archive includes the full source and CI workflow.

See [verification record](docs/VERIFICATION.md) for the exact checks performed and [import instructions](docs/IMPORT.md) for publishing the supplied Git bundle without touching your original Copilot worktree.

## License

Application code: MIT. Generated platform scaffolding is derived from Flutter 3.35.7 templates; Flutter's BSD license is retained in [docs/FLUTTER-LICENSE](docs/FLUTTER-LICENSE).
