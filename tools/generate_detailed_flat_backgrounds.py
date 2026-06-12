# SUPERSEDED 2026-06-12 by tools/generate_dnd_battlemaps.py (user rejected the
# flat circle-pebble look as amateurish). Kept for reference only.
"""Redraw the 4 combat backgrounds as lively flat top-down ground.

User feedback (2026-06-12): the current flat backgrounds are dull (almost
featureless colour fields). Make them pretty with SMALL pebbles and SMALL grass
blades so the hero never looks like he is walking over big rocks — small ground
detail only, evenly spread, low contrast so characters/enemies/projectiles read
on top. Native 2560x1440, no tall objects, no false perspective shadows.

Run from the project root:  python3 tools/generate_detailed_flat_backgrounds.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BG_DIR = ROOT / "assets" / "backgrounds"
W, H = 2560, 1440


def clamp(v):
    return max(0, min(255, int(v)))


def shift(c, d):
    return (clamp(c[0] + d), clamp(c[1] + d), clamp(c[2] + d))


def mix(a, b, t):
    return (clamp(a[0] + (b[0] - a[0]) * t), clamp(a[1] + (b[1] - a[1]) * t), clamp(a[2] + (b[2] - a[2]) * t))


def value_noise(w, h, cells, seed, blur):
    """Low-frequency mottling: small random image upscaled + blurred."""
    rng = random.Random(seed)
    small = Image.new("L", (cells, max(1, cells * h // w)))
    small.putdata([rng.randint(0, 255) for _ in range(small.width * small.height)])
    return small.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))


def base_ground(palette, seed):
    """Mottled biome base so it never reads as a flat colour field."""
    base = palette["base"]
    img = Image.new("RGB", (W, H), base)
    px = img.load()
    # two octaves of soft value mottling, tinted between dark/light biome tones
    lo = value_noise(W, H, 9, seed, 60).load()
    hi = value_noise(W, H, 40, seed + 1, 14).load()
    dark = palette["dark"]
    light = palette["light"]
    for y in range(H):
        for x in range(W):
            t = (lo[x, y] / 255.0 - 0.5) * 0.85 + (hi[x, y] / 255.0 - 0.5) * 0.45
            if t >= 0:
                px[x, y] = mix(base, light, min(t, 1.0))
            else:
                px[x, y] = mix(base, dark, min(-t, 1.0))
    return img


def add_patches(img, palette, seed):
    """Soft moss/soil patches — mid-scale colour variation, still flat."""
    rng = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(palette["patches"]):
        cx, cy = rng.randint(0, W), rng.randint(0, H)
        r = rng.randint(60, 150)
        col = rng.choice(palette["patch_colors"])
        d.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), fill=col + (rng.randint(26, 54),))
    img.alpha_composite(Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(22))).convert("RGBA")) if False else None
    base = img.convert("RGBA")
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(20)))
    return base.convert("RGB")


def pebble(d, x, y, r, col, rng):
    """Tiny rounded stone: body + bottom-right shadow + top-left highlight."""
    d.ellipse((x - r, y - r * 0.82 + 1, x + r, y + r * 0.82 + 2), fill=shift(col, -20) + (70,))  # contact shadow
    d.ellipse((x - r, y - r * 0.82, x + r, y + r * 0.82), fill=col)
    d.ellipse((x - r + 1, y - r * 0.82 + 1, x + r * 0.2, y), fill=shift(col, 12))  # top-left light
    d.point((x - r // 3, y - r // 3), fill=shift(col, 22))


def grass_tuft(d, x, y, col, rng, size):
    """A few short blades fanning up — small."""
    blades = rng.randint(3, 5)
    for _ in range(blades):
        ang = math.radians(rng.uniform(-38, 38))
        ln = size * rng.uniform(0.7, 1.15)
        tipx = x + math.sin(ang) * ln
        tipy = y - math.cos(ang) * ln
        midx = (x + tipx) / 2 + rng.uniform(-1.5, 1.5)
        midy = (y + tipy) / 2
        shade = shift(col, rng.randint(-18, 18))
        d.line((x, y, midx, midy), fill=shift(col, -14), width=2)
        d.line((midx, midy, tipx, tipy), fill=shade, width=1)


def scatter_detail(img, palette, seed):
    """Even small-detail layer: pebbles + grass + cracks + specks across the
    whole arena on a jittered grid, so movement reads everywhere and nothing
    clumps into a big rock."""
    rng = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = palette["grid"]
    for gy in range(0, H, step):
        for gx in range(0, W, step):
            roll = rng.random()
            x = gx + rng.randint(2, step - 2)
            y = gy + rng.randint(2, step - 2)
            if roll < palette["pebble_p"]:
                r = rng.randint(*palette["pebble_r"])
                pebble(d, x, y, r, rng.choice(palette["pebble_colors"]), rng)
            elif roll < palette["pebble_p"] + palette["grass_p"]:
                grass_tuft(d, x, y, rng.choice(palette["grass_colors"]), rng, palette["grass_size"])
            elif roll < palette["pebble_p"] + palette["grass_p"] + palette["speck_p"]:
                col = rng.choice(palette["speck_colors"])
                rr = rng.randint(1, 3)
                d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=col + (rng.randint(70, 140),))
    # hairline cracks / dry wisps
    for _ in range(palette["cracks"]):
        x, y = rng.randint(0, W), rng.randint(0, H)
        col = palette["crack_color"]
        pts = [(x, y)]
        for _ in range(rng.randint(4, 8)):
            x += rng.randint(-26, 26)
            y += rng.randint(-26, 26)
            pts.append((x, y))
        d.line(pts, fill=col + (rng.randint(40, 80),), width=1)
    # push the whole detail layer slightly into the ground for low contrast
    r_, g_, b_, a_ = layer.split()
    layer.putalpha(a_.point(lambda v: int(v * 0.82)))
    img2 = img.convert("RGBA")
    img2.alpha_composite(layer)
    return img2.convert("RGB")


def vignette(img):
    v = Image.new("L", (W, H), 0)
    ImageDraw.Draw(v).ellipse((-W * 0.18, -H * 0.18, W * 1.18, H * 1.18), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(220))
    dark = Image.new("RGB", (W, H), (0, 0, 0))
    return Image.composite(img, Image.blend(img, dark, 0.16), v)


PALETTES = {
    "field_meadow": {
        "base": (96, 122, 60), "dark": (60, 84, 38), "light": (132, 158, 84),
        "patches": 90, "patch_colors": [(78, 104, 46), (120, 146, 74), (84, 110, 52)],
        "grid": 30, "pebble_p": 0.10, "grass_p": 0.46, "speck_p": 0.14,
        "pebble_r": (3, 7), "pebble_colors": [(124, 116, 100), (110, 100, 84), (132, 122, 104)],
        "grass_colors": [(96, 132, 54), (118, 152, 66), (78, 112, 44), (140, 164, 80)],
        "grass_size": 16, "speck_colors": [(206, 196, 96), (228, 220, 150), (180, 90, 96)],
        "cracks": 40, "crack_color": (60, 72, 38),
    },
    "field_dry_road": {
        "base": (150, 116, 76), "dark": (112, 84, 52), "light": (180, 148, 104),
        "patches": 80, "patch_colors": [(132, 100, 62), (168, 138, 96), (120, 92, 58)],
        "grid": 28, "pebble_p": 0.20, "grass_p": 0.12, "speck_p": 0.18,
        "pebble_r": (3, 7), "pebble_colors": [(140, 122, 96), (120, 104, 82), (132, 116, 92), (108, 92, 70)],
        "grass_colors": [(150, 140, 78), (132, 120, 64), (120, 132, 70)],
        "grass_size": 13, "speck_colors": [(180, 156, 112), (120, 96, 64), (200, 178, 130)],
        "cracks": 120, "crack_color": (96, 70, 42),
    },
    "field_stone_garden": {
        "base": (120, 122, 118), "dark": (92, 94, 92), "light": (152, 152, 146),
        "patches": 80, "patch_colors": [(104, 116, 90), (138, 138, 132), (96, 110, 84)],
        "grid": 26, "pebble_p": 0.24, "grass_p": 0.16, "speck_p": 0.14,
        "pebble_r": (4, 9), "pebble_colors": [(150, 150, 144), (120, 120, 116), (168, 166, 158), (104, 106, 102)],
        "grass_colors": [(104, 126, 70), (120, 140, 78), (92, 116, 64)],
        "grass_size": 13, "speck_colors": [(150, 160, 110), (170, 168, 158), (110, 130, 86)],
        "cracks": 150, "crack_color": (78, 80, 78),
    },
    "field_marsh": {
        "base": (66, 86, 64), "dark": (40, 56, 42), "light": (96, 114, 84),
        "patches": 100, "patch_colors": [(52, 70, 50), (84, 96, 66), (46, 62, 52), (74, 88, 58)],
        "grid": 30, "pebble_p": 0.16, "grass_p": 0.40, "speck_p": 0.16,
        "pebble_r": (4, 8), "pebble_colors": [(96, 100, 92), (78, 84, 76), (110, 112, 102)],
        "grass_colors": [(72, 100, 56), (90, 116, 62), (58, 86, 50), (104, 124, 70)],
        "grass_size": 18, "speck_colors": [(120, 140, 80), (150, 160, 96), (84, 70, 56)],
        "cracks": 50, "crack_color": (44, 56, 44),
    },
}


def build(name, palette):
    seed = sum(name.encode())
    img = base_ground(palette, seed)
    img = add_patches(img, palette, seed + 5)
    img = scatter_detail(img, palette, seed + 9)
    img = vignette(img)
    img.save(BG_DIR / f"{name}.png")
    print(f"{name}: redrawn 2560x1440 detailed flat ground")


def main():
    for name, palette in PALETTES.items():
        build(name, palette)


if __name__ == "__main__":
    main()
