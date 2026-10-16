"""Encrypted on-device storage for identity, peers and consent state.

File layout: magic, scrypt salt, nonce, ChaCha20-Poly1305 ciphertext. The passphrase is
the only secret. A wrong passphrase and a corrupted file are indistinguishable by design.
"""

from __future__ import annotations

import json
import os
import secrets
from collections.abc import Callable
from pathlib import Path

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

from lantern.consent import Grant
from lantern.identity import Card, Identity
from lantern.node import LanternNode
from lantern.transport import Transport
from lantern.wire import b64d, b64e, canonical

MAGIC = b"LNTRN1"
SCRYPT_N = 2**15


class VaultError(Exception):
    """Wrong passphrase, corrupted file or unsupported version."""


def _key(passphrase: str, salt: bytes, n: int) -> bytes:
    return Scrypt(salt=salt, length=32, n=n, r=8, p=1).derive(passphrase.encode())


def save(node: LanternNode, path: Path, passphrase: str, n: int = SCRYPT_N) -> None:
    if len(passphrase) < 8:
        raise ValueError("passphrase must be at least 8 characters")
    sign_seed, kx_secret = node.identity.export_private()
    state = {
        "name": node.identity.name,
        "sign": b64e(sign_seed),
        "kx": b64e(kx_secret),
        "peers": [p.card.to_dict() for p in node._peers.values()],
        "issued": [g.to_dict() for g in node.ledger.issued.values()],
        "held": [g.to_dict() for g in node.ledger.held.values()],
        "revoked": sorted(node.ledger.revoked),
        "seen": list(node._seen),
        "relay": node.relay,
        "mesh_ttl": node.mesh_ttl,
    }
    salt, nonce = secrets.token_bytes(16), secrets.token_bytes(12)
    header = MAGIC + n.to_bytes(4, "big") + salt + nonce
    ct = ChaCha20Poly1305(_key(passphrase, salt, n)).encrypt(nonce, canonical(state), header)
    tmp = path.with_suffix(path.suffix + ".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as fh:
        fh.write(header + ct)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)


def load(
    path: Path,
    passphrase: str,
    make_transport: Callable[[Identity], Transport],
    clock: Callable[[], float] | None = None,
) -> LanternNode:
    blob = path.read_bytes()
    if len(blob) < len(MAGIC) + 4 + 16 + 12 + 16 or not blob.startswith(MAGIC):
        raise VaultError("not a Lantern vault")
    o = len(MAGIC)
    n = int.from_bytes(blob[o : o + 4], "big")
    if not 2**12 <= n <= 2**22:
        raise VaultError("not a Lantern vault")
    salt, nonce = blob[o + 4 : o + 20], blob[o + 20 : o + 32]
    header, ct = blob[: o + 32], blob[o + 32 :]
    try:
        plain = ChaCha20Poly1305(_key(passphrase, salt, n)).decrypt(nonce, ct, header)
    except InvalidTag:
        raise VaultError("wrong passphrase or corrupted vault") from None
    s = json.loads(plain)
    identity = Identity(s["name"], b64d(s["sign"]), b64d(s["kx"]))
    kwargs = {} if clock is None else {"clock": clock}
    node = LanternNode(identity, make_transport(identity), **kwargs)  # type: ignore[arg-type]
    for card in s["peers"]:
        node.add_peer(Card.from_dict(card))
    for g in map(Grant.from_dict, s["issued"]):
        node.ledger.issued[g.grant_id] = g
    for g in map(Grant.from_dict, s["held"]):
        node.ledger.held[g.grant_id] = g
    node.ledger.revoked = set(s["revoked"])
    node._seen = dict.fromkeys(s["seen"])
    node.relay, node.mesh_ttl = bool(s["relay"]), int(s["mesh_ttl"])
    return node


def wipe(path: Path) -> None:
    """Overwrite then delete the vault. Best effort: flash storage may keep old blocks."""
    if path.exists():
        size = path.stat().st_size
        with path.open("r+b") as fh:
            fh.write(secrets.token_bytes(size))
            fh.flush()
            os.fsync(fh.fileno())
        path.unlink()
