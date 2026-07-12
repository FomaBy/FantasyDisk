#!/usr/bin/env python3
"""Build SCRUM-1081 plans and source-reuse Main Menu corner previews.

This script creates no production art. It composes the accepted Main Menu
background, logo, action plates, gratitude icon and PixelLab-lineage gold shell
to demonstrate the authored responsive geometry. The restrained aura is a
preview of a runtime glow, not a new bitmap asset.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
PREVIEW = ROOT / "docs/design/previews/scrum1081_main_menu_bottom_corners"
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


def round_half_up(value: float) -> int:
    """Match the authored/Godot half-up margin oracle instead of banker's round."""
    return int(math.floor(value + 0.5))


def geometry(width: int, height: int) -> dict:
    margin_x = round_half_up(160.0 * width / 1536.0)
    margin_y = round_half_up(160.0 * height / 1024.0)
    reserve = 32 if height >= 1200 else 24
    inner = (
        margin_x + reserve,
        margin_y + reserve,
        width - 2 * (margin_x + reserve),
        height - 2 * (margin_y + reserve),
    )

    if height < 700:
        logo, button_w, button_h, button_gap = (160, 60), 320, 54, 2
        logo_gap, icon_side, glow_inset, cluster_gap = 4, 72, 6, 12
        version_w, version_h, version_font = 128, 22, 14
    elif height < 800:
        logo, button_w, button_h, button_gap = (192, 72), 340, 56, 5
        logo_gap, icon_side, glow_inset, cluster_gap = 6, 72, 6, 12
        version_w, version_h, version_font = 136, 24, 14
    elif height < 1000:
        logo, button_w, button_h, button_gap = (267, 100), 360, 64, 8
        logo_gap, icon_side, glow_inset, cluster_gap = 8, 80, 8, 16
        version_w, version_h, version_font = 144, 26, 15
    elif height < 1200:
        logo, button_w, button_h, button_gap = (331, 124), 380, 76, 10
        logo_gap, icon_side, glow_inset, cluster_gap = 12, 80, 8, 16
        version_w, version_h, version_font = 160, 28, 16
    else:
        logo, button_w, button_h, button_gap = (480, 180), 380, 96, 14
        logo_gap, icon_side, glow_inset, cluster_gap = 20, 96, 10, 20
        version_w, version_h, version_font = 184, 32, 18

    inner_x, inner_y, inner_w, inner_h = inner
    glow_side = icon_side + glow_inset * 2
    version = (
        inner_x + inner_w - version_w,
        inner_y + inner_h - version_h,
        version_w,
        version_h,
    )
    gratitude_glow = (
        version[0] - cluster_gap - glow_side,
        inner_y + inner_h - glow_side,
        glow_side,
        glow_side,
    )
    gratitude = (
        gratitude_glow[0] + glow_inset,
        gratitude_glow[1] + glow_inset,
        icon_side,
        icon_side,
    )
    action_x = inner_x
    action_y = inner_y + logo[1] + logo_gap
    actions = (
        action_x,
        action_y,
        button_w,
        button_h * len(BUTTON_LABELS) + button_gap * (len(BUTTON_LABELS) - 1),
    )
    return {
        "frame_safe": (margin_x, margin_y, width - 2 * margin_x, height - 2 * margin_y),
        "inner": inner,
        "reserve": reserve,
        "logo": (inner_x, inner_y, logo[0], logo[1]),
        "actions": actions,
        "button_h": button_h,
        "button_gap": button_gap,
        "gratitude_glow": gratitude_glow,
        "gratitude": gratitude,
        "glow_inset": glow_inset,
        "version": version,
        "version_font": version_font,
        "cluster_gap": cluster_gap,
    }


