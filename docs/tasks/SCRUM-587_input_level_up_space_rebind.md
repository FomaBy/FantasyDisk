# SCRUM-587 - Input UX: Space opens level-up and is rebindable

Status: Контроль качества
Owner: backend_scrum541_codex_20260628195911
Role/lane: backend / codex

Locked paths:
- scripts/main.gd
- scripts/ui_screens.gd
- tests/runtime_smoke_test.gd
- docs/tasks/SCRUM-587_input_level_up_space_rebind.md

Result:
- Added `open_level_up` to `INPUT_ACTIONS` with Space as the default key.
- `_input` now opens pending level-up choices from the registered action while combat remains unpaused until player input.
- Settings Controls exposes the new binding row through the existing input settings pipeline.
- Fixed linked SCRUM-658 runtime blocker: rapid level-up world-effect replacement no longer deletes `LevelUpToast`, and old world-effect nodes are removed before replacement so the live `LevelUpEffect` keeps its exact testable name.

Tests:
- PASS `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd`
- PASS `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/game_settings_smoke_test.gd`
