extends "res://scripts/ui/screens/settings_screen.gd"

# FAN-3824: модуль распределённого UI-класса — вкладки настроек: игра, управление, аудио, стили v6.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _make_settings_tab_switcher(tabs: TabContainer, _s: float) -> Control:
	# SCRUM-882 (фидбек к SCRUM-879): табы настроек — тот же стиль, что у кнопки
	# «Назад»: 260×_atlas_action_button_height(); на высоте 104 size-маппинг кита
	# даёт ту же НАТИВНУЮ плиту back_260x104, что носит SettingsBackButton, на
	# компакт-высотах 88/72 кит штатно уходит в 9-slice-ветки (как табы Атласа).
	# SCRUM-1025: 1080p/2K = one-row 4×260; compact <=760px = 2×2. Каждая
	# плита самостоятельна — исторический 3-slot ornament не растягивается.
	# SCRUM-1060: все четыре подписи — text-only и используют ровно тот же
	# readability contract, что SettingsBackButton. Иконки убраны на всех tier:
	# длинное «Управление» с иконкой не сохраняло Back-font внутри плоской
	# x=48..212 content-zone, а уменьшать кегль для fit теперь запрещено.
	var switcher := Control.new()
	switcher.name = "SettingsTabSwitcher"
	switcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_width := 260.0
	var viewport_height: float = float(game.get_viewport().get_visible_rect().size.y)
	var tab_height := 72.0 if viewport_height <= 760.0 else (88.0 if viewport_height <= 1080.0 else 104.0)
	var tab_gap := 24.0
	var compact_grid: bool = viewport_height <= 760.0
	var column_count := 2 if compact_grid else 4
	var row_count := 2 if compact_grid else 1
	var row_gap := 12.0 if compact_grid else 0.0
	switcher.custom_minimum_size = Vector2(
		tab_width * float(column_count) + tab_gap * float(column_count - 1),
		tab_height * float(row_count) + row_gap * float(row_count - 1))
	switcher.set_meta("settings_tab_columns", column_count)
	switcher.set_meta("settings_tab_rows", row_count)
	switcher.set_meta("settings_tab_gap", Vector2(tab_gap, row_gap))

	var buttons: Array[Button] = []
	var labels := ["Экран", "Звук", "Управление", "Игра"]
	for tab_index in range(labels.size()):
		var button := _make_button(labels[tab_index])
		button.name = "SettingsTabButton_%d" % tab_index
		_set_action_button_size(button, tab_width, tab_height)
		var column := tab_index % column_count
		var row := tab_index / column_count
		var tab_left := float(column) * (tab_width + tab_gap)
		var tab_top := float(row) * (tab_height + row_gap)
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = tab_left
		button.offset_top = tab_top
		button.offset_right = tab_left + tab_width
		button.offset_bottom = tab_top + tab_height
		button.icon = null
		button.expand_icon = false
		button.clip_text = false
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.set_meta("settings_tab_content_side_margin", 48.0)
		button.set_meta("settings_fixed_font_contract", _readable_font_size(SemanticTypography.ROLE_TAB, 16))
		button.tooltip_text = "Открыть вкладку: %s" % labels[tab_index]
		var target_tab := tab_index
		button.pressed.connect(func() -> void:
			tabs.current_tab = target_tab
		)
		switcher.add_child(button)
		buttons.append(button)
	# Плоское поле плиты back_260x104 — x∈[48,212] (по бокам драконьи головы
	# орнамента, промер арта): text-only «Управление» помещается в 164px при
	# Back-font 21/22/23/23. Fixed-font параметр разрешает хелперу вычислить
	# одинаковые vertical margins для пяти state styles, но запрещает downscale.
	_settings_fit_kit_row(buttons, tab_width, tab_height, 48.0, 1.0, _readable_font_size(SemanticTypography.ROLE_TAB, 16))

	var update_buttons := func(active_tab: int) -> void:
		# Актив/неактив — модуляцией, теми же тонами, что _atlas_apply_tab_state.
		var active_tint := Color(1.0, 0.94, 0.74)
		var idle_tint := Color(0.74, 0.76, 0.84, 0.92)
		for button_index in range(buttons.size()):
			buttons[button_index].modulate = active_tint if button_index == active_tab else idle_tint
	update_buttons.call(tabs.current_tab)
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		update_buttons.call(tab_index)
	)
	return switcher




