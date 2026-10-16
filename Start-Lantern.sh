#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi
if [ ! -f .venv/lantern-ready ]; then
  .venv/bin/python -m pip install -e .
  touch .venv/lantern-ready
fi
exec .venv/bin/python -m lantern app
