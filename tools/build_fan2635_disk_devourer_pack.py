#!/usr/bin/env python3
"""FAN-2635: blocking builder for the disk_devourer 8-direction PixelLab pack.

Polls a PixelLab character (already created via create_character + queued
animate_character jobs) synchronously inside this single process until every
requested animation group is terminal or a hard wall-clock ceiling is hit,
downloads the finished frames, normalizes them onto the disk_devourer runtime
canvas (matches the legacy full_frame/disk_devourer convention: 512x512
canvas, 48px bottom padding, alpha-bbox scaled), and writes the FAN-2519
explicit-eight-direction SpriteFrames resource plus a provenance manifest.

Auth: env PIXELLAB_BEARER_TOKEN, or AUTH_HEADER from ~/.codex/config.toml as a
fallback (never printed).
"""
from __future__ import annotations

import argparse
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
CHARACTER_ID = "disk_devourer"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 255
BOTTOM_PADDING = 48
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)

SOURCE_DIR = ROOT / "assets/sprites/bosses/disk_devourer_8dir/pixellab_source"
RUNTIME_DIR = ROOT / "assets/sprites/bosses/disk_devourer_8dir/runtime"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/bosses/full_frame/disk_devourer_spriteframes.tres"

# FAN-2519 direction suffix contract (clockwise from east), matching
# scripts/full_frame_animation_registry.gd::DIRECTION_SUFFIXES.
DIRECTIONS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

STATE_TIMING = {
    "idle": {"loop": True, "speed": 1.0},
    "move": {"loop": True, "speed": 9.0},
    "attack": {"loop": False, "speed": 12.0},
    "hit": {"loop": False, "speed": 10.0},
    "death": {"loop": False, "speed": 10.0},
    "skill_vampiric_bite": {"loop": False, "speed": 10.0},
    "skill_rift_zone": {"loop": False, "speed": 10.0},
}


class ApiError(Exception):
    pass


def read_auth_header() -> str:
    token = os.environ.get("PIXELLAB_BEARER_TOKEN", "").strip()
    if token:
        return "Bearer " + token
    auth = os.environ.get("AUTH_HEADER", "").strip()
    if auth:
        return auth
    config_path = Path.home() / ".codex" / "config.toml"
    if config_path.exists():
        text = config_path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r'AUTH_HEADER\s*=\s*"([^"]+)"', text)
        if match:
            return match.group(1).strip()
    raise SystemExit("no PixelLab auth found (PIXELLAB_BEARER_TOKEN / AUTH_HEADER / config.toml)")


