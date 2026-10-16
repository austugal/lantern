# Mobile verification record

The root `.github/workflows/mobile.yml` is the authoritative build pipeline.
It runs Flutter 3.35.7 analysis and tests, Android debug APK compilation, iOS
simulator compilation, and an unsigned iOS device build.

Local checks: direct offline Dart formatting/parsing, 10,019 standalone packet
checks, Android XML and iOS plist parsing. Do not confuse these with a native build.

Initial CI caught four lint findings in the original foundation. Subsequent commits
fix those findings and add feature tests; use the latest workflow result rather
than an earlier run. Desktop validation is recorded separately in the repository's
`docs/DESKTOP-QA-2026-10-16.md`.

Physical radios, GPS on actual devices, permission denial on real OS builds,
background/sleep behaviour, battery use, screen-reader/large-text behaviour and
cross-device range still require the device checklist. No APK/iOS store publication
or independent security certification is implied by a successful compiler run.
