extends SceneTree

# SCRUM-811: ядро геймпада — InputDeviceManager, joypad-биндинги, автодетект.
# Headless standalone: в script-mode автолоады не создаются, менеджер
# добавляется вручную ПОСЛЕ Main.tscn — это отражает прод-порядок применения
# (main применяет клавиатурные дефолты в кадре 0, менеджер доливает joypad
# после первого process_frame).

const ManagerScript := preload("res://scripts/input_device_manager.gd")
const GameSettingsScript := preload("res://scripts/game_settings.gd")

const GAME_ACTIONS := ["move_up", "move_down", "move_left", "move_right",
	"pause", "ultimate", "open_level_up", "feedback"]
const UI_ACTIONS := ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]

var _failed := false


func _initialize() -> void:
	await _run()
	if _failed:
		quit(1)
	else:
		print("gamepad_core_input_test passed.")
		quit(0)


func _run() -> void:
	# 0) autoload зарегистрирован в project.godot
	if not ProjectSettings.has_setting("autoload/InputDeviceManager"):
		_fail("autoload/InputDeviceManager не зарегистрирован в project.godot")
		return

	# 1) Интеграция: Main применяет клавиатуру, менеджер доливает joypad.
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn не загрузилась")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var mgr := ManagerScript.new()
	mgr.name = "InputDeviceManager"
	root.add_child(mgr)
	await process_frame
	await process_frame

	mgr.set_input_mode("auto")
	mgr.set_gamepad_bindings({})

	# Клавиатурные события выжили (main), joypad долиты (менеджер).
	_check(_action_has_key(&"move_up"), "move_up: пропали клавиатурные события")
	_check(_action_has_key(&"pause"), "pause: пропали клавиатурные события")
	for action in GAME_ACTIONS:
		_check(_action_has_joypad(action), "%s: нет joypad-событий" % action)
	for action in UI_ACTIONS:
		_check(_action_has_joypad(action), "%s: нет joypad-событий" % action)
	_check(_action_has_button("ui_accept", JOY_BUTTON_A), "ui_accept: нет кнопки A")
	_check(_action_has_button("ui_cancel", JOY_BUTTON_B), "ui_cancel: нет кнопки B")
	_check(_action_has_button("pause", JOY_BUTTON_START), "pause: нет Start")
	_check(_action_has_button("ultimate", JOY_BUTTON_Y), "ultimate: нет Y")
	_check(_action_has_button("open_level_up", JOY_BUTTON_RIGHT_SHOULDER), "open_level_up: нет RB")
	_check(_action_has_button("feedback", JOY_BUTTON_BACK), "feedback: нет Back/Select")
	_check(_action_has_axis("move_left", JOY_AXIS_LEFT_X, -1.0), "move_left: нет оси стика")
	_check(_action_has_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0), "ui_down: нет оси стика")

	# 1b) SCRUM-830 (детерминированная регрессия обратного порядка): под нагрузкой
	#     автолоад успевал предзасеять joypad в ГЛОБАЛЬНЫЙ InputMap ДО того, как
	#     ui._setup_default_input_actions() применит клавиатурные дефолты. Старый
	#     is_empty()-гард видел непустой экшен (joypad уже там) и ПРОПУСКАЛ клавиатуру
	#     → Escape не открывал quit-диалог, R не давал ультимейт. Фикс: гардить по
	#     отсутствию именно InputEventKey. Раньше ловилось лишь флаки-red под пиковой
	#     нагрузкой — здесь воспроизводим детерминированно.
	main.input_bindings = {}
	for action in ["pause", "ultimate"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for stale in InputMap.action_get_events(action):
			InputMap.action_erase_event(action, stale)
		var seed_btn := InputEventJoypadButton.new()
		seed_btn.button_index = (JOY_BUTTON_START if action == "pause" else JOY_BUTTON_Y)
		InputMap.action_add_event(action, seed_btn)
		_check(not _action_has_key(action),
			"%s: прекондиция SCRUM-830 — клавиатуры быть не должно (только joypad)" % action)
	main.ui._setup_default_input_actions()
	_check(_action_has_keycode(&"pause", KEY_ESCAPE),
		"SCRUM-830: pause потерял Escape после joypad-предзасева (is_empty-гард)")
	_check(_action_has_keycode(&"ultimate", KEY_R),
		"SCRUM-830: ultimate потерял R после joypad-предзасева (is_empty-гард)")
	_check(_action_has_button("pause", JOY_BUTTON_START),
		"SCRUM-830: долив клавиатуры стёр joypad-бинд pause (Start)")
	_check(_action_has_button("ultimate", JOY_BUTTON_Y),
		"SCRUM-830: долив клавиатуры стёр joypad-бинд ultimate (Y)")

	# 2) Идемпотентность: повторный ensure не плодит дубли.
	var counts_before := _event_counts()
	mgr.ensure_joypad_bindings()
	mgr.ensure_joypad_bindings()
	_check(_event_counts() == counts_before, "ensure_joypad_bindings плодит дубли событий")

	# 3) Классификация устройства + сигнал.
	var signal_log: Array = []
	mgr.device_changed.connect(func(kind: String) -> void: signal_log.append(kind))

	var joy_btn := InputEventJoypadButton.new()
	joy_btn.button_index = JOY_BUTTON_A
	joy_btn.pressed = true
	mgr._input(joy_btn)
	_check(mgr.active_kind() == "gamepad", "JoypadButton не переключил на gamepad")
	_check(signal_log == ["gamepad"], "device_changed не эмитнулся на gamepad")

	var key_ev := InputEventKey.new()
	key_ev.keycode = KEY_W
	key_ev.pressed = true
	mgr._input(key_ev)
	_check(mgr.active_kind() == "keyboard", "InputEventKey не вернул keyboard")
	_check(signal_log == ["gamepad", "keyboard"], "device_changed не эмитнулся на keyboard")

	var weak_motion := InputEventJoypadMotion.new()
	weak_motion.axis = JOY_AXIS_LEFT_X
	weak_motion.axis_value = 0.1
	mgr._input(weak_motion)
	_check(mgr.active_kind() == "keyboard", "дрожание стика 0.1 не должно переключать устройство")

	var strong_motion := InputEventJoypadMotion.new()
	strong_motion.axis = JOY_AXIS_LEFT_X
	strong_motion.axis_value = 0.9
	mgr._input(strong_motion)
	_check(mgr.active_kind() == "gamepad", "наклон стика 0.9 должен переключать на gamepad")

	# 4) Режимы: active_kind фиксируется, физический ввод не блокируется.
	mgr.set_input_mode("keyboard")
	_check(mgr.active_kind() == "keyboard", "mode=keyboard не зафиксировал active_kind")
	_check(InputMap.event_is_action(joy_btn, "ui_accept"),
		"mode=keyboard не должен выключать joypad-события в InputMap")
	mgr.set_input_mode("gamepad")
	_check(mgr.active_kind() == "gamepad", "mode=gamepad не зафиксировал active_kind")
	var w_key := InputEventKey.new()
	w_key.keycode = KEY_W
	_check(InputMap.event_is_action(w_key, "move_up"),
		"mode=gamepad не должен выключать клавиатурные события в InputMap")
	mgr.set_input_mode("auto")

	# 5) binding_text для обоих устройств.
	mgr.set_input_mode("gamepad")
	_check(mgr.binding_text("pause") == "Start", "binding_text(pause) != Start: '%s'" % mgr.binding_text("pause"))
	_check(mgr.binding_text("ultimate") == "Y", "binding_text(ultimate) != Y")
	mgr.set_input_mode("keyboard")
	_check(mgr.binding_text("move_up") != "", "binding_text(move_up) пуст для клавиатуры")
	mgr.set_input_mode("auto")

	# 6) Кастомные бинды и сброс к канон-дефолту.
	mgr.set_gamepad_bindings({"ultimate": {"buttons": [JOY_BUTTON_X], "axes": []}})
	_check(_action_has_button("ultimate", JOY_BUTTON_X), "кастомный бинд X не применился")
	_check(not _action_has_button("ultimate", JOY_BUTTON_Y), "кастомный бинд не заместил дефолтный Y")
	mgr.reset_gamepad_bindings_to_defaults()
	_check(_action_has_button("ultimate", JOY_BUTTON_Y), "reset не вернул дефолтный Y")
	_check(not _action_has_button("ultimate", JOY_BUTTON_X), "reset не убрал кастомный X")

	# 7) Hot-plug: device_changed эмитится РОВНО при смене active_kind.
	#    QA 2026-07-02 regression: connect не должен эмитить (устройство
	#    переключается лишь по первому вводу), disconnect не должен двоить.
	mgr._input(joy_btn)
	_check(mgr.active_kind() == "gamepad", "прекондиция hot-plug: gamepad")

	# (a) Подключение пада само по себе не меняет активное устройство → тишина.
	var before_connect: int = signal_log.size()
	mgr._on_joy_connection_changed(0, true)
	_check(signal_log.size() == before_connect,
		"connect эмитнул ложный device_changed (было %d, стало %d)"
			% [before_connect, signal_log.size()])
	_check(mgr.active_kind() == "gamepad", "connect не должен менять active_kind")

	# (b) Отключение из gamepad-состояния — РОВНО один сигнал "keyboard".
	var before_disconnect: int = signal_log.size()
	mgr._on_joy_connection_changed(0, false)
	_check(mgr.active_kind() == "keyboard", "отключение пада не вернуло keyboard")
	_check(signal_log.size() - before_disconnect == 1,
		"disconnect должен эмитить device_changed ровно один раз (эмитнуто %d)"
			% (signal_log.size() - before_disconnect))
	_check(signal_log.back() == "keyboard", "disconnect эмитнул не 'keyboard'")

	# (c) Повторный disconnect уже из keyboard-состояния — без сигнала.
	var before_noop: int = signal_log.size()
	mgr._on_joy_connection_changed(0, false)
	_check(signal_log.size() == before_noop,
		"повторный disconnect эмитнул лишний device_changed (было %d, стало %d)"
			% [before_noop, signal_log.size()])

	# 8) Настройки: новые ключи с дефолтами и валидными типами.
	var settings := GameSettingsScript.load_settings()
	_check(["auto", "keyboard", "gamepad"].has(str(settings.get("input_mode"))),
		"settings.input_mode невалиден")
	_check(settings.get("gamepad_bindings") is Dictionary, "settings.gamepad_bindings не Dictionary")
	var dz := float(settings.get("gamepad_deadzone", -1.0))
	_check(dz >= 0.05 and dz <= 0.5, "settings.gamepad_deadzone вне [0.05..0.5]")
	_check(settings.get("gamepad_vibration") is bool, "settings.gamepad_vibration не bool")

	main.queue_free()
	mgr.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	printerr("FAIL: " + message)
	_failed = true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _action_has_joypad(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false


func _action_has_key(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return true
	return false


func _action_has_keycode(action: StringName, keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and int(event.keycode) == keycode:
			return true
	return false


func _action_has_button(action: String, button_index: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and int(event.button_index) == button_index:
			return true
	return false


func _action_has_axis(action: String, axis: int, value: float) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and int(event.axis) == axis \
				and signf(event.axis_value) == signf(value):
			return true
	return false


func _event_counts() -> Dictionary:
	var counts := {}
	for action in GAME_ACTIONS + UI_ACTIONS:
		if InputMap.has_action(action):
			counts[action] = InputMap.action_get_events(action).size()
	return counts
