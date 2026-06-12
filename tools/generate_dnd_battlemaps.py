"""Redraw the 4 combat backgrounds as professional D&D tabletop battlemaps.

User feedback (2026-06-12): make them stylish with a D&D reference; flat circle
"pebbles" look amateur. So every biome is now built from proper top-down terrain
craft instead of scattered ellipses:

  stone_garden -> irregular flagstone courtyard: angular stone tiles, dark mortar
                  grooves, bevelled edges, moss in the seams.
  dry_road     -> packed cobblestone: offset rows of irregular cobbles, earth
                  gaps, faint wheel ruts, dry grass at the verges.
  meadow       -> painterly turf: layered grass brush-strokes, bare soil patches,
                  small flower clumps, a few flush angular field stones.
  marsh        -> wet peat: mottled mud, irregular water pools with rim sheen,
                  reed clumps, moss; flush dark stones.

Stays flat top-down (no tall objects / false perspective shadows), low contrast
so characters read on top. Native 2560x1440.

Run from the project root:  python3 tools/generate_dnd_battlemaps.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BG_DIR = ROOT / "assets" / "backgrounds"
W, H = 2560, 1440


def clamp(v: float) -> int:
    return max(0, min(255, int(v)))


def shift(c, d):
    return (clamp(c[0] + d), clamp(c[1] + d), clamp(c[2] + d))


def mix(a, b, t):
    return (clamp(a[0] + (b[0] - a[0]) * t), clamp(a[1] + (b[1] - a[1]) * t), clamp(a[2] + (b[2] - a[2]) * t))


def value_noise(cells, seed, blur):
    rng = random.Random(seed)
    small = Image.new("L", (cells, max(1, cells * H // W)))
    small.putdata([rng.randint(0, 255) for _ in range(small.width * small.height)])
    return small.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))


def mottled_base(base, dark, light, seed):
    img = Image.new("RGB", (W, H), base)
    px = img.load()
    lo = value_noise(10, seed, 55).load()
    hi = value_noise(46, seed + 1, 12).load()
    for y in range(H):
        for x in range(W):
            t = (lo[x, y] / 255.0 - 0.5) * 0.8 + (hi[x, y] / 255.0 - 0.5) * 0.4
            px[x, y] = mix(base, light if t >= 0 else dark, min(abs(t), 1.0))
    return img


def irregular(cx, cy, rx, ry, n, jitter, rng, squash=1.0):
    pts = []
    for i in range(n):
        a = math.tau * i / n + rng.uniform(-jitter, jitter) / n
        rr = rng.uniform(1.0 - jitter, 1.0 + jitter * 0.5)
        pts.append((cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr * squash))
    return pts


def overlay_grain(img, sigma, seed, strength):
    """Multiply-ish fine grain for a painted, non-flat surface."""
    rng_img = Image.effect_noise((W, H), sigma)
    rng_img = rng_img.filter(ImageFilter.GaussianBlur(0.5))
    grain = rng_img.point(lambda v: int((v - 128) * strength + 128))
    px = img.load()
    gp = grain.load()
    for y in range(0, H, 1):
        for x in range(0, W, 1):
            g = (gp[x, y] - 128) / 255.0
            r, gg, b = px[x, y]
            px[x, y] = (clamp(r + g * 46), clamp(gg + g * 46), clamp(b + g * 46))
    return img


def vignette(img, strength=0.18):
    v = Image.new("L", (W, H), 0)
    ImageDraw.Draw(v).ellipse((-W * 0.2, -H * 0.2, W * 1.2, H * 1.2), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(240))
    return Image.composite(img, Image.blend(img, Image.new("RGB", (W, H), (0, 0, 0)), strength), v)


# --------------------------------------------------------------------------- #
#  Stone tiles (flagstone / cobble): angular bevelled stones over mortar       #
# --------------------------------------------------------------------------- #
def stone_tiles(img, mortar, tones, cell_w, cell_h, gap, seed, n_sides=7, jitter=0.34,
                moss=None, row_offset=False):
    # mortar bed shows through the gaps
    base = mortar_layer(img, mortar, seed)
    d = ImageDraw.Draw(base, "RGBA")
    rng = random.Random(seed + 3)
    row = 0
    y = cell_h * 0.5
    while y < H + cell_h:
        x_shift = (cell_w * 0.5 if (row_offset and row % 2) else 0.0)
        x = cell_w * 0.5 + x_shift
        while x < W + cell_w:
            rx = cell_w * 0.5 - gap + rng.uniform(-4, 4)
            ry = cell_h * 0.5 - gap + rng.uniform(-4, 4)
            cx = x + rng.uniform(-gap, gap)
            cy = y + rng.uniform(-gap, gap)
            tone = shift(rng.choice(tones), rng.randint(-12, 12))
            pts = irregular(cx, cy, rx, ry, n_sides, jitter, rng)
            # contact AO under the stone
            d.polygon([(px, py + 3) for px, py in pts], fill=shift(mortar, -14) + (150,))
            d.polygon(pts, fill=tone + (255,))
            # bevel: bright top-left edge, dark bottom-right edge
            for i in range(len(pts)):
                a = pts[i]; b = pts[(i + 1) % len(pts)]
                up = (a[1] + b[1]) * 0.5 < cy
                col = shift(tone, 26) if up else shift(tone, -26)
                d.line([a, b], fill=col + (200,), width=2)
            # a couple of internal cracks / speckles
            if rng.random() < 0.5:
                ax, ay = cx + rng.uniform(-rx * 0.4, rx * 0.4), cy + rng.uniform(-ry * 0.4, ry * 0.4)
                d.line([(ax, ay), (ax + rng.uniform(-rx * 0.5, rx * 0.5), ay + rng.uniform(-ry * 0.5, ry * 0.5))],
                       fill=shift(tone, -22) + (120,), width=1)
            if moss and rng.random() < 0.30:
                mx, my = cx + rng.uniform(-rx, rx) * 0.6, cy + ry * 0.5
                d.ellipse((mx - 6, my - 3, mx + 6, my + 3), fill=rng.choice(moss) + (90,))
            x += cell_w
        y += cell_h
        row += 1
    return base.convert("RGB")


def mortar_layer(img, mortar, seed):
    m = Image.new("RGB", (W, H), mortar)
    m = overlay_grain(m, 22, seed, 0.5)
    out = img.convert("RGB")
    # blend the mortar bed with the mottled base so seams feel earthen
    return Image.blend(out, m, 0.65)


# --------------------------------------------------------------------------- #
#  Grass turf: layered short brush blades                                      #
# --------------------------------------------------------------------------- #
def grass_turf(img, colors, density, seed, blade=16, clump=True):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    n = int(W * H / density)
    for _ in range(n):
        bx, by = rng.randint(0, W), rng.randint(0, H)
        blades = rng.randint(2, 4) if clump else 1
        for _ in range(blades):
            x = bx + rng.randint(-6, 6)
            y = by + rng.randint(-6, 6)
            ang = math.radians(rng.uniform(-30, 30))
            ln = blade * rng.uniform(0.7, 1.2)
            cxp = x + math.sin(ang) * ln * 0.5 + rng.uniform(-2, 2)
            cyp = y - math.cos(ang) * ln * 0.5
            tipx = x + math.sin(ang) * ln
            tipy = y - math.cos(ang) * ln
            col = shift(rng.choice(colors), rng.randint(-14, 14))
            d.line([(x, y), (cxp, cyp)], fill=shift(col, -16) + (235,), width=2)
            d.line([(cxp, cyp), (tipx, tipy)], fill=col + (235,), width=1)
    out = img.convert("RGBA")
    out.alpha_composite(layer)
    return out.convert("RGB")


def soft_patches(img, colors, count, rmin, rmax, seed, alpha=(40, 80), squash=0.7):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    for _ in range(count):
        cx, cy = rng.randint(0, W), rng.randint(0, H)
        r = rng.randint(rmin, rmax)
        pts = irregular(cx, cy, r, r * squash, 9, 0.5, rng)
        d.polygon(pts, fill=rng.choice(colors) + (rng.randint(*alpha),))
    out = img.convert("RGBA")
    out.alpha_composite(layer.filter(ImageFilter.GaussianBlur(8)))
    return out.convert("RGB")


def flush_stones(img, tones, count, rmin, rmax, seed, moss=None):
    """A few flat angular field stones lying flush in the ground (not circles)."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    for _ in range(count):
        cx, cy = rng.randint(40, W - 40), rng.randint(40, H - 40)
        rx = rng.randint(rmin, rmax)
        ry = int(rx * rng.uniform(0.55, 0.8))
        tone = rng.choice(tones)
        pts = irregular(cx, cy, rx, ry, 7, 0.4, rng)
        d.polygon([(p[0], p[1] + 3) for p in pts], fill=(20, 18, 16, 120))
        d.polygon(pts, fill=tone + (255,))
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            up = (a[1] + b[1]) * 0.5 < cy
            d.line([a, b], fill=(shift(tone, 24) if up else shift(tone, -24)) + (200,), width=2)
        if moss and rng.random() < 0.5:
            d.ellipse((cx - rx * 0.4, cy, cx + rx * 0.2, cy + ry * 0.5), fill=rng.choice(moss) + (90,))
    out = img.convert("RGBA")
    out.alpha_composite(layer)
    return out.convert("RGB")


