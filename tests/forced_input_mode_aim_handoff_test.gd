extends SceneTree

# FAN-1721: input_mode выбирает только UI-подсказки, а ручная наводка следует
# последнему значимому физическому вводу. Это намеренно production-path тест:
# настоящий Player, InputDeviceManager и AimController получают события через
# публичный Viewport.push_input / Input.joy_connection_changed, без прямых
# вызовов их private input/hot-plug обработчиков.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ManagerScript := preload("res://scripts/input_device_manager.gd")
const AimController := preload("res://scripts/input/aim_controller.gd")

const PLAYER_POSITION := Vector2(1500.0, 1100.0)

var _errors: Array[String] = []
var _player: CharacterBody2D
var _manager: Node
var _owns_manager := false


func _initialize() -> void:
	await _run()
	_release_right_stick()
	if _manager != null and is_instance_valid(_manager):
		_manager.call("set_input_mode", "auto")
	root.set_meta("aim_mode", "nearest")
	if not _errors.is_empty():
		for error in _errors:
			push_error("forced_input_mode_aim_handoff_test: %s" % error)
		quit(1)
		return
	print("forced_input_mode_aim_handoff_test passed.")
	quit(0)


func _run() -> void:
	# Standalone SceneTree exposes its root Window after the first frame.
	await process_frame
	_manager = root.get_node_or_null("InputDeviceManager")
	if _manager == null:
		var manager := ManagerScript.new()
		manager.name = "InputDeviceManager"
		root.add_child(manager)
		_manager = manager
		_owns_manager = true

	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	if _player == null:
		_expect(false, "Player.tscn не инстанцировалась")
		return
	root.add_child(_player)
	_player.global_position = PLAYER_POSITION
	root.set_meta("gamepad_deadzone", 0.25)
	root.set_meta("aim_mode", "cursor")
	await process_frame
	await process_frame

	_expect(_manager.has_method("active_kind"), "InputDeviceManager не предоставляет active_kind")
	_expect(_player.get_node_or_null("/root/InputDeviceManager") == _manager,
		"Player не видит реальный InputDeviceManager по production autoload path")
	_expect(_player.get_node_or_null("VirtualReticle") != null, "Player не создал VirtualReticle")

	await _check_forced_mode("keyboard")
	await _check_forced_mode("gamepad")

	_player.queue_free()
	if _owns_manager:
		_manager.queue_free()


