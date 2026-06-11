"""Generate FantasyDisk artifact, shop item, shop-frame and cursor assets.

Run from the project root:

    python3 tools/generate_artifact_shop_cursor_assets.py

The output is deterministic PNG art with transparent backgrounds:
- assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png
- assets/sprites/ui/icons/shop/shop_<shop_item_id>.png
- assets/sprites/ui/shop/*.png
- assets/sprites/ui/cursor/*.png
"""
from __future__ import annotations

import math
import random
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"
SHOP_ICON_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "shop"
SHOP_UI_DIR = ROOT / "assets" / "sprites" / "ui" / "shop"
CURSOR_DIR = ROOT / "assets" / "sprites" / "ui" / "cursor"
PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_shop_cursor_preview.png"

S = 4
SIZE = 128
OUTLINE = (22, 18, 27, 255)
INK = (40, 31, 45, 255)
GOLD = (232, 181, 66, 255)
GOLD_DARK = (126, 73, 28, 255)
PARCHMENT = (231, 204, 143, 255)
STEEL = (126, 139, 155, 255)
STEEL_LIGHT = (224, 226, 222, 255)
VIOLET = (137, 79, 238, 255)
CYAN = (70, 220, 235, 255)
RED = (219, 63, 47, 255)
GREEN = (92, 207, 98, 255)
ORANGE = (238, 119, 40, 255)
BLUE = (74, 144, 232, 255)


def sc(v: float) -> int:
    return int(round(v * S))


def rgba(c: tuple[int, int, int, int], a: int | None = None) -> tuple[int, int, int, int]:
    return (c[0], c[1], c[2], c[3] if a is None else a)


def canvas(w: int = SIZE, h: int = SIZE) -> Image.Image:
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def downsample(img: Image.Image) -> Image.Image:
    return img.resize((img.width // S, img.height // S), Image.Resampling.LANCZOS)


def draw_soft_shadow(img: Image.Image, bbox: tuple[int, int, int, int], blur: float = 4.0) -> None:
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(shadow)
    x0, y0, x1, y1 = [sc(v) for v in bbox]
    d.ellipse((x0, y0 + sc(4), x1, y1 + sc(4)), fill=(0, 0, 0, 95))
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(blur)))
    img.alpha_composite(shadow)


def polygon(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill, outline=OUTLINE, width: int = 4) -> None:
    scaled = [(sc(x), sc(y)) for x, y in pts]
    if outline and width > 0:
        draw.line(scaled + [scaled[0]], fill=outline, width=sc(width), joint="curve")
    draw.polygon(scaled, fill=fill)


def line(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill, width: int = 5) -> None:
    draw.line([(sc(x), sc(y)) for x, y in pts], fill=fill, width=sc(width), joint="curve")


def ellipse(draw: ImageDraw.ImageDraw, bbox: tuple[float, float, float, float], fill, outline=OUTLINE, width: int = 4) -> None:
    box = tuple(sc(v) for v in bbox)
    if outline and width > 0:
        draw.ellipse(box, fill=outline)
        inset = sc(width)
        box = (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset)
    draw.ellipse(box, fill=fill)


def rounded(draw: ImageDraw.ImageDraw, bbox: tuple[float, float, float, float], r: float, fill, outline=OUTLINE, width: int = 4) -> None:
    box = tuple(sc(v) for v in bbox)
    if outline and width > 0:
        draw.rounded_rectangle(box, radius=sc(r), fill=outline)
        inset = sc(width)
        box = (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset)
    draw.rounded_rectangle(box, radius=sc(r), fill=fill)


def arc(draw: ImageDraw.ImageDraw, bbox: tuple[float, float, float, float], start: float, end: float, fill, width: int = 5) -> None:
    draw.arc(tuple(sc(v) for v in bbox), start=start, end=end, fill=fill, width=sc(width))


def highlight(draw: ImageDraw.ImageDraw, bbox: tuple[float, float, float, float], alpha: int = 115) -> None:
    draw.ellipse(tuple(sc(v) for v in bbox), fill=(255, 255, 255, alpha))


def add_glow(img: Image.Image, color: tuple[int, int, int, int], bbox: tuple[float, float, float, float], blur: float = 7.0) -> None:
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(tuple(sc(v) for v in bbox), fill=rgba(color, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(blur)))
    img.alpha_composite(glow)


def mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def lighten(c: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    return (min(255, c[0] + amount), min(255, c[1] + amount), min(255, c[2] + amount), c[3])


def darken(c: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    return (max(0, c[0] - amount), max(0, c[1] - amount), max(0, c[2] - amount), c[3])


def radial_disc(
    size: tuple[int, int],
    center: tuple[float, float],
    radius: float,
    inner: tuple[int, int, int, int],
    outer: tuple[int, int, int, int],
) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    px = img.load()
    cx, cy = center
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - cx, y - cy) / radius)
            px[x, y] = mix(inner, outer, t ** 0.85)
    return img


def add_painted_grain(img: Image.Image, seed: int, alpha: int = 18) -> None:
    rng = random.Random(seed)
    grain = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grain)
    for _ in range(320):
        x = rng.randrange(img.width)
        y = rng.randrange(img.height)
        a = rng.randrange(5, alpha)
        color = (255, 238, 176, a) if rng.random() > 0.45 else (0, 0, 0, a)
        gd.point((x, y), fill=color)
    mask = img.split()[3].point(lambda v: min(v, 135))
    grain.putalpha(Image.composite(grain.split()[3], Image.new("L", img.size, 0), mask))
    img.alpha_composite(grain)