def water_pools(img, water, rim, sheen, count, seed):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    for _ in range(count):
        cx, cy = rng.randint(60, W - 60), rng.randint(60, H - 60)
        rx, ry = rng.randint(40, 110), rng.randint(26, 70)
        pts = irregular(cx, cy, rx, ry, 11, 0.45, rng)
        d.polygon(pts, fill=shift(rim, -10) + (160,))
        d.polygon([(p[0], p[1] + 4) for p in pts], fill=water + (210,))
        # sky sheen streak
        d.line([(cx - rx * 0.4, cy - ry * 0.2), (cx + rx * 0.3, cy - ry * 0.35)], fill=sheen + (110,), width=3)
    out = img.convert("RGBA")
    out.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.2)))
    return out.convert("RGB")


# --------------------------------------------------------------------------- #
def build_stone_garden():
    img = mottled_base((118, 119, 114), (92, 92, 92), (150, 150, 144), 11)
    img = stone_tiles(img, mortar=(74, 72, 66),
                      tones=[(150, 150, 143), (134, 133, 127), (162, 160, 152), (122, 124, 120)],
                      cell_w=150, cell_h=128, gap=9, seed=31, n_sides=7, jitter=0.30,
                      moss=[(96, 120, 64), (120, 140, 78)])
    img = soft_patches(img, [(96, 116, 70), (110, 110, 104)], 60, 50, 120, 41)
    img = vignette(img, 0.16)
    img.save(BG_DIR / "field_stone_garden.png")
    print("stone_garden -> flagstone courtyard")


