# SCRUM-582 Continue Run Dialog 2K Frame Spec

Jira: SCRUM-582
Screen/node: `ContinueRunPanel`
Runtime entry: `scripts/ui_screens.gd::_show_continue_run_dialog()`

## Goal

Finish the 2K redesign integration for the continue-run dialog: the panel and both actions use exact-size dark-fantasy frame assets, while title, subtitle, and buttons stay inside the documented safe content zone.

## 2K Layout

Base viewport: `2560x1440`.

| Slot | Const | Rect | Texture margins | Content margins |
|---|---|---:|---:|---:|
| Dim layer | `CR_DIM_2K` | `Rect2(0, 0, 2560, 1440)` | n/a | n/a |
| Panel frame | `CR_PANEL_2K` | `Rect2(940, 530, 680, 380)` | `38,52,38,48` | `58,72,58,66` |
| Safe content | `CR_SAFE_2K` | `Rect2(998, 602, 564, 242)` | n/a | n/a |
| Title | `CR_TITLE_2K` | `Rect2(998, 614, 564, 44)` | n/a | n/a |
| Subtitle | `CR_SUBTITLE_2K` | `Rect2(998, 674, 564, 66)` | n/a | n/a |
| Continue button | `CR_BTN_CONTINUE_2K` | `Rect2(1031, 758, 240, 72)` | `50,28,50,28` | inherited button content |
| New game button | `CR_BTN_NEWGAME_2K` | `Rect2(1289, 758, 240, 72)` | `50,28,50,28` | inherited button content |

## Assets

Existing exact-slot transparent assets reused from the active overhaul kit:

- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_cr_panel.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_cr_btn.png`

No new bitmap was required: SCRUM-486/SCRUM-485 already generated the panel and button sources at the exact SCRUM-582 slot sizes. Runtime text remains separate from the image layer.

## Implementation Notes

- `ContinueRunPanel` now records `continue_run_slot`, `continue_run_content_margins`, and `continue_run_content_rect` metadata for QA.
- `ContinueRunButton` and `ContinueRunNewGameButton` use `_apply_overhaul_2k_button_theme(..., "cr_btn", ...)` instead of generic minimal-metal button selection.
- `tests/ui_no_overlap_matrix_test.gd` creates a temporary autosave, opens the dialog, clears the autosave, and asserts exact frame paths plus safe-zone metadata.

## QA Plan

- `python tools\build_ui_2k_frame_kit.py --verify`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