def base_icon(accent: tuple[int, int, int, int] = GOLD) -> Image.Image:
    img = canvas()
    add_glow(img, accent, (13, 13, 115, 115), 9.0)
    draw_soft_shadow(img, (14, 15, 114, 116), 8.0)
    d = ImageDraw.Draw(img)
    outer = [(64, 6), (82, 15), (103, 14), (114, 34), (122, 64), (114, 94), (103, 114), (82, 113), (64, 122), (46, 113), (25, 114), (14, 94), (6, 64), (14, 34), (25, 14), (46, 15)]
    polygon(d, outer, (8, 8, 15, 252), OUTLINE, 4)
    inner = [(64, 12), (79, 21), (97, 21), (107, 38), (114, 64), (107, 90), (97, 107), (79, 107), (64, 116), (49, 107), (31, 107), (21, 90), (14, 64), (21, 38), (31, 21), (49, 21)]
    polygon(d, inner, darken(GOLD_DARK, 15), OUTLINE, 2)
    ellipse(d, (18, 18, 110, 110), darken(GOLD_DARK, 24), GOLD, 6)
    ellipse(d, (25, 25, 103, 103), (13, 12, 20, 242), darken(accent, 12), 4)

    disc = radial_disc(
        img.size,
        (sc(52), sc(42)),
        sc(72),
        mix(lighten(accent, 26), (72, 62, 80, 255), 0.35),
        (18, 13, 24, 235),
    )
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse((sc(29), sc(29), sc(99), sc(99)), fill=235)
    img.alpha_composite(Image.composite(disc, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))

    # Faceted fantasy-metal rim and small rune/gem anchors.
    d = ImageDraw.Draw(img)
    for angle in [0, 45, 90, 135, 180, 225, 270, 315]:
        rad = math.radians(angle)
        x = 64 + math.cos(rad) * 46
        y = 64 + math.sin(rad) * 46
        ellipse(d, (x - 4, y - 4, x + 4, y + 4), rgba(lighten(accent, 18), 230), OUTLINE, 2)
    for angle in [22, 68, 112, 158, 202, 248, 292, 338]:
        rad = math.radians(angle)
        x = 64 + math.cos(rad) * 39
        y = 64 + math.sin(rad) * 39
        line(d, [(x - math.sin(rad) * 3, y + math.cos(rad) * 3), (x + math.sin(rad) * 3, y - math.cos(rad) * 3)], rgba((255, 229, 134, 255), 135), 2)
    arc(d, (24, 23, 104, 103), 205, 330, rgba((255, 244, 184, 255), 150), 4)
    arc(d, (28, 29, 100, 101), 34, 145, rgba((0, 0, 0, 255), 70), 5)
    return img


def polish_icon(img: Image.Image, accent: tuple[int, int, int, int], seed: int) -> Image.Image:
    add_painted_grain(img, seed, 19)
    d = ImageDraw.Draw(img)
    # Subtle top-left painted shine, clipped by existing alpha.
    shine = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    sd.ellipse((sc(31), sc(20), sc(78), sc(55)), fill=(255, 255, 255, 38))
    sd.arc((sc(26), sc(24), sc(103), sc(101)), 205, 318, fill=(255, 239, 170, 92), width=sc(3))
    shine.putalpha(Image.composite(shine.split()[3], Image.new("L", img.size, 0), img.split()[3]))
    img.alpha_composite(shine)
    # Tiny magical flecks outside the item but inside the medallion.
    rng = random.Random(seed)
    for _ in range(6):
        ang = rng.uniform(0, math.tau)
        rad = rng.uniform(31, 48)
        x = 64 + math.cos(ang) * rad
        y = 64 + math.sin(ang) * rad
        line(d, [(x - 2, y), (x + 2, y)], rgba(lighten(accent, 45), 160), 2)
        line(d, [(x, y - 2), (x, y + 2)], rgba(lighten(accent, 45), 160), 2)
    return img


def finish(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    downsample(img).save(path)


def draw_boots(img: Image.Image, color=GOLD, fast: bool = False) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (38, 39, 61, 83), 8, color, OUTLINE, 4)
    rounded(d, (64, 45, 87, 89), 8, color, OUTLINE, 4)
    rounded(d, (31, 76, 64, 96), 8, (80, 50, 35, 255), OUTLINE, 4)
    rounded(d, (59, 82, 95, 102), 8, (80, 50, 35, 255), OUTLINE, 4)
    line(d, [(39, 58), (59, 61)], (255, 225, 130, 200), 3)
    line(d, [(65, 65), (86, 68)], (255, 225, 130, 200), 3)
    if fast:
        line(d, [(22, 48), (35, 43), (29, 55)], CYAN, 4)
        line(d, [(91, 54), (106, 50), (99, 62)], CYAN, 4)


def draw_orb(img: Image.Image, color=BLUE, glass: bool = True) -> None:
    d = ImageDraw.Draw(img)
    add_glow(img, color, (35, 29, 94, 88), 8)
    ellipse(d, (35, 29, 94, 88), color, OUTLINE, 5)
    ellipse(d, (44, 38, 85, 79), tuple(max(0, min(255, c + 18)) for c in color[:3]) + (255,), None, 0)
    if glass:
        highlight(d, (47, 39, 64, 54), 175)
        arc(d, (45, 40, 84, 78), 25, 145, (255, 255, 255, 150), 4)
    rounded(d, (46, 88, 82, 100), 8, GOLD_DARK, OUTLINE, 4)


def draw_lens(img: Image.Image, color=CYAN) -> None:
    d = ImageDraw.Draw(img)
    ellipse(d, (33, 25, 84, 76), (38, 63, 80, 255), OUTLINE, 5)
    ellipse(d, (40, 32, 77, 69), rgba(color, 130), None, 0)
    highlight(d, (46, 35, 58, 47), 160)
    line(d, [(76, 70), (98, 96)], GOLD_DARK, 11)
    line(d, [(76, 70), (98, 96)], GOLD, 5)


