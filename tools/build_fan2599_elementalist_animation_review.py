#!/usr/bin/env python3
"""FAN-2599 — 8-direction review sheets for the runtime hero elementalist pack.

Renders the acceptance evidence the card asks for, straight from the runtime
PNGs the game plays (assets/sprites/characters/full_frame/elementalist_pixellab)
plus one sheet of the 240px PixelLab source rows, so a mid-loop identity split
can be traced to the source art rather than runtime normalization:

  - fan2599_elementalist_8dir_contact.png  8 direction rows x (idle + move 00..05)
  - fan2599_elementalist_row_<dir>.png     2x zoom of every direction row
  - fan2599_elementalist_source_rows.png   raw 240px PixelLab move rows

Deterministic and read-only; nothing is auto-fixed.

Usage: python3 tools/build_fan2599_elementalist_animation_review.py
Output: docs/design/previews/
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/sprites/characters/full_frame/elementalist_pixellab"
SOURCE = ROOT / "assets/sprites/characters/pixellab/elementalist"
OUT_DIR = ROOT / "docs/design/previews"

# Clockwise runtime order (manifest "directions"); rows read top to bottom.
DIRECTIONS = ["south", "south-east", "east", "north-east",
              "north", "north-west", "west", "south-west"]
# Tight window on the 512x512 runtime canvas: visible art is ~247 px tall,
# bottom-aligned with 40 px padding (alpha bboxes y 225..472, x 134..377).
CROP = (130, 215, 382, 480)
BACKGROUND = (30, 30, 36, 255)


def row_frames(direction: str) -> list[str]:
    return [f"elementalist_idle_{direction}.png"] + [
        f"elementalist_move_{direction}_{index:02d}.png" for index in range(6)
    ]


def cell(name: str) -> Image.Image:
    return Image.open(PACK / name).convert("RGBA").crop(CROP)


def grid(rows: list[list[str]], scale: int = 1) -> Image.Image:
    width, height = CROP[2] - CROP[0], CROP[3] - CROP[1]
    sheet = Image.new("RGBA", (width * len(rows[0]), height * len(rows)), BACKGROUND)
    for row_index, names in enumerate(rows):
        for column_index, name in enumerate(names):
            sheet.alpha_composite(cell(name), (column_index * width, row_index * height))
    if scale != 1:
        sheet = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    return sheet


def source_rows() -> Image.Image:
    size = 240
    sheet = Image.new("RGBA", (size * 7, size * len(DIRECTIONS)), BACKGROUND)
    for row_index, direction in enumerate(DIRECTIONS):
        for column_index, name in enumerate(row_frames(direction)):
            frame = Image.open(SOURCE / name).convert("RGBA")
            sheet.alpha_composite(frame, (column_index * size, row_index * size))
    return sheet


def main() -> int:
    for required in (PACK, SOURCE):
        if not required.is_dir():
            print(f"missing pack directory: {required}", file=sys.stderr)
            return 2
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    contact = OUT_DIR / "fan2599_elementalist_8dir_contact.png"
    grid([row_frames(direction) for direction in DIRECTIONS]).save(contact)
    print(f"contact sheet: {contact.relative_to(ROOT)}")

    for direction in DIRECTIONS:
        zoom = OUT_DIR / f"fan2599_elementalist_row_{direction.replace('-', '_')}.png"
        grid([row_frames(direction)], scale=2).save(zoom)
        print(f"row zoom:      {zoom.relative_to(ROOT)}")

    source = OUT_DIR / "fan2599_elementalist_source_rows.png"
    source_rows().save(source)
    print(f"source rows:   {source.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
