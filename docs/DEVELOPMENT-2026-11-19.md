# Duplicate-result validation recovery — 19 November 2026

Inspected main `a5a05d992289c47a3392031c65ea8be188a4f21b`, README, roadmap, development records, open PRs and CI. PR #42 is the only open PR and owns the duplicate-result work. No fresh conflicting Finish Flutter Repo ownership was retrieved. Continue that milestone rather than start another runtime change. The latest released runtime `621b32a185d9` passed mobile and desktop publication; the pinned physical-test baseline remains unchanged.

[PR #42](https://github.com/austugal/lantern/pull/42) head `f782e57c64828173cf319168ad35878b6d13b4a0` passed [Python CI](https://github.com/austugal/lantern/actions/runs/44311137167). Its [mobile run](https://github.com/austugal/lantern/actions/runs/44311137106) passed Flutter analysis and 168 tests, Android APK compilation, 87 JVM callback assertions, installed-APK emulator scenarios and both native fixtures. The iOS job was cancelled after 15 minutes with no assigned runner and no steps recorded. Its log endpoint returned BlobNotFound. A read-only specialist retrieved the public check-run annotations: GitHub reported failure to acquire a hosted runner after multiple attempts, with three macOS arm64 capacity notices. This identifies runner capacity/acquisition as the validation failure, not a compiler error.

Retried only the cancelled iOS job on unchanged source. The retry acquired a macOS runner. Successful prior jobs are reused, not represented as newly rerun. No code, SDK, workflow or test gate was weakened. [PR #42](https://github.com/austugal/lantern/pull/42) passed [mobile CI attempt 2](https://github.com/austugal/lantern/actions/runs/44311137106/attempts/2), including both iOS builds after a hosted macOS capacity cancellation. Android APK/emulator, 168 Flutter tests, 87 JVM callback checks and [Python CI](https://github.com/austugal/lantern/actions/runs/44311137167) passed. It merged as `8be0e3ec3bea4fb3b670ac2c4b9e05aa3e0a52ab`. Main release publication remains a separate gate; the prior working release and pinned physical baseline are preserved.

Primary agent owns this documentation; attribution specialist owns only the temporary evidence appendix. Fresh signed-out sidebar still shows Claude despite austugal-only main/API history. The exact Support packet remains prepared and unsent. Same-peer retry ambiguity, native/Flutter generation fencing, physical-phone validation, mixed Android/iPhone transport and production signing remain open.

## Original PR #42 iOS cancellation — checked 19 November 2026

Original job: https://github.com/austugal/lantern/actions/runs/44311137106/job/134825278751

Public REST job response dated **19 November 2026, 13:15:23 UTC**:

- Status `completed`, conclusion `cancelled`.
- Started `2026-11-18T13:11:12Z`; completed `2026-11-18T13:26:12Z` (15 minutes).
- `runner_id: 0`, empty `runner_name`, `steps: []`.

Check-run API: https://api.github.com/repos/austugal/lantern/check-runs/134825278751

Annotations API: https://api.github.com/repos/austugal/lantern/check-runs/134825278751/annotations

The check run contains four annotations:

1. Failure: “The job was not acquired by Runner of type hosted even after multiple attempts”.
2. Three identical notices: “Due to capacity constraints, jobs targeting macOS arm64 runners may experience longer queue times.”

These annotations identify hosted-runner acquisition and capacity as the reported problem. This cancelled attempt contains no compiler/test result and does not establish an application defect. A rerun's outcome must be recorded separately; this check did not inspect or claim rerun success. The original page could not be retrieved by web search (DisabledError); the evidence above is the public REST response, not a rendered page observation. No workflow, job, repository setting or credential was changed by this check.
