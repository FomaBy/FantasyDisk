"""Generate glossy RPG-style artifact icons with tier readability.

Design task: docs/tasks/codex_design_artifact_icons_rpg_item_style_task.md

The output replaces artifact PNGs in place:
    assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png

Icons are 256x256 RGBA with transparent backgrounds. The visual style follows
the stat/derived HUD icons: saturated materials, crisp dark outlines, glossy
top-left highlights, and readable silhouettes at 40px. Tier 1/2/3 receive
increasing decoration, glow and particle richness.
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
PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_rpg_40px_preview.png"
OUTPUT_SIZE = 256

TIER_ACCENT = {
    1: (245, 204, 102, 255),
    2: (81, 222, 242, 255),
    3: (252, 91, 194, 255),
}


def parse_artifacts() -> list[dict]:
    text = (ROOT / "scripts" / "progression_data.gd").read_text(encoding="utf-8")
    block = text.split("const ARTIFACTS := [", 1)[1].split("]\n\nconst LEVEL_UP_REWARDS", 1)[0]
    artifacts: list[dict] = []
    for raw in re.findall(r"\{[^\n]+\}", block):
        safe = raw
        safe = re.sub(r"Color\([^)]+\)", '"Color"', safe)
        try:
            data = ast.literal_eval(safe)
        except (SyntaxError, ValueError) as exc:
            raise RuntimeError(f"Cannot parse artifact row: {raw}") from exc
        artifacts.append(data)
    return artifacts


def sc(v: float) -> int:
    return kit.sc(v)


def clamp(v: int) -> int:
    return max(0, min(255, int(v)))


def rgba(color: tuple[int, int, int, int], alpha: int | None = None) -> tuple[int, int, int, int]:
    return (color[0], color[1], color[2], color[3] if alpha is None else alpha)


def lighten(color: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    return (clamp(color[0] + amount), clamp(color[1] + amount), clamp(color[2] + amount), color[3])


def darken(color: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    return (clamp(color[0] - amount), clamp(color[1] - amount), clamp(color[2] - amount), color[3])


def mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(4))


def transparent_source() -> Image.Image:
    return kit.canvas(128, 128)


def draw_poly(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill, outline=kit.OUTLINE, width: int = 5) -> None:
    scaled = [(sc(x), sc(y)) for x, y in pts]
    if outline and width > 0:
        draw.line(scaled + [scaled[0]], fill=outline, width=sc(width), joint="curve")
    draw.polygon(scaled, fill=fill)


def draw_line(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill, width: int = 5) -> None:
    draw.line([(sc(x), sc(y)) for x, y in pts], fill=fill, width=sc(width), joint="curve")


def draw_legendary_source(kind: str) -> Image.Image | None:
    img = transparent_source()
    d = ImageDraw.Draw(img)
    if kind == "echo_core":
        kit.add_glow(img, kit.CYAN, (27, 19, 101, 105), 10)
        kit.draw_orb(img, (89, 229, 248, 225), True)
        d.arc((sc(23), sc(21), sc(105), sc(103)), 302, 76, fill=kit.VIOLET, width=sc(5))
        d.arc((sc(18), sc(16), sc(110), sc(108)), 302, 76, fill=kit.CYAN, width=sc(3))
        return img
    if kind == "split_core":
        kit.add_glow(img, kit.VIOLET, (25, 19, 104, 106), 10)
        draw_poly(d, [(54, 17), (77, 44), (67, 104), (39, 91), (33, 44)], kit.CYAN, kit.OUTLINE, 5)
        draw_poly(d, [(75, 22), (101, 51), (86, 105), (63, 92), (56, 49)], kit.VIOLET, kit.OUTLINE, 5)
        draw_line(d, [(55, 28), (48, 85)], (235, 255, 255, 190), 3)
        draw_line(d, [(82, 33), (75, 88)], (255, 226, 255, 175), 3)
        return img
    if kind == "blood_pact":
        kit.draw_book(img, (118, 38, 44, 255))
        kit.draw_heart(img, kit.RED)
        draw_line(d, [(45, 82), (84, 82)], (255, 217, 125, 220), 3)
        return img
    if kind == "leech_heart":
        kit.draw_heart(img, (177, 28, 45, 255))
        for pts in [
            [(45, 82), (30, 96), (23, 111)],
            [(82, 79), (100, 92), (108, 109)],
            [(61, 93), (58, 108), (51, 119)],
        ]:
            draw_line(d, pts, (40, 117, 68, 255), 5)
            draw_line(d, pts, (137, 231, 119, 210), 2)
        return img
    if kind == "thorn_pact":
        kit.add_glow(img, kit.GREEN, (18, 19, 110, 111), 8)
        kit.draw_heart(img, (113, 34, 46, 255), fragile=True)
        for angle in range(20, 360, 35):
            rad = math.radians(angle)
            x = 64 + math.cos(rad) * 45
            y = 65 + math.sin(rad) * 39
            draw_line(d, [(64, 65), (x, y)], (54, 122, 48, 210), 3)
            draw_poly(d, [(x, y), (x - 5, y + 3), (x + 1, y - 8)], (192, 238, 101, 220), None, 0)
        return img
    if kind == "phantom_step":
        kit.draw_boots(img, (124, 230, 244, 214), True)
        d.arc((sc(18), sc(34), sc(118), sc(109)), 202, 330, fill=(148, 112, 255, 170), width=sc(5))
        d.arc((sc(8), sc(24), sc(123), sc(118)), 206, 328, fill=(92, 228, 246, 135), width=sc(3))
        return img
    return None


def draw_source(kind: str) -> tuple[Image.Image, tuple[int, int, int, int]]:
    special = draw_legendary_source(kind)
    accent = kit.ARTIFACT_ACCENTS.get(kind, kit.GOLD)
    if special is not None:
        return special, accent
    return dark_source.draw_source(kind)


def scaled_layer(src: Image.Image, tier: int) -> Image.Image:
    alpha = src.split()[3]
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("empty source icon")
    pad = sc(7)
    bbox = (
        max(0, bbox[0] - pad),
        max(0, bbox[1] - pad),
        min(src.width, bbox[2] + pad),
        min(src.height, bbox[3] + pad),
    )
    cropped = src.crop(bbox)
    target = {1: 206, 2: 216, 3: 224}.get(tier, 208)
    if cropped.width > cropped.height * 2.2:
        target = 232
    scale = min(target / cropped.width, target / cropped.height)
    resized = cropped.resize((round(cropped.width * scale), round(cropped.height * scale)), Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    layer.alpha_composite(resized, ((OUTPUT_SIZE - resized.width) // 2, (OUTPUT_SIZE - resized.height) // 2 - 1))
    return layer


def recolor_for_gloss(item: Image.Image, accent: tuple[int, int, int, int], tier: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    px = item.load()
    alpha = item.split()[3]
    bbox = alpha.getbbox() or (24, 24, 232, 232)
    cx = (bbox[0] + bbox[2]) * 0.5
    cy = (bbox[1] + bbox[3]) * 0.5
    span = max(1.0, max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * 0.5)
    saturation = {1: 1.15, 2: 1.28, 3: 1.42}.get(tier, 1.15)
    item = ImageEnhance.Color(item).enhance(saturation)
    item = ImageEnhance.Contrast(item).enhance(1.13 + 0.07 * tier)
    px = item.load()
    for y in range(OUTPUT_SIZE):
        for x in range(OUTPUT_SIZE):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            dx = (x - cx) / span
            dy = (y - cy) / span
            top_light = max(0.0, 1.0 - math.hypot(dx + 0.45, dy + 0.55))
            bottom_shadow = max(0.0, min(1.0, (dy + dx * 0.20 + 0.45)))
            noise = rng.uniform(-5, 5)
            r = r + 38 * top_light - 25 * bottom_shadow + noise
            g = g + 34 * top_light - 25 * bottom_shadow + noise
            b = b + 30 * top_light - 22 * bottom_shadow + noise
            if tier >= 2:
                r = r * 0.92 + accent[0] * 0.08
                g = g * 0.92 + accent[1] * 0.08
                b = b * 0.92 + accent[2] * 0.08
            px[x, y] = (clamp(r), clamp(g), clamp(b), a)
    return item


def glow_from_alpha(alpha: Image.Image, color: tuple[int, int, int, int], blur: float, strength: float) -> Image.Image:
    glow_alpha = alpha.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: clamp(v * strength))
    glow = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), color[:3] + (0,))
    glow.putalpha(glow_alpha)
    return glow


def add_bevel_and_gloss(item: Image.Image, accent: tuple[int, int, int, int], tier: int) -> None:
    alpha = item.split()[3]
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(0.55))
    top = ImageChops.multiply(ImageChops.offset(edge, -2, -2), alpha).point(lambda v: min(175, int(v * 0.95)))
    light = Image.new("RGBA", item.size, (255, 238, 178, 0))
    light.putalpha(top)
    item.alpha_composite(light)

    bottom = ImageChops.multiply(ImageChops.offset(edge, 3, 4), alpha).point(lambda v: min(205, int(v * 1.15)))
    shade = Image.new("RGBA", item.size, (4, 4, 8, 0))
    shade.putalpha(bottom)
    item.alpha_composite(shade)

    gloss = Image.new("RGBA", item.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.ellipse((34, 18, 151, 88), fill=(255, 255, 255, 30 + tier * 10))
    gd.arc((32, 24, 218, 207), 208, 318, fill=(255, 244, 181, 80 + tier * 18), width=4)
    if tier >= 2:
        gd.line((48, 50, 158, 111), fill=accent[:3] + (50 + tier * 18,), width=3)
    gloss.putalpha(ImageChops.multiply(gloss.split()[3], alpha.filter(ImageFilter.GaussianBlur(1.2))))
    item.alpha_composite(gloss)


def add_tier_fx(out: Image.Image, item_alpha: Image.Image, accent: tuple[int, int, int, int], tier: int, seed: int) -> None:
    rng = random.Random(seed + 9000)
    d = ImageDraw.Draw(out)
    bbox = item_alpha.getbbox() or (30, 30, 226, 226)
    cx = (bbox[0] + bbox[2]) / 2
    cy = (bbox[1] + bbox[3]) / 2
    radius = max(bbox[2] - bbox[0], bbox[3] - bbox[1]) / 2
    if tier >= 2:
        for angle in [38, 142, 244, 318]:
            rad = math.radians(angle)
            x = cx + math.cos(rad) * (radius * 0.78)
            y = cy + math.sin(rad) * (radius * 0.72)
            r = 5 if tier == 2 else 7
            d.ellipse((x - r - 2, y - r - 2, x + r + 2, y + r + 2), fill=(20, 14, 26, 175))
            d.ellipse((x - r, y - r, x + r, y + r), fill=lighten(accent, 32))
            d.ellipse((x - r * 0.4, y - r * 0.55, x + r * 0.15, y + r * 0.05), fill=(255, 255, 255, 180))
        for _ in range(16 if tier == 2 else 30):
            ang = rng.uniform(0, math.tau)
            rad = rng.uniform(radius * 0.70, radius * (1.0 if tier == 2 else 1.16))
            x = cx + math.cos(ang) * rad
            y = cy + math.sin(ang) * rad
            a = rng.randint(90, 175) if tier == 2 else rng.randint(120, 220)
            size = rng.choice([2, 2, 3, 4 if tier == 3 else 3])
            d.line((x - size, y, x + size, y), fill=accent[:3] + (a,), width=2)
            d.line((x, y - size, x, y + size), fill=accent[:3] + (a,), width=2)
    if tier >= 3:
        for offset, color in [(0, kit.GOLD), (12, accent), (-12, kit.GOLD)]:
            d.arc((bbox[0] - 8 + offset, bbox[1] - 5, bbox[2] + 8 + offset, bbox[3] + 10), 212, 328, fill=color[:3] + (150,), width=4)
        for angle in [90, 210, 330]:
            rad = math.radians(angle)
            x = cx + math.cos(rad) * (radius * 0.50)
            y = cy + math.sin(rad) * (radius * 0.55)
            draw_star(d, x, y, 9, kit.GOLD)


def draw_star(d: ImageDraw.ImageDraw, x: float, y: float, r: float, color) -> None:
    pts: list[tuple[float, float]] = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.42
        pts.append((x + math.cos(angle) * rr, y + math.sin(angle) * rr))
    d.polygon(pts, fill=color[:3] + (190,))


def final_icon(artifact: dict) -> Image.Image:
    kind = str(artifact["id"])
    tier = int(artifact.get("tier", 1))
    src, source_accent = draw_source(kind)
    tier_accent = TIER_ACCENT.get(tier, kit.GOLD)
    accent = mix(source_accent, tier_accent, 0.34 if tier == 1 else 0.55)
    layer = scaled_layer(src, tier)
    alpha = layer.split()[3]
    seed = sum(ord(ch) for ch in kind) + tier * 1009

    out = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    if tier >= 2:
        out.alpha_composite(glow_from_alpha(alpha, accent, 10 + tier * 4, 0.34 + tier * 0.10))

    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.filter(ImageFilter.GaussianBlur(5)).point(lambda v: int(v * 0.42)))
    shadow = ImageChops.offset(shadow, 5, 7)
    out.alpha_composite(shadow)

    outline_alpha = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(9)), alpha).filter(ImageFilter.GaussianBlur(0.35))
    outline_alpha = outline_alpha.point(lambda v: min(210, int(v * 1.15)))
    outline = Image.new("RGBA", out.size, (17, 13, 23, 0))
    outline.putalpha(outline_alpha)
    out.alpha_composite(outline)

    item = recolor_for_gloss(layer.copy(), accent, tier, seed)
    add_bevel_and_gloss(item, accent, tier)
    out.alpha_composite(item)
    add_tier_fx(out, alpha, accent, tier, seed)
    return out


def make_preview(artifacts: list[dict]) -> None:
    tile = 54
    cols = 13
    rows = math.ceil(len(artifacts) / cols)
    sheet = Image.new("RGBA", (cols * tile, rows * tile), (28, 23, 34, 255))
    d = ImageDraw.Draw(sheet)
    for i, artifact in enumerate(artifacts):
        icon = Image.open(ARTIFACT_DIR / f"artifact_{artifact['id']}.png").convert("RGBA")
        small = icon.resize((40, 40), Image.Resampling.LANCZOS)
        x = (i % cols) * tile + 7
        y = (i // cols) * tile + 5
        sheet.alpha_composite(small, (x, y))
        tier = int(artifact.get("tier", 1))
        d.ellipse((x + 30, y + 30, x + 41, y + 41), fill=TIER_ACCENT[tier], outline=(10, 8, 14, 255), width=1)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW_PATH)


def main() -> None:
    artifacts = parse_artifacts()
    for artifact in artifacts:
        final_icon(artifact).save(ARTIFACT_DIR / f"artifact_{artifact['id']}.png")
    make_preview(artifacts)
    tiers = {tier: sum(1 for artifact in artifacts if int(artifact.get("tier", 1)) == tier) for tier in (1, 2, 3)}
    print(f"generated {len(artifacts)} RPG artifact icons at 256x256")
    print(f"tier counts: {tiers}")
    print(f"wrote 40px preview: {PREVIEW_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
