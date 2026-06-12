# NOTE (2026-06-12): the frame + system-icon portion of this file is SUPERSEDED by
# tools/generate_ui_tavern_theme.py (warm D&D tavern theme). Do not regenerate
# frames/icons here - it would overwrite the warm theme with the old cold one.
# This tool is kept for the flat battle-background generation only.

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
UI_FRAME_DIR = ROOT / "assets/sprites/ui/frames/global"
SYSTEM_ICON_DIR = ROOT / "assets/sprites/ui/icons/system"
BACKGROUND_DIR = ROOT / "assets/backgrounds"


def ensure_dirs() -> None:
    UI_FRAME_DIR.mkdir(parents=True, exist_ok=True)
    SYSTEM_ICON_DIR.mkdir(parents=True, exist_ok=True)
    BACKGROUND_DIR.mkdir(parents=True, exist_ok=True)


def rgba(color: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return color[0], color[1], color[2], alpha


def draw_frame(path: Path, size: tuple[int, int], fill: tuple[int, int, int], border: tuple[int, int, int],
               inner: tuple[int, int, int], accent: tuple[int, int, int], radius: int = 10,
               border_width: int = 4, gem: bool = True) -> None:
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((8, 10, w - 6, h - 4), radius=radius + 4, fill=(0, 0, 0, 92))
    shadow = shadow.filter(ImageFilter.GaussianBlur(5))
    img.alpha_composite(shadow)

    d = ImageDraw.Draw(img)
    d.rounded_rectangle((5, 4, w - 6, h - 7), radius=radius, fill=rgba(fill, 238),
                        outline=rgba(border, 255), width=border_width)
    d.rounded_rectangle((11, 10, w - 12, h - 13), radius=max(3, radius - 4),
                        outline=rgba(inner, 205), width=max(1, border_width - 2))
    d.line((18, 9, w - 19, 9), fill=rgba(accent, 120), width=1)
    d.line((18, h - 13, w - 19, h - 13), fill=(0, 0, 0, 95), width=2)

    # Small hammered-metal dots that survive 9-patch scaling without becoming noisy.
    for x, y in [(16, 16), (w - 17, 16), (16, h - 19), (w - 17, h - 19)]:
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=rgba(accent, 230), outline=(35, 23, 12, 190))
    if gem:
        for x in (w // 2 - 18, w // 2 + 18):
            d.polygon([(x, 8), (x + 6, 14), (x, 20), (x - 6, 14)], fill=rgba(accent, 210),
                      outline=(36, 22, 10, 220))
    img.save(path)


def draw_system_icon(path: Path, kind: str, color=(238, 209, 122), accent=(86, 214, 197)) -> None:
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = rgba(color, 255)
    a = rgba(accent, 240)
    dark = (14, 10, 8, 220)
    if kind == "close":
        d.line((18, 18, 46, 46), fill=dark, width=9)
        d.line((46, 18, 18, 46), fill=dark, width=9)
        d.line((18, 18, 46, 46), fill=c, width=5)
        d.line((46, 18, 18, 46), fill=c, width=5)
    elif kind == "settings":
        d.ellipse((18, 18, 46, 46), outline=dark, width=9)
        d.ellipse((18, 18, 46, 46), outline=c, width=5)
        d.ellipse((27, 27, 37, 37), fill=a, outline=dark, width=2)
        for angle in range(0, 360, 45):
            x = 32 + math.cos(math.radians(angle)) * 22
            y = 32 + math.sin(math.radians(angle)) * 22
            d.rounded_rectangle((x - 3, y - 6, x + 3, y + 6), radius=2, fill=c, outline=dark, width=1)
    elif kind.startswith("arrow_") or kind == "back":
        direction = kind.replace("arrow_", "")
        if kind == "back":
            direction = "left"
        pts = {
            "left": [(19, 32), (38, 14), (38, 25), (50, 25), (50, 39), (38, 39), (38, 50)],
            "right": [(45, 32), (26, 14), (26, 25), (14, 25), (14, 39), (26, 39), (26, 50)],
            "up": [(32, 17), (14, 38), (25, 38), (25, 50), (39, 50), (39, 38), (50, 38)],
            "down": [(32, 47), (14, 26), (25, 26), (25, 14), (39, 14), (39, 26), (50, 26)],
        }[direction]
        d.line(pts + [pts[0]], fill=dark, width=9, joint="curve")
        d.polygon(pts, fill=c)
        d.line((pts[0][0], pts[0][1], pts[1][0], pts[1][1]), fill=a, width=2)
    elif kind == "checkbox_unchecked":
        d.rounded_rectangle((13, 13, 51, 51), radius=8, fill=(25, 22, 25, 235), outline=dark, width=8)
        d.rounded_rectangle((13, 13, 51, 51), radius=8, outline=c, width=4)
        d.rounded_rectangle((20, 20, 44, 44), radius=4, outline=(94, 71, 34, 190), width=2)
    elif kind == "checkbox_checked":
        draw_system_icon(path, "checkbox_unchecked", color, accent)
        img = Image.open(path).convert("RGBA")
        d = ImageDraw.Draw(img)
        d.line((20, 34, 29, 44, 47, 22), fill=dark, width=9, joint="curve")
        d.line((20, 34, 29, 44, 47, 22), fill=a, width=5, joint="curve")
        img.save(path)
        return
    elif kind == "slider_grabber":
        d.ellipse((12, 12, 52, 52), fill=(34, 24, 18, 245), outline=dark, width=6)
        d.ellipse((18, 18, 46, 46), outline=c, width=4)
        d.polygon([(32, 20), (40, 32), (32, 44), (24, 32)], fill=a, outline=dark)
    img.save(path)


def draw_slider_track(path: Path) -> None:
    img = Image.new("RGBA", (160, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((4, 7, 156, 17), radius=5, fill=(20, 18, 18, 235), outline=(120, 89, 40, 230), width=2)
    d.line((12, 10, 148, 10), fill=(238, 209, 122, 115), width=1)
    img.save(path)


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def blend(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t)


def draw_flat_background(path: Path, seed: int, base: tuple[int, int, int], secondary: tuple[int, int, int],
                         accent: tuple[int, int, int], biome: str) -> None:
    rng = random.Random(seed)
    w, h = 2560, 1440
    img = Image.new("RGB", (w, h), base)
    px = img.load()
    for y in range(h):
        yn = y / h
        for x in range(w):
            xn = x / w
            wave = (math.sin(xn * 18.0 + seed) + math.sin(yn * 21.0 - seed * 0.7)) * 0.5
            grain = rng.randint(-5, 5)
            t = max(0.0, min(1.0, 0.45 + wave * 0.08 + grain * 0.010))
            px[x, y] = blend(base, secondary, t)

    d = ImageDraw.Draw(img, "RGBA")
    # Low-contrast top-down ground strokes only: no tall rocks, bushes, or perspective objects.
    for _ in range(460):
        x = rng.randint(0, w)
        y = rng.randint(0, h)
        length = rng.randint(12, 55)
        angle = rng.random() * math.tau
        col = (*blend(base, accent, rng.uniform(0.25, 0.55)), rng.randint(32, 72))
        x2 = x + math.cos(angle) * length
        y2 = y + math.sin(angle) * length
        d.line((x, y, x2, y2), fill=col, width=rng.randint(1, 3))

    if biome == "stone":
        for _ in range(130):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            r = rng.randint(18, 80)
            col = (*blend(base, secondary, rng.uniform(0.55, 0.80)), 38)
            d.arc((x - r, y - r // 2, x + r, y + r // 2), rng.randint(0, 180), rng.randint(181, 360), fill=col, width=2)
        for _ in range(55):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            pts = [(x, y)]
            for _i in range(rng.randint(3, 7)):
                x += rng.randint(-55, 55)
                y += rng.randint(-35, 35)
                pts.append((x, y))
            d.line(pts, fill=(55, 52, 48, 60), width=rng.randint(1, 2))
    elif biome == "marsh":
        for _ in range(80):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            rx = rng.randint(35, 130)
            ry = rng.randint(10, 38)
            d.ellipse((x - rx, y - ry, x + rx, y + ry), fill=(36, 72, 62, 38), outline=(86, 110, 88, 35), width=2)
        for _ in range(300):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            d.line((x, y, x + rng.randint(-5, 5), y - rng.randint(8, 20)), fill=(80, 100, 70, 52), width=1)
    elif biome == "road":
        center = h // 2
        for step in range(-5, 6):
            y = center + step * 95 + rng.randint(-12, 12)
            d.line((0, y, w, y + rng.randint(-50, 50)), fill=(132, 105, 72, 34), width=rng.randint(18, 38))
        for _ in range(110):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            d.line((x, y, x + rng.randint(25, 90), y + rng.randint(-10, 10)), fill=(72, 55, 39, 56), width=1)
    elif biome == "meadow":
        for _ in range(620):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            blade = rng.randint(7, 22)
            d.line((x, y, x + rng.randint(-4, 4), y - blade), fill=(80, 116, 68, rng.randint(35, 72)), width=1)
        for _ in range(90):
            x = rng.randint(0, w)
            y = rng.randint(0, h)
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(155, 126, 86, 45))

    # Subtle edge darkening, center remains readable.
    vignette = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vignette)
    vd.ellipse((-350, -360, w + 350, h + 360), fill=205)
    vignette = Image.eval(vignette.filter(ImageFilter.GaussianBlur(90)), lambda v: int((205 - v) * 0.45))
    dark = Image.new("RGB", (w, h), (0, 0, 0))
    img = Image.composite(dark, img, vignette)
    img.save(path, quality=95)


def main() -> None:
    ensure_dirs()
    draw_frame(UI_FRAME_DIR / "ui_panel_frame.png", (128, 128), (18, 22, 26), (154, 117, 48), (72, 52, 28), (230, 188, 83), 12, 4)
    draw_frame(UI_FRAME_DIR / "ui_button_frame.png", (160, 72), (26, 30, 35), (165, 123, 49), (70, 49, 24), (241, 199, 82), 11, 4)
    draw_frame(UI_FRAME_DIR / "ui_card_frame.png", (128, 128), (18, 24, 29), (94, 132, 126), (61, 47, 31), (200, 158, 74), 9, 3, False)
    draw_frame(UI_FRAME_DIR / "ui_level_panel_frame.png", (160, 160), (25, 19, 34), (211, 157, 50), (93, 57, 121), (100, 226, 215), 12, 5)
    draw_frame(UI_FRAME_DIR / "ui_hud_panel_frame.png", (128, 96), (16, 19, 23), (139, 106, 46), (55, 45, 32), (224, 181, 77), 9, 3, False)
    draw_frame(UI_FRAME_DIR / "ui_hud_card_frame.png", (96, 72), (20, 25, 30), (78, 103, 108), (47, 42, 35), (203, 160, 73), 8, 2, False)
    draw_frame(UI_FRAME_DIR / "ui_tooltip_frame.png", (128, 96), (16, 13, 18), (142, 103, 52), (65, 43, 28), (226, 192, 98), 8, 3, False)
    for kind in ["close", "settings", "back", "arrow_left", "arrow_right", "arrow_up", "arrow_down", "checkbox_unchecked", "checkbox_checked", "slider_grabber"]:
        draw_system_icon(SYSTEM_ICON_DIR / f"ui_{kind}.png", kind)
    draw_slider_track(SYSTEM_ICON_DIR / "ui_slider_track.png")
    draw_frame(SYSTEM_ICON_DIR / "ui_scrollbar_grabber.png", (32, 96), (28, 25, 24), (158, 122, 57), (70, 51, 30), (230, 189, 83), 8, 3, False)

    draw_flat_background(BACKGROUND_DIR / "field_stone_garden.png", 1024, (75, 78, 71), (96, 101, 91), (132, 128, 108), "stone")
    draw_flat_background(BACKGROUND_DIR / "field_marsh.png", 2048, (45, 68, 56), (61, 84, 68), (89, 110, 74), "marsh")
    draw_flat_background(BACKGROUND_DIR / "field_dry_road.png", 4096, (95, 76, 52), (124, 101, 70), (153, 126, 82), "road")
    draw_flat_background(BACKGROUND_DIR / "field_meadow.png", 8192, (63, 92, 61), (79, 113, 69), (128, 133, 82), "meadow")


if __name__ == "__main__":
    main()
