"""Location fixes and precision limiting."""

from __future__ import annotations

import math
from dataclasses import dataclass

_M_PER_DEG_LAT = 111_320.0


@dataclass(frozen=True)
class Fix:
    lat: float
    lon: float
    precision_m: float


def coarsen(lat: float, lon: float, precision_m: float) -> Fix:
    """Snap a point to the centre of a grid cell about precision_m wide.

    The sender applies this before anything leaves the device, so the viewer never
    receives more precision than the sender granted.
    """
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
        raise ValueError("latitude or longitude out of range")
    lat_step = precision_m / _M_PER_DEG_LAT
    cos_lat = max(math.cos(math.radians(lat)), 1e-6)
    lon_step = precision_m / (_M_PER_DEG_LAT * cos_lat)
    snapped_lat = (math.floor(lat / lat_step) + 0.5) * lat_step
    snapped_lon = (math.floor(lon / lon_step) + 0.5) * lon_step
    return Fix(
        max(-90.0, min(90.0, snapped_lat)),
        max(-180.0, min(180.0, snapped_lon)),
        precision_m,
    )


def distance_m(a: Fix, b: Fix) -> float:
    """Great-circle distance in metres (haversine)."""
    p1, p2 = math.radians(a.lat), math.radians(b.lat)
    dphi = p2 - p1
    dl = math.radians(b.lon - a.lon)
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6_371_000.0 * math.asin(min(1.0, math.sqrt(h)))