def draw_book(img: Image.Image, color=PARCHMENT, dark: bool = False, ash: bool = False) -> None:
    d = ImageDraw.Draw(img)
    cover = (65, 43, 91, 255) if dark else color
    rounded(d, (29, 28, 93, 98), 7, cover, OUTLINE, 5)
    line(d, [(64, 31), (64, 96)], OUTLINE, 3)
    rounded(d, (35, 36, 59, 87), 3, (222, 194, 134, 255) if not dark else (86, 54, 112, 255), None, 0)
    rounded(d, (69, 36, 87, 87), 3, (222, 194, 134, 255) if not dark else (86, 54, 112, 255), None, 0)
    line(d, [(40, 47), (55, 45)], (92, 61, 46, 170) if not dark else (206, 158, 255, 190), 2)
    line(d, [(71, 55), (84, 54)], (92, 61, 46, 170) if not dark else (206, 158, 255, 190), 2)
    if ash:
        polygon(d, [(45, 23), (62, 33), (54, 46), (37, 38)], (70, 67, 65, 255), OUTLINE, 3)
        line(d, [(50, 29), (48, 39), (57, 34)], ORANGE, 3)


def draw_heart(img: Image.Image, color=RED, stone: bool = False, fragile: bool = False) -> None:
    d = ImageDraw.Draw(img)
    fill = (118, 117, 112, 255) if stone else color
    pts = [(64, 101), (27, 65), (30, 39), (48, 28), (64, 43), (80, 28), (98, 39), (101, 65)]
    polygon(d, pts, fill, OUTLINE, 5)
    highlight(d, (45, 39, 60, 54), 115)
    if stone:
        line(d, [(50, 43), (60, 58), (55, 73), (70, 87)], (70, 69, 68, 210), 3)
        line(d, [(72, 41), (66, 55), (75, 70)], (173, 168, 156, 160), 2)
    if fragile:
        line(d, [(64, 45), (58, 58), (67, 70), (60, 86)], (255, 219, 204, 230), 4)


