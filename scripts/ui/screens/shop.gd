extends "res://scripts/ui/screens/level_up_cards.gd"

# FAN-3824: модуль распределённого UI-класса — магазин: gold-shell, слоты, тултипы, покупки.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _current_shop_node_key() -> String:
	var act := int(game.current_act)
	var stage := int(game.route_stage)
	var node_type := str(game.current_node_type)
	if node_type == "":
		node_type = "shop"
	var route_choice := str(game.current_route_choice)
	if route_choice == "":
		route_choice = "direct"
	return "%d:%d:%s:%s" % [act, stage, node_type, route_choice]




func _ensure_shop_stock_for_current_node() -> void:
	var node_key := _current_shop_node_key()
	if game.current_shop_node_key == "":
		game.current_shop_node_key = node_key
	var should_generate: bool = game.current_shop_items.is_empty()
	if should_generate:
		game.current_shop_items = _random_shop_items(4)
		game.current_shop_purchased.clear()
	while game.current_shop_purchased.size() < game.current_shop_items.size():
		game.current_shop_purchased.append(false)
	if game.current_shop_purchased.size() > game.current_shop_items.size():
		game.current_shop_purchased.resize(game.current_shop_items.size())




func _clear_current_shop_stock() -> void:
	game.current_shop_items.clear()
	game.current_shop_purchased.clear()
	game.current_shop_node_key = ""




func _shop_gold_shell_base_layout(viewport_size: Vector2) -> Dictionary:
	if viewport_size.y < 900.0:
		return {
			"viewport": Vector2(1280.0, 720.0),
			"inner": Rect2(157, 137, 966, 446),
			"header": Rect2(157, 137, 966, 70),
			"hud": Rect2(181, 147, 480, 50),
			"title": Rect2(675, 137, 330, 34),
			"subtitle": Rect2(675, 173, 330, 24),
			"empty": Rect2(1057, 147, 50, 50),
			"slots": [Rect2(340, 219, 132, 140), Rect2(496, 219, 132, 140), Rect2(652, 219, 132, 140), Rect2(808, 219, 132, 140)],
			# SCRUM-1073: widen the fixed compact tooltip rather than shrinking its
			# semantic typography. Worst-case stock copy reflows to three lines.
			"tooltip": Rect2(290, 361, 700, 148),
			"tooltip_content": Rect2(315, 378, 650, 114),
			"back": Rect2(500, 511, 280, 64),
			"title_font": 24, "subtitle_font": 12, "tooltip_font": 11, "back_font": 20,
		}
	if viewport_size.y >= 1200.0:
		return {
			"viewport": Vector2(2560.0, 1440.0),
			"inner": Rect2(299, 257, 1962, 926),
			"header": Rect2(299, 257, 1962, 120),
			"hud": Rect2(323, 273, 930, 88),
			"title": Rect2(1281, 257, 700, 64),
			"subtitle": Rect2(1281, 327, 700, 40),
			"empty": Rect2(2187, 292, 50, 50),
			"slots": [Rect2(810, 421, 196, 196), Rect2(1058, 421, 196, 196), Rect2(1306, 421, 196, 196), Rect2(1554, 421, 196, 196)],
			"tooltip": Rect2(980, 649, 600, 240),
			"tooltip_content": Rect2(1016, 677, 528, 184),
			"back": Rect2(1100, 1059, 360, 88),
			"title_font": 46, "subtitle_font": 22, "tooltip_font": 17, "back_font": 30,
		}
	return {
		"viewport": Vector2(1920.0, 1080.0),
		"inner": Rect2(224, 193, 1472, 694),
		"header": Rect2(224, 193, 1472, 100),
		"hud": Rect2(248, 209, 720, 72),
		"title": Rect2(996, 193, 560, 52),
		"subtitle": Rect2(996, 251, 560, 32),
		"empty": Rect2(1622, 220, 50, 50),
		"slots": [Rect2(572, 325, 164, 164), Rect2(776, 325, 164, 164), Rect2(980, 325, 164, 164), Rect2(1184, 325, 164, 164)],
		"tooltip": Rect2(690, 513, 540, 200),
		"tooltip_content": Rect2(721, 537, 478, 152),
		"back": Rect2(780, 795, 360, 72),
		"title_font": 37, "subtitle_font": 18, "tooltip_font": 14, "back_font": 26,
	}




