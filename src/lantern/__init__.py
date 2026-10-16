"""Lantern core: consent-first offline nearby messaging and location sharing."""

from lantern.consent import Grant, Scope
from lantern.errors import ConsentError, LanternError
from lantern.identity import Card, Identity
from lantern.node import LanternNode
from lantern.safety import Alert, SafeWalk
from lantern.transport import LoopbackHub, Transport

__all__ = [
    "Alert",
    "SafeWalk",
    "Card",
    "ConsentError",
    "Grant",
    "Identity",
    "LanternError",
    "LanternNode",
    "LoopbackHub",
    "Scope",
    "Transport",
]
__version__ = "0.3.0"