def plan_for(width: int, height: int, geom: dict) -> dict:
    elements = [
        {"id": "frame_art", "kind": "decor", "x": 0, "y": 0, "w": width, "h": height, "collision": False},
        {
            "id": "authored_inner",
            "kind": "panel",
            "x": geom["inner"][0], "y": geom["inner"][1],
            "w": geom["inner"][2], "h": geom["inner"][3],
            "content_zone": True, "collision": False,
        },
        {
            "id": "logo", "kind": "icon", "parent": "authored_inner",
            "x": geom["logo"][0], "y": geom["logo"][1],
            "w": geom["logo"][2], "h": geom["logo"][3],
            "content_zone": True, "collision": True,
        },
        {
            "id": "gratitude_glow", "kind": "decor", "parent": "authored_inner",
            "x": geom["gratitude_glow"][0], "y": geom["gratitude_glow"][1],
            "w": geom["gratitude_glow"][2], "h": geom["gratitude_glow"][3],
            "content_zone": True, "collision": True,
        },
        {
            "id": "gratitude_icon", "kind": "button", "parent": "gratitude_glow",
            "x": geom["gratitude"][0], "y": geom["gratitude"][1],
            "w": geom["gratitude"][2], "h": geom["gratitude"][3],
            "min_w": geom["gratitude"][2], "min_h": geom["gratitude"][3],
            "content_zone": True, "collision": False,
        },
        {
            "id": "runtime_version", "kind": "text", "parent": "authored_inner",
            "x": geom["version"][0], "y": geom["version"][1],
            "w": geom["version"][2], "h": geom["version"][3],
            "text": "vX.Y.Z", "max_font": geom["version_font"], "min_font": geom["version_font"],
            "content_zone": True, "collision": True,
        },
    ]
    action_x, action_y, action_w, _ = geom["actions"]
    for index, label in enumerate(BUTTON_LABELS):
        elements.append({
            "id": f"action_{index + 1}", "kind": "button", "parent": "authored_inner",
            "x": action_x,
            "y": action_y + index * (geom["button_h"] + geom["button_gap"]),
            "w": action_w, "h": geom["button_h"],
            "text": label, "max_font": 24 if height >= 900 else 21, "min_font": 16,
            "content_zone": True, "collision": True,
        })
    return {
        "canvas": {"width": width, "height": height},
        "policy": {"min_gap": 1, "allow_overlap": False},
        "content": {"runtime_version": "ProjectSettings.application/config/version"},
        "elements": elements,
    }


def layout_for(width: int, height: int, geom: dict) -> dict:
    version = geom["version"]
    return {
        "canvas": {"width": width, "height": height},
        "defaults": {
            "font": str(FONT),
            "color": "#D8D0BD",
            "stroke_fill": "#120D11",
            "stroke_width": 2,
            "align": "right",
            "valign": "bottom",
        },
        "content": {"runtime_version_preview": "vX.Y.Z"},
        "runtime_contract": {
            "text": "v%s % ProjectSettings.get_setting('application/config/version', '0.0.0')",
            "hardcoded_version_forbidden": True,
        },
        "zones": [{
            "id": "runtime_version",
            "content_key": "runtime_version_preview",
            "role": "caption",
            "x": version[0], "y": version[1], "w": version[2], "h": version[3],
            "max_font": geom["version_font"], "min_font": geom["version_font"],
            "align": "right", "valign": "bottom", "required": True,
            "debug_color": "#D8D0BD",
        }],
    }


def nine_slice(src: Image.Image, size: tuple[int, int], source_margin: int = 160) -> Image.Image:
    width, height = size
    left = round_half_up(source_margin * width / src.width)
    top = round_half_up(source_margin * height / src.height)
    xs = [0, source_margin, src.width - source_margin, src.width]
    ys = [0, source_margin, src.height - source_margin, src.height]
    xd = [0, left, width - left, width]
    yd = [0, top, height - top, height]
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    for row in range(3):
        for col in range(3):
            crop = src.crop((xs[col], ys[row], xs[col + 1], ys[row + 1]))
            target = (xd[col + 1] - xd[col], yd[row + 1] - yd[row])
            if target[0] > 0 and target[1] > 0:
                output.alpha_composite(crop.resize(target, Image.Resampling.NEAREST), (xd[col], yd[row]))
    return output


