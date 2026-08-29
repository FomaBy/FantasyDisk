#!/usr/bin/env python3
"""FAN-2602 — review sheets for the current runtime Knight body pack.

The sheets are built from the 512x512 PNGs used by Knight's SpriteFrames:

  - ``fan2602_knight_8dir_contact.png``: all eight directions, idle + move 00..05
  - ``fan2602_knight_row_<direction>.png``: one enlarged row per direction

The builder is deterministic and read-only apart from its actor-local preview
outputs. It deliberately leaves the source, runtime frames and SpriteFrames
untouched.

Usage: python3 tools/build_fan2602_knight_animation_review.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/sprites/characters/full_frame/knight_pixellab"
OUT_DIR = ROOT / "docs/design/previews"

# Clockwise runtime order used by the manifest and Hero Select.
DIRECTIONS = [
    "south",
    "south-east",
    "east",
    "north-east",
    "north",
    "north-west",
    "west",
    "south-west",
]

# Tight window around the accepted 512x512 Knight silhouette: 245px visible
# height, bottom-aligned at y=504, with enough x gutter for every direction.
CROP = (160, 253, 352, 510)
BACKGROUND = (30, 30, 36, 255)


def row_frames(direction: str) -> list[str]:
    return [f"knight_idle_{direction}.png"] + [
        f"knight_move_{direction}_{index:02d}.png" for index in range(6)
    ]


def cell(name: str) -> Image.Image:
    image = Image.open(PACK / name).convert("RGBA")
    if image.size != (512, 512):
        raise ValueError(f"expected 512x512 runtime frame, got {image.size}: {name}")
    return image.crop(CROP)


def grid(rows: list[list[str]], scale: int = 1) -> Image.Image:
    width = CROP[2] - CROP[0]
    height = CROP[3] - CROP[1]
    sheet = Image.new("RGBA", (width * len(rows[0]), height * len(rows)), BACKGROUND)
    for row_index, names in enumerate(rows):
        for column_index, name in enumerate(names):
            sheet.alpha_composite(cell(name), (column_index * width, row_index * height))
    if scale != 1:
        sheet = sheet.resize((sheet.width * scale, sheet.height * scale), Image.Resampling.NEAREST)
    return sheet


def main() -> int:
    if not PACK.is_dir():
        print(f"missing runtime pack: {PACK}", file=sys.stderr)
        return 2
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    contact = OUT_DIR / "fan2602_knight_8dir_contact.png"
    grid([row_frames(direction) for direction in DIRECTIONS]).save(contact)
    print(f"contact sheet: {contact.relative_to(ROOT)}")

    for direction in DIRECTIONS:
        zoom = OUT_DIR / f"fan2602_knight_row_{direction.replace('-', '_')}.png"
        grid([row_frames(direction)], scale=2).save(zoom)
        print(f"row zoom:      {zoom.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
