from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import replace

import pytest

from lantern import (
    ConsentError,
    Grant,
    Identity,
    LanternNode,
    LoopbackHub,
    Scope,
)
from lantern.consent import issue
from lantern.errors import UnknownPeerError
from lantern.identity import Card, safety_number
from lantern.location import Fix, coarsen, distance_m
from lantern.transport import Transport
from lantern.wire import b64e, canonical


class Clock:
    def __init__(self, t: float = 1_000_000.0) -> None:
        self.t = t

    def __call__(self) -> float:
        return self.t


def make_pair(range_m: float = 30.0) -> tuple[LanternNode, LanternNode, LoopbackHub, Clock]:
    hub, clock = LoopbackHub(range_m), Clock()
    ia, ib = Identity("alice"), Identity("bob")
    a = LanternNode(ia, hub.endpoint(ia.fp, 0, 0), clock)
    b = LanternNode(ib, hub.endpoint(ib.fp, 5, 0), clock)
    a.add_peer(b.card())
    b.add_peer(a.card())
    return a, b, hub, clock


# consent gating -------------------------------------------------------------


def test_message_blocked_without_grant() -> None:
    a, b, _, _ = make_pair()
    with pytest.raises(ConsentError):
        a.send_message(b.fp, "hello")
    assert b.inbox == []


def test_message_delivered_with_grant() -> None:
    a, b, _, _ = make_pair()
    b.grant(a.fp, Scope.MESSAGE)
    assert a.send_message(b.fp, "hello")
    assert [m.text for m in b.inbox] == ["hello"]


def test_receiver_enforces_even_if_sender_skips_check() -> None:
    a, b, _, _ = make_pair()
    b.grant(a.fp, Scope.MESSAGE)
    a.send_message(b.fp, "first")
    b.revoke_all()
    # Revoke frame is delivered, but force a send past the sender-side check anyway.
    a.ledger.held.clear()
    a.ledger.held["x"] = issue(b.identity, a.fp, Scope.MESSAGE, 1_000_000.0, 3600)
    a._send(b.fp, "msg", {"text": "sneaky"})
    assert [m.text for m in b.inbox] == ["first"]
    assert any(e.detail == "msg:no_consent" for e in b.audit)


def test_message_grant_does_not_allow_location() -> None:
    a, b, _, _ = make_pair()
    b.grant(a.fp, Scope.MESSAGE)
    a.grant(b.fp, Scope.MESSAGE)
    with pytest.raises(ConsentError):
        a.share_location(b.fp, 38.7, -9.1)


def test_location_requires_grant() -> None:
    a, b, _, _ = make_pair()
    with pytest.raises(ConsentError):
        a.share_location(b.fp, 38.7, -9.1)
    assert b.locations == {}


def test_location_delivered_and_coarsened() -> None:
    a, b, _, _ = make_pair()
    a.grant(b.fp, Scope.LOCATION, ttl_s=600, precision_m=200)
    a.share_location(b.fp, 38.72234, -9.13931)
    fix = b.locations[a.fp]
    assert fix.precision_m == 200
    assert distance_m(fix, Fix(38.72234, -9.13931, 0)) <= 200
    assert (fix.lat, fix.lon) != (38.72234, -9.13931)


def test_precision_floor_enforced() -> None:
    a, b, _, _ = make_pair()
    g = a.grant(b.fp, Scope.LOCATION, ttl_s=60, precision_m=0.5)
    assert g.precision_m == 10.0


def test_unpaired_grant_rejected() -> None:
    a, _, _, _ = make_pair()
    with pytest.raises(UnknownPeerError):
        a.grant("deadbeef", Scope.MESSAGE)


# expiry and revocation ------------------------------------------------------


def test_grant_expires() -> None:
    a, b, _, clock = make_pair()
    b.grant(a.fp, Scope.MESSAGE, ttl_s=60)
    clock.t += 61
    with pytest.raises(ConsentError):
        a.send_message(b.fp, "late")


def test_expired_grant_rejected_by_receiver() -> None:
    a, b, _, clock = make_pair()
    b.grant(a.fp, Scope.MESSAGE, ttl_s=60)
    clock.t += 61
    a._send(b.fp, "msg", {"text": "late"})
    assert b.inbox == []


def test_ttl_caps() -> None:
    a, b, _, _ = make_pair()
    with pytest.raises(ValueError):
        a.grant(b.fp, Scope.LOCATION, ttl_s=24 * 3600 + 1)
    with pytest.raises(ValueError):
        a.grant(b.fp, Scope.LOCATION, ttl_s=0)


