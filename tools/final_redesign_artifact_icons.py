#!/usr/bin/env python3
"""Final-pass artifact icon polish for FantasyDisk.

The script preserves the canonical `artifact_<id>.png` filenames, extracts the
current generated artifact item from its dark tile, and writes a brighter
transparent-background epic dark-fantasy icon pass.
"""

from __future__ import annotations

import math
import re
import shutil
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"
SOURCE_BACKUP_DIR = ROOT / "build" / "artifact_icon_final_redesign_sources"
PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_final_dark_fantasy_40px_preview.png"
LEGACY_PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_generated_concept_40px_preview.png"
DARK_ARTIFACTS_PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_dark_artifacts_40px_preview.png"
PROGRESSION_DATA = ROOT / "scripts" / "progression_data.gd"

SIZE = 256


ACCENTS = {
    "blood": (235, 34, 46, 210),
    "void": (153, 64, 255, 210),
    "gold": (255, 185, 62, 210),
    "ember": (255, 104, 30, 210),
    "nature": (79, 214, 103, 205),
    "spirit": (86, 200, 255, 205),
    "silver": (196, 226, 255, 200),
}


def parse_artifacts() -> list[dict[str, object]]:
    text = PROGRESSION_DATA.read_text(encoding="utf-8")
    block = text.split("const ARTIFACTS :=", 1)[1].split("const LEVEL_UP_REWARDS", 1)[0]
    artifacts: list[dict[str, object]] = []
    for line in block.splitlines():
        if '"id":' not in line:
            continue
        artifact_id = re.search(r'"id":\s*"([^"]+)"', line)
        title = re.search(r'"title":\s*"([^"]+)"', line)
        tier = re.search(r'"tier":\s*([0-9]+)', line)
        if artifact_id:
            artifacts.append(
                {
                    "id": artifact_id.group(1),
                    "title": title.group(1) if title else artifact_id.group(1),
                    "tier": int(tier.group(1)) if tier else 1,
                }
            )
    return artifacts


def accent_for(artifact_id: str, tier: int) -> tuple[int, int, int, int]:
    if any(key in artifact_id for key in ("blood", "heart", "rage", "sigil", "pact")):
        return ACCENTS["blood"]
    if any(key in artifact_id for key in ("void", "dark", "ink", "skull", "echo", "split", "cursed")):
        return ACCENTS["void"]
    if any(key in artifact_id for key in ("ember", "burning", "whetstone")):
        return ACCENTS["ember"]
    if any(key in artifact_id for key in ("root", "seed", "thorn", "stone")):
        return ACCENTS["nature"]
    if any(key in artifact_id for key in ("phantom", "glass", "orb", "lens", "swift", "quick")):
        return ACCENTS["spirit"]
    if any(key in artifact_id for key in ("coin", "gold", "crown", "compass", "belt", "amulet")):
        return ACCENTS["gold"]
    return ACCENTS["gold"] if tier >= 3 else ACCENTS["silver"]


def ensure_source_backup() -> None:
    SOURCE_BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    for path in ARTIFACT_DIR.glob("artifact_*.png"):
        target = SOURCE_BACKUP_DIR / path.name
        if not target.exists():
            shutil.copy2(path, target)


def initial_mask(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
    pixels = img.load()
    mask = Image.new("L", img.size, 0)
    out = mask.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            hi = max(r, g, b)
            lo = min(r, g, b)
            chroma = hi - lo
            center_weight = 1.0 - min(1.0, math.hypot((x - w / 2) / 150.0, (y - h / 2) / 150.0))
            value_gate = hi > 72 and chroma > 14
            bright_gate = hi > 112 and chroma > 5
            magic_gate = chroma > 54 and hi > 42
            central_dark_gate = center_weight > 0.42 and hi > 58 and chroma > 24
            if value_gate or bright_gate or magic_gate or central_dark_gate:
                if x < 4 or y < 4 or x >= w - 4 or y >= h - 4:
                    continue
                if (y < 62 or y > 206) and hi < 122 and chroma < 48:
                    continue
                out[x, y] = 255
    mask = mask.filter(ImageFilter.MaxFilter(3))
    return keep_artifact_components(mask)


def keep_artifact_components(mask: Image.Image) -> Image.Image:
    w, h = mask.size
    src = mask.load()
    seen = [[False] * w for _ in range(h)]
    keep = Image.new("L", mask.size, 0)
    out = keep.load()
    cx, cy = w / 2, h / 2

    for start_y in range(h):
        for start_x in range(w):
            if seen[start_y][start_x] or src[start_x, start_y] == 0:
                continue
            queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            seen[start_y][start_x] = True
            pts: list[tuple[int, int]] = []
            while queue:
                x, y = queue.popleft()
                pts.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and src[nx, ny] > 0:
                        seen[ny][nx] = True
                        queue.append((nx, ny))

            area = len(pts)
            if area < 20:
                continue
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
            bw, bh = x1 - x0 + 1, y1 - y0 + 1
            comp_cx = sum(xs) / area
            comp_cy = sum(ys) / area
            dist = math.hypot((comp_cx - cx) / 120.0, (comp_cy - cy) / 120.0)
            lower_platform = y0 > 182 and bw > 128 and bh < 48
            flat_tile_sliver = bh <= 16 and bw >= 34 and area < 720
            border_strip = (x0 < 8 or y0 < 8 or x1 > w - 9 or y1 > h - 9) and area < 900
            if lower_platform or flat_tile_sliver or border_strip:
                continue
            if area > 180 or dist < 1.05 or (x0 < cx < x1 and y0 < cy + 58 < y1):
                for x, y in pts:
                    out[x, y] = 255

    keep = keep.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(0.85))
    keep = keep.point(lambda a: 0 if a < 18 else min(255, int((a - 18) * 1.28)))
    return keep


