# Changelog

## Mobile preview — explicit foreground reconnection recovery

- Background, native-stop and peer-disconnect events show a visible reason and state-clearing notice.
- Restarting discovery requires a user tap; reconnecting requires fresh peer choice and confirmation.
- Messages, requests, sharing, guardian and check-in state do not resume or queue.
- Delayed native request and consent failures cannot alter a newer session.
- A failed restart stays visible for an explicit retry or dismissal.

This remains one-peer, same-platform and foreground-only. No transport, permission, background service, automatic resend or persistent message queue was added. Physical-device lifecycle and radio validation remain outstanding.

## Mobile preview — bounded request acknowledgement

- Ordinary non-expiring text can explicitly request a human response.
- The connected recipient can accept or decline once; the decision is linked to the original request.
- Responses use the existing bounded text delivery, receipt, retry and duplicate protections.
- Unknown, late and conflicting responses are rejected without a false receipt.

This is current-session acknowledgement, not job completion, assignment, escalation or emergency dispatch. No transport, permission or background capability changed. Physical-device validation remains outstanding. The validated build is published as [mobile-preview-2baaffd3d1e2](https://github.com/austugal/lantern/releases/tag/mobile-preview-2baaffd3d1e2).

## Mobile preview — bounded text retry

- Text submission and receipt deadlines expose unconfirmed delivery.
- Confirmed manual retry reuses the original text ID, with three submissions total.
- Bounded session duplicate records and pending native calls prevent repeated retries from growing without limit.
- Late receipts win over timeout and error races; old-session callbacks cannot change a new conversation.
- Composer clears on admission; disappearing text and media remain excluded from retry.

No transport, background, signing or interoperability capability changed. Physical-device validation remains outstanding. The validated build is published as [mobile-preview-2c05cf8828df](https://github.com/austugal/lantern/releases/tag/mobile-preview-2c05cf8828df).

## Mobile 0.2.0 — communication and field tools

- Photo attachments from camera/gallery, resized and re-encoded before sending.
- Voice notes up to 30 seconds, explicit playback, and emoji entry.
- Bounded attachment transfers with complete-message receipts and disconnect cleanup.
- Opt-in generic local notifications and on-use camera/microphone permissions.
- Steady torch and repeating Morse SOS, with cancellation and background shutdown.
- Optional online maps, saved small offline areas and GeoJSON import.
- Explicit Find me/help coordinate messages with accuracy, fix time and stale-fix checks.
- Expanded built-in help, workplace examples and physical-device test checklist.

Same-platform, one-peer, foreground mobile communication remains the current limit. This does not add live calls, remote push messaging, emergency-service contact or production signing. See the mobile verification record for build evidence and untested device behaviours. Desktop version numbering is independent.

## 0.3.0 — desktop preview

- Added an offline-assets desktop interface, local vault onboarding and explanatory control help.
- Added explicit-route LAN UDP, signed expiring invitations and in-person safety-number confirmation.
- Added encrypted end-to-end app receipts for messages, alerts and revocations.
- Added pending revocation persistence/retry and honest unconfirmed-delivery status.
- Exposed expiring message/location/guardian permissions, check-in, waypoints and breadcrumb navigation.
- Bounded history, audit log, KDF cost and vault size; replaced predictable temporary vault writes with exclusive random files.
- Rejected invalid coordinates, nested mesh envelopes and invalid timer durations; expired stale locations.
- Preserved source accuracy when sharing; made geometric uncertainty estimates more conservative.
- Added native desktop build workflows and source launchers for Windows/macOS/Linux.

Not added: mobile app/APK, BLE/LoRa driver, full double ratchet, or emergency-service guarantees.
