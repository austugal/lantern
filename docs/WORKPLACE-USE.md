# Workplace use: nearby communications without internet

Lantern aims to help colleagues communicate where internet access is unavailable: hotel service areas, events, warehouses and construction sites. A local radio link is still required. Walls, floors, radio interference, permission settings and phone models affect availability; there is no verified range guarantee.

## Current developer preview

Two colleagues on the same mobile platform open Lantern, enable their radios, choose each other and accept a connection. They can exchange acknowledged text messages, optionally share location and use foreground check-in alerts. Short help dialogs explain controls. Android and iPhone have separate transports; mobile and desktop do not interoperate. No internet service is required for nearby messages, but Android currently requires Google Play services.

This preview ends the session when a phone is locked or backgrounded. It is not yet a pocket pager, group radio, emergency dispatch system or hotel-wide communications network.

## Workplace acceptance requirements (not implemented claims)

1. Mixed Android/iPhone communication, tested with representative managed and personal devices.
2. Department and incident group channels with explicit membership and removal.
3. Reliable background delivery within platform rules, with clear availability and battery status.
4. Acknowledged requests such as maintenance needed or assistance requested; distinguish sent, received and accepted.
5. Physical testing across walls, floors, stairwells and service areas, including interference and disconnection recovery.
6. Authentication appropriate for staff teams, lost-device removal, retention controls and security review.
7. An agreed fallback to established emergency procedures whenever Lantern is disconnected.

A pilot should use noncritical communications first. Never infer that an alert reached a colleague from a send action alone. Precise location is voluntary and often unreliable indoors; a colleague-selected room or work-area label may be more useful than GPS for hotel operations.
