extends "res://scripts/ui/screens/ui_screens_shared_api.gd"

# FAN-3824: модуль распределённого UI-класса — общий кит стилей: кнопки, панели, рамки, карточки, тултипы.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = _action_button_size()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button_control(button)
	return button




# SCRUM-968: единая озвучка кнопок (спека §3) — общая обёртка вокруг
# pressed.connect. kind "click" (подтверждение/переход) → ui_click, "back"
# (назад/отмена/закрытие экрана) → ui_back. Троттлинг-группа ui уже настроена
# в AudioManager (ui_click/ui_back дефолт 0.05 c) — спам исключён. Подключается
# как звук-компаньон рядом со штатным навигационным обработчиком кнопки; в
# headless _play_sfx — полный no-op.
func _connect_ui_sfx(button: BaseButton, kind := "click") -> void:
	if button == null or not is_instance_valid(button):
		return
	var sfx := "ui_back" if kind == "back" else "ui_click"
	button.pressed.connect(func() -> void:
		game._play_sfx(sfx)
	)




func _readable_font_size(role: StringName, base_size: int, min_size := 0, max_size := 96) -> int:
	var viewport_height := 864.0
	if game != null and game.get_viewport() != null:
		viewport_height = game.get_viewport().get_visible_rect().size.y
	return SemanticTypography.resolve_authored_compat(
		role, base_size, viewport_height, min_size, max_size
	)




func _make_compact_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = COMPACT_UTILITY_BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 18))
	_apply_compact_button_theme(button)
	return button




func _action_button_size(width := STANDARD_ACTION_BUTTON_WIDTH) -> Vector2:
	return Vector2(minf(width, MAX_ACTION_BUTTON_VISUAL_WIDTH), STANDARD_ACTION_BUTTON_HEIGHT)




func _set_action_button_size(button: Button, width := STANDARD_ACTION_BUTTON_WIDTH, height := STANDARD_ACTION_BUTTON_HEIGHT) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(minf(width, MAX_ACTION_BUTTON_VISUAL_WIDTH), height)
	_apply_fantasy_button_theme(button)




func _style_button_control(button: Button) -> void:
	_apply_fantasy_button_theme(button)
	button.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 16))




func _apply_fantasy_button_theme(button: Button, variant := "default", explicit_family := "") -> void:
	var role := _button_role(button, variant)
	UIButtonFamily.resolve(button, variant, explicit_family)
	button.add_theme_stylebox_override("normal", _button_state_style(button, role, "normal"))
	button.add_theme_stylebox_override("hover", _button_state_style(button, role, "hover"))
	button.add_theme_stylebox_override("pressed", _button_state_style(button, role, "pressed"))
	button.add_theme_stylebox_override("disabled", _button_state_style(button, role, "disabled"))
	button.add_theme_stylebox_override("focus", _button_state_style(button, role, "focus"))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))




func _level_up_return_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.035, 0.025, 1.0)
	style.border_color = Color(0.96, 0.72, 0.24, 1.0)
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.content_margin_left = 24
	style.content_margin_top = 14
	style.content_margin_right = 24
	style.content_margin_bottom = 14
	return style




func _button_role(button: Button, variant := "default") -> String:
	if variant == "danger":
		return "danger"
	if variant in ["reward", "level_up", "primary"]:
		return "primary"
	var text := button.text.to_lower()
	if text.contains("выйти") or text.contains("покинуть") or text.contains("смерть") or text.contains("поражение"):
		return "danger"
	if text.contains("начать") or text.contains("выбрать") or text.contains("купить") or text.contains("получить") or text.contains("продолжить"):
		return "primary"
	return "secondary"




func _button_asset_type(button: Button, variant := "default") -> String:
	return UIButtonFamily.minimal_family_type(button, variant)




func _button_state_style(button: Button, _role: String, state: String, tint := Color.WHITE) -> StyleBox:
	# SCRUM-847: legacy-маршрут settings-узлов (v3/v4 tint-стили) удалён — экран
	# настроек v6 стилизует свои контролы явно (_settings_v6_*), сюда не попадает.
	var family := str(button.get_meta(UIButtonFamily.META_FAMILY, ""))
	if family == "":
		family = UIButtonFamily.resolve(button)
	if family == "combat_level_up_plus":
		var plus_state := state
		if plus_state == "focus":
			plus_state = "hover"
		var plus_path := str(COMBAT_HUD_LEVEL_UP_BUTTON_TEXTURES.get(plus_state, COMBAT_HUD_LEVEL_UP_BUTTON_TEXTURES["normal"]))
		var plus_tint := BUTTON_NEUTRAL_HOVER_TINT if state == "hover" and tint == Color.WHITE else tint
		return _global_texture_style(plus_path, COMBAT_HUD_LEVEL_UP_MARGINS, plus_tint, COMBAT_HUD_LEVEL_UP_CONTENT)
	var texture_state := state if UIButtonFamily.STATES.has(state) else "normal"
	var descriptor := UIButtonFamily.descriptor_for_size(family, texture_state, button.custom_minimum_size)
	if descriptor.is_empty():
		return _global_texture_style(GLOBAL_BUTTON_FRAME_PATH, Vector4(50, 28, 50, 28), tint, Vector4(64, 32, 64, 32))
	var final_tint := tint
	if texture_state == "hover" and tint == Color.WHITE:
		final_tint = BUTTON_HOVER_EXTRA_TINT
	return _global_texture_style(str(descriptor["path"]), descriptor["margins"], final_tint, descriptor["content"])




