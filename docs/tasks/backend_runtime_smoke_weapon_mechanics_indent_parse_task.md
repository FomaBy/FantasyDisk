# Back-end Task: Runtime Smoke Weapon Mechanics Indent Parse Error

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Роль: Back-end
Jira: SCRUM-166
Источник: Animator verification while closing `docs/tasks/animation_biologist_rig_motion_task.md`
Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Problem

Runtime smoke currently fails to parse before execution:

```text
SCRIPT ERROR: Parse Error: Expected statement, found "Indent" instead.
          at: GDScript::reload (res://tests/runtime_smoke_test.gd:1060)
ERROR: Failed to load script "res://tests/runtime_smoke_test.gd" with error "Parse error".
```

The failing area is in `tests/runtime_smoke_test.gd` inside `_initialize()`.
Lines around 1060 have extra indentation before the weapon-mechanics awaits:

```gdscript
await _test_elementalist_weapon_mechanics()
	await _test_sniper_weapon_mechanics()
	await _test_priest_weapon_mechanics()
	await _test_biologist_weapon_mechanics()
	await _test_robot_weapon_mechanics()
	await _test_elite_unique_attacks()
```

## Scope

- Fix the indentation/parse error in `tests/runtime_smoke_test.gd`.
- Keep Back-end ownership of weapon mechanics/runtime smoke behavior.
- Re-run runtime smoke after the parse fix:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

## Out Of Scope

- Do not change Animator cutout/motion files unless a separate Animator handoff is needed.
- Do not change Biologist animation pose/profile behavior; `res://tests/animation_smoke_test.gd` already passes after Animator work.

## Acceptance

- `tests/runtime_smoke_test.gd` parses cleanly.
- Runtime smoke either passes or any subsequent Back-end failures are tracked with precise follow-up notes.

## Result

2026-06-13: Исправлен лишний indent у weapon-mechanics awaits в `tests/runtime_smoke_test.gd`.
Проверка выполнена:
`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
Result: passed.
