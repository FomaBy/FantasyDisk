#!/usr/bin/env python3
"""Focused FAN-3627 contract test for the nine actor-local mini-elite packs."""
from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ELITES = ROOT / "assets" / "sprites" / "elites"
SOURCE_ROOT = ELITES / "pixellab"
RUNTIME_ROOT = ELITES / "full_frame"

DIRECTIONS = [
    "east", "south-east", "south", "south-west", "west", "north-west",
    "north", "north-east",
]
TARGET_ACTORS = {
    "mini_scavenger_reaper": ("3d2c3c13-ed23-4784-add8-2e446a567a8b", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_reaping_dash": 6, "skill_bleed_finish": 6,
    }),
    "mini_plague_bellringer": ("2b4d4ee4-513e-4aa6-a322-f7c19cd43835", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_bell_toll": 6, "skill_poison_pool": 6,
    }),
    "mini_bone_warden": ("02f65048-756d-4b23-8459-b0090eb799cc", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_bone_guard": 6, "skill_slam_wave": 6,
    }),
    "mini_spark_wight": ("841878ea-382d-4d83-9daf-87e8dd8bd89f", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_spark_fan": 6, "skill_static_field": 6,
    }),
    "mini_shadow_devourer": ("ae0eaf0d-531d-4e2d-90b5-bd7ddf5b7280", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_shadow_blink": 6, "skill_devour_bite": 6,
    }),
    "mini_siege_rammer": ("6c8d76d0-97f8-4326-8269-bbbac2e5a634", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_shield_block": 6, "skill_slam_wave": 6,
    }),
    "mini_swarm_sniper": ("f0c3fba4-cb5e-4461-b0bf-1afd6129dc4d", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_shard_fan": 6, "skill_command_pulse": 6,
    }),
    "mini_void_phantom": ("9747cdae-86b2-4479-a24f-deacf09e2027", {
        "move": 6, "attack": 6, "hit": 6, "death": 6,
        "skill_shadow_strike": 6, "skill_phase_dash": 6,
    }),
    "mini_plague_berserker": ("9e63a280-524e-492b-9624-8ddbb2744c07", {
        "move": 6, "attack": 7, "hit": 5, "death": 7,
        "skill_poison_volley": 7,
    }),
}

SCHEMA = "FAN-3325-mini-elite-pack-v1"
EXPECTED_DIRECTIONS = [d.replace("-", "_") for d in DIRECTIONS]
EXT_RE = re.compile(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]')
ANIM_RE = re.compile(
    r'\{\s*"frames":\s*\[(?P<frames>.*?)\],\s*"loop":\s*(?P<loop>\w+),\s*'
    r'"name":\s*&"(?P<name>[^"]+)",\s*"speed":\s*(?P<speed>[-+0-9.eE]+)\s*\}',
    re.S,
)
TEXTURE_RE = re.compile(r'"texture":\s*ExtResource\("([^"]+)"\)')


def fail(message: str) -> None:
    raise AssertionError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_files(actor: str, states: dict[str, int]) -> list[Path]:
    directory = SOURCE_ROOT / actor
    expected = [directory / f"{actor}_idle_{direction.replace('-', '_')}.png" for direction in DIRECTIONS]
    for state, count in states.items():
        expected.extend(
            directory / f"{actor}_{state}_{direction.replace('-', '_')}_{index:02d}.png"
            for direction in DIRECTIONS
            for index in range(count)
        )
    return expected


