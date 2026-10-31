# Proposed Nearby Swift adapter contract

Evaluated against Lantern main `275d9801dd5a6b9c833faa51a4ef12da758ee321` on 31 October 2026. **Design only; no adapter, dependency, permission or entitlement is changed.** Read the [SDK evaluation](NEARBY-SWIFT-EVALUATION-2026-10-31.md) before implementation.

## Existing adapter compared with proposed adapter

| Boundary | Current Android | Current iPhone | Required experimental Swift adapter |
| --- | --- | --- | --- |
| Discovery protocol | Google Nearby Connections | Apple Multipeer Connectivity | Google Nearby Connections, with matching Android service ID and strategy |
| Service | `org.austugal.lantern.v1` | `lantern-v1`, `_lantern-v1._tcp` | `org.austugal.lantern.v1`; derive Bonjour declaration from the selected SDK implementation, not the existing Multipeer service |
| Topology | `P2P_POINT_TO_POINT`, one peer | One accepted peer | `.pointToPoint`, plus explicit one-peer admission guard |
| Identity information | Display name and SDK authentication digits | Display name, no independent verification code | Bounded UTF-8 display name as endpoint context; compare SDK verification code on both phones |
| Data | `Payload.fromBytes`, UTF-8 JSON at most 8,192 bytes | Reliable `MCSession.send`, same JSON bound | `ConnectionManager.send` byte data only; enforce existing bound before dispatch and after receipt |
| Background | Activity shutdown and Dart state reset | App lifecycle shutdown and Dart state reset | Preserve both shutdown layers, no automatic discovery/reconnect on resume |

These observations come from `mobile/android/app/src/main/kotlin/org/austugal/lantern/MainActivity.kt`, `mobile/ios/Runner/AppDelegate.swift`, `mobile/ios/Runner/Info.plist` and `mobile/lib/src/controller.dart` at the inspected commit. Android and iPhone currently cannot interoperate.

## Method/event mapping and consent

| Existing channel operation | Proposed SDK/state mapping | Required invariant |
| --- | --- | --- |
| `start(name)` | Construct manager, advertiser and discoverer for one generation; begin only after the user turns on Lantern | Bound endpoint context, discovery records and permission requests; fail visibly if setup fails |
| `request(id)` | Explicit `Discoverer.requestConnection` for the selected endpoint | Never request automatically from a discovery callback |
| Incoming connection request | SDK advertiser admission handler, distinct from verification handler | Reject busy/unexpected peers. Treat preliminary SDK admission as handshake only, never application consent |
| Verification callback → `invitation` | Emit endpoint/name/code to Flutter; hold a single current verification handler | Both initiator and recipient must see and confirm the matching code; reject empty/mismatched code, timeout and stale generation |
| `accept(id)` / `reject(id)` | Resolve the current verification handler exactly once | No unconditional acceptance copied from sample code; rejection/cancel/Stop must settle pending handlers and cancel transport state |
| SDK connected → `connected` | Emit only after verified, current, user-selected/accepted endpoint reaches connected state | Keep controller's `requesting == id` gate; no application packets before mutual verification |
| `send(id,data)` / byte receive → `data` | Only current connected endpoint, strict UTF-8 and packet bounds | Native completion/transfer status is not an app receipt or human acknowledgement |
| `disconnect`, `stop`, lifecycle shutdown | Stop advertising/discovery, disconnect endpoints, invalidate generation, settle held handlers/results | Late SDK callbacks cannot emit packets or revive a conversation; fresh consent after reconnect |

The existing Flutter invitation UI already shows a code when supplied. It must be exercised on iPhone after migration: the current Apple adapter emits an empty code and has a different consent path. User-visible iPhone help must remain accurate for the selected adapter. Keeping method names alone does not prove behavioral compatibility.

Maintain the native 30-second invitation deadlines and the controller’s 35-second invitation deadline, existing text/attachment deadlines, actual unresolved-call budgets, memory limits, app receipts, request decisions and privacy boundaries. Stop discovery during a connected one-peer conversation where the chosen SDK supports it; verify that doing so neither disconnects the peer nor auto-resumes discovery after loss. Media continues through bounded JSON byte chunks, not new unbounded file/stream APIs.

## Permission and rollout gates

1. Preserve the current release and same-platform iPhone transport while building an isolated experimental candidate. Do not silently switch protocols or claim compatibility with old Multipeer builds. A candidate must identify its transport in test records and user guidance.
2. Pin an evaluated upstream revision and resolve/record all transitive revisions. Review licences and dependency changes. Passing package metadata inspection is not a successful Xcode build.
3. Audit capabilities and minimum OS against the actual selected package. The existing location usage description explains coordinate sharing only. If hotspot transport requires location authorization, explain that separate purpose before a user-started permission request; do not copy an app-launch permission request. Denial must not start sharing or trigger repeated prompts. Do not change Apple account capabilities or provisioning in this work.
4. Build iOS simulator and unsigned device targets, Android APK and existing desktop targets. Run existing protocol/controller tests and native fixtures, plus native adapter tests for both verification stages, deny/mismatch/timeout, third-peer rejection, concurrent requests, pending callbacks on Stop/background and invalid/oversized payloads.
5. A signed physical iPhone and physical Android must test discovery in both roles and matching-code confirmation. Record exact app commit, SDK and transitive revisions, phone/OS, selected medium/topology, permission state, observed delivery, interruptions and failures. No simulator or same-platform test substitutes for this.
6. Test each topology independently: shared LAN with internet disabled; user-created hotspot with internet disabled; no access point/hotspot with Wi-Fi and Bluetooth enabled. Leave unsupported or untested rows explicit. Do not bypass hotel client isolation or infer infrastructure-free operation from a LAN success.
7. Validate Unicode, text retry, work decisions, photo/voice app receipts, expiry, peer changes, repeated transfers, background teardown, 30-minute foreground use and measured battery/range. Compare against the unchanged same-platform release. Stop rollout on any consent or stale-session leak.

## Physical result sheet (unexecuted)

| Scenario | Device/OS + SDK revision + medium | Observation / evidence | Status |
| --- | --- | --- | --- |
| Two Android phones, existing release | Not supplied | Establish baseline before migration | Not run |
| Mixed phones, shared offline LAN, each discovery role | Not supplied | Matching codes; bidirectional text/media and app receipts | Not run |
| Mixed phones, explicit offline hotspot | Not supplied | Permission-denial recovery and actual selected path | Not run |
| Mixed phones, no access point/hotspot | Not supplied | Establish whether a shared medium actually works | Not run |
| Mixed phones, reject/timeout/background/range loss | Not supplied | No pre-consent payloads, stale callbacks or restored sharing | Not run |

No Android–iPhone support, background delivery, signing, physical testing or security auditing is established by this design.