def draw_seed_banner(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    line(d, [(45, 95), (47, 25)], GOLD_DARK, 7)
    polygon(d, [(49, 28), (91, 36), (74, 52), (91, 69), (49, 62)], (143, 42, 70, 255), OUTLINE, 4)
    ellipse(d, (36, 82, 58, 104), GREEN, OUTLINE, 4)
    line(d, [(47, 92), (35, 108)], GREEN, 4)
    line(d, [(48, 91), (62, 108)], GREEN, 4)


def draw_whetstone(img: Image.Image, red: bool = True) -> None:
    d = ImageDraw.Draw(img)
    polygon(d, [(31, 77), (79, 27), (98, 45), (48, 96)], RED if red else STEEL, OUTLINE, 5)
    line(d, [(42, 77), (83, 36)], (255, 199, 98, 210), 4)
    line(d, [(78, 80), (100, 91)], (255, 230, 120, 230), 3)
    line(d, [(76, 88), (92, 110)], (255, 134, 61, 220), 3)


def draw_compass(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    ellipse(d, (27, 27, 101, 101), (31, 42, 59, 255), GOLD, 5)
    polygon(d, [(64, 31), (72, 58), (98, 64), (72, 70), (64, 97), (56, 70), (30, 64), (56, 58)], (231, 217, 168, 255), OUTLINE, 3)
    polygon(d, [(64, 37), (70, 63), (64, 91), (58, 63)], VIOLET, None, 0)
    ellipse(d, (58, 58, 70, 70), GOLD, OUTLINE, 2)


def draw_root(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    line(d, [(64, 30), (62, 60), (51, 89), (34, 108)], (102, 60, 34, 255), 10)
    line(d, [(64, 60), (82, 86), (96, 108)], (102, 60, 34, 255), 9)
    line(d, [(64, 58), (46, 76), (25, 84)], (102, 60, 34, 255), 7)
    line(d, [(64, 54), (88, 65), (106, 72)], (102, 60, 34, 255), 7)
    ellipse(d, (46, 20, 82, 53), GREEN, OUTLINE, 4)
    ellipse(d, (57, 31, 73, 47), (159, 242, 114, 255), None, 0)


def draw_coin(img: Image.Image, greedy: bool = False, silver: bool = False) -> None:
    d = ImageDraw.Draw(img)
    color = STEEL_LIGHT if silver else GOLD
    dark = STEEL if silver else GOLD_DARK
    ellipse(d, (30, 27, 98, 95), dark, OUTLINE, 5)
    ellipse(d, (38, 34, 90, 86), color, dark, 3)
    if greedy:
        polygon(d, [(54, 50), (65, 38), (76, 50), (72, 69), (58, 69)], (108, 52, 120, 255), OUTLINE, 3)
        ellipse(d, (43, 79, 85, 98), (116, 57, 40, 255), OUTLINE, 4)
    else:
        polygon(d, [(64, 43), (70, 57), (85, 58), (73, 68), (77, 82), (64, 74), (51, 82), (55, 68), (43, 58), (58, 57)], (255, 242, 160, 210), None, 0)


def draw_string(img: Image.Image, copper: bool = False, broken: bool = False) -> None:
    d = ImageDraw.Draw(img)
    color = (203, 102, 52, 255) if copper else CYAN
    for off in [-8, 0, 8]:
        arc(d, (24, 30 + off, 104, 102 + off), 210, 45, OUTLINE, 7)
        arc(d, (24, 30 + off, 104, 102 + off), 210, 45, color, 3)
    if broken:
        line(d, [(55, 58), (71, 44)], RED, 5)
        line(d, [(72, 80), (87, 68)], RED, 5)


def draw_totem(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (42, 23, 86, 101), 10, (101, 69, 48, 255), OUTLINE, 5)
    ellipse(d, (51, 36, 62, 47), ORANGE, OUTLINE, 2)
    ellipse(d, (66, 36, 77, 47), ORANGE, OUTLINE, 2)
    polygon(d, [(50, 63), (64, 54), (78, 63), (64, 73)], (70, 44, 34, 255), OUTLINE, 3)
    line(d, [(45, 82), (83, 82)], GOLD, 4)


def draw_gloves(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (29, 51, 59, 88), 10, (113, 70, 49, 255), OUTLINE, 5)
    rounded(d, (69, 48, 99, 85), 10, (113, 70, 49, 255), OUTLINE, 5)
    for x in [32, 41, 50, 72, 81, 90]:
        line(d, [(x, 49), (x + 3, 36)], (113, 70, 49, 255), 7)
    line(d, [(42, 73), (88, 70)], STEEL_LIGHT, 4)


def draw_sigil(img: Image.Image, color=VIOLET, blood: bool = False) -> None:
    d = ImageDraw.Draw(img)
    add_glow(img, color, (31, 31, 97, 97), 6)
    ellipse(d, (32, 32, 96, 96), (33, 23, 43, 255), color, 5)
    pts = [(64, 40), (74, 60), (95, 64), (74, 68), (64, 88), (54, 68), (33, 64), (54, 60)]
    polygon(d, pts, RED if blood else (218, 196, 100, 255), None, 0)
    ellipse(d, (57, 57, 71, 71), color, OUTLINE, 2)
    if blood:
        line(d, [(78, 77), (82, 94)], RED, 5)


def draw_ink(img: Image.Image, color=VIOLET, candle: bool = False) -> None:
    d = ImageDraw.Draw(img)
    if candle:
        rounded(d, (48, 45, 80, 98), 7, (31, 23, 31, 255), OUTLINE, 4)
        line(d, [(64, 45), (64, 35)], OUTLINE, 3)
        ellipse(d, (55, 22, 73, 43), ORANGE, OUTLINE, 3)
        ellipse(d, (60, 27, 68, 38), (255, 226, 111, 255), None, 0)
    else:
        pts = [(64, 24), (87, 59), (78, 89), (64, 100), (50, 89), (41, 59)]
        polygon(d, pts, color, OUTLINE, 5)
        highlight(d, (55, 47, 68, 62), 130)


def draw_bell(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    ellipse(d, (55, 20, 73, 38), GOLD, OUTLINE, 3)
    polygon(d, [(44, 43), (84, 43), (94, 87), (34, 87)], GOLD, OUTLINE, 5)
    arc(d, (38, 67, 90, 101), 0, 180, OUTLINE, 5)
    ellipse(d, (56, 82, 72, 100), (104, 62, 33, 255), OUTLINE, 3)
    line(d, [(34, 54), (23, 44)], VIOLET, 4)
    line(d, [(94, 54), (105, 44)], VIOLET, 4)


def draw_pick(img: Image.Image, color=VIOLET, echo: bool = False) -> None:
    d = ImageDraw.Draw(img)
    pts = [(64, 25), (95, 52), (78, 100), (50, 100), (33, 52)]
    polygon(d, pts, color, OUTLINE, 5)
    highlight(d, (51, 42, 64, 56), 125)
    if echo:
        arc(d, (30, 31, 99, 100), 315, 70, CYAN, 4)
        arc(d, (22, 24, 107, 108), 315, 70, CYAN, 3)


def draw_amulet(img: Image.Image, color=GOLD, sturdy: bool = False) -> None:
    d = ImageDraw.Draw(img)
    ellipse(d, (53, 18, 75, 40), STEEL if sturdy else GOLD, OUTLINE, 4)
    line(d, [(42, 31), (64, 58), (86, 31)], GOLD_DARK, 5)
    ellipse(d, (37, 48, 91, 102), color, OUTLINE, 5)
    ellipse(d, (51, 61, 77, 87), VIOLET if sturdy else RED, OUTLINE, 3)
    if sturdy:
        line(d, [(42, 73), (86, 73)], STEEL_LIGHT, 4)


def draw_buckle(img: Image.Image, magnet: bool = False) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (22, 53, 106, 80), 8, (95, 56, 38, 255), OUTLINE, 4)
    rounded(d, (44, 43, 84, 91), 10, GOLD, OUTLINE, 5)
    rounded(d, (55, 55, 73, 79), 5, (37, 27, 34, 255), OUTLINE, 2)
    if magnet:
        arc(d, (39, 25, 89, 75), 35, 145, CYAN, 7)
        line(d, [(45, 42), (53, 34)], CYAN, 5)
        line(d, [(83, 42), (75, 34)], CYAN, 5)


def draw_shield(img: Image.Image, cracked: bool = False) -> None:
    d = ImageDraw.Draw(img)
    pts = [(64, 22), (96, 36), (89, 82), (64, 105), (39, 82), (32, 36)]
    polygon(d, pts, STEEL, OUTLINE, 5)
    polygon(d, [(64, 31), (84, 42), (78, 76), (64, 91), (50, 76), (44, 42)], (73, 82, 96, 255), None, 0)
    if cracked:
        line(d, [(65, 33), (58, 51), (68, 62), (59, 84)], (232, 220, 189, 230), 4)


def draw_blade(img: Image.Image, jagged: bool = False, glass: bool = False) -> None:
    d = ImageDraw.Draw(img)
    fill = (173, 234, 245, 210) if glass else STEEL_LIGHT
    pts = [(77, 20), (91, 34), (52, 88), (38, 94), (43, 80)]
    if jagged:
        pts = [(78, 19), (92, 34), (75, 47), (81, 55), (63, 65), (67, 73), (51, 88), (38, 94), (43, 80)]
    polygon(d, pts, fill, OUTLINE, 5)
    line(d, [(44, 89), (31, 102)], GOLD_DARK, 8)
    line(d, [(44, 89), (31, 102)], GOLD, 4)
    if glass:
        highlight(d, (60, 39, 73, 55), 155)


def draw_grip(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    line(d, [(43, 91), (85, 49)], (77, 44, 31, 255), 14)
    line(d, [(43, 91), (85, 49)], GOLD_DARK, 7)
    polygon(d, [(76, 37), (91, 52), (77, 62), (66, 51)], STEEL, OUTLINE, 4)
    for t in [0, 1, 2]:
        line(d, [(48 + t * 9, 86 - t * 9), (58 + t * 9, 96 - t * 9)], STEEL_LIGHT, 3)


def draw_belt(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (19, 55, 109, 83), 10, (91, 53, 36, 255), OUTLINE, 5)
    rounded(d, (48, 43, 80, 94), 8, GOLD_DARK, OUTLINE, 4)
    ellipse(d, (57, 55, 71, 69), GOLD, OUTLINE, 2)
    for x in [31, 92]:
        ellipse(d, (x - 4, 66, x + 4, 74), STEEL_LIGHT, OUTLINE, 2)


def draw_crystal(img: Image.Image, color=VIOLET, dark: bool = False) -> None:
    d = ImageDraw.Draw(img)
    add_glow(img, color, (35, 19, 95, 103), 8)
    polygon(d, [(63, 17), (91, 47), (78, 103), (50, 103), (37, 47)], color, OUTLINE, 5)
    polygon(d, [(63, 25), (74, 51), (64, 92), (53, 51)], tuple(min(255, c + 40) for c in color[:3]) + (230,), None, 0)
    if dark:
        ellipse(d, (54, 54, 74, 74), (15, 9, 24, 235), OUTLINE, 3)


def draw_skull(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    ellipse(d, (37, 28, 91, 81), (206, 194, 163, 255), OUTLINE, 5)
    rounded(d, (47, 70, 81, 96), 8, (206, 194, 163, 255), OUTLINE, 4)
    ellipse(d, (49, 49, 60, 62), VIOLET, OUTLINE, 2)
    ellipse(d, (68, 49, 79, 62), VIOLET, OUTLINE, 2)
    polygon(d, [(64, 60), (70, 74), (58, 74)], (80, 61, 54, 255), OUTLINE, 2)
    arc(d, (38, 23, 91, 87), 210, 330, VIOLET, 4)


def draw_amp(img: Image.Image, loud: bool = False) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (32, 36, 96, 92), 9, (38, 34, 44, 255), OUTLINE, 5)
    rounded(d, (41, 47, 87, 82), 6, (80, 72, 78, 255), None, 0)
    ellipse(d, (49, 54, 79, 84), (37, 28, 38, 255), OUTLINE, 3)
    ellipse(d, (58, 63, 70, 75), CYAN if loud else GOLD, None, 0)
    for x in [45, 83]:
        ellipse(d, (x - 3, 41, x + 3, 47), GOLD, OUTLINE, 1)
    if loud:
        arc(d, (20, 30, 109, 98), 320, 40, CYAN, 5)
        arc(d, (12, 21, 117, 107), 320, 40, CYAN, 3)


def draw_cable(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    arc(d, (24, 34, 104, 105), 182, 32, OUTLINE, 11)
    arc(d, (24, 34, 104, 105), 182, 32, (38, 31, 50, 255), 6)
    line(d, [(36, 70), (23, 58)], STEEL_LIGHT, 7)
    line(d, [(91, 70), (105, 60)], STEEL_LIGHT, 7)
    ellipse(d, (52, 46, 76, 70), CYAN, OUTLINE, 4)


def draw_crown(img: Image.Image, cursed: bool = False) -> None:
    d = ImageDraw.Draw(img)
    pts = [(27, 84), (35, 39), (53, 65), (64, 31), (75, 65), (93, 39), (101, 84)]
    polygon(d, pts, GOLD, OUTLINE, 5)
    rounded(d, (30, 78, 98, 98), 7, GOLD_DARK, OUTLINE, 4)
    for x, col in [(35, RED), (64, VIOLET if cursed else CYAN), (93, RED)]:
        ellipse(d, (x - 6, 71, x + 6, 83), col, OUTLINE, 2)
    if cursed:
        add_glow(img, VIOLET, (45, 35, 83, 93), 8)
        arc(d, (39, 25, 89, 104), 250, 290, VIOLET, 4)


def draw_shard(img: Image.Image, burning: bool = False) -> None:
    d = ImageDraw.Draw(img)
    color = ORANGE if burning else (158, 231, 244, 220)
    if burning:
        add_glow(img, ORANGE, (32, 25, 94, 100), 10)
    polygon(d, [(64, 20), (91, 53), (76, 101), (45, 91), (37, 52)], color, OUTLINE, 5)
    polygon(d, [(64, 29), (75, 55), (65, 89), (52, 59)], (255, 223, 126, 210) if burning else (230, 255, 255, 165), None, 0)
    if burning:
        line(d, [(43, 34), (33, 18), (55, 27)], RED, 5)


def draw_route_mark(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    polygon(d, [(64, 20), (94, 42), (85, 92), (64, 108), (43, 92), (34, 42)], GOLD, OUTLINE, 5)
    line(d, [(64, 31), (64, 94)], (255, 246, 165, 230), 5)
    ellipse(d, (49, 47, 79, 77), VIOLET, OUTLINE, 3)
    polygon(d, [(64, 51), (72, 64), (64, 74), (56, 64)], (255, 245, 168, 230), None, 0)


def draw_bandage(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (23, 53, 105, 77), 9, (232, 211, 177, 255), OUTLINE, 4)
    rounded(d, (52, 43, 76, 87), 8, (232, 211, 177, 255), OUTLINE, 4)
    line(d, [(64, 52), (64, 79)], RED, 5)
    line(d, [(51, 65), (77, 65)], RED, 5)


def draw_magnet(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    arc(d, (32, 27, 96, 96), 25, 155, OUTLINE, 16)
    arc(d, (32, 27, 96, 96), 25, 155, RED, 9)
    line(d, [(37, 63), (28, 77)], STEEL_LIGHT, 13)
    line(d, [(91, 63), (100, 77)], STEEL_LIGHT, 13)
    line(d, [(28, 77), (21, 87)], OUTLINE, 5)
    line(d, [(100, 77), (107, 87)], OUTLINE, 5)


def draw_oil(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (45, 25, 83, 98), 11, (52, 45, 36, 255), OUTLINE, 5)
    rounded(d, (52, 18, 76, 35), 5, STEEL, OUTLINE, 3)
    ellipse(d, (51, 51, 77, 80), ORANGE, OUTLINE, 3)
    line(d, [(64, 36), (64, 51)], (255, 218, 123, 170), 4)


def draw_dusty_artifact(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    rounded(d, (30, 51, 98, 93), 8, (92, 64, 45, 255), OUTLINE, 5)
    rounded(d, (40, 37, 88, 57), 7, (130, 89, 54, 255), OUTLINE, 4)
    ellipse(d, (52, 52, 76, 76), VIOLET, OUTLINE, 3)
    for x, y in [(35, 35), (89, 33), (98, 76), (24, 77)]:
        ellipse(d, (x, y, x + 6, y + 6), (166, 151, 126, 180), None, 0)


def draw_charm(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    line(d, [(42, 31), (64, 54), (86, 31)], (117, 72, 40, 255), 5)
    ellipse(d, (47, 43, 81, 77), RED, OUTLINE, 4)
    polygon(d, [(64, 53), (76, 73), (64, 95), (52, 73)], GOLD, OUTLINE, 4)


def draw_icon(kind: str, accent=GOLD) -> Image.Image:
    img = base_icon(accent)
    if kind == "warrior_charm":
        draw_charm(img)
    elif kind == "fox_boots":
        draw_boots(img, (180, 92, 45, 255), True)
    elif kind == "glass_orb":
        draw_orb(img, (104, 214, 242, 215), True)
    elif kind == "hawk_lens":
        draw_lens(img, CYAN)
    elif kind == "ember_core":
        draw_crystal(img, ORANGE, False)
    elif kind == "old_codex":
        draw_book(img, PARCHMENT)
    elif kind == "stone_heart":
        draw_heart(img, stone=True)
    elif kind == "banner_seed":
        draw_seed_banner(img)
    elif kind == "red_whetstone":
        draw_whetstone(img, True)
    elif kind == "star_compass":
        draw_compass(img)
    elif kind == "living_root":
        draw_root(img)
    elif kind == "captains_coin":
        draw_coin(img)
    elif kind == "quickstring":
        draw_string(img)
    elif kind == "heavy_totem":
        draw_totem(img)
    elif kind == "splinter_gloves":
        draw_gloves(img)
    elif kind == "wide_sigil":
        draw_sigil(img, BLUE)
    elif kind == "swift_ink":
        draw_ink(img, CYAN)
    elif kind == "summoners_bell":
        draw_bell(img)
    elif kind == "blood_sigil":
        draw_sigil(img, RED, True)
    elif kind == "void_ink":
        draw_ink(img, VIOLET)
    elif kind == "echo_pick":
        draw_pick(img, VIOLET, True)
    elif kind == "sturdy_amulet":
        draw_amulet(img, STEEL, True)
    elif kind == "fast_boots":
        draw_boots(img, GOLD, True)
    elif kind == "magnetic_buckle":
        draw_buckle(img, True)
    elif kind == "silver_coin":
        draw_coin(img, silver=True)
    elif kind == "survival_manual":
        draw_book(img, (103, 143, 85, 255))
        ImageDraw.Draw(img).line([(sc(42), sc(76)), (sc(86), sc(76))], fill=RED, width=sc(4))
    elif kind == "cracked_shield":
        draw_shield(img, True)
    elif kind == "sharp_talisman":
        draw_amulet(img, GOLD)
        draw_blade(img, False, False)
    elif kind == "jagged_blade":
        draw_blade(img, True)
    elif kind == "heavy_grip":
        draw_grip(img)
    elif kind == "war_belt":
        draw_belt(img)
    elif kind == "warriors_rage":
        draw_heart(img, RED)
        ImageDraw.Draw(img).line([(sc(42), sc(38)), (sc(25), sc(20))], fill=RED, width=sc(5))
    elif kind == "dark_crystal":
        draw_crystal(img, VIOLET, True)
    elif kind == "ash_page":
        draw_book(img, PARCHMENT, ash=True)
    elif kind == "skull_resonator":
        draw_skull(img)
    elif kind == "ink_candle":
        draw_ink(img, VIOLET, True)
    elif kind == "copper_string":
        draw_string(img, copper=True)
    elif kind == "broken_pick":
        draw_pick(img, (215, 89, 141, 255))
        ImageDraw.Draw(img).line([(sc(54), sc(56)), (sc(76), sc(78))], fill=STEEL_LIGHT, width=sc(4))
    elif kind == "loud_amp":
        draw_amp(img, True)
    elif kind == "bass_cable":
        draw_cable(img)
    elif kind == "cursed_crown":
        draw_crown(img, True)
    elif kind == "fragile_heart":
        draw_heart(img, RED, fragile=True)
    elif kind == "greedy_purse":
        draw_coin(img, greedy=True)
    elif kind == "burning_shard":
        draw_shard(img, True)
    elif kind == "golden_route_mark":
        draw_route_mark(img)
    elif kind == "glass_edge":
        draw_blade(img, False, True)
    elif kind == "shop_heal":
        draw_bandage(img)
    elif kind == "shop_pickup":
        draw_magnet(img)
    elif kind == "shop_weapon_cooldown":
        draw_oil(img)
    elif kind == "shop_artifact":
        draw_dusty_artifact(img)
    elif kind == "shop_damage":
        draw_whetstone(img)
    elif kind == "shop_speed":
        draw_boots(img, GOLD, True)
    elif kind == "shop_range":
        draw_lens(img, CYAN)
    else:
        draw_sigil(img, accent)
    return polish_icon(img, accent, sum(ord(ch) for ch in kind))


ARTIFACT_ACCENTS = {
    "warrior_charm": RED, "fox_boots": ORANGE, "glass_orb": CYAN, "hawk_lens": CYAN,
    "ember_core": ORANGE, "old_codex": PARCHMENT, "stone_heart": STEEL, "banner_seed": GREEN,
    "red_whetstone": RED, "star_compass": GOLD, "living_root": GREEN, "captains_coin": GOLD,
    "quickstring": CYAN, "heavy_totem": ORANGE, "splinter_gloves": ORANGE, "wide_sigil": BLUE,
    "swift_ink": CYAN, "summoners_bell": GOLD, "blood_sigil": RED, "void_ink": VIOLET,
    "echo_pick": VIOLET, "sturdy_amulet": STEEL, "fast_boots": GOLD, "magnetic_buckle": CYAN,
    "silver_coin": STEEL_LIGHT, "survival_manual": GREEN, "cracked_shield": STEEL,
    "sharp_talisman": GOLD, "jagged_blade": STEEL_LIGHT, "heavy_grip": ORANGE,
    "war_belt": ORANGE, "warriors_rage": RED, "dark_crystal": VIOLET, "ash_page": ORANGE,
    "skull_resonator": VIOLET, "ink_candle": VIOLET, "copper_string": ORANGE,
    "broken_pick": RED, "loud_amp": CYAN, "bass_cable": CYAN, "cursed_crown": VIOLET,
    "fragile_heart": RED, "greedy_purse": GOLD, "burning_shard": ORANGE,
    "golden_route_mark": GOLD, "glass_edge": CYAN,
}

SHOP_ACCENTS = {
    "shop_damage": RED,
    "shop_heal": RED,
    "shop_pickup": CYAN,
    "shop_speed": GOLD,
    "shop_weapon_cooldown": ORANGE,
    "shop_range": CYAN,
    "shop_artifact": VIOLET,
}


def ids_from_progression() -> tuple[list[str], list[str]]:
    text = (ROOT / "scripts" / "progression_data.gd").read_text(encoding="utf-8")
    artifacts_block = text.split("const ARTIFACTS := [", 1)[1].split("]\n\nconst LEVEL_UP_REWARDS", 1)[0]
    shop_block = text.split("const SHOP_ITEMS := [", 1)[1].split("]\n\n\nstatic func base_stats", 1)[0]
    artifacts = re.findall(r'"id":\s*"([^"]+)"', artifacts_block)
    shop = re.findall(r'"id":\s*"([^"]+)"', shop_block)
    return artifacts, shop


def make_slot_assets() -> None:
    SHOP_UI_DIR.mkdir(parents=True, exist_ok=True)

    def frame(path: Path, hover: bool = False) -> None:
        img = Image.new("RGBA", (256 * S, 256 * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        add_glow(img, CYAN if hover else GOLD, (28, 28, 228, 228), 10 if hover else 6)
        fill = (12, 10, 17, 218) if not hover else (28, 18, 42, 232)
        border = CYAN if hover else GOLD
        rounded(d, (9, 11, 247, 247), 30, (5, 5, 9, 246), OUTLINE, 7)
        rounded(d, (18, 18, 238, 238), 25, darken(GOLD_DARK, 18), OUTLINE, 4)
        rounded(d, (30, 31, 226, 225), 18, fill, border, 5)
        rounded(d, (45, 45, 211, 211), 14, (42, 31, 45, 198), rgba(lighten(border, 28), 215), 3)
        # Ornate metal corner brackets, like a small relic tray.
        for x, y, sx, sy in [(22, 22, 1, 1), (234, 22, -1, 1), (22, 234, 1, -1), (234, 234, -1, -1)]:
            polygon(d, [(x, y), (x + sx * 34, y), (x + sx * 27, y + sy * 10), (x + sx * 10, y + sy * 27), (x, y + sy * 34)], darken(GOLD, 8), OUTLINE, 3)
            ellipse(d, (x - 9, y - 9, x + 9, y + 9), border, OUTLINE, 3)
        for y in [38, 218]:
            line(d, [(70, y), (186, y)], rgba((255, 236, 158, 255), 150), 3)
        for x in [38, 218]:
            line(d, [(x, 70), (x, 186)], rgba((255, 236, 158, 255), 115), 2)
        if hover:
            glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
            gd = ImageDraw.Draw(glow)
            gd.rounded_rectangle((sc(20), sc(20), sc(236), sc(236)), radius=sc(25), outline=rgba(CYAN, 220), width=sc(10))
            gd.arc((sc(41), sc(42), sc(215), sc(216)), 205, 335, fill=rgba((255, 255, 255, 255), 120), width=sc(5))
            glow = glow.filter(ImageFilter.GaussianBlur(sc(6)))
            img.alpha_composite(glow)
        add_painted_grain(img, 700 + int(hover), 16)
        downsample(img).save(path)

    frame(SHOP_UI_DIR / "ui_shop_artifact_slot_frame.png")
    frame(SHOP_UI_DIR / "ui_shop_artifact_slot_hover.png", True)

    badge = Image.new("RGBA", (256 * S, 96 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    add_glow(badge, GOLD, (14, 14, 242, 82), 7)
    rounded(d, (8, 10, 248, 86), 28, (7, 7, 12, 244), OUTLINE, 6)
    rounded(d, (20, 20, 236, 76), 21, (74, 43, 26, 238), GOLD, 5)
    line(d, [(83, 25), (218, 25)], rgba((255, 232, 138, 255), 125), 2)
    line(d, [(85, 72), (217, 72)], rgba((0, 0, 0, 255), 80), 2)
    ellipse(d, (32, 27, 76, 71), GOLD, OUTLINE, 4)
    ellipse(d, (40, 35, 68, 63), (255, 229, 113, 255), GOLD_DARK, 2)
    polygon(d, [(55, 38), (61, 50), (74, 51), (63, 59), (66, 70), (55, 64), (44, 70), (47, 59), (36, 51), (49, 50)], (255, 244, 174, 230), None, 0)
    add_painted_grain(badge, 812, 12)
    downsample(badge).save(SHOP_UI_DIR / "ui_shop_price_badge.png")

    overlay = Image.new("RGBA", (256 * S, 256 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    rounded(d, (18, 18, 238, 238), 28, (4, 5, 8, 168), OUTLINE, 4)
    line(d, [(55, 67), (201, 189)], (255, 80, 76, 225), 17)
    line(d, [(201, 67), (55, 189)], (255, 80, 76, 225), 17)
    line(d, [(55, 67), (201, 189)], (255, 211, 150, 110), 5)
    line(d, [(201, 67), (55, 189)], (255, 211, 150, 110), 5)
    downsample(overlay).save(SHOP_UI_DIR / "ui_shop_purchased_overlay.png")

    tooltip = Image.new("RGBA", (640 * S, 320 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(tooltip)
    add_glow(tooltip, VIOLET, (18, 18, 622, 302), 11)
    rounded(d, (10, 14, 630, 306), 32, (5, 6, 12, 248), OUTLINE, 8)
    rounded(d, (25, 29, 615, 291), 24, (28, 21, 34, 240), GOLD, 5)
    rounded(d, (43, 48, 597, 272), 16, (12, 12, 20, 212), rgba(CYAN, 105), 2)
    line(d, [(60, 86), (580, 86)], rgba(CYAN, 190), 4)
    for x, y in [(32, 36), (588, 36), (32, 276), (588, 276)]:
        ellipse(d, (x - 9, y - 9, x + 9, y + 9), VIOLET, OUTLINE, 3)
    arc(d, (42, 31, 598, 288), 204, 336, rgba((255, 238, 162, 255), 90), 4)
    add_painted_grain(tooltip, 909, 10)
    downsample(tooltip).save(SHOP_UI_DIR / "ui_shop_tooltip_frame.png")


def make_cursor_assets() -> None:
    CURSOR_DIR.mkdir(parents=True, exist_ok=True)

    def cursor(path: Path, accent: tuple[int, int, int, int], attack: bool = False) -> None:
        img = Image.new("RGBA", (48 * S, 48 * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        add_glow(img, accent, (1, 1, 45, 45), 3.0)
        # Dagger-quill pointer: the hotspot remains the bright tip at (5, 4).
        blade = [(5, 4), (38, 17), (25, 23), (20, 35), (14, 27)]
        polygon(d, blade, (242, 229, 191, 255), OUTLINE, 3)
        polygon(d, [(8, 7), (30, 16), (20, 20), (15, 27)], lighten(accent, 24), None, 0)
        line(d, [(14, 27), (29, 42)], GOLD_DARK, 7)
        line(d, [(14, 27), (29, 42)], (255, 228, 142, 255), 3)
        polygon(d, [(18, 25), (27, 20), (32, 26), (22, 31)], darken(GOLD, 5), OUTLINE, 2)
        ellipse(d, (22, 22, 29, 29), accent, OUTLINE, 1)
        line(d, [(6, 4), (15, 7)], (255, 255, 255, 210), 1)
        if attack:
            arc(d, (11, 4, 47, 40), 290, 90, RED, 4)
            line(d, [(34, 13), (45, 7)], RED, 4)
            line(d, [(37, 20), (47, 18)], ORANGE, 2)
        else:
            ellipse(d, (31, 6, 42, 17), accent, OUTLINE, 2)
            line(d, [(35, 10), (41, 4)], rgba((255, 255, 255, 255), 130), 2)
        add_painted_grain(img, 1000 + (1 if attack else 0) + accent[0], 16)
        downsample(img).save(path)

    cursor(CURSOR_DIR / "game_cursor.png", GOLD)
    cursor(CURSOR_DIR / "game_cursor_hover.png", CYAN)
    cursor(CURSOR_DIR / "game_cursor_attack.png", RED, True)


def make_preview(artifact_ids: list[str], shop_ids: list[str]) -> None:
    tile = 154
    cols = 10
    total = len(artifact_ids) + len(shop_ids)
    rows = math.ceil(total / cols)
    preview = Image.new("RGBA", (cols * tile, rows * tile), (12, 12, 20, 255))
    for i, artifact_id in enumerate(artifact_ids):
        img = Image.open(ARTIFACT_DIR / f"artifact_{artifact_id}.png").convert("RGBA")
        x = (i % cols) * tile + 13
        y = (i // cols) * tile + 10
        preview.alpha_composite(img, (x, y))
    offset = len(artifact_ids)
    for j, shop_id in enumerate(shop_ids):
        img = Image.open(SHOP_ICON_DIR / f"shop_{shop_id}.png").convert("RGBA")
        i = offset + j
        x = (i % cols) * tile + 13
        y = (i // cols) * tile + 10
        preview.alpha_composite(img, (x, y))
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW_PATH)


def main() -> None:
    artifact_ids, shop_ids = ids_from_progression()
    missing_artifacts = sorted(set(artifact_ids) - set(ARTIFACT_ACCENTS.keys()))
    missing_shop = sorted(set(shop_ids) - set(SHOP_ACCENTS.keys()))
    if missing_artifacts or missing_shop:
        raise SystemExit(f"Missing icon specs: artifacts={missing_artifacts}, shop={missing_shop}")

    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    SHOP_ICON_DIR.mkdir(parents=True, exist_ok=True)

    for artifact_id in artifact_ids:
        finish(draw_icon(artifact_id, ARTIFACT_ACCENTS[artifact_id]), ARTIFACT_DIR / f"artifact_{artifact_id}.png")
    for shop_id in shop_ids:
        finish(draw_icon(shop_id, SHOP_ACCENTS[shop_id]), SHOP_ICON_DIR / f"shop_{shop_id}.png")

    make_slot_assets()
    make_cursor_assets()
    make_preview(artifact_ids, shop_ids)
    print(f"Generated {len(artifact_ids)} artifact icons, {len(shop_ids)} shop icons, shop UI assets and cursor variants.")


if __name__ == "__main__":
    main()
