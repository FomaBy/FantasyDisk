"""Redraw all artifact icons in a darker painted artifact style.

Direct user request, 2026-06-11:
    delete/replace all artifact icons and draw each anew in dark-fantasy style
    using the supplied "Dark Artifacts" reference sheet.

The generated files are deterministic 256x256 RGBA PNGs with transparent
backgrounds. Godot .import sidecars are intentionally left untouched.
"""
from __future__ import annotations

import ast
import math
import random
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_artifact_shop_cursor_assets as kit  # noqa: E402
import generate_dark_fantasy_artifact_icons as dark_source  # noqa: E402


ARTIFACT_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"
PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_dark_artifacts_40px_preview.png"
OUTPUT_SIZE = 256

ARCANE_VIOLET = (161, 69, 255, 255)
CURSED_GREEN = (91, 232, 80, 255)
BLOOD_RED = (221, 38, 58, 255)
EMBER_ORANGE = (255, 115, 30, 255)
SPECTRAL_CYAN = (77, 221, 235, 255)
DULL_GOLD = (196, 142, 62, 255)
BONE = (202, 181, 142, 255)
BLACK_IRON = (42, 39, 49, 255)


def clamp(value: float) -> int:
    return max(0, min(255, int(round(value))))


def mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(4))


def lighten(color: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    return (clamp(color[0] + amount), clamp(color[1] + amount), clamp(color[2] + amount), color[3])


def darken(color: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    return (clamp(color[0] - amount), clamp(color[1] - amount), clamp(color[2] - amount), color[3])


def parse_artifacts() -> list[dict]:
    text = (ROOT / "scripts" / "progression_data_content.gd").read_text(encoding="utf-8")
    block = text.split("const ARTIFACTS := [", 1)[1].split("\n]", 1)[0]
    artifacts: list[dict] = []
    for raw in re.findall(r"\{[^\n]+\}", block):
        safe = re.sub(r"Color\([^)]+\)", '"Color"', raw)
        safe = re.sub(r"\btrue\b", "True", safe)
        safe = re.sub(r"\bfalse\b", "False", safe)
        safe = re.sub(r"\bnull\b", "None", safe)
        artifacts.append(ast.literal_eval(safe))
    return artifacts


def draw_poly(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill, outline=kit.OUTLINE, width: int = 5) -> None:
    scaled = [(kit.sc(x), kit.sc(y)) for x, y in pts]
    if outline and width > 0:
        draw.line(scaled + [scaled[0]], fill=outline, width=kit.sc(width), joint="curve")
    draw.polygon(scaled, fill=fill)


def draw_line(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill, width: int = 5) -> None:
    draw.line([(kit.sc(x), kit.sc(y)) for x, y in pts], fill=fill, width=kit.sc(width), joint="curve")


def artifact_accent(kind: str, tier: int) -> tuple[int, int, int, int]:
    if any(token in kind for token in ["blood", "rage", "heart", "crown", "sigil"]):
        return BLOOD_RED
    if any(token in kind for token in ["root", "thorn", "leech", "summoner"]):
        return CURSED_GREEN
    if any(token in kind for token in ["ember", "burning", "whetstone"]):
        return EMBER_ORANGE
    if any(token in kind for token in ["glass", "hawk", "swift", "split", "phantom", "echo"]):
        return SPECTRAL_CYAN if tier < 3 else ARCANE_VIOLET
    if any(token in kind for token in ["void", "dark", "ink", "skull", "codex", "ash"]):
        return ARCANE_VIOLET
    if any(token in kind for token in ["coin", "route", "charm", "amulet", "belt", "bell"]):
        return DULL_GOLD
    return kit.ARTIFACT_ACCENTS.get(kind, ARCANE_VIOLET)


def material_group(kind: str) -> str:
    if kind in {"old_codex", "survival_manual", "ash_page"}:
        return "cursed_paper"
    if kind in {"skull_resonator", "stone_heart", "heavy_totem"}:
        return "bone_stone"
    if kind in {"fox_boots", "fast_boots", "war_belt", "splinter_gloves", "heavy_grip", "greedy_purse"}:
        return "black_leather"
    if kind in {"quickstring", "copper_string", "bass_cable"}:
        return "chain_cord"
    if kind in {"glass_orb", "dark_crystal", "ember_core", "burning_shard", "glass_edge", "split_core", "echo_core"}:
        return "arcane_glass"
    if kind in {"living_root", "banner_seed", "thorn_pact"}:
        return "root_bone"
    return "blackened_metal"


def source_for(kind: str, tier: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    src, _ = dark_source.draw_source(kind)
    accent = artifact_accent(kind, tier)
    img = src.copy()
    d = ImageDraw.Draw(img)

    # Redraw the new legendary artifacts so they are not inherited from copied placeholders.
    if kind == "echo_core":
        img = dark_source.transparent_source()
        kit.draw_orb(img, (82, 31, 120, 230), True)
        d = ImageDraw.Draw(img)
        for box, width in [((24, 23, 104, 103), 5), ((14, 13, 114, 113), 3)]:
            d.arc(tuple(kit.sc(v) for v in box), 300, 78, fill=SPECTRAL_CYAN, width=kit.sc(width))
    elif kind == "split_core":
        img = dark_source.transparent_source()
        d = ImageDraw.Draw(img)
        draw_poly(d, [(56, 17), (83, 47), (73, 105), (44, 91), (35, 45)], (64, 23, 105, 255), kit.OUTLINE, 5)
        draw_poly(d, [(78, 22), (101, 52), (86, 106), (62, 91), (58, 49)], (39, 122, 137, 235), kit.OUTLINE, 5)
    elif kind == "blood_pact":
        img = dark_source.transparent_source()
        kit.draw_book(img, (45, 38, 39, 255))
        kit.draw_heart(img, (128, 12, 29, 255), fragile=True)
    elif kind == "leech_heart":
        img = dark_source.transparent_source()
        kit.draw_heart(img, (110, 19, 32, 255))
        d = ImageDraw.Draw(img)
        for pts in [[(44, 82), (28, 98), (21, 114)], [(83, 80), (101, 94), (109, 113)], [(61, 92), (57, 111), (50, 120)]]:
            draw_line(d, pts, (38, 100, 44, 255), 6)
            draw_line(d, pts, CURSED_GREEN, 2)
    elif kind == "thorn_pact":
        img = dark_source.transparent_source()
        kit.draw_heart(img, (88, 28, 34, 255), fragile=True)
        d = ImageDraw.Draw(img)
        for angle in range(5, 360, 30):
            rad = math.radians(angle)
            draw_line(d, [(64, 65), (64 + math.cos(rad) * 48, 65 + math.sin(rad) * 42)], (34, 82, 31, 230), 3)
    elif kind == "phantom_step":
        img = dark_source.transparent_source()
        kit.draw_boots(img, (38, 43, 56, 255), True)
        d = ImageDraw.Draw(img)
        d.arc((kit.sc(12), kit.sc(30), kit.sc(121), kit.sc(112)), 202, 330, fill=SPECTRAL_CYAN, width=kit.sc(5))

    return img, accent


def strip_soft_source(src: Image.Image) -> Image.Image:
    alpha = src.split()[3]
    alpha = alpha.point(lambda v: 0 if v < 58 else min(255, int((v - 58) * 255 / 197)))
    out = src.copy()
    out.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.25)))
    return out


