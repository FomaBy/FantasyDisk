extends "res://scripts/ui/screens/pause_menu.gd"

# FAN-3824: модуль распределённого UI-класса — выбор оружия и стартового дара.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# SCRUM-883: экраны выбора оружия и стартового буна на едином атлас-стиле
# (эталон SCRUM-879): фон-зал героев COVERED (продолжение флоу выбора героя),
# контент в safe-зоне полой рамы meta40, панели/карточки — чипы StyleBoxFlat,
# кнопки — глобальный кит. Геометрия адаптивная от _atlas_ui_scale(): на базе
# 2560×1440 держит смоук-контракты (колодец ≥200, спрайт ≥176, статс ≥300),
# на малых вьюпортах матрицы пропорционально ужимается в safe-зону.


# Общий полноэкранный корень пре-ран экранов оружия/буна: чистка UI, слой,
# root на весь экран, глобальные тултипы. Фон/safe/рама добавляются звонящим.
func _weapon_flow_shell_root(screen_name: String) -> Control:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)
	var root := Control.new()
	root.name = screen_name
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	return root




# Шапка атлас-экрана: чип-титул слева, «Назад» на глобальном ките справа
# (единый возврат 2026-07-08: плита 260 × action-height на всех экранах).
func _weapon_flow_header(layout: VBoxContainer, prefix: String, title: String, s: float, back_action: Callable) -> Button:
	var header := HBoxContainer.new()
	header.name = "%sHeader" % prefix
	header.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	layout.add_child(header)
	header.add_child(_unified_header_chip(prefix, title, "hero_select", s))
	var spacer := Control.new()
	spacer.name = "%sHeaderSpacer" % prefix
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	var back_button := _make_button("Назад")
	back_button.name = "%sBackButton" % prefix
	_set_action_button_size(back_button, 260.0, _atlas_action_button_height())
	back_button.pressed.connect(back_action)
	header.add_child(back_button)
	return back_button




func _show_weapon_select() -> void:
	var character_config = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var root := _weapon_flow_shell_root("WeaponSelectScreen")
	_unified_add_background(root, "hero_select")

	var s := _atlas_ui_scale()
	var safe := _unified_make_safe_area(root, "WeaponSelect")
	var layout := VBoxContainer.new()
	layout.name = "WeaponSelectLayout"
	layout.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	safe.add_child(layout)
	var back_button := _weapon_flow_header(layout, "WeaponSelect", "Выбор оружия", s, _show_character_select)

	# Плита карточек: узел MenuPanel_weapon_select — тест-контракт (смоук/матрица:
	# PanelContainer + StyleBoxFlat alpha >= 0.80), стиль — атлас-чип.
	var panel := PanelContainer.new()
	panel.name = "MenuPanel_weapon_select"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _weapon_select_panel_style())
	layout.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "WeaponSelectCards"
	box.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	panel.add_child(box)

	var subtitle := Label.new()
	subtitle.name = "WeaponSelectSubtitle"
	subtitle.text = "%s: выбери стартовое оружие." % str(character_config["title"])
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 17, 12, 24),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	box.add_child(subtitle)

	var weapon_cards: Array = []
	for weapon_id in game.PROGRESSION_DATA.weapon_ids(game.selected_character_id):
		var config = game.PROGRESSION_DATA.weapon(game.selected_character_id, str(weapon_id))
		var button := _make_weapon_select_card(config)
		button.pressed.connect(func() -> void:
			game.selected_weapon_id = str(config["id"])
			# SCRUM-502: фактический старт нового забега (герой+оружие выбраны) — обнулить
			# метрики сводки, чтобы они не текли из прошлого прогона/autosave.
			game.begin_new_run_session()
			# SCRUM-618: между выбором оружия и стартом — пикер стартового боона.
			_show_start_boon_select()
		)
		box.add_child(button)
		weapon_cards.append(button)

	game.ui_escape_action = _show_character_select
	# Полая рама атласа — ПОСЛЕДНЕЙ, поверх контента.
	_unified_add_frame(root, "WeaponSelect")

	# SCRUM-813: карточки оружия листаются вверх/вниз по кругу, «Назад» в шапке; A
	# выбирает, B/Esc возвращает к выбору героя. Старт — первая карточка.
	_wire_run_ui_focus(weapon_cards, false, [back_button],
		weapon_cards[0] if not weapon_cards.is_empty() else back_button)




