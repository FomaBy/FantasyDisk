#!/usr/bin/env python3
"""FAN-3052 self-check evidence: move-only contact sheet + pink-pixel table for void_mage.

Follows the tools/build_fan2628_mini_rot_hound_contact_sheet.py pattern.
Written to build/qa/fan3052_void_mage/contact_sheet_move.png plus a
pink_pixel_counts.json using the QA filter (R>200, B>150, G<150) that caught
the original defect.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "assets/sprites/enemies/full_frame/void_mage_8dir"
OUT_DIR = ROOT / "build/qa/fan3052_void_mage"
DIRECTIONS = ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
FRAME_COUNT = 6
CELL = 128


def frame_paths(direction: str) -> list[Path]:
    return [RUNTIME_DIR / f"void_mage_move_{direction}_{i:02d}.png" for i in range(FRAME_COUNT)]


def pink_pixel_count(image: Image.Image) -> int:
    colors = image.getcolors(maxcolors=200000)
    return sum(c for c, (r, g, b, a) in colors if r > 200 and b > 150 and g < 150 and a > 0)


def build_sheet() -> tuple[Path, dict]:
    cols, rows = FRAME_COUNT, len(DIRECTIONS)
    sheet = Image.new("RGBA", (cols * CELL, rows * CELL), (40, 40, 40, 255))
    draw = ImageDraw.Draw(sheet)
    counts: dict[str, list[int]] = {}
    for row, direction in enumerate(DIRECTIONS):
        row_counts = []
        for col, path in enumerate(frame_paths(direction)):
            image = Image.open(path).convert("RGBA")
            row_counts.append(pink_pixel_count(image))
            bbox = image.getchannel("A").getbbox()
            crop = image.crop(bbox) if bbox else image
            crop.thumbnail((CELL - 8, CELL - 8), Image.Resampling.NEAREST)
            x = col * CELL + (CELL - crop.width) // 2
            y = row * CELL + (CELL - crop.height) // 2
            sheet.alpha_composite(crop, (x, y))
        counts[direction] = row_counts
        draw.text((4, row * CELL + 4), direction, fill=(255, 255, 0, 255))
    out = OUT_DIR / "contact_sheet_move.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)
    return out, counts


def main() -> int:
    sheet_path, counts = build_sheet()
    print(f"wrote {sheet_path}")
    counts_path = OUT_DIR / "pink_pixel_counts.json"
    counts_path.write_text(json.dumps(counts, indent=2), encoding="utf-8")
    print(f"wrote {counts_path}")
    for direction, row_counts in counts.items():
        nonzero = [c > 0 for c in row_counts]
        stable = all(nonzero) or not any(nonzero)
        print(f"{direction}: {row_counts} stable={stable}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
