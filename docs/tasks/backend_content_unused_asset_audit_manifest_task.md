# Back-end Task: Dynamic Asset Manifest For Unused-Asset Audit

Статус: done (2026-06-13, Claude Fable 5)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-194
Эпик: epic_full_project_quality_pass

## Scope

Improve unused-asset auditing so dynamic paths and docs-only preview assets are handled safely.

## Requirements

- Add a manifest for dynamic paths: artifact icons, shop icons, cutout families, route icons, generated previews.
- Group `.import`/`.uid` sidecars with source assets.
- Preserve protected folders from process docs.
- Produce a report before any cleanup.

## Verification

- Audit report has no false-positive deletes for dynamic assets.

## Done (2026-06-13)
`tools/audit_unused_assets.py` расширен: (1) явный манифест `DYNAMIC_FAMILIES` — artifact/shop иконки, cutout-семейства (персонажи/враги/элитки/боссы), map/route иконки, ui cursor/frames/shop, docs-only превью — с паттерном пути и причиной динамичности; (2) группировка `.import`/`.uid` сайдкаров с исходным ассетом (в отчёте и stdout) — чистка удаляет блоком; (3) защищённые папки из process-доков сохранены; (4) пишется отчёт `build/asset_audit_manifest.md` ДО любой чистки (таблица семейств + кандидаты с сайдкарами). Новый селф-тест `tools/test_audit_unused_assets.py` гейтит: ни один динамический файл не в кандидатах (кроме FORCE_UNUSED), сайдкары-кандидаты только сироты, манифест консистентен с KEEP_DIRS/ID_MATCHED_DIRS/KEEP_FILES, анти-вакуум. Зелёный: 985 проверено, 286 динамических защищено, 30 кандидатов, 0 ложных удалений.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-194)

Проверено фактически:
- Селф-тест `tools/test_audit_unused_assets.py` — PASSED: «проверено 985, динамических
  защищено 286, кандидатов 30». Гейтит: ни один динамический файл не в кандидатах
  (кроме FORCE_UNUSED), сайдкары-кандидаты только сироты, манифест консистентен с
  KEEP_DIRS/ID_MATCHED_DIRS/KEEP_FILES, анти-вакуум.
- `DYNAMIC_FAMILIES` манифест: отчёт `build/asset_audit_manifest.md` — таблица семейств
  с паттерном+причиной: artifact_icons (53, `artifact_{id}.png` по ARTIFACTS), shop_icons
  (7), character_cutout (85), enemy_cutout (47), элитки/боссы/map/route/ui cursor/frames/
  docs-превью. ✓
- КЛЮЧЕВАЯ проверка (no false-positive deletes): artifact/cutout/shop динамика в списке
  CANDIDATE — ОТСУТСТВУЕТ (греп пуст) → 0 ложных удалений динамически-грузимых ассетов. ✓
- `.import`/`.uid` сайдкары группируются с исходником; защищённые папки из process-доков
  сохранены; отчёт пишется ДО любой чистки.
- Аудит-прогон: 985 файлов, 30 кандидатов, 284 dynamic keep, 2 explicit keep.
Dev-инструмент (Python), runtime игры не затрагивает. Багов нет.
