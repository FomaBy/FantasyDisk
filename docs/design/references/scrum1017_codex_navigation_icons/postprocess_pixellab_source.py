#!/usr/bin/env python3
"""Nearest-neighbour upscale of the accepted PixelLab RGBA source.

No drawing, cleanup, masking or geometry alteration is performed. The 672x378
PixelLab pixels are only scaled to the 1920x1080 compositor anchor.
"""

from pathlib import Path

from PIL import Image


HERE = Path(__file__).resolve().parent
SOURCE = HERE / "pixellab_scrum1017_codex_navigation_icons_v1_672x378.png"
OUTPUT = HERE / "pixellab_scrum1017_codex_navigation_icons_base_1920x1080.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (672, 378):
        raise ValueError(f"unexpected source size: {source.size}")
    source.resize((1920, 1080), Image.Resampling.NEAREST).save(OUTPUT)


if __name__ == "__main__":
    main()
