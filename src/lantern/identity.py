"""Device identity, pairing cards and in-person verification codes."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from cryptography.hazmat.primitives.asymmetric.x25519 import (
    X25519PrivateKey,
    X25519PublicKey,
)
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

from lantern.wire import b64d, b64e, canonical


def _raw(key: Ed25519PublicKey | X25519PublicKey) -> bytes:
    return bytes(key.public_bytes(Encoding.Raw, PublicFormat.Raw))


def fingerprint(sign_pub: bytes, kx_pub: bytes) -> str:
    """Stable 32 hex character identifier derived from both public keys."""
    return hashlib.sha256(b"lantern/fp/1" + sign_pub + kx_pub).hexdigest()[:32]


@dataclass(frozen=True)
class Card:
    """A self-signed public identity. Exchanged in person (QR code, tap, NFC)."""

    name: str
    sign_pub: bytes
    kx_pub: bytes
    sig: bytes

    @property
    def fp(self) -> str:
        return fingerprint(self.sign_pub, self.kx_pub)

    def _signed_bytes(self) -> bytes:
        return canonical({"name": self.name, "sign": b64e(self.sign_pub), "kx": b64e(self.kx_pub)})

    def verify(self) -> bool:
        try:
            Ed25519PublicKey.from_public_bytes(self.sign_pub).verify(
                self.sig, b"lantern/card/1" + self._signed_bytes()
            )
        except (InvalidSignature, ValueError):
            return False
        return True

    def to_dict(self) -> dict[str, str]:
        return {
            "name": self.name,
            "sign": b64e(self.sign_pub),
            "kx": b64e(self.kx_pub),
            "sig": b64e(self.sig),
        }

    @classmethod
    def from_dict(cls, d: dict[str, str]) -> Card:
        return cls(d["name"], b64d(d["sign"]), b64d(d["kx"]), b64d(d["sig"]))


class Identity:
    """Long-term signing (Ed25519) and key-agreement (X25519) keys."""

    def __init__(self, name: str) -> None:
        self.name = name
        self._sign = Ed25519PrivateKey.generate()
        self._kx = X25519PrivateKey.generate()
        self.sign_pub = _raw(self._sign.public_key())
        self.kx_pub = _raw(self._kx.public_key())
        self.fp = fingerprint(self.sign_pub, self.kx_pub)

    def sign(self, data: bytes) -> bytes:
        return bytes(self._sign.sign(data))

    def shared_secret(self, peer_kx_pub: bytes) -> bytes:
        return bytes(self._kx.exchange(X25519PublicKey.from_public_bytes(peer_kx_pub)))

    def card(self) -> Card:
        unsigned = Card(self.name, self.sign_pub, self.kx_pub, b"")
        sig = self.sign(b"lantern/card/1" + unsigned._signed_bytes())
        return Card(self.name, self.sign_pub, self.kx_pub, sig)


def verify_signature(sign_pub: bytes, sig: bytes, data: bytes) -> bool:
    try:
        Ed25519PublicKey.from_public_bytes(sign_pub).verify(sig, data)
    except (InvalidSignature, ValueError):
        return False
    return True


def safety_number(a: Card, b: Card) -> str:
    """Order-independent 30 digit code two people compare out loud or on screen.

    Matching codes mean neither side was handed a substituted key.
    """
    first, second = sorted([a.fp, b.fp])
    digest = hashlib.sha256(b"lantern/safety/1" + first.encode() + second.encode()).digest()
    groups = [int.from_bytes(digest[i : i + 4], "big") % 100000 for i in range(0, 24, 4)]
    return " ".join(f"{g:05d}" for g in groups)
