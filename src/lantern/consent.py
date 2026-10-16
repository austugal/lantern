"""Consent grants. Nothing happens between two devices without a live grant."""

from __future__ import annotations

import secrets
from dataclasses import dataclass
from enum import Enum

from lantern.identity import Identity, verify_signature
from lantern.wire import b64d, b64e, canonical

MAX_LOCATION_TTL_S = 24 * 3600
MAX_MESSAGE_TTL_S = 30 * 24 * 3600
MIN_PRECISION_M = 10.0


class Scope(str, Enum):
    """What a grant allows.

    MESSAGE: the grantor lets the grantee send messages to the grantor.
    LOCATION: the grantor lets the grantee see the grantor's location.
    """

    MESSAGE = "message"
    LOCATION = "location"


@dataclass(frozen=True)
class Grant:
    grant_id: str
    scope: Scope
    grantor: str
    grantee: str
    issued_at: int
    expires_at: int
    precision_m: float | None
    grantor_sign_pub: bytes
    sig: bytes = b""

    def _body(self) -> dict[str, object]:
        return {
            "id": self.grant_id,
            "scope": self.scope.value,
            "grantor": self.grantor,
            "grantee": self.grantee,
            "iat": self.issued_at,
            "exp": self.expires_at,
            "prec": self.precision_m,
            "key": b64e(self.grantor_sign_pub),
        }

    def verify(self) -> bool:
        return verify_signature(
            self.grantor_sign_pub, self.sig, b"lantern/grant/1" + canonical(self._body())
        )

    def active(self, now: float) -> bool:
        return self.issued_at <= now < self.expires_at

    def to_dict(self) -> dict[str, object]:
        return {**self._body(), "sig": b64e(self.sig)}

    @classmethod
    def from_dict(cls, d: dict[str, object]) -> Grant:
        prec = d["prec"]
        return cls(
            grant_id=str(d["id"]),
            scope=Scope(str(d["scope"])),
            grantor=str(d["grantor"]),
            grantee=str(d["grantee"]),
            issued_at=int(str(d["iat"])),
            expires_at=int(str(d["exp"])),
            precision_m=None if prec is None else float(str(prec)),
            grantor_sign_pub=b64d(str(d["key"])),
            sig=b64d(str(d["sig"])),
        )


def issue(
    identity: Identity,
    grantee: str,
    scope: Scope,
    now: float,
    ttl_s: int,
    precision_m: float | None = None,
) -> Grant:
    """Create and sign a grant. Expiry is mandatory and capped per scope."""
    cap = MAX_LOCATION_TTL_S if scope is Scope.LOCATION else MAX_MESSAGE_TTL_S
    if ttl_s <= 0 or ttl_s > cap:
        raise ValueError(f"ttl_s must be between 1 and {cap} for {scope.value}")
    if scope is Scope.LOCATION:
        precision_m = float(max(MIN_PRECISION_M, precision_m if precision_m is not None else 50.0))
    else:
        precision_m = None
    unsigned = Grant(
        grant_id=secrets.token_hex(8),
        scope=scope,
        grantor=identity.fp,
        grantee=grantee,
        issued_at=int(now),
        expires_at=int(now) + ttl_s,
        precision_m=precision_m,
        grantor_sign_pub=identity.sign_pub,
    )
    sig = identity.sign(b"lantern/grant/1" + canonical(unsigned._body()))
    return Grant(**{**unsigned.__dict__, "sig": sig})


class Ledger:
    """Grants a node has issued, grants it holds, and which are revoked."""

    def __init__(self) -> None:
        self.issued: dict[str, Grant] = {}
        self.held: dict[str, Grant] = {}
        self.revoked: set[str] = set()

    def valid_issued(self, grantee: str, scope: Scope, now: float) -> Grant | None:
        return self._best(self.issued.values(), "grantee", grantee, scope, now)

    def valid_held(self, grantor: str, scope: Scope, now: float) -> Grant | None:
        return self._best(self.held.values(), "grantor", grantor, scope, now)

    def _best(self, grants: object, attr: str, who: str, scope: Scope, now: float) -> Grant | None:
        best: Grant | None = None
        for g in grants:  # type: ignore[attr-defined]
            if (
                getattr(g, attr) == who
                and g.scope is scope
                and g.grant_id not in self.revoked
                and g.active(now)
                and (best is None or g.expires_at > best.expires_at)
            ):
                best = g
        return best

    def revoke(self, grant_id: str) -> None:
        self.revoked.add(grant_id)
