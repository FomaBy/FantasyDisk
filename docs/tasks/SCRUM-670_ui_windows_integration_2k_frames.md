# SCRUM-670 — UI windows integration: generated 2K frames

Jira: https://fantasydisk.atlassian.net/browse/SCRUM-670
Status: ready_for_qa
Owner: codex-worker-backend-scrum670
Lane: Codex

## Locked Paths

- `scripts/ui_screens.gd`
- `scripts/ui/ui_theme_paths.gd`
- `tools/build_ui_2k_frame_kit.py`
- `tests/ui_no_overlap_matrix_test.gd`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_level_up_*.png`
- `docs/design/ui_screens_inventory.md`
- `docs/design/systems/menus_ui.md`
- `docs/design/current_game_state.md`

## Result

- Integrated the SCRUM-570 level-up generated 2K frame assets into runtime:
  - `level_up_panel`: `ui_frame_2k_level_up_panel.png`, source size `1040x600`, content margins `58/72/58/66`.
  - `level_up_card`: `ui_frame_2k_level_up_card.png`, source size `238x210`, content margins `40/44/40/42`.
- Added slot/path/source-size/margin registration in `UIThemePaths` and generator coverage in `tools/build_ui_2k_frame_kit.py`.
- Updated `LevelUpPanel` and all three `LevelUpRewardButton*` controls to use the generated frames with metadata checked by `ui_no_overlap_matrix_test.gd`.
- Preserved the hard frame rule: panel/card content is inside source safe rects; reward card text is line-limited in compact/rare variants and full details remain in tooltip.
- Kept SCRUM-571 ordinary reward and SCRUM-572 elite reward mockups as design-source only because they do not include isolated alpha runtime frames. Runtime reward/elite screens remain on the existing SCRUM-338 reward-card kit rather than slicing full-screen mockups.

## Verification

- `python3 tools/build_ui_2k_frame_kit.py --verify` — PASS, including `level_up_panel 1040x600` and `level_up_card 238x210`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd` — PASS.

## Disk Cleanup

Transient unrelated `.import` files created by Godot preview imports were removed. `.godot/` cache removal is deferred until after commit/push.
