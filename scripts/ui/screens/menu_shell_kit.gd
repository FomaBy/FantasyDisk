extends "res://scripts/ui/screens/shared_shell_kit.gd"

# FAN-3824: модуль распределённого UI-класса — gold-shell меню и результаты: меню-боксы, раскладка, фоны экранов.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _uses_gold_menu_shell(screen_background_id: String) -> bool:
	return GOLD_SHELL_SCREEN_IDS.has(screen_background_id)




func _gold_menu_shell_prefix(screen_background_id: String) -> String:
	return {
		"campfire": "Rest",
		"upgrade": "Upgrade",
		"artifact_reward": "BattleReward",
		"victory": "Victory",
		"death": "Defeat",
	}.get(screen_background_id, screen_background_id.capitalize())




func _gold_shell_menu_hud_reserve(screen_background_id := "") -> float:
	return _gold_shell_menu_hud_reserve_for_size(screen_background_id, game.get_viewport().get_visible_rect().size)




func _gold_shell_menu_hud_reserve_for_size(screen_background_id: String, viewport_size: Vector2) -> float:
	var viewport_height: float = viewport_size.y
	if viewport_height < 900.0:
		return 96.0
	if viewport_height >= 1200.0:
		return 140.0
	return 112.0




func _gold_shell_panel_size(target_size: Vector2, inset := Vector2(16.0, 12.0), top_reserve := 0.0) -> Vector2:
	return _gold_shell_panel_size_for_safe(target_size, _unified_safe_rect().size, inset, top_reserve)




func _gold_shell_panel_size_for_safe(target_size: Vector2, safe_size: Vector2, inset: Vector2, top_reserve: float) -> Vector2:
	return Vector2(
		minf(target_size.x, maxf(1.0, safe_size.x - inset.x * 2.0)),
		minf(target_size.y, maxf(1.0, safe_size.y - inset.y * 2.0 - top_reserve))
	)




func _create_menu_box(title: String, subtitle: String, screen_background_id := "", panel_style_override: StyleBox = null, panel_display_size := Vector2.ZERO) -> VBoxContainer:
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "MenuScreen_%s" % screen_background_id if screen_background_id != "" else "MenuScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)

	if screen_background_id != "":
		_add_screen_background(root, screen_background_id)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel_%s" % screen_background_id if screen_background_id != "" else "MenuPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var economy_panel := _is_economy_screen_background(screen_background_id)
	var pause_end_panel := _is_pause_end_screen_background(screen_background_id)
	var result_panel := _is_result_screen_background(screen_background_id)
	var display_size := _pause_end_modal_display_size(screen_background_id) if pause_end_panel else Vector2.ZERO
	var half_size := panel_display_size * 0.5 if panel_display_size != Vector2.ZERO else (display_size * 0.5 if pause_end_panel else (_economy_menu_panel_half_size(screen_background_id) if economy_panel else Vector2(560.0, 330.0)))
	var shell_top_reserve := _gold_shell_menu_hud_reserve(screen_background_id) if _uses_gold_menu_shell(screen_background_id) and not result_panel else 0.0
	if _uses_gold_menu_shell(screen_background_id):
		var shell_panel_size := _gold_shell_panel_size(half_size * 2.0, Vector2(16.0, 0.0), shell_top_reserve)
		half_size = shell_panel_size * 0.5
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y + shell_top_reserve * 0.5
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y + shell_top_reserve * 0.5
	if pause_end_panel:
		panel.name = "PauseEndModalPanel_%s" % screen_background_id
		panel.clip_contents = true
		panel.set_meta("pause_end_display_size", display_size)
		panel.set_meta("pause_end_content_margins", _pause_end_modal_content_margins(display_size, screen_background_id))
		panel.set_meta("pause_end_content_rect", _pause_end_modal_content_rect(display_size, screen_background_id))
		panel.add_theme_stylebox_override("panel", _pause_end_modal_style(display_size, screen_background_id))
	elif panel_style_override != null:
		panel.add_theme_stylebox_override("panel", panel_style_override)
	else:
		var compact_gold_panel: bool = economy_panel and _uses_gold_menu_shell(screen_background_id) \
			and game.get_viewport().get_visible_rect().size.y < 800.0
		panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.94, 6.0) if compact_gold_panel else (_economy_panel_style() if economy_panel else _panel_style()))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var compact_gold_layout: bool = economy_panel and _uses_gold_menu_shell(screen_background_id) \
		and game.get_viewport().get_visible_rect().size.y < 800.0
	box.add_theme_constant_override("separation", (8 if result_panel and display_size.y < 660.0 else 10) if result_panel else (12 if pause_end_panel else ((8 if compact_gold_layout else 16) if economy_panel else 14)))
	if pause_end_panel and not result_panel:
		var scroll := ScrollContainer.new()
		scroll.name = "PauseEndModalScroll_%s" % screen_background_id
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		panel.add_child(scroll)
		scroll.add_child(box)
	elif result_panel:
		var result_shell := Control.new()
		result_shell.name = "ResultShell_%s" % screen_background_id
		result_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		result_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		result_shell.clip_contents = true
		panel.add_child(result_shell)
		result_shell.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.custom_minimum_size = Vector2.ZERO
		box.clip_contents = true
	elif economy_panel:
		var scroll := ScrollContainer.new()
		scroll.name = "EconomyMenuScroll_%s" % screen_background_id
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		panel.add_child(scroll)
		scroll.add_child(box)
	else:
		panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "MenuTitle_%s" % screen_background_id if screen_background_id != "" else "MenuTitle"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		_readable_font_size(SemanticTypography.ROLE_TITLE, 34 if pause_end_panel and game.get_viewport().get_visible_rect().size.y < 800.0 else 42, 0, 60),
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "MenuSubtitle_%s" % screen_background_id if screen_background_id != "" else "MenuSubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 15 if pause_end_panel and game.get_viewport().get_visible_rect().size.y < 800.0 else 17, 0, 24),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	box.add_child(subtitle_label)
	if result_panel:
		_configure_result_menu_layout(box, screen_background_id, display_size)
	if _uses_gold_menu_shell(screen_background_id):
		panel.set_meta("gold_shell_content_rect", _unified_safe_rect())
		_unified_add_frame(root, _gold_menu_shell_prefix(screen_background_id))
		root.resized.connect(func() -> void:
			_relayout_gold_menu_screen(root, panel, box, screen_background_id)
			call_deferred("_relayout_gold_menu_screen", root, panel, box, screen_background_id)
		)

	return box




