#!/usr/bin/env python3
"""Normalize PixelLab SCRUM-917 frames and build committed QA evidence."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "docs/design/references/weapon_attack_animations/robot_hydraulic_press/pixellab_animation_raw"
RUNTIME_DIR = ROOT / "assets/sprites/effects/robot_hydraulic_press_compression"
REPORT_PATH = ROOT / "docs/design/references/weapon_attack_animations/robot_hydraulic_press/compression_animation_report.json"
PREVIEW_PATH = ROOT / "docs/design/previews/weapon_attack_animations/robot_hydraulic_press_compression_contact.png"
CANVAS = 256
CONTENT = 224
OFFSET = (CANVAS - CONTENT) // 2
FPS = 25.0
ACTIVE_FRAME = 5


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def metrics(image: Image.Image) -> dict:
    alpha = image.getchannel("A")
    bbox = alpha_bbox(image)
    values = list(alpha.getdata())
    edge_visible = 0
    for x in range(CANVAS):
        edge_visible += int(alpha.getpixel((x, 0)) > 0)
        edge_visible += int(alpha.getpixel((x, CANVAS - 1)) > 0)
    for y in range(1, CANVAS - 1):
        edge_visible += int(alpha.getpixel((0, y)) > 0)
        edge_visible += int(alpha.getpixel((CANVAS - 1, y)) > 0)
    gutters = None
    if bbox:
        gutters = [bbox[0], bbox[1], CANVAS - bbox[2], CANVAS - bbox[3]]
    return {
        "size": [image.width, image.height],
        "mode": image.mode,
        "alpha_bbox": list(bbox) if bbox else None,
        "gutters_px": gutters,
        "minimum_gutter_px": min(gutters) if gutters else None,
        "edge_visible_pixels": edge_visible,
        "visible_pixels_alpha_gt_8": sum(value > 8 for value in values),
        "max_alpha": max(values),
    }


def normalize(raw: Image.Image) -> Image.Image:
    raw = raw.convert("RGBA")
    if raw.size != (CANVAS, CANVAS):
        raise ValueError(f"PixelLab frame must be {CANVAS}x{CANVAS}, got {raw.size}")
    # Nearest-neighbour inset is a mechanical safe-gutter normalization only:
    # it preserves the PixelLab pixels and stable centre pivot without repainting.
    inset = raw.resize((CONTENT, CONTENT), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(inset, (OFFSET, OFFSET))
    return canvas


def build_contact(frames: list[Image.Image]) -> None:
    width, height = 1280, 720
    canvas = Image.new("RGB", (width, height), (14, 13, 18))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 16), "SCRUM-917  PixelLab Hydraulic Press: side-to-center compression", fill=(232, 214, 174))
    draw.text((24, 36), "8 frames / 25 fps / active crush frame 5 at 0.20s / runtime 430x300 or 430x390", fill=(154, 214, 206))
    origin_x, origin_y = 128, 70
    row_step = 320
    for index, frame in enumerate(frames):
        x = origin_x + (index % 4) * 256
        y = origin_y + (index // 4) * row_step
        cell = Image.new("RGBA", (256, 256), (31, 28, 36, 255))
        cell.alpha_composite(frame)
        canvas.paste(cell.convert("RGB"), (x, y))
        label = f"frame {index}   t={index / FPS:.2f}s"
        if index == ACTIVE_FRAME:
            label += "   ACTIVE CRUSH"
        draw.text((x + 7, y + 262), label, fill=(255, 206, 106) if index == ACTIVE_FRAME else (224, 220, 210))
        if index == ACTIVE_FRAME:
            draw.rectangle((x + 2, y + 2, x + 253, y + 253), outline=(255, 178, 54), width=3)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(PREVIEW_PATH)


def main() -> None:
    raw_paths = sorted(RAW_DIR.glob("robot_hydraulic_press_compress_*.png"))
    if len(raw_paths) != 8:
        raise SystemExit(f"Expected 8 PixelLab frames, found {len(raw_paths)}")
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    runtime_frames: list[Image.Image] = []
    rows = []
    for index, raw_path in enumerate(raw_paths):
        raw = Image.open(raw_path).convert("RGBA")
        runtime = normalize(raw)
        runtime_path = RUNTIME_DIR / f"robot_hydraulic_press_compress_{index:02d}.png"
        runtime.save(runtime_path)
        runtime_frames.append(runtime)
        row = {
            "index": index,
            "time_seconds": round(index / FPS, 3),
            "active_crush": index == ACTIVE_FRAME,
            "raw_path": str(raw_path.relative_to(ROOT)),
            "runtime_path": str(runtime_path.relative_to(ROOT)),
            "raw_metrics": metrics(raw),
            "runtime_metrics": metrics(runtime),
            "runtime_sha256": hashlib.sha256(runtime_path.read_bytes()).hexdigest(),
        }
        if row["runtime_metrics"]["minimum_gutter_px"] < 16:
            raise SystemExit(f"Frame {index} lacks the required 16px runtime gutter")
        if row["runtime_metrics"]["edge_visible_pixels"] != 0:
            raise SystemExit(f"Frame {index} touches the runtime canvas edge")
        rows.append(row)
    build_contact(runtime_frames)
    report = {
        "issue": "SCRUM-917",
        "weapon_id": "robot_hydraulic_press",
        "pixel_lab_source_object_id": "99b9c7ec-23d3-4110-a22a-912cf8b455b8",
        "pixel_lab_animation_group_id": "659bdae5-22a9-4319-a3ca-57b972e5a9a3",
        "pixel_lab_animation_id": "31a9bfff-ee16-4037-a8f5-32477c37a73c",
        "pixel_lab_only": True,
        "openai_images_used": False,
        "normalization": {
            "source_canvas": [CANVAS, CANVAS],
            "runtime_canvas": [CANVAS, CANVAS],
            "content_inset": [OFFSET, OFFSET, OFFSET, OFFSET],
            "resampling": "nearest",
            "pivot": [CANVAS // 2, CANVAS // 2],
        },
        "animation": {
            "name": "compress",
            "frame_count": len(rows),
            "fps": FPS,
            "loop": False,
            "active_frame_index": ACTIVE_FRAME,
            "active_frame_time_seconds": ACTIVE_FRAME / FPS,
        },
        "geometry": {
            "start_offset_px": 28.0,
            "attack_range_px": 430.0,
            "corridor_width_px": 300.0,
            "calibrator_corridor_width_px": 390.0,
            "centre_beam_width_px": 120.0,
            "compression_axis": "perpendicular_to_attack",
        },
        "frames": rows,
        "preview": str(PREVIEW_PATH.relative_to(ROOT)),
        "decision": "pass",
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SCRUM-917 normalized {len(rows)} frames; report={REPORT_PATH.relative_to(ROOT)}")
    print(f"contact={PREVIEW_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