def build_dry_road():
    img = mottled_base((150, 116, 76), (112, 84, 52), (178, 146, 102), 21)
    img = stone_tiles(img, mortar=(120, 92, 58),
                      tones=[(156, 138, 108), (138, 120, 92), (168, 150, 118), (128, 110, 84)],
                      cell_w=74, cell_h=60, gap=6, seed=53, n_sides=8, jitter=0.36,
                      row_offset=True)
    # faint wheel ruts
    ruts = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ruts)
    rng = random.Random(7)
    for cx in (W * 0.36, W * 0.64):
        pts = [(cx + math.sin(y / 180.0) * 24 + rng.uniform(-8, 8), y) for y in range(0, H, 24)]
        rd.line(pts, fill=(80, 58, 36, 70), width=22)
    img2 = img.convert("RGBA"); img2.alpha_composite(ruts.filter(ImageFilter.GaussianBlur(9)))
    img = img2.convert("RGB")
    img = grass_turf(img, [(150, 140, 78), (132, 120, 64)], density=5200, seed=9, blade=12)
    img = vignette(img, 0.16)
    img.save(BG_DIR / "field_dry_road.png")
    print("dry_road -> cobblestone path")


def build_meadow():
    img = mottled_base((92, 120, 56), (62, 86, 38), (128, 154, 80), 17)
    img = soft_patches(img, [(120, 96, 58), (104, 84, 50)], 40, 70, 160, 23, alpha=(50, 95))  # bare soil
    img = soft_patches(img, [(80, 110, 46), (120, 150, 72)], 70, 60, 150, 24)
    img = grass_turf(img, [(96, 134, 52), (118, 154, 66), (80, 116, 46), (140, 168, 84)],
                     density=120, seed=33, blade=17)
    img = flush_stones(img, [(132, 130, 120), (112, 110, 100), (146, 142, 130)], 26, 14, 30, 71,
                       moss=[(96, 130, 56)])
    # small flower clumps
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer); rng = random.Random(80)
    for _ in range(240):
        cx, cy = rng.randint(0, W), rng.randint(0, H)
        col = rng.choice([(232, 224, 150), (228, 232, 240), (210, 150, 170), (180, 160, 230)])
        for _ in range(rng.randint(2, 4)):
            d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=col + (210,))
            cx += rng.randint(-6, 6); cy += rng.randint(-6, 6)
    img2 = img.convert("RGBA"); img2.alpha_composite(layer); img = img2.convert("RGB")
    img = vignette(img, 0.16)
    img.save(BG_DIR / "field_meadow.png")
    print("meadow -> painterly turf")


def build_marsh():
    img = mottled_base((64, 80, 58), (40, 54, 42), (92, 106, 76), 27)
    img = soft_patches(img, [(48, 60, 44), (78, 88, 58), (54, 66, 50)], 120, 60, 170, 28, alpha=(50, 100))
    img = water_pools(img, water=(48, 64, 66), rim=(74, 84, 60), sheen=(150, 170, 170), count=26, seed=29)
    img = grass_turf(img, [(72, 100, 52), (92, 116, 60), (58, 86, 48)], density=180, seed=35, blade=22)
    img = flush_stones(img, [(96, 100, 92), (80, 86, 78)], 20, 12, 26, 73, moss=[(70, 100, 52)])
    img = vignette(img, 0.2)
    img.save(BG_DIR / "field_marsh.png")
    print("marsh -> wet peat")


def main():
    build_stone_garden()
    build_dry_road()
    build_meadow()
    build_marsh()


if __name__ == "__main__":
    main()
