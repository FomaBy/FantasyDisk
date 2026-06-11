# Задача Для Animator-Агента: Исправить Parse Errors В Cutout Rig

Дата: 2026-06-10

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Не спрашивай подтверждение: исправь animation/rig compile issue, запусти проверки и обнови документацию, если меняется поведение animation layer.

## Контекст

Во время Design-задачи по замене `icon.svg` был запущен Godot headless editor import:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path /Users/sergeyfomin/Documents/AI\ Agent
```

Импорт SVG прошел, но Godot вывел parse errors в animation rig script:

```text
SCRIPT ERROR: Parse Error: Cannot infer the type of "death_p" variable because the value doesn't have a set type.
          at: GDScript::reload (res://scripts/cutout_rig_2d.gd:351)
SCRIPT ERROR: Parse Error: Cannot infer the type of "p" variable because the value doesn't have a set type.
          at: GDScript::reload (res://scripts/cutout_rig_2d.gd:436)
SCRIPT ERROR: Parse Error: Cannot infer the type of "death_p" variable because the value doesn't have a set type.
          at: GDScript::reload (res://scripts/cutout_rig_2d.gd:490)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
          at: GDScript::reload (res://scripts/player.gd:0)
ERROR: Failed to load script "res://scripts/player.gd" with error "Parse error".
```

## Scope

Исправить compile/parse errors в `scripts/cutout_rig_2d.gd`, сохранив текущую animation architecture и визуальное поведение:

- не менять gameplay/collision/weapon logic;
- сохранить `HeroFull` + hidden rig-parts схему;
- сохранить current action states: `idle`, `walk`, `attack`, `shoot`, `cast`, `hit`, `death`;
- исправить type inference failures точечными типами/приведениями.

## Files To Check

- `scripts/cutout_rig_2d.gd`
- `scripts/player.gd`
- `tests/animation_smoke_test.gd`
- `tests/runtime_smoke_test.gd`

## Acceptance Criteria

- Godot больше не выводит parse errors по `scripts/cutout_rig_2d.gd`.
- `Player.gd` снова загружается без compile error.
- Animation smoke test проходит:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

- Runtime smoke test проходит, если Animator change затрагивает общий runtime:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

## Notes

Эта задача создана из Design-чата как handoff, потому что проблема находится в animation/rig зоне и не относится к SVG app icon.
