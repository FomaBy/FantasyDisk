extends "res://tests/runtime_smoke_test.gd"

# SCRUM-824/SCRUM-825: battle action hotkeys must accept joypad action events,
# not only InputEventKey. This focused test keeps keyboard Escape/Space parity.

const ManagerScript := preload("res://scripts/input_device_manager.gd")


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("SCRUM-824/825: Main scene did not load for gamepad combat actions test.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await _ensure_gamepad_action_bindings()
	if not _assert_action_has_joy_button("pause", JOY_BUTTON_START, "SCRUM-824: pause missing Start binding."):
		return
	if not _assert_action_has_joy_button("open_level_up", JOY_BUTTON_RIGHT_SHOULDER, "SCRUM-825: open_level_up missing RB binding."):
		return
	if not _assert_action_has_keycode("pause", KEY_ESCAPE, "SCRUM-824: pause missing Escape binding."):
		return
	if not _assert_action_has_keycode("open_level_up", KEY_SPACE, "SCRUM-825: open_level_up missing Space binding."):
		return

	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 2)
	main.call("_start_combat")
	await process_frame
	await process_frame
	if not bool(main.get("combat_active")):
		_fail("SCRUM-824/825: combat did not start for gamepad combat actions test.")
		return

	await _press_joy_button(JOY_BUTTON_START)
	if not main.ui._is_run_pause_overlay_open():
		_fail("SCRUM-824: joypad Start should open pause in combat.")
		return
	var closed_pause := await _close_pause(main)
	if not closed_pause:
		return

	await _press_key(KEY_ESCAPE)
	if not main.ui._is_run_pause_overlay_open():
		_fail("SCRUM-824: keyboard Escape pause path regressed.")
		return
	closed_pause = await _close_pause(main)
	if not closed_pause:
		return

	main.set("pending_level_ups", 1)
	await _press_joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	if not bool(main.call("_has_pause_reason", "level_up")) or main.find_child("LevelUpOverlay", true, false) == null:
		_fail("SCRUM-825: joypad RB should open pending level-up in combat.")
		return
	var closed_level_up := await _close_level_up(main)
	if not closed_level_up:
		return

	main.set("pending_level_ups", 1)
	await _press_key(KEY_SPACE)
	if not bool(main.call("_has_pause_reason", "level_up")) or main.find_child("LevelUpOverlay", true, false) == null:
		_fail("SCRUM-825: keyboard Space level-up path regressed.")
		return
	closed_level_up = await _close_level_up(main)
	if not closed_level_up:
		return

	main.call("_clear_all_game_pauses")
	main.queue_free()
	await process_frame
	print("gamepad_combat_actions_test passed.")
	quit(0)


func _ensure_gamepad_action_bindings() -> void:
	var mgr := root.get_node_or_null("InputDeviceManager")
	if mgr == null:
		mgr = ManagerScript.new()
		mgr.name = "InputDeviceManager"
		root.add_child(mgr)
		await process_frame
	if mgr.has_method("set_input_mode"):
		mgr.set_input_mode("auto")
	if mgr.has_method("set_gamepad_bindings"):
		mgr.set_gamepad_bindings({})
	if mgr.has_method("ensure_joypad_bindings"):
		mgr.ensure_joypad_bindings()
	await process_frame


func _press_joy_button(button_index: int) -> void:
	var down := InputEventJoypadButton.new()
	down.button_index = button_index
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	var up := InputEventJoypadButton.new()
	up.button_index = button_index
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame


func _press_key(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	var up := InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame


func _close_pause(main) -> bool:
	if main.ui._is_run_pause_overlay_open():
		main.ui._resume_game()
	await process_frame
	if main.ui._is_run_pause_overlay_open() or bool(main.call("_has_pause_reason", "escape_menu")):
		_fail("SCRUM-824: pause overlay did not close during focused test cleanup.")
		return false
	return true


func _close_level_up(main) -> bool:
	if main.ui_escape_action.is_valid():
		main.ui_escape_action.call()
	await process_frame
	await process_frame
	if bool(main.call("_has_pause_reason", "level_up")):
		_fail("SCRUM-825: level-up pause reason did not clear during focused test cleanup.")
		return false
	return true


func _assert_action_has_joy_button(action: String, button_index: int, message: String) -> bool:
	if not InputMap.has_action(action):
		_fail(message)
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and int(event.button_index) == button_index:
			return true
	_fail(message)
	return false


func _assert_action_has_keycode(action: String, keycode: int, message: String) -> bool:
	if not InputMap.has_action(action):
		_fail(message)
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and int(event.keycode) == keycode:
			return true
	_fail(message)
	return false