def validate_manifest_identity(manifest: dict, actor: str, character_id: str) -> None:
    if manifest.get("schema") != SCHEMA:
        fail(f"{actor}: wrong provenance schema")
    if manifest.get("actor_id") != actor or manifest.get("character_id") != actor:
        fail(f"{actor}: actor identity does not match the pack directory")
    if manifest.get("pixel_lab_character_id") != character_id:
        fail(f"{actor}: manifest PixelLab character id is not its own id")
    if manifest.get("pixellab_character_id") != character_id:
        fail(f"{actor}: legacy PixelLab character id is not its own id")
    if manifest.get("source") != "PixelLab MCP" or manifest.get("fallback"):
        fail(f"{actor}: missing direct PixelLab provenance or fallback is enabled")
    if manifest.get("generation_method") != "completed 8-direction PixelLab character export":
        fail(f"{actor}: generation method is not a completed character export")
    if manifest.get("explicit_eight_directions") is not True:
        fail(f"{actor}: explicit eight-direction contract is missing")
    if manifest.get("directions") != DIRECTIONS:
        fail(f"{actor}: direction order is not canonical")
    endpoint = str(manifest.get("download_endpoint", ""))
    if character_id not in endpoint or "pixellab.ai/mcp/characters/" not in endpoint:
        fail(f"{actor}: download provenance does not name its own character")
    provenance = manifest.get("provenance", {})
    if provenance.get("pixel_lab_character_id") != character_id:
        fail(f"{actor}: provenance character identity drifted")
    if character_id not in str(provenance.get("download_endpoint", "")):
        fail(f"{actor}: provenance endpoint is not actor-local")
    for state, entry in manifest.get("states", {}).items():
        if entry.get("pixel_lab_character_id") != character_id:
            fail(f"{actor}/{state}: state donor identity leaked into the manifest")
        if state == "idle":
            if entry.get("source_state") != "rotations":
                fail(f"{actor}/idle: source state must be rotations")
        elif entry.get("source_state") != state:
            fail(f"{actor}/{state}: source state is not actor-local")


def validate_images(actor: str, states: dict[str, int], manifest: dict) -> None:
    source = SOURCE_ROOT / actor
    runtime = RUNTIME_ROOT / actor
    expected_source = source_files(actor, states)
    expected_names = {path.name for path in expected_source}
    actual_names = {path.name for path in source.glob("*.png")}
    if actual_names != expected_names:
        fail(f"{actor}: source PNG set mismatch ({len(actual_names)} vs {len(expected_names)})")
    expected_runtime = {path.name for path in expected_source}
    actual_runtime = {path.name for path in runtime.glob("*.png")}
    if actual_runtime != expected_runtime:
        fail(f"{actor}: runtime PNG set mismatch ({len(actual_runtime)} vs {len(expected_runtime)})")
    if len(actual_names) != 8 + 8 * sum(states.values()):
        fail(f"{actor}: unexpected directional source count")
    if set(manifest.get("source_frame_sha256", {})) != expected_names:
        fail(f"{actor}: source hash manifest does not cover every frame")
    if set(manifest.get("runtime_frame_sha256", {})) != expected_runtime:
        fail(f"{actor}: runtime hash manifest does not cover every frame")

    for source_path in expected_source:
        runtime_path = runtime / source_path.name
        with Image.open(source_path) as image:
            image = image.convert("RGBA")
            alpha = image.getchannel("A")
            if image.size == (0, 0) or alpha.getbbox() is None:
                fail(f"{source_path}: empty source frame")
            if alpha.getextrema()[0] == 255:
                fail(f"{source_path}: solid opaque source background")
        with Image.open(runtime_path) as image:
            image = image.convert("RGBA")
            if image.size != (512, 512):
                fail(f"{runtime_path}: runtime canvas is {image.size}, expected 512x512")
            alpha = image.getchannel("A")
            box = alpha.getbbox()
            if box is None or box[3] != 480:
                fail(f"{runtime_path}: runtime footline is not pinned to y=480")
            if alpha.getextrema()[0] == 255:
                fail(f"{runtime_path}: solid opaque runtime background")
        if sha256(source_path) != manifest["source_frame_sha256"][source_path.name]:
            fail(f"{source_path}: source SHA-256 provenance mismatch")
        if sha256(runtime_path) != manifest["runtime_frame_sha256"][runtime_path.name]:
            fail(f"{runtime_path}: runtime SHA-256 provenance mismatch")