def contain(src: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = src.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    output.alpha_composite(copy, ((size[0] - copy.width) // 2, (size[1] - copy.height) // 2))
    return output


def fit_font(draw: ImageDraw.ImageDraw, text: str, box: tuple[int, int], max_size: int, min_size: int) -> ImageFont.FreeTypeFont:
    for size in range(max_size, min_size - 1, -1):
        font = ImageFont.truetype(str(FONT), size)
        bounds = draw.textbbox((0, 0), text, font=font, stroke_width=1)
        if bounds[2] - bounds[0] <= box[0] and bounds[3] - bounds[1] <= box[1]:
            return font
    return ImageFont.truetype(str(FONT), min_size)


def write_plans() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for width, height in TARGETS:
        geom = geometry(width, height)
        slug = f"{width}x{height}"
        (OUT / f"ui_plan_{slug}.json").write_text(
            json.dumps(plan_for(width, height, geom), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        (OUT / f"layout_{slug}.json").write_text(
            json.dumps(layout_for(width, height, geom), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    (OUT / "ui_plan.json").write_text((OUT / "ui_plan_1920x1080.json").read_text(encoding="utf-8"), encoding="utf-8")
    (OUT / "layout.json").write_text((OUT / "layout_1920x1080.json").read_text(encoding="utf-8"), encoding="utf-8")


def build_preview(width: int, height: int) -> None:
    geom = geometry(width, height)
    background = Image.open(ROOT / "assets/backgrounds/main_menu_epic_battle_v3.png").convert("RGBA")
    background = background.resize((width, height), Image.Resampling.LANCZOS)
    background = Image.alpha_composite(background, Image.new("RGBA", (width, height), (5, 5, 10, 46)))
    logo = Image.open(ROOT / "assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png").convert("RGBA")
    button = Image.open(ROOT / "assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_main_menu_380x104_normal.png").convert("RGBA")
    gratitude = Image.open(ROOT / "assets/sprites/ui/icons/credits/ui_icon_gratitude.png").convert("RGBA")
    frame = Image.open(ROOT / "assets/sprites/ui/meta40/frame_border.png").convert("RGBA")

    logo_x, logo_y, logo_w, logo_h = geom["logo"]
    background.alpha_composite(contain(logo, (logo_w, logo_h)), (logo_x, logo_y))

    draw = ImageDraw.Draw(background)
    action_x, action_y, action_w, _ = geom["actions"]
    for index, label in enumerate(BUTTON_LABELS):
        y = action_y + index * (geom["button_h"] + geom["button_gap"])
        plate = button.resize((action_w, geom["button_h"]), Image.Resampling.LANCZOS)
        background.alpha_composite(plate, (action_x, y))
        font = fit_font(draw, label, (action_w - 70, geom["button_h"] - 12), 24 if height >= 900 else 21, 16)
        bounds = draw.textbbox((0, 0), label, font=font, stroke_width=2)
        text_x = action_x + (action_w - (bounds[2] - bounds[0])) // 2
        text_y = y + (geom["button_h"] - (bounds[3] - bounds[1])) // 2 - bounds[1]
        draw.text((text_x, text_y), label, font=font, fill=(241, 224, 180, 255), stroke_fill=(20, 9, 12, 230), stroke_width=2)

    glow_x, glow_y, glow_w, glow_h = geom["gratitude_glow"]
    aura = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura, "RGBA")
    aura_draw.ellipse((glow_x, glow_y, glow_x + glow_w, glow_y + glow_h), fill=(255, 190, 74, 74))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=max(5, geom["glow_inset"] * 1.5)))
    background = Image.alpha_composite(background, aura)
    icon_x, icon_y, icon_w, icon_h = geom["gratitude"]
    background.alpha_composite(contain(gratitude, (icon_w, icon_h)), (icon_x, icon_y))

    draw = ImageDraw.Draw(background)
    version_x, version_y, version_w, version_h = geom["version"]
    version_text = "vX.Y.Z"
    version_font = ImageFont.truetype(str(FONT), geom["version_font"])
    bounds = draw.textbbox((0, 0), version_text, font=version_font, stroke_width=2)
    draw.text(
        (version_x + version_w - (bounds[2] - bounds[0]), version_y + version_h - (bounds[3] - bounds[1]) - bounds[1]),
        version_text,
        font=version_font,
        fill=(216, 208, 189, 238),
        stroke_fill=(18, 13, 17, 220),
        stroke_width=2,
    )

    background = Image.alpha_composite(background, nine_slice(frame, (width, height)))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    slug = f"{width}x{height}"
    background.convert("RGB").save(PREVIEW / f"main_menu_bottom_corners_{slug}.png", quality=96)

    debug = background.copy()
    debug_draw = ImageDraw.Draw(debug, "RGBA")
    colors = {
        "inner": (66, 255, 163, 255),
        "logo": (80, 190, 255, 255),
        "actions": (255, 187, 64, 255),
        "gratitude_glow": (255, 105, 214, 255),
        "gratitude": (255, 166, 235, 255),
        "version": (220, 220, 220, 255),
    }
    for key, color in colors.items():
        x, y, w, h = geom[key]
        debug_draw.rectangle((x, y, x + w, y + h), outline=color, width=3)
        debug_draw.text((x + 4, y + 4), key, font=ImageFont.truetype(str(FONT), max(10, geom["version_font"] - 2)), fill=color, stroke_fill=(0, 0, 0, 220), stroke_width=2)
    debug.convert("RGB").save(PREVIEW / f"main_menu_bottom_corners_{slug}_debug.png", quality=96)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plans-only", action="store_true")
    args = parser.parse_args()
    write_plans()
    if not args.plans_only:
        for target in TARGETS:
            build_preview(*target)


if __name__ == "__main__":
    main()
