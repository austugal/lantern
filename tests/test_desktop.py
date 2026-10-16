from __future__ import annotations

import http.client
import json
import math
import threading
import time
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest

from lantern import Identity, LanternNode, LoopbackHub, Scope
from lantern.desktop import DesktopSession
from lantern.lan import LanTransport, local_address, make_invitation, read_invitation
from lantern.location import Fix
from lantern.vault import MAGIC, VaultError, load
from lantern.webapp import AppServer
from lantern.wire import b64d, b64e, canonical


@pytest.fixture
def sessions(tmp_path: Path) -> Iterator[tuple[DesktopSession, DesktopSession]]:
    a, b = DesktopSession(tmp_path / "a", "127.0.0.1"), DesktopSession(tmp_path / "b", "127.0.0.1")
    for session, name in [(a, "Alice"), (b, "Bob")]:
        session.action("create", {"name": name, "passphrase": "twelve words not needed"})
    yield a, b
    a.close()
    b.close()


def pair(a: DesktopSession, b: DesktopSession) -> None:
    for sender, receiver in [(a, b), (b, a)]:
        invitation = sender.action("invite", {"host": "127.0.0.1"})["invitation"]
        preview = receiver.action("preview", {"invitation": invitation})
        receiver.action("pair", {"safety": preview["safety"]})


def pump(a: DesktopSession, b: DesktopSession) -> None:
    # UDP arrival is asynchronous, even on loopback (notably on macOS).
    # Match the running worker rather than assuming four immediate polls suffice.
    deadline = time.monotonic() + 0.25
    while time.monotonic() < deadline:
        a.pump()
        b.pump()
        time.sleep(0.01)


def test_real_udp_message_receipt_and_consent(
    sessions: tuple[DesktopSession, DesktopSession],
) -> None:
    a, b = sessions
    pair(a, b)
    assert a.node and b.node
    with pytest.raises(Exception, match="permission"):
        a.action("message", {"peer": b.node.fp, "text": "No consent"})
    b.action("grant", {"peer": a.node.fp, "scope": "message", "ttl": 900})
    pump(a, b)
    a.action("message", {"peer": b.node.fp, "text": "Olá from real UDP", "ttl": 60})
    assert a.state()["messages"][-1]["status"] == "awaiting_receipt"
    pump(a, b)
    assert b.node.inbox[-1].text == "Olá from real UDP"
    assert a.state()["messages"][-1]["status"] == "received"


def test_pairing_needs_safety_confirmation(sessions: tuple[DesktopSession, DesktopSession]) -> None:
    a, b = sessions
    invitation = a.action("invite", {"host": "127.0.0.1"})["invitation"]
    b.action("preview", {"invitation": invitation})
    assert b.node and not b.node._peers
    with pytest.raises(ValueError, match="safety"):
        b.action("pair", {"safety": "wrong"})
    assert not b.node._peers


def test_location_opt_in_revoke_and_accuracy(
    sessions: tuple[DesktopSession, DesktopSession],
) -> None:
    a, b = sessions
    pair(a, b)
    assert a.node and b.node
    a.action("fix", {"lat": 38.7, "lon": -9.1, "accuracy": 250})
    pump(a, b)
    assert not b.node.locations
    a.action("grant", {"peer": b.node.fp, "scope": "location", "ttl": 60, "precision": 10})
    pump(a, b)
    assert b.node.locations[a.node.fp].precision_m == 250
    a.action("stop_location", {})
    pump(a, b)
    assert not b.node.locations
    assert not a.node.pending_revocations


def test_hidden_page_watchdog_stops_location(
    sessions: tuple[DesktopSession, DesktopSession],
) -> None:
    a, b = sessions
    pair(a, b)
    assert a.node and b.node
    a.action("fix", {"lat": 1, "lon": 1})
    a.action("grant", {"peer": b.node.fp, "scope": "location", "ttl": 60})
    a._heartbeat = time.monotonic() - 30
    pump(a, b)
    assert not a.share_to
    assert not b.node.locations


