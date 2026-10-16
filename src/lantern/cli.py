"""Command line entry point: `lantern demo` runs a scripted two person scenario."""

from __future__ import annotations

import argparse
from collections.abc import Sequence

from lantern.consent import Scope
from lantern.identity import Identity, safety_number
from lantern.node import LanternNode
from lantern.transport import LoopbackHub


def demo() -> None:
    hub = LoopbackHub(range_m=30.0)
    ida, idb = Identity("alice"), Identity("bob")
    alice = LanternNode(ida, hub.endpoint(ida.fp, 0, 0))
    bob = LanternNode(idb, hub.endpoint(idb.fp, 5, 0))

    alice.add_peer(bob.card())
    bob.add_peer(alice.card())
    print("safety number:", safety_number(alice.card(), bob.card()))

    try:
        alice.send_message(bob.fp, "hi")
    except Exception as exc:
        print("before consent ->", type(exc).__name__, exc)

    bob.grant(alice.fp, Scope.MESSAGE, ttl_s=3600)
    alice.send_message(bob.fp, "hi bob, I am by the fountain")
    print("bob inbox:", [m.text for m in bob.inbox])

    alice.grant(bob.fp, Scope.LOCATION, ttl_s=900, precision_m=100)
    alice.share_location(bob.fp, 38.7223, -9.1393)
    print("bob sees alice at:", bob.locations[alice.fp])

    alice.revoke_all()
    print("after revoke, bob still has location:", alice.fp in bob.locations)

    alice.grant(bob.fp, Scope.MESSAGE)
    hub.move(bob.fp, 500, 0)
    print("bob out of radio range, delivered:", bob.send_message(alice.fp, "can you hear me?"))
    print("audit (alice):", [e.event for e in alice.audit])


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lantern")
    parser.add_argument("command", choices=["demo"])
    args = parser.parse_args(argv)
    if args.command == "demo":
        demo()
    return 0
