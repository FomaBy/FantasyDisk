# Back-end Task: Weapon Budget Tuning Application Regression

Статус: new
Версия: 0.1.5
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
