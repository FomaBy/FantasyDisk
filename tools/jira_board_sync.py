#!/usr/bin/env python3
"""Retired Jira synchronization entry point; Multica is authoritative."""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "RETIRED: Jira synchronization is disabled for FantasyDisk. "
        "Create and update FAN-* issues with the Multica CLI.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
