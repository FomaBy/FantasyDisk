"""Generate 256x256 dark-fantasy artifact icons with transparent backgrounds.

Design task: docs/tasks/codex_design_artifact_icons_dark_fantasy_task.md

The icons intentionally contain one centered object and no frame: UI frames are
provided by the game. Existing artifact filenames are replaced in place and
Godot .import sidecars are left untouched.

Run from the project root:

    python3 tools/generate_dark_fantasy_artifact_icons.py
"""
from __future__ import annotations

import math
import random
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

import generate_artifact_shop_cursor_assets as kit


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"
PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_dark_fantasy_40px_preview.png"

SOURCE_SIZE = 128
OUTPUT_SIZE = 256


def muted(color: tuple[int, int, int, int], amount: float = 0.38) -> tuple[int, int, int, int]:
    base = (72, 54, 84, color[3])
    return tuple(round(color[i] * (1.0 - amount) + base[i] * amount) for i in range(4))


def artifact_ids() -> list[str]:
    text = (ROOT / "scripts" / "progression_data.gd").read_text(encoding="utf-8")
    block = text.split("const ARTIFACTS := [", 1)[1].split("]\n\nconst LEVEL_UP_REWARDS", 1)[0]
    return re.findall(r'"id":\s*"([^"]+)"', block)


def transparent_source() -> Image.Image:
    return kit.canvas(SOURCE_SIZE, SOURCE_SIZE)


def draw_source(kind: str) -> tuple[Image.Image, tuple[int, int, int, int]]:
    accent = kit.ARTIFACT_ACCENTS.get(kind, kit.VIOLET)
    img = transparent_source()
    d = ImageDraw.Draw(img)

    if kind == "warrior_charm":
        kit.draw_charm(img)
    elif kind == "fox_boots":
        kit.draw_boots(img, (170, 78, 42, 255), True)
    elif kind == "glass_orb":
        kit.draw_orb(img, (91, 197, 226, 214), True)
    elif kind == "hawk_lens":
        kit.draw_lens(img, kit.CYAN)
    elif kind == "ember_core":
        kit.draw_crystal(img, kit.ORANGE, False)
    elif kind == "old_codex":
        kit.draw_book(img, kit.PARCHMENT)
    elif kind == "stone_heart":
        kit.draw_heart(img, stone=True)
    elif kind == "banner_seed":
        kit.draw_seed_banner(img)
    elif kind == "red_whetstone":
        kit.draw_whetstone(img, True)
    elif kind == "star_compass":
        kit.draw_compass(img)
    elif kind == "living_root":
        kit.draw_root(img)
    elif kind == "captains_coin":
        kit.draw_coin(img)
    elif kind == "quickstring":
        kit.draw_string(img)
    elif kind == "heavy_totem":
        kit.draw_totem(img)
    elif kind == "splinter_gloves":
        kit.draw_gloves(img)
    elif kind == "wide_sigil":
        kit.draw_sigil(img, kit.BLUE)
    elif kind == "swift_ink":
        kit.draw_ink(img, kit.CYAN)
    elif kind == "summoners_bell":
        kit.draw_bell(img)
    elif kind == "blood_sigil":
        kit.draw_sigil(img, kit.RED, True)
    elif kind == "void_ink":
        kit.draw_ink(img, kit.VIOLET)
    elif kind == "echo_pick":
        kit.draw_pick(img, kit.VIOLET, True)
    elif kind == "sturdy_amulet":
        kit.draw_amulet(img, kit.STEEL, True)
    elif kind == "fast_boots":
        kit.draw_boots(img, kit.GOLD, True)
    elif kind == "magnetic_buckle":
        kit.draw_buckle(img, True)
    elif kind == "silver_coin":
        kit.draw_coin(img, silver=True)
    elif kind == "survival_manual":
        kit.draw_book(img, (103, 143, 85, 255))
        d.line([(kit.sc(42), kit.sc(76)), (kit.sc(86), kit.sc(76))], fill=kit.RED, width=kit.sc(4))
    elif kind == "cracked_shield":
        kit.draw_shield(img, True)
    elif kind == "sharp_talisman":
        kit.draw_amulet(img, kit.GOLD)
        kit.draw_blade(img, False, False)
    elif kind == "jagged_blade":
        kit.draw_blade(img, True)
    elif kind == "heavy_grip":
        kit.draw_grip(img)
    elif kind == "war_belt":
        kit.draw_belt(img)
    elif kind == "warriors_rage":
        kit.draw_heart(img, kit.RED)
        d.line([(kit.sc(42), kit.sc(38)), (kit.sc(25), kit.sc(20))], fill=kit.RED, width=kit.sc(5))
    elif kind == "dark_crystal":
        kit.draw_crystal(img, kit.VIOLET, True)
    elif kind == "ash_page":
        kit.draw_book(img, kit.PARCHMENT, ash=True)
    elif kind == "skull_resonator":
        kit.draw_skull(img)
    elif kind == "ink_candle":
        kit.draw_ink(img, kit.VIOLET, True)
    elif kind == "copper_string":
        kit.draw_string(img, copper=True)
    elif kind == "broken_pick":
        kit.draw_pick(img, (215, 89, 141, 255))
        d.line([(kit.sc(54), kit.sc(56)), (kit.sc(76), kit.sc(78))], fill=kit.STEEL_LIGHT, width=kit.sc(4))
    elif kind == "loud_amp":
        kit.draw_amp(img, True)
    elif kind == "bass_cable":
        kit.draw_cable(img)
    elif kind == "cursed_crown":
        kit.draw_crown(img, True)
    elif kind == "fragile_heart":
        kit.draw_heart(img, kit.RED, fragile=True)
    elif kind == "greedy_purse":
        kit.draw_coin(img, greedy=True)
    elif kind == "burning_shard":
        kit.draw_shard(img, True)
    elif kind == "golden_route_mark":
        kit.draw_route_mark(img)
    elif kind == "glass_edge":
        kit.draw_blade(img, False, True)
    else:
        kit.draw_sigil(img, accent)

    return img, accent


