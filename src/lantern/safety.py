"""Group and personal safety logic built on grants."""

from __future__ import annotations

from dataclasses import dataclass

from lantern.location import Fix, distance_m


@dataclass(frozen=True)
class Alert:
    """An SOS received from a peer who pre-authorised you as a guardian."""

    sender: str
    fix: Fix
    note: str
    received_at: float


@dataclass(frozen=True)
class Drift:
    peer: str
    distance_m: float


def drifted(own: Fix, others: dict[str, Fix], limit_m: float) -> list[Drift]:
    """Peers beyond limit_m after conservatively allowing for reported imprecision.

    A peer is flagged only when the distance minus both precisions still exceeds the
    limit, assuming the reported imprecision bounds are reliable. GPS estimates are not guarantees.
    """
    out: list[Drift] = []
    for peer, fix in others.items():
        d = distance_m(own, fix)
        if d - (own.precision_m + fix.precision_m) > limit_m:
            out.append(Drift(peer, d))
    return sorted(out, key=lambda x: -x.distance_m)


@dataclass
class SafeWalk:
    """Dead-man timer. If you do not check in by the deadline, guardians get an SOS."""

    deadline: float
    note: str = "Safe walk overdue"
    done: bool = False
    fired: bool = False

    def check_in(self) -> None:
        self.done = True

    def due(self, now: float) -> bool:
        return not self.done and not self.fired and now >= self.deadline
