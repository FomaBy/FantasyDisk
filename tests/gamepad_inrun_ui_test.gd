extends "res://tests/runtime_smoke_test.gd"

# SCRUM-812: геймпад/стрелочная навигация внутризабеговых экранов.
# Проверяем: (1) A→ui_accept и B→ui_cancel доведены в рантайме (в сборке их нет);
# (2) у каждого экрана есть детерминированный стартовый фокус на нужном контроле —
#     этого достаточно, чтобы D-pad листал, а A подтверждал (движок сам жмёт
#     сфокусированную кнопку по ui_accept); (3) level-up ставит дерево на паузу
#     (move_* не дёргают игрока, требование #8); (4) B (joypad) закрывает паузу-оверлей
#     через main._input; (5) карта маршрута — доступный нод получает фокус и активируется
#     по pressed (A/мышь идут одним путём, латч гасит двойную активацию).


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for gamepad in-run UI test.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 2)
	main.call("_start_combat")
	await process_frame
	await process_frame

	if not await _test_gamepad_bindings(main):
		return
	if not await _test_level_up_focus_and_pause(main):
		return
	if not await _test_reward_focus(main):
		return
	if not await _test_pause_menu_focus_and_cancel(main):
		return
	if not await _test_death_focus(main):
		return
	if not await _test_upgrade_focus(main):
		return
	if not await _test_shop_focus(main):
		return
	if not await _test_route_map_focus_and_activate(main):
		return

	main.queue_free()
	await process_frame
	_finish("Gamepad in-run UI navigation test passed.")


func _focus_owner(main) -> Control:
	var vp: Viewport = main.get_viewport()
	if vp == null:
		return null
	return vp.gui_get_focus_owner()


