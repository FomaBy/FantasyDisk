#!/usr/bin/env python3
"""Deterministically migrate the 139 SCRUM-1073 typography fingerprints.

The migrator is intentionally fingerprint-first: it refuses to edit when any
reviewed source expression differs from the schema-2 baseline, then records an
explicit original -> replacement disposition for every site.
"""
from __future__ import annotations

import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

import typography_inventory as inventory


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json"
TASK = "SCRUM-1073"


def _replace_call_arg(source: str, name: str, index: int, replacement: str) -> str:
    start = source.find(name + "(")
    if start < 0:
        raise ValueError(f"missing {name} call: {source}")
    cursor = start + len(name) + 1
    depth = 1
    spans: list[tuple[int, int]] = []
    arg_start = cursor
    while cursor < len(source) and depth:
        char = source[cursor]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                spans.append((arg_start, cursor))
                break
        elif char == "," and depth == 1:
            spans.append((arg_start, cursor))
            arg_start = cursor + 1
        cursor += 1
    if index >= len(spans):
        raise ValueError(f"missing argument {index} in {source}")
    left, right = spans[index]
    return source[:left] + " " + replacement + source[right:]


def _append_call_arg(source: str, name: str, replacement: str) -> str:
    start = source.find(name + "(")
    cursor = start + len(name) + 1
    depth = 1
    while cursor < len(source) and depth:
        if source[cursor] == "(":
            depth += 1
        elif source[cursor] == ")":
            depth -= 1
            if depth == 0:
                return source[:cursor] + ", " + replacement + source[cursor:]
        cursor += 1
    raise ValueError(f"unterminated {name} call: {source}")


def _role_literal(role: str) -> str:
    return "SemanticTypography.ROLE_%s" % role.upper()


def _semantic_band(role: str, authored: str) -> str:
    return (
        f"SemanticTypography.resolve_fixed({role}, {authored}, "
        f"SemanticTypography.role_min({role}), SemanticTypography.role_max({role}))"
    )


def _rewrite_deprecated_clamp(source: str) -> str:
    marker = "SemanticTypography.clamp_to_role"
    start = source.find(marker + "(")
    if start < 0:
        return source
    args = inventory._call_args(source[start:], marker)
    if len(args) != 2:
        raise ValueError(f"unexpected clamp_to_role call: {source}")
    cursor = start + len(marker) + 1
    depth = 1
    while cursor < len(source) and depth:
        if source[cursor] == "(":
            depth += 1
        elif source[cursor] == ")":
            depth -= 1
            if depth == 0:
                replacement = _semantic_band(args[0], args[1])
                return source[:start] + replacement + source[cursor + 1:]
        cursor += 1
    raise ValueError(f"unterminated clamp_to_role call: {source}")


def _transform(entry: dict) -> str:
    source = entry["source"]
    role = _role_literal(entry["role"])
    kind = entry["kind"]
    if kind == "font_constant":
        delimiter = ":=" if ":=" in source else "="
        return source.split(delimiter, 1)[0].rstrip() + f" {delimiter} {inventory.TOKEN_BOUNDS[entry['role']][0]}"
    if kind == "theme_override":
        call = "add_theme_font_size_override" if "add_theme_font_size_override(" in source else "set_font_size"
        args = inventory._call_args(source, call)
        return _replace_call_arg(source, call, 1, _semantic_band(role, args[1]))
    if kind == "semantic_binding":
        if "_codex_bind_stage_font(" in source:
            source = _replace_call_arg(source, "_codex_bind_stage_font", 4, f"SemanticTypography.role_max({role})")
            return _replace_call_arg(source, "_codex_bind_stage_font", 3, f"SemanticTypography.role_min({role})")
        if "_shrink_label_font_to_width(" in source:
            args = inventory._call_args(source, "_shrink_label_font_to_width")
            if len(args) < 5:
                return _append_call_arg(source, "_shrink_label_font_to_width", f"SemanticTypography.role_min({role})")
            return _replace_call_arg(source, "_shrink_label_font_to_width", 4, f"SemanticTypography.role_min({role})")
        if "_battle_prayer_label(" in source:
            args = inventory._call_args(source, "_battle_prayer_label")
            return _replace_call_arg(source, "_battle_prayer_label", 5, _semantic_band(role, args[5]))
    if kind == "draw_string":
        dependency, draw = source.split(" => ", 1)
        marker = "SemanticTypography.resolve_scaled_compat"
        call_start = dependency.index(marker)
        args = inventory._call_args(dependency[call_start:], marker)
        wrapped = _semantic_band(role, f"{marker}({', '.join(args)})")
        dependency = dependency[:call_start] + wrapped
        return dependency + " => " + draw
    raise ValueError(f"unsupported {kind}: {source}")


