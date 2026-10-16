# Verification — 16 October 2026

This release is an isolated snapshot based on PR #2 (`624073c`) plus the desktop
implementation. Branch: `finish/desktop-release`. The shared checkout was left
untouched after concurrent edits were detected. PRs #1 and #2 were not modified.

Completed locally on Linux x86-64 / Python 3.12:

- 91 passing pytest tests, including real UDP exchange between two local endpoints.
- Ruff lint and formatting; mypy strict checks.
- HTTP authorization, origin protection and static asset tests.
- JavaScript syntax check (Node).
- Python wheel build and Linux PyInstaller executable build.
- Packaged executable demo; packaged HTTP launch and vault create/lock/unlock checks.

GitHub access was restored on 16 October 2026. Source is published in PR #3:
https://github.com/austugal/lantern/pull/3

Cross-platform CI runs lint, formatting, strict typing, tests, wheel packaging and
executable demos on Linux, Windows and macOS. The separate core matrix tests Python
3.10, 3.12 and 3.13. See GitHub Actions for the outcome at each exact commit.

Initial CI exposed asynchronous loopback timing in macOS tests, a Python 3.10
resource-path compatibility issue, and a POSIX-only mode assertion on Windows.
Tests now allow bounded UDP delivery time and apply mode assertions only on POSIX;
the resource lookup uses Python 3.10-compatible chained joinpath calls.

A push to main publishes an experimental desktop prerelease only after all three
platform build jobs succeed. Downloads include platform binaries, wheel, documentation
and file checksums. They are not production code-signed/notarized.

Not verified: visual browser rendering, two physical computers, native mobile builds,
BLE/LoRa hardware, radio range, Windows ACL hardening or external security review.
