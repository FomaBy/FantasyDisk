#!/usr/bin/env python3
"""Deterministic regression for FAN-3326's exact PixelLab group alias."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_fan3326_boss_pack import (  # noqa: E402
    DIRECTIONS,
    effective_frame_count,
    expand_urls,
    missing_directions,
    parse_report,
)


OBJECT_ID = "eb2bfa56-9406-4855-96e6-dc05c9272494"
GROUP_ID = "46160bb5-e182-4810-b980-b88e27a090d6"
UNKNOWN_GROUP_ID = "00000000-0000-4000-8000-000000000001"


def report(label: str, group_id: str, frame_counts: list[int] | None = None) -> str:
    frame_counts = frame_counts or [5] * len(DIRECTIONS)
    direction_line = ", ".join(DIRECTIONS)
    rows = [
        "status: completed",
        f"id: {OBJECT_ID}",
        "animations (1 groups):",
        f"  {label} [group: {group_id}]",
        f"    directions: {direction_line} (8/8)",
        f"    frames: {max(frame_counts)}",
    ]
    rows.extend(
        f"    {direction}: https://example.invalid/{direction}/{{i}}.png  (i=0..{count - 1})"
        for direction, count in zip(DIRECTIONS, frame_counts)
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

    surplus = parse_report(
        report(real_label, GROUP_ID, [7, 7, 7, 7, 6, 7, 7, 7]),
        asset_id=OBJECT_ID,
    )
    surplus_group = surplus["animations"]["hit"]
    canonical_spec = {"frames": 6}
    assert surplus_group["frame_count"] == 7
    assert effective_frame_count(surplus_group, canonical_spec) == 6
    assert missing_directions(surplus_group, canonical_spec) == (6, [])
    assert len(surplus_group["directions"]["east"]) == 7
    assert len(surplus_group["directions"]["west"]) == 6
    assert expand_urls(surplus_group["directions"]["east"], 6)[-1].endswith("/5.png")

    short = parse_report(
        report(real_label, GROUP_ID, [7, 7, 7, 7, 5, 7, 7, 7]),
        asset_id=OBJECT_ID,
    )
    assert missing_directions(short["animations"]["hit"], canonical_spec) == (6, ["west"])

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
