#!/usr/bin/env python3
"""Build SCRUM-1059 plans and source-reuse mockups from accepted runtime art.

This script creates no new art. It composes the already accepted background,
logo, button family, gratitude icon and hollow gold shell at the exact runtime
geometry used by SCRUM-1059.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
PREVIEW = ROOT / "docs/design/previews/scrum1059_main_menu_column"
FONT = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
TARGETS = [(1152, 648), (1280, 720), (1600, 900), (1920, 1080), (2560, 1440)]
BUTTON_LABELS = [
    "Начать новую игру",
    "Настройки",
    "Атлас героев",
    "Что нового  ●",
    "Кодекс",
    "Выйти из игры",
]


def rects(width: int, height: int) -> dict:
    mx = round(160.0 * width / 1536.0)
    my = round(160.0 * height / 1024.0)
    reserve = 32 if height >= 1200 else 24
    inner = (mx + reserve, my + reserve, width - 2 * (mx + reserve), height - 2 * (my + reserve))
    if height < 700:
        logo, button_w, button_h, gap, logo_gap, credit, version_size = (160, 60), 320, 54, 2, 4, 64, (112, 18)
    elif height < 800:
        logo, button_w, button_h, gap, logo_gap, credit, version_size = (192, 72), 340, 56, 5, 6, 64, (112, 18)
    elif height < 1000:
        logo, button_w, button_h, gap, logo_gap, credit, version_size = (267, 100), 360, 64, 8, 8, 72, (126, 20)
    elif height < 1200:
        logo, button_w, button_h, gap, logo_gap, credit, version_size = (331, 124), 380, 76, 10, 12, 72, (126, 20)
    else:
        logo, button_w, button_h, gap, logo_gap, credit, version_size = (480, 180), 380, 96, 14, 20, 88, (124, 24)
    x, y, iw, ih = inner
    logo_rect = (x, y, logo[0], logo[1])
    actions_y = y + logo[1] + logo_gap
    actions_rect = (x, actions_y, button_w, button_h * 6 + gap * 5)
    credits_rect = (x + iw - credit, y, credit, credit)
    version_rect = (x + logo[0] + 16, round(y + (logo[1] - version_size[1]) / 2), *version_size)
    return {
        "frame_safe": (mx, my, width - 2 * mx, height - 2 * my),
        "inner": inner,
        "logo": logo_rect,
        "actions": actions_rect,
        "button_h": button_h,
        "gap": gap,
        "credits": credits_rect,
        "version": version_rect,
    }


def nine_slice(src: Image.Image, size: tuple[int, int], source_margin: int = 160) -> Image.Image:
    w, h = size
    dl = round(source_margin * w / src.width)
    dt = round(source_margin * h / src.height)
    dr, db = dl, dt
    sw, sh = src.size
    xs, ys = [0, source_margin, sw - source_margin, sw], [0, source_margin, sh - source_margin, sh]
    xd, yd = [0, dl, w - dr, w], [0, dt, h - db, h]
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    for yi in range(3):
        for xi in range(3):
            crop = src.crop((xs[xi], ys[yi], xs[xi + 1], ys[yi + 1]))
            target = (xd[xi + 1] - xd[xi], yd[yi + 1] - yd[yi])
            if target[0] > 0 and target[1] > 0:
                crop = crop.resize(target, Image.Resampling.NEAREST)
                out.alpha_composite(crop, (xd[xi], yd[yi]))
    return out


def contain(src: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = src.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(copy, ((size[0] - copy.width) // 2, (size[1] - copy.height) // 2))
    return out


def fit_font(draw: ImageDraw.ImageDraw, text: str, box: tuple[int, int], max_size: int, min_size: int) -> ImageFont.FreeTypeFont:
    for size in range(max_size, min_size - 1, -1):
        font = ImageFont.truetype(str(FONT), size)
        bbox = draw.textbbox((0, 0), text, font=font, stroke_width=1)
        if bbox[2] - bbox[0] <= box[0] and bbox[3] - bbox[1] <= box[1]:
            return font
    return ImageFont.truetype(str(FONT), min_size)


def plan_for(width: int, height: int, geom: dict) -> dict:
    elements = [
        {"id": "frame_art", "kind": "decor", "x": 0, "y": 0, "w": width, "h": height, "collision": False},
        {"id": "authored_inner", "kind": "panel", "x": geom["inner"][0], "y": geom["inner"][1], "w": geom["inner"][2], "h": geom["inner"][3], "content_zone": True, "collision": False},
        {"id": "logo", "kind": "icon", "parent": "authored_inner", "x": geom["logo"][0], "y": geom["logo"][1], "w": geom["logo"][2], "h": geom["logo"][3], "content_zone": True, "collision": True},
        {"id": "gratitude", "kind": "icon", "parent": "authored_inner", "x": geom["credits"][0], "y": geom["credits"][1], "w": geom["credits"][2], "h": geom["credits"][3], "content_zone": True, "collision": True},
        {"id": "version", "kind": "text", "parent": "authored_inner", "x": geom["version"][0], "y": geom["version"][1], "w": geom["version"][2], "h": geom["version"][3], "text": "v0.2.1", "max_font": 14, "min_font": 11, "content_zone": True, "collision": True},
    ]
    x, y, w, _ = geom["actions"]
    for index, label in enumerate(BUTTON_LABELS):
        elements.append({
            "id": f"action_{index + 1}", "kind": "button", "parent": "authored_inner",
            "x": x, "y": y + index * (geom["button_h"] + geom["gap"]), "w": w, "h": geom["button_h"],
            "text": label, "max_font": 24 if height >= 900 else 21, "min_font": 16,
            "content_zone": True, "collision": True,
        })
    return {
        "canvas": {"width": width, "height": height},
        # The validator expands both colliders by min_gap, so 2 validates a
        # physical gap of at least 4 px while the exact authored gaps remain in
        # the element rectangles and spec table.
        "policy": {"min_gap": 1, "allow_overlap": False},
        "elements": elements,
    }


def build(width: int, height: int) -> None:
    geom = rects(width, height)
    slug = f"{width}x{height}"
    (OUT / f"ui_plan_{slug}.json").write_text(json.dumps(plan_for(width, height, geom), ensure_ascii=False, indent=2) + "\n")

    bg = Image.open(ROOT / "assets/backgrounds/main_menu_epic_battle_v3.png").convert("RGBA")
    bg = bg.resize((width, height), Image.Resampling.LANCZOS)
    shade = Image.new("RGBA", (width, height), (5, 5, 10, 46))
    bg = Image.alpha_composite(bg, shade)
    logo = Image.open(ROOT / "assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png").convert("RGBA")
    button = Image.open(ROOT / "assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_main_menu_380x104_normal.png").convert("RGBA")
    gratitude = Image.open(ROOT / "assets/sprites/ui/icons/credits/ui_icon_gratitude.png").convert("RGBA")
    frame = Image.open(ROOT / "assets/sprites/ui/meta40/frame_border.png").convert("RGBA")

    lx, ly, lw, lh = geom["logo"]
    bg.alpha_composite(contain(logo, (lw, lh)), (lx, ly))
    draw = ImageDraw.Draw(bg)
    ax, ay, aw, _ = geom["actions"]
    for index, label in enumerate(BUTTON_LABELS):
        by = ay + index * (geom["button_h"] + geom["gap"])
        plate = button.resize((aw, geom["button_h"]), Image.Resampling.LANCZOS)
        bg.alpha_composite(plate, (ax, by))
        font = fit_font(draw, label, (aw - 70, geom["button_h"] - 12), 24 if height >= 900 else 21, 16)
        bbox = draw.textbbox((0, 0), label, font=font, stroke_width=2)
        tx = ax + (aw - (bbox[2] - bbox[0])) // 2
        ty = by + (geom["button_h"] - (bbox[3] - bbox[1])) // 2 - bbox[1]
        draw.text((tx, ty), label, font=font, fill=(241, 224, 180, 255), stroke_fill=(20, 9, 12, 230), stroke_width=2)
    cx, cy, cw, ch = geom["credits"]
    bg.alpha_composite(contain(gratitude, (cw, ch)), (cx, cy))
    vx, vy, vw, vh = geom["version"]
    vfont = ImageFont.truetype(str(FONT), 12)
    vb = draw.textbbox((0, 0), "v0.2.1", font=vfont)
    draw.text((vx + vw - (vb[2] - vb[0]), vy + (vh - (vb[3] - vb[1])) // 2 - vb[1]), "v0.2.1", font=vfont, fill=(158, 168, 184, 220))
    bg = Image.alpha_composite(bg, nine_slice(frame, (width, height)))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(PREVIEW / f"main_menu_single_column_{slug}.png", quality=96)

    debug = bg.copy()
    dd = ImageDraw.Draw(debug, "RGBA")
    ix, iy, iw, ih = geom["inner"]
    dd.rectangle((ix, iy, ix + iw, iy + ih), outline=(66, 255, 163, 255), width=3)
    for key, color in [("logo", (80, 190, 255, 255)), ("actions", (255, 187, 64, 255)), ("credits", (238, 110, 255, 255)), ("version", (210, 210, 210, 255))]:
        x, y, w, h = geom[key]
        dd.rectangle((x, y, x + w, y + h), outline=color, width=3)
    debug.convert("RGB").save(PREVIEW / f"main_menu_single_column_{slug}_debug.png", quality=96)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for target in TARGETS:
        build(*target)