def test_lock_keeps_identity_but_clears_routes_and_messages(
    sessions: tuple[DesktopSession, DesktopSession],
) -> None:
    a, b = sessions
    pair(a, b)
    assert a.node and a.transport
    fp, transport = a.node.fp, a.transport
    a.action("lock", {})
    assert transport.closed and a.node is None
    a.action("unlock", {"passphrase": "twelve words not needed"})
    assert a.node and a.node.fp == fp
    assert not a.state()["messages"]
    assert not a.state()["peers"][0]["route"]


def test_safe_walk_needs_guardian_and_fresh_position(
    sessions: tuple[DesktopSession, DesktopSession],
) -> None:
    a, b = sessions
    pair(a, b)
    assert a.node and b.node
    with pytest.raises(ValueError, match="fresh position"):
        a.action("walk", {"minutes": 1})
    a.action("fix", {"lat": 1, "lon": 1, "accuracy": 30})
    with pytest.raises(ValueError, match="guardian"):
        a.action("walk", {"minutes": 1})
    a.action("grant", {"peer": b.node.fp, "scope": "sos", "ttl": 900})
    pump(a, b)
    a.action("walk", {"minutes": 1})
    a._walk_deadline = time.monotonic() - 1
    a.fix_at = time.monotonic() - 200
    pump(a, b)
    assert not b.node.alerts
    a.action("fix", {"lat": 1, "lon": 1, "accuracy": 30})
    pump(a, b)
    assert len(b.node.alerts) == 1
    assert b.node.alerts[0].fix.precision_m == 30
    assert a.state()["deliveries"][-1]["status"] == "received"
    pump(a, b)
    assert len(b.node.alerts) == 1


@pytest.mark.parametrize(
    "host", ["8.8.8.8", "169.254.169.254", "0.0.0.0", "224.0.0.1", "localhost", "192.168.1.255"]
)
def test_routes_only_allow_explicit_private_ipv4(host: str) -> None:
    with pytest.raises(ValueError):
        local_address(host)


def test_signed_invitation_rejects_endpoint_tampering_and_expiry() -> None:
    invitation = make_invitation(Identity("Alice"), "192.168.1.4", 22000, 1000)
    assert read_invitation(invitation, 1001).host == "192.168.1.4"
    body = json.loads(b64d(invitation[8:]))
    body["host"] = "192.168.1.5"
    with pytest.raises(ValueError, match="signature"):
        read_invitation("lantern:" + b64e(canonical(body)), 1001)
    with pytest.raises(ValueError, match="expired"):
        read_invitation(invitation, 1601)


@pytest.mark.parametrize("value", [float("nan"), float("inf"), -float("inf")])
def test_nonfinite_fixes_rejected(value: float) -> None:
    with pytest.raises(ValueError):
        Fix(value, 0, 10)
    with pytest.raises(ValueError):
        Fix(0, 0, value)


def test_vault_rejects_memory_bomb_before_deriving(tmp_path: Path) -> None:
    path = tmp_path / "bad.vault"
    path.write_bytes(MAGIC + (2**22).to_bytes(4, "big") + bytes(44))
    with pytest.raises(VaultError):
        load(path, "any passphrase", lambda _: LoopbackHub().endpoint("unused"))


def test_expired_and_stale_location_is_removed() -> None:
    clock = [1000.0]
    hub = LoopbackHub()
    ia, ib = Identity("a"), Identity("b")
    a = LanternNode(ia, hub.endpoint(ia.fp), lambda: clock[0])
    b = LanternNode(ib, hub.endpoint(ib.fp), lambda: clock[0])
    a.add_peer(b.card())
    b.add_peer(a.card())
    a.grant(b.fp, Scope.LOCATION, ttl_s=60)
    a.share_location(b.fp, 1, 1)
    assert b.locations
    clock[0] += 61
    b.purge_expired()
    assert not b.locations
    a.grant(b.fp, Scope.LOCATION, ttl_s=900)
    a.share_location(b.fp, 1, 1)
    clock[0] += 121
    b.purge_expired()
    assert not b.locations


