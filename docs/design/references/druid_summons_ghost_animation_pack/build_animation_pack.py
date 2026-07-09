#!/usr/bin/env python3
"""Build the SCRUM-1016 west/east PixelLab ally animation pack.

The PixelLab download contains the service-side four-direction character state.
This builder intentionally copies only west/east animation frames into the
repository, keeps raw PixelLab source separate from normalized runtime PNGs,
and uses one global scale plus a shared bottom baseline for the full five-creature
pack.
"""

from __future__ import annotations

import json
import re
import shutil
import tempfile
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
REFERENCE_DIR = Path(__file__).resolve().parent
PREVIEW_DIR = ROOT / "docs/design/previews"
ALLY_DIR = ROOT / "assets/sprites/allies"
CELL_SIZE = 256
BASELINE_Y = 232
MAX_VISIBLE_WIDTH = 216
MAX_VISIBLE_HEIGHT = 208
MAX_GLOBAL_SCALE = 1.45
ALPHA_THRESHOLD = 4
MOVE_SPEED = 10.0
ATTACK_SPEED = 12.0
DIRECTIONS = {"west": "left", "east": "right"}
USER_AGENT = "FantasyDisk-Codex-SCRUM-1016/1.0"
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def validate_job_evidence(job_evidence: dict, characters: list[dict]) -> None:
    recorded = job_evidence.get("characters", {})
    expected_ids = {character["id"] for character in characters}
    if set(recorded) != expected_ids:
        raise RuntimeError(f"PixelLab job evidence IDs {sorted(recorded)} do not match {sorted(expected_ids)}")
    job_ids = []
    for character_id in sorted(expected_ids):
        for kind in ("move", "attack"):
            by_direction = recorded[character_id].get(kind, {})
            if set(by_direction) != {"left", "right"}:
                raise RuntimeError(f"{character_id} {kind} job evidence must contain only left/right")
            for direction in ("left", "right"):
                evidence = by_direction[direction]
                if not isinstance(evidence, dict):
                    raise RuntimeError(f"Missing structured PixelLab evidence for {character_id} {kind}_{direction}")
                job_id = str(evidence.get("job_id", ""))
                if not UUID_RE.fullmatch(job_id):
                    raise RuntimeError(f"Invalid PixelLab job UUID for {character_id} {kind}_{direction}: {job_id}")
                if not str(evidence.get("download_folder", "")):
                    raise RuntimeError(f"Missing exact PixelLab download folder for {character_id} {kind}_{direction}")
                if int(evidence.get("exported_frame_count", 0)) != 6:
                    raise RuntimeError(f"Expected exactly 6 exported frames for {character_id} {kind}_{direction}")
                job_ids.append(job_id)
    if len(job_ids) != 20 or len(set(job_ids)) != 20:
        raise RuntimeError("PixelLab job evidence must contain exactly 20 unique successful job UUIDs")


def download_pack(character_uuid: str, destination: Path) -> None:
    url = f"https://api.pixellab.ai/mcp/characters/{character_uuid}/download"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            destination.write_bytes(response.read())
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"PixelLab download HTTP {exc.code} for {character_uuid}") from exc


def selected_state(metadata: dict, character_uuid: str) -> dict:
    states = metadata.get("states", [])
    for state in states:
        if str(state.get("character", {}).get("id", "")) == character_uuid:
            return state
    raise RuntimeError(f"PixelLab metadata does not contain exact accepted character UUID {character_uuid}")


def require_animation_direction(animations: dict, folder: str, service_direction: str, kind: str) -> list[str]:
    by_direction = animations.get(folder)
    if not isinstance(by_direction, dict):
        raise RuntimeError(f"Exact PixelLab {kind} folder {folder!r} is missing")
    frames = list(by_direction.get(service_direction, []))
    if len(frames) != 6:
        raise RuntimeError(
            f"Exact PixelLab {kind} folder {folder!r}/{service_direction} has {len(frames)} frames, expected 6"
        )
    return frames


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    return mask.getbbox()


