extends "res://scripts/ui/screens/hero_select.gd"

# FAN-3824: модуль распределённого UI-класса — лавка характеристик и цены вознесения.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _ascension_price(base: int) -> int:
	# Ветвь Богатства мета-древа (SCRUM-150): удешевление докачки атрибутов
	# (attr_cost_mult ≤ 0). Используется только ценами докачки, не магазином.
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	var discount := maxf(1.0 + float(skill_mods.get("attr_cost_mult", 0.0)), 0.1)
	return maxi(1, int(round(float(base) * float(game.ascension_difficulty()["price_mult"]) * discount)))




func _attribute_buy_cost() -> int:
	var scaling_stage: int = game.route_scaling_stage()
	return _ascension_price(game.PROGRESSION_DATA.stage_scaled_cost(ATTRIBUTE_BUY_BASE_COST + ATTRIBUTE_BUY_STAGE_COST * scaling_stage, scaling_stage))




func _attribute_reroll_cost() -> int:
	var scaling_stage: int = game.route_scaling_stage()
	return _ascension_price(game.PROGRESSION_DATA.stage_scaled_cost(ATTRIBUTE_REROLL_BASE_COST + ATTRIBUTE_REROLL_STAGE_COST * scaling_stage, scaling_stage))




# FAN-1887: пул базовых характеристик Докачки с consumability-фильтром — Лидерство
# предлагается только фактически summon/deploy-способным классам (data-driven,
# ProgressionData.is_base_stat_consumable); ряд перецентровывается после фильтра.
# FAN-1927 (спека AS, eligible_stat_ids): характеристика с нулевым итогом —
# +1 не меняет НИ ОДНУ player-facing ось текущего класса/оружия (cap/no-op) —
# отсеивается ДО построения AttributeOffers и не резервирует ряд.
func _attribute_shop_stat_pool() -> Array:
	var pool: Array = []
	for stat_id in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
		if not game.PROGRESSION_DATA.is_base_stat_consumable(stat_id, game.selected_character_id):
			continue
		if not _attribute_shop_stat_eligible(str(stat_id)):
			continue
		pool.append(stat_id)
	return pool




func _attribute_shop_stat_eligible(stat_id: String) -> bool:
	return AttributeSurfaces.shop_stat_eligible(
		game.selected_character_id, _active_stats_snapshot(), _active_modifiers_snapshot(), _active_weapon_config(), stat_id)




func _random_attribute_pair() -> Array:
	var pool := _attribute_shop_stat_pool()
	# Ветвь Знаний мета-древа (SCRUM-150): attr_extra_options добавляет варианты
	# в окне докачки (по умолчанию 2 — обратная совместимость).
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	var option_count: int = clampi(2 + int(skill_mods.get("attr_extra_options", 0.0)), 2, pool.size())
	var pair := []
	for _pick in range(option_count):
		var index: int = game.rng.randi_range(0, pool.size() - 1)
		pair.append(pool[index])
		pool.remove_at(index)
	return pair



func _normalize_attribute_offer(saved_offer: Array) -> Array:
	# Old saves and automation fixtures may contain duplicate, removed or 4+
	# entries. Preserve canonical entries in order, then fill to the live 2/3
	# contract without ever overflowing the authored three-card row.
	var pool := _attribute_shop_stat_pool()
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	var option_count: int = clampi(2 + int(skill_mods.get("attr_extra_options", 0.0)), 2, 3)
	var normalized: Array = []
	for raw_offer in saved_offer:
		var stat_id := str((raw_offer as Dictionary).get("id", "")) if raw_offer is Dictionary else str(raw_offer)
		if not pool.has(stat_id):
			continue
		normalized.append((raw_offer as Dictionary).duplicate(true) if raw_offer is Dictionary else stat_id)
		pool.erase(stat_id)
		if normalized.size() >= option_count:
			return normalized
	while normalized.size() < option_count and not pool.is_empty():
		var index: int = game.rng.randi_range(0, pool.size() - 1)
		normalized.append(pool[index])
		pool.remove_at(index)
	return normalized



func _attribute_shop_layout_for_size(viewport_size: Vector2) -> Dictionary:
	# FAN-1927: раскладка (включая AS.DetailDrawer) извлечена в AttributeSurfaces
	# по monolith-ратчету; rect-провайдеры экрана остаются здесь.
	return AttributeSurfaces.shop_layout(
		viewport_size,
		_unified_safe_rect_for_size(viewport_size),
		_gold_shell_inner_rect_for_size(viewport_size)
	)



