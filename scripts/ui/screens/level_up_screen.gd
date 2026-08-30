extends "res://scripts/ui/screens/weapon_select.gd"

# FAN-3824: модуль распределённого UI-класса — экран level-up: показ, метрики, интро-анимации.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _show_reward_screen() -> void:
	# SCRUM-883: панель награды — чип Атласа (карточки внутри — чип-ряды).
	var box := _create_menu_box("Награда за бой", "Выбери 1 из 3 усилений.", "artifact_reward", _atlas_chip_style(0.94, 18.0))
	_create_menu_run_hud()
	var rewards_row := HBoxContainer.new()
	var reward_card_size := _battle_reward_card_size()
	rewards_row.name = "BattleRewardCardsRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, reward_card_size.y)
	rewards_row.add_theme_constant_override("separation", 18)
	box.add_child(rewards_row)
	var reward_buttons: Array[Button] = []
	for reward in _random_rewards(3):
		var reward_data: Dictionary = reward
		var button := _make_battle_reward_card(reward_data)
		button.name = "BattleRewardButton%d" % rewards_row.get_child_count()
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward_data)
			game.save_run_autosave("reward_choice")
			game.route._show_battle_map()
		)
		rewards_row.add_child(button)
		reward_buttons.append(button)
	for index in range(reward_buttons.size()):
		var card := reward_buttons[index]
		var left := reward_buttons[(index - 1 + reward_buttons.size()) % reward_buttons.size()]
		var right := reward_buttons[(index + 1) % reward_buttons.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path()
	if not reward_buttons.is_empty():
		reward_buttons[0].grab_focus()




func _show_level_up_screen(return_to_map := false) -> void:
	game.level_up_return_to_map = return_to_map
	var layout := _level_up_layout_metrics()
	var box := _create_level_up_menu_box("Повышение уровня", "Выбери 1 из 3 усилений. Один выбор за уровень.", layout)
	if not game.combat_active:
		_create_menu_run_hud()

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "LevelUpRewardsRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.position = layout.get("rewards_row_position", Vector2.ZERO)
	# SCRUM-892: ряд занимает зону между шапкой и «Позже»; карточки контентной
	# высоты (SIZE_SHRINK_CENTER) центрируются в ней по вертикали.
	rewards_row.size = layout.get("rewards_row_size", Vector2(760.0, 320.0))
	rewards_row.custom_minimum_size = rewards_row.size
	rewards_row.add_theme_constant_override("separation", int(layout.get("card_gap", 0)))
	box.add_child(rewards_row)

	var saved_offer: Array = game.level_up_offer
	game.level_up_offer = AttributeContract.sanitize_level_up_offer(game.level_up_offer, game.selected_character_id, _active_stats_snapshot(), _active_modifiers_snapshot(), _active_weapon_config())
	if not game.level_up_offer.is_empty() and saved_offer.size() == game.level_up_offer.size():
		for reward_index in range(game.level_up_offer.size()):
			var saved_reward := saved_offer[reward_index] as Dictionary
			if saved_reward.has("description"): (game.level_up_offer[reward_index] as Dictionary)["description"] = str(saved_reward["description"])
	if game.level_up_offer.is_empty():
		game.level_up_offer = _random_level_up_rewards(3)
	# SCRUM-871: прогноз «до -> после» и бейджи «Лучший урон»/«Выживание» на весь
	# набор — один раз на построение экрана, от живых статов игрока.
	var advice := _level_up_offer_advice(game.level_up_offer)
	# SCRUM-892: единый план стека на весь набор (глубина описаний/дельт, бейдж-
	# слот) — сокеты и титулы трёх карточек стоят в одну линию, без пустых зон.
	layout["card_plan"] = _level_up_card_plan(game.level_up_offer, advice, layout)
	var reward_buttons: Array[Button] = []
	for reward in game.level_up_offer:
		var button := _make_level_up_reward_button(reward, layout, advice, reward_buttons.size())
		button.name = "LevelUpRewardButton%d" % reward_buttons.size()
		button.pressed.connect(func() -> void:
			_apply_reward_to_active_run(reward)
			game.level_up_offer = []
			game.pending_level_ups = maxi(game.pending_level_ups - 1, 0)
			game.ui_escape_action = Callable()
			_update_level_up_button()
			if game.pending_level_ups > 0:
				_show_level_up_screen(return_to_map)
			else:
				game.level_up_return_to_map = false
				game.pop_pause("level_up")
				game._clear_ui()
				if game.combat_active:
					_create_hud()
					_update_hud()
				elif game.level_up_return_to_event and not game.current_event_definition.is_empty():
					# SCRUM-530: level-up был открыт с узла-события — возвращаемся на него.
					game.level_up_return_to_event = false
					_return_from_level_up_to_event()
				elif return_to_map or not game.combat_active:
					game.level_up_return_to_event = false
					game.save_run_autosave("level_up_choice")
					game.route._show_battle_map()
		)
		rewards_row.add_child(button)
		reward_buttons.append(button)

	# FAN-1927 (спека LU.DetailDrawer): полная русская копия сфокусированной
	# карточки — placement из остатка зоны под контентной высотой карточек
	# (AttributeSurfaces; compact-вьюпорты получают focus-overlay).
	var drawer_placement := AttributeSurfaces.level_up_drawer_placement(layout, rewards_row.position, rewards_row.size)
	var drawer_overlay := bool(drawer_placement.get("overlay", false))
	var drawer_rect: Rect2 = drawer_placement.get("rect", Rect2())
	if not drawer_overlay:
		var reduced_row_size: Vector2 = drawer_placement.get("reduced_row_size", rewards_row.size)
		rewards_row.custom_minimum_size = reduced_row_size
		rewards_row.size = reduced_row_size
	var lu_drawer_nodes := AttributeSurfaces.make_detail_drawer("LevelUp", _atlas_chip_style(0.94 if drawer_overlay else 0.88, 10.0))
	var drawer_panel := lu_drawer_nodes["panel"] as PanelContainer
	var drawer_label := lu_drawer_nodes["label"] as Label
	drawer_panel.position = drawer_rect.position
	drawer_panel.size = drawer_rect.size
	drawer_panel.custom_minimum_size = drawer_rect.size
	drawer_panel.visible = not drawer_overlay
	drawer_panel.set_meta("lu_drawer_overlay", drawer_overlay)
	box.add_child(drawer_panel)
	var drawer_forecasts: Array = advice.get("forecasts", [])
	var drawer_badges: Array = advice.get("badges", [])
	for reward_index in range(reward_buttons.size()):
		var focus_reward: Dictionary = game.level_up_offer[reward_index]
		var focus_forecast: Dictionary = drawer_forecasts[reward_index] if reward_index < drawer_forecasts.size() else {}
		var focus_badge := str(drawer_badges[reward_index]) if reward_index < drawer_badges.size() else ""
		var drawer_text := _level_up_detail_drawer_text(focus_reward, focus_forecast, focus_badge, advice)
		if reward_index == 0:
			drawer_label.text = drawer_text
		AttributeSurfaces.wire_detail_focus(reward_buttons[reward_index], drawer_label, drawer_panel, drawer_overlay, drawer_text)

	# Типографика: авто-подбор мог дать титулам разный размер — выравниваем ряд
	# по минимальному, чтобы карточки читались как одна линейка.
	var title_labels: Array = []
	var min_title_font := 999
	for button in reward_buttons:
		var reward_title := button.find_child("LevelUpRewardTitle", true, false) as Label
		if reward_title != null:
			title_labels.append(reward_title)
			min_title_font = mini(min_title_font, reward_title.get_theme_font_size("font_size"))
	for reward_title in title_labels:
		(reward_title as Label).add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TITLE,
			min_title_font,
			SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
			SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
		))

	# Клавиатура/геймпад: фокус по карточкам стрелками по кругу, Enter/Space/A выбирают.
	# Полная разводка (карточки + «Позже») ставится ниже, после создания later_button.

	# Отложенный выбор: «Позже» (и Escape) закрывают окно БЕЗ траты пика — набор
	# зафиксирован, вернуться можно кнопкой повышения внизу экрана.
	var defer_choice := func() -> void:
		game.ui_escape_action = Callable()
		game.level_up_return_to_map = false
		game.pop_pause("level_up")
		game._clear_ui()
		if game.combat_active:
			_create_hud()
			_update_hud()
			_update_level_up_button()
		elif game.level_up_return_to_event and not game.current_event_definition.is_empty():
			# SCRUM-530: «Позже»/Escape на level-up, открытом с события — пик сохранён,
			# возвращаемся на то же событие (угловая кнопка level-up появится снова).
			game.level_up_return_to_event = false
			_return_from_level_up_to_event()
		else:
			game.level_up_return_to_event = false
			game.save_run_autosave("level_up_deferred")
			game.route._show_battle_map()

	# SCRUM-883: «Позже» — Button-контрол действия, только глобальный кит (имя узла
	# LevelUpLaterButton мапится на текстуры later_260x72; _set_action_button_size
	# переприменяет тему кита после установки размера).
	var later_button := _make_button("Позже")
	later_button.name = "LevelUpLaterButton"
	var later_button_size: Vector2 = layout.get("later_button_size", Vector2(260.0, 72.0))
	_set_action_button_size(later_button, later_button_size.x, later_button_size.y)
	later_button.position = layout.get("later_button_position", Vector2.ZERO)
	later_button.size = later_button_size
	later_button.tooltip_text = "Закрыть без выбора — пик сохранится, вернуться можно кнопкой повышения внизу."
	later_button.pressed.connect(defer_choice)
	box.add_child(later_button)
	game.ui_escape_action = defer_choice

	# SCRUM-812: карточки по кругу (лево/право), «Позже» достижима ui_down, старт — первая карточка.
	_wire_run_ui_focus(reward_buttons, true, [later_button], reward_buttons[0] if not reward_buttons.is_empty() else null)

	var panel := box.get_parent() as PanelContainer
	var title_label := box.find_child("LevelUpTitle", true, false) as Label
	var sparkle_root = game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpParticles") as Control
	_start_level_up_intro(panel, title_label, reward_buttons, sparkle_root)




