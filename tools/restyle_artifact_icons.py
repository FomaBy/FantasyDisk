"""Restyle all artifact icons into the painted fantasy-cartoon game style
and generate the combat timer frame assets.

Design task: design_artifact_icons_fantasy_restyle_task.md

Each 128x128 icon keeps its recognizable item art (the inner disc of the old
flat badge) but gets a new rich medallion: dark outline, shaded gold ring with
rivets, color-graded inner disc with vignette and a top light, per-icon accent
glow sampled from the item itself. Reads at 40px and pops both on the light
shop parchment and the dark pause background.

Timer: assets/sprites/ui/hud/timer_frame.png (300x90) and
timer_frame_alarm.png (red-glow variant for the low-time state - Back-end
swaps the texture, no shader needed).

Originals are backed up to build/bg_backup/artifacts/ (rebuilt from backup,
idempotent). Run:  python3 tools/restyle_artifact_icons.py
"""
from __future__ import annotations

import colorsys
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"
BACKUP = ROOT / "build" / "bg_backup" / "artifacts"
HUD_DIR = ROOT / "assets" / "sprites" / "ui" / "hud"

SIZE = 128
CENTER = SIZE / 2.0
DISC_R = 45          # inner disc radius extracted from the old badge
RING_OUT = 60        # new gold ring outer radius
RING_IN = 46

OUTLINE = (32, 24, 40)
GOLD_DARK = (122, 82, 32)
GOLD_MID = (196, 142, 58)
GOLD_LIGHT = (244, 205, 110)


def circle_mask(radius: float, blur: float = 0.8) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((CENTER - radius, CENTER - radius, CENTER + radius, CENTER + radius), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(blur))


def accent_color(disc: Image.Image) -> tuple[int, int, int]:
    """Most saturated-bright hue of the item art."""
    small = disc.resize((32, 32))
    best = (180, 120, 220)
    best_score = -1.0
    for r, g, b, a in small.getdata():
        if a < 120:
            continue
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        score = s * v
        if score > best_score:
            best_score = score
            best = (r, g, b)
    h, s, v = colorsys.rgb_to_hsv(*(c / 255.0 for c in best))
    r, g, b = colorsys.hsv_to_rgb(h, min(s * 1.2, 1.0), min(v * 1.25 + 0.15, 1.0))
    return int(r * 255), int(g * 255), int(b * 255)


def shaded_ring(rivets: int = 8) -> Image.Image:
    ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    d.ellipse((CENTER - RING_OUT - 3, CENTER - RING_OUT - 3, CENTER + RING_OUT + 3, CENTER + RING_OUT + 3), fill=OUTLINE + (255,))
    d.ellipse((CENTER - RING_OUT, CENTER - RING_OUT, CENTER + RING_OUT, CENTER + RING_OUT), fill=GOLD_MID + (255,))
    # volumetric light: bright top-left arc, dark bottom-right arc
    light = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ld = ImageDraw.Draw(light)
    ld.arc((CENTER - RING_OUT + 2, CENTER - RING_OUT + 2, CENTER + RING_OUT - 2, CENTER + RING_OUT - 2), 170, 350, fill=GOLD_LIGHT + (235,), width=7)
    ld.arc((CENTER - RING_OUT + 2, CENTER - RING_OUT + 2, CENTER + RING_OUT - 2, CENTER + RING_OUT - 2), 10, 150, fill=GOLD_DARK + (235,), width=7)
    ring.alpha_composite(light.filter(ImageFilter.GaussianBlur(2.2)))
    # punch out the center so the ring is an annulus over the item disc
    hole = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(hole).ellipse((CENTER - RING_IN, CENTER - RING_IN, CENTER + RING_IN, CENTER + RING_IN), fill=255)
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ring_data = Image.composite(transparent, ring, hole)
    ring.paste(ring_data, (0, 0))
    d = ImageDraw.Draw(ring)
    # inner edge of the ring
    d.ellipse((CENTER - RING_IN - 2, CENTER - RING_IN - 2, CENTER + RING_IN + 2, CENTER + RING_IN + 2), outline=OUTLINE + (255,), width=4)
    # rivets
    for i in range(rivets):
        ang = math.tau * i / rivets + math.pi / 8
        rx = CENTER + math.cos(ang) * (RING_OUT - 7)
        ry = CENTER + math.sin(ang) * (RING_OUT - 7)
        d.ellipse((rx - 4.5, ry - 4.5, rx + 4.5, ry + 4.5), fill=OUTLINE + (255,))
        d.ellipse((rx - 3.0, ry - 3.0, rx + 3.0, ry + 3.0), fill=GOLD_LIGHT + (255,))
        d.ellipse((rx - 2.0, ry - 2.0, rx + 1.0, ry + 1.0), fill=(255, 240, 190, 255))
    return ring


