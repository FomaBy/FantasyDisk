#!/usr/bin/env python3
"""Validate the SCRUM-1067 design handoff without loading Godot runtime code."""

from __future__ import annotations

import json
import hashlib
import math
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs/design/data/scrum1067_weapon_finals_manifest.json"

CANONICAL_TRIOS = {
    "berserk": ["sword", "axe", "hammer"],
    "soldier": ["soldier_rifle", "soldier_grenade", "soldier_bayonet"],
    "thief": ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"],
    "elementalist": ["elementalist_orb_ring", "elementalist_prism_focus", "elementalist_meteor_core"],
    "sniper": ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"],
    "priest": ["priest_reliquary", "priest_censer", "priest_chime"],
    "biologist": ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"],
    "robot": ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"],
    "engineer": ["engineer_sentry_wrench", "engineer_repair_drone", "engineer_pressure_mines"],
    "dark_mage": ["dark_book", "cursed_skull", "dark_wand"],
    "guitarist": ["electric_guitar", "bass_guitar", "sound_amp"],
    "assassin": ["chakrams", "shadow_daggers", "venom_wire"],
    "ranger": ["moon_crossbow", "storm_longbow", "hunter_trap"],
    "doctor": ["restore_potion", "plague_syringe", "bone_saw"],
    "chemist": ["blast_powder", "acid_flask", "homunculus_vial"],
    "knight": ["long_spear", "tower_shield", "holy_flail"],
    "druid": ["summon_amulet", "briar_staff", "raven_totem"],
}

ALLOWED_AXES = {"solo", "aoe", "crowd", "defense"}
GEOMETRY_KEYS = {
    "solo": "range_or_precision_zone_mult",
    "aoe": "radius_or_blast_geometry_mult",
    "crowd": "arc_chain_or_zone_geometry_mult",
    "defense": "guard_control_zone_mult",
}
AXIS_KEYS = {
    "solo": "precision_window_mult",
    "aoe": "impact_area_mult",
    "crowd": "target_pattern_budget_mult",
    "defense": "control_sustain_value_mult",
}
REQUIRED_SCENARIOS = [
    "no_meta", "path_5_of_6", "path_6_of_6", "three_paths_6_of_6",
    "full_20_of_20", "a5_live",
]
APPROVED_FINALS_SHA256 = "71dcae59d5be86513fc8d77fd34e5be092078e04cdfb8d6ff1f9c29fb1a8afbc"
APPROVED_BASELINE_SHA256 = "7af15c21e294c81c69b7438606c86c9eaf3777d337cdbea9847b40c5975014f7"


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def valid_consumer(value: object) -> bool:
    path = str(value or "")
    return path.startswith("scripts/") and (ROOT / path).is_file()


def is_finite_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def at_least(value: object, floor: float) -> bool:
    return is_finite_number(value) and value >= floor


def percent_deviation_matches(measured: object, target: object, reported: object) -> bool:
    if not at_least(measured, 0.000001) or not at_least(target, 0.000001) or not is_finite_number(reported):
        return False
    calculated = (measured / target - 1.0) * 100.0
    # The tracked harness table rounds DPS to 0.01 and deviation to 0.1%, so
    # allow the combined display-rounding envelope while rejecting real drift.
    return abs(calculated - reported) <= 0.15