func _show_elite_artifact_reward(on_done: Callable) -> void:
	var choices: Array = game.PROGRESSION_DATA.elite_artifact_choices(game.route_scaling_stage(), 3, game.selected_character_id, _run_ascension_level(), _run_cross_class_artifact_ids())
	_show_artifact_reward_screen(
		"Elite",
		"Трофей элитки",
		"Выбери 1 из 3 артефактов. Чем глубже маршрут, тем выше шанс редкой добычи.",
		choices,
		on_done
	)




func _show_boss_artifact_reward(on_done: Callable) -> void:
	# SCRUM-873: награда за акт-босса — выбор 1 из 3 СУПЕРРЕДКИХ артефактов
	var choices: Array = game.PROGRESSION_DATA.boss_completion_artifact_choices(3, game.selected_character_id, _run_ascension_level(), _run_cross_class_artifact_ids())
	# Пул пуст (теоретический случай) — не запирать игрока на экране без карт.
	if choices.is_empty():
		push_warning("Boss artifact reward: пул суперредких пуст — экран пропущен.")
		game._clear_ui()
		if on_done.is_valid():
			on_done.call()
		return
	_show_artifact_reward_screen(
		"Boss",
		"Трофей босса",
		"Акт пройден! Выбери 1 из 3 эпических артефактов.",
		choices,
		on_done
	)