def restyle_icon(path: Path, ring: Image.Image) -> None:
    src = Image.open(path).convert("RGBA")
    disc = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    disc.paste(src, (0, 0), circle_mask(DISC_R))

    accent = accent_color(disc)
    graded = ImageEnhance.Color(disc).enhance(1.30)
    graded = ImageEnhance.Contrast(graded).enhance(1.12)
    graded = ImageEnhance.Brightness(graded).enhance(1.04)

    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # soft drop shadow so icons sit on the light parchment
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((CENTER - RING_OUT, CENTER - RING_OUT + 4, CENTER + RING_OUT, CENTER + RING_OUT + 8), fill=(14, 10, 20, 130))
    icon.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(4)))

    # accent halo behind the medallion
    halo = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse((CENTER - RING_OUT - 2, CENTER - RING_OUT - 2, CENTER + RING_OUT + 2, CENTER + RING_OUT + 2), fill=accent + (60,))
    icon.alpha_composite(halo.filter(ImageFilter.GaussianBlur(6)))

    # inner disc with grading and lighting
    icon.paste(graded, (0, 0), circle_mask(DISC_R))
    vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    vd.ellipse((CENTER - DISC_R, CENTER - DISC_R, CENTER + DISC_R, CENTER + DISC_R), outline=(16, 10, 26, 170), width=9)
    icon.alpha_composite(vignette.filter(ImageFilter.GaussianBlur(4)))
    toplight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    td = ImageDraw.Draw(toplight)
    td.ellipse((CENTER - DISC_R * 0.86, CENTER - DISC_R * 0.98, CENTER + DISC_R * 0.86, CENTER - DISC_R * 0.08), fill=(255, 245, 220, 46))
    icon.alpha_composite(toplight.filter(ImageFilter.GaussianBlur(5)))
    glowline = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glowline).ellipse((CENTER - DISC_R + 1, CENTER - DISC_R + 1, CENTER + DISC_R - 1, CENTER + DISC_R - 1), outline=accent + (110,), width=3)
    icon.alpha_composite(glowline.filter(ImageFilter.GaussianBlur(1.6)))

    icon.alpha_composite(ring)
    icon.save(path)


def timer_frame(alarm: bool) -> Image.Image:
    width, height = 300, 90
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    accent = (255, 70, 50) if alarm else (168, 120, 255)

    # outer glow (strong red when alarmed)
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle((10, 12, width - 10, height - 8), radius=26, fill=accent + (130 if alarm else 70,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(9)))

    # stone/wood plate with gold border
    d.rounded_rectangle((14, 14, width - 14, height - 10), radius=22, fill=OUTLINE + (255,))
    d.rounded_rectangle((17, 17, width - 17, height - 13), radius=20, fill=GOLD_MID + (255,))
    d.rounded_rectangle((22, 22, width - 22, height - 18), radius=16, fill=(52, 40, 66, 255))
    d.rounded_rectangle((26, 26, width - 26, height - 22), radius=13, fill=(33, 25, 46, 255))
    # gold border light/shade along the top and bottom edges
    d.line((44, 19, width - 44, 19), fill=GOLD_LIGHT, width=3)
    d.line((44, height - 15, width - 44, height - 15), fill=GOLD_DARK, width=3)

    # side gems + rune ticks
    for cx in (30, width - 30):
        d.ellipse((cx - 9, height / 2 - 11, cx + 9, height / 2 + 7), fill=OUTLINE + (255,))
        gem = accent if alarm else (150, 96, 235)
        d.ellipse((cx - 6, height / 2 - 8, cx + 6, height / 2 + 4), fill=gem + (255,))
        d.ellipse((cx - 4, height / 2 - 6, cx, height / 2 - 2), fill=(255, 230, 230, 230) if alarm else (225, 195, 255, 230))
    for i, tx in enumerate(range(58, width - 50, 24)):
        d.line((tx, 22, tx + 4, 26), fill=GOLD_LIGHT + (110,), width=2)

    # top crest notch
    d.polygon([(width / 2 - 16, 16), (width / 2 + 16, 16), (width / 2 + 9, 6), (width / 2 - 9, 6)], fill=OUTLINE + (255,))
    d.polygon([(width / 2 - 12, 16), (width / 2 + 12, 16), (width / 2 + 6, 9), (width / 2 - 6, 9)], fill=GOLD_MID + (255,))

    if alarm:
        inner = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        idr = ImageDraw.Draw(inner)
        idr.rounded_rectangle((26, 26, width - 26, height - 22), radius=13, outline=accent + (180,), width=4)
        img.alpha_composite(inner.filter(ImageFilter.GaussianBlur(2.5)))
    return img


def main() -> None:
    BACKUP.mkdir(parents=True, exist_ok=True)
    ring = shaded_ring()
    count = 0
    for path in sorted(ICON_DIR.glob("artifact_*.png")):
        backup_path = BACKUP / path.name
        if not backup_path.exists():
            shutil.copy(path, backup_path)
        shutil.copy(backup_path, path)  # always restyle from the original
        restyle_icon(path, ring)
        count += 1
    print(f"restyled {count} artifact icons")

    HUD_DIR.mkdir(parents=True, exist_ok=True)
    timer_frame(False).save(HUD_DIR / "timer_frame.png")
    timer_frame(True).save(HUD_DIR / "timer_frame_alarm.png")
    print("wrote timer_frame.png and timer_frame_alarm.png (300x90)")


if __name__ == "__main__":
    main()
