# Back-end Task: Split Runtime Smoke Into Focused Suites

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-178
Jira: SCRUM-202
Эпик: epic_full_project_quality_pass

## Scope

Split `tests/runtime_smoke_test.gd` into focused suites while keeping an umbrella smoke path.

## Target Suites

- UI/menu smoke.
- Combat smoke.
- Progression/economy smoke.
- Weapon mechanics smoke.
- Boss/elite smoke.

## Verification

- Existing runtime smoke command remains available.
- All new focused suites pass headless.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Blocked / Serialized (2026-06-13)

Blocked by active smoke-surface churn rather than a failing test. Runtime smoke
is still being extended by current content/UI tasks (SCRUM-192 registry
alignment, SCRUM-203 no-overlap matrix already in QA, SCRUM-222 UI theme
dependency). Splitting the umbrella smoke while those checks are moving would
create duplicate maintenance work.

Next unblock: resume once the current focused smoke additions are closed or
accepted by QA. Existing umbrella `tests/runtime_smoke_test.gd` remains the
required smoke command.

## Dispatcher Unblock / Dispatch (2026-06-13)

Unblocked after SCRUM-192, SCRUM-203 and SCRUM-222 reached `Готово`, and the
runtime smoke/test paths were clean in git status. Dispatched to Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` as item 1 in the serialized refactor
queue. Keep reasoning High/no low; close and Jira-sync this task before taking
the next queued refactor.

## Result Summary (2026-06-13)

Implemented focused runtime smoke suites while preserving the existing umbrella
command:

- `tests/runtime_smoke_ui_test.gd`
- `tests/runtime_smoke_combat_test.gd`
- `tests/runtime_smoke_progression_economy_test.gd`
- `tests/runtime_smoke_weapon_mechanics_test.gd`
- `tests/runtime_smoke_boss_elite_test.gd`

Implementation decision: the new suites extend `tests/runtime_smoke_test.gd` and
reuse its helper/assertion layer, but override `_initialize()` to run thematic
subsets. This keeps the mandatory umbrella smoke command stable and gives later
refactors sharper, faster regression coverage without duplicating large helper
logic or changing gameplay behavior.

Verification:

- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_combat_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_progression_economy_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_weapon_mechanics_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_boss_elite_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.

Note: the umbrella smoke emitted one residual `Lambda capture at index 0 was
freed` Godot warning but exited 0 with `Runtime smoke test passed.` This task did
not change gameplay/runtime cleanup code; if the warning becomes blocking, handle
it as a separate debug-cleanup bug.
