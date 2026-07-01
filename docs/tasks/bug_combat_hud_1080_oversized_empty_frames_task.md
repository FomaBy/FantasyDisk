# SCRUM-778: BUG SCRUM-700 - combat HUD is oversized and mostly empty at 1920x1080

Статус: review
Приоритет: P1
Роль: Back-end / runtime UI
Контур: Codex
Owner: codex-backend-scrum778-hud-scale
Thread/Worker: codex-backend-scrum778-hud-scale
Branch: `codex/scrum-778-hud-scale`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-778-hud-scale`
Locked paths: `scripts/ui_screens.gd`, `tests/ui_no_overlap_matrix_test.gd`, `docs/design/systems/menus_ui.md`, `docs/tasks/bug_combat_hud_1080_oversized_empty_frames_task.md`, `build/qa/scrum778_hud_scale/`
Версия: 0.1.8
Jira: SCRUM-778
Related QA: SCRUM-700

## Problem

SCRUM-700 1080p UI QA found the live combat HUD visually oversized and mostly
empty at 1920x1080. Reported evidence:

- `RunResourceHud`: `[P: (30, 63), S: (1116, 159)]`
- `CombatTimerPanel`: `[P: (1194, 62), S: (318, 164)]`
- `AscensionHudBadge`: `[P: (1624, 41), S: (248, 242)]`
- Priority panel area: `14.32%`
- Top HUD band: `26.20%` of viewport height

## Implementation

- Compacted SCRUM-666/SCRUM-671 combat HUD source-space rects in
  `scripts/ui_screens.gd` while preserving the same accepted generated frame
  assets and essential-only content set: HP, XP, money, ULT, timer, ascension
  and pending level-up.
- Kept runtime content inside frame-safe metadata zones; timer, ascension and
  pending-count zones were resized to fit rendered text without touching frame
  ornament.
- Added a 1920x1080 regression guard in `tests/ui_no_overlap_matrix_test.gd`:
  combat HUD top band must be `<= 18%` viewport height and pending-level frame
  footprint must be `<= 3.5%` viewport area.
- Updated `docs/design/systems/menus_ui.md` with the new geometry and constraints.

## UI Director Deviation

No new PixelLab mockup/art layer was generated. This is an intentional
runtime-only compaction of existing HUD geometry, not a new visual design pass:
the accepted SCRUM-666/SCRUM-671 art, content set, frame-safe model and runtime
assets remain unchanged. New art would add churn without addressing the bug,
which is oversized source-space placement at 1080p.

## Result

At 1920x1080 after SCRUM-778:

- `RunResourceHud`: `[P: (30.0, 45.0), S: (938.0, 111.0)]`
- `CombatTimerPanel`: `[P: (1031.0, 44.0), S: (233.0, 108.0)]`
- `AscensionHudBadge`: `[P: (1710.0, 39.0), S: (123.0, 123.0)]`
- `LevelUpPlusButton`: `[P: (1778.0, 936.0), S: (66.0, 78.0)]`
- Top HUD band bottom: `162 px` = `15.00%` of viewport height.
- Pending-level frame footprint: `165x188 px` = `1.50%` of viewport area.

Evidence:

- `build/qa/scrum778_hud_scale/combat_hud_rects.md`

## Verification

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- BLOCKED screenshot capture only: `python3 tools/godot_gate.py --headless --path . --script res://tests/design_review_screenshot_capture_test.gd` failed under headless dummy rendering with `viewport image unavailable` / `texture_2d_get` at `_capture_screen()`. Rect/matrix evidence was captured through the passing no-overlap verifier.

## Changed Files

- `scripts/ui_screens.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `docs/design/systems/menus_ui.md`
- `docs/tasks/bug_combat_hud_1080_oversized_empty_frames_task.md`
- `build/qa/scrum778_hud_scale/combat_hud_rects.md`

## Disk Cleanup

Removed task-created `.godot/` import cache, generated `.import` sidecars, and
failed screenshot capture output under `build/qa/design_review/`. Kept only the
small SCRUM-778 evidence markdown under `build/qa/scrum778_hud_scale/`.