def copy_selected_sources(extract_dir: Path, character: dict, state: dict, destination: Path, job_evidence: dict) -> dict:
    animations = state.get("frames", {}).get("animations", {})
    selected: dict[str, dict[str, str]] = {"move": {}, "attack": {}}
    source_files: dict[str, dict[str, list[str]]] = {"move": {}, "attack": {}}
    source_root = destination / "pixellab_source"
    source_root.mkdir(parents=True, exist_ok=True)
    (source_root / ".gdignore").write_text(
        "# Raw PixelLab provenance only; runtime imports live in ../runtime/.\n",
        encoding="utf-8",
    )
    for kind in ("move", "attack"):
        for service_direction, runtime_direction in DIRECTIONS.items():
            evidence = job_evidence[kind][runtime_direction]
            folder = str(evidence["download_folder"])
            frames = require_animation_direction(animations, folder, service_direction, kind)
            selected[kind][runtime_direction] = folder
            direction_dir = source_root / kind / runtime_direction
            direction_dir.mkdir(parents=True, exist_ok=True)
            source_files[kind][runtime_direction] = []
            for index, relative_path in enumerate(frames):
                source_path = extract_dir / relative_path
                target = direction_dir / f"{character['id']}_{kind}_{runtime_direction}_{index:02d}.png"
                shutil.copyfile(source_path, target)
                source_files[kind][runtime_direction].append(target.relative_to(ROOT).as_posix())
    return {"selected_folders": selected, "source_files": source_files}


def collect_source_frames(characters: list[dict]) -> list[Path]:
    frames = []
    for character in characters:
        frames.extend(sorted((ALLY_DIR / character["id"] / "pixellab_source").glob("*/*/*.png")))
    return frames


def global_scale_for(frames: list[Path]) -> tuple[float, dict[str, dict]]:
    max_width = 0
    max_height = 0
    bboxes = {}
    for frame in frames:
        image = Image.open(frame).convert("RGBA")
        if image.size != (180, 180):
            raise RuntimeError(f"Expected PixelLab 180x180 source frame, got {image.size} in {frame}")
        corner_alpha = [
            image.getpixel((0, 0))[3],
            image.getpixel((image.width - 1, 0))[3],
            image.getpixel((0, image.height - 1))[3],
            image.getpixel((image.width - 1, image.height - 1))[3],
        ]
        if max(corner_alpha) > ALPHA_THRESHOLD:
            raise RuntimeError(f"Non-transparent PixelLab source corner {corner_alpha} in {frame}")
        bbox = alpha_bbox(image)
        if bbox is None:
            raise RuntimeError(f"No visible alpha in {frame}")
        bbox_width = bbox[2] - bbox[0]
        bbox_height = bbox[3] - bbox[1]
        mask = image.getchannel("A").point(lambda value: 1 if value > ALPHA_THRESHOLD else 0)
        visible_pixels = sum(mask.getdata())
        bbox_area = bbox_width * bbox_height
        perimeter_points = set()
        for x in range(bbox[0], bbox[2]):
            perimeter_points.add((x, bbox[1]))
            perimeter_points.add((x, bbox[3] - 1))
        for y in range(bbox[1], bbox[3]):
            perimeter_points.add((bbox[0], y))
            perimeter_points.add((bbox[2] - 1, y))
        perimeter_visible = sum(1 for x, y in perimeter_points if mask.getpixel((x, y)) > 0)
        fill_ratio = visible_pixels / float(max(1, bbox_area))
        perimeter_coverage = perimeter_visible / float(max(1, len(perimeter_points)))
        source_gutters = [bbox[0], bbox[1], image.width - bbox[2], image.height - bbox[3]]
        if min(source_gutters) < 2:
            raise RuntimeError(f"PixelLab source alpha touches/crops the canvas edge in {frame}: {source_gutters}")
        if fill_ratio > 0.92 or perimeter_coverage > 0.80:
            raise RuntimeError(
                f"PixelLab source has implausibly rectangular/matte alpha in {frame}: "
                f"fill={fill_ratio:.4f} perimeter={perimeter_coverage:.4f}"
            )
        bboxes[frame.relative_to(ROOT).as_posix()] = {
            "bbox": list(bbox),
            "gutters": source_gutters,
            "visible_fill_ratio": round(fill_ratio, 6),
            "bbox_perimeter_coverage": round(perimeter_coverage, 6),
            "transparent_corners": True,
            "matte_rectangle_check": "PASS",
        }
        max_width = max(max_width, bbox_width)
        max_height = max(max_height, bbox_height)
    scale = min(MAX_GLOBAL_SCALE, MAX_VISIBLE_WIDTH / max_width, MAX_VISIBLE_HEIGHT / max_height)
    return scale, bboxes


