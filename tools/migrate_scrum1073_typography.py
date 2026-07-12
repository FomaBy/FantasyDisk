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
from copy import deepcopy
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


def _gdscript_expression_tokens(source: str) -> tuple[str, ...]:
    """Tokenize an inventory expression with conservative whitespace handling.

    This is intentionally smaller than a GDScript parser: it preserves quoted
    strings byte-for-byte, groups identifiers and numbers, recognizes common
    contiguous operators, and keeps every other punctuation character. Only
    leading/trailing and delimiter-adjacent whitespace around `()[]{},` is
    ignored. Ambiguous whitespace near operators, literals, identifiers,
    StringName/NodePath prefixes, `$`/`%` paths or annotations is retained as a
    token and therefore fails closed.
    """
    tokens: list[str] = []
    index = 0
    multi_operators = (
        "**=", "<<=", ">>=", "==", "!=", "<=", ">=", "->", ":=",
        "&&", "||", "+=", "-=", "*=", "/=", "%=", "**", "<<", ">>",
    )
    safe_whitespace_delimiters = frozenset("()[]{},")
    while index < len(source):
        char = source[index]
        if char.isspace():
            start = index
            while index < len(source) and source[index].isspace():
                index += 1
            previous = source[start - 1] if start > 0 else ""
            following = source[index] if index < len(source) else ""
            if previous and following and not (
                previous in safe_whitespace_delimiters
                or following in safe_whitespace_delimiters
            ):
                tokens.append("whitespace")
            continue
        if char in {'"', "'"}:
            quote = char
            start = index
            index += 1
            escaped = False
            while index < len(source):
                current = source[index]
                index += 1
                if escaped:
                    escaped = False
                elif current == "\\":
                    escaped = True
                elif current == quote:
                    break
            else:
                raise ValueError("unterminated string in typography expression")
            tokens.append("string:" + source[start:index])
            continue
        if char.isalpha() or char == "_":
            start = index
            index += 1
            while index < len(source) and (source[index].isalnum() or source[index] == "_"):
                index += 1
            tokens.append("identifier:" + source[start:index])
            continue
        if char.isdigit() or (char == "." and index + 1 < len(source) and source[index + 1].isdigit()):
            start = index
            if char == ".":
                index += 1
                while index < len(source) and (source[index].isdigit() or source[index] == "_"):
                    index += 1
            elif source.startswith(("0x", "0X"), index):
                index += 2
                while index < len(source) and (source[index] in "0123456789abcdefABCDEF_"):
                    index += 1
            elif source.startswith(("0b", "0B"), index):
                index += 2
                while index < len(source) and source[index] in "01_":
                    index += 1
            else:
                while index < len(source) and (source[index].isdigit() or source[index] == "_"):
                    index += 1
                if (
                    index + 1 < len(source)
                    and source[index] == "."
                    and source[index + 1].isdigit()
                ):
                    index += 1
                    while index < len(source) and (source[index].isdigit() or source[index] == "_"):
                        index += 1
            if index < len(source) and source[index] in "eE":
                exponent = index + 1
                if exponent < len(source) and source[exponent] in "+-":
                    exponent += 1
                digit_start = exponent
                while exponent < len(source) and (source[exponent].isdigit() or source[exponent] == "_"):
                    exponent += 1
                if exponent > digit_start:
                    index = exponent
            tokens.append("number:" + source[start:index])
            continue
        operator = next((value for value in multi_operators if source.startswith(value, index)), "")
        if operator:
            tokens.append("operator:" + operator)
            index += len(operator)
            continue
        tokens.append("punctuation:" + char)
        index += 1
    return tuple(tokens)


def _reconcile_token_equivalent_fingerprints(existing: dict, current: list[dict]) -> tuple[dict, bool]:
    """Return a reviewed live candidate only for token-identical expressions."""
    reviewed_entries = list(existing.get("entries", []))
    reviewed_groups: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    live_groups: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    for item in reviewed_entries:
        reviewed_groups[(item["path"], item["function"], item["kind"])].append(item)
    for item in current:
        live_groups[(item["path"], item["function"], item["kind"])].append(item)
    if set(reviewed_groups) != set(live_groups):
        raise SystemExit("live typography snapshot groups changed; refusing to rewrite the reviewed manifest")

    fingerprint_changes: dict[str, str] = {}
    review_by_live: dict[str, dict] = {}
    changed = False
    for key in reviewed_groups:
        reviewed_values = sorted(reviewed_groups[key], key=lambda item: int(item["line"]))
        live_values = sorted(live_groups[key], key=lambda item: int(item["line"]))
        if len(reviewed_values) != len(live_values):
            raise SystemExit(
                f"live typography snapshot cardinality changed for {key}; "
                "refusing to rewrite the reviewed manifest"
            )
        for reviewed, live in zip(reviewed_values, live_values):
            try:
                reviewed_tokens = _gdscript_expression_tokens(str(reviewed.get("source", "")))
                live_tokens = _gdscript_expression_tokens(str(live.get("source", "")))
            except ValueError as error:
                raise SystemExit(f"typography tokenization failed for {key}: {error}") from error
            if reviewed_tokens != live_tokens:
                raise SystemExit(
                    f"live typography expression is not token-equivalent for {key}; "
                    "refusing to rewrite the reviewed manifest"
                )
            old_fingerprint = str(reviewed.get("fingerprint", ""))
            live_fingerprint = str(live.get("fingerprint", ""))
            fingerprint_changes[old_fingerprint] = live_fingerprint
            review_by_live[live_fingerprint] = reviewed
            changed = changed or old_fingerprint != live_fingerprint

    candidate = deepcopy(existing)
    rendered_entries: list[dict] = []
    for item in current:
        review = review_by_live.get(str(item.get("fingerprint", "")))
        if review is None:
            raise SystemExit(
                f"live typography fingerprint {item.get('fingerprint', '')} lost its reviewed identity; "
                "refusing to rewrite the reviewed manifest"
            )
        rendered = dict(item)
        for field in inventory.REVIEW_FIELDS:
            if field in review:
                rendered[field] = review[field]
        if "status" not in rendered or "role" not in rendered:
            raise SystemExit(
                f"live typography fingerprint {item.get('fingerprint', '')} lost review metadata; "
                "refusing to rewrite the reviewed manifest"
            )
        rendered["mapping_source"] = "reviewed_manifest"
        rendered_entries.append(rendered)
    candidate["entries"] = rendered_entries
    for migration in candidate.get("migrations", []):
        old_replacement = str(migration.get("replacement_fingerprint", ""))
        if old_replacement not in fingerprint_changes:
            raise SystemExit(
                f"migration replacement {old_replacement} lost its reviewed identity; "
                "refusing to rewrite the reviewed manifest"
            )
        migration["replacement_fingerprint"] = fingerprint_changes[old_replacement]
    return candidate, changed


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
            candidate = deepcopy(existing)
            candidate["entries"] = rendered_entries
            for migration in candidate.get("migrations", []):
                old_replacement = migration["replacement_fingerprint"]
                migration["replacement_fingerprint"] = replacement_changes.get(old_replacement, old_replacement)
            existing = candidate
        current = inventory.collect_raw()
        candidate, reconciled = _reconcile_token_equivalent_fingerprints(existing, current)
        errors = inventory.validate(candidate)
        if errors:
            raise SystemExit("\n".join(errors))
        if rewrites or reconciled:
            MANIFEST.write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
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