func _shop_map_design_rect(design_rect: Rect2, design_inner: Rect2, current_inner: Rect2) -> Rect2:
	var scale := Vector2(
		current_inner.size.x / maxf(design_inner.size.x, 1.0),
		current_inner.size.y / maxf(design_inner.size.y, 1.0)
	)
	return Rect2(
		Vector2(
			roundf(current_inner.position.x + (design_rect.position.x - design_inner.position.x) * scale.x),
			roundf(current_inner.position.y + (design_rect.position.y - design_inner.position.y) * scale.y)
		),
		Vector2(roundf(design_rect.size.x * scale.x), roundf(design_rect.size.y * scale.y))
	)




func _shop_gold_shell_metrics(viewport_size: Vector2) -> Dictionary:
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = game.get_viewport().get_visible_rect().size
	var safe_rect := _unified_safe_rect_for_size(viewport_size)
	var inner_rect := _gold_shell_inner_rect_for_size(viewport_size)
	var base := _shop_gold_shell_base_layout(viewport_size)
	var design_inner: Rect2 = base["inner"]
	var mapped_slots: Array[Rect2] = []
	for design_slot in base["slots"]:
		mapped_slots.append(_shop_map_design_rect(design_slot as Rect2, design_inner, inner_rect))
	var backdrop_scale := minf(safe_rect.size.x / 2560.0, safe_rect.size.y / 1440.0)
	var backdrop_size := Vector2(2560.0, 1440.0) * backdrop_scale
	var visible_backdrop_rect := Rect2(safe_rect.get_center() - backdrop_size * 0.5, backdrop_size)
	return {
		"safe_rect": safe_rect,
		"inner_rect": inner_rect,
		"visible_backdrop_rect": visible_backdrop_rect,
		"header_rect": _shop_map_design_rect(base["header"], design_inner, inner_rect),
		"hud_rect": _shop_map_design_rect(base["hud"], design_inner, inner_rect),
		"title_rect": _shop_map_design_rect(base["title"], design_inner, inner_rect),
		"subtitle_rect": _shop_map_design_rect(base["subtitle"], design_inner, inner_rect),
		"manual_attribute_reserved_empty": _shop_map_design_rect(base["empty"], design_inner, inner_rect),
		"slot_rects": mapped_slots,
		"slot_size": mapped_slots[0].size,
		"tooltip_rect": _shop_map_design_rect(base["tooltip"], design_inner, inner_rect),
		"tooltip_content_rect": _shop_map_design_rect(base["tooltip_content"], design_inner, inner_rect),
		"back_rect": _shop_map_design_rect(base["back"], design_inner, inner_rect),
		"title_font": base["title_font"], "subtitle_font": base["subtitle_font"],
		"tooltip_font": base["tooltip_font"], "back_font": base["back_font"],
	}




func _add_shop_gold_shell_background(root: Control) -> void:
	var underlay := ColorRect.new()
	underlay.name = "ShopGoldUnderlay"
	underlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	underlay.color = Color(0.012, 0.010, 0.016, 1.0)
	underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(underlay)

	var clip := Control.new()
	clip.name = "ShopBackgroundClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.z_index = 1
	root.add_child(clip)

	var background := TextureRect.new()
	background.name = "ShopGoldBackdrop"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.texture = _screen_background_texture("shop")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(background)

	var shade := ColorRect.new()
	shade.name = "ShopGoldReadableShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(shade)