def strip_source_glow(src: Image.Image) -> Image.Image:
    out = src.copy()
    alpha = out.split()[3]
    alpha = alpha.point(lambda v: 0 if v < 72 else min(255, int((v - 72) * 255 / 183)))
    out.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.35)))
    return out


def scaled_item_layer(src: Image.Image, target: int) -> Image.Image:
    alpha = src.split()[3]
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("source icon is empty")

    pad = kit.sc(8)
    bbox = (
        max(0, bbox[0] - pad),
        max(0, bbox[1] - pad),
        min(src.width, bbox[2] + pad),
        min(src.height, bbox[3] + pad),
    )
    cropped = src.crop(bbox)
    scale = min(target / cropped.width, target / cropped.height)
    resized = cropped.resize((round(cropped.width * scale), round(cropped.height * scale)), Image.Resampling.LANCZOS)

    layer = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    x = (OUTPUT_SIZE - resized.width) // 2
    y = (OUTPUT_SIZE - resized.height) // 2 - 2
    layer.alpha_composite(resized, (x, y))
    return layer


def painterly_warp(layer: Image.Image, seed: int, amount: int = 2) -> Image.Image:
    rng = random.Random(seed + 173)
    warped = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    phase = rng.uniform(0, math.tau)
    amp = rng.uniform(0.8, float(amount))
    for y in range(0, OUTPUT_SIZE, 2):
        shift = round(math.sin(y * 0.075 + phase) * amp + rng.choice([-1, 0, 0, 1]))
        strip = layer.crop((0, y, OUTPUT_SIZE, min(OUTPUT_SIZE, y + 2)))
        warped.alpha_composite(strip, (shift, y))

    second = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    phase = rng.uniform(0, math.tau)
    for x in range(0, OUTPUT_SIZE, 3):
        shift = round(math.sin(x * 0.055 + phase) * 0.8)
        strip = warped.crop((x, 0, min(OUTPUT_SIZE, x + 3), OUTPUT_SIZE))
        second.alpha_composite(strip, (x, shift))
    return second.filter(ImageFilter.UnsharpMask(radius=0.7, percent=115, threshold=3))


