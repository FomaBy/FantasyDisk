#!/usr/bin/env python3
"""Build the FAN-2619 winged_spark 8-direction PixelLab pack.

Parses the saved plain-text report of the PixelLab MCP `get_character()` call
(rotation + animation frame URLs for idle/move/attack/hit/death, all 8
directions), downloads every frame, normalizes them into the fleet-standard
512x512 transparent runtime canvas (245px visible height, 32px bottom
padding, alpha-bbox scaled -- same maths as tools/build_fan2613_bone_caller_pack.py),
and writes the FAN-2519 explicit-eight-direction SpriteFrames resource plus a
manifest/alpha report.

Animation jobs were queued with v3 default keep_first_frame=true, so each
direction's URL list is [reference_frame, animated_frame_0, ..., animated_frame_N-1];
frame 0 (a duplicate of the idle rotation) is dropped before normalization.
`idle` intentionally carries the hover-flap identity (winged_spark is a flying
actor with no separate "hover" state name in the runtime resolver).
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ID = "winged_spark"
PIXELLAB_CHARACTER_ID = "918ad402-d90d-49bb-ac6a-1897e112cfcb"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
USER_AGENT = "FantasyDisk-FAN2619/1.0"

SOURCE_DIR = ROOT / "assets/sprites/enemies/pixellab/winged_spark"
RUNTIME_DIR = ROOT / "assets/sprites/enemies/full_frame/winged_spark"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/enemies/full_frame/winged_spark_spriteframes.tres"

# FAN-2519 direction suffix contract (clockwise from east), matching
# scripts/full_frame_animation_registry.gd::DIRECTION_SUFFIXES.
DIRECTIONS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

STATE_TIMING = {
    "idle": {"loop": True, "speed": 8.0},
    "move": {"loop": True, "speed": 10.0},
    "attack": {"loop": False, "speed": 12.0},
    "hit": {"loop": False, "speed": 10.0},
    "death": {"loop": False, "speed": 10.0},
}

STATE_ACTION_DESCRIPTIONS = {
    "idle": "hovering in place in mid-air, wings flapping steadily up and down, body bobbing gently with each flap, legs dangling loose",
    "move": "flying forward aggressively, powerful wing beats propelling the body ahead, torso leaning into the direction of travel, claws reaching forward, tail trailing behind",
    "attack": "lunging forward in mid-air with a vicious clawed swipe attack, wings snapping back for thrust, mouth open baring fangs, body coiling then striking forward",
    "hit": "recoiling in pain from a hit while airborne, flinching backward, wings flaring out for balance, body jerking back briefly",
    "death": "dying and falling out of the sky, wings crumpling and going limp, body going ragdoll and collapsing downward, defeated",
}


def suffix(direction: str) -> str:
    return direction.replace("-", "_")


def download(url: str, dest: Path) -> None:
    if dest.exists():
        return
    import time
    import urllib.error
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_exc: Exception | None = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(response.read())
                return
        except urllib.error.HTTPError as exc:
            last_exc = exc
            if exc.code not in (404, 429, 500, 502, 503, 504) or attempt == 3:
                raise
            time.sleep(3 * (attempt + 1))
    if last_exc:
        raise last_exc


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


def parse_get_character_report(text: str) -> dict:
    """Parse the plain-text get_character() report into rotations + animations."""
    lines = text.splitlines()
    rotations: dict[str, str] = {}
    animations: dict[str, dict[str, list[str]]] = {}

    section = None
    current_state = None
    in_rotations = False
    for line in lines:
        if line.startswith("rotations:"):
            in_rotations = True
            continue
        if line.startswith("animations ("):
            in_rotations = False
            section = "animations"
            continue
        if line.startswith("pending jobs") or line.startswith("download:"):
            in_rotations = False
            section = None
            continue
        if in_rotations:
            m = re.match(r"^  ([a-z-]+): (https://\S+)", line)
            if m:
                rotations[m.group(1)] = m.group(2)
            continue
        if section == "animations":
            m = re.match(r"^  ([a-z_]+) — ", line)
            if m:
                current_state = m.group(1)
                animations.setdefault(current_state, {})
                continue
            m = re.match(r"^    ([a-z-]+): (.+)$", line)
            if m and current_state:
                direction = m.group(1)
                urls = [part.strip() for part in m.group(2).split(",")]
                urls = [u for u in urls if u.startswith("https://")]
                animations[current_state][direction] = urls
    return {"rotations": rotations, "animations": animations}


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: build_fan2619_winged_spark_pack.py <get_character_report.txt>", file=sys.stderr)
        return 2
    dump = parse_get_character_report(Path(sys.argv[1]).read_text(encoding="utf-8"))
    rotations = dump["rotations"]
    animations = dump["animations"]

    missing_rot = [d for d in DIRECTIONS if d not in rotations]
    if missing_rot:
        raise RuntimeError(f"missing idle rotations: {missing_rot}")
    for state in STATE_TIMING:
        if state == "idle":
            continue
        missing = [d for d in DIRECTIONS if d not in animations.get(state, {})]
        if missing:
            raise RuntimeError(f"missing {state} directions: {missing}")
    missing_idle_anim = [d for d in DIRECTIONS if d not in animations.get("idle", {})]
    if missing_idle_anim:
        raise RuntimeError(f"missing idle (hover) directions: {missing_idle_anim}")

    alpha_report: dict[str, list] = {}
    ext_lines: list[str] = []
    resources: dict[str, str] = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resources:
            return resources[key]
        rid = f"{next_id}_ws"
        next_id += 1
        rel = path.resolve().relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{rid}"]')
        resources[key] = rid
        return rid

    animation_blocks: list[str] = []

    # idle: dedicated hover-flap loop animation per direction (NOT the static
    # rotation image -- winged_spark is a flying actor, so its resting state
    # must show wing flap motion; frame 0 of the animate_character URL list is
    # the static reference pose and is dropped like every other state).
    for state, timing in STATE_TIMING.items():
        for direction in DIRECTIONS:
            s = suffix(direction)
            urls = animations[state][direction][1:]
            rids = []
            reports = []
            for index, url in enumerate(urls):
                src = SOURCE_DIR / f"winged_spark_{state}_{s}_{index:02d}.png"
                dest = RUNTIME_DIR / f"winged_spark_{state}_{s}_{index:02d}.png"
                try:
                    download(url, src)
                except Exception as exc:
                    print(f"FAILED state={state} dir={direction} idx={index} url={url!r}: {exc}", file=sys.stderr)
                    raise
                reports.append(normalize_frame(src, dest))
                rids.append(add_resource(dest))
            alpha_report[f"{state}_{s}"] = reports
            animation_blocks.append(frame_block(rids, timing["speed"], timing["loop"], f"{state}_{s}"))

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
        "generated_at": "2026-08-19",
        "source": "PixelLab MCP",
        "mode": "v3 (idle/move/attack/hit/death, all custom v3, 8 directions each)",
        "body_type": "humanoid",
        "view": "low top-down",
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "directions": DIRECTIONS,
        "states": {
            "idle": {"frame_count": 6, "mode": "v3", "action_description": STATE_ACTION_DESCRIPTIONS["idle"], "fps": 8.0, "note": "hover-flap loop (flying identity; resolves through the idle state, no separate hover state name)"},
            "move": {"frame_count": 6, "mode": "v3", "action_description": STATE_ACTION_DESCRIPTIONS["move"], "fps": 10.0},
            "attack": {"frame_count": 6, "mode": "v3", "action_description": STATE_ACTION_DESCRIPTIONS["attack"], "fps": 12.0},
            "hit": {"frame_count": 4, "mode": "v3", "action_description": STATE_ACTION_DESCRIPTIONS["hit"], "fps": 10.0},
            "death": {"frame_count": 6, "mode": "v3", "action_description": STATE_ACTION_DESCRIPTIONS["death"], "fps": 10.0},
        },
        "notes": (
            "FAN-2519 explicit-eight-direction pack for standard_monster/winged_spark "
            "(FAN-2619). 8x6 idle(hover)/move/attack/death frames + 8x4 hit frames, all "
            "normalized to 245px visible height on a transparent 512x512 canvas, footline pinned "
            "at bottom_padding=32. Replaces the single west-facing flip-mirrored winged_spark "
            "pack (source_faces_left=true, single hover_flap/move/attack_primary/death rows)."
        ),
    }
    (RUNTIME_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"wrote {SPRITEFRAMES_PATH}")
    print(f"wrote {SOURCE_DIR / 'manifest.json'}")
    print(f"wrote {SOURCE_DIR / 'alpha_bbox_report.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
