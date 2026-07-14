#!/usr/bin/env python3
"""Retired Jira intake entry point kept as a fail-closed compatibility stub."""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "RETIRED: FantasyDisk intake and claim live in Multica (FAN-*). "
        "This Jira archive helper cannot query or claim work.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
