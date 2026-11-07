# Record a two-Android-phone baseline

This offline Python tool prepares and checks **human-reported test records** for the first physical-device baseline. It does not operate phones, inspect an installed app, prove that an observation happened, certify security or approve a release. It covers ten communication/lifecycle checks, not the full [physical acceptance checklist](../mobile/docs/DEVICE_TESTS.md). Other checklist entries remain separate and pending.

## Prepare and record

From a source checkout with Python 3.10 or newer:

```sh
python tools/device_evidence.py template > android-baseline.json
```

The generated report starts incomplete. Fill in the exact app source commit and testing APK SHA-256, tester label, test date, network/radio conditions and two distinct physical phones labelled A and B. Record both phones' models, Android versions and Google Play services versions. Identical phone models are allowed; the tester must confirm that A and B are distinct physical devices. No serial number, account, precise location, guest information or message content is needed. Keep observations factual and omit sensitive data.

Run the ten named checks on the actual phones. Record `pass`, `fail`, `blocked` or `not_run` and an observation for each. For bidirectional media, check both directions and app receipts, not just native submission. Record retry duplicates, permission recovery, range-loss failures and background shutdown. For foreground endurance, observe a 30-minute session and record duration and battery readings from each phone; this is a measured observation, not a battery-life claim. Do not mark blocked or unexecuted checks as passed.

The pinned validated Android baseline artifact is [mobile-preview-68b3a3233a49](https://github.com/austugal/lantern/releases/tag/mobile-preview-68b3a3233a49), published 6 November 2026 at 14:11:45 UTC. Its source is `68b3a3233a49ef04d42a0ae27e46fd448fa103ff`; GitHub's APK digest is `d147cb6952f3cfbc031a6812965de2eb4b085d25b56b67d64ce088419c252417`, checked against the downloaded 158,277,656-byte APK on 7 November. Check the downloaded APK's hash against this value and ensure both phones use the intended build. The validator compares report fields against supplied expected values. With `--apk-file`, it also hashes the downloaded local file; it cannot verify installed binaries.

## Validate the record

```sh
python tools/device_evidence.py validate android-baseline.json \
  --expected-commit 68b3a3233a49ef04d42a0ae27e46fd448fa103ff \
  --expected-apk-sha256 d147cb6952f3cfbc031a6812965de2eb4b085d25b56b67d64ce088419c252417 \
  --apk-file Lantern-Android-testing.apk
```

Use a single line in Windows PowerShell, without the shell continuation backslashes. For a different artifact, deliberately supply its independently checked expected values; do not overwrite expected values merely to silence a mismatch.

| Exit | Meaning |
| --- | --- |
| 0 | All required metadata and ten passing observations are reported; not independently verified and not release approval |
| 1 | Structurally valid but incomplete, not run, blocked or failed; no complete-baseline claim |
| 2 | Invalid report/arguments, artifact mismatch, malformed/duplicate JSON, unexpected fields/types, invalid dates or oversized input |

The tool accepts at most 64 KiB, bounds text fields, rejects unexpected schemas/duplicate check IDs and treats observations as inert text. It makes no network request, executes no recorded command and uploads nothing. Report files are local plaintext; keep them outside committed test fixtures unless reviewed and intentionally published. Only fabricated test fixtures belong in unit tests. A manually fabricated report can still satisfy the schema, so a human must review the evidence.

A complete report establishes neither Android–iPhone support nor radio coverage, background delivery, signing, safety assurance or completion of the wider device checklist. Mixed-phone testing still requires the [SDK candidate gates](../mobile/docs/NEARBY-ADAPTER-CONTRACT.md) and a signed physical iPhone. Keep the working release available while collecting evidence.

## Downloaded APK integrity

`--apk-file` is optional. When supplied, the tool streams a regular, non-empty local file of at most 512 MiB and compares its SHA-256 with `--expected-apk-sha256`. Missing, unreadable, oversized or mismatched files fail with exit 2. It neither opens the APK as an archive nor executes it. Without this option, only report fields are compared. A matching downloaded file does not prove installation, APK structure, publisher identity, security or a physical test. Obtain the expected digest independently from the intended release; do not copy it from an untrusted report. A matching file does not turn an incomplete report into a passing one.