def test_nested_mesh_is_rejected_without_recursive_decode() -> None:
    hub = LoopbackHub()
    identity = Identity("n")
    node = LanternNode(identity, hub.endpoint(identity.fp))
    nested = canonical({"m": 1, "id": "n", "to": node.fp, "ttl": 3, "f": ""})
    outer = canonical({"m": 1, "id": "n", "to": node.fp, "ttl": 3, "f": b64e(nested)})
    assert node.handle(outer) == "rejected:mesh_envelope"


def test_audit_is_bounded() -> None:
    identity = Identity("n")
    node = LanternNode(identity, LoopbackHub().endpoint(identity.fp))
    for _ in range(1000):
        node.handle(b"invalid")
    assert len(node.audit) == 500


def test_safe_walk_rejects_invalid_durations() -> None:
    identity = Identity("n")
    node = LanternNode(identity, LoopbackHub().endpoint(identity.fp))
    for minutes in [0, -1, math.inf, math.nan, 1441]:
        with pytest.raises(ValueError):
            node.start_safe_walk(minutes)


def test_http_requires_token_origin_and_has_offline_assets(tmp_path: Path) -> None:
    session = DesktopSession(tmp_path)
    server = AppServer(session)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:

        def request(path: str, headers: dict[str, str] | None = None) -> tuple[int, bytes, Any]:
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port)
            connection.request("GET", path, headers=headers or {})
            response = connection.getresponse()
            result = response.status, response.read(), response.headers
            connection.close()
            return result

        assert request("/api/state")[0] == 403
        assert request("/api/state", {"X-Lantern-Token": server.token})[0] == 200
        assert (
            request("/api/state", {"X-Lantern-Token": server.token, "Origin": "https://evil.test"})[
                0
            ]
            == 403
        )
        assert request("/", {"Host": "evil.test"})[0] == 403
        status, html, headers = request("/")
        assert status == 200 and b"Your nearby circle" in html
        assert "frame-ancestors 'none'" in headers["Content-Security-Policy"]
        assert request("/app.js")[0] == 200
        assert request("/../profile.lantern")[0] == 404
    finally:
        server.shutdown()
        server.server_close()
        session.close()
        thread.join(timeout=2)


def test_udp_ignores_unknown_sources() -> None:
    import socket

    transport = LanTransport("127.0.0.1")
    sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    received: list[bytes] = []
    transport.set_receiver(received.append)
    try:
        sender.sendto(b"untrusted", ("127.0.0.1", transport.port))
        transport.poll()
        assert not received
    finally:
        transport.close()
        sender.close()


def test_conversation_interleaves_sent_and_received(
    sessions: tuple[DesktopSession, DesktopSession],
) -> None:
    a, b = sessions
    pair(a, b)
    assert a.node and b.node
    for sender, receiver in [(a, b), (b, a)]:
        assert receiver.node
        sender.action("grant", {"peer": receiver.node.fp, "scope": "message", "ttl": 900})
    pump(a, b)
    a.action("message", {"peer": b.node.fp, "text": "first"})
    pump(a, b)
    b.action("message", {"peer": a.node.fp, "text": "second"})
    pump(a, b)
    a.action("message", {"peer": b.node.fp, "text": "third"})
    pump(a, b)
    assert [m["text"] for m in a.state()["messages"]] == ["first", "second", "third"]
    assert [m["text"] for m in b.state()["messages"]] == ["first", "second", "third"]


def test_backtrack_keeps_short_first_leg(sessions: tuple[DesktopSession, DesktopSession]) -> None:
    a, _ = sessions
    a.action("fix", {"lat": 0, "lon": 0, "accuracy": 1})
    a.action("fix", {"lat": 0, "lon": 0.00005, "accuracy": 1})
    assert a.state()["trail_count"] == 1
    assert len(a.state()["backtrack"]) == 1
