# Android APK smoke startup repair — 2 November 2026

## Report and cause

Tiago's GitHub failure email was for the first attempt of [main mobile run 41326475834](https://github.com/austugal/lantern/actions/runs/41326475834), completed on 1 November at 16:44:57 UTC. Its targeted retry had already passed and published the d9538c0445a2 preview. There were no current failing Lantern jobs when this repair began.

The retained first-attempt evidence showed the launcher, an empty app crash buffer and Android force-removing Lantern's activity immediately after `clearApplicationUserData`, before its process started. The fixture called `pm clear` immediately before `am start`. This repair removes that startup race rather than relying on another manual retry.

## Change

The APK check now verifies that Lantern is absent from the test device, installs without replacement or runtime-permission grants, and verifies that the expected package is registered before launch. A pre-existing installation or failed package query stops the test before installation; existing application data is never cleared by the smoke helper. The fresh AVD used by CI meets this precondition. Installation output is retained with the other evidence.

The onboarding and 13 navigation checks remain required. Install, launch and genuine application failures still fail the gate; no generic restart/reinstall recovery was added. The exact Pixel Launcher ANR handling remains unchanged. Phone application code, firmware/radio behaviour, permissions, licence terms and hardware-validation limits are unchanged.

## Validation

Eight regression cases cover fresh installation, protection of an existing installation, failed package lookup, failed installation, an unregistered APK, exact package-name matching, activity launch errors and preservation of genuine app-startup failures. The repository root is added to pytest's import path so CI can test the in-repository helper without packaging it into Lantern.

Local checks passed: all 126 Python tests, Ruff lint/format, strict mypy, XML parser fixture and whitespace checks. Native/emulator execution and publication evidence is recorded below and in the [mobile verification record](../mobile/docs/VERIFICATION.md). These synthetic cases are not physical-device tests.

Package checks use `pm list packages` and an exact package line. Android’s [`pm path` implementation](https://android.googlesource.com/platform/frameworks/base/+/daeda6e736322ae2a7119f2715dc06626e6ce479/services/core/java/com/android/server/pm/PackageManagerShellCommand.java) returns exit status 1 for an absent package, so it is unsuitable for a success-only absence check.

## Merged validation

[PR #24](https://github.com/austugal/lantern/pull/24) merged validated head `f15459352a7ababc375376d2a3131e875e3b1757` as `a59edf05c3bccb712775a8a7abc8f5b98e166f85`. Both have tree `51b643ce5aa39c1862d2691a093678ec055d085d`.

- [PR Python CI](https://github.com/austugal/lantern/actions/runs/41462940344): 126 tests on Python 3.10/3.12/3.13, lint, formatting and strict typing passed.
- [PR mobile CI](https://github.com/austugal/lantern/actions/runs/41462939265): 165 Flutter tests, format/analyzer, Android APK, iOS simulator and unsigned device builds, 13 installed-APK navigation checks and two native fixtures passed. The repaired emulator check passed on its first attempt, without a manual retry.
- [PR desktop packages](https://github.com/austugal/lantern/actions/runs/41462939616): Linux, Windows and macOS packaging/executable checks passed.
- [Main Python CI](https://github.com/austugal/lantern/actions/runs/41466114604) and [main desktop packages](https://github.com/austugal/lantern/actions/runs/41466114536) passed. The [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-a59edf05c3bc) targets the merge commit.

## Main publication

[Main mobile run 41466114554](https://github.com/austugal/lantern/actions/runs/41466114554) repeated all mobile gates successfully, including all 13 APK navigation checks and both native fixtures on the first attempt. [Main Python CI](https://github.com/austugal/lantern/actions/runs/41466114604) and [desktop packages](https://github.com/austugal/lantern/actions/runs/41466114536) also passed. [Mobile preview](https://github.com/austugal/lantern/releases/tag/mobile-preview-a59edf05c3bc), published 2 November at 15:12:06 UTC, and [desktop preview](https://github.com/austugal/lantern/releases/tag/desktop-preview-a59edf05c3bc) both target `a59edf05c3bccb712775a8a7abc8f5b98e166f85`. The published Android APK's GitHub SHA-256 digest is `a7379adc261d28bfcf8a4f01cb95901518cc3d26cfaa34ac1e0a5ec2b9e30922`. Current download links and the physical-baseline artifact example refer to this release.

These are automated build/emulator results. Physical phone/radio acceptance and real-iPhone operation remain unexecuted; the unsigned device archive still requires Apple signing and provisioning.
