#!/usr/bin/env python3
"""Build the FAN-2622 plague_prophet 8-direction PixelLab pack.

Parses a saved plain-text `get_character()` dump from the PixelLab MCP
server, downloads every rotation/animation frame it references, normalizes
them into the fleet-standard 512x512 transparent runtime canvas (245px
visible height, 32px bottom padding), and writes the FAN-2519
explicit-eight-direction SpriteFrames resource plus a manifest/alpha report.

Same approach as tools/build_fan2628_mini_rot_hound_pack.py (FAN-2628).
"""
from __future__ import annotations

import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ID = "plague_prophet"
PIXELLAB_CHARACTER_ID = "c5559de2-2347-41a2-89a2-f030ff286019"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
USER_AGENT = "FantasyDisk-FAN2622/1.0"

SOURCE_DIR = ROOT / "assets/sprites/elites/pixellab/plague_prophet"
RUNTIME_DIR = ROOT / "assets/sprites/elites/full_frame/plague_prophet"
SPRITEFRAMES_PATH = ROOT / "assets/sprites/elites/full_frame/plague_prophet_spriteframes.tres"

# FAN-2519 direction suffix contract (clockwise from east), matching
# scripts/full_frame_animation_registry.gd::DIRECTION_SUFFIXES.
DIRECTIONS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

# scripts/enemy.gd::_play_elite_attack_phase_animation resolves the full-frame
# attack animation from "<behavior>:<attack_id>:<phase>" via
# FullFrameAnimationRegistry._state_candidates(), which keys only on
# attack_id (not phase) -- "windup" and "strike" both resolve to the same
# "skill_<attack_id>_<dir>" row. So windup (cast) and strike (shoot) frames
# are concatenated into a single one-shot skill_poison_volley clip instead of
# two separately-named states that the resolver could never tell apart.
STATE_TIMING = {
    "idle": {"loop": True, "speed": 1.0},
    "move": {"loop": True, "speed": 9.0},
    "skill_poison_volley": {"loop": False, "speed": 9.0},
    "hit": {"loop": False, "speed": 10.0},
    "death": {"loop": False, "speed": 10.0},
}
# Maps a runtime state name to the dump animation-block name(s) it draws
# frames from, in order. Most states are 1:1; skill_poison_volley merges two.
STATE_SOURCE_BLOCKS = {
    "move": ["move"],
    "skill_poison_volley": ["cast", "shoot"],
    "hit": ["hit"],
    "death": ["death"],
}
# The first five shoot frames repeat the neutral pose at the end of cast.
# Keep only the actual strike frames; their source names stay shoot_05..09 so
# a clean rebuild produces the same committed source tree.
SKIP_SOURCE_FRAMES = {("skill_poison_volley", "shoot"): 5}


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
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(response.read())
                return
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code not in (404, 429, 500, 502, 503, 504):
                raise
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"failed to download {url} after retries: {last_error}")


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def strip_disconnected_alpha_islands(image: Image.Image, alpha_threshold: int = 10) -> int:
    """Zero out every opaque connected component except the largest.

    PixelLab v3 custom animations occasionally leave stray floating pixels
    (glitch dots, faint particle noise) disconnected from the character
    silhouette. Keeping only the largest 4-connected component removes them
    without touching the actual character art. Returns the count of removed
    pixels.
    """
    from collections import deque

    alpha = image.getchannel("A")
    w, h = alpha.size
    px = alpha.load()
    visited = bytearray(w * h)
    best_comp: list[tuple[int, int]] = []

    for sy in range(h):
        for sx in range(w):
            idx = sy * w + sx
            if visited[idx] or px[sx, sy] <= alpha_threshold:
                continue
            comp = [(sx, sy)]
            visited[idx] = 1
            queue = deque([(sx, sy)])
            while queue:
                x, y = queue.popleft()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        nidx = ny * w + nx
                        if not visited[nidx] and px[nx, ny] > alpha_threshold:
                            visited[nidx] = 1
                            comp.append((nx, ny))
                            queue.append((nx, ny))
            if len(comp) > len(best_comp):
                best_comp = comp

    keep = set(best_comp)
    removed = 0
    full = image.load()
    for y in range(h):
        for x in range(w):
            if px[x, y] > alpha_threshold and (x, y) not in keep:
                full[x, y] = (0, 0, 0, 0)
                removed += 1
    return removed