func _text_button_unique_id(button: Button) -> String:
	return UIButtonFamily.text_family_id(button)




func _apply_compact_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_state_style(button, "secondary", "normal"))
	button.add_theme_stylebox_override("hover", _button_state_style(button, "secondary", "hover"))
	button.add_theme_stylebox_override("pressed", _button_state_style(button, "secondary", "pressed"))
	button.add_theme_stylebox_override("focus", _button_state_style(button, "secondary", "focus"))
	button.add_theme_stylebox_override("disabled", _button_state_style(button, "secondary", "disabled"))
	button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.80, 1.0, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))




func _level_up_text_field_style(hovered := false, rare := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.060, 0.050, 0.88) if rare else Color(0.052, 0.058, 0.074, 0.86)
	style.border_color = Color(0.92, 0.72, 0.28, 0.98) if rare else Color(0.46, 0.52, 0.58, 0.82)
	if hovered:
		style.bg_color = Color(0.095, 0.080, 0.052, 0.94) if rare else Color(0.075, 0.082, 0.098, 0.94)
		style.border_color = Color(1.0, 0.84, 0.34, 1.0) if rare else Color(0.72, 0.82, 0.90, 0.94)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.12)
	if disabled:
		style.bg_color = Color(0.04, 0.045, 0.055, 0.56)
		style.border_color = Color(0.25, 0.25, 0.27, 0.70)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2 if rare else 1)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style




func _panel_style() -> StyleBox:
	return _minimal_frame_style("panel")




func _level_up_panel_style() -> StyleBox:
	return _minimal_frame_style("panel", Color(1.06, 1.03, 1.08, 1.0))




func _card_hover_style() -> StyleBox:
	return _minimal_frame_style("card", BUTTON_NEUTRAL_HOVER_TINT)




func _character_card_style() -> StyleBox:
	return _minimal_frame_style("card")




func _is_economy_screen_background(screen_background_id: String) -> bool:
	return ["campfire", "upgrade", "event"].has(screen_background_id)




func _is_pause_end_screen_background(screen_background_id: String) -> bool:
	return ["pause", "victory", "death"].has(screen_background_id)




func _is_result_screen_background(screen_background_id: String) -> bool:
	return ["victory", "death"].has(screen_background_id)




func _pause_end_modal_display_size(screen_background_id: String) -> Vector2:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	return _pause_end_modal_display_size_for_viewport(screen_background_id, viewport_size)




func _pause_end_modal_display_size_for_viewport(screen_background_id: String, viewport_size: Vector2) -> Vector2:
	var max_width := viewport_size.x * 0.84
	var max_height := viewport_size.y * 0.90
	if screen_background_id == "victory" or screen_background_id == "death":
		var safe_size := _unified_safe_rect_for_size(viewport_size).size
		max_width = minf(viewport_size.x * 0.82, maxf(1.0, safe_size.x - 48.0))
		max_height = minf(viewport_size.y * 0.88, maxf(1.0, safe_size.y - 40.0))
	var source_aspect := PAUSE_END_MODAL_SOURCE_SIZE.x / PAUSE_END_MODAL_SOURCE_SIZE.y
	var height := minf(max_height, max_width / source_aspect)
	var minimum_height := minf(520.0, max_height)
	height = clampf(height, minimum_height, 820.0)
	var width := height * source_aspect
	if width > max_width:
		width = max_width
		height = width / source_aspect
	return Vector2(roundf(width), roundf(height))




func _pause_end_modal_content_margins(display_size: Vector2, screen_background_id: String) -> Vector4:
	# SCRUM-883: у результ-чипа контент держат симметричные чип-пэддинги.
	if _is_result_screen_background(screen_background_id):
		return _atlas_chip_content_margins(RESULT_MODAL_CHIP_PAD)
	return _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_CONTENT)




func _pause_end_modal_content_rect(display_size: Vector2, screen_background_id: String) -> Rect2:
	var margins := _pause_end_modal_content_margins(display_size, screen_background_id)
	return Rect2(
		Vector2(margins.x, margins.y),
		Vector2(maxf(1.0, display_size.x - margins.x - margins.z), maxf(1.0, display_size.y - margins.y - margins.w))
	)




func _economy_menu_panel_half_size(screen_background_id: String) -> Vector2:
	var target_size := Vector2(1120.0, 660.0)
	match screen_background_id:
		"event":
			target_size = Vector2(1720.0, 780.0)
		"upgrade":
			target_size = Vector2(1720.0, 730.0)
		"campfire":
			target_size = Vector2(1180.0, 716.0)
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var max_size := Vector2(maxf(520.0, viewport_size.x), maxf(420.0, viewport_size.y - 48.0))
	target_size.x = minf(target_size.x, max_size.x)
	target_size.y = minf(target_size.y, max_size.y)
	return target_size * 0.5




func _scaled_frame_margins(source_size: Vector2, display_size: Vector2, source_margins: Vector4) -> Vector4:
	var scale := minf(display_size.x / source_size.x, display_size.y / source_size.y)
	return Vector4(
		roundf(source_margins.x * scale),
		roundf(source_margins.y * scale),
		roundf(source_margins.z * scale),
		roundf(source_margins.w * scale)
	)




