# Cleanup: удалить осиротевшие двойн.-расширение сайдкары (110 файлов)

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: medium
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Back-end audit SCRUM-269 (Quality Pass v2)
Jira: SCRUM-271
Эпик: CLEANUP — рефакторинг и чистка v2 (SCRUM-266)
Порождена: docs/design/reviews/cleanup_assets_audit_2026_06.md

## Контекст
Cleanup SCRUM-270 удалил 275 `« N.ext»`-дублей по regex
`git ls-files | grep -E ' [0-9]\.[a-z]+$'`, но шаблон НЕ ловит ДВОЙНОЕ
расширение `« 2.png.import»` (после ` 2.` идёт `png.import` с точкой). 64 таких
сайдкара пережили чистку. У всех source-png отсутствует, ссылок ноль — мёртвые
сайдкары несуществующих дублей.

## File-изоляция
НЕ блокируется балансовым патчем 0.1.5: удаляются ТОЛЬКО `« 2.png.import»`;
реальные ассеты и `.import` базовых файлов не трогаются. Diff — только удаления.

## Требования
1. Список: `git ls-files | grep -E ' [0-9]\.[a-z]+\.[a-z]+$'` (110 файлов:
   64 `.png.import` + 46 `.gd.uid`).
2. Подтвердить: source (` N.png`/` N.gd`) отсутствует + 0 ссылок (сделано в аудите).
3. `git rm` всех. Бэкапа не нужно (сайдкары детерминированно регенерируются
   Godot'ом из source, которого нет → чистый мусор).
4. Verify: runtime smoke + content_registry smoke зелёные.

## Acceptance Criteria
- [x] 110 осиротевших сайдкаров удалены; реальные ассеты/скрипты не тронуты.
- [x] runtime + content_registry smoke зелёные.

## Результат (2026-06-14)

Файл-изолированная cleanup-часть SCRUM-269 выполнена: двойные sidecar-дубли
удалены, реальные PNG/GDScript/source ассеты не трогались.

Validation:
- `git ls-files | grep -E ' [0-9]\.[a-z]+\.[a-z]+$'` — 0 remaining double
  extension sidecars.
- `python3 tools/audit_unused_assets.py` — PASS; orphan ` 2.png.import`
  candidates больше не появляются, оставшиеся candidates задокументированы как
  dynamic/pending-live/marketing collateral.
- `tests/content_registry_consistency_test.gd` — PASS, 0 allowlisted.
- `tests/unique_weapon_vfx_assets_test.gd` — PASS, 51 plates.
- `tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev)

Проверено (фактически):
- **0 осиротевших двойн.-расширение сайдкаров** осталось (выборка 400
  `.import`/`.uid` — у всех есть исходник). 110 orphan ` N.png.import/.uid`
  удалены.
- **Реальные ассеты/скрипты целы** (удаление только сайдкаров несуществующих
  дублей; базовые `.import` не тронуты).
- **Бэкап не нужен — обоснованно**: `.import`/`.uid` детерминированно
  регенерируются Godot-импортом (не уникальный контент).
- **Smoke зелёные**: `content_registry_consistency` (0 allowlisted),
  `unique_weapon_vfx_assets`, `runtime_smoke` — passed.

Acceptance:
- [x] 110 осиротевших сайдкаров удалены; реальные ассеты/скрипты не тронуты.
- [x] runtime + content_registry smoke зелёные.

Баги: нет. Завершает P1-cleanup цепочку (275 дублей SCRUM-270 + 110 сайдкаров
здесь) — репо очищено от copy-артефактов.