func _settings_fit_kit_row(row_buttons: Array, button_width: float, button_height: float, side_pad := 0.0, fit_ratio := 1.0, fixed_font_size := 0) -> void:
	# SCRUM-879: кит-кнопки в фиксированных слотах модалки (табы 84×s, нижний
	# ряд 80×s). Пластины кита не искажаем (те же текстуры, 9-slice-раскрой),
	# но контент доводим под слот: подпись одной строкой (autowrap раздувает
	# min-height Button двухстрочным переносом и распирает кнопку за слот —
	# матрица ловит наезд на соседей), ЕДИНЫЙ для ряда кегль по самой длинной
	# подписи, вертикальные content-margins дозируем от высоты слота; клип —
	# страховка оконного рендера (строка в окне до ×1.5 шире headless-мерки).
	# side_pad > 0 переопределяет боковые поля контента (левое гнездо иконки
	# у табов), 0 — родные поля пластины кита. fit_ratio < 1 — страховка
	# оконного рендера (строка в окне до ~1.4-1.5 шире headless-мерки): кегль
	# подбирается под долю доступной ширины, чтобы буквы не клипались в окне.
	# fixed_font_size > 0 — typography contract для рядов, где layout/spec уже
	# доказал fit: helper не имеет права повторно уменьшать кегль.
	if row_buttons.is_empty():
		return
	var first := row_buttons[0] as Button
	if first == null:
		return
	var font := first.get_theme_font("font")
	var font_size := fixed_font_size if fixed_font_size > 0 else _readable_font_size(SemanticTypography.ROLE_ACTION, 16)
	var side_left := side_pad
	var side_right := side_pad
	if side_pad <= 0.0:
		var base_style := first.get_theme_stylebox("normal")
		side_left = base_style.content_margin_left if base_style != null else 45.0
		side_right = base_style.content_margin_right if base_style != null else 45.0
	var icon_span := 0.0
	var icon_height := 0.0
	for entry in row_buttons:
		var entry_icon := (entry as Button).icon
		if entry_icon != null:
			icon_span = maxf(icon_span, minf(36.0, float(entry_icon.get_width())) + 4.0)
			icon_height = maxf(icon_height, float(entry_icon.get_height()))
	if font != null:
		var avail := (button_width - side_left - side_right - icon_span) * clampf(fit_ratio, 0.1, 1.0)
		var widest := 0.0
		for entry in row_buttons:
			widest = maxf(widest, font.get_string_size((entry as Button).text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
		while fixed_font_size <= 0 and font_size > 11 and widest > avail:
			font_size -= 1
			widest = 0.0
			for entry in row_buttons:
				widest = maxf(widest, font.get_string_size((entry as Button).text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var line_height := 22.0
	if font != null:
		line_height = font.get_height(font_size)
	var v_pad := clampf((button_height - maxf(line_height, icon_height)) * 0.5, 4.0, 16.0)
	for entry in row_buttons:
		var button := entry as Button
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		# Fixed-font rows have already proved full text fit against their declared
		# content zone, so clipping would hide a future localization regression.
		button.clip_text = fixed_font_size <= 0
		button.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_ACTION,
			font_size,
			SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
		))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var state_style := button.get_theme_stylebox(state)
			if state_style == null:
				continue
			var fitted: StyleBox = state_style.duplicate()
			if side_pad > 0.0:
				fitted.content_margin_left = side_pad
				fitted.content_margin_right = side_pad
			fitted.content_margin_top = v_pad
			fitted.content_margin_bottom = v_pad
			button.add_theme_stylebox_override(state, fitted)




func _make_settings_tab(tab_name: String, s := 1.0, column_w := 0.0) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	var page := VBoxContainer.new()
	page.name = "%sContent" % tab_name
	# SCRUM-882 (фидбек): страница таба — колонка фикс-ширины column_w по ЦЕНТРУ
	# панели (SHRINK_CENTER внутри margin-обёртки), строки внутри колонки
	# остаются с левым выравниванием (у самих строк SIZE_SHRINK_BEGIN). Ширины
	# строк считаются от s = column_w/1276 — уже колонки по построению.
	page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if column_w > 0.0 else Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if column_w > 0.0:
		page.custom_minimum_size = Vector2(roundf(column_w), 0.0)
	page.add_theme_constant_override("separation", int(roundf(20.0 * s)))
	margin.add_child(page)
	return margin




func _make_settings_game_tab(s: float, column_w: float, viewport_size: Vector2) -> MarginContainer:
	var game_tab := _make_settings_tab("Игра", s, column_w)
	var page := game_tab.get_child(0) as VBoxContainer
	var compact := viewport_size.y <= 760.0
	var game_content_w := 878.0 if compact else clampf(1424.0 * (viewport_size.y / 1440.0), 1068.0, 1424.0)
	var game_scroll_w := 892.0 if compact else game_content_w
	# SCRUM-1030's 306px mockup viewport was authored without the live Atlas
	# border. In the runtime shell it would end beneath the bottom ornament,
	# violating the global frame-safe rule. Keep the exact 878×520 canvas and
	# 14px lane, but cap the visible height to the actual empty frame interior.
	var compact_scroll_h := maxf(160.0, roundf(viewport_size.y * 0.6875 - 253.0)) if compact else 0.0
	page.custom_minimum_size.x = game_scroll_w
	page.add_theme_constant_override("separation", 0)

	var scroll := ScrollContainer.new()
	scroll.name = "SettingsGameScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(game_scroll_w, compact_scroll_h)
	page.add_child(scroll)
	_settings_v6_style_audio_scrollbar(scroll, s)
	if compact:
		scroll.get_v_scroll_bar().custom_minimum_size.x = 14.0

	var content: Control
	if compact:
		content = Control.new()
	else:
		var wide_content := VBoxContainer.new()
		wide_content.add_theme_constant_override("separation", maxi(2, int(roundf(3.0 * s))))
		content = wide_content
	content.name = "SettingsGameContent"
	content.custom_minimum_size = Vector2(game_content_w, 520.0 if compact else 0.0)
	content.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var title := Label.new()
	title.name = "SettingsGameTitle"
	title.text = "Игровая песочница"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		_settings_v6_font(SemanticTypography.ROLE_TITLE, 28.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))
	title.add_theme_color_override("font_color", SETTINGS_V6_GOLD)
	var status := Label.new()
	status.name = "SettingsGameStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_VALUE,
		_settings_v6_font(SemanticTypography.ROLE_VALUE, 22.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
		SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
	))
	if compact:
		content.add_child(title)
		_settings_game_place_control(title, Rect2(14.0, 8.0, 400.0, 34.0))
		content.add_child(status)
		_settings_game_place_control(status, Rect2(536.0, 8.0, 328.0, 34.0))
	else:
		var header := HBoxContainer.new()
		header.name = "SettingsGameHeader"
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_theme_constant_override("separation", int(roundf(16.0 * s)))
		content.add_child(header)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		status.custom_minimum_size = Vector2(roundf(360.0 * s), roundf(42.0 * s))
		header.add_child(status)

	var description := Label.new()
	description.name = "SettingsGameDescription"
	description.text = "Настрой сложность следующего забега. Текущий забег не изменится."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_DESCRIPTION,
		_settings_v6_font(SemanticTypography.ROLE_DESCRIPTION, 20.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
	))
	description.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	content.add_child(description)
	if compact:
		_settings_game_place_control(description, Rect2(14.0, 52.0, 850.0, 30.0))

	var warning := Label.new()
	warning.name = "SettingsSandboxWarning"
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(0.0, 42.0 if compact else roundf(42.0 * s))
	warning.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_DESCRIPTION,
		_settings_v6_font(SemanticTypography.ROLE_DESCRIPTION, 19.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
	))
	content.add_child(warning)
	if compact:
		_settings_game_place_control(warning, Rect2(14.0, 92.0, 850.0, 42.0))

	var sliders := {}
	var value_labels := {}
	var slider_order: Array[HSlider] = []
	var rows := [
		{"key": game.GAMEPLAY_SANDBOX.MONSTER_HP, "suffix": "monster_hp", "label": "Здоровье монстров"},
		{"key": game.GAMEPLAY_SANDBOX.MONSTER_DAMAGE, "suffix": "monster_damage", "label": "Урон монстров"},
		{"key": game.GAMEPLAY_SANDBOX.PLAYER_DAMAGE, "suffix": "player_damage", "label": "Урон игрока"},
		{"key": game.GAMEPLAY_SANDBOX.PLAYER_ATTACK_SPEED, "suffix": "player_attack_speed", "label": "Скорость атак игрока"},
		{"key": game.GAMEPLAY_SANDBOX.MONSTER_ATTACK_SPEED, "suffix": "monster_attack_speed", "label": "Скорость атак монстров"},
	]
	var configured: Dictionary = game.sandbox_snapshot()
	var layout_scale := viewport_size.y / 1440.0
	var row_label_w := 310.0 if compact else 580.0 * layout_scale
	var row_slider_w := 346.0 if compact else 420.0 * layout_scale
	var row_value_w := 126.0 if compact else 170.0 * layout_scale
	var row_height := 56.0 if compact else 76.0 * layout_scale
	var reset_height := 50.0 if compact else 64.0
	var reset := _settings_v6_make_action_button("Сбросить игровые настройки", "SettingsResetGameButton", 392.0, reset_height)
	_settings_fit_kit_row([reset], 392.0, reset_height, 48.0, 0.72)
	for row_index in range(rows.size()):
		var row_config: Dictionary = rows[row_index]
		var key := str(row_config["key"])
		var suffix := str(row_config["suffix"])
		var spec: Dictionary = game.GAMEPLAY_SANDBOX.SPECS[key]
		var row: Control = Control.new() if compact else HBoxContainer.new()
		row.name = "SettingsSandboxRow_%s" % suffix
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.custom_minimum_size = Vector2(842.0 if compact else 0.0, row_height)
		if not compact:
			(row as HBoxContainer).add_theme_constant_override("separation", int(roundf(16.0 * s)))
		content.add_child(row)
		if compact:
			var compact_row_y: float = float([142.0, 206.0, 278.0, 342.0, 406.0][row_index])
			_settings_game_place_control(row, Rect2(10.0, compact_row_y, 842.0, 56.0))
		else:
			var row_inset := Control.new()
			row_inset.name = "SettingsSandboxInset_%s" % suffix
			row_inset.custom_minimum_size.x = 16.0
			row_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(row_inset)

		var row_label := Label.new()
		row_label.name = "SettingsSandboxLabel_%s" % suffix
		row_label.text = str(row_config["label"])
		row_label.custom_minimum_size = Vector2(roundf(row_label_w), roundf(row_height))
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_FIELD,
			_settings_v6_font(SemanticTypography.ROLE_FIELD, 24.0, s),
			SemanticTypography.role_min(SemanticTypography.ROLE_FIELD),
			SemanticTypography.role_max(SemanticTypography.ROLE_FIELD)
		))
		row_label.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
		row.add_child(row_label)
		if compact:
			_settings_game_place_control(row_label, Rect2(16.0, 8.0, 310.0, 40.0))

		var slider := HSlider.new()
		slider.name = "SettingsSandboxSlider_%s" % suffix
		slider.min_value = float(spec["min"])
		slider.max_value = float(spec["max"])
		slider.step = float(spec["step"])
		slider.value = float(configured[key])
		slider.custom_minimum_size = Vector2(roundf(row_slider_w), roundf(40.0 if compact else 56.0 * layout_scale))
		slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
		_settings_v6_style_slider(slider, s)
		row.add_child(slider)
		if compact:
			_settings_game_place_control(slider, Rect2(342.0, 8.0, 346.0, 40.0))

		var chip := PanelContainer.new()
		chip.name = "SettingsSandboxValueChip_%s" % suffix
		chip.custom_minimum_size = Vector2(roundf(row_value_w), roundf(40.0 if compact else 56.0 * layout_scale))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_theme_stylebox_override("panel", _settings_v6_texture_box(
			SETTINGS_V6_VALUE_CHIP_PATH, Vector4(16.0, 14.0, 16.0, 14.0), Vector4(6.0 * s, 2.0 * s, 6.0 * s, 2.0 * s)))
		row.add_child(chip)
		if compact:
			_settings_game_place_control(chip, Rect2(702.0, 8.0, 126.0, 40.0))
		var value_label := Label.new()
		value_label.name = "SettingsSandboxValue_%s" % suffix
		value_label.text = "%.1f×" % slider.value
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_VALUE,
			_settings_v6_font(SemanticTypography.ROLE_VALUE, 22.0, s),
			SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
			SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
		))
		value_label.add_theme_color_override("font_color", SETTINGS_V6_AMBER)
		chip.add_child(value_label)
		sliders[key] = slider
		value_labels[key] = value_label
		slider_order.append(slider)

		slider.value_changed.connect(func(value: float) -> void:
			game.set_sandbox_multiplier(key, value, true)
			_refresh_settings_game_page(status, warning, reset, sliders, value_labels)
		)

	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.pressed.connect(func() -> void:
		game.reset_sandbox_settings(true)
		_refresh_settings_game_page(status, warning, reset, sliders, value_labels)
	)
	content.add_child(reset)
	if compact:
		# The semantic action font makes the textured button's measured minimum
		# three pixels taller than its authored 50px slot.  Lift the slot by that
		# exact amount so follow_focus reveals the complete focus plate at the
		# bottom scroll extent without entering the Atlas ornament below it.
		_settings_game_place_control(reset, Rect2(446.0, 467.0, 392.0, 50.0))
	_refresh_settings_game_page(status, warning, reset, sliders, value_labels)
	game_tab.set_meta("settings_game_sliders", slider_order)
	game_tab.set_meta("settings_game_reset", reset)
	return game_tab