func _scaled_frame_margins_xy(source_size: Vector2, display_size: Vector2, source_margins: Vector4) -> Vector4:
	var scale_x := display_size.x / maxf(source_size.x, 1.0)
	var scale_y := display_size.y / maxf(source_size.y, 1.0)
	return Vector4(
		roundf(source_margins.x * scale_x),
		roundf(source_margins.y * scale_y),
		roundf(source_margins.z * scale_x),
		roundf(source_margins.w * scale_y)
	)




func _level_up_scaled_position(rect: Rect2, scale: Vector2) -> Vector2:
	return Vector2(roundf(rect.position.x * scale.x), roundf(rect.position.y * scale.y))




func _level_up_scaled_size(rect: Rect2, scale: Vector2) -> Vector2:
	return Vector2(roundf(rect.size.x * scale.x), roundf(rect.size.y * scale.y))




func _minimal_frame_style(frame_type: String, tint := Color.WHITE) -> StyleBox:
	var path_map := {
		"modal": MINIMAL_MODAL_PATH,
		"panel": MINIMAL_PANEL_PATH,
		"card": MINIMAL_CARD_PATH,
		"tooltip": MINIMAL_TOOLTIP_PATH,
		"hud_strip": MINIMAL_HUD_STRIP_PATH,
		"field": MINIMAL_FIELD_PATH,
	}
	var key := frame_type if path_map.has(frame_type) else "panel"
	var margins: Vector4 = MINIMAL_FRAME_TEXTURE_MARGINS.get(key, MINIMAL_FRAME_TEXTURE_MARGINS["panel"])
	var content: Vector4 = MINIMAL_FRAME_CONTENT.get(key, MINIMAL_FRAME_CONTENT["panel"])
	return _global_texture_style(str(path_map[key]), margins, tint, content, true)




func _minimal_metal_frame_style(frame_type: String, tint := Color.WHITE) -> StyleBox:
	var key := frame_type if MINIMAL_METAL_FRAME_PATHS.has(frame_type) else "panel"
	var margins: Vector4 = MINIMAL_METAL_FRAME_TEXTURE_MARGINS.get(key, MINIMAL_METAL_FRAME_TEXTURE_MARGINS["panel"])
	var content: Vector4 = MINIMAL_METAL_FRAME_CONTENT.get(key, MINIMAL_METAL_FRAME_CONTENT["panel"])
	return _global_texture_style(str(MINIMAL_METAL_FRAME_PATHS[key]), margins, tint, content, true)




# SCRUM-486: построить StyleBoxTexture для @2K-слота блока Меню/Навигация. Ассет нарисован
# РОВНО в свой пиксельный размер (OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]); 9-slice-бордюры
# масштабируются от source→display (на 2K display==source, на 1080p/4K — uniform-скейл
# вьюпорта), поэтому орнамент держится в margin-band, а тянется только плоская середина.
# tile_edges=false: бордюры стретчатся по margins (как в minimal_metal panel-стиле), не тайлятся
# — для гладкого градиента, без STRETCH_SCALE на самой текстуре (верификатор SCRUM-483 чист).
func _overhaul_2k_frame_style(slot: String, display_size: Vector2, tint := Color.WHITE) -> StyleBox:
	if not OVERHAUL_2K_FRAME_PATHS.has(slot):
		return _minimal_metal_frame_style("panel", tint)
	var source_size: Vector2 = OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]
	var base_margins: Vector4 = OVERHAUL_2K_FRAME_TEXTURE_MARGINS[slot]
	var base_content: Vector4 = OVERHAUL_2K_FRAME_CONTENT.get(slot, Vector4.ZERO)
	var texture_margins := _scaled_frame_margins_xy(source_size, display_size, base_margins)
	var content_margins := _scaled_frame_margins_xy(source_size, display_size, base_content)
	return _global_texture_style(str(OVERHAUL_2K_FRAME_PATHS[slot]), texture_margins, tint, content_margins, false)




# SCRUM-684: Фикс-margins styling для Dark Fantasy pixel-art кодекса. Без
# масштабирования по display_size — texture_margins берутся РОВНО в пикселях
# источника, иначе 9-slice пересекает орнамент малых текстур.
# Pixel-art иконки/портреты кодекса масштабируются вьюпортом — рендерим nearest,
# чтобы не было блюра (дефолт проекта = linear).
func _codex_pl_make_nearest(node: CanvasItem) -> void:
	if node != null:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST




func _overhaul_2k_content_margins(slot: String, display_size: Vector2) -> Vector4:
	if not OVERHAUL_2K_FRAME_SOURCE_SIZE.has(slot):
		return Vector4.ZERO
	var source_size: Vector2 = OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]
	var base_content: Vector4 = OVERHAUL_2K_FRAME_CONTENT.get(slot, Vector4.ZERO)
	return _scaled_frame_margins_xy(source_size, display_size, base_content)




