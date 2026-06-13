# Back-end Task: Weapon Budget Tuning Application Regression

Статус: done (2026-06-13, Claude Fable 5)
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

## Done (2026-06-13)
`tests/weapon_tuning_application_test.gd` — три гейта: (1) реестр `ProgressionData.weapon()` добавляет `budget_damage_multiplier`/`budget_tuning`, а сырой `WEAPONS_BY_CLASS` их НЕ несёт (обход отлавливается); (2) деривация — `damage/magic_damage/sound_wave_damage` масштабируются ровно множителем (ratio == budget_damage_multiplier); (3) рантайм — реальный `Player.configure_character` кладёт тюненный конфиг в `weapon_config`, equip не обходит `weapon()`. Анти-вакуум: ≥9 пар, ≥1 нетривиальный множитель. Headless зелёный: 51 пара, все 51 с множителем != 1.0.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.