def scaled_layer(src: Image.Image, kind: str) -> Image.Image:
    alpha = src.split()[3]
    bbox = alpha.getbbox()
    if not bbox:
        raise ValueError(f"empty source for {kind}")
    pad = kit.sc(7)
    bbox = (
        max(0, bbox[0] - pad),
        max(0, bbox[1] - pad),
        min(src.width, bbox[2] + pad),
        min(src.height, bbox[3] + pad),
    )
    cropped = src.crop(bbox)
    target = 232 if cropped.width > cropped.height * 1.9 else 222
    scale = min(target / cropped.width, target / cropped.height)
    resized = cropped.resize((round(cropped.width * scale), round(cropped.height * scale)), Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    layer.alpha_composite(resized, ((OUTPUT_SIZE - resized.width) // 2, (OUTPUT_SIZE - resized.height) // 2 - 2))
    return layer


def material_palette(kind: str, accent: tuple[int, int, int, int]) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int], tuple[int, int, int, int]]:
    group = material_group(kind)
    if group == "cursed_paper":
        return (darken(BONE, 42), (44, 35, 31, 255), accent)
    if group == "bone_stone":
        return (BONE, (48, 45, 42, 255), accent)
    if group == "black_leather":
        return ((91, 52, 39, 255), (22, 19, 25, 255), accent)
    if group == "chain_cord":
        return ((102, 81, 74, 255), (21, 19, 25, 255), accent)
    if group == "arcane_glass":
        return (mix(accent, (190, 180, 210, 255), 0.34), (16, 15, 26, 255), accent)
    if group == "root_bone":
        return ((91, 70, 44, 255), (23, 22, 20, 255), accent)
    return ((92, 83, 83, 255), BLACK_IRON, accent)


def paint_material(layer: Image.Image, kind: str, accent: tuple[int, int, int, int], seed: int) -> Image.Image:
    rng = random.Random(seed)
    alpha = layer.split()[3]
    bbox = alpha.getbbox() or (24, 24, 232, 232)
    cx = (bbox[0] + bbox[2]) * 0.5
    cy = (bbox[1] + bbox[3]) * 0.5
    span = max(1.0, max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * 0.52)
    hi, lo, glow = material_palette(kind, accent)

    item = ImageEnhance.Color(layer.copy()).enhance(0.62)
    px = item.load()
    for y in range(OUTPUT_SIZE):
        for x in range(OUTPUT_SIZE):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            dx = (x - cx) / span
            dy = (y - cy) / span
            light = max(0.0, 1.0 - math.hypot(dx + 0.42, dy + 0.58))
            shade = max(0.0, min(1.0, 0.40 + dy * 0.65 + dx * 0.24))
            grain = (
                math.sin(x * 0.17 + y * 0.09 + seed)
                + math.sin(x * 0.039 - y * 0.21 + seed * 0.13)
                + rng.uniform(-0.32, 0.32)
            ) / 2.8

            base = (
                r * 0.43 + hi[0] * 0.38 + lo[0] * 0.19,
                g * 0.43 + hi[1] * 0.38 + lo[1] * 0.19,
                b * 0.43 + hi[2] * 0.38 + lo[2] * 0.19,
            )
            if material_group(kind) == "arcane_glass":
                base = (
                    base[0] * 0.62 + glow[0] * 0.38,
                    base[1] * 0.62 + glow[1] * 0.38,
                    base[2] * 0.62 + glow[2] * 0.38,
                )

            value = 0.68 + 0.64 * light - 0.31 * shade + grain * 0.12
            if material_group(kind) in {"arcane_glass", "bone_stone", "cursed_paper"}:
                value += 0.08
            px[x, y] = (
                clamp(base[0] * value),
                clamp(base[1] * value),
                clamp(base[2] * value),
                a,
            )
    return item


def clip_overlay(overlay: Image.Image, alpha: Image.Image, opacity: float = 1.0) -> Image.Image:
    out = overlay.copy()
    out.putalpha(ImageChops.multiply(out.split()[3], alpha.point(lambda v: int(v * opacity))))
    return out


def add_reference_details(item: Image.Image, kind: str, accent: tuple[int, int, int, int], seed: int) -> None:
    rng = random.Random(seed + 211)
    alpha = item.split()[3]
    bbox = alpha.getbbox() or (28, 28, 228, 228)
    x0, y0, x1, y1 = bbox
    detail = Image.new("RGBA", item.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(detail)
    group = material_group(kind)

    # Painted cracks, scratches and engraved gold filigree like the reference sheet.
    for _ in range(42):
        x = rng.randint(x0, max(x0, x1 - 1))
        y = rng.randint(y0, max(y0, y1 - 1))
        length = rng.randint(10, 42)
        angle = rng.uniform(-0.85, 0.45)
        col = (246, 222, 165, rng.randint(38, 82)) if rng.random() > 0.42 else (5, 3, 8, rng.randint(52, 105))
        d.line((x, y, x + math.cos(angle) * length, y + math.sin(angle) * length), fill=col, width=rng.choice([1, 1, 2]))

    if group in {"blackened_metal", "black_leather", "chain_cord"}:
        for _ in range(15):
            x = rng.randint(x0 + 4, max(x0 + 4, x1 - 18))
            y = rng.randint(y0 + 6, max(y0 + 6, y1 - 6))
            d.arc((x, y - 9, x + rng.randint(22, 46), y + 12), 188, 342, fill=DULL_GOLD[:3] + (90,), width=2)
        for _ in range(10):
            x = rng.randint(x0 + 8, max(x0 + 8, x1 - 8))
            y = rng.randint(y0 + 8, max(y0 + 8, y1 - 8))
            r = rng.randint(3, 6)
            d.ellipse((x - r, y - r, x + r, y + r), fill=accent[:3] + (125,), outline=(6, 4, 10, 160), width=1)
    elif group == "bone_stone":
        for _ in range(18):
            x = rng.randint(x0 + 6, max(x0 + 6, x1 - 6))
            y = rng.randint(y0 + 6, max(y0 + 6, y1 - 6))
            d.line((x, y, x + rng.randint(-14, 16), y + rng.randint(7, 24)), fill=(69, 49, 42, 118), width=2)
    elif group == "arcane_glass":
        for _ in range(14):
            x = rng.randint(x0 + 6, max(x0 + 6, x1 - 6))
            d.line((x, y0 + rng.randint(4, 22), x + rng.randint(-20, 20), y1 - rng.randint(8, 22)), fill=(240, 230, 255, 94), width=2)
    elif group == "cursed_paper":
        for _ in range(12):
            x = rng.randint(x0 + 8, max(x0 + 8, x1 - 30))
            y = rng.randint(y0 + 12, max(y0 + 12, y1 - 12))
            d.line((x, y, x + rng.randint(15, 40), y + rng.randint(-2, 2)), fill=(35, 22, 19, 125), width=2)
        d.ellipse((x0 + 28, y0 + 28, x1 - 28, y1 - 28), outline=accent[:3] + (105,), width=3)

    item.alpha_composite(clip_overlay(detail, alpha, 1.0))

    # Reference-style embedded glow: small colored cores/gems/runes make the
    # dark silhouettes readable without turning them into bright medallions.
    glow_detail = Image.new("RGBA", item.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_detail)
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    for _ in range(5 if group != "arcane_glass" else 9):
        x = rng.uniform(x0 + 18, x1 - 18)
        y = rng.uniform(y0 + 18, y1 - 18)
        r = rng.choice([4, 5, 6, 7])
        gd.ellipse((x - r, y - r, x + r, y + r), fill=accent[:3] + (96,), outline=(255, 236, 190, 58), width=1)
    gd.arc((cx - 46, cy - 44, cx + 46, cy + 44), rng.randint(195, 235), rng.randint(295, 345), fill=accent[:3] + (90,), width=3)
    if group in {"arcane_glass", "cursed_paper"}:
        gd.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), outline=accent[:3] + (120,), width=3)
    item.alpha_composite(clip_overlay(glow_detail.filter(ImageFilter.GaussianBlur(0.25)), alpha, 1.0))


