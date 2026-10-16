"""Exception types."""


class LanternError(Exception):
    """Base error."""


class ConsentError(LanternError):
    """Raised when an action would happen without valid consent."""


class UnknownPeerError(LanternError):
    """Raised when a peer has not been paired (no card exchanged)."""
