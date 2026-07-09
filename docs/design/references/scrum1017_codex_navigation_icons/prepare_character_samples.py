#!/usr/bin/env python3
"""Create preview-only alpha-bbox crops from canonical runtime character PNGs.

The pixels come only from the tracked runtime images. The script removes empty
transparent canvas and adds an 8% transparent reserve so the compositor can
demonstrate the SCRUM-1017 row/detail crop policy without redrawing any art.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent / "character_samples"
SOURCES = {
    "berserk": ROOT / "assets/sprites/characters/full_frame/berserk_pixellab/berserk_idle_south.png",
    "dark_mage": ROOT / "assets/sprites/characters/full_frame/dark_mage_pixellab/dark_mage_idle_south.png",
    "guitarist": ROOT / "assets/sprites/characters/full_frame/guitarist_pixellab/guitarist_idle_south.png",
    "druid": ROOT / "assets/sprites/characters/full_frame/druid_pixellab/druid_idle_south.png",
}


def crop_with_reserve(source: Path, output: Path) -> None:
    image = Image.open(source).convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"empty alpha: {source}")
    subject = image.crop(bbox)
    reserve = max(8, int(round(max(subject.size) * 0.08)))
    side = max(subject.width, subject.height) + reserve * 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    x = (side - subject.width) // 2
    y = side - reserve - subject.height
    canvas.alpha_composite(subject, (x, y))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)


def main() -> None:
    for character_id, source in SOURCES.items():
        crop_with_reserve(source, OUT / f"{character_id}_alpha_bbox_crop.png")


if __name__ == "__main__":
    main()
