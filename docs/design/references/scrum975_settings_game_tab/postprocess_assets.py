#!/usr/bin/env python3
"""Deterministic post-processing for the SCRUM-975 PixelLab source exports."""

from __future__ import annotations

from pathlib import Path
from collections import deque

from PIL import Image


ROOT = Path(__file__).resolve().parent
PREVIEW = ROOT.parents[1] / "previews" / "scrum975_settings_game_tab"
PROJECT = ROOT.parents[3]


def build_game_icon() -> None:
    source = Image.open(ROOT / "pixellab_game_tab_medallion_source.png").convert("RGBA")
    # PixelLab returned a UI source sheet. Select the isolated worn-gold round
    # medallion component (alpha component bbox measured on the 192x192 source).
    glyph = source.crop((151, 10, 165, 24)).resize((28, 28), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (44, 44), (0, 0, 0, 0))
    out.alpha_composite(glyph, ((44 - glyph.width) // 2, (44 - glyph.height) // 2))
    out.save(ROOT / "ui_settings_game_tab_icon_44.png")
    PREVIEW.mkdir(parents=True, exist_ok=True)
    out.resize((352, 352), Image.Resampling.NEAREST).save(PREVIEW / "ui_settings_game_tab_icon_8x.png")


def _is_checker(rgb: tuple[int, int, int]) -> bool:
    return min(rgb) > 145 and max(rgb) - min(rgb) < 25


def remove_baked_checker(source: Image.Image, broad: bool = False) -> Image.Image:
    """Remove PixelLab's visually-checkered but opaque export background.

    Only the bright neutral region connected to the canvas edge is removed.
    Interior silver/gold highlights remain because dark UI borders disconnect
    them from the generated checker field.
    """

    image = source.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        r, g, b, _ = pixels[x, y]
        if not (min(r, g, b) > 145 if broad else _is_checker((r, g, b))):
            continue
        pixels[x, y] = (r, g, b, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen:
                queue.append((nx, ny))
    return image


def _cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def _compose_layout(
    source_path: Path,
    alpha_name: str,
    targets: dict[str, tuple[int, int]],
    compact_cleanup: bool = False,
) -> None:
    if not source_path.exists():
        return
    layer = remove_baked_checker(Image.open(source_path), broad=compact_cleanup)
    if compact_cleanup:
        pixels = layer.load()
        # PixelLab tinted two checker rows behind the active lower-right tab.
        # Remove only those bright disconnected export artifacts; preserve the
        # dark tab shadow and all gold frame pixels.
        for x, y, cutoff in [
            *((x, y, 115) for y in range(105, 120) for x in range(345, 480)),
            *((x, y, 105) for y in range(154, 170) for x in range(345, 480)),
        ]:
            r, g, b, _ = pixels[x, y]
            if max(r, g, b) > cutoff and (y >= 154 or min(r, g, b) > 80):
                pixels[x, y] = (r, g, b, 0)
    layer.save(ROOT / alpha_name)
    backdrop_source = Image.open(PROJECT / "assets/backgrounds/ui/ui_backdrop_system_cathedral.png").convert("RGBA")
    for filename, size in targets.items():
        backdrop = _cover(backdrop_source, size)
        shade = Image.new("RGBA", size, (0, 0, 0, 255))
        backdrop = Image.blend(backdrop, shade, 0.30)
        scaled_layer = layer.resize(size, Image.Resampling.NEAREST)
        backdrop.alpha_composite(scaled_layer)
        backdrop.save(ROOT / filename)


def build_layout_bases() -> None:
    _compose_layout(
        ROOT / "pixellab_settings_four_tab_layout_source.png",
        "pixellab_settings_four_tab_layout_alpha.png",
        {
            "pixellab_settings_four_tab_layout_2560x1440.png": (2560, 1440),
            "pixellab_settings_four_tab_layout_1920x1080.png": (1920, 1080),
        },
    )
    _compose_layout(
        ROOT / "pixellab_settings_four_tab_layout_720_source.png",
        "pixellab_settings_four_tab_layout_720_alpha.png",
        {"pixellab_settings_four_tab_layout_1280x720.png": (1280, 720)},
        compact_cleanup=True,
    )


if __name__ == "__main__":
    build_game_icon()
    build_layout_bases()
