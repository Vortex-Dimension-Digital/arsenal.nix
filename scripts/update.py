#!/usr/bin/env python3
"""List or update packages in this repository."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path


ROOT = Path(
    os.environ.get("ARSENAL_NIX_ROOT", Path(__file__).resolve().parent.parent)
).resolve()
PACKAGES = ROOT / "packages"


def package_names() -> list[str]:
    return sorted(
        path.name
        for path in PACKAGES.iterdir()
        if path.is_dir() and (path / "package.nix").is_file()
    )


def update_names() -> list[str]:
    return [
        name
        for name in package_names()
        if not (PACKAGES / name / "update-owner").is_file()
    ]


def update(package: str) -> None:
    if package not in package_names():
        raise SystemExit(f"Unknown package: {package}")

    package_dir = PACKAGES / package
    owner_file = package_dir / "update-owner"
    if owner_file.is_file():
        owner = owner_file.read_text().strip()
        if owner not in package_names():
            raise SystemExit(f"Invalid update owner for {package}: {owner}")
        print(f"{package} shares its source with {owner}; updating {owner}")
        package = owner
        package_dir = PACKAGES / package

    custom_updater = package_dir / "update.py"
    args_file = package_dir / "nix-update-args"

    if custom_updater.is_file():
        command = [str(custom_updater)]
    else:
        extra_args = []
        if args_file.is_file():
            extra_args = [
                line
                for raw_line in args_file.read_text().splitlines()
                if (line := raw_line.strip()) and not line.startswith("#")
            ]
        command = ["nix-update", "--flake", package, *extra_args]

    subprocess.run(command, cwd=ROOT, check=True)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("package", nargs="?", help="package to update")
parser.add_argument(
    "--list",
    action="store_true",
    help="print package names as a JSON array",
)
parser.add_argument(
    "--list-updates",
    action="store_true",
    help="print independent package update targets as a JSON array",
)
args = parser.parse_args()

if args.list and args.list_updates:
    parser.error("--list and --list-updates are mutually exclusive")
elif args.list:
    print(json.dumps(package_names()))
elif args.list_updates:
    print(json.dumps(update_names()))
elif args.package:
    update(args.package)
else:
    parser.error("provide a package name, --list, or --list-updates")
