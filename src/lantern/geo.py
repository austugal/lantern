"""Offline navigation helpers. Pure maths: no maps, no network, no tiles."""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from lantern.location import Fix, distance_m

_R = 6_371_000.0
_POINTS = [
    "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
]  # fmt: skip


def bearing_deg(a: Fix, b: Fix) -> float:
    """Initial compass bearing from a to b, 0 to 360, 0 is true north."""
    p1, p2 = math.radians(a.lat), math.radians(b.lat)
    dl = math.radians(b.lon - a.lon)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


def compass_point(bearing: float) -> str:
    return _POINTS[int((bearing % 360.0) / 22.5 + 0.5) % 16]


def destination(start: Fix, bearing: float, dist_m: float) -> Fix:
    """Point reached by travelling dist_m from start along bearing."""
    d, brg = dist_m / _R, math.radians(bearing)
    p1, l1 = math.radians(start.lat), math.radians(start.lon)
    p2 = math.asin(math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(brg))
    l2 = l1 + math.atan2(
        math.sin(brg) * math.sin(d) * math.cos(p1), math.cos(d) - math.sin(p1) * math.sin(p2)
    )
    lon = (math.degrees(l2) + 540.0) % 360.0 - 180.0
    return Fix(math.degrees(p2), lon, start.precision_m)


@dataclass(frozen=True)
class Heading:
    """Where to walk to reach a target."""

    distance_m: float
    bearing: float
    uncertainty_m: float

    def describe(self) -> str:
        return (
            f"{self.distance_m:.0f} m {compass_point(self.bearing)} "
            f"({self.bearing:.0f} deg), +/- {self.uncertainty_m:.0f} m"
        )


def guide(me: Fix, target: Fix) -> Heading:
    """Distance and bearing to a peer. Uncertainty comes from both fixes' precision."""
    return Heading(
        distance_m(me, target),
        bearing_deg(me, target),
        (me.precision_m + target.precision_m) / 2.0,
    )


@dataclass
class Trail:
    """Breadcrumb trail that lets you walk back to any earlier point with no map."""

    min_step_m: float = 15.0
    points: list[Fix] = field(default_factory=list)

    def record(self, fix: Fix) -> bool:
        if self.points and distance_m(self.points[-1], fix) < self.min_step_m:
            return False
        self.points.append(fix)
        return True

    def backtrack(self, here: Fix) -> list[Heading]:
        """Legs that retrace the trail from here back to the first recorded point."""
        legs: list[Heading] = []
        current = here
        for p in reversed(self.points):
            legs.append(guide(current, p))
            current = p
        return legs


@dataclass
class Waypoints:
    """Named places (camp, car, meeting point) stored on the device."""

    places: dict[str, Fix] = field(default_factory=dict)

    def save(self, name: str, fix: Fix) -> None:
        self.places[name] = fix

    def nearest(self, here: Fix) -> tuple[str, Heading] | None:
        if not self.places:
            return None
        name = min(self.places, key=lambda n: distance_m(here, self.places[n]))
        return name, guide(here, self.places[name])


@dataclass
class DeadReckoner:
    """Position estimate from heading and distance when GPS is lost (tunnel, canyon).

    Error grows with every step, so the reported precision grows too. Feed it a real
    GPS fix with snap() as soon as one is available.
    """

    fix: Fix
    drift_per_m: float = 0.05

    def advance(self, heading: float, dist_m: float) -> Fix:
        moved = destination(self.fix, heading, dist_m)
        self.fix = Fix(moved.lat, moved.lon, self.fix.precision_m + dist_m * self.drift_per_m)
        return self.fix

    def snap(self, gps: Fix) -> Fix:
        self.fix = gps
        return gps
