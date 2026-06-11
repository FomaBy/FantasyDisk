"""Redraw the four arena backgrounds at native 2560x1440.

Design task: design_arena_backgrounds_2k_native_task.md

Pipeline per background:
  1. Lanczos upscale 1600x900 -> 2560x1440 + gentle unsharp (no runtime stretch).
  2. Auto-pick "donor" detail patches (stones, tufts, cracks) from the image
     itself by local variance - style stays perfectly consistent.
  3. Scatter donors into low-detail cells of a uniform grid with soft
     elliptical masks, flips, small rotations and brightness jitter, so ground
     landmarks cover the whole arena and movement reads naturally.

Originals are backed up to build/bg_backup/ before replacement.

Run from the project root:  python3 tools/redraw_arena_backgrounds.py
"""
from __future__ import annotations

import math
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageStat

ROOT = Path(__file__).resolve().parents[1]
BG_DIR = ROOT / "assets" / "backgrounds"
BACKUP = ROOT / "build" / "bg_backup"

TARGET = (2560, 1440)
PATCH = 150          # donor patch size at 2560 scale
GRID_X, GRID_Y = 10, 6

BACKGROUNDS = {
    # name: (variance threshold for "empty" cell, donors per empty cell)
    "field_stone_garden": {"empty_thr": 1.00, "per_cell": (1, 2)},
    "field_marsh": {"empty_thr": 1.00, "per_cell": (1, 2)},
    "field_dry_road": {"empty_thr": 1.00, "per_cell": (1, 2)},
    "field_meadow": {"empty_thr": 1.0, "per_cell": (1, 2)},
}


def local_variance_map(gray: Image.Image, cell: int) -> list[list[float]]:
    w, h = gray.size
    cols = w // cell
    rows = h // cell
    grid = []
    for row in range(rows):
        grid_row = []
        for col in range(cols):
            box = (col * cell, row * cell, (col + 1) * cell, (row + 1) * cell)
            stat = ImageStat.Stat(gray.crop(box))
            grid_row.append(stat.stddev[0])
        grid.append(grid_row)
    return grid


def pick_donors(img: Image.Image, rng: random.Random, count: int = 12) -> list[Image.Image]:
    """Pick high-detail patches, spread across the image."""
    gray = img.convert("L")
    w, h = img.size
    step = PATCH // 2
    candidates = []
    for y in range(0, h - PATCH, step):
        for x in range(0, w - PATCH, step):
            stat = ImageStat.Stat(gray.crop((x, y, x + PATCH, y + PATCH)))
            candidates.append((stat.stddev[0], x, y))
    candidates.sort(reverse=True)
    chosen: list[tuple[int, int]] = []
    donors: list[Image.Image] = []
    for _, x, y in candidates:
        if len(donors) >= count:
            break
        if any(abs(x - cx) < PATCH and abs(y - cy) < PATCH for cx, cy in chosen):
            continue
        chosen.append((x, y))
        donors.append(img.crop((x, y, x + PATCH, y + PATCH)))
    rng.shuffle(donors)
    return donors


def soft_mask(size: int, rng: random.Random) -> Image.Image:
    """Soft irregular ellipse so the patch melts into the ground."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    c = size / 2.0
    points = []
    for i in range(24):
        ang = math.tau * i / 24.0
        r = size * 0.42 * rng.uniform(0.82, 1.0)
        points.append((c + math.cos(ang) * r, c + math.sin(ang) * r * 0.85))
    d.polygon(points, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(size * 0.10))


def scatter(img: Image.Image, donors: list[Image.Image], cfg: dict, rng: random.Random) -> int:
    w, h = img.size
    cell_w = w // GRID_X
    cell_h = h // GRID_Y
    gray = img.convert("L")
    placed = 0
    # normalize variance: empty cells are those below (mean * empty_thr)
    cell_std = []
    for gy in range(GRID_Y):
        for gx in range(GRID_X):
            box = (gx * cell_w, gy * cell_h, (gx + 1) * cell_w, (gy + 1) * cell_h)
            cell_std.append((ImageStat.Stat(gray.crop(box)).stddev[0], gx, gy))
    mean_std = sum(item[0] for item in cell_std) / len(cell_std)

    for std, gx, gy in cell_std:
        if std >= mean_std * cfg["empty_thr"]:
            continue
        count = rng.randint(*cfg["per_cell"])
        for _ in range(count):
            donor = rng.choice(donors)
            scale = rng.uniform(0.55, 0.95)
            size = max(int(PATCH * scale), 48)
            piece = donor.resize((size, size), Image.LANCZOS)
            if rng.random() < 0.5:
                piece = piece.transpose(Image.FLIP_LEFT_RIGHT)
            piece = piece.rotate(rng.uniform(-14.0, 14.0), resample=Image.BICUBIC, expand=False)
            piece = ImageEnhance.Brightness(piece).enhance(rng.uniform(0.96, 1.04))
            mask = soft_mask(size, rng)
            px = gx * cell_w + rng.randint(0, max(cell_w - size, 1))
            py = gy * cell_h + rng.randint(0, max(cell_h - size, 1))
            img.paste(piece, (px, py), mask)
            placed += 1
    return placed


def main() -> None:
    BACKUP.mkdir(parents=True, exist_ok=True)
    for name, cfg in BACKGROUNDS.items():
        path = BG_DIR / f"{name}.png"
        backup_path = BACKUP / f"{name}.png"
        if not backup_path.exists():
            shutil.copy(path, backup_path)
        src = Image.open(backup_path).convert("RGB")
        rng = random.Random(hash(name) & 0xFFFF)

        big = src.resize(TARGET, Image.LANCZOS)
        big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=62, threshold=2))
        donors = pick_donors(big, rng)
        placed = scatter(big, donors, cfg, rng)
        big.save(path)
        print(f"{name}: {src.size} -> {big.size}, landmarks placed: {placed}")


if __name__ == "__main__":
    main()