func _layout_shop_gold_shell(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var metrics := _shop_gold_shell_metrics(root.size)
	var safe_rect: Rect2 = metrics["safe_rect"]
	var inner_rect: Rect2 = metrics["inner_rect"]
	root.set_meta("gold_shell_content_rect", safe_rect)
	root.set_meta("gold_shell_inner_rect", inner_rect)
	root.set_meta("scrum993_manual_attribute_reserved_empty", metrics["manual_attribute_reserved_empty"])

	var clip := root.find_child("ShopBackgroundClip", true, false) as Control
	if clip != null:
		_apply_control_rect(clip, safe_rect)
	var backdrop := root.find_child("ShopGoldBackdrop", true, false) as TextureRect
	if backdrop != null:
		backdrop.set_meta("scrum993_visible_image_rect", metrics["visible_backdrop_rect"])
		backdrop.set_meta("scrum993_source_fully_contained", true)

	var header := root.find_child("ShopHeader", true, false) as Control
	var header_rect: Rect2 = metrics["header_rect"]
	if header != null:
		_apply_control_rect(header, header_rect)
	var title := root.find_child("ShopTitleLabel", true, false) as Label
	var title_rect: Rect2 = metrics["title_rect"]
	if title != null:
		_apply_control_rect(title, Rect2(title_rect.position - header_rect.position, title_rect.size))
		title.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, int(metrics["title_font"]), 20, int(metrics["title_font"])))
	var subtitle := root.find_child("ShopSubtitleLabel", true, false) as Label
	var subtitle_rect: Rect2 = metrics["subtitle_rect"]
	if subtitle != null:
		_apply_control_rect(subtitle, Rect2(subtitle_rect.position - header_rect.position, subtitle_rect.size))
		subtitle.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_CAPTION,
			_readable_font_size(SemanticTypography.ROLE_CAPTION, int(metrics["subtitle_font"]), 11, int(metrics["subtitle_font"])),
			SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
		))

	var wall := root.find_child("ShopParchmentWall", true, false) as Control
	if wall != null:
		_apply_control_rect(wall, inner_rect)
	var slots: Array = metrics["slot_rects"]
	for index in range(slots.size()):
		var button := root.find_child("ShopItemButton%d" % index, true, false) as Button
		if button == null:
			continue
		var slot_rect: Rect2 = slots[index]
		_apply_control_rect(button, Rect2(slot_rect.position - inner_rect.position, slot_rect.size))
		_resize_shop_item_slot(button, slot_rect.size)

	var tooltip_panel := root.find_child("ShopTooltipPanel", true, false) as Panel
	var tooltip_rect: Rect2 = metrics["tooltip_rect"]
	if tooltip_panel != null:
		tooltip_panel.add_theme_stylebox_override("panel", _shop_tooltip_texture_style(tooltip_rect.size))
		_apply_control_rect(tooltip_panel, tooltip_rect)
	var tooltip_text := root.find_child("ShopTooltipText", true, false) as Label
	var tooltip_content_rect: Rect2 = metrics["tooltip_content_rect"]
	if tooltip_text != null:
		_apply_control_rect(tooltip_text, Rect2(tooltip_content_rect.position - tooltip_rect.position, tooltip_content_rect.size))
		tooltip_text.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TOOLTIP,
			_readable_font_size(SemanticTypography.ROLE_TOOLTIP, int(metrics["tooltip_font"]), 11, int(metrics["tooltip_font"])),
			SemanticTypography.role_min(SemanticTypography.ROLE_TOOLTIP),
			SemanticTypography.role_max(SemanticTypography.ROLE_TOOLTIP)
		))

	var back := root.find_child("ShopLeaveButton", true, false) as Button
	var back_rect: Rect2 = metrics["back_rect"]
	if back != null:
		_set_action_button_size(back, back_rect.size.x, back_rect.size.y)
		_apply_slim_action_button_theme(back)
		_apply_control_rect(back, back_rect)
		back.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, int(metrics["back_font"]), 16, int(metrics["back_font"])))

	var hud_root := game.hud_layer.find_child("MenuRunHudRoot", true, false) as Control if game.hud_layer != null and is_instance_valid(game.hud_layer) else null
	if hud_root != null:
		_layout_shop_gold_shell_resource_hud_current(hud_root)




func _resize_shop_item_slot(button: Button, display_size: Vector2) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.custom_minimum_size = display_size
	button.size = display_size
	button.clip_contents = true
	_apply_atlas_choice_card_theme(button, _atlas_card_pad(display_size))
	var content := button.find_child("ShopWallItemContent", true, false) as Control
	if content == null:
		return
	var content_scale := minf(display_size.x / SHOP_INLINE_SLOT_SIZE.x, display_size.y / SHOP_INLINE_SLOT_SIZE.y)
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.size = SHOP_INLINE_SLOT_SIZE
	content.custom_minimum_size = SHOP_INLINE_SLOT_SIZE
	content.scale = Vector2(content_scale, content_scale)
	content.position = (display_size - SHOP_INLINE_SLOT_SIZE * content_scale) * 0.5
	content.set_meta("scrum993_uniform_content_scale", content_scale)




func _show_shop_gold_tooltip(root: Control, source: Button) -> void:
	if root == null or source == null or not is_instance_valid(root) or not is_instance_valid(source):
		return
	var panel := root.find_child("ShopTooltipPanel", true, false) as Panel
	var label := root.find_child("ShopTooltipText", true, false) as Label
	if panel == null or label == null:
		return
	label.text = str(source.get_meta("shop_tooltip_text", ""))
	panel.set_meta("shop_tooltip_source", source.name)
	panel.visible = label.text.strip_edges() != ""