func _make_weapon_select_card(config: Dictionary) -> Button:
	var weapon_id := str(config.get("id", ""))
	var character_id := str(config.get("character_id", game.selected_character_id))
	var s := _atlas_ui_scale()
	var button := Button.new()
	button.name = "WeaponOption_%s" % weapon_id
	button.set_meta("weapon_id", weapon_id)
	button.text = ""
	# Пол min-высоты держит карточку читаемой на малых вьюпортах; на базе карточки
	# растягиваются EXPAND_FILL и делят плиту (фактически ~260, смоук требует >=110).
	button.custom_minimum_size = Vector2(0.0, roundf(maxf(200.0 * s, 96.0)))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s\n%s" % [
		str(config.get("title", weapon_id)),
		_weapon_select_identity_text(character_id, weapon_id),
		str(config.get("description", "")),
	]
	_weapon_card_theme(button, roundf(12.0 * s))

	var row := HBoxContainer.new()
	row.name = "WeaponOptionContent_%s" % weapon_id
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card_content := _weapon_select_card_content_margins()
	row.offset_left = card_content.x
	row.offset_top = card_content.y
	row.offset_right = -card_content.z
	row.offset_bottom = -card_content.w
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(roundf(24.0 * s)))
	button.add_child(row)

	var icon_well := PanelContainer.new()
	icon_well.name = "WeaponSelectIconWell_%s" % weapon_id
	# База 2560: 204×204 (смоук-контракт >=200); на малых вьюпортах ужимается.
	icon_well.custom_minimum_size = Vector2(roundf(204.0 * s), roundf(204.0 * s))
	icon_well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_well.add_theme_stylebox_override("panel", _weapon_select_icon_well_style())
	row.add_child(icon_well)

	var sprite := TextureRect.new()
	sprite.name = "WeaponSelectSprite_%s" % weapon_id
	sprite.custom_minimum_size = Vector2(roundf(176.0 * s), roundf(176.0 * s))
	sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = game._cached_texture(_weapon_sprite_path(config))
	icon_well.add_child(sprite)

	var text_box := VBoxContainer.new()
	text_box.name = "WeaponSelectText_%s" % weapon_id
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.name = "WeaponSelectTitle_%s" % weapon_id
	title_label.text = str(config.get("title", weapon_id))
	title_label.max_lines_visible = 1
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 26, 12, 36))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var identity_label := Label.new()
	identity_label.name = "WeaponSelectIdentity_%s" % weapon_id
	identity_label.text = "Отличие: %s" % _weapon_select_identity_text(character_id, weapon_id)
	identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_label.max_lines_visible = 2
	identity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_FIELD, 17, 12, 23))
	identity_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	identity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(identity_label)

	var desc_label := Label.new()
	desc_label.name = "WeaponSelectDescription_%s" % weapon_id
	desc_label.text = _weapon_select_mechanic_summary(config)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 2
	desc_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 15, 12, 21))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(desc_label)

	var role_label := Label.new()
	role_label.name = "WeaponSelectRole_%s" % weapon_id
	role_label.text = _weapon_select_role_text(character_id, config)
	role_label.max_lines_visible = 1
	role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_FIELD, 14, 12, 18))
	role_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(role_label)

	var stats_panel := PanelContainer.new()
	stats_panel.name = "WeaponSelectStatsPanel_%s" % weapon_id
	# База 2560: 310×204 (смоук-контракт min.x >= 300).
	stats_panel.custom_minimum_size = Vector2(roundf(310.0 * s), roundf(204.0 * s))
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_theme_stylebox_override("panel", _weapon_select_stats_panel_style())
	row.add_child(stats_panel)

	var stats_label := Label.new()
	stats_label.name = "WeaponSelectStats_%s" % weapon_id
	stats_label.custom_minimum_size = Vector2(roundf(280.0 * s), 0)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.text = _weapon_select_stats_text(config)
	stats_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_BODY, 13, 12, 17))
	stats_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_child(stats_label)
	return button




# SCRUM-883: плита экрана — атлас-чип (тест-контракт: StyleBoxFlat, alpha >= 0.80).
func _weapon_select_panel_style() -> StyleBoxFlat:
	return _atlas_chip_style(0.90, roundf(12.0 * _atlas_ui_scale()))




func _weapon_select_card_content_margins() -> Vector4:
	var s := _atlas_ui_scale()
	return Vector4(roundf(22.0 * s), roundf(18.0 * s), roundf(22.0 * s), roundf(18.0 * s))




# SCRUM-883: тема карточек оружия/буна — «кожаный ряд» атласа (hover/pressed/
# focus/disabled от row-theme) с поднятым normal-чипом: row-normal 0.72 ниже
# смоук-контракта прозрачности (>=0.80), карточкам нужен фон плотнее.
func _weapon_card_theme(button: Button, pad := 12.0) -> void:
	_unified_apply_row_theme(button, pad)
	UIButtonFamily.assign(button, UIButtonFamily.FAMILY_WEAPON_CARD)
	button.add_theme_stylebox_override("normal", _atlas_chip_style(0.86, pad))




