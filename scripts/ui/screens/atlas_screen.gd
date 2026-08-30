extends "res://scripts/ui/screens/victory_death.gd"

# FAN-3824: модуль распределённого UI-класса — экран «Атлас героев»: показ, стили, чипы валют.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.



func _show_atlas_screen() -> void:
	# SCRUM-827: экран «Атлас героев» (Мета 4.0, дизайн §7 + мокап meta40_atlas_mockup).
	# Две вкладки (Созвездие/Гильдия), созвездие класса ЦЕЛИКОМ без пан/зума на небе
	# bg_sky, лента 17 медальонов-гербов слева, панель узла справа, церемонии покупки
	# и рассеивания тумана. Ядро — SCRUM-828 (constellation_nodes/allocate_node/
	# active_keystone/hidden_star_progress); арт — кит SCRUM-826/832 (meta40/).
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var s := _atlas_ui_scale()
	var class_id := str(game.selected_character_id)
	if not game.META_PROGRESSION.CLASS_ENTRY_NODES.has(class_id):
		class_id = "berserk"
	_atlas = {
		"tab": "constellation",
		"class_id": class_id,
		"selected": "",
		"status": {},
		"edges": [],
		"edge_flash": {},
		"node_buttons": {},
		"node_centers": {},
		"npos": {},
		"fog_tweens": {},
		"medallions": [],
	}

	var root := Control.new()
	root.name = "AtlasScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_atlas["root"] = root

	# Ночное небо — фулскрин-ассет кита, без общего фона/шейда.
	var sky := TextureRect.new()
	sky.name = "AtlasSky"
	sky.texture = game._cached_texture(META40_BG_SKY_PATH)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)

	# Контент строго в пустой зоне рамы (safe-area правило проекта): маргины
	# повторяют texture-margins рамы (band + угловые вырезы).
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	var frame_margins := _scaled_frame_margins_xy(
		ATLAS_FRAME_SOURCE_SIZE, vp,
		Vector4(ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN))
	# Full currency names plus three standard action plates need ~1.4K. At
	# compact safe widths the icons keep the resource identity, labels show the
	# exact count, and the full localized phrase moves to the tooltip.
	var atlas_safe_width := maxf(0.0, vp.x - frame_margins.x - frame_margins.z)
	var compact_header_currency := atlas_safe_width < 1420.0
	var safe := MarginContainer.new()
	safe.name = "AtlasSafeArea"
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Фидбек 2026-07-08: шапку чуть выше, футер чуть ниже (band рамы имеет тёмный
	# внутренний отступ — 14% захода визуально остаются в пустой зоне), телу
	# достаётся больше высоты под 2 колонки эмблем без скролла.
	safe.add_theme_constant_override("margin_left", int(frame_margins.x))
	safe.add_theme_constant_override("margin_top", int(frame_margins.y * 0.86))
	safe.add_theme_constant_override("margin_right", int(frame_margins.z))
	safe.add_theme_constant_override("margin_bottom", int(frame_margins.w * 0.86))
	root.add_child(safe)

	var layout := VBoxContainer.new()
	layout.name = "AtlasLayout"
	layout.add_theme_constant_override("separation", int(roundf(10.0 * s)))
	safe.add_child(layout)

	# --- Шапка (фидбек пользователя 2026-07-08): «Созвездие» слева + рядом счётчик
	# свободных эмблем класса; «Гильдия» + звёздная пыль по центру (между двумя
	# expand-спейсерами); «Назад» справа. Табы и назад — единые плиты кита 260×h,
	# как back-кнопки остальных экранов (однообразие возврата и кнопок).
	var header := HBoxContainer.new()
	header.name = "AtlasHeader"
	header.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	layout.add_child(header)
	var atlas_action_h := _atlas_action_button_height()
	var tab_constellation := _make_button("Созвездие")
	tab_constellation.name = "AtlasTabConstellation"
	_set_action_button_size(tab_constellation, 260.0, atlas_action_h)
	tab_constellation.pressed.connect(Callable(self, "_atlas_switch_tab").bind("constellation"))
	header.add_child(tab_constellation)
	_atlas["tab_constellation"] = tab_constellation
	var emblem_badge := _atlas_make_currency_chip("AtlasEmblemBadge", META40_CURRENCY_EMBLEM_PATH, "AtlasEmblemsLabel", s)
	header.add_child(emblem_badge)
	emblem_badge.tooltip_text = "Эмблемы класса"
	_atlas["emblem_badge"] = emblem_badge
	_atlas["emblems_label"] = emblem_badge.find_child("AtlasEmblemsLabel", true, false)
	var header_spacer := Control.new()
	header_spacer.name = "AtlasHeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var tab_guild := _make_button("Гильдия")
	tab_guild.name = "AtlasTabGuild"
	_set_action_button_size(tab_guild, 260.0, atlas_action_h)
	tab_guild.pressed.connect(Callable(self, "_atlas_switch_tab").bind("guild"))
	header.add_child(tab_guild)
	_atlas["tab_guild"] = tab_guild
	var stardust_badge := _atlas_make_currency_chip("AtlasStardustBadge", META40_CURRENCY_STARDUST_PATH, "AtlasStardustLabel", s)
	header.add_child(stardust_badge)
	stardust_badge.tooltip_text = "Звёздная пыль"
	_atlas["stardust_badge"] = stardust_badge
	_atlas["stardust_label"] = stardust_badge.find_child("AtlasStardustLabel", true, false)
	_atlas["compact_header_currency"] = compact_header_currency
	var header_spacer_right := Control.new()
	header_spacer_right.name = "AtlasHeaderSpacerRight"
	header_spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer_right)
	var back_button := _make_button("Назад")
	back_button.name = "AtlasBackButton"
	_set_action_button_size(back_button, 260.0, atlas_action_h)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	_atlas["back_button"] = back_button
	game.ui_escape_action = _show_main_menu

	# --- Тело: лента классов | небо-созвездие | панель узла ---
	var body := HBoxContainer.new()
	body.name = "AtlasBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	layout.add_child(body)

	# Фидбек 2026-07-08 (SCRUM-884): все 17 героев видимы разом — сетка в 2
	# столбца; размер медальона считается от высоты тела (9 рядов), скролл
	# остаётся только страховкой для карликовых окон (пол 44px).
	var strip_rows := ceili(float(game.META_PROGRESSION.constellation_class_ids().size()) / 2.0)
	var strip_sep := int(roundf(6.0 * s))
	var vp_h: float = game.get_viewport().get_visible_rect().size.y
	# Фидбек 2026-07-08: размер медальона от ФАКТИЧЕСКОЙ высоты тела (вьюпорт минус
	# ужатые маргины рамы, шапка, футер, сепараторы) — на 1080p и 1440p все 9 рядов
	# видимы без скролла; пол 44 — только страховка карликовых окон.
	var atlas_body_h := vp_h - frame_margins.y * 0.86 - frame_margins.w * 0.86 \
		- atlas_action_h * 2.0 - roundf(10.0 * s) * 2.0 - 8.0
	var medallion_px := roundf(clampf(atlas_body_h / float(maxi(strip_rows, 1)) - float(strip_sep), 44.0, 112.0))
	var strip := ScrollContainer.new()
	strip.name = "AtlasClassStrip"
	strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.follow_focus = true
	strip.custom_minimum_size = Vector2(medallion_px * 2.0 + float(strip_sep) + roundf(14.0 * s), 0.0)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(strip)
	_atlas["strip"] = strip
	var strip_box := GridContainer.new()
	strip_box.name = "AtlasClassStripBox"
	strip_box.columns = 2
	strip_box.add_theme_constant_override("h_separation", strip_sep)
	strip_box.add_theme_constant_override("v_separation", strip_sep)
	strip.add_child(strip_box)
	for raw_cid in game.META_PROGRESSION.constellation_class_ids():
		var cid := str(raw_cid)
		var cfg: Dictionary = game.PROGRESSION_DATA.character_config(cid)
		var mb := TextureButton.new()
		mb.name = "AtlasMedallion_%s" % cid
		UIButtonFamily.assign(mb, "atlas_medallion")
		mb.texture_normal = game._cached_texture(META40_UI_DIR + "crest_%s.png" % cid)
		mb.ignore_texture_size = true
		mb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		mb.custom_minimum_size = Vector2(medallion_px, medallion_px)
		mb.focus_mode = Control.FOCUS_ALL
		mb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mb.tooltip_text = str(cfg.get("title", cid))
		mb.set_meta("class_id", cid)
		mb.pressed.connect(Callable(self, "_atlas_select_class").bind(cid))
		strip_box.add_child(mb)
		(_atlas["medallions"] as Array).append(mb)
		var prog_chip := PanelContainer.new()
		prog_chip.name = "MedallionProgressChip"
		prog_chip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		var chip_h := maxf(16.0, roundf(20.0 * s))
		prog_chip.offset_top = -chip_h
		prog_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog_chip.add_theme_stylebox_override("panel", _atlas_translucent_style(0.55, 6.0))
		mb.add_child(prog_chip)
		var prog := Label.new()
		prog.name = "AtlasMedallionProgress_%s" % cid
		prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prog.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, 11))
		prog.add_theme_color_override("font_color", Color(0.93, 0.89, 0.74, 0.96))
		prog_chip.add_child(prog)
		var badge := PanelContainer.new()
		badge.name = "AtlasMedallionBadge_%s" % cid
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		var badge_px := maxf(20.0, roundf(30.0 * s))
		badge.offset_left = -badge_px
		badge.offset_bottom = badge_px
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _atlas_unspent_badge_style(badge_px * 0.5))
		badge.visible = false
		mb.add_child(badge)
		var badge_label := Label.new()
		badge_label.name = "BadgeCount"
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_HUD, 11))
		badge_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.86, 1.0))
		badge.add_child(badge_label)

	# SCRUM-971: the header is already fully owned by tabs, currencies and Back.
	# Give the localized selected-class title a lightweight native-text row over
	# the graph instead. The shared VBox reserves the row without overlaying any
	# socket, while the canvas keeps all remaining responsive height.
	var center_column := VBoxContainer.new()
	center_column.name = "AtlasCenterColumn"
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", maxi(4, int(roundf(6.0 * s))))
	body.add_child(center_column)
	_atlas["center_column"] = center_column
	var selected_class_label := Label.new()
	selected_class_label.name = "AtlasSelectedClassLabel"
	selected_class_label.custom_minimum_size = Vector2(0.0, maxf(28.0, roundf(52.0 * s)))
	selected_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_class_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_class_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 20, 16, 28))
	selected_class_label.add_theme_color_override("font_color", Color(0.96, 0.87, 0.58, 1.0))
	selected_class_label.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.07, 0.96))
	selected_class_label.add_theme_constant_override("outline_size", maxi(2, int(roundf(4.0 * s))))
	center_column.add_child(selected_class_label)
	_atlas["selected_class_label"] = selected_class_label

	var canvas := Control.new()
	canvas.name = "AtlasCanvas"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.gui_input.connect(Callable(self, "_atlas_canvas_input"))
	canvas.resized.connect(Callable(self, "_atlas_schedule_layout_passes"))
	center_column.add_child(canvas)
	_atlas["canvas"] = canvas
	var edge_layer := Control.new()
	edge_layer.name = "AtlasEdges"
	edge_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_layer.draw.connect(Callable(self, "_atlas_draw_edges"))
	canvas.add_child(edge_layer)
	_atlas["edge_layer"] = edge_layer

	# --- Панель узла (титул/тип/описание с числами/цена/действия) ---
	var panel := PanelContainer.new()
	panel.name = "AtlasNodePanel"
	panel.custom_minimum_size = Vector2(roundf(clampf(452.0 * s, 272.0, 452.0)), 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# SCRUM-1090/1091 dossier contract: the calm runtime interior begins at
	# least 30 px inside the panel on every target tier. Long copy scrolls inside
	# that zone; shrinking the inset to gain space would put text on ornament.
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.90, 30.0))
	body.add_child(panel)
	var panel_box := VBoxContainer.new()
	panel_box.name = "AtlasNodePanelBox"
	panel_box.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	panel.add_child(panel_box)
	var kind_label := Label.new()
	kind_label.name = "AtlasNodeKind"
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_FIELD, 13))
	kind_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	panel_box.add_child(kind_label)
	_atlas["panel_kind"] = kind_label
	var icon_center := CenterContainer.new()
	icon_center.name = "AtlasNodeIconCenter"
	panel_box.add_child(icon_center)
	var node_icon := TextureRect.new()
	node_icon.name = "AtlasNodeIcon"
	node_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px := roundf(clampf(104.0 * s, 56.0, 104.0))
	node_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	icon_center.add_child(node_icon)
	_atlas["panel_icon"] = node_icon
	var title_label := Label.new()
	title_label.name = "AtlasNodeTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 22))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	panel_box.add_child(title_label)
	_atlas["panel_title"] = title_label
	var info_scroll := ScrollContainer.new()
	info_scroll.name = "AtlasNodeScroll"
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.focus_mode = Control.FOCUS_ALL
	info_scroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	info_scroll.tooltip_text = "Описание звезды. Прокрутка: ↑/↓ или колесо мыши."
	panel_box.add_child(info_scroll)
	_atlas["panel_scroll"] = info_scroll
	var info_box := VBoxContainer.new()
	info_box.name = "AtlasNodeInfoBox"
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	info_scroll.add_child(info_box)
	var final_callout := Label.new()
	final_callout.name = "AtlasNodeFinalCallout"
	final_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_callout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	final_callout.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_FIELD, 14))
	final_callout.add_theme_color_override("font_color", Color(0.54, 0.78, 1.0, 1.0))
	final_callout.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.03, 0.98))
	final_callout.add_theme_constant_override("outline_size", maxi(2, int(roundf(3.0 * s))))
	final_callout.visible = false
	info_box.add_child(final_callout)
	_atlas["panel_final_callout"] = final_callout
	var desc_label := Label.new()
	desc_label.name = "AtlasNodeDesc"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 15))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.95, 0.96))
	info_box.add_child(desc_label)
	_atlas["panel_desc"] = desc_label
	var condition_label := Label.new()
	condition_label.name = "AtlasNodeCondition"
	condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	condition_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	condition_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 13))
	condition_label.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0, 0.95))
	condition_label.visible = false
	info_box.add_child(condition_label)
	_atlas["panel_condition"] = condition_label
	var lore_label := Label.new()
	lore_label.name = "AtlasNodeLore"
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 12))
	lore_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82, 0.85))
	lore_label.visible = false
	info_box.add_child(lore_label)
	_atlas["panel_lore"] = lore_label
	var price_row := HBoxContainer.new()
	price_row.name = "AtlasNodePriceRow"
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	panel_box.add_child(price_row)
	_atlas["panel_price_row"] = price_row
	var price_label := Label.new()
	price_label.name = "AtlasNodePriceLabel"
	price_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, 17))
	price_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	price_row.add_child(price_label)
	_atlas["panel_price_label"] = price_label
	var price_icon := TextureRect.new()
	price_icon.name = "AtlasNodePriceIcon"
	price_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	price_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var price_icon_px := maxf(18.0, roundf(28.0 * s))
	price_icon.custom_minimum_size = Vector2(price_icon_px, price_icon_px)
	price_row.add_child(price_icon)
	_atlas["panel_price_icon"] = price_icon
	var buy_button := _make_button("Вложить эмблему")
	buy_button.name = "AtlasBuyButton"
	# Let the action fill the responsive dossier width without imposing the
	# legacy 360 px minimum that widened the panel after selection on 720p/1080p.
	_set_action_button_size(buy_button, 0.0, 88.0)
	buy_button.pressed.connect(Callable(self, "_atlas_buy_selected"))
	panel_box.add_child(buy_button)
	_atlas["buy_button"] = buy_button
	var keystone_toggle := _make_button("Сделать активной")
	keystone_toggle.name = "AtlasKeystoneToggle"
	_set_action_button_size(keystone_toggle, 0.0, 88.0)
	keystone_toggle.pressed.connect(Callable(self, "_atlas_toggle_keystone"))
	keystone_toggle.visible = false
	panel_box.add_child(keystone_toggle)
	_atlas["keystone_toggle"] = keystone_toggle
	var progress_label := Label.new()
	progress_label.name = "AtlasProgressLabel"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, 14))
	progress_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.70, 0.95))
	# Variable progress/hint copy belongs to the existing dossier scroll. Keeping
	# it outside forced a 420px panel minimum and expanded 1280x720 beyond the
	# real viewport after node selection (SCRUM-1024).
	info_box.add_child(progress_label)
	_atlas["panel_progress"] = progress_label
	var hidden_hint := Label.new()
	hidden_hint.name = "AtlasHiddenHint"
	hidden_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hidden_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hidden_hint.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_CAPTION, 12))
	hidden_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.98, 0.88))
	hidden_hint.visible = false
	info_box.add_child(hidden_hint)
	_atlas["panel_hidden_hint"] = hidden_hint
	info_scroll.gui_input.connect(func(event: InputEvent) -> void:
		var scroll_direction := 0
		if event.is_action_pressed("ui_down"):
			scroll_direction = 1
		elif event.is_action_pressed("ui_up"):
			scroll_direction = -1
		if scroll_direction == 0:
			return
		var scrollbar := info_scroll.get_v_scroll_bar()
		var scroll_max := maxi(0, int(floor(scrollbar.max_value - scrollbar.page)))
		var scroll_step := maxi(12, int(round(info_scroll.size.y * 0.65)))
		var previous_scroll := info_scroll.scroll_vertical
		var target_scroll := clampi(previous_scroll + scroll_direction * scroll_step, 0, scroll_max)
		if target_scroll == previous_scroll:
			var side := SIDE_BOTTOM if scroll_direction > 0 else SIDE_TOP
			var boundary_neighbor := info_scroll.find_valid_focus_neighbor(side)
			if boundary_neighbor != null:
				boundary_neighbor.grab_focus()
				info_scroll.accept_event()
			return
		info_scroll.scroll_vertical = target_scroll
		info_scroll.accept_event()
	)

	# --- Низ: «Сброс умений» (бесплатный респек — в тултипе) + легенда состояний ---
	var footer := HBoxContainer.new()
	footer.name = "AtlasFooter"
	footer.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	layout.add_child(footer)
	# SCRUM-1070: accepted Atlas mockup uses the wide reset action. Pin the exact
	# 420×104 family explicitly so compact 72/88px tiers keep its 9-slice caps and
	# do not fall through size inference to a narrow Later/Back plate.
	var respec_button := _make_button("Сброс умений")
	respec_button.name = "AtlasRespecButton"
	respec_button.tooltip_text = "Сбросить все купленные узлы — бесплатно."
	respec_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	respec_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	respec_button.clip_text = false
	UIButtonFamily.assign(respec_button, "text/standard_420x104")
	_set_action_button_size(respec_button, STANDARD_ACTION_BUTTON_WIDTH, atlas_action_h)
	var refresh_respec_geometry := func() -> void:
		var responsive_viewport: Vector2 = game.get_viewport().get_visible_rect().size
		var responsive_height := _atlas_action_button_height()
		var responsive_frame_margins := _scaled_frame_margins_xy(
			ATLAS_FRAME_SOURCE_SIZE, responsive_viewport,
			Vector4(ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN)
		)
		safe.add_theme_constant_override("margin_left", int(responsive_frame_margins.x))
		safe.add_theme_constant_override("margin_top", int(responsive_frame_margins.y * 0.86))
		safe.add_theme_constant_override("margin_right", int(responsive_frame_margins.z))
		safe.add_theme_constant_override("margin_bottom", int(responsive_frame_margins.w * 0.86))
		var responsive_frame := _atlas.get("frame") as Panel
		if responsive_frame != null:
			responsive_frame.add_theme_stylebox_override("panel", _atlas_frame_style(responsive_frame_margins))
		respec_button.custom_minimum_size = Vector2(STANDARD_ACTION_BUTTON_WIDTH, responsive_height)
		# The compact plate has a 30px text zone after its accepted 21px vertical
		# content margins. Its semantic 21px action line keeps the exact 72px hit
		# tier; medium/large tiers retain the accepted 23px compatibility token.
		respec_button.add_theme_font_size_override(
			"font_size",
			maxi(SemanticTypography.role_min(SemanticTypography.ROLE_ACTION), 21)
				if responsive_height <= 72.0
				else _readable_font_size(SemanticTypography.ROLE_ACTION, 16)
		)
	refresh_respec_geometry.call()
	# Keep the visual and hit rectangle at the exact responsive tier. VBox/HBox
	# integer distribution can otherwise donate one spare pixel to this row.
	respec_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	respec_button.pressed.connect(Callable(self, "_atlas_respec_prompt"))
	footer.add_child(respec_button)
	_atlas["respec_button"] = respec_button
	var footer_spacer := Control.new()
	footer_spacer.name = "AtlasFooterSpacer"
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	var legend := HBoxContainer.new()
	legend.name = "AtlasLegend"
	legend.add_theme_constant_override("separation", int(roundf(16.0 * s)))
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(legend)
	_atlas_add_legend_item(legend, META40_STAR_ALLOC_PATH, "куплено", s)
	_atlas_add_legend_item(legend, str(META40_SOCKET_TEXTURES["minor"]), "доступно", s)
	_atlas_add_legend_item(legend, str(META40_SOCKET_TEXTURES["keystone"]), "ключевая", s)
	_atlas_add_legend_item(legend, str(META40_SOCKET_TEXTURES["hidden"]), "скрытая", s)
	# Footer-only live responsiveness: containers reflow automatically; refresh
	# the exact tiered hit height/font when the same Atlas instance is resized.
	root.resized.connect(refresh_respec_geometry)

	# Полая орнаментная рама кита ПОВЕРХ контента (клики сквозь; nearest — чтобы
	# key-цвет прозрачной середины не подмешивался фильтрацией).
	var frame := Panel.new()
	frame.name = "AtlasFrame"
	_atlas["frame"] = frame
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _atlas_frame_style(frame_margins))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(frame)

	# --- Подтверждение респека (поверх рамы) ---
	var respec_popup := PanelContainer.new()
	respec_popup.name = "AtlasRespecPopup"
	respec_popup.visible = false
	respec_popup.custom_minimum_size = Vector2(roundf(clampf(560.0 * s, 380.0, 560.0)), 0.0)
	respec_popup.set_anchors_preset(Control.PRESET_CENTER)
	respec_popup.add_theme_stylebox_override("panel", _atlas_chip_style(0.97, roundf(20.0 * s)))
	respec_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(respec_popup)
	_atlas["respec_popup"] = respec_popup
	var respec_box := VBoxContainer.new()
	respec_box.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	respec_popup.add_child(respec_box)
	var respec_text := Label.new()
	respec_text.name = "AtlasRespecPopupBody"
	respec_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	respec_text.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 16))
	respec_text.add_theme_color_override("font_color", Color(0.92, 0.94, 0.88, 0.96))
	respec_box.add_child(respec_text)
	_atlas["respec_text"] = respec_text
	var respec_actions := HBoxContainer.new()
	respec_actions.alignment = BoxContainer.ALIGNMENT_END
	respec_actions.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	respec_box.add_child(respec_actions)
	var respec_cancel := _make_button("Отмена")
	respec_cancel.name = "AtlasRespecCancelButton"
	_set_action_button_size(respec_cancel, 200.0, 84.0)
	respec_cancel.pressed.connect(Callable(self, "_atlas_respec_cancel"))
	respec_actions.add_child(respec_cancel)
	var respec_confirm := _make_button("Сбросить")
	respec_confirm.name = "AtlasRespecConfirmButton"
	_set_action_button_size(respec_confirm, 200.0, 84.0)
	respec_confirm.pressed.connect(Callable(self, "_atlas_respec_confirm"))
	respec_actions.add_child(respec_confirm)

	_ensure_run_ui_gamepad_bindings()
	_atlas_apply_tab_state()
	_atlas_build_canvas()
	_atlas_refresh()
	_atlas_wire_focus(true)




