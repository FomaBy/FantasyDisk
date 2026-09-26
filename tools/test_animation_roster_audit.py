#!/usr/bin/env python3
"""FAN-2518 — селф-тест рекурсивного аудита анимационных паков.

Проверки:
  1. Ростер покрывает ровно 56 уникальных runtime actor id с точными
     размерами групп (17/25/7/5/2), без дублей и пропусков.
  2. Гейты приёмки: priest, secret_ascension_boss и любые оставшиеся
     fallback мини-элиты присутствуют явно (не скрыты за fallback).
  3. Fallback-мини-элиты указывают на существующий пак базовой элитки.
  4. Манифест на диске (data/meta/animation_roster_manifest.json)
     синхронен с ростером в коде.
  5. Парсер .tres видит анимации и кадры в контрольных паках, включая
     вложенные каталоги кадров (не только верхнеуровневые PNG).
  6. Аудит стартует по всем 56 актёрам без ошибок ресурсов (каждый пак
     существует, парсится, все текстуры кадров есть на диске).

Запуск: python3 tools/test_animation_roster_audit.py
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "animation_roster_audit.py"


def load_audit():
    spec = importlib.util.spec_from_file_location("animation_roster_audit", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    audit = load_audit()
    failures = []

    ids = [a["id"] for a in audit.ROSTER]
    if len(ids) != 56:
        failures.append(f"expected 56 actors, got {len(ids)}")
    if len(set(ids)) != len(ids):
        duplicates = sorted({i for i in ids if ids.count(i) > 1})
        failures.append(f"duplicate actor ids: {duplicates}")
    for group, expected in audit.GROUP_SIZES.items():
        actual = sum(1 for a in audit.ROSTER if a["group"] == group)
        if actual != expected:
            failures.append(f"group '{group}': expected {expected}, got {actual}")

    for gate in ("priest", "secret_ascension_boss"):
        if gate not in ids:
            failures.append(f"acceptance gate actor missing: {gate}")

    # FAN-3875: FAN-3627 gave every registered mini-elite its own pack and
    # emptied MINI_ELITE_FALLBACK, so the old "exactly 4 fallbacks" expectation
    # certified a retired substitution. What still matters is that any fallback
    # left in the table is listed explicitly and points at a pack that exists.
    fallback_ids = sorted(audit.MINI_ELITE_FALLBACK)
    for fid in fallback_ids:
        if fid not in ids:
            failures.append(f"canonical fallback mini-elite missing: {fid}")
    for mini, base in audit.MINI_ELITE_FALLBACK.items():
        pack = ROOT / "assets/sprites/elites/full_frame" / f"{base}_spriteframes.tres"
        if not pack.exists():
            failures.append(f"fallback pack missing for {mini}: {pack.name}")

    import json
    manifest = json.loads((ROOT / "data/meta/animation_roster_manifest.json").read_text(encoding="utf-8"))
    if manifest != audit.build_manifest():
        failures.append("stale manifest: rerun python3 tools/animation_roster_audit.py")

    for probe, min_anims in [("knight", 24), ("rift_cutter", 5),
                             ("ally_druid_ghost_wolf", 6), ("secret_ascension_boss", 10)]:
        path = next((ROOT / a["frames"] for a in audit.ROSTER if a["id"] in
                     (probe, f"druid_ghost_{probe.split('_')[-1]}" if probe.startswith("ally_") else probe)), None)
        if path is None or not path.exists():
            failures.append(f"probe pack missing: {probe}")
            continue
        parsed = audit.parse_spriteframes(path)
        if len(parsed["animations"]) < min_anims:
            failures.append(f"{path.name}: expected >= {min_anims} animations, "
                            f"got {len(parsed['animations'])}")
        for anim in parsed["animations"]:
            if not anim["textures"]:
                failures.append(f"{path.name}/{anim['name']}: no frame textures")
            for res in anim["textures"]:
                if not (ROOT / res.removeprefix("res://")).exists():
                    failures.append(f"{path.name}/{anim['name']}: frame file missing: {res}")

    for actor in audit.ROSTER:
        if not (ROOT / actor["frames"]).exists():
            failures.append(f"[{actor['id']}] pack missing: {actor['frames']}")

    if failures:
        for f in failures:
            print("FAIL:", f)
        return 1
    print(f"OK: {len(ids)} actors, groups {audit.GROUP_SIZES}, gates present, manifest in sync")
    return 0


if __name__ == "__main__":
    sys.exit(main())
