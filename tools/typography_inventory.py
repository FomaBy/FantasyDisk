#!/usr/bin/env python3
"""Generate/check the SCRUM-1061 player-facing font override inventory.

Fingerprints intentionally exclude line numbers. They combine repository path,
enclosing function, normalized source and same-source ordinal, so harmless line
movement stays stable while a changed typography assignment requires review.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json"
GD_PATTERNS = {
    "semantic_binding": re.compile(
        r"(?:_codex_bind_stage_font|_battle_prayer_label|_shrink_label_font_to_width)\s*\("
    ),
    "theme_override": re.compile(r"(?:add_theme_font_size_override|set_font_size)\s*\("),
    "draw_string": re.compile(r"draw_string\s*\("),
    "font_constant": re.compile(r"^const\s+[A-Za-z0-9_]*FONT_SIZE[A-Za-z0-9_]*\s*:?="),
}
RESOURCE_PATTERN = re.compile(
    r"(?:^|/)(?:font_size|font_sizes/[A-Za-z0-9_]+|theme_override_font_sizes/[A-Za-z0-9_]+)\s*="
)
FUNCTION = re.compile(r"^func\s+([A-Za-z0-9_]+)\s*\(")
SKIP = {
    "scripts/dev_console.gd",  # developer-only console, not player-facing UI
    "scripts/ui/semantic_typography.gd",  # token implementation, not a consumer
}
VALID_ROLES = {
    "display", "title", "section", "body", "description", "action",
    "tab", "field", "value", "tooltip", "caption", "hud",
}
TOKEN_BOUNDS = {
    "display": (32, 72), "title": (24, 54), "section": (20, 34),
    "body": (16, 24), "description": (14, 22), "action": (16, 34),
    "tab": (16, 28), "field": (16, 28), "value": (16, 28),
    "tooltip": (18, 24), "caption": (12, 18), "hud": (14, 34),
}
REVIEW_FIELDS = (
    "role", "status", "mapping_mode", "range_contract", "effective_min",
    "effective_max", "role_trace", "owner", "reason", "next_issue",
)
DYNAMIC_HELPER_FUNCTIONS = {
    "_codex_bind_stage_font", "_codex_refresh_stage_fonts",
    "_battle_prayer_label", "_shrink_label_font_to_width",
}
SEMANTIC_ROLE_EXPECTATIONS = {
    "carousel_counter_label.add_theme": "value",
    "stat_value.add_theme": "value",
    "selected_class_label.add_theme": "title",
    "qmark.add_theme": "hud",
    "deadzone_value.add_theme": "value",
    "BattleRewardAction": "action",
    "CombatTimerLabel": "hud",
    "Hud%sLabel": "hud",
    "value.add_theme_font_size_override(\"font_size\", _readable_font_size(SemanticTypography.ROLE_VALUE, 15)": "value",
}
SOURCE_SEMANTIC_PATTERNS = {
    r'find_children\("DerivedGroupTitle_.*?ROLE_SECTION': "Pause derived group titles",
    r'find_children\("BaseStatName_.*?ROLE_FIELD': "Pause base stat names",
    r'find_children\("BaseStatValue_.*?ROLE_VALUE': "Pause base stat values",
    r'find_children\("SurvivalStatName_.*?ROLE_FIELD': "Pause survival stat names",
    r'find_children\("SurvivalStatValue_.*?ROLE_VALUE': "Pause survival stat values",
    r'find_children\("DerivedStatName_.*?ROLE_FIELD': "Pause derived stat names",
    r'find_children\("DerivedStatValue_.*?ROLE_VALUE': "Pause derived stat values",
    r'deadzone_value\.add_theme_font_size_override.*?ROLE_VALUE': "Settings deadzone value",
    r'action\.add_theme_font_size_override.*?ROLE_ACTION': "Reward-card action labels",
    r'CombatTimerLabel.*?ROLE_HUD': "Combat timer",
    r'Hud%sLabel.*?ROLE_HUD': "Combat HUD bar labels",
    r'CombatIntroBannerLabel.*?ROLE_DISPLAY': "Combat title banner",
    r'AtlasSelectedClassLabel.*?ROLE_TITLE': "Atlas selected-class title",
    r'qmark\.add_theme_font_size_override.*?ROLE_HUD': "Atlas hidden-node question mark",
}


def _entry(path: str, function: str, line_number: int, normalized: str, ordinal: int, kind: str) -> dict:
    material = f"{path}\0{function}\0{normalized}\0{ordinal}"
    entry = {
        "fingerprint": hashlib.sha256(material.encode("utf-8")).hexdigest()[:16],
        "path": path,
        "function": function,
        "line": line_number,
        "kind": kind,
        "source": normalized,
    }
    return entry


def _expression(lines: list[str], start: int, kind: str) -> tuple[str, int]:
    if kind == "font_constant":
        return " ".join(lines[start].strip().split()), start
    parts = [lines[start].strip()]
    balance = lines[start].count("(") - lines[start].count(")")
    end = start
    while balance > 0 and end + 1 < len(lines):
        end += 1
        parts.append(lines[end].strip())
        balance += lines[end].count("(") - lines[end].count(")")
    return " ".join(" ".join(parts).split()), end


def _call_args(source: str, name: str) -> list[str]:
    start = source.find(name + "(")
    if start < 0:
        return []
    index = start + len(name) + 1
    depth = 1
    current: list[str] = []
    args: list[str] = []
    while index < len(source) and depth:
        char = source[index]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                break
        if char == "," and depth == 1:
            args.append("".join(current).strip())
            current = []
        else:
            current.append(char)
        index += 1
    args.append("".join(current).strip())
    return args


def _number(value: str) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _godot_round(value: float) -> int:
    return math.floor(value + 0.5)


def _inferred_bounds(item: dict) -> tuple[int, int] | None:
    source = item.get("source", "")
    args = _call_args(source, "_readable_font_size")
    if len(args) >= 2:
        base = _number(args[1])
        minimum = _number(args[2]) if len(args) > 2 else 0.0
        maximum = _number(args[3]) if len(args) > 3 else 96.0
        if base is not None and minimum is not None and maximum is not None:
            values = []
            for scale in (1.32, 1.45):
                value = _godot_round(base * scale)
                if minimum > 0:
                    value = max(value, int(minimum))
                if maximum > 0:
                    value = min(value, int(maximum))
                values.append(value)
            return min(values), max(values)
    args = _call_args(source, "_settings_v6_font")
    if len(args) >= 2:
        design = _number(args[1])
        if design is not None:
            # Settings clamps column scale to 0.55 .. (920*1.05)/1276.
            max_scale = (920.0 * 1.05) / 1276.0
            values = [max(12, _godot_round(design * scale)) for scale in (0.55, max_scale)]
            return min(values), max(values)
    if item.get("kind") == "semantic_binding":
        if "_codex_bind_stage_font" in source:
            args = _call_args(source, "_codex_bind_stage_font")
            if len(args) >= 5 and _number(args[-2]) is not None and _number(args[-1]) is not None:
                return int(float(args[-2])), int(float(args[-1]))
        if "_battle_prayer_label" in source:
            if item.get("function") == "show_battle_prayer_choice":
                return (24, 24) if item.get("role") == "title" else (15, 15)
            return {"title": (12, 14), "description": (12, 12), "action": (11, 11)}.get(item.get("role"))
        if "_shrink_label_font_to_width" in source:
            return {"title": (12, 26), "body": (12, 20), "hud": (12, 16)}.get(item.get("role"))
    if item.get("path") == "scripts/ui_icon_registry.gd" and "display_size.x >= 55.0" in source:
        return 16, 18
    if item.get("function") == "_layout_shop_gold_shell":
        lhs = source.split(".add_theme_font_size_override", 1)[0].strip()
        return {"title": (24, 46), "subtitle": (12, 22), "tooltip_text": (11, 17), "back": (20, 30)}.get(lhs)
    return None


def collect_raw() -> list[dict]:
    entries: list[dict] = []
    for file_path in sorted((ROOT / "scripts").rglob("*.gd")):
        path = file_path.relative_to(ROOT).as_posix()
        if path in SKIP or "/dev/" in path:
            continue
        function = "<class>"
        seen: dict[tuple[str, str], int] = {}
        lines = file_path.read_text(encoding="utf-8").splitlines()
        index = 0
        while index < len(lines):
            line = lines[index]
            match = FUNCTION.match(line.strip())
            if match:
                function = match.group(1)
            elif line and not line[0].isspace():
                function = "<class>"
            stripped = line.strip()
            kind = next((name for name, pattern in GD_PATTERNS.items() if pattern.search(stripped)), "")
            # Inventory the semantic consumer calls, not the generic helper
            # implementation. Otherwise a changed call-site role would leave a
            # misleading BODY fingerprint untouched.
            if kind == "semantic_binding" and (stripped.startswith("func ") or stripped.startswith("#")):
                kind = ""
            if kind == "theme_override" and function in DYNAMIC_HELPER_FUNCTIONS:
                kind = ""
            if not kind:
                index += 1
                continue
            normalized, end = _expression(lines, index, kind)
            if kind == "draw_string" and "font_size" in normalized:
                for dependency_index in range(index - 1, max(-1, index - 9), -1):
                    dependency = lines[dependency_index].strip()
                    if re.search(r"\bfont_size\s*:?=", dependency):
                        dependency_source, _ = _expression(lines, dependency_index, kind)
                        normalized = "%s => %s" % (dependency_source, normalized)
                        break
            key = (function, normalized)
            ordinal = seen.get(key, 0)
            seen[key] = ordinal + 1
            entries.append(_entry(path, function, index + 1, normalized, ordinal, kind))
            index = end + 1
    for suffix in ("*.tscn", "*.tres", "*.theme"):
        for file_path in sorted(ROOT.rglob(suffix)):
            if ".godot" in file_path.parts or "build" in file_path.parts:
                continue
            path = file_path.relative_to(ROOT).as_posix()
            seen: dict[str, int] = {}
            for line_number, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), 1):
                if not RESOURCE_PATTERN.search(line.strip()):
                    continue
                normalized = " ".join(line.strip().split())
                ordinal = seen.get(normalized, 0)
                seen[normalized] = ordinal + 1
                entries.append(_entry(path, "<resource>", line_number, normalized, ordinal, "resource_override"))
    return entries


def _existing_reviews() -> dict[str, dict]:
    if not OUTPUT.exists():
        return {}
    parsed = json.loads(OUTPUT.read_text(encoding="utf-8"))
    return {str(item.get("fingerprint", "")): item for item in parsed.get("entries", [])}


def document() -> dict:
    reviews = _existing_reviews()
    entries = collect_raw()
    for entry in entries:
        review = reviews.get(entry["fingerprint"], {})
        for field in REVIEW_FIELDS:
            if field in review:
                entry[field] = review[field]
        if "status" not in entry:
            entry["status"] = "unreviewed"
            entry["role"] = ""
        entry["mapping_source"] = "reviewed_manifest"
    return {
        "schema": 2,
        "task": "SCRUM-1061",
        "scope": "player-facing GDScript theme overrides, explicit semantic helper bindings, draw_string calls and FONT_SIZE constants plus .tscn/.tres/.theme font overrides; generic helper implementations and developer-only scripts/dev_console.gd excluded",
        "fingerprint_contract": "sha256(path\\0function\\0normalized_full_expression\\0same_source_ordinal)[:16]",
        "roles": sorted(VALID_ROLES),
        "entries": entries,
        "counts": {
            "total": len(entries),
            "mapped": sum(item["status"] == "mapped" for item in entries),
            "allowlist": sum(item["status"] == "allowlist" for item in entries),
            "unreviewed": sum(item["status"] == "unreviewed" for item in entries),
            "draw_string": sum(item["kind"] == "draw_string" for item in entries),
            "font_constant": sum(item["kind"] == "font_constant" for item in entries),
            "semantic_binding": sum(item["kind"] == "semantic_binding" for item in entries),
            "resource_override": sum(item["kind"] == "resource_override" for item in entries),
            "semantic_native": sum(item.get("mapping_mode") == "semantic_native" for item in entries),
            "legacy_compat": sum(item.get("mapping_mode") == "legacy_compat" for item in entries),
            "routed_scrum_1068": sum(item.get("next_issue") == "SCRUM-1068" for item in entries),
            "routed_scrum_1073": sum(item.get("next_issue") == "SCRUM-1073" for item in entries),
        },
    }


def validate(document_data: dict) -> list[str]:
    errors: list[str] = []
    for item in document_data["entries"]:
        fingerprint = item["fingerprint"]
        status = item.get("status", "")
        role = item.get("role", "")
        if status == "unreviewed":
            errors.append(f"unreviewed fingerprint {fingerprint} {item['path']}::{item['function']}")
            continue
        if status not in {"mapped", "allowlist"}:
            errors.append(f"invalid status {status} for {fingerprint}")
        if role not in VALID_ROLES:
            errors.append(f"invalid role {role} for {fingerprint}")
        role_literals = [value.lower() for value in re.findall(r"SemanticTypography\.ROLE_([A-Z_]+)", item.get("source", ""))]
        if role_literals and role not in role_literals:
            errors.append(f"manifest role {role} disagrees with runtime literals {role_literals} for {fingerprint}")
        if not role_literals and not item.get("role_trace"):
            errors.append(f"role {role} has no runtime literal or explicit trace for {fingerprint}")
        if item.get("kind") == "semantic_binding" and len(set(role_literals)) != 1:
            errors.append(f"semantic binding {fingerprint} must carry exactly one literal role")
        mode = item.get("mapping_mode", "")
        if mode not in {"semantic_native", "legacy_compat"}:
            errors.append(f"invalid mapping_mode {mode} for {fingerprint}")
        if mode == "legacy_compat" and not item.get("range_contract"):
            errors.append(f"legacy_compat {fingerprint} misses range_contract")
        if mode == "legacy_compat":
            if not isinstance(item.get("effective_min"), (int, float)) or not isinstance(item.get("effective_max"), (int, float)):
                errors.append(f"legacy_compat {fingerprint} misses numeric effective bounds")
            elif item["effective_min"] > item["effective_max"]:
                errors.append(f"legacy_compat {fingerprint} has reversed effective bounds")
        inferred = _inferred_bounds(item)
        if inferred is not None and (item.get("effective_min"), item.get("effective_max")) != inferred:
            errors.append(
                f"reviewed bounds for {fingerprint} are {item.get('effective_min')}..{item.get('effective_max')}, "
                f"but source contract proves {inferred[0]}..{inferred[1]}"
            )
        if mode == "semantic_native":
            if "effective_min" not in item or "effective_max" not in item:
                errors.append(f"semantic_native {fingerprint} misses effective bounds")
            elif role in TOKEN_BOUNDS:
                low, high = TOKEN_BOUNDS[role]
                if item["effective_min"] < low or item["effective_max"] > high:
                    errors.append(f"semantic_native {fingerprint} escapes {role} token bounds")
        if status == "allowlist":
            for field in ("owner", "reason", "next_issue"):
                if not item.get(field):
                    errors.append(f"allowlist {fingerprint} misses {field}")
            next_issue = item.get("next_issue")
            if next_issue not in {"SCRUM-1068", "SCRUM-1073"}:
                errors.append(f"allowlist {fingerprint} has invalid next_issue")
            is_atlas_canvas = (
                item.get("path") == "scripts/ui_screens.gd"
                and item.get("function") in {"_show_atlas_screen", "_atlas_build_canvas"}
            )
            if next_issue == "SCRUM-1068" and not is_atlas_canvas:
                errors.append(f"allowlist {fingerprint} overloads Atlas-only SCRUM-1068")
            if next_issue == "SCRUM-1073" and is_atlas_canvas:
                errors.append(f"allowlist {fingerprint} must stay with Atlas topology SCRUM-1068")
            if "effective_min" not in item or "effective_max" not in item:
                errors.append(f"allowlist {fingerprint} misses reviewed effective bounds")
            elif role in TOKEN_BOUNDS:
                low, high = TOKEN_BOUNDS[role]
                if item["effective_min"] >= low and item["effective_max"] <= high:
                    errors.append(f"allowlist {fingerprint} is inside token bounds and should be mapped")
        elif status == "mapped" and role in TOKEN_BOUNDS and "effective_min" in item and "effective_max" in item:
            low, high = TOKEN_BOUNDS[role]
            if item["effective_min"] < low or item["effective_max"] > high:
                errors.append(f"mapped {fingerprint} escapes {role} token bounds and must be allowlisted")
        for marker, expected_role in SEMANTIC_ROLE_EXPECTATIONS.items():
            if marker in item.get("source", "") and role != expected_role:
                errors.append(f"semantic intent marker {marker!r} requires {expected_role}, got {role} for {fingerprint}")
    bindings = [item for item in document_data["entries"] if item.get("kind") == "semantic_binding"]
    expected_binding_counts = {
        "_codex_bind_stage_font": 8,
        "_battle_prayer_label": 5,
        "_shrink_label_font_to_width": 3,
    }
    for helper, expected_count in expected_binding_counts.items():
        actual_count = sum(helper in item.get("source", "") for item in bindings)
        if actual_count != expected_count:
            errors.append(f"semantic helper {helper} has {actual_count} inventoried consumers, expected {expected_count}")
    ui_source = (ROOT / "scripts/ui_screens.gd").read_text(encoding="utf-8")
    if 'control.set_meta("codex_semantic_role", role)' not in ui_source or 'control.get_meta("codex_semantic_role"' not in ui_source:
        errors.append("Codex stage font role metadata is not preserved across refresh")
    semantic_sources = ui_source + "\n" + (ROOT / "scripts/pause_stats_menu.gd").read_text(encoding="utf-8")
    for pattern, description in SOURCE_SEMANTIC_PATTERNS.items():
        if re.search(pattern, semantic_sources, re.S) is None:
            errors.append(f"semantic source contract missing: {description}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated = document()
    errors = validate(generated)
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors[:40]))
        return 1
    rendered = json.dumps(generated, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != rendered:
            print(f"STALE: {OUTPUT.relative_to(ROOT)}")
            return 1
        print("PASS: semantic typography inventory is current")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(rendered, encoding="utf-8")
    print(f"WROTE: {OUTPUT.relative_to(ROOT)} ({generated['counts']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
