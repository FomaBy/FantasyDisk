#!/usr/bin/env python3
"""Validate FantasyDisk artifact icons and build QA contact sheets."""

from __future__ import annotations

import re
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"
PROGRESSION_DATA = ROOT / "scripts" / "progression_data_content.gd"
PREVIEW_PATH = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifact_per_item_preview.png"
SIZE = 256
EDGE_MARGIN = 4


def parse_artifact_ids() -> list[str]:
    text = PROGRESSION_DATA.read_text(encoding="utf-8")
    block = text.split("const ARTIFACTS := [", 1)[1].split("\n]", 1)[0]
    return re.findall(r'"id":\s*"([^"]+)"', block)


def alpha_components(alpha: Image.Image, threshold: int = 8) -> list[tuple[int, tuple[int, int, int, int]]]:
    mask = alpha.point(lambda a: 255 if a > threshold else 0)
    w, h = mask.size
    px = mask.load()
    seen = [[False] * w for _ in range(h)]
    comps: list[tuple[int, tuple[int, int, int, int]]] = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy] == 0:
                continue
            queue: deque[tuple[int, int]] = deque([(sx, sy)])
            seen[sy][sx] = True
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
            comps.append((len(pts), (min(xs), min(ys), max(xs) + 1, max(ys) + 1)))
    return sorted(comps, reverse=True)


def validate_icon(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        img = Image.open(path).convert("RGBA")
    except Exception as exc:  # pragma: no cover - diagnostic script
        return [f"open failed: {exc}"]
    if img.size != (SIZE, SIZE):
        errors.append(f"size {img.size}, expected 256x256")
    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        errors.append("empty alpha")
        return errors
    x0, y0, x1, y1 = bbox
    if x0 < EDGE_MARGIN or y0 < EDGE_MARGIN or x1 > SIZE - EDGE_MARGIN or y1 > SIZE - EDGE_MARGIN:
        errors.append(f"bbox too close to edge {bbox}")
    for xy in ((0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1)):
        if alpha.getpixel(xy) != 0:
            errors.append(f"corner alpha at {xy}")
            break
    comps = alpha_components(alpha)
    if not comps:
        errors.append("no visible component")
    elif len(comps) > 1:
        largest = comps[0][0]
        stray = [area for area, _bbox in comps[1:] if area > max(32, largest * 0.01)]
        if stray:
            errors.append(f"detached components {stray[:5]}")
    return errors


def build_preview(ids: list[str]) -> None:
    cols = 8
    cell_w = 290
    cell_h = 350
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (24, 22, 28, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("Arial.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
    for index, artifact_id in enumerate(ids):
        path = ARTIFACT_DIR / f"artifact_{artifact_id}.png"
        icon = Image.open(path).convert("RGBA")
        small = icon.resize((40, 40), Image.Resampling.LANCZOS)
        x = (index % cols) * cell_w
        y = (index // cols) * cell_h
        draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=(67, 61, 76, 255))
        sheet.alpha_composite(icon, (x + 17, y + 14))
        sheet.alpha_composite(small, (x + 124, y + 272))
        draw.text((x + 8, y + 318), artifact_id, fill=(225, 216, 198, 255), font=font)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW_PATH)


def main() -> int:
    ids = parse_artifact_ids()
    failed: dict[str, list[str]] = {}
    for artifact_id in ids:
        path = ARTIFACT_DIR / f"artifact_{artifact_id}.png"
        errors = validate_icon(path)
        if errors:
            failed[artifact_id] = errors
    build_preview(ids)
    if failed:
        for artifact_id, errors in failed.items():
            print(f"{artifact_id}: {'; '.join(errors)}")
        return 1
    print(f"Validated {len(ids)} artifact icons")
    print(f"Wrote {PREVIEW_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
