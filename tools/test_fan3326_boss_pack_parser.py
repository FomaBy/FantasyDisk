#!/usr/bin/env python3
"""Deterministic regression for FAN-3326's exact PixelLab group alias."""

from __future__ import annotations

import tempfile
from pathlib import Path
import sys
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_fan3326_boss_pack import (  # noqa: E402
    BuildError,
    DIRECTIONS,
    assert_queued,
    request_frame_count,
    SECRET_STATES,
    check_manifest,
    download_source,
    effective_frame_count,
    expand_urls,
    missing_directions,
    parse_report,
    rebuild_manifest,
    wait_for_pack,
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

    object_surplus = {
        "status": "completed",
        "animations": {
            "move": {"directions": {direction: ["frame"] * 8 for direction in DIRECTIONS}},
            "attack_primary": {"directions": {direction: ["frame"] * 7 for direction in DIRECTIONS}},
            "hit": {"directions": {direction: ["frame"] * 7 for direction in DIRECTIONS}},
            "death": {"directions": {direction: ["frame"] * 7 for direction in DIRECTIONS}},
            "skill_gravity_well": {"directions": {direction: ["frame"] * 7 for direction in DIRECTIONS}},
            "skill_rift_zone": {"directions": {direction: ["frame"] * 7 for direction in DIRECTIONS}},
        },
    }
    with patch("build_fan3326_boss_pack.get_report", return_value=object_surplus):
        objects, secret = wait_for_pack("test-token", 1, 0, batch_boss="rift_warden", log=lambda *_: None)
    assert objects["rift_warden"] == object_surplus
    assert secret is None

    character_surplus = {
        "status": "completed",
        "animations": {
            spec["server_state"]: {
                "directions": {direction: ["frame"] * 7 for direction in DIRECTIONS}
            }
            for spec in SECRET_STATES.values()
        },
    }
    with patch("build_fan3326_boss_pack.get_report", return_value=character_surplus):
        objects, secret = wait_for_pack(
            "test-token", 1, 0, batch_boss="secret_ascension_boss", log=lambda *_: None
        )
    assert objects == {}
    assert secret == character_surplus

    character_group = {
        "directions": {
            direction: ["https://example.invalid/%s/%d.png" % (direction, index) for index in range(7)]
            for direction in DIRECTIONS
        }
    }
    with tempfile.TemporaryDirectory(prefix="fan3326_download_test_") as temp_dir:
        downloaded = []

        def destination(actor, state, direction, index):
            return Path(temp_dir) / state / (direction.replace("-", "_") + "_%02d.png" % index)

        def fake_download(url, path):
            downloaded.append(url)
            Image.new("RGBA", (2, 2), (255, 255, 255, 255)).save(path, format="PNG")
            return Path(path).stat().st_size

        with patch("build_fan3326_boss_pack.source_path", side_effect=destination):
            with patch("build_fan3326_boss_pack.download", side_effect=fake_download):
                rows, _ = download_source(
                    "secret_ascension_boss", "attack", character_group, 6,
                    "character", "test-token", 1, log=lambda *_: None,
                )
        assert all(len(paths) == 6 for paths in rows.values())
        assert all(urls[-1].endswith("/5.png") for urls in (
            [url for url in character_group["directions"][direction]][:6]
            for direction in DIRECTIONS
        ))
        assert len(downloaded) == len(DIRECTIONS) * 6
        assert all(len(character_group["directions"][direction]) == 7 for direction in DIRECTIONS)

    with tempfile.TemporaryDirectory(prefix="fan3326_manifest_test_") as temp_dir:
        missing = Path(temp_dir) / "missing.json"
        assert not check_manifest(missing)
        corrupt = Path(temp_dir) / "corrupt.json"
        corrupt.write_text("{not-json", encoding="utf-8")
        assert not check_manifest(corrupt)
        corrupt.write_text('{"frames": []}', encoding="utf-8")
        assert not check_manifest(corrupt)
        assert not rebuild_manifest(corrupt)

    # FAN-3854 (2026-09-03): PixelLab v3 accepts only even 4..16 frame counts; the
    # request rounds up while the canonical row still consumes the spec count.
    assert [request_frame_count(n) for n in (6, 7, 8, 1, 16, 17)] == [6, 8, 8, 4, 16, 16]
    assert len(expand_urls(["<url>/{i}.png"], 7)) == 7  # surplus 8th frame is ignored
    # A rejected request arrives as plain text, not a JSON-RPC error, and used to be
    # logged as "jobs=unreported" while the builder polled forever.
    rejected = False
    try:
        assert_queued({"_raw": "error: v3 frame_count must be even 4-16, got 7"}, "rift_warden/move")
    except BuildError as error:
        rejected = "rift_warden/move" in str(error)
    assert rejected
    assert_queued({"_raw": "queued 7 jobs"}, "rift_warden/move")
    assert_queued({"jobs": ["x"]}, "rift_warden/move")

    print("FAN-3326 parser alias regression passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
