#!/usr/bin/env python3
"""Validate production/runtime parity and schema-6 constellation invariants."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from generate_scrum1068_runtime_manifest import (
    DEFAULT_OUTPUT,
    DEFAULT_SOURCE,
    canonical_bytes,
    runtime_projection,
)


ROOT = Path(__file__).resolve().parents[1]
CANONICAL_CLASSES = [
    "berserk",
    "soldier",
    "thief",
    "elementalist",
    "sniper",
    "priest",
    "biologist",
    "robot",
    "engineer",
    "dark_mage",
    "guitarist",
    "assassin",
    "ranger",
    "doctor",
    "chemist",
    "knight",
    "druid",
]
ORDINARY_EFFECT_KEYS = {
    "weapon_damage_flat",
    "weapon_attack_speed_mult",
    "range_or_precision_zone_mult",
    "precision_window_mult",
    "target_pattern_budget_mult",
    "arc_chain_or_zone_geometry_mult",
    "guard_control_zone_mult",
    "control_sustain_value_mult",
    "radius_or_blast_geometry_mult",
    "impact_area_mult",
    "weapon_prefinal_identity_mult",
}
HIDDEN_EFFECT_KEYS = {
    "hidden_solo_mastery_mult",
    "hidden_defense_mastery_mult",
    "hidden_crowd_mastery_mult",
    "hidden_aoe_mastery_mult",
}


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def validate(source_path: Path, runtime_path: Path) -> list[str]:
    errors: list[str] = []
    try:
        source_bytes = source_path.read_bytes()
        source = json.loads(source_bytes)
        runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"cannot load manifests: {exc}"]

    expected_projection = runtime_projection(source)
    actual_projection = {
        key: runtime.get(key)
        for key in (
            "schema_id",
            "runtime_schema_version",
            "source_issue",
            "topology",
            "economy",
            "branch_boon_contract",
            "classes",
        )
    }
    if actual_projection != expected_projection:
        errors.append("runtime projection differs from approved SCRUM-1067 source")
    if runtime.get("source_sha256") != _sha256(source_bytes):
        errors.append("source_sha256 does not match the approved source bytes")
    expected_projection_hash = _sha256(canonical_bytes(expected_projection))
    if runtime.get("projection_sha256") != expected_projection_hash:
        errors.append("projection_sha256 does not match runtime projection")
    if runtime.get("runtime_schema_version") != 6:
        errors.append("runtime_schema_version must be 6")

    topology = runtime.get("topology", {})
    exact_topology = {
        "class_count": 17,
        "weapons_per_class": 3,
        "free_core_count": 1,
        "branch_count": 3,
        "purchasable_nodes_per_branch": 6,
        "ordinary_boons_per_branch": 5,
        "weapon_finals_per_branch": 1,
        "cost_per_branch_node": 1,
        "hidden_side_nodes": 2,
        "hidden_cost_each": 1,
        "nodes_per_class": 21,
        "total_spend": 20,
        "hidden_blocks_final": False,
        "all_weapon_finals_simultaneously_active": True,
        "explicit_branch_node_count": 306,
        "explicit_hidden_node_count": 34,
    }
    for key, expected in exact_topology.items():
        if topology.get(key) != expected:
            errors.append(f"topology.{key} must be {expected!r}")

    economy = runtime.get("economy", {})
    if economy.get("sigil_rewards_by_first_clear_ascension") != [2, 2, 3, 4, 4, 5]:
        errors.append("schema-6 ascension rewards must total exactly 20")
    if economy.get("sigils_from_class_challenges") != 0:
        errors.append("class challenges must grant zero spendable sigils")
    if economy.get("spendable_cap") != 20:
        errors.append("schema-6 spendable cap must be 20")

    classes = runtime.get("classes", [])
    class_ids = [entry.get("class_id") for entry in classes if isinstance(entry, dict)]
    if class_ids != CANONICAL_CLASSES:
        errors.append("classes must match the exact canonical order")

    node_ids: set[str] = set()
    mechanic_ids: set[str] = set()
    branch_nodes = 0
    hidden_nodes = 0
    finals = 0
    for class_entry in classes:
        if not isinstance(class_entry, dict):
            errors.append("class entry must be an object")
            continue
        class_id = str(class_entry.get("class_id", ""))
        core = class_entry.get("core", {})
        _validate_node_identity(core, class_id, node_ids, errors, core=True)
        if core.get("cost") != 0 or core.get("role") != "free_core":
            errors.append(f"{class_id}: core must be free_core cost 0")
        branches = class_entry.get("weapon_branches", [])
        if len(branches) != 3:
            errors.append(f"{class_id}: expected exactly three weapon branches")
            continue
        weapon_ids = [str(branch.get("weapon_id", "")) for branch in branches]
        if len(set(weapon_ids)) != 3 or "" in weapon_ids:
            errors.append(f"{class_id}: weapon IDs must be three unique non-empty values")
        for branch in branches:
            weapon_id = str(branch.get("weapon_id", ""))
            nodes = branch.get("nodes", [])
            if len(nodes) != 6:
                errors.append(f"{class_id}/{weapon_id}: expected six nodes")
                continue
            orders = [node.get("branch_order") for node in nodes]
            if orders != [1, 2, 3, 4, 5, 6]:
                errors.append(f"{class_id}/{weapon_id}: branch orders must be 1..6")
            for index, node in enumerate(nodes):
                branch_nodes += 1
                _validate_node_identity(node, class_id, node_ids, errors)
                if node.get("weapon_id") != weapon_id:
                    errors.append(f"{class_id}/{weapon_id}: node weapon ownership drift")
                if node.get("cost") != 1:
                    errors.append(f"{class_id}/{weapon_id}: every branch node must cost 1")
                profile = node.get("effect_profile", {})
                if profile.get("scope") != "owning_weapon_only":
                    errors.append(f"{class_id}/{weapon_id}: effect scope must be owning_weapon_only")
                if index < 5:
                    if node.get("role") != "weapon_boon":
                        errors.append(f"{class_id}/{weapon_id}: orders 1..5 must be weapon_boon")
                    if profile.get("effect_key") not in ORDINARY_EFFECT_KEYS:
                        errors.append(f"{class_id}/{weapon_id}: unknown ordinary effect key")
                else:
                    finals += 1
                    mechanic_id = str(node.get("mechanic_id", ""))
                    if node.get("role") != "weapon_final" or mechanic_id == "":
                        errors.append(f"{class_id}/{weapon_id}: order 6 must be a named final")
                    elif mechanic_id in mechanic_ids:
                        errors.append(f"duplicate mechanic_id: {mechanic_id}")
                    mechanic_ids.add(mechanic_id)
                    if profile.get("effect_key") != mechanic_id:
                        errors.append(f"{class_id}/{weapon_id}: final effect key must equal mechanic_id")
                    negatives = node.get("negative_controls", [])
                    if sorted(negatives) != sorted(set(weapon_ids) - {weapon_id}):
                        errors.append(f"{class_id}/{weapon_id}: final needs the exact two foreign controls")
                    if float(node.get("gain_over_order_5_min", 0.0)) < 1.2:
                        errors.append(f"{class_id}/{weapon_id}: final power floor below 1.2")
                _validate_consumer(node, errors)

        hidden = class_entry.get("hidden", [])
        if len(hidden) != 2:
            errors.append(f"{class_id}: expected exactly two hidden nodes")
        for hidden_node in hidden:
            hidden_nodes += 1
            _validate_node_identity(hidden_node, class_id, node_ids, errors)
            if hidden_node.get("role") != "hidden_side_boon" or hidden_node.get("cost") != 1:
                errors.append(f"{class_id}: hidden node must be hidden_side_boon cost 1")
            if hidden_node.get("attach_weapon_id") not in weapon_ids:
                errors.append(f"{class_id}: hidden node attaches to an unknown weapon")
            if hidden_node.get("purchase_required_for_effect") is not True:
                errors.append(f"{class_id}: hidden reveal must not auto-activate")
            if hidden_node.get("reveal", {}).get("reveals_only") is not True:
                errors.append(f"{class_id}: hidden reveal must reveal only")
            profile = hidden_node.get("effect_profile", {})
            if profile.get("scope") != "owning_weapon_only":
                errors.append(f"{class_id}: hidden scope must be owning_weapon_only")
            if profile.get("effect_key") not in HIDDEN_EFFECT_KEYS:
                errors.append(f"{class_id}: unknown hidden effect key")
            negatives = hidden_node.get("negative_controls", [])
            owning_weapon = str(hidden_node.get("attach_weapon_id", ""))
            if sorted(negatives) != sorted(set(weapon_ids) - {owning_weapon}):
                errors.append(f"{class_id}/{owning_weapon}: hidden needs exact foreign controls")
            _validate_consumer(hidden_node, errors)

    if branch_nodes != 306:
        errors.append(f"expected 306 branch nodes, got {branch_nodes}")
    if hidden_nodes != 34:
        errors.append(f"expected 34 hidden nodes, got {hidden_nodes}")
    if finals != 51 or len(mechanic_ids) != 51:
        errors.append(f"expected 51 unique finals, got {finals}/{len(mechanic_ids)}")
    if len(node_ids) != 357:
        errors.append(f"expected 357 unique class nodes, got {len(node_ids)}")
    if len(node_ids) + 25 != 382:
        errors.append("class nodes plus frozen Guild Atlas must equal 382")
    return errors


def _validate_node_identity(
    node: Any,
    class_id: str,
    node_ids: set[str],
    errors: list[str],
    *,
    core: bool = False,
) -> None:
    if not isinstance(node, dict):
        errors.append(f"{class_id}: node must be an object")
        return
    node_id = str(node.get("id" if core else "node_id", node.get("id", "")))
    if node_id == "":
        errors.append(f"{class_id}: node ID is empty")
    elif node_id in node_ids:
        errors.append(f"duplicate node ID: {node_id}")
    node_ids.add(node_id)
    if node.get("class_id") != class_id:
        errors.append(f"{node_id}: class ownership drift")


def _validate_consumer(node: dict[str, Any], errors: list[str]) -> None:
    consumer = str(node.get("runtime_consumer", ""))
    if not consumer.startswith("scripts/") or not (ROOT / consumer).is_file():
        errors.append(f"{node.get('node_id', node.get('id'))}: missing runtime consumer {consumer}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--runtime", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    errors = validate(args.source, args.runtime)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("SCRUM-1068 runtime manifest parity passed: 17 classes, 306 branches, 51 finals, 34 hidden, 357+25=382 nodes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
