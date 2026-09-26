#!/usr/bin/env python3
"""Build the FAN-3627 mini-elite source/runtime contract.

The checked-in PixelLab PNGs are the durable input.  This builder only crops
their visible alpha, scales one actor-wide factor, pins the footline to
512-32, and writes the SpriteFrames resource plus hash/audit manifest.  The
optional dump mode is only for importing the already-completed
mini_plague_berserker character; normal rebuilds are offline and deterministic.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ELITES = ROOT / "assets" / "sprites" / "elites"
PIXEL_LAB_ROOT = ELITES / "pixellab"
RUNTIME_ROOT = ELITES / "full_frame"

DIRECTIONS = [
    "east", "south-east", "south", "south-west", "west", "north-west",
    "north", "north-east",
]
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
SCHEMA = "FAN-3325-mini-elite-pack-v1"
BUILDER = "tools/build_fan3627_mini_elite_pack.py"
GODOT_UID_ALPHABET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

# The failed FAN-3606 candidate already contains the accepted bytes for every
# non-repair frame.  Rebuild only these twelve derivatives from the repaired
# transparent source frames; all other runtime PNGs are preserved byte-for-byte.
REPAIRED_DIRECTIONS = {
    ("mini_scavenger_reaper", "move", "north"),
    ("mini_void_phantom", "move", "west"),
}

CHARACTER_IDS = {
    "mini_scavenger_reaper": "3d2c3c13-ed23-4784-add8-2e446a567a8b",
    "mini_plague_bellringer": "2b4d4ee4-513e-4aa6-a322-f7c19cd43835",
    "mini_bone_warden": "02f65048-756d-4b23-8459-b0090eb799cc",
    "mini_spark_wight": "841878ea-382d-4d83-9daf-87e8dd8bd89f",
    "mini_shadow_devourer": "ae0eaf0d-531d-4e2d-90b5-bd7ddf5b7280",
    "mini_siege_rammer": "6c8d76d0-97f8-4326-8269-bbbac2e5a634",
    "mini_swarm_sniper": "f0c3fba4-cb5e-4461-b0bf-1afd6129dc4d",
    "mini_void_phantom": "9747cdae-86b2-4479-a24f-deacf09e2027",
    "mini_plague_berserker": "9e63a280-524e-492b-9624-8ddbb2744c07",
}

ACTOR_STATES = {
    "mini_scavenger_reaper": ["move", "attack", "hit", "death", "skill_reaping_dash", "skill_bleed_finish"],
    "mini_plague_bellringer": ["move", "attack", "hit", "death", "skill_bell_toll", "skill_poison_pool"],
    "mini_bone_warden": ["move", "attack", "hit", "death", "skill_bone_guard", "skill_slam_wave"],
    "mini_spark_wight": ["move", "attack", "hit", "death", "skill_spark_fan", "skill_static_field"],
    "mini_shadow_devourer": ["move", "attack", "hit", "death", "skill_shadow_blink", "skill_devour_bite"],
    "mini_siege_rammer": ["move", "attack", "hit", "death", "skill_shield_block", "skill_slam_wave"],
    "mini_swarm_sniper": ["move", "attack", "hit", "death", "skill_shard_fan", "skill_command_pulse"],
    "mini_void_phantom": ["move", "attack", "hit", "death", "skill_shadow_strike", "skill_phase_dash"],
    "mini_plague_berserker": ["move", "attack", "hit", "death", "skill_poison_volley"],
}

STATE_TIMING = {
    "idle": {"loop": True, "speed": 1.0, "frame_count": 1, "mode": "rotations"},
    "move": {"loop": True, "speed": 9.0, "frame_count": 6, "mode": "template"},
    "attack": {"loop": False, "speed": 12.0, "frame_count": 6, "mode": "v3"},
    "hit": {"loop": False, "speed": 10.0, "frame_count": 6, "mode": "v3"},
    "death": {"loop": False, "speed": 10.0, "frame_count": 6, "mode": "v3"},
}

for _states in ACTOR_STATES.values():
    for _state in _states[4:]:
        STATE_TIMING.setdefault(_state, {"loop": False, "speed": 12.0, "frame_count": 6, "mode": "v3"})
STATE_TIMING["skill_poison_volley"] = {"loop": False, "speed": 12.0, "frame_count": 7, "mode": "v3"}

FRAME_COUNTS = {
    "mini_plague_berserker": {
        "attack": 7,
        "hit": 5,
        "death": 7,
        "skill_poison_volley": 7,
    },
}


def suffix(direction: str) -> str:
    return direction.replace("-", "_")


def frame_count(actor: str, state: str) -> int:
    return FRAME_COUNTS.get(actor, {}).get(state, STATE_TIMING[state]["frame_count"])


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ensure_import_sidecar(path: Path) -> None:
    """Create the minimal tracked texture import record when it is absent."""
    sidecar = Path(f"{path}.import")
    if sidecar.exists():
        return
    digest = sha256(path)
    uid_seed = int(hashlib.sha256(
        f"{path.relative_to(ROOT).as_posix()}:{digest}".encode("utf-8")
    ).hexdigest()[:16], 16)
    if uid_seed == 0:
        uid_seed = 1
    uid_chars = []
    for _ in range(13):
        uid_chars.append(GODOT_UID_ALPHABET[uid_seed & 31])
        uid_seed >>= 5
    uid = "".join(reversed(uid_chars))
    imported = f"res://.godot/imported/{path.name}-{digest[:32]}.ctex"
    sidecar.write_text(
        "[remap]\n"
        "importer=\"texture\"\n"
        "type=\"CompressedTexture2D\"\n"
        f"uid=\"uid://{uid}\"\n"
        f"path=\"{imported}\"\n"
        "metadata={\n\"vram_texture\": false\n}\n\n"
        "[deps]\n"
        f"source_file=\"res://{path.relative_to(ROOT).as_posix()}\"\n"
        f"dest_files=[\"{imported}\"]\n\n"
        "[params]\n"
        "compress/mode=0\n"
        "compress/high_quality=false\n"
        "compress/lossy_quality=0.7\n"
        "compress/uastc_level=0\n"
        "compress/rdo_quality_loss=0.0\n"
        "compress/hdr_compression=1\n"
        "compress/normal_map=0\n"
        "compress/channel_pack=0\n"
        "mipmaps/generate=false\n"
        "mipmaps/limit=-1\n"
        "roughness/mode=0\n"
        "roughness/src_normal=\"\"\n"
        "process/channel_remap/red=0\n"
        "process/channel_remap/green=1\n"
        "process/channel_remap/blue=2\n"
        "process/channel_remap/alpha=3\n"
        "process/fix_alpha_border=true\n"
        "process/premult_alpha=false\n"
        "process/normal_map_invert_y=false\n"
        "process/hdr_as_srgb=false\n"
        "process/hdr_clamp_exposure=0\n"
        "process/size_limit=0\n"
        "detect_3d/compress_to=1\n",
        encoding="utf-8",
    )


def pixel_sha256(path: Path) -> str:
    with Image.open(path) as image:
        return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def alpha_bbox(image: Image.Image):
    return image.getchannel("A").getbbox()


def parse_dump(path: Path) -> tuple[dict[str, str], dict[str, dict[str, list[str]]]]:
    raw = path.read_text(encoding="utf-8")
    if "data: " in raw:
        payload = None
        for line in raw.splitlines():
            if line.startswith("data: "):
                payload = json.loads(line[6:])
                break
        if payload:
            raw = payload["result"]["content"][0]["text"]

    rotations: dict[str, str] = {}
    for line in raw.splitlines():
        match = re.match(r"^  ([a-z-]+): (https?://\S+)$", line)
        if match:
            rotations[match.group(1)] = match.group(2)

    animations: dict[str, dict[str, list[str]]] = {}
    current_state = None
    state_header = re.compile(r"^  ([a-z_]+) — .+\[group: [0-9a-f-]+\]$")
    direction_line = re.compile(r"^    ([a-z-]+): (.+)$")
    for line in raw.splitlines():
        match = state_header.match(line)
        if match:
            current_state = match.group(1)
            animations.setdefault(current_state, {})
            continue
        if current_state:
            match = direction_line.match(line)
            if match:
                animations[current_state][match.group(1)] = [
                    item.strip() for item in match.group(2).split(", ") if item.strip()
                ]
    return rotations, animations


def download(url: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "FantasyDisk-FAN3627/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        path.write_bytes(response.read())


def import_character(actor: str, dump_path: Path) -> None:
    rotations, animations = parse_dump(dump_path)
    source_dir = PIXEL_LAB_ROOT / actor
    missing = [direction for direction in DIRECTIONS if direction not in rotations]
    if missing:
        raise RuntimeError(f"{actor}: dump is missing idle rotations: {missing}")
    source_idle = {
        direction: source_dir / f"{actor}_idle_{suffix(direction)}.png"
        for direction in DIRECTIONS
    }
    for direction, path in source_idle.items():
        download(rotations[direction], path)

    for state in ACTOR_STATES[actor]:
        source_state = state
        if state not in animations:
            raise RuntimeError(f"{actor}: dump is missing animation {state}")
        missing = [direction for direction in DIRECTIONS if direction not in animations[state]]
        if missing:
            raise RuntimeError(f"{actor}/{state}: dump is missing directions: {missing}")
        for direction in DIRECTIONS:
            urls = animations[state][direction]
            for index, url in enumerate(urls):
                download(url, source_dir / f"{actor}_{source_state}_{suffix(direction)}_{index:02d}.png")


def global_scale(source_paths: list[Path]) -> float:
    boxes = []
    for path in source_paths:
        with Image.open(path) as image:
            image = image.convert("RGBA")
            box = alpha_bbox(image)
            if box is None:
                raise RuntimeError(f"{path}: source frame has no visible alpha")
            if image.getchannel("A").getextrema()[0] == 255:
                raise RuntimeError(f"{path}: source frame is a solid opaque rectangle")
            boxes.append(box)
    return min(
        TARGET_VISIBLE_HEIGHT / float(max(box[3] - box[1] for box in boxes)),
        CELL_SIZE / float(max(box[2] - box[0] for box in boxes)),
    )


def normalize_frame(source_path: Path, runtime_path: Path, scale: float, rewrite: bool = True) -> dict:
    with Image.open(source_path) as opened:
        image = opened.convert("RGBA")
    box = alpha_bbox(image)
    if box is None:
        raise RuntimeError(f"{source_path}: source frame has no visible alpha")
    width, height = box[2] - box[0], box[3] - box[1]
    resized_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    if rewrite:
        resized = image.crop(box).resize(resized_size, Image.Resampling.NEAREST)
        paste_x = round((CELL_SIZE - resized_size[0]) / 2.0)
        paste_y = CELL_SIZE - BOTTOM_PADDING - resized_size[1]
        if paste_x < 0 or paste_y < 0 or paste_x + resized_size[0] > CELL_SIZE or paste_y + resized_size[1] > CELL_SIZE:
            raise RuntimeError(f"{source_path}: normalized frame exceeds canvas: {resized_size}")
        canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(resized, (paste_x, paste_y))
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(runtime_path)
    with Image.open(runtime_path) as runtime_opened:
        runtime_image = runtime_opened.convert("RGBA")
    runtime_box = alpha_bbox(runtime_image)
    if runtime_box is None or runtime_box[3] != CELL_SIZE - BOTTOM_PADDING:
        raise RuntimeError(f"{runtime_path}: runtime footline drifted: {runtime_box}")
    return {
        "source": source_path.name,
        "runtime": runtime_path.name,
        "source_size": list(image.size),
        "source_alpha_bbox": list(box),
        "source_alpha_bbox_size": [width, height],
        "scale": scale,
        "resized_visible_size": list(resized_size),
        "runtime_alpha_bbox": list(runtime_box),
        "source_encoded_sha256": sha256(source_path),
        "source_pixel_sha256": pixel_sha256(source_path),
        "runtime_encoded_sha256": sha256(runtime_path),
        "runtime_pixel_sha256": pixel_sha256(runtime_path),
    }


def frame_block(resource_ids: list[str], timing: dict, name: str) -> str:
    frames = ",\n".join(
        '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource_id
        for resource_id in resource_ids
    )
    return (
        "{\n"
        f'"frames": [{frames}],\n"loop": {str(timing["loop"]).lower()},\n'
        f'"name": &"{name}",\n"speed": {timing["speed"]}\n'
        "}"
    )


def build_actor(actor: str) -> None:
    source_dir = PIXEL_LAB_ROOT / actor
    runtime_dir = RUNTIME_ROOT / actor
    spriteframes_path = RUNTIME_ROOT / f"{actor}_spriteframes.tres"
    states = ACTOR_STATES[actor]

    source_paths = []
    for direction in DIRECTIONS:
        source_paths.append(source_dir / f"{actor}_idle_{suffix(direction)}.png")
    for state in states:
        for direction in DIRECTIONS:
            expected = frame_count(actor, state)
            source_paths.extend(
                source_dir / f"{actor}_{state}_{suffix(direction)}_{index:02d}.png"
                for index in range(expected)
            )
    missing = [path for path in source_paths if not path.exists()]
    if missing:
        raise RuntimeError(f"{actor}: missing source frames, first: {missing[0]}")
    scale = global_scale(source_paths)

    resources: dict[str, str] = {}
    ext_lines: list[str] = []
    blocks: list[str] = []
    reports: dict[str, list[dict]] = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = path.as_posix()
        if key not in resources:
            resource_id = f"{next_id}_fan3627"
            next_id += 1
            relative = path.relative_to(ROOT).as_posix()
            ext_lines.append(f'[ext_resource type="Texture2D" path="res://{relative}" id="{resource_id}"]')
            resources[key] = resource_id
        return resources[key]

    def add_row(state: str, source_state: str, direction: str, speed: float, loop: bool) -> None:
        row_name = f"{state}_{suffix(direction)}"
        frame_ids = []
        row_reports = []
        count = 1 if source_state == "idle" else frame_count(actor, source_state)
        for index in range(count):
            source_name = f"{actor}_{source_state}_{suffix(direction)}"
            if source_state != "idle":
                source_name += f"_{index:02d}"
            source_path = source_dir / f"{source_name}.png"
            runtime_path = runtime_dir / f"{source_name}.png"
            repair = (actor, source_state, direction) in REPAIRED_DIRECTIONS
            ensure_import_sidecar(source_path)
            row_reports.append(normalize_frame(source_path, runtime_path, scale,
                                               rewrite=repair or not runtime_path.exists()))
            ensure_import_sidecar(runtime_path)
            frame_ids.append(add_resource(runtime_path))
        reports[row_name] = row_reports
        blocks.append(frame_block(frame_ids, {"speed": speed, "loop": loop}, row_name))

    for direction in DIRECTIONS:
        add_row("idle", "idle", direction, STATE_TIMING["idle"]["speed"], True)
    for state in states:
        timing = STATE_TIMING[state]
        for direction in DIRECTIONS:
            add_row(state, state, direction, timing["speed"], timing["loop"])
    for direction in DIRECTIONS:
        add_row("walk", "move", direction, STATE_TIMING["move"]["speed"], True)
        add_row("attack_primary", "attack", direction, STATE_TIMING["attack"]["speed"], False)
    for state in states[4:]:
        for direction in DIRECTIONS:
            add_row(f"attack_{state}", state, direction, STATE_TIMING[state]["speed"], False)

    spriteframes = (
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_lines)
        + '\n\n[resource]\nanimations = [\n'
        + ",\n".join(blocks)
        + "\n]\n"
    )
    spriteframes_path.parent.mkdir(parents=True, exist_ok=True)
    spriteframes_path.write_text(spriteframes, encoding="utf-8")

    runtime_dir.mkdir(parents=True, exist_ok=True)
    (runtime_dir / "row_scale_report.json").write_text(
        json.dumps(reports, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    source_hashes = {path.name: sha256(path) for path in sorted(source_paths)}
    runtime_paths = sorted(runtime_dir.glob(f"{actor}_*.png"))
    runtime_hashes = {path.name: sha256(path) for path in runtime_paths}
    character_id = CHARACTER_IDS[actor]
    states_manifest = {
        "idle": {
            "fallback": False, "frame_count": 1, "mode": "rotations",
            "pixel_lab_character_id": character_id, "source_state": "rotations",
        }
    }
    for state in states:
        timing = STATE_TIMING[state]
        states_manifest[state] = {
            "fallback": False,
            "frame_count": frame_count(actor, state),
            "fps": timing["speed"],
            "mode": timing["mode"],
            "pixel_lab_character_id": character_id,
            "source_state": state,
        }
    manifest = {
        "schema": SCHEMA,
        "actor_id": actor,
        "character_id": actor,
        "pixel_lab_character_id": character_id,
        "pixellab_character_id": character_id,
        "source": "PixelLab MCP",
        "generation_method": "completed 8-direction PixelLab character export",
        "generated_at": "2026-08-28",
        "fallback": False,
        "explicit_eight_directions": True,
        "directions": DIRECTIONS,
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "scale": scale,
        "builder": BUILDER,
        "rebuild": f"python3 {BUILDER} --actor {actor}",
        "download_endpoint": f"https://api.pixellab.ai/mcp/characters/{character_id}/download",
        "states": states_manifest,
        "source_frame_sha256": source_hashes,
        "runtime_frame_sha256": runtime_hashes,
        "alpha_bbox_report": reports,
        "provenance": {
            "pixel_lab_character_id": character_id,
            "download_endpoint": f"https://api.pixellab.ai/mcp/characters/{character_id}/download",
            "source_frame_sha256": list(source_hashes.values()),
        },
    }
    (source_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"{actor}: source={len(source_paths)} runtime={len(runtime_paths)} scale={scale:.12g}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actor", choices=sorted(ACTOR_STATES), action="append", dest="actors")
    parser.add_argument("--download-from-dump", type=Path,
                        help="import a completed get_character dump before building")
    args = parser.parse_args()
    actors = args.actors or sorted(ACTOR_STATES)
    if args.download_from_dump:
        if actors != ["mini_plague_berserker"]:
            raise SystemExit("--download-from-dump is reserved for mini_plague_berserker")
        import_character(actors[0], args.download_from_dump)
    for actor in actors:
        build_actor(actor)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAN-3627 pack build failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
