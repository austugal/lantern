"""Transport abstraction plus an in-process simulator with a radio range."""

from __future__ import annotations

import math
from collections.abc import Callable
from typing import Protocol


class Transport(Protocol):
    """Anything that can move opaque frames to a nearby peer (BLE, Wi-Fi Aware, ...)."""

    def send(self, dst_fp: str, frame: bytes) -> bool: ...

    def set_receiver(self, callback: Callable[[bytes], object]) -> None: ...


class LoopbackHub:
    """Simulated radio environment. Frames only reach peers within range_m."""

    def __init__(self, range_m: float = 30.0) -> None:
        self.range_m = range_m
        self._pos: dict[str, tuple[float, float]] = {}
        self._rx: dict[str, Callable[[bytes], object]] = {}
        self.dropped = 0

    def endpoint(self, fp: str, x: float = 0.0, y: float = 0.0) -> _Endpoint:
        self._pos[fp] = (x, y)
        return _Endpoint(self, fp)

    def move(self, fp: str, x: float, y: float) -> None:
        self._pos[fp] = (x, y)

    def _deliver(self, src: str, dst: str, frame: bytes) -> bool:
        if dst not in self._rx or src not in self._pos or dst not in self._pos:
            self.dropped += 1
            return False
        sx, sy = self._pos[src]
        dx, dy = self._pos[dst]
        if math.hypot(sx - dx, sy - dy) > self.range_m:
            self.dropped += 1
            return False
        self._rx[dst](frame)
        return True


class _Endpoint:
    def __init__(self, hub: LoopbackHub, fp: str) -> None:
        self._hub = hub
        self._fp = fp

    def send(self, dst_fp: str, frame: bytes) -> bool:
        return self._hub._deliver(self._fp, dst_fp, frame)

    def set_receiver(self, callback: Callable[[bytes], object]) -> None:
        self._hub._rx[self._fp] = callback
