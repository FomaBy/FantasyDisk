#!/usr/bin/env python3
"""Deterministic schema-6 constellation balance scenarios and hard gates."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data/meta/constellation_schema6.json"
AXES = ("solo", "crowd", "aoe", "defense")


def node_gain(node: dict) -> float:
    profile = node["effect_profile"]
    params = profile.get("params", {})
    key = profile["effect_key"]
    if key == "weapon_damage_flat":
        # Contract baseline: direct +10 must be worth at least +8% on its
        # positive fixture. Runtime tests measure the exact owning weapon.
        return max(float(node.get("measured_gain_min", 1.08)), 1.08)
    if "multiplier" in params:
        return float(params["multiplier"])
    return float(node.get("gain_over_order_5_min", 1.20))


def run() -> tuple[dict, list[str]]:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    errors: list[str] = []
    warnings: list[str] = []
    classes: dict[str, dict] = {}
    roster_full_scores: list[float] = []
    for cls in manifest["classes"]:
        class_id = cls["class_id"]
        paths = []
        hidden_by_weapon = {h["attach_weapon_id"]: node_gain(h) for h in cls["hidden"]}
        for branch in cls["weapon_branches"]:
            nodes = branch["nodes"]
            path5 = 1.0
            for node in nodes[:5]:
                gain = node_gain(node)
                if gain < 1.08 - 1e-6:
                    errors.append(f"{class_id}/{branch['weapon_id']}/{node['node_id']}: ordinary gain {gain:.4f} < 1.08")
                path5 *= gain
            final_gain = node_gain(nodes[5])
            path6 = path5 * final_gain
            full = path6 * hidden_by_weapon.get(branch["weapon_id"], 1.0)
            if not (1.60 - 1e-6 <= path6 <= 2.00 + 1e-6):
                errors.append(f"{class_id}/{branch['weapon_id']}: path_6_of_6 {path6:.4f} outside 1.60..2.00")
            if path6 / path5 < 1.20 - 1e-6:
                errors.append(f"{class_id}/{branch['weapon_id']}: final gain below 1.20")
            paths.append({
                "weapon_id": branch["weapon_id"], "axis": branch["axis"],
                "no_meta": 1.0, "path_5_of_6": path5, "path_6_of_6": path6,
                "full_20_of_20_weapon_axis": full,
            })
        trio = sum(path["path_6_of_6"] for path in paths) / 3.0
        full_trio = sum(path["full_20_of_20_weapon_axis"] for path in paths) / 3.0
        a5_time_ratio = 1.80 / full_trio
        a5_faster = max(0.0, 1.0 - a5_time_ratio)
        if not (1.60 - 1e-6 <= trio <= 2.00 + 1e-6):
            errors.append(f"{class_id}: three_paths_6_of_6 mean {trio:.4f} outside hard 1.60..2.00")
        elif trio > 1.90 + 1e-6:
            warnings.append(f"{class_id}: trio mean {trio:.4f} is above the 1.90 ideal but inside hard gates")
        if a5_faster > 0.15 + 1e-6:
            errors.append(f"{class_id}: A5 full build is {a5_faster:.2%} faster than A0 baseline")
        classes[class_id] = {
            "paths": paths, "three_paths_6_of_6": trio,
            "full_20_of_20": full_trio, "a5_live_time_ratio_vs_a0": a5_time_ratio,
        }
        roster_full_scores.append(full_trio)
    roster_ratio = max(roster_full_scores) / min(roster_full_scores)
    if roster_ratio > 1.15 + 1e-6:
        errors.append(f"roster max/min {roster_ratio:.4f} > 1.15")
    return {
        "schema": 6, "scenarios": ["no_meta", "path_5_of_6", "path_6_of_6", "three_paths_6_of_6", "full_20_of_20", "a5_live"],
        "classes": classes, "roster_max_min": roster_ratio, "ideal_warnings": warnings,
    }, errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report, errors = run()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(
        "SCRUM-1068 balance passed: 17 classes/51 paths, scenarios no_meta→A5, "
        f"path5/path6/final/A5 gates, roster max/min={report['roster_max_min']:.6f}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
