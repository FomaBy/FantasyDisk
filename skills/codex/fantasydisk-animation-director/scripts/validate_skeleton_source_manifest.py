#!/usr/bin/env python3
"""Validate FantasyDisk skeleton-friendly source-part manifests.

This validator is intentionally structural. It verifies that Design delivered a
usable separated-parts package before Animator builds Skeleton2D/Bone2D rigs.
It does not replace visual QA or alpha/pixel inspection.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_HUMANOID_PARTS = {
    "head",
    "torso",
    "pelvis",
    "upper_arm_l",
    "lower_arm_l",
    "hand_l",
    "upper_arm_r",
    "lower_arm_r",
    "hand_r",
    "thigh_l",
    "shin_l",
    "foot_l",
    "thigh_r",
    "shin_r",
    "foot_r",
}


def _as_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _fail(errors: list[str], message: str) -> None:
    errors.append(message)


def validate_manifest(data: dict[str, Any], manifest_path: Path) -> list[str]:
    errors: list[str] = []
    entity_id = str(data.get("entity_id", "")).strip()
    parts = _as_dict(data.get("parts"))
    pivots = _as_dict(data.get("pivots"))
    checks = _as_dict(data.get("checks"))
    base_dir = manifest_path.parent

    if not entity_id:
        _fail(errors, "missing entity_id")
    if data.get("kind") not in {"hero", "enemy", "summon", "ally"}:
        _fail(errors, "kind must be hero/enemy/summon/ally for skeleton source")
    if data.get("pose") not in {"a_pose", "t_pose", "neutral_front"}:
        _fail(errors, "pose must be a_pose, t_pose, or neutral_front")

    missing_parts = sorted(REQUIRED_HUMANOID_PARTS.difference(parts.keys()))
    if missing_parts:
        _fail(errors, "missing required parts: " + ", ".join(missing_parts))

    for part_name, part_path in sorted(parts.items()):
        if not isinstance(part_path, str) or not part_path.strip():
            _fail(errors, f"{part_name}: part path must be a non-empty string")
            continue
        resolved = (base_dir / part_path).resolve() if not Path(part_path).is_absolute() else Path(part_path)
        if resolved.suffix.lower() != ".png":
            _fail(errors, f"{part_name}: part must be a PNG")
        if not resolved.exists():
            _fail(errors, f"{part_name}: missing file {part_path}")
        pivot = _as_dict(pivots.get(part_name))
        if "x" not in pivot or "y" not in pivot:
            _fail(errors, f"{part_name}: missing pivot x/y")

    if checks.get("transparent_rgba") is not True:
        _fail(errors, "checks.transparent_rgba must be true")
    if checks.get("no_background") is not True:
        _fail(errors, "checks.no_background must be true")
    if checks.get("joint_overlap") is not True:
        _fail(errors, "checks.joint_overlap must be true")
    if checks.get("empty_hands") is not True:
        _fail(errors, "checks.empty_hands must be true for playable skeleton sources")

    style_anchor = str(data.get("style_anchor", "")).strip()
    if not style_anchor:
        _fail(errors, "missing style_anchor")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()

    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        print("Skeleton source manifest must be a JSON object.", file=sys.stderr)
        return 2

    errors = validate_manifest(data, args.manifest)
    if errors:
        print("FantasyDisk skeleton source manifest FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"FantasyDisk skeleton source manifest OK: {data.get('entity_id')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
