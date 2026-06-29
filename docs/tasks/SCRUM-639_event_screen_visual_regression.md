# SCRUM-639 - Event Screen Visual Regression

Статус: done
Контур: Codex
Owner: Codex backend/UI fix worker
Thread/Worker: codex-backend-fix-scrum639-event-screen
Locked paths: scripts/ui_screens.gd; tests/ui_no_overlap_matrix_test.gd; docs/design/systems/menus_ui.md; docs/tasks/SCRUM-639_event_screen_visual_regression.md
Jira: SCRUM-639

## Problem

SCRUM-672 visual release gate on latest `origin/dev` showed
`build/qa/design_review/event_1920x1080.png` as a large blank gray event panel:
no visible event title, story, choices, or back action. The only visible element
inside the panel was a small up arrow.

## Cause

`_show_event_screen()` called `_create_upgrade_fab(..., false)` after creating
`MenuPanel_event`. That put a disabled `UpgradeFabButton` directly inside the
event `PanelContainer`. `PanelContainer` lays out its children as panel content,
so the extra disabled FAB disrupted the event scroll/content layout and rendered
as the lone arrow over an otherwise empty gray interior.

## Fix

- Removed the disabled event-screen upgrade FAB creation. Attribute upgrade is
  still unavailable on Event, but no non-interactive FAB is rendered there.
- Hardened `tests/ui_no_overlap_matrix_test.gd` so `event_economy` now fails if:
  - `UpgradeFabButton` exists on Event;
  - `EventContent`, `EventTitle`, `EventStory`, choices, or `EventBackButton`
    are missing, empty, invisible, or outside the scaled `evt_panel` safe rect.
- Updated `docs/design/systems/menus_ui.md` with the SCRUM-639 regression guard.

## Evidence

- Renderer-capable design review capture:
  `build/qa/design_review/event_1920x1080.png` now shows the event title, story,
  three choice cards, and the back button.
- `python3 tools/build_ui_2k_frame_kit.py --verify` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd` - PASS.

## Notes

- `tests/design_review_screenshot_capture_test.gd` fails under `--headless`
  because the dummy renderer returns null viewport textures. The same script was
  run without `--headless` in this macOS checkout and produced the fixed PNGs.
- Disk cleanup: removed generated `.import`/`.uid` sidecars and `.godot/`
  import cache from `/Users/sergeyfomin/Documents/FantasyDisk-SCRUM-639`.