def fit_subject(item: Image.Image, alpha: Image.Image) -> tuple[Image.Image, Image.Image]:
    bbox = alpha.getbbox()
    if bbox is None:
        return item, alpha
    x0, y0, x1, y1 = bbox
    pad = 12
    crop_box = (max(0, x0 - pad), max(0, y0 - pad), min(SIZE, x1 + pad), min(SIZE, y1 + pad))
    item_crop = item.crop(crop_box)
    alpha_crop = alpha.crop(crop_box)
    max_dim = 224
    scale = min(max_dim / item_crop.width, max_dim / item_crop.height, 1.42)
    new_size = (max(1, round(item_crop.width * scale)), max(1, round(item_crop.height * scale)))
    item_resized = item_crop.resize(new_size, Image.Resampling.LANCZOS)
    alpha_resized = alpha_crop.resize(new_size, Image.Resampling.LANCZOS)
    fitted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fitted_alpha = Image.new("L", (SIZE, SIZE), 0)
    offset = ((SIZE - new_size[0]) // 2, (SIZE - new_size[1]) // 2)
    fitted.alpha_composite(item_resized, offset)
    fitted_alpha.paste(alpha_resized, offset)
    fitted_alpha = clean_fitted_alpha(fitted_alpha)
    return fitted, fitted_alpha


def clean_fitted_alpha(alpha: Image.Image) -> Image.Image:
    w, h = alpha.size
    src = alpha.point(lambda a: 255 if a > 10 else 0)
    px = src.load()
    original = alpha.load()
    seen = [[False] * w for _ in range(h)]
    out = Image.new("L", alpha.size, 0)
    out_px = out.load()

    comps: list[tuple[int, tuple[int, int, int, int], list[tuple[int, int]]]] = []
    for start_y in range(h):
        for start_x in range(w):
            if seen[start_y][start_x] or px[start_x, start_y] == 0:
                continue
            queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            seen[start_y][start_x] = True
            pts: list[tuple[int, int]] = []
            while queue:
                x, y = queue.popleft()
                pts.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny] > 0:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            comps.append((len(pts), (min(xs), min(ys), max(xs), max(ys)), pts))

    if not comps:
        return alpha
    largest = max(area for area, _bbox, _pts in comps)
    for area, (x0, y0, x1, y1), pts in comps:
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        aspect = bw / max(1, bh)
        flat_sliver = bh <= 22 and aspect >= 2.25 and area < 1650
        tiny_speck = area < 22
        keep = area == largest or (area > 80 and not flat_sliver) or (area > 280 and bh > 18)
        if tiny_speck or flat_sliver:
            keep = False
        if keep:
            for x, y in pts:
                out_px[x, y] = original[x, y]
    return out.filter(ImageFilter.GaussianBlur(0.25))


def color_polish(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(1.24)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.22)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.08)
    rgb = ImageEnhance.Sharpness(rgb).enhance(1.35)
    return rgb.convert("RGBA")


def add_final_fx(item: Image.Image, alpha: Image.Image, artifact_id: str, tier: int) -> Image.Image:
    accent = accent_for(artifact_id, tier)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    shadow_alpha = alpha.filter(ImageFilter.GaussianBlur(7)).point(lambda a: min(130, int(a * 0.44)))
    shadow = Image.new("RGBA", (SIZE, SIZE), (4, 2, 8, 0))
    shadow.putalpha(shadow_alpha)
    canvas.alpha_composite(ImageChops.offset(shadow, 5, 8))

    outline_alpha = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(9)), alpha)
    outline_alpha = outline_alpha.filter(ImageFilter.GaussianBlur(0.45)).point(lambda a: min(230, int(a * 1.35)))
    outline = Image.new("RGBA", (SIZE, SIZE), (8, 4, 10, 0))
    outline.putalpha(outline_alpha)
    canvas.alpha_composite(outline)

    glow_strength = 0.22 + tier * 0.12
    glow_alpha = alpha.filter(ImageFilter.GaussianBlur(10 + tier * 2)).point(
        lambda a: 0 if a < 10 else min(150, int((a - 10) * glow_strength))
    )
    glow = Image.new("RGBA", (SIZE, SIZE), accent[:3] + (0,))
    glow.putalpha(glow_alpha)
    canvas.alpha_composite(glow)

    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(0.7))
    rim_alpha = ImageChops.multiply(edge, alpha).point(lambda a: min(150, int(a * 0.82)))
    rim = Image.new("RGBA", (SIZE, SIZE), accent[:3] + (0,))
    rim.putalpha(rim_alpha)
    canvas.alpha_composite(rim)

    top_light_alpha = ImageChops.multiply(ImageChops.offset(edge, -3, -3), alpha).point(lambda a: min(130, int(a * 0.68)))
    top_light = Image.new("RGBA", (SIZE, SIZE), (255, 235, 190, 0))
    top_light.putalpha(top_light_alpha)

    item = item.copy()
    item.putalpha(alpha)
    item.alpha_composite(top_light)
    canvas.alpha_composite(item)

    if tier >= 3:
        draw = ImageDraw.Draw(canvas)
        bbox = alpha.getbbox() or (44, 44, 212, 212)
        x0, y0, x1, y1 = bbox
        for i in range(8):
            t = (i * 37 + len(artifact_id) * 11) % 100 / 100.0
            x = round(x0 + (x1 - x0) * ((i * 0.37 + t) % 1.0))
            y = round(y0 + (y1 - y0) * ((i * 0.23 + 0.18) % 1.0))
            r = 1 + (i % 2)
            draw.ellipse((x - r, y - r, x + r, y + r), fill=accent[:3] + (120,))

    return remove_top_sliver_artifacts(canvas)


