# SCRUM-562 - Weapon Select UI @2K

Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)
Owner: Codex Design / design_562_codex562_201933
Branch: codex/scrum-562-ui-texture-load
Jira: SCRUM-562

## Result

Weapon Select now uses a dedicated 2K frame package and larger safe layout:

- Panel: `WS_PANEL_2K = Rect2(420,190,1720,1060)`.
- Safe zone: `WS_SAFE_2K = Rect2(498,286,1564,898)`.
- Cards: three `1564x190` weapon cards with `48/35/48/32` content margins.
- Back button: `280x60` `ws_btn_back` frame inside the panel safe zone.
- Start-boon and Route Map/SCRUM-563 were not changed.

## Evidence

- UI plan gate: `docs/design/mockups/scrum562_weapon_select_2k/ui_plan_report.json` -> `ready_for_image`.
- OpenAI source mockup: `docs/design/references/scrum562_weapon_select_2k/openai_mockup_source.png`.
- Composited preview and debug overlay: `docs/design/previews/scrum562_weapon_select_2k_preview.png`, `docs/design/previews/scrum562_weapon_select_2k_debug.png`.
- Runtime frames: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ws_panel.png`, `ui_frame_2k_ws_card.png`, `ui_frame_2k_ws_btn_back.png`.

## Validation

- PASS: `python tools/build_ui_2k_frame_kit.py --verify`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`

## RED QA follow-up 2026-06-28

Fresh-checkout/headless QA reported that `runtime_smoke_ui_test.gd` could not
load the SCRUM-562 `ws_*` frame textures from `.godot/imported`, causing
`_test_weapon_select_clean_layout` to see untextured card styles. The fix is
scoped to runtime texture loading: `_cached_texture()` now falls back to loading
an existing `res://*.png` source file through `Image.load()` when the imported
resource is not available yet, while preserving `resource_path` for the existing
texture-path assertions.

Validation on fresh worktree `C:\Users\FomaE\FantasyDisk_agents\design_562_codex562_201933`:

- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --import`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