def validate_spriteframes(actor: str, states: dict[str, int]) -> None:
    path = RUNTIME_ROOT / f"{actor}_spriteframes.tres"
    text = path.read_text(encoding="utf-8")
    resources = {resource_id: texture for texture, resource_id in EXT_RE.findall(text)}
    animations = {}
    for match in ANIM_RE.finditer(text):
        resource_ids = TEXTURE_RE.findall(match.group("frames"))
        animations[match.group("name")] = {
            "count": len(resource_ids),
            "loop": match.group("loop") == "true",
            "textures": [resources.get(resource_id, "") for resource_id in resource_ids],
        }
    expected_states = ["idle", *states]
    for state in expected_states:
        expected_count = 1 if state == "idle" else states[state]
        expected_loop = state in ("idle", "move")
        for direction in EXPECTED_DIRECTIONS:
            name = f"{state}_{direction}"
            animation = animations.get(name)
            if animation is None:
                fail(f"{actor}: missing SpriteFrames row {name}")
            if animation["count"] != expected_count or animation["loop"] != expected_loop:
                fail(f"{actor}: wrong SpriteFrames contract for {name}")
            if any(f"/full_frame/{actor}/" not in texture for texture in animation["textures"]):
                fail(f"{actor}: SpriteFrames row {name} references a donor texture")
    for direction in EXPECTED_DIRECTIONS:
        for alias, state in (("walk", "move"), ("attack_primary", "attack")):
            name = f"{alias}_{direction}"
            if name not in animations or animations[name]["count"] != states[state]:
                fail(f"{actor}: missing or malformed alias {name}")
        for state in states:
            if state.startswith("skill_"):
                name = f"attack_{state}_{direction}"
                if name not in animations or animations[name]["count"] != states[state]:
                    fail(f"{actor}: missing or malformed skill alias {name}")


def validate_registry_and_roster() -> None:
    registry = (ROOT / "scripts" / "full_frame_animation_registry.gd").read_text(encoding="utf-8")
    for actor in TARGET_ACTORS:
        marker = f'"{actor}": {{'
        start = registry.find(marker)
        if start < 0:
            fail(f"registry: missing {actor}")
        block = registry[start:registry.find("\n\t\t},", start) + 5]
        if f"full_frame/{actor}_spriteframes.tres" not in block:
            fail(f"registry: {actor} does not use its actor-local SpriteFrames")
        if '"explicit_eight_directions": true' not in block:
            fail(f"registry: {actor} is not explicit eight-direction")

    roster = json.loads((ROOT / "data" / "meta" / "animation_roster_manifest.json").read_text())
    entries = {entry["id"]: entry for entry in roster}
    for actor in TARGET_ACTORS:
        entry = entries.get(actor)
        if not entry or entry.get("frames") != f"res://assets/sprites/elites/full_frame/{actor}_spriteframes.tres":
            fail(f"roster: {actor} does not point to its own pack")
        if entry.get("directional") is not True or "fallback_of" in entry:
            fail(f"roster: {actor} is still marked as fallback")


def validate_negative_donor_fixture(manifests: dict[str, dict]) -> None:
    fixture = copy.deepcopy(manifests["mini_scavenger_reaper"])
    fixture["states"]["attack"]["pixel_lab_character_id"] = manifests["mini_bone_warden"]["pixel_lab_character_id"]
    try:
        validate_manifest_identity(
            fixture,
            "mini_scavenger_reaper",
            manifests["mini_scavenger_reaper"]["pixel_lab_character_id"],
        )
    except AssertionError:
        return
    fail("negative donor fixture was accepted by schema-only validation")


def main() -> int:
    manifests = {}
    for actor, (character_id, states) in TARGET_ACTORS.items():
        manifest = json.loads((SOURCE_ROOT / actor / "manifest.json").read_text(encoding="utf-8"))
        manifests[actor] = manifest
        validate_manifest_identity(manifest, actor, character_id)
        if manifest["states"].keys() != {"idle", *states}:
            fail(f"{actor}: manifest state set mismatch")
        for state, count in states.items():
            if manifest["states"][state].get("frame_count") != count:
                fail(f"{actor}/{state}: manifest frame count mismatch")
        validate_images(actor, states, manifest)
        validate_spriteframes(actor, states)

    seen_hashes: dict[str, str] = {}
    for actor in TARGET_ACTORS:
        for path in (SOURCE_ROOT / actor).glob("*.png"):
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            prior = seen_hashes.setdefault(digest, actor)
            if prior != actor:
                fail(f"cross-actor source duplicate: {path.name} duplicates {prior}")
    validate_registry_and_roster()
    validate_negative_donor_fixture(manifests)
    print(f"FAN-3627 mini-elite directional contract passed: actors={len(TARGET_ACTORS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