def validate(manifest: dict) -> list[str]:
    errors: list[str] = []
    topology = manifest.get("topology", {})
    economy = manifest.get("economy", {})
    balance = manifest.get("balance", {})

    expected_topology = {
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
        "explicit_branch_node_count": 306,
        "explicit_hidden_node_count": 34,
    }
    for key, expected in expected_topology.items():
        if topology.get(key) != expected:
            fail(errors, f"topology.{key}: expected {expected!r}, got {topology.get(key)!r}")
    if topology.get("hidden_blocks_final") is not False:
        fail(errors, "hidden side nodes must not gate a weapon final")
    if topology.get("all_weapon_finals_simultaneously_active") is not True:
        fail(errors, "all three owned weapon finals must be simultaneously active")

    rewards = economy.get("sigil_rewards_by_first_clear_ascension", [])
    if rewards != [2, 2, 3, 4, 4, 5] or sum(rewards) != 20:
        fail(errors, f"ascension reward schedule must be [2,2,3,4,4,5] = 20, got {rewards}")
    if economy.get("sigils_from_class_challenges") != 0:
        fail(errors, "class challenges reveal hidden stars but must not add spendable sigils")
    if economy.get("spendable_cap") != topology.get("total_spend"):
        fail(errors, "spendable cap must equal the 20-point full-buy cost")
    migration = economy.get("migration", {})
    if (migration.get("from_schema"), migration.get("to_schema")) != (5, 6):
        fail(errors, "migration must be schema 5 -> 6")
    if migration.get("legacy_excess_policy") != "legacy_mastery":
        fail(errors, "legacy excess must use the approved non-combat legacy_mastery ledger")
    if migration.get("idempotence_key") != "constellation_schema6_migrated":
        fail(errors, "migration idempotence key is missing or changed")
    if economy.get("anti_farm") != "first_clear_facts_only":
        fail(errors, "repeat clears must not farm constellation currency")
    if economy.get("challenge_role") != "reveal_hidden_side_nodes_only":
        fail(errors, "class challenges must reveal hidden stars only")
    if migration.get("allocation_policy") != "full_constellation_respec":
        fail(errors, "schema-5 allocations must receive a full respec")
    required_preserve = {
        "ascension_levels", "meta_point_awards", "class_boss_wins",
        "class_challenge_progress", "class_challenges_done", "hidden_reveal_facts",
    }
    if set(migration.get("preserve", [])) != required_preserve:
        fail(errors, "migration preserve facts drifted from the approved set")
    if set(migration.get("remove", [])) != {"active_keystones", "schema5_constellation_node_allocations"}:
        fail(errors, "migration must remove schema-5 allocations and active_keystones")
    if migration.get("legacy_mastery_formula") != "max(schema5_earned_sigils - 20, 0) per class":
        fail(errors, "legacy_mastery compensation formula drifted")
    if migration.get("legacy_mastery_effect") != "non_combat_prestige_badge_only":
        fail(errors, "legacy_mastery must remain non-combat prestige only")

    if float(balance.get("ordinary_boon_measured_axis_gain_min", 0.0)) < 1.08:
        fail(errors, "ordinary boon measured gain floor must be >= 1.08")
    if float(balance.get("weapon_damage_flat_min", 0.0)) < 10.0:
        fail(errors, "weapon-scoped direct damage floor must be >= 10")
    if float(balance.get("final_gain_over_prefinal_min", 0.0)) < 1.20:
        fail(errors, "weapon final must add >= 20% over its 5/6 fixture")
    if balance.get("full_path_intended_axis_gain_range") != [1.6, 2.0]:
        fail(errors, "full path intended-axis corridor must be [1.6, 2.0]")
    if balance.get("full_trio_average_gain_range") != [1.6, 1.9]:
        fail(errors, "full trio gain corridor must be [1.6, 1.9]")
    if float(balance.get("roster_total_max_min_ratio", 99.0)) > 1.15:
        fail(errors, "roster max/min total corridor must be <= 1.15")
    if float(balance.get("defense_score_cap_for_class_total", 0.0)) != 1.5:
        fail(errors, "class-total comparison must explicitly cap defense score at 1.50")
    expected_balance = {
        "ordinary_boon_measured_axis_gain_min": 1.08,
        "weapon_damage_flat_min": 10.0,
        "final_gain_over_prefinal_min": 1.2,
        "full_path_intended_axis_gain_range": [1.6, 2.0],
        "full_trio_average_gain_range": [1.6, 1.9],
        "class_axis_ideal_deviation": 0.1,
        "defense_score_cap_for_class_total": 1.5,
        "class_total_ideal_deviation": 0.08,
        "class_total_hard_fail_deviation": 0.15,
        "roster_total_max_min_ratio": 1.15,
        "a5_speedup_over_a0_baseline_max": 1.15,
        "required_scenarios": REQUIRED_SCENARIOS,
    }
    for key, expected in expected_balance.items():
        if balance.get(key) != expected:
            fail(errors, f"balance.{key}: expected {expected!r}, got {balance.get(key)!r}")
    slots = manifest.get("branch_boon_contract", {}).get("slots", [])
    if (
        len(slots) != 6
        or [slot.get("order") for slot in slots] != [1, 2, 3, 4, 5, 6]
        or [slot.get("role") for slot in slots] != ["weapon_boon"] * 5 + ["weapon_final"]
    ):
        fail(errors, "branch boon contract must define five ordered boons plus one final")

    classes = manifest.get("classes", [])
    if len(classes) != 17:
        fail(errors, f"expected 17 class manifests, got {len(classes)}")
    by_class = {entry.get("class_id"): entry for entry in classes}
    if set(by_class) != set(CANONICAL_TRIOS):
        fail(errors, f"class IDs differ from canonical roster: {sorted(set(by_class) ^ set(CANONICAL_TRIOS))}")

    final_ids: set[str] = set()
    mechanic_ids: set[str] = set()
    positive_fixtures: set[str] = set()
    all_weapons: list[str] = []
    hidden_ids: set[str] = set()
    hidden_fixtures: set[str] = set()
    branch_node_ids: set[str] = set()
    branch_fixtures: set[str] = set()
    explicit_branch_node_count = 0
    approved_final_projection: list[dict] = []
    approved_baseline_projection: list[dict] = []
    for class_id, expected_weapons in CANONICAL_TRIOS.items():
        entry = by_class.get(class_id, {})
        core = entry.get("core", {})
        if core.get("id") != f"{class_id}_core" or core.get("cost") != 0:
            fail(errors, f"{class_id}: core must be {class_id}_core at cost 0")
        expected_core_profile = {
            "effect_key": "primary_attribute_flat",
            "params": {"attribute": core.get("primary_attribute"), "amount": 1},
            "scope": "owning_class",
        }
        if (
            core.get("class_id") != class_id
            or core.get("role") != "free_core"
            or core.get("order") != 0
            or core.get("always_active") is not True
            or core.get("excluded_from_spend") is not True
            or core.get("effect_profile") != expected_core_profile
            or core.get("caps") != {"amount": 1}
            or not valid_consumer(core.get("runtime_consumer"))
        ):
            fail(errors, f"{class_id}: free core must explicitly grant exactly +1 primary attribute outside spend")
        branches = entry.get("weapon_branches", [])
        actual_weapons = [branch.get("weapon_id") for branch in branches]
        if actual_weapons != expected_weapons:
            fail(errors, f"{class_id}: canonical trio/order expected {expected_weapons}, got {actual_weapons}")
        all_weapons.extend(actual_weapons)

        hidden = entry.get("hidden", [])
        if len(hidden) != 2:
            fail(errors, f"{class_id}: expected two hidden side nodes, got {len(hidden)}")
        for node in hidden:
            node_id = str(node.get("id", ""))
            if node_id in hidden_ids or not node_id.startswith(f"{class_id}_h"):
                fail(errors, f"{class_id}: hidden ID is missing, duplicated or non-canonical: {node_id!r}")
            hidden_ids.add(node_id)
            if node.get("cost") != 1:
                fail(errors, f"{node_id}: hidden node must cost 1 after reveal")
            if node.get("attach_weapon_id") not in expected_weapons:
                fail(errors, f"{node_id}: hidden node must attach to one canonical weapon branch")
            reveal = node.get("reveal", {})
            if (
                not reveal.get("metric")
                or int(reveal.get("threshold", 0)) <= 0
                or reveal.get("reveals_only") is not True
                or node.get("purchase_required_for_effect") is not True
            ):
                fail(errors, f"{node_id}: reveal must be separate from the cost-1 effect purchase")
            profile = node.get("effect_profile", {})
            hidden_fixture = str(node.get("positive_fixture", ""))
            hidden_floor = 1.10 if node.get("affected_axis") == "defense" else 1.08
            if (
                node.get("class_id") != class_id
                or node.get("role") != "hidden_side_boon"
                or node.get("affected_axis") not in ALLOWED_AXES
                or profile.get("scope") != "owning_weapon_only"
                or not profile.get("effect_key")
                or not isinstance(profile.get("params"), dict)
                or not profile.get("params")
                or not isinstance(node.get("caps"), dict)
                or not node.get("caps")
                or not valid_consumer(node.get("runtime_consumer"))
                or not at_least(node.get("measured_gain_min"), 1.08)
                or not hidden_fixture
                or set(node.get("negative_controls", [])) != (set(expected_weapons) - {node.get("attach_weapon_id")})
                or profile.get("effect_key") != f"hidden_{node.get('affected_axis')}_mastery_mult"
                or not at_least(profile.get("params", {}).get("multiplier"), hidden_floor)
                or not at_least(node.get("caps", {}).get("axis_multiplier"), hidden_floor)
            ):
                fail(errors, f"{node_id}: hidden node lacks an executable >=8% scoped effect contract")
            if hidden_fixture in hidden_fixtures:
                fail(errors, f"{node_id}: hidden positive fixture is duplicated")
            hidden_fixtures.add(hidden_fixture)

        for branch in branches:
            weapon_id = str(branch.get("weapon_id", ""))
            if branch.get("axis") not in ALLOWED_AXES:
                fail(errors, f"{class_id}/{weapon_id}: invalid intended axis {branch.get('axis')!r}")
            if not str(branch.get("identity", "")).strip():
                fail(errors, f"{class_id}/{weapon_id}: identity is empty")
            nodes = branch.get("nodes", [])
            explicit_branch_node_count += len(nodes)
            if len(nodes) != 6 or [node.get("branch_order") for node in nodes] != [1, 2, 3, 4, 5, 6]:
                fail(errors, f"{class_id}/{weapon_id}: branch must instantiate exact ordered nodes 1..6")
                continue
            boon_effect_keys: set[str] = set()
            if sum(int(node.get("cost", 0)) for node in nodes) != 6:
                fail(errors, f"{class_id}/{weapon_id}: explicit root-to-final branch cost must equal 6")
            for expected_order, node in enumerate(nodes, start=1):
                node_id = str(node.get("node_id", ""))
                fixture_id = str(node.get("positive_fixture", ""))
                profile = node.get("effect_profile", {})
                if not node_id or node_id in branch_node_ids:
                    fail(errors, f"{class_id}/{weapon_id}/{expected_order}: node ID missing or duplicated")
                branch_node_ids.add(node_id)
                if not fixture_id or fixture_id in branch_fixtures:
                    fail(errors, f"{node_id}: positive fixture missing or duplicated")
                branch_fixtures.add(fixture_id)
                if (
                    node.get("class_id") != class_id
                    or node.get("weapon_id") != weapon_id
                    or node.get("cost") != 1
                    or node.get("affected_axis") != branch.get("axis")
                    or not str(node.get("title_ru", "")).strip()
                    or profile.get("scope") != "owning_weapon_only"
                    or not profile.get("effect_key")
                    or not isinstance(profile.get("params"), dict)
                    or not profile.get("params")
                    or not isinstance(node.get("caps"), dict)
                    or not node.get("caps")
                    or not valid_consumer(node.get("runtime_consumer"))
                ):
                    fail(errors, f"{node_id}: incomplete class/weapon/axis/effect/caps/consumer contract")
                if expected_order <= 5:
                    if node.get("role") != "weapon_boon" or not at_least(node.get("measured_gain_min"), 1.08):
                        fail(errors, f"{node_id}: ordinary boon must declare >=8% measured gain")
                    effect_key = str(profile.get("effect_key", ""))
                    boon_effect_keys.add(effect_key)
                    params = profile.get("params", {})
                    caps = node.get("caps", {})
                    expected_keys = {
                        1: "weapon_damage_flat",
                        2: "weapon_attack_speed_mult",
                        3: GEOMETRY_KEYS[branch.get("axis")],
                        4: AXIS_KEYS[branch.get("axis")],
                        5: "weapon_prefinal_identity_mult",
                    }
                    if effect_key != expected_keys[expected_order]:
                        fail(errors, f"{node_id}: unexpected or unknown boon effect key {effect_key!r}")
                    if expected_order == 1 and (
                        not at_least(params.get("amount"), 10.0)
                        or not at_least(caps.get("flat_damage_bonus"), 10.0)
                    ):
                        fail(errors, f"{node_id}: weapon_damage_flat params/cap must be >=10")
                    if expected_order == 2 and (
                        not at_least(params.get("multiplier"), 1.08)
                        or not at_least(caps.get("attack_speed_multiplier"), 1.08)
                    ):
                        fail(errors, f"{node_id}: attack-speed params/cap must be >=1.08")
                    if expected_order == 3 and (
                        not at_least(params.get("multiplier"), 1.12)
                        or not at_least(caps.get("geometry_multiplier"), 1.12)
                    ):
                        fail(errors, f"{node_id}: geometry params/cap must be >=1.12")
                    if expected_order == 4:
                        floor = 1.10 if branch.get("axis") == "defense" else 1.08
                        if not at_least(params.get("multiplier"), floor) or not at_least(caps.get("axis_multiplier"), floor):
                            fail(errors, f"{node_id}: axis params/cap must be >={floor:.2f}")
                    if expected_order == 5 and (
                        not at_least(params.get("multiplier"), 1.12)
                        or params.get("identity") != branch.get("identity")
                        or not at_least(caps.get("identity_multiplier"), 1.12)
                    ):
                        fail(errors, f"{node_id}: prefinal identity params/cap are incomplete")
                elif node.get("role") != "weapon_final":
                    fail(errors, f"{node_id}: order 6 must be weapon_final")
            if len(boon_effect_keys) != 5:
                fail(errors, f"{class_id}/{weapon_id}: five ordinary boons must use five distinct effect profiles")

            final = nodes[5]
            final_id = str(final.get("final_id", ""))
            mechanic_id = str(final.get("mechanic_id", ""))
            fixture = str(final.get("positive_fixture", ""))
            if not final_id or final_id in final_ids:
                fail(errors, f"{class_id}/{weapon_id}: final ID missing or duplicated: {final_id!r}")
            if not mechanic_id or mechanic_id in mechanic_ids:
                fail(errors, f"{class_id}/{weapon_id}: mechanic ID missing or duplicated: {mechanic_id!r}")
            if not fixture or fixture in positive_fixtures:
                fail(errors, f"{class_id}/{weapon_id}: positive fixture missing or duplicated: {fixture!r}")
            final_ids.add(final_id)
            mechanic_ids.add(mechanic_id)
            positive_fixtures.add(fixture)
            if (
                not str(final.get("title_ru", "")).strip()
                or final.get("identity") != branch.get("identity")
                or not str(final.get("effect_profile", {}).get("hook", "")).strip()
                or not at_least(final.get("gain_over_order_5_min"), 1.20)
                or final.get("effect_profile", {}).get("effect_key") != mechanic_id
                or final.get("effect_profile", {}).get("params") != final.get("caps")
                or len(str(final.get("effect_profile", {}).get("hook", "")).split()) < 6
                or any(key.lower() in {"noop", "none", "generic"} for key in final.get("caps", {}))
                or not any(isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0 for value in final.get("caps", {}).values())
            ):
                fail(errors, f"{class_id}/{weapon_id}: final title/hook missing")
            if not valid_consumer(final.get("runtime_consumer")):
                fail(errors, f"{class_id}/{weapon_id}: runtime consumer must be explicit")
            if not isinstance(final.get("caps"), dict) or not final.get("caps"):
                fail(errors, f"{class_id}/{weapon_id}: final must declare hard caps")
            expected_negative = set(expected_weapons) - {weapon_id}
            if set(final.get("negative_controls", [])) != expected_negative:
                fail(errors, f"{class_id}/{weapon_id}: negative controls must be exactly {sorted(expected_negative)}")
            approved_final_projection.append({
                "class_id": class_id,
                "weapon_id": weapon_id,
                "identity": final.get("identity"),
                "affected_axis": final.get("affected_axis"),
                "title_ru": final.get("title_ru"),
                "final_id": final.get("final_id"),
                "mechanic_id": final.get("mechanic_id"),
                "effect_profile": final.get("effect_profile"),
                "caps": final.get("caps"),
                "runtime_consumer": final.get("runtime_consumer"),
                "positive_fixture": final.get("positive_fixture"),
                "negative_controls": final.get("negative_controls"),
            })
            before = branch.get("before_baseline", {})
            after = branch.get("after_target_contract", {})
            approved_baseline_projection.append({
                "class_id": class_id,
                "weapon_id": weapon_id,
                "before_baseline": before,
            })
            if (
                before.get("status") != "PASS"
                or not at_least(before.get("solo_dps"), 0.000001)
                or not at_least(before.get("solo_target"), 0.000001)
                or not is_finite_number(before.get("solo_deviation_pct"))
                or abs(before.get("solo_deviation_pct", 999)) > 20
                or not percent_deviation_matches(
                    before.get("solo_dps"), before.get("solo_target"), before.get("solo_deviation_pct")
                )
                or not str(before.get("profile", "")).strip()
                or not str(before.get("survival_profile", "")).strip()
                or not at_least(before.get("five_target_dps"), 0.000001)
                or not at_least(before.get("five_target_target"), 0.000001)
                or not is_finite_number(before.get("five_target_deviation_pct"))
                or abs(before.get("five_target_deviation_pct", 999)) > 20
                or not percent_deviation_matches(
                    before.get("five_target_dps"),
                    before.get("five_target_target"),
                    before.get("five_target_deviation_pct"),
                )
                or not at_least(before.get("ehp"), 0.000001)
                or set(before.get("cct_seconds", {})) != {"5", "10", "20"}
                or set(before.get("cct_deviation_pct", {})) != {"5", "10", "20"}
                or any(not at_least(value, 0.000001) for value in before.get("cct_seconds", {}).values())
                or any(not is_finite_number(value) or abs(value) > 30 for value in before.get("cct_deviation_pct", {}).values())
                or after.get("no_meta_baseline_unchanged") is not True
                or after.get("path_5_of_6_axis_gain_range") != [1.34, 1.66]
                or after.get("path_6_of_6_axis_gain_range") != [1.6, 2.0]
                or after.get("final_gain_over_5_of_6_min") != 1.2
                or after.get("full_class_trio_average_gain_range") != [1.6, 1.9]
                or after.get("universal_axis_dominance_forbidden") is not True
            ):
                fail(errors, f"{class_id}/{weapon_id}: before/after power-budget contract is incomplete")

        class_branch_spend = sum(sum(int(node.get("cost", 0)) for node in branch.get("nodes", [])) for branch in branches)
        class_hidden_spend = sum(int(node.get("cost", 0)) for node in hidden)
        if class_branch_spend + class_hidden_spend != 20:
            fail(errors, f"{class_id}: instantiated branch+hidden spend must equal 20")

    if len(all_weapons) != 51 or len(set(all_weapons)) != 51:
        fail(errors, f"expected 51 unique canonical weapon keys, got {len(all_weapons)}/{len(set(all_weapons))}")
    if len(final_ids) != 51 or len(mechanic_ids) != 51 or len(positive_fixtures) != 51:
        fail(errors, "expected 51 unique finals, mechanic hooks and positive fixtures")
    if len(hidden_ids) != 34:
        fail(errors, f"expected 34 unique hidden nodes, got {len(hidden_ids)}")
    if explicit_branch_node_count != 306 or len(branch_node_ids) != 306:
        fail(errors, f"expected 306 explicit unique branch nodes, got {explicit_branch_node_count}/{len(branch_node_ids)}")
    final_blob = json.dumps(
        approved_final_projection, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    if hashlib.sha256(final_blob).hexdigest() != APPROVED_FINALS_SHA256:
        fail(errors, "approved 51-final design definitions drifted from the reviewed SCRUM-1067 set")
    baseline_blob = json.dumps(
        approved_baseline_projection, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    if hashlib.sha256(baseline_blob).hexdigest() != APPROVED_BASELINE_SHA256:
        fail(errors, "approved 51-weapon no-meta baseline drifted from the reviewed SCRUM-1067 evidence")

    calculated_nodes = 1 + 3 * 6 + 2
    calculated_spend = 3 * 6 + 2 * 1
    if calculated_nodes != topology.get("nodes_per_class") or calculated_spend != topology.get("total_spend"):
        fail(errors, "topology arithmetic drifted from 1 core + 3x6 + 2 hidden = 21/20")
    return errors


def main() -> int:
    path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_MANIFEST
    with path.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    errors = validate(manifest)
    if errors:
        print(f"SCRUM-1067 manifest FAILED ({len(errors)} error(s)):")
        for error in errors:
            print(f"- {error}")
        return 1
    print("SCRUM-1067 manifest PASS: 17 classes, 306 explicit branch nodes, 51 unique weapon finals, 34 explicit hidden side nodes, 21 nodes/20 spend per class.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
