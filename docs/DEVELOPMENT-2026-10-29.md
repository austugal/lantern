# Development record — 29 October 2026

## Coordination and scope

Main inspected at `3b9a0e88899008b7e72fa0f69b617b49c5a1e5c0`. No open PRs were found, and the dated work records describe completed milestones. The prior field-instruments release completed its remaining emulator gate and published on 28 October at 22:37:07 UTC; it is not still failing validation. Mobile verification and the download links now record that completed release.

The bounded release-readiness milestone adds `ruff format --check .` to PR CI ahead of typing and tests. The desktop packaging workflow already required formatting; adding the same check before merge catches the concrete APK-harness formatting problem that previously reached main. No application, transport, permission, location/media/notification consent or background behaviour is changed. No SDK transport research is required for this CI-only change.

## Ownership and verification

The integrator owns `.github/workflows/ci.yml` and the gate regression check. The documentation specialist owns the current README, roadmap, changelog and verification updates. A read-only CI specialist reviewed the gate; completed results are recorded below.

The existing validated release passed 130 Flutter tests, Android/iOS builds, 11 installed-APK navigation checks, both native integration fixtures, 91 desktop tests and Linux/macOS/Windows package checks. Exact links and limitations are in [mobile verification](../mobile/docs/VERIFICATION.md). Physical compass, radio/GPS/battery tests, mixed Android–iPhone interoperability, production signing and independent security review remain outstanding.

## Completed gate validation

[PR #15](https://github.com/austugal/lantern/pull/15) adds the format check. [PR CI 40883610385](https://github.com/austugal/lantern/actions/runs/40883610385) passed the new gate, lint, typing and 91 tests on Python 3.10/3.12/3.13. Whole-repository local Ruff lint and formatting passed; the exact unformatted harness from main `7060afce7e971fec67824e8f562510e00bf2b98c` was replayed in a temporary directory and rejected by the new command with exit 1. A read-only CI specialist found no blocking issue. The change merged as `5cd5d468aa8c0baafc481eeb33791754328a23ef`; [main CI 40883788893](https://github.com/austugal/lantern/actions/runs/40883788893) passed.

Contributor API verification and retained-history evidence are in [the support packet](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md). The visible sidebar remains unverified today because the Browser tool was unavailable; no removal is claimed. No external support request was sent.

[Main desktop packaging 40883788809](https://github.com/austugal/lantern/actions/runs/40883788809) also passed all three platform builds, executable checks and publication. The mobile application was not changed by today's CI gate; its published Android/iOS validation remains run 40778887313.
