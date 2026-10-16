"""LanternNode: the consent-enforcing endpoint that ties everything together."""

from __future__ import annotations

import json
import secrets
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

from lantern import consent
from lantern.consent import Grant, Ledger, Scope
from lantern.errors import ConsentError, UnknownPeerError
from lantern.identity import Card, Identity, verify_signature
from lantern.location import Fix, coarsen
from lantern.safety import Alert, SafeWalk
from lantern.transport import Transport
from lantern.wire import b64d, b64e, canonical

PROTOCOL_VERSION = 1
MAX_FRAME_BYTES = 16 * 1024
MAX_TEXT_CHARS = 2000
CLOCK_SKEW_S = 300
SEEN_LIMIT = 4096
DEFAULT_LOCATION_TTL_S = 3600
DEFAULT_MESSAGE_TTL_S = 24 * 3600
MAX_MESH_TTL = 16
DEFAULT_MESH_TTL = 8
MAX_NOTE_CHARS = 200
SOS_PRECISION_M = 1.0


@dataclass(frozen=True)
class Message:
    sender: str
    text: str
    received_at: float
    expires_at: float | None = None


@dataclass
class AuditEntry:
    at: float
    event: str
    peer: str
    detail: str = ""


@dataclass
class _Peer:
    card: Card
    secret: bytes


