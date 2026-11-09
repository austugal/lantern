# Android callback isolation — 9 November 2026

Inspected main, README, roadmap, active work records, PRs and CI before changing code. PR #33 and its phone-model correction were already on main. Their physical report and product artwork were preserved. PR #34 was the only open PR; its exact head passed Android APK/emulator, iOS simulator and unsigned-device builds, Flutter, JVM and Python CI before merge. No failing release required repair.

This isolated branch completes the next bounded reconnection-reliability fix: obsolete initiation/result callbacks cannot perform endpoint-wide reject/disconnect actions in a new discovery generation. Current-session acceptance and rejection rules remain; a gate fixture covers delayed callbacks with reused endpoint IDs. This is a code-level failure scenario, not a claimed reproduction on phones.

Local verification: 19 JVM regression checks at Java 17 source/target on OpenJDK21; all 136 Python tests. Relative Markdown links and diff whitespace checked. Native Kotlin/Java integration, Android emulator and iOS builds are required CI gates before merge. A specialist owned only the fixture; another checked attribution separately. No credentials, visibility or released history changed.

The user-reported first Samsung trial remains recorded separately; device details and the structured ten-check baseline are still incomplete. No additional physical tests or background operation were performed. Contributor discrepancy evidence remains prepared and unsent.