def test_revoke_stops_location_and_clears_last_fix() -> None:
    a, b, _, _ = make_pair()
    g = a.grant(b.fp, Scope.LOCATION, ttl_s=600)
    a.share_location(b.fp, 38.7, -9.1)
    assert a.fp in b.locations
    a.revoke(g.grant_id)
    assert a.fp not in b.locations
    with pytest.raises(ConsentError):
        a.share_location(b.fp, 38.7, -9.1)


def test_revoke_all_panic() -> None:
    a, b, _, _ = make_pair()
    a.grant(b.fp, Scope.LOCATION, ttl_s=600)
    a.grant(b.fp, Scope.MESSAGE, ttl_s=600)
    assert a.revoke_all() == 2
    assert a.revoke_all() == 0
    assert a.ledger.valid_issued(b.fp, Scope.LOCATION, 1_000_000.0) is None


def test_receiver_drops_location_after_revoke_even_if_sender_ignores() -> None:
    a, b, _, _ = make_pair()
    g = a.grant(b.fp, Scope.LOCATION, ttl_s=600)
    a.revoke(g.grant_id)
    a._send(b.fp, "loc", {"gid": g.grant_id, "lat": 1.0, "lon": 1.0, "prec": 50.0})
    assert b.locations == {}


def test_receiver_rejects_finer_precision_than_granted() -> None:
    a, b, _, _ = make_pair()
    g = a.grant(b.fp, Scope.LOCATION, ttl_s=600, precision_m=500)
    a._send(b.fp, "loc", {"gid": g.grant_id, "lat": 38.7, "lon": -9.1, "prec": 10.0})
    assert b.locations == {}


def test_unpair_revokes_and_forgets() -> None:
    a, b, _, _ = make_pair()
    a.grant(b.fp, Scope.LOCATION, ttl_s=600)
    a.share_location(b.fp, 38.7, -9.1)
    b.remove_peer(a.fp)
    assert a.fp not in b.locations
    a.remove_peer(b.fp)
    with pytest.raises(UnknownPeerError):
        a.share_location(b.fp, 38.7, -9.1)


def test_broadcast_only_to_grantees() -> None:
    hub, clock = LoopbackHub(), Clock()
    ids = [Identity(n) for n in ("a", "b", "c")]
    n = [LanternNode(i, hub.endpoint(i.fp, k), clock) for k, i in enumerate(ids)]
    for x in n:
        for y in n:
            if x is not y:
                x.add_peer(y.card())
    n[0].grant(n[1].fp, Scope.LOCATION, ttl_s=600)
    assert n[0].broadcast_location(38.7, -9.1) == 1
    assert n[0].fp in n[1].locations
    assert n[0].fp not in n[2].locations


# proximity ------------------------------------------------------------------


def test_out_of_range_not_delivered() -> None:
    a, b, hub, _ = make_pair(range_m=30)
    b.grant(a.fp, Scope.MESSAGE)
    hub.move(b.fp, 500, 0)
    assert a.send_message(b.fp, "hello") is False
    assert hub.dropped == 1
    assert b.inbox == []


# adversarial input ----------------------------------------------------------


class Tap:
    """Transport wrapper that records every frame it sends."""

    def __init__(self, inner: Transport, deliver: bool = True) -> None:
        self.inner = inner
        self.deliver = deliver
        self.frames: list[bytes] = []

    def send(self, dst_fp: str, frame: bytes) -> bool:
        self.frames.append(frame)
        return self.inner.send(dst_fp, frame) if self.deliver else True

    def set_receiver(self, callback: Callable[[bytes], object]) -> None:
        self.inner.set_receiver(callback)


def frame(a: LanternNode, b: LanternNode) -> bytes:
    tap = Tap(a.transport)
    a.transport = tap
    b.grant(a.fp, Scope.MESSAGE)
    a.send_message(b.fp, "payload")
    return tap.frames[-1]


def test_replay_rejected() -> None:
    a, b, _, _ = make_pair()
    raw = frame(a, b)
    assert b.handle(raw) == "rejected:replay"
    assert len(b.inbox) == 1


def test_tampered_frame_rejected() -> None:
    a, b, _, _ = make_pair()
    raw = frame(a, b)
    env = json.loads(raw)
    env["id"] = "ff" * 12
    assert b.handle(canonical(env)) == "rejected:bad_signature"


