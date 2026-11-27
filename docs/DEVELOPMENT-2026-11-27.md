# Native foreground discovery admission — 27 November 2026

Inspected main `ed5a2a2f55819a54eaf1d106ba4ae65168b06137`, README, roadmap, recent ownership records, open PRs and CI. No open PR or fresh conflicting Finish Flutter Repo ownership was found. All prior main gates passed; mobile and desktop previews for `441b27b8636b` published on 26 November at 14:13:01 and 13:58:18 UTC respectively. Work is isolated on `fix/android-permission-lifecycle-20261127`.

## Boundary and repair

Dart checks foreground state before sending a start request, but native method-channel handling is asynchronous. The native `handle(start)` previously had no visible-activity check before shutdown, permission requests or advertising; the final `start(result)` boundary also set running without checking visibility. A call delivered after `onStop` could therefore enter those paths while the native foreground flag was false. This is a source-level admission gap, not a claimed physical-device reproduction.

Initialize the flag false until `onStart`, reject stopped calls before permission/state changes, and check again before SDK start. Preserve the existing visible `onStart`/`onStop` semantics; do not move discovery shutdown to `onPause`, which can occur with temporary focus loss. Ordinary permission results arriving after `onStop` were already ignored because shutdown clears the pending result; do not misidentify that path as the reproduced bug.

The repair introduces no transport migration, automatic restart, background service, consent change or new app permission. Full same-peer attempt isolation remains a separate open item.

## Verification and ownership

The primary agent owns MainActivity guards, emulator script/workflow wiring and documentation. The lifecycle specialist owns only Android instrumentation test source and test Gradle configuration, and reviews primary lifecycle documentation. The attribution specialist owns only a temporary evidence appendix.

All 136 Python tests passed; shell syntax and whitespace checks passed. Native instrumentation is added to the emulator publication gate, alongside the existing downloaded-APK smoke and Flutter native fixtures. Its result is retained separately and any failure blocks publication. Android/emulator and iOS PR validation remain pending; no emulator pass or physical-device result is claimed before those jobs complete.

The [working mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-441b27b8636b) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-441b27b8636b) previews and pinned 6 November physical baseline remain preserved. No production signing, mixed-platform, background-delivery or independent security-audit claim is added. The 27 November contributor API/history still contain only austugal across 107 commits, while the signed-out sidebar shows Claude; exact evidence and the unsent Support request are retained in the [Support packet](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md).

Primary documentation reviewed on 27 November: [Android activity lifecycle](https://developer.android.com/guide/components/activities/activity-lifecycle), [ActivityScenario](https://developer.android.com/reference/androidx/test/core/app/ActivityScenario), and [AndroidX Test releases](https://developer.android.com/jetpack/androidx/releases/test). The two instrumentation tests move a real activity to CREATED through `onStop`, invoke each native start boundary and assert one state error without mutation, then resume and verify normal name validation. Reflection is test-only; no production test channel is added. Independent lifecycle/test review found no blocker. Test-only dependencies are pinned; execution remains pending CI.
