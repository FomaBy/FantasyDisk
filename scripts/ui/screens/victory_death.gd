extends "res://scripts/ui/screens/attribute_shop.gd"

# FAN-3824: модуль распределённого UI-класса — баннер победы, экраны победы/смерти и сводка забега.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _show_victory_banner(on_continue: Callable) -> void:
	# Затемнение + крупная «Победа»; продолжение по клику или через 1.3с.
	var banner_layer := CanvasLayer.new()
	banner_layer.name = "VictoryBannerLayer"
	banner_layer.layer = 80
	banner_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(banner_layer)

	var continue_once := func() -> void:
		if is_instance_valid(banner_layer):
			banner_layer.queue_free()
			if on_continue.is_valid():
				on_continue.call()

	var click_catcher := Button.new()
	click_catcher.name = "VictoryBanner"
	UIButtonFamily.assign(click_catcher, "invisible_catcher")
	click_catcher.flat = true
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	click_catcher.pressed.connect(continue_once)
	banner_layer.add_child(click_catcher)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.02, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_catcher.add_child(shade)

	var frame := PanelContainer.new()
	frame.name = "VictoryBannerFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	# SCRUM-883: транзиентный оверлей поверх боя — компактный чип Атласа вместо
	# тяжёлой vbn_frame @2K-рамы (просто и торжественно; дим сохранён, растяжек нет).
	var banner_size := VICTORY_BANNER_CHIP_SIZE
	frame.offset_left = -banner_size.x * 0.5
	frame.offset_right = banner_size.x * 0.5
	frame.offset_top = -banner_size.y * 0.5
	frame.offset_bottom = banner_size.y * 0.5
	frame.pivot_offset = banner_size * 0.5
	frame.scale = Vector2(0.92, 0.92)
	frame.modulate.a = 0.0
	frame.add_theme_stylebox_override("panel", _atlas_chip_style(0.92, VICTORY_BANNER_CHIP_PAD))
	frame.set_meta("victory_banner_style", "atlas_chip")
	click_catcher.add_child(frame)

	var label := Label.new()
	label.name = "VictoryBannerLabel"
	label.text = "ПОБЕДА"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_DISPLAY,
		_readable_font_size(SemanticTypography.ROLE_DISPLAY, 90),
		SemanticTypography.role_min(SemanticTypography.ROLE_DISPLAY),
		SemanticTypography.role_max(SemanticTypography.ROLE_DISPLAY)
	))
	label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 8)
	frame.add_child(label)

	var tween := banner_layer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(shade, "color:a", 0.66, 0.30)
	tween.tween_property(frame, "modulate:a", 1.0, 0.35)
	tween.tween_property(frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.3)
	tween.chain().tween_callback(continue_once)

	# SCRUM-968: акцент баннера — artifact_reveal (level_up остаётся только за
	# настоящим повышением уровня в _on_player_leveled_up).
	game._play_sfx("artifact_reveal")




func _show_victory_screen() -> void:
	game.clear_run_autosave()
	var ascension_level: int = game.ascension_level_for(game.selected_character_id)
	var character_config: Dictionary = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var character_title := str(character_config.get("title", "Герой"))
	if character_title == "" or character_title == game.selected_character_id:
		character_title = "Герой"
	var run_level: int = game.selected_ascension_level
	# Нейтральная победа даёт прогресс; custom sandbox честно сообщает, что
	# persistent-награды отключены (SCRUM-976), а не обещает невыданное очко.
	var skill_points_total: int = game.META_PROGRESSION.skill_points(game.meta_state)
	var progression_line := "Получено очко умений — всего %d, потрать их в «Древе умений» в меню." % skill_points_total
	var ascension_summary := _victory_ascension_summary(game.selected_character_id, run_level, ascension_level)
	if not game.run_progression_eligible():
		progression_line = "Пользовательский sandbox: метапрогрессия и достижения не начисляются."
		ascension_summary = "Текущий предел Возвышения: %d из %d. Без изменений в пользовательском sandbox." % [ascension_level, game.META_PROGRESSION.MAX_ASCENSION_LEVEL]
	# FAN-1080: первая строка — лорная Печать (вместо плоской «Финальный босс
	# повержен»); вариант «Разлом уйдёт глубже», пока остаются витки Возвышения.
	var rift_goes_deeper: bool = game.run_progression_eligible() \
		and run_level < game.META_PROGRESSION.MAX_ASCENSION_LEVEL
	var subtitle := "%s\n%s завершил забег.\nОчки наследия: %d.\n%s\n%s" % [
		LORE_DATA.victory_line(rift_goes_deeper),
		character_title,
		game.meta_points,
		progression_line,
		ascension_summary,
	]
	var result_layout := _create_result_menu_box("Победа", subtitle, "victory")
	_add_result_crest_to_slot(result_layout["crest_slot"] as Control, "victory")
	codex_unlock_presenter.add_victory_unlocks(result_layout["summary_column"] as VBoxContainer, self)
	_add_run_summary_rows(result_layout["summary_column"] as VBoxContainer, true, true)  # SCRUM-502: сводка прогона
	var finish_run := func() -> void:
		game.current_act = 1
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.event_shop_exit_action = Callable()  # SCRUM-996
		game.run_used_shop = false
		game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var restart_button := _make_button("Новый забег")
	restart_button.name = "VictoryNewRunButton"
	_set_action_button_size(restart_button, _pause_end_result_button_width("victory"), _pause_end_result_button_height())
	restart_button.pressed.connect(finish_run)
	(result_layout["button_slot"] as Control).add_child(restart_button)
	game.ui_escape_action = finish_run
	# SCRUM-812: стартовый фокус на основной кнопке; B/Esc = основная кнопка (finish_run),
	# «пустого» закрытия нет.
	_wire_run_ui_focus([restart_button], false, [], restart_button)




