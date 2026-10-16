"""PyInstaller entry point; running without arguments launches the desktop app."""

from lantern.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