func _settings_game_place_control(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size




func _wire_settings_game_focus(tabs: TabContainer, game_tab: Control, compact: bool) -> void:
	var tab_buttons: Array[Button] = []
	for tab_index in range(4):
		var button := tabs.get_parent().get_parent().get_parent().find_child("SettingsTabButton_%d" % tab_index, true, false) as Button
		if button != null:
			tab_buttons.append(button)
	if tab_buttons.size() != 4:
		return
	for tab_index in range(tab_buttons.size()):
		var current := tab_buttons[tab_index]
		if compact:
			var other_column := tab_index ^ 1
			var other_row := (tab_index + 2) % 4
			current.focus_neighbor_left = tab_buttons[other_column].get_path()
			current.focus_neighbor_right = tab_buttons[other_column].get_path()
			current.focus_neighbor_top = tab_buttons[other_row].get_path()
			current.focus_neighbor_bottom = tab_buttons[other_row].get_path()
		else:
			current.focus_neighbor_left = tab_buttons[(tab_index - 1 + 4) % 4].get_path()
			current.focus_neighbor_right = tab_buttons[(tab_index + 1) % 4].get_path()
			current.focus_neighbor_top = current.get_path()

	var sliders: Array = game_tab.get_meta("settings_game_sliders", [])
	var reset := game_tab.get_meta("settings_game_reset", null) as Button
	if sliders.size() != 5 or reset == null:
		return
	var first_slider := sliders[0] as HSlider
	var last_slider := sliders[sliders.size() - 1] as HSlider
	tab_buttons[3].focus_neighbor_bottom = first_slider.get_path()
	for slider_index in range(sliders.size()):
		var slider := sliders[slider_index] as HSlider
		slider.focus_neighbor_top = tab_buttons[3].get_path() if slider_index == 0 else (sliders[slider_index - 1] as HSlider).get_path()
		slider.focus_neighbor_bottom = reset.get_path() if slider_index == sliders.size() - 1 else (sliders[slider_index + 1] as HSlider).get_path()
	reset.focus_neighbor_top = last_slider.get_path()
	reset.focus_neighbor_bottom = tab_buttons[3].get_path()
	reset.focus_neighbor_left = reset.get_path()
	reset.focus_neighbor_right = reset.get_path()




func _refresh_settings_game_page(status: Label, warning: Label, reset: Button, sliders: Dictionary, value_labels: Dictionary) -> void:
	var snapshot: Dictionary = game.sandbox_snapshot()
	var neutral: bool = bool(game.sandbox_settings_are_neutral())
	status.text = "Обычный режим · 1.0×" if neutral else "Песочница активна"
	status.add_theme_color_override("font_color", Color(0.64, 0.86, 0.58, 1.0) if neutral else SETTINGS_V6_AMBER)
	warning.text = "Изменения применятся только к следующему забегу." if neutral else "Обычная прогрессия, достижения и release-balance evidence отключены."
	warning.add_theme_color_override("font_color", SETTINGS_V6_MUTED if neutral else Color(1.0, 0.68, 0.36, 1.0))
	if reset != null:
		reset.disabled = neutral
	for key in sliders:
		var slider := sliders[key] as HSlider
		var value_label := value_labels.get(key) as Label
		var value := float(snapshot.get(key, 1.0))
		if slider != null:
			slider.set_value_no_signal(value)
		if value_label != null:
			value_label.text = "%.1f×" % value




func _add_settings_control_row(parent: VBoxContainer, title: String, control: Control, s := 1.0) -> HBoxContainer:
	# v6: единая двухколоночная сетка label(380)|control — колонки выровнены по
	# всем вкладкам, контролы фиксированных размеров, ничего не тянется.
	var row := HBoxContainer.new()
	row.name = "SettingsRow_%s" % title.replace(" ", "_")
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", int(roundf(24.0 * s)))
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(roundf(SETTINGS_V6_LABEL_COL.x * s), roundf(SETTINGS_V6_LABEL_COL.y * s))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_FIELD,
		_settings_v6_font(SemanticTypography.ROLE_FIELD, 26.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_FIELD),
		SemanticTypography.role_max(SemanticTypography.ROLE_FIELD)
	))
	label.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row




