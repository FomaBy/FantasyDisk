#!/usr/bin/env python3
"""Emit a deterministic source inventory for the UI and ClassWeapon facades."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from check_gdscript_contracts import GDScriptContractError, resolved_chains


AUDIT_BASELINE_SHA = "a53a521604cd7ab7137733838cdda11b3efaf71e"
INVENTORY_METHOD = (
    "Resolve each facade's single extends declaration from facade to engine base; "
    "count UTF-8 source lines and record every resolved extends edge."
)


def build_inventory(root: Path) -> dict[str, object]:
    """Build stable JSON data suitable for review diffs and CI evidence."""
    facades: list[dict[str, object]] = []
    for spec, chain in resolved_chains(root):
        modules: list[dict[str, object]] = []
        edges: list[dict[str, str]] = []
        for script in reversed(chain):
            modules.append({"path": script.path, "line_count": script.line_count})
        for script in chain:
            edges.append({"from": script.path, "to": script.extends or "<missing>"})
        facades.append(
            {
                "name": spec.name,
                "facade": spec.facade,
                "terminal_base": spec.terminal_base,
                "module_count": len(modules),
                "line_count": sum(item["line_count"] for item in modules),
                "modules": modules,
                "dependency_edges": edges,
            }
        )
    return {
        "schema_version": 1,
        "audit_baseline_sha": AUDIT_BASELINE_SHA,
        "method": INVENTORY_METHOD,
        "facades": facades,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        inventory = build_inventory(args.root.resolve())
    except GDScriptContractError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(json.dumps(inventory, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
