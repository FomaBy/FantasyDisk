#!/usr/bin/env python3
"""Build the Red & Gold Dragon button kit from the user reference sheet."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png"
OUT_DIR = ROOT / "assets/sprites/ui/frames/red_gold"
PREVIEW = ROOT / "docs/design/previews/red_gold_button_kit_contact.png"
BACKUP_DIR = ROOT / "build/cleanup_backup_red_gold_buttons_2026_06_14"


BUTTONS = [
    {
        "id": "standard",
        "title": "Standard",
        "box": (23, 67, 454, 190),
        "size": (420, 104),
        "margins": (84, 30, 84, 32),
        "content": (76, 14, 76, 14),
    },
    {
        "id": "max",
        "title": "Max visual",
        "box": (469, 67, 1063, 190),
        "size": (560, 104),
        "margins": (90, 30, 90, 32),
        "content": (82, 14, 82, 14),
    },
    {
        "id": "main_menu",
        "title": "Main menu",
        "box": (24, 266, 468, 389),
        "size": (380, 104),
        "margins": (84, 30, 84, 32),
        "content": (76, 14, 76, 14),
    },
    {
        "id": "hero_confirm",
        "title": "Hero confirm",
        "box": (582, 266, 934, 389),
        "size": (320, 104),
        "margins": (78, 30, 78, 32),
        "content": (70, 14, 70, 14),
    },
    {
        "id": "reset_audio",
        "title": "Reset audio",
        "box": (32, 462, 470, 586),
        "size": (420, 104),
        "margins": (84, 30, 84, 32),
        "content": (76, 14, 76, 14),
    },
    {
        "id": "reset_bindings",
        "title": "Reset bindings",
        "box": (543, 462, 1008, 586),
        "size": (440, 104),
        "margins": (86, 30, 86, 32),
        "content": (78, 14, 78, 14),
    },
    {
        "id": "codex_tab",
        "title": "Codex tab",
        "box": (31, 656, 278, 778),
        "size": (170, 104),
        "margins": (58, 30, 58, 32),
        "content": (50, 14, 50, 14),
    },
    {
        "id": "back_s",
        "title": "Back S",
        "box": (403, 656, 647, 778),
        "size": (170, 104),
        "margins": (58, 30, 58, 32),
        "content": (50, 14, 50, 14),
    },
    {
        "id": "back_m",
        "title": "Back M",
        "box": (735, 656, 1044, 778),
        "size": (280, 104),
        "margins": (74, 30, 74, 32),
        "content": (66, 14, 66, 14),
    },
    {
        "id": "back_l",
        "title": "Back L",
        "box": (279, 832, 751, 950),
        "size": (380, 104),
        "margins": (84, 30, 84, 32),
        "content": (76, 14, 76, 14),
    },
    {
        "id": "attr_selector",
        "title": "Attribute",
        "box": (42, 977, 1004, 1106),
        "size": (560, 104),
        "margins": (92, 30, 92, 32),
        "content": (82, 14, 82, 14),
    },
    {
        "id": "fab",
        "title": "Upgrade FAB",
        "box": (66, 1207, 155, 1310),
        "size": (50, 50),
        "margins": (18, 18, 18, 18),
        "content": (8, 8, 8, 8),
    },
    {
        "id": "utility",
        "title": "Utility",
        "box": (292, 1206, 371, 1312),
        "size": (54, 42),
        "margins": (18, 14, 18, 14),
        "content": (8, 6, 8, 6),
    },
    {
        "id": "pause",
        "title": "Pause",
        "box": (525, 1174, 920, 1266),
        "size": (280, 60),
        "margins": (68, 20, 68, 20),
        "content": (56, 8, 56, 8),
    },
    {
        "id": "rebind",
        "title": "Rebind",
        "box": (423, 1320, 920, 1408),
        "size": (420, 62),
        "margins": (82, 20, 82, 20),
        "content": (72, 8, 72, 8),
    },
]


def _alpha_from_background(crop: Image.Image) -> Image.Image:
    rgba = crop.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    corner_points = [
        (0, 0),
        (width - 1, 0),
        (0, height - 1),
        (width - 1, height - 1),
        (width // 2, 0),
        (width // 2, height - 1),
    ]
    bg = tuple(sum(pixels[x, y][i] for x, y in corner_points) // len(corner_points) for i in range(3))
    for y in range(height):
        for x in range(width):
            r, g, b, _a = pixels[x, y]
            dr = abs(r - bg[0])
            dg = abs(g - bg[1])
            db = abs(b - bg[2])
            diff = dr + dg + db
            sat = max(r, g, b) - min(r, g, b)
            red_gold = max(0, r - bg[0]) + max(0, g - bg[1]) * 0.65
            alpha = max((diff - 12) * 5, (sat - 18) * 3, red_gold * 3)
            if alpha < 12:
                alpha = 0
            alpha = max(0, min(255, int(alpha)))
            # Remove the sheet's dark background color while keeping the
            # painted object color intact.
            pixels[x, y] = (r, g, b, alpha)
    alpha = rgba.getchannel("A").filter(ImageFilter.GaussianBlur(0.45))
    rgba.putalpha(alpha)
    return rgba


def _trim_alpha(image: Image.Image, padding: int = 2) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return image
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(image.width, bbox[2] + padding)
    bottom = min(image.height, bbox[3] + padding)
    return image.crop((left, top, right, bottom))


def _fit_exact(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    # The reference sheet labels define runtime dimensions. Fit the crop into
    # that box while preserving the button silhouette as much as possible.
    fitted = ImageOps.contain(image, size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas


def _state_variant(base: Image.Image, state: str) -> Image.Image:
    if state == "hover":
        glow = base.getchannel("A").filter(ImageFilter.GaussianBlur(4.0))
        glow_rgba = Image.new("RGBA", base.size, (255, 185, 48, 0))
        glow_rgba.putalpha(glow.point(lambda a: min(120, int(a * 0.55))))
        bright = ImageEnhance.Brightness(base).enhance(1.16)
        bright = ImageEnhance.Color(bright).enhance(1.12)
        out = Image.alpha_composite(glow_rgba, bright)
        return out
    if state == "pressed":
        shifted = Image.new("RGBA", base.size, (0, 0, 0, 0))
        dark = ImageEnhance.Brightness(base).enhance(0.78)
        shifted.alpha_composite(dark, (0, min(2, max(0, base.height // 24))))
        return shifted
    if state == "disabled":
        gray = ImageOps.grayscale(base.convert("RGB")).convert("RGBA")
        gray.putalpha(base.getchannel("A").point(lambda a: int(a * 0.58)))
        return ImageEnhance.Brightness(gray).enhance(0.62)
    return base


def _backup_old_buttons() -> None:
    old_dir = ROOT / "assets/sprites/ui/frames/dark_fantasy"
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    for path in sorted(old_dir.glob("ui_df_button_*.png")):
        shutil.copy2(path, BACKUP_DIR / path.name)


def _build_preview(records: list[dict]) -> None:
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    font_color = (238, 222, 180, 255)
    for record in records:
        idle = Image.open(record["path"]).convert("RGBA")
        hover = Image.open(record["hover"]).convert("RGBA")
        pressed = Image.open(record["pressed"]).convert("RGBA")
        disabled = Image.open(record["disabled"]).convert("RGBA")
        max_w = max(idle.width, hover.width, pressed.width, disabled.width)
        row_h = max(idle.height, hover.height, pressed.height, disabled.height) + 42
        row = Image.new("RGBA", (max_w * 4 + 300, row_h), (8, 10, 13, 255))
        draw = ImageDraw.Draw(row)
        draw.text((14, 8), f"{record['id']} {idle.width}x{idle.height}", fill=font_color)
        x = 290
        for img, label in [(idle, "idle"), (hover, "hover"), (pressed, "pressed"), (disabled, "disabled")]:
            y = 30 + (row_h - 34 - img.height) // 2
            row.alpha_composite(img, (x + (max_w - img.width) // 2, y))
            draw.text((x + 8, 8), label, fill=(176, 168, 144, 255))
            x += max_w
        rows.append(row)
    width = max(row.width for row in rows)
    height = sum(row.height + 8 for row in rows) + 32
    sheet = Image.new("RGBA", (width, height), (5, 7, 10, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 10), "FantasyDisk Red & Gold Dragon Button Kit", fill=(255, 210, 104, 255))
    y = 32
    for row in rows:
        sheet.alpha_composite(row, (0, y))
        y += row.height + 8
    sheet.save(PREVIEW)


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    _backup_old_buttons()
    records: list[dict] = []
    for item in BUTTONS:
        crop = source.crop(item["box"])
        alpha = _alpha_from_background(crop)
        fitted = _fit_exact(_trim_alpha(alpha), item["size"])
        base_path = OUT_DIR / f"ui_btn_red_gold_{item['id']}.png"
        fitted.save(base_path)
        record = {"id": item["id"], "path": str(base_path)}
        for state in ["hover", "pressed", "disabled"]:
            state_path = OUT_DIR / f"ui_btn_red_gold_{item['id']}_{state}.png"
            _state_variant(fitted, state).save(state_path)
            record[state] = str(state_path)
        records.append(record)
    _build_preview(records)
    print(f"Built {len(records)} button types into {OUT_DIR}")
    print(f"Preview: {PREVIEW}")
    print(f"Old button backup: {BACKUP_DIR}")


if __name__ == "__main__":
    main()
