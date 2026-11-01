# MeshCore companion and ownership milestone — 1 November 2026

## Result

[PR #22](https://github.com/austugal/lantern/pull/22) adds an independent MeshCore BLE companion client under **Field tools → MeshCore radio**. Compatible external firmware provides LoRa routing; Lantern implements discovery, existing-channel selection, short UTF-8 channel text and explicit inbox retrieval. It neither flashes firmware nor changes region, channel keys or radio configuration. The radio's generic OK is labelled **Accepted by radio**, never recipient delivery. Firmware inbox reads consume queued items; a confirmation explains that direct/data items are not displayed by this bounded subset.

Session generations protect command replies, connection opening and delayed cleanup. Commands are serialized and bounded; uncertain sends are not automatically retried. Backgrounding and leaving the screen invalidate the session. Radio/PIN/channel-key bytes are not exposed or persisted. No GPS sharing, nearby-to-LoRa bridge, media or background radio session is added. See [setup and protocol sources](../mobile/docs/MESHCORE.md).

Ownership changes reserve rights in new original additions and modifications first published under the new terms, while preserving MIT grants through baseline `54acce7f3b8374ef26e0581f36aad8267adea6fd` and third-party licences. Notices are bundled in the phone app, wheels and desktop/mobile downloads. Lantern™ branding claims no verified registration or entitlement to ®. No registration application was submitted by this workflow.

## Validated source

Final PR head `14ca1561536fc91706911a9c272c41c7a05a3a35` merged as `d9538c0445a2a78063c2e42a5ba488da2c204e06`. Local index and merged source tree both equal `e533edffb98a5a06968d32c6d100f6fc2a17cb58`.

- [PR mobile validation 41324733436](https://github.com/austugal/lantern/actions/runs/41324733436): formatting, clean analysis and **165 Flutter tests**; Android APK, iOS simulator and unsigned device builds; **13 actual-APK navigation checks** and **two native fixtures**. The radio and licence screens were opened without starting a radio scan.
- [PR Python CI 41324733321](https://github.com/austugal/lantern/actions/runs/41324733321): **118 tests** (91 core plus 27 evidence-tool cases), lint/format and strict typing on Python 3.10/3.12/3.13.
- [PR desktop packaging 41324733365](https://github.com/austugal/lantern/actions/runs/41324733365): Linux, Windows and macOS packages and executable checks passed. The Windows archive and wheel were inspected for the correct root/legacy notices, normalizing Windows line endings.
- Local Python tests, lint/format, strict typing, link/notice checks and smoke-parser fixture passed. Local Flutter dependency setup was blocked by automatic approval review following an attempted cloud metadata-endpoint contact. It was not retried; GitHub's existing CI supplied mobile validation instead.

Main validation initially failed before onboarding: the retained UI tree showed Pixel Launcher, the crash buffer was empty, and system logs showed the requested Lantern activity being force-removed immediately after `clearApplicationUserData`, despite `am start` returning OK. Both instrumented native fixtures passed. Only the failed emulator stage and dependent publication were retried using the existing built APK; no application source or test gate was weakened.

[Main Python CI 41326475941](https://github.com/austugal/lantern/actions/runs/41326475941) repeated all 118 checks on Python 3.10/3.12/3.13. [Main desktop packaging 41326475869](https://github.com/austugal/lantern/actions/runs/41326475869) passed all three platforms and published [desktop-preview-d9538c0445a2](https://github.com/austugal/lantern/releases/tag/desktop-preview-d9538c0445a2). [Main mobile validation 41326475834](https://github.com/austugal/lantern/actions/runs/41326475834), completed on attempt 2 after the startup-only failure above, passed 165 Flutter tests, Android/iOS builds, all 13 APK checks, both native fixtures and publication. [Mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-d9538c0445a2) published on 1 November 2026 at 16:56:54 UTC, targeting the exact merge commit. It contains the Android testing APK, iOS simulator ZIP, unsigned device ZIP, proprietary/legacy notices and checksums. The published APK SHA-256 is `23531cdee9a7ddeca69c92d96edd58831c515483218b1d344800632b09faa50b`, verified from GitHub's release asset digest. No application or test-gate change was needed for the retry.

The [PR-tested dependency graph](validation/MESHCORE-2026-11-01-pubspec.lock) is an evidence snapshot, not the active build lockfile. SHA-256: `3e762ecf423f1115f2369527042a53b3e357b83889b98cc5251e46f1e8b3413b`. The final PR validation artifact's ZIP digest was verified before extracting it. The direct BLE client is 5.4.0; the resolved mobile adapter is 5.4.2 and platform interface 5.6.0.

## Remaining hardware gates

Physical MeshCore radios were unavailable. No real BLE pairing, MTU/notification behaviour, mesh delivery, range, repeater coverage or battery result is claimed. Test both phone platforms and firmware versions with actual radios. Existing Nearby Android–iPhone transport interoperability, background messaging, signed real-iPhone installation, production signing and independent security review remain outstanding.
