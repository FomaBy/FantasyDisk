# Аудит: архитектура кода и план рефакторинга

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя: полный аудит и рефакторинг проекта)
Jira: SCRUM-174
Эпик: epic_full_project_quality_pass

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил ВСЁ. Работать автономно без вопросов и ожидания
инпута (директива полной автономии). Тупик = blocked с причиной + handoff.

## Роль
Back-end (Claude)
## Контекст
Кодовая база ~20k строк GDScript. Болевые точки по размеру: `ui_screens.gd` 4304,
`progression_data.gd` 2320, `class_weapon.gd` 1969, `cutout_rig_2d.gd` 1485,
`player.gd` 1368. Нужен системный код-ревью и приоритизированный план рефакторинга.

## Что сделать (READ-ONLY: только читать код и писать отчёт + дочерние задачи)
1. Полный обзор архитектуры: разбиение на сцены/скрипты, связность, god-объекты,
   циклические зависимости, дублирование, мёртвый код, не-data-driven хардкод.
2. **План распила `ui_screens.gd` (4304 стр)** на доменные модули (меню/HUD/
   магазин/level-up/пауза/победа и т.д.) — конкретные границы, без изменения
   поведения. То же для `class_weapon.gd` (режимы оружия) и `progression_data.gd`.
3. Производительность: горячие пути (спавн волн, VFX-пулы, _process), аллокации.
4. Качество GDScript: типизация, guard'ы освобождённых нод (уже были баги),
   именование, мёртвые ветки.
5. **Отчёт** `docs/design/reviews/code_architecture_audit_2026_06.md`: находки по
   приоритету (P1 критично/P2/P3), с файлами и строками.
6. **Породить execution-задачи** `backend_refactor_<area>_task.md` (Версия 0.1.4)
   по каждому крупному пункту: точные границы, «поведение сохранить, 6 smoke
   зелёные», для общих файлов — пометка «сериализовать, предпочтительно после
   0.1.4». Поставить их на доску со статусом new (или blocked, если зависят).

## Acceptance Criteria
- [ ] Отчёт с приоритизированными находками (P1/P2/P3) и точными ссылками.
- [ ] План распила 3+ крупнейших файлов с границами модулей.
- [ ] Созданы дочерние backend_refactor_*-задачи на доске + Jira.
- [ ] Аудит НИЧЕГО не ломает (read-only); 6 smoke остаются зелёными.

## Документация
docs/design/reviews/ (новый отчёт), ссылки в эпике.

## Результат — 2026-06-13

Read-only аудит завершен. Отчет создан:
`docs/design/reviews/code_architecture_audit_2026_06.md`.

Ключевые выводы:
- P1: `scripts/ui_screens.gd` — god-object на 4320 строк, нужно разделить по доменам экранов/HUD/styles.
- P1: `scripts/class_weapon.gd` — 48 non-Berserk weapon modes и shared runtime helpers в одном файле; нужен registry/executor split.
- P1: `scripts/progression_data.gd` — смешаны registry, formulas, rewards, economy, ascension и budget model.
- P2: hot-path enemy scans через `get_nodes_in_group("enemies")` стоит заменить target-query cache.

Созданы child task specs 0.1.4:
- `docs/tasks/backend_refactor_ui_screens_domain_split_task.md`
- `docs/tasks/backend_refactor_class_weapon_mode_registry_task.md`
- `docs/tasks/backend_refactor_progression_data_domain_split_task.md`
- `docs/tasks/backend_refactor_combat_target_query_cache_task.md`

Jira для child tasks: pending PM sync, потому что текущий Back-end toolset не имеет Jira connector/API.

Verification: runtime, animation, meta progression, meta skill tree, melee targeting, attack VFX and hazard VFX smoke suites passed on 2026-06-13.
