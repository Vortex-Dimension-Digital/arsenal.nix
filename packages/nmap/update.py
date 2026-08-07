#!/usr/bin/env python3

import re
import subprocess
import urllib.request

html = urllib.request.urlopen("https://nmap.org/download", timeout=30).read().decode()

match = re.search(
    r"Latest(?:\s|<[^>]+>)*stable(?:\s|<[^>]+>)*Nmap release "
    r"tarball:.*?nmap-(\d+(?:\.\d+)+)\.tar\.bz2",
    html,
    re.IGNORECASE | re.DOTALL,
)

if not match:
    raise SystemExit("Could not find latest stable Nmap version")

subprocess.run(
    ["nix-update", "--flake", "nmap", "--version", match.group(1)],
    check=True,
)
