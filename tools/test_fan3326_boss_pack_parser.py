#!/usr/bin/env python3
"""Deterministic regression for FAN-3326's exact PixelLab group alias."""

from __future__ import annotations

import hashlib
import io
import json
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
import sys
from unittest.mock import patch

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_fan3326_boss_pack as builder  # noqa: E402
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
    mirrored_frames,
    missing_directions,
    parse_active_job_count,
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


def png_bytes(color: tuple[int, int, int, int]) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGBA", (8, 8), color).save(buffer, format="PNG")
    return buffer.getvalue()


def image_hashes(path: Path) -> tuple[str, str]:
    encoded = hashlib.sha256(path.read_bytes()).hexdigest()
    with Image.open(path) as image:
        pixels = hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()
    return encoded, pixels


def write_check_fixture(
    root: Path,
    *,
    corrupt_source: bool = False,
    corrupt_runtime: bool = False,
    missing_source: bool = False,
) -> tuple[Path, Path]:
    source_root = root / "assets/sprites/bosses/rift_warden_8dir/pixellab_source"
    runtime_root = root / "assets/sprites/bosses/rift_warden_8dir/runtime"
    source_path = source_root / "idle/east.png"
    runtime_path = runtime_root / "idle/east.png"
    source_path.parent.mkdir(parents=True)
    runtime_path.parent.mkdir(parents=True)
    if not missing_source:
        source_path.write_bytes(b"not-a-png" if corrupt_source else png_bytes((255, 0, 0, 255)))
    runtime_path.write_bytes(b"not-a-png" if corrupt_runtime else png_bytes((0, 255, 0, 255)))

    source_encoded, source_pixels = ("source", "source") if corrupt_source or missing_source else image_hashes(source_path)
    runtime_encoded, runtime_pixels = ("runtime", "runtime") if corrupt_runtime else image_hashes(runtime_path)
    manifest = {
        "frames": [{
            "state": "idle",
            "direction": "east",
            "index": 0,
            "source_file": "idle/east.png",
            "runtime_file": "idle/east.png",
            "source_encoded_sha256": source_encoded,
            "source_pixel_sha256": source_pixels,
            "runtime_encoded_sha256": runtime_encoded,
            "runtime_pixel_sha256": runtime_pixels,
        }],
        "states": {"idle": {}},
    }
    manifest_path = source_root / "manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    return source_path, runtime_path


def run_check_fixture(root: Path) -> tuple[int, str, str]:
    output = io.StringIO()
    errors = io.StringIO()
    with patch.object(builder, "ROOT", root):
        with patch.object(builder, "actor_specs", return_value=[("rift_warden", "object", "fixture", {}, {})]):
            with redirect_stdout(output), redirect_stderr(errors):
                result = builder.main(["--check"])
    return result, output.getvalue(), errors.getvalue()


def frame(marker: int) -> Image.Image:
    image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    image.putpixel((marker, 1), (255, 0, 0, 255))
    image.putpixel((7 - marker, 6), (0, 255, 0, 255))
    return image


