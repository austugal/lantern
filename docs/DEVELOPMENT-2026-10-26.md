# Development record — 26 October 2026

## Coordination and scope

Base inspected: `main` at `93ad5022a9f1e311d186a301fa79e7a8d87994f6`. GitHub listed no open PRs or issues and no active CI runs when work resumed. Tracked repository files contained no active work record or AGENTS instructions. The earlier local mobile worktree was left untouched; workspace maintenance later removed that checkout, so this milestone was reconstructed against the same unchanged base and revalidated.

The existing [mobile release](https://github.com/austugal/lantern/releases/tag/mobile-preview-e99ac83ace6f) passed [mobile release run 38904352555](https://github.com/austugal/lantern/actions/runs/38904352555), desktop builds and desktop CI. It remains the working download while this PR is validated.

This milestone implements bounded text delivery deadlines and explicit same-session retry. Native Android and iOS transport files, permissions, consent, background behaviour and desktop source remain unchanged. Mixed Android/iPhone communication still requires a separate transport milestone and physical devices.

## File ownership and review

- Controller specialist: `mobile/lib/src/controller.dart` only.
- Regression-test specialist: `mobile/test/delivery_retry_test.dart` and `mobile/test/delivery_retry_widget_test.dart` only.
- Read-only reliability reviewer: controller, protocol, UI and test inspection.
- Integrator: UI, documentation and CI evidence.

Review from the original implementation corrected two concrete issues: unresolved native-call accounting must survive reconnect, and an admitted draft must clear even when delivery is unconfirmed so another Send tap cannot generate a new ID from that retained text. Disappearing messages are deliberately excluded from retry to avoid extending the recipient's relative lifetime.

## Acceptance boundary

- Text native submission deadline: 10 seconds; receipt deadline: 30 seconds after submission.
- No automatic retry. Explicit same-ID ordinary-text retry, three submissions total.
- Eight pending text attempts and eight unresolved native text calls maximum; the latter budget survives reconnect.
- Dedicated session ledger accepts 1,024 text IDs without eviction. Accepted duplicates are acknowledged but not displayed again; new IDs at capacity are rejected without a false receipt.
- Late receipts can confirm delivery; stale native completions and errors cannot overwrite a new attempt or connection.
- No durable message queue, task acceptance, physical-device validation, signing or security-audit claim.

## Contributor attribution follow-up

GitHub's contributors API was checked again during this milestone. The current result and any visible-sidebar limitation are recorded in the run report; no history was rewritten and no support message was sent.

## Validation

Local and CI results are recorded in [mobile verification](../mobile/docs/VERIFICATION.md). Existing physical-device tests remain pending.
