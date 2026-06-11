#!/usr/bin/env python3
"""Asset usage audit for FantasyDisk.

Builds a reference map for every file under assets/ (plus loose root files),
scanning scenes/*.tscn, scripts/*.gd, tests/*.gd, project.godot and
export_presets.cfg, including dynamically-constructed paths (artifact icon dir,
rig parts, etc.). Unused files are MOVED to build/unused_assets_backup/
preserving relative paths (never deleted), together with their .import pairs.

Usage:
    python3 tools/audit_unused_assets.py            # dry run, prints the plan
    python3 tools/audit_unused_assets.py --apply    # actually move files
"""

import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_DIR = os.path.join(ROOT, "build", "unused_assets_backup")

SOURCE_GLOBS = ["scenes", "scripts", "tests", "tools"]
SOURCE_FILES = ["project.godot", "export_presets.cfg", "AGENTS.md"]

# Каталоги, файлы которых собираются кодом по игровым ID; держим целиком,
# кроме файлов, чей встроенный id не матчится ни с одним известным ID.
ID_MATCHED_DIRS = {
    "assets/sprites/ui/icons/artifacts": "artifact_{id}.png",
    "assets/sprites/ui/icons/shop": "shop_{id}.png",
}

# Каталоги, которые держим целиком: пути строятся динамически из профилей
# рига/реестра и активно меняются параллельными агентами.
KEEP_DIRS = [
    "assets/sprites/characters/rig_parts",
    "assets/sprites/enemies/rig_parts",
    "assets/sprites/elites/rig_parts",
    "assets/sprites/bosses/rig_parts",
]

ROOT_LOOSE_CANDIDATES = ["icon 2.svg", "icon 2.svg.import", "visual_redesign_preview.png"]
FORCE_UNUSED = ["icon 2.svg"]  # дубль icon.svg; имя совпадает со строками в доках

# Дизайн-референсы, задокументированные в escape_stats_visual_kit.md как
# "design reference, not required at runtime" — держим по правилу роли.
KEEP_FILES = [
    "assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png",
    "assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png",
]


def collect_source_text():
    chunks = []
    for directory in SOURCE_GLOBS:
        for base, _dirs, files in os.walk(os.path.join(ROOT, directory)):
            for name in files:
                if name.endswith((".gd", ".tscn", ".tres", ".cfg", ".py", ".md")):
                    with open(os.path.join(base, name), errors="ignore") as handle:
                        chunks.append(handle.read())
    for name in SOURCE_FILES:
        path = os.path.join(ROOT, name)
        if os.path.exists(path):
            with open(path, errors="ignore") as handle:
                chunks.append(handle.read())
    return "\n".join(chunks)


def known_game_ids():
    ids = set()
    progression = open(os.path.join(ROOT, "scripts", "progression_data.gd")).read()
    for match in re.finditer(r'"id":\s*"([a-z0-9_]+)"', progression):
        ids.add(match.group(1))
    return ids


def main():
    apply_changes = "--apply" in sys.argv
    source_text = collect_source_text()
    ids = known_game_ids()

    asset_files = []
    for base, _dirs, files in os.walk(os.path.join(ROOT, "assets")):
        for name in files:
            asset_files.append(os.path.relpath(os.path.join(base, name), ROOT))
    for name in ROOT_LOOSE_CANDIDATES:
        if os.path.exists(os.path.join(ROOT, name)):
            asset_files.append(name)

    unused = []
    kept_dynamic = 0
    for rel_path in sorted(asset_files):
        if rel_path.endswith(".import"):
            continue  # judged together with the source file
        base_name = os.path.basename(rel_path)
        rel_dir = os.path.dirname(rel_path)

        if any(rel_dir.startswith(keep) for keep in KEEP_DIRS):
            kept_dynamic += 1
            continue
        if rel_path in KEEP_FILES:
            continue
        if rel_path in FORCE_UNUSED:
            unused.append((rel_path, "дубликат icon.svg в корне проекта"))
            continue

        id_dir = next((d for d in ID_MATCHED_DIRS if rel_dir == d), None)
        if id_dir is not None:
            prefix = ID_MATCHED_DIRS[id_dir].split("{id}")[0]
            embedded = base_name[len(prefix):].rsplit(".", 1)[0]
            if embedded in ids:
                continue
            unused.append((rel_path, "id '%s' отсутствует в progression_data" % embedded))
            continue

        if base_name in source_text or ("res://" + rel_path) in source_text:
            continue
        unused.append((rel_path, "нет ссылок в tscn/gd/project.godot/export_presets"))

    print("Всего ассетов: %d; кандидатов на перенос: %d; динамических сохранено: %d" % (
        len([a for a in asset_files if not a.endswith(".import")]), len(unused), kept_dynamic))
    for rel_path, reason in unused:
        print("  UNUSED:", rel_path, "—", reason)

    if not apply_changes:
        print("\nDry run. Запустите с --apply для переноса.")
        return

    moved = []
    for rel_path, reason in unused:
        for candidate in [rel_path, rel_path + ".import"]:
            absolute = os.path.join(ROOT, candidate)
            if not os.path.exists(absolute):
                continue
            target = os.path.join(BACKUP_DIR, candidate)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.move(absolute, target)
            moved.append((candidate, reason))
    print("\nПеренесено файлов (с .import): %d -> build/unused_assets_backup/" % len(moved))
    with open(os.path.join(ROOT, "build", "unused_assets_moved.txt"), "w") as handle:
        for candidate, reason in moved:
            handle.write("%s\t%s\n" % (candidate, reason))


if __name__ == "__main__":
    main()
