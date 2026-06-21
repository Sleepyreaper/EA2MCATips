"""Command-line entry point for ea2mca."""

from __future__ import annotations

import argparse

from ea2mca import __version__


def greet(name: str = "world") -> str:
    """Return a friendly greeting."""
    return f"Hello, {name}! EA2MCA project is ready."


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    parser = argparse.ArgumentParser(prog="ea2mca", description="EA2MCA project tooling.")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.add_argument("--name", default="world", help="Name to greet.")
    args = parser.parse_args(argv)
    print(greet(args.name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