def normalize_frame(source: Path, destination: Path, scale: float) -> dict:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 0 if value <= ALPHA_THRESHOLD else value)
    image.putalpha(alpha)
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"No visible alpha in {source}")
    cropped = image.crop(bbox)
    width = max(1, round(cropped.width * scale))
    height = max(1, round(cropped.height * scale))
    resized = cropped.resize((width, height), Image.Resampling.NEAREST)
    paste_x = round((CELL_SIZE - width) / 2.0)
    paste_y = BASELINE_Y - height
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (paste_x, paste_y))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination)
    runtime_bbox = alpha_bbox(canvas)
    if runtime_bbox is None:
        raise RuntimeError(f"No visible runtime alpha in {destination}")
    gutters = [runtime_bbox[0], runtime_bbox[1], CELL_SIZE - runtime_bbox[2], CELL_SIZE - runtime_bbox[3]]
    if min(gutters) < 12:
        raise RuntimeError(f"Unsafe gutter {gutters} in {destination}")
    return {
        "source": source.relative_to(ROOT).as_posix(),
        "runtime": destination.relative_to(ROOT).as_posix(),
        "source_size": list(image.size),
        "source_bbox": list(bbox),
        "runtime_size": [CELL_SIZE, CELL_SIZE],
        "runtime_bbox": list(runtime_bbox),
        "gutters": gutters,
        "baseline_y": BASELINE_Y,
        "center_x": CELL_SIZE // 2,
        "global_scale": scale,
    }


def normalize_all(characters: list[dict], scale: float) -> dict[str, list[dict]]:
    reports = {}
    for character in characters:
        character_id = character["id"]
        source_root = ALLY_DIR / character_id / "pixellab_source"
        runtime_root = ALLY_DIR / character_id / "runtime"
        reports[character_id] = []
        for kind in ("move", "attack"):
            for direction in ("left", "right"):
                for source in sorted((source_root / kind / direction).glob("*.png")):
                    index = int(source.stem.rsplit("_", 1)[1])
                    destination = runtime_root / f"{character_id}_{kind}_{direction}_{index:02d}.png"
                    reports[character_id].append(normalize_frame(source, destination, scale))
    return reports


def frame_block(resource_ids: list[str], name: str, speed: float, loop: bool) -> str:
    frames = ", ".join(
        '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource_id
        for resource_id in resource_ids
    )
    return (
        "{\n"
        f'"frames": [{frames}],\n'
        f'"loop": {str(loop).lower()},\n'
        f'"name": &"{name}",\n'
        f'"speed": {speed}\n'
        "}"
    )