func _gold_menu_target_size(screen_background_id: String) -> Vector2:
	match screen_background_id:
		"campfire":
			return Vector2(1180.0, 716.0)
		"upgrade":
			return Vector2(1720.0, 730.0)
		"artifact_reward":
			return Vector2(1120.0, 660.0)
	return Vector2(1120.0, 660.0)




func _relayout_gold_menu_screen(root: Control, panel: PanelContainer, box: VBoxContainer, screen_background_id: String) -> void:
	if root == null or panel == null or box == null or not is_instance_valid(root) or not is_instance_valid(panel) or not is_instance_valid(box):
		return
	var viewport_size := root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var safe_rect := _unified_safe_rect_for_size(viewport_size)
	var inner_rect := _gold_shell_inner_rect_for_size(viewport_size)
	var reserve := _gold_shell_menu_hud_reserve_for_size(screen_background_id, viewport_size)
	var panel_size := _gold_shell_panel_size_for_safe(_gold_menu_target_size(screen_background_id), safe_rect.size, Vector2(16.0, 0.0), reserve)
	var half_size := panel_size * 0.5
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y + reserve * 0.5
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y + reserve * 0.5
	panel.set_meta("gold_shell_content_rect", safe_rect)
	panel.set_meta("gold_shell_inner_rect", inner_rect)

	var compact_economy := viewport_size.y < 800.0 and ["campfire", "upgrade"].has(screen_background_id)
	if screen_background_id in ["campfire", "upgrade"]:
		panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.94, 6.0 if compact_economy else 18.0))
		box.add_theme_constant_override("separation", 8 if compact_economy else 16)
		var cards_in_row := 2 if screen_background_id == "campfire" else 3
		var card_size := _gold_shell_economy_choice_display_size_for_viewport(cards_in_row, viewport_size)
		var row_name := "RestChoiceRow" if screen_background_id == "campfire" else "UpgradeChoiceRow"
		var row := box.find_child(row_name, true, false) as HBoxContainer
		if row != null:
			var gap := _economy_choice_row_gap(card_size)
			row.custom_minimum_size.x = card_size.x * float(cards_in_row) + float(gap * maxi(cards_in_row - 1, 0))
			row.custom_minimum_size.y = card_size.y
			row.add_theme_constant_override("separation", gap)
			for child in row.get_children():
				if child is Button:
					_resize_economy_choice_card(child as Button, card_size)
	elif screen_background_id == "artifact_reward":
		panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.94, 18.0))
		var reward_size := _battle_reward_card_size_for_viewport(viewport_size)
		var rewards_row := box.find_child("BattleRewardCardsRow", true, false) as HBoxContainer
		if rewards_row != null:
			rewards_row.custom_minimum_size.y = reward_size.y
			for child in rewards_row.get_children():
				if child is Button:
					_resize_reward_card(child as Button, reward_size)

	var title := box.find_child("MenuTitle_%s" % screen_background_id, true, false) as Label
	if title == null and screen_background_id == "campfire":
		title = box.find_child("RestTitle", true, false) as Label
	if title != null:
		title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TITLE,
			_readable_font_size(SemanticTypography.ROLE_TITLE, 42, 0, 60),
			SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
			SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
		))
	var subtitle := box.find_child("MenuSubtitle_%s" % screen_background_id, true, false) as Label
	if subtitle == null and screen_background_id == "campfire":
		subtitle = box.find_child("RestSubtitle", true, false) as Label
	if subtitle != null:
		subtitle.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_CAPTION,
			_readable_font_size(SemanticTypography.ROLE_CAPTION, 17, 0, 24),
			SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
		))




