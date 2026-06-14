# BUG: Флака `melee_unique_mechanics_test` — arc follow-up (same-frame target cache)

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: normal
Роль: Back-end
Версия: 0.1.5
Jira: SCRUM-272
Найдено QA: при тестировании SCRUM-251 (melee classes strengthen), 2026-06-14

## Результат (2026-06-14)
Применён одностроковый фикс: `await process_frame` после добавления врагов
(после строки 124) и ДО `_apply_unique_melee_hit_effects` в
`tests/melee_unique_mechanics_test.gd` — враги попадают в группу `enemies` до
покадрового запроса кэша CombatTargetQuery. Геймплей/баланс не тронуты.
Валидация: 18/18 прогонов зелёные (было ~3/12 падений). Acceptance ≥15×0 — PASS.

## Dispatcher Dispatch (2026-06-14)

Sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`. Keep reasoning
High/no low. Scope is Back-end test reliability: stabilize
`tests/melee_unique_mechanics_test.gd` without gameplay/balance changes unless the
one-line `await process_frame` fix proves insufficient and the executor documents
why. Duplicate audit: related to SCRUM-228's same-frame target-cache class, but
not a duplicate because this is the separate Berserk arc follow-up test path.

## Симптом
`tests/melee_unique_mechanics_test.gd` интермиттентно падает:
`Melee unique mechanics: Expected berserk melee arc follow-up to damage a nearby
secondary target.` (`_test_berserk_weapon_followup`, строка 127/129).

Замер QA: ~3 падения из 12 прогонов (кластером), затем чистые серии — классическая
интермиттентность, НЕ детерминированная поломка.

## Корневая причина (диагностика QA) — тот же класс, что SCRUM-228
Тест (`melee_unique_mechanics_test.gd:116-127`):
1. инстансит `primary`/`secondary` врагов, `holder.add_child(...)` (строки 116-119);
2. задаёт позиции/HP;
3. **СРАЗУ** зовёт `weapon.call("_apply_unique_melee_hit_effects", ...)` (строка 125)
   — БЕЗ промежуточного `await process_frame` после добавления врагов.

Arc-cleave ищет вторичную цель через покадровый кэш `CombatTargetQuery` (кэш врагов
keyed по кадру, `scripts/combat_target_query.gd`). Если другой тикающий node
(`_process` оружия) уже наполнил кэш этого кадра ДО добавления `secondary`, cleave
не видит вторичную цель → ложное падение. Зависит от тайминга `_cooldown`/`delta` →
интермиттентно. Идентично корню SCRUM-228 (флака `melee_weapon_targeting_test`).

Это дефект **надёжности теста**, не геймплея: cleave работает (тест проходит, когда
кэш свеж; balance smoke зелёный).

## Предлагаемое исправление (одна строка)
В `tests/melee_unique_mechanics_test.gd` добавить `await process_frame` ПОСЛЕ
добавления врагов (после строки 124) и ДО `_apply_unique_melee_hit_effects`
(строка 125), чтобы враги попали в группу `enemies` до любого `_process`-запроса
кэша. (См. фикс SCRUM-228: `await process_frame` перед атакой.)
После фикса прогнать тест ≥15 раз — 0 падений.

## Воспроизведение
`~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script
res://tests/melee_unique_mechanics_test.gd` — прогнать 10-15 раз, часть падает.

## Окружение
- Godot 4.6.3.stable headless, macOS (M4), ветка dev (HEAD 2981acf8), 0.1.5 WIP.
- Класс/оружие: Berserk + axe (arc follow-up / cleave).
