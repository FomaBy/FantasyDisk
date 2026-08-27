#!/usr/bin/env python3
"""Focused offline integrity check for FAN-3325's nine mini-elite packs."""
from __future__ import annotations

import json
import hashlib
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ELITES = ROOT / "assets" / "sprites" / "elites"
DIRECTIONS = ["east", "south_east", "south", "south_west", "west",
              "north_west", "north", "north_east"]
ACTORS = {
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
ANIMATION_RE = re.compile(
    r'\{\s*"frames":\s*\[(?P<frames>.*?)\],\s*"loop":\s*(?P<loop>true|false),\s*'
    r'"name":\s*&"(?P<name>[^"]+)"', re.S)
FRAME_RE = re.compile(r'"texture":\s*ExtResource\("[^"]+"\)')


def fail(message: str) -> None:
    raise AssertionError(message)


def animations(path: Path) -> dict[str, tuple[int, bool]]:
    text = path.read_text(encoding="utf-8")
    result = {}
    for match in ANIMATION_RE.finditer(text):
        name = match.group("name")
        if name in result:
            fail(f"{path.name}: duplicate animation {name}")
        result[name] = (len(FRAME_RE.findall(match.group("frames"))), match.group("loop") == "true")
    return result


def check_actor(actor: str, states: list[str], registry: str, roster: dict) -> int:
    source_dir = ELITES / "pixellab" / actor
    runtime_dir = ELITES / "full_frame" / actor
    spriteframes_path = ELITES / "full_frame" / f"{actor}_spriteframes.tres"
    manifest_path = source_dir / "manifest.json"
    for path in (source_dir, runtime_dir, spriteframes_path, manifest_path):
        if not path.exists():
            fail(f"{actor}: missing {path.relative_to(ROOT)}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != "FAN-3325-mini-elite-pack-v1":
        fail(f"{actor}: wrong source manifest schema")
    if manifest.get("actor_id") != actor or manifest.get("source") != "PixelLab MCP":
        fail(f"{actor}: source identity/provenance is incomplete")
    if manifest.get("directions") != [d.replace("_", "-") for d in DIRECTIONS]:
        fail(f"{actor}: source manifest directions are not the eight canonical directions")
    source_states = manifest.get("states", {})
    for state in ["idle"] + states:
        entry = source_states.get(state)
        if not entry or int(entry.get("frame_count", 0)) < 1:
            fail(f"{actor}: missing source provenance for {state}")
        if not entry.get("pixel_lab_character_id") or not entry.get("source_state"):
            fail(f"{actor}: incomplete PixelLab provenance for {state}")
    alpha_report = manifest.get("alpha_bbox_report", {})
    if not alpha_report:
        fail(f"{actor}: alpha/frame hash report is missing")

    source_pngs = sorted(source_dir.glob(f"{actor}_*.png"))
    runtime_pngs = sorted(runtime_dir.glob(f"{actor}_*.png"))
    if len(source_pngs) < 8 or len(runtime_pngs) < 8:
        fail(f"{actor}: source/runtime frame set is unexpectedly small")
    for path in source_pngs:
        with Image.open(path) as image:
            if image.mode != "RGBA":
                fail(f"{path.name}: source is not RGBA")
            if image.getchannel("A").getbbox() is None:
                fail(f"{path.name}: source is fully transparent")
    for path in runtime_pngs:
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.size != (512, 512):
                fail(f"{path.name}: runtime frame is not 512x512 RGBA")
            bbox = image.getchannel("A").getbbox()
            if bbox is None:
                fail(f"{path.name}: runtime frame is fully transparent")
            if bbox[3] != 512 - 32:
                fail(f"{path.name}: runtime footline drifted to y={bbox[3]} instead of y=480")
    for row, reports in alpha_report.items():
        for report in reports:
            source = source_dir / report["source"]
            runtime = runtime_dir / report["runtime"]
            if not source.exists() or not runtime.exists():
                fail(f"{actor}: alpha report references a missing frame in {row}")
            source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            runtime_hash = hashlib.sha256(runtime.read_bytes()).hexdigest()
            if source_hash != report.get("source_encoded_sha256"):
                fail(f"{actor}: source hash mismatch in {row}/{source.name}")
            if runtime_hash != report.get("runtime_encoded_sha256"):
                fail(f"{actor}: runtime hash mismatch in {row}/{runtime.name}")

    parsed = animations(spriteframes_path)
    required = ["idle", "move", "walk", "attack", "attack_primary", "hit", "death"] + states[4:]
    for base in required:
        counts = []
        for direction in DIRECTIONS:
            name = f"{base}_{direction}"
            if name not in parsed:
                fail(f"{actor}: missing directional row {name}")
            count, loop = parsed[name]
            if count < 1:
                fail(f"{actor}: empty directional row {name}")
            if base in ("idle", "move", "walk") and not loop:
                fail(f"{actor}: {name} must loop")
            if base not in ("idle", "move", "walk") and loop:
                fail(f"{actor}: {name} must be one-shot")
            counts.append(count)
        if len(set(counts)) != 1:
            fail(f"{actor}: {base} frame counts differ across directions: {counts}")

    config = f'"{actor}": {{'
    start = registry.find(config)
    if start < 0:
        fail(f"{actor}: missing registry entry")
    end = registry.find("\n\t\t},", start)
    if end < 0 or '"explicit_eight_directions": true' not in registry[start:end]:
        fail(f"{actor}: registry does not enforce explicit eight-direction playback")
    roster_entry = next((entry for entry in roster if entry.get("id") == actor), None)
    if roster_entry is None or roster_entry.get("directional") is not True:
        fail(f"{actor}: roster manifest is not marked directional")
    if roster_entry.get("fallback_of"):
        fail(f"{actor}: roster still points at a fallback pack")
    return sum(count for count, _ in parsed.values())


def main() -> int:
    registry = (ROOT / "scripts" / "full_frame_animation_registry.gd").read_text(encoding="utf-8")
    roster = json.loads((ROOT / "data" / "meta" / "animation_roster_manifest.json").read_text(encoding="utf-8"))
    total = sum(check_actor(actor, states, registry, roster) for actor, states in ACTORS.items())
    print(f"FAN-3325 mini-elite directional integrity passed: actors={len(ACTORS)} animation_frames={total}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, OSError, ValueError) as exc:
        print(f"FAN-3325 mini-elite directional integrity failed: {exc}", file=sys.stderr)
        sys.exit(1)