func _apply_attribute_shop_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	# SCRUM-1073: labels may have a larger intrinsic minimum after semantic
	# floors are enforced. Their authored card lane is the clipping/wrap owner;
	# do not let the intrinsic minimum push the Control outside that lane.
	control.custom_minimum_size = Vector2.ZERO if control is Label else rect.size
	control.size = rect.size
	if control is Label:
		(control as Label).clip_text = true




func _layout_attribute_shop(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var layout := _attribute_shop_layout_for_size(root.size)
	root.set_meta("gold_shell_content_rect", layout["safe_rect"])
	root.set_meta("gold_shell_inner_rect", layout["inner_rect"])
	root.set_meta("attribute_shop_tooltip_host_rect", layout["tooltip_host_rect"])
	var title := root.find_child("AttributeShopTitle", true, false) as Label
	var money := root.find_child("AttributeShopMoney", true, false) as Label
	var offers := root.find_child("AttributeOffers", true, false) as HBoxContainer
	var actions := root.find_child("AttributeShopActions", true, false) as HBoxContainer
	_apply_attribute_shop_rect(title, layout["title_rect"])
	_apply_attribute_shop_rect(money, layout["money_rect"])
	_apply_attribute_shop_rect(offers, layout["offers_rect"])
	_apply_attribute_shop_rect(actions, layout["actions_rect"])
	var drawer := root.find_child("AttributeShopDetailDrawer", true, false) as PanelContainer
	if drawer != null:
		var drawer_rect: Rect2 = layout.get("drawer_rect", Rect2())
		var compact_drawer := root.size.y < 1000.0
		drawer.visible = drawer_rect.size.y > 0.0 and (not compact_drawer or bool(drawer.get_meta("detail_drawer_open", false)))
		drawer.set_meta("production_tooltip_host", true)
		if drawer_rect.size.y > 0.0:
			_apply_attribute_shop_rect(drawer, drawer_rect)
	if title != null:
		title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TITLE, int(clampf(roundf((layout["title_rect"] as Rect2).size.y * 0.58), 24.0, 42.0))
		))
	if money != null:
		money.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_VALUE,
			int(clampf(roundf((layout["money_rect"] as Rect2).size.y * 0.34), 12.0, 22.0)),
			SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
			SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
		))
	if offers != null:
		offers.add_theme_constant_override("separation", int(roundf(float(layout["offer_gap"]))))
		for child in offers.get_children():
			if child is Button:
				var offer_button := child as Button
				offer_button.custom_minimum_size = layout["offer_size"]
				offer_button.size = layout["offer_size"]
				_apply_atlas_choice_card_theme(offer_button, _atlas_card_pad(layout["offer_size"]))
				_layout_attribute_offer_card(offer_button)
				_layout_attribute_offer_card.call_deferred(offer_button)
	if actions != null:
		actions.add_theme_constant_override("separation", int(roundf(float(layout["action_gap"]))))
		for action_child in actions.get_children():
			if action_child is Button:
				var action_button := action_child as Button
				action_button.custom_minimum_size = layout["action_size"]
				action_button.size = layout["action_size"]
				action_button.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
					SemanticTypography.ROLE_ACTION,
					int(clampf(roundf((layout["action_size"] as Vector2).y * 0.27), 14.0, 24.0)),
					SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
					SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
				))
				# Compact authored action band: avoid the 104px global button plate
				# expanding the HBox beyond the gold-shell inner rect at 720p.
				_apply_slim_action_button_theme(action_button)
	var frame := root.find_child("AttributeShopFrame", false, false) as Panel
	if frame != null:
		root.move_child(frame, root.get_child_count() - 1)




