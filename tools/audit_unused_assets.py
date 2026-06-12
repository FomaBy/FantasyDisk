#!/usr/bin/env python3
"""Conservative asset cleanup audit for FantasyDisk.

The audit builds a reference map for runtime assets and loose temporary files.
It understands FantasyDisk dynamic asset conventions (artifact/shop icons,
cutout rig manifests, map icons and UI frame folders), and it respects the
protected development areas listed in the 2026-06-12 cleanup task.

This script is report-first. It prints candidates with category and reason.
The cleanup task still backs up tracked files and removes them with git rm.

Usage:
    python3 tools/audit_unused_assets.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SELF = Path(__file__).resolve()
BACKUP_DIR = ROOT / "build" / "cleanup_backup_2026_06_12"

SOURCE_GLOBS = ("scenes", "scripts", "tests", "tools")
SOURCE_FILES = ("project.godot", "export_presets.cfg", "AGENTS.md")

PROTECTED_PREFIXES = (
    "docs/",
    "tools/",
    "tests/",
    "source_docs/",
    "releases/",
    ".claude/",
    ".git/",
    ".godot/",
    "build/qa/",
    "build/cleanup_backup_2026_06_12/",
)
PROTECTED_FILES = {"keep-awake.sh"}

ID_MATCHED_DIRS = {
    "assets/sprites/ui/icons/artifacts": "artifact_{id}.png",
    "assets/sprites/ui/icons/shop": "shop_{id}.png",
}

KEEP_DIRS = (
    "assets/sprites/characters/cutout",
    "assets/sprites/enemies/cutout",
    "assets/sprites/elites/cutout",
    "assets/sprites/bosses/cutout",
    "assets/sprites/map_icons",
    "assets/sprites/ui/cursor",
    "assets/sprites/ui/frames",
    "assets/sprites/ui/shop",
)

KEEP_FILES = {
    "assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png",
    "assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png",
}

ROOT_LOOSE_CANDIDATES = (
    ".DS_Store",
    ".keep-awake.sh.swp",
    "icon 2.svg",
    "icon 2.svg.import",
)

FORCE_UNUSED = {
    "icon 2.svg": ("duplicate_root_file", "дубликат icon.svg в корне проекта"),
    "assets/sprites/visual_redesign_preview.png": (
        "registry_obsolete",
        "content_registry помечает как устаревший preview, runtime не грузит",
    ),
    "assets/sprites/ui/icons/artifact_realistic_dnd_source_contact.png": (
        "art_iteration_source",
        "старый artifact source/contact sheet после итераций иконок, runtime не грузит",
    ),
    "assets/sprites/effects/effects_dnd_preview.png": (
        "art_iteration_preview",
        "контрольный Design preview-лист эффектов, runtime не грузит",
    ),
}

TEMP_NAMES = {".DS_Store"}
TEMP_SUFFIXES = (".swp", ".tmp", ".bak", "~")


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def is_protected(rel_path: str) -> bool:
    if rel_path in PROTECTED_FILES:
        return True
    return rel_path.startswith(PROTECTED_PREFIXES)


def read_text(path: Path) -> str:
    return path.read_text(errors="ignore")


ITERATION_PATTERNS = ("preview", "_source", "contact", "concept")


def collect_runtime_source_text() -> str:
    # Только runtime-источники (без tools/): ссылка из tools/-генератора на свой
    # output-путь НЕ делает превью/исходник «используемым» в игре.
    chunks: list[str] = []
    for directory in ("scenes", "scripts", "tests"):
        root_dir = ROOT / directory
        if not root_dir.exists():
            continue
        for path in root_dir.rglob("*"):
            if path.is_file() and path.suffix in (".gd", ".tscn", ".tres", ".cfg"):
                chunks.append(read_text(path))
    for filename in ("project.godot", "export_presets.cfg"):
        path = ROOT / filename
        if path.exists():
            chunks.append(read_text(path))
    return "\n".join(chunks)


def collect_source_text() -> str:
    chunks: list[str] = []
    for directory in SOURCE_GLOBS:
        root_dir = ROOT / directory
        if not root_dir.exists():
            continue
        for path in root_dir.rglob("*"):
            if not path.is_file() or path.resolve() == SELF:
                continue
            if path.suffix in (".gd", ".tscn", ".tres", ".cfg", ".py", ".md"):
                chunks.append(read_text(path))
    for filename in SOURCE_FILES:
        path = ROOT / filename
        if path.exists():
            chunks.append(read_text(path))
    return "\n".join(chunks)


def known_game_ids() -> set[str]:
    ids: set[str] = set()
    for rel_path in ("scripts/progression_data.gd", "scripts/event_data.gd"):
        path = ROOT / rel_path
        if not path.exists():
            continue
        for match in re.finditer(r'"id":\s*"([a-z0-9_]+)"', read_text(path)):
            ids.add(match.group(1))
    return ids


def collect_audit_files() -> list[str]:
    files: set[str] = set()
    assets_dir = ROOT / "assets"
    if assets_dir.exists():
        for path in assets_dir.rglob("*"):
            if path.is_file():
                files.add(rel(path))
    for filename in ROOT_LOOSE_CANDIDATES:
        if (ROOT / filename).exists():
            files.add(filename)
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel_path = rel(path)
        if is_protected(rel_path):
            continue
        if path.name in TEMP_NAMES or path.name.endswith(TEMP_SUFFIXES):
            files.add(rel_path)
    return sorted(files)


def make_candidate(rel_path: str, category: str, reason: str) -> dict[str, str]:
    return {"path": rel_path, "category": category, "reason": reason}


def build_candidates() -> tuple[list[dict[str, str]], dict[str, int]]:
    source_text = collect_source_text()
    runtime_source_text = collect_runtime_source_text()
    game_ids = known_game_ids()
    candidates: list[dict[str, str]] = []
    stats = {"checked": 0, "dynamic_kept": 0, "explicit_kept": 0}

    for rel_path in collect_audit_files():
        if is_protected(rel_path):
            continue
        path = ROOT / rel_path
        stats["checked"] += 1
        name = path.name
        rel_dir = path.parent.relative_to(ROOT).as_posix() if path.parent != ROOT else ""

        if rel_path.endswith(".import"):
            source_rel = rel_path[:-7]
            if not (ROOT / source_rel).exists():
                candidates.append(make_candidate(rel_path, "orphan_import", "исходный файл отсутствует"))
            continue
        if rel_path.endswith(".uid"):
            source_rel = rel_path[:-4]
            if not (ROOT / source_rel).exists():
                candidates.append(make_candidate(rel_path, "orphan_uid", "исходный файл отсутствует"))
            continue
        if name in TEMP_NAMES or name.endswith(TEMP_SUFFIXES):
            candidates.append(make_candidate(rel_path, "temporary_file", "служебный временный файл"))
            continue
        if rel_path in KEEP_FILES:
            stats["explicit_kept"] += 1
            continue
        if any(rel_dir == keep or rel_dir.startswith(keep + "/") for keep in KEEP_DIRS):
            stats["dynamic_kept"] += 1
            continue
        if rel_path in FORCE_UNUSED:
            category, reason = FORCE_UNUSED[rel_path]
            candidates.append(make_candidate(rel_path, category, reason))
            continue

        id_dir = next((directory for directory in ID_MATCHED_DIRS if rel_dir == directory), None)
        if id_dir is not None:
            prefix = ID_MATCHED_DIRS[id_dir].split("{id}")[0]
            embedded_id = name[len(prefix):].rsplit(".", 1)[0]
            if embedded_id in game_ids:
                stats["dynamic_kept"] += 1
                continue
            candidates.append(make_candidate(
                rel_path,
                "unknown_dynamic_id",
                "id '%s' отсутствует в progression_data/event_data" % embedded_id,
            ))
            continue

        # Превью/исходники/контакт-листы арт-итераций: засчитываем только
        # runtime-ссылки (tools/-генератор ссылается на свой output — это не usage).
        is_iteration = any(pattern in name.lower() for pattern in ITERATION_PATTERNS)
        usage_text = runtime_source_text if is_iteration else source_text
        if name in usage_text or ("res://" + rel_path) in usage_text:
            continue
        if rel_path.startswith("assets/"):
            reason = "арт-итерация без runtime-ссылок (tools/-генератор не считается)" if is_iteration \
                else "нет ссылок в tscn/gd/tests/tools/project.godot/export_presets"
            candidates.append(make_candidate(rel_path, "art_iteration_leftover" if is_iteration else "unused_asset", reason))

    return candidates, stats


def main() -> int:
    if "--apply" in sys.argv:
        print("This audit is report-only; use the cleanup task's backup + git rm procedure.")
        return 2

    candidates, stats = build_candidates()
    print(
        "Всего проверено файлов: {checked}; кандидатов: {count}; "
        "dynamic keep: {dynamic_kept}; explicit keep: {explicit_kept}".format(
            count=len(candidates),
            **stats,
        )
    )
    print("Backup target:", BACKUP_DIR.relative_to(ROOT).as_posix())
    for item in candidates:
        print("CANDIDATE\t{path}\t{category}\t{reason}".format(**item))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