# SCRUM-990/991: единый reward-hall builder для элитного/сундукового и boss
# путей. Фон — канонический reward hall, единственная внешняя ornament-рама
# добавляется ПОСЛЕДНЕЙ и остаётся полой; центрального modal/panel больше нет.
func _show_artifact_reward_screen(
		prefix: String,
		title_text: String,
		subtitle_text: String,
		choices: Array,
		on_done: Callable) -> void:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "%sArtifactRewardScreen" % prefix
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, "artifact_reward")

	var content_root := Control.new()
	content_root.name = "%sArtifactRewardContentRoot" % prefix
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content_root)

	var title := Label.new()
	title.name = "%sArtifactRewardTitle" % prefix
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", TIER_COLORS[3] if prefix == "Boss" else Color(0.96, 0.90, 0.68, 1.0))
	content_root.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "%sArtifactRewardSubtitle" % prefix
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	content_root.add_child(subtitle)

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "%sArtifactRewardRow" % prefix
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(rewards_row)

	var presentations := _artifact_reward_presentations(choices)
	var reward_cards: Array[Button] = []
	for index in range(choices.size()):
		var reward_data := choices[index] as Dictionary
		var presentation := presentations[index] as Dictionary
		var button := _make_elite_artifact_card(reward_data, presentation)
		button.name = "%sArtifactRewardButton%d" % [prefix, index]
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward_data)
			game._clear_ui()
			if on_done.is_valid():
				on_done.call()
		)
		rewards_row.add_child(button)
		reward_cards.append(button)

	for index in range(reward_cards.size()):
		var card := reward_cards[index]
		var left := reward_cards[(index - 1 + reward_cards.size()) % reward_cards.size()]
		var right := reward_cards[(index + 1) % reward_cards.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path()
	if not reward_cards.is_empty():
		reward_cards[0].grab_focus()

	game.ui_escape_action = Callable()
	_unified_add_frame(root, "%sArtifactReward" % prefix)
	_layout_artifact_reward_screen(root, prefix)
	root.resized.connect(func() -> void:
		_layout_artifact_reward_screen(root, prefix)
		call_deferred("_layout_artifact_reward_screen", root, prefix)
	)
	game._play_sfx("artifact_reveal")




func _artifact_reward_layout_metrics(viewport_size: Vector2) -> Dictionary:
	var inner := _gold_shell_inner_rect_for_size(viewport_size)
	var card_size: Vector2
	var gap: float
	var title_size: Vector2
	var subtitle_size: Vector2
	var title_top: float
	var subtitle_top: float
	var row_top: float
	var bottom_reserve: float
	if viewport_size.y < 900.0:
		card_size = Vector2(286.0, 344.0)
		gap = 21.0
		title_size = Vector2(520.0, 38.0)
		subtitle_size = Vector2(760.0, 28.0)
		title_top = 4.0
		subtitle_top = 44.0
		row_top = 82.0
		bottom_reserve = 20.0
	elif viewport_size.y < 1200.0:
		card_size = Vector2(360.0, 520.0)
		gap = 36.0
		title_size = Vector2(640.0, 52.0)
		subtitle_size = Vector2(960.0, 34.0)
		title_top = 16.0
		subtitle_top = 76.0
		row_top = 130.0
		bottom_reserve = 44.0
	else:
		card_size = Vector2(430.0, 660.0)
		gap = 60.0
		title_size = Vector2(920.0, 70.0)
		subtitle_size = Vector2(1280.0, 42.0)
		title_top = 24.0
		subtitle_top = 108.0
		row_top = 186.0
		bottom_reserve = 80.0

	card_size.x = minf(card_size.x, floorf((inner.size.x - gap * 2.0) / 3.0))
	card_size.y = minf(card_size.y, maxf(180.0, inner.size.y - row_top - bottom_reserve))
	var row_size := Vector2(card_size.x * 3.0 + gap * 2.0, card_size.y)
	return {
		"inner_rect": inner,
		"title_rect": Rect2(Vector2(inner.get_center().x - title_size.x * 0.5, inner.position.y + title_top), title_size),
		"subtitle_rect": Rect2(Vector2(inner.get_center().x - subtitle_size.x * 0.5, inner.position.y + subtitle_top), subtitle_size),
		"row_rect": Rect2(Vector2(inner.get_center().x - row_size.x * 0.5, inner.position.y + row_top), row_size),
		"card_size": card_size,
		"gap": gap,
	}




func _layout_artifact_reward_screen(root: Control, prefix: String) -> void:
	if root == null or not is_instance_valid(root) or root.size.x <= 1.0 or root.size.y <= 1.0:
		return
	var metrics := _artifact_reward_layout_metrics(root.size)
	var inner := metrics["inner_rect"] as Rect2
	root.set_meta("gold_shell_inner_rect", inner)
	var content_root := root.find_child("%sArtifactRewardContentRoot" % prefix, false, false) as Control
	if content_root == null:
		return
	content_root.position = inner.position
	content_root.size = inner.size
	content_root.set_meta("gold_shell_inner_rect", inner)

	var title := content_root.find_child("%sArtifactRewardTitle" % prefix, false, false) as Label
	var subtitle := content_root.find_child("%sArtifactRewardSubtitle" % prefix, false, false) as Label
	var row := content_root.find_child("%sArtifactRewardRow" % prefix, false, false) as HBoxContainer
	var title_rect := metrics["title_rect"] as Rect2
	var subtitle_rect := metrics["subtitle_rect"] as Rect2
	var row_rect := metrics["row_rect"] as Rect2
	if title != null:
		title.position = title_rect.position - inner.position
		title.size = title_rect.size
		title.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 30 if root.size.y < 900.0 else (42 if root.size.y < 1200.0 else 54), 20, 54))
	if subtitle != null:
		subtitle.position = subtitle_rect.position - inner.position
		subtitle.size = subtitle_rect.size
		subtitle.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_CAPTION,
			_readable_font_size(SemanticTypography.ROLE_CAPTION, 14 if root.size.y < 900.0 else (17 if root.size.y < 1200.0 else 20), 11, 24),
			SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
		))
	if row != null:
		row.position = row_rect.position - inner.position
		row.size = row_rect.size
		row.custom_minimum_size = row_rect.size
		row.add_theme_constant_override("separation", int(roundf(float(metrics["gap"]))))
		for child in row.get_children():
			if child is Button:
				_resize_elite_artifact_card(child as Button, metrics["card_size"] as Vector2)




