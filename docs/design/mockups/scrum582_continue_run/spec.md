# SCRUM-582 / SCRUM-842 Continue Run Dialog 2K Frame Spec

Jira: SCRUM-582
Follow-up Jira: SCRUM-842
Screen/node: `ContinueRunPanel`
Runtime entry: `scripts/ui_screens.gd::_show_continue_run_dialog()`

## Goal

Finish the 2K redesign integration for the continue-run dialog: the panel and both actions use exact-size dark-fantasy frame assets, while title, subtitle, and buttons stay inside the documented safe content zone.

SCRUM-842 follow-up: the Russian label `Продолжить` must fit fully inside the
primary button in normal/hover/focus/pressed/disabled states. The fix uses the
existing `continue_run_long_420x72` text-button family and widens the modal
enough for `420 + 18 + 240` button-row geometry to remain inside the frame
safe-zone.

## Mockup / Reference

- PixelLab MCP reference job: `6f789a6f-8d9a-4f97-add9-e821784dd504`
  (`SCRUM-842 continue-run dialog widened button reference`).
- Reference PNG:
  `docs/design/mockups/scrum582_continue_run/scrum842_continue_run_button_fit_reference.png`
- Note: PixelLab baked English placeholder button labels into the reference
  despite the no-text prompt. Treat the PNG as a composition/content-zone
  reference only; runtime Russian labels remain Godot-rendered text.
- Runtime assets stay existing: `cr_panel`, `continue_run_long_420x72`, and
  `continue_240x72`. No new production bitmap asset is required.

## 2K Layout

Base viewport: `2560x1440`.

| Slot | Const | Rect | Texture margins | Content margins |
|---|---|---:|---:|---:|
| Dim layer | `CR_DIM_2K` | `Rect2(0, 0, 2560, 1440)` | n/a | n/a |
| Panel frame | `CR_PANEL_2K` | `Rect2(860, 530, 840, 380)` | scaled from `38,52,38,48` | scaled from `58,72,58,66` |
| Safe content | `CR_SAFE_2K` | `Rect2(932, 602, 696, 242)` | n/a | n/a |
| Title | `CR_TITLE_2K` | `Rect2(932, 614, 696, 44)` | n/a | n/a |
| Subtitle | `CR_SUBTITLE_2K` | `Rect2(932, 674, 696, 66)` | n/a | n/a |
| Continue button | `CR_BTN_CONTINUE_2K` | `Rect2(942, 758, 420, 72)` | `37,14,37,14` | `54,14,54,14` |
| New game button | `CR_BTN_NEWGAME_2K` | `Rect2(1380, 758, 240, 72)` | `37,14,37,14` | `47,14,47,14` |

## Assets

Existing transparent assets reused from the active text-button / overhaul kits:

- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_cr_panel.png`
- `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_run_long_420x72_<state>.png`
- `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_240x72_<state>.png`

No new production bitmap is required: SCRUM-669 already promoted the text-button
families. Runtime text remains separate from the image layer.

## Implementation Notes

- `ContinueRunPanel` now records `continue_run_slot`, `continue_run_content_margins`, and `continue_run_content_rect` metadata for QA.
- `ContinueRunButton` uses 420x72 so `_text_button_unique_id()` selects
  `continue_run_long_420x72`; `ContinueRunNewGameButton` remains 240x72 and
  uses `continue_240x72`.
- `tests/ui_no_overlap_matrix_test.gd` creates a temporary autosave, opens the
  dialog, clears the autosave, and asserts frame paths, safe-zone metadata,
  button containment, and `Продолжить` text fit.

## QA Plan

- `python tools\build_ui_2k_frame_kit.py --verify`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
