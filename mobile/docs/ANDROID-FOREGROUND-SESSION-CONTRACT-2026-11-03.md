# Android foreground nearby-session contract — 3 November 2026

Status: **design gate only**. Lantern does not implement or claim Android background communication yet. This document changes no transport, permission, service, notification or runtime behaviour.

## Why implementation must wait

The current Android app targets SDK 35, compiles with SDK 36 and supports Android 7+ (minimum SDK 24). `MainActivity` owns the Google Nearby `ConnectionsClient`, peer state, permissions and callbacks. Its `onStop()` calls `shutdown()`, which stops advertising and discovery, disconnects every endpoint and invalidates callbacks. Dart independently stops Nearby and clears messages, attachments, location, requests, check-ins and timers when Flutter leaves the foreground. Adding a notification around this Activity-owned client would not preserve a coherent session.

The first implementation must move the accepted Nearby session into a non-exported Android service and define how the service and Flutter exchange bounded state. iPhone remains foreground-only and keeps its current teardown behaviour. A successful Android build or emulator test will not establish Android–iPhone interoperability.

## Platform requirements

These items come from Android platform guidance rather than Lantern policy.

- Use foreground-service type `connectedDevice` for communication with an external Bluetooth, Wi-Fi or local-network device. For an app targeting Android 14 or later, declare `android.permission.FOREGROUND_SERVICE`, `android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE` and a service with `android:foregroundServiceType="connectedDevice"`. Its runtime prerequisites include an appropriate granted Bluetooth permission or an eligible declared network-state permission. [Foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- Start the service from a visible user action. Android 12+ generally forbids starting a foreground service while the app is already in the background. [Background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- Call `startForegroundService()`, then promptly promote the service with a non-zero notification ID, a LOW-or-higher notification and the declared connected-device type. [Launch a foreground service](https://developer.android.com/develop/background-work/services/fgs/launch)
- Android 13+ does not require notification permission merely to launch a foreground service, but a denied permission can hide its notification from the notification drawer while still showing the service in Task Manager. [Notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- Android 13+ Task Manager **Stop** kills the whole app, removes its back stack and foreground-service notification, and sends no callback to the app. [User-initiated stopping](https://developer.android.com/develop/background-work/services/fgs/handle-user-stopping)
- Generic Android BLE guidance identifies a connected-device foreground service as one option for work while the user switches apps. It does not prove that Nearby Connections will survive every device, process or power state. [BLE background guidance](https://developer.android.com/develop/connectivity/bluetooth/ble/background)
- Nearby Connections documents required runtime permissions and refuses advertising or discovery when they are missing. It does not promise background survival. [Nearby Connections setup](https://developers.google.com/nearby/connections/android/get-started)
- Nearby guidance requires explicit user initiation, easy stopping and honest battery expectations. Its Activity-versus-Service notes for Nearby Messages must not be presented as a Nearby Connections guarantee. [Nearby developer guidelines](https://developers.google.com/nearby/developer-guidelines)

## Lantern product contract

The following are stricter Lantern choices for the first candidate.

1. **Explicit opt-in after verification.** The control becomes available only after one peer is connected and its pairing code has been confirmed in the foreground. Discovery, advertising and invitations never continue in the background.
2. **Notification consent first.** Lantern requires notification permission before enabling this mode, even where Android would allow a foreground service without it. Denial keeps the current foreground-only behaviour so the generic persistent notification and its **Stop** action remain visible in the notification drawer.
3. **Two visible Stop controls.** The connected screen retains a prominent **Stop foreground session** control. The persistent private notification says only that a Lantern nearby session is active, shows remaining time and offers **Stop**. It contains no peer name, message text, location or work-request content.
4. **Service-owned session.** A non-exported `connectedDevice` service owns the already verified endpoint and generation. It uses `START_NOT_STICKY`. No boot receiver, automatic restart, automatic discovery, automatic connection, reconnection or retry is allowed.
5. **Hard lifetime bound.** One opt-in lasts at most 30 minutes. Expiry stops the service, disconnects the endpoint, removes the notification and clears all service memory. Extending it requires the visible app and another explicit choice.
6. **Bounded volatile buffer.** While Flutter is unavailable, accept complete byte payloads only from the exact verified endpoint. Hold at most 32 payloads and at most 256 KiB total, whichever limit is reached first. Store nothing on disk. On malformed endpoint state or overflow, disconnect and clear the buffer rather than silently discard communication.
7. **No early receipt.** Native receipt or buffering is not Lantern delivery. The service must not send an application `ack` until Flutter resumes, checks the endpoint/session generation, decodes and validates the packet, admits it within app limits and displays or otherwise accepts it. Sender UI therefore remains honestly unconfirmed while the recipient app is backgrounded.
8. **Sensitive features still stop.** Backgrounding immediately stops location sharing, local navigation/GPS, guardian check-ins, camera/microphone work, media recording/playback, compass and torch/SOS. The first service declares only `connectedDevice`; it must not add location, camera or microphone foreground-service types.
9. **Termination is final.** In-app Stop, notification Stop, timeout, disconnect, permission loss, process death, force-stop and Android Task Manager Stop all end the session and clear volatile packets. Reopening Lantern shows a stopped/interrupted state and requires fresh discovery, peer choice and verification. No callback or delivery claim is invented when Android kills the process.

## Required state transitions

| Current state | Event | Required result |
| --- | --- | --- |
| Foreground-only, no peer | User turns on Lantern | Existing foreground discovery and consent flow; service does not start |
| Verified one-peer foreground connection | User selects foreground session and grants notification permission | Stop discovery/advertising, bind the exact endpoint to a new service generation, start the service and 30-minute countdown |
| Foreground session active | App backgrounds | Stop sensitive features and Flutter-owned timers; preserve only the service-owned verified connection and bounded byte buffer |
| Foreground session active | App resumes | Rebind to the same generation, drain packets in order through Dart validation, issue receipts only after admission, keep Stop and remaining time visible |
| Foreground session active | Buffer limit, endpoint mismatch or invalid generation | Disconnect, clear memory and expose an interruption on next foreground entry |
| Foreground session active | User Stop, timeout, disconnect or process termination | Stop service/notification, disconnect, clear all memory; never restart automatically |
| Any stopped state | App resumes | Remain stopped; require a new explicit discovery and verification flow |

## Acceptance matrix before implementation can be described as working

| Gate | Required evidence | Current status |
| --- | --- | --- |
| Static/native | Manifest service/permissions/type, non-exported service, `START_NOT_STICKY`, notification privacy and bounded counters reviewed | Not implemented |
| Flutter/controller | Opt-out preserves today's teardown; Android opt-in splits sensitive-state teardown from transport continuity; iOS remains foreground-only | Not implemented |
| Android emulator | Explicit start only, permission denial, private notification, both Stop controls, 30-minute expiry via controlled clock, ordered drain, no early receipt, overflow disconnect, process/task removal and stale-generation rejection | Not run |
| Existing regressions | Flutter suite, Android APK, iOS simulator/unsigned-device build, installed-APK navigation/native fixtures and desktop tests remain green | Required after implementation |
| Two physical Android phones | Both roles, screen off/Home/app switch, text and work-status receipts after resume, range loss, force-stop, notification denial, battery observation and exact OS/device/build record | Not run |

Emulator evidence cannot establish radio continuity on physical phones. Until the physical two-Android gate passes, documentation must continue to say that Lantern stops communication when backgrounded. Android–iPhone communication, production signing, independent security review, measured battery impact, guaranteed background execution and emergency-service contact remain unverified and outside this contract.