func _maybe_hide_shop_gold_tooltip(root: Control, source: Button) -> void:
	call_deferred("_hide_shop_gold_tooltip_if_inactive", root, source)




func _hide_shop_gold_tooltip_if_inactive(root: Control, source: Button) -> void:
	if root == null or source == null or not is_instance_valid(root) or not is_instance_valid(source):
		return
	if source.has_focus() or source.get_global_rect().has_point(source.get_global_mouse_position()):
		return
	var panel := root.find_child("ShopTooltipPanel", true, false) as Panel
	if panel != null and str(panel.get_meta("shop_tooltip_source", "")) == str(source.name):
		panel.visible = false




func _show_shop_screen() -> void:
	_ensure_shop_stock_for_current_node()

	var money := _run_money()
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "ShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)

	var initial_metrics := _shop_gold_shell_metrics(root.size)
	root.set_meta("gold_shell_content_rect", initial_metrics["safe_rect"])
	root.set_meta("gold_shell_inner_rect", initial_metrics["inner_rect"])
	root.set_meta("gold_shell_screen_id", "shop")
	_add_shop_gold_shell_background(root)
	_create_menu_run_hud()

	var title_box := Control.new()
	title_box.name = "ShopHeader"
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.z_index = 20
	root.add_child(title_box)

	var title := Label.new()
	title.name = "ShopTitleLabel"
	title.text = "Магазин"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		_readable_font_size(SemanticTypography.ROLE_TITLE, 42),
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "ShopSubtitleLabel"
	subtitle.text = "Выбери предмет — описание появится ниже."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.clip_text = true
	subtitle.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 16, 12),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	title_box.add_child(subtitle)

	# Товары лежат в центральной свободной зоне shop backdrop как предметы
	# лавки, а не как UI-карточки.
	var wall := Control.new()
	wall.name = "ShopParchmentWall"
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.z_index = 20
	root.add_child(wall)

	var items_area := Control.new()
	items_area.name = "ShopInlineItems"
	items_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	items_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.add_child(items_area)

	for index in range(game.current_shop_items.size()):
		var item: Dictionary = game.current_shop_items[index]
		var slot := _make_shop_item_slot(item, index, money, initial_metrics["slot_size"])
		items_area.add_child(slot)

	# SCRUM-993: описание не следует за курсором и не может попасть на орнамент.
	# Один фиксированный tooltip-band расположен под четырьмя товарами.
	var tooltip_panel := Panel.new()
	tooltip_panel.name = "ShopTooltipPanel"
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 30
	tooltip_panel.visible = false
	var tooltip_style := _shop_tooltip_texture_style(initial_metrics["tooltip_rect"].size)
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style if tooltip_style != null else _atlas_chip_style(0.96, 10.0))
	root.add_child(tooltip_panel)

	var tooltip_text := Label.new()
	tooltip_text.name = "ShopTooltipText"
	tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tooltip_text.clip_text = true
	tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78, 1.0))
	tooltip_panel.add_child(tooltip_text)

	for slot_node in items_area.get_children():
		var slot := slot_node as Button
		if slot == null:
			continue
		slot.mouse_entered.connect(_show_shop_gold_tooltip.bind(root, slot))
		slot.focus_entered.connect(_show_shop_gold_tooltip.bind(root, slot))
		slot.mouse_exited.connect(_maybe_hide_shop_gold_tooltip.bind(root, slot))
		slot.focus_exited.connect(_maybe_hide_shop_gold_tooltip.bind(root, slot))

	var skip_button := _make_button("Назад")
	skip_button.name = "ShopLeaveButton"
	skip_button.tooltip_text = "Покинуть магазин и продолжить маршрут."
	var leave_shop := func() -> void:
		# SCRUM-996: событийный магазин (shop_after) продолжает событийный путь
		# (advance/пост-боевой возврат с автосейвом); обычный узел-магазин —
		# прежний выход с возможностью повторного входа на узел.
		if game.event_shop_exit_action.is_valid():
			var exit_action: Callable = game.event_shop_exit_action
			game.event_shop_exit_action = Callable()
			exit_action.call()
		else:
			game.route._return_to_map_after_shop_visit()
	skip_button.pressed.connect(leave_shop)
	# SCRUM-968: «Назад» из магазина — выход/закрытие экрана → ui_back.
	_connect_ui_sfx(skip_button, "back")
	game.ui_escape_action = leave_shop
	skip_button.z_index = 20
	root.add_child(skip_button)

	# SCRUM-812: товары проходимы с геймпада (крестовина/стик), «Назад» доступна ui_down,
	# покупка по A. Стартовый фокус — первый доступный товар (иначе «Назад»). Соседи между
	# анкер-размещёнными слотами Godot добирает по геометрии.
	var shop_focus_items: Array = []
	for slot in items_area.get_children():
		if slot is Button and not (slot as Button).disabled:
			shop_focus_items.append(slot)
	_wire_run_ui_focus(shop_focus_items, true, [skip_button],
		shop_focus_items[0] if not shop_focus_items.is_empty() else skip_button)

	_layout_shop_gold_shell(root)
	root.resized.connect(func() -> void:
		_layout_shop_gold_shell(root)
		call_deferred("_layout_shop_gold_shell", root)
	)
	# Visual-only hollow frame must remain the final UI child.
	var frame := _unified_add_frame(root, "ShopGold")
	frame.z_index = 100




