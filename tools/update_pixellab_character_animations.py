#!/usr/bin/env python3
"""Refresh playable PixelLab character packs into FantasyDisk runtime assets.

The script intentionally refuses partial PixelLab exports. A character is updated
only when the downloaded pack has all 8 rotations and at least 6 movement frames
for every direction; otherwise the existing repo assets are left untouched and a
blocker is recorded in the report.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - environment guard
    raise SystemExit("Pillow is required: python3 -m pip install Pillow") from exc


DIRECTIONS = [
    "south",
    "south-east",
    "east",
    "north-east",
    "north",
    "north-west",
    "west",
    "south-west",
]

UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)
USER_AGENT = "FantasyDisk-Codex-SCRUM-869/1.0"


def animation_suffix(direction: str) -> str:
    return direction.replace("-", "_")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def playable_character_ids(project_root: Path) -> list[str]:
    text = (project_root / "scripts/progression_data_characters.gd").read_text(encoding="utf-8")
    start = text.index("const CHARACTER_CONFIGS := {")
    end = text.index("\nconst ULTIMATE_CONFIGS", start)
    return re.findall(r'^\t"([a-z_]+)": \{', text[start:end], flags=re.MULTILINE)


def manifest_uuid(manifest: dict) -> str | None:
    for key in ("pixellab_character_id", "character_id"):
        value = manifest.get(key)
        if isinstance(value, str) and UUID_RE.match(value):
            return value
    return None


def download_pack(character_uuid: str, dest_zip: Path) -> None:
    url = f"https://api.pixellab.ai/mcp/characters/{character_uuid}/download"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            dest_zip.parent.mkdir(parents=True, exist_ok=True)
            dest_zip.write_bytes(response.read())
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"download HTTP {exc.code}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"download failed: {exc.reason}") from exc


def extract_metadata(zip_path: Path, extract_dir: Path) -> dict:
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(extract_dir)
    metadata_path = extract_dir / "metadata.json"
    if not metadata_path.exists():
        raise RuntimeError("metadata.json missing in PixelLab download")
    metadata = read_json(metadata_path)
    states = metadata.get("states")
    if not isinstance(states, list) or not states:
        raise RuntimeError("metadata.json has no states")
    return metadata


def select_state(metadata: dict, character_uuid: str) -> dict:
    states = metadata.get("states", [])
    for state in states:
        if str(state.get("character", {}).get("id", "")) == character_uuid:
            return state
    return states[0]


def select_motion_frames(state: dict, move_frame_count: int) -> tuple[dict[str, list[str]], dict[str, str]]:
    animations = state.get("frames", {}).get("animations", {})
    selected: dict[str, list[str]] = {}
    selected_folder: dict[str, str] = {}
    for direction in DIRECTIONS:
        for folder, by_direction in animations.items():
            frames = by_direction.get(direction, [])
            if len(frames) >= move_frame_count:
                selected[direction] = list(frames[-move_frame_count:])
                selected_folder[direction] = folder
                break
    return selected, selected_folder


def validate_pack(state: dict, move_frame_count: int) -> tuple[list[str], dict[str, list[str]], dict[str, str]]:
    frames = state.get("frames", {})
    rotations = frames.get("rotations", {})
    blockers: list[str] = []
    missing_rotations = [direction for direction in DIRECTIONS if direction not in rotations]
    if missing_rotations:
        blockers.append("missing rotations: " + ", ".join(missing_rotations))
    motion, folders = select_motion_frames(state, move_frame_count)
    missing_motion = [direction for direction in DIRECTIONS if direction not in motion]
    if missing_motion:
        blockers.append("missing 6f movement rows: " + ", ".join(missing_motion))
    return blockers, motion, folders


def copy_source_files(
    extract_dir: Path,
    state: dict,
    motion: dict[str, list[str]],
    source_dir: Path,
    character_id: str,
) -> dict:
    source_dir.mkdir(parents=True, exist_ok=True)
    source_files = {"idle": {}, "move": {}}
    rotations = state["frames"]["rotations"]
    for direction in DIRECTIONS:
        idle_dest = source_dir / f"{character_id}_idle_{direction}.png"
        shutil.copyfile(extract_dir / rotations[direction], idle_dest)
        source_files["idle"][direction] = idle_dest.name
        source_files["move"][direction] = []
        for index, rel_frame in enumerate(motion[direction]):
            move_dest = source_dir / f"{character_id}_move_{direction}_{index:02d}.png"
            shutil.copyfile(extract_dir / rel_frame, move_dest)
            source_files["move"][direction].append(move_dest.name)
    return source_files


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def visible_height_target(manifest: dict, default: int) -> int:
    for key in ("runtime_visible_height_target", "runtime_visible_height_px"):
        value = manifest.get(key)
        if isinstance(value, int):
            return value
        if isinstance(value, list) and value:
            numeric = [int(v) for v in value if isinstance(v, (int, float))]
            if numeric:
                return int(round(sum(numeric) / len(numeric)))
    return default


def bottom_padding(manifest: dict, default: int) -> int:
    for key in ("runtime_bottom_padding", "bottom_padding_px"):
        value = manifest.get(key)
        if isinstance(value, int):
            return value
    return default


def normalize_frame(
    source_path: Path,
    dest_path: Path,
    *,
    cell_size: int,
    target_visible_height: int,
    bottom_pad: int,
) -> dict:
    image = Image.open(source_path).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"{source_path} has no visible alpha")
    bbox_width = bbox[2] - bbox[0]
    bbox_height = bbox[3] - bbox[1]
    scale = target_visible_height / float(bbox_height)
    scaled_size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    resized = image.resize(scaled_size, Image.Resampling.NEAREST)
    scaled_bbox = tuple(round(v * scale) for v in bbox)
    visible_center_x = (scaled_bbox[0] + scaled_bbox[2]) / 2.0
    paste_x = round((cell_size / 2.0) - visible_center_x)
    paste_y = round((cell_size - bottom_pad) - scaled_bbox[3])
    if paste_x < -scaled_size[0] or paste_y < -scaled_size[1]:
        raise RuntimeError(f"{source_path} normalized outside canvas")
    canvas = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
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
        "runtime_alpha_bbox": list(runtime_bbox) if runtime_bbox else None,
    }


def normalize_character(
    source_dir: Path,
    runtime_dir: Path,
    character_id: str,
    manifest: dict,
    move_frame_count: int,
    cell_size: int,
    default_visible_height: int,
    default_bottom_padding: int,
) -> dict:
    target_height = visible_height_target(manifest, default_visible_height)
    bottom_pad = bottom_padding(manifest, default_bottom_padding)
    report = {
        "runtime_canvas": [cell_size, cell_size],
        "target_visible_height": target_height,
        "bottom_padding": bottom_pad,
        "frames": [],
    }
    runtime_dir.mkdir(parents=True, exist_ok=True)
    for direction in DIRECTIONS:
        idle_src = source_dir / f"{character_id}_idle_{direction}.png"
        idle_dest = runtime_dir / f"{character_id}_idle_{direction}.png"
        report["frames"].append(
            normalize_frame(
                idle_src,
                idle_dest,
                cell_size=cell_size,
                target_visible_height=target_height,
                bottom_pad=bottom_pad,
            )
        )
        for index in range(move_frame_count):
            move_src = source_dir / f"{character_id}_move_{direction}_{index:02d}.png"
            move_dest = runtime_dir / f"{character_id}_move_{direction}_{index:02d}.png"
            report["frames"].append(
                normalize_frame(
                    move_src,
                    move_dest,
                    cell_size=cell_size,
                    target_visible_height=target_height,
                    bottom_pad=bottom_pad,
                )
            )
    return report


def frame_block(resource_ids: list[str], speed: float, name: str) -> str:
    frames = []
    for resource_id in resource_ids:
        frames.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource_id)
    return (
        "{\n"
        '"frames": [%s],\n'
        '"loop": true,\n'
        '"name": &"%s",\n'
        '"speed": %s\n'
        "}"
    ) % (", ".join(frames), name, speed)


def write_spriteframes(
    spriteframes_path: Path,
    runtime_dir: Path,
    project_root: Path,
    character_id: str,
    move_frame_count: int,
    move_speed: float,
) -> None:
    ext_lines = []
    resources: dict[str, str] = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resources:
            return resources[key]
        resource_id = f"{next_id}_pixellab"
        next_id += 1
        rel_path = path.resolve().relative_to(project_root).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel_path}" id="{resource_id}"]')
        resources[key] = resource_id
        return resource_id

    idle_ids: dict[str, str] = {}
    move_ids: dict[str, list[str]] = {}
    for direction in DIRECTIONS:
        idle_ids[direction] = add_resource(runtime_dir / f"{character_id}_idle_{direction}.png")
        move_ids[direction] = [
            add_resource(runtime_dir / f"{character_id}_move_{direction}_{index:02d}.png")
            for index in range(move_frame_count)
        ]

    animations = [
        frame_block([idle_ids["south"]], 1.0, "idle"),
        frame_block(move_ids["south"], move_speed, "move"),
        frame_block(move_ids["south"], move_speed, "walk"),
    ]
    for direction in DIRECTIONS:
        suffix = animation_suffix(direction)
        animations.append(frame_block([idle_ids[direction]], 1.0, f"idle_{suffix}"))
    for direction in DIRECTIONS:
        suffix = animation_suffix(direction)
        animations.append(frame_block(move_ids[direction], move_speed, f"move_{suffix}"))
    for direction in DIRECTIONS:
        suffix = animation_suffix(direction)
        animations.append(frame_block(move_ids[direction], move_speed, f"walk_{suffix}"))

    spriteframes_path.write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n[resource]\nanimations = [\n"
        + ",\n".join(animations)
        + "\n]\n",
        encoding="utf-8",
    )


def update_manifest(
    manifest_path: Path,
    manifest: dict,
    metadata: dict,
    state: dict,
    source_files: dict,
    selected_folders: dict[str, str],
    normalize_report: dict,
    args: argparse.Namespace,
) -> None:
    character = state.get("character", {})
    manifest["pixellab_character_id"] = character.get("id", manifest.get("pixellab_character_id"))
    manifest["pixellab_name"] = character.get("name", manifest.get("pixellab_name"))
    manifest["directions"] = DIRECTIONS
    manifest["move_frame_count"] = args.move_frame_count
    manifest["runtime_canvas"] = f"{args.cell_size}x{args.cell_size}"
    manifest["source_files"] = source_files
    manifest["runtime_dir"] = f"assets/sprites/characters/full_frame/{manifest_path.parent.name}_pixellab"
    manifest["spriteframes"] = f"assets/sprites/characters/{manifest_path.parent.name}_spriteframes.tres"
    manifest["scrum869_refresh"] = {
        "task": "SCRUM-869",
        "refreshed_at": utc_now(),
        "pixellab_download_export_date": metadata.get("export_date"),
        "pixellab_export_version": metadata.get("export_version"),
        "selected_animation_folders": selected_folders,
        "runtime_canvas": normalize_report["runtime_canvas"],
        "runtime_visible_height_target": normalize_report["target_visible_height"],
        "runtime_bottom_padding": normalize_report["bottom_padding"],
        "source": "PixelLab MCP download endpoint",
        "legacy_or_manual_fallback_used": False,
    }
    write_json(manifest_path, manifest)


def refresh_character(project_root: Path, character_id: str, args: argparse.Namespace) -> dict:
    source_dir = project_root / "assets/sprites/characters/pixellab" / character_id
    manifest_path = source_dir / "manifest.json"
    if not manifest_path.exists():
        return {"character": character_id, "status": "blocked", "reason": "manifest.json missing"}
    manifest = read_json(manifest_path)
    character_uuid = manifest_uuid(manifest)
    if not character_uuid:
        return {"character": character_id, "status": "blocked", "reason": "manifest has no PixelLab UUID"}

    with tempfile.TemporaryDirectory(prefix=f"scrum869_{character_id}_") as tmp:
        tmp_path = Path(tmp)
        zip_path = tmp_path / f"{character_id}.zip"
        try:
            download_pack(character_uuid, zip_path)
            extract_dir = tmp_path / "extract"
            metadata = extract_metadata(zip_path, extract_dir)
            state = select_state(metadata, character_uuid)
            blockers, motion, selected_folders = validate_pack(state, args.move_frame_count)
        except Exception as exc:
            return {
                "character": character_id,
                "status": "blocked",
                "pixellab_character_id": character_uuid,
                "reason": str(exc),
            }
        character = state.get("character", {})
        if blockers:
            return {
                "character": character_id,
                "status": "blocked",
                "pixellab_character_id": character_uuid,
                "pixellab_name": character.get("name"),
                "reason": "; ".join(blockers),
            }
        result = {
            "character": character_id,
            "status": "dry_run" if args.dry_run else "refreshed",
            "pixellab_character_id": character_uuid,
            "pixellab_name": character.get("name"),
            "pixellab_export_date": metadata.get("export_date"),
            "selected_animation_folders": selected_folders,
        }
        if args.dry_run:
            return result
        source_files = copy_source_files(extract_dir, state, motion, source_dir, character_id)
        runtime_dir = project_root / "assets/sprites/characters/full_frame" / f"{character_id}_pixellab"
        normalize_report = normalize_character(
            source_dir,
            runtime_dir,
            character_id,
            manifest,
            args.move_frame_count,
            args.cell_size,
            args.visible_height,
            args.bottom_padding,
        )
        spriteframes_path = project_root / "assets/sprites/characters" / f"{character_id}_spriteframes.tres"
        write_spriteframes(
            spriteframes_path,
            runtime_dir,
            project_root,
            character_id,
            args.move_frame_count,
            args.move_speed,
        )
        write_json(source_dir / "alpha_bbox_report.json", normalize_report)
        update_manifest(
            manifest_path,
            manifest,
            metadata,
            state,
            source_files,
            selected_folders,
            normalize_report,
            args,
        )
        result["source_dir"] = str(source_dir.relative_to(project_root))
        result["runtime_dir"] = str(runtime_dir.relative_to(project_root))
        result["spriteframes"] = str(spriteframes_path.relative_to(project_root))
        return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", action="append", help="Character id to refresh; repeatable")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--report", type=Path, default=Path("build/qa/pixellab_character_animation_refresh/report.json"))
    parser.add_argument("--move-frame-count", type=int, default=6)
    parser.add_argument("--cell-size", type=int, default=512)
    parser.add_argument("--visible-height", type=int, default=245)
    parser.add_argument("--bottom-padding", type=int, default=32)
    parser.add_argument("--move-speed", type=float, default=10.0)
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    characters = args.character or playable_character_ids(project_root)
    report = {
        "task": "SCRUM-869",
        "generated_at": utc_now(),
        "dry_run": args.dry_run,
        "characters_requested": characters,
        "results": [],
    }
    for character_id in characters:
        result = refresh_character(project_root, character_id, args)
        report["results"].append(result)
        print(f"{character_id}: {result['status']} - {result.get('reason', result.get('pixellab_character_id', ''))}")
    refreshed = [r["character"] for r in report["results"] if r["status"] in {"refreshed", "dry_run"}]
    blocked = [r for r in report["results"] if r["status"] == "blocked"]
    report["summary"] = {
        "refreshed_or_ready_count": len(refreshed),
        "blocked_count": len(blocked),
        "refreshed_or_ready": refreshed,
        "blocked": blocked,
    }
    if args.report:
        report_path = args.report if args.report.is_absolute() else project_root / args.report
        write_json(report_path, report)
        print(f"report: {report_path}")
    return 0 if not blocked else 1


if __name__ == "__main__":
    raise SystemExit(main())
