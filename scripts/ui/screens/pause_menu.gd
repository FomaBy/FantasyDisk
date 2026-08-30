extends "res://scripts/ui/screens/settings_tabs.gd"

# FAN-3824: модуль распределённого UI-класса — пауза: меню, подтверждение завершения забега, досье.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _show_pause_menu(force := false) -> void:
	if not force and not _can_open_pause_dossier():
		return

	game.push_pause("escape_menu")
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		game.pause_overlay_layer.queue_free()
	game.pause_overlay_layer = CanvasLayer.new()
	game.pause_overlay_layer.name = "RunPauseOverlayLayer"
	game.pause_overlay_layer.layer = 120
	game.pause_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.pause_overlay_layer)
	game.pause_stats_menu = null
	# SCRUM-890: Esc в любой момент забега открывает сразу досье героя — промежуточное
	# простое меню паузы (RunPauseMenu) удалено, его функции живут в шапке досье.
	_show_pause_dossier_menu()




# SCRUM-883: модалка подтверждения «Завершить забег» из паузы — тот же стиль, что у
# quit-диалога главного меню: плотный atlas-чип, золотой титул, парные кнопки 240×72
# на нативной continue_240x72 family, стартовый фокус на безопасной «Отмене»,
# Esc/B и клик мимо панели отменяют только модалку (пауза остаётся).
func _show_end_run_confirmation_dialog() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	if game.pause_overlay_layer.find_child("EndRunConfirmationDialog", true, false) != null:
		var existing_cancel := game.pause_overlay_layer.find_child("EndRunConfirmCancelButton", true, false) as Button
		if existing_cancel != null:
			existing_cancel.grab_focus()
		return

	var overlay := Control.new()
	overlay.name = "EndRunConfirmationDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	game.pause_overlay_layer.add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "EndRunConfirmationDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "EndRunConfirmationPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -170.0
	panel.offset_right = 300.0
	panel.offset_bottom = 170.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.97, roundf(20.0 * _atlas_ui_scale())))
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "EndRunConfirmationTitle"
	title_label.text = "Завершить забег?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 34))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "EndRunConfirmationSubtitle"
	subtitle_label.text = "Текущий забег закончится, и будет подведён итог. Продолжить?"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 16),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.name = "EndRunConfirmationButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, END_RUN_CONFIRM_BUTTON_SIZE.y)
	button_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var confirm_button := _make_button("Завершить")
	confirm_button.name = "EndRunConfirmAcceptButton"
	_set_action_button_size(confirm_button, END_RUN_CONFIRM_BUTTON_SIZE.x, END_RUN_CONFIRM_BUTTON_SIZE.y)
	_apply_fantasy_button_theme(confirm_button, "default", END_RUN_CONFIRM_BUTTON_FAMILY)
	confirm_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Диалог живёт в pause_overlay_layer и умрёт вместе с ним при _clear_ui завершения.
	confirm_button.pressed.connect(_end_current_run_by_player)
	button_row.add_child(confirm_button)

	var cancel_button := _make_button("Отмена")
	cancel_button.name = "EndRunConfirmCancelButton"
	_set_action_button_size(cancel_button, END_RUN_CONFIRM_BUTTON_SIZE.x, END_RUN_CONFIRM_BUTTON_SIZE.y)
	_apply_fantasy_button_theme(cancel_button, "default", END_RUN_CONFIRM_BUTTON_FAMILY)
	cancel_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_button.pressed.connect(_cancel_end_run_confirmation_dialog)
	button_row.add_child(cancel_button)

	# Полное 4-стороннее замыкание фокуса: под модалкой вертикальная колонна кнопок
	# паузы, стрелки не должны уводить фокус за пределы диалога.
	confirm_button.focus_neighbor_left = cancel_button.get_path()
	confirm_button.focus_neighbor_right = cancel_button.get_path()
	confirm_button.focus_neighbor_top = cancel_button.get_path()
	confirm_button.focus_neighbor_bottom = cancel_button.get_path()
	cancel_button.focus_neighbor_left = confirm_button.get_path()
	cancel_button.focus_neighbor_right = confirm_button.get_path()
	cancel_button.focus_neighbor_top = confirm_button.get_path()
	cancel_button.focus_neighbor_bottom = confirm_button.get_path()
	cancel_button.grab_focus()

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not panel.get_global_rect().has_point((event as InputEventMouseButton).global_position):
				_cancel_end_run_confirmation_dialog()
	)




# Возвращает true, если модалка подтверждения была открыта и закрыта этим вызовом.
func _cancel_end_run_confirmation_dialog() -> bool:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return false
	var overlay: Node = game.pause_overlay_layer.find_child("EndRunConfirmationDialog", true, false)
	if overlay == null:
		return false
	overlay.queue_free()
	var end_run_button := game.pause_overlay_layer.find_child("PauseEndRunButton", true, false) as Button
	if end_run_button != null and is_instance_valid(end_run_button):
		end_run_button.grab_focus()
	return true