func _show_death_screen(reason := "") -> void:
	game.clear_run_autosave()
	var subtitle := str(reason)
	if subtitle == "":
		subtitle = "Забег завершён: %s, этап маршрута %d." % [game.act_progress_label(), game.route_stage + 1]
	# FAN-1080: лорная строка поражения — Диск помнит павших, цикл продолжается.
	subtitle += "\n%s" % LORE_DATA.defeat_line()
	var result_layout := _create_result_menu_box("Поражение", subtitle, "death")
	_add_result_crest_to_slot(result_layout["crest_slot"] as Control, "death")
	_add_run_summary_rows(result_layout["summary_column"] as VBoxContainer, false, true)  # SCRUM-502: сводка прогона
	var back_to_menu := func() -> void:
		game.current_act = 1
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.event_shop_exit_action = Callable()  # SCRUM-996
		game.run_used_shop = false
		game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var retry_button := _make_button("Начать заново")
	retry_button.name = "DeathRetryButton"
	_set_action_button_size(retry_button, _pause_end_result_button_width("death"), _pause_end_result_button_height())
	retry_button.pressed.connect(back_to_menu)
	(result_layout["button_slot"] as Control).add_child(retry_button)
	game.ui_escape_action = back_to_menu
	# SCRUM-812: стартовый фокус на «Начать заново»; B/Esc = основная кнопка, без «пустого» закрытия.
	_wire_run_ui_focus([retry_button], false, [], retry_button)




# SCRUM-502/SCRUM-841: блок сводки прогона на экранах победы/смерти. В старом
# контейнерном пути он кладётся в box; в no-scroll result layout — в компактную
# RunSummaryColumn. Все строки MOUSE_FILTER_IGNORE, чтобы не перехватывать клик
# кнопки и Escape. Стабильные имена узлов — для matrix-теста.
func _add_run_summary_rows(box: VBoxContainer, is_victory: bool, force_compact := false) -> void:
	var metrics: Dictionary = game.run_metrics if not game.run_metrics.is_empty() else {}
	var outcome := str(metrics.get("outcome_reason", ""))
	var summary_parent := _result_summary_parent(box)
	var target: VBoxContainer = summary_parent if summary_parent != null else box
	var compact := force_compact or summary_parent != null
	var ultra_compact: bool = compact and game.get_viewport().get_visible_rect().size.y < 800.0

	if outcome != "":
		var outcome_label := Label.new()
		outcome_label.name = "RunSummaryOutcome"
		outcome_label.text = outcome
		outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outcome_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_SECTION,
			_readable_font_size(SemanticTypography.ROLE_SECTION, 10 if ultra_compact else (13 if compact else 17), 10 if ultra_compact else 12, 22),
			SemanticTypography.role_min(SemanticTypography.ROLE_SECTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_SECTION)
		))
		outcome_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
		outcome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(outcome_label)

	var grid := GridContainer.new()
	grid.name = "RunSummaryStats"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8 if ultra_compact else (14 if compact else 28))
	grid.add_theme_constant_override("v_separation", 0 if ultra_compact else (2 if compact else 6))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(grid)

	var artifacts: Array = metrics.get("artifacts", []) as Array
	var rows := [
		["time", "Время забега", _format_run_duration(float(metrics.get("time_seconds", 0.0)))],
		["route", "Дошёл до этапа", str(int(metrics.get("route_stage_reached", 0)) + 1)],
		["kills", "Убийств", str(int(metrics.get("kills", 0)))],
		["damage_dealt", "Урон по врагам", str(int(round(float(metrics.get("damage_dealt", 0.0)))))],
		["damage_taken", "Получено урона", str(int(round(float(metrics.get("damage_taken", 0.0)))))],
		["gold", "Собрано золота", str(int(metrics.get("gold_collected", 0)))],
		["level", "Финальный уровень", str(int(metrics.get("final_level", 0)))],
		["artifacts", "Артефактов", str(artifacts.size())],
	]
	var unlocks: Array = metrics.get("new_unlocks", []) as Array
	if is_victory and not unlocks.is_empty():
		rows = [rows[0], rows[2], rows[5], rows[6]]
	for row in rows:
		var name_label := Label.new()
		name_label.name = "RunSummaryStatName_%s" % str(row[0])
		name_label.text = "%s:" % str(row[1])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_FIELD,
			_readable_font_size(SemanticTypography.ROLE_FIELD, 10 if ultra_compact else (12 if compact else 16), 10 if ultra_compact else 12, 20),
			SemanticTypography.role_min(SemanticTypography.ROLE_FIELD),
			SemanticTypography.role_max(SemanticTypography.ROLE_FIELD)
		))
		name_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(name_label)
		var value_label := Label.new()
		value_label.name = "RunSummaryStat_%s" % str(row[0])
		value_label.text = str(row[2])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_VALUE,
			_readable_font_size(SemanticTypography.ROLE_VALUE, 10 if ultra_compact else (13 if compact else 16), 10 if ultra_compact else 12, 20),
			SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
			SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
		))
		value_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(value_label)

	if not artifacts.is_empty() and (not is_victory or unlocks.is_empty()):
		var names := []
		for artifact in artifacts:
			if artifact is Dictionary:
				names.append(str((artifact as Dictionary).get("title", (artifact as Dictionary).get("name", "Артефакт"))))
			else:
				names.append(str(artifact))
		var artifacts_label := Label.new()
		artifacts_label.name = "RunSummaryArtifacts"
		artifacts_label.text = _compact_result_artifact_names(names) if compact else ", ".join(names)
		artifacts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		artifacts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		artifacts_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			_readable_font_size(SemanticTypography.ROLE_BODY, 10 if ultra_compact else (11 if compact else 14), 10 if ultra_compact else 12, 18),
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))
		artifacts_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.95))
		artifacts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(artifacts_label)




