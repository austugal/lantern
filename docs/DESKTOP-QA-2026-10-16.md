# Desktop verification — 16 October 2026

Tested source: `4404b74` (`Prepare CI-gated prereleases and correct cross-platform compatibility`).
Environment: Linux x86-64, Python 3.12, Node.js, jsdom. Tests explicitly used this checkout's `src` directory, avoiding an older editable installation in the available Python environment.

## Results

| Check | Result |
| --- | --- |
| Python test suite | 91 passed in 14.06 seconds |
| Ruff lint | Passed |
| Strict mypy | Passed; 19 source files |
| Desktop DOM + HTTP + UDP integration | Passed with two independent application processes |

The integration exercised the shipped HTML/JavaScript against real local HTTP servers and UDP sockets. It verified:

- Vault creation through the UI, invitation exchange, matching safety numbers, and explicit pairing.
- Permission-controlled messaging, message arrival at the second process, and receipt display in the first UI.
- Manual position entry, opt-in position sharing, and removal at the receiver after revocation.
- One-second disappearing messages removed at both sender and receiver.
- Explain-controls popup activation without executing the underlying Lock action; form submission blocked while help is enabled.
- Requests with absent or incorrect capability tokens, and requests from another origin, rejected with HTTP 403.
- Lock and unlock preserve identity but do not restore messages, routes, or live location sharing.
- Incorrect vault passphrases rejected.

The Python suite additionally covers inactive-page location shutdown, stale-position handling for guardian timers, expiry, tampered invitations, unknown UDP senders, malformed mesh envelopes, bounded audit history, and vault input validation.

## Reproduce

```sh
PYTHONPATH=src python -m pytest -q
ruff check .
mypy --strict src tests
# Requires Node.js and jsdom installed separately for development/testing:
LANTERN_PYTHON=/path/to/python LANTERN_JSDOM=/path/to/node_modules/jsdom node tests/desktop_dom_smoke.cjs
```

The DOM test starts and stops two temporary local app instances. It does not use real contacts or external services. `LANTERN_PYTHON` defaults to `python3`; `LANTERN_JSDOM` defaults to normal Node module resolution of `jsdom`.

## Limits

jsdom is not a visual browser. Dialog opening/closing was stubbed, and this test does not establish layout, accessibility, real device geolocation, or browser security-policy enforcement. No physical multi-computer Wi-Fi, Bluetooth, LoRa, Android, or iPhone test was performed in this desktop QA run. Windows/macOS executable execution and signing are outside this Linux run. These checks are not an independent cryptographic or penetration-test certification.
