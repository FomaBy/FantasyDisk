# Bug: Gamepad global input actions do not confirm UI or move player
Статус: review
Приоритет: high
Роль: Back-end
Контур: Codex
Owner: backend/codex-gamepad-input-review
Thread: current Codex user-requested gamepad fix run
Locked paths: scripts/input_device_manager.gd; scripts/main.gd; scripts/player.gd; scripts/ui_screens.gd; scripts/route_map_screen.gd; tests/gamepad_*.gd; docs/design/systems/input_controls.md; docs/design/current_game_state.md
Branch/worktree: `codex/gamepad-input-review` at `/Users/sergeyfomin/Documents/FantasyDisk_gamepad_input`
Jira: SCRUM-846
Версия: 0.2.0
Создано: 2026-07-03
Автор: direct user request

## Context / problem
User reports that gamepad focus can move through UI controls, but there is no working select/confirm action. During combat, the left stick does not move the player. Existing gamepad tasks already added default bindings and partial smoke coverage, but the live build still fails core gamepad-only actions.

## Required change
Review every current player-facing action and make it work from gamepad without breaking keyboard/mouse controls:
- UI confirm/select: `A` / `ui_accept` activates focused buttons/cards/options on all menu and in-run screens.
- UI cancel/back: `B` / `ui_cancel` closes the current overlay/screen where a back action exists.
- Combat movement: left stick and D-pad move the player through `move_left/right/up/down`.
- Combat/system actions: Start pauses/resumes, RB opens pending level-up, Y activates ultimate, Back/Select opens feedback.
- Settings/rebind flow must preserve joypad bindings when keyboard bindings are changed.

## Acceptance Criteria
- [ ] A gamepad-only flow can start from main menu, choose hero/weapon, enter combat, move with the left stick, pause/resume, open/resolve level-up, use ultimate, open/close feedback, and return through victory/death/pause flows where applicable.
- [ ] `ui_accept`, `ui_cancel`, `ui_up/down/left/right`, `move_*`, `pause`, `ultimate`, `open_level_up`, and `feedback` all have working default joypad events after startup and after settings/rebind/reset.
- [ ] `main._input` handles action semantics by action, not keyboard-only event type, except debug-only keyboard shortcuts such as F12.
- [ ] Existing keyboard/mouse controls and saved keybindings remain compatible.
- [ ] Focused regression tests cover real `InputEventJoypadButton` / `InputEventJoypadMotion` paths, not only direct `Input.action_press`.
- [ ] Documentation for the gamepad input contract and known gaps is updated.

## Initial evidence
- Related known partial bugs: SCRUM-824 (Start pause gate), SCRUM-825 (RB level-up gate).
- Current user symptoms expand the scope to A/confirm and combat movement, so this ticket is a broader gamepad input audit/fix.

## Implementation result
- `main._input` now routes `feedback`, feedback-close, `pause`, and `open_level_up` through action semantics instead of keyboard-only event checks. Back/Select opens feedback; B/Start/Esc close it.
- `_is_fresh_action_press()` accepts `InputEventJoypadButton`, `InputEventJoypadMotion`, `InputEventAction`, and keyboard events while preserving keyboard echo guards.
- `InputDeviceManager` sanitizes saved `gamepad_bindings`: empty/malformed entries are ignored, saved configs cannot override `ui_*` canonical A/B/stick/D-pad bindings, and stale custom joypad events are cleared when an invalid saved game action falls back to default.
- Regression coverage now includes malformed saved bindings, Back/Select feedback flow, B/Start feedback close, Start pause, RB level-up, A confirm, left-stick movement, in-run UI navigation, settings rebind persistence, and general runtime smoke.

## Verification
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_core_input_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_combat_actions_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_full_flow_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_player_movement_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_inrun_ui_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_settings_rebind_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_menu_focus_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`

## Cleanup
- Disk cleanup: removed `/Users/sergeyfomin/Documents/FantasyDisk_gamepad_input/.godot` and transient Godot `.import` sidecars created by headless import.