func _show_attribute_shop(on_done: Callable) -> void:
	# SCRUM-982/987/988: mandatory post-combat gold shop. Manual Route/Rest entry
	# is removed; this screen remains the victory continuation for 2 default or
	# 3 Atlas offers in one row inside the shared hollow gold shell.
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "AttributeShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, "meta_progression")

	var shade := ColorRect.new()
	shade.name = "AttributeShopReadableShade"
	shade.color = Color(0.02, 0.025, 0.045, 0.20)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var title := Label.new()
	title.name = "AttributeShopTitle"
	title.text = "Докачка"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	var money_label := Label.new()
	money_label.name = "AttributeShopMoney"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(money_label)

	var offers_box := HBoxContainer.new()
	offers_box.name = "AttributeOffers"
	offers_box.alignment = BoxContainer.ALIGNMENT_CENTER
	offers_box.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(offers_box)
	var actions := HBoxContainer.new()
	actions.name = "AttributeShopActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(actions)

	var reroll_button := _make_button("")
	reroll_button.name = "AttributeRerollButton"
	_apply_slim_action_button_theme(reroll_button)
	actions.add_child(reroll_button)
	var skip_button := _make_button("Пропустить")
	skip_button.name = "AttributeSkipButton"
	_apply_slim_action_button_theme(skip_button)
	actions.add_child(skip_button)
	# FAN-1966: placement of the full-copy production disclosure host.
	var detail_drawer_nodes := AttributeSurfaces.make_detail_drawer("AttributeShop", _atlas_chip_style(0.88, 10.0))
	root.add_child(detail_drawer_nodes["panel"] as Control)
	# Набор и счетчик rerolls живут в game-state: повторный runtime вызов не дает
	# бесплатного реролла; сброс — только в победном флоу нового боя. Legacy and
	# malformed saved arrays are canonicalized to the same strict 2/3 contract.
	game.attribute_offer = _normalize_attribute_offer(game.attribute_offer)
	skip_button.pressed.connect(func() -> void:
		if on_done.is_valid():
			on_done.call()
	)
	# SCRUM-968: «Пропустить» докачку — отмена/закрытие → ui_back.
	_connect_ui_sfx(skip_button, "back")
	reroll_button.pressed.connect(func() -> void:
		if game.attribute_rerolls_left <= 0 or not _spend_run_money(_attribute_reroll_cost()):
			# SCRUM-968: реролл недоступен / нет золота — отказ.
			game._play_sfx("ui_error")
			return
		# SCRUM-968: платный реролл характеристик — трата золота.
		game._play_sfx("purchase")
		game.attribute_rerolls_left -= 1
		game.attribute_offer = _random_attribute_pair()
		_refresh_attribute_shop(root, on_done)
	)
	game.ui_escape_action = skip_button.pressed.emit
	_unified_add_frame(root, "AttributeShop")
	_layout_attribute_shop(root)
	root.resized.connect(func() -> void:
		_layout_attribute_shop(root)
		_layout_attribute_shop.call_deferred(root)
	)
	_refresh_attribute_shop(root, on_done)




func _make_attribute_offer_card(stat_id: String, stat_title: String, interpretation: String, influence_text: String, preview_lines: Array, buy_cost: int, display_size: Vector2) -> Button:
	var button := Button.new()
	button.name = "AttributeOffer_%s" % stat_id
	button.text = ""
	button.custom_minimum_size = display_size
	button.size = display_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("attribute_stat_id", stat_id)
	button.set_meta("economy_display_size", display_size)
	var card_pad := _atlas_card_pad(display_size)
	button.set_meta("economy_content_margins", _atlas_chip_content_margins(card_pad))
	_apply_atlas_choice_card_theme(button, card_pad)

	var icon_control: Control = game.UIIconRegistry.make_icon(stat_id, Vector2(32, 32))
	icon_control.name = "%sIcon" % button.name
	icon_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon_control)

	var title_label := Label.new()
	title_label.name = "%sTitle" % button.name
	title_label.text = "%s  +1" % stat_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title_label)

	var interpretation_label := Label.new()
	interpretation_label.name = "%sInterpretation" % button.name
	interpretation_label.text = interpretation
	interpretation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interpretation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interpretation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interpretation_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	interpretation_label.max_lines_visible = 2
	interpretation_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 1.0))
	interpretation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(interpretation_label)

	var influence_label := Label.new()
	influence_label.name = "%sInfluence" % button.name
	influence_label.text = "Влияет на: %s" % (influence_text if influence_text != "" else "базовую характеристику")
	influence_label.set_meta("full_text", influence_label.text)
	influence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	influence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	influence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	influence_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.96, 1.0))
	influence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(influence_label)

	var preview_label := Label.new()
	preview_label.name = "%sPreview" % button.name
	preview_label.text = "\n".join(preview_lines) if not preview_lines.is_empty() else "+1 к базовой характеристике"
	preview_label.set_meta("full_text", preview_label.text)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(preview_label)

	var price_label := Label.new()
	price_label.name = "%sAction" % button.name
	price_label.text = "%d зол." % buy_cost
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(price_label)

	button.resized.connect(_layout_attribute_offer_card.bind(button))
	_layout_attribute_offer_card(button)
	return button




