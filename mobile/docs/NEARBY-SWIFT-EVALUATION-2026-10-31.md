# Nearby Swift evaluation — 31 October 2026

Status: **evaluation complete; migration not ready for the published preview**. This is a source review, not an implemented adapter, dependency-resolution check, SDK build or mixed-phone test.

## Decision

Google documents Nearby Connections as supporting communication between Android and iOS [1]. Evaluate its Swift SDK in an isolated candidate before considering replacement of Lantern's Apple Multipeer adapter. Preserve the current same-platform release, one-peer limit, explicit verification and foreground-only shutdown. Do not claim that installing this package alone establishes Lantern interoperability.

## Dependency and build boundary

The reviewed upstream main revision is `958f82f40dc8d2ec80a25fa1dae85cf70d415ef2`, committed 31 October 2026 at 02:23:06 UTC. Its [Package.swift][2] declares Swift tools 5.7, iOS 13 and product `NearbyConnections`. Google's setup page requires Xcode 14 or newer and describes Xcode's Swift Package Manager installation [3]. These are declared minima, not a successful build with Lantern's Flutter/Xcode configuration.

The [tags response][9] returned only `v0.0.1-ios` at `0175a9809843167243de1241260c502ee67cd60d`. This review does not recommend that old tag as a compatible release. Pin an evaluated revision and commit `Package.resolved` for a candidate. The reviewed manifest includes an Abseil dependency on branch `jan-lts` and a BoringSSL version range; pinning only the top-level package does not lock the entire graph. Verify resolution, licences, transitive revisions, source/submodule availability, simulator/device architectures and archive reproducibility before adopting it.

## Medium and permission questions

There is a material upstream documentation discrepancy. The [repository's Connections README][4] says Apple builds support Wi-Fi LAN only, while the newer [Swift setup guide][3] describes BLE, Wi-Fi LAN and hotspot configuration. Do not silently treat either description as proof that the selected revision provides every medium. A candidate must identify which compiled mediums operate, then test each intended path. In particular, shared-LAN success must not be relabelled as success without an access point or as measured radio coverage.

The setup guide identifies Bluetooth and local-network usage descriptions, a service-ID-derived Bonjour service declaration, and location authorization for hotspot upgrades. Wi-Fi information and Hotspot Configuration capabilities depend on the intended medium; hotspot capability also involves provisioning [3]. Do not retain Multipeer's old Bonjour service type by assumption. The embedded [Google generator][13] uppercases the SHA-256 hex string and takes its first **12 hex characters**, then forms `_<prefix>._tcp`. This differs from the guide prose describing 12 bytes. For `org.austugal.lantern.v1`, the generator yields `_9E0CCCC25D0F._tcp`. Treat this as a documentation-derived candidate value: compare it with the pinned SDK's native serialization and verify discovery before changing the plist. Do not use a guessed 24-hex-character prefix.

Lantern must preserve its explicit-start consent flow. Do not copy Google's sample startup location request into application launch. Explain and request any transport-specific authorization after the user chooses the candidate mode; GPS sharing remains a separate choice. Test denial, restricted/not-determined states, later Settings changes and Stop while a permission prompt is unresolved. This review changes no entitlement, provisioning profile or permission.

## Connection and payload contract

Use an identical application service ID and matching one-to-one strategy on both platforms. Swift exposes `.pointToPoint`; the existing Android strategy must be compared explicitly rather than copying Google's `.cluster` example. Discovery advertises endpoint context and reports found/lost endpoints; stop discovery when a peer is selected/connected to reduce radio contention [5]. Endpoint context is untrusted display information, not authenticated identity.

Swift has two consent stages: the advertiser receives a connection-request handler, followed by a connection-manager verification handler on both ends. Google recommends comparing the same verification code on both devices and warns against unverified connections [6]. Candidate UI must preserve an explicit verification choice on each phone, lifecycle-bound admission, cancellation, rejection and deadlines. Never auto-accept the sample handlers or emit Lantern's `connected` event before mutual verification completes.

Swift byte payloads use `ConnectionManager.send(Data, to: ...)` and arrive as complete `Data` in its delegate [7]. The [source API][10] distinguishes submission completion from subsequent transfer success/failure. Preserve Lantern's application `ack` packet as the only Delivered signal; SDK submission or transfer success is not a human read/acceptance event. Keep the existing bounded JSON packets and chunked-media protocol, without converting to unbounded file/stream transfers. Google's documented byte limit is 32 KiB [11], above Lantern's 8,192-byte wire limit; that size comparison is an inference about fit, not an executed interop test.

## Lifecycle and privacy limits

No reviewed Connections Swift source establishes continuous iOS background messaging. Keep explicit Stop, native teardown, old-session callback rejection and fresh foreground consent. Do not borrow background instructions from the separate, deprecated Nearby Messages API. Apple's current Multipeer documentation describes disconnect on background [8]; changing SDKs does not remove operating-system suspension constraints.

Google's overview describes usage/performance and device diagnostics for the **Google Play services** Nearby SDK, with user control through Google settings [11]. Do not transfer that exact scope or opt-out mechanism to the open-source Swift package without evidence. The candidate requires a separate Swift/transitive-dependency privacy review before any new privacy assertion. Upstream also states its repository is not an officially supported Google product [12].

## Required next evidence

A separate candidate needs a fully resolved dependency graph, simulator and unsigned-device builds, consent/verification adapter tests, delayed-callback and bounded-resource tests, and physical Android–iPhone discovery and bidirectional text/photo/voice tests. Exercise both roles, explicit rejection, mismatched codes, missing permissions, range loss, interruption and no-internet scenarios. Record models, OS versions, SDK revisions, actual network/medium conditions and outcomes. Retain same-platform regression checks and the existing release until these gates pass. Production signing, independent security review, battery/range measurements and background delivery remain separate outstanding gates.

## Primary sources checked on 31 October 2026

[1]: https://developers.google.com/nearby
[2]: https://github.com/google/nearby/blob/958f82f40dc8d2ec80a25fa1dae85cf70d415ef2/Package.swift
[3]: https://developers.google.com/nearby/connections/swift/get-started
[4]: https://github.com/google/nearby/blob/958f82f40dc8d2ec80a25fa1dae85cf70d415ef2/connections/README.md
[5]: https://developers.google.com/nearby/connections/swift/discover-devices
[6]: https://developers.google.com/nearby/connections/swift/manage-connections
[7]: https://developers.google.com/nearby/connections/swift/exchange-data
[8]: https://developer.apple.com/documentation/multipeerconnectivity
[9]: https://api.github.com/repos/google/nearby/tags?per_page=8
[10]: https://github.com/google/nearby/blob/958f82f40dc8d2ec80a25fa1dae85cf70d415ef2/connections/swift/NearbyConnections/Sources/ConnectionManager.swift
[11]: https://developers.google.com/nearby/connections/overview
[12]: https://github.com/google/nearby
[13]: https://developers.google.com/frame/nearby/connections/swift/get-started_8ae2356bc61db41ef042e2da374b8c1ac2693db253f0169eaaeabf846a031f20.frame

1. [Google Nearby platform][1]
2. [Pinned package manifest][2]
3. [Swift installation and permissions][3]
4. [Pinned medium-support README][4]
5. [Swift advertising/discovery][5]
6. [Swift connection verification][6]
7. [Swift payload exchange][7]
8. [Apple Multipeer lifecycle documentation][8]
9. [Observed upstream tags][9]
10. [Pinned send API semantics][10]
11. [Payload limits and Play services diagnostics][11]
12. [Upstream support disclaimer][12]
13. [Google Bonjour generator source][13]
