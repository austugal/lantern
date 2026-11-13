# iOS build compatibility repair — 13 November 2026

Main remains `0b73e672202f56eb065d9ee49f70c629cd115f4c`, with passing mobile, Python and desktop CI and published previews. README, roadmap, active records and open PRs were inspected; PR #37 is the only open item. No new competing Finish Flutter Repo work was found. Repairing its failed validation takes priority over adding a feature.

## Failure evidence

[Job 131214525717](https://github.com/austugal/lantern/actions/runs/43227545151/job/131214525717) failed on 12 November at 13:30 UTC. SwiftProtobuf's Message+BinaryAdditions.swift lines 123 and 184 referenced unavailable RawSpan. The Android, emulator and Flutter jobs passed; Python passed separately. No failing main release was replaced.

Primary sources checked 13 November:
- [SwiftProtobuf 1.40.0 release](https://github.com/apple/swift-protobuf/releases/tag/1.40.0): released 11 November after the successful main build; explicitly drops Swift 6.1.
- [1.39.0 implementation](https://github.com/apple/swift-protobuf/blob/1.39.0/Sources/SwiftProtobuf/Message%2BBinaryAdditions.swift) guards RawSpan APIs with compiler >=6.2; [1.40.0](https://github.com/apple/swift-protobuf/blob/1.40.0/Sources/SwiftProtobuf/Message%2BBinaryAdditions.swift) removes those guards.
- [Exact runner image manifest](https://github.com/actions/runner-images/blob/macos-15-arm64/20261104.0514/images/macos/macos-15-arm64-Readme.md) lists Xcode 16.4 as default.

The actual [reactive_ble_mobile 5.4.2 archive](https://pub.dev/api/archives/reactive_ble_mobile-5.4.2.tar.gz) declares SwiftProtobuf `~> 1.0`, allowing the exact 1.39.0 pin. Independent read-only review found no defect in the Podfile/workflow diff.

The error, source lines, release timing and absent native lock establish a dependency/compiler compatibility diagnosis. The failed log does not print the resolved pod version; 1.40.0 resolution is an inference, not a recovered lockfile observation.

## Smallest repair and validation

The isolated branch `fix/ios-protobuf-20261113` starts at PR #37's exact head. Pin SwiftProtobuf to 1.39.0 in the Runner Podfile target. Keep the Flutter version, native SDKs, compiler selection, consent and resource limits unchanged. CI records xcodebuild/swift/pod versions and uploads Podfile.lock and pubspec.lock even after failure. Publish still requires all existing mobile gates.

The primary agent owns the Podfile, workflow and docs; an independent specialist reviews upstream compatibility read-only, and attribution checking has no source ownership. Local workflow YAML parsing and release-gate assertions passed, as did 136 Python tests. This Linux workspace cannot compile the iOS app; both native iOS builds must pass CI before merge. A dependency pin is not a complete dependency lock; broader lockfile maintenance remains future work.

This repair adds no physical testing, production signing, background execution or Android–iPhone communication. The validated mobile/desktop previews and pinned physical baseline remain available. The separate same-peer lifecycle callback limitation remains open.