func _apply_overhaul_2k_button_theme(button: Button, slot: String, display_size: Vector2) -> void:
	if slot == "cr_btn" and _text_button_unique_id(button) != "":
		_apply_fantasy_button_theme(button)
		return
	UIButtonFamily.assign(button, "overhaul_2k/%s" % slot)
	button.add_theme_stylebox_override("normal", _overhaul_2k_frame_style(slot, display_size))
	button.add_theme_stylebox_override("hover", _overhaul_2k_frame_style(slot, display_size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("focus", _overhaul_2k_frame_style(slot, display_size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("pressed", _overhaul_2k_frame_style(slot, display_size, Color(0.90, 0.84, 0.76, 1.0)))
	button.add_theme_stylebox_override("disabled", _overhaul_2k_frame_style(slot, display_size, Color(0.58, 0.58, 0.58, 0.82)))
	button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.80, 1.0, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))




# SCRUM-883: панели экономических экранов маршрута (костёр и фолбэк) — чип Атласа.
func _economy_panel_style() -> StyleBox:
	return _atlas_chip_style(0.94, 18.0)




# SCRUM-883: Событие в едином атлас-стиле. Панель — atlas-чип (MenuPanel_event),
# контент раскладывается от ФАКТИЧЕСКИХ content-margins чипа (не от source-зон
# @2K-рамки); титул золотом 30/36, стори — читаемое тело 16+ с autowrap.
# SCRUM-997: метрики зон иллюстрированного event-диалога — единственный источник
# геометрии экрана события (спека docs/design/mockups/scrum997_event_dialog/spec.md §1-2):
# диалог-панель СПРАВА (~36% ширины, от верха safe-зоны до верха нижнего ряда),
# нижняя полоса (~22% высоты) = ряд из 3 карточек + плита «Назад» 260×action-height
# у правого края. Все значения — от фактического viewport (матрица 1152×648…3840×2160).
func _event_dialog_metrics() -> Dictionary:
	var vp := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		vp = game.get_viewport().get_visible_rect().size
	var m := roundf(clampf(vp.y * 0.025, 12.0, 36.0))
	# Four in-band semantic lanes need 176px on compact tiers. The extra height
	# grows upward from the bottom safe strip and leaves the dialogue panel above
	# it disjoint; no content enters the viewport/frame rail.
	var bottom_h := roundf(clampf(vp.y * 0.22, 176.0, 320.0))
	var row_top := vp.y - m - bottom_h
	var gap := roundf(clampf(vp.x * 0.012, 10.0, 32.0))
	var gap_v := roundf(clampf(vp.y * 0.016, 8.0, 24.0))
	var panel_w := roundf(clampf(vp.x * 0.36, 330.0, 980.0))
	var pad := roundf(clampf(vp.y * 0.018, 12.0, 26.0))
	var back_w := 260.0
	var back_h := _atlas_action_button_height()
	var card_w := floorf((vp.x - 2.0 * m - back_w - 3.0 * gap) / 3.0)
	return {
		"vp": vp,
		"margin": m,
		"gap": gap,
		"panel_pad": pad,
		"panel_rect": Rect2(vp.x - m - panel_w, m, panel_w, row_top - gap_v - m),
		"row_rect": Rect2(m, row_top, card_w * 3.0 + gap * 2.0, bottom_h),
		"card_size": Vector2(card_w, bottom_h),
		"back_rect": Rect2(vp.x - m - back_w, row_top + roundf((bottom_h - back_h) * 0.5), back_w, back_h),
	}




# SCRUM-997: титул события — autowrap по словам, но шрифт ужимается так, чтобы
# самое ДЛИННОЕ слово гарантированно влезало в контент-ширину панели (иначе
# WORD_SMART рвёт слово посреди: «жертвоприношени/й»). Мерка внешняя +
# жёсткий запас fit_ratio 0.62 — как _shrink_label_font_to_width (оконный
# рендер строки до ~1.5x шире Font.get_string_size, память проекта).
func _shrink_event_title_font(title_label: Label, base_font_size: int, max_width: float) -> void:
	if title_label == null:
		return
	var longest := ""
	for word in title_label.text.split(" ", false):
		if word.length() > longest.length():
			longest = word
	if longest == "":
		longest = title_label.text
	var font: Font = title_label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := base_font_size
	if font != null:
		var fit_width := maxf(max_width, 8.0) * 0.62
		while font_size > 18 and font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > fit_width:
			font_size -= 1
	title_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		font_size,
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))




# SCRUM-997: корень экрана события (EventScreen) от контент-бокса: box → scroll →
# MenuPanel_event → root. Null-safe для ранних вызовов/деградаций.
func _event_screen_root(box: VBoxContainer) -> Control:
	if box == null or not is_instance_valid(box):
		return null
	var scroll := box.get_parent()
	if scroll == null:
		return null
	var panel := scroll.get_parent()
	if panel == null:
		return null
	return panel.get_parent() as Control




