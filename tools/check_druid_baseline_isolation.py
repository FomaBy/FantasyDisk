#!/usr/bin/env python3
"""FAN-3383: guards a Druid-only rebuild of the 51-row ultimate effectiveness
baseline against the FAN-2665 defect, where a full-file regeneration silently
changed an unrelated `doctor/restore_potion` row.

This compares the baseline row-by-row, keyed by `class_id/weapon_id`, against
a known-good base revision. Only the scoped class's rows may differ; any other
row that moved is reported as a violation. It is a pure data diff — no Godot
run is needed, so it is immune to any live-measurement noise in unrelated
classes.

`--class` scopes the guard to whichever class-conversion card is in flight
(FAN-2533 reuses it for `guitarist`); it defaults to the Druid scope it shipped
with.

Usage:
    python3 tools/check_druid_baseline_isolation.py --base origin/dev
    python3 tools/check_druid_baseline_isolation.py --base origin/dev --class guitarist
    python3 tools/check_druid_baseline_isolation.py --base <sha> --path build/ultimate_effectiveness_baseline.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

DEFAULT_PATH = "build/ultimate_effectiveness_baseline.json"
ALLOWED_DRIFT_CLASS = "druid"


def rows_by_key(document: dict) -> dict[str, dict]:
    return {str(row.get("key", "")): row for row in document.get("rows", [])}


def find_non_druid_drift(
    base_rows: dict[str, dict],
    candidate_rows: dict[str, dict],
    allowed_class: str = ALLOWED_DRIFT_CLASS,
) -> list[str]:
    """Returns one message per non-`allowed_class` row that differs, is
    missing, or was added between `base_rows` and `candidate_rows`."""
    violations: list[str] = []
    for key, base_row in base_rows.items():
        if str(base_row.get("class_id", "")) == allowed_class:
            continue
        if key not in candidate_rows:
            violations.append(f"row.missing: {key} present in base, absent from candidate")
            continue
        if candidate_rows[key] != base_row:
            violations.append(f"row.drifted: {key} changed outside the {allowed_class} scope")
    for key, candidate_row in candidate_rows.items():
        if key in base_rows:
            continue
        if str(candidate_row.get("class_id", "")) != allowed_class:
            violations.append(f"row.unexpected: {key} is new and outside the {allowed_class} scope")
    return violations


def _git_show(ref: str, path: str) -> dict:
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="git ref holding the known-good baseline")
    parser.add_argument("--path", default=DEFAULT_PATH, help="repo-relative path to the baseline JSON")
    parser.add_argument(
        "--class", dest="allowed_class", default=ALLOWED_DRIFT_CLASS,
        help="the only class_id whose rows may differ",
    )
    args = parser.parse_args()

    base_document = _git_show(args.base, args.path)
    candidate_document = json.loads(Path(args.path).read_text(encoding="utf-8"))

    violations = find_non_druid_drift(
        rows_by_key(base_document), rows_by_key(candidate_document), args.allowed_class
    )
    if violations:
        for violation in violations:
            print(f"check_druid_baseline_isolation: {violation}", file=sys.stderr)
        print(f"check_druid_baseline_isolation: FAIL ({len(violations)} violation(s))", file=sys.stderr)
        return 1

    print(f"check_druid_baseline_isolation: PASS (no row drift outside {args.allowed_class})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