func _check_forced_mode(mode: String) -> void:
	_manager.call("set_input_mode", mode)
	_release_right_stick()
	_send_mouse_button(MOUSE_BUTTON_LEFT, false)
	await _advance()
	_expect(str(_manager.call("active_kind")) == mode,
		"input_mode=%s должен сохранить UI kind до handoff" % mode)
	_expect(str(_manager.call("input_mode")) == mode,
		"input_mode=%s не должен меняться от физического ввода" % mode)
	_expect(_aim().device() == AimController.DEVICE_MOUSE,
		"precondition %s: физическая мышь должна выбрать cursor" % mode)

	# Connect → right-stick: событие приходит по тому же публичному пути, что и
	# в игре. В headless нет настоящего pad-list, поэтому наличие наводки стиком
	# подтверждает availability, а signal проверяет production hot-plug callback.
	Input.joy_connection_changed.emit(0, true)
	_send_right_stick(0.0, 0.95)
	await _advance()
	_expect(_aim().device() == AimController.DEVICE_GAMEPAD,
		"input_mode=%s: right-stick не передал ручную наводку геймпаду" % mode)
	_expect(_aim().reticle_visible(),
		"input_mode=%s: right-stick не показал virtual reticle" % mode)
	_expect(Vector2(_player.call("attack_aim_direction", Vector2.LEFT, 320.0)).dot(Vector2.DOWN) > 0.99,
		"input_mode=%s: right-stick не изменил направление ручной наводки" % mode)
	_expect((Vector2(_player.call("attack_aim_position", 320.0)) - PLAYER_POSITION).normalized().dot(Vector2.DOWN) > 0.99,
		"input_mode=%s: right-stick не изменил точку ручной наводки" % mode)
	_expect(str(_manager.call("active_kind")) == mode,
		"input_mode=%s: gameplay handoff не должен сменить UI kind" % mode)

	# Нейтраль не переключает устройство и удерживает последнюю наводку.
	var before: Vector2 = _player.call("attack_aim_direction", Vector2.LEFT, 320.0)
	_release_right_stick()
	for _index in range(3):
		await _advance()
		_expect(Vector2(_player.call("attack_aim_direction", Vector2.LEFT, 320.0)).is_equal_approx(before),
			"input_mode=%s: neutral right-stick не удержал последнюю наводку" % mode)
	_expect(_aim().reticle_visible(),
		"input_mode=%s: neutral right-stick не должен скрывать reticle" % mode)

	# Disconnect → mouse fallback → reconnect → right-stick повторяет handoff
	# без private handler calls и сохраняет forced UI preference.
	Input.joy_connection_changed.emit(0, false)
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _advance()
	_expect(_aim().device() == AimController.DEVICE_MOUSE,
		"input_mode=%s: disconnect и mouse не вернули aim курсору" % mode)
	_expect(not _aim().reticle_visible(),
		"input_mode=%s: disconnect и mouse не скрыли reticle" % mode)
	_expect(str(_manager.call("active_kind")) == mode,
		"input_mode=%s: mouse fallback не должен менять UI kind" % mode)

	Input.joy_connection_changed.emit(0, true)
	_send_right_stick(-0.95, 0.0)
	await _advance()
	_expect(_aim().device() == AimController.DEVICE_GAMEPAD,
		"input_mode=%s: reconnect/right-stick не вернул aim геймпаду" % mode)
	_expect(_aim().reticle_visible(),
		"input_mode=%s: reconnect/right-stick не показал reticle" % mode)
	_expect(Vector2(_player.call("attack_aim_direction", Vector2.RIGHT, 320.0)).dot(Vector2.LEFT) > 0.99,
		"input_mode=%s: reconnect/right-stick не обновил направление" % mode)

	# Реальный mouse button/key должен отобрать aim у геймпада даже если UI
	# намеренно зафиксирован на gamepad; debug RMB/Shift+LMB остаётся обычным
	# mouse input и не оставляет reticle залипшим.
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	_send_mouse_button(MOUSE_BUTTON_LEFT, true)
	_send_key(KEY_W)
	await _advance()
	_expect(_aim().device() == AimController.DEVICE_MOUSE,
		"input_mode=%s: mouse/key не вернули aim курсору" % mode)
	_expect(not _aim().reticle_visible(),
		"input_mode=%s: mouse/key не скрыли reticle" % mode)
	_expect(str(_manager.call("active_kind")) == mode,
		"input_mode=%s: mouse/key не должны менять UI kind" % mode)
	_expect(str(_manager.call("input_mode")) == mode,
		"input_mode=%s: mouse/key не должны менять preference" % mode)


func _aim() -> RefCounted:
	return _player.get("_aim") as RefCounted


func _advance() -> void:
	# Дожидаемся обычного SceneTree physics route, а не вызываем Player handlers
	# напрямую: именно так production Player синхронизирует AimController.
	await physics_frame
	await process_frame


func _send_right_stick(x: float, y: float) -> void:
	for axis_value in [[JOY_AXIS_RIGHT_X, x], [JOY_AXIS_RIGHT_Y, y]]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis_value[0]
		event.axis_value = axis_value[1]
		_deliver_input(event)


func _release_right_stick() -> void:
	_send_right_stick(0.0, 0.0)


func _send_mouse_button(button_index: int, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index as MouseButton
	event.pressed = true
	event.shift_pressed = shift
	_deliver_input(event)
	var release := InputEventMouseButton.new()
	release.button_index = button_index as MouseButton
	release.pressed = false
	release.shift_pressed = shift
	_deliver_input(release)


func _send_key(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_deliver_input(event)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	_deliver_input(release)


func _deliver_input(event: InputEvent) -> void:
	# Real engine input both updates InputMap and routes the event through the
	# viewport. The standalone SceneTree APIs expose those two public legs
	# separately, so exercise both without bypassing a component handler.
	Input.parse_input_event(event)
	root.get_viewport().push_input(event, true)
	Input.flush_buffered_events()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
