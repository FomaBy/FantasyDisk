# Аудит: неиспользуемые спрайты и картинки

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: high
Роль: Design (Claude) → Back-end cleanup
Версия: 0.1.5

## Результат (2026-06-14)
Отчёт: docs/design/reviews/cleanup_assets_audit_2026_06.md. Вывод: мёртвого
игрового арта НЕТ — все 79 «unused» кандидатов ложные (vfx_weapon_%s / weapons/%s
грузятся по weapon_id; боссы/мини-элитки 0.1.5 ждут вайринга; marketing —
коллатераль). Реальный мусор: 64 осиротевших «2.png.import» (остаток дублей
SCRUM-270, пропущенный regex'ом) → порождена
cleanup_remove_orphan_import_sidecars_task (SCRUM-271), исполнена в этой же цепочке.
Проверки после аудита/sidecar cleanup: `audit_unused_assets.py` PASS,
`content_registry_consistency_test` PASS, `unique_weapon_vfx_assets_test` PASS,
`runtime_smoke_test` PASS.
Создано: 2026-06-14
Автор: PM (запрос пользователя — полный рефакторинг/чистка)
Jira: SCRUM-269
Эпик: CLEANUP — рефакторинг и чистка v2 (SCRUM-266)

## Dispatcher Dispatch (2026-06-14)

Sent to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`. Keep reasoning
High/no low. Scope is read-only asset/image audit and report/task generation
only: do not delete assets, generate art, or change runtime code.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## ВАЖНО: это READ-ONLY аудит (Фаза 1)
Только читать код/ассеты/доки и писать ОТЧЁТ + порождать точечные execution-задачи.
НЕ удалять и не рефакторить в этой задаче. Исполнение (Фаза 2) — отдельными
задачами, СЕРИАЛИЗОВАНО ПОСЛЕ балансового патча 0.1.5 (общие файлы:
progression_data/stat_formulas/class_weapon/player/ui_screens), чтобы не ловить
коллизии и сломанный HEAD. Порождённые execution-задачи помечать
`blocked (после балансового патча 0.1.5)` либо new, если файл-изолированы.

## Контекст
Запрос пользователя: «удалить ненужные спрайты и картинки». Есть
tools/audit_unused_assets.py (консервативный аудит) + история чисток.

## Требования (READ-ONLY + спека удаления)
1. Прогнать tools/audit_unused_assets.py и вручную сверить: какие PNG/ассеты в
   assets/ и docs/design/previews/ не имеют runtime-ссылок (res:// в коде/сценах),
   с учётом динамических путей (артефакты/оружие/иконки строятся по ID — НЕ
   считать мёртвыми ложно).
2. Отделить: точно неиспользуемые (под удаление в backup), превью/контакт-листы
   (док-артефакты — оставить/в docs), placeholder/итерации (в backup).
3. Учесть свежий арт 0.1.4 (leather_gold, курсор, боссы/мини-элитки) и
   незаконченную интеграцию (мини-элитки на тинте — спрайты ещё подключаются;
   НЕ удалять то, что ждёт вайринга).
4. ОТЧЁТ docs/design/reviews/cleanup_assets_audit_2026_06.md: списки «удалить /
   оставить / в backup» с обоснованием; обновить content_registry-сверку.
5. ПОРОДИТЬ execution-задачу(и) cleanup_* (Back-end): физический вынос в backup
   вне assets/ + чистка content_registry; файл-изолированы — можно new.
   Само удаление — НЕ в этой read-only задаче.

## Acceptance Criteria
- [x] Список неиспользуемых ассетов с защитой от ложных срабатываний (динамич. пути).
- [x] Отчёт с «удалить/оставить/backup»; созданы дочерние cleanup-задачи.
- [x] Read-only: ничего не удалено в этой задаче; import/smoke зелёные.

## Документация
docs/design/reviews/, content_registry.md.

## Validation (2026-06-14)

- `python3 tools/audit_unused_assets.py` — PASS, 1116 files checked, 87 raw
  candidates after orphan sidecar cleanup; remaining raw candidates are
  classified in the report as dynamic/pending-live/marketing collateral.
- `tests/content_registry_consistency_test.gd` — PASS, 0 allowlisted.
- `tests/unique_weapon_vfx_assets_test.gd` — PASS, 51 plates.
- `tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev)

Read-only asset-аудит. QA = наличие/содержательность отчёта + защита от ложных
срабатываний + read-only.

Проверено (фактически):
- **Отчёт** `docs/design/reviews/cleanup_assets_audit_2026_06.md` (7.1KB):
  сводка, таблица, **защита от ложных срабатываний** (79 «unused» = динамическая
  загрузка; раздел «арт в ожидании вайринга — НЕ удалять»; `assets/marketing/**`
  = KEEP), и реальный мусор (110 осиротевших сайдкаров → дочерняя задача).
- **Read-only/ничего не сломано**: `content_registry_consistency` (0 allowlisted),
  `runtime_smoke`, `unique_weapon_vfx_assets` — зелёные; `audit_unused_assets.py`
  PASS (1116 файлов проверено).

Acceptance:
- [x] Список неиспользуемых с защитой от ложных срабатываний (динам. пути).
- [x] Отчёт «удалить/оставить/backup»; дочерние cleanup-задачи.
- [x] Read-only; import/smoke зелёные.

Баги: нет.
