#!/usr/bin/env python3
"""Mutation tests for the FAN-3383 Druid baseline row-isolation guard."""

from __future__ import annotations

import copy

from check_druid_baseline_isolation import find_non_druid_drift, rows_by_key

BASE_DOCUMENT = {
    "rows": [
        {"key": "doctor/restore_potion", "class_id": "doctor", "weapon_id": "restore_potion",
         "scenarios": {"crowd_20": {"targets_struck": 12.0}}},
        {"key": "druid/summon_amulet", "class_id": "druid", "weapon_id": "summon_amulet",
         "scenarios": {"crowd_20": {"targets_struck": 20.0}}},
        {"key": "robot/robot_hydraulic_press", "class_id": "robot", "weapon_id": "robot_hydraulic_press",
         "scenarios": {"crowd_20": {"targets_struck": 8.0}}},
    ]
}


def main() -> int:
    failures: list[str] = []
    base_rows = rows_by_key(BASE_DOCUMENT)

    identical = copy.deepcopy(BASE_DOCUMENT)
    if find_non_druid_drift(base_rows, rows_by_key(identical)):
        failures.append("an unchanged candidate must produce no violations")

    druid_only_change = copy.deepcopy(BASE_DOCUMENT)
    druid_only_change["rows"][1]["scenarios"]["crowd_20"]["targets_struck"] = 99.0
    if find_non_druid_drift(base_rows, rows_by_key(druid_only_change)):
        failures.append("a Druid-only row change must not be flagged")

    doctor_row_drift = copy.deepcopy(BASE_DOCUMENT)
    doctor_row_drift["rows"][0]["scenarios"]["crowd_20"]["targets_struck"] = 20.0
    if not find_non_druid_drift(base_rows, rows_by_key(doctor_row_drift)):
        failures.append("the exact FAN-2665 doctor drift must be flagged")

    robot_row_drift = copy.deepcopy(BASE_DOCUMENT)
    robot_row_drift["rows"][2]["scenarios"]["crowd_20"]["targets_struck"] = 18.0
    if not find_non_druid_drift(base_rows, rows_by_key(robot_row_drift)):
        failures.append("a robot row drift must be flagged")

    missing_row = copy.deepcopy(BASE_DOCUMENT)
    missing_row["rows"].pop(0)
    if not find_non_druid_drift(base_rows, rows_by_key(missing_row)):
        failures.append("a dropped non-Druid row must be flagged")

    unexpected_row = copy.deepcopy(BASE_DOCUMENT)
    unexpected_row["rows"].append(
        {"key": "knight/holy_flail", "class_id": "knight", "weapon_id": "holy_flail", "scenarios": {}}
    )
    if not find_non_druid_drift(base_rows, rows_by_key(unexpected_row)):
        failures.append("a new non-Druid row must be flagged")

    dropped_druid_row = copy.deepcopy(BASE_DOCUMENT)
    dropped_druid_row["rows"].pop(1)
    if find_non_druid_drift(base_rows, rows_by_key(dropped_druid_row)):
        failures.append("a dropped Druid row is out of this guard's scope and must not be flagged")

    # FAN-2533 reuses the guard for `guitarist`: re-scoping must move the
    # exemption with it, so the Druid row is now a foreign row like any other.
    if find_non_druid_drift(base_rows, rows_by_key(copy.deepcopy(BASE_DOCUMENT)), "guitarist"):
        failures.append("an unchanged candidate must produce no violations under any scope")
    druid_drift = copy.deepcopy(BASE_DOCUMENT)
    druid_drift["rows"][1]["scenarios"]["crowd_20"]["targets_struck"] = 99.0
    if not find_non_druid_drift(base_rows, rows_by_key(druid_drift), "guitarist"):
        failures.append("a Druid row drift must be flagged when the guard is scoped to guitarist")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1
    print("test_check_druid_baseline_isolation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
