# Back-end Task: Weapon Budget Tuning Application Regression

Статус: new (PM 2026-06-13: сброшен из залипшего in_progress — claim >3ч без коммитов, Codex-dispatch не дал прогресса; готов к взятию воркером)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-176
Jira: SCRUM-191
Эпик: epic_full_project_quality_pass

## Scope

Ensure all weapon runtime paths receive `ProgressionData.weapon()` configs with budget tuning applied.

## Requirements

- For every class+weapon, instantiate player, equip weapon and assert derived damage includes `budget_damage_multiplier`.
- Guard against bypassing `ProgressionData.weapon()` with raw `WEAPONS_BY_CLASS` dictionaries.

## Verification

- Runtime smoke or focused weapon config test passes.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
