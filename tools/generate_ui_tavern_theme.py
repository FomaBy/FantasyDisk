"""Re-skin the global UI frames and system icons into a warm D&D tavern theme.

User art direction (2026-06-12): simplicity + Dungeons & Dragons tavern /
travel / adventure vibe. Replaces the cold navy-black + cyan-gem panels with
warm dark wood, worn leather, brass trim and candle-amber accents.

Design constraint: in-game text is light, so panels stay DARK (a tavern at
night) to keep text readable — the warmth comes from wood/leather/brass, not
from going light. Same file names, sizes and border geometry as the previous
set, so the StyleBoxTexture 9-patch wiring in ui_screens.gd is unchanged.
Cyan gems are dropped (simpler, and nothing unique sits mid-edge where 9-patch
would stretch it).

Run from the project root:  python3 tools/generate_ui_tavern_theme.py
"""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
FRAME_DIR = ROOT / "assets/sprites/ui/frames/global"
ICON_DIR = ROOT / "assets/sprites/ui/icons/system"

# --- tavern palette ---------------------------------------------------------
WALNUT_TOP = (54, 38, 25)        # lit top of a wood panel
WALNUT_BOT = (33, 22, 15)        # shaded bottom
LEATHER_TOP = (46, 30, 26)       # worn oxblood leather (tooltip/level panel)
LEATHER_BOT = (28, 17, 15)
HUD_TOP = (30, 22, 17)           # darker wood for HUD over gameplay
HUD_BOT = (18, 13, 10)
BRASS = (158, 116, 54)
BRASS_LIGHT = (224, 178, 104)
BRASS_DARK = (84, 58, 28)
AMBER = (232, 176, 92)
STUD_OUTLINE = (30, 19, 9)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def lerp(a, b, t):
    return int(a + (b - a) * t)


def vgrad(c_top, c_bot, t):
    return (lerp(c_top[0], c_bot[0], t), lerp(c_top[1], c_bot[1], t), lerp(c_top[2], c_bot[2], t))


def wood_fill(size, c_top, c_bot, radius, leather=False, seed=7):
    """Warm wood/leather fill: vertical gradient + soft grain, clipped to a
    rounded rectangle so it drops straight into the frame interior."""
    w, h = size
    rng = random.Random(seed)
    fill = Image.new("RGBA", size, (0, 0, 0, 0))
    px = fill.load()
    for y in range(h):
        base = vgrad(c_top, c_bot, y / max(h - 1, 1))
        for x in range(w):
            px[x, y] = (base[0], base[1], base[2], 255)
    grain = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grain)
    if leather:
        for _ in range(int(w * h * 0.02)):
            x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
            shade = rng.choice([(18, 11, 10, 60), (70, 48, 42, 50)])
            gd.point((x, y), fill=shade)
    else:
        for _ in range(max(6, w // 14)):
            gx = rng.randint(2, w - 3)
            wob = rng.uniform(-1.2, 1.2)
            light = rng.random() < 0.5
            col = (96, 70, 44, 36) if light else (20, 13, 8, 46)
            pts = [(gx + wob * (yy / h), yy) for yy in range(0, h, 2)]
            gd.line(pts, fill=col, width=1)
    grain = grain.filter(ImageFilter.GaussianBlur(0.6))
    fill.alpha_composite(grain)
    # round the corners
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((5, 4, w - 6, h - 7), radius=radius, fill=255)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(fill, (0, 0), mask)
    return out


def draw_tavern_frame(path, size, c_top, c_bot, radius=10, border_width=4,
                      leather=False, stud=True, cabochon=False, seed=7):
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))

    # drop shadow grounds the panel
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((8, 11, w - 6, h - 4), radius=radius + 4, fill=(0, 0, 0, 96))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(5)))

    # wood / leather interior
    img.alpha_composite(wood_fill(size, c_top, c_bot, radius, leather, seed))

    d = ImageDraw.Draw(img)
    # candle sheen across the top, inside the panel
    sheen = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(sheen).rounded_rectangle((10, 8, w - 11, h // 2), radius=radius, fill=(255, 220, 150, 26))
    img.alpha_composite(sheen.filter(ImageFilter.GaussianBlur(6)))

    # brass border: dark seat, brass body, warm top-left bevel
    d.rounded_rectangle((5, 4, w - 6, h - 7), radius=radius, outline=rgba(BRASS_DARK), width=border_width + 2)
    d.rounded_rectangle((5, 4, w - 6, h - 7), radius=radius, outline=rgba(BRASS), width=border_width)
    d.arc((6, 5, w - 7, h - 8), 150, 320, fill=rgba(BRASS_LIGHT, 220), width=max(1, border_width - 2))
    # thin inner shadow line for depth
    d.rounded_rectangle((5 + border_width + 2, 4 + border_width + 2, w - 7 - border_width, h - 9 - border_width),
                        radius=max(2, radius - 4), outline=(0, 0, 0, 90), width=1)

    if stud:
        m = 14
        for x, y in [(m, m), (w - m - 1, m), (m, h - m - 4), (w - m - 1, h - m - 4)]:
            d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=rgba(BRASS_DARK), outline=STUD_OUTLINE + (220,))
            d.ellipse((x - 3, y - 3, x + 2, y + 2), fill=rgba(BRASS_LIGHT))
            d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(255, 240, 205, 255))
    if cabochon:
        cx = w // 2
        d.ellipse((cx - 9, 3, cx + 9, 19), fill=rgba(BRASS_DARK), outline=STUD_OUTLINE + (230,))
        d.ellipse((cx - 7, 5, cx + 7, 17), fill=rgba(AMBER))
        d.ellipse((cx - 5, 6, cx, 11), fill=(255, 226, 168, 230))
    img.save(path)