func _resize_economy_choice_card(button: Button, display_size: Vector2) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.custom_minimum_size = display_size
	button.set_meta("economy_display_size", display_size)
	button.set_meta("gold_shell_compact", display_size.y < ECONOMY_CHOICE_TARGET_720.y)
	var pad := _atlas_card_pad(display_size)
	_apply_atlas_choice_card_theme(button, pad)
	var margins := _atlas_chip_content_margins(pad)
	button.set_meta("economy_content_margins", margins)
	var content := button.find_child("%sContent" % button.name, true, false) as Control
	if content != null:
		content.offset_left = margins.x
		content.offset_top = margins.y
		content.offset_right = -margins.z
		content.offset_bottom = -margins.w
	call_deferred("_fit_economy_choice_card_content", button)




func _resize_reward_card(button: Button, display_size: Vector2) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.custom_minimum_size = display_size
	_apply_reward_card_theme(button, false)
	var margins := _atlas_chip_content_margins(_atlas_card_pad(display_size))
	var content := button.find_child("BattleRewardCardContent", true, false) as Control
	if content != null:
		content.offset_left = margins.x
		content.offset_top = margins.y
		content.offset_right = -margins.z
		content.offset_bottom = -margins.w
	var compact := display_size.y <= 300.0
	var content_box := content as VBoxContainer
	if content_box != null:
		content_box.add_theme_constant_override("separation", 2 if compact else 5)
	var icon := button.find_child("UIIcon_*", true, false) as Control
	if icon != null:
		icon.custom_minimum_size = Vector2(32.0, 32.0) if compact else Vector2(40.0, 40.0)
	var title := button.find_child("BattleRewardTitle", true, false) as Label
	if title != null:
		title.max_lines_visible = 1 if compact else 2
		title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TITLE,
			_readable_font_size(SemanticTypography.ROLE_TITLE, 12 if compact else 17, 10 if compact else 12, 15 if compact else 22),
			SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
			SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
		))
	var preview := button.find_child("BattleRewardPreview", true, false) as Label
	if preview != null:
		preview.max_lines_visible = 2 if compact else -1
		preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		preview.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			_readable_font_size(SemanticTypography.ROLE_BODY, 10 if compact else 14, 10, 13 if compact else 16),
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))
	var description := button.find_child("BattleRewardDescription", true, false) as Label
	if description != null:
		description.max_lines_visible = 1 if compact else 2
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_DESCRIPTION,
			_readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 9 if compact else 12, 9 if compact else 12, 12 if compact else 14),
			SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
		))
	var note := button.find_child("BattleRewardClassNote", true, false) as Label
	if note != null:
		note.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			_readable_font_size(SemanticTypography.ROLE_BODY, 9 if compact else 11, 9 if compact else 12, 12 if compact else 14),
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))
	var action := button.find_child("BattleRewardActionLabel", true, false) as Label
	if action != null:
		action.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_ACTION,
			_readable_font_size(SemanticTypography.ROLE_ACTION, 10 if compact else 15, 10, 13 if compact else 16),
			SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
		))




