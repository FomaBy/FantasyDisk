#!/usr/bin/env python3
"""SCRUM-194 — селф-тест аудита ассетов: гарантирует отсутствие
ложноположительных удалений динамических ассетов.

Проверки:
  1. Каждое динамическое семейство (DYNAMIC_FAMILIES) реально защищено
     протекцией аудита (KEEP_DIRS / ID_MATCHED_DIRS / KEEP_FILES) — манифест
     консистентен с логикой.
  2. Ни один файл динамического семейства НЕ попал в кандидаты на удаление
     (кроме осознанных FORCE_UNUSED).
  3. Любой кандидат-сайдкар (.import/.uid) — сирота (исходник отсутствует),
     живые сайдкары не удаляются в одиночку.
  4. write_manifest пишет непустой отчёт.
  5. Анти-вакуум: семейства непусты, проверено разумное число файлов.

Запуск: python3 tools/test_audit_unused_assets.py
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "audit_unused_assets.py"


def load_audit():
    spec = importlib.util.spec_from_file_location("audit_unused_assets", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def family_is_protected(audit, family: dict) -> bool:
    if family["kind"] == "files":
        return all(rel_path in audit.KEEP_FILES for rel_path in family["files"])
    if family["kind"] == "id":
        return family["dir"] in audit.ID_MATCHED_DIRS
    # kind == "dir"
    directory = family["dir"]
    return any(directory == keep or directory.startswith(keep + "/") for keep in audit.KEEP_DIRS)


def main() -> int:
    audit = load_audit()
    errors: list[str] = []

    candidates, stats = audit.build_candidates()
    candidate_paths = {item["path"] for item in candidates}
    inventory = audit.dynamic_inventory()

    # 1) Манифест консистентен с защитой.
    for family in audit.DYNAMIC_FAMILIES:
        if not family_is_protected(audit, family):
            errors.append("семейство '%s' (%s) НЕ покрыто KEEP_DIRS/ID_MATCHED_DIRS/KEEP_FILES" % (
                family["name"], family.get("dir", family.get("files"))))

    # 2) Ни один динамический файл не помечен на удаление (кроме FORCE_UNUSED).
    dynamic_members: set[str] = set()
    for entry in inventory:
        for member in entry["members"]:
            dynamic_members.add(member)
            if member in candidate_paths and member not in audit.FORCE_UNUSED:
                errors.append("ЛОЖНОЕ УДАЛЕНИЕ динамического ассета '%s' (семейство '%s')" % (
                    member, entry["family"]["name"]))

    # Registry-removed id assets are no longer dynamic: they must remain visible
    # as cleanup candidates instead of being silently protected by directory.
    game_ids = audit.known_game_ids()
    for family in audit.DYNAMIC_FAMILIES:
        if family["kind"] != "id":
            continue
        directory = audit.ROOT / family["dir"]
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if not path.is_file() or audit.rel(path).endswith(audit.SIDECAR_SUFFIXES):
                continue
            embedded_id = audit.dynamic_id_from_filename(path.name, family["pattern"])
            if embedded_id not in game_ids and audit.rel(path) not in candidate_paths:
                errors.append("ORPHAN id-ассет скрыт от cleanup candidates: '%s'" % audit.rel(path))

    # 3) Кандидаты-сайдкары — только сироты.
    for item in candidates:
        path = item["path"]
        if path.endswith((".import", ".uid")):
            source = path.rsplit(".", 1)[0]
            if (ROOT / source).exists():
                errors.append("живой сайдкар '%s' в кандидатах при существующем '%s'" % (path, source))

    # 4) Отчёт пишется и непуст.
    report_path = audit.write_manifest(candidates, stats, inventory)
    if not report_path.exists() or report_path.stat().st_size == 0:
        errors.append("манифест-отчёт не записан или пуст: %s" % report_path)

    # 5) Анти-вакуум.
    if len(dynamic_members) < 50:
        errors.append("динамических файлов подозрительно мало (%d) — тест прошёл бы вакуумно" % len(dynamic_members))
    if stats["checked"] < 100:
        errors.append("проверено подозрительно мало файлов (%d)" % stats["checked"])
    if not any(f["kind"] == "id" for f in audit.DYNAMIC_FAMILIES):
        errors.append("в манифесте нет ни одного id-семейства — покрытие неполное")

    if errors:
        for e in errors:
            print("FAIL:", e, file=sys.stderr)
        print("Asset audit self-test: %d ошибок (проверено %d, динамических %d, кандидатов %d)." % (
            len(errors), stats["checked"], len(dynamic_members), len(candidates)), file=sys.stderr)
        return 1
    print("Asset audit self-test passed (проверено %d, динамических защищено %d, кандидатов %d, отчёт %s)." % (
        stats["checked"], len(dynamic_members), len(candidates),
        report_path.relative_to(ROOT).as_posix()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