# --- system icons -----------------------------------------------------------
GOLD = (236, 206, 128)
GOLD_ACCENT = (232, 176, 92)
INK = (26, 16, 10, 230)


def draw_icon(path, kind):
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = rgba(GOLD)
    a = rgba(GOLD_ACCENT, 245)
    if kind == "close":
        d.line((18, 18, 46, 46), fill=INK, width=10)
        d.line((46, 18, 18, 46), fill=INK, width=10)
        d.line((18, 18, 46, 46), fill=c, width=5)
        d.line((46, 18, 18, 46), fill=c, width=5)
    elif kind == "settings":
        d.ellipse((19, 19, 45, 45), outline=INK, width=10)
        d.ellipse((19, 19, 45, 45), outline=c, width=5)
        d.ellipse((27, 27, 37, 37), fill=a, outline=INK, width=2)
        for ang in range(0, 360, 45):
            import math
            x = 32 + math.cos(math.radians(ang)) * 22
            y = 32 + math.sin(math.radians(ang)) * 22
            d.rounded_rectangle((x - 3, y - 6, x + 3, y + 6), radius=2, fill=c, outline=INK, width=1)
    elif kind.startswith("arrow_") or kind == "back":
        direction = "left" if kind == "back" else kind.replace("arrow_", "")
        pts = {
            "left": [(19, 32), (38, 14), (38, 25), (50, 25), (50, 39), (38, 39), (38, 50)],
            "right": [(45, 32), (26, 14), (26, 25), (14, 25), (14, 39), (26, 39), (26, 50)],
            "up": [(32, 17), (14, 38), (25, 38), (25, 50), (39, 50), (39, 38), (50, 38)],
            "down": [(32, 47), (14, 26), (25, 26), (25, 14), (39, 14), (39, 26), (50, 26)],
        }[direction]
        d.line(pts + [pts[0]], fill=INK, width=10, joint="curve")
        d.polygon(pts, fill=c)
        d.line((pts[0][0], pts[0][1], pts[1][0], pts[1][1]), fill=a, width=2)
    elif kind == "checkbox_unchecked":
        # small wooden plaque with brass rim
        d.rounded_rectangle((13, 13, 51, 51), radius=8, fill=(40, 28, 19, 240), outline=INK, width=8)
        d.rounded_rectangle((13, 13, 51, 51), radius=8, outline=c, width=4)
        d.arc((14, 14, 50, 50), 150, 320, fill=rgba(BRASS_LIGHT, 200), width=2)
    elif kind == "checkbox_checked":
        draw_icon(path, "checkbox_unchecked")
        img2 = Image.open(path).convert("RGBA")
        d2 = ImageDraw.Draw(img2)
        d2.line((20, 34, 29, 44, 47, 22), fill=INK, width=10, joint="curve")
        d2.line((20, 34, 29, 44, 47, 22), fill=a, width=5, joint="curve")
        img2.save(path)
        return
    elif kind == "slider_grabber":
        # brass-bound wooden knob
        d.ellipse((12, 12, 52, 52), fill=(44, 30, 19, 248), outline=INK, width=6)
        d.ellipse((18, 18, 46, 46), outline=c, width=4)
        d.arc((13, 13, 51, 51), 150, 320, fill=rgba(BRASS_LIGHT, 200), width=2)
        d.ellipse((28, 28, 36, 36), fill=a, outline=INK, width=1)
    img.save(path)


def draw_slider_track(path):
    img = Image.new("RGBA", (160, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((4, 7, 156, 17), radius=5, fill=(30, 20, 13, 240), outline=rgba(BRASS, 235), width=2)
    d.line((12, 10, 148, 10), fill=rgba(BRASS_LIGHT, 120), width=1)
    img.save(path)


def main():
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    # (name, size, top, bot, radius, border_width, leather, stud, cabochon)
    frames = [
        ("ui_panel_frame.png", (128, 128), WALNUT_TOP, WALNUT_BOT, 12, 4, False, True, False),
        ("ui_button_frame.png", (160, 72), (60, 43, 28), (36, 25, 16), 11, 4, False, True, False),
        ("ui_card_frame.png", (128, 128), WALNUT_TOP, WALNUT_BOT, 9, 3, False, True, False),
        ("ui_level_panel_frame.png", (160, 160), LEATHER_TOP, LEATHER_BOT, 12, 5, True, True, True),
        ("ui_hud_panel_frame.png", (128, 96), HUD_TOP, HUD_BOT, 9, 3, False, False, False),
        ("ui_hud_card_frame.png", (96, 72), HUD_TOP, HUD_BOT, 8, 2, False, False, False),
        ("ui_tooltip_frame.png", (128, 96), LEATHER_TOP, LEATHER_BOT, 8, 3, True, False, False),
    ]
    for name, size, top, bot, r, bw, leather, stud, cab in frames:
        draw_tavern_frame(FRAME_DIR / name, size, top, bot, r, bw, leather, stud, cab,
                          seed=sum(name.encode()))
    draw_tavern_frame(ICON_DIR / "ui_scrollbar_grabber.png", (32, 96), (52, 36, 23), (32, 21, 14),
                      8, 3, False, False, False, seed=99)
    for kind in ["close", "settings", "back", "arrow_left", "arrow_right", "arrow_up", "arrow_down",
                 "checkbox_unchecked", "checkbox_checked", "slider_grabber"]:
        draw_icon(ICON_DIR / f"ui_{kind}.png", kind)
    draw_slider_track(ICON_DIR / "ui_slider_track.png")
    print(f"tavern theme written: {len(frames)} frames + system icons")


if __name__ == "__main__":
    main()
