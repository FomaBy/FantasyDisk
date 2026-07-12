extends "res://tests/runtime_smoke_test.gd"

# SCRUM-816: настройки — выбор устройства ввода + ребинд кнопок геймпада.
# Headless-проверки вкладки «Управление»:
#   1) новые контролы секций «Устройство ввода» и «Геймпад» присутствуют;
#   2) синтетический ребинд joypad-кнопки назначается и заменяет joypad-часть;
#   3) конфликт (кнопка занята) ловится, биндинг не меняется;
#   4) клавиатурный ребинд НЕ стирает joypad-события (баг-фикс _apply_keycodes_to_action);
#   5) ребинд на ось стика назначается по порогу |value|>0.5;
#   6) round-trip: input_mode/gamepad_bindings/deadzone/vibration переживают
#      перезагрузку настроек; старый settings.cfg без новых ключей грузится с дефолтами.
#
# Автолоады в script-mode не создаются — InputDeviceManager добавляется вручную
# ПОСЛЕ Main.tscn (как в gamepad_core_input_test), отражая прод-порядок.

const ManagerScript := preload("res://scripts/input_device_manager.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const SAVE_PATH := "user://settings.cfg"

var _errors: Array = []


func _initialize() -> void:
	# Бэкап реального settings.cfg — тест пишет настройки (round-trip/legacy).
	var had_original := FileAccess.file_exists(SAVE_PATH)
	var original_bytes := PackedByteArray()
	if had_original:
		var reader := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if reader != null:
			original_bytes = reader.get_buffer(reader.get_length())
			reader.close()

	await _run()

	if had_original:
		var writer := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if writer != null:
			writer.store_buffer(original_bytes)
			writer.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	if not _errors.is_empty():
		for err in _errors:
			push_error("SCRUM-816: %s" % err)
		quit(1)
		return
	print("gamepad_settings_rebind_test passed.")
	quit(0)


func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		_errors.append(msg)
	return cond


func _run() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if not _expect(main_scene != null, "Main.tscn не загрузилась"):
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	# В Godot 4.7 автолоад InputDeviceManager создаётся и в script-mode. Используем
	# существующий (тот же узел, что найдёт ui._input_device_manager); если его нет —
	# добавляем вручную (совместимость со старым поведением).
	var mgr = main.get_tree().root.get_node_or_null("InputDeviceManager")
	if mgr == null:
		mgr = ManagerScript.new()
		mgr.name = "InputDeviceManager"
		root.add_child(mgr)
		await process_frame
		await process_frame

	# Детерминизм: тесты читают ЖИВОЙ settings.cfg, где могли залипнуть кастомные
	# бинды/режим от прошлых прогонов. Жёстко сбрасываем клавиатуру И геймпад к
	# дефолтам (ultimate → клавиша R + joypad Y) до первых проверок.
	main.set("input_mode", "auto")
	main.set("gamepad_bindings", {})
	if mgr.has_method("set_input_mode"):
		mgr.set_input_mode("auto")
	if mgr.has_method("reset_gamepad_bindings_to_defaults"):
		mgr.reset_gamepad_bindings_to_defaults()
	main.ui._reset_input_bindings_to_defaults()
	await process_frame
	await process_frame

	if not await _test_controls_tab_widgets(main):
		return
	if not await _test_gamepad_button_rebind(main):
		return
	if not await _test_gamepad_conflict(main):
		return
	if not await _test_keyboard_rebind_preserves_joypad(main):
		return
	if not await _test_axis_rebind(main):
		return
	_test_persistence_round_trip(main)
	_test_legacy_settings_compat()

	main.queue_free()
	await process_frame


func _find(main, node_name: String) -> Node:
	return main.find_child(node_name, true, false)


func _action_has_joy_button(action: String, button: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and int(event.button_index) == button:
			return true
	return false


func _action_has_joy_axis(action: String, axis: int, value: float) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and int(event.axis) == axis \
				and signf(event.axis_value) == signf(value):
			return true
	return false


func _action_has_key(action: String, keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var kc: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
			if kc == keycode:
				return true
	return false


func _test_controls_tab_widgets(main) -> bool:
	main.ui._show_settings_menu()
	await process_frame
	await process_frame

	if not _expect(_find(main, "SettingsInputModeOption") != null, "нет OptionButton устройства ввода"):
		return false
	if not _expect(_find(main, "SettingsGamepadDeadzoneSlider") != null, "нет слайдера deadzone"):
		return false
	if not _expect(_find(main, "SettingsGamepadVibrationToggle") != null, "нет чекбокса вибрации"):
		return false
	if not _expect(_find(main, "SettingsResetGamepadButton") != null, "нет кнопки сброса геймпада"):
		return false
	for action in ["move_up", "pause", "ultimate", "open_level_up", "feedback"]:
		if not _expect(_find(main, "GamepadBindButton_%s" % action) != null, "нет кнопки ребинда геймпада для %s" % action):
			return false

	var status := _find(main, "SettingsGamepadStatus") as Label
	if not _expect(status != null and status.text != "", "строка статуса геймпада пуста"):
		return false

	# Дефолтная раскладка показана до любых ребиндов: ultimate → Y (из InputMap, не хардкод).
	var ult_btn := _find(main, "GamepadBindButton_ultimate") as Button
	if not _expect(ult_btn != null and ult_btn.text == "Y", "ultimate дефолт-биндинг геймпада не «Y» (текст: «%s»)" % (ult_btn.text if ult_btn != null else "?")):
		return false
	return true


func _test_gamepad_button_rebind(main) -> bool:
	main.ui._begin_gamepad_rebind("ultimate")
	await process_frame
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	main.call("_input", event)
	await process_frame
	await process_frame

	var bindings = main.get("gamepad_bindings")
	if not _expect(bindings is Dictionary and bindings.has("ultimate"), "gamepad_bindings не содержит ultimate после ребинда"):
		return false
	var buttons: Array = (bindings["ultimate"] as Dictionary).get("buttons", [])
	if not _expect(buttons.has(JOY_BUTTON_X), "ultimate не назначен на X"):
		return false
	if not _expect(_action_has_joy_button("ultimate", JOY_BUTTON_X), "InputMap ultimate без X"):
		return false
	if not _expect(not _action_has_joy_button("ultimate", JOY_BUTTON_Y), "InputMap ultimate всё ещё с Y (joypad-часть не заменена)"):
		return false
	# Клавиатурный биндинг ultimate (R) не тронут joypad-ребиндом.
	if not _expect(_action_has_key("ultimate", KEY_R), "ultimate потерял клавишу R после joypad-ребинда"):
		return false

	# Настройки перестроились (commit зовёт _show_settings_menu) — кнопка показывает X.
	var ult_btn := _find(main, "GamepadBindButton_ultimate") as Button
	if not _expect(ult_btn != null and ult_btn.text == "X", "кнопка ultimate не показывает X (текст: «%s»)" % (ult_btn.text if ult_btn != null else "?")):
		return false
	return true


func _test_gamepad_conflict(main) -> bool:
	# open_level_up по умолчанию RB. Назначаем RB на pause → конфликт, биндинг не меняется.
	main.ui._begin_gamepad_rebind("pause")
	await process_frame
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	event.pressed = true
	main.call("_input", event)
	await process_frame
	await process_frame

	var retry_button := _find(main, "GamepadRebindConflictRetryButton") as Button
	var back_button := _find(main, "GamepadRebindConflictBackButton") as Button
	if not _expect(retry_button != null, "нет диалога конфликта геймпада"):
		return false
	if not _expect(back_button != null, "нет кнопки возврата в диалоге конфликта геймпада"):
		return false
	await process_frame
	var focus_owner := root.gui_get_focus_owner()
	if not _expect(focus_owner == retry_button, "диалог конфликта геймпада не фокусирует Retry для A/крестовины"):
		return false
	if not _expect(main.get("ui_escape_action") is Callable and (main.get("ui_escape_action") as Callable).is_valid(),
			"диалог конфликта геймпада не выставляет ui_escape_action для B/Esc"):
		return false
	if not _expect(_action_has_joy_button("pause", JOY_BUTTON_START), "pause потерял Start при конфликте"):
		return false
	if not _expect(not _action_has_joy_button("pause", JOY_BUTTON_RIGHT_SHOULDER), "pause получил RB несмотря на конфликт"):
		return false
	if not _expect(_action_has_joy_button("open_level_up", JOY_BUTTON_RIGHT_SHOULDER), "open_level_up потерял RB"):
		return false
	if not _expect(str(main.get("pending_rebind_action")) == "", "конфликт геймпада должен сбрасывать pending_rebind_action"):
		return false
	var accept_event := InputEventJoypadButton.new()
	accept_event.button_index = JOY_BUTTON_A
	accept_event.pressed = true
	main.call("_input", accept_event)
	await process_frame
	if not _expect(not _action_has_joy_button("pause", JOY_BUTTON_A), "A из conflict-dialog не должен назначаться на pause"):
		return false
	var cancel_event := InputEventJoypadButton.new()
	cancel_event.button_index = JOY_BUTTON_B
	cancel_event.pressed = true
	main.call("_input", cancel_event)
	await process_frame
	await process_frame
	if not _expect(_find(main, "GamepadRebindConflictRetryButton") == null, "B/ui_cancel не закрывает диалог конфликта геймпада"):
		return false

	main.ui._cancel_gamepad_rebind()
	await process_frame
	await process_frame
	return true


func _test_keyboard_rebind_preserves_joypad(main) -> bool:
	# ultimate сейчас: joypad X (тест 2) + клавиша R. Ребиндим клавишу на T.
	main.ui._begin_rebind("ultimate")
	await process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_T
	event.pressed = true
	main.call("_input", event)
	await process_frame
	await process_frame

	if not _expect(_action_has_key("ultimate", KEY_T), "ultimate не получил клавишу T"):
		return false
	if not _expect(not _action_has_key("ultimate", KEY_R), "ultimate сохранил старую клавишу R"):
		return false
	# Баг-фикс: клавиатурный ребинд не должен стирать joypad-события.
	if not _expect(_action_has_joy_button("ultimate", JOY_BUTTON_X), "клавиатурный ребинд стёр joypad X (регресс баг-фикса SCRUM-811)"):
		return false
	return true


func _test_axis_rebind(main) -> bool:
	# feedback → наклон правого стика вправо (RIGHT_X, +1.0) по порогу |value|>0.5.
	main.ui._begin_gamepad_rebind("feedback")
	await process_frame
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_RIGHT_X
	event.axis_value = 1.0
	main.call("_input", event)
	await process_frame
	await process_frame

	if not _expect(_action_has_joy_axis("feedback", JOY_AXIS_RIGHT_X, 1.0), "feedback не назначен на ось RIGHT_X+"):
		return false
	var bindings = main.get("gamepad_bindings")
	if not _expect(bindings is Dictionary and bindings.has("feedback"), "gamepad_bindings без feedback после ось-ребинда"):
		return false
	return true


func _test_persistence_round_trip(main) -> void:
	main.set("input_mode", "gamepad")
	main.set("gamepad_deadzone", 0.35)
	main.set("gamepad_vibration", false)
	main.set("gamepad_bindings", {"ultimate": {"buttons": [JOY_BUTTON_X], "axes": []}})
	main.call("save_game_settings")

	var loaded := GameSettings.load_settings()
	_expect(str(loaded.get("input_mode")) == "gamepad", "round-trip: input_mode не gamepad")
	_expect(absf(float(loaded.get("gamepad_deadzone")) - 0.35) < 0.001, "round-trip: deadzone не 0.35")
	_expect(bool(loaded.get("gamepad_vibration")) == false, "round-trip: vibration не false")
	var bindings = loaded.get("gamepad_bindings")
	if _expect(bindings is Dictionary and bindings.has("ultimate"), "round-trip: gamepad_bindings.ultimate потерян"):
		var buttons: Array = (bindings["ultimate"] as Dictionary).get("buttons", [])
		_expect(buttons.has(JOY_BUTTON_X), "round-trip: ultimate.buttons без X")


func _test_legacy_settings_compat() -> void:
	# Старый settings.cfg без gamepad-ключей грузится с дефолтами и без падений.
	var config := ConfigFile.new()
	config.set_value("settings", "master_volume", 0.8)
	config.set_value("settings", "aim_mode", "cursor")
	config.save(SAVE_PATH)

	var loaded := GameSettings.load_settings()
	_expect(str(loaded.get("input_mode")) == "auto", "legacy: input_mode дефолт не auto")
	_expect(loaded.get("gamepad_bindings") is Dictionary, "legacy: gamepad_bindings не Dictionary")
	var deadzone := float(loaded.get("gamepad_deadzone", -1.0))
	_expect(deadzone >= 0.05 and deadzone <= 0.5, "legacy: gamepad_deadzone вне [0.05..0.5]")
	_expect(loaded.get("gamepad_vibration") is bool, "legacy: gamepad_vibration не bool")
