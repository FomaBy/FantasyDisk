#!/usr/bin/env python3
"""Retired Jira recovery entry point kept as a fail-closed compatibility stub."""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "RETIRED: release or reassign stale FantasyDisk ownership in Multica. "
        "This Jira archive helper cannot transition issues.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