func _layout_attribute_offer_card(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var display_size := button.size
	if display_size.x <= 1.0 or display_size.y <= 1.0:
		display_size = button.custom_minimum_size
	var pad := _atlas_card_pad(display_size)
	var margins := _atlas_chip_content_margins(pad)
	button.set_meta("economy_display_size", display_size)
	button.set_meta("economy_content_margins", margins)
	var content_rect := Rect2(
		Vector2(margins.x, margins.y),
		Vector2(maxf(1.0, display_size.x - margins.x - margins.z), maxf(1.0, display_size.y - margins.y - margins.w))
	)
	button.set_meta("attribute_content_rect", content_rect)
	var gap := clampf(roundf(content_rect.size.y * 0.012), 2.0, 6.0)
	var icon_side := clampf(roundf(content_rect.size.y * 0.14), 26.0, 56.0)
	var title_h := clampf(roundf(content_rect.size.y * 0.11), 20.0, 48.0)
	var interpretation_h := clampf(roundf(content_rect.size.y * 0.12), 24.0, 58.0)
	var influence_h := clampf(roundf(content_rect.size.y * 0.22), 38.0, 96.0)
	var price_h := clampf(roundf(content_rect.size.y * 0.12), 22.0, 48.0)
	if display_size.y >= 230.0 and display_size.y <= 240.0:
		# Approved 720p plan: 11px minimum body copy, two interpretation lines,
		# a full wrapped influence block and four derived preview lines all fit.
		# The decorative stat icon yields its compact slot to copy at this tier.
		icon_side = 0.0
		title_h = 32.0
		interpretation_h = 38.0
		influence_h = 50.0
		price_h = 24.0
	elif display_size.y <= 410.0:
		# At the 1080p tier the icon is redundant with the title and tooltip;
		# yield its lane to the four semantic-size derived preview rows.
		icon_side = 0.0
	var fixed_h := icon_side + title_h + interpretation_h + influence_h + price_h + gap * 5.0
	var preview_h := maxf(38.0, content_rect.size.y - fixed_h)
	if fixed_h + preview_h > content_rect.size.y:
		interpretation_h = maxf(20.0, interpretation_h - (fixed_h + preview_h - content_rect.size.y))
		fixed_h = icon_side + title_h + interpretation_h + influence_h + price_h + gap * 5.0
		preview_h = maxf(32.0, content_rect.size.y - fixed_h)
	var y := content_rect.position.y
	var icon := button.find_child("%sIcon" % button.name, false, false) as Control
	if icon != null:
		icon.visible = icon_side > 0.0
		if icon.visible:
			_apply_attribute_shop_rect(icon, Rect2(Vector2(content_rect.position.x + (content_rect.size.x - icon_side) * 0.5, y), Vector2(icon_side, icon_side)))
	y += icon_side + gap
	var title := button.find_child("%sTitle" % button.name, false, false) as Label
	var interpretation := button.find_child("%sInterpretation" % button.name, false, false) as Label
	var influence := button.find_child("%sInfluence" % button.name, false, false) as Label
	var preview := button.find_child("%sPreview" % button.name, false, false) as Label
	var price := button.find_child("%sAction" % button.name, false, false) as Label
	var compact_semantic := display_size.y < 300.0
	if influence != null:
		var full_influence := str(influence.get_meta("full_text", influence.text))
		var influence_items := full_influence.trim_prefix("Влияет на: ").split(",", false)
		var compact_influence := str(influence_items[0]).strip_edges() if not influence_items.is_empty() else "характеристику"
		if compact_influence.length() > 18:
			compact_influence = compact_influence.left(18).strip_edges()
		influence.text = "Влияет на: %s" % compact_influence if compact_semantic else full_influence
		influence.max_lines_visible = 2 if compact_semantic else -1
	if preview != null:
		var full_preview := str(preview.get_meta("full_text", preview.text))
		var preview_lines := full_preview.split("\n", false)
		var compact_lines := PackedStringArray()
		for line_index in range(mini(2, preview_lines.size())):
			compact_lines.append(AttributeSurfaces.compact_preview_line(str(preview_lines[line_index])))
		preview.text = "\n".join(compact_lines) if compact_semantic else full_preview
		preview.max_lines_visible = 2 if compact_semantic else -1
	_apply_attribute_shop_rect(title, Rect2(Vector2(content_rect.position.x, y), Vector2(content_rect.size.x, title_h)))
	y += title_h + gap
	_apply_attribute_shop_rect(interpretation, Rect2(Vector2(content_rect.position.x, y), Vector2(content_rect.size.x, interpretation_h)))
	y += interpretation_h + gap
	_apply_attribute_shop_rect(influence, Rect2(Vector2(content_rect.position.x, y), Vector2(content_rect.size.x, influence_h)))
	y += influence_h + gap
	_apply_attribute_shop_rect(preview, Rect2(Vector2(content_rect.position.x, y), Vector2(content_rect.size.x, preview_h)))
	y += preview_h + gap
	_apply_attribute_shop_rect(price, Rect2(Vector2(content_rect.position.x, y), Vector2(content_rect.size.x, price_h)))
	var minimum_body_font := 11.0 if display_size.y >= 230.0 else 9.0
	var base_font := int(clampf(roundf(display_size.y * 0.040), minimum_body_font, 20.0))
	if title != null:
		title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TITLE,
			base_font + 2,
			SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
			SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
		))
	if interpretation != null:
		interpretation.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			base_font,
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))
	if influence != null:
		influence.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_DESCRIPTION,
			base_font,
			SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
		))
	if preview != null:
		preview.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_DESCRIPTION,
			base_font - 2,
			SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
		))
	if price != null:
		price.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_VALUE,
			base_font + 1,
			SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
			SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
		))
	# FAN-1927: карточка — компактная проекция; полные списки осей живут в
	# drawer/тултипе (full_text meta). Не вмещающиеся wrapped-строки не
	# обрезаются ellipsis'ом, а убираются ЦЕЛЫМИ пунктами с конца.
	AttributeSurfaces.fit_list_label(influence, "Влияет на: ", ", ")
	AttributeSurfaces.fit_list_label(preview, "", "\n")