func _create_result_menu_box(title: String, subtitle: String, screen_background_id: String) -> Dictionary:
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "ResultScreen_%s" % screen_background_id
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, screen_background_id)

	var display_size := _pause_end_modal_display_size(screen_background_id)
	var panel := PanelContainer.new()
	panel.name = "PauseEndModalPanel_%s" % screen_background_id
	panel.clip_contents = true
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var half_size := display_size * 0.5
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y
	panel.set_meta("pause_end_display_size", display_size)
	panel.set_meta("pause_end_content_margins", _pause_end_modal_content_margins(display_size, screen_background_id))
	panel.set_meta("pause_end_content_rect", _pause_end_modal_content_rect(display_size, screen_background_id))
	panel.add_theme_stylebox_override("panel", _pause_end_modal_style(display_size, screen_background_id))
	root.add_child(panel)

	var content := Control.new()
	content.name = "ResultContent_%s" % screen_background_id
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.custom_minimum_size = Vector2.ZERO
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.set_meta("result_no_scroll_layout", true)
	content.set_meta("result_screen_id", screen_background_id)
	content.set_meta("result_content_rect", _pause_end_modal_content_rect(display_size, screen_background_id))
	panel.add_child(content)

	var title_label := Label.new()
	title_label.name = "MenuTitle_%s" % screen_background_id
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "MenuSubtitle_%s" % screen_background_id
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.clip_text = true
	subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(subtitle_label)

	var body := Control.new()
	body.name = "ResultBody_%s" % screen_background_id
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(body)

	var crest_slot := CenterContainer.new()
	crest_slot.name = "ResultCrestSlot_%s" % screen_background_id
	crest_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(crest_slot)

	var summary_column := VBoxContainer.new()
	summary_column.name = "RunSummaryColumn_%s" % screen_background_id
	summary_column.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_column.clip_contents = true
	summary_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(summary_column)

	var button_slot := CenterContainer.new()
	button_slot.name = "ResultButtonSlot_%s" % screen_background_id
	button_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(button_slot)

	content.resized.connect(func() -> void:
		_layout_result_content(content, screen_background_id)
	)
	_layout_result_content(content, screen_background_id)
	call_deferred("_layout_result_content", content, screen_background_id)
	panel.set_meta("gold_shell_content_rect", _unified_safe_rect())
	_unified_add_frame(root, _gold_menu_shell_prefix(screen_background_id))
	root.resized.connect(func() -> void:
		_relayout_gold_result_screen(root, panel, content, screen_background_id)
		call_deferred("_relayout_gold_result_screen", root, panel, content, screen_background_id)
	)

	return {
		"content": content,
		"crest_slot": crest_slot,
		"summary_column": summary_column,
		"button_slot": button_slot,
	}




func _relayout_gold_result_screen(root: Control, panel: PanelContainer, content: Control, screen_background_id: String) -> void:
	if root == null or panel == null or content == null or not is_instance_valid(root) or not is_instance_valid(panel) or not is_instance_valid(content):
		return
	var viewport_size := root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var display_size := _pause_end_modal_display_size_for_viewport(screen_background_id, viewport_size)
	var half_size := display_size * 0.5
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y
	var content_margins := _pause_end_modal_content_margins(display_size, screen_background_id)
	var content_rect := _pause_end_modal_content_rect(display_size, screen_background_id)
	panel.set_meta("pause_end_display_size", display_size)
	panel.set_meta("pause_end_content_margins", content_margins)
	panel.set_meta("pause_end_content_rect", content_rect)
	panel.set_meta("gold_shell_content_rect", _unified_safe_rect_for_size(viewport_size))
	panel.add_theme_stylebox_override("panel", _pause_end_modal_style(display_size, screen_background_id))
	content.set_meta("result_content_rect", content_rect)

	var crest_size := _pause_end_result_crest_size_for_viewport(viewport_size.y)
	var crest := content.find_child("ResultCrest", true, false) as TextureRect
	if crest != null:
		crest.custom_minimum_size = Vector2(crest_size, crest_size)
	var action_name := "VictoryNewRunButton" if screen_background_id == "victory" else "DeathRetryButton"
	var action := content.find_child(action_name, true, false) as Button
	if action != null:
		_set_action_button_size(action, _pause_end_result_button_width_for_viewport(screen_background_id, viewport_size), _pause_end_result_button_height_for_viewport(viewport_size.y))
	_layout_result_content(content, screen_background_id)
	_relayout_result_summary_typography(content, viewport_size.y)




