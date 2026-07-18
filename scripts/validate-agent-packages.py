#!/usr/bin/env python3
"""Validate inventory, generated drift, and copied package self-containment."""

from __future__ import annotations

import argparse
from pathlib import Path

from plugin_surfaces import generated_drift, validate_isolated_packages, validate_repository


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", action="store_true", help="validate only inventory and contract")
    parser.add_argument("--packages", action="store_true", help="validate only generation and packages")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    errors: list[str] = []
    if args.inventory or not args.packages:
        errors.extend(validate_repository(root))
    if args.packages or not args.inventory:
        errors.extend(generated_drift(root))
        errors.extend(validate_isolated_packages(root))
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Validated agent plugin inventory and packages.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
