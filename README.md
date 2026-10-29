# Lantern Comms

[Project contributors](CONTRIBUTORS.md)

![A robot writes Lantern — Stay connected. Even offline.](assets/lantern-robot.gif)

[View the still banner](assets/lantern-banner.png)

**Keep your team connected. Even offline.**

Lantern Comms, or **Lantern** for short, brings nearby messaging, location tools and practical offline help together for people working side by side.

Lantern is a **mobile-first, open-source nearby messaging tool** for Android and iPhone, with a separate desktop companion preview. The aim is simple: help colleagues exchange requests and updates when internet access is unavailable. After installation, phones communicate through their nearby radios; they still need Wi-Fi/Bluetooth enabled, suitable permissions and a working local connection. They do not need an internet-connected Wi-Fi access point for nearby messaging.

The current mobile preview connects **two phones of the same platform with both apps open**. It is a starting point for workplace trials, not yet a hotel-wide team network.

**[Download Lantern](https://github.com/austugal/lantern/releases)** · [Mobile setup](mobile/README.md) · [Desktop setup](docs/DESKTOP.md)

## Mobile app — Android and iPhone

| Your device | Download and use |
| --- | --- |
| Android phone | Download the Android [**testing APK**](https://github.com/austugal/lantern/releases/download/mobile-preview-3b9a0e888990/Lantern-Android-testing.apk), open it on your phone and allow installation from that source when prompted. This is a development-signed testing app, not a Play Store release. |
| iPhone | The iPhone app has compiled successfully. [Mobile downloads](https://github.com/austugal/lantern/releases/tag/mobile-preview-3b9a0e888990) include a **Mac simulator app** and an **unsigned device app**. Installing on a real iPhone still requires Apple signing and provisioning; there is no TestFlight or App Store release yet. |

Android uses Google Nearby Connections and requires Google Play services. iPhone uses Apple Multipeer Connectivity. The adapters do not yet connect Android to iPhone.

### How two colleagues use it on phones

1. Install Lantern on **two Android phones** or **two iPhones with a signed build**. Keep both apps open and Wi-Fi/Bluetooth enabled.
2. Choose a display name and turn on Lantern. Grant the requested nearby-device permissions.
3. Select the other person. On Android, compare the code on both phones before accepting. On iPhone, confirm the invitation with the person before accepting; a display name does not verify identity.
4. Open the conversation and send a message. **Delivered** means the other app returned a receipt.
5. Share your location only if you want to. It has a stop button and a 15-minute limit.

Use the small **help buttons** for short instructions. Opening help does not start discovery, GPS or sharing.

Ordinary text becomes **Delivery unconfirmed** if submission times out or no app receipt arrives within 30 seconds of submission. It may already have arrived. **Retry message** asks for confirmation and reuses its ID, with at most two retries in the same connection. Disappearing messages and attachments do not have this retry control. There is no automatic resend or retry after reconnection. A receipt still does not mean a colleague accepted a task.

For an ordinary non-expiring work request, choose **Request acknowledgement**. The connected colleague can accept or decline once. Their linked response has its own delivery receipt and retry status. Acceptance records that the colleague tapped Accept; it does not prove completion, escalation or supervisor approval. Requests and responses remain in the current foreground connection and clear on disconnect.

Android connects to Android; iPhone connects to iPhone. Each mobile session supports **one connected peer**. Switching apps or locking the phone stops the session, cancels check-in timers and clears its messages. This preview has no background messaging. When Lantern returns to the foreground after an interruption, a visible notice explains that nothing was queued. Restarting discovery requires a tap, and reconnecting still requires choosing and confirming the person again; location sharing, check-ins and messages do not restart.

### Mobile capabilities

| Feature | What the phone app does |
| --- | --- |
| Private text messages | Encrypted nearby connection, receipts, visible failures and optional one-time Accept/Decline request acknowledgement |
| Emojis, photos and voice notes | Emoji text, camera/gallery photo attachments and short recorded voice messages |
| Message notifications | Optional generic local alerts when messages arrive over an active session |
| Torch and SOS flash | Steady light or repeating Morse SOS; immediate Stop, switches off on background |
| GPS map | Optional online street map; save a small basic area offline before losing internet |
| Find me / I need help | Review and send coordinates, accuracy and fix time to the connected colleague |
| Disappearing messages | Optional 1-minute, 5-minute, 15-minute or 1-hour expiry |
| Location sharing | Separate opt-in, stop button, 15-minute limit; stale fixes disappear |
| Compass | Local magnetic-north heading, explicit Start/Stop, sensor and interference warnings |
| Calculator & measurements | Offline arithmetic, length/area/volume conversion, rectangle area/perimeter and box volume from entered dimensions |
| Local navigation | GPS breadcrumbs, named waypoints, distance and true-north bearing |
| Guardian alerts | Connected peer must accept the role; alerts do not automatically send location |
| Check-in timer | Foreground only; cancels on disconnect or background |
| Local profile | Saves your display name |
| Simple instructions | Tappable help beside features |
| Offline guide | Searchable built-in guidance and a staff request template |

Open **Field tools → Compass · find north** for the magnetic compass, or **Calculator & measurements** for offline calculations. Hold the phone flat, away from metal and magnets. The compass requires a heading sensor and stops when left or interrupted. It does not start GPS or send coordinates. Magnetic north differs from the true-north bearings calculated between GPS points. Measurements use dimensions you enter; this is not a camera tape measure or calibrated screen ruler.

Navigation gives a direction and straight-line distance, **not a road route or a safe path**. Mobile GPS requires permission and a usable fix. Desktop browser location may depend on an online provider; manually entered coordinates are supported and labelled.

The mobile map can save roads, building outlines and landmarks around a GPS position (about 500 metres) for offline viewing. It is a basic local map, not a complete city download or a live disaster map. Saving an area requires internet beforehand and confirmation to send its coordinate to the map-data provider. Online maps are opt-in. Saved areas remain on the phone until deleted. See [maps and finding a colleague](docs/MAPS.md).

Photo and voice messages use the same nearby connection, with or without internet present. Notifications do not extend radio range or enable background delivery. Camera, microphone and notification access is requested when used. Torch SOS is a visual signal only. “I need help” messages reach only the connected colleague; app receipt is not confirmation that someone read the request or that rescue is coming.

Messages, coordinates, trails and waypoints are not saved as permanent history. Mobile trails and waypoints remain in memory until cleared or the app closes; desktop locking clears session data and timers. A recipient can still copy or screenshot information.

## How hotels and other industries could use it

These are proposed pilot uses of the existing one-to-one messaging feature, not claims of deployed customers, automatic dispatch or built-in department channels.

| Workplace | Practical example |
| --- | --- |
| Hotel housekeeping | Two nearby attendants exchange a linen or supply request in a service area with poor internet access. Put the floor or work-area name in the message. |
| Hotel maintenance | A colleague sends “Maintenance request: service corridor, light not working; please acknowledge.” The recipient replies when they accept the task. |
| Hotel reception and operations | Nearby colleagues exchange a short operational handover during an internet outage, provided their phones can still connect locally. |
| Events and venues | A floor attendant asks a nearby coordinator for supplies or confirms that a meeting point is ready. |
| Warehouses and retail | Colleagues exchange an aisle/location and a stock request without using guest or public Wi-Fi. |
| Construction and field work | Nearby colleagues share a meeting point or routine progress update; optional coordinates are useful only where GPS has a usable fix. |
| Community groups | People together in person exchange updates when internet access is unavailable. |

**Example staff message:** “Housekeeping request — Floor 2 service cupboard — need towels — routine priority.” Use work-area labels rather than guest names or booking information, then choose **Request acknowledgement** if you need an explicit Accept/Decline response. The offline guide includes a template you can copy and edit.

Start with two same-platform phones and routine, noncritical tasks. Test the actual rooms, floors and service areas: walls and distance can break a connection. “Delivered” confirms app receipt, not that a colleague read or accepted the job; ask for a reply. Indoor GPS may be inaccurate, so room or area labels are often more useful.

Lantern may provide an additional local communication option during an internet outage, but it cannot guarantee communication during an emergency or reach emergency services. Keep established radios, telephones and emergency procedures available. Group channels, mixed Android/iPhone teams and locked-screen delivery remain future work.

## Desktop version — Windows, Mac and Linux

Desktop is a separate implementation for computers on a shared LAN, Wi-Fi network or hotspot. It does not currently connect to the phone app. Internet access is not required for local conversations, but a working local network is.

| Computer | Download and use |
| --- | --- |
| Windows | Download the Windows desktop ZIP, extract it and run `Lantern.exe`. No Python installation required for the packaged app. |
| Mac or Linux | Download the matching desktop archive and run `Lantern`. The local interface opens in your browser. Desktop binaries are unsigned; platform trust checks may apply. |

### Two computers

1. Open Lantern on both computers and join the same Wi-Fi, LAN or hotspot.
2. Create/unlock each local profile with a passphrase.
3. In **Your circle → Add a person**, generate an invitation using each computer's LAN IPv4 address. Exchange invitations in both directions.
4. Compare all six safety-number groups over a trusted channel, confirm the pairing and allow messages.
5. Open **Conversations**. Use **Explain controls** to read what a button or field does before using it.

The desktop app uses the local network, not phone Bluetooth. A firewall or hotspot that isolates its clients can prevent a connection. `127.0.0.1` is only for testing on one computer. See [desktop troubleshooting](docs/DESKTOP.md).

Desktop includes signed invitations and safety-number verification, encrypted messages and receipts, a passphrase-protected profile vault, separate expiring permissions, optional location sharing, guardian alerts, local waypoints and breadcrumbs. Its **Explain controls** mode and searchable offline guide explain each feature. See [desktop setup](docs/DESKTOP.md) for full instructions.

## Practical limits

- No Android-to-iPhone, phone-to-desktop or group-chat interoperability yet.
- No guaranteed distance or hotel-wide coverage. Walls, devices and radio conditions matter. The core's 1,000 m relay test is a **simulation**, not a measured radio range.
- No mobile mesh relay, LoRa bridge, voice calls, background rescue monitoring or mobile evidence vault.
- The instructions are **help text, not an AI assistant**. Online AI, local AI and telephone-style conversation are ideas for future work, not current features.
- No Wi-Fi password bypass, covert phone access, account intrusion or tracking someone through their phone number, email or username.

Lantern is an experimental preview. Do not use it as your only emergency communication system. An alert receipt is not a human response, and mobile guardian alerts do not currently have receipt confirmation.

## Privacy and security

**Secure communication is a core design priority.** Lantern is a working, open-source developer preview with downloadable builds and published automated test results. It is not an independently certified or audited security product.

- **Encrypted communication:** desktop messages are signed and encrypted; mobile sessions use the native platform's encrypted transport.
- **Explicit consent:** people accept connections; location sharing and guardian roles require separate choices.
- **Limited exposure:** location sharing expires, stale positions are removed, and mobile sessions end when the app backgrounds.
- **Reviewable releases:** download from this repository's release pages. The mobile release includes `SHA256SUMS.txt` for file-integrity checking; checksums do not prove a file is harmless.
- **Verified checks:** 91 desktop tests and 130 Flutter tests passed, and Android, iOS and desktop builds completed. These checks cannot guarantee that every device or real-world scenario is safe.

The Android APK uses development signing and desktop packages are unsigned. No “anti-hack”, malware-free or unhackable guarantee is made. Test on noncritical devices and workflows before operational use.

There is no Lantern account server, advertising or cloud message relay. The desktop interface is served locally on `127.0.0.1`, requires a launch token and uses no external scripts, fonts or maps. Android uses Google Nearby Connections and Google Play services; that SDK can collect diagnostics under Google's policies. iPhone uses Apple's encrypted Multipeer Connectivity.

The desktop vault uses scrypt and ChaCha20-Poly1305. Its passphrase cannot be reset. Desktop permissions are signed, expiring and independently revocable. Desktop per-frame keys do **not** provide a complete double ratchet: compromise of a receiver key can expose previously captured traffic. Mobile relies on native transport encryption and has no independent cryptographic identity comparison on iPhone.

No independent security audit or immunity from hacking is claimed. For details, read the [threat model](docs/THREAT_MODEL.md), [desktop protocol](docs/PROTOCOL.md) and [mobile architecture](mobile/docs/ARCHITECTURE.md).

## Test results

| Area | Completed checks |
| --- | --- |
| Desktop | 91 Python tests; lint and strict type checks; integration checks; Windows, macOS and Linux builds and executable checks |
| Mobile | Flutter analyzer and **130 automated tests** passed; Android testing APK, iOS simulator app and unsigned iOS device app compiled |
| Mobile wire format | 10,019 standalone offline packet checks passed |

See [desktop QA results](docs/DESKTOP-QA-2026-10-16.md) and [mobile verification](mobile/docs/VERIFICATION.md) for evidence and limits. Real phone-to-phone radio, GPS, range and battery tests are still outstanding. A successful build does not prove those behaviours.

## Build from source

**Mobile first:** use Flutter 3.35.7 and the [mobile build instructions](mobile/README.md). The Android and iOS native projects are in `mobile/`.

**Desktop:** requires Python 3.10+. First installation downloads dependencies:

```sh
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -e .
lantern app
```

The source archive also includes `Start-Lantern.cmd` and `Start-Lantern.sh`. The encrypted desktop profile is stored in `~/.lantern/profile.lantern`. Keep the launcher running; Ctrl+C closes it and locks the vault.

Mobile uses Flutter 3.35.7; see [mobile build instructions](mobile/README.md). GitHub Actions builds preview downloads, and the release workflow publishes them. Store submission, production signing and notarization are not configured.

## Copyright and licence

Copyright © 2026 Tiago Fitas (austugal). Lantern is distributed under the [MIT License](LICENSE). Existing third-party notices remain in place, including [Flutter scaffold attribution](mobile/docs/FLUTTER-LICENSE). This notice does not represent a copyright or trademark registration.

[Roadmap](docs/ROADMAP.md) · [Community introduction](docs/COMMUNITY-INTRODUCTION.md)

### Web reading on mobile

Open **Field tools → Web & saved pages** for basic HTTPS browsing while online. Explicitly download up to 20 public-page text snapshots for offline reading: useful for staff instructions, equipment guides and prepared reference material. Offline reading does not fetch new pages or preserve images, videos, forms or live services. JavaScript is disabled; interactive websites may not work. Saved text stays on the device until deleted and is not an encrypted vault. See [mobile instructions](mobile/README.md).

Offline web downloads fetch the public HTTPS page separately, without the browser’s cookies or signed-in session. Saved text may differ from what the browser displays; browser logins are not reused and content generated by scripts is not supported. The full address is requested again, so private or token-bearing links can still return sensitive text. The download is bounded and parsed as inert text, with no scripts executed.