func _add_controls_section_header(parent: VBoxContainer, title: String, s := 1.0) -> Label:
	# v6: заголовок секции в атласном золоте + латунная линия до правого края —
	# секции «Устройство/Клавиатура/Геймпад» читаются как главы одного свитка.
	var row := HBoxContainer.new()
	row.name = "SettingsSectionRow_%s" % title.replace(" ", "_")
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(roundf(18.0 * s)))
	parent.add_child(row)
	var header := Label.new()
	header.name = "SettingsSectionHeader_%s" % title.replace(" ", "_")
	header.text = title
	header.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_SECTION,
		_settings_v6_font(SemanticTypography.ROLE_SECTION, 28.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_SECTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_SECTION)
	))
	header.add_theme_color_override("font_color", SETTINGS_V6_GOLD)
	header.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	header.add_theme_constant_override("shadow_offset_x", maxi(1, int(roundf(1.5 * s))))
	header.add_theme_constant_override("shadow_offset_y", maxi(1, int(roundf(1.5 * s))))
	row.add_child(header)
	var line := ColorRect.new()
	line.color = SETTINGS_V6_BRONZE_LINE
	line.custom_minimum_size = Vector2(0.0, maxf(2.0, roundf(2.0 * s)))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	return header




func _add_volume_row(box: VBoxContainer, title: String, volume_key: String, enabled_key: String, s := 1.0) -> void:
	var row := HBoxContainer.new()
	row.name = "VolumeRow_%s" % volume_key
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", int(roundf(16.0 * s)))
	box.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(roundf(SETTINGS_V6_LABEL_COL.x * s), roundf(SETTINGS_V6_LABEL_COL.y * s))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_FIELD,
		_settings_v6_font(SemanticTypography.ROLE_FIELD, 26.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_FIELD),
		SemanticTypography.role_max(SemanticTypography.ROLE_FIELD)
	))
	label.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "VolumeSlider_%s" % volume_key
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 2.0
	# Высота 42×s — компактный sound-ряд (контракт SCRUM-674: ≤460×46).
	slider.custom_minimum_size = Vector2(roundf(420.0 * s), roundf(42.0 * s))
	slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	_settings_v6_style_slider(slider, s)
	slider.value = float(game.audio_settings.get(volume_key, 1.0)) * 100.0
	slider.value_changed.connect(func(value: float) -> void:
		game.audio_settings[volume_key] = value / 100.0
		game._apply_audio_settings()
		game.save_game_settings()
	)
	row.add_child(slider)

	var chip := PanelContainer.new()
	chip.name = "VolumeChip_%s" % volume_key
	chip.custom_minimum_size = Vector2(roundf(96.0 * s), roundf(48.0 * s))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _settings_v6_texture_box(
		SETTINGS_V6_VALUE_CHIP_PATH, Vector4(16.0, 14.0, 16.0, 14.0), Vector4(6.0 * s, 2.0 * s, 6.0 * s, 2.0 * s)))
	row.add_child(chip)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text = "%d%%" % int(slider.value)
	value_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_VALUE,
		_settings_v6_font(SemanticTypography.ROLE_VALUE, 24.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
		SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
	))
	value_label.add_theme_color_override("font_color", SETTINGS_V6_AMBER)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value)
	)
	chip.add_child(value_label)

	if enabled_key != "":
		var toggle := CheckBox.new()
		toggle.name = "VolumeToggle_%s" % enabled_key
		toggle.button_pressed = bool(game.audio_settings.get(enabled_key, true))
		toggle.text = "Вкл." if toggle.button_pressed else "Выкл."
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_settings_v6_style_checkbox(toggle, s)
		slider.editable = toggle.button_pressed
		toggle.toggled.connect(func(pressed: bool) -> void:
			game.audio_settings[enabled_key] = pressed
			toggle.text = "Вкл." if pressed else "Выкл."
			slider.editable = pressed
			game._apply_audio_settings()
			game.save_game_settings()
		)
		row.add_child(toggle)




