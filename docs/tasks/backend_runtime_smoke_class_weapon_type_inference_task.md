# Back-end Task: ClassWeapon Type Inference Parse Errors

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Роль: Back-end
Jira: SCRUM-167
Связь: `backend_add_character_sniper_task.md`; обнаружено во время Animator verification `animation_thief_rig_motion_task.md` / SCRUM-169

## Контекст

Animator SCRUM-169 завершил Thief cutout rig/motion and action pose hooks. `tests/animation_smoke_test.gd` проходит, Godot headless editor import проходит. Общий runtime smoke не может пройти из-за Back-end parse errors в `scripts/class_weapon.gd`, в sniper weapon methods.

Команда:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Текущий лог:

```text
SCRIPT ERROR: Parse Error: Cannot infer the type of "shot_finish" variable because the value doesn't have a set type.
          at: GDScript::reload (res://scripts/class_weapon.gd:1059)
SCRIPT ERROR: Parse Error: Cannot infer the type of "end_point" variable because the value doesn't have a set type.
          at: GDScript::reload (res://scripts/class_weapon.gd:1136)
SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
          at: GDScript::reload (res://scripts/class_weapon.gd:1095)
```

Likely source area:

- `scripts/class_weapon.gd::_fire_sniper_lockshot`
- `scripts/class_weapon.gd::_fire_sniper_kill_zone`
- `scripts/class_weapon.gd::_fire_sniper_split_round`

## Scope

- Add explicit GDScript types/casts around the reported sniper variables and Variant-returning calls.
- Preserve Sniper gameplay behavior, weapon balance, cooldowns, VFX timing, and damage logic.
- Re-run runtime smoke after the parse errors are fixed.

## Acceptance

- `scripts/class_weapon.gd` loads without parse/type-inference errors.
- `tests/runtime_smoke_test.gd` passes or reports a newer unrelated blocker with a separate task.
- No Animator-layer code changes are required for this fix.

## Dispatch

- 2026-06-13: dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as part of active Sniper/Jira `SCRUM-167` ownership. This is a runtime smoke blocker, not separate feature scope.

## Result

- 2026-06-13: done as part of SCRUM-167. Added explicit `Vector2`, `Node2D`, `Array`, and `float(...)` casts around Sniper methods in `scripts/class_weapon.gd` and `scripts/player.gd`.
- Runtime smoke loads `scripts/class_weapon.gd` without the reported type inference parse errors at `shot_finish`, `targets`, or `end_point`; no Animator changes were required.
