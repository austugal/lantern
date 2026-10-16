# Desktop preview

## Two instances on one computer

```sh
lantern app --data-dir ./alice
lantern app --data-dir ./bob
```

Each process opens its own private local link. Use `127.0.0.1` in both invitations. Create the vaults, exchange both invitations and compare safety numbers. Allow incoming messages on both sides. Neither pairing nor setting a local position automatically grants location access.

## Two computers on a private network

Use each computer's LAN IPv4 address in its invitation (for example 192.168.1.20). The UI header shows the UDP port. Permit that app/port through the firewall only on trusted private networks. Do not forward it on your router or expose the local UI to the internet. Networks with client isolation can prevent communication even when both computers show the same Wi-Fi name.

If a message stays unconfirmed: check both apps are unlocked, routes were imported in both directions, the recipient allowed messages, clocks are reasonably accurate, and the network allows peer traffic. Reimport invitations after restarting/unlocking. UDP is best effort: no automatic message retry is implemented. Unconfirmed messages may already have arrived if the return receipt was lost; avoid duplicate resends of sensitive actions.

## Vault and session lifetime

The default path is `~/.lantern/profile.lantern`; `--data-dir` chooses another profile directory. Back it up while the app is locked and protect the passphrase. Private keys, paired identities, grants and pending revocations are persisted. Messages, local/remote positions, navigation history and check-in timers are not. Socket routes are reimported each session. Live location/guardian grants do not resume automatically after unlock.

Locking cancels timers and revokes permissions locally before closing UDP. Revocations that cannot be delivered are retried after unlocking and reimporting a peer route, until the original grant expires. A peer can keep copies of what they received regardless of local controls.

## Location and check-in limits

The browser can request a device position. Desktop browsers often use network-based geolocation, so this is not a promise of offline GPS. Manual coordinates are supported; keep their reported uncertainty realistic. Navigation is geometric bearing and distance, not road directions, obstacle avoidance or a safe route.

Location updates stop when the app page is hidden; a server watchdog revokes sharing after 20 seconds without an active-page heartbeat. Location grants also have a monotonic 15-minute session cap. Received fixes expire after 120 seconds or grant expiry. Check-in uses a monotonic in-process deadline, but the process must remain alive and the computer awake. An overdue timer with a stale position displays a warning and waits for a fresh fix instead of inventing a current location.

## Public release checklist

- Exercise the app on two physical computers on Windows, macOS and Linux.
- Confirm packet loss, wrong passphrase, network loss, host sleep and denied geolocation behaviour.
- Complete keyboard/screen-reader and large-text review.
- Obtain independent review of protocol, cryptography, vault and browser-facing local service.
- Sign Windows executables and sign/notarize macOS builds before a broad consumer release.
- Provide an authenticated mobile transport and platform lifecycle implementation before promising APK/iOS support.

A Python wheel and a native Linux test executable can be built locally. Windows/macOS executables require the respective CI runners. Source launchers are provided so those users can run the app with Python before native artifacts are available.
