#!/usr/bin/env python3
"""Build the FAN-3093 iron_bastion 8-direction PixelLab pack (rework of FAN-2620).

Downloads PixelLab source frames from the URLs in urls.json (character
465c1b5d-2736-4b4d-a593-c126723b91d6, generated with mode="v3"
reference_image_base64 seeded from the existing shipped iron_bastion sprite so
the regenerated pack keeps the same identity: broad heavy knight, black-gold
armor, purple glowing cracks, skull tower shield, spiked morningstar),
normalizes them onto the fleet-standard 512x512 transparent runtime canvas
(245px visible height, 32px bottom padding -- same maths as
tools/build_fan2628_mini_rot_hound_pack.py), and writes the FAN-2519
explicit-eight-direction SpriteFrames resource plus a manifest/alpha report.
No attack_primary/attack_<skill> alias rows -- the directional contract
(FAN-2613/FAN-2901 precedent) drops them since gameplay only ever requests
bare "attack"/"skill_<id>" state names for directional packs.
"""
from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ID = "iron_bastion"
PIXELLAB_CHARACTER_ID = "465c1b5d-2736-4b4d-a593-c126723b91d6"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32

URLS_PATH = ROOT / "tools/fan3093_iron_bastion_urls.json"
SOURCE_DIR = ROOT / "assets/sprites/elites/pixellab/iron_bastion"
RUNTIME_DIR = ROOT / "assets/sprites/elites/full_frame/iron_bastion"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/elites/full_frame/iron_bastion_spriteframes.tres"

# FAN-2519 direction suffix contract (clockwise from east), matching
# scripts/full_frame_animation_registry.gd::DIRECTION_SUFFIXES.
DIRECTIONS = ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
URL_DIRECTIONS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

# state -> frame_count/loop/speed.
STATE_TIMING = {
    "idle": {"frame_count": 1, "loop": True, "speed": 1.0},
    "move": {"frame_count": 8, "loop": True, "speed": 9.0},
    "attack": {"frame_count": 7, "loop": False, "speed": 12.0},
    "hit": {"frame_count": 6, "loop": False, "speed": 10.0},
    "death": {"frame_count": 7, "loop": False, "speed": 10.0},
    "skill_shield_block": {"frame_count": 7, "loop": False, "speed": 12.0},
    "skill_slam_wave": {"frame_count": 7, "loop": False, "speed": 12.0},
}


def alpha_bbox(image: Image.Image):
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


def download(url: str, dest: Path) -> None:
    if dest.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    # Strip the "?t=" cache-busting query param: it is a snapshot timestamp
    # from whichever get_character call produced this URL and can 404 on a
    # content-addressed path fetched later; the bare path is stable.
    url = url.split("?", 1)[0]
    last_exc = None
    for attempt in range(8):
        try:
            subprocess.run(
                ["curl", "-sS", "--fail", "-A", "Mozilla/5.0", "-o", str(dest), url],
                check=True, timeout=30,
            )
            time.sleep(0.15)  # avoid tripping the backend's burst rate limit
            return
        except subprocess.CalledProcessError as exc:  # transient backend hiccups: retry with backoff
            last_exc = exc
            time.sleep(2.0 * (attempt + 1))
    raise RuntimeError(f"failed to download {url} -> {dest}: {last_exc}") from last_exc


def fetch_sources(urls: dict) -> None:
    for direction_idx, direction in enumerate(URL_DIRECTIONS):
        suffix = DIRECTIONS[direction_idx]
        rot_url = urls["rotations"][direction]
        download(rot_url, SOURCE_DIR / f"{CHARACTER_ID}_idle_{suffix}.png")
        for state, frame_urls in urls["animations"].items():
            for index, url in enumerate(frame_urls[direction]):
                download(url, SOURCE_DIR / f"{CHARACTER_ID}_{state}_{suffix}_{index:02d}.png")


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


