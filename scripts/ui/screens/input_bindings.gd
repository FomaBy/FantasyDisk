extends "res://scripts/ui/screens/run_encounters.gd"

# FAN-3824: модуль распределённого UI-класса — клавиатурный и геймпадный ребинд, статус устройств.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _setup_default_input_actions() -> void:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		# SCRUM-830: гардим по отсутствию именно КЛАВИАТУРНОГО (InputEventKey) события,
		# а не по is_empty(). Автолоад InputDeviceManager (SCRUM-811) может предзасеять
		# joypad-события в глобальный InputMap ДО этого вызова (гонка старта под нагрузкой);
		# тогда is_empty()=false и клавиатурные дефолты (Escape=pause, R=ultimate и др.)
		# терялись — Escape не открывал quit-диалог, R не давал ультимейт. Проверка «нет
		# key-события» доливает клавиатуру идемпотентно, joypad не трогая
		# (_apply_keycodes_to_action стирает только key-события).
		if not _action_has_key_event(action_name):
			_apply_keycodes_to_action(action_name, _default_keycodes_for_action(input_action))
	_apply_saved_input_bindings()




func _action_has_key_event(action_name: String) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return true
	return false




func _apply_saved_input_bindings() -> void:
	var saved_bindings: Dictionary = game.input_bindings
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var saved_keys: Array = saved_bindings.get(action_name, [])
		if saved_keys.is_empty():
			continue
		_apply_keycodes_to_action(action_name, saved_keys)




func _default_keycodes_for_action(input_action: Dictionary) -> Array:
	var keys := []
	var default_key := int(input_action.get("default_key", 0))
	var alternate_key := int(input_action.get("alternate_key", 0))
	if default_key != 0:
		keys.append(default_key)
	if alternate_key != 0 and alternate_key != default_key:
		keys.append(alternate_key)
	return keys




func _apply_keycodes_to_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	# SCRUM-816 баг-фикс: раньше здесь был action_erase_events, стиравший ВСЕ события
	# экшена — включая joypad-биндинги ядра (SCRUM-811). Клавиатурный ребинд/применение
	# сохранённых клавиш ронял геймпад. Теперь трогаем только InputEventKey.
	# ВАЖНО: НЕ звать здесь ensure_joypad_bindings — это примитив, используемый в
	# цикле _setup_default_input_actions. Долив joypad всем экшенам в середине цикла
	# сделал бы ещё-не-обработанные экшены «непустыми» и клавиатурные дефолты бы
	# пропустились. Долив делает менеджер (autoload) после первого кадра, а в
	# пользовательских ребиндах — вызывающие (_handle_rebind_input/reset) явно.
	_erase_key_events(action_name)
	for keycode_value in keycodes:
		var keycode := int(keycode_value)
		if keycode == 0:
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)




func _erase_key_events(action_name: String) -> void:
	# Стереть только клавиатурные события экшена, не трогая joypad-биндинги.
	if not InputMap.has_action(action_name):
		return
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			InputMap.action_erase_event(action_name, event)




func _input_device_manager() -> Node:
	# Автолоад InputDeviceManager (SCRUM-811). null-safe для тестов без автолоада.
	if game == null:
		return null
	var tree = game.get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("InputDeviceManager")




func _ensure_joypad_after_rebind() -> void:
	var idm := _input_device_manager()
	if idm != null and idm.has_method("ensure_joypad_bindings"):
		idm.ensure_joypad_bindings()




func _current_input_bindings() -> Dictionary:
	var result := {}
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var keys := []
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
				if keycode != 0:
					keys.append(keycode)
		result[action_name] = keys
	return result




