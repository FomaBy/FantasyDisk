#!/usr/bin/env python3
"""Retired Jira QA entry point kept as a fail-closed compatibility stub."""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "RETIRED: FantasyDisk QA comments and status transitions live in Multica. "
        "This Jira archive helper cannot read or mutate issues.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