func _show_pause_dossier_menu() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	for child in game.pause_overlay_layer.get_children():
		child.queue_free()

	# SCRUM-890: досье может быть первым открытым UI забега — гарантируем
	# геймпад-биндинги ui_accept/ui_cancel (B = «Продолжить» через main._input).
	_ensure_run_ui_gamepad_bindings()
	game.pause_stats_menu = game.PAUSE_STATS_MENU_SCENE.instantiate() as Control
	game.pause_overlay_layer.add_child(game.pause_stats_menu)
	if game.pause_stats_menu.has_method("setup"):
		game.pause_stats_menu.setup(_pause_dossier_player())
	game.pause_stats_menu.resume_requested.connect(_resume_game)
	game.pause_stats_menu.settings_requested.connect(func() -> void:
		_show_settings_menu(SETTINGS_RETURN_RUN_PAUSE)
	)
	# SCRUM-890: «Завершить забег» из шапки досье открывает модалку SCRUM-883
	# (EndRunConfirmationDialog в pause_overlay_layer), а не движковый фолбэк сцены.
	game.pause_stats_menu.set("end_run_confirm_handler", Callable(self, "_show_end_run_confirmation_dialog"))
	game.pause_stats_menu.end_run_confirmed.connect(_end_current_run_by_player)
	game.pause_stats_menu.main_menu_requested.connect(_quit_current_run)




func _is_run_pause_overlay_open() -> bool:
	return game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer)




func _is_settings_screen_open() -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	return game.ui_layer.find_child("SettingsV2Root", true, false) != null




func _can_open_pause_dossier() -> bool:
	if _is_settings_screen_open():
		return false
	if game.combat_active:
		return true
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	for screen_name in ["RouteMapScreen", "ShopScreen", "AttributeShopScreen", "LevelUpOverlay", "EliteArtifactRewardScreen", "EventScreen"]:
		if game.ui_layer.find_child(screen_name, true, false) != null:
			return true
	return false




func _pause_dossier_player() -> Node:
	if game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player
	var temp_player: Node = game.combat._snapshot_player_for_menu()
	temp_player.set_meta("pause_dossier_temp_player", true)
	return temp_player




func _resume_game() -> void:
	# SCRUM-883: Esc/B при открытом подтверждении «Завершить забег» отменяет только
	# модалку — пауза остаётся (паритет с Escape-отменой quit-диалога главного меню).
	if _cancel_end_run_confirmation_dialog():
		return
	game.pending_rebind_action = ""
	game.pop_pause("escape_menu")
	if game.pause_stats_menu != null and is_instance_valid(game.pause_stats_menu):
		var temp_player := game.pause_stats_menu.get("_player") as Node
		if temp_player != null and is_instance_valid(temp_player) and bool(temp_player.get_meta("pause_dossier_temp_player", false)):
			temp_player.queue_free()
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		game.pause_overlay_layer.queue_free()
	game.pause_overlay_layer = null
	game.pause_stats_menu = null




func _quit_current_run() -> void:
	game.pending_rebind_action = ""
	game._clear_all_game_pauses()
	game.combat_active = false
	game.boss_combat_active = false
	game.current_act = 1
	game.route_stage = 0
	game.run_player_snapshot.clear()
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.event_shop_exit_action = Callable()  # SCRUM-996
	game.pending_level_ups = 0
	game.current_route_choice = ""
	game.run_used_shop = false
	game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
	game.route_nodes = game.route._generate_route()
	game._clear_world()
	game._clear_hud()
	_show_main_menu()




func _end_current_run_by_player() -> void:
	game.pending_rebind_action = ""
	game._clear_all_game_pauses()
	game.combat_active = false
	game.boss_combat_active = false
	# SCRUM-502: ручное завершение забега — снять метрики-финалы с живого игрока ДО очистки
	# снапшота (иначе экран итогов был бы пуст), затем причина исхода.
	if game.current_player != null and is_instance_valid(game.current_player):
		game.combat._store_player_snapshot(game.current_player)
	game.capture_run_metrics_finals(game.run_player_snapshot)
	if str(game.run_metrics.get("outcome_reason", "")) == "":
		game.run_metrics["outcome_reason"] = "Забег завершён игроком на этапе маршрута %d" % (game.route_stage + 1)
	game.run_player_snapshot.clear()
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.event_shop_exit_action = Callable()  # SCRUM-996
	game.pending_level_ups = 0
	game.current_route_choice = ""
	game._clear_world()
	game._clear_hud()
	_show_death_screen("Забег завершен игроком.")