func _add_audio_option_row(box: VBoxContainer, title: String, setting_key: String, s := 1.0) -> HBoxContainer:
	var toggle := CheckBox.new()
	toggle.name = "AudioToggle_%s" % setting_key
	toggle.button_pressed = bool(game.audio_settings.get(setting_key, game.GAME_SETTINGS.DEFAULTS.get(setting_key, false)))
	toggle.text = "Вкл." if toggle.button_pressed else "Выкл."
	toggle.tooltip_text = title
	_settings_v6_style_checkbox(toggle, s)
	toggle.toggled.connect(func(pressed: bool) -> void:
		game.audio_settings[setting_key] = pressed
		toggle.text = "Вкл." if pressed else "Выкл."
		game._apply_audio_settings()
		game.save_game_settings()
	)
	var row := _add_settings_control_row(box, title, toggle, s)
	row.name = "AudioOptionRow_%s" % setting_key
	return row




func _settings_v6_style_audio_scrollbar(scroll: ScrollContainer, s: float) -> void:
	var scrollbar := scroll.get_v_scroll_bar()
	if scrollbar == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.05, 0.04, 0.03, 0.85)
	track.set_corner_radius_all(int(roundf(4.0 * s)))
	track.set_content_margin_all(roundf(2.0 * s))
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.52, 0.41, 0.24, 0.95)
	grabber.set_corner_radius_all(int(roundf(4.0 * s)))
	var grabber_highlight: StyleBoxFlat = grabber.duplicate()
	grabber_highlight.bg_color = Color(0.78, 0.66, 0.44, 1.0)
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_highlight)




