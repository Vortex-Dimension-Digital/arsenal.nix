#!/usr/bin/env python3
"""Group uncached flake checks into independent CI build jobs.

Reads `nix-eval-jobs --check-cache-status` JSON lines on standard input and
prints a JSON array of build groups. Checks whose outputs are already available
locally or from a substituter are skipped. Checks that need any of the same
derivations built share a group, so parallel jobs never rebuild shared work.
"""

from __future__ import annotations

import json
import sys


def read_jobs() -> list[dict]:
    jobs = []
    errors = []
    for line in sys.stdin:
        if not line.strip():
            continue
        job = json.loads(line)
        if "error" in job:
            errors.append(f"{job.get('attr', '<unknown>')}: {job['error']}")
        else:
            jobs.append(job)

    if errors:
        print("Evaluation failed:", file=sys.stderr)
        for error in errors:
            print(error, file=sys.stderr)
        raise SystemExit(1)

    return jobs


def build_groups(jobs: list[dict]) -> list[dict[str, object]]:
    parent: dict[str, str] = {}

    def find(node: str) -> str:
        while parent[node] != node:
            parent[node] = parent[parent[node]]
            node = parent[node]
        return node

    def union(first: str, second: str) -> None:
        parent.setdefault(first, first)
        parent.setdefault(second, second)
        parent[find(first)] = find(second)

    uncached = [job for job in jobs if job.get("cacheStatus") == "notBuilt"]
    for job in uncached:
        attr_node = f"attr:{job['attr']}"
        parent.setdefault(attr_node, attr_node)
        for drv in job.get("neededBuilds") or [job["drvPath"]]:
            union(attr_node, f"drv:{drv}")

    grouped: dict[str, list[str]] = {}
    for job in uncached:
        grouped.setdefault(find(f"attr:{job['attr']}"), []).append(job["attr"])

    groups = []
    for attrs in grouped.values():
        attrs.sort()
        name = attrs[0] if len(attrs) == 1 else f"{attrs[0]} (+{len(attrs) - 1})"
        groups.append({"name": name, "attrs": " ".join(attrs)})
    return sorted(groups, key=lambda group: group["name"])


def main() -> None:
    jobs = read_jobs()
    groups = build_groups(jobs)

    cached = len(jobs) - sum(len(group["attrs"].split()) for group in groups)
    print(
        f"{len(jobs)} checks, {cached} cached, {len(groups)} build groups",
        file=sys.stderr,
    )
    for group in groups:
        print(f"  {group['attrs']}", file=sys.stderr)

    print(json.dumps(groups))


if __name__ == "__main__":
    main()