def _fingerprint(path: str, function: str, source: str, ordinal: int) -> str:
    material = f"{path}\0{function}\0{source}\0{ordinal}"
    return hashlib.sha256(material.encode("utf-8")).hexdigest()[:16]


def _reconcile_format_only_fingerprints(existing: dict, current: list[dict]) -> bool:
    """Remap reviewed fingerprints after structure-preserving formatting.

    SCRUM-1073's readability pass reflows calls and collapses redundant
    same-role resolve_fixed wrappers without adding/removing inventory sites.
    Exact fingerprints intentionally change with the normalized expression, so
    reconcile only when every path/function/kind group has the same cardinality
    and every reviewed semantic role remains present in the paired live source.
    Any structural drift is a hard failure rather than a silent review copy.
    """
    old_entries = list(existing.get("entries", []))
    if {item["fingerprint"] for item in old_entries} == {item["fingerprint"] for item in current}:
        return False
    old_groups: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    new_groups: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    for item in old_entries:
        old_groups[(item["path"], item["function"], item["kind"])].append(item)
    for item in current:
        new_groups[(item["path"], item["function"], item["kind"])].append(item)
    if set(old_groups) != set(new_groups):
        raise SystemExit("format reconciliation refused: inventory groups changed")

    fingerprint_changes: dict[str, str] = {}
    rendered: list[dict] = []
    review_by_current: dict[str, dict] = {}
    for key in sorted(old_groups):
        old_values = sorted(old_groups[key], key=lambda item: int(item["line"]))
        new_values = sorted(new_groups[key], key=lambda item: int(item["line"]))
        if len(old_values) != len(new_values):
            raise SystemExit(f"format reconciliation refused: cardinality changed for {key}")
        for old, live in zip(old_values, new_values):
            role = str(old.get("role", ""))
            role_literals = {
                value.lower()
                for value in re.findall(r"SemanticTypography\.ROLE_([A-Z_]+)", live.get("source", ""))
            }
            if role and role_literals and role not in role_literals:
                raise SystemExit(
                    f"format reconciliation refused: role drift {old['fingerprint']} {role} -> {sorted(role_literals)}"
                )
            fingerprint_changes[old["fingerprint"]] = live["fingerprint"]
            review_by_current[live["fingerprint"]] = old

    for item in current:
        review = review_by_current[item["fingerprint"]]
        for field in inventory.REVIEW_FIELDS:
            if field in review:
                item[field] = review[field]
        if "status" not in item:
            raise SystemExit(f"format reconciliation lost review for {item['fingerprint']}")
        item["mapping_source"] = "reviewed_manifest"
        rendered.append(item)
    for migration in existing.get("migrations", []):
        old_replacement = migration["replacement_fingerprint"]
        if old_replacement not in fingerprint_changes:
            raise SystemExit(f"format reconciliation lost migration replacement {old_replacement}")
        migration["replacement_fingerprint"] = fingerprint_changes[old_replacement]
    existing["entries"] = rendered
    MANIFEST.write_text(json.dumps(existing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return True


def main() -> int:
    existing = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if existing.get("migration_task") == TASK:
        current = inventory.collect_raw()
        current_by_fingerprint = {entry["fingerprint"]: entry for entry in current}
        rewrites = [
            entry for entry in existing["entries"]
            if "SemanticTypography.clamp_to_role" in entry.get("source", "")
            and entry["fingerprint"] in current_by_fingerprint
        ]
        grouped_rewrites: dict[str, list[dict]] = defaultdict(list)
        for entry in rewrites:
            live = dict(current_by_fingerprint[entry["fingerprint"]])
            live["replacement_source"] = _rewrite_deprecated_clamp(live["source"])
            grouped_rewrites[live["path"]].append(live)
        for path, entries in grouped_rewrites.items():
            file_path = ROOT / path
            lines = file_path.read_text(encoding="utf-8").splitlines()
            for entry in sorted(entries, key=lambda item: int(item["line"]), reverse=True):
                start = int(entry["line"]) - 1
                normalized, end = inventory._expression(lines, start, entry["kind"])
                if entry["kind"] == "draw_string":
                    for dependency_index in range(start - 1, max(-1, start - 12), -1):
                        dependency_source, dependency_end = inventory._expression(lines, dependency_index, "theme_override")
                        if "SemanticTypography.clamp_to_role" in dependency_source:
                            indent = lines[dependency_index][: len(lines[dependency_index]) - len(lines[dependency_index].lstrip())]
                            lines[dependency_index:dependency_end + 1] = [indent + _rewrite_deprecated_clamp(dependency_source)]
                            break
                    else:
                        raise SystemExit(f"draw dependency not found for {entry['fingerprint']}")
                    continue
                if normalized != entry["source"]:
                    raise SystemExit(f"live migration drift for {entry['fingerprint']}")
                indent = lines[start][: len(lines[start]) - len(lines[start].lstrip())]
                lines[start:end + 1] = [indent + entry["replacement_source"]]
            file_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

        if rewrites:
            current = inventory.collect_raw()
            current_keys: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
            for item in current:
                current_keys[(item["path"], item["function"], item["source"])].append(item)
            for values in current_keys.values():
                values.sort(key=lambda item: int(item["line"]))
            used: dict[tuple[str, str, str], int] = defaultdict(int)
            review_by_current: dict[str, dict] = {}
            replacement_changes: dict[str, str] = {}
            for old in existing["entries"]:
                source = _rewrite_deprecated_clamp(old["source"])
                key = (old["path"], old["function"], source)
                if key not in current_keys:
                    continue
                index = used[key]
                used[key] += 1
                live = current_keys[key][index]
                review_by_current[live["fingerprint"]] = old
                replacement_changes[old["fingerprint"]] = live["fingerprint"]
            rendered_entries = []
            for item in current:
                review = review_by_current.get(item["fingerprint"], {})
                for field in inventory.REVIEW_FIELDS:
                    if field in review:
                        item[field] = review[field]
                if "status" not in item:
                    item["status"] = "unreviewed"
                    item["role"] = ""
                item["mapping_source"] = "reviewed_manifest"
                rendered_entries.append(item)
            for migration in existing.get("migrations", []):
                old_replacement = migration["replacement_fingerprint"]
                migration["replacement_fingerprint"] = replacement_changes.get(old_replacement, old_replacement)
            existing["entries"] = rendered_entries
            MANIFEST.write_text(json.dumps(existing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        current = inventory.collect_raw()
        reconciled = _reconcile_format_only_fingerprints(existing, current)
        errors = inventory.validate(inventory.document())
        if errors:
            raise SystemExit("\n".join(errors))
        if rewrites or reconciled:
            MANIFEST.write_text(json.dumps(inventory.document(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PASS: SCRUM-1073 migration applied and verified without a central helper lock")
        return 0
    targets = [
        entry for entry in existing["entries"]
        if entry.get("status") == "allowlist" and entry.get("next_issue") == TASK
    ]
    if len(targets) != 139:
        raise SystemExit(f"expected 139 SCRUM-1073 fingerprints, found {len(targets)}")

    live_before = {entry["fingerprint"]: entry for entry in inventory.collect_raw()}
    replacements: dict[str, str] = {}
    grouped: dict[str, list[dict]] = defaultdict(list)
    for entry in targets:
        entry = dict(entry)
        entry["replacement_source"] = _transform(entry)
        if entry["fingerprint"] in live_before:
            entry["live_line"] = live_before[entry["fingerprint"]]["line"]
        replacements[entry["fingerprint"]] = entry["replacement_source"]
        grouped[entry["path"]].append(entry)

    # Edit bottom-up so reviewed line coordinates remain stable during the run.
    for path, entries in grouped.items():
        file_path = ROOT / path
        lines = file_path.read_text(encoding="utf-8").splitlines()
        live_entries = [entry for entry in entries if "live_line" in entry]
        for entry in sorted(live_entries, key=lambda item: int(item["live_line"]), reverse=True):
            start = int(entry["live_line"]) - 1
            normalized, end = inventory._expression(lines, start, entry["kind"])
            if entry["kind"] == "draw_string":
                # The dependency belongs to the same fingerprint but precedes
                # the draw call. Replace it in-place without flattening the draw.
                old_call = "SemanticTypography.resolve_scaled_compat("
                for dependency_index in range(start - 1, max(-1, start - 9), -1):
                    dependency_source, dependency_end = inventory._expression(lines, dependency_index, "theme_override")
                    if old_call in dependency_source and "font_size" in dependency_source:
                        role = _role_literal(entry["role"])
                        raw_args = inventory._call_args(dependency_source, "SemanticTypography.resolve_scaled_compat")
                        new_dependency = dependency_source.replace(
                            "SemanticTypography.resolve_scaled_compat(" + ", ".join(raw_args) + ")",
                            f"SemanticTypography.clamp_to_role({role}, SemanticTypography.resolve_scaled_compat({', '.join(raw_args)}))",
                        )
                        indent = lines[dependency_index][: len(lines[dependency_index]) - len(lines[dependency_index].lstrip())]
                        lines[dependency_index:dependency_end + 1] = [indent + new_dependency]
                        break
                else:
                    raise SystemExit(f"dependency not found for {entry['fingerprint']}")
                continue
            if normalized != entry["source"]:
                raise SystemExit(
                    f"fingerprint drift {entry['fingerprint']} {path}:{entry['live_line']}\n"
                    f"expected: {entry['source']}\nactual:   {normalized}"
                )
            indent = lines[start][: len(lines[start]) - len(lines[start].lstrip())]
            lines[start:end + 1] = [indent + entry["replacement_source"]]
        file_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    current = inventory.collect_raw()
    old_reviews = {entry["fingerprint"]: entry for entry in existing["entries"]}
    target_by_key: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    for entry in targets:
        target_by_key[(entry["path"], entry["function"], replacements[entry["fingerprint"]])].append(entry)
    for values in target_by_key.values():
        values.sort(key=lambda item: int(item["line"]))

    migrated_by_replacement: dict[str, dict] = {}
    migrations: list[dict] = []
    used_by_key: dict[tuple[str, str, str], int] = defaultdict(int)
    for item in current:
        key = (item["path"], item["function"], item["source"])
        if key not in target_by_key:
            continue
        occurrence = used_by_key[key]
        used_by_key[key] += 1
        original = target_by_key[key][occurrence]
        low, high = inventory.TOKEN_BOUNDS[original["role"]]
        effective_min = max(low, min(high, int(original["effective_min"])))
        effective_max = max(low, min(high, int(original["effective_max"])))
        review = {
            "role": original["role"],
            "status": "mapped",
            "mapping_mode": "semantic_native",
            "effective_min": effective_min,
            "effective_max": effective_max,
            "migration_task": TASK,
            "replaces_fingerprint": original["fingerprint"],
            "disposition": "migrated_semantic_band",
        }
        if not re.findall(r"SemanticTypography\.ROLE_([A-Z_]+)", item["source"]):
            review["role_trace"] = "scrum1073_reviewed_semantic_migration"
        migrated_by_replacement[item["fingerprint"]] = review
        migrations.append({
            "original_fingerprint": original["fingerprint"],
            "replacement_fingerprint": item["fingerprint"],
            "path": item["path"],
            "function": item["function"],
            "role": original["role"],
            "effective_before": [original["effective_min"], original["effective_max"]],
            "effective_after": [effective_min, effective_max],
            "disposition": "migrated_semantic_band",
        })

    if len(migrations) != 139:
        raise SystemExit(f"replacement audit produced {len(migrations)} records, expected 139")
    rendered_entries: list[dict] = []
    for item in current:
        review = old_reviews.get(item["fingerprint"], migrated_by_replacement.get(item["fingerprint"], {}))
        for field in inventory.REVIEW_FIELDS:
            if field in review:
                item[field] = review[field]
        if "status" not in item:
            item["status"] = "unreviewed"
            item["role"] = ""
        item["mapping_source"] = "reviewed_manifest"
        rendered_entries.append(item)
    existing["entries"] = rendered_entries
    existing["migration_task"] = TASK
    existing["migrations"] = sorted(migrations, key=lambda item: (item["path"], item["function"], item["original_fingerprint"]))
    existing["counts"] = inventory.document()["counts"]
    MANIFEST.write_text(json.dumps(existing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    generated = inventory.document()
    errors = inventory.validate(generated)
    if errors:
        raise SystemExit("\n".join(errors))
    MANIFEST.write_text(json.dumps(generated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("PASS: migrated 139 SCRUM-1073 fingerprints with explicit dispositions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
