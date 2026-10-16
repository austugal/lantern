from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from lantern import ConsentError, Identity, LanternNode, LoopbackHub, Scope
from lantern.geo import (
    DeadReckoner,
    Trail,
    Waypoints,
    bearing_deg,
    compass_point,
    destination,
    guide,
)
from lantern.location import Fix, distance_m
from lantern.safety import drifted
from lantern.transport import RADIO_PROFILES, hops_needed, reach_m
from lantern.vault import VaultError, load, save, wipe
from lantern.wire import b64e, canonical


class Clock:
    def __init__(self) -> None:
        self.t = 1_000_000.0

    def __call__(self) -> float:
        return self.t


def chain(
    n: int, spacing: float, link: float = 100.0, relay: bool = True
) -> tuple[list[LanternNode], LoopbackHub, Clock]:
    hub, clock = LoopbackHub(link), Clock()
    ids = [Identity(f"n{i}") for i in range(n)]
    nodes = [LanternNode(i, hub.endpoint(i.fp, k * spacing, 0), clock) for k, i in enumerate(ids)]
    for node in nodes[1:-1]:
        node.relay = relay
    a, z = nodes[0], nodes[-1]
    a.add_peer(z.card())
    z.add_peer(a.card())
    return nodes, hub, clock


# mesh -----------------------------------------------------------------------


def test_message_crosses_1000m_through_relays() -> None:
    nodes, _, _ = chain(11, 100.0, link=110.0)  # ends are 1000 m apart, 10 hops
    a, z = nodes[0], nodes[-1]
    a.mesh_ttl = z.mesh_ttl = 12
    z.grant(a.fp, Scope.MESSAGE)
    a.send_message(z.fp, "one kilometre away")
    assert [m.text for m in z.inbox] == ["one kilometre away"]


def test_default_ttl_is_not_enough_for_ten_hops() -> None:
    nodes, _, _ = chain(11, 100.0, link=110.0)
    a, z = nodes[0], nodes[-1]
    z.grant(a.fp, Scope.MESSAGE)
    assert a.ledger.held == {}


def test_no_relays_no_delivery() -> None:
    nodes, _, _ = chain(11, 100.0, link=110.0, relay=False)
    a, z = nodes[0], nodes[-1]
    a.mesh_ttl = z.mesh_ttl = 12
    z.grant(a.fp, Scope.MESSAGE)
    assert z.ledger.issued and a.ledger.held == {}


def test_ttl_limits_reach() -> None:
    nodes, _, _ = chain(11, 100.0, link=110.0)
    a, z = nodes[0], nodes[-1]
    a.mesh_ttl = z.mesh_ttl = 5
    z.grant(a.fp, Scope.MESSAGE)
    assert a.ledger.held == {}


def test_relays_cannot_read_and_flood_terminates() -> None:
    nodes, _, _ = chain(5, 50.0, link=60.0)
    a, z = nodes[0], nodes[-1]
    z.grant(a.fp, Scope.MESSAGE)
    a.send_message(z.fp, "secret")
    for relay in nodes[1:-1]:
        assert relay.inbox == []
        assert any(e.event == "relayed" for e in relay.audit)


def test_mesh_duplicate_dropped() -> None:
    nodes, _, _ = chain(3, 50.0, link=60.0)
    a, z = nodes[0], nodes[-1]
    z.grant(a.fp, Scope.MESSAGE)
    relay = nodes[1]
    pkt = canonical(
        {
            "m": 1,
            "ttl": 4,
            "to": z.fp,
            "id": "dup",
            "f": b64e(canonical({"v": 1, "to": z.fp, "id": "dup"})),
        }
    )
    relay.handle(pkt)
    assert relay.handle(pkt) == "dropped:duplicate"


def test_reach_helpers() -> None:
    assert reach_m(RADIO_PROFILES["ble"], 10) == 1000
    assert hops_needed(RADIO_PROFILES["ble"], 1000) == 10
    assert hops_needed(RADIO_PROFILES["lora"], 1000) == 1


# forward secrecy ------------------------------------------------------------


def test_each_frame_uses_fresh_ephemeral_key() -> None:
    nodes, _, _ = chain(2, 10.0)
    a, z = nodes
    seen: list[str] = []
    original = z.handle

    def spy(raw: bytes) -> str:
        seen.append(json.loads(raw)["e"])
        return original(raw)

    z.transport.set_receiver(spy)
    z.grant(a.fp, Scope.MESSAGE)
    a.send_message(z.fp, "one")
    a.send_message(z.fp, "two")
    assert len(set(seen)) == len(seen) == 2