func _relayout_result_summary_typography(content: Control, viewport_height: float) -> void:
	if content == null or not is_instance_valid(content):
		return
	var ultra_compact: bool = viewport_height < 800.0
	var outcome := content.find_child("RunSummaryOutcome", true, false) as Label
	if outcome != null:
		outcome.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_SECTION,
			_readable_font_size(SemanticTypography.ROLE_SECTION, 10 if ultra_compact else 13, 10 if ultra_compact else 12, 22),
			SemanticTypography.role_min(SemanticTypography.ROLE_SECTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_SECTION)
		))
	var grid := content.find_child("RunSummaryStats", true, false) as GridContainer
	if grid != null:
		grid.add_theme_constant_override("h_separation", 8 if ultra_compact else 14)
		grid.add_theme_constant_override("v_separation", 0 if ultra_compact else 2)
		for label_node in grid.get_children():
			var label := label_node as Label
			if label == null:
				continue
			var base_size := 10 if ultra_compact else (12 if str(label.name).begins_with("RunSummaryStatName_") else 13)
			if str(label.name).begins_with("RunSummaryStatName_"):
				label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
					SemanticTypography.ROLE_FIELD,
					_readable_font_size(SemanticTypography.ROLE_FIELD, base_size, 10 if ultra_compact else 12, 20),
					SemanticTypography.role_min(SemanticTypography.ROLE_FIELD),
					SemanticTypography.role_max(SemanticTypography.ROLE_FIELD)
				))
			else:
				label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
					SemanticTypography.ROLE_VALUE,
					_readable_font_size(SemanticTypography.ROLE_VALUE, base_size, 10 if ultra_compact else 12, 20),
					SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
					SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
				))
	var artifacts := content.find_child("RunSummaryArtifacts", true, false) as Label
	if artifacts != null:
		artifacts.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			_readable_font_size(SemanticTypography.ROLE_BODY, 10 if ultra_compact else 11, 10 if ultra_compact else 12, 18),
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))




func _layout_result_content(content: Control, screen_background_id: String) -> void:
	if content == null or not is_instance_valid(content):
		return
	var size := content.size
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var compact := size.y < 520.0 or float(game.get_viewport().get_visible_rect().size.y) < 760.0
	var gap := 6.0 if compact else 10.0
	var button_height := minf(_pause_end_result_button_height(), maxf(56.0, size.y * 0.20))
	var available_height := maxf(1.0, size.y - button_height - gap * 3.0)
	var title_height := clampf(available_height * 0.12, 28.0 if compact else 34.0, 42.0)
	var subtitle_height := clampf(available_height * (0.23 if compact else 0.25), 58.0 if compact else 104.0, 112.0 if compact else 128.0)
	var body_height := maxf(1.0, available_height - title_height - subtitle_height)
	var minimum_body := 162.0 if compact else 220.0
	if body_height < minimum_body:
		var deficit := minimum_body - body_height
		subtitle_height = maxf(58.0 if compact else 82.0, subtitle_height - deficit)
		body_height = maxf(1.0, available_height - title_height - subtitle_height)

	var title := content.get_node_or_null("MenuTitle_%s" % screen_background_id) as Label
	var subtitle := content.get_node_or_null("MenuSubtitle_%s" % screen_background_id) as Label
	var body := content.get_node_or_null("ResultBody_%s" % screen_background_id) as Control
	var button_slot := content.get_node_or_null("ResultButtonSlot_%s" % screen_background_id) as Control

	_apply_control_rect(title, Rect2(0.0, 0.0, size.x, title_height))
	_apply_control_rect(subtitle, Rect2(0.0, title_height + gap, size.x, subtitle_height))
	_apply_control_rect(body, Rect2(0.0, title_height + gap + subtitle_height + gap, size.x, body_height))
	_apply_control_rect(button_slot, Rect2(0.0, maxf(0.0, size.y - button_height), size.x, button_height))

	if title != null:
		title.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 26 if compact else 34, 0, 42))
	if subtitle != null:
		subtitle.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_CAPTION, 11 if compact else 13, 0, 18))
	if body == null:
		return

	var crest_slot := body.get_node_or_null("ResultCrestSlot_%s" % screen_background_id) as Control
	var summary_column := body.get_node_or_null("RunSummaryColumn_%s" % screen_background_id) as VBoxContainer
	var body_gap := 10.0 if compact else 18.0
	var crest_width := clampf(size.x * 0.26, 92.0 if compact else 112.0, 168.0)
	var summary_x := crest_width + body_gap
	var summary_width := maxf(1.0, size.x - summary_x)
	_apply_control_rect(crest_slot, Rect2(0.0, 0.0, crest_width, body_height))
	_apply_control_rect(summary_column, Rect2(summary_x, 0.0, summary_width, body_height))
	if summary_column != null:
		summary_column.add_theme_constant_override("separation", 2 if compact else 4)




