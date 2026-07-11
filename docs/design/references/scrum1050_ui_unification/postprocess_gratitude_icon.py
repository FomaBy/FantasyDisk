#!/usr/bin/env python3
"""Remove PixelLab's opaque neutral backdrop and normalize the gratitude icon."""

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "docs/design/references/scrum1050_ui_unification/pixellab_gratitude_icon_raw_256.png"
REFERENCE = ROOT / "docs/design/references/scrum1050_ui_unification/pixellab_gratitude_icon_alpha_256.png"
RUNTIME = ROOT / "assets/sprites/ui/icons/credits/ui_icon_gratitude.png"
PREVIEW = ROOT / "docs/design/previews/scrum1050_ui_unification_gratitude_icon_contact.png"


def is_neutral_background(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return max(red, green, blue) - min(red, green, blue) <= 20 and 72 <= max(red, green, blue) <= 196


def flood_background(image: Image.Image) -> set[tuple[int, int]]:
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
        point = queue.popleft()
        if point in visited:
            continue
        x, y = point
        if not is_neutral_background(image.getpixel((x, y))):
            continue
        visited.add(point)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    return visited


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    background = flood_background(source)
    cleaned = source.copy()
    alpha = cleaned.getchannel("A")
    alpha_pixels = alpha.load()
    for x, y in background:
        alpha_pixels[x, y] = 0
    cleaned.putalpha(alpha)

    bbox = cleaned.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("background removal erased the full icon")
    subject = cleaned.crop(bbox)
    subject.thumbnail((160, 160), Image.Resampling.LANCZOS)
    normalized = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    normalized.alpha_composite(subject, ((256 - subject.width) // 2, (256 - subject.height) // 2))
    REFERENCE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    normalized.save(REFERENCE)
    normalized.save(RUNTIME)

    contact = Image.new("RGBA", (512, 192), (18, 16, 20, 255))
    draw = ImageDraw.Draw(contact)
    for index, size in enumerate((32, 48, 64, 96)):
        tile_x = 16 + index * 124
        draw.rounded_rectangle((tile_x, 16, tile_x + 112, 176), radius=12, fill=(31, 28, 34, 255), outline=(117, 83, 44, 255), width=2)
        icon = normalized.resize((size, size), Image.Resampling.LANCZOS)
        contact.alpha_composite(icon, (tile_x + (112 - size) // 2, 16 + (160 - size) // 2))
    contact.save(PREVIEW)


if __name__ == "__main__":
    main()