# SCRUM-892: план стека карточек на весь набор наград — карточки контентной
# высоты без пустых зон (сокет-иконка → титул → описание → сразу дельта-блок);
# глубина описания (2-3 строки), дельта-блока (1-3 строки) и бейдж-слот
# выравниваются по максимуму набора, чтобы сокеты и титулы трёх карточек
# стояли в одну линию. Все номиналы 2K скейлятся ×scale (сокеты — пропорционально).
func _level_up_card_plan(rewards: Array, advice: Dictionary, layout: Dictionary) -> Dictionary:
	var scale := float(layout.get("scale", 0.5))
	var compact := bool(layout.get("compact", scale <= 0.52))
	var zone_height := float((layout.get("rewards_row_size", Vector2(760.0, 4096.0)) as Vector2).y)
	# Reserve the same real, non-overlay 720p drawer lane used by placement.
	if compact:
		zone_height = maxf(zone_height - 84.0, 64.0)
	var card_width := float(layout.get("card_width", roundf(LU_CARD_2K.size.x * scale)))
	# Mirror widened compact card padding so planned and rendered safe rects agree.
	var pad := maxf(6.0, roundf(LU_CARD_CHIP_PAD_2K * card_width / LU_CARD_2K.size.x))
	var content_width := maxf(card_width - pad * 2.8, 48.0)
	var gap := maxf(6.0, roundf(LU_CARD_STACK_GAP_2K * scale))
	var small_gap := maxf(4.0, roundf(8.0 * scale))
	# Шрифты стека (пол кегля 12 — фидбек читаемости SCRUM-883).
	var badge_font := _readable_font_size(SemanticTypography.ROLE_HUD, maxi(12, int(roundf(13.0 * scale))), 0, 16)
	var title_font := maxi(
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		_readable_font_size(SemanticTypography.ROLE_TITLE, maxi(12, int(roundf(18.0 * scale))), 0, 26)
	)
	var desc_font := _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, maxi(12, int(roundf(13.0 * scale))), 0, 18)
	var effect_font := _readable_font_size(SemanticTypography.ROLE_BODY, maxi(12, int(roundf(15.0 * scale))), 0, 20)
	# Высоты строк меряем probe-Label'ом — та же метрика, какой Godot считает
	# minimum size настоящих подписей (headless-гейты честные, без сюрпризов).
	var badge_line_h := _level_up_probe_line_height(badge_font)
	var title_line_h := _level_up_probe_line_height(title_font)
	var desc_line_h := _level_up_probe_line_height(desc_font) + 3.0
	var effect_row_h := _level_up_probe_line_height(effect_font) + 4.0
	# Бейдж всегда занимает отдельный слот на весь ряд. До SCRUM-1032 compact-
	# режим накладывал плашку на верх сокета: при 1280x720 она закрывала 31px
	# орнамента и 18px самой reward-иконки. Бюджетный цикл ниже уже умеет ужимать
	# описание/дельты, поэтому безопаснее сохранять отдельный ряд на всех scale.
	var badges: Array = advice.get("badges", [])
	var forecasts: Array = advice.get("forecasts", [])
	var badge_any := false
	for badge_kind in badges:
		if str(badge_kind) != "":
			badge_any = true
			break
	var badge_slot := badge_any
	# Глубина описания: 2 строки; 3 — если просторно и хоть одному описанию
	# набора мало двух (меряем той же гарнитурой, что и line height).
	var measure_probe := Label.new()
	var measure_font: Font = measure_probe.get_theme_font("font")
	measure_probe.free()
	if measure_font == null:
		measure_font = ThemeDB.fallback_font
	var desc_lines := 2
	if not compact:
		var desc_width := content_width - 12.0
		var desc_font_h := _level_up_probe_line_height(desc_font)
		for reward in rewards:
			var desc_needed := measure_font.get_multiline_string_size(
				_level_up_card_description(reward), HORIZONTAL_ALIGNMENT_CENTER, desc_width, desc_font).y
			if desc_needed > desc_font_h * 2.0 + 1.0:
				desc_lines = 3
				break
	# Глубина дельта-блока: максимум строк по набору (1-3); строки кэшируются,
	# чтобы карточки не пересчитывали их заново.
	var delta_lines_per_card := []
	var effect_rows := 1
	for reward_index in range(rewards.size()):
		var forecast: Dictionary = forecasts[reward_index] if reward_index < forecasts.size() else {}
		var lines := _level_up_delta_lines(rewards[reward_index], forecast)
		delta_lines_per_card.append(lines)
		effect_rows = maxi(effect_rows, lines.size())
	var socket_box := roundf(clampf(LU_CARD_SOCKET_BOX_2K * scale, 44.0, LU_CARD_SOCKET_BOX_2K))
	var badge_h := badge_line_h + 8.0
	# Keep baseline room for the title face at its semantic floor.
	var title_h := maxf(title_line_h + 4.0, float(title_font + 8))
	var effect_pad := maxf(5.0, roundf(10.0 * scale))
	var effect_inset := 2.0 if compact else maxf(6.0, roundf(16.0 * scale))
	var effect_text_width := maxf(content_width - effect_inset * 2.0 - effect_pad * 2.8, 8.0)
	var delta_line_heights_per_card: Array = []
	for card_lines in delta_lines_per_card:
		var line_heights: Array = []
		for line in card_lines:
			var measured_height := measure_font.get_multiline_string_size(str(line), HORIZONTAL_ALIGNMENT_CENTER, effect_text_width, effect_font).y
			line_heights.append(maxf(effect_row_h, ceilf(measured_height) + 2.0))
		delta_line_heights_per_card.append(line_heights)
	# Ужимаем только описание; обязательные строки эффекта не удаляем.
	var desc_h := 0.0
	var effect_chip_h := 0.0
	var content_height := 0.0
	while true:
		desc_h = desc_line_h * float(desc_lines) + 4.0
		var effect_content_h := 0.0
		for line_heights in delta_line_heights_per_card:
			var card_effect_h := 0.0
			for line_index in range(mini(effect_rows, (line_heights as Array).size())):
				card_effect_h += float((line_heights as Array)[line_index])
			effect_content_h = maxf(effect_content_h, card_effect_h)
		effect_chip_h = effect_content_h + effect_pad * 2.0
		content_height = socket_box + gap + title_h + small_gap + desc_h + gap + effect_chip_h
		if badge_slot:
			content_height = badge_h + gap + content_height
		if content_height + pad * 2.0 <= zone_height:
			break
		if desc_lines > 1:
			desc_lines -= 1
			continue
		if socket_box > 44.0:
			socket_box = maxf(44.0, socket_box - ceilf(content_height + pad * 2.0 - zone_height))
			continue
		break
	# Keep the real required height so mandatory-row clipping cannot false-green.
	var card_height := roundf(content_height + pad * 2.0)
	return {
		"pad": pad,
		"content_width": content_width,
		"card_size": Vector2(card_width, card_height),
		"gap": gap,
		"small_gap": small_gap,
		"badge_slot": badge_slot,
		"badge_h": badge_h,
		"badge_w": minf(roundf(LU_CARD_BADGE_WIDTH_2K * scale), content_width - 8.0),
		"badge_font": badge_font,
		"socket_box": socket_box,
		"icon_px": roundf(socket_box * LU_CARD_SOCKET_ICON_RATIO),
		"star_px": roundf(clampf(LU_CARD_STAR_2K * scale, 14.0, LU_CARD_STAR_2K)),
		"title_h": title_h,
		"title_font": title_font,
		"desc_lines": desc_lines,
		"desc_h": desc_h,
		"desc_font": desc_font,
		"effect_rows": effect_rows,
		"effect_row_h": effect_row_h,
		"effect_font": effect_font,
		"effect_pad": effect_pad,
		"effect_inset": effect_inset,
		"effect_chip_h": effect_chip_h,
		"delta_lines_per_card": delta_lines_per_card,
		"delta_line_heights_per_card": delta_line_heights_per_card,
	}




