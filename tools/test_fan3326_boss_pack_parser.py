#!/usr/bin/env python3
"""Deterministic regression for FAN-3326's exact PixelLab group alias."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_fan3326_boss_pack import DIRECTIONS, parse_report  # noqa: E402


OBJECT_ID = "eb2bfa56-9406-4855-96e6-dc05c9272494"
GROUP_ID = "46160bb5-e182-4810-b980-b88e27a090d6"
UNKNOWN_GROUP_ID = "00000000-0000-4000-8000-000000000001"


def report(label: str, group_id: str) -> str:
    direction_line = ", ".join(DIRECTIONS)
    rows = [
        "status: completed",
        f"id: {OBJECT_ID}",
        "animations (1 groups):",
        f"  {label} [group: {group_id}]",
        f"    directions: {direction_line} (8/8)",
        "    frames: 5",
    ]
    rows.extend(
        f"    {direction}: https://example.invalid/{direction}/{{i}}.png  (i=0..4)"
        for direction in DIRECTIONS
    )
    return "\n".join(rows) + "\n"


def main() -> int:
    real_label = "molten stone colossus absorbs a blow, sh"
    parsed = parse_report(report(real_label, GROUP_ID), asset_id=OBJECT_ID)
    group = parsed["animations"]["hit"]
    assert group["group_id"] == GROUP_ID
    assert group["frame_count"] == 5
    assert set(group["directions"]) == set(DIRECTIONS)
    assert all(len(group["directions"][direction]) == 5 for direction in DIRECTIONS)

    unknown_label = "unrelated provider label"
    unknown = parse_report(report(unknown_label, UNKNOWN_GROUP_ID), asset_id=OBJECT_ID)
    assert "hit" not in unknown["animations"]
    assert unknown["animations"][unknown_label]["group_id"] == UNKNOWN_GROUP_ID

    wrong_object = parse_report(report(real_label, GROUP_ID), asset_id="different-object-id")
    assert "hit" not in wrong_object["animations"]
    assert wrong_object["animations"][real_label]["group_id"] == GROUP_ID

    malformed = parse_report(report(real_label, GROUP_ID[:-1]), asset_id=OBJECT_ID)
    assert not malformed["animations"]

    print("FAN-3326 parser alias regression passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