def add_bevel(item: Image.Image, accent: tuple[int, int, int, int]) -> None:
    alpha = item.split()[3]
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(0.7))
    light_alpha = ImageChops.multiply(ImageChops.offset(edge, -2, -2), alpha).point(lambda v: min(170, int(v * 0.85)))
    light = Image.new("RGBA", item.size, (255, 232, 178, 0))
    light.putalpha(light_alpha)
    item.alpha_composite(light)
    dark_alpha = ImageChops.multiply(ImageChops.offset(edge, 4, 5), alpha).point(lambda v: min(230, int(v * 1.25)))
    dark = Image.new("RGBA", item.size, (2, 2, 7, 0))
    dark.putalpha(dark_alpha)
    item.alpha_composite(dark)
    rim_alpha = edge.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: min(110, int(v * 0.42)))
    rim = Image.new("RGBA", item.size, accent[:3] + (0,))
    rim.putalpha(rim_alpha)
    item.alpha_composite(rim)


def add_outer_fx(out: Image.Image, alpha: Image.Image, kind: str, accent: tuple[int, int, int, int], tier: int, seed: int) -> None:
    rng = random.Random(seed + 481)
    # Shadow is heavy and grounded, but the background remains transparent.
    shadow_alpha = alpha.filter(ImageFilter.GaussianBlur(5)).point(lambda v: min(125, int(v * 0.46)))
    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha)
    out.alpha_composite(ImageChops.offset(shadow, 6, 8))

    outline_alpha = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(11)), alpha).filter(ImageFilter.GaussianBlur(0.65))
    outline_alpha = outline_alpha.point(lambda v: min(230, int(v * 1.08)))
    outline = Image.new("RGBA", out.size, (5, 4, 10, 0))
    outline.putalpha(outline_alpha)
    out.alpha_composite(outline)

    glow_alpha = alpha.filter(ImageFilter.GaussianBlur(10 + tier * 2)).point(lambda v: min(145, int(v * (0.24 + tier * 0.08))))
    glow = Image.new("RGBA", out.size, darken(accent, 28)[:3] + (0,))
    glow.putalpha(glow_alpha)
    out.alpha_composite(glow)

    if tier >= 2:
        d = ImageDraw.Draw(out)
        bbox = alpha.getbbox() or (32, 32, 224, 224)
        cx = (bbox[0] + bbox[2]) / 2
        cy = (bbox[1] + bbox[3]) / 2
        radius = max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * 0.52
        for _ in range(12 + tier * 8):
            angle = rng.uniform(0, math.tau)
            dist = rng.uniform(radius * 0.68, radius * (1.05 if tier == 2 else 1.22))
            x = cx + math.cos(angle) * dist
            y = cy + math.sin(angle) * dist
            size = rng.choice([2, 2, 3, 4])
            d.line((x - size, y, x + size, y), fill=accent[:3] + (rng.randint(95, 190),), width=2)
            d.line((x, y - size, x, y + size), fill=accent[:3] + (rng.randint(95, 190),), width=2)