func _make_shop_item_slot(item: Dictionary, index: int, money: int, display_size := SHOP_INLINE_SLOT_SIZE) -> Button:
	var purchased: bool = index < game.current_shop_purchased.size() and bool(game.current_shop_purchased[index])
	var cost := int(item.get("cost", 0))
	var affordable := money >= cost
	var button := Button.new()
	button.name = "ShopItemButton%d" % index
	button.custom_minimum_size = display_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	button.tooltip_text = ""
	button.set_meta("shop_tooltip_text", _shop_item_tooltip(item, purchased, affordable))
	if str(item.get("kind", "")) == "artifact":
		var affinity_note := _artifact_affinity_note(item)
		if not affinity_note.is_empty():
			# SCRUM-963: бейдж «!» — только на выпадении ЧУЖОГО класса (cross-class
			# слот «Украденного герба»); свой классовый артефакт — штатный товар,
			# пометка живёт в тултипе без тревожного маркера.
			var affinity_list: Array = item.get("class_affinity", [])
			if not affinity_list.has(game.selected_character_id):
				var note_label := Label.new()
				note_label.name = "ShopAffinityNote"
				note_label.text = "!"
				note_label.tooltip_text = str(affinity_note["text"])
				note_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
					SemanticTypography.ROLE_BODY,
					_readable_font_size(SemanticTypography.ROLE_BODY, 22),
					SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
					SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
				))
				note_label.add_theme_color_override("font_color", affinity_note["color"])
				note_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				note_label.offset_left = -26.0
				note_label.offset_top = 4.0
				note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				button.add_child(note_label)
	# SCRUM-883: слот товара — чип-ряд Атласа (StyleBoxFlat, hover — золотой кант);
	# внутренности слота (иконка, пергамент-плашка, ценник) сохранены.
	_apply_atlas_choice_card_theme(button, _atlas_card_pad(display_size))
	button.pressed.connect(func() -> void:
		# SCRUM-968: успех покупки → purchase, отказ (не хватает золота) → ui_error.
		if _buy_shop_item_at(index):
			game._play_sfx("purchase")
		else:
			game._play_sfx("ui_error")
	)

	if purchased:
		button.disabled = true
		_add_shop_empty_hook(button)
		return button

	var content := Control.new()
	content.name = "ShopWallItemContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.size = SHOP_INLINE_SLOT_SIZE
	content.custom_minimum_size = SHOP_INLINE_SLOT_SIZE
	button.add_child(content)
	_resize_shop_item_slot(button, display_size)

	var shadow := PanelContainer.new()
	shadow.name = "ShopItemContactShadow"
	shadow.anchor_left = 0.5
	shadow.anchor_top = 0.0
	shadow.anchor_right = 0.5
	shadow.anchor_bottom = 0.0
	shadow.offset_left = -46.0
	shadow.offset_top = 88.0
	shadow.offset_right = 46.0
	shadow.offset_bottom = 106.0
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", _shop_item_shadow_style())
	content.add_child(shadow)

	var icon := TextureRect.new()
	icon.name = "ShopItemIcon"
	icon.texture = _shop_item_icon_texture(item)
	icon.custom_minimum_size = SHOP_INLINE_ICON_SIZE
	icon.anchor_left = 0.5
	icon.anchor_top = 0.0
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.0
	icon.offset_left = -SHOP_INLINE_ICON_SIZE.x * 0.5
	icon.offset_top = SHOP_INLINE_ICON_TOP
	icon.offset_right = SHOP_INLINE_ICON_SIZE.x * 0.5
	icon.offset_bottom = SHOP_INLINE_ICON_TOP + SHOP_INLINE_ICON_SIZE.y
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.52, 0.48, 0.45, 0.82)
	content.add_child(icon)

	# SCRUM-567: фикс-размерная подпись названия товара в верхней полосе слота —
	# превращает «голую стену иконок» в читаемую сетку товаров (название видно
	# сразу, полное описание по-прежнему в тултипе). Размер фиксирован
	# (SHOP_INLINE_CAPTION_SIZE), длинный текст ужимается clip в 1 строку, рамку
	# не растягивает и из слота не вылазит.
	# 9-slice плашка-нейм-плейт под подписью (отдельный ассет в едином стиле).
	var plate_texture: Texture2D = game._cached_texture(SHOP_CAPTION_PLATE_PATH)
	if plate_texture != null:
		var plate := NinePatchRect.new()
		plate.name = "ShopItemCaptionPlate"
		plate.texture = plate_texture
		# Source rails are authored at 1728x624. Their raw 150px values would
		# force a 300x300 minimum into a 140x20 runtime label, so scale the
		# 9-slice margins to the actual caption plate before assigning them.
		var plate_margins := _scaled_frame_margins(Vector2(1728.0, 624.0), SHOP_INLINE_CAPTION_SIZE, SHOP_CAPTION_PLATE_MARGINS)
		plate.patch_margin_left = int(roundf(plate_margins.x))
		plate.patch_margin_top = int(roundf(plate_margins.y))
		plate.patch_margin_right = int(roundf(plate_margins.z))
		plate.patch_margin_bottom = int(roundf(plate_margins.w))
		plate.anchor_left = 0.5
		plate.anchor_top = 0.0
		plate.anchor_right = 0.5
		plate.anchor_bottom = 0.0
		plate.offset_left = -SHOP_INLINE_CAPTION_SIZE.x * 0.5
		plate.offset_top = SHOP_INLINE_CAPTION_TOP
		plate.offset_right = SHOP_INLINE_CAPTION_SIZE.x * 0.5
		plate.offset_bottom = SHOP_INLINE_CAPTION_TOP + SHOP_INLINE_CAPTION_SIZE.y
		plate.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.82, 0.78, 0.72, 0.82)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(plate)

	var caption := Label.new()
	caption.name = "ShopItemCaption"
	caption.text = str(item.get("title", "Предмет"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.max_lines_visible = 1
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Текст ужимаем по ширине парчмент-центра плашки (≈ −16px от полной ширины).
	caption.custom_minimum_size = Vector2(SHOP_INLINE_CAPTION_SIZE.x - 16.0, SHOP_INLINE_CAPTION_SIZE.y)
	caption.anchor_left = 0.5
	caption.anchor_top = 0.0
	caption.anchor_right = 0.5
	caption.anchor_bottom = 0.0
	caption.offset_left = -(SHOP_INLINE_CAPTION_SIZE.x - 16.0) * 0.5
	caption.offset_top = SHOP_INLINE_CAPTION_TOP
	caption.offset_right = (SHOP_INLINE_CAPTION_SIZE.x - 16.0) * 0.5
	caption.offset_bottom = SHOP_INLINE_CAPTION_TOP + SHOP_INLINE_CAPTION_SIZE.y
	caption.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 13),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	caption.add_theme_color_override("font_color", Color(0.96, 0.82, 0.48, 1.0) if affordable else Color(0.70, 0.66, 0.60, 0.90))
	caption.add_theme_color_override("font_outline_color", Color(0.08, 0.045, 0.02, 0.96))
	caption.add_theme_constant_override("outline_size", 2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)

	var price_badge := Panel.new()
	price_badge.name = "ShopPriceBadge"
	price_badge.anchor_left = 0.5
	price_badge.anchor_top = 1.0
	price_badge.anchor_right = 0.5
	price_badge.anchor_bottom = 1.0
	price_badge.offset_left = -64.0
	price_badge.offset_top = -52.0
	price_badge.offset_right = 64.0
	price_badge.offset_bottom = -12.0
	price_badge.custom_minimum_size = Vector2(128, 40)
	price_badge.clip_contents = true
	price_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_badge.add_theme_stylebox_override("panel", _shop_price_badge_style(affordable))
	content.add_child(price_badge)

	var price_row := HBoxContainer.new()
	price_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	price_row.offset_left = 16.0
	price_row.offset_top = 8.0
	price_row.offset_right = -16.0
	price_row.offset_bottom = -8.0
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_badge.add_child(price_row)

	var money_icon := TextureRect.new()
	money_icon.name = "ShopPriceMoneyIcon"
	money_icon.texture = game.UIIconRegistry.texture_for("money")
	money_icon.custom_minimum_size = Vector2(16, 16)
	money_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(money_icon)

	var price_label := Label.new()
	price_label.name = "ShopItemPrice"
	price_label.text = "%d" % cost
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, 16, 12, 18))
	price_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0) if affordable else Color(1.0, 0.42, 0.42, 1.0))
	price_row.add_child(price_label)

	# Unaffordable products remain fully legible/focusable: the icon tint, red
	# price and fixed tooltip communicate the state without covering the item.
	return button




