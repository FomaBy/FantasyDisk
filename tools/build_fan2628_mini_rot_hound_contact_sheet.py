#!/usr/bin/env python3
"""Contact-sheet evidence for the FAN-2628 mini_rot_hound 8-direction pack.

One row per <state>_<direction> animation, cropped to each frame's alpha
bbox so silhouette/identity/artifacts are readable at a glance. Written to
build/qa/fan2628_mini_rot_hound/contact_sheet_<state>.png (one sheet per
state to keep each PNG a readable size).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "assets/sprites/elites/full_frame/mini_rot_hound"
OUT_DIR = ROOT / "build/qa/fan2628_mini_rot_hound"

DIRECTIONS = ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
STATE_FRAME_COUNTS = {
    "idle": 1,
    "move": 6,
    "attack": 7,
    "hit": 5,
    "death": 7,
    "skill_shadow_strike": 7,
}
CELL = 128


def frame_paths(state: str, direction: str, count: int) -> list[Path]:
    if count == 1:
        return [RUNTIME_DIR / f"mini_rot_hound_{state}_{direction}.png"]
    return [RUNTIME_DIR / f"mini_rot_hound_{state}_{direction}_{i:02d}.png" for i in range(count)]


def build_sheet(state: str, count: int) -> Path:
    cols = count
    rows = len(DIRECTIONS)
    sheet = Image.new("RGBA", (cols * CELL, rows * CELL), (40, 40, 40, 255))
    draw = ImageDraw.Draw(sheet)
    for row, direction in enumerate(DIRECTIONS):
        for col, path in enumerate(frame_paths(state, direction, count)):
            image = Image.open(path).convert("RGBA")
            bbox = image.getchannel("A").getbbox()
            crop = image.crop(bbox) if bbox else image
            crop.thumbnail((CELL - 8, CELL - 8), Image.Resampling.NEAREST)
            x = col * CELL + (CELL - crop.width) // 2
            y = row * CELL + (CELL - crop.height) // 2
            sheet.alpha_composite(crop, (x, y))
        draw.text((4, row * CELL + 4), direction, fill=(255, 255, 0, 255))
    out = OUT_DIR / f"contact_sheet_{state}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)
    return out


def main() -> int:
    for state, count in STATE_FRAME_COUNTS.items():
        out = build_sheet(state, count)
        print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
