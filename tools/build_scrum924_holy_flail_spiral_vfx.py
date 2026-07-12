#!/usr/bin/env python3
"""Normalize PixelLab SCRUM-924 frames and build committed QA evidence."""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
REF_DIR = ROOT / "docs/design/references/scrum924_holy_flail_spiral_vfx"
RAW_DIR = REF_DIR / "pixellab_raw/animation"
CLEAN_DIR = REF_DIR / "pixellab_alpha_clean"
RUNTIME_DIR = ROOT / "assets/sprites/effects/holy_flail_spiral"
REPORT_PATH = REF_DIR / "frame_qa_report.json"
MANIFEST_PATH = REF_DIR / "manifest.json"
PREVIEW_PATH = ROOT / "docs/design/previews/scrum924_holy_flail_spiral_vfx_contact.png"
SPRITEFRAMES_PATH = RUNTIME_DIR / "holy_flail_spiral_spriteframes.tres"
CANVAS = 256
CONTENT = 224
OFFSET = (CANVAS - CONTENT) // 2
FRAME_COUNT = 8
STEP_COUNT = 7
STEP_TIME = 0.085
PIXELLAB_OBJECT_ID = "b1089fd9-a4c7-49ce-aec2-af62fb0317b6"
PIXELLAB_GROUP_ID = "50cb9b87-58b3-411e-af3e-caabce8b4cb4"


def _distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return sum((a[i] - b[i]) ** 2 for i in range(3)) ** 0.5


def remove_flat_edge_background(image: Image.Image) -> Image.Image:
    """Remove only edge-connected near-flat preview pixels; no repainting."""
    image = image.convert("RGBA")
    pixels = image.load()
    corners = [pixels[0, 0][:3], pixels[CANVAS - 1, 0][:3],
               pixels[0, CANVAS - 1][:3], pixels[CANVAS - 1, CANVAS - 1][:3]]
    background = tuple(round(sum(c[channel] for c in corners) / 4) for channel in range(3))
    queued: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()
    for x in range(CANVAS):
        queued.append((x, 0)); queued.append((x, CANVAS - 1))
    for y in range(1, CANVAS - 1):
        queued.append((0, y)); queued.append((CANVAS - 1, y))
    while queued:
        x, y = queued.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))
        if _distance(pixels[x, y][:3], background) > 34.0:
            continue
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        if x > 0: queued.append((x - 1, y))
        if x + 1 < CANVAS: queued.append((x + 1, y))
        if y > 0: queued.append((x, y - 1))
        if y + 1 < CANVAS: queued.append((x, y + 1))
    # Calm combat alpha while preserving the PixelLab RGB pixels.
    for y in range(CANVAS):
        for x in range(CANVAS):
            r, g, b, alpha = pixels[x, y]
            if alpha:
                pixels[x, y] = (r, g, b, min(alpha, 190))
    return image