func _apply_game_cursor() -> void:
	var arrow_texture: Texture2D = game._cached_texture(game.GAME_CURSOR_PATH)
	if arrow_texture == null:
		return
	Input.set_custom_mouse_cursor(arrow_texture, Input.CURSOR_ARROW, game.GAME_CURSOR_HOTSPOT)

	var hover_texture: Texture2D = game._cached_texture(str(SHOP_CURSOR_VARIANTS["pointing_hand"]))
	if hover_texture != null:
		Input.set_custom_mouse_cursor(hover_texture, Input.CURSOR_POINTING_HAND, game.GAME_CURSOR_HOTSPOT)

	var attack_texture: Texture2D = game._cached_texture(str(SHOP_CURSOR_VARIANTS["cross"]))
	if attack_texture != null:
		Input.set_custom_mouse_cursor(attack_texture, Input.CURSOR_CROSS, game.GAME_CURSOR_HOTSPOT)




func _begin_rebind(action_name: String) -> void:
	game.pending_rebind_action = action_name
	_rebind_is_gamepad = false
	var label := _action_label(action_name)
	var box := _create_menu_box("Клавиша: %s" % label, "Нажми новую клавишу. Esc отменяет.", "settings")

	var cancel_button := _make_button("Отмена")
	cancel_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	box.add_child(cancel_button)




func _handle_rebind_input(event: InputEvent) -> void:
	# SCRUM-816: один диспетчер на два режима прослушивания. В режиме геймпада ждём
	# joypad-кнопку/ось, в клавиатурном — клавишу. Роутинг из main._input по
	# game.pending_rebind_action; _rebind_is_gamepad различает режим.
	if _rebind_is_gamepad:
		_handle_gamepad_rebind_input(event)
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		game.pending_rebind_action = ""
		_show_settings_menu()
		return

	var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
	var conflict_action := _binding_conflict_action(game.pending_rebind_action, keycode)
	if conflict_action != "":
		_show_rebind_conflict(game.pending_rebind_action, keycode, conflict_action)
		return

	# SCRUM-816 баг-фикс: только клавиатурные события, joypad ядра не затираем.
	_erase_key_events(game.pending_rebind_action)
	var new_event := InputEventKey.new()
	new_event.keycode = keycode
	new_event.physical_keycode = event.physical_keycode
	InputMap.action_add_event(game.pending_rebind_action, new_event)
	_ensure_joypad_after_rebind()

	game.input_bindings = _current_input_bindings()
	game.save_game_settings()
	game.pending_rebind_action = ""
	_show_settings_menu()




func _handle_gamepad_rebind_input(event: InputEvent) -> void:
	# Отмена: Esc (клавиатура) или B (ui_cancel). B в этот момент НЕ назначается.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_gamepad_rebind()
		return
	if event is InputEventJoypadButton and event.pressed and int(event.button_index) == JOY_BUTTON_B:
		_cancel_gamepad_rebind()
		return

	if event is InputEventJoypadButton and event.pressed:
		_assign_gamepad_button(game.pending_rebind_action, int(event.button_index))
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) > GAMEPAD_REBIND_ACTIVATION:
		var value := 1.0 if event.axis_value > 0.0 else -1.0
		_assign_gamepad_axis(game.pending_rebind_action, int(event.axis), value)
		return




func _cancel_gamepad_rebind() -> void:
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
	_show_settings_menu()




func _binding_conflict_action(target_action: String, keycode: int) -> String:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if action_name == target_action:
			continue
		for existing_event in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey:
				var existing_key: int = int(existing_event.keycode if existing_event.keycode != 0 else existing_event.physical_keycode)
				if existing_key == keycode:
					return action_name
	return ""




