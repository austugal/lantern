# Verification record

## Passed in this environment

- Dart source parsing and formatting for lib/, test/ and tool/.
- Standalone protocol check: 10,019 checks, including Unicode, version/size validation, invalid coordinates, receipts, revocation and 10,000 malformed fuzz inputs.
- iOS property-list parsing and Android XML parsing.
- Git whitespace/diff check.

## Not run

- Flutter analyzer, widget/controller test suite, Android APK build, iOS build, physical-device radio/location tests.
- Local Flutter setup was stopped by automatic approval review after an unexpected request to cloud metadata address 169.254.169.254. The blocked setup was not retried; only the installed Dart binary's offline parsing/formatting and standalone protocol checks were used.
- GitHub publication and Actions: integration returned HTTP 403, `Resource not accessible by integration`, on branch creation. CLI Git also lacked push credentials. No remote modifications or PR were made.

Do not interpret source completeness or the offline checks as native build validation. Run the included CI workflow and physical-device acceptance checklist after restoring repository write access.