# Высота строки Label при данном кегле — через Font.get_height той же
# гарнитуры, какой рисуются подписи (тема проекта → fallback). ВАЖНО: мерить
# probe-Label'ом вне дерева нельзя — override кегля не попадает в theme-cache
# узла до входа в дерево, и min size считается дефолтным кеглем; а Label,
# которому бокс ниже строки, не рисует её ВООБЩЕ (lines_visible = 0).
func _level_up_probe_line_height(font_size: int) -> float:
	var probe := Label.new()
	var font: Font = probe.get_theme_font("font")
	probe.free()
	if font == null:
		font = ThemeDB.fallback_font
	return ceilf(font.get_height(font_size))




# SCRUM-892: лёгкий подсвет сокета при hover/focus карточки — modulate 1.12 без
# таймеров; метод+bind вместо лямбды (канон freed-lambda SCRUM-551) + гарды.
func _update_level_up_socket_glow(button: Button, socket: TextureRect) -> void:
	if button == null or socket == null or not is_instance_valid(button) or not is_instance_valid(socket):
		return
	var lit := button.is_hovered() or button.has_focus()
	socket.modulate = Color(1.12, 1.12, 1.12, 1.0) if lit else Color.WHITE




func _make_level_up_reward_button(reward: Dictionary, layout := {}, advice := {}, reward_index := -1) -> Button:
	var is_rare := bool(reward.get("rare", false))
	var rare_color: Color = TIER_COLORS[3]
	# SCRUM-871: прогноз этой карточки и её бейдж из общего advice набора.
	var forecast: Dictionary = {}
	var badge_kind := ""
	var forecasts: Array = advice.get("forecasts", [])
	var badges: Array = advice.get("badges", [])
	if reward_index >= 0 and reward_index < forecasts.size():
		forecast = forecasts[reward_index]
	if reward_index >= 0 and reward_index < badges.size():
		badge_kind = str(badges[reward_index])
	# SCRUM-892: стек контентной высоты по общему плану набора.
	var plan: Dictionary = layout.get("card_plan", {})
	if plan.is_empty():
		plan = _level_up_card_plan([reward], {"forecasts": [forecast], "badges": [badge_kind]}, layout)
	var card_size: Vector2 = plan.get("card_size", Vector2(238.0, 300.0))
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = card_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _level_up_card_tooltip(reward, forecast, badge_kind, advice)
	button.set_meta("level_up_text_field_card", true)
	_apply_level_up_card_atlas_theme(button, card_size, is_rare)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)

	# Контент-зона = фактические content margins чип-стиля карточки; блоки стека
	# позиционируются вручную (Control-хост, не контейнер — гейт no_overlap).
	var card_margins: Vector4 = button.get_meta("level_up_card_content_margins", Vector4.ZERO)
	var content := Control.new()
	content.name = "LevelUpRewardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.clip_contents = true
	content.position = Vector2(card_margins.x, card_margins.y)
	content.size = Vector2(
		maxf(card_size.x - card_margins.x - card_margins.z, 8.0),
		maxf(card_size.y - card_margins.y - card_margins.w, 8.0)
	)
	content.custom_minimum_size = content.size
	button.add_child(content)

	var content_width := content.size.x
	var gap := float(plan.get("gap", 8.0))
	var badge_w := float(plan.get("badge_w", 200.0))
	var badge_h := float(plan.get("badge_h", 26.0))
	var has_badge := badge_kind != "" and LU_BADGE_META.has(badge_kind)
	var stack_y := 0.0
	if bool(plan.get("badge_slot", false)):
		if has_badge:
			_add_level_up_badge(
				content, badge_kind,
				Rect2(roundf((content_width - badge_w) * 0.5), stack_y, badge_w, badge_h),
				int(plan.get("badge_font", 12))
			)
		stack_y += badge_h + gap

	# Сокет атласа за иконкой награды: socket_notable; карточке advisor-акцента
	# (метки «ЛУЧШИЙ УРОН»/«ЛУЧШИЙ ВЫБОР») — socket_keystone + звезда star_alloc
	# в правом-верхнем углу сокета. Только KEEP_ASPECT_CENTERED в фикс-боксах
	# (натив 128/168/80 или пропорциональный даунскейл), NEAREST.
	var socket_box := float(plan.get("socket_box", 64.0))
	var advisor_keystone := badge_kind in ["dps", "both"]
	var socket := TextureRect.new()
	socket.name = "LevelUpRewardSocket%d" % maxi(reward_index, 0)
	socket.texture = game._cached_texture(str(META40_SOCKET_TEXTURES["keystone" if advisor_keystone else "notable"]))
	socket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	socket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	socket.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket.position = Vector2(roundf((content_width - socket_box) * 0.5), stack_y)
	socket.size = Vector2(socket_box, socket_box)
	socket.custom_minimum_size = socket.size
	content.add_child(socket)

	var icon_px := float(plan.get("icon_px", 40.0))
	var icon_size := Vector2(icon_px, icon_px)
	# Сокет уже задаёт читаемый визуальный масштаб: registry-scale здесь нельзя
	# применять, иначе Control становится в 1.45x больше строгой inner safe-zone.
	var icon := game.UIIconRegistry.make_icon(_reward_icon_id(reward), icon_size, false) as Control
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = socket.position + Vector2(roundf((socket_box - icon_px) * 0.5), roundf((socket_box - icon_px) * 0.5))
	# Фиксируем Control ровно в рассчитанной inner safe-zone.
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	content.add_child(icon)

	if advisor_keystone:
		var star_px := float(plan.get("star_px", 16.0))
		var star_inset := maxf(1.0, roundf(2.0 * float(layout.get("scale", 0.5))))
		var star := TextureRect.new()
		star.name = "LevelUpRewardSocketStar%d" % maxi(reward_index, 0)
		star.texture = game._cached_texture(META40_STAR_ALLOC_PATH)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.position = socket.position + Vector2(socket_box - star_px - star_inset, star_inset)
		star.size = Vector2(star_px, star_px)
		content.add_child(star)

	# Лёгкий подсвет сокета при hover/focus карточки — существующие сигналы кнопки.
	var glow_callable := Callable(self, "_update_level_up_socket_glow").bind(button, socket)
	button.mouse_entered.connect(glow_callable)
	button.mouse_exited.connect(glow_callable)
	button.focus_entered.connect(glow_callable)
	button.focus_exited.connect(glow_callable)
	stack_y += socket_box + gap

	var title_label := Label.new()
	title_label.name = "LevelUpRewardTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Upgrade"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = true
	title_label.max_lines_visible = 1
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.position = Vector2(4.0, stack_y)
	title_label.size = Vector2(content_width - 8.0, float(plan.get("title_h", 20.0)))
	title_label.custom_minimum_size = title_label.size
	# Фидбек читаемости SCRUM-883: пол кегля 12 — длинные титулы уходят в
	# ellipsis, но не в нечитаемый микрошрифт.
	_shrink_label_font_to_width(title_label, SemanticTypography.ROLE_TITLE, int(plan.get("title_font", 12)), title_label.size.x - 4.0, SemanticTypography.role_min(SemanticTypography.ROLE_TITLE))
	title_label.add_theme_color_override("font_color", rare_color if is_rare else Color(0.96, 0.90, 0.68, 1.0))
	content.add_child(title_label)
	stack_y += float(plan.get("title_h", 20.0)) + float(plan.get("small_gap", 4.0))

	var description_label := Label.new()
	description_label.name = "LevelUpRewardDescription"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = _level_up_card_description(reward)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.clip_text = true
	description_label.max_lines_visible = int(plan.get("desc_lines", 2))
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.position = Vector2(6.0, stack_y)
	description_label.size = Vector2(content_width - 12.0, float(plan.get("desc_h", 36.0)))
	description_label.custom_minimum_size = description_label.size
	description_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_DESCRIPTION,
		int(plan.get("desc_font", 12)),
		SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
	))
	description_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	content.add_child(description_label)
	stack_y += float(plan.get("desc_h", 36.0)) + gap

	# SCRUM-871: блок «до -> после» — реально пересчитанные дельты производных
	# статов; глубина блока единая по набору (план), строки центрируются в чипе.
	var effect_inset := float(plan.get("effect_inset", 8.0))
	var effect_panel := PanelContainer.new()
	effect_panel.name = "LevelUpRewardEffectPreview"
	effect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_panel.position = Vector2(effect_inset, stack_y)
	effect_panel.size = Vector2(content_width - effect_inset * 2.0, float(plan.get("effect_chip_h", 40.0)))
	effect_panel.custom_minimum_size = effect_panel.size
	var effect_style := _atlas_chip_style(0.62, float(plan.get("effect_pad", 5.0)))
	effect_panel.add_theme_stylebox_override("panel", effect_style)
	content.add_child(effect_panel)

	# Нулевой minimum size хоста не даёт PanelContainer вырасти из контент-зоны карточки.
	var effect_rows := Control.new()
	effect_rows.name = "LevelUpRewardEffectRows"
	effect_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_panel.add_child(effect_rows)

	var rows_size := Vector2(
		maxf(effect_panel.size.x - effect_style.content_margin_left - effect_style.content_margin_right, 8.0),
		maxf(effect_panel.size.y - effect_style.content_margin_top - effect_style.content_margin_bottom, 8.0)
	)
	var delta_lines_cache: Array = plan.get("delta_lines_per_card", [])
	var delta_lines: Array = delta_lines_cache[reward_index] if (reward_index >= 0 and reward_index < delta_lines_cache.size()) else _level_up_delta_lines(reward, forecast)
	var row_height := float(plan.get("effect_row_h", 18.0))
	var effect_font := int(plan.get("effect_font", 12))
	var line_heights_cache: Array = plan.get("delta_line_heights_per_card", [])
	var line_heights: Array = line_heights_cache[reward_index] if (reward_index >= 0 and reward_index < line_heights_cache.size()) else []
	var has_forecast_deltas: bool = not (forecast.get("deltas", []) as Array).is_empty()
	var planned_height := 0.0
	for line_index in range(delta_lines.size()):
		planned_height += float(line_heights[line_index]) if line_index < line_heights.size() else row_height
	var used_height := roundf(maxf(rows_size.y - planned_height, 0.0) * 0.5)
	for line_index in range(delta_lines.size()):
		var line_label := Label.new()
		line_label.name = "LevelUpRewardEffectText" if line_index == 0 else "LevelUpRewardEffectText%d" % (line_index + 1)
		line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_label.text = str(delta_lines[line_index])
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_shrink_label_font_to_width(line_label, SemanticTypography.ROLE_BODY, effect_font, rows_size.x - 4.0, SemanticTypography.role_min(SemanticTypography.ROLE_BODY))
		line_label.add_theme_color_override("font_color", Color(0.76, 0.96, 0.80, 1.0) if has_forecast_deltas else Color(0.84, 0.97, 1.0, 1.0))
		var line_height := float(line_heights[line_index]) if line_index < line_heights.size() else row_height
		line_label.position = Vector2(0.0, used_height)
		line_label.size = Vector2(rows_size.x, line_height)
		effect_rows.add_child(line_label)
		used_height += line_height
	return button




