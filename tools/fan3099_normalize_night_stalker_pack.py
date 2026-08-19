#!/usr/bin/env python3
"""FAN-3099: normalize the already-generated night_stalker frames in place.

FAN-2757 rejected the night_stalker candidate on geometry only: the 368
frames were committed straight from PixelLab on their raw per-state canvases
(128/164/168/172px) instead of going through the fleet-standard normalize
pass, so the silhouette scale and footline drifted between states/directions.
No regeneration is involved -- this script re-normalizes the existing PNGs
in place (same paths, same night_stalker_spriteframes.tres) using the exact
normalize_frame() maths already used for the accepted 512x512 / 245px /
32px-bottom-padding elite packs (mini_rot_hound, ash_marksman, bone_caller,
small_biter): see tools/update_pixellab_character_animations.py.

It additionally despeckles: connected alpha islands of 4px or fewer, sitting
away from the main silhouette, are cleared before the bbox is measured so a
stray PixelLab dust pixel can no longer blow up the crop/scale like it did in
the rejected candidate.

Usage:
  python3 tools/fan3099_normalize_night_stalker_pack.py [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FRAME_DIR = ROOT / "assets/sprites/elites/full_frame/night_stalker"
MANIFEST_PATH = ROOT / "assets/sprites/elites/pixellab/night_stalker/manifest.json"
REPORT_PATH = ROOT / "assets/sprites/elites/pixellab/night_stalker/alpha_bbox_report.json"

CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
DUST_ISLAND_MAX_PIXELS = 4


def despeckle(image: Image.Image) -> tuple[Image.Image, int]:
    """Zero out connected alpha islands with <= DUST_ISLAND_MAX_PIXELS pixels."""
    alpha = image.getchannel("A")
    width, height = alpha.size
    pixels = alpha.load()
    visited = bytearray(width * height)
    removed = 0
    out = image.copy()
    out_pixels = out.load()

    for start_y in range(height):
        for start_x in range(width):
            idx = start_y * width + start_x
            if visited[idx] or pixels[start_x, start_y] == 0:
                continue
            component: list[tuple[int, int]] = []
            queue = deque([(start_x, start_y)])
            visited[idx] = 1
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
                               (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1)):
                    if 0 <= nx < width and 0 <= ny < height:
                        nidx = ny * width + nx
                        if not visited[nidx] and pixels[nx, ny] != 0:
                            visited[nidx] = 1
                            queue.append((nx, ny))
            if len(component) <= DUST_ISLAND_MAX_PIXELS:
                for x, y in component:
                    out_pixels[x, y] = (0, 0, 0, 0)
                removed += 1
    return out, removed


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def normalize_frame(source_path: Path) -> dict:
    image = Image.open(source_path).convert("RGBA")
    cleaned, dust_islands_removed = despeckle(image)
    bbox = alpha_bbox(cleaned)
    if bbox is None:
        raise RuntimeError(f"{source_path} has no visible alpha after despeckle")
    bbox_width = bbox[2] - bbox[0]
    bbox_height = bbox[3] - bbox[1]
    scale = TARGET_VISIBLE_HEIGHT / float(bbox_height)
    scaled_size = (max(1, round(bbox_width * scale)), TARGET_VISIBLE_HEIGHT)
    resized = cleaned.crop(bbox).resize(scaled_size, Image.Resampling.NEAREST)
    paste_x = round((CELL_SIZE - scaled_size[0]) / 2.0)
    paste_y = CELL_SIZE - BOTTOM_PADDING - scaled_size[1]
    if paste_x < 0 or paste_y < 0 or paste_x + scaled_size[0] > CELL_SIZE or paste_y + scaled_size[1] > CELL_SIZE:
        raise RuntimeError(f"{source_path} normalized outside canvas ({scaled_size})")
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (paste_x, paste_y))
    canvas, post_paste_dust_removed = despeckle(canvas)
    dust_islands_removed += post_paste_dust_removed
    runtime_bbox = alpha_bbox(canvas)
    remaining_islands = 0
    if runtime_bbox is not None:
        _, remaining_islands = despeckle(canvas)
    return {
        "source": source_path.name,
        "source_size": list(image.size),
        "dust_islands_removed": dust_islands_removed,
        "source_alpha_bbox": list(bbox),
        "source_alpha_bbox_size": [bbox_width, bbox_height],
        "scale": scale,
        "resized_visible_size": list(scaled_size),
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "runtime_alpha_bbox": list(runtime_bbox) if runtime_bbox else None,
        "runtime_alpha_bbox_size": [runtime_bbox[2] - runtime_bbox[0], runtime_bbox[3] - runtime_bbox[1]] if runtime_bbox else None,
        "runtime_dust_islands_remaining": remaining_islands,
        "canvas": canvas,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    frames = sorted(p for p in FRAME_DIR.glob("*.png"))
    if not frames:
        print(f"no frames found under {FRAME_DIR}", file=sys.stderr)
        return 2

    report: dict[str, dict] = {}
    heights: set[int] = set()
    bottoms: set[int] = set()
    total_dust_removed = 0
    frames_with_gt3_islands = 0

    for frame_path in frames:
        entry = normalize_frame(frame_path)
        canvas = entry.pop("canvas")
        heights.add(entry["runtime_alpha_bbox_size"][1])
        bottoms.add(entry["runtime_alpha_bbox"][3])
        total_dust_removed += entry["dust_islands_removed"]
        if entry["dust_islands_removed"] > 3:
            frames_with_gt3_islands += 1
        report[frame_path.name] = entry
        print(f"  {frame_path.name}: {entry['source_size']} -> canvas 512, "
              f"visible {entry['runtime_alpha_bbox_size']}, scale {entry['scale']:.3f}, "
              f"dust removed {entry['dust_islands_removed']}")
        if not args.dry_run:
            canvas.save(frame_path)

    print(f"\nframes processed: {len(frames)}")
    print(f"distinct visible heights after normalize: {sorted(heights)}")
    print(f"distinct footline bottoms after normalize: {sorted(bottoms)}")
    print(f"total dust islands removed: {total_dust_removed}")
    print(f"frames with >3 removed dust islands: {frames_with_gt3_islands}")

    if not args.dry_run:
        REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        manifest["runtime_canvas"] = [CELL_SIZE, CELL_SIZE]
        manifest["normalization"] = {
            "task": "FAN-3099",
            "tool": "tools/fan3099_normalize_night_stalker_pack.py",
            "target_visible_height": TARGET_VISIBLE_HEIGHT,
            "bottom_padding": BOTTOM_PADDING,
            "dust_island_max_pixels": DUST_ISLAND_MAX_PIXELS,
            "total_dust_islands_removed": total_dust_removed,
            "note": (
                "Offline re-normalization of the 368 already-generated frames "
                "from FAN-2621 (rejected by FAN-2757 for non-uniform canvas / "
                "silhouette scale). No PixelLab regeneration."
            ),
        }
        MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        print(f"\nwrote {REPORT_PATH}")
        print(f"updated {MANIFEST_PATH}")

    if len(heights) != 1 or len(bottoms) != 1:
        print("FAIL: visible height or footline is not uniform across all frames", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