func _shop_wall_slot_anchor(index: int) -> Vector2:
	var anchors := [
		Vector2(0.30, 0.18),
		Vector2(0.70, 0.18),
		Vector2(0.30, 0.84),
		Vector2(0.70, 0.84),
	]
	return anchors[index % anchors.size()]




func _add_shop_empty_hook(button: Button) -> void:
	var hook := PanelContainer.new()
	hook.name = "ShopEmptyHook"
	hook.anchor_left = 0.5
	hook.anchor_top = 0.5
	hook.anchor_right = 0.5
	hook.anchor_bottom = 0.5
	hook.offset_left = -34.0
	hook.offset_top = -18.0
	hook.offset_right = 34.0
	hook.offset_bottom = 18.0
	hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook.add_theme_stylebox_override("panel", _shop_empty_hook_style())
	button.add_child(hook)

	var label := Label.new()
	label.text = "снято"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_BODY, 13))
	label.add_theme_color_override("font_color", Color(0.40, 0.30, 0.20, 0.78))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook.add_child(label)




func _add_shop_state_overlay(button: Button, text: String) -> void:
	var overlay := Panel.new()
	overlay.name = "ShopItemStateOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("panel", _shop_purchased_overlay_style())
	button.add_child(overlay)

	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_BODY, 15, 12, 17))
	label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	overlay.add_child(label)




