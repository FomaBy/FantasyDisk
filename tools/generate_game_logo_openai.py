#!/usr/bin/env python3
"""SCRUM-894: генерация логотипа игры для главного меню (gpt-image-2).

Три арт-направления одной надписи "FANTASY DISK" (эпический D&D-леттеринг,
дарк-фэнтези, палитра фона меню: фиолетовый аркан + янтарное золото).
Пайплайн канона: magenta key #FF00FF -> global key wipe -> erode -> crop 8:3.
Варианты кладутся в references/game_logo/, выбор и установка в
assets/sprites/ui/menu_title/ — вручную (оркестратор смотрит глазами).
"""
from __future__ import annotations

import base64
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from generate_meta40_ui_openai import (  # noqa: E402
    MODEL, require_client, _key_mask, erode_alpha, crop_to_aspect,
)

OUT_DIR = Path(__file__).resolve().parent.parent / "references" / "game_logo"
CANVAS = "1536x1024"
TARGET = (1440, 540)  # слот меню 720x270 @2K, x2 запас

COMMON = (
    'single line of text with EXACT spelling "FANTASY DISK" in epic '
    "Dungeons and Dragons movie-logo lettering: massive sharp-serif "
    "capitals, hand-chiseled fantasy typeface, dramatic perspective kept "
    "flat and readable; dark fantasy game logo, highly detailed, cinematic; "
    "letters fill most of the canvas width; tight rim lighting only, NO wide "
    "soft outer glow; no watermark, no signature, no other text or letters; "
    "entire background is one solid uniform bright magenta color #FF00FF, "
    "flat, nothing else touches the background"
)

VARIANTS = {
    "logo_v1_ember_steel.png": (
        "weathered dark-steel letters with polished gold bevel edges and "
        "rivets, faint crimson ember underglow along the bottom edges, "
        "behind the lettering a large cracked dark runic stone disk with a "
        "glowing violet arcane core and thin golden inlay rings; "
    ),
    "logo_v2_molten_gold.png": (
        "ornate molten-gold letters with deep engraved filigree and dark "
        "bronze shadows, small violet arcane disk emblem centered behind "
        "the words, slim dragon-wing flourishes extending from the sides "
        "of the lettering, amber sparks; "
    ),
    "logo_v3_arcane_obsidian.png": (
        "polished black-obsidian letters with glowing violet arcane runes "
        "inlaid in the strokes and warm amber rim light from below, a "
        "shattered runic disk halo with violet energy behind the title; "
    ),
}


def main() -> None:
    client = require_client()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for fname, style in VARIANTS.items():
        prompt = style + COMMON
        print(f"[gen] {fname} ...", flush=True)
        result = client.images.generate(
            model=MODEL, prompt=prompt, size=CANVAS, quality="high",
            output_format="png", n=1)
        raw = base64.b64decode(result.data[0].b64_json)
        img = Image.open(__import__("io").BytesIO(raw)).convert("RGBA")
        a = np.array(img, dtype=np.uint8)
        a[_key_mask(a, (255, 0, 255), 90), 3] = 0
        img = erode_alpha(Image.fromarray(a))
        img = crop_to_aspect(img, *TARGET)
        img = img.resize(TARGET, Image.LANCZOS)
        img.save(OUT_DIR / fname)
        print(f"[ok] {OUT_DIR / fname}", flush=True)


if __name__ == "__main__":
    main()
