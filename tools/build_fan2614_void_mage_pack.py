#!/usr/bin/env python3
"""Build the FAN-2614 void_mage 8-direction PixelLab pack.

Parses a saved plain-text `get_character()` dump from the PixelLab MCP
server (same format tools/build_fan2610_ash_marksman_pack.py consumes),
downloads every rotation/animation frame it references, normalizes them into
the fleet-standard 512x512 transparent runtime canvas (245px visible height,
32px bottom padding, alpha-bbox scaled), and writes the FAN-2519
explicit-eight-direction SpriteFrames resource plus a manifest/alpha report.
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ID = "void_mage"
PIXELLAB_CHARACTER_ID = "63c8426e-dd29-48b7-b2d7-00dad7f592c3"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
USER_AGENT = "FantasyDisk-FAN2614/1.0"

SOURCE_DIR = ROOT / "assets/sprites/enemies/pixellab/void_mage"
RUNTIME_DIR = ROOT / "assets/sprites/enemies/full_frame/void_mage_8dir"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/enemies/full_frame/void_mage_spriteframes.tres"

# FAN-2519 direction suffix contract (clockwise from east), matching
# scripts/full_frame_animation_registry.gd::DIRECTION_SUFFIXES.
DIRECTIONS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

STATE_TIMING = {
    "idle": {"loop": True, "speed": 1.0},
    "move": {"loop": True, "speed": 9.0},
    "attack": {"loop": False, "speed": 12.0},
    "hit": {"loop": False, "speed": 10.0},
    "death": {"loop": False, "speed": 10.0},
}

# get_character() animation group state names -> our runtime state names.
STATE_KEY_MAP = {
    "idle": "idle",
    "move": "move",
    "attack_primary": "attack",
    "hit": "hit",
    "death": "death",
}


def suffix(direction: str) -> str:
    return direction.replace("-", "_")


def parse_dump(text: str) -> tuple[dict[str, str], dict[str, dict[str, list[str]]]]:
    rotations: dict[str, str] = {}
    animations: dict[str, dict[str, list[str]]] = {}

    rot_block = re.search(r"^rotations:\n((?:  .+\n)+)", text, re.MULTILINE)
    if not rot_block:
        raise RuntimeError("no rotations block found in dump")
    for line in rot_block.group(1).splitlines():
        m = re.match(r"\s+([a-z-]+): (\S+)", line)
        if m:
            rotations[m.group(1)] = m.group(2)

    state_header_re = re.compile(r"^  ([a-z_]+) — .+\[group: [0-9a-f-]+\]$")
    direction_line_re = re.compile(r"^    ([a-z-]+): (.+)$")
    current_state = None
    for line in text.splitlines():
        header = state_header_re.match(line)
        if header:
            current_state = header.group(1)
            animations.setdefault(current_state, {})
            continue
        if current_state is None:
            continue
        dmatch = direction_line_re.match(line)
        if dmatch:
            direction, urls_blob = dmatch.groups()
            urls = [u.strip() for u in urls_blob.split(", ") if u.strip()]
            animations[current_state][direction] = urls

    return rotations, animations


def download(url: str, dest: Path) -> None:
    if dest.exists():
        return
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(response.read())


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def row_scale(source_path: Path) -> float:
    match = re.match(r"(.+)_\d{2}$", source_path.stem)
    source_paths = sorted(source_path.parent.glob(f"{match.group(1)}_*.png")) if match else [source_path]
    sizes = []
    for path in source_paths:
        with Image.open(path) as image:
            bbox = alpha_bbox(image.convert("RGBA"))
        if bbox is None:
            raise RuntimeError(f"{path} has no visible alpha")
        sizes.append((bbox[2] - bbox[0], bbox[3] - bbox[1]))
    return min(TARGET_VISIBLE_HEIGHT / float(max(height for _, height in sizes)), CELL_SIZE / float(max(width for width, _ in sizes)))


def normalize_frame(source_path: Path, dest_path: Path) -> dict:
    image = Image.open(source_path).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"{source_path} has no visible alpha")
    bbox_width = bbox[2] - bbox[0]
    bbox_height = bbox[3] - bbox[1]
    scale = row_scale(source_path)
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
    }


def frame_block(resource_ids: list[str], speed: float, loop: bool, name: str) -> str:
    frames = ",\n".join(
        '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid for rid in resource_ids
    )
    return (
        "{\n"
        '"frames": [%s],\n'
        '"loop": %s,\n'
        '"name": &"%s",\n'
        '"speed": %s\n'
        "}"
    ) % (frames, "true" if loop else "false", name, speed)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: build_fan2614_void_mage_pack.py <dump.txt>", file=sys.stderr)
        return 2
    dump_path = Path(sys.argv[1])
    rotations, raw_animations = parse_dump(dump_path.read_text(encoding="utf-8"))
    animations = {STATE_KEY_MAP.get(k, k): v for k, v in raw_animations.items()}

    missing_rot = [d for d in DIRECTIONS if d not in rotations]
    if missing_rot:
        raise RuntimeError(f"missing idle rotations: {missing_rot}")
    for state in STATE_TIMING:
        if state == "idle":
            continue
        missing = [d for d in DIRECTIONS if d not in animations.get(state, {})]
        if missing:
            raise RuntimeError(f"missing {state} directions: {missing}")

    alpha_report: dict[str, dict] = {}
    ext_lines: list[str] = []
    resources: dict[str, str] = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resources:
            return resources[key]
        rid = f"{next_id}_vm"
        next_id += 1
        rel = path.resolve().relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{rid}"]')
        resources[key] = rid
        return rid

    animation_blocks: list[str] = []

    # idle: single-frame rotation per direction (fleet-standard convention,
    # matching ash_marksman/bone_caller — no separate idle-loop animation).
    for direction in DIRECTIONS:
        s = suffix(direction)
        src = SOURCE_DIR / f"{CHARACTER_ID}_idle_{s}.png"
        dest = RUNTIME_DIR / f"{CHARACTER_ID}_idle_{s}.png"
        download(rotations[direction], src)
        alpha_report[f"idle_{s}"] = [normalize_frame(src, dest)]
        rid = add_resource(dest)
        animation_blocks.append(
            frame_block([rid], STATE_TIMING["idle"]["speed"], STATE_TIMING["idle"]["loop"], f"idle_{s}")
        )

    # move/attack/hit/death: multi-frame per direction
    for state, timing in STATE_TIMING.items():
        if state == "idle":
            continue
        for direction in DIRECTIONS:
            s = suffix(direction)
            urls = animations[state][direction]
            rids = []
            reports = []
            for index, url in enumerate(urls):
                src = SOURCE_DIR / f"{CHARACTER_ID}_{state}_{s}_{index:02d}.png"
                dest = RUNTIME_DIR / f"{CHARACTER_ID}_{state}_{s}_{index:02d}.png"
                download(url, src)
                reports.append(normalize_frame(src, dest))
                rids.append(add_resource(dest))
            alpha_report[f"{state}_{s}"] = reports
            animation_blocks.append(
                frame_block(rids, timing["speed"], timing["loop"], f"{state}_{s}")
            )

    text = (
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n[resource]\nanimations = [\n"
        + ",\n".join(animation_blocks)
        + "\n]\n"
    )
    SPRITEFRAMES_PATH.parent.mkdir(parents=True, exist_ok=True)
    SPRITEFRAMES_PATH.write_text(text, encoding="utf-8")

    (RUNTIME_DIR / "row_scale_report.json").write_text(
        json.dumps(alpha_report, indent=2), encoding="utf-8"
    )

    manifest = {
        "character_id": CHARACTER_ID,
        "pixellab_character_id": PIXELLAB_CHARACTER_ID,
        "generated_at": "2026-08-18",
        "source": "PixelLab MCP",
        "mode": "v3 reference-image rotation (idle, 1f) + template walking-6-frames (move) + v3 custom (attack/hit/death)",
        "body_type": "humanoid",
        "view": "low top-down",
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "directions": DIRECTIONS,
        "states": {
            "idle": {"frame_count": 1, "source": "rotations"},
            "move": {"frame_count": 6, "template_animation_id": "walking-6-frames", "fps": 9.0},
            "attack": {"frame_count": 6, "mode": "v3", "action_description": "casting a void spell, thrusting hand forward and unleashing a burst of dark energy", "fps": 12.0},
            "hit": {"frame_count": 4, "mode": "v3", "action_description": "recoiling in pain from a hit, flinching backward", "fps": 10.0},
            "death": {"frame_count": 6, "mode": "v3", "action_description": "collapsing and dissolving into void smoke, dying", "fps": 10.0},
        },
        "notes": (
            "FAN-2614: dedicated 8-direction pack replacing the single authored "
            "horizontal view + flip for standard_monster/void_mage. "
            "8 idle rotations (1f) + 8x6 move frames + 8x6 attack frames + 8x4 "
            "hit frames + 8x6 death frames, all normalized to 245px visible "
            "height on a transparent 512x512 canvas, footline pinned at "
            "bottom_padding=32. void_mage is ground-based (no hover)."
        ),
    }
    (RUNTIME_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"wrote {SPRITEFRAMES_PATH}")
    print(f"wrote {SOURCE_DIR / 'manifest.json'}")
    print(f"wrote {SOURCE_DIR / 'alpha_bbox_report.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