func _result_summary_parent(box: VBoxContainer) -> VBoxContainer:
	if box == null or not bool(box.get_meta("result_no_scroll_layout", false)):
		return null
	var screen_id := str(box.get_meta("result_screen_id", ""))
	if screen_id == "":
		return null
	return box.find_child("RunSummaryColumn_%s" % screen_id, true, false) as VBoxContainer




func _compact_result_artifact_names(names: Array) -> String:
	if names.size() <= 3:
		return ", ".join(names)
	var visible_names := []
	for index in range(mini(3, names.size())):
		visible_names.append(str(names[index]))
	return "%s + ещё %d" % [", ".join(visible_names), names.size() - visible_names.size()]




func _format_run_duration(total_seconds: float) -> String:
	var secs := int(maxf(0.0, total_seconds))
	return "%02d:%02d" % [secs / 60, secs % 60]




func _victory_ascension_summary(character_id: String, run_level: int, unlocked_level: int) -> String:
	var lines := ["Текущий предел Возвышения: %d из %d." % [unlocked_level, game.META_PROGRESSION.MAX_ASCENSION_LEVEL]]  # SCRUM-622: динамический кап (SCRUM-516: 10→5), не хардкод
	if run_level >= unlocked_level - 1 and unlocked_level > 0:
		lines.append("Открыт следующий уровень Возвышения.")
		var reward_text := _ascension_reward_summary(character_id, unlocked_level)
		if reward_text != "":
			lines.append(reward_text)
	else:
		lines.append("Пройден уже освоенный уровень Возвышения.")
	return "\n".join(lines)




func _ascension_reward_summary(character_id: String, level: int) -> String:
	var rewards: Array = game.PROGRESSION_DATA.ascension_levels(character_id)
	var index := clampi(level - 1, 0, rewards.size() - 1)
	if rewards.is_empty() or index < 0 or index >= rewards.size():
		return ""
	var reward: Dictionary = rewards[index]
	var title := str(reward.get("title", "Новая мета-награда"))
	var modifier_text := _modifier_summary_text(reward.get("mods", {}))
	if modifier_text == "":
		return "Новая награда для будущих забегов: %s." % title
	return "Новая награда для будущих забегов: %s — %s." % [title, modifier_text]




func _modifier_summary_text(mods_value) -> String:
	var mods: Dictionary = mods_value if mods_value is Dictionary else {}
	var parts := []
	for key in mods.keys():
		var value := float(mods[key])
		match str(key):
			"damage_multiplier":
				parts.append("урон +%d%%" % int(round((value - 1.0) * 100.0)))
			"attack_speed_multiplier":
				parts.append("скорость атаки +%d%%" % int(round((value - 1.0) * 100.0)))
			"move_speed_multiplier":
				parts.append("скорость движения +%d%%" % int(round((value - 1.0) * 100.0)))
			"aoe_radius_multiplier":
				parts.append("радиус атак +%d%%" % int(round((value - 1.0) * 100.0)))
			"knockback_multiplier":
				parts.append("отталкивание +%d%%" % int(round((value - 1.0) * 100.0)))
			"max_health_flat":
				parts.append("максимальное здоровье +%d" % int(round(value)))
			"defense_flat":
				parts.append("защита +%d%%" % int(round(value * 100.0)))
			"crit_chance_flat":
				parts.append("шанс крита +%d%%" % int(round(value * 100.0)))
	return ", ".join(parts)
