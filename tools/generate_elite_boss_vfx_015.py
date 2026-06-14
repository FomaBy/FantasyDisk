#!/usr/bin/env python3
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
EFFECTS = ROOT / "assets" / "sprites" / "effects"
PREVIEWS = ROOT / "docs" / "design" / "previews"

RNG = random.Random(261)


def rgba(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return color[0], color[1], color[2], alpha


def new(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def add(dst: Image.Image, src: Image.Image) -> Image.Image:
    return Image.alpha_composite(dst, src)


def radial_alpha(size: int, inner: float, outer: float, opacity: float = 1.0) -> Image.Image:
    img = Image.new("L", (size, size), 0)
    pix = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            if d < inner:
                v = 255
            elif d > outer:
                v = 0
            else:
                t = (d - inner) / max(outer - inner, 0.001)
                v = int(255 * (1 - t) ** 1.7)
            pix[x, y] = int(v * opacity)
    return img


def glow_disc(size: int, color: tuple[int, int, int], opacity: float, inner: float, outer: float) -> Image.Image:
    layer = Image.new("RGBA", (size, size), rgba(color, 255))
    layer.putalpha(radial_alpha(size, inner, outer, opacity))
    return layer


def irregular_ring(
    size: int,
    color: tuple[int, int, int],
    radius: float,
    width: float,
    alpha: int,
    spikes: int = 96,
    roughness: float = 0.045,
    blur: float = 1.2,
) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    c = size / 2
    outer = []
    inner = []
    for i in range(spikes):
        a = math.tau * i / spikes
        wobble = 1 + math.sin(a * 5.0) * roughness + RNG.uniform(-roughness, roughness)
        r = radius * wobble
        outer.append((c + math.cos(a) * r, c + math.sin(a) * r))
        ri = max(1, r - width * (0.82 + RNG.random() * 0.34))
        inner.append((c + math.cos(a) * ri, c + math.sin(a) * ri))
    draw.polygon(outer, fill=alpha)
    draw.polygon(inner[::-1], fill=0)
    if blur:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new("RGBA", (size, size), rgba(color, 255))
    layer.putalpha(mask)
    return layer


def rune_ring(size: int, color: tuple[int, int, int], radius: float, count: int, alpha: int) -> Image.Image:
    layer = new((size, size))
    draw = ImageDraw.Draw(layer)
    c = size / 2
    for i in range(count):
        a = math.tau * i / count
        p = (c + math.cos(a) * radius, c + math.sin(a) * radius)
        tangent = a + math.pi / 2
        length = size * 0.035
        cross = size * 0.013
        p1 = (p[0] - math.cos(tangent) * length, p[1] - math.sin(tangent) * length)
        p2 = (p[0] + math.cos(tangent) * length, p[1] + math.sin(tangent) * length)
        p3 = (p[0] - math.cos(a) * cross, p[1] - math.sin(a) * cross)
        p4 = (p[0] + math.cos(a) * cross, p[1] + math.sin(a) * cross)
        draw.line([p1, p2], fill=rgba(color, alpha), width=max(1, size // 96))
        draw.line([p3, p4], fill=rgba(color, int(alpha * 0.75)), width=max(1, size // 128))
    return layer.filter(ImageFilter.GaussianBlur(0.25))


def crack_lines(size: int, color: tuple[int, int, int], count: int, alpha: int, inward: bool = True) -> Image.Image:
    layer = new((size, size))
    draw = ImageDraw.Draw(layer)
    c = size / 2
    for _ in range(count):
        a = RNG.random() * math.tau
        r1 = RNG.uniform(size * 0.12, size * 0.28) if inward else RNG.uniform(size * 0.35, size * 0.45)
        r2 = RNG.uniform(size * 0.34, size * 0.48) if inward else RNG.uniform(size * 0.16, size * 0.30)
        pts = []
        steps = RNG.randint(2, 4)
        for i in range(steps):
            t = i / (steps - 1)
            r = r1 + (r2 - r1) * t
            aa = a + RNG.uniform(-0.12, 0.12) * t
            pts.append((c + math.cos(aa) * r, c + math.sin(aa) * r))
        draw.line(pts, fill=rgba(color, alpha), width=RNG.randint(2, 4), joint="curve")
    return layer.filter(ImageFilter.GaussianBlur(0.35))


def particles(size: int, color: tuple[int, int, int], count: int, alpha: int, rmin: float, rmax: float) -> Image.Image:
    layer = new((size, size))
    draw = ImageDraw.Draw(layer)
    c = size / 2
    for _ in range(count):
        a = RNG.random() * math.tau
        r = RNG.uniform(rmin, rmax)
        p = (c + math.cos(a) * r, c + math.sin(a) * r)
        dot = RNG.uniform(size * 0.004, size * 0.013)
        draw.ellipse((p[0] - dot, p[1] - dot, p[0] + dot, p[1] + dot), fill=rgba(color, RNG.randint(alpha // 3, alpha)))
    return layer.filter(ImageFilter.GaussianBlur(0.3))


def zone(
    name: str,
    size: int,
    main: tuple[int, int, int],
    accent: tuple[int, int, int],
    theme: str,
) -> Image.Image:
    img = new((size, size))
    img = add(img, glow_disc(size, main, 0.20, 0.12, 0.95))
    img = add(img, irregular_ring(size, main, size * 0.40, size * 0.045, 168, 128, 0.06, 1.6))
    img = add(img, irregular_ring(size, accent, size * 0.32, size * 0.018, 145, 96, 0.035, 0.9))
    img = add(img, rune_ring(size, accent, size * 0.245, 12, 112))
    if theme in {"rift", "gravity", "summon"}:
        img = add(img, crack_lines(size, accent, 18, 130, inward=True))
        img = add(img, irregular_ring(size, accent, size * 0.18, size * 0.045, 92, 80, 0.08, 2.6))
    if theme == "vampire":
        draw = ImageDraw.Draw(img)
        c = size / 2
        for sign in (-1, 1):
            pts = [
                (c + sign * size * 0.055, c - size * 0.18),
                (c + sign * size * 0.13, c + size * 0.02),
                (c + sign * size * 0.035, c + size * 0.205),
            ]
            draw.line(pts, fill=rgba(accent, 168), width=size // 32, joint="curve")
    if theme == "web":
        draw = ImageDraw.Draw(img)
        c = size / 2
        for i in range(16):
            a = math.tau * i / 16
            draw.line((c, c, c + math.cos(a) * size * 0.40, c + math.sin(a) * size * 0.40), fill=rgba(accent, 90), width=max(1, size // 160))
        for r in (0.13, 0.21, 0.30, 0.38):
            bbox = (c - size * r, c - size * r, c + size * r, c + size * r)
            draw.arc(bbox, 0, 360, fill=rgba(accent, 110), width=max(1, size // 150))
    if theme in {"ember", "molten"}:
        img = add(img, crack_lines(size, accent, 26, 155, inward=False))
        img = add(img, particles(size, (255, 210, 115), 55, 150, size * 0.10, size * 0.42))
    if theme == "bone":
        draw = ImageDraw.Draw(img)
        c = size / 2
        for i in range(10):
            a = math.tau * i / 10 + 0.08
            r = size * 0.30
            base = (c + math.cos(a) * r, c + math.sin(a) * r)
            tip = (c + math.cos(a) * size * 0.43, c + math.sin(a) * size * 0.43)
            side = a + math.pi / 2
            w = size * RNG.uniform(0.018, 0.030)
            poly = [
                (base[0] + math.cos(side) * w, base[1] + math.sin(side) * w),
                tip,
                (base[0] - math.cos(side) * w, base[1] - math.sin(side) * w),
            ]
            draw.polygon(poly, fill=rgba(accent, 150))
            draw.line([base, tip], fill=rgba((255, 250, 220), 190), width=max(1, size // 130))
    img = add(img, particles(size, accent, 36, 120, size * 0.14, size * 0.46))
    return img


def projectile_orb(size: int, color: tuple[int, int, int], accent: tuple[int, int, int], kind: str) -> Image.Image:
    img = new((size, size))
    img = add(img, glow_disc(size, color, 0.56, 0.04, 0.82))
    img = add(img, irregular_ring(size, color, size * 0.35, size * 0.075, 155, 80, 0.12, 1.4))
    img = add(img, glow_disc(size, accent, 0.85, 0.02, 0.38))
    draw = ImageDraw.Draw(img)
    c = size / 2
    if kind == "shard":
        pts = [(c, size * 0.08), (size * 0.70, c), (c, size * 0.92), (size * 0.30, c)]
        draw.polygon(pts, fill=rgba(color, 210))
        draw.line(pts + [pts[0]], fill=rgba(accent, 220), width=max(2, size // 30))
        draw.line((c, size * 0.08, c, size * 0.92), fill=rgba((255, 255, 255), 90), width=max(1, size // 42))
    elif kind == "lob":
        for i in range(6):
            a = math.tau * i / 6
            draw.ellipse((c + math.cos(a) * size * 0.23 - size * 0.045, c + math.sin(a) * size * 0.23 - size * 0.045, c + math.cos(a) * size * 0.23 + size * 0.045, c + math.sin(a) * size * 0.23 + size * 0.045), fill=rgba(accent, 120))
    return img


def shield(size: int) -> Image.Image:
    blue = (113, 181, 218)
    gold = (222, 172, 86)
    img = new((size, size))
    img = add(img, glow_disc(size, blue, 0.24, 0.05, 0.74))
    draw = ImageDraw.Draw(img)
    c = size / 2
    pts = [
        (c, size * 0.08),
        (size * 0.77, size * 0.22),
        (size * 0.70, size * 0.63),
        (c, size * 0.90),
        (size * 0.30, size * 0.63),
        (size * 0.23, size * 0.22),
    ]
    draw.polygon(pts, fill=rgba((42, 83, 118), 190))
    draw.line(pts + [pts[0]], fill=rgba(blue, 235), width=size // 22, joint="curve")
    draw.line((c, size * 0.14, c, size * 0.80), fill=rgba(gold, 150), width=size // 58)
    draw.arc((size * 0.28, size * 0.17, size * 0.72, size * 0.67), 205, 335, fill=rgba(gold, 135), width=size // 56)
    return img.filter(ImageFilter.GaussianBlur(0.15))


def shadow_trail() -> Image.Image:
    size = (256, 128)
    img = new(size)
    draw = ImageDraw.Draw(img)
    for i in range(7):
        y = 64 + RNG.uniform(-14, 14)
        pts = []
        for x in range(-20, 280, 24):
            pts.append((x, y + math.sin(x * 0.045 + i) * RNG.uniform(6, 15)))
        draw.line(pts, fill=(120, 75, 190, 65 - i * 5), width=18 - i, joint="curve")
    img = img.filter(ImageFilter.GaussianBlur(4.0))
    img = add(img, crack_lines(256, (182, 130, 255), 10, 80, inward=True).resize(size))
    return img


def preview(files: list[tuple[str, str]]) -> None:
    tile_w, tile_h = 210, 230
    cols = 5
    rows = math.ceil(len(files) / cols)
    sheet = Image.new("RGBA", (cols * tile_w, rows * tile_h), (26, 23, 31, 255))
    draw = ImageDraw.Draw(sheet)
    for idx, (label, filename) in enumerate(files):
        x = (idx % cols) * tile_w
        y = (idx // cols) * tile_h
        draw.rounded_rectangle((x + 8, y + 8, x + tile_w - 8, y + tile_h - 8), radius=8, outline=(112, 91, 66, 255), width=1, fill=(34, 30, 41, 255))
        asset = Image.open(EFFECTS / filename).convert("RGBA")
        asset.thumbnail((150, 150), Image.Resampling.LANCZOS)
        sheet.alpha_composite(asset, (x + (tile_w - asset.width) // 2, y + 28))
        draw.text((x + 14, y + 178), label[:27], fill=(235, 222, 196, 255))
        draw.text((x + 14, y + 198), filename[:30], fill=(148, 134, 116, 255))
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEWS / "scrum261_elite_boss_vfx_contact.png")


def save(img: Image.Image, filename: str) -> None:
    EFFECTS.mkdir(parents=True, exist_ok=True)
    img.save(EFFECTS / filename)


def main() -> None:
    purple = (116, 65, 209)
    violet = (175, 118, 255)
    red = (190, 38, 47)
    blood = (255, 86, 74)
    ember = (210, 75, 30)
    flame = (255, 172, 70)
    web = (210, 220, 200)
    sick = (112, 183, 80)
    acid = (140, 220, 82)
    teal = (80, 196, 206)
    bone = (205, 195, 170)
    gold = (235, 180, 78)

    outputs: list[tuple[str, str]] = []
    specs = [
        ("universal telegraph", "hazard_zone.png", zone("hazard", 256, (108, 84, 132), (224, 188, 115), "rift")),
        ("detonation ring", "impact_ring.png", irregular_ring(256, (235, 210, 145), 103, 14, 180, 132, 0.035, 1.4)),
        ("detonation flash", "impact_flash.png", glow_disc(128, (255, 236, 175), 0.78, 0.01, 0.82)),
        ("elite telegraph", "elite_telegraph_circle.png", zone("elite", 512, (112, 78, 139), (236, 185, 96), "rift")),
        ("elite shockwave", "elite_shockwave_ring.png", zone("shock", 512, (154, 127, 98), (255, 222, 150), "molten")),
        ("poison pool", "poison_pool.png", zone("poison", 256, (72, 142, 72), acid, "poison")),
        ("shadow trail", "elite_shadow_trail.png", shadow_trail()),
        ("poison lob", "elite_poison_lob.png", projectile_orb(96, sick, acid, "lob")),
        ("crystal shard", "elite_crystal_shard.png", projectile_orb(96, (94, 180, 212), (230, 248, 255), "shard")),
        ("gravity well", "boss_gravity_well_zone.png", zone("gravity", 512, purple, violet, "gravity")),
        ("vampiric bite", "boss_vampiric_bite_zone.png", zone("bite", 512, red, blood, "vampire")),
        ("rift zone", "boss_rift_zone.png", zone("rift", 512, purple, violet, "rift")),
        ("brood web", "boss_brood_web_zone.png", zone("web", 512, (125, 135, 118), web, "web")),
        ("ash ember", "boss_ash_ember_zone.png", zone("ember", 512, ember, flame, "ember")),
        ("molten pulse", "boss_molten_armor_pulse.png", zone("molten", 512, ember, flame, "molten")),
        ("bone prison", "boss_bone_prison_zone.png", zone("bone", 512, (132, 125, 110), bone, "bone")),
        ("summon portal", "enemy_summon_portal.png", zone("summon", 512, purple, violet, "summon")),
        ("shield block", "enemy_shield_block_front.png", shield(256)),
        ("thorn reflect", "enemy_reflect_thorns_aura.png", zone("thorns", 512, (71, 126, 116), (182, 230, 205), "bone")),
        ("command aura", "enemy_command_aura_pulse.png", zone("aura", 512, (142, 105, 39), gold, "rift")),
        ("shadow blink mark", "enemy_shadow_blink_mark.png", zone("blink", 512, (68, 51, 95), violet, "summon")),
        ("shard fan burst", "enemy_shard_fan_burst.png", zone("shard", 512, (70, 134, 170), (200, 242, 255), "rift")),
    ]
    for label, filename, img in specs:
        save(img, filename)
        outputs.append((label, filename))
    preview(outputs)


if __name__ == "__main__":
    main()