def write_spriteframes(character_id: str) -> Path:
    runtime_root = ALLY_DIR / character_id / "runtime"
    spriteframes_path = ALLY_DIR / f"ally_{character_id}_spriteframes.tres"
    resource_ids = {}
    ext_resources = []
    next_id = 1
    for kind in ("move", "attack"):
        for direction in ("left", "right"):
            key = f"{kind}_{direction}"
            resource_ids[key] = []
            for frame in sorted(runtime_root.glob(f"{character_id}_{kind}_{direction}_*.png")):
                resource_id = f"{next_id}_scrum1016"
                next_id += 1
                resource_ids[key].append(resource_id)
                ext_resources.append(
                    f'[ext_resource type="Texture2D" path="res://{frame.relative_to(ROOT).as_posix()}" id="{resource_id}"]'
                )
    animations = [
        frame_block(resource_ids["attack_left"], "attack", ATTACK_SPEED, False),
        frame_block(resource_ids["attack_left"], "attack_left", ATTACK_SPEED, False),
        frame_block(resource_ids["attack_right"], "attack_right", ATTACK_SPEED, False),
        frame_block(resource_ids["move_left"], "move", MOVE_SPEED, True),
        frame_block(resource_ids["move_left"], "move_left", MOVE_SPEED, True),
        frame_block(resource_ids["move_right"], "move_right", MOVE_SPEED, True),
    ]
    spriteframes_path.write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_resources)
        + "\n\n[resource]\nanimations = [\n"
        + ",\n".join(animations)
        + "\n]\n",
        encoding="utf-8",
    )
    return spriteframes_path