func _configure_event_menu_layout(box: VBoxContainer) -> void:
	if box == null:
		return
	# SCRUM-997: диалог-панель СПРАВА (спека §2) вместо центральной economy-панели:
	# ручной rect (якоря 0/0), панель не перекрывает иллюстрацию слева.
	var metrics := _event_dialog_metrics()
	var panel_rect: Rect2 = metrics["panel_rect"]
	var pad: float = metrics["panel_pad"]
	var scroll := box.get_parent() as ScrollContainer
	var panel: PanelContainer = null
	if scroll != null:
		panel = scroll.get_parent() as PanelContainer
	if panel != null:
		panel.anchor_left = 0.0
		panel.anchor_top = 0.0
		panel.anchor_right = 0.0
		panel.anchor_bottom = 0.0
		panel.offset_left = panel_rect.position.x
		panel.offset_top = panel_rect.position.y
		panel.offset_right = panel_rect.end.x
		panel.offset_bottom = panel_rect.end.y
	# Контент-зона чипа: по X pad·1.4 (см. _atlas_chip_style), по Y pad.
	var content_size := Vector2(
		maxf(240.0, panel_rect.size.x - pad * 2.8),
		maxf(180.0, panel_rect.size.y - pad * 2.0)
	)
	var compact := (metrics["vp"] as Vector2).y < 760.0
	box.name = "EventContent"
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	# Ширина минус запас на вертикальный скроллбар: длинный story скроллится,
	# не распирая панель (канон: фикс-зону держат ручные rect'ы, не min-size лейблов).
	box.custom_minimum_size = Vector2(content_size.x - 14.0, 0.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10 if compact else 14)
	if scroll != null:
		scroll.follow_focus = false
		scroll.scroll_vertical = 0
		scroll.custom_minimum_size = content_size
	var title_label := box.find_child("MenuTitle_event", false, false) as Label
	if title_label != null:
		title_label.name = "EventTitle"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.custom_minimum_size = Vector2(content_size.x - 14.0, 0.0)
		title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
		# Длинные слова («жертвоприношений») не должны рваться посреди строки:
		# ужимаем шрифт под самое длинное слово (канон fit_ratio 0.62 — оконный
		# рендер строк шире мерки, память проекта), autowrap доносит остальное.
		_shrink_event_title_font(title_label, _readable_font_size(SemanticTypography.ROLE_TITLE, 30 if compact else 34, 0, 44), content_size.x - 14.0)
		# Латунная отчёркивающая линия под титулом (спека §2).
		if box.find_child("EventTitleRule", false, false) == null:
			var rule := ColorRect.new()
			rule.name = "EventTitleRule"
			rule.color = Color(0.52, 0.41, 0.24, 0.90)
			rule.custom_minimum_size = Vector2(0.0, 2.0)
			rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(rule)
			box.move_child(rule, title_label.get_index() + 1)
	var story_label := box.find_child("MenuSubtitle_event", false, false) as Label
	if story_label != null:
		story_label.name = "EventStory"
		story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		story_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story_label.custom_minimum_size = Vector2(content_size.x - 14.0, 0.0)
		story_label.size_flags_vertical = Control.SIZE_FILL
		story_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 16 if compact else 17, 13, 22))
		story_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))




# SCRUM-565/568 → SCRUM-883: чип-карточка держит контент собственными симметричными
# пэддингами — переинсет под content-зону текстурной рамки больше не нужен. Хелпер
# сохранён идемпотентной переустановкой чип-маржин (его зовёт экран события).
func _reinset_overhaul_choice_content(button: Button, _slot: String, _display_size: Vector2) -> void:
	if button == null:
		return
	var content := button.find_child("%sContent" % button.name, true, false) as Control
	if content == null:
		return
	var margins: Vector4 = button.get_meta("economy_content_margins", Vector4.ZERO)
	if margins == Vector4.ZERO:
		return
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w




# SCRUM-565/568 → SCRUM-883: карточки выбора больше не переодеваются в текстурные
# @2K-рамки — единый чип-язык Атласа. Сигнатура и точки вызова сохранены (экран
# события зовёт хелпер со слотом; слот игнорируется).
func _apply_overhaul_choice_2k_theme(button: Button, _slot: String, display_size: Vector2) -> void:
	if button == null:
		return
	_apply_atlas_choice_card_theme(button, _atlas_card_pad(display_size))




# SCRUM-883: карточка награды = кожаный чип-ряд атласа (база — _unified_apply_
# row_theme) с поднятой плотностью поверх замороженного боя: normal 0.88,
# hover/focus — золотой кант ярче, pressed — толстый золотой борт (селект).
func _apply_level_up_card_atlas_theme(button: Button, display_size: Vector2, is_rare := false) -> void:
	# SCRUM-892: пэддинг чипа — от ШИРИНЫ карточки (высота теперь контентная,
	# завязка на неё зациклила бы план стека).
	var pad := maxf(6.0, roundf(LU_CARD_CHIP_PAD_2K * display_size.x / LU_CARD_2K.size.x))
	_unified_apply_row_theme(button, pad)
	UIButtonFamily.assign(button, UIButtonFamily.FAMILY_LEVEL_UP_CARD)
	var normal := _atlas_chip_style(0.88, pad)
	if is_rare:
		normal.border_color = Color(0.80, 0.62, 0.30, 0.95)
	var hover := _atlas_chip_style(0.92, pad)
	hover.border_color = Color(0.93, 0.77, 0.40, 0.95)
	var focus := _atlas_chip_style(0.90, pad)
	focus.border_color = Color(0.93, 0.77, 0.40, 0.95)
	var pressed := _atlas_chip_style(0.96, pad)
	pressed.border_color = Color(0.98, 0.84, 0.46, 1.0)
	pressed.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", pressed)
	var content_margins := Vector4(
		normal.content_margin_left,
		normal.content_margin_top,
		normal.content_margin_right,
		normal.content_margin_bottom
	)
	button.set_meta("level_up_card_slot", "level_up_card")
	button.set_meta("level_up_card_content_margins", content_margins)
	button.set_meta("level_up_card_content_rect", Rect2(
		content_margins.x,
		content_margins.y,
		display_size.x - content_margins.x - content_margins.z,
		display_size.y - content_margins.y - content_margins.w
	))




