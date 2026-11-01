# MeshCore radio preview

Open **Field tools → MeshCore radio**. This is a separate companion-radio mode;
it does not change Lantern's existing nearby session protocol or connect the
Python desktop app to a radio. Compatible radio firmware supplies the LoRa mesh.
A phone alone cannot provide LoRa radio or extend range by installing software.

## Use

1. Use a supported LoRa device with **MeshCore BLE companion firmware**. Configure
   the correct region/radio parameters and channels using the device vendor and
   MeshCore tools. Lantern neither flashes firmware nor changes these settings.
2. Close other apps connected to the radio. Keep Lantern open. Tap **Scan for
   MeshCore radio**, allow Bluetooth permissions and select your own radio. A
   displayed name or UART service is not authenticated identity. Confirm any OS
   pairing prompt with the radio's configured PIN. Older Android releases also
   need Location permission/service for BLE scans; Lantern does not start GPS.
3. Select an existing radio channel slot and check its returned name. Empty slots
   cannot send. Channel names do not prove secrecy. Public and hashtag channels
   are readable by people with publicly known/derivable keys.
4. Send up to **100 UTF-8 bytes**. Accented letters and emoji can take more than
   one byte. This conservative cap leaves room for MeshCore's radio sender name.
   **Accepted by radio** means the companion accepted the command. There is no
   recipient delivery, reading or task-acceptance confirmation.
5. **Receive radio inbox** explicitly asks before retrieving up to 20 queued
   items. Reading consumes the shared firmware queue. This preview displays only
   channel text (legacy and v3 formats); direct messages and binary datagrams are
   consumed but not displayed. Use the official client for those message types.
   This limitation is stated in the confirmation dialog before any inbox read.
6. Leave the screen or use **Disconnect and clear** to end the local session.
   Backgrounding/locking also invalidates it. Messages are memory-only and clear;
   commands already accepted by the radio may still transmit afterwards. No
   automatic reconnect, polling, retry, forwarding or GPS sharing occurs.

The radio and other recipients can retain messages independently of Lantern.
Received sender labels/content are unverified and use the radio's security,
not Lantern's nearby identity/receipt system. No photo, voice or web transport
is implemented over LoRa. No MeshCore/Meshtastic interoperability is claimed.
Range, battery behaviour and two-radio delivery require physical testing.

## Implementation and review evidence

- Independently implemented companion protocol; no firmware or upstream client
  code is bundled. BLE client dependency: `flutter_reactive_ble` **5.4.0**, with
  its own licence exposed in Flutter's package licence registry.
- BLE UART service `6e400001-b5a3-f393-e0a9-e50e24dcca9e`; write-with-response on
  RX `...0002...`, notification subscription on TX `...0003...`.
- MTU must carry a complete 176-byte frame (ATT MTU at least 179). No guessed
  frame fragmentation. Negotiation failure closes the session.
- Handshake: APP_START, DEVICE_QUERY with target protocol 3, GET_CHANNEL 0.
  Requires protocol >=3 and an advertised channel count of 1–40. Channel reads
  retain only the slot/name; raw channel keys, BLE PIN and self position are
  neither logged nor exposed/persisted by this client.
- Serialized commands, eight-second deadline, bounded discovery (32 devices),
  history (100), deduplication (200) and explicit queue drain (20). A timeout or
  malformed expected response ends the session so a late generic OK cannot be
  assigned to a subsequent send. Session generations invalidate delayed events.
- Commands used: `0x01`, `0x16`, `0x1f`, `0x03`, `0x0a`. No firmware/configuration,
  private-key export, contacts, advert or GPS-update commands are sent.
- The firmware's channel-send handler returns `RESP_CODE_OK` (`0x00`). The
  companion guide says `RESP_CODE_SENT` (`0x06`); this client follows the handler
  and never interprets either response as end-to-end delivery.

Source reviewed on 1 November 2026:

- [Official firmware](https://github.com/meshcore-dev/MeshCore/blob/81dbae592ffad40b4212bc0b37e82b38da08f4bc/examples/companion_radio/MyMesh.cpp)
  (`CMD_SEND_CHANNEL_TXT_MSG`, `CMD_SYNC_NEXT_MESSAGE`, `CMD_GET_CHANNEL`, APP_START).
- [Official companion guide](https://github.com/meshcore-dev/MeshCore/blob/81dbae592ffad40b4212bc0b37e82b38da08f4bc/docs/companion_protocol.md).
- [BLE library documentation](https://pub.dev/packages/flutter_reactive_ble/versions/5.4.0).

Automated fixtures cover command bytes, UTF-8 limits, parsing, serialization,
channel negotiation, rejection/timeout, inbox bounds, duplicate handling,
disconnect races and consent UI. An APK navigation check opens the screen
without requesting Bluetooth. These are not physical-radio validation. Real BLE
pairing, MTU/notification behaviour, both phone platforms, channel transmission,
radio queue interactions, radio range and battery use remain hardware gates.
