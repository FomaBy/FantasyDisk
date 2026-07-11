#!/usr/bin/env python3
"""Validate production/runtime parity and schema-6 constellation invariants."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
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

# Mechanic-bound consumer entry points for the 40 ClassWeapon finals.  A whole-
# file string search is not proof: another weapon can emit the same generic
# event and hide deletion of this weapon's live route.  Each entry therefore
# names the exact function whose body must retain either the required event or
# an explicitly tagged payoff for the mechanic.
FINAL_ROUTE_METHODS: dict[str, tuple[str, str]] = {
    "rifle_suppression_mark": ("scripts/player.gd", "meta_damage_multiplier"),
    "grenade_shrapnel_second_wave": ("scripts/class_weapon.gd", "_explode_grenade_fuse"),
    "bayonet_brace_countershot": ("scripts/class_weapon.gd", "_resolve_bayonet_brace_countershot"),
    "coin_unique_target_return": ("scripts/class_weapon.gd", "_fire_coin_ricochet"),
    "dagger_backstab_execute_mark": ("scripts/class_weapon.gd", "_fire_shadow_backstab"),
    "smoke_dodge_triggered_burst": ("scripts/class_weapon.gd", "constellation_owner_event"),
    "orb_four_element_resonance": ("scripts/class_weapon.gd", "_elemental_square_tick"),
    "prism_intersection_rift": ("scripts/class_weapon.gd", "_resolve_prism_rift"),
    "meteor_shard_recall": ("scripts/class_weapon.gd", "_resolve_meteor_impact"),
    "deadeye_weakpoint_cycle": ("scripts/class_weapon.gd", "_resolve_sniper_lockshot"),
    "spotter_highest_hp_priority": ("scripts/class_weapon.gd", "_land_spotter_shell"),
    "shatter_extra_pierce_falloff": ("scripts/class_weapon.gd", "_impact_shatter_bullet"),
    "reliquary_mark_expiry_burst": ("scripts/class_weapon.gd", "_constellation_reliquary_expire"),
    "censer_absorb_retaliation": ("scripts/class_weapon.gd", "constellation_owner_event"),
    "chime_owner_return_shield": ("scripts/class_weapon.gd", "_fire_priest_dual_toll"),
    "spore_final_ring_blooms": ("scripts/class_weapon.gd", "_bio_spore_pulse"),
    "injector_sample_analysis_ramp": ("scripts/class_weapon.gd", "_fire_bio_sample_dart"),
    "symbiote_link_transfer": ("scripts/class_weapon.gd", "_germinate_symbiote_seed"),
    "anchor_next_heavy_hit_setup": ("scripts/class_weapon.gd", "_resolve_robot_anchor"),
    "reactor_vent_cycle_pulse": ("scripts/class_weapon.gd", "_fire_robot_reactor_vent"),
    "mine_adjacency_chain": ("scripts/class_weapon.gd", "_detonate_engineer_mine"),
    "book_mirror_midpoint_collapse": ("scripts/class_weapon.gd", "_resolve_dark_mirror_blast"),
    "skull_death_curse_transfer": ("scripts/class_weapon.gd", "_constellation_transfer_skull_curse"),
    "wand_pierce_decay_echo": ("scripts/class_weapon.gd", "_resolve_dark_chain_hit"),
    "guitar_riff_harmony_lane": ("scripts/class_weapon.gd", "_fire_riff_strip"),
    "bass_every_nth_stagger": ("scripts/class_weapon.gd", "_fire_pulse"),
    "amp_instrument_echo": ("scripts/class_weapon.gd", "_constellation_instrument_echo"),
    "chakram_return_execute_mark": ("scripts/class_weapon.gd", "_damage_boomerang_return"),
    "dagger_execute_shadow_window": ("scripts/class_weapon.gd", "constellation_owner_event"),
    "wire_poison_ramp_snap": ("scripts/class_weapon.gd", "_damage_enemy_with_dot"),
    "crossbow_full_charge_mark": ("scripts/class_weapon.gd", "_fire_moon_split_shot"),
    "longbow_outer_storm_branch": ("scripts/class_weapon.gd", "_fire_storm_pierce_cone"),
    "trap_prey_mark_distribution": ("scripts/class_weapon.gd", "_trigger_hunter_trap"),
    "potion_overheal_absorb_pool": ("scripts/class_weapon.gd", "_heal_owner_from_damage"),
    "syringe_infection_threshold_spread": ("scripts/class_weapon.gd", "_apply_plague_infection"),
    "saw_wound_execute_heal": ("scripts/class_weapon.gd", "_fire_saw_sector"),
    "powder_cross_reagent_combo": ("scripts/class_weapon.gd", "_trigger_chemist_combo"),
    "acid_stack_detonation": ("scripts/class_weapon.gd", "_apply_pool_contact_statuses"),
    "briar_sustained_root_burst": ("scripts/class_weapon.gd", "_briar_zone_tick"),
    "totem_every_nth_raven_strike": ("scripts/class_weapon.gd", "_fire_deployable_pulse"),
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
    event_routes, route_errors = _load_final_event_routes()
    errors.extend(route_errors)
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
                    _validate_final_route(node, event_routes, errors)
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
    if set(event_routes) != mechanic_ids:
        errors.append("final event-route keys must exactly match the 51 manifest mechanics")
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


def _load_final_event_routes() -> tuple[dict[str, str], list[str]]:
    runtime_path = ROOT / "scripts/constellation_final_runtime.gd"
    try:
        text = runtime_path.read_text(encoding="utf-8")
    except OSError as exc:
        return {}, [f"cannot load final event runtime: {exc}"]
    marker = "const EVENT_BY_MECHANIC :="
    if marker not in text:
        return {}, ["final runtime has no EVENT_BY_MECHANIC registry"]
    section = text.split(marker, 1)[1].split("}", 1)[0]
    pairs = re.findall(r'"([a-z0-9_]+)"\s*:\s*"([a-z0-9_]+)"', section)
    routes: dict[str, str] = {}
    errors: list[str] = []
    for mechanic_id, event in pairs:
        if mechanic_id in routes:
            errors.append(f"duplicate final event route: {mechanic_id}")
        routes[mechanic_id] = event
    if len(routes) != 51:
        errors.append(f"expected 51 explicit final event routes, got {len(routes)}")
    return routes, errors


def _validate_final_route(node: dict[str, Any], routes: dict[str, str], errors: list[str]) -> None:
    mechanic_id = str(node.get("mechanic_id", ""))
    event = routes.get(mechanic_id, "")
    if event == "":
        errors.append(f"{mechanic_id}: missing explicit final event route")
        return
    consumer = str(node.get("runtime_consumer", ""))
    route = FINAL_ROUTE_METHODS.get(mechanic_id)
    route_consumer, route_method = route if route is not None else (consumer, "")
    consumer_path = ROOT / route_consumer
    try:
        source = consumer_path.read_text(encoding="utf-8")
    except OSError:
        return
    if route is None and mechanic_id not in source:
        errors.append(f"{mechanic_id}: declared consumer has no mechanic hook registration")
    route_source = source
    if route_method:
        match = re.search(
            rf"^func\s+{re.escape(route_method)}\s*\([^\n]*\).*?(?=^func\s+|\Z)",
            source,
            flags=re.MULTILINE | re.DOTALL,
        )
        if match is None:
            errors.append(f"{mechanic_id}: bound live method {route_method} is missing")
            return
        route_source = match.group(0)
    # A registry mention or a generic damage gateway is not implementation
    # evidence. The declared consumer must dispatch its exact event, or a
    # concrete bridge must emit damage explicitly tagged with this mechanic.
    explicit_call = bool(
        re.search(rf'_constellation_event\([^\n]*"{re.escape(event)}"', route_source)
        or re.search(rf'constellation_weapon_event[^\n]*"{re.escape(event)}"', route_source)
    )
    payoff_marker = re.compile(
        rf'["\']constellation_final["\']\s*:\s*["\']{re.escape(mechanic_id)}["\']'
    )
    direct_payoff = bool(payoff_marker.search(route_source))
    if not direct_payoff and route is None:
        for bridge_path in (ROOT / "scripts").glob("*.gd"):
            if bridge_path == consumer_path:
                continue
            if payoff_marker.search(bridge_path.read_text(encoding="utf-8")):
                direct_payoff = True
                break
    if not explicit_call and not direct_payoff:
        errors.append(f"{mechanic_id}: consumer never invokes required event {event}")


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
