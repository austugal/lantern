# First two-Android-phone validation

Use this walkthrough with [DEVICE-EVIDENCE](DEVICE-EVIDENCE.md) and the wider [physical acceptance checklist](../mobile/docs/DEVICE_TESTS.md). The working record is [evidence/android-baseline.json](evidence/android-baseline.json). It uses the existing validator schema; do not invent a second result format. The tester reports that the initial two-phone test worked and that further testing is required. This is a user-reported successful initial trial, not a completed ten-check baseline.

## Initial phone-test report

- Reporter: **Austugal**.
- Report received: **8 November 2026**; actual test date and duration not supplied.
- Overall observation: “first test show all works. but more testing require.”
- Phone A: **Samsung S Ultra**, as reported; exact model unconfirmed.
- Phone B: **Samsung Note A9**, as reported; exact model unconfirmed. This label is preserved rather than inferred to mean a different Samsung model.

No failure was reported in this initial trial. Individual feature results, Android and Google Play services versions, radio/internet conditions, installed APK identity, timing and battery measurements have not been supplied. The downloaded APK verification below does not establish which build was installed during this trial.

The existing JSON record now includes the reported device labels. Its test date remains empty because the actual date is unknown. All ten detailed checks retain `not_run`, meaning not documented as executed under this checklist; this does not negate the reported initial trial. None can yet be assigned an individual verified pass, failure or blocked result. Follow the sequence below to collect those observations. No reproducible defect has been established from the overall report.

## Exact build

