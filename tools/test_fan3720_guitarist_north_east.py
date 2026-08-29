#!/usr/bin/env python3
"""Focused FAN-3720 contract for the Guitarist north-east row."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets/sprites/characters/pixellab/guitarist"
RUNTIME_DIR = ROOT / "assets/sprites/characters/full_frame/guitarist_pixellab"
SPRITEFRAMES = ROOT / "assets/sprites/characters/guitarist_spriteframes.tres"
BASE_REF = "origin/dev"
DIRECTIONS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
CHANGED_DIRECTION = "north-east"


def base_bytes(path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{BASE_REF}:{path}"])


def alpha_bbox(path: Path) -> tuple[int, int, int, int]:
    with Image.open(path).convert("RGBA") as image:
        bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise AssertionError(f"{path} has no visible alpha")
    return bbox


def main() -> int:
    changed = {
        f"assets/sprites/characters/pixellab/guitarist/guitarist_idle_{CHANGED_DIRECTION}.png",
        *{
            f"assets/sprites/characters/pixellab/guitarist/guitarist_move_{CHANGED_DIRECTION}_{index:02d}.png"
            for index in range(6)
        },
        f"assets/sprites/characters/full_frame/guitarist_pixellab/guitarist_idle_{CHANGED_DIRECTION}.png",
        *{
            f"assets/sprites/characters/full_frame/guitarist_pixellab/guitarist_move_{CHANGED_DIRECTION}_{index:02d}.png"
            for index in range(6)
        },
    }
    for direction in DIRECTIONS:
        if direction == CHANGED_DIRECTION:
            continue
        names = [f"guitarist_idle_{direction}.png"] + [
            f"guitarist_move_{direction}_{index:02d}.png" for index in range(6)
        ]
        for name in names:
            for relative in (
                f"assets/sprites/characters/pixellab/guitarist/{name}",
                f"assets/sprites/characters/full_frame/guitarist_pixellab/{name}",
            ):
                if (ROOT / relative).read_bytes() != base_bytes(relative):
                    raise AssertionError(f"unexpected non-north-east change: {relative}")

    source_files = [SOURCE_DIR / f"guitarist_idle_{CHANGED_DIRECTION}.png"] + [
        SOURCE_DIR / f"guitarist_move_{CHANGED_DIRECTION}_{index:02d}.png" for index in range(6)
    ]
    runtime_files = [RUNTIME_DIR / f"guitarist_idle_{CHANGED_DIRECTION}.png"] + [
        RUNTIME_DIR / f"guitarist_move_{CHANGED_DIRECTION}_{index:02d}.png" for index in range(6)
    ]
    widths = []
    for source, runtime in zip(source_files, runtime_files):
        with Image.open(source) as image:
            assert image.size == (240, 240) and image.mode == "RGBA", source
        with Image.open(runtime) as image:
            assert image.size == (512, 512) and image.mode == "RGBA", runtime
        source_box = alpha_bbox(source)
        runtime_box = alpha_bbox(runtime)
        source_height = source_box[3] - source_box[1]
        runtime_height = runtime_box[3] - runtime_box[1]
        assert 110 <= source_height <= 120, (source, source_box)
        assert runtime_height == 245 and runtime_box[3] == 400, (runtime, runtime_box)
        widths.append(source_box[2] - source_box[0])
    assert min(widths) >= 100, f"guitar silhouette width regressed: {widths}"

    manifest = json.loads((SOURCE_DIR / "manifest.json").read_text(encoding="utf-8"))
    regeneration = manifest["fan3720_north_east_regeneration"]
    assert regeneration["pixellab_character_id"] == "d278e753-9885-4550-82ff-81ee3bef297d"
    assert regeneration["animation"]["frame_count"] == 6
    assert len(regeneration["source_frames"]) == 6
    spriteframes = SPRITEFRAMES.read_text(encoding="utf-8")
    assert spriteframes.count("guitarist_move_north-east_") == 6
    assert spriteframes.count("guitarist_idle_north-east.png") == 1
    assert '"name": &"move_north_east"' in spriteframes
    assert '"name": &"walk_north_east"' in spriteframes
    print("FAN-3720 Guitarist north-east contract passed")
    print(f"changed_scope={len(changed)} files; source_widths={widths}; runtime_height=245; footline=400")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