func _level_up_layout_metrics() -> Dictionary:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	# SCRUM-985 убрал внешнюю раму: frameless stage масштабируется от реального
	# viewport. Повторное вычитание старого safe-inset уменьшало Level Up почти
	# вдвое и превращало LU.DetailDrawer в перекрывающий карточки overlay.
	var scale := clampf(
		minf((viewport_size.x - 8.0) / LU_PANEL_2K.size.x, (viewport_size.y - 8.0) / LU_PANEL_2K.size.y),
		0.30, 1.0
	)
	var compact := viewport_size.y < 900.0
	var xy := Vector2(scale, scale)
	var panel_size := Vector2(roundf(LU_PANEL_2K.size.x * scale), roundf(LU_PANEL_2K.size.y * scale))
	# Контент-зона = фактические content margins чипа панели (_atlas_chip_style:
	# по горизонтали pad*1.4) — PanelContainer сам ставит бокс ровно в эту зону.
	var panel_pad := roundf(LU_PANEL_CHIP_PAD_2K * scale)
	var content_position := Vector2(panel_pad * 1.4, panel_pad)
	var content_size := panel_size - Vector2(panel_pad * 2.8, panel_pad * 2.0)
	var card_gap := roundf(LU_CARD_GAP_2K * scale)
	# Frameless compact stage has useful horizontal slack. Give it to the three
	# cards (up to the authored 2K width) so complete multi-row deltas wrap less
	# and leave a real vertical lane for LU.DetailDrawer.
	var authored_card_width := roundf(LU_CARD_2K.size.x * scale)
	var available_card_width := floorf((content_size.x - card_gap * 2.0 - 16.0) / 3.0)
	var card_width := minf(LU_CARD_2K.size.x, maxf(authored_card_width, available_card_width))
	# «Позже» — фикс-размер глобального кита (высота от вьюпорта, не от scale):
	# прижата к низу контент-зоны, по центру.
	var later_size := Vector2(LU_LATER_BUTTON_WIDTH, _atlas_action_button_height())
	var later_position := Vector2(
		roundf((content_size.x - later_size.x) * 0.5),
		content_size.y - later_size.y - maxf(8.0, roundf(12.0 * scale))
	)
	# FAN-1927 (спека LU.DetailDrawer): ЖЕЛАЕМЫЙ размер scroll-зоны длинной
	# русской копии (@1920 ≈ 900×190, uniform scale). Фактический rect считает
	# _show_level_up_screen из остатка зоны ПОД контентной высотой карточек —
	# карточный план никогда не ужимается ради drawer.
	var drawer_size := Vector2(
		minf(roundf(1200.0 * scale), content_size.x - 16.0),
		clampf(roundf(210.0 * scale), 64.0, 210.0)
	)
	# Ряд карточек занимает всю зону между шапкой и «Позже»; карточки контентной
	# высоты (SIZE_SHRINK_CENTER) центрируются в ней по вертикали.
	var rewards_zone_top := roundf(LU_REWARDS_ROW_TOP_2K * scale)
	var rewards_zone_bottom := later_position.y - maxf(8.0, roundf(14.0 * scale))
	var rewards_row_size := Vector2(
		card_width * 3.0 + card_gap * 2.0,
		maxf(rewards_zone_bottom - rewards_zone_top, 64.0)
	)
	var rewards_row_position := Vector2(roundf((content_size.x - rewards_row_size.x) * 0.5), rewards_zone_top)
	# Церемониальный орнамент под титулом: бокс ~46% ширины панели, высота 14-28
	# (KEEP_ASPECT_CENTERED центрирует арт по высоте бокса).
	var divider_size := Vector2(
		roundf(panel_size.x * LU_DIVIDER_PANEL_WIDTH_RATIO),
		clampf(roundf(LU_DIVIDER_HEIGHT_2K * scale), 14.0, LU_DIVIDER_HEIGHT_2K)
	)
	var divider_position := Vector2(
		roundf((content_size.x - divider_size.x) * 0.5),
		roundf(LU_DIVIDER_TOP_2K * scale)
	)
	return {
		"scale": scale,
		"panel_size": panel_size,
		"panel_pad": panel_pad,
		"content_position": content_position,
		"content_size": content_size,
		"hero_header_position": _level_up_scaled_position(LU_HERO_HEADER_RECT, xy),
		"hero_header_size": _level_up_scaled_size(LU_HERO_HEADER_RECT, xy),
		"title_position": _level_up_scaled_position(LU_TITLE_RECT, xy),
		"title_size": _level_up_scaled_size(LU_TITLE_RECT, xy),
		"divider_position": divider_position,
		"divider_size": divider_size,
		"subtitle_position": _level_up_scaled_position(LU_SUBTITLE_RECT, xy),
		"subtitle_size": _level_up_scaled_size(LU_SUBTITLE_RECT, xy),
		"rewards_row_position": rewards_row_position,
		"rewards_row_size": rewards_row_size,
		"card_width": card_width,
		"card_gap": card_gap,
		"drawer_size": drawer_size,
		"later_button_position": later_position,
		"later_button_size": later_size,
		"title_font": maxi(16, int(roundf(38.0 * scale))),
		"title_scale": Vector2.ONE,
		"subtitle_font": maxi(12, int(roundf(18.0 * scale))),
		"compact": compact,
	}




