"""Explicit-route LAN/hotspot UDP. No scanning, internet service or automatic pairing."""

from __future__ import annotations

import ipaddress
import json
import socket
import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from lantern.identity import Card, Identity, verify_signature
from lantern.wire import b64d, b64e, canonical

MAX_DATAGRAM = 16 * 1024
MAX_ROUTES = 64


def local_address(host: str) -> str:
    address = ipaddress.IPv4Address(host)
    allowed = address.is_loopback or any(
        address in ipaddress.IPv4Network(network)
        for network in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
    )
    if not allowed or address.is_multicast or str(address).endswith(".255"):
        raise ValueError("Use a private LAN IPv4 address (or 127.0.0.1 for this computer)")
    return str(address)


@dataclass(frozen=True)
class Invitation:
    card: Card
    host: str
    port: int
    expires: int


def make_invitation(identity: Identity, host: str, port: int, now: float) -> str:
    host = local_address(host)
    if not 1024 <= port <= 65535:
        raise ValueError("port must be 1024..65535")
    body: dict[str, Any] = {
        "v": 1,
        "card": identity.card().to_dict(),
        "host": host,
        "port": port,
        "exp": int(now) + 600,
    }
    return "lantern:" + b64e(
        canonical(
            {
                **body,
                "sig": b64e(identity.sign(b"lantern/invite/1" + canonical(body))),
            }
        )
    )


def read_invitation(value: str, now: float) -> Invitation:
    if not value.startswith("lantern:") or len(value) > 4096:
        raise ValueError("Paste a Lantern invitation")
    try:
        body = json.loads(b64d(value[8:]))
        if not isinstance(body, dict) or body.get("v") != 1:
            raise ValueError("unsupported invitation")
        card = Card.from_dict(body["card"])
        if not card.verify() or not 1 <= len(card.name) <= 40:
            raise ValueError("invalid pairing card")
        if type(body["exp"]) is not int or not now < body["exp"] <= now + 900:
            raise ValueError("Invitation expired; ask for a new one")
        if type(body["port"]) is not int or not 1024 <= body["port"] <= 65535:
            raise ValueError("invalid port")
        signed = {k: body[k] for k in ("v", "card", "host", "port", "exp")}
        if not verify_signature(
            card.sign_pub, b64d(body["sig"]), b"lantern/invite/1" + canonical(signed)
        ):
            raise ValueError("invitation signature is invalid")
        return Invitation(card, local_address(body["host"]), body["port"], body["exp"])
    except (KeyError, TypeError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("invalid invitation") from exc


class LanTransport:
    """Nonblocking socket, pumped under the app lock. True means submitted, not delivered."""

    def __init__(self, host: str = "0.0.0.0", port: int = 0) -> None:
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind((host, port))
        self.socket.setblocking(False)
        self.port = int(self.socket.getsockname()[1])
        self.routes: dict[str, tuple[str, int]] = {}
        self._receiver: Callable[[bytes], object] = lambda _: None
        self.closed = False
        self.received = 0
        self.sent = 0
        self._window = time.monotonic()
        self._budget = 200

    def add_route(self, fp: str, host: str, port: int) -> None:
        if fp not in self.routes and len(self.routes) >= MAX_ROUTES:
            raise ValueError("peer limit reached")
        if not 1024 <= port <= 65535:
            raise ValueError("invalid port")
        self.routes[fp] = (local_address(host), port)

    def set_receiver(self, callback: Callable[[bytes], object]) -> None:
        self._receiver = callback

    def send(self, dst_fp: str, frame: bytes) -> bool:
        if self.closed or dst_fp not in self.routes or len(frame) > MAX_DATAGRAM:
            return False
        try:
            self.socket.sendto(frame, self.routes[dst_fp])
            self.sent += 1
            return True
        except OSError:
            return False

    def broadcast(self, frame: bytes) -> int:
        return sum(self.send(fp, frame) for fp in list(self.routes))

    def poll(self) -> int:
        if self.closed:
            return 0
        if time.monotonic() - self._window >= 1:
            self._window = time.monotonic()
            self._budget = 200
        processed = 0
        for _ in range(64):
            try:
                raw, address = self.socket.recvfrom(MAX_DATAGRAM + 1)
            except BlockingIOError:
                break
            except OSError:
                break
            if len(raw) > MAX_DATAGRAM or address not in self.routes.values():
                continue
            if self._budget <= 0:
                continue
            self._budget -= 1
            self._receiver(raw)
            self.received += 1
            processed += 1
        return processed

    def close(self) -> None:
        self.closed = True
        self.socket.close()