def test_ephemeral_key_swap_fails() -> None:
    nodes, _, _ = chain(2, 10.0)
    a, z = nodes
    z.grant(a.fp, Scope.MESSAGE)
    from lantern.wire import b64e

    sent: list[bytes] = []

    def capture(dst: str, f: bytes) -> bool:
        sent.append(f)
        return True

    a.transport.send = capture  # type: ignore[assignment]
    a.send_message(z.fp, "x")
    env = json.loads(sent[0])
    env["e"] = b64e(bytes(32))
    assert z.handle(canonical(env)).startswith("rejected:")


# SOS and safe walk ----------------------------------------------------------


def test_sos_only_reaches_pre_authorised_guardians() -> None:
    hub, clock = LoopbackHub(), Clock()
    ids = [Identity(n) for n in ("me", "mum", "stranger")]
    me, mum, st = (LanternNode(i, hub.endpoint(i.fp, k), clock) for k, i in enumerate(ids))
    for x in (me, mum, st):
        for y in (me, mum, st):
            if x is not y:
                x.add_peer(y.card())
    me.grant(mum.fp, Scope.SOS, ttl_s=3600)
    assert me.trigger_sos(38.7223, -9.1393, "help") == 1
    assert mum.alerts[0].note == "help"
    assert mum.alerts[0].fix.precision_m == 1.0
    assert st.alerts == []


def test_sos_without_grant_sends_nothing_and_receiver_enforces() -> None:
    nodes, _, _ = chain(2, 10.0)
    a, z = nodes
    assert a.trigger_sos(1.0, 1.0) == 0
    a._send(z.fp, "sos", {"lat": 1.0, "lon": 1.0, "prec": 1.0, "note": ""})
    assert z.alerts == []


def test_sos_revoked_stops() -> None:
    nodes, _, _ = chain(2, 10.0)
    a, z = nodes
    g = a.grant(z.fp, Scope.SOS, ttl_s=60)
    a.revoke(g.grant_id)
    assert a.trigger_sos(1.0, 1.0) == 0


def test_safe_walk_fires_only_when_overdue() -> None:
    nodes, _, clock = chain(2, 10.0)
    a, z = nodes
    a.grant(z.fp, Scope.SOS, ttl_s=7200)
    a.start_safe_walk(30)
    clock.t += 29 * 60
    assert a.tick(1.0, 1.0) is False
    clock.t += 2 * 60
    assert a.tick(1.0, 1.0) is True
    assert a.tick(1.0, 1.0) is False
    assert z.alerts[0].note == "Safe walk overdue"


def test_safe_walk_check_in_cancels() -> None:
    nodes, _, clock = chain(2, 10.0)
    a, z = nodes
    a.grant(z.fp, Scope.SOS, ttl_s=7200)
    walk = a.start_safe_walk(10)
    walk.check_in()
    clock.t += 3600
    assert a.tick(1.0, 1.0) is False
    assert z.alerts == []


# disappearing messages ------------------------------------------------------


def test_disappearing_message_purged() -> None:
    nodes, _, clock = chain(2, 10.0)
    a, z = nodes
    z.grant(a.fp, Scope.MESSAGE)
    a.send_message(z.fp, "burn after reading", disappear_s=60)
    a.send_message(z.fp, "keep")
    clock.t += 61
    assert z.purge_expired() == 1
    assert [m.text for m in z.inbox] == ["keep"]
    with pytest.raises(ValueError):
        a.send_message(z.fp, "x", disappear_s=0)


def test_fix_time_recorded() -> None:
    nodes, _, clock = chain(2, 10.0)
    a, z = nodes
    a.grant(z.fp, Scope.LOCATION, ttl_s=600)
    a.share_location(z.fp, 38.7, -9.1)
    assert z.fix_times[a.fp] == clock.t


# geo ------------------------------------------------------------------------


def test_bearing_and_compass() -> None:
    o = Fix(0.0, 0.0, 0.0)
    assert bearing_deg(o, Fix(1.0, 0.0, 0.0)) == pytest.approx(0.0)
    assert bearing_deg(o, Fix(0.0, 1.0, 0.0)) == pytest.approx(90.0)
    assert compass_point(45) == "NE" and compass_point(359) == "N" and compass_point(180) == "S"


