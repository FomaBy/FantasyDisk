#!/usr/bin/env python3
"""Remove PixelLab's baked neutral checkerboard and scale the accepted UI layer.

This script changes only the connected neutral background. It never paints,
covers, or adds frames/panels/content over the PixelLab artwork.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--clean-output", required=True)
    parser.add_argument("--scaled-output", required=True)
    return parser.parse_args()


def is_checker(rgb: tuple[int, int, int]) -> bool:
    """PixelLab's four baked checker colors are bright, low-chroma neutrals."""
    lo = min(rgb)
    hi = max(rgb)
    return lo >= 170 and hi - lo <= 18


def main() -> int:
    args = parse_args()
    image = Image.open(args.input).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    pending: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()

    for x in range(width):
        pending.append((x, 0))
        pending.append((x, height - 1))
    for y in range(height):
        pending.append((0, y))
        pending.append((width - 1, y))

    while pending:
        x, y = pending.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        r, g, b, _ = pixels[x, y]
        if not is_checker((r, g, b)):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        if x:
            pending.append((x - 1, y))
        if x + 1 < width:
            pending.append((x + 1, y))
        if y:
            pending.append((x, y - 1))
        if y + 1 < height:
            pending.append((x, y + 1))

    clean_path = Path(args.clean_output)
    scaled_path = Path(args.scaled_output)
    clean_path.parent.mkdir(parents=True, exist_ok=True)
    scaled_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(clean_path)
    image.resize((1920, 1080), Image.Resampling.NEAREST).save(scaled_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
