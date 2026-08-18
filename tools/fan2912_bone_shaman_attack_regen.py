#!/usr/bin/env python3
"""FAN-2912: regenerate the bone_shaman attack rows west/east/north/north-east.

Two PixelLab generation passes went into the final source frames:

- west: v3 custom animation (group ccd339c7-..., job a473dcc5-...), 6 animated
  frames after dropping the keep_first_frame reference pose. Passed review on
  the first attempt (identity + staff + swing all correct).
- east/north/north-east: v3 mode lost identity or staff readability twice in a
  row, so these three escalated to "pro" mode (cross-direction reference,
  higher quality). Pro mode returns a fixed 16 frames for this canvas size (no
  separate reference frame) instead of v3's frame_count; 6 frames evenly
  sampled at indices [0, 3, 6, 9, 12, 15] were selected to match the existing
  6-frame attack contract (frame count, fps=12.0) and give a readable
  anticipation -> windup -> swing -> cast progression.

Normalizes every source frame with the same maths as
tools/build_fan2618_bone_shaman_pack.py (245px visible height, 32px bottom
padding, transparent 512x512 canvas) and overwrites only the four
regenerated rows' PNGs in place -- same file names, so
bone_shaman_spriteframes.tres needs no edits. idle/move/hit/death and the
other four attack rows are untouched.
"""
from __future__ import annotations

import json
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
USER_AGENT = "FantasyDisk-FAN2912/1.0"

SOURCE_DIR = ROOT / "assets/sprites/enemies/pixellab/bone_shaman"
RUNTIME_DIR = ROOT / "assets/sprites/enemies/full_frame/bone_shaman"

BASE = (
    "https://backblaze.pixellab.ai/file/pixellab-characters/"
    "7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/fa5b71b2-0532-404b-b5d9-b640d0bef7c0/"
    "animations/{job}/{direction}/{index}.png"
)

# west: v3 mode, job holds [reference, frame0..frame5] -> use source indices 1..6
# east/north/north-east: pro mode, job holds 16 animated frames (no reference) ->
# sample indices [0, 3, 6, 9, 12, 15] directly
JOBS = {
    "west": {"job": "a473dcc5-8ed5-4498-8824-912539dc8f02", "source_indices": [1, 2, 3, 4, 5, 6]},
    "east": {"job": "b5022c4a-af9f-4b41-bf2a-8d2a8e714e4a", "source_indices": [0, 3, 6, 9, 12, 15]},
    "north": {"job": "41030a2e-cd4e-4f35-a102-1d37cefd088b", "source_indices": [0, 3, 6, 9, 12, 15]},
    "north-east": {"job": "bdae2049-8965-44aa-9876-5934529f194e", "source_indices": [0, 3, 6, 9, 12, 15]},
}


def suffix(direction: str) -> str:
    return direction.replace("-", "_")


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(response.read())


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def normalize_frame(source_path: Path, dest_path: Path) -> dict:
    image = Image.open(source_path).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"{source_path} has no visible alpha")
    bbox_width = bbox[2] - bbox[0]
    bbox_height = bbox[3] - bbox[1]
    height_scale = TARGET_VISIBLE_HEIGHT / float(bbox_height)
    width_scale = CELL_SIZE / float(bbox_width)
    scale = min(height_scale, width_scale)
    scaled_size = (max(1, round(bbox_width * scale)), max(1, round(bbox_height * scale)))
    resized = image.crop(bbox).resize(scaled_size, Image.Resampling.NEAREST)
    paste_x = round((CELL_SIZE - scaled_size[0]) / 2.0)
    paste_y = CELL_SIZE - BOTTOM_PADDING - scaled_size[1]
    if paste_x < 0 or paste_y < 0 or paste_x + scaled_size[0] > CELL_SIZE or paste_y + scaled_size[1] > CELL_SIZE:
        raise RuntimeError(f"{source_path} normalized outside canvas ({scaled_size})")
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (paste_x, paste_y))
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest_path)
    runtime_bbox = alpha_bbox(canvas)
    return {
        "source": source_path.name,
        "runtime": dest_path.name,
        "source_size": list(image.size),
        "source_alpha_bbox": list(bbox),
        "source_alpha_bbox_size": [bbox_width, bbox_height],
        "scale": scale,
        "resized_visible_size": list(scaled_size),
        "runtime_alpha_bbox": list(runtime_bbox) if runtime_bbox else None,
        "runtime_alpha_bbox_bottom": runtime_bbox[3] if runtime_bbox else None,
    }


def main() -> int:
    alpha_report_path = SOURCE_DIR / "alpha_bbox_report.json"
    alpha_report = json.loads(alpha_report_path.read_text(encoding="utf-8"))

    for direction, spec in JOBS.items():
        s = suffix(direction)
        job = spec["job"]
        reports = []
        for out_index, src_index in enumerate(spec["source_indices"]):
            url = BASE.format(job=job, direction=direction, index=src_index)
            src = SOURCE_DIR / f"bone_shaman_attack_{s}_{out_index:02d}.png"
            dest = RUNTIME_DIR / f"bone_shaman_attack_{s}_{out_index:02d}.png"
            download(url, src)
            reports.append(normalize_frame(src, dest))
        alpha_report[f"attack_{s}"] = reports
        print(f"regenerated attack_{s}: {len(reports)} frames")

    alpha_report_path.write_text(json.dumps(alpha_report, indent=2), encoding="utf-8")
    print(f"wrote {alpha_report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
