# Back-end Task: Split Runtime Smoke Into Focused Suites

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-178
Jira: SCRUM-202
QA: in_progress (2026-06-13)
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

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 35b79e06 (ветка dev)

Проверено (фактически):
- **5 focused-сьютов существуют** и НЕ пустышки: каждый
  `extends "res://tests/runtime_smoke_test.gd"` (переиспользует helper/assert-слой)
  и override `_initialize()` запускает реальное thematic-подмножество `_test_*`:
  - ui → glossary, settings/rebind, weapon-select, parchment-seal;
  - combat → arena generation, damage;
  - progression_economy → stat/artifact recording, settings persistence,
    full/universal attribute wiring;
  - weapon_mechanics → berserk/class weapon configs, mode registry, all variants equip;
  - boss_elite → elite flow, unique attacks, stage scaling, epic boss hitbox.
- **Прогон headless (отдельные user-data-dir)**:
  - `runtime_smoke_ui_test` — passed (0 warn)
  - `runtime_smoke_combat_test` — passed (0 warn)
  - `runtime_smoke_progression_economy_test` — passed (0 warn)
  - `runtime_smoke_weapon_mechanics_test` — passed (0 warn)
  - `runtime_smoke_boss_elite_test` — passed (0 warn)
  - umbrella `runtime_smoke_test` — passed (обязательная команда сохранена).
- **Регрессия (вне smoke-семейства)**: animation / meta_progression /
  melee_weapon_targeting / ui_no_overlap_matrix — все зелёные.

Acceptance:
- [x] Существующая umbrella-команда доступна и зелёная.
- [x] Все 5 новых focused-сьютов проходят headless.

Краевые случаи:
- Сьюты — настоящие подмножества (быстрее umbrella), а не дубль всего набора.
- Umbrella не сломан сплитом (зелёный).
- Переиспользование assert-слоя через `extends` подтверждено.

Баги: нет. Нефатальный warning `Lambda capture at index 0 was freed` у umbrella
воспроизводится (exit 0, тест passed) — латентный, не введён этим тиаском, у
focused-сьютов отсутствует. Per авторская заметка отложен как debug-cleanup до
момента, когда станет блокером; QA bug не заводит (не дефект приёмки, не блокер).