func _settings_v6_apply_field_theme(button: Button, s: float) -> void:
	UIButtonFamily.assign(button, UIButtonFamily.FAMILY_SETTINGS_FIELD)
	# Врезное поле 560×56×s: дропдауны и кнопки биндингов. Арт — 9-slice
	# источник 320×56 (углы 1:1, плоская середина тянется по ширине).
	button.custom_minimum_size = Vector2(roundf(SETTINGS_V6_CONTROL_SIZE.x * s), roundf(SETTINGS_V6_CONTROL_SIZE.y * s))
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_ACTION,
		_settings_v6_font(SemanticTypography.ROLE_ACTION, 24.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
	))
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v6: у арта поля декоративные наконечники ~52px + золотое кольцо капсулы
	# ~20px с каждого конца — текст держим строго в плоской зоне капсулы,
	# иначе края длинных опций ложатся на кольцо.
	var content := Vector4(76.0 * s, 6.0 * s, 76.0 * s, 6.0 * s)
	if button is OptionButton:
		# OptionButton резервирует справа зону стрелки (internal margin) и
		# центрирует текст в остатке — центр уезжает влево, длинные опции
		# ложатся на кольцо. Компенсируем слева (+20px к базе), справа держим
		# 76, чтобы стрелка осталась внутри капсулы; вместе с кеглем 22 у
		# самой длинной опции зазор до кольца ≥25px на 1080p/1440p.
		content = Vector4(96.0 * s, 6.0 * s, 76.0 * s, 6.0 * s)
		button.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_ACTION,
			_settings_v6_font(SemanticTypography.ROLE_ACTION, 22.0, s),
			SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
		))
	# Арт поля 560×56 — точный дизайн-размер контрола (без 9-slice растяжений).
	var source_margins := Vector4(12.0, 10.0, 12.0, 10.0)
	button.add_theme_stylebox_override("normal", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["normal"], source_margins, content))
	button.add_theme_stylebox_override("hover", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["hover"], source_margins, content))
	button.add_theme_stylebox_override("pressed", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["pressed"], source_margins, content))
	button.add_theme_stylebox_override("focus", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["hover"], source_margins, content))
	button.add_theme_stylebox_override("disabled", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["normal"], source_margins, content))
	button.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	button.add_theme_color_override("font_hover_color", SETTINGS_V6_TEXT_BRIGHT)
	button.add_theme_color_override("font_pressed_color", SETTINGS_V6_TEXT_BRIGHT)
	button.add_theme_color_override("font_focus_color", SETTINGS_V6_TEXT_BRIGHT)
	button.add_theme_color_override("font_disabled_color", SETTINGS_V6_DISABLED)
	if button is OptionButton:
		# 30px: меньший резерв стрелки оставляет длинным опциям запас от клипа.
		var arrow := _settings_v6_icon(SETTINGS_V6_ARROW_PATH, Vector2(30.0, 30.0), s)
		if arrow != null:
			button.add_theme_icon_override("arrow", arrow)
		var popup := (button as OptionButton).get_popup()
		popup.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_FIELD,
			_settings_v6_font(SemanticTypography.ROLE_FIELD, 24.0, s),
			SemanticTypography.role_min(SemanticTypography.ROLE_FIELD),
			SemanticTypography.role_max(SemanticTypography.ROLE_FIELD)
		))
		# v6: поп-ап как чип Атласа — тёмный фон, латунная кромка, скругление.
		var popup_style := StyleBoxFlat.new()
		popup_style.bg_color = SETTINGS_V6_POPUP_BG
		popup_style.border_color = Color(0.52, 0.41, 0.24, 0.90)
		popup_style.set_border_width_all(maxi(1, int(roundf(2.0 * s))))
		popup_style.set_corner_radius_all(int(roundf(10.0 * s)))
		popup_style.set_content_margin_all(roundf(10.0 * s))
		popup.add_theme_stylebox_override("panel", popup_style)
		var popup_hover := StyleBoxFlat.new()
		popup_hover.bg_color = Color(0.30, 0.23, 0.12, 0.85)
		popup_hover.set_corner_radius_all(int(roundf(8.0 * s)))
		popup.add_theme_stylebox_override("hover", popup_hover)
		popup.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
		popup.add_theme_color_override("font_hover_color", SETTINGS_V6_TEXT_BRIGHT)




