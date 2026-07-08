#!/usr/bin/env python3
"""Atlas-style screen unification — fullscreen backgrounds (OpenAI gpt-image-2).

Часть задачи «Унификация UI под стиль Атласа героев» (см.
docs/tasks/design_ui_atlas_style_unify_screens_task.md). Фоны для экранов
выбора персонажа / кодекса / релиз-нотов / настроек в палитре кита meta40
(SCRUM-832): полуночно-синий, латунь/античное золото, тихий тёмный центр под
читаемый UI. Пайплайн канона: генерация 1536x1024 -> crop 16:9 -> LANCZOS
2560x1440 (как bg_sky.png).

Usage:
  python3 tools/generate_atlas_style_screens_openai.py [--only key1,key2] [--dry-run]
"""

from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_meta40_ui_openai import (  # noqa: E402
    MODEL, crop_to_aspect, require_client)

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/sprites/ui/atlas_style"
PREVIEW_DIR = ROOT / "docs/design/previews"

BG_STYLE = ("16-bit pixel art, deep midnight-blue palette with faint teal "
            "nebula accents and antique gold highlights, dark fantasy "
            "roguelite, quiet muted low-contrast composition so bright gold "
            "UI panels stay readable on top, 16:9 full-screen background, "
            "no frame, no border, no text, no letters, no watermark, "
            "no people, no characters")

# key -> (filename, prompt)
SPEC: dict[str, tuple[str, str]] = {
    "bg_hero_hall": (
        "bg_hero_hall.png",
        "full-screen background for a hero selection sanctum: vast dark "
        "ceremonial great hall at night, rows of dim heroic stone statues in "
        "wall niches fading into shadow along the far left and right edges, "
        "tall arched windows high up revealing a midnight-blue starry sky "
        "with faint teal nebula, polished dark stone floor with a faint "
        "antique gold inlaid circle low near the bottom center, the middle "
        "and lower half of the image kept very dark, empty and quiet; "
        + BG_STYLE),
    "bg_codex_archive": (
        "bg_codex_archive.png",
        "full-screen background for an arcane codex archive: towering "
        "ancient library shelves with stacked grimoires as dark silhouettes "
        "along the far left and right edges, a few faint floating golden "
        "dust motes, a hint of teal nebula light through one high window, "
        "dark leather-brown undertones, the large central area kept very "
        "dark, empty and quiet; " + BG_STYLE),
    "bg_chronicle": (
        "bg_chronicle.png",
        "full-screen background for a chronicle-of-updates screen: quiet "
        "dark scriptorium under a midnight-blue starry sky, thin faint "
        "constellation lines connecting a few dim stars high in the sky, a "
        "barely visible silhouette of a huge closed ancient tome at the very "
        "bottom edge with a soft gold glow seam (no glyphs, no writing), "
        "the central area kept very dark, empty and quiet; " + BG_STYLE),
    "bg_sanctum": (
        "bg_sanctum.png",
        "full-screen background for a settings sanctum: dark stone wall "
        "with subtle carved arcane gear reliefs and faint rune circles near "
        "the far left and right edges, dim bronze pipes and hanging chains "
        "as barely visible silhouettes, one quiet teal-blue light shaft from "
        "above, the large central area kept very dark, empty and quiet; "
        + BG_STYLE),
}

TARGET = (2560, 1440)
CANVAS = "1536x1024"


def generate(client, key: str, quality: str) -> Path:
    fname, prompt = SPEC[key]
    result = client.images.generate(model=MODEL, prompt=prompt, size=CANVAS,
                                    quality=quality, output_format="png", n=1)
    raw = base64.b64decode(result.data[0].b64_json)
    src = ASSET_DIR / f"_src_{fname}"
    src.write_bytes(raw)
    img = Image.open(src).convert("RGB")
    img = crop_to_aspect(img, *TARGET)
    img = img.resize(TARGET, Image.LANCZOS)
    out = ASSET_DIR / fname
    img.save(out)
    src.unlink()
    return out


def contact_sheet() -> Path:
    from PIL import ImageDraw, ImageFont
    paths = [ASSET_DIR / spec[0] for spec in SPEC.values()
             if (ASSET_DIR / spec[0]).exists()]
    cell_w, cell_h = 640, 400
    cols = 2
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (16, 18, 28))
    dr = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf", 16)
    for i, p in enumerate(sorted(paths, key=lambda x: x.name)):
        img = Image.open(p).convert("RGB")
        img.thumbnail((cell_w - 24, cell_h - 44), Image.LANCZOS)
        x = (i % cols) * cell_w
        y = (i // cols) * cell_h
        sheet.paste(img, (x + (cell_w - img.width) // 2, y + 8))
        dr.text((x + cell_w // 2, y + cell_h - 20), p.stem, font=font,
                fill=(220, 205, 160), anchor="mm")
    out = PREVIEW_DIR / "atlas_style_bg_contact.png"
    sheet.save(out)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated keys")
    ap.add_argument("--quality", default="high", choices=["low", "medium", "high"])
    ap.add_argument("--sheet-only", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.sheet_only:
        print(f"contact sheet: {contact_sheet().relative_to(ROOT)}")
        return
    keys = list(SPEC) if not args.only else [k.strip() for k in args.only.split(",")]
    unknown = [k for k in keys if k not in SPEC]
    if unknown:
        raise SystemExit(f"unknown keys: {unknown}")
    if args.dry_run:
        for k in keys:
            print(f"{k:18s} {CANVAS} -> {TARGET} ({SPEC[k][0]})")
        return
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    client = require_client()
    for i, k in enumerate(keys, 1):
        try:
            out = generate(client, k, args.quality)
        except Exception as exc:  # noqa: BLE001 — billing/quota errors must surface
            print(f"[{i}/{len(keys)}] {k}: FAILED — {exc}", flush=True)
            sys.exit(2)
        print(f"[{i}/{len(keys)}] {k}: {out.relative_to(ROOT)}", flush=True)
    print(f"contact sheet: {contact_sheet().relative_to(ROOT)}")


if __name__ == "__main__":
    main()
