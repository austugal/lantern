# Changelog

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
