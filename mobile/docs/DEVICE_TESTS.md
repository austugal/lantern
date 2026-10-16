# Physical device acceptance gate

Status: **not yet run**. Do not replace these checks with simulator success.

Record phone models, OS versions, app commit, tester, date and observed result for each test. Use two Android devices and separately two iPhones.

| Test | Expected result | Result |
| --- | --- | --- |
| First launch | No discovery/location permission prompt before user action | Pending |
| Turn on / deny permission | Clear error, no false connected state; granting in Settings allows retry | Pending |
| Radios disabled | Actionable OS/error state; no fake peers | Pending |
| Nearby discovery | Each phone sees the other; no automatic connection | Pending |
| Android authentication | Same code on both; both must accept | Pending |
| iPhone consent | Receiver must accept; unverified-name limitation visible | Pending |
| Decline / cancel / 35-second timeout | No chat or location; another attempt works | Pending |
| Third device while connected | No unsolicited second connection or messages | Pending |
| Simultaneous requests | Failure/timeout is recoverable; no auto-accept | Pending |
| Messages both directions | Unicode and multiline work; receiver acknowledgement gives Delivered | Pending |
| Range loss during send | No false Delivered; reconnect starts a fresh conversation | Pending |
| Share location | Separate confirmation; only selected peer receives updates | Pending |
| Deny location after connecting | Messaging continues; no sharing indicator left on | Pending |
| Stop / disconnect / 15-minute expiry | Position stream stops; peer coordinates clear or expire | Pending |
| Lock screen / Home / app switch | Native session stops and Flutter state clears on return | Pending |
| Permission dialog interrupted by background | No delayed discovery or sharing on return | Pending |
| Stationary GPS | Coordinates age out after 30 seconds if no new fix arrives | Pending |
| Restart / profile rename | Name persists, conversation does not; rename disconnects | Pending |
| Airplane mode + re-enable Wi-Fi/Bluetooth | Local connection works where the OS permits; no mobile data required | Pending |
| Large text / VoiceOver / TalkBack / rotation | Controls remain accessible; no clipping or silent actions | Pending |
| Photo camera and gallery | Permission requested on use; preview appears; reconnect after picker if necessary; receipt only after full transfer | Pending |
| Photo metadata and memory | Sent image contains re-encoded pixels; oversized media rejected; repeated transfers remain bounded | Pending |
| Voice record / deny microphone | Denial is recoverable; recording stops by 30 seconds; audio never auto-plays | Pending |
| Background during record/playback | Recording/playback stops; temporary audio files cleaned up | Pending |
| Attachment interrupted by disconnect | No partial image/audio is presented as delivered | Pending |
| Notifications allow/deny/revoke | Generic alert only after received message and opt-in; no sender/text leak; denial does not prevent chat | Pending |
| Torch absent / camera busy / permission denied | Actionable error; no false active indicator | Pending |
| Torch SOS and Stop | Three short, three long, three short; Stop and background switch flash off | Pending |
| Torch permission interrupted | Cancelling/backgrounding cannot turn flash on later | Pending |
| Offline saved map | Previously saved area renders with network disabled; date and coverage limits visible | Pending |
| Find me help message | Explicit review before coordinates leave device; stale/missing GPS not presented as current; delivery status accurate | Pending |

Release blockers: unresolved failures here, iOS identity verification if stronger threat protection is required, cross-platform interoperability if product scope requires it, production signing and store/privacy declarations.
