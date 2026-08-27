#!/usr/bin/env python3
"""Build the FAN-2623 Shard Marshal pack from its completed PixelLab export.

The export is a completed 8-direction PixelLab character.  This builder keeps
the 48x48 source frames separate from the 512x512 runtime frames, normalizes
every frame with one global scale and bottom footline, and writes the
directional SpriteFrames resource plus a provenance manifest without signed
URLs or credentials.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ID = "shard_marshal"
PIXELLAB_CHARACTER_ID = "06de6f32-fca4-43f2-a657-b011a85d7632"
PIXELLAB_GROUP_ID = "e314660c-298f-4e81-a3e7-5fadd79e50ec"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
SOURCE_DIR = ROOT / "assets/sprites/elites/pixellab/shard_marshal"
RUNTIME_DIR = ROOT / "assets/sprites/elites/full_frame/shard_marshal"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/elites/full_frame/shard_marshal_spriteframes.tres"
EXPORT_URL = f"https://api.pixellab.ai/mcp/characters/{PIXELLAB_CHARACTER_ID}/download"
USER_AGENT = "FantasyDisk-Codex-FAN-2623/1.0"

DIRECTIONS = [
    "east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"
]
STATES = {
    "idle": {"loop": True, "speed": 1.0},
    "move": {"loop": True, "speed": 9.0},
    "attack": {"loop": False, "speed": 12.0},
    "hit": {"loop": False, "speed": 10.0},
    "death": {"loop": False, "speed": 10.0},
    "skill_shard_fan": {"loop": False, "speed": 12.0},
    "skill_command_pulse": {"loop": False, "speed": 12.0},
}


def suffix(direction: str) -> str:
    return direction


def archive_direction(direction: str) -> str:
    """Map canonical runtime suffixes to PixelLab export rotation keys."""
    return direction.replace("_", "-")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def download_export() -> bytes:
    request = urllib.request.Request(EXPORT_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def read_state(metadata: dict) -> dict:
    for state in metadata.get("states", []):
        if state.get("character", {}).get("id") == PIXELLAB_CHARACTER_ID:
            return state
    raise RuntimeError(f"PixelLab export has no state for {PIXELLAB_CHARACTER_ID}")


def source_name(state: str, direction: str, index: int | None = None) -> str:
    name = f"{CHARACTER_ID}_{state}_{suffix(direction)}"
    return f"{name}.png" if index is None else f"{name}_{index:02d}.png"


def collect_source_names(state: dict) -> dict[str, dict[str, list[str]]]:
    frames = state.get("frames", {})
    rotations = frames.get("rotations", {})
    animations = frames.get("animations", {})
    missing = [direction for direction in DIRECTIONS if archive_direction(direction) not in rotations]
    if missing:
        raise RuntimeError(f"missing idle directions: {missing}")

    files: dict[str, dict[str, list[str]]] = {"idle": {}}
    for direction in DIRECTIONS:
        files["idle"][direction] = [source_name("idle", direction)]
    for state_name in list(STATES)[1:]:
        by_direction = animations.get(state_name, {})
        files[state_name] = {}
        for direction in DIRECTIONS:
            source_frames = by_direction.get(archive_direction(direction), [])
            expected = len(source_frames)
            if expected == 0:
                raise RuntimeError(f"missing {state_name} direction: {direction}")
            files[state_name][direction] = [source_name(state_name, direction, i) for i in range(expected)]
    return files


def extract_sources(archive: zipfile.ZipFile, state: dict, files: dict[str, dict[str, list[str]]]) -> None:
    frames = state["frames"]
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    for direction in DIRECTIONS:
        destination = SOURCE_DIR / source_name("idle", direction)
        destination.write_bytes(archive.read(frames["rotations"][archive_direction(direction)]))
    for state_name in list(STATES)[1:]:
        for direction in DIRECTIONS:
            for index, archive_name in enumerate(frames["animations"][state_name][archive_direction(direction)]):
                (SOURCE_DIR / source_name(state_name, direction, index)).write_bytes(archive.read(archive_name))


def source_paths(files: dict[str, dict[str, list[str]]]) -> list[Path]:
    return [SOURCE_DIR / filename for state in files.values() for names in state.values() for filename in names]


def normalize_frame(source: Path, destination: Path, scale: float) -> dict:
    image = Image.open(source).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"{source} has no visible alpha")
    width = max(1, round((bbox[2] - bbox[0]) * scale))
    height = max(1, round((bbox[3] - bbox[1]) * scale))
    if width > CELL_SIZE or height + BOTTOM_PADDING > CELL_SIZE:
        raise RuntimeError(f"{source} does not fit runtime canvas: {width}x{height}")
    visible = image.crop(bbox).resize((width, height), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    paste_x = round((CELL_SIZE - width) / 2.0)
    paste_y = CELL_SIZE - BOTTOM_PADDING - height
    canvas.alpha_composite(visible, (paste_x, paste_y))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination)
    runtime_bbox = alpha_bbox(canvas)
    return {
        "source": source.name,
        "runtime": destination.name,
        "source_size": list(image.size),
        "source_alpha_bbox": list(bbox),
        "source_alpha_bbox_size": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "scale": scale,
        "runtime_alpha_bbox": list(runtime_bbox) if runtime_bbox else None,
        "encoded_sha256": sha256(destination),
    }


def frame_block(resource_ids: list[str], timing: dict, name: str) -> str:
    frames = ",\n".join(
        '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource_id
        for resource_id in resource_ids
    )
    return (
        "{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %.1f\n}"
        % (frames, "true" if timing["loop"] else "false", name, timing["speed"])
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true", help="rebuild from already-exported source PNGs")
    args = parser.parse_args()

    if args.offline:
        metadata_path = SOURCE_DIR / "pixellab_export_metadata.json"
        if not metadata_path.exists():
            raise SystemExit(f"missing {metadata_path}; run without --offline once")
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        state = read_state(metadata)
        files = collect_source_names(state)
    else:
        with zipfile.ZipFile(io.BytesIO(download_export())) as archive:
            metadata = json.loads(archive.read("metadata.json"))
            state = read_state(metadata)
            files = collect_source_names(state)
            extract_sources(archive, state, files)
        (SOURCE_DIR / "pixellab_export_metadata.json").write_text(
            json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    paths = source_paths(files)
    missing = [str(path) for path in paths if not path.exists()]
    if missing:
        raise RuntimeError("missing source frames:\n" + "\n".join(missing))
    measurements = []
    for path in paths:
        with Image.open(path) as image:
            image = image.convert("RGBA")
            bbox = alpha_bbox(image)
            if bbox is None:
                raise RuntimeError(f"{path} has no visible alpha")
            measurements.append((bbox[2] - bbox[0], bbox[3] - bbox[1]))
    scale = min(
        TARGET_VISIBLE_HEIGHT / max(height for _, height in measurements),
        CELL_SIZE / max(width for width, _ in measurements),
    )

    ext_lines: list[str] = []
    resource_ids: dict[str, str] = {}
    alpha_report: dict[str, list[dict]] = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = path.as_posix()
        if key in resource_ids:
            return resource_ids[key]
        resource_id = f"{next_id}_sm"
        next_id += 1
        relative = path.relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{relative}" id="{resource_id}"]')
        resource_ids[key] = resource_id
        return resource_id

    animation_blocks: list[str] = []
    for state_name, timing in STATES.items():
        for direction in DIRECTIONS:
            suffix_name = suffix(direction)
            reports = []
            ids = []
            for filename in files[state_name][direction]:
                source = SOURCE_DIR / filename
                runtime = RUNTIME_DIR / filename
                reports.append(normalize_frame(source, runtime, scale))
                ids.append(add_resource(runtime))
            row_name = f"{state_name}_{suffix_name}"
            alpha_report[row_name] = reports
            animation_blocks.append(frame_block(ids, timing, row_name))

    # Existing resolver/validator names are kept as exact row aliases, not
    # mirrored images or fallback placeholders.
    for alias, target in [("attack_primary", "attack"),
                          ("attack_shard_fan", "skill_shard_fan"),
                          ("attack_command_pulse", "skill_command_pulse")]:
        timing = STATES[target]
        for direction in DIRECTIONS:
            alias_row = f"{alias}_{suffix(direction)}"
            target_row = alpha_report[f"{target}_{suffix(direction)}"]
            ids = [add_resource(RUNTIME_DIR / item["runtime"]) for item in target_row]
            animation_blocks.append(frame_block(ids, timing, alias_row))

    SPRITEFRAMES_PATH.write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n[resource]\nanimations = [\n"
        + ",\n".join(animation_blocks)
        + "\n]\n",
        encoding="utf-8",
    )
    (RUNTIME_DIR / "row_scale_report.json").write_text(
        json.dumps(alpha_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    state_counts = {name: len(next(iter(by_direction.values()))) for name, by_direction in files.items()}
    source_hashes = {path.name: sha256(path) for path in paths}
    manifest = {
        "manifest_version": 1,
        "character_id": CHARACTER_ID,
        "pixellab_character_id": PIXELLAB_CHARACTER_ID,
        "pixellab_group_id": metadata.get("group_id", PIXELLAB_GROUP_ID),
        "source": "PixelLab MCP completed character export",
        "reference_image": "assets/sprites/elites/shard_marshal.png",
        "export": {
            "export_version": metadata.get("export_version"),
            "export_date": metadata.get("export_date"),
            "state_name": state["character"].get("name"),
            "created_at": state["character"].get("created_at"),
            "prompt": state["character"].get("prompt"),
            "body_type": state["character"].get("template_id"),
            "view": state["character"].get("view"),
            "source_size": [state["character"]["size"]["width"], state["character"]["size"]["height"]],
        },
        "directions": DIRECTIONS,
        "states": {
            name: {
                "frame_count": state_counts[name],
                "fps": timing["speed"],
                "loop": timing["loop"],
                "source_files": files[name],
            }
            for name, timing in STATES.items()
        },
        "aliases": {
            "attack_primary": "attack",
            "attack_shard_fan": "skill_shard_fan",
            "attack_command_pulse": "skill_command_pulse",
        },
        "normalization": {
            "runtime_canvas": [CELL_SIZE, CELL_SIZE],
            "target_visible_height": TARGET_VISIBLE_HEIGHT,
            "bottom_padding": BOTTOM_PADDING,
            "scale_strategy": "one global nearest-neighbor scale; every frame bottom-aligned",
            "global_scale": scale,
            "source_dir": "assets/sprites/elites/pixellab/shard_marshal",
            "runtime_dir": "assets/sprites/elites/full_frame/shard_marshal",
        },
        "source_frame_sha256": source_hashes,
        "notes": (
            "FAN-2623: preserves the shipped Shard Marshal identity from the existing "
            "runtime sprite reference through the completed PixelLab 8-direction character. "
            "All eight directions are authored explicitly; no flip_h mirroring is part of "
            "the pack. mini_swarm_sniper intentionally resolves this elite's base registry "
            "entry until a mini-specific pack exists."
        ),
    }
    (SOURCE_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (RUNTIME_DIR / "manifest.json").write_text(
        json.dumps({
            "character_id": CHARACTER_ID,
            "source_manifest": "assets/sprites/elites/pixellab/shard_marshal/manifest.json",
            "runtime_canvas": [CELL_SIZE, CELL_SIZE],
            "directions": DIRECTIONS,
            "states": {name: {"frame_count": state_counts[name], "fps": timing["speed"], "loop": timing["loop"]}
                       for name, timing in STATES.items()},
            "aliases": manifest["aliases"],
            "normalization": manifest["normalization"],
        }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"source frames: {len(paths)}")
    print(f"runtime rows: {len(STATES) * len(DIRECTIONS)} + 24 aliases")
    print(f"global scale: {scale:.6f}")
    print(f"wrote {SPRITEFRAMES_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