# Колодец иконки: тихая полупрозрачная подложка без канта (арт не спорит с рамой).
func _weapon_select_icon_well_style() -> StyleBoxFlat:
	return _atlas_translucent_style(0.55, 10.0)




func _weapon_select_stats_panel_style() -> StyleBoxFlat:
	return _atlas_chip_style(0.62, roundf(10.0 * _atlas_ui_scale()))




func _weapon_select_identity_text(character_id: String, weapon_id: String) -> String:
	var identity := str(game.PROGRESSION_DATA.weapon_mechanic_identity(character_id, weapon_id))
	if identity.strip_edges() == "":
		return "уникальный стиль атаки этого оружия"
	return identity




func _weapon_select_role_text(character_id: String, config: Dictionary) -> String:
	var archetype := _weapon_select_archetype_label(config)
	var main_attribute := str(game.PROGRESSION_DATA.class_main_attribute(character_id))
	var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(main_attribute, main_attribute))
	var mode_label := _weapon_select_mode_label(config)
	return "Роль: %s · %s · Скейл: %s" % [archetype, mode_label, stat_name]




func _weapon_select_mechanic_summary(config: Dictionary) -> String:
	var archetype := _weapon_select_archetype_label(config)
	var mode_label := _weapon_select_mode_label(config)
	var attack_range := float(config.get("attack_range", 0.0))
	var radius := float(config.get("aoe_radius", 0.0))
	if int(config.get("max_summons", 0)) > 0:
		return "Призывает до %d союзн.; держит давление сам, лучше раскрывается через Leadership." % int(config.get("max_summons", 0))
	match mode_label:
		"сектор":
			return "Направленный сектор: важно позиционирование. Дуга/радиус растут от секторных усилений."
		"круг":
			return "Круговая зона вокруг героя: стабильная зачистка рядом, радиус раскрывает контроль толпы."
		"траектория":
			return "Траектория/линия: сильнее по выбранному направлению, ценит дальность и точное наведение."
		"взрыв":
			return "Взрывная зона: короткое окно урона по группе, радиус повышает число задетых целей."
		"установка":
			return "Ставит объект/ловушку: контроль пространства, заранее покрывает подходы врагов."
		"цепь":
			return "Цепная атака: перескакивает между целями и лучше работает в плотной группе."
		_:
			if archetype == "область" or radius >= attack_range * 0.75:
				return "Зональная атака: держит область под контролем и хорошо чистит ближнюю толпу."
			if attack_range >= 420.0:
				return "Дальняя атака: безопаснее открывает бой и сильнее отыгрывает дистанцию."
	return "Уникальная схема атаки: отличается формой удара, темпом и способом контроля целей."




func _weapon_select_archetype_label(config: Dictionary) -> String:
	match str(game.PROGRESSION_DATA.weapon_archetype(config)):
		"melee":
			return "ближний бой"
		"beam":
			return "луч/линия"
		"aoe":
			return "область"
		"summon":
			return "призыв/устройство"
		"aura":
			return "аура"
		"projectile":
			return "снаряд"
	return "особая атака"




func _weapon_select_mode_label(config: Dictionary) -> String:
	var mode := str(config.get("attack_mode", config.get("attack_shape", "")))
	match mode:
		"cone", "sweep":
			return "сектор"
		"circle", "slam", "aura":
			return "круг"
		"beam", "line", "pierce":
			return "траектория"
		"burst", "explosion":
			return "взрыв"
		"deploy", "trap", "mine":
			return "установка"
		"chain":
			return "цепь"
		"single":
			return "точечная цель"
	if str(config.get("summon_role", "")) != "" or int(config.get("max_summons", 0)) > 0:
		return "союзники"
	return "механика"




