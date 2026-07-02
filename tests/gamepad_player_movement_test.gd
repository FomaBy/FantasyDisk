extends SceneTree

# SCRUM-814: Player movement accepts analog left-stick input through Input.get_vector,
# keeps keyboard/D-pad full-speed behavior, and exposes safe gamepad vibration hooks.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const EPS := 0.01


func _initialize() -> void:
	var errors: Array[String] = []
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	if player == null:
		_fail(["Player scene did not instantiate."])
		return
	root.add_child(player)
	await process_frame

	if not player.has_method("_ensure_default_input_actions"):
		errors.append("Player is missing _ensure_default_input_actions.")
	else:
		player.call("_ensure_default_input_actions")
		if not _assert_no_duplicate_input_events(player, errors):
			await _finish(player, errors)
			return

	root.set_meta("gamepad_deadzone", 0.25)
	if not await _assert_analog_motion(player, errors):
		await _finish(player, errors)
		return
	if not await _assert_deadzone(player, errors):
		await _finish(player, errors)
		return
	if not await _assert_dpad_motion(player, errors):
		await _finish(player, errors)
		return
	if not _assert_vibration_helper_noop(player, errors):
		await _finish(player, errors)
		return

	await _finish(player, errors)


func _assert_analog_motion(player: CharacterBody2D, errors: Array[String]) -> bool:
	var speed := float(player.get("speed"))
	_send_left_stick(0.7, 0.0)
	player.call("_physics_process", 1.0 / 60.0)
	await process_frame
	var velocity := player.velocity
	_release_left_stick()
	await physics_frame
	if velocity.x <= 0.0 or absf(velocity.y) > EPS:
		errors.append("Left stick axis 0 value 0.7 should move right only, got velocity %s." % str(velocity))
		return false
	if velocity.x >= speed - EPS:
		errors.append("Left stick axis 0 value 0.7 should scale below max speed %.2f, got %.2f." % [speed, velocity.x])
		return false
	print("SCRUM-814 analog axis 0.7 velocity: %s (speed %.2f)" % [str(velocity), speed])
	return true


func _assert_deadzone(player: CharacterBody2D, errors: Array[String]) -> bool:
	_send_left_stick(0.1, 0.0)
	player.call("_physics_process", 1.0 / 60.0)
	await process_frame
	var velocity := player.velocity
	_release_left_stick()
	await physics_frame
	if velocity.length() > EPS:
		errors.append("Left stick axis 0 value 0.1 should be inside deadzone, got velocity %s." % str(velocity))
		return false
	print("SCRUM-814 deadzone axis 0.1 velocity: %s" % str(velocity))
	return true


func _assert_dpad_motion(player: CharacterBody2D, errors: Array[String]) -> bool:
	var speed := float(player.get("speed"))
	_send_dpad(JOY_BUTTON_DPAD_RIGHT, true)
	player.call("_physics_process", 1.0 / 60.0)
	await process_frame
	var velocity := player.velocity
	_send_dpad(JOY_BUTTON_DPAD_RIGHT, false)
	await physics_frame
	if velocity.x < speed - EPS or absf(velocity.y) > EPS:
		errors.append("D-pad right should move at full speed %.2f, got velocity %s." % [speed, str(velocity)])
		return false
	print("SCRUM-814 D-pad right velocity: %s (speed %.2f)" % [str(velocity), speed])
	return true


func _assert_vibration_helper_noop(player: CharacterBody2D, errors: Array[String]) -> bool:
	root.set_meta("gamepad_vibration", true)
	player.call("_trigger_gamepad_vibration", 0.6, 0.0, 0.25)
	root.set_meta("gamepad_vibration", false)
	player.call("_trigger_gamepad_vibration", 0.0, 0.8, 0.5)
	root.set_meta("gamepad_vibration", true)
	if errors.size() > 0:
		return false
	return true


func _assert_no_duplicate_input_events(player: CharacterBody2D, errors: Array[String]) -> bool:
	var before := _movement_event_counts()
	player.call("_ensure_default_input_actions")
	player.call("_ensure_default_input_actions")
	var after := _movement_event_counts()
	for action_name in before.keys():
		if int(after[action_name]) != int(before[action_name]):
			errors.append("%s event count changed after repeated init: %d -> %d." % [action_name, int(before[action_name]), int(after[action_name])])
			return false
	for action_name in ["move_up", "move_down", "move_left", "move_right"]:
		if not _has_joy_motion(action_name) or not _has_dpad_button(action_name):
			errors.append("%s should have both left-stick and D-pad events." % action_name)
			return false
	return true


func _movement_event_counts() -> Dictionary:
	var counts := {}
	for action_name in ["move_up", "move_down", "move_left", "move_right"]:
		counts[action_name] = InputMap.action_get_events(action_name).size()
	return counts


func _has_joy_motion(action_name: String) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion:
			return true
	return false


func _has_dpad_button(action_name: String) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			return true
	return false


func _send_left_stick(x: float, y: float) -> void:
	var x_event := InputEventJoypadMotion.new()
	x_event.device = 0
	x_event.axis = JOY_AXIS_LEFT_X
	x_event.axis_value = x
	Input.parse_input_event(x_event)
	var y_event := InputEventJoypadMotion.new()
	y_event.device = 0
	y_event.axis = JOY_AXIS_LEFT_Y
	y_event.axis_value = y
	Input.parse_input_event(y_event)
	Input.flush_buffered_events()


func _release_left_stick() -> void:
	_send_left_stick(0.0, 0.0)


func _send_dpad(button_index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finish(player: Node, errors: Array[String]) -> void:
	_release_left_stick()
	_send_dpad(JOY_BUTTON_DPAD_RIGHT, false)
	if player != null and is_instance_valid(player):
		player.queue_free()
	await process_frame
	if not errors.is_empty():
		_fail(errors)
		return
	print("Gamepad player movement test passed.")
	quit(0)


func _fail(errors: Array[String]) -> void:
	for error in errors:
		push_error(error)
	quit(1)
