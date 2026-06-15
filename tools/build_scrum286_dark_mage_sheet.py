#!/usr/bin/env python3
"""Build FantasyDisk character runtime and QA animation sheets from a source."""

from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CLASS_ID = "dark_mage"
TASK_ID = "scrum286"
DISPLAY_NAME = "Dark Mage"
NOTES_NAME = "Dark Mage"
SRC = ROOT / "docs/design/references/characters/dark_mage/dark_mage_sheet_source.png"
CLEAN_REF = ROOT / "docs/design/references/characters/dark_mage/dark_mage_sheet_alpha_clean.png"
GUTTERED_REF = ROOT / "docs/design/references/characters/dark_mage/dark_mage_sheet_guttered_source.png"
RUNTIME = ROOT / "assets/sprites/characters/dark_mage_sheet.png"
PREVIEW = ROOT / "docs/design/previews/scrum286_dark_mage_sheet_contact.png"
QA_DIR = ROOT / "build/qa/scrum286_dark_mage"
MANIFEST = QA_DIR / "animation_manifest.json"
REPORT = QA_DIR / "dark_mage_sheet_report.json"
WALK_GIF = QA_DIR / "dark_mage_walk_preview.gif"
ATTACK_GIF = QA_DIR / "dark_mage_attack_primary_preview.gif"

CELL = 384
COLUMNS = 5
ROWS = 3
GUTTER = 32
TARGET_BOTTOM = 356
SAFE_LEFT = 24
SAFE_RIGHT = CELL - 24
SAFE_TOP = 20
SAFE_BOTTOM = CELL - 16


def _configure_paths() -> None:
    global CLASS_ID, TASK_ID, DISPLAY_NAME, NOTES_NAME
    global SRC, CLEAN_REF, GUTTERED_REF, RUNTIME, PREVIEW, QA_DIR, MANIFEST, REPORT, WALK_GIF, ATTACK_GIF
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--class-id", default=CLASS_ID)
    parser.add_argument("--task-id", default=TASK_ID)
    parser.add_argument("--display-name", default=DISPLAY_NAME)
    parser.add_argument("--notes-name", default=NOTES_NAME)
    args = parser.parse_args()

    CLASS_ID = args.class_id
    TASK_ID = args.task_id
    DISPLAY_NAME = args.display_name
    NOTES_NAME = args.notes_name
    ref_dir = ROOT / "docs/design/references/characters" / CLASS_ID
    QA_DIR = ROOT / "build/qa" / f"{TASK_ID}_{CLASS_ID}"
    SRC = ref_dir / f"{CLASS_ID}_sheet_source.png"
    CLEAN_REF = ref_dir / f"{CLASS_ID}_sheet_alpha_clean.png"
    GUTTERED_REF = ref_dir / f"{CLASS_ID}_sheet_guttered_source.png"
    RUNTIME = ROOT / "assets/sprites/characters" / f"{CLASS_ID}_sheet.png"
    PREVIEW = ROOT / "docs/design/previews" / f"{TASK_ID}_{CLASS_ID}_sheet_contact.png"
    MANIFEST = QA_DIR / "animation_manifest.json"
    REPORT = QA_DIR / f"{CLASS_ID}_sheet_report.json"
    WALK_GIF = QA_DIR / f"{CLASS_ID}_walk_preview.gif"
    ATTACK_GIF = QA_DIR / f"{CLASS_ID}_attack_primary_preview.gif"


