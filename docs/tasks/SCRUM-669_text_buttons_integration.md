# SCRUM-669: UI buttons integration - SCRUM-657 text-button kit

Статус: review
Роль: Back-end/UI integration
Контур: Codex
Owner: Back-end/Codex
Thread/Worker: codex-worker-backend-scrum669
Locked paths: scripts/ui/ui_theme_paths.gd; scripts/ui_screens.gd; scripts/pause_stats_menu.gd; tests/dark_fantasy_ui_theme_test.gd; tests/runtime_smoke_test.gd; docs/design/current_game_state.md; docs/design/systems/menus_ui.md; docs/design/systems/visual_style_assets.md; docs/tasks/SCRUM-669_text_buttons_integration.md
Jira: SCRUM-669

## Context

SCRUM-657 delivered the generated D&D + Dark Fantasy Dragon text-button package:

- Runtime textures: `assets/sprites/ui/frames/text_buttons_unique/`
- Metadata and source evidence: `docs/design/references/ui_text_buttons_unique_size_redraw/`
- Preview sheets: `docs/design/previews/scrum_text_buttons_unique_size_dark_contact.png`, `docs/design/previews/scrum_text_buttons_unique_size_light_contact.png`

SCRUM-669 owns runtime integration only. It must not redraw assets or apply text-button frames to icon-only controls, cards, slots, portraits, steppers, route nodes, weapon/reward cards, shop item wall hit areas, or non-text decorative frames.

## Implementation Notes

- `scripts/ui_screens.gd` already exposes `TEXT_BUTTON_UNIQUE_*` runtime maps and resolves normal text/action buttons by exact generated size through `_text_button_unique_id()` / `_button_state_style()`.
- This task keeps that resolver as the global source and wires the separate pause dossier helper in `scripts/pause_stats_menu.gd` to the generated `pause_280x60` state textures.
- Tests now assert representative normal text buttons use the full generated state kit instead of old minimal/overhaul button art.

## Verification Plan

- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`

## Result

Implemented and ready for QA.

- Normal text/action buttons continue to route through the global generated SCRUM-657 resolver in `scripts/ui_screens.gd`; icon-only controls, cards, slots, portraits, steppers, route nodes, and non-text decorative frames remain excluded.
- The pause dossier helper in `scripts/pause_stats_menu.gd` now uses the generated `pause_280x60` normal/hover/focus/pressed/disabled PNG state kit with SCRUM-657 content margins.
- `tests/dark_fantasy_ui_theme_test.gd` now treats the generated text-button package as the expected runtime kit, verifies every configured id/state resource exists under `assets/sprites/ui/frames/text_buttons_unique/`, and checks content margins enclose texture margins.
- `tests/runtime_smoke_test.gd` representative pause button assertions now require the `pause_280x60` generated kit.
- Documentation updated in `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`, and `docs/design/systems/visual_style_assets.md`.

Verification:

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- BLOCKED unrelated before UI assertions: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` fails on existing combat socket assertion: `Expected SCRUM-455 right attack weapon socket to follow attack direction (1.0, 0.0), got (0.0, -1.0).`

Disk cleanup: `.godot/` and untracked Godot import sidecars removed before final report; disposable clone retained only until commit/push/report are complete.