func _settings_v6_make_action_button(text: String, button_name: String, width: float, height: float) -> Button:
	# SCRUM-879: кнопки-действия настроек — глобальный кит (Правило 2, как экран
	# «Атлас героев»): _make_button + _set_action_button_size. Имя ставим ДО
	# применения размера: маппинг текстур кита (_text_button_unique_id /
	# _button_asset_type) читает name+size. Прежние ui_settings_v6_btn_* стили
	# не используются; disabled-состояние (Apply) кит поддерживает.
	var button := _make_button(text)
	button.name = button_name
	_set_action_button_size(button, width, height)
	return button




func _settings_v6_style_checkbox(toggle: CheckBox, s: float) -> void:
	UIButtonFamily.assign(toggle, "settings_toggle")
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_ACTION,
		_settings_v6_font(SemanticTypography.ROLE_ACTION, 24.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
	))
	var unchecked := _settings_v6_icon(SETTINGS_V6_CHECKBOX_OFF_PATH, Vector2(52.0, 52.0), s)
	var checked := _settings_v6_icon(SETTINGS_V6_CHECKBOX_ON_PATH, Vector2(52.0, 52.0), s)
	if unchecked != null:
		toggle.add_theme_icon_override("unchecked", unchecked)
		toggle.add_theme_icon_override("unchecked_disabled", unchecked)
	if checked != null:
		toggle.add_theme_icon_override("checked", checked)
		toggle.add_theme_icon_override("checked_disabled", checked)
	toggle.add_theme_constant_override("h_separation", int(roundf(14.0 * s)))
	toggle.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	toggle.add_theme_color_override("font_hover_color", SETTINGS_V6_TEXT_BRIGHT)
	toggle.add_theme_color_override("font_pressed_color", SETTINGS_V6_TEXT_BRIGHT)
	# v6: видимое фокус-кольцо для геймпад-навигации (латунная рамка).
	var focus_ring := StyleBoxFlat.new()
	focus_ring.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus_ring.border_color = Color(0.78, 0.66, 0.44, 0.85)
	focus_ring.set_border_width_all(maxi(1, int(roundf(2.0 * s))))
	focus_ring.set_corner_radius_all(int(roundf(8.0 * s)))
	toggle.add_theme_stylebox_override("focus", focus_ring)