func _shop_item_tooltip(item: Dictionary, purchased: bool, affordable: bool) -> String:
	var lines := [
		str(item.get("title", "Предмет")),
		str(item.get("description", "")),
	]
	var detail_line := "Цена: %dg" % int(item.get("cost", 0))
	var class_text := _shop_item_classes_text(item)
	if class_text != "":
		detail_line += " · Класс: %s" % class_text
	lines.append(detail_line)
	var state_parts: Array[String] = []
	if str(item.get("kind", "")) == "artifact":
		state_parts.append(_artifact_tier_text(item))
	if purchased:
		state_parts.append("Уже куплено")
	elif not affordable:
		state_parts.append("Не хватает монет")
	if not state_parts.is_empty():
		lines.append(" · ".join(state_parts))
	return "\n".join(lines)




func _shop_item_classes_text(item: Dictionary) -> String:
	var classes: Array = item.get("classes", [])
	if classes.is_empty():
		classes = item.get("class_affinity", [])
	if classes.is_empty():
		return ""
	var titles := []
	for character_id in classes:
		var config: Dictionary = game.PROGRESSION_DATA.character_config(str(character_id))
		titles.append(str(config.get("title", character_id)))
	return ", ".join(titles)




func _shop_item_icon_texture(item: Dictionary) -> Texture2D:
	var dedicated_path := _shop_item_icon_path(item)
	var dedicated_texture: Texture2D = game._cached_texture(dedicated_path)
	if dedicated_texture != null:
		return dedicated_texture
	return game.UIIconRegistry.texture_for(_shop_item_fallback_icon_id(item))




func _shop_item_icon_path(item: Dictionary) -> String:
	var item_id := str(item.get("id", ""))
	if item_id == "":
		return ""
	if str(item.get("kind", "")) == "artifact" or not item_id.begins_with("shop_"):
		return "%sartifact_%s.png" % [ARTIFACT_ICON_DIR, item_id]
	return "%sshop_%s.png" % [SHOP_ICON_DIR, item_id]