def saved(directory: Path, name: str, image: Image.Image) -> Path:
    path = directory / (name + ".png")
    image.save(path)
    return path


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

    with tempfile.TemporaryDirectory(prefix="fan3326_decode_test_") as temp_dir:
        fixture_root = Path(temp_dir)
        source, _ = write_check_fixture(fixture_root, corrupt_source=True)
        result, output, errors = run_check_fixture(fixture_root)
        assert result == 6
        assert output.count("FAIL:") == 1
        assert "rift_warden/idle source PNG decode failed" in output
        assert str(source) in output
        assert "cannot identify image file" in output
        assert "Traceback" not in output + errors

    with tempfile.TemporaryDirectory(prefix="fan3326_decode_test_") as temp_dir:
        fixture_root = Path(temp_dir)
        _, runtime = write_check_fixture(fixture_root, corrupt_runtime=True)
        result, output, errors = run_check_fixture(fixture_root)
        assert result == 6
        assert output.count("FAIL:") == 1
        assert "rift_warden/idle runtime PNG decode failed" in output
        assert str(runtime) in output
        assert "cannot identify image file" in output
        assert "Traceback" not in output + errors

    with tempfile.TemporaryDirectory(prefix="fan3326_missing_frame_test_") as temp_dir:
        fixture_root = Path(temp_dir)
        source, _ = write_check_fixture(fixture_root, missing_source=True)
        result, output, errors = run_check_fixture(fixture_root)
        assert result == 6
        assert "FAIL: missing" in output
        assert str(source) in output
        assert "Traceback" not in output + errors

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

    # A direction filled by reflecting its opposite is a mirrored substitute, not a real row.
    with tempfile.TemporaryDirectory() as mirror_dir:
        east = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        east.putpixel((1, 2), (255, 0, 0, 255))
        east.putpixel((6, 5), (0, 255, 0, 255))
        distinct = east.copy()
        distinct.putpixel((3, 3), (0, 0, 255, 255))
        paths = {}
        for name, image in (("east_0", east), ("east_1", distinct), ("west_0", ImageOps.mirror(east)), ("west_1", distinct), ("north_east_0", east), ("north_west_0", distinct)):
            target = Path(mirror_dir) / (name + ".png")
            image.save(target)
            paths[name] = target
        findings = mirrored_frames({
            "east": [paths["east_0"], paths["east_1"]],
            "west": [paths["west_0"], paths["west_1"]],
            "north-east": [paths["north_east_0"]],
            "north-west": [paths["north_west_0"]],
        })
        assert len(findings) == 1, findings
        assert "east[0]=" in findings[0] and "west[0]=" in findings[0], findings
        assert str(paths["east_0"]) in findings[0]
        assert str(paths["west_0"]) in findings[0]

        assert any("row length mismatch" in finding for finding in mirrored_frames({
            "east": [paths["east_0"], paths["east_0"]],
            "west": [paths["west_0"]],
        }))
        missing = Path(mirror_dir) / "missing.png"
        missing_findings = mirrored_frames({"east": [missing], "west": [paths["west_0"]]})
        assert len(missing_findings) == 1
        assert "missing frame: east[0]=" in missing_findings[0]
        assert str(missing) in missing_findings[0]
        counterpart_findings = mirrored_frames({"east": [paths["east_0"]]})
        assert len(counterpart_findings) == 1
        assert "missing counterpart row" in counterpart_findings[0]
        assert "west" in counterpart_findings[0]

    with tempfile.TemporaryDirectory() as permutation_dir:
        directory = Path(permutation_dir)
        east_a = saved(directory, "east_a", frame(1))
        east_b = saved(directory, "east_b", frame(2))
        west_b = saved(directory, "west_b", ImageOps.mirror(frame(2)))
        west_a = saved(directory, "west_a", ImageOps.mirror(frame(1)))
        findings = mirrored_frames({"east": [east_a, east_b], "west": [west_b, west_a]})
        assert len(findings) == 2, findings
        assert any("east[0]=" in finding and "west[1]=" in finding for finding in findings)
        assert any("east[1]=" in finding and "west[0]=" in finding for finding in findings)
        assert any(str(east_a) in finding and str(west_a) in finding for finding in findings)
        assert any(str(east_b) in finding and str(west_b) in finding for finding in findings)

        corrected_west_a = saved(directory, "corrected_west_a", frame(3))
        corrected_west_b = saved(directory, "corrected_west_b", frame(4))
        assert mirrored_frames({
            "east": [east_a, east_b],
            "west": [corrected_west_a, corrected_west_b],
        }) == []

    assert parse_active_job_count("15 jobs:\nabc processing 17%") == 15
    assert parse_active_job_count("no active jobs (nothing pending or processing)\nhint: ...") == 0
    assert parse_active_job_count("error: unauthorized") is None

    print("FAN-3326 parser alias regression passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
