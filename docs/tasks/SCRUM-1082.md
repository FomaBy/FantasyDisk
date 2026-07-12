# SCRUM-1080 Back-end: runtime placement, glow и current version

Статус: done
Версия: 0.2.1
Jira: SCRUM-1082
Контур: Codex
Owner: Back-end
Thread: /root/main_menu_corner_backend
Locked paths: `scripts/ui_screens.gd`, relevant Main Menu/UI tests, `docs/design/systems/menus_ui.md`, backend result in this mirror

## Scope

Start read-only. After SCRUM-1081 handoff, move and slightly enlarge the gratitude control, add a restrained procedural glow, and ensure the bottom-right version label reads the current `application/config/version`. Preserve icon-only face, tooltip/accessibility, neutral focus, gamepad navigation, callback, SFX and frame-safe geometry.

## Back-end result

- Implemented the exact five-tier SCRUM-1081 geometry in
  `scripts/ui_screens.gd`, including live resize.
- Reused `MainMenuCreditsButton`, the accepted PixelLab icon, callback,
  tooltip/accessibility metadata and click SFX; hitboxes are now 72/80/96 px.
- Added mouse-ignoring `MainMenuGratitudeGlow`, a bounded procedural radial
  gradient with geometry-stable normal/hover/focus/pressed alpha states.
- Reused the single `MainMenuVersionLabel`; it continues to resolve
  `application/config/version` and now uses bottom-right alignment, responsive
  14/15/16/18 px typography, warm-neutral color and a dark 2 px outline.
- Kept the action column at its accepted SCRUM-1059 X; button sizes, vertical
  rhythm, order and callbacks are unchanged.
- Positioned glow/icon immediately left of the bottom-right version with exact
  12/16/20 px responsive cluster gaps.
- Updated deterministic keyboard/gamepad focus: action `Right` enters gratitude;
  gratitude `Left/Up` returns to Exit, `Down` returns to Start and `Right`
  remains on gratitude.

Focused verification:

- `tests/scrum1059_main_menu_single_column_test.gd` — PASS (five viewports + live resize).
- `tests/scrum981_gold_menu_shell_test.gd` — PASS.
- `tests/scrum1051_ui_button_family_test.gd` — PASS.
- `tests/ui_no_overlap_matrix_test.gd` — PASS (seven viewport matrix).
- `tests/runtime_smoke_ui_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS.

The two runtime suites emit the pre-existing dummy-renderer screenshot
diagnostic `texture_2d_get: Parameter "t" is null` from
`_try_capture_weapon_select_screenshot`; both suites still complete with exit 0
and their explicit PASS verdicts.

Disk cleanup: removed the task-worktree `.godot` cache (~446 MB) and all
untracked `.uid`/`.import` sidecars created by the import/test run; tracked
source and task/design evidence were preserved.

Commit/push intentionally left to the parent SCRUM-1080 integrator.

## QA PASSED

SCRUM-1083 independently passed the exact geometry, live resize, focus/gamepad,
button-family/accessibility, overlap matrix, Metal visual capture and UI/full
runtime smoke gates. Bugs: none.

Disk cleanup: removed implementation `.godot` cache (~446 MiB) and generated
untracked `.uid`/`.import` sidecars.
