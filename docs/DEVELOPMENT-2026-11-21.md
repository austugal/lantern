# Established-peer initiation integration — 21 November 2026

Inspected main `b490f9b3d19fcfa60ed9a1b8529377042cb99603`, README, roadmap, active development records, open PRs and CI. PR #44 was the only open PR and owned this milestone; no fresh conflicting Finish Flutter Repo work was found. Completed its validation/integration rather than duplicating it.

[PR #44](https://github.com/austugal/lantern/pull/44) passed [mobile CI](https://github.com/austugal/lantern/actions/runs/44743330055), including Android APK/emulator, both iOS builds, 168 Flutter tests and 110 JVM callback checks, plus [Python CI](https://github.com/austugal/lantern/actions/runs/44743329849). It merged on 21 November as `008645ebcb65aa29dd86349045450234b2a033d7`, with tree `01673487e41531f51baa71b0d9b5f058af046d22` identical to validated head `0d7f5a03cf444901265ca0333ecf8bb029a205e8`.

The change prevents an initiation callback for the current running connected endpoint from invoking endpoint-wide rejection or reopening consent. It preserves the current peer, name, code and invitation timer. It does not identify SDK attempt identity or resolve duplicate pending initiation, registration collisions, same-peer retry ambiguity or event-generation fencing.

## Evidence and release boundary

CI logs confirm simulator and unsigned-device iOS applications compiled, Flutter completed 168 tests and the Java 17 callback fixture passed 110 assertions. Android APK and emulator jobs passed; Python CI passed. The earlier local negative regression demonstrated failure against the old helper, and 136 Python tests passed locally. These local checks were not unnecessarily rerun for this documentation-only integration.

The latest published [mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-8be0e3ec3bea) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-8be0e3ec3bea) previews remain available. Main build/publication for the new merge is separate from PR validation and must be checked before claiming a new release. The pinned 6 November physical-test baseline remains unchanged.

Work occurred on isolated branch `docs/android-initiation-integration-20261121`. The primary agent owns README, roadmap and verification updates; the attribution specialist owns only a temporary evidence appendix. Documentation verification checks relative links, whitespace and that runtime/test/workflow files match the validated merge tree. No transport, dependency, permissions, resource limits or background behavior changed during integration.

No physical-phone, Android–iPhone, production-signing or security-audit claim is added. Contributor Support evidence remains prepared and unsent.

[Main mobile](https://github.com/austugal/lantern/actions/runs/44911277672) and [desktop](https://github.com/austugal/lantern/actions/runs/44911277691) builds were in progress at this integration check; [main Python CI](https://github.com/austugal/lantern/actions/runs/44911277682) passed. No new release is claimed. Fresh attribution evidence still shows Claude in the public sidebar while main history is austugal-only.
