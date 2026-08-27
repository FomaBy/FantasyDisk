#!/usr/bin/env python3
"""FAN-3325: fetch and rebuild the nine mini-elite directional packs.

PixelLab character exports are kept as source frames.  Runtime frames are
deterministically normalized to a transparent 512px canvas and assembled into
directional SpriteFrames.  ``--offline`` never calls PixelLab; it rebuilds from
the checked-in source manifests and is the reproducibility check for the pack.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
API = "https://api.pixellab.ai/mcp"
USER_AGENT = "FantasyDisk-FAN3325/1.0"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
DIRECTIONS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

PIXELLAB_IDS = {
    "mini_scavenger_reaper": "3d2c3c13-ed23-4784-add8-2e446a567a8b",
    "mini_plague_bellringer": "2b4d4ee4-513e-4aa6-a322-f7c19cd43835",
    "mini_bone_warden": "02f65048-756d-4b23-8459-b0090eb799cc",
    "mini_spark_wight": "841878ea-382d-4d83-9daf-87e8dd8bd89f",
    "mini_shadow_devourer": "ae0eaf0d-531d-4e2d-90b5-bd7ddf5b7280",
    "mini_siege_rammer": "6c8d76d0-97f8-4326-8269-bbbac2e5a634",
    "mini_swarm_sniper": "f0c3fba4-cb5e-4461-b0bf-1afd6129dc4d",
    "mini_plague_berserker": "9e63a280-524e-492b-9624-8ddbb2744c07",
    "mini_void_phantom": "9747cdae-86b2-4479-a24f-deacf09e2027",
}

# Completed PixelLab characters provide a stable fallback for a newly-created
# mini whose action group is still processing.  The mini's own eight rotations
# remain its idle/source identity; fallback rows are recorded in provenance.
FALLBACK_IDS = {
    "iron": "465c1b5d-2736-4b4d-a593-c126723b91d6",
    "night": "2a1aea5b-b457-4e04-88e1-eba9d0f2f928",
    "plague": "c5559de2-2347-41a2-89a2-f030ff286019",
    "shard": "06de6f32-fca4-43f2-a657-b011a85d7632",
}
FALLBACK_ROUTE = {
    "mini_plague_bellringer": ("plague", {"attack": "shoot", "skill_bell_toll": "cast", "skill_poison_pool": "shoot"}),
    "mini_bone_warden": ("iron", {}),
    "mini_spark_wight": ("shard", {}),
    "mini_shadow_devourer": ("night", {}),
    "mini_siege_rammer": ("iron", {}),
    "mini_swarm_sniper": ("shard", {}),
    "mini_void_phantom": ("night", {}),
    "mini_scavenger_reaper": ("night", {"skill_bleed_finish": "skill_phase_dash"}),
    "mini_plague_berserker": ("plague", {"skill_poison_volley": "skill_poison_volley"}),
}
STATES = {
    "mini_scavenger_reaper": ["move", "attack", "hit", "death", "skill_reaping_dash", "skill_bleed_finish"],
    "mini_plague_bellringer": ["move", "attack", "hit", "death", "skill_bell_toll", "skill_poison_pool"],
    "mini_bone_warden": ["move", "attack", "hit", "death", "skill_bone_guard", "skill_slam_wave"],
    "mini_spark_wight": ["move", "attack", "hit", "death", "skill_spark_fan", "skill_static_field"],
    "mini_shadow_devourer": ["move", "attack", "hit", "death", "skill_shadow_blink", "skill_devour_bite"],
    "mini_siege_rammer": ["move", "attack", "hit", "death", "skill_shield_block", "skill_slam_wave"],
    "mini_swarm_sniper": ["move", "attack", "hit", "death", "skill_shard_fan", "skill_command_pulse"],
    "mini_plague_berserker": ["move", "attack", "hit", "death", "skill_poison_volley"],
    "mini_void_phantom": ["move", "attack", "hit", "death", "skill_shadow_strike", "skill_phase_dash"],
}


def suffix(direction: str) -> str:
    return direction.replace("-", "_")


def call(tool: str, arguments: dict, bearer: str) -> str:
    payload = json.dumps({
        "jsonrpc": "2.0", "id": int(time.time() * 1000) % 1000000000,
        "method": "tools/call", "params": {"name": tool, "arguments": arguments},
    }).encode()
    request = urllib.request.Request(API, data=payload, headers={
        "Authorization": "Bearer " + bearer,
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    })
    try:
        raw = urllib.request.urlopen(request, timeout=180).read().decode()
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{tool}: {exc}") from exc
    for line in raw.splitlines():
        if line.startswith("data:"):
            raw = line[5:].strip()
            break
    response = json.loads(raw)
    if "error" in response:
        raise RuntimeError(f"{tool}: {response['error']}")
    for item in response.get("result", {}).get("content", []):
        if item.get("type") == "text":
            return str(item["text"])
    raise RuntimeError(f"{tool}: missing text result")


def parse_character_dump(text: str) -> tuple[dict[str, str], dict[str, dict[str, list[str]]]]:
    rotations: dict[str, str] = {}
    animations: dict[str, dict[str, list[str]]] = {}
    in_rotations = False
    current: str | None = None
    header = re.compile(r"^  ([a-z0-9_]+) — .* \[group: [0-9a-f-]+\]$")
    direction = re.compile(r"^    ([a-z-]+): (.+)$")
    for line in text.splitlines():
        if line == "rotations:":
            in_rotations = True
            current = None
            continue
        if in_rotations:
            match = re.match(r"^  ([a-z-]+): (\S+)$", line)
            if match:
                rotations[match.group(1)] = match.group(2)
                continue
            if line and not line.startswith("  "):
                in_rotations = False
        match = header.match(line)
        if match:
            current = match.group(1)
            animations.setdefault(current, {})
            continue
        if current is not None:
            match = direction.match(line)
            if match:
                animations[current][match.group(1)] = [u.strip() for u in match.group(2).split(", ")]
    return rotations, animations


def download(url: str, path: Path) -> None:
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        path.write_bytes(response.read())


def frame_hash(path: Path) -> tuple[str, str]:
    raw = path.read_bytes()
    with Image.open(path) as image:
        pixels = image.convert("RGBA").tobytes()
    return hashlib.sha256(raw).hexdigest(), hashlib.sha256(pixels).hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def normalize(path: Path, output: Path, scale: float) -> dict:
    source_encoded, source_pixels = frame_hash(path)
    with Image.open(path) as loaded:
        image = loaded.convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"{path} has no visible alpha")
    visible = image.crop(bbox)
    size = (max(1, round(visible.width * scale)), max(1, round(visible.height * scale)))
    resized = visible.resize(size, Image.Resampling.NEAREST)
    x = round((CELL_SIZE - size[0]) / 2)
    y = CELL_SIZE - BOTTOM_PADDING - size[1]
    if x < 0 or y < 0 or x + size[0] > CELL_SIZE or y + size[1] > CELL_SIZE:
        raise RuntimeError(f"{path} does not fit the {CELL_SIZE}px runtime canvas")
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (x, y))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    runtime_bbox = alpha_bbox(canvas)
    encoded, pixels = frame_hash(output)
    return {
        "source": path.name, "runtime": output.name,
        "source_size": list(image.size), "source_alpha_bbox": list(bbox),
        "runtime_alpha_bbox": list(runtime_bbox) if runtime_bbox else None,
        "source_encoded_sha256": source_encoded,
        "source_pixel_sha256": source_pixels,
        "runtime_encoded_sha256": encoded, "runtime_pixel_sha256": pixels,
    }


def write_spriteframes(actor: str, rows: dict[str, list[Path]], destination: Path) -> None:
    ext: list[str] = []
    resources: dict[str, str] = {}
    next_id = 1

    def resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key not in resources:
            rid = f"{next_id}_{actor[:3]}"
            next_id += 1
            rel = path.relative_to(ROOT).as_posix()
            ext.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{rid}"]')
            resources[key] = rid
        return resources[key]

    def block(name: str, paths: list[Path], loop: bool, speed: float) -> str:
        frames = ",\n".join(
            '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource(path)
            for path in paths
        )
        return '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            frames, "true" if loop else "false", name, speed
        )

    blocks: list[str] = []
    for state, paths in rows.items():
        blocks.append(block(state, paths, state.startswith("idle_") or state.startswith("move_") or state.startswith("walk_"), 9.0 if state.startswith(("move_", "walk_")) else 12.0))
    text = '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(ext) + '\n\n[resource]\nanimations = [\n' + ",\n".join(blocks) + "\n]\n"
    destination.write_text(text, encoding="utf-8")


def character_texts(bearer: str) -> dict[str, tuple[dict[str, str], dict[str, dict[str, list[str]]]]]:
    result = {}
    for actor, character_id in {**PIXELLAB_IDS, **FALLBACK_IDS}.items():
        result[actor] = parse_character_dump(call("get_character", {"character_id": character_id, "include_preview": False}, bearer))
    return result


def build_actor(actor: str, texts: dict[str, tuple[dict[str, str], dict[str, dict[str, list[str]]]]], fetch: bool) -> dict:
    source_dir = ROOT / "assets/sprites/elites/pixellab" / actor
    runtime_dir = ROOT / "assets/sprites/elites/full_frame" / actor
    spriteframes = ROOT / "assets/sprites/elites/full_frame" / f"{actor}_spriteframes.tres"
    source_dir.mkdir(parents=True, exist_ok=True)
    runtime_dir.mkdir(parents=True, exist_ok=True)
    own_id = PIXELLAB_IDS[actor]
    own_rotations, own_animations = texts[actor]
    fallback_name, skill_map = FALLBACK_ROUTE[actor]
    fallback_id = FALLBACK_IDS[fallback_name]
    fallback_rotations, fallback_animations = texts[fallback_name]
    manifest_path = source_dir / "manifest.json"
    old = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    entries: list[dict] = []
    state_provenance: dict[str, dict] = {}
    state_sources: dict[str, tuple[dict[str, str], dict[str, dict[str, list[str]]], str, str]] = {}
    for state in STATES[actor]:
        source_rotations, source_animations, source_id = own_rotations, own_animations, own_id
        candidates = [state]
        if state == "attack":
            candidates += ["attack_primary", "shoot", "cast"]
        if state.startswith("skill_"):
            candidates += [skill_map.get(state, ""), "cast", "shoot", "attack", "attack_primary"]
        source_state = next((candidate for candidate in candidates if candidate and candidate in source_animations and all(direction in source_animations[candidate] for direction in DIRECTIONS)), None)
        if source_state is None:
            source_rotations, source_animations, source_id = fallback_rotations, fallback_animations, fallback_id
            candidates = [skill_map.get(state, ""), state]
            if state == "attack":
                candidates += ["attack_primary", "shoot", "cast"]
            if state.startswith("skill_"):
                candidates += ["cast", "shoot", "attack", "attack_primary"]
            source_state = next((candidate for candidate in candidates if candidate and candidate in source_animations and all(direction in source_animations[candidate] for direction in DIRECTIONS)), None)
        if source_state is None:
            raise RuntimeError(f"{actor}: no PixelLab source state for {state}")
        state_sources[state] = (source_rotations, source_animations, source_id, source_state)
        state_provenance[state] = {"pixel_lab_character_id": source_id, "source_state": source_state, "fallback": source_id != own_id}

    source_files: list[Path] = []
    source_specs: list[tuple[str, str, int, str]] = []
    idle_rotations, idle_id = own_rotations, own_id
    if any(direction not in idle_rotations for direction in DIRECTIONS):
        idle_rotations, idle_id = fallback_rotations, fallback_id
    state_provenance["idle"] = {"pixel_lab_character_id": idle_id, "source_state": "rotations", "fallback": idle_id != own_id}
    for direction in DIRECTIONS:
        name = f"{actor}_idle_{suffix(direction)}_00.png"
        path = source_dir / name
        if fetch:
            download(idle_rotations[direction], path)
        elif not path.exists():
            raise RuntimeError(f"offline rebuild missing source {path}")
        source_files.append(path)
        source_specs.append(("idle", direction, 0, idle_id))
    for state, (rotations, animations, source_id, source_state) in state_sources.items():
        for direction in DIRECTIONS:
            urls = animations[source_state][direction]
            for index, url in enumerate(urls):
                name = f"{actor}_{state}_{suffix(direction)}_{index:02d}.png"
                path = source_dir / name
                if fetch:
                    download(url, path)
                elif not path.exists():
                    raise RuntimeError(f"offline rebuild missing source {path}")
                source_files.append(path)
                source_specs.append((state, direction, index, source_id))

    max_visible_height = 1
    max_width = 1
    for path in source_files:
        with Image.open(path) as loaded:
            bbox = alpha_bbox(loaded.convert("RGBA"))
        if bbox is None:
            raise RuntimeError(f"{path} has no visible alpha")
        max_visible_height = max(max_visible_height, bbox[3] - bbox[1])
        max_width = max(max_width, bbox[2] - bbox[0])
    scale = min(TARGET_VISIBLE_HEIGHT / max_visible_height, CELL_SIZE / max_width)
    rows: dict[str, list[Path]] = {}
    alpha: dict[str, list[dict]] = {}
    for (state, direction, index, source_id), source_path in zip(source_specs, source_files):
        row = f"{state}_{suffix(direction)}"
        runtime_path = runtime_dir / f"{actor}_{row}_{index:02d}.png"
        alpha.setdefault(row, []).append(normalize(source_path, runtime_path, scale))
        rows.setdefault(row, []).append(runtime_path)
    for direction in DIRECTIONS:
        s = suffix(direction)
        rows[f"idle_{s}"] = rows[f"idle_{s}"][:1]
        rows[f"walk_{s}"] = rows[f"move_{s}"]
    for direction in DIRECTIONS:
        s = suffix(direction)
        for alias in ["attack_primary", "attack"]:
            rows[f"{alias}_{s}"] = rows[f"attack_{s}"]
        for state in STATES[actor]:
            if state.startswith("skill_"):
                rows[f"attack_{state[6:]}_{s}"] = rows[f"{state}_{s}"]
    # Generic aliases keep the historical state API intact while directional
    # rows are now the canonical runtime route.
    for state in ["idle", "move", "walk", "attack", "attack_primary", "hit", "death"] + [s for s in STATES[actor] if s.startswith("skill_")]:
        rows[state] = rows[f"{state}_south"]
    write_spriteframes(actor, rows, spriteframes)
    manifest = {
        "schema": "FAN-3325-mini-elite-pack-v1",
        "actor_id": actor,
        "pixel_lab_character_id": own_id,
        "source": "PixelLab MCP",
        "directions": DIRECTIONS,
        "states": {state: {"frame_count": len(rows[f"{state}_south"]), "fps": 1.0 if state == "idle" else (9.0 if state == "move" else 12.0), **state_provenance[state]} for state in ["idle"] + STATES[actor]},
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "scale": scale,
        "alpha_bbox_report": alpha,
        "rebuild": "python3 tools/build_fan3325_mini_elite_packs.py --offline",
        "auth": "PIXELLAB_BEARER_TOKEN env (never committed)",
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return {"actor": actor, "source_id": own_id, "scale": scale, "states": {state: len(rows[f"{state}_south"]) for state in STATES[actor]}, "fallback_states": [state for state, info in state_provenance.items() if info["fallback"]]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true", help="rebuild from checked-in source files without PixelLab")
    parser.add_argument("--actor", action="append", choices=sorted(STATES), help="build only this actor (repeatable)")
    args = parser.parse_args()
    actors = args.actor or list(STATES)
    bearer = os.environ.get("PIXELLAB_BEARER_TOKEN")
    if not args.offline and not bearer:
        raise SystemExit("PIXELLAB_BEARER_TOKEN is not set")
    texts = character_texts(bearer) if not args.offline else {}
    reports = []
    for actor in actors:
        if args.offline:
            # Offline manifests carry the complete source file set; parsing the
            # source manifest is not needed to rebuild the deterministic rows.
            source_dir = ROOT / "assets/sprites/elites/pixellab" / actor
            if not (source_dir / "manifest.json").exists():
                raise SystemExit(f"offline source manifest missing: {source_dir / 'manifest.json'}")
            # Use the manifest's recorded origin states only for the report;
            # source files themselves are the immutable rebuild input.
            own = (PIXELLAB_IDS[actor], {}, "")
            fallback_name = FALLBACK_ROUTE[actor][0]
            texts[actor] = ({d: "" for d in DIRECTIONS}, {})
            texts[fallback_name] = ({d: "" for d in DIRECTIONS}, {})
            # The offline path is handled by the manifest-aware fast rebuild.
            manifest = json.loads((source_dir / "manifest.json").read_text(encoding="utf-8"))
            build_from_manifest(actor, manifest)
            reports.append({"actor": actor, "offline": True})
        else:
            reports.append(build_actor(actor, texts, True))
    print(json.dumps(reports, indent=2, ensure_ascii=False))
    return 0


def build_from_manifest(actor: str, manifest: dict) -> None:
    source_dir = ROOT / "assets/sprites/elites/pixellab" / actor
    runtime_dir = ROOT / "assets/sprites/elites/full_frame" / actor
    rows: dict[str, list[Path]] = {}
    all_sources: list[Path] = []
    for state in ["idle"] + STATES[actor]:
        frame_count = int(manifest.get("states", {}).get(state, {}).get("frame_count", 0))
        for direction in DIRECTIONS:
            for index in range(frame_count):
                all_sources.append(source_dir / f"{actor}_{state}_{suffix(direction)}_{index:02d}.png")
    if not all_sources:
        raise SystemExit(f"offline source frames missing: {source_dir}")
    max_height = 1
    max_width = 1
    for path in all_sources:
        with Image.open(path) as loaded:
            bbox = alpha_bbox(loaded.convert("RGBA"))
        if bbox is None:
            raise SystemExit(f"{path} has no visible alpha")
        max_height = max(max_height, bbox[3] - bbox[1])
        max_width = max(max_width, bbox[2] - bbox[0])
    scale = min(TARGET_VISIBLE_HEIGHT / max_height, CELL_SIZE / max_width)
    for source in all_sources:
        match = re.match(rf"{re.escape(actor)}_(.+)_(\d{{2}})\.png$", source.name)
        if not match or not source.exists():
            raise SystemExit(f"offline source frame missing: {source}")
        row, index = match.groups()
        dest = runtime_dir / f"{actor}_{row}_{index}.png"
        normalize(source, dest, scale)
        rows.setdefault(row, []).append(dest)
    for direction in DIRECTIONS:
        s = suffix(direction)
        rows[f"idle_{s}"] = rows[f"idle_{s}"][:1]
        rows[f"walk_{s}"] = rows[f"move_{s}"]
        rows[f"attack_primary_{s}"] = rows[f"attack_{s}"]
        for state in STATES[actor]:
            if state.startswith("skill_"):
                rows[f"attack_{state[6:]}_{s}"] = rows[f"{state}_{s}"]
    for state in ["idle", "move", "walk", "attack", "attack_primary", "hit", "death"] + [s for s in STATES[actor] if s.startswith("skill_")]:
        rows[state] = rows[f"{state}_south"]
    write_spriteframes(actor, rows, ROOT / "assets/sprites/elites/full_frame" / f"{actor}_spriteframes.tres")
    # Do not rewrite the source manifest during an offline rebuild.  The
    # checked-in source manifest is provenance, while the scale is derived
    # from those immutable frames and is therefore intentionally not a second
    # mutable input.


if __name__ == "__main__":
    raise SystemExit(main())
