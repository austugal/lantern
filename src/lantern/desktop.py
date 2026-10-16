"""Local desktop session. All core/transport access is serialized by one lock."""

from __future__ import annotations

import threading
import time
from dataclasses import asdict
from pathlib import Path
from typing import Any

from lantern import Identity, LanternNode, Scope
from lantern.geo import Trail, Waypoints, guide
from lantern.identity import safety_number
from lantern.lan import Invitation, LanTransport, make_invitation, read_invitation
from lantern.location import Fix
from lantern.vault import load, save


class DesktopSession:
    def __init__(self, data_dir: Path, bind: str = "0.0.0.0") -> None:
        self.data_dir = data_dir
        self.path = data_dir / "profile.lantern"
        self.bind = bind
        self.lock = threading.RLock()
        self.node: LanternNode | None = None
        self.transport: LanTransport | None = None
        self.passphrase = ""
        self.pending: Invitation | None = None
        self.own_fix: Fix | None = None
        self.fix_at = 0.0
        self.fix_source = ""
        self.share_to: dict[str, float] = {}
        self.trail = Trail()
        self.waypoints = Waypoints()
        self.outgoing: list[dict[str, Any]] = []
        self.status = ""
        self._retry_at = 0.0
        self._saved_at = 0.0
        self._heartbeat = time.monotonic()
        self._walk_deadline: float | None = None
        self._stopped = threading.Event()
        self._thread: threading.Thread | None = None

    def start_worker(self) -> None:
        self._thread = threading.Thread(target=self._run, name="lantern-session", daemon=True)
        self._thread.start()

    def _run(self) -> None:
        while not self._stopped.wait(0.1):
            with self.lock:
                try:
                    self.pump()
                except Exception:
                    # Stop the radios on a persistence/worker fault, not a silent continuation.
                    self.status = "Session stopped after an internal error. Unlock to reconnect."
                    self._drop_session()

    def _require(self) -> LanternNode:
        if self.node is None:
            raise ValueError("Unlock your vault first")
        return self.node

    def _persist(self) -> None:
        if self.node is not None:
            save(self.node, self.path, self.passphrase)
            self._saved_at = time.monotonic()

    def pump(self) -> None:
        node, transport = self.node, self.transport
        if node is None or transport is None:
            return
        changed = transport.poll()
        node.purge_expired()
        now = time.monotonic()
        if now - self._heartbeat > 20 and self.share_to:
            self._stop_location()
            self.status = "Location sharing stopped: the app page is no longer active."
        for fp, expiry in list(self.share_to.items()):
            if now >= expiry or node.ledger.valid_issued(fp, Scope.LOCATION, node.clock()) is None:
                self._stop_location(fp)
        if node.safe_walk and not node.safe_walk.done and not node.safe_walk.fired:
            if self._walk_deadline is not None and now >= self._walk_deadline:
                if self.own_fix is not None and now - self.fix_at <= 120:
                    node.safe_walk.fired = True
                    count = node.trigger_sos(
                        self.own_fix.lat,
                        self.own_fix.lon,
                        node.safe_walk.note,
                        accuracy_m=self.own_fix.precision_m,
                    )
                    self.status = f"Guardian alert submitted to {count} route(s); check receipts."
                else:
                    self.status = "Check-in overdue. No fresh position: no alert sent."
        if now - self._retry_at >= 10:
            node.retry_revocations()
            self._retry_at = now
        self.outgoing[:] = [
            m for m in self.outgoing if m["expires"] is None or m["expires"] > time.time()
        ]
        if (changed or now - self._saved_at >= 30) and now - self._saved_at >= 2:
            self._persist()

    def _drop_session(self) -> None:
        if self.transport:
            self.transport.close()
        self.node = None
        self.transport = None
        self.passphrase = ""
        self.pending = None
        self.own_fix = None
        self.share_to.clear()
        self.outgoing.clear()
        self.trail = Trail()
        self.waypoints = Waypoints()
        self._walk_deadline = None

    def close(self) -> None:
        self._stopped.set()
        if self._thread and self._thread is not threading.current_thread():
            self._thread.join(timeout=3)
        with self.lock:
            if self.node:
                self.node.revoke_all()
                if self.node.safe_walk:
                    self.node.safe_walk.check_in()
                self._persist()
            self._drop_session()

    def _stop_location(self, peer: str | None = None) -> None:
        node = self._require()
        for grant in list(node.ledger.issued.values()):
            if (
                grant.scope is Scope.LOCATION
                and (peer is None or grant.grantee == peer)
                and grant.grant_id not in node.ledger.revoked
            ):
                node.revoke(grant.grant_id)
        if peer is None:
            self.share_to.clear()
        else:
            self.share_to.pop(peer, None)

    def action(self, command: str, data: dict[str, Any]) -> dict[str, Any]:
        with self.lock:
            if command in {"create", "unlock"}:
                if self.node:
                    raise ValueError("Lock the current vault first")
                password = str(data.get("passphrase", ""))
                if not 12 <= len(password) <= 256:
                    raise ValueError("Use a passphrase of 12–256 characters")
                if command == "create" and self.path.exists():
                    raise ValueError("A vault already exists; unlock it")
                self.data_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
                transport = LanTransport(self.bind)
                try:
                    if command == "create":
                        name = str(data.get("name", "")).strip()
                        if not 1 <= len(name) <= 40:
                            raise ValueError("Choose a name with 1–40 characters")
                        node = LanternNode(Identity(name), transport)
                    else:
                        node = load(self.path, password, lambda _: transport)
                    # Never automatically restore live sharing or a timer after unlock.
                    node.relay = False
                    for grant in list(node.ledger.issued.values()):
                        if grant.scope in {Scope.LOCATION, Scope.SOS}:
                            node.ledger.revoke(grant.grant_id)
                            node.pending_revocations.add(grant.grant_id)
                    save(node, self.path, password)
                    self.node, self.transport, self.passphrase = node, transport, password
                    self.status = "Unlocked. Exchange invitations to connect."
                    self._heartbeat = time.monotonic()
                except Exception:
                    transport.close()
                    raise
                return {"ok": True}
            node = self._require()
            active_transport = self.transport
            assert active_transport is not None
            peer = str(data.get("peer", ""))
            result: dict[str, Any] = {"ok": True}
            if command == "invite":
                result["invitation"] = make_invitation(
                    node.identity, str(data["host"]), active_transport.port, node.clock()
                )
            elif command == "preview":
                candidate = read_invitation(str(data["invitation"]).strip(), node.clock())
                if candidate.card.fp == node.fp:
                    raise ValueError("That is your own invitation")
                self.pending = candidate
                result.update(
                    {
                        "name": candidate.card.name,
                        "safety": safety_number(node.card(), candidate.card),
                    }
                )
            elif command == "pair":
                if self.pending is None or self.pending.expires <= node.clock():
                    raise ValueError("Preview a current invitation first")
                if data.get("safety") != safety_number(node.card(), self.pending.card):
                    raise ValueError("Compare and confirm the complete safety number")
                active_transport.add_route(
                    self.pending.card.fp, self.pending.host, self.pending.port
                )
                node.add_peer(self.pending.card)
                self.pending = None
                self.status = (
                    "Paired. Both people must import and verify each other. Then allow messages."
                )
            elif command == "grant":
                scope = Scope(str(data["scope"]))
                ttl = int(data.get("ttl", 900))
                if scope is Scope.LOCATION:
                    if self.own_fix is None or time.monotonic() - self.fix_at > 120:
                        raise ValueError("Set a fresh location before sharing")
                    if not 30 <= ttl <= 900:
                        raise ValueError("Location sharing is limited to 30 seconds–15 minutes")
                # New grants replace this scope; an older, longer grant must not win.
                for old in list(node.ledger.issued.values()):
                    if (
                        old.grantee == peer
                        and old.scope is scope
                        and old.grant_id not in node.ledger.revoked
                    ):
                        node.revoke(old.grant_id)
                node.grant(peer, scope, ttl, float(data.get("precision", 100)))
                if scope is Scope.LOCATION:
                    self.share_to[peer] = time.monotonic() + ttl
                    assert self.own_fix is not None
                    node.share_location(
                        peer,
                        self.own_fix.lat,
                        self.own_fix.lon,
                        accuracy_m=self.own_fix.precision_m,
                    )
            elif command == "revoke":
                node.revoke(str(data["id"]))
            elif command == "message":
                text = str(data["text"]).strip()
                ttl_value = data.get("ttl")
                message_ttl = int(ttl_value) if ttl_value else None
                node.send_message(peer, text, message_ttl)
                frame_id = next(reversed(node.deliveries))
                self.outgoing.append(
                    {
                        "peer": peer,
                        "text": text,
                        "id": frame_id,
                        "at": time.time(),
                        "expires": time.time() + message_ttl if message_ttl else None,
                    }
                )
                del self.outgoing[:-500]
            elif command == "fix":
                fix = Fix(float(data["lat"]), float(data["lon"]), float(data.get("accuracy", 100)))
                self.own_fix = fix
                self.fix_at = time.monotonic()
                self.fix_source = "device" if data.get("source") == "device" else "manual"
                self.trail.record(fix)
                del self.trail.points[:-2000]
                for fp in list(self.share_to):
                    if node.ledger.valid_issued(fp, Scope.LOCATION, node.clock()):
                        node.share_location(fp, fix.lat, fix.lon, accuracy_m=fix.precision_m)
            elif command == "stop_location":
                self._stop_location()
            elif command == "sos":
                if self.own_fix is None or time.monotonic() - self.fix_at > 120:
                    raise ValueError("A position from the last two minutes is required")
                count = node.trigger_sos(
                    self.own_fix.lat,
                    self.own_fix.lon,
                    str(data.get("note", "Please check on me")),
                    accuracy_m=self.own_fix.precision_m,
                )
                self.status = (
                    f"Alert submitted to {count} guardian route(s). "
                    "Received is not a human response."
                )
                result["submitted"] = count
            elif command == "walk":
                minutes = float(data["minutes"])
                if self.own_fix is None or time.monotonic() - self.fix_at > 120:
                    raise ValueError("Set a fresh position before starting a check-in timer")
                if not any(
                    node.ledger.valid_issued(fp, Scope.SOS, node.clock()) for fp in node._peers
                ):
                    raise ValueError("Choose at least one guardian first")
                node.start_safe_walk(minutes)
                self._walk_deadline = time.monotonic() + minutes * 60
                self.status = "Check-in timer armed. Keep Lantern running and this computer awake."
            elif command == "checkin":
                if node.safe_walk:
                    node.safe_walk.check_in()
                self._walk_deadline = None
                self.status = "Checked in. Timer cancelled."
            elif command == "waypoint":
                if self.own_fix is None:
                    raise ValueError("Set your location first")
                label = str(data["name"]).strip()
                if not 1 <= len(label) <= 40 or len(self.waypoints.places) >= 100:
                    raise ValueError("Use a short waypoint name; maximum 100 waypoints")
                self.waypoints.save(label, self.own_fix)
            elif command == "unpair":
                node.remove_peer(peer)
                active_transport.routes.pop(peer, None)
                self.share_to.pop(peer, None)
                self.outgoing[:] = [m for m in self.outgoing if m["peer"] != peer]
            elif command in {"panic", "lock"}:
                node.revoke_all()
                self.share_to.clear()
                if node.safe_walk:
                    node.safe_walk.check_in()
                self._walk_deadline = None
                self.status = (
                    "All permissions revoked locally. "
                    "Offline peers receive revocations on reconnect."
                )
            else:
                raise ValueError("unknown action")
            self._persist()
            if command == "lock":
                self._drop_session()
            return result

    def state(self, active_page: bool = False) -> dict[str, Any]:
        with self.lock:
            if active_page:
                self._heartbeat = time.monotonic()
            node = self.node
            if node is None:
                return {"locked": True, "exists": self.path.exists(), "status": self.status}
            node.purge_expired()
            now = node.clock()
            peers = []
            for fp, peer in node._peers.items():
                fix = node.locations.get(fp)
                peers.append(
                    {
                        "fp": fp,
                        "name": peer.card.name,
                        "route": fp in (self.transport.routes if self.transport else {}),
                        "safety": safety_number(node.card(), peer.card),
                        "can_message": node.ledger.valid_held(fp, Scope.MESSAGE, now) is not None,
                        "sharing": fp in self.share_to,
                        "location": asdict(fix) if fix else None,
                        "heading": guide(self.own_fix, fix).describe()
                        if fix and self.own_fix
                        else None,
                    }
                )
            grants = [
                g
                for g in node.ledger.issued.values()
                if g.active(now) and g.grant_id not in node.ledger.revoked
            ]
            messages: list[dict[str, Any]] = [
                {
                    "peer": m.sender,
                    "text": m.text,
                    "mine": False,
                    "status": "received",
                    "at": m.received_at,
                }
                for m in node.inbox
            ]
            for m in self.outgoing:
                delivery = node.deliveries.get(m["id"])
                status = delivery.status if delivery else "unknown"
                if delivery and status == "awaiting_receipt" and now - delivery.at > 15:
                    status = "unconfirmed"
                messages.append({**m, "mine": True, "status": status})
            messages.sort(key=lambda message: message["at"])
            walk = node.safe_walk
            return {
                "locked": False,
                "name": node.name,
                "fp": node.fp,
                "port": self.transport.port if self.transport else 0,
                "peers": peers,
                "messages": messages,
                "grants": [
                    {
                        "id": g.grant_id,
                        "peer": g.grantee,
                        "scope": g.scope.value,
                        "seconds": max(0, int(g.expires_at - now)),
                        "precision": g.precision_m,
                    }
                    for g in grants
                ],
                "pending_revocations": len(node.pending_revocations),
                "alerts": [asdict(a) for a in node.alerts],
                "deliveries": [
                    {"id": k, **asdict(v)} for k, v in node.deliveries.items() if v.kind == "sos"
                ],
                "status": self.status,
                "own_fix": asdict(self.own_fix) if self.own_fix else None,
                "fix_source": self.fix_source,
                "fix_age": int(time.monotonic() - self.fix_at) if self.own_fix else None,
                "sharing": bool(self.share_to),
                "walk": {
                    "remaining": max(0, int((self._walk_deadline or 0) - time.monotonic())),
                    "done": walk.done,
                    "fired": walk.fired,
                }
                if walk
                else None,
                "waypoints": [
                    {
                        "name": name,
                        "heading": guide(self.own_fix, fix).describe()
                        if self.own_fix
                        else "Set a position first",
                    }
                    for name, fix in self.waypoints.places.items()
                ],
                "trail_count": len(self.trail.points),
                "backtrack": [
                    h.describe() for h in self.trail.backtrack(self.own_fix) if h.distance_m > 0.01
                ][:20]
                if self.own_fix
                else [],
            }
