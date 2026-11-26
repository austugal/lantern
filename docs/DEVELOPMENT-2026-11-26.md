# Rejected-endpoint ledger validation — 26 November 2026

Inspected main `f73be8262559341aa095d6d0ad142809d06022b8`, README, roadmap, recent work records, PRs and CI. PR #49 was the sole open PR and owned this milestone; no fresh conflicting Finish Flutter Repo ownership was retrieved. Complete its validation and integration rather than duplicate it.

[PR #49](https://github.com/austugal/lantern/pull/49) passed [mobile CI](https://github.com/austugal/lantern/actions/runs/45621012507), including Android APK/emulator, both iOS builds, 168 Flutter tests, 77 rejected-ledger assertions and 124 callback checks, plus [Python CI](https://github.com/austugal/lantern/actions/runs/45621012467). It merged on 26 November as `441b27b8636b99566b201c871ebe0bd146f55203`, with tree `d322149a6d0c30ebcf94cff4be520c8035259671` identical to validated head `bb91ecf2962d99590af570338f045d231147fc8c`.

## Result and limits

The standalone ledger retains at most 100 rejected identifiers, closes admission at capacity without eviction, and bounds identifier length. It has no reset. Invalid rejection closes admission without retention; invalid queries are read-only. Its future owner must serialize admission and generation transitions. MainActivity does not call the ledger; current phone behavior is unchanged. Coordinated generation retirement, one-attempt ownership, Flutter event fencing, restart UI and physical same-peer validation remain open.

CI logs confirm the two iOS builds, 168 Flutter tests, 77 ledger assertions, 124 callback checks, 33 strict packet-decoder checks and the inbox fixture. Android emulator and Python matrix jobs passed. Prior local checks passed 136 Python tests and caught a delayed-closure mutation. This documentation-only integration does not repeat unchanged runtime tests or alter the validated code, dependencies or workflows.

## Release and ownership

The working [mobile](https://github.com/austugal/lantern/releases/tag/mobile-preview-60efb9a279a0) and [desktop](https://github.com/austugal/lantern/releases/tag/desktop-preview-60efb9a279a0) previews remain available. Main release builds for the new merge are separate gates; no new release is claimed here. The 6 November physical baseline and APK hash remain pinned.

Work is isolated on `docs/rejection-ledger-validation-20261126`. The primary agent owns documentation; the attribution specialist owns only temporary read-only evidence. Documentation validation checks relative links, whitespace and unchanged runtime/test/workflow files. No transport, consent, permission or resource-bound change is introduced. No physical-device, mixed Android/iPhone, background-delivery, production-signing or audit claim is added. Support evidence remains prepared and unsent.

[Main Python CI](https://github.com/austugal/lantern/actions/runs/45834018023) passed. [Main mobile](https://github.com/austugal/lantern/actions/runs/45834018078) and [desktop](https://github.com/austugal/lantern/actions/runs/45834018122) builds were running at this integration checkpoint. This document records PR validation, not a new published release.

The 26 November signed-out sidebar still lists Claude. API/history show only austugal: 105 commits before the merge, 106 after it. Exact snapshots and the unsent Support request are retained in the [attribution evidence](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md).