def frame_block(resource_ids: list, speed: float, loop: bool, name: str) -> str:
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
    # urls.json is a transient PixelLab download manifest (signed URLs expire)
    # deleted after the raw frames landed under SOURCE_DIR; re-running this
    # script normalizes the already-committed raw frames. Recreate urls.json
    # from a fresh get_character() call (see manifest.json pixellab_character_id)
    # only if SOURCE_DIR needs to be rebuilt from scratch.
    if URLS_PATH.exists():
        urls = json.loads(URLS_PATH.read_text(encoding="utf-8"))
        fetch_sources(urls)

    missing_states = []
    for state, timing in STATE_TIMING.items():
        for suffix in DIRECTIONS:
            if state == "idle":
                src = SOURCE_DIR / f"{CHARACTER_ID}_idle_{suffix}.png"
                if not src.exists():
                    missing_states.append(str(src))
                continue
            for index in range(timing["frame_count"]):
                src = SOURCE_DIR / f"{CHARACTER_ID}_{state}_{suffix}_{index:02d}.png"
                if not src.exists():
                    missing_states.append(str(src))
    if missing_states:
        raise RuntimeError("missing source frames:\n" + "\n".join(missing_states))

    alpha_report: dict = {}
    ext_lines: list = []
    resources: dict = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resources:
            return resources[key]
        rid = f"{next_id}_ib"
        next_id += 1
        rel = path.resolve().relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{rid}"]')
        resources[key] = rid
        return rid

    animation_blocks: list = []
    visible_heights: list = []

    for state, timing in STATE_TIMING.items():
        for suffix in DIRECTIONS:
            if state == "idle":
                src = SOURCE_DIR / f"{CHARACTER_ID}_idle_{suffix}.png"
                dest = RUNTIME_DIR / f"{CHARACTER_ID}_idle_{suffix}.png"
                report = normalize_frame(src, dest)
                alpha_report[f"idle_{suffix}"] = [report]
                if report["runtime_alpha_bbox"]:
                    visible_heights.append(report["runtime_alpha_bbox"][3] - report["runtime_alpha_bbox"][1])
                rid = add_resource(dest)
                animation_blocks.append(frame_block([rid], timing["speed"], timing["loop"], f"idle_{suffix}"))
                continue

            rids = []
            reports = []
            for index in range(timing["frame_count"]):
                src = SOURCE_DIR / f"{CHARACTER_ID}_{state}_{suffix}_{index:02d}.png"
                dest = RUNTIME_DIR / f"{CHARACTER_ID}_{state}_{suffix}_{index:02d}.png"
                report = normalize_frame(src, dest)
                reports.append(report)
                if report["runtime_alpha_bbox"]:
                    visible_heights.append(report["runtime_alpha_bbox"][3] - report["runtime_alpha_bbox"][1])
                rids.append(add_resource(dest))
            alpha_report[f"{state}_{suffix}"] = reports
            row_name = f"{state}_{suffix}"
            animation_blocks.append(frame_block(rids, timing["speed"], timing["loop"], row_name))

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
        "mode": "v3 reference_image_base64 (seeded from shipped assets/sprites/elites/iron_bastion.png, 8 rotations) + template walking-8-frames (move) + v3 custom (attack, hit, death, skill_shield_block, skill_slam_wave -- hit/death moved off the taking-punch/falling-back-death templates after they injected per-direction color artifacts: red eyes, pink blobs, orange skin patches on some octants only, reproducing the FAN-2755 QA defect class)",
        "body_type": "humanoid",
        "view": "low top-down",
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "directions": DIRECTIONS,
        "measured_visible_height_avg": (sum(visible_heights) / len(visible_heights)) if visible_heights else None,
        "states": {
            "idle": {"frame_count": 1, "source": "rotations"},
            "move": {"frame_count": 8, "template_animation_id": "walking-8-frames", "fps": 9.0},
            "attack": {"frame_count": 7, "mode": "v3", "action_description": "swinging a heavy spiked morningstar flail overhead and smashing it down in a crushing strike, no sparks, no flashes, no light bursts, no extra colors", "fps": 12.0, "note": "regenerated once after the first pass put a one-off white flash icon in south-east only"},
            "hit": {"frame_count": 6, "mode": "v3", "action_description": "heavily armored knight staggering backward from a heavy hit, armor plates staying intact, no blood, no wounds, no color change", "fps": 10.0},
            "death": {"frame_count": 7, "mode": "v3", "action_description": "heavily armored knight collapsing backward and falling to the ground, armor plates staying intact, no blood, no wounds, no color change", "fps": 10.0},
            "skill_shield_block": {"frame_count": 7, "mode": "v3", "action_description": "raising the heavy spiked tower shield up to brace behind it, the shield flaring with dark purple energy", "fps": 12.0, "note": "runtime state for elite_attack_id=shield_block windup/hold phase; NOT currently requested by enemy.gd (the shield behavior plays the generic 'cast' state) -- kept consistent for a future wiring task, per FAN-3093 scope boundary"},
            "skill_slam_wave": {"frame_count": 7, "mode": "v3", "action_description": "winding up then slamming the tower shield down into the ground, unleashing a ring of dark purple shockwave energy rippling outward", "fps": 12.0, "note": "runtime state for elite_attack_id=slam_wave windup/strike phase"},
        },
        "notes": (
            "FAN-3093 (rework of FAN-2620, rejected by QA FAN-2755). Replaces the "
            "single west-facing flip-mirrored iron_bastion pack with a full "
            "FAN-2519 explicit-eight-direction pack that PRESERVES the shipped "
            "iron_bastion identity (broad heavy knight, black-gold armor, purple "
            "glowing cracks, skull tower shield, spiked morningstar) by seeding "
            "PixelLab v3 character generation with the actual shipped sprite as "
            "reference_image_base64, instead of a from-scratch text description. "
            "8 idle rotations + 8x8 move + 8x7 attack/death/skill_shield_block/"
            "skill_slam_wave + 8x6 hit frames, all normalized to 245px visible "
            "height on a transparent 512x512 canvas, footline pinned at "
            "bottom_padding=32. No attack_primary/attack_<skill> alias rows "
            "(FAN-2613/FAN-2901 precedent). No hover state (iron_bastion is "
            "ground-based, not flying)."
        ),
    }
    (RUNTIME_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"wrote {SPRITEFRAMES_PATH}")
    print(f"wrote {SOURCE_DIR / 'manifest.json'}")
    print(f"wrote {SOURCE_DIR / 'alpha_bbox_report.json'}")
    if visible_heights:
        print(f"measured visible height avg={sum(visible_heights)/len(visible_heights):.1f} min={min(visible_heights)} max={max(visible_heights)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
