#!/usr/bin/env python3

import json
import os
import re
import subprocess
import time
import urllib.error
import urllib.request

def fetch_latest_version():
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "arsenal.nix",
    }
    # Unauthenticated requests share a low per-IP rate limit on CI runners.
    if token := os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        "https://api.github.com/repos/nmap/nmap/tags?per_page=100",
        headers=headers,
    )

    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                tags = json.load(response)
            break
        except (TimeoutError, urllib.error.URLError):
            if attempt == 2:
                raise
            time.sleep(2**attempt)

    for tag in tags:
        match = re.fullmatch(r"v(\d+(?:\.\d+)+)", tag.get("name", ""))
        if match:
            return match.group(1)

    raise SystemExit("Could not find latest stable Nmap version")


version = fetch_latest_version()

subprocess.run(
    ["nix-update", "--flake", "nmap", "--version", version],
    check=True,
)
