# BUG: Combat HUD is oversized and mostly empty at 1920x1080

Статус: done (QA PASSED -> Готово)
Приоритет: P1
Роль: Back-end (UI runtime)
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: `scripts/ui_screens.gd`, `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_ui_test.gd`, `docs/design/systems/menus_ui.md`, `docs/tasks/bug_combat_hud_1080_oversized_empty_frames_task.md`, QA evidence under `build/qa/scrum700_1080_ui_scale/`
Версия: 0.1.8
Создано: 2026-06-30
Источник: SCRUM-700 1080p UI scale QA pass
Jira: SCRUM-778

## Problem

At 1920x1080 the live combat HUD uses the SCRUM-666 2K source rectangles at
`0.75` scale. Geometry/no-overlap passes, but the visual footprint is too heavy:
the top HUD frames are very wide/tall and mostly empty, especially the resource
strip, timer panel and ascension badge.

Fresh SCRUM-700 measurements:

- `RunResourceHud`: `[P: (30, 63), S: (1116, 159)]`.
- `CombatTimerPanel`: `[P: (1194, 62), S: (318, 164)]`.
- `AscensionHudBadge`: `[P: (1624, 41), S: (248, 242)]`.
- Priority panel area: `14.32%` of the viewport.
- Top HUD band reaches `26.20%` of viewport height.

## Evidence

- Screenshot:
  `build/qa/scrum700_1080_ui_scale/screenshots/combat_hud_1920x1080.png`
- Rect dump:
  `build/qa/scrum700_1080_ui_scale/priority_rects_1920x1080.md`
- Preliminary verdicts:
  `build/qa/scrum700_1080_ui_scale/preliminary_verdicts.md`

## Expected

Combat HUD remains compact and essential at 1920x1080, preserving readability
without large empty frames or excessive top-band occupation. Runtime content
must stay inside frame safe zones, and generated art must not be one-axis
stretched/squashed.

## Actual

The HUD does not literally cover half of the screen by area, but it dominates
the upper combat field visually. The ascension frame in particular is a large
mostly empty box relative to its single roman numeral.

## Recommended Fix Scope

- Back-end UI runtime should retune SCRUM-666 HUD scale/slot geometry for
  1920x1080 while preserving 1280x720 and 2560x1440 no-overlap.
- If the current frame art cannot be made compact without distortion, create a
  Design handoff for a smaller native HUD frame/layout variant.
- Add/extend a 1920x1080 HUD footprint assertion so the top HUD band and panel
  area do not regress.

## Acceptance Criteria

- [ ] Combat HUD at 1920x1080 is visually compact and no longer dominated by
      large empty top frames.
- [ ] HP/XP/gold/ULT/timer/ascension/level-up remain readable and inside safe
      zones at 1280x720, 1920x1080 and 2560x1440.
- [ ] No runtime UI content overlaps frame ornament.
- [ ] `runtime_smoke_ui_test.gd` and `ui_no_overlap_matrix_test.gd` pass or any
      unrelated blocker is recorded precisely.
- [ ] Evidence screenshot/rect dump is updated under `build/qa/`.

Disk cleanup: none created by bug filing; evidence lives in the ignored
SCRUM-700 QA folder.

## QA-Вердикт (2026-07-01)

Статус: PASSED

Проверено on `origin/dev` after integration:

- Branch/worktree: `codex/qa-scrum-778-verify` at `/Users/sergeyfomin/Documents/FantasyDisk-QA-SCRUM-778`.
- Source of truth: `origin/dev` base `75d9b444`; integration commit `245dcdaf` is an ancestor.
- 1920x1080 combat HUD rects from the live no-overlap matrix:
  - `RunResourceHud`: `[P: (30.0, 45.0), S: (938.0, 111.0)]`
  - `CombatTimerPanel`: `[P: (1031.0, 44.0), S: (233.0, 108.0)]`
  - `AscensionHudBadge`: `[P: (1710.0, 39.0), S: (123.0, 123.0)]`
  - `LevelUpPlusButton`: `[P: (1778.0, 936.0), S: (66.0, 78.0)]`
- Visual screenshot: `build/qa/scrum778_dev_verify/combat_hud_1920x1080.png`.
- Evidence report: `build/qa/scrum778_dev_verify/qa_verdict.md`.

Проверки:

- PASS: `git merge-base --is-ancestor 245dcdaf origin/dev`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `python3 tools/godot_gate.py --path . --script res://tests/design_review_screenshot_capture_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd`
- PASS after rebase on `origin/dev` base `d0dc04e4`: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS after rebase on `origin/dev` base `d0dc04e4`: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS final-base rerun on `origin/dev` base `75d9b444`: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS final-base rerun on `origin/dev` base `75d9b444`: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`

Краевые случаи:

- 1280x720, 1920x1080, and 2560x1440 combat HUD screenshots captured.
- UI no-overlap matrix covered supported sizes from 1152x648 through 3840x2160.
- Runtime UI smoke covered normal/boss HUD no-overlap at 1152x648, 1280x720, and 2560x1440.

Баги: нет.