def test_forged_sender_rejected() -> None:
    a, b, _, _ = make_pair()
    mallory = Identity("mallory")
    hub = LoopbackHub()
    m = LanternNode(mallory, hub.endpoint(mallory.fp))
    m.add_peer(b.card())
    b.add_peer(mallory.card())
    raw = frame(a, b)
    env = json.loads(raw)
    env["from"] = mallory.fp
    assert b.handle(canonical(env)).startswith("rejected:")


def test_unpaired_sender_rejected() -> None:
    a, b, _, _ = make_pair()
    raw = frame(a, b)
    b._peers.pop(a.fp)
    assert b.handle(raw) == "rejected:unpaired"


def test_stale_frame_rejected() -> None:
    a, b, _, clock = make_pair()
    b.grant(a.fp, Scope.MESSAGE)
    tap = Tap(a.transport, deliver=False)
    a.transport = tap
    a.send_message(b.fp, "old")
    clock.t += 301
    assert b.handle(tap.frames[-1]) == "rejected:stale"


@pytest.mark.parametrize("junk", [b"", b"not json", b"[]", b"{}", b"x" * 20000, b'{"v":1}'])
def test_garbage_never_raises(junk: bytes) -> None:
    _, b, _, _ = make_pair()
    assert b.handle(junk).startswith("rejected:")


def test_forged_grant_rejected() -> None:
    a, b, _, _ = make_pair()
    real = issue(a.identity, b.fp, Scope.MESSAGE, 1_000_000.0, 3600)
    forged = replace(real, expires_at=real.expires_at + 10_000)
    assert not forged.verify()
    a._send(b.fp, "grant", {"grant": forged.to_dict()})
    assert b.ledger.held == {}


def test_grant_for_someone_else_rejected() -> None:
    a, b, _, _ = make_pair()
    g = issue(a.identity, "someoneelse", Scope.MESSAGE, 1_000_000.0, 3600)
    a._send(b.fp, "grant", {"grant": g.to_dict()})
    assert b.ledger.held == {}


def test_message_length_limits() -> None:
    a, b, _, _ = make_pair()
    b.grant(a.fp, Scope.MESSAGE)
    with pytest.raises(ValueError):
        a.send_message(b.fp, "")
    with pytest.raises(ValueError):
        a.send_message(b.fp, "x" * 2001)


# identity -------------------------------------------------------------------


def test_card_roundtrip_and_tamper() -> None:
    card = Identity("alice").card()
    assert card.verify()
    assert Card.from_dict(card.to_dict()) == card
    assert not replace(card, name="eve").verify()
    with pytest.raises(ValueError):
        a, _, _, _ = make_pair()
        a.add_peer(replace(card, name="eve"))


def test_cannot_pair_with_self() -> None:
    a, _, _, _ = make_pair()
    with pytest.raises(ValueError):
        a.add_peer(a.card())


def test_safety_number_symmetric_and_distinct() -> None:
    a, b, _, _ = make_pair()
    c = Identity("carol").card()
    assert safety_number(a.card(), b.card()) == safety_number(b.card(), a.card())
    assert safety_number(a.card(), b.card()) != safety_number(a.card(), c)


def test_grant_dict_roundtrip() -> None:
    a, b, _, _ = make_pair()
    g = a.grant(b.fp, Scope.LOCATION, ttl_s=60, precision_m=75)
    assert Grant.from_dict(json.loads(canonical(g.to_dict()))) == g
    assert b64e(g.sig)


# location math --------------------------------------------------------------


def test_coarsen_stays_within_cell_and_validates() -> None:
    f = coarsen(38.7223, -9.1393, 100)
    assert distance_m(f, Fix(38.7223, -9.1393, 0)) < 100
    assert coarsen(38.7223, -9.1393, 100) == f
    with pytest.raises(ValueError):
        coarsen(91, 0, 100)


def test_coarsen_near_pole_and_dateline() -> None:
    assert coarsen(89.9999, 179.9999, 50).lat <= 90
    assert -180 <= coarsen(0, -179.9999, 50).lon <= 180


def test_cli_demo_runs(capsys: pytest.CaptureFixture[str]) -> None:
    from lantern.cli import main

    assert main(["demo"]) == 0
    out = capsys.readouterr().out
    assert "after revoke, bob still has location: False" in out
    assert "delivered: False" in out