func _show_rebind_conflict(target_action: String, keycode: int, conflict_action: String) -> void:
	var target_label := _action_label(target_action)
	var conflict_label := _action_label(conflict_action)
	var key_name := OS.get_keycode_string(keycode)
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "RebindConflictDialog"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, "settings")

	var panel := Panel.new()
	panel.name = "RebindConflictPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -RC_PANEL_2K.size.x * 0.5
	panel.offset_top = -RC_PANEL_2K.size.y * 0.5
	panel.offset_right = RC_PANEL_2K.size.x * 0.5
	panel.offset_bottom = RC_PANEL_2K.size.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("rc_panel", RC_PANEL_2K.size))
	panel.set_meta("rebind_conflict_stage", "openai_mockup_ready_runtime_rc_assets")
	panel.set_meta("rebind_conflict_slot", "rc_panel")
	panel.set_meta("rebind_conflict_content_margins", _overhaul_2k_content_margins("rc_panel", RC_PANEL_2K.size))
	panel.set_meta("rebind_conflict_content_rect", Rect2(RC_SAFE_2K.position - RC_PANEL_2K.position, RC_SAFE_2K.size))
	root.add_child(panel)

	var title_label := Label.new()
	title_label.name = "RebindConflictTitle"
	title_label.text = "Клавиша занята"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 36, 0, 40))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	panel.add_child(title_label)
	title_label.position = RC_TITLE_2K.position - RC_PANEL_2K.position
	title_label.size = RC_TITLE_2K.size

	var message_label := Label.new()
	message_label.name = "RebindConflictMessage"
	message_label.text = "%s занята: «%s». Для «%s» выбери другую." % [key_name, conflict_label, target_label]
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_label.clip_text = true
	message_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_BODY, 18, 0, 24))
	message_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
	panel.add_child(message_label)
	message_label.position = RC_MESSAGE_2K.position - RC_PANEL_2K.position
	message_label.size = RC_MESSAGE_2K.size

	var retry_button := _make_button("Выбрать другую")
	retry_button.name = "RebindConflictRetryButton"
	_set_action_button_size(retry_button, RC_BTN_RETRY_2K.size.x, RC_BTN_RETRY_2K.size.y)
	_apply_overhaul_2k_button_theme(retry_button, "rc_btn", RC_BTN_RETRY_2K.size)
	retry_button.clip_text = true
	retry_button.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 18, 0, 18))
	retry_button.pressed.connect(func() -> void:
		_begin_rebind(target_action)
	)
	panel.add_child(retry_button)
	retry_button.position = RC_BTN_RETRY_2K.position - RC_PANEL_2K.position
	retry_button.size = RC_BTN_RETRY_2K.size
	var back_button := _make_button("Настройки")
	back_button.name = "RebindConflictBackButton"
	_set_action_button_size(back_button, RC_BTN_BACK_2K.size.x, RC_BTN_BACK_2K.size.y)
	_apply_overhaul_2k_button_theme(back_button, "rc_btn", RC_BTN_BACK_2K.size)
	back_button.clip_text = true
	back_button.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 18, 0, 18))
	back_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	panel.add_child(back_button)
	back_button.position = RC_BTN_BACK_2K.position - RC_PANEL_2K.position
	back_button.size = RC_BTN_BACK_2K.size
	retry_button.focus_neighbor_right = back_button.get_path()
	retry_button.focus_neighbor_left = back_button.get_path()
	back_button.focus_neighbor_left = retry_button.get_path()
	back_button.focus_neighbor_right = retry_button.get_path()
	retry_button.grab_focus()




func _reset_input_bindings_to_defaults() -> void:
	for input_action in game.INPUT_ACTIONS:
		_apply_keycodes_to_action(str(input_action["action"]), _default_keycodes_for_action(input_action))
	# После сброса клавиатуры один раз доливаем joypad (эрейз клавиш их не трогал,
	# но страхуемся и на случай, если экшен был свежесоздан).
	_ensure_joypad_after_rebind()
	game.input_bindings = _current_input_bindings()
	game.save_game_settings()




func _binding_text(action_name: String) -> String:
	# Только клавиатурные события: joypad-биндинги ядра (SCRUM-811) теперь живут в
	# том же экшене, но у клавиатурной кнопки-ребинда показываем лишь клавиши.
	var labels := []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
			labels.append(OS.get_keycode_string(keycode))
	if labels.is_empty():
		return "Не назначено"
	return " / ".join(labels)




# --- SCRUM-816: геймпад — текст биндингов, ребинд, статус устройства ---

