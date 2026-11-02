# Android APK smoke startup repair — 2 November 2026

## Report and cause

Tiago's GitHub failure email was for the first attempt of [main mobile run 41326475834](https://github.com/austugal/lantern/actions/runs/41326475834), completed on 1 November at 16:44:57 UTC. Its targeted retry had already passed and published the d9538c0445a2 preview. There were no current failing Lantern jobs when this repair began.

The retained first-attempt evidence showed the launcher, an empty app crash buffer and Android force-removing Lantern's activity immediately after `clearApplicationUserData`, before its process started. The fixture called `pm clear` immediately before `am start`. This repair removes that startup race rather than relying on another manual retry.

## Change

The APK check now verifies that Lantern is absent from the test device, installs without replacement or runtime-permission grants, and verifies that the expected package is registered before launch. A pre-existing installation or failed package query stops the test before installation; existing application data is never cleared by the smoke helper. The fresh AVD used by CI meets this precondition. Installation output is retained with the other evidence.

The onboarding and 13 navigation checks remain required. Install, launch and genuine application failures still fail the gate; no generic restart/reinstall recovery was added. The exact Pixel Launcher ANR handling remains unchanged. Phone application code, firmware/radio behaviour, permissions, licence terms and hardware-validation limits are unchanged.

## Validation

Seven regression cases cover fresh installation, protection of an existing installation, failed package lookup, failed installation, an unregistered APK, activity launch errors and preservation of genuine app-startup failures. The repository root is added to pytest's import path so CI can test the in-repository helper without packaging it into Lantern.

Local checks passed: all 125 Python tests, Ruff lint/format, strict mypy, XML parser fixture and whitespace checks. Native/emulator execution and publication results are recorded separately in the mobile verification record after CI completes. These synthetic cases are not physical-device tests.
