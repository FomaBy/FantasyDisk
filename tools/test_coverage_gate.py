#!/usr/bin/env python3
"""Ratchet the repository's executable Godot and Python test surface."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_PATH_PARTS = {".godot", "__pycache__", "build", "vendor"}
GODOT_TEST_EXTENDS_RE = re.compile(
    r'^\s*extends\s+(?:SceneTree|["\']res://tests/[^"\']+\.gd["\'])\s*(?:#.*)?$',
    re.MULTILINE,
)


def _test_files(root: Path, pattern: str) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in (root / "tests").rglob(pattern)
        if not EXCLUDED_PATH_PARTS.intersection(path.relative_to(root).parts)
    )


def _group(files: list[str]) -> dict[str, object]:
    digest = hashlib.sha256("\n".join(files).encode("utf-8")).hexdigest()
    return {"test_files": len(files), "inventory_sha256": digest}


def _godot_test_files(root: Path) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in (root / "tests").rglob("*.gd")
        if not EXCLUDED_PATH_PARTS.intersection(path.relative_to(root).parts)
        and GODOT_TEST_EXTENDS_RE.search(path.read_text(encoding="utf-8"))
    )


def collect(root: Path) -> dict[str, dict[str, object]]:
    return {
        "godot": _group(_godot_test_files(root)),
        "python": _group(_test_files(root, "test_*.py")),
    }


def evaluate(groups: dict[str, dict[str, object]], baseline: dict) -> list[str]:
    errors: list[str] = []
    for name, minimum in baseline["groups"].items():
        actual = groups.get(name, {}).get("test_files", 0)
        required = minimum["minimum_test_files"]
        if actual < required:
            errors.append(f"{name} test surface below baseline: {actual} < {required}")
    return errors


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_markdown(path: Path, payload: dict) -> None:
    lines = [
        "# Test coverage surface report",
        "",
        "This report measures executable test inventory, not source-line coverage.",
        "",
        "| Group | Test files | Baseline | Inventory SHA-256 |",
        "| --- | ---: | ---: | --- |",
    ]
    for name, group in payload["groups"].items():
        baseline = payload["baseline"]["groups"][name]["minimum_test_files"]
        lines.append(
            f"| {name} | {group['test_files']} | {baseline} | `{group['inventory_sha256']}` |"
        )
    lines.extend(["", f"Status: **{payload['status']}**", ""])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--baseline", type=Path, default=ROOT / "tools/test_coverage_baseline.json")
    parser.add_argument("--json-report", type=Path)
    parser.add_argument("--markdown-report", type=Path)
    parser.add_argument("--max-duration-seconds", type=float, default=5.0)
    args = parser.parse_args(argv)

    started = time.monotonic()
    root = args.root.resolve()
    try:
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        if baseline.get("schema_version") != 1 or not isinstance(baseline.get("groups"), dict):
            raise ValueError("unsupported baseline schema")
        groups = collect(root)
        errors = evaluate(groups, baseline)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"test coverage gate: {exc}", file=sys.stderr)
        return 2

    # Runtime duration is telemetry, not inventory evidence: it varies between
    # otherwise-identical runs and must stay out of the hashed report so the
    # checksum stays reproducible for the same candidate (FAN-3649).
    duration = round(time.monotonic() - started, 3)
    if duration > args.max_duration_seconds:
        errors.append(f"coverage measurement exceeded budget: {duration}s > {args.max_duration_seconds}s")
    payload = {
        "schema_version": 1,
        "measurement": "executable_test_inventory",
        "excluded_path_parts": sorted(EXCLUDED_PATH_PARTS),
        "baseline": baseline,
        "groups": groups,
        "max_duration_seconds": args.max_duration_seconds,
        "status": "passed" if not errors else "failed",
        "errors": errors,
    }
    if args.json_report:
        _write_json(args.json_report, payload)
    if args.markdown_report:
        _write_markdown(args.markdown_report, payload)
    for error in errors:
        print(f"COVERAGE FAIL: {error}", file=sys.stderr)
    print(f"TEST COVERAGE {payload['status'].upper()}: {duration}s", flush=True)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
