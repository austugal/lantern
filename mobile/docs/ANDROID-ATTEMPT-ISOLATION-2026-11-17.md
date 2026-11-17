# Android attempt isolation contract — 17 November 2026

Status: reviewed design gate, not implemented or hardware-validated. This defines the next lifecycle implementation slice. The app still permits retries within discovery; the known same-peer ambiguity remains present.

## Evidence and failure model

[Google lifecycle callbacks](https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/ConnectionLifecycleCallback) identify an endpoint in result/disconnect notifications, without an attempt identifier. [ConnectionsClient](https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/ConnectionsClient) accepts a callback for each outbound request and another when advertising starts. Documentation checked 17 November does not promise that stopping drains already queued callbacks.

In MainActivity, outbound requests create fresh lifecycle objects but capture only discovery generation. Incoming requests use the advertising callback for that generation. Reading a mutable invitation counter inside a callback cannot prove which attempt generated it. PR #37 protects request-task failure cleanup, and PR #39 filters non-owned disconnects; neither distinguishes successive attempts reusing one endpoint in one generation. Flutter operation epochs protect method completions, but lifecycle events currently carry no native generation.

## Selected implementation boundary

Use one admitted attempt per discovery generation, including its established connection. After that attempt terminates, retire discovery and require the user to restart it. This trades an extra explicit restart for a simpler isolation boundary. It adds no automatic reconnect, persistence or background capability.

A future implementation must perform the following as one coordinated native/Flutter change:

1. Record admission before issuing requestConnection or showing an incoming invitation. Accept at most one consent initiation from the expected callback registration and phase. Duplicate initiation must not renew the timeout, blindly reject the already-owned endpoint or replace its displayed consent token. Treat ambiguous simultaneous incoming/outgoing attempts as a terminal collision requiring explicit restart; do not silently adopt fresh consent information.
2. On an owned terminal event, invalidate native generation before cleanup or emitting events, mark running false, clear pending/connected/names, stop advertising/discovery/endpoints and retire timers. Existing shutdown is a starting point, not sufficient integration by itself.
3. Send a terminal event identifying the retired native generation and a bounded reason. Flutter must validate that generation, advance its operation epoch, set active/busy false, clear peer/session state and expose an explicit restart. Delayed terminal/data/error events from retired generations must not alter a restarted session. Establish the generation handshake before accepting events during start; do not assume method/event delivery order.
4. Complete each original MethodChannel result once even if stale. Stale completions cannot mutate current state. Failure after initiation must retain the existing invitation-phase ownership protection.
5. Restart creates new callback registrations and a new generation. The user chooses the peer and verifies again. No message, location share, media transfer, guardian state or check-in resumes automatically.

## Terminal-event rules

| Event | Required behavior |
| --- | --- |
| User cancels pending request (even when the SDK emits no disconnect callback), declines owned invitation or disconnects owned connection | Retire generation and show stopped/restart state; no automatic discovery |
| Owned request task failure before initiation; owned accept failure | Retire only the captured current attempt; original method receives error |
| Native 30-second invitation timeout or Flutter 35-second fallback | Retire once; simultaneous callbacks cannot emit multiple terminal transitions |
| Owned failed connection result or established-peer disconnect | Retire and clear sensitive session state |
| Duplicate success or failure result after connection established | Ignore; never run the current REJECT branch against an already connected owner |
| Old generation result/disconnect/initiation/payload/task completion | No state change, endpoint-wide action, acknowledgement or current-session event |
| Unrelated peer while an attempt is owned | Reject/ignore without terminating the owner; never promote that peer in this generation |
| Stop, background or destroy | Retire before cleanup; preserve existing foreground-only behavior |

No rejected endpoint may later be admitted in the same generation: a delayed rejection/result would alias that new attempt. Before the first admission, retain rejected endpoint IDs in a bounded set (maximum 100); refuse reuse until explicit restart. At capacity, latch all admissions closed until explicit restart, including IDs that could not be recorded. Do not reopen admission within that generation, evict IDs or grow memory. Do not let unsolicited peers cause automatic restart loops. The exact denial UX and state machine must be tested with the implementation.

## Required acceptance cases

| Layer | Scenario and assertion |
| --- | --- |
| JVM/native policy | Cancel A, retire, restart, request A; inject every old callback and assert no cleanup, endpoint calls or events on the new generation |
| JVM/native policy | Repeat for incoming A using the old advertising callback, failed result, timeout and accept failure |
| JVM/native policy | Duplicate success or failure after connected A produces no state change, event or disconnect; duplicate terminal notifications produce one retirement |
| JVM/native policy | Duplicate initiation leaves authentication digits/deadline unchanged; different-registration same-endpoint collision retires without substituting consent |
| JVM/native policy | Unrelated B cannot retire A; rejected B cannot later be admitted in the same generation; rejection-set overflow keeps all admissions latched closed without growing memory |
| Flutter fake transport | Terminal before/after original method completion yields stopped state once; stale event after restart cannot reset new state |
| Flutter fake transport | Consent, location/media/guardian/check-in state clears; restart never restores it; existing unresolved-send budgets remain bounded |
| Flutter widgets | Explicit restart and reason visible, retry while stopped unavailable, name/code confirmation required again |
| CI | Existing Flutter, JVM, Android APK/emulator, iOS and desktop gates pass without weakened assertions |
| Physical phones | Two-Android cancellation/retry from both roles, simultaneous initiation, Bluetooth interruption, screen lock and repeated same-peer cycles; record models/OS and observed ordering |

An SDK callback delivered under a newly registered callback despite originating from an old radio exchange is not ruled out by the public documentation. Generation fencing protects callbacks delivered through old registrations; physical evidence and SDK behavior review are required before claiming universal isolation. Do not label this a completed race fix until the coordinated implementation and tests exist.
