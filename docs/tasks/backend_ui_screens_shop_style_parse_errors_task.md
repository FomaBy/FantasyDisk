# Back-end Task: UI Screens Shop Style Parse Errors

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Роль: Back-end / UI
Jira: SCRUM-160
Источник: Animator verification while closing `docs/tasks/animation_engineer_rig_motion_task.md`

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 as part of active SCRUM-160 shop-wall recovery.

## Problem

Runtime smoke cannot start because `scripts/ui_screens.gd` fails to compile:

```text
SCRIPT ERROR: Parse Error: Function "_shop_wall_button_style()" not found in base self.
          at: GDScript::reload (res://scripts/ui_screens.gd:2041)
SCRIPT ERROR: Parse Error: Function "_shop_item_shadow_style()" not found in base self.
          at: GDScript::reload (res://scripts/ui_screens.gd:2071)
SCRIPT ERROR: Parse Error: Too many arguments for "_shop_price_badge_style()" call. Expected at most 0 but received 1.
          at: GDScript::reload (res://scripts/ui_screens.gd:2104)
SCRIPT ERROR: Parse Error: Function "_shop_empty_hook_style()" not found in base self.
          at: GDScript::reload (res://scripts/ui_screens.gd:2158)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
          at: GDScript::reload (res://scripts/main.gd:0)
```

Repro command:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

## Scope

- Fix missing/incorrect shop style helper calls in `scripts/ui_screens.gd`.
- Keep this in Back-end/UI ownership; do not change Animator rig/motion files unless a separate Animator handoff is needed.
- Re-run runtime smoke after the fix.

## Out Of Scope

- Do not change Engineer animation/cutout behavior.
- Do not change gameplay/balance.

## Acceptance

- `scripts/ui_screens.gd` compiles.
- Runtime smoke reaches execution and passes, or any next unrelated blocker is documented precisely.

## Result

2026-06-13: Fixed as part of active SCRUM-160 shop-wall recovery.

- Added `_shop_wall_button_style()`, `_shop_item_shadow_style()`, `_shop_empty_hook_style()`.
- Updated `_shop_price_badge_style(affordable := true)` to match new calls.
- `scripts/ui_screens.gd` compiles and runtime smoke passes.

Verification:

- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED

Проверено фактически:
- 4 ранее отсутствовавших/неверных helper'а определены с корректными сигнатурами:
  `_shop_wall_button_style(is_hovered: bool)` (2629), `_shop_item_shadow_style()` (2644),
  `_shop_empty_hook_style()` (2653), `_shop_price_badge_style(affordable := true)` (2666 —
  теперь принимает аргумент, ранее «Too many arguments expected 0»). +`_add_shop_empty_hook`.
- ui_screens.gd компилируется: smoke на ЧИСТОМ worktree HEAD зелёный (нет Parse Error /
  «not found in base» / Compile Error). Транзиентный compile-break shop-wall работы закрыт.
- Подтверждено косвенно: рендер магазина-стены (SCRUM-160 main) отработал — требует
  компиляции ui_screens + этих helper'ов.

Багов нет.
