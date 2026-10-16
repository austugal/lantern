# Lantern

**Good company. No cloud required.** An open-source desktop preview for consent-first encrypted conversations on a shared LAN, Wi-Fi network or hotspot.

Lantern 0.3 builds a usable desktop interface on the Python core from PRs #1 and #2. It adds a real UDP transport, verified invitation flow, encrypted vault, messaging receipts, expiring sharing controls, guardian alerts, local waypoints and a breadcrumb route back.

**This is an experimental desktop preview, not an Android/iPhone release or an emergency service.** No security audit or physical radio-range validation has been completed.

## Start the app

Python 3.10+ is required for source installation. First setup needs internet to install dependencies; subsequent conversations do not.

- **Windows:** extract the source archive, then double-click `Start-Lantern.cmd`. Install Python with the `py` launcher first if necessary.
- **macOS / Linux:** run `./Start-Lantern.sh` in the extracted directory.
- **Packaged build:** run `Lantern` / `Lantern.exe`; your default browser opens the local interface.

Manual setup:

```sh
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -e .
lantern app
```

Use a passphrase of at least 12 characters. The encrypted profile is stored in `~/.lantern/profile.lantern`. There is no password reset. The browser interface is served only on `127.0.0.1`, requires a fresh launch token, and uses no external scripts, fonts or map services. Keep the launcher running; Ctrl+C locks the vault and closes the network connection.

Use **Explain controls** to turn on help mode. Select a button or field to see a short explanation without performing its action. Turn help off to use it normally.

## Connect two people

1. Run Lantern on both computers and join the same network or hotspot.
2. In **Your circle → Add a person**, enter each computer's private LAN IPv4 address and generate an invitation. Invitations expire after 10 minutes.
3. Exchange invitations in **both directions**, preview them, and compare all six safety-number groups in person or over an already trusted channel.
4. Confirm the matching numbers on both computers. Pairing alone grants no access.
5. Choose **Allow messages** on each person's card. Then open **Conversations**.
6. A message is **Received** only after an encrypted receipt returns. A successful socket send alone does not count as delivered.

The default `127.0.0.1` invitation address is only for testing two instances on one computer. For another computer, use its LAN address. Host firewalls or hotspot client isolation may block UDP. Reimport invitations after unlocking because the UDP port can change.

## Features and boundaries

| Feature | Current behaviour |
| --- | --- |
| Conversations | Signed, encrypted messages; app-level receipts; optional expiry; in-memory history |
| Pairing | Signed invitations, explicit LAN routes, complete safety-number comparison |
| Vault | Scrypt + ChaCha20-Poly1305; atomic writes; bounded file size and KDF cost |
| Permissions | Signed, expiring, independently revocable message/location/guardian scopes |
| Location | Opt-in, at most 15 minutes; reported device uncertainty respected; stale positions removed |
| Stop sharing | Explicit stop; hidden page/heartbeat watchdog; revocation retry |
| Guardian alerts | Only pre-authorized peers; encrypted receipt distinguishes submission from app receipt |
| Check-in timer | Runs in this desktop process; requires a position less than two minutes old at trigger time |
| Navigation | Local bearings, waypoint names and breadcrumb legs; no downloaded maps or safe-path routing |
| Mesh | Existing **simulator** supports opt-in relays; desktop transport is explicit-route LAN UDP |
| Packaging | Python wheel; PyInstaller workflow for Linux, Windows and macOS |

Location permissions and guardian permissions are separate. Browser geolocation may depend on an internet-backed provider and is not guaranteed offline GPS; manual coordinates are supported and labelled. Coordinates, messages, trails and waypoints are not saved by the desktop app. Locking clears them and cancels timers.

No BLE or LoRa hardware adapter, kilometre-range guarantee, automatic nearby-device scanning, Android APK, iOS app, full double ratchet, push notifications or background rescue monitoring is included. The 1,000 m test is a simulated relay chain, not a real-world measurement.

## Privacy and security

- No account, application analytics, internet relay or third-party asset requests.
- Only paired identities can pass signature and consent checks. Network routes are explicitly imported; no subnet scan is performed.
- The desktop interface rejects unauthorized API calls, foreign origins, forged hosts and oversized request bodies.
- Per-frame ephemeral keys do **not** provide full forward secrecy: a compromised receiver key can expose previously captured traffic. See [threat model](docs/THREAT_MODEL.md).
- Revocation is immediate on the issuing device. Offline recipients may retain previously received data until they reconnect or it expires. Copying and screenshots cannot be prevented.
- Guardian receipt means an app received the alert, not a human response. Sleeping/closed computers, stale location, network loss and denied permissions can prevent alerts. Do not rely on Lantern for safety-critical use.

## Development and validation

```sh
pip install -e ".[dev]" build pyinstaller
ruff check .
ruff format --check .
mypy
pytest -q
python -m build --wheel
pyinstaller --noconfirm --onefile --name Lantern --collect-data lantern packaging/launcher.py
```

The included desktop workflow builds on Linux, Windows and macOS and uploads preview artifacts. It does not publish a release automatically. Production code signing, notarization, platform testing and external security review remain release gates.

See [desktop setup and troubleshooting](docs/DESKTOP.md), [verification](docs/VERIFICATION.md), [roadmap](docs/ROADMAP.md), and [protocol](docs/PROTOCOL.md). License: MIT.
