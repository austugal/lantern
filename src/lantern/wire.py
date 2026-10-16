"""Canonical JSON and base64 helpers shared by the wire format."""

from __future__ import annotations

import base64
import json
from typing import Any


def b64e(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def b64d(text: str) -> bytes:
    return base64.b64decode(text.encode("ascii"), validate=True)


def canonical(obj: Any) -> bytes:
    """Deterministic JSON bytes used for everything that is signed."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
