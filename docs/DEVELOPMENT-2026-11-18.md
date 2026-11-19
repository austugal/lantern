# Android duplicate connection results — 18 November 2026

Inspected main `a5a05d992289c47a3392031c65ea8be188a4f21b`, README, roadmap, active work records, open PRs and CI. No open PR or fresh competing callback ownership was found; retrieved Finish Flutter Repo context described earlier foundation work, not this slice. Latest runtime main `621b32a185d964dca31c6ac2371e4e29c17087e7` passed [mobile](https://github.com/austugal/lantern/actions/runs/43875157163), [Python](https://github.com/austugal/lantern/actions/runs/43875157053) and [desktop](https://github.com/austugal/lantern/actions/runs/43875156953) CI. Matching [mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-621b32a185d9) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-621b32a185d9) releases exist; no failed release needs repair.

## Bounded change

On isolated branch `fix/android-duplicate-result-20261118`, implement only the [attempt-isolation contract](../mobile/docs/ANDROID-ATTEMPT-ISOLATION-2026-11-17.md)'s duplicate-result rule. After success clears pending, another result previously entered REJECT and MainActivity called disconnectFromEndpoint on the established owner. The policy now ignores the running, current-generation connected endpoint before pending rejection, for either result status. No state mutation or duplicate event follows. Pending results and unrelated-peer rejection retain existing behavior.

[Google lifecycle documentation](https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/ConnectionLifecycleCallback) was rechecked on 18 November for result versus disconnect semantics. The regression supplies synthetic duplicates; it is not evidence that a physical SDK emitted this sequence. No transport, dependency, permissions, resource budget or background behavior changes.

## Ownership and verification

The primary agent owns the policy and documentation. A test specialist owns only the callback fixture; a separate specialist reviewed the guard and MainActivity read-only. Attribution review owns a separate temporary evidence appendix and performs no outreach.

- **87 JVM checks passed**: 53 retained and 34 added assertions. The new fixture fails against the baseline helper at `duplicate result attempted endpoint-wide disconnection`, then passes against this fix. It models MainActivity effects for success followed by duplicate success/failure, repeated results, unrelated endpoints, inconsistent pending state, pending failure, stopped state and null endpoint.
- Local compilation uses OpenJDK 21 with Java 17 source/target and warnings treated as errors. Existing Android CI uses JDK 17 and `--release 17`.
- **136 Python tests passed**; desktop source is unchanged.
- Independent source review and whitespace checks passed. Android APK/emulator, Flutter and both iOS builds are separate PR gates; local JVM tests do not substitute for them.

The coordinated discovery retirement, native/Flutter event fencing, duplicate-initiation and stale same-peer disconnect cases remain open. No physical-device, mixed Android/iPhone, production signing, background delivery or security-audit claim is added. The pinned 6 November physical-test baseline remains unchanged. Fresh attribution evidence still shows the Claude sidebar entry while API and main history are austugal-only; the Support packet is prepared and unsent.