func _settings_v6_style_slider(slider: HSlider, s: float) -> void:
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var groove_h := maxf(8.0, 9.0 * s)
	var track := _settings_v6_texture_box(SETTINGS_V6_SLIDER_TRACK_PATH, Vector4(8.0, 5.0, 8.0, 5.0), Vector4.ZERO)
	if track is StyleBoxTexture:
		track.content_margin_top = groove_h
		track.content_margin_bottom = groove_h
	var fill := _settings_v6_texture_box(SETTINGS_V6_SLIDER_FILL_PATH, Vector4(6.0, 4.0, 6.0, 4.0), Vector4.ZERO)
	if fill is StyleBoxTexture:
		fill.content_margin_top = maxf(8.0, groove_h - 2.0 * s)
		fill.content_margin_bottom = maxf(8.0, groove_h - 2.0 * s)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_constant_override("center_grabber", 1)
	var gem := _settings_v6_icon(SETTINGS_V6_SLIDER_GEM_PATH, Vector2(36.0, 36.0), s)
	if gem != null:
		slider.add_theme_icon_override("grabber", gem)
		slider.add_theme_icon_override("grabber_disabled", gem)
	# v6: под фокусом/hover гем чуть крупнее — заметно с геймпада.
	var gem_focus := _settings_v6_icon(SETTINGS_V6_SLIDER_GEM_PATH, Vector2(40.0, 40.0), s)
	if gem_focus != null:
		slider.add_theme_icon_override("grabber_highlight", gem_focus)




func _reset_audio_to_defaults() -> void:
	for key in [
		"master_volume", "music_volume", "sfx_volume", "ui_volume",
		"music_enabled", "sfx_enabled", "mute_when_unfocused", "low_hp_warning_enabled",
	]:
		game.audio_settings[key] = game.GAME_SETTINGS.DEFAULTS[key]
	game.audio_settings["master_zero_intent"] = false
	game._apply_audio_settings()
	game.save_game_settings()
