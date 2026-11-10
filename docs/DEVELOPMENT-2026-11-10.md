# Mobile release recovery — 10 November 2026

Priority was the failed main release gate, ahead of new application work. Inspected current main 59df59a, README, roadmap, PR #35, dated work records and CI. The separate 9 November build-error investigation had identified an external dependency download failure and left GitHub unchanged; no competing source repair was found. PR #35's Android, iOS, Flutter, JVM and Python checks all passed, and was left unmerged so this recovery could validate the existing main release independently.

## Root cause and narrow repair

Main mobile run [42632639391, attempt 1](https://github.com/austugal/lantern/actions/runs/42632639391/attempts/1) built the APK and passed its installed smoke checks (apk_smoke_exit=0). The subsequent WebView fixture rebuild failed resolving Kotlin 2.0.21 because Maven Central returned HTTP 403 for kotlin-stdlib, kotlin-gradle-plugins-bom and kotlin-gradle-plugin-api POMs. The job reported webview_integration_exit=1 and uninstall_exit=0. This was not an assertion failure in Lantern. The iOS job was cancelled; publication was skipped.

The repair is a retry of the unsuccessful workflow jobs on the same commit. No dependency versions, repositories, credentials, validation gates or runtime behavior were changed. The matching PR #35 checks had succeeded with the same dependency configuration; that supports a transient dependency-host/runner failure rather than a necessary source fix, without establishing the provider's underlying cause.

## Boundaries

Keep the pinned physical-test APK and user-reported Samsung trial unchanged. Do not treat the template as a completed ten-check physical baseline. Desktop builds on main remain successful. No physical tests, background operation, Android–iPhone delivery, signing or security audit were performed in this recovery.


## Verified outcome

[Attempt 2](https://github.com/austugal/lantern/actions/runs/42632639391/attempts/2) passed the retried Android emulator job and both iOS builds, then published [mobile-preview-59df59a4c131](https://github.com/austugal/lantern/releases/tag/mobile-preview-59df59a4c131). Successful Flutter and Android compilation results from attempt 1 were reused; they were not represented as newly executed tests. No source change was necessary. All main release gates are now successful. PR #35 remains a separately validated, unmerged candidate.

The documentation-only recovery record was checked with git diff --check and 76 relative Markdown targets. Contributor recheck remains in the separate Support evidence document. No new physical observations were recorded.