def final_icon(artifact: dict) -> Image.Image:
    kind = str(artifact["id"])
    tier = int(artifact.get("tier", 1))
    accent = artifact_accent(kind, tier)
    seed = sum(ord(ch) for ch in kind) + tier * 707
    src, accent = source_for(kind, tier)
    layer = scaled_layer(strip_soft_source(src), kind)
    alpha = layer.split()[3]

    out = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    add_outer_fx(out, alpha, kind, accent, tier, seed)
    item = paint_material(layer, kind, accent, seed)
    add_reference_details(item, kind, accent, seed)
    add_bevel(item, accent)

    # A cold top-left specular flash and a lower shadow push the object toward
    # the rendered clipart look from the user reference.
    gloss = Image.new("RGBA", item.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.ellipse((32, 16, 154, 86), fill=(255, 245, 215, 40))
    gd.line((46, 43, 166, 108), fill=(255, 240, 180, 58), width=3)
    gloss.putalpha(ImageChops.multiply(gloss.split()[3], alpha.filter(ImageFilter.GaussianBlur(1.2))))
    item.alpha_composite(gloss)

    lower = Image.new("RGBA", item.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lower)
    for y in range(OUTPUT_SIZE):
        ld.line((0, y, OUTPUT_SIZE, y), fill=(0, 0, 0, int(75 * (y / OUTPUT_SIZE) ** 1.5)))
    lower.putalpha(ImageChops.multiply(lower.split()[3], alpha))
    item.alpha_composite(lower)

    out.alpha_composite(item)
    return out


def make_preview(artifacts: list[dict]) -> None:
    tile = 54
    cols = 13
    rows = math.ceil(len(artifacts) / cols)
    sheet = Image.new("RGBA", (cols * tile, rows * tile), (20, 17, 23, 255))
    for index, artifact in enumerate(artifacts):
        icon = Image.open(ARTIFACT_DIR / f"artifact_{artifact['id']}.png").convert("RGBA")
        small = icon.resize((40, 40), Image.Resampling.LANCZOS)
        x = (index % cols) * tile + 7
        y = (index // cols) * tile + 7
        sheet.alpha_composite(small, (x, y))
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW_PATH)


def main() -> None:
    artifacts = parse_artifacts()
    for artifact in artifacts:
        final_icon(artifact).save(ARTIFACT_DIR / f"artifact_{artifact['id']}.png")
    make_preview(artifacts)
    print(f"redrew {len(artifacts)} artifact icons in reference dark-artifact style")
    print(f"wrote 40px preview: {PREVIEW_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
