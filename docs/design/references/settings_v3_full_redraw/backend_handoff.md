# SCRUM-694 — Back-end integration handoff: Settings v3 frame family

Design (claude-designer) produced the v3 PixelLab 9-slice frame family + textless
OpenAI mockups + exact geometry. This doc tells Back-end (UI) how to wire the new
assets into `scripts/ui_screens.gd::_show_settings_menu()` without changing any
behaviour. **No runtime semantics change** — only the StyleBox texture sources.

## Production assets (PixelLab final, textless, transparent)

| Element | Asset path | 9-slice texture margins (l,t,r,b) | Used by |
|---|---|---|---|
| Main modal frame | `assets/sprites/ui/frames/settings_v3/ui_frame_settings_v3_main_modal.png` | see `manifest.json` (measure on export, ~ proportional to 640x384) | `SettingsV2MainModalFrame` panel stylebox |
| Tab switcher frame | `.../ui_frame_settings_v3_tab_switcher.png` | horizontal 9-slice, native ends | `SettingsTabSwitcherFrame` |
| Content panel | `.../ui_frame_settings_v3_content_panel.png` | inset 9-slice | `SettingsContentPanel` |
| Inset field | `.../ui_frame_settings_v3_inset_field.png` | 9-slice | `SettingsResolutionOption`, `SettingsWindowModeOption`, `SettingsScreenOption`, `SettingsAimModeOption`, `BindingButton_*` |
| Action button | `.../ui_frame_settings_v3_action_button.png` | 9-slice raised | `SettingsApplyButton`, `SettingsRevertButton`, `SettingsBackButton`, `SettingsReset*Button` |

## Wiring points (constants near line 96-109 of ui_screens.gd)

Replace the v3 path constants only — keep the scaling/margin helper math (it already
produces the correct rects, validated against `layout.json`):

```
const SETTINGS_V3_FRAME_DIR := "res://assets/sprites/ui/frames/settings_v3/"
const SETTINGS_V3_MAIN_MODAL_PATH := SETTINGS_V3_FRAME_DIR + "ui_frame_settings_v3_main_modal.png"
const SETTINGS_V3_TAB_SWITCHER_PATH := SETTINGS_V3_FRAME_DIR + "ui_frame_settings_v3_tab_switcher.png"
const SETTINGS_V3_CONTENT_PANEL_PATH := SETTINGS_V3_FRAME_DIR + "ui_frame_settings_v3_content_panel.png"
const SETTINGS_V3_FIELD_PATH := SETTINGS_V3_FRAME_DIR + "ui_frame_settings_v3_inset_field.png"
const SETTINGS_V3_BUTTON_PATH := SETTINGS_V3_FRAME_DIR + "ui_frame_settings_v3_action_button.png"
```

- `SETTINGS_V2_MAIN_MODAL_PATH` (line 99) -> `SETTINGS_V3_MAIN_MODAL_PATH`.
  Update `SETTINGS_V2_MAIN_SOURCE_SIZE` to the exported PNG size (640x384) and
  re-measure `SETTINGS_V2_MAIN_TEXTURE_MARGINS` / `_CONTENT_MARGINS` proportionally
  to the new corner ornament thickness (see manifest; corners ~22% of short side).
- `SettingsTabSwitcherFrame` uses `_minimal_frame_style("field")` (line 3805) →
  point a new texture stylebox at `SETTINGS_V3_TAB_SWITCHER_PATH`.
- `SettingsContentPanel` uses `_settings_v2_content_panel_style()` (line 3360) →
  swap to a `_global_texture_style(SETTINGS_V3_CONTENT_PANEL_PATH, margins, ...)`.
- OptionButtons via `_apply_compact_button_theme` and `BindingButton_*` → route the
  `inset_field` texture through the existing button-state registry (per-state tint;
  no separate per-state textures needed — current code already tints normal/hover/
  pressed/disabled off one base 9-slice).
- Action buttons via `_apply_fantasy_button_theme` → register `action_button` for
  asset types `reset_audio`, `reset_bindings`, and the generic settings action set.

## Geometry (already correct — do not change)

`layout.json` confirms the live rects match the v3 art targets at 1280x720,
1920x1080, 2560x1440, 3840x2160. Fit gate = `ready_for_image` (no overlap of
title/switcher/content/action-row; safe width >= widest control 560). Modal native
2048x1232 (clamped, covers 2K + 4K); 1080p = proportional 1536x924 (same aspect).

## Micro-controls (below PixelLab 192px floor)

`checkbox on/off`, `slider handle`, `scrollbar grabber` are <=42px runtime glyphs.
Keep the existing `_style_checkbox()` / HSlider / ScrollContainer theme, OR Design
will deliver a 192px source pack downscaled, in a follow-up. Not blocking the frame
family swap.

## Required verification (Back-end)

1. `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
2. `tests/ui_no_overlap_matrix_test.gd` at 1280x720 / 1920x1080 / 2560x1440.
3. `tests/video_settings_apply_test.gd`, `tests/game_settings_smoke_test.gd`,
   `tests/display_resolution_test.gd` (behaviour unchanged → must stay green).
4. Screenshot all three tabs at 1920x1080 + 2560x1440 → `build/qa/settings_v3_full_redraw/`.
5. Confirm no content overlaps frame ornaments (global frame safe-area rule).
