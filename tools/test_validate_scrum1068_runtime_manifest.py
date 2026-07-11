#!/usr/bin/env python3
"""Mutation tests for the SCRUM-1068 production manifest validator."""

from __future__ import annotations

import copy
import json
import tempfile
from pathlib import Path

from generate_scrum1068_runtime_manifest import DEFAULT_OUTPUT, DEFAULT_SOURCE
from validate_scrum1068_runtime_manifest import validate


def main() -> int:
    baseline = json.loads(DEFAULT_OUTPUT.read_text(encoding="utf-8"))
    failures: list[str] = []
    if validate(DEFAULT_SOURCE, DEFAULT_OUTPUT):
        failures.append("canonical runtime manifest did not validate")

    mutations = {
        "missing_class": lambda data: data["classes"].pop(),
        "duplicate_node": lambda data: data["classes"][0]["weapon_branches"][0]["nodes"][1].update(
            {"node_id": data["classes"][0]["weapon_branches"][0]["nodes"][0]["node_id"]}
        ),
        "foreign_scope": lambda data: data["classes"][0]["weapon_branches"][0]["nodes"][0]["effect_profile"].update(
            {"scope": "owning_class"}
        ),
        "unnamed_final": lambda data: data["classes"][0]["weapon_branches"][0]["nodes"][5].update(
            {"mechanic_id": ""}
        ),
        "wrong_negative_controls": lambda data: data["classes"][0]["weapon_branches"][0]["nodes"][5].update(
            {"negative_controls": []}
        ),
        "hidden_auto_active": lambda data: data["classes"][0]["hidden"][0].update(
            {"purchase_required_for_effect": False}
        ),
        "wrong_rewards": lambda data: data["economy"].update(
            {"sigil_rewards_by_first_clear_ascension": [2, 2, 3, 4, 5, 6]}
        ),
        "source_hash": lambda data: data.update({"source_sha256": "0" * 64}),
        "projection_hash": lambda data: data.update({"projection_sha256": "0" * 64}),
        "missing_consumer": lambda data: data["classes"][0]["weapon_branches"][0]["nodes"][0].update(
            {"runtime_consumer": "scripts/does_not_exist.gd"}
        ),
        "wrong_topology_count": lambda data: data["topology"].update(
            {"explicit_branch_node_count": 357}
        ),
    }
    with tempfile.TemporaryDirectory(prefix="scrum1068-validator-") as temp_dir:
        temp_path = Path(temp_dir) / "runtime.json"
        for name, mutate in mutations.items():
            candidate = copy.deepcopy(baseline)
            mutate(candidate)
            temp_path.write_text(json.dumps(candidate, ensure_ascii=False), encoding="utf-8")
            if not validate(DEFAULT_SOURCE, temp_path):
                failures.append(f"mutation unexpectedly passed: {name}")

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}")
        return 1
    print(f"SCRUM-1068 validator mutation gate passed ({len(mutations)} corruptions rejected).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
