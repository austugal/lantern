# Complete the Android callback-isolation milestone — 11 November 2026

Main 6d0a1d1 and the recovered mobile release were inspected alongside README, roadmap, active records, open PRs and CI. PR #35 was the only open work item; no separate active source repair was found. The previous release failure is resolved by successful attempt 2 of run 42632639391.

PR #35 head b074887b0cb2fc4ac90fb942575b532223255496 passed all jobs in mobile run 42633056610, including Android APK, installed emulator, Flutter, JVM fixture and iOS simulator/unsigned-device builds; Python run 42633056441 also passed. Integration with main produced conflicts only in the dated roadmap, mobile verification and contributor evidence. Both sides were retained. The application, tests and workflows remain byte-for-byte identical to that validated PR head.

Local regression verification repeated the 19 callback checks, 33 strict decoder checks and inbox fixture, with Java 17 source/target on OpenJDK21. All 136 Python tests passed. Relative Markdown links and conflict-marker/whitespace checks passed. The integration commit skips redundant CI because only documentation changed relative to the validated PR; main's application merge still requires its normal release gates. Do not infer published artifacts from a merge.

The change prevents old Android initiation/result callbacks from issuing endpoint actions after a newer discovery generation starts. Existing consent and current-session rejection behavior remain. The user-reported Samsung trial and pinned physical-test APK are unchanged; no new physical results, background operation or mixed Android/iPhone communication were established.