func _action_has_joy_button(action: String, button: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false


func _test_gamepad_bindings(main) -> bool:
	# Разводка фокуса любого экрана доводит A/B; берём level-up как триггер.
	main.set("pending_level_ups", 1)
	main.ui._open_pending_level_up()
	await process_frame
	await process_frame
	if not _action_has_joy_button("ui_accept", JOY_BUTTON_A):
		_fail("SCRUM-812: ui_accept должен получить JOY_BUTTON_A (A) в рантайме.")
		return false
	if not _action_has_joy_button("ui_cancel", JOY_BUTTON_B):
		_fail("SCRUM-812: ui_cancel должен получить JOY_BUTTON_B (B) в рантайме.")
		return false
	return true


func _test_level_up_focus_and_pause(main) -> bool:
	# level-up уже открыт из _test_gamepad_bindings (pending=1). Пауза + стартовый фокус.
	if not bool(main.get_tree().paused):
		_fail("SCRUM-812: level-up должен ставить дерево на паузу (гейт move_* в игрока).")
		return false
	var focus := _focus_owner(main)
	if focus == null or not str(focus.name).begins_with("LevelUpRewardButton"):
		_fail("SCRUM-812: стартовый фокус level-up — первая карточка, получено: %s" % [focus])
		return false
	# «Позже» достижима вниз (ui_down): у карточки focus_neighbor_bottom указывает на неё.
	var later := main.find_child("LevelUpLaterButton", true, false) as Button
	if later == null or later.focus_mode != Control.FOCUS_ALL:
		_fail("SCRUM-812: кнопка «Позже» должна быть фокусируемой (ui_down).")
		return false
	# Закрываем level-up без выбора, снимаем паузу.
	if main.ui_escape_action.is_valid():
		main.ui_escape_action.call()
	await process_frame
	await process_frame
	return true


func _test_reward_focus(main) -> bool:
	main.ui._show_reward_screen()
	await process_frame
	await process_frame
	var focus := _focus_owner(main)
	if focus == null or not str(focus.name).begins_with("BattleRewardButton"):
		_fail("SCRUM-812: стартовый фокус награды — первая карточка, получено: %s" % [focus])
		return false
	return true


func _test_pause_menu_focus_and_cancel(main) -> bool:
	# SCRUM-890: _show_pause_menu ВСЕГДА открывает досье героя; стартовый фокус —
	# первая кнопка шапки «Продолжить» (PauseResumeButton).
	main.ui._show_pause_menu(true)
	await process_frame
	await process_frame
	var focus := _focus_owner(main)
	var focus_name := str(focus.name) if focus != null else ""
	if focus == null or focus_name != "PauseResumeButton":
		_fail("SCRUM-812/890: стартовый фокус досье — «Продолжить» (PauseResumeButton), получено: %s" % [focus])
		return false
	if not main.ui._is_run_pause_overlay_open():
		_fail("SCRUM-812: пауза-оверлей должен быть открыт.")
		return false
	main.ui._show_settings_menu("run_pause")
	await process_frame
	await process_frame
	if not main.ui._is_settings_screen_open():
		_fail("SCRUM-844: настройки из паузы должны открывать SettingsV2Root.")
		return false
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	main.call("_input", escape)
	await process_frame
	await process_frame
	if main.ui._is_settings_screen_open():
		_fail("SCRUM-844: Esc из Settings должен вернуться к pause, а не оставить настройки поверх.")
		return false
	if not main.ui._is_run_pause_overlay_open():
		_fail("SCRUM-844: Esc из Settings, открытых из паузы, должен восстановить pause overlay.")
		return false
	# B (joypad) через main._input закрывает паузу (ui_cancel → _resume_game).
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	main.call("_input", cancel)
	await process_frame
	await process_frame
	if main.ui._is_run_pause_overlay_open():
		_fail("SCRUM-812: B (joypad) должен закрыть паузу-оверлей.")
		return false
	return true


func _test_death_focus(main) -> bool:
	main.ui._show_death_screen()
	await process_frame
	await process_frame
	var focus := _focus_owner(main)
	if focus == null or str(focus.name) != "DeathRetryButton":
		_fail("SCRUM-812: стартовый фокус экрана смерти — «Начать заново», получено: %s" % [focus])
		return false
	return true


func _test_upgrade_focus(main) -> bool:
	main.ui._show_upgrade_screen()
	await process_frame
	await process_frame
	var focus := _focus_owner(main)
	if focus == null or not str(focus.name).begins_with("UpgradeChoiceButton"):
		_fail("SCRUM-812: стартовый фокус улучшения — первая карточка, получено: %s" % [focus])
		return false
	return true


func _test_shop_focus(main) -> bool:
	main.set("current_shop_items", main.ui._random_shop_items(3))
	main.set("current_shop_purchased", [false, false, false])
	main.ui._show_shop_screen()
	await process_frame
	await process_frame
	var focus := _focus_owner(main)
	if focus == null or not (focus is Button):
		_fail("SCRUM-812: у магазина должен быть стартовый фокус на кнопке (товар/«Назад»), получено: %s" % [focus])
		return false
	return true


func _test_route_map_focus_and_activate(main) -> bool:
	# Ряд 0 всегда достижим (см. _is_route_node_reachable), поэтому его ноды «available»
	# и получают стартовый фокус независимо от истории выбора.
	main.set("route_stage", 0)
	main.set("route_selected_indices", [])
	main.route._show_battle_map()
	await process_frame
	await process_frame
	var focus := _focus_owner(main)
	if focus == null or not str(focus.name).begins_with("RouteNode_"):
		_fail("SCRUM-812: карта маршрута — стартовый фокус на доступном ноде, получено: %s" % [focus])
		return false
	if not (focus is Button) or (focus as Button).disabled:
		_fail("SCRUM-812: сфокусированный нод карты должен быть доступным (не disabled).")
		return false
	if focus.get_theme_stylebox("focus") == null:
		_fail("SCRUM-812: у выбранного нода карты должно быть заметное выделение (focus stylebox).")
		return false
	# Активация по A/pressed уводит с карты (латч гасит двойной вызов от мыши).
	var map_screen: Node = main.ui_layer.get_node_or_null("RouteMapScreen")
	focus.emit_signal("pressed")
	await process_frame
	await process_frame
	if map_screen != null and is_instance_valid(map_screen) and map_screen.get_parent() != null:
		_fail("SCRUM-812: активация нода (A/pressed) должна увести с карты маршрута.")
		return false
	return true
