#!/usr/bin/env python3
"""Focused offline integrity contract for FAN-3606 mini-elite packs."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ELITES = ROOT / "assets" / "sprites" / "elites"
DIRECTIONS = ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
ACTORS = {
    "mini_siege_rammer": ["move", "attack", "hit", "death", "skill_shield_block", "skill_slam_wave"],
    "mini_spark_wight": ["move", "attack", "hit", "death", "skill_spark_fan", "skill_static_field"],
    "mini_swarm_sniper": ["move", "attack", "hit", "death", "skill_shard_fan", "skill_command_pulse"],
    "mini_bone_warden": ["move", "attack", "hit", "death", "skill_bone_guard", "skill_slam_wave"],
    "mini_void_phantom": ["move", "attack", "hit", "death", "skill_shadow_strike", "skill_phase_dash"],
    "mini_shadow_devourer": ["move", "attack", "hit", "death", "skill_devour_bite", "skill_shadow_blink"],
    "mini_plague_bellringer": ["move", "attack", "hit", "death", "skill_bell_toll", "skill_poison_pool"],
    "mini_scavenger_reaper": ["move", "attack", "hit", "death", "skill_reaping_dash", "skill_bleed_finish"],
}
ANIMATION_RE = re.compile(
    r'\{\s*"frames":\s*\[(?P<frames>.*?)\],\s*"loop":\s*(?P<loop>true|false),\s*'
    r'"name":\s*&"(?P<name>[^"]+)"', re.S
)
FRAME_RE = re.compile(r'"texture":\s*ExtResource\("([^"]+)"\)')
EXT_RE = re.compile(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]')


def fail(message: str) -> None:
    raise AssertionError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_animations(path: Path) -> tuple[dict[str, tuple[int, bool]], dict[str, str]]:
    text = path.read_text(encoding="utf-8")
    ext = {resource_id: resource_path for resource_path, resource_id in EXT_RE.findall(text)}
    result: dict[str, tuple[int, bool]] = {}
    for match in ANIMATION_RE.finditer(text):
        name = match.group("name")
        if name in result:
            fail(f"{path.name}: duplicate animation {name}")
        result[name] = (len(FRAME_RE.findall(match.group("frames"))), match.group("loop") == "true")
    return result, ext


def validate_manifest_identity(actor: str, manifest: dict) -> None:
    own_id = manifest.get("pixel_lab_character_id") or manifest.get("pixellab_character_id")
    if not own_id or manifest.get("character_id") != actor:
        fail(f"{actor}: missing own PixelLab identity")
    if manifest.get("schema") != "FAN-3325-mini-elite-pack-v1":
        fail(f"{actor}: source manifest schema is not the directional pack contract")
    if manifest.get("source") != "PixelLab MCP" or manifest.get("generation_method") != "animate_character":
        fail(f"{actor}: source provenance is incomplete")
    if manifest.get("fallback") is not False or manifest.get("explicit_eight_directions") is not True:
        fail(f"{actor}: dedicated/non-fallback flags are missing")
    if manifest.get("directions") != [d.replace("_", "-") for d in DIRECTIONS]:
        fail(f"{actor}: canonical directions are missing")
    for state, entry in manifest.get("states", {}).items():
        if entry.get("pixel_lab_character_id") != own_id:
            fail(f"{actor}: {state} points at a donor PixelLab character")
        if not entry.get("source_state"):
            fail(f"{actor}: {state} has no source-state mapping")
    if not manifest.get("alpha_bbox_report"):
        fail(f"{actor}: alpha/hash report is missing")


def assert_no_cross_actor_source_duplicates(entries: list[tuple[str, str, str]]) -> None:
    seen: dict[str, tuple[str, str]] = {}
    for actor, path, digest in entries:
        prior = seen.get(digest)
        if prior and prior[0] != actor:
            fail(f"cross-actor source-frame duplicate: {prior[0]}/{prior[1]} == {actor}/{path}")
        seen[digest] = (actor, path)


def run_negative_fixtures() -> None:
    donor_state = {
        "character_id": "fixture",
        "pixellab_character_id": "own-character",
        "source": "PixelLab MCP animate_character",
        "fallback": False,
        "explicit_eight_directions": True,
        "directions": [d.replace("_", "-") for d in DIRECTIONS],
        "states": {"attack": {"pixel_lab_character_id": "donor-character", "source_state": "attack"}},
        "alpha_bbox_report": {"attack": []},
    }
    try:
        validate_manifest_identity("fixture", donor_state)
    except AssertionError:
        pass
    else:
        fail("negative donor-ID fixture was accepted")
    try:
        assert_no_cross_actor_source_duplicates([("actor_a", "frame.png", "same"), ("actor_b", "frame.png", "same")])
    except AssertionError:
        pass
    else:
        fail("negative cross-actor duplicate fixture was accepted")


def check_actor(actor: str, states: list[str], registry: str, roster: list[dict]) -> int:
    source_dir = ELITES / "pixellab" / actor
    runtime_dir = ELITES / "full_frame" / actor
    spriteframes_path = ELITES / "full_frame" / f"{actor}_spriteframes.tres"
    manifest_path = source_dir / "manifest.json"
    for path in (source_dir, runtime_dir, spriteframes_path, manifest_path):
        if not path.exists():
            fail(f"{actor}: missing {path.relative_to(ROOT)}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    validate_manifest_identity(actor, manifest)
    source_pngs = sorted(source_dir.glob(f"{actor}_*.png"))
    runtime_pngs = sorted(runtime_dir.glob(f"{actor}_*.png"))
    expected_count = 8 + (len(states) * 8 * 6)
    if len(source_pngs) != expected_count or len(runtime_pngs) != expected_count:
        fail(f"{actor}: expected {expected_count} source/runtime frames, got {len(source_pngs)}/{len(runtime_pngs)}")
    for path in source_pngs:
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.getchannel("A").getbbox() is None:
                fail(f"{actor}: invalid source frame {path.name}")
    for path in runtime_pngs:
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.size != (512, 512):
                fail(f"{actor}: runtime frame is not 512x512 RGBA: {path.name}")
            frame_bbox = image.getchannel("A").getbbox()
            if frame_bbox is None or frame_bbox[3] != 480:
                fail(f"{actor}: runtime footline drifted in {path.name}: {frame_bbox}")

    reports = manifest["alpha_bbox_report"]
    for row, row_reports in reports.items():
        for report in row_reports:
            source = source_dir / report["source"]
            runtime = runtime_dir / report["runtime"]
            if not source.exists() or not runtime.exists():
                fail(f"{actor}: report references missing frame in {row}")
            if sha256(source) != report.get("source_encoded_sha256"):
                fail(f"{actor}: source hash mismatch in {row}/{source.name}")
            if sha256(runtime) != report.get("runtime_encoded_sha256"):
                fail(f"{actor}: runtime hash mismatch in {row}/{runtime.name}")

    parsed, ext = parse_animations(spriteframes_path)
    required_bases = ["idle", "move", "walk", "attack", "attack_primary", "hit", "death"] + states[4:]
    total = 0
    for base in required_bases:
        counts = []
        for direction in DIRECTIONS:
            name = f"{base}_{direction}"
            if name not in parsed:
                fail(f"{actor}: missing directional row {name}")
            count, loop = parsed[name]
            if count < 1 or (base in ("idle", "move", "walk")) != loop:
                fail(f"{actor}: invalid loop/count for {name}: {count}/{loop}")
            counts.append(count)
            total += count
            if base.startswith("skill_") and f"attack_{base}_{direction}" not in parsed:
                fail(f"{actor}: missing skill alias attack_{base}_{direction}")
        if len(set(counts)) != 1:
            fail(f"{actor}: {base} frame counts differ across directions: {counts}")
    for resource_path in ext.values():
        if not (ROOT / resource_path.removeprefix("res://")).exists():
            fail(f"{actor}: SpriteFrames references missing texture {resource_path}")

    registry_pattern = '"' + re.escape(actor) + r'": \{(?P<body>.*?)\n\t\t\},'
    registry_entry = re.search(registry_pattern, registry, re.S)
    if not registry_entry or '"explicit_eight_directions": true' not in registry_entry.group("body"):
        fail(f"{actor}: registry does not enforce explicit eight-direction playback")
    roster_entry = next((entry for entry in roster if entry.get("id") == actor), None)
    if not roster_entry or roster_entry.get("directional") is not True or roster_entry.get("fallback_of"):
        fail(f"{actor}: roster still points at a fallback")
    return total


def main() -> int:
    roster = json.loads((ROOT / "data/meta/animation_roster_manifest.json").read_text(encoding="utf-8"))
    registry = (ROOT / "scripts/full_frame_animation_registry.gd").read_text(encoding="utf-8")
    total = 0
    source_entries: list[tuple[str, str, str]] = []
    for actor, states in ACTORS.items():
        total += check_actor(actor, states, registry, roster)
        for path in sorted((ELITES / "pixellab" / actor).glob(f"{actor}_*.png")):
            source_entries.append((actor, path.name, sha256(path)))
    assert_no_cross_actor_source_duplicates(source_entries)
    berserker = next((entry for entry in roster if entry.get("id") == "mini_plague_berserker"), None)
    if not berserker or berserker.get("fallback_of") != "plague_prophet" or berserker.get("directional"):
        fail("mini_plague_berserker clean-control fallback marker changed")
    run_negative_fixtures()
    print(f"FAN-3606 mini-elite directional integrity passed: actors={len(ACTORS)} animation_frames={total}; negative_fixtures=2")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, OSError, ValueError) as exc:
        print(f"FAN-3606 mini-elite directional integrity failed: {exc}", file=sys.stderr)
        sys.exit(1)
