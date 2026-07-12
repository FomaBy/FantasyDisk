#!/usr/bin/env python3
"""Render the 16:9 responsive evidence matrix from the accepted 1920 anchor."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
PREVIEWS = HERE.parents[1] / "previews"
TARGETS = [(1280, 720), (2560, 1440)]


def main() -> None:
    source = Image.open(HERE / "codex_characters_mockup_1920x1080.png").convert("RGBA")
    debug = Image.open(HERE / "codex_characters_mockup_debug_1920x1080.png").convert("RGBA")
    responsive = {}
    responsive_debug = {}
    for width, height in TARGETS:
        key = f"{width}x{height}"
        responsive[key] = source.resize((width, height), Image.Resampling.NEAREST)
        responsive_debug[key] = debug.resize((width, height), Image.Resampling.NEAREST)
        responsive[key].save(HERE / f"codex_characters_mockup_{key}.png")
        responsive_debug[key].save(HERE / f"codex_characters_mockup_debug_{key}.png")

    card_w, card_h, label_h = 640, 360, 36
    contact = Image.new("RGB", (card_w * 3, card_h + label_h), (12, 10, 14))
    draw = ImageDraw.Draw(contact)
    font_path = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
    font = ImageFont.truetype(font_path, 22)
    states = [
        ("1280×720", responsive["1280x720"]),
        ("1920×1080", source),
        ("2560×1440", responsive["2560x1440"]),
    ]
    for index, (label, image) in enumerate(states):
        thumb = image.resize((card_w, card_h), Image.Resampling.NEAREST).convert("RGB")
        contact.paste(thumb, (index * card_w, label_h))
        bbox = draw.textbbox((0, 0), label, font=font)
        x = index * card_w + (card_w - (bbox[2] - bbox[0])) // 2
        draw.text((x, 5), label, font=font, fill=(238, 219, 170))
    contact.save(PREVIEWS / "scrum1017_codex_navigation_icons_responsive_contact.png")


if __name__ == "__main__":
    main()
