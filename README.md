# Lantern

![A robot writes Lantern — Stay connected. Even offline.](assets/lantern-robot.gif)

[View the still banner](assets/lantern-banner.png)

**Talk nearby. Share your location by choice. Keep control of your data.**

Lantern is an open-source communication tool with **mobile and desktop previews**. It is designed for people together in person: colleagues in a hotel, an event team, warehouse staff, friends or family. After installation, nearby conversations can work without an internet connection.

**[Download Lantern](https://github.com/austugal/lantern/releases)** · [Mobile setup](mobile/README.md) · [Desktop setup](docs/DESKTOP.md)

## Which download do I need?

| Your device | Download and use |
| --- | --- |
| Android phone | Download the Android [**testing APK**](https://github.com/austugal/lantern/releases/download/mobile-preview-928a3c3c4bed/Lantern-Android-testing.apk), open it on your phone and allow installation from that source when prompted. This is a development-signed testing app, not a Play Store release. |
| iPhone | The iPhone app has compiled successfully. [Mobile downloads](https://github.com/austugal/lantern/releases/tag/mobile-preview-928a3c3c4bed) include a **Mac simulator app** and an **unsigned device app**. Installing on a real iPhone still requires Apple signing and provisioning; there is no TestFlight or App Store release yet. |
| Windows | Download the Windows desktop ZIP, extract it and run `Lantern.exe`. No Python installation required for the packaged app. |
| Mac or Linux | Download the matching desktop archive and run `Lantern`. The local interface opens in your browser. Desktop binaries are unsigned; platform trust checks may apply. |

Keep the desktop and mobile downloads separate. They are two implementations and **do not yet talk to each other**.

## How does it work?

### Two phones

1. Install Lantern on **two Android phones** or **two iPhones with a signed build**. Keep both apps open and Wi-Fi/Bluetooth enabled.
2. Choose a display name and turn on Lantern. Grant the requested nearby-device permissions.
3. Select the other person. On Android, compare the code on both phones before accepting. On iPhone, confirm the invitation with the person before accepting; a display name does not verify identity.
4. Open the conversation and send a message. **Delivered** means the other app returned a receipt.
5. Share your location only if you want to. It has a stop button and a 15-minute limit.

Use the small **help buttons** for short instructions. Opening help does not start discovery, GPS or sharing.

Android connects to Android; iPhone connects to iPhone. Each mobile session supports **one connected peer**. Switching apps or locking the phone stops the session, cancels check-in timers and clears its messages. This preview has no background messaging.

### Two computers

1. Open Lantern on both computers and join the same Wi-Fi, LAN or hotspot.
2. Create/unlock each local profile with a passphrase.
3. In **Your circle → Add a person**, generate an invitation using each computer's LAN IPv4 address. Exchange invitations in both directions.
4. Compare all six safety-number groups over a trusted channel, confirm the pairing and allow messages.
5. Open **Conversations**. Use **Explain controls** to read what a button or field does before using it.

The desktop app uses the local network, not phone Bluetooth. A firewall or hotspot that isolates its clients can prevent a connection. `127.0.0.1` is only for testing on one computer. See [desktop troubleshooting](docs/DESKTOP.md).

## What can Lantern do now?

| Feature | Mobile | Desktop |
| --- | --- | --- |
| Private text messages | Encrypted nearby connection, receipts and visible failures | Signed and encrypted LAN messages with encrypted receipts |
| Disappearing messages | Optional 1-minute, 5-minute, 15-minute or 1-hour expiry | Optional expiry; session history stays in memory |
| Location sharing | Separate opt-in, stop button, 15-minute limit; stale fixes disappear | Separate, expiring permission; reported accuracy respected; stop/revocation controls |
| Local navigation | GPS breadcrumbs, named waypoints, distance and true-north bearing | Local waypoints, bearings and breadcrumb legs |
| Guardian alerts | Connected peer must accept the role; alerts do not automatically send location | Pre-authorized guardians; receipt separates network submission from app receipt |
| Check-in timer | Foreground only; cancels on disconnect or background | Runs while the desktop process is alive; requires a recent position at trigger time |
| Local profile | Saves your display name | Passphrase-protected encrypted vault |
| Simple instructions | Tappable help beside features | **Explain controls** mode |
| Offline guide | Searchable built-in guidance and a staff request template | Searchable built-in guidance and a staff request template |

Navigation gives a direction and straight-line distance, **not a road route or a safe path**. Mobile GPS requires permission and a usable fix. Desktop browser location may depend on an online provider; manually entered coordinates are supported and labelled.

Messages, coordinates, trails and waypoints are not saved as permanent history. Mobile trails and waypoints remain in memory until cleared or the app closes; desktop locking clears session data and timers. A recipient can still copy or screenshot information.

## Practical limits

- No Android-to-iPhone, phone-to-desktop or group-chat interoperability yet.
- No guaranteed distance or hotel-wide coverage. Walls, devices and radio conditions matter. The core's 1,000 m relay test is a **simulation**, not a measured radio range.
- No mobile mesh relay, LoRa bridge, voice calls, background rescue monitoring or mobile evidence vault.
- The instructions are **help text, not an AI assistant**. Online AI, local AI and telephone-style conversation are ideas for future work, not current features.
- No Wi-Fi password bypass, covert phone access, account intrusion or tracking someone through their phone number, email or username.

Lantern is an experimental preview. Do not use it as your only emergency communication system. An alert receipt is not a human response, and mobile guardian alerts do not currently have receipt confirmation.

## Privacy and security

There is no Lantern account server, advertising or cloud message relay. The desktop interface is served locally on `127.0.0.1`, requires a launch token and uses no external scripts, fonts or maps. Android uses Google Nearby Connections and Google Play services; that SDK can collect diagnostics under Google's policies. iPhone uses Apple's encrypted Multipeer Connectivity.

The desktop vault uses scrypt and ChaCha20-Poly1305. Its passphrase cannot be reset. Desktop permissions are signed, expiring and independently revocable. Desktop per-frame keys do **not** provide a complete double ratchet: compromise of a receiver key can expose previously captured traffic. Mobile relies on native transport encryption and has no independent cryptographic identity comparison on iPhone.

No independent security audit or immunity from hacking is claimed. For details, read the [threat model](docs/THREAT_MODEL.md), [desktop protocol](docs/PROTOCOL.md) and [mobile architecture](mobile/docs/ARCHITECTURE.md).

## Test results

| Area | Completed checks |
| --- | --- |
| Desktop | 91 Python tests; lint and strict type checks; integration checks; Windows, macOS and Linux builds and executable checks |
| Mobile | Flutter analyzer and **28 automated tests** passed; Android testing APK, iOS simulator app and unsigned iOS device app compiled |
| Mobile wire format | 10,019 standalone offline packet checks passed |

See [desktop QA results](docs/DESKTOP-QA-2026-10-16.md) and [mobile verification](mobile/docs/VERIFICATION.md) for evidence and limits. Real phone-to-phone radio, GPS, range and battery tests are still outstanding. A successful build does not prove those behaviours.

## Build from source

Desktop requires Python 3.10+. First installation downloads dependencies:

```sh
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -e .
lantern app
```

The source archive also includes `Start-Lantern.cmd` and `Start-Lantern.sh`. The encrypted desktop profile is stored in `~/.lantern/profile.lantern`. Keep the launcher running; Ctrl+C closes it and locks the vault.

Mobile uses Flutter 3.35.7; see [mobile build instructions](mobile/README.md). GitHub Actions builds preview downloads, and the release workflow publishes them. Store submission, production signing and notarization are not configured.

[Roadmap](docs/ROADMAP.md) · [License: MIT](LICENSE)
