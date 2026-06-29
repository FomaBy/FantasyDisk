# SCRUM-590 Victory Banner 2K Frame Spec

Jira: SCRUM-590
Screen/node: `VictoryBanner` / `VictoryBannerFrame`
Runtime entry: `scripts/ui_screens.gd::_show_victory_banner()`

## Goal

Replace the full-screen bare victory text with a centered D&D + Dark Fantasy Dragon frame while preserving the existing dim overlay, click-to-continue behavior, and 1.3 second auto-continue.

## 2K Layout

Base viewport: `2560x1440`.

| Slot | Const | Rect | Texture margins | Content margins | Content rect |
|---|---|---:|---:|---:|---:|
| Dim/click layer | `VBN_DIM_2K` | `Rect2(0, 0, 2560, 1440)` | n/a | n/a | n/a |
| Victory frame | `VBN_FRAME_2K` | `Rect2(560, 600, 1440, 240)` | `84,44,84,44` | `112,52,112,52` | `Rect2(112, 52, 1216, 136)` |
| Global safe area | `VBN_SAFE_2K` | `Rect2(672, 652, 1216, 136)` | n/a | n/a | n/a |

Runtime text is one short line, `ПОБЕДА`, centered in `VictoryBannerLabel`. The frame is anchored top-center and scales uniformly with the project viewport settings on 1080p, 2K, and 4K.

## Assets

Generated exact-size transparent frame asset:

- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_vbn_frame.png`

The asset contains only the frame/ornament layer. No text is baked into the image; the label is runtime UI constrained by StyleBox content margins.

## Implementation Notes

- `scripts/ui/ui_theme_paths.gd` registers `vbn_frame` path, source size, texture margins, and content margins.
- `scripts/ui_screens.gd` builds `VictoryBannerFrame` as a `PanelContainer` child of the full-screen click catcher.
- Runtime metadata stores `victory_banner_slot`, `victory_banner_content_margins`, and `victory_banner_content_rect` for QA assertions.
- `tools/build_ui_2k_frame_kit.py` includes the VBN slot in the deterministic exact-slot 2K frame kit, because this HUD banner requires a transparent, pixel-exact 9-slice-safe source.

## QA Plan

- `python tools\build_ui_2k_frame_kit.py --verify`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`

Acceptance: `VictoryBannerLabel` global rect must remain inside the scaled `Rect2(112, 52, 1216, 136)` frame content zone; the decorative frame remains visible and unblocked.