def test_destination_roundtrip() -> None:
    start = Fix(38.7223, -9.1393, 0.0)
    end = destination(start, 73.0, 800.0)
    assert distance_m(start, end) == pytest.approx(800.0, abs=1.0)
    assert bearing_deg(start, end) == pytest.approx(73.0, abs=0.5)


def test_guide_describes_with_uncertainty() -> None:
    me = Fix(38.7223, -9.1393, 10.0)
    them = destination(Fix(38.7223, -9.1393, 100.0), 90.0, 500.0)
    h = guide(me, them)
    assert "E" in h.describe() and h.uncertainty_m == 110.0


def test_trail_backtrack_returns_to_start() -> None:
    start = Fix(38.7223, -9.1393, 5.0)
    trail = Trail(min_step_m=10)
    pos = start
    trail.record(start)
    for brg in (0, 0, 90, 90, 180):
        pos = destination(pos, float(brg), 200.0)
        trail.record(pos)
    assert trail.record(pos) is False
    legs = trail.backtrack(pos)
    assert len(legs) == 6
    assert sum(leg.distance_m for leg in legs) == pytest.approx(1000.0, abs=5.0)


def test_waypoints_nearest() -> None:
    w = Waypoints()
    assert w.nearest(Fix(0, 0, 0)) is None
    w.save("car", Fix(38.70, -9.10, 5))
    w.save("camp", Fix(38.80, -9.20, 5))
    name, _ = w.nearest(Fix(38.701, -9.101, 5)) or ("", None)
    assert name == "car"


def test_dead_reckoning_error_grows_and_snap_resets() -> None:
    dr = DeadReckoner(Fix(38.7, -9.1, 5.0))
    f = dr.advance(90.0, 400.0)
    assert f.precision_m == pytest.approx(25.0)
    assert dr.snap(Fix(38.7, -9.1, 4.0)).precision_m == 4.0


def test_drift_alert_respects_precision() -> None:
    me = Fix(38.7223, -9.1393, 10.0)
    near = destination(me, 0.0, 400.0)
    far = destination(me, 0.0, 900.0)
    coarse = Fix(far.lat, far.lon, 800.0)
    out = drifted(me, {"near": near, "far": far, "coarse": coarse}, 500.0)
    assert [d.peer for d in out] == ["far"]


# vault ----------------------------------------------------------------------


def test_vault_roundtrip_preserves_consent_state(tmp_path: Path) -> None:
    nodes, hub, clock = chain(2, 10.0)
    a, z = nodes
    z.grant(a.fp, Scope.MESSAGE)
    a.grant(z.fp, Scope.LOCATION, ttl_s=600)
    path = tmp_path / "v.bin"
    save(a, path, "correct horse battery", n=2**12)
    if os.name == "posix":
        assert (path.stat().st_mode & 0o777) == 0o600
    hub2 = LoopbackHub()
    restored = load(path, "correct horse battery", lambda i: hub2.endpoint(i.fp), clock)
    assert restored.fp == a.fp
    assert restored.ledger.valid_held(z.fp, Scope.MESSAGE, clock.t) is not None
    assert restored.ledger.valid_issued(z.fp, Scope.LOCATION, clock.t) is not None


def test_vault_wrong_passphrase_and_tamper(tmp_path: Path) -> None:
    nodes, _, _ = chain(2, 10.0)
    path = tmp_path / "v.bin"
    save(nodes[0], path, "correct horse battery", n=2**12)
    with pytest.raises(VaultError):
        load(path, "wrong passphrase!!", lambda i: LoopbackHub().endpoint(i.fp))
    blob = bytearray(path.read_bytes())
    blob[-1] ^= 1
    path.write_bytes(bytes(blob))
    with pytest.raises(VaultError):
        load(path, "correct horse battery", lambda i: LoopbackHub().endpoint(i.fp))
    path.write_bytes(b"junk")
    with pytest.raises(VaultError):
        load(path, "correct horse battery", lambda i: LoopbackHub().endpoint(i.fp))


def test_vault_rejects_short_passphrase_and_wipes(tmp_path: Path) -> None:
    nodes, _, _ = chain(2, 10.0)
    path = tmp_path / "v.bin"
    with pytest.raises(ValueError):
        save(nodes[0], path, "short", n=2**12)
    save(nodes[0], path, "long enough pass", n=2**12)
    wipe(path)
    assert not path.exists()


def test_consent_error_still_enforced_with_mesh() -> None:
    nodes, _, _ = chain(3, 50.0, link=60.0)
    a, z = nodes[0], nodes[-1]
    with pytest.raises(ConsentError):
        a.send_message(z.fp, "no grant")