func _create_level_up_menu_box(title: String, subtitle: String, layout := {}) -> Control:
	game._clear_ui()
	if layout.is_empty():
		layout = _level_up_layout_metrics()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "LevelUpOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, "level_up")

	var dim := ColorRect.new()
	dim.name = "LevelUpDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.035, 0.0)
	# ColorRect по умолчанию перехватывает мышь (STOP). Полноэкранная подложка не должна
	# глотать клики по карточкам — пропускаем ввод насквозь.
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var sparkle_root := Control.new()
	sparkle_root.name = "LevelUpParticles"
	sparkle_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	sparkle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sparkle_root)
	_create_level_up_burst_shapes(sparkle_root)

	var panel := PanelContainer.new()
	panel.name = "LevelUpPanel"
	var panel_size: Vector2 = layout.get("panel_size", Vector2(1120, 660))
	var panel_pad: float = layout.get("panel_pad", 14.0)
	var panel_content_position: Vector2 = layout.get("content_position", Vector2(46.0, 55.0))
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	# SCRUM-552: панель НЕ масштабируем на интро (scale<1 сжимал глобальные rect'ы
	# текстовых лейблов → ui_no_overlap_matrix флачил «needs height X but has 0.86*X»).
	# Раскрытие — через fade (modulate.a) ниже в _start_level_up_intro, геометрия с
	# первого кадра финальная и детерминированная.
	panel.scale = Vector2.ONE
	panel.modulate.a = 0.0
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# SCRUM-985: PanelContainer остаётся layout/safe-margin хостом, но большая
	# общая рамка визуально снята. Контраст обеспечивают локальные reward cards.
	var panel_style := _atlas_chip_style(LU_PANEL_BACKGROUND_ALPHA, panel_pad)
	panel_style.border_color = Color.TRANSPARENT
	panel_style.set_border_width_all(0)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_meta("level_up_slot", "level_up_panel")
	panel.set_meta("level_up_content_margins", Vector4(
		panel_style.content_margin_left,
		panel_style.content_margin_top,
		panel_style.content_margin_right,
		panel_style.content_margin_bottom
	))
	panel.set_meta("level_up_content_rect", Rect2(panel_content_position, layout.get("content_size", Vector2(768.0, 417.0))))
	root.add_child(panel)

	var box := Control.new()
	box.name = "LevelUpContent"
	box.position = panel_content_position
	box.size = layout.get("content_size", Vector2(768.0, 417.0))
	box.custom_minimum_size = box.size
	panel.add_child(box)

	var hero_header := Control.new()
	hero_header.name = "LevelUpHeroHeader"
	hero_header.position = layout.get("hero_header_position", Vector2.ZERO)
	hero_header.size = layout.get("hero_header_size", Vector2(645.0, 70.0))
	hero_header.custom_minimum_size = hero_header.size
	box.add_child(hero_header)

	# Директива пользователя SCRUM-892: иконки/портрета класса на level-up НЕТ —
	# шапка симметричная и церемониальная: золотой титул на всю ширину, под ним
	# орнамент-разделитель, под орнаментом сабтитул.
	var title_label := Label.new()
	title_label.name = "LevelUpTitle"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.position = layout.get("title_position", Vector2.ZERO)
	title_label.size = layout.get("title_size", Vector2(440.0, 30.0))
	title_label.scale = layout.get("title_scale", Vector2(1.18, 1.18))
	title_label.modulate.a = 0.0
	title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DISPLAY, int(layout.get("title_font", 50)), 0, 72))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	# SCRUM-892: церемониальная линия под золотым титулом — атласный
	# divider_ornament в фикс-боксе (KEEP_ASPECT_CENTERED, NEAREST).
	var title_divider := TextureRect.new()
	title_divider.name = "LevelUpTitleDivider"
	title_divider.texture = game._cached_texture(ATLAS_STYLE_DIVIDER_PATH)
	title_divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_divider.position = layout.get("divider_position", Vector2.ZERO)
	title_divider.size = layout.get("divider_size", Vector2(360.0, 24.0))
	title_divider.custom_minimum_size = title_divider.size
	box.add_child(title_divider)

	var subtitle_label := Label.new()
	subtitle_label.name = "LevelUpSubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.position = layout.get("subtitle_position", Vector2.ZERO)
	subtitle_label.size = layout.get("subtitle_size", Vector2(460.0, 22.0))
	subtitle_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, int(layout.get("subtitle_font", 17)), 0, 26),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	box.add_child(subtitle_label)

	return box