def normalize(clean: Image.Image) -> Image.Image:
    inset = clean.resize((CONTENT, CONTENT), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(inset, (OFFSET, OFFSET))
    return canvas


def metrics(image: Image.Image) -> dict:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    values = list(alpha.getdata())
    gutters = [bbox[0], bbox[1], CANVAS - bbox[2], CANVAS - bbox[3]] if bbox else None
    edge_visible = sum(alpha.getpixel((x, y)) > 8 for x in range(CANVAS) for y in (0, CANVAS - 1))
    edge_visible += sum(alpha.getpixel((x, y)) > 8 for y in range(1, CANVAS - 1) for x in (0, CANVAS - 1))
    return {
        "size": [image.width, image.height],
        "mode": image.mode,
        "alpha_bbox_gt_8": list(bbox) if bbox else None,
        "gutters_px": gutters,
        "minimum_gutter_px": min(gutters) if gutters else None,
        "edge_visible_pixels": edge_visible,
        "visible_pixels_alpha_gt_8": sum(value > 8 for value in values),
        "visible_ratio_alpha_gt_8": round(sum(value > 8 for value in values) / len(values), 4),
        "max_alpha": max(values),
    }


def write_spriteframes() -> None:
    lines = [f'[gd_resource type="SpriteFrames" load_steps={FRAME_COUNT + 1} format=3]', ""]
    for index in range(FRAME_COUNT):
        lines.append('[ext_resource type="Texture2D" path="res://assets/sprites/effects/holy_flail_spiral/holy_flail_spiral_%02d.png" id="%d_frame"]' % (index, index + 1))
    lines.extend(["", "[resource]", "animations = [{", '"frames": ['])
    for index in range(FRAME_COUNT):
        suffix = "," if index + 1 < FRAME_COUNT else ""
        lines.extend(["{", '"duration": 1.0,', '"texture": ExtResource("%d_frame")' % (index + 1), "}%s" % suffix])
    lines.extend([
        '],',
        '"loop": false,',
        '"name": &"spiral",',
        '"speed": %.6f' % (1.0 / STEP_TIME),
        '}, {',
        '"frames": [{',
        '"duration": 1.0,',
        '"texture": ExtResource("1_frame")',
        '}],',
        '"loop": true,',
        '"name": &"default",',
        '"speed": 5.0',
        '}])',
    ])
    SPRITEFRAMES_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_contact(frames: list[Image.Image]) -> None:
    canvas = Image.new("RGB", (1280, 720), (15, 13, 19))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 16), "SCRUM-924  PixelLab Holy Flail: center-to-outer spiral", fill=(238, 214, 157))
    draw.text((24, 38), "8 authored frames / runtime 7 steps x 0.085s / radius 22% -> 100% / pivot center", fill=(177, 196, 219))
    for index, frame in enumerate(frames):
        x = 128 + (index % 4) * 256
        y = 70 + (index // 4) * 320
        cell = Image.new("RGBA", (256, 256), (34, 30, 40, 255))
        cell.alpha_composite(frame)
        canvas.paste(cell.convert("RGB"), (x, y))
        role = "outer closure" if index == 6 else ("settle" if index == 7 else "spiral step %d" % (index + 1))
        draw.text((x + 8, y + 262), "frame %d  %s" % (index, role), fill=(255, 204, 98) if index == 6 else (223, 219, 210))
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(PREVIEW_PATH)


def main() -> None:
    raw_paths = sorted(RAW_DIR.glob("holy_flail_spiral_*.png"))
    if len(raw_paths) != FRAME_COUNT:
        raise SystemExit("Expected %d PixelLab frames in %s, found %d" % (FRAME_COUNT, RAW_DIR, len(raw_paths)))
    CLEAN_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    runtime_frames: list[Image.Image] = []
    rows = []
    for index, raw_path in enumerate(raw_paths):
        raw = Image.open(raw_path).convert("RGBA")
        if raw.size != (CANVAS, CANVAS):
            raise SystemExit("PixelLab frame %d is %s, expected 256x256" % (index, raw.size))
        clean = remove_flat_edge_background(raw)
        clean_path = CLEAN_DIR / ("holy_flail_spiral_%02d.png" % index)
        clean.save(clean_path)
        runtime = normalize(clean)
        runtime_path = RUNTIME_DIR / ("holy_flail_spiral_%02d.png" % index)
        runtime.save(runtime_path)
        report = metrics(runtime)
        if not report["alpha_bbox_gt_8"]:
            raise SystemExit("Frame %d is empty after alpha cleanup" % index)
        if report["minimum_gutter_px"] < 16 or report["edge_visible_pixels"]:
            raise SystemExit("Frame %d failed gutter/edge contract: %s" % (index, report))
        rows.append({
            "index": index,
            "runtime_step": index if index < STEP_COUNT else None,
            "time_seconds": round(index * STEP_TIME, 3),
            "raw_path": str(raw_path.relative_to(ROOT)),
            "clean_path": str(clean_path.relative_to(ROOT)),
            "runtime_path": str(runtime_path.relative_to(ROOT)),
            "runtime_metrics": report,
            "runtime_sha256": hashlib.sha256(runtime_path.read_bytes()).hexdigest(),
        })
        runtime_frames.append(runtime)
    write_spriteframes()
    build_contact(runtime_frames)
    qa = {
        "issue": "SCRUM-924",
        "weapon_id": "holy_flail",
        "pixel_lab_object_id": PIXELLAB_OBJECT_ID,
        "pixel_lab_animation_group_id": PIXELLAB_GROUP_ID,
        "pixel_lab_only": True,
        "openai_images_used": False,
        "normalization": "PixelLab RGB retained; edge-connected flat preview background removed; alpha capped at 190; full canvas nearest-neighbour inset 16px",
        "pivot": [128, 128],
        "frame_count": FRAME_COUNT,
        "runtime_step_count": STEP_COUNT,
        "step_time_seconds": STEP_TIME,
        "frames": rows,
        "decision": "pass",
    }
    REPORT_PATH.write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("SCRUM-924 built %d PixelLab frames" % FRAME_COUNT)
    print("report=%s" % REPORT_PATH.relative_to(ROOT))
    print("preview=%s" % PREVIEW_PATH.relative_to(ROOT))


if __name__ == "__main__":
    main()