# Масштаб UI Атласа: min-ось от дизайн-окна 2560×1440 (ассеты кита нарисованы
# ровно под слоты этого окна).
func _atlas_ui_scale() -> float:
	var vp := Vector2(2560.0, 1440.0)
	if game != null and game.get_viewport() != null:
		vp = game.get_viewport().get_visible_rect().size
	return minf(vp.x / 2560.0, vp.y / 1440.0)




func _atlas_socket_scale() -> float:
	var vp := Vector2(2560.0, 1440.0)
	if game != null and game.get_viewport() != null:
		vp = game.get_viewport().get_visible_rect().size
	var compact := clampf((vp.y - 720.0) / 720.0, 0.0, 1.0)
	return _atlas_ui_scale() * lerpf(0.80, 1.0, compact)




func _atlas_action_button_height() -> float:
	var vp_h := 1440.0
	if game != null and game.get_viewport() != null:
		vp_h = game.get_viewport().get_visible_rect().size.y
	if vp_h < 760.0:
		return 72.0
	if vp_h < 1000.0:
		return 88.0
	return STANDARD_ACTION_BUTTON_HEIGHT




# Полая рама Атласа: 9-slice frame_border с draw_center=false (середина ассета —
# key-прозрачность). Margins масштабируются от source→display (паттерн SCRUM-486).
func _atlas_frame_style(margins: Vector4) -> StyleBox:
	var texture: Texture2D = game._cached_texture(META40_FRAME_BORDER_PATH)
	if texture == null:
		return _atlas_chip_style(0.0, 0.0)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.draw_center = false
	return style




