# Strict Android packet input — 8 November 2026

Inspected main a8d6ccd, README, roadmap, dated work records, active PRs and CI. PR #33 owns the physical-baseline walkthrough and product introduction; its files and branch were not edited. Our README addition is a separate packet-validation paragraph, outside its hero/introduction work. Existing main mobile and desktop releases passed all gates. No failing release needed repair.

The next bounded reliability milestone fixes Android's lossy UTF-8 conversion on incoming nearby bytes. The iPhone callback already rejects undecodable input. Android now also rejects malformed, empty or oversized packets before emitting data to Flutter, preserving valid Unicode and the 8 KiB ceiling. Current-peer and session-generation checks remain ahead of decoding. No protocol fields, radio SDK, pairing, permission, receipt semantics or background mode were added.

Primary Java decoder and Google Nearby payload documentation were inspected before changing the adapter boundary; links are in mobile/docs/VERIFICATION.md. A specialist owned only the standalone JVM fixture. Another specialist refreshed contributor evidence separately; no Support message was sent.

Local checks: 33 JVM assertions passed using Java 17 source/target on OpenJDK 21. All 136 Python tests passed. Changed Markdown links and diff whitespace checked. Remote CI must additionally compile the Kotlin/Java integration, execute Flutter tests, build Android/iOS and exercise the installed Android APK. Local checks do not demonstrate those remote results or physical radios.
