#!/usr/bin/env python3
"""Generate deterministic, checked-in host adapters and package metadata."""

from __future__ import annotations

import argparse
from pathlib import Path

from plugin_surfaces import generated_drift, write_generated_files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare in memory without writing")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    if args.check:
        drift = generated_drift(root)
        if drift:
            for error in drift:
                print(f"ERROR: {error}")
            return 1
        print("Generated agent packages are current.")
        return 0
    changed = write_generated_files(root)
    if changed:
        for path in changed:
            print(f"generated {path}")
    else:
        print("Generated agent packages were already current.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
