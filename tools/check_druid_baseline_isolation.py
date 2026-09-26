#!/usr/bin/env python3
"""FAN-3383: guards a Druid-only rebuild of the 51-row ultimate effectiveness
baseline against the FAN-2665 defect, where a full-file regeneration silently
changed an unrelated `doctor/restore_potion` row.

This compares the reassembled baseline row-by-row, keyed by
`class_id/weapon_id`, against a known-good base revision. It reads per-class
shards when present and falls back to the legacy monolith for pre-migration
refs. Only the scoped class's rows may differ; any other row that moved is
reported as a violation. It is a pure data diff — no Godot run is needed, so
it is immune to any live-measurement noise in unrelated classes.

`--class` scopes the guard to whichever class-conversion card is in flight
(FAN-2533 reuses it for `guitarist`); it defaults to the Druid scope it shipped
with.

Usage:
    python3 tools/check_druid_baseline_isolation.py --base origin/dev
    python3 tools/check_druid_baseline_isolation.py --base origin/dev --class guitarist
    python3 tools/check_druid_baseline_isolation.py --base <sha> --path build/ultimate_effectiveness_baseline.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

DEFAULT_PATH = "build/ultimate_effectiveness_baseline.json"
DEFAULT_SHARD_DIR = "build/effectiveness"
ENVELOPE_NAME = "_envelope.json"
PUBLIC_ENVELOPE_KEYS = (
    "schema_version", "label", "scenario_ids", "metric_keys", "tolerances",
)
ALLOWED_DRIFT_CLASS = "druid"


def rows_by_key(document: dict) -> dict[str, dict]:
    return {str(row.get("key", "")): row for row in document.get("rows", [])}


def split_document(document: dict) -> tuple[dict, list[dict]]:
    """Returns the private ordering envelope and canonical per-class shards."""
    rows = document.get("rows")
    if not isinstance(rows, list):
        raise ValueError("baseline.rows_type: rows must be a list")
    class_ids: list[str] = []
    row_keys: list[str] = []
    rows_by_class: dict[str, list[dict]] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("baseline.row_type: rows must be objects")
        class_id = str(row.get("class_id", ""))
        key = str(row.get("key", ""))
        if not class_id or not key:
            raise ValueError("baseline.row_identity: every row needs class_id and key")
        if class_id not in rows_by_class:
            class_ids.append(class_id)
            rows_by_class[class_id] = []
        rows_by_class[class_id].append(row)
        row_keys.append(key)
    envelope = {key: document[key] for key in PUBLIC_ENVELOPE_KEYS if key in document}
    envelope["class_ids"] = class_ids
    envelope["row_keys"] = row_keys
    shards = [
        {"class_id": class_id, "rows": rows_by_class[class_id]}
        for class_id in class_ids
    ]
    return envelope, shards


def assemble_shards(envelope: dict, shards: list[dict]) -> dict:
    """Validates ownership boundaries and reassembles the public document."""
    class_ids = envelope.get("class_ids")
    row_keys = envelope.get("row_keys")
    if not isinstance(class_ids, list) or not class_ids:
        raise ValueError("baseline.class_ids: envelope must list canonical classes")
    if not isinstance(row_keys, list) or not row_keys:
        raise ValueError("baseline.row_keys: envelope must list canonical rows")
    expected_classes = {str(class_id) for class_id in class_ids}
    if len(expected_classes) != len(class_ids) or "" in expected_classes:
        raise ValueError("baseline.class_id_duplicate: class_ids must be unique and non-empty")

    seen_classes: set[str] = set()
    rows: dict[str, dict] = {}
    for shard in shards:
        if not isinstance(shard, dict):
            raise ValueError("baseline.shard_type: every shard must be an object")
        class_id = str(shard.get("class_id", ""))
        file_class_id = str(shard.get("_file_class_id", class_id))
        if class_id not in expected_classes:
            raise ValueError(f"baseline.class_unknown: {class_id}")
        if file_class_id != class_id:
            raise ValueError(
                f"baseline.class_file_mismatch: {file_class_id} contains {class_id}"
            )
        if class_id in seen_classes:
            raise ValueError(f"baseline.class_duplicate: {class_id}")
        seen_classes.add(class_id)
        shard_rows = shard.get("rows")
        if not isinstance(shard_rows, list):
            raise ValueError(f"baseline.rows_type: {class_id} rows must be a list")
        for row in shard_rows:
            if not isinstance(row, dict):
                raise ValueError(
                    f"baseline.row_type: {class_id} shard contains a non-object row"
                )
            key = str(row.get("key", ""))
            row_class_id = str(row.get("class_id", ""))
            if row_class_id != class_id:
                raise ValueError(
                    f"baseline.row_cross_class: {key} belongs to {row_class_id}, not {class_id}"
                )
            if key in rows:
                raise ValueError(f"baseline.row_duplicate: {key}")
            rows[key] = row

    missing_classes = [str(class_id) for class_id in class_ids if str(class_id) not in seen_classes]
    if missing_classes:
        raise ValueError(f"baseline.class_missing: {', '.join(missing_classes)}")
    if len(set(map(str, row_keys))) != len(row_keys):
        raise ValueError("baseline.row_key_duplicate: row_keys must be unique")
    missing_rows = [str(key) for key in row_keys if str(key) not in rows]
    if missing_rows:
        raise ValueError(f"baseline.row_missing: {', '.join(missing_rows)}")
    unknown_rows = sorted(set(rows) - set(map(str, row_keys)))
    if unknown_rows:
        raise ValueError(f"baseline.row_unknown: {', '.join(unknown_rows)}")

    document = {key: envelope[key] for key in PUBLIC_ENVELOPE_KEYS if key in envelope}
    document["rows"] = [rows[str(key)] for key in row_keys]
    return document


def find_non_druid_drift(
    base_rows: dict[str, dict],
    candidate_rows: dict[str, dict],
    allowed_class: str = ALLOWED_DRIFT_CLASS,
) -> list[str]:
    """Returns one message per non-`allowed_class` row that differs, is
    missing, or was added between `base_rows` and `candidate_rows`."""
    violations: list[str] = []
    for key, base_row in base_rows.items():
        if str(base_row.get("class_id", "")) == allowed_class:
            continue
        if key not in candidate_rows:
            violations.append(f"row.missing: {key} present in base, absent from candidate")
            continue
        if candidate_rows[key] != base_row:
            violations.append(f"row.drifted: {key} changed outside the {allowed_class} scope")
    for key, candidate_row in candidate_rows.items():
        if key in base_rows:
            continue
        if str(candidate_row.get("class_id", "")) != allowed_class:
            violations.append(f"row.unexpected: {key} is new and outside the {allowed_class} scope")
    return violations


def _git_show(ref: str, path: str) -> dict:
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def _git_has_path(ref: str, path: str) -> bool:
    result = subprocess.run(
        ["git", "cat-file", "-e", f"{ref}:{path}"],
        capture_output=True, check=False,
    )
    return result.returncode == 0


def _git_document(ref: str, legacy_path: str, shard_dir: str) -> dict:
    envelope_path = f"{shard_dir}/{ENVELOPE_NAME}"
    if not _git_has_path(ref, envelope_path):
        return _git_show(ref, legacy_path)
    envelope = _git_show(ref, envelope_path)
    result = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", ref, "--", shard_dir],
        capture_output=True, text=True, check=True,
    )
    shards: list[dict] = []
    for path in result.stdout.splitlines():
        if not path.endswith(".json") or path == envelope_path:
            continue
        shard = _git_show(ref, path)
        shard["_file_class_id"] = Path(path).stem
        shards.append(shard)
    return assemble_shards(envelope, shards)


def _working_document(legacy_path: str, shard_dir: str) -> dict:
    envelope_path = Path(shard_dir) / ENVELOPE_NAME
    if not envelope_path.is_file():
        return json.loads(Path(legacy_path).read_text(encoding="utf-8"))
    envelope = json.loads(envelope_path.read_text(encoding="utf-8"))
    shards: list[dict] = []
    for path in sorted(Path(shard_dir).glob("*.json")):
        if path.name == ENVELOPE_NAME:
            continue
        shard = json.loads(path.read_text(encoding="utf-8"))
        shard["_file_class_id"] = path.stem
        shards.append(shard)
    return assemble_shards(envelope, shards)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="git ref holding the known-good baseline")
    parser.add_argument("--path", default=DEFAULT_PATH, help="repo-relative path to the baseline JSON")
    parser.add_argument(
        "--shard-dir", default=DEFAULT_SHARD_DIR,
        help="repo-relative directory holding _envelope.json and class shards",
    )
    parser.add_argument(
        "--class", dest="allowed_class", default=ALLOWED_DRIFT_CLASS,
        help="the only class_id whose rows may differ",
    )
    args = parser.parse_args()

    try:
        base_document = _git_document(args.base, args.path, args.shard_dir)
        candidate_document = _working_document(args.path, args.shard_dir)
    except (json.JSONDecodeError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"check_druid_baseline_isolation: FAIL ({error})", file=sys.stderr)
        return 1

    violations = find_non_druid_drift(
        rows_by_key(base_document), rows_by_key(candidate_document), args.allowed_class
    )
    if violations:
        for violation in violations:
            print(f"check_druid_baseline_isolation: {violation}", file=sys.stderr)
        print(f"check_druid_baseline_isolation: FAIL ({len(violations)} violation(s))", file=sys.stderr)
        return 1

    print(f"check_druid_baseline_isolation: PASS (no row drift outside {args.allowed_class})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