func _pause_end_modal_style(display_size: Vector2, screen_background_id := "") -> StyleBox:
	# SCRUM-883: итоги забега (Победа/Поражение) — модалка-чип Атласа 0.96 вместо
	# текстурных рам (result_panel @2K у смерти, minimal-modal у победы). Пауза —
	# чужая зона: остаётся на общем PAUSE_END_MODAL_PATH.
	if _is_result_screen_background(screen_background_id):
		return _atlas_chip_style(0.96, RESULT_MODAL_CHIP_PAD)
	var texture_margins := _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_TEXTURE_MARGINS)
	var content_margins := _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_CONTENT)
	return _global_texture_style(PAUSE_END_MODAL_PATH, texture_margins, Color.WHITE, content_margins, true)




# SCRUM-883: чип-пэддинг карточек наград/экономики от высоты слота (симметрия с
# _atlas_chip_style: по X пад расширяется 1.4x внутри самого стиля).
func _atlas_card_pad(display_size: Vector2) -> float:
	return roundf(clampf(display_size.y * 0.10, 18.0, 34.0))




func _atlas_chip_content_margins(pad: float) -> Vector4:
	return Vector4(pad * 1.4, pad, pad * 1.4, pad)




# SCRUM-883: контентные карточки-ряды (награда за бой, артефакты элитки/босса,
# экономика маршрута, докачка, события) — единый чип-язык Атласа поверх
# _unified_apply_row_theme: normal — плотный чип 0.86, hover/focus/pressed —
# золотой кант; disabled сохраняет силуэт чипа (дим — модуляцией карточки).
# Никаких текстурных рамок и растяжек (Правило 1/2 SCRUM-879).
func _apply_atlas_choice_card_theme(button: Button, pad: float) -> void:
	_unified_apply_row_theme(button, pad)
	UIButtonFamily.assign(button, UIButtonFamily.FAMILY_CHOICE_CARD)
	button.add_theme_stylebox_override("normal", _atlas_chip_style(0.86, pad))
	var hover := _atlas_chip_style(0.90, pad)
	hover.border_color = Color(0.93, 0.77, 0.40, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := _atlas_chip_style(0.94, pad)
	pressed.bg_color = Color(0.11, 0.09, 0.07, 0.94)
	pressed.border_color = Color(0.93, 0.77, 0.40, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := _atlas_chip_style(0.90, pad)
	focus.border_color = Color(0.93, 0.77, 0.40, 0.95)
	button.add_theme_stylebox_override("focus", focus)
	var disabled := _atlas_chip_style(0.80, pad)
	disabled.border_color = Color(0.36, 0.32, 0.26, 0.70)
	button.add_theme_stylebox_override("disabled", disabled)
	button.set_meta("economy_card_style", "atlas_chip")
	button.set_meta("economy_card_pad", pad)




func _economy_choice_display_size(cards_in_row := 3) -> Vector2:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	if cards_in_row <= 2:
		if viewport_size.x >= 1920.0 and viewport_size.y >= 1000.0:
			return ECONOMY_CHOICE_TARGET_1440
		return ECONOMY_CHOICE_TARGET_1080
	if viewport_size.x < 1280.0:
		return Vector2(320.0, 240.0)
	if viewport_size.x >= 2400.0 and viewport_size.y >= 1200.0:
		return ECONOMY_CHOICE_TARGET_1440
	if viewport_size.x >= 1800.0 and viewport_size.y >= 900.0:
		return ECONOMY_CHOICE_TARGET_1080
	return ECONOMY_CHOICE_TARGET_720




func _gold_shell_economy_choice_display_size(cards_in_row: int) -> Vector2:
	return _gold_shell_economy_choice_display_size_for_viewport(cards_in_row, game.get_viewport().get_visible_rect().size)




func _gold_shell_economy_choice_display_size_for_viewport(cards_in_row: int, viewport_size: Vector2) -> Vector2:
	if viewport_size.y < 800.0:
		return Vector2(390.0, 150.0) if cards_in_row <= 2 else Vector2(280.0, 180.0)
	if viewport_size.y < 1000.0:
		return Vector2(390.0, 200.0) if cards_in_row <= 2 else Vector2(320.0, 220.0)
	if cards_in_row <= 2:
		return ECONOMY_CHOICE_TARGET_1440 if viewport_size.x >= 1920.0 and viewport_size.y >= 1000.0 else ECONOMY_CHOICE_TARGET_1080
	if viewport_size.x >= 2400.0 and viewport_size.y >= 1200.0:
		return ECONOMY_CHOICE_TARGET_1440
	if viewport_size.x >= 1800.0 and viewport_size.y >= 900.0:
		return ECONOMY_CHOICE_TARGET_1080
	return ECONOMY_CHOICE_TARGET_720




func _economy_attribute_choice_display_size() -> Vector2:
	var size := _economy_choice_display_size(3)
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	if viewport_size.y <= 660.0:
		return Vector2(maxf(size.x, 320.0), 240.0)
	if size.y < 280.0:
		size.y = 280.0
	return size




func _economy_choice_row_gap(display_size: Vector2) -> int:
	if display_size.x >= ECONOMY_CHOICE_TARGET_1440.x:
		return 48
	if display_size.x >= ECONOMY_CHOICE_TARGET_1080.x:
		return 36
	if display_size.x < ECONOMY_CHOICE_TARGET_720.x:
		return 20
	return 24




func _make_economy_choice_row(row_name: String, display_size := Vector2.ZERO, cards_in_row := 3) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var resolved_size := _economy_choice_display_size(cards_in_row) if display_size == Vector2.ZERO else display_size
	var gap := _economy_choice_row_gap(resolved_size)
	row.custom_minimum_size.x = resolved_size.x * float(cards_in_row) + float(gap * maxi(cards_in_row - 1, 0))
	row.add_theme_constant_override("separation", gap)
	return row




func _make_economy_choice_card(title: String, description: String, action_text: String, button_name: String, display_size: Vector2) -> Button:
	var button := Button.new()
	button.name = button_name if button_name != "" else "EconomyChoiceCard"
	var compact_attribute := button.name.begins_with("AttributeOffer_")
	button.set_meta("economy_frame_kind", "choice_card")
	button.set_meta("economy_display_size", display_size)
	button.set_meta("gold_shell_compact", display_size.y < ECONOMY_CHOICE_TARGET_720.y)
	button.text = ""
	button.custom_minimum_size = display_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [title, description]
	# SCRUM-883: карточка выбора — чип-ряд Атласа (StyleBoxFlat), контент держат
	# симметричные чип-пэддинги вместо content-зоны текстурной рамки.
	var card_pad := _atlas_card_pad(display_size)
	_apply_atlas_choice_card_theme(button, card_pad)

	var margins := _atlas_chip_content_margins(card_pad)
	button.set_meta("economy_content_margins", margins)
	var content := VBoxContainer.new()
	content.name = "%sContent" % button.name
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 3 if compact_attribute else 7)
	button.add_child(content)

	var title_label := Label.new()
	title_label.name = "%sTitle" % button.name
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		_readable_font_size(SemanticTypography.ROLE_TITLE, 14 if compact_attribute else 17, 12, 24),
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "%sDescription" % button.name
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 11 if compact_attribute else 13, 12, 20))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(desc_label)

	var action_label := Label.new()
	action_label.name = "%sAction" % button.name
	action_label.text = action_text
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 12 if compact_attribute else 15, 12, 22))
	action_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(action_label)

	# SCRUM-808: длинное описание продавливало VBox за safe-зону фрейма (флаки матрицы
	# на 1536×864 в зависимости от выпавших наград). Доводка после ready — по реальным
	# minimum size (шрифтовые метрики без line_spacing врут на ~1 строку).
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.ready.connect(_fit_economy_choice_card_content.bind(button), CONNECT_ONE_SHOT)
	return button