func _gamepad_binding_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "Не назначено"
	var labels := []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			labels.append(_gamepad_button_label(int(event.button_index)))
		elif event is InputEventJoypadMotion:
			labels.append(_gamepad_axis_label(int(event.axis), float(event.axis_value)))
	if labels.is_empty():
		return "Не назначено"
	return " / ".join(labels)




func _gamepad_button_label(button_index: int) -> String:
	return GAMEPAD_BUTTON_LABELS.get(button_index, "Кнопка %d" % button_index)




func _gamepad_axis_label(axis: int, value: float) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "Стик ←" if value < 0.0 else "Стик →"
		JOY_AXIS_LEFT_Y:
			return "Стик ↑" if value < 0.0 else "Стик ↓"
		JOY_AXIS_RIGHT_X:
			return "Пр. стик ←" if value < 0.0 else "Пр. стик →"
		JOY_AXIS_RIGHT_Y:
			return "Пр. стик ↑" if value < 0.0 else "Пр. стик ↓"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "Ось %d" % axis




func _gamepad_glyph_for_action(action_name: String) -> Texture2D:
	# Иконка первого joypad-события экшена, если ассет-манифест существует (SCRUM-810).
	# null-safe: нет ассета → null → показываем только текст.
	if not InputMap.has_action(action_name):
		return null
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			return InputGlyphRegistry.texture_for_joy_button(int(event.button_index), 32)
		elif event is InputEventJoypadMotion:
			return InputGlyphRegistry.texture_for_axis(int(event.axis), 32)
	return null




func _begin_gamepad_rebind(action_name: String) -> void:
	game.pending_rebind_action = action_name
	_rebind_is_gamepad = true
	var label := _action_label(action_name)
	var box := _create_menu_box("Геймпад: %s" % label, "Нажми кнопку или наклони стик. B/Esc отменяет.", "settings")

	var cancel_button := _make_button("Отмена")
	cancel_button.pressed.connect(func() -> void:
		_cancel_gamepad_rebind()
	)
	box.add_child(cancel_button)




func _assign_gamepad_button(action_name: String, button_index: int) -> void:
	var conflict := _gamepad_button_conflict(action_name, button_index)
	if conflict != "":
		_show_gamepad_rebind_conflict(action_name, _gamepad_button_label(button_index), conflict)
		return
	_commit_gamepad_binding(action_name, {"buttons": [button_index], "axes": []})




func _assign_gamepad_axis(action_name: String, axis: int, value: float) -> void:
	var conflict := _gamepad_axis_conflict(action_name, axis, value)
	if conflict != "":
		_show_gamepad_rebind_conflict(action_name, _gamepad_axis_label(axis, value), conflict)
		return
	_commit_gamepad_binding(action_name, {"buttons": [], "axes": [{"axis": axis, "value": value}]})




func _commit_gamepad_binding(action_name: String, binding: Dictionary) -> void:
	# Заменяет только joypad-часть экшена; клавиатурные события не трогаются
	# (ensure_joypad_bindings внутри set_gamepad_bindings стирает лишь joypad).
	if not (game.gamepad_bindings is Dictionary):
		game.gamepad_bindings = {}
	game.gamepad_bindings[action_name] = binding
	var idm := _input_device_manager()
	if idm != null and idm.has_method("set_gamepad_bindings"):
		idm.set_gamepad_bindings(game.gamepad_bindings)
	else:
		# Тесты без автолоада: применяем joypad-часть локально, детерминированно.
		_apply_gamepad_binding_local(action_name, binding)
	game.save_game_settings()
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
	_show_settings_menu()




func _apply_gamepad_binding_local(action_name: String, binding: Dictionary) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(action_name, event)
	for button_index in binding.get("buttons", []):
		var btn := InputEventJoypadButton.new()
		btn.button_index = int(button_index) as JoyButton
		InputMap.action_add_event(action_name, btn)
	for axis_binding in binding.get("axes", []):
		var motion := InputEventJoypadMotion.new()
		motion.axis = int(axis_binding.get("axis", 0)) as JoyAxis
		motion.axis_value = float(axis_binding.get("value", 1.0))
		InputMap.action_add_event(action_name, motion)




