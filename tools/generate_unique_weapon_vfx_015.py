#!/usr/bin/env python3
"""Generate SCRUM-258 weapon identity VFX plates and preview sheets.

The output is deterministic painterly-style RGBA PNG, one transparent VFX plate
per current FantasyDisk weapon id. The plates are deliberately texture assets:
runtime mechanics, timings and damage stay in GDScript.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
EFFECTS_DIR = ROOT / "assets/sprites/effects"
PREVIEW_DIR = ROOT / "docs/design/previews"

SIZE = 256


WEAPONS = [
    ("berserk", "sword", "arc", (120, 178, 255), "silver execution sweep"),
    ("berserk", "axe", "arc", (255, 122, 54), "brutal cleave sparks"),
    ("berserk", "hammer", "slam", (190, 166, 255), "cracked impact rune"),
    ("soldier", "soldier_rifle", "beam", (214, 188, 128), "suppression tracer"),
    ("soldier", "soldier_grenade", "burst", (244, 119, 48), "fuse grenade blast"),
    ("soldier", "soldier_bayonet", "lance", (118, 207, 255), "braced bayonet thrust"),
    ("thief", "thief_coin_pouch", "chain", (255, 196, 62), "ricochet gold path"),
    ("thief", "thief_shadow_cloak", "stab", (178, 76, 255), "phantom backstab"),
    ("thief", "thief_smoke_bomb", "cloud", (114, 124, 142), "smoke evasion bloom"),
    ("elementalist", "elementalist_orb_ring", "orbit", (88, 190, 255), "triune elemental orbit"),
    ("elementalist", "elementalist_prism_focus", "cross", (196, 100, 255), "prismatic rift cross"),
    ("elementalist", "elementalist_meteor_core", "meteor", (255, 100, 38), "meteor shard fall"),
    ("sniper", "sniper_deadeye_rifle", "mark", (224, 238, 255), "deadeye lock mark"),
    ("sniper", "sniper_spotter_scope", "reticle", (255, 156, 46), "spotter kill zone"),
    ("sniper", "sniper_shatter_rounds", "shards", (112, 212, 255), "shattering round fan"),
    ("priest", "priest_reliquary", "seal", (255, 226, 112), "holy reliquary seal"),
    ("priest", "priest_censer", "ward", (238, 255, 178), "censer ward pulse"),
    ("priest", "priest_chime", "chain", (176, 226, 255), "prayer chain"),
    ("biologist", "biologist_spore_lens", "spore", (124, 255, 106), "spore bloom rings"),
    ("biologist", "biologist_sample_injector", "dart", (174, 255, 82), "sample analysis dart"),
    ("biologist", "biologist_symbiote_seed", "web", (86, 226, 142), "symbiote network"),
    ("robot", "robot_magnetic_anchor", "magnet", (90, 192, 255), "magnetic anchor field"),
    ("robot", "robot_hydraulic_press", "press", (228, 174, 86), "hydraulic compression"),
    ("robot", "robot_reactor_core", "vent", (80, 255, 214), "reactor vent cross"),
    ("engineer", "engineer_sentry_wrench", "sentry", (218, 170, 76), "sentry link node"),
    ("engineer", "engineer_repair_drone", "chain", (112, 220, 255), "repair drone tether"),
    ("engineer", "engineer_pressure_mines", "mines", (255, 126, 58), "pressure mine grid"),
    ("dark_mage", "dark_book", "sigil", (118, 54, 230), "void book sigil"),
    ("dark_mage", "cursed_skull", "skull", (202, 58, 255), "cursed skull mark"),
    ("dark_mage", "dark_wand", "beam", (80, 230, 255), "piercing dark beam"),
    ("guitarist", "electric_guitar", "wave", (58, 235, 216), "electric resonance wave"),
    ("guitarist", "bass_guitar", "pulse", (255, 190, 58), "bass control pulse"),
    ("guitarist", "sound_amp", "amp", (255, 86, 176), "deployed amp aura"),
    ("assassin", "chakrams", "boomerang", (184, 82, 255), "returning blade corridor"),
    ("assassin", "shadow_daggers", "stab", (150, 58, 230), "shadow dagger flurry"),
    ("assassin", "venom_wire", "wire", (84, 242, 86), "poison garrote line"),
    ("ranger", "moon_crossbow", "lance", (188, 216, 255), "charged moon bolt"),
    ("ranger", "storm_longbow", "shards", (76, 176, 255), "storm arrow fan"),
    ("ranger", "hunter_trap", "trap", (216, 146, 58), "hunter trap teeth"),
    ("doctor", "restore_potion", "drain", (92, 235, 128), "restorative drain link"),
    ("doctor", "plague_syringe", "dart", (84, 234, 92), "plague syringe tether"),
    ("doctor", "bone_saw", "saw", (224, 62, 54), "blood saw risk arc"),
    ("chemist", "blast_powder", "burst", (170, 238, 58), "alchemical powder burst"),
    ("chemist", "acid_flask", "pool", (66, 242, 78), "acid pool splash"),
    ("chemist", "homunculus_vial", "summon", (132, 245, 116), "homunculus vial spawn"),
    ("knight", "long_spear", "lance", (194, 212, 238), "long spear oath"),
    ("knight", "tower_shield", "shield", (174, 184, 224), "tower shield bash"),
    ("knight", "holy_flail", "orbit", (255, 206, 72), "holy flail orbit"),
    ("druid", "summon_amulet", "summon", (118, 202, 94), "pack command amulet"),
    ("druid", "briar_staff", "briar", (86, 198, 76), "thorn field bloom"),
    ("druid", "raven_totem", "totem", (58, 178, 108), "raven totem pulse"),
]


def rgba(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return color[0], color[1], color[2], alpha


def blend(color: tuple[int, int, int], target: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(color[i] * (1.0 - t) + target[i] * t) for i in range(3))


def add_glow(base: Image.Image, mask: Image.Image, color: tuple[int, int, int], blur: float, alpha: int) -> None:
    glow = Image.new("RGBA", base.size, rgba(color, 0))
    glow.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda p: min(int(p * alpha / 255), alpha)))
    base.alpha_composite(glow)


def draw_polyline_mask(points: list[tuple[float, float]], width: int) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    draw.line(points, fill=255, width=width, joint="curve")
    return mask


def draw_ring(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: float, color: tuple[int, int, int], width: int, alpha: int) -> None:
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=rgba(color, alpha), width=width)


def arc_points(radius: float, start: float, end: float, count: int = 44) -> list[tuple[float, float]]:
    return [
        (SIZE / 2 + math.cos(start + (end - start) * i / (count - 1)) * radius,
         SIZE / 2 + math.sin(start + (end - start) * i / (count - 1)) * radius)
        for i in range(count)
    ]


def draw_arc(base: Image.Image, color: tuple[int, int, int], seed: int, wide: bool = False) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(base)
    points = arc_points(78 if not wide else 92, math.radians(205), math.radians(334), 48)
    mask = draw_polyline_mask(points, 18 if not wide else 24)
    add_glow(base, mask, color, 10, 150)
    draw.line(points, fill=rgba(blend(color, (255, 244, 210), 0.34), 220), width=11 if not wide else 15, joint="curve")
    draw.line(points, fill=rgba((42, 29, 24), 150), width=3, joint="curve")
    for _ in range(10):
        a = rng.uniform(math.radians(215), math.radians(330))
        r = rng.uniform(74, 103)
        p = (SIZE / 2 + math.cos(a) * r, SIZE / 2 + math.sin(a) * r)
        draw.line((p[0], p[1], p[0] + rng.uniform(10, 26), p[1] + rng.uniform(-8, 8)), fill=rgba(color, 110), width=2)


def draw_beam(base: Image.Image, color: tuple[int, int, int], seed: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(base)
    y = SIZE / 2
    mask = draw_polyline_mask([(30, y), (226, y + rng.uniform(-8, 8))], 18)
    add_glow(base, mask, color, 8, 150)
    draw.line((28, y, 228, y), fill=rgba(blend(color, (255, 250, 230), 0.45), 220), width=8)
    draw.line((36, y - 12, 212, y - 5), fill=rgba(color, 95), width=3)
    draw.line((36, y + 12, 212, y + 5), fill=rgba(color, 95), width=3)
    draw.polygon([(214, y), (185, y - 15), (192, y), (185, y + 15)], fill=rgba(color, 170))


def draw_burst(base: Image.Image, color: tuple[int, int, int], seed: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(base)
    mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(mask)
    for i in range(16):
        a = TAU * i / 16 + rng.uniform(-0.08, 0.08)
        inner = 28 + rng.uniform(-5, 5)
        outer = 78 + rng.uniform(-12, 16)
        p1 = (128 + math.cos(a - 0.045) * inner, 128 + math.sin(a - 0.045) * inner)
        p2 = (128 + math.cos(a) * outer, 128 + math.sin(a) * outer)
        p3 = (128 + math.cos(a + 0.045) * inner, 128 + math.sin(a + 0.045) * inner)
        md.polygon([p1, p2, p3], fill=210)
    md.ellipse((76, 76, 180, 180), fill=190)
    add_glow(base, mask, color, 12, 160)
    base.alpha_composite(Image.composite(Image.new("RGBA", base.size, rgba(color, 190)), Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))
    draw.ellipse((100, 100, 156, 156), fill=rgba(blend(color, (255, 245, 215), 0.45), 190))


def draw_orbit(base: Image.Image, color: tuple[int, int, int], seed: int) -> None:
    draw = ImageDraw.Draw(base)
    for idx, rot in enumerate([0, math.pi / 3, -math.pi / 3]):
        pts = []
        for i in range(60):
            a = TAU * i / 59
            x = math.cos(a) * 78
            y = math.sin(a) * 26
            xr = x * math.cos(rot) - y * math.sin(rot)
            yr = x * math.sin(rot) + y * math.cos(rot)
            pts.append((128 + xr, 128 + yr))
        c = blend(color, [(255, 120, 60), (90, 205, 255), (170, 94, 255)][idx], 0.45)
        mask = draw_polyline_mask(pts, 7)
        add_glow(base, mask, c, 5, 110)
        draw.line(pts, fill=rgba(c, 170), width=3, joint="curve")
    for a, c in [(0.1, (255, 116, 62)), (2.3, (96, 218, 255)), (4.4, (178, 92, 255))]:
        x, y = 128 + math.cos(a) * 74, 128 + math.sin(a) * 28
        draw.ellipse((x - 12, y - 12, x + 12, y + 12), fill=rgba(c, 210))


def draw_chain(base: Image.Image, color: tuple[int, int, int], seed: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(base)
    points = [(36, 138), (88, 96 + rng.uniform(-8, 8)), (134, 134), (184, 92 + rng.uniform(-6, 10)), (220, 128)]
    mask = draw_polyline_mask(points, 14)
    add_glow(base, mask, color, 7, 135)
    draw.line(points, fill=rgba(color, 185), width=7, joint="curve")
    for x, y in points[1:-1]:
        draw.ellipse((x - 11, y - 11, x + 11, y + 11), outline=rgba(blend(color, (255, 246, 220), 0.35), 220), width=4)


def draw_seal(base: Image.Image, color: tuple[int, int, int], seed: int, spiky: bool = False) -> None:
    draw = ImageDraw.Draw(base)
    mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse((58, 58, 198, 198), outline=220, width=14)
    if spiky:
        for i in range(12):
            a = TAU * i / 12
            p1 = (128 + math.cos(a - 0.07) * 62, 128 + math.sin(a - 0.07) * 62)
            p2 = (128 + math.cos(a) * 94, 128 + math.sin(a) * 94)
            p3 = (128 + math.cos(a + 0.07) * 62, 128 + math.sin(a + 0.07) * 62)
            md.polygon([p1, p2, p3], fill=175)
    add_glow(base, mask, color, 8, 140)
    base.alpha_composite(Image.composite(Image.new("RGBA", base.size, rgba(color, 185)), Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))
    draw_ring(draw, (128, 128), 58, blend(color, (255, 244, 210), 0.40), 4, 205)
    draw.line((128, 78, 128, 178), fill=rgba(blend(color, (255, 244, 210), 0.35), 175), width=5)
    draw.line((86, 148, 170, 108), fill=rgba(color, 145), width=4)


def draw_cloud(base: Image.Image, color: tuple[int, int, int], seed: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(base)
    mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(mask)
    for _ in range(16):
        x = rng.uniform(72, 184)
        y = rng.uniform(78, 170)
        r = rng.uniform(18, 36)
        md.ellipse((x - r, y - r, x + r, y + r), fill=rng.randint(95, 180))
    add_glow(base, mask, color, 10, 120)
    base.alpha_composite(Image.composite(Image.new("RGBA", base.size, rgba(color, 122)), Image.new("RGBA", base.size, (0, 0, 0, 0)), mask.filter(ImageFilter.GaussianBlur(2))))
    for _ in range(5):
        x, y = rng.uniform(78, 180), rng.uniform(92, 166)
        draw.arc((x - 22, y - 14, x + 22, y + 14), 190, 340, fill=rgba(blend(color, (255, 255, 255), 0.32), 70), width=2)


def draw_web(base: Image.Image, color: tuple[int, int, int], seed: int) -> None:
    draw = ImageDraw.Draw(base)
    center = (128, 128)
    for i in range(8):
        a = TAU * i / 8
        end = (128 + math.cos(a) * 88, 128 + math.sin(a) * 70)
        draw.line((center, end), fill=rgba(color, 135), width=3)
    for r in [28, 50, 74]:
        pts = [(128 + math.cos(TAU * i / 48) * r, 128 + math.sin(TAU * i / 48) * r * 0.78) for i in range(49)]
        draw.line(pts, fill=rgba(color, 122), width=3, joint="curve")
    add_glow(base, base.split()[-1], color, 7, 105)


def draw_totem(base: Image.Image, color: tuple[int, int, int], seed: int) -> None:
    draw = ImageDraw.Draw(base)
    draw_seal(base, color, seed, True)
    draw.polygon([(128, 50), (146, 110), (128, 202), (110, 110)], fill=rgba(blend(color, (25, 20, 18), 0.25), 170))
    draw.ellipse((112, 98, 144, 130), fill=rgba(blend(color, (255, 245, 210), 0.42), 210))


def draw_plate(kind: str, color: tuple[int, int, int], seed: int) -> Image.Image:
    base = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    if kind in ("arc", "stab", "saw", "boomerang"):
        draw_arc(base, color, seed, kind == "boomerang")
    elif kind in ("beam", "lance", "wire", "dart", "drain"):
        draw_beam(base, color, seed)
    elif kind in ("burst", "slam", "meteor", "shards"):
        draw_burst(base, color, seed)
    elif kind in ("orbit", "pulse", "wave", "vent"):
        draw_orbit(base, color, seed)
    elif kind in ("chain",):
        draw_chain(base, color, seed)
    elif kind in ("seal", "ward", "sigil", "mark", "reticle", "shield", "trap", "magnet", "sentry", "amp"):
        draw_seal(base, color, seed, kind in ("reticle", "trap", "magnet", "sentry"))
    elif kind in ("cloud", "pool", "spore", "briar", "summon"):
        draw_cloud(base, color, seed)
    elif kind in ("web", "cross", "press", "mines"):
        draw_web(base, color, seed)
    elif kind in ("skull",):
        draw_seal(base, color, seed, True)
        draw = ImageDraw.Draw(base)
        draw.ellipse((100, 92, 156, 150), fill=rgba(blend(color, (222, 220, 190), 0.55), 185))
        draw.ellipse((112, 112, 124, 124), fill=(20, 12, 18, 210))
        draw.ellipse((132, 112, 144, 124), fill=(20, 12, 18, 210))
        draw.rectangle((116, 146, 140, 166), fill=rgba(blend(color, (190, 180, 150), 0.35), 150))
    else:
        draw_totem(base, color, seed)

    # Painterly edge: soften the alpha but keep the center crisp.
    alpha = base.split()[-1].filter(ImageFilter.GaussianBlur(0.35))
    base.putalpha(alpha)
    return base


TAU = math.tau


def save_weapon_assets() -> None:
    EFFECTS_DIR.mkdir(parents=True, exist_ok=True)
    for index, (_class_id, weapon_id, kind, color, _desc) in enumerate(WEAPONS):
        plate = draw_plate(kind, color, 1500 + index * 17)
        plate.save(EFFECTS_DIR / f"vfx_weapon_{weapon_id}.png")


def make_preview() -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    cols = 6
    cell_w = 236
    cell_h = 196
    rows = math.ceil(len(WEAPONS) / cols)
    preview = Image.new("RGBA", (cols * cell_w, rows * cell_h), (19, 18, 16, 255))
    draw = ImageDraw.Draw(preview)
    for i in range(0, preview.width, 32):
        draw.line((i, 0, i - 96, preview.height), fill=(35, 33, 29, 255), width=1)
    for idx, (class_id, weapon_id, kind, color, desc) in enumerate(WEAPONS):
        x = (idx % cols) * cell_w
        y = (idx // cols) * cell_h
        draw.rounded_rectangle((x + 12, y + 12, x + cell_w - 12, y + cell_h - 12), radius=8, fill=(29, 25, 22, 255), outline=(92, 74, 44, 255), width=2)
        plate = Image.open(EFFECTS_DIR / f"vfx_weapon_{weapon_id}.png").convert("RGBA")
        preview.alpha_composite(plate.resize((128, 128), Image.Resampling.LANCZOS), (x + 54, y + 20))
        draw.text((x + 18, y + 148), weapon_id[:28], fill=(234, 220, 184, 255))
        draw.text((x + 18, y + 166), f"{class_id} / {kind}", fill=(156, 180, 174, 255))
    preview.save(PREVIEW_DIR / "scrum258_unique_weapon_vfx_contact.png")

    # Readability strip over two real battle backgrounds.
    bg_paths = [ROOT / "assets/backgrounds/field_meadow.png", ROOT / "assets/backgrounds/field_marsh.png"]
    strip = Image.new("RGBA", (1536, 512), (0, 0, 0, 255))
    for bg_idx, bg_path in enumerate(bg_paths):
        if bg_path.exists():
            bg = Image.open(bg_path).convert("RGBA").resize((768, 512), Image.Resampling.LANCZOS)
        else:
            bg = Image.new("RGBA", (768, 512), (44, 52, 42, 255))
        strip.alpha_composite(bg, (bg_idx * 768, 0))
    sample = [0, 4, 8, 10, 14, 17, 20, 23, 26, 30, 34, 38, 42, 47, 50]
    for bg_idx in range(2):
        for n, idx in enumerate(sample):
            _, weapon_id, _kind, _color, _desc = WEAPONS[idx]
            plate = Image.open(EFFECTS_DIR / f"vfx_weapon_{weapon_id}.png").convert("RGBA").resize((82, 82), Image.Resampling.LANCZOS)
            px = bg_idx * 768 + 28 + (n % 5) * 145
            py = 36 + (n // 5) * 148
            strip.alpha_composite(plate, (px, py))
    strip.save(PREVIEW_DIR / "scrum258_unique_weapon_vfx_readability.png")


def main() -> None:
    save_weapon_assets()
    make_preview()
    print(f"generated {len(WEAPONS)} weapon VFX assets")
    print(PREVIEW_DIR / "scrum258_unique_weapon_vfx_contact.png")
    print(PREVIEW_DIR / "scrum258_unique_weapon_vfx_readability.png")


if __name__ == "__main__":
    main()
