#!/usr/bin/env python3
"""Generate the production schema-6 constellation manifest from SCRUM-1067."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "docs/design/data/scrum1067_weapon_finals_manifest.json"
DEFAULT_OUTPUT = ROOT / "data/meta/constellation_schema6.json"


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def runtime_projection(source: dict[str, Any]) -> dict[str, Any]:
    classes: list[dict[str, Any]] = []
    for class_entry in source["classes"]:
        branches: list[dict[str, Any]] = []
        for branch in class_entry["weapon_branches"]:
            branches.append(
                {
                    "weapon_id": branch["weapon_id"],
                    "weapon_title": branch["weapon_title"],
                    "identity": branch["identity"],
                    "axis": branch["axis"],
                    "nodes": branch["nodes"],
                }
            )
        classes.append(
            {
                "class_id": class_entry["class_id"],
                "core": class_entry["core"],
                "hidden": class_entry["hidden"],
                "weapon_branches": branches,
            }
        )
    return {
        "schema_id": source["schema"],
        "runtime_schema_version": 6,
        "source_issue": source["issue"],
        "topology": source["topology"],
        "economy": source["economy"],
        "branch_boon_contract": source["branch_boon_contract"],
        "classes": classes,
    }


def generate(source_path: Path, output_path: Path) -> dict[str, Any]:
    source_bytes = source_path.read_bytes()
    source = json.loads(source_bytes)
    projection = runtime_projection(source)
    result = {
        "generated_by": "tools/generate_scrum1068_runtime_manifest.py",
        "source_path": "res://docs/design/data/scrum1067_weapon_finals_manifest.json",
        "source_sha256": sha256(source_bytes),
        "projection_sha256": sha256(canonical_bytes(projection)),
        **projection,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = generate(args.source, args.output)
    print(
        "SCRUM-1068 runtime manifest generated: "
        f"{len(result['classes'])} classes, projection {result['projection_sha256']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
