"""Generate unique class weapon and elite/boss skill VFX sprites.

Design tasks:
- SCRUM-258 / design_codex_unique_weapons_vfx_all_classes_015_task.md
- SCRUM-261 / design_codex_elite_boss_new_skills_vfx_task.md

The output is deterministic painterly D&D/tabletop VFX with transparent alpha.
These files are a named Design kit for Back-end integration; no gameplay logic
is changed by this generator.

Run from project root:
    python3 tools/generate_unique_weapon_enemy_vfx.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
EFFECTS = ROOT / "assets" / "sprites" / "effects"
PREVIEWS = ROOT / "docs" / "design" / "previews"

INK = (25, 20, 28, 210)
WARM = (226, 184, 96)
VIOLET = (148, 76, 220)
GREEN = (96, 178, 96)
RED = (214, 70, 48)
BLUE = (108, 170, 220)
CYAN = (96, 220, 220)
GOLD = (246, 205, 112)
PALE = (232, 225, 202)


def canvas(size: tuple[int, int] | int) -> Image.Image:
    if isinstance(size, int):
        size = (size, size)
    return Image.new("RGBA", size, (0, 0, 0, 0))


def save(img: Image.Image, name: str) -> None:
    EFFECTS.mkdir(parents=True, exist_ok=True)
    img = fade_edges(img)
    img.save(EFFECTS / name)
    print("wrote", name, img.size)


def fade_edges(img: Image.Image, margin: int = 10) -> Image.Image:
    """Keep antialiased alpha but guarantee clean transparent texture borders."""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    w, h = img.size
    alpha = img.getchannel("A")
    mask = Image.new("L", img.size, 255)
    pixels = mask.load()
    for y in range(h):
        dy = min(y, h - 1 - y)
        for x in range(w):
            d = min(x, w - 1 - x, dy)
            if d < margin:
                pixels[x, y] = int(255 * (d / float(margin)))
    alpha = Image.composite(alpha, Image.new("L", img.size, 0), mask)
    out = img.copy()
    out.putalpha(alpha)
    return out


def rgba(rgb: tuple[int, int, int], a: int) -> tuple[int, int, int, int]:
    return (rgb[0], rgb[1], rgb[2], a)


def add_glow(img: Image.Image, box: tuple[float, float, float, float], color: tuple[int, int, int], alpha: int, blur: float) -> None:
    layer = canvas(img.size)
    ImageDraw.Draw(layer).ellipse(box, fill=rgba(color, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def rough_ring(
    img: Image.Image,
    center: tuple[float, float],
    inner: float,
    outer: float,
    color: tuple[int, int, int],
    alpha: int,
    *,
    seed: int,
    jitter: float = 4.0,
    blur: float = 1.4,
    steps: int = 96,
) -> None:
    rng = random.Random(seed)
    ring = canvas(img.size)
    d = ImageDraw.Draw(ring)
    ox, oy = center
    outer_pts = []
    inner_pts = []
    for i in range(steps):
        ang = math.tau * i / steps
        ro = outer + rng.uniform(-jitter, jitter)
        ri = inner + rng.uniform(-jitter, jitter)
        outer_pts.append((ox + math.cos(ang) * ro, oy + math.sin(ang) * ro))
        inner_pts.append((ox + math.cos(ang) * ri, oy + math.sin(ang) * ri))
    d.polygon(outer_pts, fill=rgba(color, alpha))
    mask = canvas(img.size)
    ImageDraw.Draw(mask).polygon(inner_pts, fill=(255, 255, 255, 255))
    ring = Image.composite(canvas(img.size), ring, mask.split()[3])
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(blur)))


def star_flash(size: int, color: tuple[int, int, int], seed: int, spikes: int = 12) -> Image.Image:
    img = canvas(size)
    c = size / 2
    add_glow(img, (c - size * 0.36, c - size * 0.36, c + size * 0.36, c + size * 0.36), color, 130, size * 0.055)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    for i in range(spikes):
        ang = math.tau * i / spikes + rng.uniform(-0.04, 0.04)
        length = rng.uniform(size * 0.22, size * 0.43)
        width = rng.uniform(size * 0.025, size * 0.05)
        tip = (c + math.cos(ang) * length, c + math.sin(ang) * length)
        left = (c + math.cos(ang + math.pi / 2) * width, c + math.sin(ang + math.pi / 2) * width)
        right = (c + math.cos(ang - math.pi / 2) * width, c + math.sin(ang - math.pi / 2) * width)
        d.polygon([left, tip, right], fill=rgba(color, 165))
    d.ellipse((c - size * 0.07, c - size * 0.07, c + size * 0.07, c + size * 0.07), fill=rgba(PALE, 225))
    return img.filter(ImageFilter.GaussianBlur(0.6))


def sigil(name: str, color: tuple[int, int, int], seed: int, *, size: int = 256, motifs: str = "runes") -> None:
    img = canvas(size)
    c = size / 2
    add_glow(img, (c - 92, c - 92, c + 92, c + 92), color, 88, 16)
    rough_ring(img, (c, c), 70, 82, color, 190, seed=seed, jitter=3.5)
    rough_ring(img, (c, c), 38, 44, PALE, 92, seed=seed + 1, jitter=2.0, blur=0.8)
    d = ImageDraw.Draw(img)
    for i in range(8):
        ang = math.tau * i / 8
        p1 = (c + math.cos(ang) * 49, c + math.sin(ang) * 49)
        p2 = (c + math.cos(ang + math.pi / 8) * 18, c + math.sin(ang + math.pi / 8) * 18)
        d.line((p1, p2), fill=rgba(color, 180), width=4)
    if motifs == "thorns":
        for i in range(12):
            ang = math.tau * i / 12
            x = c + math.cos(ang) * 86
            y = c + math.sin(ang) * 86
            tip = (c + math.cos(ang) * 104, c + math.sin(ang) * 104)
            d.line((x, y, tip[0], tip[1]), fill=rgba(GREEN, 160), width=4)
    elif motifs == "metal":
        for i in range(4):
            ang = math.tau * i / 4 + math.pi / 4
            d.line((c, c, c + math.cos(ang) * 92, c + math.sin(ang) * 92), fill=rgba(GOLD, 150), width=5)
    else:
        for i in range(12):
            ang = math.tau * i / 12
            x = c + math.cos(ang) * 96
            y = c + math.sin(ang) * 96
            d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=rgba(PALE, 170))
    save(img, name)


def streak(name: str, color: tuple[int, int, int], seed: int, *, size: tuple[int, int] = (256, 128), coins: bool = False) -> None:
    img = canvas(size)
    w, h = size
    rng = random.Random(seed)
    blobs = canvas(size)
    d = ImageDraw.Draw(blobs)
    for i in range(35):
        t = i / 34
        x = 12 + t * (w - 24)
        y = h * 0.5 + math.sin(t * math.tau * 1.5) * 7 + rng.uniform(-8, 8)
        r = rng.uniform(8, 23) * (0.35 + t * 0.9)
        d.ellipse((x - r, y - r * 0.45, x + r, y + r * 0.45), fill=rgba(color, int(28 + t * 145)))
    img.alpha_composite(blobs.filter(ImageFilter.GaussianBlur(3.1)))
    d = ImageDraw.Draw(img)
    for _ in range(7):
        x = rng.uniform(w * 0.35, w * 0.92)
        y = rng.uniform(h * 0.32, h * 0.68)
        d.line((x - 28, y + rng.uniform(-5, 5), x + 14, y + rng.uniform(-5, 5)), fill=rgba(PALE, 130), width=3)
    if coins:
        for _ in range(4):
            x = rng.uniform(w * 0.3, w * 0.86)
            y = rng.uniform(h * 0.36, h * 0.64)
            d.ellipse((x - 8, y - 8, x + 8, y + 8), fill=rgba(INK[:3], 180))
            d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=rgba(GOLD, 230))
    save(img, name)


def beam_plate(name: str, color: tuple[int, int, int], seed: int, *, size: tuple[int, int] = (256, 64), nodes: bool = False) -> None:
    img = canvas(size)
    w, h = size
    mid = h / 2
    add_glow(img, (8, mid - 24, w - 8, mid + 24), color, 92, 7)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((12, mid - 8, w - 12, mid + 8), radius=8, fill=rgba(color, 205))
    d.rounded_rectangle((24, mid - 3, w - 24, mid + 3), radius=3, fill=rgba(PALE, 190))
    rng = random.Random(seed)
    for _ in range(6):
        x = rng.uniform(22, w - 22)
        d.line((x, mid - 20, x + rng.uniform(-12, 12), mid + 20), fill=rgba(color, 115), width=2)
    if nodes:
        for x in (42, w - 42):
            d.ellipse((x - 11, mid - 11, x + 11, mid + 11), fill=rgba(INK[:3], 170))
            d.ellipse((x - 7, mid - 7, x + 7, mid + 7), fill=rgba(PALE, 220))
    save(img, name)


def pool(name: str, color: tuple[int, int, int], seed: int, *, size: int = 512, kind: str = "pool") -> None:
    img = canvas(size)
    rng = random.Random(seed)
    c = size / 2
    add_glow(img, (c - 205, c - 160, c + 205, c + 160), color, 78, 22)
    d = ImageDraw.Draw(img)
    for i in range(11):
        rx = rng.uniform(62, 120)
        ry = rng.uniform(34, 76)
        x = c + rng.uniform(-120, 120)
        y = c + rng.uniform(-70, 70)
        a = int(rng.uniform(80, 150))
        d.ellipse((x - rx, y - ry, x + rx, y + ry), fill=rgba(color, a))
    rough_ring(img, (c, c), 142, 176, color, 135, seed=seed + 50, jitter=16, blur=3.0)
    if kind == "web":
        for i in range(14):
            ang = math.tau * i / 14
            d.line((c, c, c + math.cos(ang) * 175, c + math.sin(ang) * 132), fill=rgba(PALE, 90), width=3)
    elif kind == "fire":
        for i in range(18):
            x = c + rng.uniform(-150, 150)
            y = c + rng.uniform(-80, 80)
            d.polygon([(x, y - 28), (x + 14, y + 20), (x - 14, y + 18)], fill=rgba((255, 128, 48), 120))
    elif kind == "gravity":
        for r in (54, 92, 132):
            d.arc((c - r, c - r, c + r, c + r), 20, 310, fill=rgba(PALE, 105), width=4)
    else:
        for _ in range(18):
            x = c + rng.uniform(-150, 150)
            y = c + rng.uniform(-95, 95)
            r = rng.uniform(4, 12)
            d.ellipse((x - r, y - r, x + r, y + r), fill=rgba(PALE, 95))
    save(img, name)


def shield(name: str, color: tuple[int, int, int], seed: int, *, size: int = 512) -> None:
    img = canvas(size)
    c = size / 2
    add_glow(img, (c - 175, c - 205, c + 175, c + 205), color, 80, 19)
    d = ImageDraw.Draw(img)
    pts = [(c, 38), (c + 150, 106), (c + 124, 318), (c, 466), (c - 124, 318), (c - 150, 106)]
    d.polygon([(x + 4, y + 4) for x, y in pts], fill=rgba(INK[:3], 140))
    d.polygon(pts, fill=rgba(color, 120))
    for inset, alpha in [(30, 170), (62, 105)]:
        d.arc((c - 164 + inset, 44 + inset, c + 164 - inset, 460 - inset), 210, -30, fill=rgba(PALE, alpha), width=8)
    for i in range(6):
        ang = math.tau * i / 6 + math.pi / 6
        d.line((c, c, c + math.cos(ang) * 142, c + math.sin(ang) * 172), fill=rgba(PALE, 75), width=4)
    save(img, name)


def portal(name: str, color: tuple[int, int, int], seed: int, *, size: int = 512) -> None:
    img = canvas(size)
    rng = random.Random(seed)
    c = size / 2
    for i, r in enumerate((186, 150, 112, 72)):
        rough_ring(img, (c, c), r - 12, r + 4, color if i % 2 == 0 else PALE, 125 - i * 18, seed=seed + i, jitter=9, blur=2.0)
    d = ImageDraw.Draw(img)
    for _ in range(24):
        ang = rng.uniform(0, math.tau)
        r = rng.uniform(86, 198)
        x = c + math.cos(ang) * r
        y = c + math.sin(ang) * r
        d.line((x, y, x + math.cos(ang + 0.8) * 28, y + math.sin(ang + 0.8) * 28), fill=rgba(color, 140), width=4)
    add_glow(img, (c - 58, c - 58, c + 58, c + 58), color, 140, 14)
    save(img, name)


def spikes(name: str, color: tuple[int, int, int], seed: int, *, size: int = 512) -> None:
    img = canvas(size)
    rng = random.Random(seed)
    c = size / 2
    add_glow(img, (c - 180, c - 150, c + 180, c + 150), color, 72, 20)
    d = ImageDraw.Draw(img)
    for _ in range(22):
        ang = rng.uniform(0, math.tau)
        dist = rng.uniform(42, 172)
        x = c + math.cos(ang) * dist
        y = c + math.sin(ang) * dist
        h = rng.uniform(44, 90)
        w = rng.uniform(12, 26)
        pts = [(x, y - h), (x + w, y + h * 0.2), (x - w, y + h * 0.2)]
        d.polygon([(px + 3, py + 3) for px, py in pts], fill=rgba(INK[:3], 155))
        d.polygon(pts, fill=rgba(color, 205))
        d.line((x - w * 0.25, y - h * 0.55, x + w * 0.25, y + h * 0.05), fill=rgba(PALE, 135), width=3)
    rough_ring(img, (c, c), 128, 154, color, 118, seed=seed + 4, jitter=10, blur=2.0)
    save(img, name)


def generate_class_vfx() -> list[str]:
    specs = [
        ("vfx_class_berserk_fury_arc.png", RED, 101, "metal"),
        ("vfx_class_dark_mage_void_sigil.png", VIOLET, 102, "runes"),
        ("vfx_class_guitarist_resonance_wave.png", GOLD, 103, "runes"),
        ("vfx_class_assassin_shadow_dash.png", (104, 72, 140), 104, "streak"),
        ("vfx_class_ranger_focus_mark.png", GREEN, 105, "runes"),
        ("vfx_class_doctor_drain_link.png", GREEN, 106, "beam"),
        ("vfx_class_chemist_combo_burst.png", (226, 138, 58), 107, "burst"),
        ("vfx_class_knight_counter_guard.png", BLUE, 108, "shield"),
        ("vfx_class_druid_command_bloom.png", GREEN, 109, "thorns"),
        ("vfx_class_soldier_suppression_tracer.png", WARM, 110, "beam"),
        ("vfx_class_thief_ricochet_coin_trail.png", GOLD, 111, "coins"),
        ("vfx_class_elementalist_orbit_triune.png", CYAN, 112, "runes"),
        ("vfx_class_sniper_deadeye_mark.png", RED, 113, "runes"),
        ("vfx_class_priest_sanctify_seal.png", GOLD, 114, "runes"),
        ("vfx_class_biologist_spore_bloom.png", GREEN, 115, "pool"),
        ("vfx_class_robot_magnetic_anchor_field.png", BLUE, 116, "metal"),
        ("vfx_class_engineer_sentry_link.png", (190, 144, 86), 117, "beam"),
    ]
    out: list[str] = []
    for name, color, seed, kind in specs:
        if kind == "streak":
            streak(name, color, seed)
        elif kind == "coins":
            streak(name, color, seed, coins=True)
        elif kind == "beam":
            beam_plate(name, color, seed, nodes=name.endswith("sentry_link.png"))
        elif kind == "burst":
            img = star_flash(256, color, seed, spikes=18)
            rough_ring(img, (128, 128), 74, 93, color, 120, seed=seed + 2, jitter=8, blur=2.0)
            save(img, name)
        elif kind == "shield":
            shield(name, color, seed, size=256)
        elif kind == "pool":
            pool(name, color, seed, size=256)
        else:
            sigil(name, color, seed, motifs=kind)
        out.append(name)
    return out


def generate_enemy_vfx() -> list[str]:
    specs = [
        ("vfx_enemy_command_aura_pulse.png", GOLD, 201, "sigil"),
        ("vfx_enemy_fire_pool.png", (226, 86, 42), 202, "fire"),
        ("vfx_enemy_acid_pool.png", GREEN, 203, "pool"),
        ("vfx_enemy_poison_pool_heavy.png", (112, 174, 66), 204, "pool"),
        ("vfx_enemy_teleport_gate_in.png", VIOLET, 205, "portal"),
        ("vfx_enemy_teleport_gate_out.png", CYAN, 206, "portal"),
        ("vfx_enemy_shield_block_front.png", BLUE, 207, "shield"),
        ("vfx_enemy_summon_portal.png", VIOLET, 208, "portal"),
        ("vfx_enemy_slow_gravity_zone.png", (112, 100, 172), 209, "gravity"),
        ("vfx_boss_bone_archon_bone_spikes.png", PALE, 210, "spikes"),
        ("vfx_boss_brood_mother_web_zone.png", (190, 190, 170), 211, "web"),
        ("vfx_boss_ashen_colossus_ember_slam.png", (226, 92, 45), 212, "fire"),
        ("vfx_elite_shadow_blink_mark.png", (104, 70, 152), 213, "small_portal"),
        ("vfx_elite_plague_bell_aura.png", (140, 196, 70), 214, "sigil"),
        ("vfx_elite_spark_wight_static_field.png", BLUE, 215, "sigil"),
    ]
    out: list[str] = []
    for name, color, seed, kind in specs:
        if kind == "sigil":
            sigil(name, color, seed, size=512 if name.startswith("vfx_enemy") or name.startswith("vfx_elite") else 256)
        elif kind == "portal":
            portal(name, color, seed)
        elif kind == "small_portal":
            portal(name, color, seed, size=256)
        elif kind == "shield":
            shield(name, color, seed)
        elif kind == "spikes":
            spikes(name, color, seed)
        elif kind in {"fire", "web", "gravity", "pool"}:
            pool(name, color, seed, kind=kind)
        out.append(name)
    return out


def make_contact(names: list[str], title: str, output: str, columns: int = 5) -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    cell_w, cell_h = 238, 258
    rows = math.ceil(len(names) / columns)
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h + 48), (23, 20, 27, 255))
    d = ImageDraw.Draw(sheet)
    d.text((18, 14), title, fill=(235, 220, 190, 255), font=ImageFont.load_default())
    for idx, name in enumerate(names):
        img = Image.open(EFFECTS / name).convert("RGBA")
        max_side = 158
        scale = min(max_side / img.width, max_side / img.height, 1.0)
        thumb = img.resize((int(img.width * scale), int(img.height * scale)), Image.Resampling.LANCZOS)
        x = (idx % columns) * cell_w
        y = (idx // columns) * cell_h + 48
        # dark + subtle checker center for alpha readability
        d.rounded_rectangle((x + 10, y + 10, x + cell_w - 10, y + cell_h - 12), radius=8, fill=(34, 30, 40, 255), outline=(88, 74, 58, 255), width=1)
        px = x + (cell_w - thumb.width) // 2
        py = y + 18 + (166 - thumb.height) // 2
        sheet.alpha_composite(thumb, (px, py))
        label = name.replace("vfx_", "").replace(".png", "")
        chunks = [label[i:i + 25] for i in range(0, len(label), 25)]
        for line, chunk in enumerate(chunks[:3]):
            d.text((x + 16, y + 190 + line * 16), chunk, fill=(230, 216, 188, 255), font=ImageFont.load_default())
        d.text((x + 16, y + cell_h - 32), f"{img.width}x{img.height}", fill=(154, 138, 112, 255), font=ImageFont.load_default())
    sheet.save(PREVIEWS / output)
    print("wrote", output)


def make_readability_preview(names: list[str]) -> None:
    bg_path = ROOT / "assets" / "backgrounds" / "field_meadow.png"
    if not bg_path.exists():
        return
    bg = Image.open(bg_path).convert("RGBA").resize((1280, 720), Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(bg)
    positions = [(180, 180), (420, 220), (680, 180), (900, 250), (260, 500), (560, 500), (860, 480)]
    for name, pos in zip(names, positions):
        img = Image.open(EFFECTS / name).convert("RGBA")
        scale = 0.42 if img.width >= 512 else 0.72
        thumb = img.resize((int(img.width * scale), int(img.height * scale)), Image.Resampling.LANCZOS)
        bg.alpha_composite(thumb, (int(pos[0] - thumb.width / 2), int(pos[1] - thumb.height / 2)))
        d.text((pos[0] - 70, pos[1] + thumb.height / 2 + 8), name.replace("vfx_", "").replace(".png", "")[:24], fill=(240, 230, 200, 255), font=ImageFont.load_default())
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    bg.save(PREVIEWS / "unique_enemy_vfx_readability_field_meadow.png")
    print("wrote unique_enemy_vfx_readability_field_meadow.png")


def main() -> None:
    class_names = generate_class_vfx()
    enemy_names = generate_enemy_vfx()
    make_contact(class_names, "SCRUM-258: Unique class weapon/attack VFX kit", "unique_weapons_vfx_contact.png", columns=5)
    make_contact(enemy_names, "SCRUM-261: Elite/boss skill VFX + telegraph kit", "elite_boss_skills_vfx_contact.png", columns=5)
    make_readability_preview([
        "vfx_enemy_fire_pool.png",
        "vfx_enemy_shield_block_front.png",
        "vfx_enemy_teleport_gate_in.png",
        "vfx_boss_bone_archon_bone_spikes.png",
        "vfx_class_priest_sanctify_seal.png",
        "vfx_class_robot_magnetic_anchor_field.png",
        "vfx_class_doctor_drain_link.png",
    ])


if __name__ == "__main__":
    main()