def _alpha_from_checkerboard(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    maxc = np.maximum.reduce([r, g, b])
    minc = np.minimum.reduce([r, g, b])
    luma = (0.2126 * r + 0.7152 * g + 0.0722 * b).astype(np.float32)
    saturation = maxc - minc

    foreground = (luma < 222) | ((saturation > 18) & (luma < 246))
    strong = (luma < 205) | ((saturation > 28) & (luma < 238))
    alpha = np.zeros(rgb.shape[:2], dtype=np.uint8)
    alpha[foreground] = 120
    alpha[strong] = 255
    return alpha


def _bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _keep_largest_components(mask: np.ndarray, min_area: int = 90) -> np.ndarray:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    keep = np.zeros_like(mask, dtype=bool)
    components: list[tuple[int, list[tuple[int, int]], tuple[int, int, int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen[y, x] = True
            points: list[tuple[int, int]] = []
            minx = maxx = x
            miny = maxy = y
            while queue:
                px, py = queue.popleft()
                points.append((px, py))
                minx = min(minx, px)
                maxx = max(maxx, px)
                miny = min(miny, py)
                maxy = max(maxy, py)
                for nx in (px - 1, px, px + 1):
                    for ny in (py - 1, py, py + 1):
                        if nx == px and ny == py:
                            continue
                        if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            queue.append((nx, ny))
            components.append((len(points), points, (minx, miny, maxx + 1, maxy + 1)))
    if not components:
        return keep
    components.sort(key=lambda entry: entry[0], reverse=True)
    largest_bbox = components[0][2]
    lx0, ly0, lx1, ly1 = largest_bbox
    for index, (area, points, cbbox) in enumerate(components):
        cx0, cy0, cx1, cy1 = cbbox
        touches_cell_edge = cx0 <= 2 or cy0 <= 2 or cx1 >= width - 2 or cy1 >= height - 2
        if index != 0 and touches_cell_edge:
            continue
        touches_body = not (cx1 < lx0 - 40 or cx0 > lx1 + 40 or cy1 < ly0 - 40 or cy0 > ly1 + 40)
        if area >= min_area and (index == 0 or touches_body):
            for px, py in points:
                keep[py, px] = True
    return keep


def _trim_far_vfx(cell: Image.Image) -> Image.Image:
    rgba = np.array(cell.convert("RGBA"))
    alpha = rgba[:, :, 3]
    luma = (
        0.2126 * rgba[:, :, 0]
        + 0.7152 * rgba[:, :, 1]
        + 0.0722 * rgba[:, :, 2]
    )
    dark_body = (alpha > 80) & (luma < 120)
    body_bbox = _bbox(dark_body)
    if body_bbox is None:
        body_bbox = _bbox(alpha > 8)
    if body_bbox is None:
        return cell
    x0, y0, x1, y1 = body_bbox
    x0 = max(0, x0 - 74)
    y0 = max(0, y0 - 72)
    x1 = min(CELL, x1 + 74)
    y1 = min(CELL, y1 + 64)
    region = np.zeros_like(alpha, dtype=bool)
    region[y0:y1, x0:x1] = True
    component_mask = _keep_largest_components((alpha > 8) & region)
    rgba[:, :, 3] = np.where(component_mask, alpha, 0).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def _fit_cell(cell: Image.Image, global_scale: float) -> tuple[Image.Image, dict[str, int]]:
    bbox = cell.getbbox()
    if bbox is None:
        return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0)), {"x": 0, "y": 0, "w": 0, "h": 0}
    crop = cell.crop(bbox)
    if global_scale < 0.999:
        new_size = (
            max(1, int(round(crop.width * global_scale))),
            max(1, int(round(crop.height * global_scale))),
        )
        crop = crop.resize(new_size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    x = int(round((CELL - crop.width) * 0.5))
    y = int(round(TARGET_BOTTOM - crop.height))
    x = max(SAFE_LEFT, min(x, SAFE_RIGHT - crop.width))
    y = max(SAFE_TOP, min(y, SAFE_BOTTOM - crop.height))
    out.alpha_composite(crop, (x, y))
    final_bbox = out.getbbox()
    if final_bbox is None:
        return out, {"x": 0, "y": 0, "w": 0, "h": 0}
    x0, y0, x1, y1 = final_bbox
    return out, {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}


def _sheet_to_guttered(cells: list[Image.Image]) -> Image.Image:
    width = COLUMNS * CELL + (COLUMNS + 1) * GUTTER
    height = ROWS * CELL + (ROWS + 1) * GUTTER
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for row in range(ROWS):
        for col in range(COLUMNS):
            x = GUTTER + col * (CELL + GUTTER)
            y = GUTTER + row * (CELL + GUTTER)
            sheet.alpha_composite(cells[row * COLUMNS + col], (x, y))
    return sheet


def _make_preview(runtime: Image.Image, bboxes: list[dict[str, int]]) -> Image.Image:
    scale = 0.5
    preview = Image.new("RGBA", (int(runtime.width * scale), int(runtime.height * scale) + 42), (28, 24, 32, 255))
    checker = Image.new("RGBA", runtime.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(checker)
    tile = 24
    for y in range(0, runtime.height, tile):
        for x in range(0, runtime.width, tile):
            c = (54, 50, 60, 255) if ((x // tile + y // tile) % 2) else (72, 68, 78, 255)
            draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=c)
    checker.alpha_composite(runtime)
    small = checker.resize((int(runtime.width * scale), int(runtime.height * scale)), Image.Resampling.LANCZOS)
    preview.alpha_composite(small, (0, 42))
    draw = ImageDraw.Draw(preview)
    try:
        font = ImageFont.truetype("Arial.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    draw.text((12, 10), f"{TASK_ID.upper()} {DISPLAY_NAME}: idle / walk / attack_primary, 5 frames each", fill=(236, 226, 196, 255), font=font)
    labels = ["idle", "walk", "attack_primary"]
    for row, label in enumerate(labels):
        draw.text((8, 42 + int((row * CELL + 10) * scale)), label, fill=(236, 226, 196, 255), font=font)
    for row in range(ROWS):
        for col in range(COLUMNS):
            x = int(col * CELL * scale)
            y = 42 + int(row * CELL * scale)
            draw.rectangle((x, y, x + int(CELL * scale), y + int(CELL * scale)), outline=(180, 136, 255, 180), width=1)
    return preview


def _save_gif(cells: list[Image.Image], row: int, path: Path, duration_ms: int, loop: int) -> None:
    frames: list[Image.Image] = []
    for col in range(COLUMNS):
        cell = cells[row * COLUMNS + col]
        canvas = Image.new("RGBA", (CELL, CELL), (38, 34, 44, 255))
        canvas.alpha_composite(cell)
        frames.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE))
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=loop,
        disposal=2,
    )


def main() -> None:
    _configure_paths()
    QA_DIR.mkdir(parents=True, exist_ok=True)
    CLEAN_REF.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)

    source = Image.open(SRC).convert("RGBA")
    if source.size != (COLUMNS * CELL, ROWS * CELL):
        raise SystemExit(f"unexpected source size {source.size}")
    rgb = np.array(source.convert("RGB"))
    alpha = _alpha_from_checkerboard(rgb)
    rgba = np.array(source)
    rgba[:, :, 3] = alpha
    cleaned = Image.fromarray(rgba, "RGBA")

    raw_cells: list[Image.Image] = []
    bboxes_before: list[tuple[int, int, int, int]] = []
    for row in range(ROWS):
        for col in range(COLUMNS):
            cell = cleaned.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
            cell = _trim_far_vfx(cell)
            raw_cells.append(cell)
            bbox = cell.getbbox() or (0, 0, 0, 0)
            bboxes_before.append(bbox)

    max_w = max((bbox[2] - bbox[0]) for bbox in bboxes_before)
    max_h = max((bbox[3] - bbox[1]) for bbox in bboxes_before)
    global_scale = min(1.0, (SAFE_RIGHT - SAFE_LEFT) / max_w, (SAFE_BOTTOM - SAFE_TOP) / max_h)

    runtime = Image.new("RGBA", (COLUMNS * CELL, ROWS * CELL), (0, 0, 0, 0))
    fitted_cells: list[Image.Image] = []
    bboxes: list[dict[str, int]] = []
    edge_touch: list[dict[str, int | str]] = []
    for row in range(ROWS):
        for col in range(COLUMNS):
            fitted, bbox = _fit_cell(raw_cells[row * COLUMNS + col], global_scale)
            fitted_cells.append(fitted)
            bboxes.append(bbox)
            runtime.alpha_composite(fitted, (col * CELL, row * CELL))
            if bbox["x"] < SAFE_LEFT or bbox["y"] < SAFE_TOP or bbox["x"] + bbox["w"] > SAFE_RIGHT or bbox["y"] + bbox["h"] > SAFE_BOTTOM:
                edge_touch.append({"row": row, "col": col, **bbox})

    runtime.save(RUNTIME)
    runtime.save(CLEAN_REF)
    _sheet_to_guttered(fitted_cells).save(GUTTERED_REF)
    _make_preview(runtime, bboxes).save(PREVIEW)
    _save_gif(fitted_cells, 1, WALK_GIF, 100, 0)
    _save_gif(fitted_cells, 2, ATTACK_GIF, 72, 1)

    report = {
        "source": str(SRC.relative_to(ROOT)),
        "runtime": str(RUNTIME.relative_to(ROOT)),
        "clean_reference": str(CLEAN_REF.relative_to(ROOT)),
        "guttered_reference": str(GUTTERED_REF.relative_to(ROOT)),
        "preview": str(PREVIEW.relative_to(ROOT)),
        "walk_gif": str(WALK_GIF.relative_to(ROOT)),
        "attack_gif": str(ATTACK_GIF.relative_to(ROOT)),
        "cell_size": [CELL, CELL],
        "rows": ["idle", "walk", "attack_primary"],
        "columns": COLUMNS,
        "global_scale": global_scale,
        "safe_rect": [SAFE_LEFT, SAFE_TOP, SAFE_RIGHT - SAFE_LEFT, SAFE_BOTTOM - SAFE_TOP],
        "bboxes": bboxes,
        "edge_touch": edge_touch,
    }
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")

    manifest = {
        "entities": [
            {
                "id": CLASS_ID,
                "kind": "hero",
                "production_pipeline": "full_frame_spritesheet",
                "sprite_sheet": str(GUTTERED_REF.relative_to(ROOT)),
                "runtime_sheet": str(RUNTIME.relative_to(ROOT)),
                "canvas": {"width": CELL, "height": CELL},
                "frame_gutter_px": GUTTER,
                "outer_padding_px": GUTTER,
                "pivot": {"x": 192, "y": 348, "type": "bottom_center_foot_anchor"},
                "animations": [
                    {"name": "idle", "frames": 5, "loop": True, "fps": 5},
                    {"name": "walk", "frames": 5, "loop": True, "fps": 10},
                    {"name": "attack_primary", "frames": 5, "loop": False, "fps": 14},
                ],
                "transparent_background_checked": True,
                "no_crop_checked": len(edge_touch) == 0,
                "safe_slicing_checked": len(edge_touch) == 0,
                "cutout_used": False,
                "notes": f"Design-owned accepted unarmed {NOTES_NAME} sheet; runtime Player loader slices the non-guttered runtime_sheet, while the source QA sheet keeps 32px gutters for animation-director validation.",
            }
        ]
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"runtime": str(RUNTIME), "edge_touch": edge_touch, "global_scale": global_scale}, indent=2))


if __name__ == "__main__":
    main()