def normalize_frame(source_path: Path, dest_path: Path) -> dict:
    image = Image.open(source_path).convert("RGBA")
    removed_stray_pixels = strip_disconnected_alpha_islands(image)
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
        "stray_alpha_pixels_removed": removed_stray_pixels,
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
        print("usage: build_fan2622_plague_prophet_pack.py <dump.txt>", file=sys.stderr)
        return 2
    dump_path = Path(sys.argv[1])
    rotations, animations = parse_dump(dump_path.read_text(encoding="utf-8"))

    missing_rot = [d for d in DIRECTIONS if d not in rotations]
    if missing_rot:
        raise RuntimeError(f"missing idle rotations: {missing_rot}")
    for source_blocks in STATE_SOURCE_BLOCKS.values():
        for block in source_blocks:
            missing = [d for d in DIRECTIONS if d not in animations.get(block, {})]
            if missing:
                raise RuntimeError(f"missing {block} directions: {missing}")

    alpha_report: dict[str, dict] = {}
    ext_lines: list[str] = []
    resources: dict[str, str] = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resources:
            return resources[key]
        rid = f"{next_id}_pp"
        next_id += 1
        rel = path.resolve().relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{rid}"]')
        resources[key] = rid
        return rid

    animation_blocks: list[str] = []

    # idle: single-frame rotation per direction
    for direction in DIRECTIONS:
        s = suffix(direction)
        src = SOURCE_DIR / f"plague_prophet_idle_{s}.png"
        dest = RUNTIME_DIR / f"plague_prophet_idle_{s}.png"
        download(rotations[direction], src)
        alpha_report[f"idle_{s}"] = [normalize_frame(src, dest)]
        rid = add_resource(dest)
        animation_blocks.append(frame_block([rid], STATE_TIMING["idle"]["speed"], STATE_TIMING["idle"]["loop"], f"idle_{s}"))

    # move/skill_poison_volley/hit/death: multi-frame per direction, merging
    # each state's source dump block(s) (see STATE_SOURCE_BLOCKS) in order.
    for state, source_blocks in STATE_SOURCE_BLOCKS.items():
        timing = STATE_TIMING[state]
        for direction in DIRECTIONS:
            s = suffix(direction)
            rids = []
            reports = []
            index = 0
            for block in source_blocks:
                urls = animations[block][direction]
                urls = urls[SKIP_SOURCE_FRAMES.get((state, block), 0):]
                for url in urls:
                    src = SOURCE_DIR / f"plague_prophet_{block}_{s}_{index:02d}.png"
                    dest = RUNTIME_DIR / f"plague_prophet_{state}_{s}_{index:02d}.png"
                    download(url, src)
                    reports.append(normalize_frame(src, dest))
                    rids.append(add_resource(dest))
                    index += 1
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

    (SOURCE_DIR / "alpha_bbox_report.json").write_text(
        json.dumps(alpha_report, indent=2), encoding="utf-8"
    )

    manifest = {
        "character_id": CHARACTER_ID,
        "pixellab_character_id": PIXELLAB_CHARACTER_ID,
        "generated_at": "2026-08-19",
        "source": "PixelLab MCP",
        "mode": "standard (idle rotations) + template walking-8-frames (move) + v3 custom (skill_poison_volley/hit/death)",
        "body_type": "humanoid",
        "view": "low top-down",
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "bottom_padding": BOTTOM_PADDING,
        "directions": DIRECTIONS,
        "states": {
            "idle": {"frame_count": 1, "source": "rotations"},
            "move": {"frame_count": 8, "template_animation_id": "walking-8-frames", "fps": 9.0},
            "skill_poison_volley": {
                "frame_count": 10,
                "mode": "v3",
                "action_description": "windup (raising bone staff overhead, brewing a swirling poison cloud) then strike (hurling three lobbing poison globs forward)",
                "fps": 9.0,
                "note": (
                    "windup+strike frames concatenated into one one-shot clip; "
                    "the five neutral duplicate frames leading shoot are omitted. "
                    "scripts/enemy.gd::_play_elite_attack_phase_animation resolves "
                    "the attack via FullFrameAnimationRegistry with state string "
                    "'plague_prophet:poison_volley:<phase>', and _state_candidates() "
                    "keys only on the attack_id (poison_volley), not the phase, so "
                    "windup and strike both resolve to skill_poison_volley_<dir> -- "
                    "a separate cast/shoot state pair would never be reachable."
                ),
            },
            "hit": {"frame_count": 5, "mode": "v3", "action_description": "flinching backward in pain from a hit, robe rippling, recoiling", "fps": 10.0},
            "death": {"frame_count": 7, "mode": "v3", "action_description": "collapsing and dying, robe crumpling to the ground, staff falling from hand, body slumping", "fps": 10.0},
        },
        "notes": (
            "FAN-2622: replaces the single authored horizontal view + flip with a "
            "dedicated 8-direction pack. 8 idle rotations + 8x8 move + 8x10 "
            "skill_poison_volley + 8x5 hit + 8x7 death frames, all normalized to "
            "245px visible height on a transparent 512x512 canvas, footline "
            "pinned at bottom_padding=32. Frames were passed through a "
            "connected-component cleanup (strip_disconnected_alpha_islands) to "
            "remove stray PixelLab v3 glitch pixels disconnected from the "
            "character silhouette."
        ),
    }
    (SOURCE_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"wrote {SPRITEFRAMES_PATH}")
    print(f"wrote {SOURCE_DIR / 'manifest.json'}")
    print(f"wrote {SOURCE_DIR / 'alpha_bbox_report.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
