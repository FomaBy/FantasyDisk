#!/usr/bin/env python3
"""Normalize already-downloaded PixelLab source rows into the runtime pack.

A source-pack-only regeneration (PixelLab MCP writing
assets/sprites/characters/pixellab/<id>/) leaves the runtime frames the game
actually plays untouched, so the new art never reaches the screen. The full
importer (update_pixellab_character_animations.py) closes that gap but always
re-downloads from PixelLab and rewrites every direction. This does the offline
half only: the same normalize_frame() pass, restricted to named directions.

Normalization parameters come from the character's manifest.json, so runtime
frames stay identical in canvas, visible height, pivot and footline to the rows
they sit next to.

Usage:
  python3 tools/normalize_pixellab_rows.py --character sniper \\
      --direction north-east --direction north-west
  python3 tools/normalize_pixellab_rows.py --character sniper --all --dry-run
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMPORTER = Path(__file__).resolve().parent / "update_pixellab_character_animations.py"


def load_importer():
    spec = importlib.util.spec_from_file_location("update_pixellab_character_animations", IMPORTER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--character", required=True)
    parser.add_argument("--direction", action="append", default=[],
                        help="Direction to normalize; repeatable")
    parser.add_argument("--all", action="store_true", help="Normalize every direction")
    parser.add_argument("--move-frame-count", type=int, default=6)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    importer = load_importer()
    directions = list(importer.DIRECTIONS) if args.all else args.direction
    if not directions:
        print("nothing to do: pass --direction or --all", file=sys.stderr)
        return 2
    unknown = [d for d in directions if d not in importer.DIRECTIONS]
    if unknown:
        print(f"unknown direction(s): {', '.join(unknown)}", file=sys.stderr)
        return 2

    source_dir = ROOT / "assets/sprites/characters/pixellab" / args.character
    runtime_dir = ROOT / f"assets/sprites/characters/full_frame/{args.character}_pixellab"
    manifest_path = source_dir / "manifest.json"
    if not manifest_path.is_file():
        print(f"missing manifest: {manifest_path}", file=sys.stderr)
        return 2
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    runtime_canvas = manifest.get("runtime_canvas", [512, 512])
    if isinstance(runtime_canvas, str):
        cell_size = int(runtime_canvas.split("x", 1)[0])
    else:
        cell_size = int(runtime_canvas[0])
    target_height = importer.visible_height_target(manifest, 245)
    bottom_pad = importer.bottom_padding(manifest, 32)
    threshold = importer.alpha_threshold(manifest)
    print(f"{args.character}: canvas {cell_size}, visible height {target_height}, "
          f"bottom padding {bottom_pad}, alpha threshold {threshold}")

    written = 0
    for direction in directions:
        names = [f"{args.character}_idle_{direction}.png"] + [
            f"{args.character}_move_{direction}_{index:02d}.png"
            for index in range(args.move_frame_count)
        ]
        for name in names:
            source = source_dir / name
            if not source.is_file():
                print(f"  skip (no source): {name}")
                continue
            if args.dry_run:
                print(f"  would normalize: {name}")
                continue
            report = importer.normalize_frame(
                source,
                runtime_dir / name,
                cell_size=cell_size,
                target_visible_height=target_height,
                bottom_pad=bottom_pad,
                threshold=threshold,
            )
            print(f"  {name}: bbox {report['source_alpha_bbox_size']} "
                  f"-> {report['resized_visible_size']} (scale {report['scale']:.3f})")
            written += 1
    print(f"normalized {written} frame(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