func _weapon_select_stats_text(config: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Архетип: %s" % _weapon_select_archetype_label(config))
	lines.append("Дальность %.0f / радиус %.0f" % [
		float(config.get("attack_range", 0.0)),
		float(config.get("aoe_radius", 0.0)),
	])
	lines.append("Перезарядка %.2fс" % float(config.get("fire_interval", 0.0)))
	if int(config.get("max_summons", 0)) > 0:
		lines.append("Лимит: %d" % int(config.get("max_summons", 0)))
	elif float(config.get("knockback", 0.0)) > 0.0:
		lines.append("Контроль: %.0f" % float(config.get("knockback", 0.0)))
	else:
		lines.append("Урон x%.2f" % float(config.get("damage_multiplier", 1.0)))
	return "\n".join(lines)




# SCRUM-618: пикер стартового боона. Показывает 3 случайных боона (карточный паттерн)
# между выбором оружия и стартом забега. Выбор → game.selected_start_boon_id + автосейв
# + карта. «Без боона» завершает выбор тождественно (selected_start_boon_id="").
# SCRUM-883: тот же атлас-шелл, что у выбора оружия (фон-зал/safe/чип-шапка/рама).
func _show_start_boon_select() -> void:
	var all_boons: Array = game.PROGRESSION_DATA.start_boons(game.selected_character_id)
	# Случайная выборка 3 без повторов (детерминирована текущим состоянием game.rng).
	var pool: Array = all_boons.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = game.rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var offered: Array = pool.slice(0, mini(3, pool.size()))

	var root := _weapon_flow_shell_root("StartBoonScreen")
	_unified_add_background(root, "hero_select")

	var s := _atlas_ui_scale()
	var safe := _unified_make_safe_area(root, "StartBoon")
	var layout := VBoxContainer.new()
	layout.name = "StartBoonLayout"
	layout.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	safe.add_child(layout)
	var back_button := _weapon_flow_header(layout, "StartBoon", "Стартовый боон", s, _show_weapon_select)

	var panel := PanelContainer.new()
	panel.name = "StartBoonPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _weapon_select_panel_style())
	layout.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "StartBoonCards"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	panel.add_child(box)

	var subtitle := Label.new()
	subtitle.name = "StartBoonSubtitle"
	subtitle.text = "Выбери одно благословение на этот забег."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 17, 12, 24),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	box.add_child(subtitle)

	var boon_cards: Array = []
	for boon in offered:
		var boon_dict: Dictionary = boon
		var button := _make_start_boon_card(boon_dict)
		button.pressed.connect(func() -> void:
			game.selected_start_boon_id = str(boon_dict.get("id", ""))
			game.save_run_autosave("start_boon")
			game.route._show_battle_map()
		)
		box.add_child(button)
		boon_cards.append(button)

	# «Без боона» — пропустить (тождественность). Возможность не брать ничего.
	var skip_button := _make_button("Без боона")
	skip_button.name = "StartBoonSkipButton"
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_button.pressed.connect(func() -> void:
		game.selected_start_boon_id = ""
		game.save_run_autosave("start_boon")
		game.route._show_battle_map()
	)
	box.add_child(skip_button)
	game.ui_escape_action = _show_weapon_select
	_unified_add_frame(root, "StartBoon")

	# SCRUM-813: бооны листаются вверх/вниз по кругу, «Без боона» ниже, «Назад» в
	# шапке; A выбирает, B/Esc возвращает к выбору оружия. Старт — первый боон.
	_wire_run_ui_focus(boon_cards, false, [skip_button, back_button],
		boon_cards[0] if not boon_cards.is_empty() else skip_button)




func _make_start_boon_card(boon: Dictionary) -> Button:
	var boon_id := str(boon.get("id", ""))
	var s := _atlas_ui_scale()
	var button := Button.new()
	button.name = "StartBoonOption_%s" % boon_id
	button.set_meta("boon_id", boon_id)
	button.text = ""
	button.custom_minimum_size = Vector2(0.0, roundf(maxf(116.0 * s, 84.0)))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [str(boon.get("title", boon_id)), str(boon.get("description", ""))]
	_weapon_card_theme(button, roundf(10.0 * s))

	var text_box := VBoxContainer.new()
	text_box.name = "StartBoonText_%s" % boon_id
	text_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_box.offset_left = roundf(22.0 * s)
	text_box.offset_top = roundf(12.0 * s)
	text_box.offset_right = -roundf(22.0 * s)
	text_box.offset_bottom = -roundf(12.0 * s)
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	button.add_child(text_box)

	var title_label := Label.new()
	title_label.name = "StartBoonTitle_%s" % boon_id
	title_label.text = str(boon.get("title", boon_id))
	title_label.max_lines_visible = 1
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 21, 12, 30))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "StartBoonDescription_%s" % boon_id
	desc_label.text = str(boon.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 3
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 14, 12, 20))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(desc_label)
	return button




func _weapon_sprite_path(config: Dictionary) -> String:
	for key in ["icon_path", "sprite_path", "weapon_sprite_path"]:
		var configured_path := str(config.get(key, ""))
		if configured_path != "" and ResourceLoader.exists(configured_path):
			return configured_path
	var weapon_id := str(config.get("id", ""))
	var aliases := {
		"sword": "two_handed_sword",
		"axe": "two_handed_axe",
		"hammer": "two_handed_hammer",
	}
	var asset_id := str(aliases.get(weapon_id, weapon_id))
	var direct_path := "res://assets/sprites/weapons/%s.png" % asset_id
	if ResourceLoader.exists(direct_path):
		return direct_path
	return ""