# Тёмная кожа + латунный кант (курс SCRUM-806/809, без ярко-жёлтых рамок).
func _atlas_chip_style(alpha: float, pad: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.070, 0.055, alpha)
	style.border_color = Color(0.52, 0.41, 0.24, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = pad * 1.4
	style.content_margin_right = pad * 1.4
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	return style




func _settings_seamless_content_style(pad: float) -> StyleBoxFlat:
	# SCRUM-972: Settings is already inside the fullscreen sanctum shell. Keep a
	# StyleBox owner solely for responsive content margins; drawing another fill
	# or border here makes the center read as a separate gray inset panel.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = pad * 1.4
	style.content_margin_right = pad * 1.4
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	return style




func _atlas_translucent_style(alpha: float, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, alpha)
	style.set_corner_radius_all(int(radius))
	return style




func _atlas_unspent_badge_style(radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.56, 0.14, 0.12, 0.95)
	style.border_color = Color(0.78, 0.56, 0.30, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	return style




func _atlas_make_currency_chip(chip_name: String, icon_path: String, label_name: String, s: float) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_HELP
	chip.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, roundf(10.0 * s)))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.name = "%sIcon" % chip_name
	icon.texture = game._cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := maxf(20.0, roundf(30.0 * s))
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	row.add_child(icon)
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, 16))
	label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.74, 1.0))
	row.add_child(label)
	return chip




func _atlas_add_legend_item(legend: HBoxContainer, icon_path: String, text: String, s: float) -> void:
	var item := HBoxContainer.new()
	item.name = "AtlasLegendItem_%s" % text
	item.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	legend.add_child(item)
	var icon := TextureRect.new()
	icon.texture = game._cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px := maxf(16.0, roundf(26.0 * s))
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(icon)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 13),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94, 0.92))
	item.add_child(label)
