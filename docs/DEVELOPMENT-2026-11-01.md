# Development record — 1 November 2026

Inspected main `e9bb535ebe7a36d882e8392ff065ae76aa6b529b`, README, roadmap, dated work records, open PRs/issues and CI. No open PR or overlapping current Finish Flutter Repo claim was found. The 30 October mobile release run 41068600810, desktop CI 41068600774 and packaging 41068601103 remain successful; Android, iOS, checks, emulator and publish job conclusions were inspected individually. No earlier release needed repair.

## Bounded milestone and ownership

The first hardware priority remains two physical Android phones. This run cannot operate those phones, so it adds a concrete preparation tool: an offline bounded JSON record template and validator for ten communication/lifecycle baseline checks. The validator distinguishes reported completeness from independently verified evidence. It rejects malformed or mismatched artifact records and never treats pending, failed or blocked observations as complete. It makes no external request or recorded-command execution. It does not replace the full physical acceptance checklist.

The implementation specialist owns `tools/device_evidence.py`, the test specialist owns `tests/test_device_evidence.py`, and the integrator owns documentation, integration and validation on isolated branch `feat/device-evidence-validator-2026-11-01`. No native transport is changed, so no SDK migration is made. Android/iPhone interoperability, background delivery, physical range/battery tests, signing and independent security review remain open.

## Verification

Local full-suite checks passed with 117 tests before the additional numeric-overflow regression case; the final focused CLI suite passed 27 cases. Whole-repository Ruff lint/format and strict mypy passed. Independent review found no blocking issue; wording was corrected to distinguish the 64 KiB accepted limit from the extra byte read to detect overflow. PR/main CI and package results will be recorded after execution. The current mobile app, dependencies, permission flows, native adapters and published mobile artifacts are unchanged. Existing 147 Flutter tests are prior release evidence, not rerun or new physical validation for this tool. The expected release commit and APK SHA-256 were rechecked against the actual GitHub release on 1 November.

## Desktop validation prerequisite

PR packaging twice cancelled the macOS 14 job before any runner step/log. GitHub’s [runner retirement notice](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement/) schedules retirement for 2 November 2026 and recommends macOS 15 as a replacement. The desktop matrix now pins `macos-15`, matching the already-used iOS build host. This is a required packaging repair discovered during validation, not a transport change. New builds must pass all three platform/executable gates; successful execution on macOS 15 does not independently establish compatibility with every older Mac.