func _fit_economy_choice_card_content(button: Button) -> void:
	# SCRUM-808: ужимаем шрифт описания (до 9), затем режем строки многоточием,
	# пока контент не влезет в safe-зону карточки; полный текст остаётся в tooltip.
	if button == null or not is_instance_valid(button):
		return
	var content := button.find_child("%sContent" % button.name, false, false) as BoxContainer
	var desc_label := button.find_child("%sDescription" % button.name, true, false) as Label
	if content == null or desc_label == null:
		return
	var margins: Vector4 = button.get_meta("economy_content_margins", Vector4.ZERO)
	var avail_h: float = button.custom_minimum_size.y - margins.y - margins.w
	if avail_h <= 0.0:
		return
	var font_size := desc_label.get_theme_font_size("font_size")
	while font_size > 12 and content.get_combined_minimum_size().y > avail_h:
		font_size -= 1
		desc_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_DESCRIPTION,
			font_size,
			SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
		))
	var guard := desc_label.get_line_count()
	while guard > 1 and content.get_combined_minimum_size().y > avail_h:
		guard -= 1
		desc_label.max_lines_visible = guard




func _prepend_economy_choice_content(button: Button, control: Control) -> void:
	if button == null or control == null:
		return
	var content := button.find_child("%sContent" % button.name, true, false) as BoxContainer
	if content == null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(control)
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(control)
	content.move_child(control, 0)




# SCRUM-883: чип-пэддинг карточки награды (обычной/элитной) от её display-размера.
func _reward_card_pad(elite := false) -> float:
	return _atlas_card_pad(REWARD_ELITE_CARD_SIZE if elite else REWARD_CARD_SIZE)




func _battle_reward_card_size() -> Vector2:
	# The 720p gold-shell interior is 1014×494. Three compact cards remain fully
	# inside it together with title/subtitle; larger tiers keep the accepted size.
	return _battle_reward_card_size_for_viewport(game.get_viewport().get_visible_rect().size)




func _battle_reward_card_size_for_viewport(viewport_size: Vector2) -> Vector2:
	if viewport_size.y < 800.0:
		# SCRUM-1036: 224px leaves the exact 96px authored header reserve while
		# preserving the compact single-line reward-card layout at 720p.
		return Vector2(270.0, 224.0)
	if viewport_size.y < 1000.0:
		return Vector2(280.0, 300.0)
	return REWARD_CARD_SIZE




