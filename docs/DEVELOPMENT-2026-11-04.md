# Downloaded APK integrity — 4 November 2026

Inspected main `db808fcebb75a0143ff42029a69b245348d364b1`, README, roadmap, dated work records, branches, open PRs and agent inventory. No open PR, live competing agent or current overlapping tracked work claim was found. Latest mobile run 41652190175, Python run 41652190243 and desktop run 41652190315 were successful. No failing release required repair.

## Bounded milestone

The physical-baseline evidence tool now accepts optional `--apk-file`. It hashes downloaded bytes in 1 MiB chunks, caps the file at 512 MiB, rejects empty/nonregular/symlink inputs and hash mismatches, and detects ordinary file modification or replacement while reading. Expected hashes remain independently supplied by the operator. This does not establish APK structure, publisher provenance, signing, installation or physical testing. No archive extraction or network access is added. Existing metadata-only use and incomplete-report exit codes remain unchanged.

## Verification

Local Ruff lint/format, strict mypy and all 135 Python tests passed, including 36 evidence-tool tests. PR CI results are recorded in the pull request. Tests use synthetic byte files and fabricated reports, never physical phones. Current Android/iOS application evidence remains the successful [3 November mobile run](https://github.com/austugal/lantern/actions/runs/41652190175), including 168 Flutter tests, Android APK, iOS simulator and unsigned device builds, 13 installed-APK checks and two native fixtures. This milestone changes no mobile source, transport, permission or lifecycle behavior. The [current mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-ae0b65b85f6f) remains available.

Physical two-phone testing, Android–iPhone implementation, background-session implementation, production signing and independent security review remain pending. No message was sent to GitHub Support; contributor evidence records today's API result and the unavailable sidebar check separately.