- Release: [mobile-preview-68b3a3233a49](https://github.com/austugal/lantern/releases/tag/mobile-preview-68b3a3233a49).
- [Download Lantern-Android-testing.apk](https://github.com/austugal/lantern/releases/download/mobile-preview-68b3a3233a49/Lantern-Android-testing.apk).
- Source: `68b3a3233a49ef04d42a0ae27e46fd448fa103ff`.
- Size: **158,277,656 bytes**.
- SHA-256: `d147cb6952f3cfbc031a6812965de2eb4b085d25b56b67d64ce088419c252417`.

The file was independently downloaded and hashed again on 8 November 2026, matching GitHub's release asset digest and size. This verifies downloaded bytes, not installation or device behaviour. The pinned build predates PR #31 (`7ff14fe4777d0bcca20ccd764d9985e88bcf2fdc`); its added inbox expiry logic cannot be tested through this APK. The future session inbox is not a background messaging service.

On Windows, verify the downloaded file before transferring/installing the same file on both phones:

```powershell
Get-FileHash .\Lantern-Android-testing.apk -Algorithm SHA256
(Get-Item .\Lantern-Android-testing.apk).Length
```

## Configuration to report before starting

Label the actual phones **A** and **B**. Record model, Android version and Google Play services version for each (Settings → About phone / Software information; Settings → Apps → Google Play services → app/version information, with labels varying by vendor). No serial numbers, account details or precise location are needed.

Both phones need Android 7/API 24 or newer, Google Play services, Wi-Fi and Bluetooth. Record whether Location is enabled and the exact permissions requested. Do not pregrant permissions before the first-launch check. Use distinct display names such as Test A and Test B. Record existing installation versus fresh install, and confirm installation from the verified file on each; the visible app version alone does not prove the source commit. Do not erase existing data to obtain a fresh launch without considering what would be lost. If first-launch consent cannot be observed, record that check as blocked.

Start close together, about 1–2 metres apart. Record Wi-Fi access-point connection, internet/mobile-data availability, power-saving settings and screen timeout. Keep both apps visible and screens awake, except for the explicit interruption tests. For an offline phase, disable mobile data and disconnect from internet-connected access points while leaving Wi-Fi/Bluetooth radios enabled. If using airplane mode, re-enable both radios and record whether the OS permits it. Download/install before going offline. Do not claim offline operation from an online-only trial.

## Ten checks and observations

The order below runs permission recovery early; IDs match the existing validator. Use harmless test content and do not publish real conversations, pairing codes or coordinates.

| Order / record ID | Physical procedure | Evidence needed for pass |
| --- | --- | --- |
| 1 — `first_launch_consent` | Open each fresh installation without turning discovery on. Observe prompts, then deliberately tap Turn on. | No discovery/location request before user action; describe the prompts and their timing on both phones. |
| 2 — `permission_recovery` | On A, deny a requested nearby/location permission after Turn on. Observe the error and connection state. Grant the requested permission in Android app settings, return and deliberately retry discovery. | Clear error, no false connected state, recovery works after granting and retrying. Record exact denied permission and observed UI. Opening Settings may stop the session by design. |
| 3 — `connection_verification` | Discover the other phone. Select it. Compare the displayed authentication codes in person. Confirm on both phones. | Both see the intended peer, no automatic connection, codes match, both approvals required. Report that codes matched without publishing them. |
| 4 — `text_both_directions` | Send Unicode and multiline text A→B and B→A. Repeat with internet unavailable but local radios enabled. | Each receiving app shows correct content; each sender shows Delivered after an app receipt. Record direction, timing and online/offline conditions. Delivered is not proof of reading. |
| 5 — `text_retry` | Only if an ordinary non-expiring text reaches Delivery unconfirmed while the same connection survives: wait at least the 30-second receipt deadline, confirm Retry, observe recipient count and later receipt. Exercise the two-retry limit if possible. | No automatic resend, one recipient bubble for the reused ID, receipt updates correctly, at most three submissions total. If no safe reproducible missing-receipt condition exists, mark blocked. Disconnecting/reconnecting does not test same-session retry. Do not fabricate a fault or a pass. |
| 6 — `photo_both_directions` | Send a harmless image A→B and B→A. Observe camera/gallery permission timing, preview and receipt. Reconnect explicitly if the picker interrupts the session; record that interruption. | Complete images arrive both ways; Delivered follows full receipt. Record any failure, missing attachment or duplicate. Native submission alone is insufficient. |
| 7 — `voice_both_directions` | Send a short non-sensitive voice note both ways; manually play it on each receiver. Observe microphone permission and recording limit (30 seconds). | Both notes arrive and play only on request, with sender app receipts. Record duration, audio failures and any interruption. |
| 8 — `range_loss` | In a safe area, separate the phones until the actual connection is lost; attempt a message around the interruption. Reunite, rediscover and confirm pairing. | No false Delivered for an unreceived message; loss visible; a fresh conversation after reconnection, no automatic resend. Record estimated distance, obstacles and observed timing, without extrapolating a range claim. If separation is impractical, mark blocked. |
| 9 — `background_shutdown` | During a fresh session, use Home, lock screen and switch apps, checking A and B in turn and reconnecting between attempts. Return to Lantern each time. | Session stops, messages and timers clear, interruption notice appears; no hidden queue, automatic discovery, reconnection or sharing resumes. Record each action and device separately. |
| 10 — `foreground_endurance` | Reconnect. Record start time and battery % on both phones; keep both apps open continuously for at least 30 measured minutes. Exchange text at start, 10, 20 and 30 minutes. Record end time, both battery readings, charging state, brightness and any loss. | At least 30 continuous foreground minutes with observed successful exchanges, no crash/unexpected disconnect. Record actual duration and both batteries, not estimates. Interruptions must be reported; a restarted run is separate evidence, not silently combined. |

For every check report: **ID; pass/fail/blocked/not_run; A observation; B observation; elapsed time; repeat count if relevant**. A failed expected behaviour is `fail`; an unmet prerequisite preventing execution is `blocked`; an unattempted check is `not_run`. A partially attempted bidirectional check does not pass. Record failures even if a later retry succeeds, with both outcomes.

For a suspected defect record exact build, phone configuration, starting state, numbered reproduction steps, expected/actual result and frequency (for example 2/3 attempts). Redact screenshots/logs before sharing. No physical defect has yet been observed in this session; missing evidence is a validation blocker, not itself an app defect.

## Validate the real record

From the repository root, with the verified APK in that directory (or adjust `--apk-file`):

```sh
python tools/device_evidence.py validate docs/evidence/android-baseline.json --expected-commit 68b3a3233a49ef04d42a0ae27e46fd448fa103ff --expected-apk-sha256 d147cb6952f3cfbc031a6812965de2eb4b085d25b56b67d64ce088419c252417 --apk-file Lantern-Android-testing.apk
```

The 8 November preparation run verified the local APK and returned exit **1**. The unchanged evidence-tool suite also passed all **37 synthetic tests**; these are not phone observations.

Exit **1** is the current expected outcome: metadata and ten physical observations are incomplete. Exit **2** indicates invalid input or an artifact mismatch. Exit **0** only means the required human-reported fields and ten passing observations are present. It does not independently verify the phones or approve release. Keep the validator unchanged; do not weaken gates to turn missing results green.

Only reviewed, deliberately shared non-sensitive observations should be committed to this record. Keep raw recordings and private logs outside the repository.

## Remaining release limits

Even a complete baseline does not clear the wider device checklist, production signing, security audit, physical iPhone or MeshCore radio validation. No Android-to-iPhone, phone-to-desktop, group communication or background delivery is established. The pinned preview uses a development signing key. Neither this test nor the capability illustration establishes hotel-wide coverage, emergency reliability or a battery-life guarantee.