# SCRUM-883: карточки наград — чип-ряды Атласа (общий язык с карточками экономики);
# текстурные reward-рамки SCRUM-338/448 сняты.
func _apply_reward_card_theme(button: Button, elite := false) -> void:
	var display_size := button.custom_minimum_size if button != null else (REWARD_ELITE_CARD_SIZE if elite else REWARD_CARD_SIZE)
	_apply_atlas_choice_card_theme(button, _atlas_card_pad(display_size))
	UIButtonFamily.assign(button, UIButtonFamily.FAMILY_REWARD_CARD)




func _add_reward_card_content_container(button: Button, elite := false) -> VBoxContainer:
	var display_size := button.custom_minimum_size if button != null else (REWARD_ELITE_CARD_SIZE if elite else REWARD_CARD_SIZE)
	var margins := _atlas_chip_content_margins(_atlas_card_pad(display_size))
	var content := VBoxContainer.new()
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(content)
	return content




func _progression_node_style(status: String, focused := false) -> StyleBox:
	var texture_id := "focus" if focused else status
	if not PROGRESSION_NODE_TEXTURES.has(texture_id):
		texture_id = "locked"
	var tint := Color.WHITE
	if status == "locked":
		tint = Color(0.70, 0.72, 0.78, 0.82)
	return _global_texture_style(str(PROGRESSION_NODE_TEXTURES[texture_id]), Vector4.ZERO, tint, Vector4(18.0, 18.0, 18.0, 18.0))




func _hero_select_clear_button_style(hovered := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.86, 0.42, 0.08) if hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(1.0, 0.82, 0.34, 0.42) if hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(2 if hovered else 0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style




func _button_style(background: Color, _border: Color, _shadow_alpha := 0.38, _border_width := 2) -> StyleBox:
	var tint := background.lightened(0.38)
	tint.a = 1.0
	return _global_texture_style(GLOBAL_BUTTON_FRAME_PATH, Vector4(34, 26, 34, 28), tint, Vector4(18, 12, 18, 14))




func _bar_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(6)
	return style




func _slider_track_style(background: Color, border := Color(0.0, 0.0, 0.0, 0.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(9)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style




func _global_texture_style(path: String, margins: Vector4, tint := Color.WHITE, content := Vector4.ZERO, tile_edges := false) -> StyleBox:
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.06, 0.08, 0.12, 0.94)
		fallback.border_color = Color(0.95, 0.78, 0.32, 0.85)
		fallback.set_border_width_all(2)
		fallback.set_corner_radius_all(8)
		fallback.content_margin_left = content.x
		fallback.content_margin_top = content.y
		fallback.content_margin_right = content.z
		fallback.content_margin_bottom = content.w
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	if tile_edges:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.modulate_color = tint
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style




func _prepare_global_tooltips(root: Control) -> void:
	if root == null:
		return
	if _global_tooltip_theme == null:
		_global_tooltip_theme = GlobalTooltip.make_theme()
	root.theme = _global_tooltip_theme
	if not bool(root.get_meta("global_tooltip_child_hook", false)):
		root.set_meta("global_tooltip_child_hook", true)
		root.child_entered_tree.connect(func(_child: Node) -> void:
			_schedule_global_tooltip_install(root)
		)
	_schedule_global_tooltip_install(root)




func _schedule_global_tooltip_install(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	if bool(root.get_meta("global_tooltip_install_pending", false)):
		return
	root.set_meta("global_tooltip_install_pending", true)
	call_deferred("_install_global_tooltips_for_root", root)




func _install_global_tooltips_for_root(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.set_meta("global_tooltip_install_pending", false)
	GlobalTooltip.install_on_tree(root, GlobalTooltipControl)




func _style_slider(slider: HSlider) -> void:
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_stylebox_override("slider", _slider_track_style(Color(0.035, 0.045, 0.065, 0.96), Color(0.55, 0.42, 0.18, 0.85)))
	slider.add_theme_stylebox_override("grabber_area", _slider_track_style(Color(0.86, 0.62, 0.20, 0.82), Color(1.0, 0.82, 0.36, 0.90)))
	slider.add_theme_stylebox_override("grabber_area_highlight", _slider_track_style(Color(1.0, 0.76, 0.28, 0.95), Color(1.0, 0.92, 0.54, 1.0)))
	slider.add_theme_constant_override("center_grabber", 1)
	var grabber: Texture2D = game._cached_texture(SYSTEM_SLIDER_GRABBER_PATH)
	if grabber != null:
		slider.add_theme_icon_override("grabber", grabber)
		slider.add_theme_icon_override("grabber_highlight", grabber)
		slider.add_theme_icon_override("grabber_disabled", grabber)




func _style_checkbox(toggle: CheckBox) -> void:
	UIButtonFamily.assign(toggle, "checkbox")
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var unchecked: Texture2D = game._cached_texture(SYSTEM_CHECKBOX_UNCHECKED_PATH)
	var checked: Texture2D = game._cached_texture(SYSTEM_CHECKBOX_CHECKED_PATH)
	if unchecked != null:
		toggle.add_theme_icon_override("unchecked", unchecked)
		toggle.add_theme_icon_override("unchecked_disabled", unchecked)
	if checked != null:
		toggle.add_theme_icon_override("checked", checked)
		toggle.add_theme_icon_override("checked_disabled", checked)
	toggle.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	toggle.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.54, 1.0))
	toggle.add_theme_color_override("font_pressed_color", Color(0.70, 1.0, 0.92, 1.0))