def call(tool_name: str, arguments: dict, auth_header: str, call_id: int) -> dict:
    payload = json.dumps(
        {"jsonrpc": "2.0", "id": call_id, "method": "tools/call",
         "params": {"name": tool_name, "arguments": arguments}}
    ).encode()
    req = urllib.request.Request(
        API, data=payload,
        headers={
            "Authorization": auth_header,
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )
    try:
        body = urllib.request.urlopen(req, timeout=180).read().decode()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
    except urllib.error.URLError as exc:
        raise ApiError(f"{tool_name}: network error: {exc}")
    for line in body.splitlines():
        if line.startswith("data:"):
            body = line[5:].strip()
            break
    try:
        result = json.loads(body)
    except ValueError:
        raise ApiError(f"{tool_name}: non-JSON response: {body[:300]}")
    if "error" in result:
        raise ApiError(f"{tool_name}: JSON-RPC error: {result['error']}")
    content = result.get("result", {}).get("content", [])
    for item in content:
        if item.get("type") == "text":
            return {"_raw": item["text"]}
    return result.get("result", {})


def parse_dump(text: str):
    rotations: dict[str, str] = {}
    rot_block = re.search(r"^rotations:\n((?:  .+\n)+)", text, re.MULTILINE)
    if rot_block:
        for line in rot_block.group(1).splitlines():
            m = re.match(r"\s+([a-z-]+): (\S+)", line)
            if m:
                rotations[m.group(1)] = m.group(2)

    animations: dict[str, dict[str, list[str]]] = {}
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

    pending = []
    for line in text.splitlines():
        m = re.match(r"^  (\S.+?): (\d+)% ~(\d+)s$", line.strip() and "  " + line.strip() or line)
        if m:
            pending.append(line.strip())
    return rotations, animations, pending


def wait_for_states(character_id: str, states: list[str], auth_header: str,
                     timeout_s: float, interval_s: float, log=print):
    deadline = time.time() + timeout_s
    call_id = 1000
    while True:
        info = call("get_character", {"character_id": character_id, "include_preview": False},
                     auth_header, call_id)
        call_id += 1
        text = info.get("_raw", "")
        rotations, animations, pending = parse_dump(text)
        missing = [s for s in states if s != "idle" and
                   len([d for d in DIRECTIONS if d in animations.get(s, {})]) < len(DIRECTIONS)]
        log(f"t={int(time.time() - (deadline - timeout_s))}s missing={missing} pending_jobs={len(pending)}")
        if not missing:
            return rotations, animations
        if time.time() >= deadline:
            return rotations, animations
        time.sleep(interval_s)


def download(url: str, dest: Path) -> None:
    if dest.exists():
        return
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(response.read())
                return
        except urllib.error.HTTPError as exc:
            last_error = exc
            time.sleep(2.0)
    raise RuntimeError(f"download {url} failed after retries: {last_error}")


def suffix(direction: str) -> str:
    return direction.replace("-", "_")


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
    return {"source": source_path.name, "runtime": dest_path.name, "scale": scale}


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
    parser = argparse.ArgumentParser()
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--states", nargs="+", default=list(STATE_TIMING.keys()))
    parser.add_argument("--timeout", type=float, default=600.0)
    parser.add_argument("--poll-interval", type=float, default=20.0)
    args = parser.parse_args()

    auth_header = read_auth_header()

    rotations, animations = wait_for_states(
        args.character_id, args.states, auth_header, args.timeout, args.poll_interval
    )

    missing_rot = [d for d in DIRECTIONS if d not in rotations]
    if missing_rot:
        print(f"ERROR: missing idle rotations: {missing_rot}", file=sys.stderr)
        return 3

    alpha_report: dict[str, dict] = {}
    ext_lines: list[str] = []
    resources: dict[str, str] = {}
    next_id = 1
    incomplete: dict[str, list[str]] = {}

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resources:
            return resources[key]
        rid = f"{next_id}_dd"
        next_id += 1
        rel = path.resolve().relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{rid}"]')
        resources[key] = rid
        return rid

    animation_blocks: list[str] = []

    if "idle" in args.states:
        for direction in DIRECTIONS:
            s = suffix(direction)
            src = SOURCE_DIR / "idle" / f"disk_devourer_idle_{s}.png"
            dest = RUNTIME_DIR / f"disk_devourer_idle_{s}.png"
            download(rotations[direction], src)
            alpha_report[f"idle_{s}"] = [normalize_frame(src, dest)]
            rid = add_resource(dest)
            animation_blocks.append(frame_block([rid], STATE_TIMING["idle"]["speed"], STATE_TIMING["idle"]["loop"], f"idle_{s}"))

    for state in args.states:
        if state == "idle":
            continue
        timing = STATE_TIMING[state]
        for direction in DIRECTIONS:
            s = suffix(direction)
            urls = animations.get(state, {}).get(direction)
            if not urls:
                incomplete.setdefault(state, []).append(direction)
                continue
            rids = []
            reports = []
            for index, url in enumerate(urls):
                src = SOURCE_DIR / state / f"disk_devourer_{state}_{s}_{index:02d}.png"
                dest = RUNTIME_DIR / f"disk_devourer_{state}_{s}_{index:02d}.png"
                download(url, src)
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

    (SOURCE_DIR / "alpha_bbox_report.json").write_text(json.dumps(alpha_report, indent=2), encoding="utf-8")

    manifest = {
        "character_id": CHARACTER_ID,
        "pixel_lab_character_id": args.character_id,
        "source": "PixelLab MCP (create_character v3 + animate_character v3 custom)",
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "directions": DIRECTIONS,
        "states_requested": args.states,
        "incomplete": incomplete,
        "auth": "PIXELLAB_BEARER_TOKEN / AUTH_HEADER (never committed)",
    }
    (SOURCE_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"wrote {SPRITEFRAMES_PATH}")
    print(f"wrote {SOURCE_DIR / 'manifest.json'}")
    if incomplete:
        print(f"INCOMPLETE: {json.dumps(incomplete)}", file=sys.stderr)
        return 5
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
