#!/usr/bin/env python3
"""Generate the package table in README.md from flake metadata."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


BEGIN_MARKER = "<!-- BEGIN GENERATED PACKAGE DOCS -->"
END_MARKER = "<!-- END GENERATED PACKAGE DOCS -->"
ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
NIX_EXPRESSION = ROOT / "scripts" / "generate-package-docs.nix"


def package_metadata() -> dict[str, dict[str, str]]:
    result = subprocess.run(
        ["nix", "eval", "--json", "--file", str(NIX_EXPRESSION)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def table_cell(value: object) -> str:
    return str(value).replace("|", r"\|").replace("\n", " ")


def generated_table() -> str:
    lines = [
        "| Package | Description | Version |",
        "| --- | --- | --- |",
    ]
    for name, metadata in sorted(package_metadata().items()):
        package = f"[`{name}`](packages/{name}/package.nix)"
        description = table_cell(metadata["description"])
        version = table_cell(metadata["version"])
        lines.append(f"| {package} | {description} | {version} |")
    return "\n".join(lines)


def rendered_readme() -> str:
    content = README.read_text()
    begin = content.find(BEGIN_MARKER)
    end = content.find(END_MARKER)
    if begin == -1 or end == -1 or end < begin:
        raise SystemExit("README.md does not contain valid package-doc markers")

    return (
        content[: begin + len(BEGIN_MARKER)]
        + "\n\n"
        + generated_table()
        + "\n\n"
        + content[end:]
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail instead of writing when README.md is out of date",
    )
    args = parser.parse_args()

    content = rendered_readme()
    current = README.read_text()
    if content == current:
        print("README package table is up to date")
        return

    if args.check:
        print(
            "README package table is out of date; run "
            "./scripts/generate-package-docs.py",
            file=sys.stderr,
        )
        raise SystemExit(1)

    README.write_text(content)
    print("Updated README package table")


if __name__ == "__main__":
    main()
