# SCRUM-1044 — Priest prayer Escape opens Pause dossier above mandatory modal

Статус: review
Приоритет: high
Роль: Back-end
Контур: Codex
Owner: `/root/scrum1044_prayer_escape`
Thread: `/root`
Версия: 0.2.1
Jira: SCRUM-1044
Найдено QA при приёмке: SCRUM-926

## Problem

`BattlePrayerChoiceScreen` is mandatory, but physical keyboard Escape reached
the general `Main._input` pause branch and opened `PauseStatsMenuRoot` above the
prayer modal. Gamepad B happened to take the `ui_escape_action` no-op path, so
the original focused test did not reproduce the keyboard defect.

## Fix contract

- While the prayer screen is open, `Main._input` consumes `pause` and
  `ui_cancel` before every other global overlay/hotkey branch.
- Other input returns from Main global handling but remains available to the
  focused GUI prayer cards; Enter/gamepad A/mouse selection is unchanged.
- Physical Escape, keyboard `ui_cancel` and gamepad B keep the prayer modal,
  `battle_prayer` pause and original card focus; no pause dossier is created.
- No visual/layout changes and no changes to prayer effects or combat order.

## Evidence

- `tests/scrum926_priest_prayer_choice_test.gd` — PASS at 1280×720,
  1920×1080 and 2560×1440; physical Escape, `InputEventAction(ui_cancel)` and
  joypad B all traverse `Main._input`, preserve the prayer/focus and never
  create `PauseStatsMenuRoot`.
- `tests/ui_no_overlap_matrix_test.gd` — PASS.
- `tests/gamepad_inrun_ui_test.gd` — PASS.
- `tests/runtime_smoke_ui_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` with isolated task userdata — PASS.
- Independent re-QA is required for SCRUM-1044 before SCRUM-926 may move from
  QA FAILED to Done.

Disk cleanup: task-local `.godot` and isolated userdata are removed after the
origin/dev landing; no generated asset or disposable clone is retained.
