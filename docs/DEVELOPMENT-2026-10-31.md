# Development record — 31 October 2026

## Scope and coordination

Inspected main `275d9801dd5a6b9c833faa51a4ef12da758ee321`, README, roadmap, dated work records, open PRs and CI. No open PR or current overlapping Finish Flutter Repo work claim was found. The 30 October weekly read-only review recommends two physical Android phones as the next hardware milestone. Those devices are unavailable here; that gate remains unexecuted. No earlier release is failing: mobile run 41068600810, desktop CI 41068600774 and packaging 41068601103 are successful, with mobile/desktop previews at `b810cdf371a5` published on 30 October.

This bounded milestone completes the research/evaluation slice of roadmap priority 2: compare Google's Nearby Swift SDK with the current Android adapter before changing transports. It produces an [SDK evaluation](../mobile/docs/NEARBY-SWIFT-EVALUATION-2026-10-31.md) and a [method/consent mapping and physical acceptance matrix](../mobile/docs/NEARBY-ADAPTER-CONTRACT.md). A research specialist owns the SDK evaluation, the integrator owns adapter mapping and surrounding docs, and a separate specialist reviews the result read-only. Work uses isolated branch `docs/nearby-cross-platform-evaluation-2026-10-31`.

## Findings and validation boundary

Pinned upstream source inspection identifies revision `958f82f40dc8d2ec80a25fa1dae85cf70d415ef2`, declared iOS 13 / Swift 5.7 minima and a branch-based transitive dependency requiring a resolved lock. Current setup documentation and source README disagree about Apple radio mediums. Google's embedded Bonjour generator takes 12 hex characters while prose says 12 bytes; the deterministic service-ID calculation was checked independently. These are reasons to validate a pinned candidate, not proof that Lantern can connect mixed phones.

The mapping preserves service ID `org.austugal.lantern.v1`, point-to-point strategy, explicit mutual verification, 8,192-byte JSON packets, bounded media/calls, app receipts and foreground teardown. Any future hotspot-related location authorization must explain its distinct purpose and follow a user action; it cannot silently start coordinate sharing or copy startup prompting examples.

Documentation scope/whitespace checks passed and all 50 relative-link targets exist. Independent specialist review found no remaining blocker after correcting the native 30-second/controller 35-second invitation deadlines. Primary-source review validates this evaluation milestone. Existing Android/iOS/checks/emulator/publish job conclusions were inspected individually and all are successful. The release's 147 Flutter tests and 91 desktop tests remain prior release evidence; no new app tests, SDK build, package resolution or physical test was run for these Markdown changes. Application code, dependency locks, entitlements, permissions and desktop remain unchanged. No new binary release is made; the working 30 October downloads are preserved.

## Contributor limitation

At 13:24:16 UTC on 31 October the API listed only austugal, 61 contributions. The live loaded sidebar still showed austugal and claude. The [support packet](CONTRIBUTOR-SUPPORT-EVIDENCE-2026-10-29.md) now records this check alongside legacy refs and the exact support question. No support request, history rewrite or removal claim was made.