func _configure_result_menu_layout(box: VBoxContainer, screen_background_id: String, display_size: Vector2) -> void:
	var content_rect := _pause_end_modal_content_rect(display_size, screen_background_id)
	var content_size := content_rect.size
	var compact := display_size.y < 660.0
	box.name = "ResultContent_%s" % screen_background_id
	box.set_meta("result_no_scroll_layout", true)
	box.set_meta("result_screen_id", screen_background_id)
	box.set_meta("result_content_rect", content_rect)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.custom_minimum_size = Vector2.ZERO
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8 if compact else 10)

	var title_label := box.find_child("MenuTitle_%s" % screen_background_id, false, false) as Label
	if title_label != null:
		title_label.custom_minimum_size = Vector2(content_size.x, 30.0 if compact else 42.0)
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 28 if compact else 36, 0, 48))

	var subtitle_label := box.find_child("MenuSubtitle_%s" % screen_background_id, false, false) as Label
	if subtitle_label != null:
		subtitle_label.custom_minimum_size = Vector2(content_size.x, 112.0 if compact else 128.0)
		subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		subtitle_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_CAPTION,
			_readable_font_size(SemanticTypography.ROLE_CAPTION, 13 if compact else 16, 0, 21),
			SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
		))

	var body := HBoxContainer.new()
	body.name = "ResultBody_%s" % screen_background_id
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12 if compact else 18)
	box.add_child(body)

	var crest_column := VBoxContainer.new()
	crest_column.name = "ResultCrestColumn_%s" % screen_background_id
	crest_column.alignment = BoxContainer.ALIGNMENT_CENTER
	crest_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var crest_column_width := clampf(content_size.x * 0.28, 112.0, 170.0)
	crest_column.custom_minimum_size = Vector2(crest_column_width, 0.0)
	body.add_child(crest_column)

	var crest_slot := CenterContainer.new()
	crest_slot.name = "ResultCrestSlot_%s" % screen_background_id
	var crest_size := _pause_end_result_crest_size()
	crest_slot.custom_minimum_size = Vector2(crest_column_width, crest_size)
	crest_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest_column.add_child(crest_slot)

	var summary_column := VBoxContainer.new()
	summary_column.name = "RunSummaryColumn_%s" % screen_background_id
	summary_column.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_column.add_theme_constant_override("separation", 4 if compact else 6)
	body.add_child(summary_column)




func _add_result_crest(box: VBoxContainer, kind: String) -> void:
	var slot := box.find_child("ResultCrestSlot_%s" % kind, true, false) as Control
	if slot != null:
		_add_result_crest_to_slot(slot, kind)
		return
	# Аддитивная геральдическая эмблема-кольцо над заголовком экранов победы/поражения
	# (D&D Dark Fantasy Dragon, fantasydisk-asset-generator). SCRUM-330.
	var crest := _make_result_crest(kind)
	if crest == null:
		return
	box.add_child(crest)
	box.move_child(crest, 0)




