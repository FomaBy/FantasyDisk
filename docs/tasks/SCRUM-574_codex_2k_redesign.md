# SCRUM-574 Codex 2K Redesign

Jira: https://fantasydisk.atlassian.net/browse/SCRUM-574
Status: qa-ready
Owner: flex-loop
Lane: Codex / Design

## Locked Paths

- `scripts/ui_screens.gd`
- `scripts/ui/ui_theme_paths.gd`
- `tools/build_ui_2k_frame_kit.py`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_*.png`
- `docs/design/references/scrum574_codex_2k/`
- `docs/design/mockups/scrum574_codex_2k/`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/visual_style_assets.md`
- `docs/design/content_registry.md`
- `tests/runtime_smoke_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`

## Result

Codex now has a dedicated 2K frame kit for its main shell, navigation panel,
list panel, detail panel, entry cards, vertical tabs and compact back button.
The runtime keeps the existing three-column Control layout, but all major
surfaces resolve through `OVERHAUL_2K_FRAME_*` metadata and the shared 2K
StyleBoxTexture helper.

OpenAI API mockup:
`docs/design/references/scrum574_codex_2k/codex_2k_mockup.png`

Safe-zone preview:
`docs/design/previews/scrum574_codex_2k_safe_zones.png`

Implementation spec:
`docs/design/mockups/scrum574_codex_2k/spec.md`

Generated runtime assets:

- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_main.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_nav.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_list.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_detail.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_entry_card.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_tab_btn.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_back_btn.png`

## Verification

- PASS: `python tools\build_ui_2k_frame_kit.py --all`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --import`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd`

Note: `python tools\godot_gate.py ...` is Unix-specific in this Windows worker
because it imports `fcntl`, so the equivalent direct Godot console binary was
used after a headless import pass.
