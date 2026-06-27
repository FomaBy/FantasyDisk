#!/usr/bin/env python3
"""Validate FantasyDisk animation manifest coverage.

This is a lightweight structural validator. It does not replace visual QA.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


MOVE_NAMES = {"move", "walk", "run", "levitate", "hover"}
ATTACK_PREFIX = "attack"
STRICT_KINDS = {"elite", "boss"}
VALID_KINDS = {"hero", "enemy", "monster", "summon", "ally", "elite", "boss"}
VALID_PIPELINES = {
    "skeleton2d_rig",
    "hybrid_rig_spritesheet",
    "full_frame_spritesheet",
    "spriteframes_existing",
    "legacy_cutout",
}


def _fail(errors: list[str], entity_id: str, message: str) -> None:
    errors.append(f"{entity_id}: {message}")


def _animations(entity: dict[str, Any]) -> list[dict[str, Any]]:
    animations = entity.get("animations", [])
    return animations if isinstance(animations, list) else []


def _animation_names(entity: dict[str, Any]) -> set[str]:
    return {str(anim.get("name", "")) for anim in _animations(entity)}


def _frame_count(anim: dict[str, Any]) -> int:
    try:
        return int(anim.get("frames", 0))
    except (TypeError, ValueError):
        return 0


def _positive_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _has_non_empty_sequence_or_mapping(value: Any) -> bool:
    return isinstance(value, (list, dict)) and bool(value)


def _minimum_sheet_gutter(canvas: dict[str, Any]) -> int:
    width = _positive_int(canvas.get("width")) if isinstance(canvas, dict) else 0
    height = _positive_int(canvas.get("height")) if isinstance(canvas, dict) else 0
    max_dim = max(width, height)
    if max_dim <= 0:
        return 24
    return max(24, int(math.ceil((max_dim * 0.08) / 8.0) * 8))


def validate_entity(entity: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    entity_id = str(entity.get("id", "<missing-id>"))
    kind = str(entity.get("kind", "")).lower()
    names = _animation_names(entity)
    animations = _animations(entity)
    attack_required = entity.get("attack_required", True) is not False
    if kind in STRICT_KINDS:
        attack_required = True

    if not entity.get("id"):
        _fail(errors, entity_id, "missing id")
    pipeline = str(entity.get("production_pipeline", "")).strip()
    if kind not in VALID_KINDS:
        _fail(errors, entity_id, "kind must be hero/enemy/monster/summon/ally/elite/boss")
    if pipeline and pipeline not in VALID_PIPELINES:
        _fail(errors, entity_id, f"unknown production_pipeline {pipeline}")

    has_sprite_output = bool(entity.get("sprite_sheet") or entity.get("spriteframes"))
    has_rig_output = bool(entity.get("rig_scene"))
    if not has_sprite_output and not has_rig_output:
        _fail(errors, entity_id, "missing sprite_sheet, spriteframes, or rig_scene path")
    if pipeline == "skeleton2d_rig" and not has_rig_output:
        _fail(errors, entity_id, "skeleton2d_rig pipeline requires rig_scene")
    if pipeline == "hybrid_rig_spritesheet":
        if not has_rig_output:
            _fail(errors, entity_id, "hybrid_rig_spritesheet pipeline requires rig_scene")
        if not has_sprite_output:
            _fail(errors, entity_id, "hybrid_rig_spritesheet pipeline requires sprite output")
    if pipeline in {"skeleton2d_rig", "hybrid_rig_spritesheet"}:
        source_parts = entity.get("source_parts", [])
        if not isinstance(source_parts, list) or not source_parts:
            _fail(errors, entity_id, f"{pipeline} pipeline requires non-empty source_parts")
        if not str(entity.get("animation_player_node", "")).strip():
            _fail(errors, entity_id, f"{pipeline} pipeline requires animation_player_node")
        if not _has_non_empty_sequence_or_mapping(entity.get("bone_hierarchy")):
            _fail(errors, entity_id, f"{pipeline} pipeline requires bone_hierarchy")
        if entity.get("animation_player_clips_checked") is not True:
            _fail(errors, entity_id, f"{pipeline} pipeline requires animation_player_clips_checked=true")

    move_anims = [anim for anim in animations if str(anim.get("name", "")) in MOVE_NAMES]
    if not move_anims:
        _fail(errors, entity_id, "missing move/walk/levitate animation")
    for anim in move_anims:
        if _frame_count(anim) < 5:
            _fail(errors, entity_id, f"{anim.get('name')} has fewer than 5 frames")
        if anim.get("loop") is not True:
            _fail(errors, entity_id, f"{anim.get('name')} should loop")

    attack_anims = [
        anim for anim in animations if str(anim.get("name", "")).startswith(ATTACK_PREFIX)
    ]
    if attack_required and "attack_primary" not in names:
        _fail(errors, entity_id, "missing attack_primary animation")
    for anim in attack_anims:
        if _frame_count(anim) < 5:
            _fail(errors, entity_id, f"{anim.get('name')} has fewer than 5 frames")
        if anim.get("loop") not in (False, None):
            _fail(errors, entity_id, f"{anim.get('name')} should not loop")

    if pipeline in {"skeleton2d_rig", "hybrid_rig_spritesheet"} and attack_anims:
        if entity.get("timeline_markers_checked") is not True:
            _fail(errors, entity_id, f"{pipeline} pipeline requires timeline_markers_checked=true for attack clips")

    if kind in STRICT_KINDS:
        if pipeline in {"legacy_cutout", "skeleton2d_rig"}:
            _fail(errors, entity_id, "elite/boss runtime must be full-frame or coherent full-frame export")
        if entity.get("cutout_used") is not False:
            _fail(errors, entity_id, "elite/boss production animation must be full-frame, not cutout")
        if len(attack_anims) < 2:
            _fail(errors, entity_id, "elite/boss needs multiple attack patterns")
        skills = entity.get("skills", [])
        if isinstance(skills, list):
            if len(skills) < 2:
                _fail(errors, entity_id, "elite/boss should list multiple skills")
            for skill in skills:
                expected = f"attack_{skill}"
                if expected not in names:
                    _fail(errors, entity_id, f"missing skill animation {expected}")
        else:
            _fail(errors, entity_id, "skills must be a list for elite/boss")

    if entity.get("transparent_background_checked") is not True:
        _fail(errors, entity_id, "transparent_background_checked must be true")
    if entity.get("no_crop_checked") is not True:
        _fail(errors, entity_id, "no_crop_checked must be true")

    canvas = entity.get("canvas", {})
    if not isinstance(canvas, dict) or not canvas.get("width") or not canvas.get("height"):
        _fail(errors, entity_id, "canvas width/height required")
    if entity.get("sprite_sheet"):
        min_gutter = _minimum_sheet_gutter(canvas)
        frame_gutter_px = _positive_int(entity.get("frame_gutter_px"))
        outer_padding_px = _positive_int(entity.get("outer_padding_px"))
        if frame_gutter_px < min_gutter:
            _fail(
                errors,
                entity_id,
                f"frame_gutter_px must be at least {min_gutter}px for this canvas",
            )
        if outer_padding_px < min_gutter:
            _fail(
                errors,
                entity_id,
                f"outer_padding_px must be at least {min_gutter}px for this canvas",
            )
        if entity.get("safe_slicing_checked") is not True:
            _fail(errors, entity_id, "safe_slicing_checked must be true")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()

    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    entities = data.get("entities", [])
    if not isinstance(entities, list) or not entities:
        print("Manifest must contain a non-empty entities list.", file=sys.stderr)
        return 2

    errors: list[str] = []
    for entity in entities:
        if not isinstance(entity, dict):
            errors.append("entity entry must be an object")
            continue
        errors.extend(validate_entity(entity))

    if errors:
        print("FantasyDisk animation manifest FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"FantasyDisk animation manifest OK: {len(entities)} entities")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
