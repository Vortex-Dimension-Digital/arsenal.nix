#!/usr/bin/env python3
"""Update metasploit.

nix-update cannot regenerate the Ruby gemset, so this updater:
  1. finds the latest upstream tag,
  2. points the Gemfile at it,
  3. relocks with bundler and regenerates gemset.nix with bundix,
  4. hands the version to nix-update, which rewrites the source hash.

bundler/bundix and the native libraries they need are not on the update app's
PATH, so when they are missing the script re-execs itself inside `nix shell`.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

# Toolchain used to relock and regenerate the gemset, mirrored from the upstream
# nixpkgs updater. nix-update is included so the final step works no matter how
# the script was launched.
NIX_SHELL_TOOLS = [
    "bundix",
    "git",
    "libiconv",
    "libpcap",
    "libxml2",
    "libxslt",
    "nix-update",
    "pkg-config",
    "postgresql",
    "ruby.devEnv",
    "sqlite",
]

BOOTSTRAP_MARKER = "METASPLOIT_UPDATE_BOOTSTRAPPED"


def reexec_in_nix_shell() -> None:
    installables = [f"nixpkgs#{tool}" for tool in NIX_SHELL_TOOLS]
    env = {**os.environ, BOOTSTRAP_MARKER: "1"}
    os.execvpe(
        "nix",
        ["nix", "shell", *installables, "--command", sys.executable, str(HERE / "update.py")],
        env,
    )


def latest_tag() -> str:
    feed = "https://github.com/rapid7/metasploit-framework/tags.atom"
    with urllib.request.urlopen(feed) as response:
        titles = re.findall(r"<title>([^<]+)</title>", response.read().decode())
    # The first <title> names the feed; tag entries follow, newest first.
    versions = [title for title in titles if re.fullmatch(r"\d+(?:\.\d+)+", title)]
    if not versions:
        raise SystemExit("could not find a metasploit tag in the atom feed")
    return versions[0]


def regenerate_gemset(version: str) -> None:
    gemfile = HERE / "Gemfile"
    gemfile.write_text(
        re.sub(r"refs/tags/[^\"]+", f"refs/tags/{version}", gemfile.read_text())
    )

    lock_env = {**os.environ, "BUNDLE_FORCE_RUBY_PLATFORM": "true"}
    subprocess.run(["bundle", "lock", "--update"], cwd=HERE, env=lock_env, check=True)
    subprocess.run(["bundix"], cwd=HERE, check=True)

    # bundix emits a `dependencies = [...]` line per gem; the bundlerEnv build
    # only needs nokogiri's, which bundix misses. Drop them all, add nokogiri's
    # back (mirrors the upstream nixpkgs updater).
    gemset = HERE / "gemset.nix"
    kept = [
        line
        for line in gemset.read_text().splitlines(keepends=True)
        if not re.match(r"\s*dependencies =", line)
    ]
    gemset.write_text(
        "".join(kept).replace(
            "nokogiri = {",
            'nokogiri = {\n    dependencies = ["mini_portile2" "racc"];',
        )
    )


def main() -> None:
    if BOOTSTRAP_MARKER not in os.environ and shutil.which("bundix") is None:
        reexec_in_nix_shell()

    version = latest_tag()
    regenerate_gemset(version)
    subprocess.run(
        ["nix-update", "--flake", "metasploit", "--version", version],
        cwd=ROOT,
        check=True,
    )
    # bundix emits gemset.nix in its own style; format it so CI's fmt check passes.
    subprocess.run(["nix", "fmt", "--", str(HERE)], cwd=ROOT, check=True)


main()
