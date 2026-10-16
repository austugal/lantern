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

Not verified: visual browser rendering (no browser binary available), two physical
computers, Windows/macOS native executables, mobile builds, BLE/LoRa hardware,
radio range, external security review or production code signing.

GitHub branch creation still returned `403 Resource not accessible by integration`.
No remote commit, pull request, release, merge or CI run was created here. The
archive includes a Git bundle and patch so the exact source can be imported.
