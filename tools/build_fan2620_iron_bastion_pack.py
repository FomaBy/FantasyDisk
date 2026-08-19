#!/usr/bin/env python3
"""Build the FAN-2620 iron_bastion 8-direction PixelLab pack.

Reads raw PixelLab source frames already downloaded under
assets/sprites/elites/pixellab/iron_bastion/ (deterministic
iron_bastion_<state>_<direction>[_<frame>].png naming), normalizes them onto
the fleet-standard 512x512 transparent runtime canvas (245px visible height,
32px bottom padding, alpha-bbox scaled -- same maths as
tools/build_fan2628_mini_rot_hound_pack.py / update_pixellab_character_animations.py),
and writes the FAN-2519 explicit-eight-direction SpriteFrames resource plus a
manifest/alpha report. No attack_primary/attack_<skill> alias rows -- the
directional contract (FAN-2613/FAN-2901 precedent) drops them since gameplay
only ever requests bare "attack"/"skill_<id>" state names for directional
packs.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ID = "iron_bastion"
PIXELLAB_CHARACTER_ID = "3fbeff55-6030-47be-8e8f-d1a4f3fb11a9"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32

SOURCE_DIR = ROOT / "assets/sprites/elites/pixellab/iron_bastion"
RUNTIME_DIR = ROOT / "assets/sprites/elites/full_frame/iron_bastion"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/elites/full_frame/iron_bastion_spriteframes.tres"

# FAN-2519 direction suffix contract (clockwise from east), matching
# scripts/full_frame_animation_registry.gd::DIRECTION_SUFFIXES.
DIRECTIONS = ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

# state -> frame_count/loop/speed. No attack_primary/attack_<skill> alias rows:
# the FAN-2519 directional contract (FAN-2613/FAN-2901 precedent) drops them --
# gameplay only ever requests bare "attack" and "skill_<id>" state names for
# directional packs, never the _primary/attack_<skill> validator aliases used
# by the old non-directional pack's flat-name resolution.
STATE_TIMING = {
    "idle": {"frame_count": 1, "loop": True, "speed": 1.0},
    "move": {"frame_count": 8, "loop": True, "speed": 9.0},
    # v3 custom animations default keep_first_frame=true: frame_count=6
    # requested -> 7 frames stored (reference frame kept as frame 0).
    "attack": {"frame_count": 7, "loop": False, "speed": 12.0},
    "hit": {"frame_count": 6, "loop": False, "speed": 10.0},
    "death": {"frame_count": 7, "loop": False, "speed": 10.0},
    "skill_shield_block": {"frame_count": 7, "loop": False, "speed": 12.0},
    "skill_slam_wave": {"frame_count": 7, "loop": False, "speed": 12.0},
}


def alpha_bbox(image: Image.Image):
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
    missing_states = []
    for state, timing in STATE_TIMING.items():
        for direction in DIRECTIONS:
            if state == "idle":
                src = SOURCE_DIR / f"{CHARACTER_ID}_idle_{direction}.png"
                if not src.exists():
                    missing_states.append(str(src))
                continue
            for index in range(timing["frame_count"]):
                src = SOURCE_DIR / f"{CHARACTER_ID}_{state}_{direction}_{index:02d}.png"
                if not src.exists():
                    missing_states.append(str(src))
    if missing_states:
        raise RuntimeError("missing source frames:\n" + "\n".join(missing_states))

    alpha_report: dict[str, list] = {}
    ext_lines: list[str] = []
    resources: dict[str, str] = {}
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

    animation_blocks: list[str] = []

    for state, timing in STATE_TIMING.items():
        for direction in DIRECTIONS:
            if state == "idle":
                src = SOURCE_DIR / f"{CHARACTER_ID}_idle_{direction}.png"
                dest = RUNTIME_DIR / f"{CHARACTER_ID}_idle_{direction}.png"
                report = normalize_frame(src, dest)
                alpha_report[f"idle_{direction}"] = [report]
                rid = add_resource(dest)
                animation_blocks.append(frame_block([rid], timing["speed"], timing["loop"], f"idle_{direction}"))
                continue

            rids = []
            reports = []
            for index in range(timing["frame_count"]):
                src = SOURCE_DIR / f"{CHARACTER_ID}_{state}_{direction}_{index:02d}.png"
                dest = RUNTIME_DIR / f"{CHARACTER_ID}_{state}_{direction}_{index:02d}.png"
                reports.append(normalize_frame(src, dest))
                rids.append(add_resource(dest))
            alpha_report[f"{state}_{direction}"] = reports
            row_name = f"{state}_{direction}"
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

    (SOURCE_DIR / "alpha_bbox_report.json").write_text(
        json.dumps(alpha_report, indent=2), encoding="utf-8"
    )

    manifest = {
        "character_id": CHARACTER_ID,
        "pixellab_character_id": PIXELLAB_CHARACTER_ID,
        "generated_at": "2026-08-19",
        "source": "PixelLab MCP",
        "mode": "standard (idle rotations, 8-dir humanoid) + template walking-8-frames (move) + template taking-punch (hit) + template falling-back-death (death) + v3 custom (attack, skill_shield_block, skill_slam_wave)",
        "body_type": "humanoid",
        "view": "low top-down",
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "directions": DIRECTIONS,
        "states": {
            "idle": {"frame_count": 1, "source": "rotations"},
            "move": {"frame_count": 8, "template_animation_id": "walking-8-frames", "fps": 9.0},
            "attack": {"frame_count": 7, "mode": "v3", "action_description": "swinging a heavy spiked flail mace overhead and smashing it down in a crushing strike", "fps": 12.0},
            "hit": {"frame_count": 6, "template_animation_id": "taking-punch", "fps": 10.0},
            "death": {"frame_count": 7, "template_animation_id": "falling-back-death", "fps": 10.0},
            "skill_shield_block": {"frame_count": 7, "mode": "v3", "action_description": "raising the heavy spiked tower shield up to brace behind it, the shield flaring with dark purple energy", "fps": 12.0, "note": "runtime state for elite_attack_id=shield_block windup/hold phase"},
            "skill_slam_wave": {"frame_count": 7, "mode": "v3", "action_description": "winding up then slamming the tower shield down into the ground, unleashing a ring of dark shockwave energy rippling outward", "fps": 12.0, "note": "runtime state for elite_attack_id=slam_wave windup/strike phase"},
        },
        "notes": (
            "FAN-2620: first FAN-2519 explicit-eight-direction pack for a route "
            "elite (iron_bastion). Replaces the FAN-2519 SCRUM-368 single "
            "west-facing flip-mirrored pack (backed up under "
            "docs/design/backups/fan2620_iron_bastion_pre_directional/). 8 idle "
            "rotations + 8x8 move + 8x6 attack/hit/skill_shield_block/"
            "skill_slam_wave + 8x7 death frames, all normalized to 245px "
            "visible height on a transparent 512x512 canvas, footline pinned "
            "at bottom_padding=32. No attack_primary/attack_<skill> alias "
            "rows (FAN-2613/FAN-2901 precedent: the directional contract "
            "drops them, gameplay only ever requests bare attack/skill_<id> "
            "state names for directional packs). No hover state "
            "(iron_bastion is ground-based, not flying)."
        ),
    }
    (SOURCE_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"wrote {SPRITEFRAMES_PATH}")
    print(f"wrote {SOURCE_DIR / 'manifest.json'}")
    print(f"wrote {SOURCE_DIR / 'alpha_bbox_report.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