def glow_from_alpha(alpha: Image.Image, color: tuple[int, int, int, int], blur: float, strength: int) -> Image.Image:
    glow_alpha = alpha.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: min(255, int(v * strength / 255)))
    return Image.merge("RGBA", (
        Image.new("L", (OUTPUT_SIZE, OUTPUT_SIZE), color[0]),
        Image.new("L", (OUTPUT_SIZE, OUTPUT_SIZE), color[1]),
        Image.new("L", (OUTPUT_SIZE, OUTPUT_SIZE), color[2]),
        glow_alpha,
    ))


def paint_grain(mask: Image.Image, seed: int) -> Image.Image:
    rng = random.Random(seed)
    grain = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(grain)
    for _ in range(1300):
        x = rng.randrange(OUTPUT_SIZE)
        y = rng.randrange(OUTPUT_SIZE)
        if mask.getpixel((x, y)) < 40:
            continue
        a = rng.randrange(5, 23)
        color = (255, 232, 178, a) if rng.random() > 0.55 else (0, 0, 0, a)
        d.point((x, y), fill=color)
    return grain


def painterly_material_base(item: Image.Image, kind: str, accent: tuple[int, int, int, int], seed: int) -> Image.Image:
    rng = random.Random(seed + 373)
    alpha = item.split()[3]
    x0, y0, x1, y1 = bbox_or_full(alpha)
    cx = (x0 + x1) * 0.5
    cy = (y0 + y1) * 0.5
    span = max(1.0, max(x1 - x0, y1 - y0) * 0.5)
    group = material_group(kind)

    material_tint = {
        "leather": (92, 52, 36),
        "braid": (90, 62, 52),
        "crystal": (78, 53, 96),
        "paper": (142, 116, 73),
        "wood": (73, 50, 31),
        "rune": (51, 31, 57),
        "stone": (82, 80, 76),
        "metal": (91, 82, 78),
        "mixed": (76, 61, 66),
    }.get(group, (76, 61, 66))

    px = item.load()
    apx = alpha.load()
    phase = rng.random() * math.tau
    for y in range(OUTPUT_SIZE):
        for x in range(OUTPUT_SIZE):
            a = apx[x, y]
            if a == 0:
                continue
            r, g, b, _ = px[x, y]
            dx = (x - cx) / span
            dy = (y - cy) / span
            light = max(0.0, min(1.0, 0.58 - 0.36 * dx - 0.42 * dy))
            shade = max(0.0, min(1.0, 0.22 + 0.30 * dx + 0.45 * dy))
            grain = (
                math.sin(x * 0.21 + y * 0.11 + phase)
                + math.sin(x * 0.047 - y * 0.19 + phase * 0.7)
                + rng.uniform(-0.16, 0.16)
            ) / 2.35
            edge_dark = 1.0 - min(1.0, a / 240.0)

            # Pull clean vector fills toward dirty game-material colors.
            r = int(r * 0.66 + material_tint[0] * 0.22 + accent[0] * 0.12)
            g = int(g * 0.66 + material_tint[1] * 0.22 + accent[1] * 0.12)
            b = int(b * 0.66 + material_tint[2] * 0.22 + accent[2] * 0.12)

            lift = int(42 * light + 18 * grain)
            drop = int(72 * shade + 52 * edge_dark)
            r = max(0, min(235, r + lift - drop))
            g = max(0, min(235, g + int(lift * 0.92) - drop))
            b = max(0, min(235, b + int(lift * 0.80) - int(drop * 0.92)))
            px[x, y] = (r, g, b, a)
    return item


def clip_to_alpha(overlay: Image.Image, alpha: Image.Image, opacity: float = 1.0) -> Image.Image:
    out = overlay.copy()
    clipped = ImageChops.multiply(out.split()[3], alpha.point(lambda v: int(v * opacity)))
    out.putalpha(clipped)
    return out


def bbox_or_full(alpha: Image.Image) -> tuple[int, int, int, int]:
    return alpha.getbbox() or (22, 22, 234, 234)