func _create_level_up_burst_shapes(parent: Control) -> void:
	var center = game.ARENA_CENTER
	for index in range(12):
		var ray := ColorRect.new()
		ray.name = "LevelUpRay%d" % index
		ray.color = Color(1.0, 0.78, 0.24, 0.0)
		ray.position = center
		ray.size = Vector2(240.0 + float(index % 3) * 42.0, 4.0)
		ray.pivot_offset = Vector2(0.0, 2.0)
		ray.rotation = TAU * float(index) / 12.0
		parent.add_child(ray)

	for index in range(20):
		var spark := ColorRect.new()
		spark.name = "LevelUpSpark%d" % index
		spark.color = Color(0.38, 0.95, 1.0, 0.0) if index % 2 == 0 else Color(1.0, 0.78, 0.24, 0.0)
		spark.position = center
		spark.size = Vector2(8.0, 8.0)
		spark.pivot_offset = Vector2(4.0, 4.0)
		parent.add_child(spark)




func _start_level_up_intro(panel: Node, title_label: Node, reward_buttons: Array, sparkle_root: Node) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	await game.get_tree().process_frame
	if panel == null or not is_instance_valid(panel) or game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return

	var level_up_panel := panel as PanelContainer
	if level_up_panel == null:
		return
	level_up_panel.pivot_offset = level_up_panel.size * 0.5
	var dim = game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpDim") as ColorRect
	if dim != null:
		var dim_tween = dim.create_tween()
		dim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		# SCRUM-985: arcane-lab остаётся заметным вместо почти чёрной подложки.
		dim_tween.tween_property(dim, "color:a", LU_DIM_ALPHA, 0.16)

	# SCRUM-552: панель раскрываем только fade'ом (modulate.a). Scale-«поп» убран —
	# он сжимал глобальные rect'ы текстовых лейблов (LevelUpTitle/RewardDescription),
	# из-за чего ui_no_overlap_matrix интермиттентно краснел на оверфлоу высоты.
	var panel_tween = level_up_panel.create_tween()
	panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(level_up_panel, "modulate:a", 1.0, 0.18)

	var title := title_label as Label
	if title != null and is_instance_valid(title):
		title.pivot_offset = title.size * 0.5
		var title_tween = title.create_tween()
		title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		title_tween.set_trans(Tween.TRANS_BACK)
		title_tween.set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title, "scale", Vector2.ONE, 0.28)
		title_tween.parallel().tween_property(title, "modulate:a", 1.0, 0.18)

	_start_level_up_button_intro(reward_buttons)
	_start_level_up_burst_intro(sparkle_root)




func _start_level_up_button_intro(reward_buttons: Array) -> void:
	for index in range(reward_buttons.size()):
		var button := reward_buttons[index] as Button
		if button == null or not is_instance_valid(button):
			continue
		button.modulate.a = 0.0
		# Keep generated frame geometry exact for safe-zone QA; reveal cards with fade only.
		button.scale = Vector2.ONE
		button.pivot_offset = button.size * 0.5
		var button_tween = button.create_tween()
		button_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		button_tween.set_trans(Tween.TRANS_CUBIC)
		button_tween.set_ease(Tween.EASE_OUT)
		button_tween.tween_interval(0.10 + float(index) * 0.07)
		button_tween.tween_property(button, "modulate:a", 1.0, 0.18)




func _start_level_up_burst_intro(sparkle_root: Node) -> void:
	if sparkle_root == null or not is_instance_valid(sparkle_root):
		return

	var center = game.ARENA_CENTER
	for child in sparkle_root.get_children():
		if not child is ColorRect:
			continue
		var rect := child as ColorRect
		var tween = rect.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		if rect.name.begins_with("LevelUpRay"):
			rect.position = center
			rect.scale = Vector2(0.12, 1.0)
			tween.tween_property(rect, "scale", Vector2(1.0, 1.0), 0.24)
			tween.parallel().tween_property(rect, "color:a", 0.32, 0.10)
			tween.tween_property(rect, "color:a", 0.0, 0.30)
		else:
			var index := int(str(rect.name).trim_prefix("LevelUpSpark"))
			var angle := TAU * float(index) / 20.0
			var distance := 120.0 + float(index % 5) * 26.0
			rect.position = center
			rect.scale = Vector2(0.35, 0.35)
			tween.tween_interval(float(index % 4) * 0.035)
			tween.tween_property(rect, "position", center + Vector2.RIGHT.rotated(angle) * distance, 0.34)
			tween.parallel().tween_property(rect, "scale", Vector2(1.0, 1.0), 0.18)
			tween.parallel().tween_property(rect, "color:a", 0.92, 0.10)
			tween.tween_property(rect, "color:a", 0.0, 0.28)