def remove_top_sliver_artifacts(img: Image.Image) -> Image.Image:
    alpha = img.split()[3]
    hard = alpha.point(lambda a: 255 if a > 40 else 0)
    w, h = hard.size
    px = hard.load()
    seen = [[False] * w for _ in range(h)]
    comps: list[tuple[int, tuple[int, int, int, int], list[tuple[int, int]]]] = []
    for start_y in range(h):
        for start_x in range(w):
            if seen[start_y][start_x] or px[start_x, start_y] == 0:
                continue
            queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            seen[start_y][start_x] = True
            pts: list[tuple[int, int]] = []
            while queue:
                x, y = queue.popleft()
                pts.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny] > 0:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            comps.append((len(pts), (min(xs), min(ys), max(xs), max(ys)), pts))

    if len(comps) < 2:
        return img
    largest = max(area for area, _bbox, _pts in comps)
    removal = Image.new("L", img.size, 0)
    removal_px = removal.load()
    for area, (_x0, y0, _x1, y1), pts in comps:
        if area >= largest * 0.22:
            continue
        if y0 < 82 and y1 < 92 and area < 5600:
            for x, y in pts:
                removal_px[x, y] = 255
    if removal.getbbox() is None:
        return img

    removal = removal.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(1.2))
    out = img.copy()
    out_alpha = out.split()[3]
    clean_alpha = ImageChops.subtract(out_alpha, removal.point(lambda a: min(255, int(a * 1.8))))
    out.putalpha(clean_alpha)
    return out


def process_icon(source: Path, target: Path, artifact_id: str, tier: int) -> None:
    src = Image.open(source).convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    base_alpha = src.split()[3]
    if base_alpha.getextrema()[0] < 8:
        source_rgb = Image.new("RGB", (SIZE, SIZE), (5, 4, 8))
        source_rgb.paste(src.convert("RGB"), mask=base_alpha)
    else:
        source_rgb = src.convert("RGB")
    mask = initial_mask(source_rgb)
    polished = color_polish(source_rgb)
    fitted_item, fitted_alpha = fit_subject(polished, mask)
    final = add_final_fx(fitted_item, fitted_alpha, artifact_id, tier)
    final.save(target)


def build_preview(artifacts: list[dict[str, object]]) -> None:
    thumb = 40
    pad = 6
    cols = 13
    rows = math.ceil(len(artifacts) / cols)
    preview = Image.new("RGBA", (cols * (thumb + pad) + pad, rows * (thumb + pad) + pad), (8, 6, 12, 255))
    for index, artifact in enumerate(artifacts):
        artifact_id = str(artifact["id"])
        path = ARTIFACT_DIR / f"artifact_{artifact_id}.png"
        icon = Image.open(path).convert("RGBA").resize((thumb, thumb), Image.Resampling.LANCZOS)
        x = pad + (index % cols) * (thumb + pad)
        y = pad + (index // cols) * (thumb + pad)
        preview.alpha_composite(icon, (x, y))
    for path in (PREVIEW_PATH, LEGACY_PREVIEW_PATH, DARK_ARTIFACTS_PREVIEW_PATH):
        preview.save(path)


def main() -> None:
    artifacts = parse_artifacts()
    ensure_source_backup()
    for artifact in artifacts:
        artifact_id = str(artifact["id"])
        tier = int(artifact["tier"])
        source = SOURCE_BACKUP_DIR / f"artifact_{artifact_id}.png"
        target = ARTIFACT_DIR / f"artifact_{artifact_id}.png"
        if not source.exists():
            raise FileNotFoundError(source)
        process_icon(source, target, artifact_id, tier)
    build_preview(artifacts)
    print(f"final artifact redesign complete: {len(artifacts)} icons")
    print(PREVIEW_PATH.relative_to(ROOT))


if __name__ == "__main__":
    main()
