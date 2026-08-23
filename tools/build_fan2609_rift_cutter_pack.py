#!/usr/bin/env python3
"""FAN-2609 — build the explicit 8-direction rift_cutter runtime pack from a
PixelLab MCP character+animation export (source URLs listed in
docs/design/references/fan2609_rift_cutter/pixellab_sources.json).

Downloads every rotation/animation frame, normalizes it onto a fixed 384x384
canvas (alpha-bbox crop -> scale to a shared visible height -> bottom-pinned
paste, same technique as tools/update_pixellab_character_animations.py), then
writes assets/sprites/enemies/full_frame/rift_cutter/*.png and a fresh
rift_cutter_spriteframes.tres with explicit `<state>_<suffix>` rows for all
eight FullFrameAnimationRegistry.DIRECTION_SUFFIXES.

Usage: python3 tools/build_fan2609_rift_cutter_pack.py
"""
from __future__ import annotations

import json
import re
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES_PATH = ROOT / "docs/design/references/fan2609_rift_cutter/pixellab_sources.json"
RUNTIME_DIR = ROOT / "assets/sprites/enemies/full_frame/rift_cutter"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres"
CHARACTER_ID = "rift_cutter"

# PixelLab hyphenated direction -> FullFrameAnimationRegistry.DIRECTION_SUFFIXES.
DIRECTIONS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 192
BOTTOM_PADDING = 32
STATE_FRAME_COUNTS = {"idle": 4, "move": 6, "attack": 6, "hit": 6, "death": 6}
STATE_SPEED = {"idle": 4.0, "move": 10.0, "attack": 10.0, "hit": 10.0, "death": 10.0}
USER_AGENT = "FantasyDisk-PixelArtist-FAN2609/1.0"


def suffix_of(direction: str) -> str:
    return direction.replace("-", "_")


def download(url: str, dest: Path) -> None:
    if dest.exists():
        return
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        dest.write_bytes(response.read())


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.convert("RGBA").getchannel("A").getbbox()


def row_scale(source_path: Path) -> float:
    match = re.match(r"(.+)_\d{2}_src$", source_path.stem)
    source_paths = sorted(source_path.parent.glob(f"{match.group(1)}_*_src.png")) if match else [source_path]
    sizes = []
    for path in source_paths:
        with Image.open(path) as image:
            bbox = alpha_bbox(image.convert("RGBA"))
        if bbox is None:
            raise RuntimeError(f"{path} has no visible alpha")
        sizes.append((bbox[2] - bbox[0], bbox[3] - bbox[1]))
    max_width = CELL_SIZE - 8
    return min(TARGET_VISIBLE_HEIGHT / float(max(height for _, height in sizes)), max_width / float(max(width for width, _ in sizes)))


def normalize_frame(src: Path, dest: Path) -> dict:
    image = Image.open(src).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"{src} has no visible alpha")
    bbox_w, bbox_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    scale = row_scale(src)
    scaled_size = (max(1, round(bbox_w * scale)), max(1, round(bbox_h * scale)))
    resized = image.crop(bbox).resize(scaled_size, Image.Resampling.NEAREST)
    paste_x = round((CELL_SIZE - scaled_size[0]) / 2.0)
    paste_y = CELL_SIZE - BOTTOM_PADDING - scaled_size[1]
    paste_x = max(0, min(paste_x, CELL_SIZE - scaled_size[0]))
    paste_y = max(0, min(paste_y, CELL_SIZE - scaled_size[1]))
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (paste_x, paste_y))
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest)
    return {"source": str(src.name), "runtime": str(dest.name), "scale": scale}


def frame_block(paths: list[str], resources: dict[str, str], speed: float, name: str, loop: bool) -> str:
    frames = ",\n".join(
        '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resources[path]
        for path in paths
    )
    return (
        "{\n"
        '"frames": [%s],\n'
        '"loop": %s,\n'
        '"name": &"%s",\n'
        '"speed": %s\n'
        "}"
    ) % (frames, "true" if loop else "false", name, speed)


def write_spriteframes(frame_paths: dict[str, dict[str, list[str]]]) -> None:
    ext_lines = []
    resources: dict[str, str] = {}
    next_id = 1

    def add_resource(relative_path: str) -> str:
        nonlocal next_id
        if relative_path in resources:
            return resources[relative_path]
        resource_id = f"{next_id}_rc"
        next_id += 1
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{relative_path}" id="{resource_id}"]')
        resources[relative_path] = resource_id
        return resource_id

    for state, per_direction in frame_paths.items():
        for direction, paths in per_direction.items():
            for path in paths:
                add_resource(path)

    animations = []
    # Non-directional fallback rows default to the south-facing frames.
    for state in ("idle", "move", "attack", "hit", "death"):
        loop = state in ("idle", "move")
        animations.append(frame_block(frame_paths[state]["south"], resources, STATE_SPEED[state], state, loop))
    animations.append(frame_block(frame_paths["attack"]["south"], resources, STATE_SPEED["attack"], "attack_primary", False))

    for direction in DIRECTIONS:
        suffix = suffix_of(direction)
        for state in ("idle", "move", "attack", "hit", "death"):
            loop = state in ("idle", "move")
            animations.append(
                frame_block(frame_paths[state][direction], resources, STATE_SPEED[state], f"{state}_{suffix}", loop)
            )
        animations.append(
            frame_block(
                frame_paths["attack"][direction], resources, STATE_SPEED["attack"], f"attack_primary_{suffix}", False
            )
        )

    SPRITEFRAMES_PATH.write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n[resource]\nanimations = [\n"
        + ",\n".join(animations)
        + "\n]\n",
        encoding="utf-8",
    )


def main() -> int:
    sources = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))
    tmp_dir = ROOT / "build/fan2609_rift_cutter_src"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    for direction in DIRECTIONS:
        suffix = suffix_of(direction)
        for state, count in STATE_FRAME_COUNTS.items():
            urls = sources[state][direction]
            if len(urls) != count:
                raise RuntimeError(f"{state}/{direction}: expected {count} frames, got {len(urls)}")
            for index, url in enumerate(urls):
                download(url, tmp_dir / f"{CHARACTER_ID}_{state}_{suffix}_{index:02d}_src.png")

    frame_paths: dict[str, dict[str, list[str]]] = {state: {} for state in STATE_FRAME_COUNTS}
    report: dict[str, list[dict]] = {}

    for direction in DIRECTIONS:
        suffix = suffix_of(direction)
        for state, count in STATE_FRAME_COUNTS.items():
            urls = sources[state][direction]
            if len(urls) != count:
                raise RuntimeError(f"{state}/{direction}: expected {count} frames, got {len(urls)}")
            runtime_paths = []
            reports = []
            for index, url in enumerate(urls):
                src = tmp_dir / f"{CHARACTER_ID}_{state}_{suffix}_{index:02d}_src.png"
                download(url, src)
                dest = RUNTIME_DIR / f"{CHARACTER_ID}_{state}_{suffix}_{index:02d}.png"
                reports.append(normalize_frame(src, dest))
                runtime_paths.append(str(dest.relative_to(ROOT)))
            report[f"{state}_{suffix}"] = reports
            frame_paths[state][direction] = runtime_paths

    write_spriteframes(frame_paths)
    report_path = RUNTIME_DIR / "row_scale_report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {SPRITEFRAMES_PATH.relative_to(ROOT)} and {sum(len(frames) for frames in report.values())} runtime frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