func _gamepad_button_conflict(target_action: String, button_index: int) -> String:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if action_name == target_action:
			continue
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton and int(event.button_index) == button_index:
				return action_name
	return ""




func _gamepad_axis_conflict(target_action: String, axis: int, value: float) -> String:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if action_name == target_action:
			continue
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadMotion and int(event.axis) == axis \
					and signf(event.axis_value) == signf(value):
				return action_name
	return ""




func _show_gamepad_rebind_conflict(target_action: String, binding_desc: String, conflict_action: String) -> void:
	# Тот же UX, что и у клавиатурного конфликта (_show_rebind_conflict), но текст
	# про кнопку/ось геймпада. «Выбрать другую» перезапускает прослушивание.
	var target_label := _action_label(target_action)
	var conflict_label := _action_label(conflict_action)
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
	var box := _create_menu_box("Кнопка занята",
		"%s занята: «%s». Для «%s» выбери другую." % [binding_desc, conflict_label, target_label], "settings")

	var retry_button := _make_button("Выбрать другую")
	retry_button.name = "GamepadRebindConflictRetryButton"
	retry_button.pressed.connect(func() -> void:
		_begin_gamepad_rebind(target_action)
	)
	box.add_child(retry_button)

	var back_button := _make_button("Настройки")
	back_button.name = "GamepadRebindConflictBackButton"
	back_button.pressed.connect(func() -> void:
		_cancel_gamepad_rebind()
	)
	box.add_child(back_button)
	_wire_run_ui_focus([retry_button, back_button], true, [], retry_button)
	game.ui_escape_action = _cancel_gamepad_rebind




func _reset_gamepad_bindings_to_defaults() -> void:
	game.gamepad_bindings = {}
	var idm := _input_device_manager()
	if idm != null and idm.has_method("reset_gamepad_bindings_to_defaults"):
		idm.reset_gamepad_bindings_to_defaults()
	game.save_game_settings()
	_show_settings_menu()




func _refresh_gamepad_status_line() -> void:
	if _gamepad_status_label == null or not is_instance_valid(_gamepad_status_label):
		return
	var idm := _input_device_manager()
	var connected := false
	var pad_name := ""
	if idm != null and idm.has_method("gamepad_connected"):
		connected = idm.gamepad_connected()
		pad_name = idm.gamepad_name()
	else:
		var pads := Input.get_connected_joypads()
		connected = not pads.is_empty()
		pad_name = Input.get_joy_name(int(pads[0])) if not pads.is_empty() else ""
	if connected:
		_gamepad_status_label.text = "Геймпад: %s подключён" % (pad_name if pad_name != "" else "устройство")
	else:
		_gamepad_status_label.text = "Геймпад не обнаружен"




func _connect_gamepad_status_signals() -> void:
	# Идемпотентно: ui_screens живёт всю сессию, коллбэки гардятся валидностью Label.
	if not Input.joy_connection_changed.is_connected(_on_gamepad_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_gamepad_joy_connection_changed)
	var idm := _input_device_manager()
	if idm != null and idm.has_signal("device_changed") \
			and not idm.device_changed.is_connected(_on_gamepad_device_changed):
		idm.device_changed.connect(_on_gamepad_device_changed)




func _on_gamepad_device_changed(_kind: String) -> void:
	_refresh_gamepad_status_line()
	AimController.apply_hint_label(_aim_mode_hint_label, game.aim_mode, _input_device_manager())




func _on_gamepad_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_gamepad_status_line()
	AimController.apply_hint_label(_aim_mode_hint_label, game.aim_mode, _input_device_manager())




func _action_label(action_name: String) -> String:
	for input_action in game.INPUT_ACTIONS:
		if input_action["action"] == action_name:
			return input_action["label"]

	return action_name
