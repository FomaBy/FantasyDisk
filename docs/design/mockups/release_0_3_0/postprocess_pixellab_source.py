#!/usr/bin/env python3
"""Remove PixelLab's baked checker matte and prepare the square poster base."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


TARGET_SIZE = (1350, 1350)
BACKGROUND = (10, 7, 14, 255)


def _is_checker(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return (
        alpha > 0
        and min(red, green, blue) >= 175
        and max(red, green, blue) - min(red, green, blue) <= 20
    )


def remove_connected_checker(source: Image.Image) -> Image.Image:
    image = source.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or not _is_checker(pixels[x, y]):
            continue
        visited.add((x, y))
        red, green, blue, _ = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--transparent-output", type=Path, required=True)
    parser.add_argument("--base-output", type=Path, required=True)
    args = parser.parse_args()

    cleaned = remove_connected_checker(Image.open(args.source))
    alpha_bbox = cleaned.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise SystemExit("PixelLab source became empty after checker cleanup")
    cleaned = cleaned.crop(alpha_bbox)
    cleaned = cleaned.resize(TARGET_SIZE, Image.Resampling.LANCZOS)

    args.transparent_output.parent.mkdir(parents=True, exist_ok=True)
    cleaned.save(args.transparent_output)
    base = Image.new("RGBA", TARGET_SIZE, BACKGROUND)
    base.alpha_composite(cleaned)
    base.convert("RGB").save(args.base_output)
    print(
        f"prepared {args.base_output} from bbox={alpha_bbox}; "
        f"target={TARGET_SIZE[0]}x{TARGET_SIZE[1]}"
    )


if __name__ == "__main__":
    main()
