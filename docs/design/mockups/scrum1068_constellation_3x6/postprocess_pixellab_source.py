#!/usr/bin/env python3
"""Remove PixelLab's connected checker matte and build the Atlas preview base."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


TARGET_SIZE = (1920, 1080)


def _is_checker(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and min(red, green, blue) >= 180 and max(red, green, blue) - min(red, green, blue) <= 14


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


def cover(image: Image.Image, size: tuple[int, int], resample: Image.Resampling) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), resample)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--transparent-output", type=Path, required=True)
    parser.add_argument("--background", type=Path, required=True)
    parser.add_argument("--base-output", type=Path, required=True)
    args = parser.parse_args()

    source = remove_connected_checker(Image.open(args.source))
    args.transparent_output.parent.mkdir(parents=True, exist_ok=True)
    source.save(args.transparent_output)

    background = cover(Image.open(args.background).convert("RGBA"), TARGET_SIZE, Image.Resampling.NEAREST)
    panel_layer = cover(source, TARGET_SIZE, Image.Resampling.NEAREST)
    background.alpha_composite(panel_layer)
    args.base_output.parent.mkdir(parents=True, exist_ok=True)
    background.convert("RGB").save(args.base_output)


if __name__ == "__main__":
    main()