func _refresh_attribute_shop(root: Control, on_done: Callable) -> void:
	if root == null or not is_instance_valid(root):
		return
	var offers_box := root.find_child("AttributeOffers", true, false) as Container
	var money_label := root.find_child("AttributeShopMoney", true, false) as Label
	var reroll_button := root.find_child("AttributeRerollButton", true, false) as Button
	if offers_box == null or money_label == null or reroll_button == null:
		return
	for child in offers_box.get_children():
		offers_box.remove_child(child)
		child.queue_free()

	var buy_cost := _attribute_buy_cost()
	var money := _run_money()
	money_label.text = "Золото: %d · Цена +1: %d зол." % [money, buy_cost]
	reroll_button.text = "Обновить · %d зол. · %d" % [_attribute_reroll_cost(), game.attribute_rerolls_left]
	reroll_button.disabled = game.attribute_rerolls_left <= 0 or money < _attribute_reroll_cost()

	var detail_label := root.find_child("AttributeShopDetailLabel", true, false) as Label
	var detail_drawer := root.find_child("AttributeShopDetailDrawer", true, false) as PanelContainer
	var first_detail_text := ""
	for offer_value in game.attribute_offer:
		var stat_id := str((offer_value as Dictionary).get("id", "")) if offer_value is Dictionary else str(offer_value)
		var stat_title: String = str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
		var interpretation: String = str((offer_value as Dictionary).get("interpretation", game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, stat_id))) if offer_value is Dictionary else str(game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, stat_id))
		var influence_text := _attribute_influence_text(stat_id)
		var preview_lines := _attribute_upgrade_preview_lines(stat_id)
		var attr_offer_size: Vector2 = _attribute_shop_layout_for_size(root.size)["offer_size"]
		var offer_button := _make_attribute_offer_card(stat_id, stat_title, interpretation, influence_text, preview_lines, buy_cost, attr_offer_size)
		var detail_text := AttributeSurfaces.shop_card_detail_text(stat_title, buy_cost, "", influence_text, _attribute_upgrade_preview_lines(str(stat_id), 1.0, 99)) + ("\n%s" % interpretation if interpretation != "" else "")
		if first_detail_text == "":
			first_detail_text = detail_text
		if detail_label != null:
			AttributeSurfaces.wire_detail_focus(offer_button, detail_label, detail_drawer, false, detail_text)
		offer_button.disabled = money < buy_cost
		# SCRUM-413: недоступные (не хватает золота) карточки визуально затемнены —
		# явно видно, что купить нельзя, а не «активная, но не реагирует».
		offer_button.modulate = Color(0.5, 0.5, 0.55, 0.85) if offer_button.disabled else Color(1.0, 1.0, 1.0, 1.0)
		# SCRUM-525/SCRUM-851: тултип краткий и по делу — на что влияет атрибут и живой
		# предпросмотр производных при +1; интерпретация класса уже написана на карточке.
		offer_button.tooltip_text = "%s +1" % stat_title
		# Compact display copy may be abbreviated, but focus disclosure keeps the
		# exact source strings stored on the labels.
		var influence_label := offer_button.find_child("%sInfluence" % offer_button.name, false, false) as Label
		var preview_label := offer_button.find_child("%sPreview" % offer_button.name, false, false) as Label
		var full_influence := str(influence_label.get_meta("full_text", "")) if influence_label != null else ""
		var full_preview := str(preview_label.get_meta("full_text", "")) if preview_label != null else ""
		if full_influence != "":
			offer_button.tooltip_text += "\n%s" % full_influence
		if full_preview != "":
			offer_button.tooltip_text += "\nПредпросмотр при +1:\n• %s" % "\n• ".join(full_preview.split("\n", false))
		if offer_button.disabled:
			offer_button.tooltip_text += "\nНедостаточно золота: нужно %d, есть %d." % [buy_cost, money]
		offer_button.tooltip_text += "\n%s" % interpretation if interpretation != "" else ""
		offer_button.set_meta("attribute_tooltip_text", offer_button.tooltip_text)
		offer_button.set_meta("production_tooltip_host", true)
		offer_button.pressed.connect(func() -> void:
			if not _spend_run_money(buy_cost):
				# SCRUM-968: не хватает золота на +1 к характеристике — отказ.
				game._play_sfx("ui_error")
				return
			# SCRUM-968: успешная докачка характеристики — трата золота.
			game._play_sfx("purchase")
			_apply_reward_to_run({"stats": {stat_id: 1.0}})
			game.attribute_offer = []
			if on_done.is_valid():
				on_done.call()
		)
		offers_box.add_child(offer_button)
	if detail_label != null and first_detail_text != "":
		detail_label.text = first_detail_text
	_layout_attribute_shop(root)
	_layout_attribute_shop.call_deferred(root)

	# SCRUM-813: докач-опции + Reroll/Skip проходимы с геймпада/стрелок; старт — первая
	# доступная опция (иначе Reroll/Skip), без scroll-зависимости.
	var attr_skip_button := root.find_child("AttributeSkipButton", true, false) as Button
	var attr_focus: Array = []
	for offer_child in offers_box.get_children():
		if offer_child is Button:
			attr_focus.append(offer_child)
	var attr_secondary: Array = []
	if reroll_button != null:
		attr_secondary.append(reroll_button)
	if attr_skip_button != null:
		attr_secondary.append(attr_skip_button)
	_wire_run_ui_focus(attr_focus, true, attr_secondary, null)
	# The action controls are visually horizontal, so Left/Right must traverse
	# them. Map Down from the offer row to the nearest action and Up back.
	var focusable_offers := _collect_focusable_controls(attr_focus)
	var focusable_actions := _collect_focusable_controls(attr_secondary)
	if focusable_actions.size() == 2:
		var left_action := focusable_actions[0]
		var right_action := focusable_actions[1]
		left_action.focus_neighbor_left = right_action.get_path()
		left_action.focus_neighbor_right = right_action.get_path()
		right_action.focus_neighbor_left = left_action.get_path()
		right_action.focus_neighbor_right = left_action.get_path()
		if not focusable_offers.is_empty():
			left_action.focus_neighbor_top = focusable_offers[0].get_path()
			right_action.focus_neighbor_top = focusable_offers[focusable_offers.size() - 1].get_path()
			for offer_index in range(focusable_offers.size()):
				var action_target := left_action if offer_index < ceili(float(focusable_offers.size()) * 0.5) else right_action
				focusable_offers[offer_index].focus_neighbor_bottom = action_target.get_path()




func _spend_run_money(amount: int) -> bool:
	if game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player.spend_money(amount)
	var temp_player = game.combat._snapshot_player_for_menu()
	if temp_player == null:
		return false
	if not temp_player.spend_money(amount):
		temp_player.queue_free()
		return false
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()
	return true