@dataclass
class LanternNode:
    identity: Identity
    transport: Transport
    clock: Callable[[], float] = time.time
    ledger: Ledger = field(default_factory=Ledger)
    inbox: list[Message] = field(default_factory=list)
    locations: dict[str, Fix] = field(default_factory=dict)
    audit: list[AuditEntry] = field(default_factory=list)
    alerts: list[Alert] = field(default_factory=list)
    fix_times: dict[str, float] = field(default_factory=dict)
    relay: bool = False
    mesh_ttl: int = DEFAULT_MESH_TTL
    safe_walk: SafeWalk | None = None
    _relay_seen: dict[str, None] = field(default_factory=dict)
    _peers: dict[str, _Peer] = field(default_factory=dict)
    _seen: dict[str, None] = field(default_factory=dict)

    def __post_init__(self) -> None:
        self.transport.set_receiver(self.handle)

    # pairing ---------------------------------------------------------------

    @property
    def name(self) -> str:
        return self.identity.name

    @property
    def fp(self) -> str:
        return self.identity.fp

    def card(self) -> Card:
        return self.identity.card()

    def add_peer(self, card: Card) -> str:
        """Pair with a peer after an in-person card exchange. Returns their fingerprint."""
        if not card.verify():
            raise ValueError("card signature is invalid")
        if card.fp == self.fp:
            raise ValueError("cannot pair with yourself")
        known = self._peers.get(card.fp)
        if known is None:
            self._peers[card.fp] = _Peer(card, self.identity.shared_secret(card.kx_pub))
            self._log("pair", card.fp, card.name)
        return card.fp

    def remove_peer(self, fp: str) -> None:
        """Unpair. Revokes everything issued to this peer first so they stop immediately."""
        for g in list(self.ledger.issued.values()):
            if g.grantee == fp and g.grant_id not in self.ledger.revoked:
                self.revoke(g.grant_id)
        self._peers.pop(fp, None)
        self.locations.pop(fp, None)
        self.fix_times.pop(fp, None)
        self._log("unpair", fp)

    # consent ---------------------------------------------------------------

    def grant(
        self,
        peer_fp: str,
        scope: Scope,
        ttl_s: int | None = None,
        precision_m: float | None = None,
    ) -> Grant:
        self._peer(peer_fp)
        if ttl_s is None:
            ttl_s = DEFAULT_LOCATION_TTL_S if scope is Scope.LOCATION else DEFAULT_MESSAGE_TTL_S
        g = consent.issue(self.identity, peer_fp, scope, self.clock(), ttl_s, precision_m)
        self.ledger.issued[g.grant_id] = g
        self._log("grant", peer_fp, f"{scope.value} ttl={ttl_s}s")
        self._send(peer_fp, "grant", {"grant": g.to_dict()})
        return g

    def revoke(self, grant_id: str) -> None:
        g = self.ledger.issued.get(grant_id)
        if g is None:
            raise KeyError(grant_id)
        self.ledger.revoke(grant_id)
        self._log("revoke", g.grantee, g.scope.value)
        if g.grantee in self._peers:
            self._send(g.grantee, "revoke", {"id": grant_id})

    def revoke_all(self, scope: Scope | None = None) -> int:
        """Panic button. Revokes every live grant you issued (optionally one scope)."""
        n = 0
        for g in list(self.ledger.issued.values()):
            if g.grant_id not in self.ledger.revoked and (scope is None or g.scope is scope):
                self.revoke(g.grant_id)
                n += 1
        return n

    # actions ---------------------------------------------------------------

    def send_message(self, peer_fp: str, text: str, disappear_s: int | None = None) -> bool:
        """Send text. disappear_s asks the receiver to delete it after that many seconds."""
        if not text or len(text) > MAX_TEXT_CHARS:
            raise ValueError(f"text must be 1..{MAX_TEXT_CHARS} characters")
        self._peer(peer_fp)
        if self.ledger.valid_held(peer_fp, Scope.MESSAGE, self.clock()) is None:
            raise ConsentError("peer has not granted you permission to message them")
        body: dict[str, Any] = {"text": text}
        if disappear_s is not None:
            if not 1 <= disappear_s <= 7 * 24 * 3600:
                raise ValueError("disappear_s must be between 1 second and 7 days")
            body["ttl"] = disappear_s
        return self._send(peer_fp, "msg", body)

    def share_location(self, peer_fp: str, lat: float, lon: float) -> bool:
        self._peer(peer_fp)
        g = self.ledger.valid_issued(peer_fp, Scope.LOCATION, self.clock())
        if g is None or g.precision_m is None:
            raise ConsentError("you have not granted this peer your location")
        fix = coarsen(lat, lon, g.precision_m)
        return self._send(
            peer_fp,
            "loc",
            {"gid": g.grant_id, "lat": fix.lat, "lon": fix.lon, "prec": fix.precision_m},
        )

    def broadcast_location(self, lat: float, lon: float) -> int:
        """Send a fix to every peer with a live location grant. Returns delivered count."""
        sent = 0
        for fp in list(self._peers):
            if self.ledger.valid_issued(fp, Scope.LOCATION, self.clock()) is not None:
                sent += int(self.share_location(fp, lat, lon))
        return sent

    def trigger_sos(self, lat: float, lon: float, note: str = "") -> int:
        """Send your exact position to every guardian you pre-authorised with Scope.SOS.

        Returns how many guardians were reached. Peers without a live SOS grant get nothing.
        """
        if len(note) > MAX_NOTE_CHARS:
            raise ValueError(f"note must be at most {MAX_NOTE_CHARS} characters")
        fix = coarsen(lat, lon, SOS_PRECISION_M)
        sent = 0
        for fp in list(self._peers):
            if self.ledger.valid_issued(fp, Scope.SOS, self.clock()) is not None:
                body = {"lat": fix.lat, "lon": fix.lon, "prec": fix.precision_m, "note": note}
                sent += int(self._send(fp, "sos", body))
        self._log("sos_sent", "*", f"guardians_reached={sent}")
        return sent

    def start_safe_walk(self, minutes: float, note: str = "Safe walk overdue") -> SafeWalk:
        """Arm a dead-man timer. Call safe_walk.check_in() on arrival."""
        self.safe_walk = SafeWalk(self.clock() + minutes * 60.0, note)
        self._log("safe_walk_start", "*", f"{minutes} min")
        return self.safe_walk

    def tick(self, lat: float, lon: float) -> bool:
        """Call periodically with the latest GPS fix. Fires the SOS if a safe walk is overdue."""
        walk = self.safe_walk
        if walk is not None and walk.due(self.clock()):
            walk.fired = True
            self.trigger_sos(lat, lon, walk.note)
            return True
        return False

    def purge_expired(self) -> int:
        """Delete disappearing messages whose time has passed."""
        now = self.clock()
        keep = [m for m in self.inbox if m.expires_at is None or m.expires_at > now]
        removed = len(self.inbox) - len(keep)
        self.inbox[:] = keep
        return removed

    # receive path ----------------------------------------------------------

    def handle(self, raw: bytes) -> str:
        """Process an incoming frame. Never raises on hostile input."""
        try:
            return self._handle(raw)
        except Exception:  # hostile or malformed input must not crash the node
            return self._reject("?", "malformed")

    def _handle(self, raw: bytes) -> str:
        if len(raw) > MAX_FRAME_BYTES:
            return self._reject("?", "oversize")
        env = json.loads(raw)
        if isinstance(env, dict) and env.get("m") == 1:
            return self._mesh(env)
        if not isinstance(env, dict) or env.get("v") != PROTOCOL_VERSION:
            return self._reject("?", "version")
        sender = str(env["from"])
        if env["to"] != self.fp:
            return self._reject(sender, "wrong_recipient")
        peer = self._peers.get(sender)
        if peer is None:
            return self._reject(sender, "unpaired")
        header = {k: env[k] for k in ("v", "t", "from", "to", "id", "ts", "e", "n", "c")}
        if not verify_signature(
            peer.card.sign_pub, b64d(env["s"]), b"lantern/env/1" + canonical(header)
        ):
            return self._reject(sender, "bad_signature")
        now = self.clock()
        if abs(now - int(env["ts"])) > CLOCK_SKEW_S:
            return self._reject(sender, "stale")
        if env["id"] in self._seen:
            return self._reject(sender, "replay")
        aad = canonical({k: env[k] for k in ("v", "t", "from", "to", "id", "ts", "e")})
        eph = b64d(env["e"])
        try:
            key = self._frame_key(peer, self.identity.shared_secret(eph))
            plain = ChaCha20Poly1305(key).decrypt(b64d(env["n"]), b64d(env["c"]), aad)
        except InvalidTag:
            return self._reject(sender, "bad_ciphertext")
        self._seen[env["id"]] = None
        while len(self._seen) > SEEN_LIMIT:
            self._seen.pop(next(iter(self._seen)))
        body = json.loads(plain)
        kind = str(env["t"])
        reason = self._dispatch(kind, sender, body, now)
        return f"ok:{kind}" if reason is None else self._reject(sender, reason, kind)

    def _dispatch(self, kind: str, sender: str, body: dict[str, Any], now: float) -> str | None:
        if kind == "grant":
            g = Grant.from_dict(body["grant"])
            if not g.verify() or g.grantor != sender or g.grantee != self.fp:
                return "bad_grant"
            if g.grantor_sign_pub != self._peers[sender].card.sign_pub or not g.active(now):
                return "bad_grant"
            self.ledger.held[g.grant_id] = g
            self._log("grant_received", sender, g.scope.value)
            return None
        if kind == "revoke":
            gid = str(body["id"])
            held = self.ledger.held.get(gid)
            if held is None or held.grantor != sender:
                return "unknown_grant"
            self.ledger.revoke(gid)
            if held.scope is Scope.LOCATION:
                self.locations.pop(sender, None)
                self.fix_times.pop(sender, None)
            self._log("revoked_by_peer", sender, held.scope.value)
            return None
        if kind == "msg":
            if self.ledger.valid_issued(sender, Scope.MESSAGE, now) is None:
                return "no_consent"
            text = str(body["text"])
            if not text or len(text) > MAX_TEXT_CHARS:
                return "bad_text"
            ttl = body.get("ttl")
            expires = now + min(max(int(ttl), 1), 7 * 24 * 3600) if ttl is not None else None
            self.inbox.append(Message(sender, text, now, expires))
            return None
        if kind == "loc":
            held = self.ledger.valid_held(sender, Scope.LOCATION, now)
            if held is None or held.grant_id != body["gid"] or held.precision_m is None:
                return "no_consent"
            fix = Fix(float(body["lat"]), float(body["lon"]), float(body["prec"]))
            if fix.precision_m < held.precision_m:
                return "precision_exceeds_grant"
            self.locations[sender] = fix
            self.fix_times[sender] = now
            return None
        if kind == "sos":
            if self.ledger.valid_held(sender, Scope.SOS, now) is None:
                return "no_consent"
            fix = Fix(float(body["lat"]), float(body["lon"]), float(body["prec"]))
            note = str(body.get("note", ""))[:MAX_NOTE_CHARS]
            self.alerts.append(Alert(sender, fix, note, now))
            self._log("sos_received", sender, note)
            return None
        return "unknown_type"

    # internals -------------------------------------------------------------

    def _peer(self, fp: str) -> _Peer:
        peer = self._peers.get(fp)
        if peer is None:
            raise UnknownPeerError(fp)
        return peer

    def _frame_key(self, peer: _Peer, ephemeral_secret: bytes) -> bytes:
        salt = "".join(sorted([self.fp, peer.card.fp])).encode()
        return HKDF(hashes.SHA256(), 32, salt, b"lantern/key/2").derive(
            peer.secret + ephemeral_secret
        )

    def _send(self, peer_fp: str, kind: str, body: dict[str, Any]) -> bool:
        peer = self._peer(peer_fp)
        eph = X25519PrivateKey.generate()
        eph_pub = eph.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
        key = self._frame_key(
            peer, eph.exchange(X25519PublicKey.from_public_bytes(peer.card.kx_pub))
        )
        header: dict[str, Any] = {
            "v": PROTOCOL_VERSION,
            "t": kind,
            "from": self.fp,
            "to": peer_fp,
            "id": secrets.token_hex(12),
            "ts": int(self.clock()),
            "e": b64e(eph_pub),
        }
        nonce = secrets.token_bytes(12)
        ct = ChaCha20Poly1305(key).encrypt(nonce, canonical(body), canonical(header))
        header["n"], header["c"] = b64e(nonce), b64e(ct)
        sig = self.identity.sign(b"lantern/env/1" + canonical(header))
        frame = canonical({**header, "s": b64e(sig)})
        if self.transport.send(peer_fp, frame):
            return True
        if self.mesh_ttl <= 0:
            return False
        packet = canonical(
            {
                "m": 1,
                "ttl": min(self.mesh_ttl, MAX_MESH_TTL),
                "to": peer_fp,
                "id": header["id"],
                "f": b64e(frame),
            }
        )
        self._relay_seen[header["id"]] = None
        return self.transport.broadcast(packet) > 0

    def _mesh(self, pkt: dict[str, Any]) -> str:
        """Relay or deliver a flooded packet. Relays only ever see ciphertext."""
        pid = str(pkt["id"])
        if pid in self._relay_seen:
            return "dropped:duplicate"
        self._relay_seen[pid] = None
        while len(self._relay_seen) > SEEN_LIMIT:
            self._relay_seen.pop(next(iter(self._relay_seen)))
        if pkt["to"] == self.fp:
            return self._handle(b64d(pkt["f"]))
        ttl = min(int(pkt["ttl"]), MAX_MESH_TTL)
        if not self.relay or ttl <= 1:
            return "dropped:not_relaying"
        self.transport.broadcast(canonical({**pkt, "ttl": ttl - 1}))
        self._log("relayed", str(pkt["to"]))
        return "relayed"

    def _reject(self, peer: str, reason: str, kind: str = "") -> str:
        self._log("rejected", peer, f"{kind}:{reason}" if kind else reason)
        return f"rejected:{reason}"

    def _log(self, event: str, peer: str, detail: str = "") -> None:
        self.audit.append(AuditEntry(self.clock(), event, peer, detail))
