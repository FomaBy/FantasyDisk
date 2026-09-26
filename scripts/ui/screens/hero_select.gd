extends "res://scripts/ui/screens/hero_select_kit.gd"

# FAN-3824: модуль распределённого UI-класса — экран выбора героя (Character Select v4).
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _build_character_select_v4() -> void:
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "HeroSelectScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)

	var vp: Vector2 = root.get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(1600.0, 900.0)
	var layout_scale := clampf(vp.y / 900.0, 0.76, 1.18)
	var s := _atlas_ui_scale()
	var action_h := _atlas_action_button_height()

	# SCRUM-879: единый атлас-стиль — фон-зал героев, контент строго в safe-зоне
	# рамы, полая рама frame_border добавляется последней (поверх контента).
	_unified_add_background(root, "hero_select")
	var sm := _unified_safe_margins()
	var content_rect := Rect2(Vector2(sm.x, sm.y), vp - Vector2(sm.x + sm.z, sm.y + sm.w))

	# --- Шапка: чип-титул слева, «Назад» на глобальном ките справа ---
	var title_chip := _unified_header_chip("HS4", "Выбор героя", "hero_select", s)
	title_chip.position = content_rect.position
	root.add_child(title_chip)
	var back_button := _make_button("Назад")
	back_button.name = "HS4BackButton"
	# Единый возврат (фидбек 2026-07-08): та же плита 260×h, что на всех экранах.
	_set_action_button_size(back_button, 260.0, action_h)
	back_button.position = Vector2(content_rect.end.x - 260.0, content_rect.position.y)
	root.add_child(back_button)
	back_button.pressed.connect(_show_main_menu)
	# Реальная высота шапки: у кит-кнопки 9-slice минимум выше компактного
	# action_h (контент-маргины ассета) — меряем фактический минимум.
	var header_h := maxf(back_button.get_combined_minimum_size().y, action_h)

	# Геометрия (SCRUM-882): единая шапка (чип-титул слева, «Назад» справа) над
	# ОБЕИМИ колоннами; ниже слева колонна-витрина (портрет на пьедестале → CTA
	# «Выбрать» у низа safe-зоны), справа досье → возвышение → карусель.
	var column_gap := clampf(content_rect.size.x * 0.012, 8.0, 16.0)
	var vgap := clampf(content_rect.size.y * 0.010, 4.0, 10.0)
	var header_band := maxf(title_chip.get_combined_minimum_size().y + 4.0, header_h)
	var baseline_carousel_slot_size := clampf(content_rect.size.y * 0.26, HS4_MINIMAL_SLOT_MIN_SIZE, HS4_MINIMAL_SLOT_MAX_SIZE)
	# The fixed outer shell is narrow at 1152×648/1280×720. Uniformly scale the
	# complete square cards there so the doubled arrows never reduce the window
	# below three visible heroes or overlap a portrait/label.
	var carousel_slot_size := baseline_carousel_slot_size
	if vp.y <= 648.0:
		carousel_slot_size = minf(carousel_slot_size, 116.0)
	elif vp.y <= 720.0:
		carousel_slot_size = minf(carousel_slot_size, 132.0)
	var carousel_h := carousel_slot_size + clampf(content_rect.size.y * 0.012, 6.0, 14.0)
	# SCRUM-1063 doubles the former responsive width exactly while preserving the
	# pre-change height derived from the original slot tier: old aspect 0.75 -> 1.5.
	var carousel_arrow_h := clampf(roundf(baseline_carousel_slot_size * 0.52), 84.0, 140.0)
	var former_carousel_arrow_w := roundf(carousel_arrow_h * 0.75)
	var carousel_arrow_size := Vector2(former_carousel_arrow_w * 2.0, carousel_arrow_h)
	var carousel_min_w := 2.0 * carousel_arrow_size.x + 3.0 * HS4_MINIMAL_SLOT_MIN_SIZE + 4.0 * 6.0
	if vp.y <= 720.0:
		carousel_min_w = 2.0 * carousel_arrow_size.x + 3.0 * carousel_slot_size + 4.0 * 6.0
	# CTA «Выбрать» — плита кнопок главного меню 380×104 (Правило 1: только
	# пропорциональный даунскейл под ширину колонны, аспект не ломаем).
	var choose_aspect := 104.0 / 380.0
	var ascension_pad := roundf(clampf(9.0 * s, 4.0, 9.0))
	# Utility button art has a 59px combined minimum at compact readability.
	# Reserve that real minimum plus both content margins; using the requested
	# 42px alone left the 720p row only 1–2px from/inside the decorative border.
	var asc_utility_min_h := 59.0
	var asc_min_h := maxf(62.0, asc_utility_min_h + ascension_pad * 2.0)
	var asc_target_h := maxf(asc_min_h, clampf(content_rect.size.y * 0.115, 52.0, 100.0))
	# SCRUM-1026: the 1080p/1440p contract promises the complete selected-level
	# delta without an internal scrollbar. Level 5 is the longest supported copy;
	# reserve four readable lines plus the unchanged frame padding. The band's
	# bottom edge stays anchored above the carousel, so this grows upward only and
	# consumes the already scroll-safe dossier budget. Compact 720p keeps the
	# original band and its intentional keyboard/mouse/gamepad scroll path.
	if vp.y >= 1000.0:
		asc_target_h = maxf(asc_target_h, 132.0)
	# All four wide controls share exact geometry. Grow the band upward when the
	# preserved carousel height plus real frame padding exceeds the older band.
	asc_target_h = maxf(asc_target_h, carousel_arrow_size.y + ascension_pad * 2.0)
	# Вертикальный бюджет левой колонны: portrait + vgap + CTA. Возвышение после
	# SCRUM-980 живёт в правой полосе и больше не отнимает высоту у preview.
	var preview_floor := HS4_MINIMAL_PREVIEW_MIN_SIZE
	if vp.y < 680.0:
		preview_floor = 240.0
	elif vp.y < 800.0:
		preview_floor = 270.0
	var left_x := content_rect.position.x
	var left_top := content_rect.position.y + header_band + vgap
	var column_budget := content_rect.end.y - left_top
	var portrait_size := (column_budget - vgap) / (1.0 + choose_aspect)
	if portrait_size > MAX_ACTION_BUTTON_VISUAL_WIDTH:
		# Плита CTA шире 560 не растёт (глобальный кап кита) — высота фиксируется.
		portrait_size = column_budget - vgap - roundf(MAX_ACTION_BUTTON_VISUAL_WIDTH * choose_aspect)
	portrait_size = minf(portrait_size, content_rect.size.x * 0.34)
	portrait_size = minf(portrait_size, content_rect.size.x - column_gap - carousel_min_w)
	# Global action art caps at 560px; keep CTA at least 90% of the portrait
	# column instead of allowing a visibly undersized plate on 1440p.
	portrait_size = minf(portrait_size, MAX_ACTION_BUTTON_VISUAL_WIDTH / 0.90)
	portrait_size = floorf(clampf(portrait_size, preview_floor, HS4_MINIMAL_PREVIEW_MAX_SIZE))
	var choose_w := minf(portrait_size, MAX_ACTION_BUTTON_VISUAL_WIDTH)
	var choose_h := maxf(roundf(choose_w * choose_aspect), 68.0)
	# The 1152×648 shell's source-space gold border rounds 4 px inward compared
	# with the generic safe-margin helper. Keep the CTA fully off that ornament.
	var choose_bottom_reserve := 4.0 if vp.y <= 648.0 else 0.0
	var choose_top := content_rect.end.y - choose_h - choose_bottom_reserve
	var dossier_x := left_x + portrait_size + column_gap
	var dossier_w := content_rect.end.x - dossier_x
	# Фидбек SCRUM-882: top досье == top портрет-фрейма (одна линия под шапкой).
	var dossier_y := left_top
	var carousel_y := content_rect.end.y - carousel_h

	# Счётчик карусели «N–M из K» — полупрозрачный чип над правым краем карусели.
	# Создаётся до досье: его фактическая ширина резервирует правый сегмент полосы
	# возвышения между досье и каруселью.
	var carousel_counter := PanelContainer.new()
	carousel_counter.name = "HS4CarouselCounter"
	var counter_style := _atlas_translucent_style(0.55, 8.0)
	counter_style.content_margin_left = 12.0
	counter_style.content_margin_right = 12.0
	counter_style.content_margin_top = 4.0
	counter_style.content_margin_bottom = 4.0
	carousel_counter.add_theme_stylebox_override("panel", counter_style)
	carousel_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var carousel_counter_label := Label.new()
	carousel_counter_label.name = "HS4CarouselCounterLabel"
	carousel_counter_label.text = "88–88 из 88"
	carousel_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carousel_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carousel_counter_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, 12, 0, 18))
	carousel_counter_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72, 1.0))
	carousel_counter.add_child(carousel_counter_label)
	root.add_child(carousel_counter)
	# SCRUM-980: полоса между досье и каруселью принадлежит отдельному правому
	# фрейму возвышения. Счётчик карусели занимает правый край той же полосы,
	# поэтому ни описание, ни +/- не делят вертикаль с левой CTA.
	var ascension_h := asc_target_h
	# The frame-safe 69px compact band must not steal height from the fixed
	# eight-row stats column. At 720p reclaim that budget from the two decorative
	# inter-panel gaps (still positive/non-overlapping); full sizes retain vgap.
	var ascension_outer_gap := 1.0 if vp.y < 800.0 else vgap
	var ascension_top := carousel_y - ascension_outer_gap - ascension_h
	var dossier_h := maxf(0.0, ascension_top - ascension_outer_gap - dossier_y)

	var portrait_panel := Panel.new()
	portrait_panel.name = "HS4PortraitFrame"
	portrait_panel.position = Vector2(left_x, left_top)
	portrait_panel.size = Vector2(portrait_size, portrait_size)
	portrait_panel.custom_minimum_size = portrait_panel.size
	portrait_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.82, roundf(clampf(10.0 * s, 5.0, 10.0))))
	portrait_panel.clip_contents = true
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait_panel)

	# Пьедестал-подиум PixelLab: аспект-бокс 676:148 у нижней кромки портрет-фрейма,
	# добавлен ДО портрета (под ним по z-порядку). Герой floor-align на верхнюю
	# площадку — линия пола = верх бокса + 22% его высоты.
	var pedestal := TextureRect.new()
	pedestal.name = "HS4Pedestal"
	pedestal.texture = game._cached_texture(ATLAS_STYLE_PEDESTAL_PATH)
	pedestal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pedestal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pedestal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pedestal_w := roundf(portrait_size * 0.86)
	var pedestal_h := roundf(pedestal_w * 148.0 / 676.0)
	pedestal.position = Vector2(roundf((portrait_size - pedestal_w) * 0.5), portrait_size - pedestal_h - maxf(6.0, roundf(portrait_size * 0.02)))
	pedestal.size = Vector2(pedestal_w, pedestal_h)
	portrait_panel.add_child(pedestal)
	var portrait := TextureRect.new()
	portrait.name = "HS4Portrait"
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait)
	var hs4_alpha_bbox_cache := {}
	var texture_alpha_bbox := func(texture: Texture2D) -> Rect2:
		var texture_size := Vector2(512.0, 512.0)
		if texture != null and texture.get_size().x > 0.0 and texture.get_size().y > 0.0:
			texture_size = texture.get_size()
		if texture == null:
			return Rect2(Vector2.ZERO, texture_size)
		var key := texture.resource_path
		if key.is_empty():
			key = str(texture.get_rid())
		if hs4_alpha_bbox_cache.has(key):
			return hs4_alpha_bbox_cache[key]
		var bbox := Rect2(Vector2.ZERO, texture_size)
		var image := texture.get_image()
		if image != null and not image.is_empty():
			var min_x := image.get_width()
			var min_y := image.get_height()
			var max_x := -1
			var max_y := -1
			var alpha_threshold := 0.02
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a <= alpha_threshold:
						continue
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
			if max_x >= min_x and max_y >= min_y:
				bbox = Rect2(Vector2(float(min_x), float(min_y)), Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1)))
		hs4_alpha_bbox_cache[key] = bbox
		return bbox
	var position_alpha_cropped_texture := func(texture_rect: TextureRect, texture: Texture2D, parent_size: Vector2, target_visible_size: Vector2, visible_bottom_y: float, visible_center_x: float) -> void:
		if texture_rect == null or not is_instance_valid(texture_rect):
			return
		var texture_size := Vector2(512.0, 512.0)
		if texture != null and texture.get_size().x > 0.0 and texture.get_size().y > 0.0:
			texture_size = texture.get_size()
		var bbox: Rect2 = texture_alpha_bbox.call(texture)
		var bbox_w := maxf(1.0, bbox.size.x)
		var bbox_h := maxf(1.0, bbox.size.y)
		var visible_target := Vector2(maxf(1.0, target_visible_size.x), maxf(1.0, target_visible_size.y))
		var draw_scale := minf(visible_target.x / bbox_w, visible_target.y / bbox_h)
		draw_scale = maxf(draw_scale, 0.01)
		var draw_size := Vector2(roundf(texture_size.x * draw_scale), roundf(texture_size.y * draw_scale))
		var visible_texture_center_x := bbox.position.x + bbox.size.x * 0.5
		var visible_texture_bottom_y := bbox.position.y + bbox.size.y
		var left := roundf(visible_center_x - visible_texture_center_x * draw_scale)
		var top := roundf(visible_bottom_y - visible_texture_bottom_y * draw_scale)
		texture_rect.anchor_left = 0.0
		texture_rect.anchor_top = 0.0
		texture_rect.anchor_right = 0.0
		texture_rect.anchor_bottom = 0.0
		texture_rect.offset_left = left
		texture_rect.offset_top = top
		texture_rect.offset_right = left + draw_size.x
		texture_rect.offset_bottom = top + draw_size.y
	var position_main_portrait := func(texture: Texture2D) -> void:
		# Floor-align на верхнюю площадку пьедестала (верх бокса + 22% высоты).
		var floor_y := pedestal.position.y + roundf(pedestal.size.y * 0.22)
		var visible_target := Vector2(portrait_panel.size.x * 0.86, maxf(96.0, floor_y - maxf(10.0, roundf(portrait_panel.size.y * 0.05))))
		position_alpha_cropped_texture.call(portrait, texture, portrait_panel.size, visible_target, floor_y, portrait_panel.size.x * 0.5)
	var portrait_preview_state := {
		"character_id": "",
		"sprite_frames": null,
		"direction_index": 0,
		"frame_index": 0,
	}
	var portrait_preview_timer := Timer.new()
	portrait_preview_timer.name = "HS4PortraitPreviewTimer"
	portrait_preview_timer.wait_time = 0.10
	portrait_preview_timer.autostart = true
	root.add_child(portrait_preview_timer)
	portrait_preview_timer.timeout.connect(func() -> void:
		_advance_hero_select_portrait_preview(portrait, portrait_preview_state)
		position_main_portrait.call(portrait.texture)
	)

	var dossier_chip_pad := roundf(clampf(12.0 * s, 6.0, 12.0))
	var dossier_panel := PanelContainer.new()
	dossier_panel.name = "HS4DossierFrame"
	dossier_panel.position = Vector2(dossier_x, dossier_y)
	dossier_panel.size = Vector2(dossier_w, dossier_h)
	dossier_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.88, dossier_chip_pad))
	dossier_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(dossier_panel)

	var dossier_margin_side := maxi(14, int(round(20.0 * layout_scale)))
	var dossier_margin_v := maxi(12, int(round(16.0 * layout_scale)))
	var dossier_margin := MarginContainer.new()
	dossier_margin.name = "HS4DossierContentSafe"
	dossier_margin.add_theme_constant_override("margin_left", dossier_margin_side)
	dossier_margin.add_theme_constant_override("margin_top", dossier_margin_v)
	dossier_margin.add_theme_constant_override("margin_right", dossier_margin_side)
	dossier_margin.add_theme_constant_override("margin_bottom", dossier_margin_v)
	dossier_panel.add_child(dossier_margin)

	# SCRUM-887: досье из двух колонн — слева скролл текстов (растёт), справа
	# фикс-колонна из 8 полос характеристик БЕЗ скролла (всегда все видимы).
	var dossier_columns := HBoxContainer.new()
	dossier_columns.name = "HS4DossierColumns"
	dossier_columns.add_theme_constant_override("separation", maxi(10, int(round(14.0 * layout_scale))))
	dossier_margin.add_child(dossier_columns)

	var dossier_scroll := ScrollContainer.new()
	dossier_scroll.name = "HS4DossierScroll"
	dossier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dossier_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dossier_scroll.focus_mode = Control.FOCUS_ALL
	dossier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_columns.add_child(dossier_scroll)

	var dossier_content := VBoxContainer.new()
	dossier_content.name = "HS4DossierContent"
	dossier_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_content.add_theme_constant_override("separation", 4)
	dossier_scroll.add_child(dossier_content)
	# SCRUM-1046: a focusable ScrollContainer does not automatically provide the
	# menu's scroll-first contract. Consume discrete vertical/page actions while
	# copy remains, then hand focus to the declared Back/Choose neighbour only at
	# the boundary. Keep this local to the dossier so gameplay/global input and
	# configurable controller bindings remain authoritative.
	dossier_scroll.tooltip_text = "Досье героя. Прокрутка: ↑/↓, Page Up/Page Down или колесо мыши."
	dossier_scroll.gui_input.connect(func(event: InputEvent) -> void:
		var scroll_direction := 0
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_page_down"):
			scroll_direction = 1
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_page_up"):
			scroll_direction = -1
		if scroll_direction == 0:
			return
		var scrollbar := dossier_scroll.get_v_scroll_bar()
		var scroll_max := maxi(0, int(ceil(scrollbar.max_value - scrollbar.page)))
		var scroll_step := maxi(12, int(round(dossier_scroll.size.y * 0.65)))
		var previous_scroll := dossier_scroll.scroll_vertical
		var target_scroll := clampi(previous_scroll + scroll_direction * scroll_step, 0, scroll_max)
		if target_scroll == previous_scroll:
			var side := SIDE_BOTTOM if scroll_direction > 0 else SIDE_TOP
			var boundary_neighbor := dossier_scroll.find_valid_focus_neighbor(side)
			if boundary_neighbor != null:
				boundary_neighbor.grab_focus()
				dossier_scroll.accept_event()
			return
		dossier_scroll.scroll_vertical = target_scroll
		dossier_scroll.accept_event()
	)

	# SCRUM-1064: the optional canonical trait is the first dossier block. Hidden
	# traits collapse completely in the VBox, so name becomes first without a gap.
	# The title/body stay as native labels inside the existing scroll-safe content
	# zone; no generated ornament or frame is used as a live text surface.
	var trait_heading := Label.new()
	trait_heading.name = "HS4TraitHeading"
	trait_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	trait_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_heading.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_SECTION,
		_readable_font_size(SemanticTypography.ROLE_SECTION, maxi(11, int(round(14.0 * layout_scale))), 0, 21),
		SemanticTypography.role_min(SemanticTypography.ROLE_SECTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_SECTION)
	))
	trait_heading.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	trait_heading.mouse_filter = Control.MOUSE_FILTER_PASS
	dossier_content.add_child(trait_heading)

	var name_label := Label.new()
	name_label.name = "HS4NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, maxi(20, int(round(30.0 * layout_scale))), 0, 44))
	name_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	dossier_content.add_child(name_label)

	var weapon_label := Label.new()
	weapon_label.name = "HS4Weapon"
	weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_label.max_lines_visible = -1
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	weapon_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_BODY,
		_readable_font_size(SemanticTypography.ROLE_BODY, maxi(11, int(round(14.0 * layout_scale))), 0, 22),
		SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
		SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
	))
	weapon_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier_content.add_child(weapon_label)

	var leading_stats_label := Label.new()
	leading_stats_label.name = "HS4LeadingBaseStats"
	leading_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leading_stats_label.max_lines_visible = -1
	leading_stats_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	leading_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	leading_stats_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_BODY,
		_readable_font_size(SemanticTypography.ROLE_BODY, maxi(11, int(round(14.0 * layout_scale))), 0, 22),
		SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
		SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
	))
	leading_stats_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	dossier_content.add_child(leading_stats_label)

	# SCRUM-887/951: характеристики не скроллятся. Full-size остаётся одной
	# вертикальной колонной; 720p использует PixelLab-specified 2x4 reflow, чтобы
	# имя и число не исчезали и цвет не становился единственным носителем смысла.
	# Высоты решает арифметика (не min-size детей): хост — обычный Control.
	var compact_stat_grid := vp.y < 800.0
	var stat_grid_columns := 2 if compact_stat_grid else 1
	var stat_grid_rows := 4 if compact_stat_grid else 8
	var stats_col_w := 320.0 if compact_stat_grid else clampf(300.0 * layout_scale, 220.0, 320.0)
	var stats_inner_h := dossier_h - 2.0 * dossier_chip_pad - 2.0 * float(dossier_margin_v)
	var stats_column := Control.new()
	stats_column.name = "HS4StatsColumn"
	stats_column.custom_minimum_size = Vector2(stats_col_w, 0.0)
	stats_column.mouse_filter = Control.MOUSE_FILTER_PASS
	dossier_columns.add_child(stats_column)

	var stats_title_font := _readable_font_size(SemanticTypography.ROLE_TITLE, maxi(11, int(round(14.0 * layout_scale))), 0, 22)
	var stats_title_band := roundf(float(stats_title_font) * 1.5) + 6.0
	# Норма: ряд 34–52px; тесный бюджет использует compact paddings. 720p уже
	# reflowed в четыре ряда, поэтому сохраняет текст вместо bar-only fallback.
	var stat_row_sep := clampf(roundf(4.0 * layout_scale), 3.0, 6.0)
	var stat_separator_count := stat_grid_rows - 1
	var stat_row_h := clampf(floorf((stats_inner_h - stats_title_band - float(stat_separator_count) * stat_row_sep) / float(stat_grid_rows)), 34.0, 52.0)
	var stat_row_style_pad := 8.0
	var stat_row_pad_v := 5.0
	var stat_row_pad_h := 8.0
	if stats_title_band + float(stat_grid_rows) * stat_row_h + float(stat_separator_count) * stat_row_sep > stats_inner_h + 0.5:
		stat_row_sep = 3.0 if compact_stat_grid else 2.0
		stat_row_style_pad = 4.0
		stat_row_pad_v = 1.0
		stat_row_pad_h = 6.0
		stat_row_h = floorf((stats_inner_h - stats_title_band - float(stat_separator_count) * stat_row_sep) / float(stat_grid_rows))
	var stat_rows_show_text := compact_stat_grid or stat_row_h >= 14.0
	if not stat_rows_show_text:
		stat_row_style_pad = 2.0
		stat_row_h = maxf(10.0, stat_row_h)

	var stats_title := Label.new()
	stats_title.name = "HS4StatsTitle"
	stats_title.text = "Характеристики"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats_title.position = Vector2.ZERO
	stats_title.size = Vector2(stats_col_w, maxf(0.0, stats_title_band - 4.0))
	stats_title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		stats_title_font,
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))
	stats_title.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	stats_column.add_child(stats_title)

	var stats_grid := GridContainer.new()
	stats_grid.name = "HS4StatsGrid"
	stats_grid.columns = stat_grid_columns
	stats_grid.position = Vector2(0.0, stats_title_band)
	stats_grid.size = Vector2(stats_col_w, maxf(0.0, stats_inner_h - stats_title_band))
	stats_grid.add_theme_constant_override("v_separation", int(stat_row_sep))
	var stat_column_sep := 6.0 if compact_stat_grid else 0.0
	stats_grid.add_theme_constant_override("h_separation", int(stat_column_sep))
	stats_column.add_child(stats_grid)
	var stat_buttons := {}
	var stat_fill_nodes := {}
	var stat_value_labels := {}
	# SCRUM-951: the former 12px base produced a 26px Label line box inside
	# 21px rows at 1080p. Use a stat-only compact step so visible text/bar tracks
	# stay within the accepted dossier geometry; 2K still scales upward.
	var stat_text_font_size := _readable_font_size(SemanticTypography.ROLE_BODY, maxi(8, int(round(10.0 * layout_scale))), 0, 18)
	var stat_cell_w := floorf((stats_col_w - stat_column_sep * float(stat_grid_columns - 1)) / float(stat_grid_columns))
	for sid in HS4_MINIMAL_BASE_STATS:
		var stat_button := Button.new()
		stat_button.name = "HS4Stat_%s" % sid
		stat_button.custom_minimum_size = Vector2(stat_cell_w, stat_row_h)
		stat_button.mouse_default_cursor_shape = Control.CURSOR_HELP
		stat_button.focus_mode = Control.FOCUS_ALL
		stat_button.text = ""
		stat_button.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_ACTION,
			_readable_font_size(SemanticTypography.ROLE_ACTION, maxi(10, int(round(12.0 * layout_scale))), 0, 18),
			SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
		))
		_unified_apply_row_theme(stat_button, stat_row_style_pad)
		var stat_row := HBoxContainer.new()
		stat_row.name = "HS4StatLine_%s" % sid
		stat_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		stat_row.offset_left = stat_row_pad_h
		stat_row.offset_right = -stat_row_pad_h
		stat_row.offset_top = stat_row_pad_v
		stat_row.offset_bottom = -stat_row_pad_v
		stat_row.add_theme_constant_override("separation", 3 if compact_stat_grid else maxi(5, int(round(7.0 * layout_scale))))
		stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_button.add_child(stat_row)
		var stat_name := Label.new()
		stat_name.name = "HS4StatName_%s" % sid
		stat_name.custom_minimum_size = Vector2(90.0 if compact_stat_grid else 126.0, 0.0)
		stat_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_name.text = str(game.PROGRESSION_DATA.STAT_NAMES.get(sid, sid))
		stat_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stat_name.visible = stat_rows_show_text
		# A compact 2×4 cell has a 90px name lane. This is a terse stat caption,
		# not a form field: use the documented 12px caption floor so full Russian
		# names remain visible without abbreviating or stealing the bar/value lanes.
		stat_name.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_CAPTION,
			stat_text_font_size,
			SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
		))
		stat_name.add_theme_color_override("font_color", _hs4_stat_text_color(sid))
		stat_row.add_child(stat_name)
		var bar_bg := ColorRect.new()
		bar_bg.name = "HS4StatBar_%s" % sid
		bar_bg.custom_minimum_size = Vector2(28.0 if compact_stat_grid else maxf(64.0, 96.0 * layout_scale), maxf(8.0, minf(12.0 * layout_scale, stat_row_h - 2.0 * stat_row_pad_v)))
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar_bg.color = Color(0.09, 0.085, 0.075, 0.92)
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_row.add_child(bar_bg)
		var bar_fill := ColorRect.new()
		bar_fill.name = "HS4StatBarFill_%s" % sid
		bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_fill.anchor_right = 0.5
		bar_fill.color = _hs4_stat_fill_color(sid)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.add_child(bar_fill)
		var stat_value := Label.new()
		stat_value.name = "HS4StatValue_%s" % sid
		stat_value.custom_minimum_size = Vector2(18.0 if compact_stat_grid else maxf(22.0, 28.0 * layout_scale), 0.0)
		stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_value.visible = stat_rows_show_text
		stat_value.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_VALUE,
			stat_text_font_size,
			SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
			SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
		))
		stat_value.add_theme_color_override("font_color", _hs4_stat_text_color(sid))
		stat_row.add_child(stat_value)
		stats_grid.add_child(stat_button)
		stat_buttons[sid] = stat_button
		stat_fill_nodes[sid] = bar_fill
		stat_value_labels[sid] = stat_value

	# FAN-1887: досье перечисляет только то, что герой реально может получить —
	# рейл «Слабые атрибуты» удалён, исключения не отображаются как выбор.
	# FAN-1927 (HS.CapPotential/HS.CapabilityLine): те же label-строки в scroll-
	# досье несут потенциал капов (крит/вампиризм) и capability реальных
	# потребителей призыва.
	var guidance_labels := {}
	for relevance in ["primary", "secondary", "cap_potential", "capability"]:
		var guide_label := Label.new()
		guide_label.name = "HS4BuildGuidance_%s" % relevance
		guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide_label.max_lines_visible = -1
		guide_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		guide_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_DESCRIPTION,
			_readable_font_size(SemanticTypography.ROLE_DESCRIPTION, maxi(10, int(round(13.0 * layout_scale))), 0, 20),
			SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
		))
		guide_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
		dossier_content.add_child(guide_label)
		guidance_labels[relevance] = guide_label

	# Возвышение — широкая правая полоса между досье и каруселью. Хост остаётся
	# обычным Panel: ручная арифметика гарантирует пустую content-zone рамки и не
	# даёт minimum-size детей вытолкнуть CTA/карусель (SCRUM-876/SCRUM-980).
	var ascension_counter_gap := maxf(column_gap, 8.0)
	var ascension_w := maxf(0.0, dossier_w - carousel_counter.get_combined_minimum_size().x - ascension_counter_gap)
	var ascension_panel := Panel.new()
	ascension_panel.name = "HS4AscensionFrame"
	ascension_panel.position = Vector2(dossier_x, ascension_top)
	ascension_panel.size = Vector2(ascension_w, ascension_h)
	ascension_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, ascension_pad))
	ascension_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	ascension_panel.clip_contents = true
	root.add_child(ascension_panel)
	# Степпер слева, полное описание выбранного уровня в вертикальном scroll справа.
	# `_atlas_chip_style` uses pad*1.4 for horizontal content margins. Keep the
	# manually positioned row/scroll on that exact authored inset, not the
	# smaller vertical pad (SCRUM-1026 frame-content oracle).
	var ascension_pad_x := ascension_pad * 1.4
	var asc_button_size := carousel_arrow_size

	# Заголовок/интро остаются скрытыми compatibility nodes; доступное описание
	# уровня и полный cumulative tooltip принадлежат правой полосе.
	var asc_label := Label.new()
	asc_label.name = "AscensionLevelLabel"
	asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	asc_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		_readable_font_size(SemanticTypography.ROLE_TITLE, maxi(12, int(round(17.0 * layout_scale))), 0, 26),
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))
	asc_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	asc_label.visible = false
	asc_label.position = Vector2(ascension_pad_x, ascension_pad)
	asc_label.size = Vector2(maxf(0.0, ascension_w - ascension_pad_x * 2.0), 0.0)
	ascension_panel.add_child(asc_label)

	var asc_intro := Label.new()
	asc_intro.name = "HS4AscensionIntro"
	asc_intro.text = "Возвышение усложняет забег и открывает мета-прогресс персонажа после победы над боссом."
	asc_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asc_intro.max_lines_visible = 1
	asc_intro.visible = false
	asc_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_intro.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_DESCRIPTION,
		_readable_font_size(SemanticTypography.ROLE_DESCRIPTION, maxi(9, int(round(11.0 * layout_scale))), 0, 16),
		SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
	))
	asc_intro.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	asc_intro.position = Vector2(ascension_pad_x, ascension_pad)
	asc_intro.size = Vector2(maxf(0.0, ascension_w - ascension_pad_x * 2.0), 0.0)
	ascension_panel.add_child(asc_intro)

	var asc_box := HBoxContainer.new()
	asc_box.name = "HS4AscensionActionRow"
	asc_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var asc_control_gap := maxi(10, int(roundf(asc_button_size.x * 0.10)))
	asc_box.add_theme_constant_override("separation", asc_control_gap)
	ascension_panel.add_child(asc_box)
	var asc_minus := _make_button("−")
	asc_minus.name = "AscensionMinusButton"
	_set_action_button_size(asc_minus, asc_button_size.x, asc_button_size.y)
	_hs4_apply_wide_control_style(asc_minus, asc_button_size)
	asc_minus.set_meta("former_responsive_width", former_carousel_arrow_w)
	asc_box.add_child(asc_minus)
	var asc_stepper_label := Label.new()
	asc_stepper_label.name = "HS4AscensionValue"
	asc_stepper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_stepper_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var asc_value_available := maxf(
		120.0,
		ascension_w - ascension_pad_x * 2.0 - asc_button_size.x * 2.0 - asc_control_gap * 2.0)
	asc_stepper_label.custom_minimum_size = Vector2(minf(maxf(172.0, roundf(220.0 * layout_scale)), asc_value_available), asc_button_size.y)
	asc_stepper_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, maxi(13, int(round(17.0 * layout_scale))), 0, 26))
	asc_stepper_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66, 1.0))
	asc_stepper_label.mouse_filter = Control.MOUSE_FILTER_PASS
	asc_box.add_child(asc_stepper_label)
	var asc_plus := _make_button("+")
	asc_plus.name = "AscensionPlusButton"
	_set_action_button_size(asc_plus, asc_button_size.x, asc_button_size.y)
	_hs4_apply_wide_control_style(asc_plus, asc_button_size)
	asc_plus.set_meta("former_responsive_width", former_carousel_arrow_w)
	asc_box.add_child(asc_plus)
	# Equal controls + equal gaps make the label centre identical to the midpoint
	# between the two button centres. Centre the complete row in the frame.
	asc_box.size = asc_box.get_combined_minimum_size()
	asc_box.position = Vector2(
		roundf((ascension_w - asc_box.size.x) * 0.5),
		roundf((ascension_h - asc_box.size.y) * 0.5))

	var asc_description_gap := maxf(8.0, roundf(10.0 * layout_scale))
	var asc_description_x := asc_box.position.x + asc_box.size.x + asc_description_gap
	var asc_description_scroll := ScrollContainer.new()
	asc_description_scroll.name = "HS4AscensionDescriptionScroll"
	asc_description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	asc_description_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Compatibility node for older test/tool lookup. SCRUM-1063 intentionally
	# removes the visible modifier lane; the complete copy lives in tooltips.
	asc_description_scroll.focus_mode = Control.FOCUS_NONE
	asc_description_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	asc_description_scroll.visible = false
	asc_description_scroll.position = Vector2(asc_description_x, ascension_pad)
	asc_description_scroll.size = Vector2.ZERO
	ascension_panel.add_child(asc_description_scroll)
	var asc_mods := Label.new()
	asc_mods.name = "AscensionModsLabel"
	asc_mods.custom_minimum_size = Vector2(maxf(0.0, asc_description_scroll.size.x - 14.0), 0.0)
	asc_mods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc_mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asc_mods.max_lines_visible = -1
	asc_mods.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	asc_mods.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	asc_mods.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	asc_mods.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_DESCRIPTION,
		_readable_font_size(SemanticTypography.ROLE_DESCRIPTION, maxi(10, int(round(12.0 * layout_scale))), 0, 18),
		SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
	))
	asc_mods.add_theme_color_override("font_color", Color(0.95, 0.62, 0.55, 0.95))
	asc_mods.mouse_filter = Control.MOUSE_FILTER_IGNORE
	asc_mods.visible = false
	asc_description_scroll.add_child(asc_mods)
	asc_description_scroll.gui_input.connect(func(event: InputEvent) -> void:
		var scroll_direction := 0
		if event.is_action_pressed("ui_down"):
			scroll_direction = 1
		elif event.is_action_pressed("ui_up"):
			scroll_direction = -1
		if scroll_direction == 0:
			return
		var scrollbar := asc_description_scroll.get_v_scroll_bar()
		var scroll_max := maxi(0, int(floor(scrollbar.max_value - scrollbar.page)))
		var scroll_step := maxi(12, int(round(asc_description_scroll.size.y * 0.65)))
		var previous_scroll := asc_description_scroll.scroll_vertical
		var target_scroll := clampi(
			asc_description_scroll.scroll_vertical + scroll_direction * scroll_step,
			0,
			scroll_max)
		if target_scroll == previous_scroll:
			# ScrollContainer owns ui_up/down internally, so explicitly hand focus
			# to the declared boundary neighbor when there is nothing left to scroll.
			var side := SIDE_BOTTOM if scroll_direction > 0 else SIDE_TOP
			var boundary_neighbor := asc_description_scroll.find_valid_focus_neighbor(side)
			if boundary_neighbor != null:
				boundary_neighbor.grab_focus()
				asc_description_scroll.accept_event()
			return
		asc_description_scroll.scroll_vertical = target_scroll
		asc_description_scroll.accept_event()
	)

	# CTA «Выбрать» — под превью, прижат к низу
	# safe-зоны, на плите кнопок главного меню (main_menu_380x104 через
	# _text_button_unique_id) во всю ширину колонны. Шрифт — базовый кнопочный
	# (как в главном меню), без кастомных override.
	var select_button := _make_button("Выбрать")
	select_button.name = "HS4ChooseButton"
	_set_action_button_size(select_button, choose_w, choose_h)
	select_button.clip_text = true
	select_button.position = Vector2(left_x + roundf((portrait_size - choose_w) * 0.5), choose_top)
	root.add_child(select_button)

	var carousel_panel := Panel.new()
	carousel_panel.name = "HS4CarouselFrame"
	carousel_panel.position = Vector2(dossier_x, carousel_y)
	carousel_panel.size = Vector2(dossier_w, carousel_h)
	carousel_panel.add_theme_stylebox_override("panel", _atlas_translucent_style(0.45, 12.0))
	carousel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(carousel_panel)
	var carousel := Control.new()
	carousel.name = "HS4Carousel"
	carousel.position = Vector2.ZERO
	carousel.size = carousel_panel.size
	carousel.mouse_filter = Control.MOUSE_FILTER_PASS
	carousel_panel.add_child(carousel)
	var carousel_w: float = carousel.size.x
	var carousel_area_h: float = carousel.size.y
	var arrow_size := carousel_arrow_size
	var slot_size := Vector2(carousel_slot_size, carousel_slot_size)
	var slot_label_h := clampf(roundf(slot_size.y * 0.17), 26.0, 34.0)
	var slot_label_gap := maxf(3.0, roundf(slot_size.y * 0.02))
	var slot_label_margin_x := maxf(6.0, roundf(slot_size.x * 0.04))
	var roster: Array = game.PROGRESSION_DATA.character_ids()
	if roster.is_empty():
		return
	var visible_slot_count := clampi(int(floor((carousel_w - arrow_size.x * 2.0 - 6.0) / (carousel_slot_size + 6.0))), 3, roster.size())
	var slot_gap: float = maxf(6.0, (carousel_w - arrow_size.x * 2.0 - slot_size.x * float(visible_slot_count)) / float(visible_slot_count + 1))
	var slot_y: float = round((carousel_area_h - slot_size.y) * 0.5)
	var arrow_y: float = round((carousel_area_h - arrow_size.y) * 0.5)

	# SCRUM-1063: both arrows share the same horizontal PixelLab/9-slice source,
	# geometry and states as Ascension −/+; hidden counts remain runtime text.
	var left_arrow := _make_button("‹")
	left_arrow.name = "HS4CarouselPrevButton"
	_set_action_button_size(left_arrow, arrow_size.x, arrow_size.y)
	_hs4_apply_wide_control_style(left_arrow, arrow_size)
	left_arrow.set_meta("former_responsive_width", former_carousel_arrow_w)
	left_arrow.clip_text = true
	left_arrow.position = Vector2(0.0, arrow_y)
	carousel.add_child(left_arrow)
	var right_arrow := _make_button("›")
	right_arrow.name = "HS4CarouselNextButton"
	_set_action_button_size(right_arrow, arrow_size.x, arrow_size.y)
	_hs4_apply_wide_control_style(right_arrow, arrow_size)
	right_arrow.set_meta("former_responsive_width", former_carousel_arrow_w)
	right_arrow.clip_text = true
	right_arrow.position = Vector2(carousel_w - arrow_size.x, arrow_y)
	carousel.add_child(right_arrow)

	if not roster.has(game.selected_character_id):
		game.selected_character_id = str(roster[0])

	var slot_buttons: Array = []
	var slot_portraits: Array = []
	var slot_labels: Array = []
	for i in range(visible_slot_count):
		var slot := Button.new()
		slot.name = "HS4CarouselSlot_%02d" % i
		slot.focus_mode = Control.FOCUS_ALL
		slot.text = ""
		slot.clip_contents = true
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.position = Vector2(arrow_size.x + slot_gap + i * (slot_size.x + slot_gap), slot_y)
		slot.size = slot_size
		slot.custom_minimum_size = slot_size
		_unified_apply_row_theme(slot, 6.0)
		var slot_portrait := TextureRect.new()
		slot_portrait.name = "HS4CarouselPortrait_%02d" % i
		slot_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
		slot_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_portrait)
		var slot_label := Label.new()
		slot_label.name = "HS4CarouselLabel_%02d" % i
		slot_label.text = ""
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_label.clip_text = true
		slot_label.position = Vector2(slot_label_margin_x, slot_size.y - slot_label_h)
		slot_label.size = Vector2(slot_size.x - slot_label_margin_x * 2.0, slot_label_h)
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_FIELD, maxi(12, int(round(slot_size.y * 0.075))), 0, 16))
		slot_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.74, 0.94))
		slot_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		slot_label.add_theme_constant_override("outline_size", 3)
		slot.add_child(slot_label)
		carousel.add_child(slot)
		slot_buttons.append(slot)
		slot_portraits.append(slot_portrait)
		slot_labels.append(slot_label)

	var state := {"offset": 0}
	var sel0: int = roster.find(game.selected_character_id)
	state["offset"] = clampi(sel0 - visible_slot_count / 2, 0, maxi(0, roster.size() - visible_slot_count))
	var position_carousel_portrait := func(slot_portrait: TextureRect, texture: Texture2D) -> void:
		var label_top := slot_size.y - slot_label_h
		var visible_bottom_y := label_top - slot_label_gap
		var visible_target := Vector2(slot_size.x * 0.94, maxf(24.0, visible_bottom_y * 0.96))
		position_alpha_cropped_texture.call(slot_portrait, texture, slot_size, visible_target, visible_bottom_y, slot_size.x * 0.5)

	var refresh_focus_graph := func(grab_default := false) -> void:
		var visible_slots: Array = []
		for slot in slot_buttons:
			var slot_button := slot as Button
			slot_button.focus_mode = Control.FOCUS_ALL
			if slot_button.visible:
				visible_slots.append(slot_button)
		var row_controls: Array = [left_arrow]
		row_controls.append_array(visible_slots)
		row_controls.append(right_arrow)
		var default_focus: Control = select_button
		if not visible_slots.is_empty():
			var selected_index: int = roster.find(game.selected_character_id)
			var visible_index: int = clampi(selected_index - int(state["offset"]), 0, visible_slots.size() - 1)
			default_focus = visible_slots[visible_index] as Control
		for i in range(row_controls.size()):
			var ctrl := row_controls[i] as Control
			# SCRUM-1063 restores the cyclic row: outward focus moves to the
			# opposite arrow, and activating either focused arrow uses the same wrap
			# path as pointer input.
			var left := (row_controls.back() as Control) if i == 0 else (row_controls[i - 1] as Control)
			var right := (row_controls.front() as Control) if i == row_controls.size() - 1 else (row_controls[i + 1] as Control)
			ctrl.focus_neighbor_left = left.get_path()
			ctrl.focus_neighbor_right = right.get_path()
			ctrl.focus_neighbor_top = select_button.get_path()
			ctrl.focus_neighbor_bottom = ctrl.get_path()
		# SCRUM-887: статы — вертикальная колонна у правого края досье; цепочка
		# сверху вниз, вход — с «Назад», выход вниз — в правую стрелку карусели.
		var stat_chain: Array = []
		for sid in HS4_MINIMAL_BASE_STATS:
			stat_chain.append(stat_buttons[sid] as Control)
		for i in range(stat_chain.size()):
			var stat_ctrl := stat_chain[i] as Control
			var above := (back_button as Control) if i == 0 else (stat_chain[i - 1] as Control)
			var below := (right_arrow as Control) if i == stat_chain.size() - 1 else (stat_chain[i + 1] as Control)
			stat_ctrl.focus_neighbor_top = above.get_path()
			stat_ctrl.focus_neighbor_bottom = below.get_path()
			stat_ctrl.focus_neighbor_left = dossier_scroll.get_path()
			stat_ctrl.focus_neighbor_right = stat_ctrl.get_path()
		right_arrow.focus_neighbor_top = (stat_chain.back() as Control).get_path()
		back_button.focus_neighbor_left = back_button.get_path()
		back_button.focus_neighbor_right = back_button.get_path()
		back_button.focus_neighbor_top = back_button.get_path()
		back_button.focus_neighbor_bottom = dossier_scroll.get_path()
		dossier_scroll.focus_neighbor_left = dossier_scroll.get_path()
		dossier_scroll.focus_neighbor_right = (stat_chain.front() as Control).get_path()
		dossier_scroll.focus_neighbor_top = back_button.get_path()
		dossier_scroll.focus_neighbor_bottom = select_button.get_path()
		asc_minus.focus_neighbor_left = asc_minus.get_path()
		asc_minus.focus_neighbor_right = asc_plus.get_path()
		asc_minus.focus_neighbor_top = back_button.get_path()
		asc_minus.focus_neighbor_bottom = select_button.get_path()
		asc_plus.focus_neighbor_left = asc_minus.get_path()
		asc_plus.focus_neighbor_right = asc_plus.get_path()
		asc_plus.focus_neighbor_top = back_button.get_path()
		asc_plus.focus_neighbor_bottom = select_button.get_path()
		# CTA внизу левой колонны: вверх ведёт к степперу правой полосы,
		# вправо — вход в ряд карусели.
		select_button.focus_neighbor_left = asc_minus.get_path()
		select_button.focus_neighbor_right = left_arrow.get_path()
		select_button.focus_neighbor_top = dossier_scroll.get_path()
		select_button.focus_neighbor_bottom = default_focus.get_path()
		if grab_default:
			default_focus.grab_focus()

	var keep_selected_visible := func() -> void:
		var selected_index: int = roster.find(game.selected_character_id)
		if selected_index < 0:
			selected_index = 0
			game.selected_character_id = str(roster[0])
		var max_offset: int = maxi(0, roster.size() - visible_slot_count)
		if roster.size() <= visible_slot_count:
			state["offset"] = 0
			return
		var offset: int = int(state["offset"])
		if selected_index < offset:
			offset = selected_index
		elif selected_index >= offset + visible_slot_count:
			offset = selected_index - visible_slot_count + 1
		state["offset"] = clampi(offset, 0, max_offset)

	var refresh := func() -> void:
		keep_selected_visible.call()
		var cid: String = game.selected_character_id
		var config: Dictionary = game.PROGRESSION_DATA.character_config(cid)
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(cid)
		var dossier: Dictionary = game.PROGRESSION_DATA.hero_select_dossier(cid)
		var trait_config: Dictionary = dossier.get("trait", {}) as Dictionary
		_set_hero_select_portrait_preview(portrait, cid, config, portrait_preview_state)
		position_main_portrait.call(portrait.texture)
		name_label.text = str(dossier.get("name", config.get("title", cid)))
		var trait_title := str(trait_config.get("title", "")).strip_edges()
		var trait_copy := str(trait_config.get("short_description", trait_config.get("description", ""))).strip_edges()
		trait_heading.visible = not trait_title.is_empty() and not trait_copy.is_empty()
		trait_heading.text = "Особенность: %s — %s" % [trait_title, trait_copy] if trait_heading.visible else ""
		trait_heading.tooltip_text = trait_heading.text
		weapon_label.text = "Оружие: %s" % _hs4_join_dossier_names(dossier.get("weapons", []) as Array)
		dossier_scroll.scroll_vertical = 0
		dossier_scroll.set_deferred("scroll_vertical", 0)
		var leading_stats := PackedStringArray()
		for stat_value in dossier.get("leading_base_stats", []) as Array:
			var stat_entry := stat_value as Dictionary
			leading_stats.append("%s — %d" % [
				str(stat_entry.get("name", stat_entry.get("id", ""))),
				int(round(float(stat_entry.get("value", 0.0)))),
			])
		leading_stats_label.text = "Основные характеристики: %s." % "; ".join(leading_stats)
		for sid in HS4_MINIMAL_BASE_STATS:
			var sval := float(stats.get(sid, 0.0))
			var stat_button := stat_buttons[sid] as Button
			stat_button.text = ""
			stat_button.tooltip_text = _hs4_stat_tooltip(sid, sval, cid)
			var stat_fill := stat_fill_nodes[sid] as ColorRect
			stat_fill.anchor_right = clampf(sval / 10.0, 0.04, 1.0)
			stat_fill.color = _hs4_stat_fill_color(sid)
			var stat_value := stat_value_labels[sid] as Label
			stat_value.text = str(int(round(sval)))
		var guidance_groups: Dictionary = dossier.get("attribute_relevance", {}) as Dictionary
		var relevance_titles := {
			"primary": "Основные атрибуты",
			"secondary": "Второстепенные атрибуты",
		}
		for relevance in ["primary", "secondary"]:
			var guide_label := guidance_labels[relevance] as Label
			var title := str(relevance_titles.get(relevance, relevance))
			var entries: Array = guidance_groups.get(relevance, []) as Array
			guide_label.text = "%s: %s" % [title, _hs4_join_dossier_names(entries)]
			guide_label.tooltip_text = guide_label.text
		# FAN-1927 (HS.CapPotential/HS.CapabilityLine): тексты — из единого
		# view-model (AttributeSurfaces.hero_dossier_lines), без CTA.
		var hero_lines: Dictionary = AttributeSurfaces.hero_dossier_lines(
			cid, stats, game.PROGRESSION_DATA.weapon(cid, game.selected_weapon_id))
		var cap_label := guidance_labels["cap_potential"] as Label
		cap_label.text = str(hero_lines.get("cap_potential", ""))
		cap_label.visible = cap_label.text != ""
		cap_label.tooltip_text = cap_label.text
		var capability_label := guidance_labels["capability"] as Label
		var capability_format := tr("hero_select_capability_format")
		capability_label.text = capability_format % str(hero_lines.get("capability", "")) if capability_format != "hero_select_capability_format" else str(hero_lines.get("capability", ""))
		capability_label.visible = capability_label.text != ""
		capability_label.tooltip_text = capability_label.text
		var maxl: int = game.ascension_selectable_max(cid)
		game.selected_ascension_level = clampi(game.selected_ascension_level, 0, maxl)
		asc_label.text = "Возвышение"
		asc_stepper_label.text = "Возвышение %d" % game.selected_ascension_level
		var ascension_tooltip := _hs4_ascension_text(game.selected_ascension_level)
		asc_mods.text = str(game.PROGRESSION_DATA.ascension_level_change_line(game.selected_ascension_level))
		asc_description_scroll.scroll_vertical = 0
		asc_description_scroll.set_deferred("scroll_vertical", 0)
		asc_mods.tooltip_text = ascension_tooltip
		asc_stepper_label.tooltip_text = ascension_tooltip
		asc_minus.tooltip_text = ascension_tooltip
		asc_plus.tooltip_text = ascension_tooltip
		asc_description_scroll.tooltip_text = ascension_tooltip
		ascension_panel.tooltip_text = ascension_tooltip
		asc_minus.disabled = game.selected_ascension_level <= 0
		asc_plus.disabled = game.selected_ascension_level >= maxl
		var off: int = int(state["offset"])
		carousel.set_meta("window_offset", off)
		carousel.set_meta("visible_slot_count", visible_slot_count)
		carousel.set_meta("cyclic_wrap", true)
		for i in range(visible_slot_count):
			var idx: int = off + i
			var slot: Button = slot_buttons[i]
			var slot_portrait := slot_portraits[i] as TextureRect
			var slot_label := slot_labels[i] as Label
			if idx < roster.size():
				var rid: String = str(roster[idx])
				slot.set_meta("character_id", rid)
				var rconf: Dictionary = game.PROGRESSION_DATA.character_config(rid)
				var slot_texture := game._cached_texture(str(rconf.get("sprite_path", rconf.get("sprite", "")))) as Texture2D
				slot_portrait.texture = slot_texture
				position_carousel_portrait.call(slot_portrait, slot_texture)
				slot.visible = true
				var slot_title := str(rconf.get("title", rid))
				slot.tooltip_text = slot_title
				slot_label.text = slot_title
				_unified_apply_row_theme(slot, 6.0, rid == cid)
				slot_portrait.modulate = Color(1.0, 1.0, 1.0, 1.0) if rid == cid else Color(0.58, 0.60, 0.68, 0.78)
				slot_label.modulate = Color(1.0, 0.96, 0.80, 1.0) if rid == cid else Color(0.66, 0.68, 0.74, 0.84)
			else:
				slot.visible = false
				slot.remove_meta("character_id")
				slot_portrait.texture = null
				slot_label.text = ""
		# SCRUM-882: явный счётчик карусели — «N–M из K» + число скрытых на стрелках.
		var roster_total: int = roster.size()
		var window_first: int = mini(off + 1, roster_total)
		var window_last: int = mini(off + visible_slot_count, roster_total)
		carousel_counter_label.text = "%d–%d из %d" % [window_first, window_last, roster_total]
		carousel_counter.size = carousel_counter.get_combined_minimum_size()
		carousel_counter.position = Vector2(
			content_rect.end.x - carousel_counter.size.x,
			carousel_y - 4.0 - carousel_counter.size.y)
		var hidden_left: int = off
		var hidden_right: int = maxi(0, roster_total - off - visible_slot_count)
		left_arrow.text = "‹" if hidden_left <= 0 else "‹%d" % hidden_left
		right_arrow.text = "›" if hidden_right <= 0 else "%d›" % hidden_right
		refresh_focus_graph.call(false)

	var select_hero := func(cid: String) -> void:
		game.selected_character_id = cid
		game.selected_ascension_level = game.ascension_selectable_max(cid)
		refresh.call()

	var scroll_carousel_window := func(direction: int) -> void:
		keep_selected_visible.call()
		var selected_index: int = roster.find(game.selected_character_id)
		if selected_index < 0:
			selected_index = 0
		var old_offset: int = int(state["offset"])
		var anchor: int = clampi(selected_index - old_offset, 0, visible_slot_count - 1)
		var max_offset: int = maxi(0, roster.size() - visible_slot_count)
		var wraps_to_end := direction < 0 and old_offset <= 0
		var wraps_to_start := direction > 0 and old_offset >= max_offset
		var new_offset: int = old_offset
		if wraps_to_end:
			new_offset = max_offset
		elif wraps_to_start:
			new_offset = 0
		else:
			new_offset = clampi(old_offset + direction, 0, max_offset)
		state["offset"] = new_offset
		var window_end: int = mini(new_offset + visible_slot_count - 1, roster.size() - 1)
		var target_index: int
		if wraps_to_end:
			target_index = roster.size() - 1
		elif wraps_to_start:
			target_index = 0
		else:
			target_index = clampi(new_offset + anchor, new_offset, window_end)
		select_hero.call(str(roster[target_index]))

	for i in range(visible_slot_count):
		var slot_index := i
		slot_buttons[i].pressed.connect(func() -> void:
			var idx: int = int(state["offset"]) + slot_index
			if idx < roster.size():
				select_hero.call(str(roster[idx]))
		)
	left_arrow.pressed.connect(func() -> void:
		scroll_carousel_window.call(-1)
	)
	right_arrow.pressed.connect(func() -> void:
		scroll_carousel_window.call(1)
	)
	asc_minus.pressed.connect(func() -> void:
		game.selected_ascension_level = maxi(game.selected_ascension_level - 1, 0)
		refresh.call()
	)
	asc_plus.pressed.connect(func() -> void:
		game.selected_ascension_level = mini(game.selected_ascension_level + 1, game.ascension_selectable_max(game.selected_character_id))
		refresh.call()
	)
	select_button.pressed.connect(func() -> void:
		_show_weapon_select()
	)
	game.selected_ascension_level = game.ascension_selectable_max(game.selected_character_id)
	game.ui_escape_action = _show_main_menu
	refresh.call()
	refresh_focus_graph.call(true)
	# SCRUM-1064: Hero Select used one-shot viewport arithmetic while the unified
	# frame itself already followed resize. Rebuild this screen only (without the
	# route/run reset in _show_character_select) after a real live size change.
	# The deferred guard coalesces resize bursts and the old root invalidates on
	# _clear_ui, preventing duplicate rebuilds.
	var built_viewport_size := root.size
	root.resized.connect(func() -> void:
		if not is_instance_valid(root) or root.get_meta("hero_resize_rebuild_pending", false):
			return
		if root.size.distance_to(built_viewport_size) <= 0.5:
			return
		root.set_meta("hero_resize_rebuild_pending", true)
		_rebuild_character_select_after_resize.call_deferred(root)
	)
	# Полая рама 9-slice поверх всего контента — добавляется последней.
	_unified_add_frame(root, "HeroSelect")