def build_contact_sheet(characters: list[dict]) -> Path:
    frame_preview = 72
    tile_w, tile_h = frame_preview * 6 + 20, 118
    margin, label_h = 18, 28
    sheet = Image.new("RGBA", (margin * 2 + tile_w * 4, margin * 2 + tile_h * len(characters)), (12, 18, 29, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    columns = ["move_left", "move_right", "attack_left", "attack_right"]
    for row, character in enumerate(characters):
        character_id = character["id"]
        for column, animation in enumerate(columns):
            kind, direction = animation.split("_", 1)
            x = margin + column * tile_w
            y = margin + row * tile_h
            draw.rectangle((x + 2, y + 2, x + tile_w - 3, y + tile_h - 3), outline=(63, 111, 145, 255), width=1)
            draw.text((x + 8, y + 7), f"{character_id} — {animation} — 6f", fill=(210, 235, 255, 255), font=font)
            for frame_index in range(6):
                frame = ALLY_DIR / character_id / "runtime" / f"{character_id}_{kind}_{direction}_{frame_index:02d}.png"
                image = Image.open(frame).convert("RGBA")
                preview = image.resize((frame_preview, frame_preview), Image.Resampling.NEAREST)
                sheet.alpha_composite(preview, (x + 10 + frame_index * frame_preview, y + label_h))
                draw.text((x + 14 + frame_index * frame_preview, y + label_h + frame_preview + 1), str(frame_index), fill=(126, 170, 200, 255), font=font)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    output = PREVIEW_DIR / "druid_summons_ghost_animation_pack_contact.png"
    sheet.save(output)
    return output


def main() -> int:
    requests = read_json(REFERENCE_DIR / "pixellab_requests.json")
    job_evidence = read_json(REFERENCE_DIR / "pixellab_job_ids.json")
    characters = requests["characters"]
    validate_job_evidence(job_evidence, characters)

    provenance = {}
    with tempfile.TemporaryDirectory(prefix="scrum1016_pixellab_") as tmp:
        tmp_path = Path(tmp)
        for character in characters:
            character_id = character["id"]
            character_uuid = character["pixellab_character_id"]
            zip_path = tmp_path / f"{character_id}.zip"
            extract_dir = tmp_path / character_id
            download_pack(character_uuid, zip_path)
            with zipfile.ZipFile(zip_path) as archive:
                archive.extractall(extract_dir)
            metadata = read_json(extract_dir / "metadata.json")
            state = selected_state(metadata, character_uuid)
            destination = ALLY_DIR / character_id
            selection = copy_selected_sources(
                extract_dir,
                character,
                state,
                destination,
                job_evidence["characters"][character_id],
            )
            provenance[character_id] = {
                "pixellab_character_id": character_uuid,
                "pixellab_name": state.get("character", {}).get("name"),
                "role": character["role"],
                "action_description": character["action"]["action_description"],
                "pixellab_export_date": metadata.get("export_date"),
                "pixellab_export_version": metadata.get("export_version"),
                "pixellab_job_ids": job_evidence["characters"][character_id],
                "runtime_animations": ["move_left", "move_right", "attack_left", "attack_right"],
                **selection,
            }

    source_frames = collect_source_frames(characters)
    if len(source_frames) != 120:
        raise RuntimeError(f"Expected exactly 120 west/east source frames, got {len(source_frames)}")
    scale, source_bboxes = global_scale_for(source_frames)
    normalization = normalize_all(characters, scale)
    spriteframes = [write_spriteframes(character["id"]) for character in characters]
    contact = build_contact_sheet(characters)
    manifest = {
        "jira": "SCRUM-1016",
        "source_issue": "SCRUM-1015",
        "generated_at": utc_now(),
        "generator": "PixelLab MCP animate_character + character download",
        "policy": {
            "exact_character_ids_only": True,
            "repo_runtime_directions": ["west/left", "east/right"],
            "north_south_diagonal_repo_assets": False,
            "openai_manual_legacy_fallback": False,
            "pro_mode_used": False,
        },
        "canvas": [CELL_SIZE, CELL_SIZE],
        "pivot": {"center_x": CELL_SIZE // 2, "baseline_y": BASELINE_Y},
        "normalization": {
            "single_global_scale": scale,
            "max_global_scale": MAX_GLOBAL_SCALE,
            "max_visible_width": MAX_VISIBLE_WIDTH,
            "max_visible_height": MAX_VISIBLE_HEIGHT,
            "alpha_threshold": ALPHA_THRESHOLD,
            "source_bboxes": source_bboxes,
            "frames": normalization,
        },
        "characters": provenance,
        "spriteframes": [path.relative_to(ROOT).as_posix() for path in spriteframes],
        "contact_sheet": contact.relative_to(ROOT).as_posix(),
        "frame_counts": {
            "move_left": 6,
            "move_right": 6,
            "attack_left": 6,
            "attack_right": 6,
        },
        "loop_flags": {"move_left": True, "move_right": True, "attack_left": False, "attack_right": False},
    }
    write_json(REFERENCE_DIR / "manifest.json", manifest)
    all_frame_reports = [frame for frames in normalization.values() for frame in frames]
    minimum_gutter = min(min(frame["gutters"]) for frame in all_frame_reports)
    qa_report = {
        "jira": "SCRUM-1016",
        "status": "AUTOMATED_PASS_READY_FOR_VISUAL_REVIEW",
        "source_png_count": len(source_frames),
        "runtime_png_count": len(all_frame_reports),
        "source_canvas": [180, 180],
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "minimum_runtime_gutter_px": minimum_gutter,
        "common_center_x": CELL_SIZE // 2,
        "common_baseline_y": BASELINE_Y,
        "baseline_delta_px": 0,
        "rows_per_character": ["move_left", "move_right", "attack_left", "attack_right"],
        "frames_per_row": 6,
        "movement_loop": True,
        "attack_loop": False,
        "extra_runtime_directions": [],
        "horizontal_flip_required": False,
        "alpha_threshold": ALPHA_THRESHOLD,
        "visual_review": "PENDING Animator implementation self-check of the generated contact sheet; independent QA follows after handoff",
        "contact_sheet": contact.relative_to(ROOT).as_posix(),
    }
    write_json(REFERENCE_DIR / "qa_report.json", qa_report)
    print(json.dumps({
        "status": "PASS",
        "source_frames": len(source_frames),
        "runtime_frames": sum(len(frames) for frames in normalization.values()),
        "global_scale": scale,
        "minimum_gutter": minimum_gutter,
        "spriteframes": len(spriteframes),
        "contact_sheet": contact.relative_to(ROOT).as_posix(),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
