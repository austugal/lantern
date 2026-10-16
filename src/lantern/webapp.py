"""Loopback-only desktop UI with per-process capability token and origin checks."""

from __future__ import annotations

import json
import secrets
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from importlib.resources import files
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from lantern.desktop import DesktopSession
from lantern.errors import LanternError
from lantern.vault import VaultError

MAX_REQUEST = 32 * 1024


class AppServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = False

    def __init__(self, session: DesktopSession, port: int = 0) -> None:
        self.session = session
        self.token = secrets.token_urlsafe(32)
        super().__init__(("127.0.0.1", port), Handler)
        self.origin = f"http://127.0.0.1:{self.server_port}"

    @property
    def url(self) -> str:
        return f"{self.origin}/#{self.token}"


class Handler(BaseHTTPRequestHandler):
    server: AppServer
    protocol_version = "HTTP/1.0"

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, format: str, *args: Any) -> None:
        # Do not log invitations, passphrases, message text or token-bearing URLs.
        pass

    def _reply(self, code: int, body: bytes, kind: str = "application/json") -> None:
        self.send_response(code)
        self.send_header("Content-Type", kind + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self'; "
            "connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; "
            "base-uri 'none'; form-action 'none'",
        )
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code: int, payload: dict[str, Any]) -> None:
        self._reply(code, json.dumps(payload, allow_nan=False).encode())

    def _origin_ok(self) -> bool:
        return (
            self.headers.get("Host") == self.server.origin.removeprefix("http://")
            and self.headers.get("Origin", self.server.origin) == self.server.origin
            and self.headers.get("Sec-Fetch-Site", "same-origin") not in {"cross-site", "same-site"}
        )

    def _authorized(self) -> bool:
        token = self.headers.get("X-Lantern-Token", "")
        return self._origin_ok() and secrets.compare_digest(token, self.server.token)

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if not self._origin_ok():
            self._json(403, {"error": "Local origin required"})
            return
        if path == "/api/state":
            if not self._authorized():
                self._json(403, {"error": "Reopen the private app link from the launcher"})
                return
            self._json(200, self.server.session.state(self.headers.get("X-Lantern-Active") == "1"))
            return
        resources = {
            "/": ("index.html", "text/html"),
            "/app.js": ("app.js", "text/javascript"),
            "/style.css": ("style.css", "text/css"),
            "/icon.svg": ("icon.svg", "image/svg+xml"),
        }
        if path not in resources:
            self._json(404, {"error": "Not found"})
            return
        name, kind = resources[path]
        self._reply(200, files("lantern").joinpath("web").joinpath(name).read_bytes(), kind)

    def do_POST(self) -> None:
        if not self._authorized():
            self._json(403, {"error": "Local app authorization required"})
            return
        if self.headers.get("Content-Type") != "application/json" or self.headers.get(
            "Transfer-Encoding"
        ):
            self._json(415, {"error": "JSON required"})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            size = -1
        if not 0 < size <= MAX_REQUEST:
            self._json(413, {"error": "Invalid request size"})
            return
        path = urlsplit(self.path).path
        if not path.startswith("/api/"):
            self._json(404, {"error": "Not found"})
            return
        try:
            data = json.loads(self.rfile.read(size))
            if not isinstance(data, dict):
                raise ValueError("Expected a JSON object")
            result = self.server.session.action(path[5:], data)
            self._json(200, result)
        except (
            ValueError,
            KeyError,
            TypeError,
            OverflowError,
            LanternError,
            VaultError,
            OSError,
        ) as exc:
            # Explicit user-facing errors; no tracebacks or private state in the response.
            self._json(400, {"error": str(exc)[:300]})


def serve(data_dir: Path, port: int = 0, open_browser: bool = True) -> None:
    session = DesktopSession(data_dir)
    server = AppServer(session, port)
    session.start_worker()
    print("Lantern desktop preview. Keep this process running; Ctrl+C locks and exits.")
    print("Open this private local link (do not share it):", server.url, flush=True)
    if open_browser:
        threading.Timer(0.3, lambda: webbrowser.open(server.url)).start()
    try:
        server.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        session.close()