func _rebuild_character_select_after_resize(previous_root: Control) -> void:
	if previous_root == null or not is_instance_valid(previous_root) or previous_root.get_parent() == null:
		return
	game._clear_ui()
	_build_character_select_v4()



func _show_character_select() -> void:
	game.clear_run_autosave()
	game.clear_run_sandbox_snapshot()
	game.run_player_snapshot.clear()
	game.current_act = 1
	game.route_stage = 0
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.event_shop_exit_action = Callable()  # SCRUM-996
	game.run_used_shop = false
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1
	game.route_nodes = game.route._generate_route()
	_clear_current_shop_stock()
	game._clear_ui()

	# Экран выбора героя строит v4-билдер (SCRUM-470). Мёртвая v3-вёрстка удалена (SCRUM-492).
	_build_character_select_v4()




func _update_hero_select_info(info_labels: Dictionary, title: String, description: String, strengths: String, weaknesses: String, stats_text: String) -> void:
	var title_label := info_labels.get("title") as Label
	var description_label := info_labels.get("description") as Label
	var stats_label := info_labels.get("stats") as Label
	if title_label != null:
		title_label.text = title
	if description_label != null:
		description_label.text = "%s  |  Сильные: %s  |  Слабые: %s" % [description, strengths, weaknesses]
	if stats_label != null:
		stats_label.text = stats_text
