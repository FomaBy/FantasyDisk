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
