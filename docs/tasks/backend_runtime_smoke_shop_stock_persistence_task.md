# Back-end: runtime smoke shop stock persistence regression

Статус: done (duplicate 2026-06-13; covered by SCRUM-207)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Animator handoff from SCRUM-184/185/186/187 verification
Jira: SCRUM-209 (duplicate of SCRUM-207)

## Dispatcher Note (2026-06-13)
Duplicate audit: this failure is the same source problem already tracked and
dispatched as `bug_shop_rebuy_exploit_reopen_task.md` / Jira `SCRUM-207`
(shop stock regenerates when reopening the same shop node). Not dispatched as a
separate task. Keep SCRUM-207 as the source of truth.

Dispatcher sync: SCRUM-209 exists as a duplicate Jira issue and should stay
closed as duplicate/superseded by SCRUM-207.

## Role / Scope
Back-end/UI state. Do not route to Animator; this is not a rig, motion, or
animation timing issue.

## Context
Animator changed only `scripts/cutout_rig_2d.gd`, animation smoke coverage, and
animation docs/tasks. `tests/animation_smoke_test.gd` passes, but the mandatory
runtime smoke failed in the shop/noncombat route section.

## Failure
Command:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Observed failure:

```text
Expected reopening the same shop node to keep the original stock, got ["loud_amp", "quickstring", "shop_artifact", "magnetic_buckle"] instead of ["shop_artifact", "ember_core", "skull_resonator", "sharp_talisman"].
at: _test_noncombat_nodes (res://tests/runtime_smoke_test.gd:1916)
```

Relevant code pointers:
- `tests/runtime_smoke_test.gd:1792` `_test_noncombat_nodes`
- `tests/runtime_smoke_test.gd:1916` reopened same shop stock assertion
- `scripts/ui_screens.gd:1933` `_ensure_shop_stock_for_current_node`
- `scripts/ui_screens.gd:1946` `_clear_current_shop_stock`

## Expected
Reopening the same route shop node should keep the same stock and purchased
positions. A new route shop node should receive distinct generated stock.

## Acceptance Criteria
- Runtime smoke passes.
- Existing shop wall/frameless UI behavior remains intact.
- No animation/rig changes are required.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (дубликат, покрыт SCRUM-207)
Регрессия персистентности стока магазина уже верифицирована в рамках
`bug_shop_rebuy_exploit_reopen_task.md` (SCRUM-207, QA passed 2026-06-13):
re-show узла сохраняет сток/purchased, rebuy невозможен, тест поведенческий зелёный.
Отдельной работы не требует. Багов нет.