def material_group(kind: str) -> str:
    if kind in {"fox_boots", "fast_boots", "war_belt", "heavy_grip", "splinter_gloves", "greedy_purse"}:
        return "leather"
    if kind in {"quickstring", "copper_string", "bass_cable"}:
        return "braid"
    if kind in {"dark_crystal", "ember_core", "burning_shard", "glass_edge", "glass_orb"}:
        return "crystal"
    if kind in {"old_codex", "survival_manual", "ash_page"}:
        return "paper"
    if kind in {"living_root", "banner_seed", "heavy_totem"}:
        return "wood"
    if kind in {"blood_sigil", "wide_sigil", "void_ink", "swift_ink", "ink_candle"}:
        return "rune"
    if kind in {"stone_heart", "cracked_shield"}:
        return "stone"
    if kind in {"sturdy_amulet", "sharp_talisman", "warrior_charm", "summoners_bell", "cursed_crown", "captains_coin", "silver_coin", "magnetic_buckle", "red_whetstone", "jagged_blade"}:
        return "metal"
    return "mixed"


def add_material_wear(item: Image.Image, kind: str, accent: tuple[int, int, int, int], seed: int) -> None:
    alpha = item.split()[3]
    x0, y0, x1, y1 = bbox_or_full(alpha)
    rng = random.Random(seed + 611)
    group = material_group(kind)
    overlay = Image.new("RGBA", item.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    dark = (8, 6, 12, 92)
    cold = (126, 104, 168, 72)
    warm = (236, 192, 112, 64)
    pale = (255, 237, 190, 76)
    blood = (117, 19, 33, 82)

    for _ in range(48):
        x = rng.randint(x0, max(x0, x1 - 1))
        y = rng.randint(y0, max(y0, y1 - 1))
        length = rng.randint(9, 42)
        angle = rng.uniform(-0.9, 0.45)
        color = pale if rng.random() > 0.58 else dark
        width = rng.choice([1, 1, 2, 2, 3])
        d.line((x, y, x + math.cos(angle) * length, y + math.sin(angle) * length), fill=color, width=width)

    for _ in range(18):
        x = rng.randint(x0, max(x0, x1 - 1))
        y = rng.randint(y0, max(y0, y1 - 1))
        r = rng.randint(2, 7)
        color = (255, 225, 152, rng.randint(18, 52)) if rng.random() > 0.5 else (3, 2, 6, rng.randint(26, 64))
        d.ellipse((x - r, y - r // 2, x + r, y + r // 2 + 1), fill=color)

    if group == "leather":
        for _ in range(22):
            x = rng.randint(x0 + 5, max(x0 + 5, x1 - 8))
            y = rng.randint(y0 + 5, max(y0 + 5, y1 - 8))
            d.arc((x - 10, y - 5, x + 20, y + 11), 188, 342, fill=(58, 27, 22, 105), width=2)
        for _ in range(18):
            x = rng.randint(x0 + 6, max(x0 + 6, x1 - 6))
            y = rng.randint(y0 + 6, max(y0 + 6, y1 - 6))
            d.line((x - 3, y, x + 3, y), fill=(241, 184, 105, 95), width=1)
    elif group == "braid":
        for step in range(-80, 230, 14):
            d.line((x0 + step, y0 + 8, x0 + step + 95, y1 - 8), fill=(232, 174, 91, 70), width=2)
            d.line((x0 + step + 5, y1 - 8, x0 + step + 100, y0 + 8), fill=(29, 21, 31, 82), width=2)
        for _ in range(12):
            x = rng.randint(x0, max(x0, x1 - 1))
            y = rng.randint(y0, max(y0, y1 - 1))
            d.line((x, y, x + rng.randint(6, 18), y + rng.randint(-4, 6)), fill=(126, 226, 210, 58), width=1)
    elif group == "crystal":
        cx = (x0 + x1) / 2
        for _ in range(18):
            x = rng.randint(x0 + 4, max(x0 + 4, x1 - 4))
            d.line((cx, y0 + rng.randint(4, 24), x, y1 - rng.randint(8, 30)), fill=cold, width=rng.choice([1, 2]))
        for _ in range(10):
            x = rng.randint(x0 + 10, max(x0 + 10, x1 - 10))
            y = rng.randint(y0 + 10, max(y0 + 10, y1 - 10))
            d.line((x, y, x + rng.randint(-18, 18), y + rng.randint(8, 24)), fill=(246, 231, 255, 76), width=2)
    elif group == "paper":
        for _ in range(38):
            x = rng.randint(x0, max(x0, x1 - 1))
            y = rng.randint(y0, max(y0, y1 - 1))
            d.ellipse((x, y, x + rng.randint(2, 6), y + rng.randint(1, 4)), fill=(70, 43, 29, rng.randint(28, 75)))
        for _ in range(9):
            x = rng.randint(x0 + 7, max(x0 + 7, x1 - 35))
            y = rng.randint(y0 + 10, max(y0 + 10, y1 - 12))
            d.line((x, y, x + rng.randint(18, 42), y + rng.randint(-2, 3)), fill=(58, 35, 29, 94), width=2)
    elif group == "wood":
        for _ in range(28):
            y = rng.randint(y0, max(y0, y1 - 1))
            x = rng.randint(x0, max(x0, x1 - 10))
            d.arc((x - 12, y - 8, x + 38, y + 18), 160, 330, fill=(47, 28, 18, 96), width=2)
        for _ in range(12):
            x = rng.randint(x0 + 4, max(x0 + 4, x1 - 5))
            y = rng.randint(y0 + 4, max(y0 + 4, y1 - 5))
            d.line((x, y, x + rng.randint(-5, 8), y + rng.randint(12, 30)), fill=(150, 86, 46, 76), width=2)
    elif group == "rune":
        for _ in range(18):
            x = rng.randint(x0 + 8, max(x0 + 8, x1 - 8))
            y = rng.randint(y0 + 8, max(y0 + 8, y1 - 8))
            d.line((x - 5, y, x + 5, y), fill=accent[:3] + (82,), width=1)
            d.line((x, y - 5, x, y + 5), fill=accent[:3] + (82,), width=1)
        for _ in range(8):
            x = rng.randint(x0 + 10, max(x0 + 10, x1 - 10))
            y = rng.randint(y0 + 10, max(y0 + 10, y1 - 10))
            d.line((x, y, x + rng.randint(-13, 13), y + rng.randint(10, 22)), fill=blood, width=2)
    elif group in {"metal", "stone"}:
        for _ in range(20):
            x = rng.randint(x0 + 7, max(x0 + 7, x1 - 7))
            y = rng.randint(y0 + 7, max(y0 + 7, y1 - 7))
            d.line((x, y, x + rng.randint(7, 25), y + rng.randint(-5, 7)), fill=(250, 233, 179, 72), width=2)
            d.line((x + 2, y + 2, x + rng.randint(6, 23), y + rng.randint(-3, 9)), fill=dark, width=1)
        for _ in range(16):
            x = rng.randint(x0, max(x0, x1 - 1))
            y = rng.randint(y0, max(y0, y1 - 1))
            d.polygon([(x, y), (x + rng.randint(3, 9), y + rng.randint(-3, 4)), (x + rng.randint(1, 6), y + rng.randint(4, 11))], fill=(7, 6, 9, 86))
    else:
        for _ in range(20):
            x = rng.randint(x0, max(x0, x1 - 1))
            y = rng.randint(y0, max(y0, y1 - 1))
            d.line((x, y, x + rng.randint(-15, 22), y + rng.randint(-8, 18)), fill=warm if rng.random() > 0.5 else cold, width=2)

    item.alpha_composite(clip_to_alpha(overlay, alpha, 1.0))


def add_edge_modeling(item: Image.Image, accent: tuple[int, int, int, int]) -> None:
    alpha = item.split()[3]
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(0.7))

    light_alpha = ImageChops.multiply(ImageChops.offset(edge, -2, -2), alpha).point(lambda v: min(150, int(v * 0.72)))
    light = Image.new("RGBA", item.size, (255, 229, 170, 0))
    light.putalpha(light_alpha)
    item.alpha_composite(light)

    dark_alpha = ImageChops.multiply(ImageChops.offset(edge, 4, 5), alpha).point(lambda v: min(190, int(v * 1.05)))
    dark = Image.new("RGBA", item.size, (4, 3, 8, 0))
    dark.putalpha(dark_alpha)
    item.alpha_composite(dark)

    accent_alpha = edge.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: min(62, int(v * 0.28)))
    rim = Image.new("RGBA", item.size, muted(accent, 0.46)[:3] + (0,))
    rim.putalpha(accent_alpha)
    item.alpha_composite(rim)


def add_dark_fantasy_polish(layer: Image.Image, kind: str, accent: tuple[int, int, int, int], seed: int) -> Image.Image:
    alpha = layer.split()[3]
    item = painterly_material_base(layer.copy(), kind, accent, seed)
    item = ImageEnhance.Color(item).enhance(0.82)
    item = ImageEnhance.Contrast(item).enhance(1.36)
    item = ImageEnhance.Brightness(item).enhance(0.76)

    shade = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.rectangle((0, 0, OUTPUT_SIZE, OUTPUT_SIZE), fill=(0, 0, 0, 0))
    for y in range(OUTPUT_SIZE):
        strength = int(94 * (y / OUTPUT_SIZE) ** 1.35)
        sd.line((0, y, OUTPUT_SIZE, y), fill=(0, 0, 0, strength))
    shade.putalpha(ImageChops.multiply(shade.split()[3], alpha))
    item.alpha_composite(shade)

    light = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    ld = ImageDraw.Draw(light)
    ld.ellipse((28, 15, 156, 88), fill=(214, 172, 112, 52))
    ld.line((52, 34, 176, 111), fill=(226, 188, 126, 68), width=3)
    light.putalpha(ImageChops.multiply(light.split()[3], alpha.filter(ImageFilter.GaussianBlur(1.4))))
    item.alpha_composite(light)
    add_material_wear(item, kind, muted(accent, 0.25), seed)
    item.alpha_composite(paint_grain(alpha, seed))
    add_edge_modeling(item, muted(accent, 0.25))
    return item


def final_icon(kind: str) -> Image.Image:
    src, accent = draw_source(kind)
    src = strip_source_glow(src)
    target = 236 if kind not in {"quickstring", "copper_string", "bass_cable"} else 242
    layer = painterly_warp(scaled_item_layer(src, target), sum(ord(ch) for ch in kind))
    alpha = layer.split()[3]

    out = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))

    outline_alpha = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(7)), alpha).filter(ImageFilter.GaussianBlur(0.8))
    outline_alpha = outline_alpha.point(lambda v: min(150, int(v * 0.82)))
    outline = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (3, 2, 7, 0))
    outline.putalpha(outline_alpha)
    out.alpha_composite(outline)

    shadow_alpha = alpha.filter(ImageFilter.GaussianBlur(4)).point(lambda v: min(95, int(v * 0.34)))
    shadow = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha)
    shadow = ImageChops.offset(shadow, 4, 6)
    out.alpha_composite(Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (5, 3, 9, 0)))
    out.alpha_composite(shadow)

    item = add_dark_fantasy_polish(layer, kind, accent, sum(ord(ch) for ch in kind) + 2600)
    out.alpha_composite(item)
    return out


def make_preview(ids: list[str]) -> None:
    tile = 48
    cols = 12
    rows = math.ceil(len(ids) / cols)
    sheet = Image.new("RGBA", (cols * tile, rows * tile), (24, 20, 28, 255))
    for i, artifact_id in enumerate(ids):
        icon = Image.open(ARTIFACT_DIR / f"artifact_{artifact_id}.png").convert("RGBA")
        small = icon.resize((40, 40), Image.Resampling.LANCZOS)
        x = (i % cols) * tile + 4
        y = (i // cols) * tile + 4
        sheet.alpha_composite(small, (x, y))
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW_PATH)


def main() -> None:
    ids = artifact_ids()
    for artifact_id in ids:
        final_icon(artifact_id).save(ARTIFACT_DIR / f"artifact_{artifact_id}.png")
    make_preview(ids)
    print(f"generated {len(ids)} dark-fantasy artifact icons at 256x256")
    print(f"wrote 40px readability preview: {PREVIEW_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
