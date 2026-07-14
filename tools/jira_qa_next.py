#!/usr/bin/env python3
"""Retired Jira QA intake entry point kept as a fail-closed compatibility stub."""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "RETIRED: discover FantasyDisk review work in Multica with "
        "`multica issue list --status in_review`; Jira is archive-only.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
