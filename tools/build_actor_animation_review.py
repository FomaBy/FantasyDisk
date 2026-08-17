#!/usr/bin/env python3
"""8-direction review sheets for a PixelLab actor body pack.

Renders the acceptance evidence a 0.3.1 actor-polish card asks for, straight
from the runtime PNGs the game plays (full_frame/<actor>_pixellab), plus the
matching PixelLab source rows so a defect can be attributed to the art instead
of to runtime normalization:

  - <slug>_<actor>_8dir_contact.png   8 direction rows x (idle + move 00..05)
  - <slug>_<actor>_row_<dir>.png      2x zoom of each reviewed row
  - <slug>_<actor>_source_rows.png    the same rows from the 252 px source

Actor-parameterized successor to build_fan2606_sniper_animation_review.py, so a
per-card copy is not needed for the remaining roster. Deterministic and
read-only; nothing is auto-fixed.

Usage: python3 tools/build_actor_animation_review.py berserk --slug fan2593 \
           --rows south,south-east,north-east,north,west
Output: docs/design/previews/
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "docs/design/previews"
# Clockwise runtime order; the manifest owns it, this is the fallback.
DIRECTIONS = ["south", "south-east", "east", "north-east",
              "north", "north-west", "west", "south-west"]
BACKGROUND = (30, 30, 36, 255)
MARGIN = 6


def row_frames(actor: str, direction: str) -> list[str]:
    return [f"{actor}_idle_{direction}.png"] + [
        f"{actor}_move_{direction}_{index:02d}.png" for index in range(6)
    ]


def directions_of(actor: str) -> list[str]:
    manifest = ROOT / f"assets/sprites/characters/pixellab/{actor}/manifest.json"
    if not manifest.is_file():
        return DIRECTIONS
    return json.loads(manifest.read_text()).get("directions", DIRECTIONS)


def crop_box(pack: Path, names: list[str]) -> tuple[int, int, int, int]:
    """Tight window covering every frame's visible art, so no row is clipped."""
    boxes = [Image.open(pack / name).convert("RGBA").getchannel("A").getbbox()
             for name in names]
    return (min(b[0] for b in boxes) - MARGIN, min(b[1] for b in boxes) - MARGIN,
            max(b[2] for b in boxes) + MARGIN, max(b[3] for b in boxes) + MARGIN)


def grid(pack: Path, rows: list[list[str]], crop: tuple[int, int, int, int],
         scale: int = 1) -> Image.Image:
    width, height = crop[2] - crop[0], crop[3] - crop[1]
    sheet = Image.new("RGBA", (width * len(rows[0]), height * len(rows)), BACKGROUND)
    for row_index, names in enumerate(rows):
        for column_index, name in enumerate(names):
            cell = Image.open(pack / name).convert("RGBA").crop(crop)
            sheet.alpha_composite(cell, (column_index * width, row_index * height))
    if scale != 1:
        sheet = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    return sheet


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("actor", help="roster id, e.g. berserk")
    parser.add_argument("--slug", required=True, help="card slug, e.g. fan2593")
    parser.add_argument("--rows", default="",
                        help="comma-separated directions to zoom (default: none)")
    options = parser.parse_args()

    actor, slug = options.actor, options.slug
    pack = ROOT / f"assets/sprites/characters/full_frame/{actor}_pixellab"
    if not pack.is_dir():
        print(f"missing runtime pack: {pack}", file=sys.stderr)
        return 2
    directions = directions_of(actor)
    reviewed = [row for row in options.rows.split(",") if row]
    unknown = [row for row in reviewed if row not in directions]
    if unknown:
        print(f"unknown directions: {', '.join(unknown)}", file=sys.stderr)
        return 2
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    rows = [row_frames(actor, direction) for direction in directions]
    crop = crop_box(pack, [name for row in rows for name in row])
    contact = OUT_DIR / f"{slug}_{actor}_8dir_contact.png"
    grid(pack, rows, crop).save(contact)
    print(f"contact sheet: {contact.relative_to(ROOT)}")

    for direction in reviewed:
        zoom = OUT_DIR / f"{slug}_{actor}_row_{direction.replace('-', '_')}.png"
        grid(pack, [row_frames(actor, direction)], crop, scale=2).save(zoom)
        print(f"row zoom:      {zoom.relative_to(ROOT)}")

    if reviewed:
        source = ROOT / f"assets/sprites/characters/pixellab/{actor}"
        source_rows = [row_frames(actor, direction) for direction in reviewed]
        source_crop = crop_box(source, [name for row in source_rows for name in row])
        sheet = OUT_DIR / f"{slug}_{actor}_source_rows.png"
        grid(source, source_rows, source_crop, scale=2).save(sheet)
        print(f"source rows:   {sheet.relative_to(ROOT)} ({', '.join(reviewed)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
