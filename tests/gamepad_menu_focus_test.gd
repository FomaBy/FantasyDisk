extends "res://tests/runtime_smoke_test.gd"

# SCRUM-813: геймпад/стрелочная фокус-навигация мета-меню (вне забега).
# Проверяем на каждом ключевом экране: детерминированный стартовый фокус (этого
# достаточно, чтобы D-pad листал, а A подтверждал — движок жмёт сфокусированную
# кнопку по ui_accept), B (ui_cancel) закрывает попап через main._input, и LB/RB
# листают вкладки настроек / секции кодекса (ui._handle_menu_shoulder_nav).


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for gamepad menu focus test.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if not await _test_main_menu_focus_and_quit_cancel(main):
		return
	if not await _test_weapon_and_boon_focus(main):
		return
	if not await _test_skill_tree_focus(main):
		return
	if not await _test_patch_notes_focus(main):
		return
	if not await _test_codex_focus_and_shoulder(main):
		return
	if not await _test_settings_focus_and_shoulder(main):
		return

	main.queue_free()
	await process_frame
	print("Gamepad menu focus navigation test passed.")
	quit()


func _focus_owner(main) -> Control:
	var vp: Viewport = main.get_viewport()
	if vp == null:
		return null
	return vp.gui_get_focus_owner()


func _focus_name(main) -> String:
	var f := _focus_owner(main)
	return str(f.name) if f != null else ""


func _test_main_menu_focus_and_quit_cancel(main) -> bool:
	# Главное меню показано при старте. Стартовый фокус — «Начать новую игру».
	main.ui._show_main_menu()
	await process_frame
	await process_frame
	if _focus_name(main) != "MainMenuStartButton":
		_fail("SCRUM-813: стартовый фокус главного меню — MainMenuStartButton, получено: %s" % [_focus_name(main)])
		return false
	# Диалог выхода: B (joypad ui_cancel) закрывает его (ui_escape_action).
	main.ui._show_quit_confirmation_dialog()
	await process_frame
	await process_frame
	if main.find_child("QuitConfirmationDialog", true, false) == null:
		_fail("SCRUM-813: диалог выхода не открылся.")
		return false
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	main.call("_input", cancel)
	await process_frame
	await process_frame
	if main.find_child("QuitConfirmationDialog", true, false) != null:
		_fail("SCRUM-813: B (joypad) должен закрыть диалог выхода.")
		return false
	return true


func _test_weapon_and_boon_focus(main) -> bool:
	main.set("selected_character_id", "berserk")
	main.ui._show_weapon_select()
	await process_frame
	await process_frame
	if not _focus_name(main).begins_with("WeaponOption_"):
		_fail("SCRUM-813: стартовый фокус выбора оружия — первая карточка, получено: %s" % [_focus_name(main)])
		return false
	main.set("selected_weapon_id", "sword")
	main.ui._show_start_boon_select()
	await process_frame
	await process_frame
	var boon_focus := _focus_name(main)
	if not (boon_focus.begins_with("StartBoonOption_") or boon_focus == "StartBoonSkipButton"):
		_fail("SCRUM-813: стартовый фокус выбора боона — карточка/«Без боона», получено: %s" % [boon_focus])
		return false
	return true


func _test_skill_tree_focus(main) -> bool:
	main.ui._show_skill_tree_screen()
	await process_frame
	await process_frame
	if _focus_name(main) != "SkillTreeClassSelector":
		_fail("SCRUM-813: стартовый фокус дерева умений — SkillTreeClassSelector, получено: %s" % [_focus_name(main)])
		return false
	return true


func _test_patch_notes_focus(main) -> bool:
	main.ui._show_patch_notes_screen()
	await process_frame
	await process_frame
	if _focus_name(main) != "PatchNotesBackButton":
		_fail("SCRUM-813: стартовый фокус патч-ноутов — PatchNotesBackButton, получено: %s" % [_focus_name(main)])
		return false
	return true


func _codex_active_section(main) -> String:
	if main.ui_layer == null or not is_instance_valid(main.ui_layer):
		return ""
	for node in main.ui_layer.find_children("*", "PanelContainer", true, false):
		if node.has_meta("codex_active_section"):
			return str(node.get_meta("codex_active_section", ""))
	return ""


func _test_codex_focus_and_shoulder(main) -> bool:
	main.ui._show_codex_screen()
	await process_frame
	await process_frame
	if _focus_name(main) != "CodexTab_characters":
		_fail("SCRUM-813: стартовый фокус кодекса — CodexTab_characters, получено: %s" % [_focus_name(main)])
		return false
	var before := _codex_active_section(main)
	if before != "characters":
		_fail("SCRUM-813: активная секция кодекса на старте — characters, получено: %s" % [before])
		return false
	# RB (правый бампер) через main._input листает секцию вперёд.
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	main.call("_input", rb)
	await process_frame
	await process_frame
	var after := _codex_active_section(main)
	if after == "" or after == before:
		_fail("SCRUM-813: RB должен пролистнуть секцию кодекса (было %s, стало %s)." % [before, after])
		return false
	# LB возвращает назад к characters.
	var lb := InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb.pressed = true
	main.call("_input", lb)
	await process_frame
	await process_frame
	if _codex_active_section(main) != before:
		_fail("SCRUM-813: LB должен вернуть секцию кодекса к %s, получено %s." % [before, _codex_active_section(main)])
		return false
	return true


func _settings_current_tab(main) -> int:
	if main.ui_layer == null or not is_instance_valid(main.ui_layer):
		return -1
	var settings_root: Node = main.ui_layer.find_child("SettingsV2Root", true, false)
	if settings_root == null:
		return -1
	var containers := settings_root.find_children("*", "TabContainer", true, false)
	if containers.is_empty():
		return -1
	return (containers[0] as TabContainer).current_tab


func _test_settings_focus_and_shoulder(main) -> bool:
	main.ui._show_settings_menu()
	await process_frame
	await process_frame
	if _focus_name(main) != "SettingsTabButton_0":
		_fail("SCRUM-813: стартовый фокус настроек — SettingsTabButton_0, получено: %s" % [_focus_name(main)])
		return false
	if _settings_current_tab(main) != 0:
		_fail("SCRUM-813: активная вкладка настроек на старте — 0, получено: %d" % [_settings_current_tab(main)])
		return false
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	main.call("_input", rb)
	await process_frame
	await process_frame
	if _settings_current_tab(main) != 1:
		_fail("SCRUM-813: RB должен переключить вкладку настроек на 1, получено: %d" % [_settings_current_tab(main)])
		return false
	return true
