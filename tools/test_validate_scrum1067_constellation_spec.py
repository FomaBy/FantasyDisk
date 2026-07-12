#!/usr/bin/env python3
"""Negative mutation probes for the SCRUM-1067 design-manifest validator."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Callable

from validate_scrum1067_constellation_spec import DEFAULT_MANIFEST, validate


Mutation = Callable[[dict], None]


def attack_speed_zero(data: dict) -> None:
    node = data["classes"][0]["weapon_branches"][0]["nodes"][1]
    node["effect_profile"]["params"]["multiplier"] = 0
    node["caps"]["attack_speed_multiplier"] = 0


def migration_destroyed(data: dict) -> None:
    economy = data["economy"]
    economy["anti_farm"] = "repeat_clear_farming"
    migration = economy["migration"]
    migration["allocation_policy"] = "keep_old_allocations"
    migration["preserve"] = []
    migration["remove"] = []
    migration["legacy_mastery_formula"] = "0"
    migration["legacy_mastery_effect"] = "combat_damage"


def balance_gates_destroyed(data: dict) -> None:
    balance = data["balance"]
    for key in (
        "class_axis_ideal_deviation",
        "class_total_ideal_deviation",
        "class_total_hard_fail_deviation",
        "a5_speedup_over_a0_baseline_max",
    ):
        balance[key] = 99
    balance["required_scenarios"] = []


def final_replaced_by_noop(data: dict) -> None:
    final = data["classes"][0]["weapon_branches"][0]["nodes"][5]
    final["effect_profile"]["hook"] = "x"
    final["effect_profile"]["params"] = {"noop": True}
    final["caps"] = {"none": True}


def final_approved_definition_drift(data: dict) -> None:
    final = data["classes"][0]["weapon_branches"][0]["nodes"][5]
    final["mechanic_id"] = "plausible_but_unreviewed_execute"
    final["effect_profile"]["effect_key"] = final["mechanic_id"]


def baseline_non_finite(data: dict) -> None:
    baseline = data["classes"][0]["weapon_branches"][0]["before_baseline"]
    baseline["solo_dps"] = float("nan")
    baseline["five_target_dps"] = float("inf")
    baseline["ehp"] = None


def baseline_arithmetic_drift(data: dict) -> None:
    baseline = data["classes"][0]["weapon_branches"][0]["before_baseline"]
    baseline["five_target_dps"] = 1.0


def baseline_cct_drift(data: dict) -> None:
    baseline = data["classes"][0]["weapon_branches"][0]["before_baseline"]
    baseline["cct_seconds"]["20"] = 999.0


def unknown_boon_profiles(data: dict) -> None:
    nodes = data["classes"][0]["weapon_branches"][0]["nodes"][:5]
    for index, node in enumerate(nodes):
        node["effect_profile"]["effect_key"] = f"unknown_unique_{index}"


def reveal_purchase_leak(data: dict) -> None:
    hidden = data["classes"][0]["hidden"][0]
    hidden["reveal"]["reveals_only"] = False
    hidden["purchase_required_for_effect"] = False


def missing_consumer(data: dict) -> None:
    data["classes"][0]["weapon_branches"][0]["nodes"][0]["runtime_consumer"] = "scripts/not_real.gd"


MUTATIONS: dict[str, Mutation] = {
    "attack_speed_zero": attack_speed_zero,
    "migration_destroyed": migration_destroyed,
    "balance_gates_destroyed": balance_gates_destroyed,
    "final_replaced_by_noop": final_replaced_by_noop,
    "final_approved_definition_drift": final_approved_definition_drift,
    "baseline_non_finite": baseline_non_finite,
    "baseline_arithmetic_drift": baseline_arithmetic_drift,
    "baseline_cct_drift": baseline_cct_drift,
    "unknown_boon_profiles": unknown_boon_profiles,
    "reveal_purchase_leak": reveal_purchase_leak,
    "missing_consumer": missing_consumer,
}


def main() -> int:
    source = json.loads(Path(DEFAULT_MANIFEST).read_text(encoding="utf-8"))
    positive_errors = validate(copy.deepcopy(source))
    if positive_errors:
        print("SCRUM-1067 validator mutation test FAILED: canonical manifest rejected")
        return 1
    false_passes: list[str] = []
    for name, mutate in MUTATIONS.items():
        candidate = copy.deepcopy(source)
        mutate(candidate)
        if not validate(candidate):
            false_passes.append(name)
    if false_passes:
        print("SCRUM-1067 validator mutation test FAILED; false passes: " + ", ".join(false_passes))
        return 1
    print(f"SCRUM-1067 validator mutation PASS: canonical accepted; {len(MUTATIONS)} critical mutations rejected.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