func _shop_item_fallback_icon_id(item: Dictionary) -> String:
	var stats: Dictionary = item.get("stats", {})
	for stat_id in game.UIIconRegistry.BASE_STAT_IDS:
		if stats.has(stat_id):
			return stat_id

	var modifiers: Dictionary = item.get("mods", {})
	if item.has("heal_percent") or modifiers.has("max_health_flat") or modifiers.has("max_health_multiplier"):
		return "health_point"
	if modifiers.has("attack_speed_multiplier"):
		return "attack_speed"
	if modifiers.has("move_speed_multiplier"):
		return "move_speed"
	if modifiers.has("pickup_radius_flat"):
		return "pickup_radius"
	if modifiers.has("aoe_radius_multiplier"):
		return "aoe_radius"
	if modifiers.has("crit_chance_flat") or modifiers.has("crit_damage_flat"):
		return "crit_chance"
	if modifiers.has("defense_flat"):
		return "defense"
	if modifiers.has("summon_bonus"):
		return "summon_amount"
	if modifiers.has("knockback_multiplier"):
		return "knockback_power"

	var classes: Array = item.get("classes", [])
	if classes.has("dark_mage"):
		return "magic_damage"
	if classes.has("guitarist"):
		return "magic_damage"
	if modifiers.has("money_gain_multiplier"):
		return "money"
	if modifiers.has("xp_gain_multiplier"):
		return "xp"
	if modifiers.has("damage_multiplier"):
		return "damage"
	return "artifact"




func _shop_item_shadow_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.016, 0.38)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(16)
	return style




func _shop_empty_hook_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.075, 0.050, 0.22)
	style.border_color = Color(0.18, 0.13, 0.08, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style




func _shop_price_badge_style(affordable := true) -> StyleBox:
	var display_size := Vector2(128.0, 40.0)
	# The visible rails in the 256x96 source are ~24x14px. The older economy
	# constants described a much larger generic safe zone and expanded this
	# compact 128x40 badge past its product slot. Keep four runtime pixels of
	# reserve beyond the scaled rails while leaving 20px for icon/text.
	var texture_margins := _scaled_frame_margins(Vector2(256.0, 96.0), display_size, Vector4(24.0, 14.0, 24.0, 14.0))
	var content_margins := _scaled_frame_margins(Vector2(256.0, 96.0), display_size, Vector4(32.0, 19.2, 32.0, 19.2))
	var tint := Color.WHITE if affordable else Color(0.76, 0.55, 0.55, 0.92)
	var texture_style := _global_texture_style(ECONOMY_PRICE_BADGE_PATH, texture_margins, tint, content_margins)
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.055, 0.035, 0.78) if affordable else Color(0.20, 0.055, 0.050, 0.82)
	style.border_color = Color(0.72, 0.48, 0.16, 0.72) if affordable else Color(0.96, 0.30, 0.26, 0.76)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 5
	style.content_margin_top = 3
	style.content_margin_right = 6
	style.content_margin_bottom = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style




func _shop_purchased_overlay_style() -> StyleBox:
	var texture_style := _shop_texture_style(SHOP_PURCHASED_OVERLAY_PATH, Vector2(18, 18))
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.030, 0.68)
	style.border_color = Color(0.36, 0.48, 0.52, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style




func _shop_texture_style(path: String, margin: Vector2) -> StyleBoxTexture:
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin.x
	style.texture_margin_top = margin.y
	style.texture_margin_right = margin.x
	style.texture_margin_bottom = margin.y
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style




func _shop_tooltip_texture_style(display_size: Vector2) -> StyleBox:
	# The 640x320 source frame is displayed at three authored sizes. Scale its
	# decorative rails with the actual panel instead of keeping the 2K margins
	# at 720p; reserve four additional pixels before any text starts.
	var rail := Vector2(
		maxf(12.0, roundf(display_size.x * 0.05)),
		maxf(10.0, roundf(display_size.y * 0.10))
	)
	var content := Vector4(rail.x + 4.0, rail.y + 4.0, rail.x + 4.0, rail.y + 4.0)
	var texture: Texture2D = game._cached_texture(SHOP_TOOLTIP_FRAME_PATH)
	if texture == null:
		var fallback := _atlas_chip_style(0.96, 10.0)
		fallback.content_margin_left = content.x
		fallback.content_margin_top = content.y
		fallback.content_margin_right = content.z
		fallback.content_margin_bottom = content.w
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = rail.x
	style.texture_margin_top = rail.y
	style.texture_margin_right = rail.x
	style.texture_margin_bottom = rail.y
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style




func _apply_slim_action_button_theme(button: Button) -> void:
	# Compact economy actions are a semantic action family, not rebind fields.
	# The registry owns their accepted slim-source alias and safe margins.
	_apply_fantasy_button_theme(button, "default", UIButtonFamily.FAMILY_SLIM_ACTION)