func _add_result_crest_to_slot(slot: Control, kind: String) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var crest := _make_result_crest(kind)
	if crest == null:
		return
	slot.add_child(crest)




func _make_result_crest(kind: String) -> TextureRect:
	# Аддитивная геральдическая эмблема-кольцо над заголовком экранов победы/поражения
	# (D&D Dark Fantasy Dragon, fantasydisk-asset-generator). SCRUM-330.
	var slug := "victory" if kind == "victory" else "defeat"
	var tex: Texture2D = game._cached_texture("res://assets/sprites/ui/result_crests/ui_crest_%s.png" % slug)
	if tex == null:
		return null
	var crest := TextureRect.new()
	crest.name = "ResultCrest"
	crest.texture = tex
	var crest_size := _pause_end_result_crest_size()
	crest.custom_minimum_size = Vector2(crest_size, crest_size)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return crest




func _pause_end_result_crest_size() -> float:
	var viewport_height: float = float(game.get_viewport().get_visible_rect().size.y)
	return _pause_end_result_crest_size_for_viewport(viewport_height)




func _pause_end_result_crest_size_for_viewport(viewport_height: float) -> float:
	if viewport_height < 760.0:
		return clampf(viewport_height * 0.15, 88.0, 112.0)
	return clampf(viewport_height * 0.16, 112.0, 168.0)




func _pause_end_result_button_height() -> float:
	var viewport_height: float = float(game.get_viewport().get_visible_rect().size.y)
	return _pause_end_result_button_height_for_viewport(viewport_height)




func _pause_end_result_button_height_for_viewport(viewport_height: float) -> float:
	if viewport_height < 800.0:
		return 72.0
	if viewport_height < 1000.0:
		return 88.0
	return STANDARD_ACTION_BUTTON_HEIGHT




func _pause_end_result_button_width(screen_background_id: String) -> float:
	return _pause_end_result_button_width_for_viewport(screen_background_id, game.get_viewport().get_visible_rect().size)




func _pause_end_result_button_width_for_viewport(screen_background_id: String, viewport_size: Vector2) -> float:
	var display_size := _pause_end_modal_display_size_for_viewport(screen_background_id, viewport_size)
	var content_width := _pause_end_modal_content_rect(display_size, screen_background_id).size.x
	return clampf(floorf(content_width), 260.0, STANDARD_ACTION_BUTTON_WIDTH)




func _add_screen_background(root: Control, screen_background_id: String) -> void:
	var texture := _screen_background_texture(screen_background_id)
	if texture != null:
		var background := TextureRect.new()
		background.name = "ScreenBackground_%s" % screen_background_id
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.texture = texture
		if screen_background_id == "level_up":
			background.modulate = LU_BACKGROUND_BRIGHTEN
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(background)
	else:
		var fallback := ColorRect.new()
		fallback.name = "ScreenBackgroundFallback_%s" % screen_background_id
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.color = game.SCREEN_BACKGROUND_FALLBACK_COLORS.get(screen_background_id, Color(0.035, 0.040, 0.060, 1.0))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fallback)

	var shade := ColorRect.new()
	shade.name = "ScreenBackgroundReadableShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# SCRUM-684: кодекс рисуется поверх детального гримуар-разворота — гасим фон
	# сильнее, чтобы орнаментные панели читались как передний план.
	if screen_background_id == "codex":
		shade.color = Color(0.02, 0.015, 0.03, 0.62)
	elif screen_background_id == "level_up":
		shade.color = Color(0.015, 0.010, 0.030, LU_BACKGROUND_SHADE_ALPHA)
	else:
		shade.color = Color(0.0, 0.0, 0.0, 0.44)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)




func _screen_background_texture(screen_background_id: String) -> Texture2D:
	if game.screen_background_cache.has(screen_background_id):
		return game.screen_background_cache[screen_background_id]
	var path = str(game.SCREEN_BACKGROUND_PATHS.get(screen_background_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		game.screen_background_cache[screen_background_id] = null
		return null
	var texture = game._cached_texture(path)
	game.screen_background_cache[screen_background_id] = texture
	return texture
