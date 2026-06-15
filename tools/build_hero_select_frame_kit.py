#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "docs/design/references/herouiframe"
OUT_DIR = ROOT / "assets/sprites/ui/frames/hero_select"
PREVIEW = ROOT / "docs/design/previews/hero_select_frame_kit_contact.png"
BACKUP_DIR = ROOT / "build/cleanup_backup_hero_select_frames_2026_06_14"


SOURCE_BY_INDEX = {
    1: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (1).png",
    2: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (2).png",
    3: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (3).png",
    4: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (4).png",
    5: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (5).png",
    6: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (6).png",
    7: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (7).png",
    8: "ChatGPT Image Jun 14, 2026, 09_13_08 AM (8).png",
}


FRAMES = {
    "portrait": {"source": 6, "margin": (72, 86, 72, 92), "content": (50, 58, 50, 62), "label": "Large portrait"},
    "dossier": {"source": 2, "margin": (92, 86, 92, 90), "content": (58, 48, 58, 50), "label": "Dossier / reserve"},
    "radar": {"source": 3, "margin": (88, 88, 88, 88), "content": (44, 40, 44, 42), "label": "Radar"},
    "thumbnail_strip": {"source": 7, "margin": (96, 48, 96, 52), "content": (46, 22, 46, 24), "label": "Thumbnail strip"},
    "thumbnail": {"source": 5, "margin": (78, 72, 78, 76), "content": (34, 28, 34, 30), "label": "Hero thumbnail"},
    "asc_button": {"source": 1, "margin": (58, 58, 58, 62), "content": (14, 12, 14, 14), "label": "Ascension +/-"},
    "asc_label": {"source": 4, "margin": (86, 36, 86, 38), "content": (24, 8, 24, 8), "label": "Ascension label"},
    "asc_mods": {"source": 8, "margin": (96, 30, 96, 32), "content": (28, 6, 28, 6), "label": "Ascension mods"},
}


def remove_checkerboard(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    px = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # The references have a baked white/grey checkerboard in transparent
            # areas. Dark metal/red ornament and dark filled centers stay opaque.
            if max(r, g, b) > 178 and abs(r - g) < 12 and abs(g - b) < 12:
                px[x, y] = (255, 255, 255, 0)
    bbox = rgba.getbbox()
    if bbox == None:
        return rgba
    pad = 4
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(width, bbox[2] + pad)
    bottom = min(height, bbox[3] + pad)
    return rgba.crop((left, top, right, bottom))


def backup_existing() -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    for path in [
        ROOT / "assets/sprites/ui/frames/ornate/ui_frame_ornate_hero_card.png",
        ROOT / "assets/sprites/ui/frames/ornate/ui_frame_ornate_card_frame.png",
        ROOT / "assets/sprites/ui/frames/ornate/ui_frame_ornate_card_hover.png",
        ROOT / "assets/sprites/ui/frames/red_gold/ui_btn_red_gold_utility.png",
        ROOT / "assets/sprites/ui/frames/red_gold/ui_btn_red_gold_utility_hover.png",
        ROOT / "assets/sprites/ui/frames/red_gold/ui_btn_red_gold_utility_pressed.png",
        ROOT / "assets/sprites/ui/frames/red_gold/ui_btn_red_gold_utility_disabled.png",
    ]:
        if path.exists():
            (BACKUP_DIR / path.name).write_bytes(path.read_bytes())


def build_preview(paths: list[Path]) -> None:
    cell_w, cell_h = 330, 220
    columns = 2
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("RGBA", (cell_w * columns, cell_h * rows), (14, 12, 12, 255))
    draw = ImageDraw.Draw(sheet)
    for idx, path in enumerate(paths):
        frame = Image.open(path).convert("RGBA")
        thumb = frame.copy()
        thumb.thumbnail((cell_w - 44, cell_h - 54), Image.Resampling.LANCZOS)
        x = (idx % columns) * cell_w + (cell_w - thumb.width) // 2
        y = (idx // columns) * cell_h + 36
        sheet.alpha_composite(thumb, (x, y))
        draw.text(((idx % columns) * cell_w + 14, (idx // columns) * cell_h + 12), path.stem, fill=(245, 210, 150, 255))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    backup_existing()
    written: list[Path] = []
    for frame_id, spec in FRAMES.items():
        src = SRC_DIR / SOURCE_BY_INDEX[int(spec["source"])]
        image = Image.open(src)
        frame = remove_checkerboard(image)
        out = OUT_DIR / f"ui_frame_hero_select_{frame_id}.png"
        frame.save(out)
        written.append(out)
    build_preview(written)
    print(f"Built {len(written)} hero-select frames into {OUT_DIR}")
    print(f"Preview: {PREVIEW}")
    print(f"Backup: {BACKUP_DIR}")


if __name__ == "__main__":
    main()
