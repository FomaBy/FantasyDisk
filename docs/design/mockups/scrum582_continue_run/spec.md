# SCRUM-582 / SCRUM-842 / SCRUM-1062 Continue Run Dialog Spec

Jira: SCRUM-582
Follow-up Jira: SCRUM-842
Typography follow-up Jira: SCRUM-1062
Screen/node: `ContinueRunPanel`
Runtime entry: `scripts/ui_screens.gd::_show_continue_run_dialog()`

Status: `implemented` (SCRUM-1062 typography update)
Role owner: Back-end/Codex `/root/scrum1062_continue_title`
Responsive targets: `1152x648`, `1280x720`, `1920x1080`, `2560x1440`, live resize

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

SCRUM-1062 reuses this accepted PixelLab composition and the unchanged runtime
frame/button assets. It does not generate replacement art: the title becomes
live Godot text inside the existing empty title zone. Until SCRUM-1061 lands its
cross-screen semantic token API, `ContinueRunTitle` uses the same effective
theme/default `Font` family as the standard `QuitConfirmationTitle`, with the
local fit-safe `_readable_font_size(29)` title tier. This is the task-authorized pre-SCRUM-1061 fallback,
not a new font family. The local override is removed/migrated by SCRUM-1061.

## 2K Layout

Base viewport: `2560x1440`.

| Slot | Const | Rect | Texture margins | Content margins |
|---|---|---:|---:|---:|
| Dim layer | `CR_DIM_2K` | `Rect2(0, 0, 2560, 1440)` | n/a | n/a |
| Panel frame | `CR_PANEL_2K` | `Rect2(860, 530, 840, 380)` | scaled from `38,52,38,48` | scaled from `58,72,58,66` |
| Safe content | `CR_SAFE_2K` | `Rect2(932, 602, 696, 242)` | n/a | n/a |
| Title | live `ContinueRunTitle` Label | exact 2K `Rect2(932, 602, 696, 70)` | n/a | at least 6px vertical effect reserve inside the title control |
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

The former `assets/sprites/ui/menu_title/continue_run_title.png` wordmark and
its Luminari/Trattatello generator are not valid SCRUM-1062 runtime inputs.
They may be removed only after a repository-wide reference check confirms that
the Continue Run dialog was their sole consumer.

## SCRUM-1062 Typography Contract

| Property | Contract |
|---|---|
| Runtime node | `Label`, name remains `ContinueRunTitle` |
| Text | exact live Russian string `Продолжить забег?` |
| Font family/resource | inherited theme/default `Font`, equal to standard title Labels; no system font or bitmap glyph texture |
| Size | `_readable_font_size(29)`: 38px at 1152x648, 40px at 1280x720, 42px at 1920x1080 and 2560x1440 under the current SCRUM-883 readability scale |
| Line policy | one line, no wrap, centered; fit must be verified from rendered glyph bounds |
| Color | warm title gold `Color(0.96, 0.90, 0.68, 1)` |
| Readability effects | dark 2px outline and 2px shadow offset; effects remain inside the title control |
| Safe parent | `ContinueRunPanel` content rect, approximately `Rect2(71.65, 72, 696.71, 242)` in the fixed 840x380 panel |
| Forbidden zones | panel rails, corner ornaments and all pixels outside the content rect; subtitle/button slots |

The panel remains fixed at `840x380` and centered. Its authored safe rect remains
fixed; only viewport-relative panel position changes. The title control is
exactly `696x70`: local `Rect2(72,72,696,70)` at 1080p/2K and the same size at
local y=73/74 on the 720p/648p integer-layout tiers. It leaves at least 6px of vertical reserve around the
rendered 42px glyph line plus outline/shadow at the largest tier. At smaller tiers the font shrinks
while the control and safe-zone reserve remain stable. A viewport `size_changed`
hook recomputes the readable font size in place during live resize; the title
never scales or stretches as a texture.

Interaction states are unchanged: the title is non-interactive; both buttons
retain normal/hover/focus/pressed/disabled visuals and their existing callbacks,
focus ring, mouse behavior and Escape cancellation.

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
- focused SCRUM-1062 title/glyph/safe-zone matrix at all four target viewports
- `tests/gamepad_menu_focus_test.gd`
- `tests/gamepad_full_flow_smoke_test.gd`
- full `tests/runtime_smoke_test.gd`

## SCRUM-1062 Acceptance Checks

- [x] `ContinueRunTitle` is a live `Label` with exact Russian text.
- [x] Its effective font resource equals a standard game title Label resource.
- [x] No runtime reference to `continue_run_title.png`, Luminari or Trattatello remains.
- [x] Rendered glyph bounds, including outline/shadow reserve, stay inside the
  title control and the panel's authored content rect at every target size.
- [x] Title does not wrap, clip, intersect subtitle/buttons or touch frame ornament.
- [x] Continue/new-game/Escape and mouse/keyboard/gamepad focus behavior is unchanged.

## SCRUM-1062 Verification

Headless focused geometry, global no-overlap, menu focus, full gamepad flow,
runtime UI, asset-reference integrity and full runtime smoke pass. Real Metal on
Apple M4 Pro passes and was visually inspected at all four target resolutions.
Independent read-only review repeated focused/no-overlap/gamepad/runtime/full
gates and returned PASS with no actionable findings. The only emitted diagnostic
is the known non-failing dummy-renderer null texture warning in the headless
weapon-select screenshot helper.

## Deviations

No visual/layout deviation from the updated SCRUM-1062 contract. The accepted
PixelLab SCRUM-842 reference contains baked English placeholder button text and
continues to serve only as composition/content-zone reference; runtime Russian
button labels and the new Russian title remain separate Godot text.
