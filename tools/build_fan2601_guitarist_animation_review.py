#!/usr/bin/env python3
"""FAN-2601 — 8-direction review sheets for the runtime hero guitarist body pack.

Renders the acceptance evidence the card asks for, straight from the runtime
PNGs the game plays (assets/sprites/characters/full_frame/guitarist_pixellab):

  - fan2601_guitarist_8dir_contact.png  8 direction rows x (idle + move 00..05)
  - fan2601_guitarist_row_<dir>.png     2x zoom of every row, all eight rows

Deterministic and read-only; nothing is auto-fixed.

Usage: python3 tools/build_fan2601_guitarist_animation_review.py
Output: docs/design/previews/
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/sprites/characters/full_frame/guitarist_pixellab"
OUT_DIR = ROOT / "docs/design/previews"

# Clockwise runtime order (manifest "directions"); rows read top to bottom.
DIRECTIONS = ["south", "south-east", "east", "north-east",
              "north", "north-west", "west", "south-west"]
# Tight window on the 512x512 runtime canvas: visible art spans x 141..371,
# y 154..401 across the whole pack (guitar silhouette included).
CROP = (120, 130, 392, 420)
BACKGROUND = (30, 30, 36, 255)


def row_frames(direction: str) -> list[str]:
    return [f"guitarist_idle_{direction}.png"] + [
        f"guitarist_move_{direction}_{index:02d}.png" for index in range(6)
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


def main() -> int:
    if not PACK.is_dir():
        print(f"missing runtime pack: {PACK}", file=sys.stderr)
        return 2
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    contact = OUT_DIR / "fan2601_guitarist_8dir_contact.png"
    grid([row_frames(direction) for direction in DIRECTIONS]).save(contact)
    print(f"contact sheet: {contact.relative_to(ROOT)}")

    for direction in DIRECTIONS:
        zoom = OUT_DIR / f"fan2601_guitarist_row_{direction.replace('-', '_')}.png"
        grid([row_frames(direction)], scale=2).save(zoom)
        print(f"row sheet: {zoom.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
