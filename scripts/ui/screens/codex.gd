extends "res://scripts/ui/screens/misc_screens.gd"

# FAN-3824: модуль распределённого UI-класса — Кодекс: сцена, вкладки, досье и разделы.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _show_codex_screen() -> void:
	# SCRUM-954: the accepted SCRUM-1017 PixelLab contract is authored on a
	# 1920x1080 stage. The stage scales uniformly and letterboxes instead of
	# compressing the three columns through their ornamental/content margins.
	# Lazy sections, discovery/locked state and focus navigation remain data-driven.
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "CodexScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)

	_unified_add_background(root, "codex")
	root.set_meta("codex_runtime_skin", "fan1065_atlas_settings")

	var stage := Control.new()
	stage.name = "CodexStage"
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(stage)
	_codex_update_stage_transform(stage)
	root.resized.connect(_codex_update_stage_transform.bind(stage))

	# FAN-1069: the PixelLab crest is a quiet header accent in the empty stage
	# band. Runtime text stays separate from the art; tabs/Back remain the exact
	# shared Main Menu button family requested by the user.
	if ResourceLoader.exists(CODEX_CREST_PATH):
		var crest := TextureRect.new()
		crest.name = "CodexCrest"
		crest.texture = game._cached_texture(CODEX_CREST_PATH)
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_codex_pl_make_nearest(crest)
		_codex_set_design_rect(crest, Rect2(908, 24, 104, 104))
		stage.add_child(crest)

	# Header frame and Back use the same restrained metal/button family as the
	# rest of the product. No category emblem competes with the screen title.
	var title_frame := PanelContainer.new()
	title_frame.name = "CodexTitleFrame"
	title_frame.add_theme_stylebox_override("panel", _codex_panel_style(0.90, Vector4(36, 22, 36, 22)))
	_codex_set_design_rect(title_frame, Rect2(72, 36, 340, 112))
	stage.add_child(title_frame)
	var title_label := Label.new()
	title_label.name = "CodexTitleLabel"
	title_label.text = "КОДЕКС"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_codex_bind_stage_font(title_label, SemanticTypography.ROLE_TITLE, 30, SemanticTypography.role_min(SemanticTypography.ROLE_TITLE), SemanticTypography.role_max(SemanticTypography.ROLE_TITLE))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_frame.add_child(title_label)

	var back_button := Button.new()
	back_button.name = "CodexBackButton"
	back_button.text = "НАЗАД"
	back_button.custom_minimum_size = Vector2(268, 96)
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_fantasy_button_theme(back_button, "default", "text/back_260x104")
	back_button.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 16))
	_codex_bind_stage_font(back_button, SemanticTypography.ROLE_ACTION, 22, SemanticTypography.role_min(SemanticTypography.ROLE_ACTION), SemanticTypography.role_max(SemanticTypography.ROLE_ACTION))
	_codex_set_design_rect(back_button, Rect2(1580, 46, 268, 96))
	back_button.pressed.connect(_show_main_menu)
	_connect_ui_sfx(back_button, "back")
	stage.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	# Exact panel frames and their content margins are the accepted empty zones.
	var nav_panel := PanelContainer.new()
	nav_panel.name = "CodexNavPanel"
	nav_panel.add_theme_stylebox_override("panel", _codex_panel_style(0.90, Vector4(32, 38, 32, 50)))
	_codex_set_design_rect(nav_panel, Rect2(72, 172, 324, 840))
	stage.add_child(nav_panel)
	var tabs_row := Control.new()
	tabs_row.name = "CodexTabs"
	nav_panel.add_child(tabs_row)

	var content := PanelContainer.new()
	content.name = "CodexContent"
	content.add_theme_stylebox_override("panel", _codex_panel_style(0.88, Vector4(32, 36, 32, 44)))
	_codex_set_design_rect(content, Rect2(420, 172, 620, 840))
	stage.add_child(content)
	var center_inner := Control.new()
	center_inner.name = "CodexCenterBox"
	content.add_child(center_inner)
	var center_title := Label.new()
	center_title.name = "CodexCenterTitle"
	center_title.text = "ПЕРСОНАЖИ"
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_codex_bind_stage_font(center_title, SemanticTypography.ROLE_SECTION, 24, SemanticTypography.role_min(SemanticTypography.ROLE_SECTION), SemanticTypography.role_max(SemanticTypography.ROLE_SECTION))
	center_title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	_codex_set_design_rect(center_title, Rect2(88, 14, 380, 44))
	center_inner.add_child(center_title)

	var center_list_host := Control.new()
	center_list_host.name = "CodexCenterListHost"
	center_list_host.clip_contents = true
	_codex_set_design_rect(center_list_host, Rect2(0, 70, 556, 690))
	center_inner.add_child(center_list_host)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "CodexDetailPanel"
	detail_panel.add_theme_stylebox_override("panel", _codex_panel_style(0.92, Vector4(32, 36, 32, 44)))
	_codex_set_design_rect(detail_panel, Rect2(1064, 172, 784, 840))
	stage.add_child(detail_panel)

	content.set_meta("codex_detail_panel", detail_panel)
	content.set_meta("codex_tabs", tabs_row)
	content.set_meta("codex_section_host", center_list_host)
	content.set_meta("codex_section_title", center_title)
	content.set_meta("codex_active_section", "characters")

	# Seven fixed Russian labels (FAN-1080 added «Летопись»). The category-emblem
	# path is intentionally absent: canonical images belong to entries, not to
	# navigation furniture. Pitch 104 keeps the 7th plate inside the 752px
	# content zone of the nav panel (840 - 38 top - 50 bottom margins).
	var nav_y := [24.0, 128.0, 232.0, 336.0, 440.0, 544.0, 648.0]
	for section_index in range(CODEX_SECTIONS.size()):
		var section: Dictionary = CODEX_SECTIONS[section_index]
		var section_id := str(section["id"])
		var tab_button := Button.new()
		tab_button.name = "CodexTab_%s" % section_id
		tab_button.text = str(section["title"])
		tab_button.custom_minimum_size = Vector2(260, 72)
		tab_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_fantasy_button_theme(tab_button, "default", UIButtonFamily.FAMILY_MAIN_MENU)
		tab_button.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TAB, 16))
		tab_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		tab_button.clip_text = false
		_codex_bind_stage_font(tab_button, SemanticTypography.ROLE_TAB, 20, SemanticTypography.role_min(SemanticTypography.ROLE_TAB), SemanticTypography.role_max(SemanticTypography.ROLE_TAB))
		_codex_set_design_rect(tab_button, Rect2(0, nav_y[section_index], 260, 72))
		tab_button.pressed.connect(_show_codex_section.bind(content, section_id))
		_connect_ui_sfx(tab_button, "click")
		tabs_row.add_child(tab_button)
		if ["characters", "monsters", "artifacts"].has(section_id):
			var tab_badge: TextureRect = codex_unlock_presenter.add_unread_badge(tab_button, "CodexTabUnreadBadge_%s" % section_id, 28.0, 30.0)
			tab_badge.visible = codex_unlock_presenter.section_has_unread(section_id)

	_show_codex_section(content, "characters")

	# SCRUM-954 intentionally has no full-screen ornamental shell. The previous
	# CodexFrame covered the authored header/nav zones at 720p and 1080p; each
	# surface above now owns its own explicit safe content margin.

	# SCRUM-813: стартовый фокус — первая вкладка кодекса; LB/RB листают разделы
	# (см. _handle_menu_shoulder_nav), карточки записей фокусируемы и прокручиваются
	# (follow_focus). B/Esc = назад в меню.
	_ensure_run_ui_gamepad_bindings()
	var first_codex_tab := tabs_row.get_node_or_null("CodexTab_characters") as Button
	if first_codex_tab != null:
		first_codex_tab.focus_mode = Control.FOCUS_ALL
		first_codex_tab.call_deferred("grab_focus")




func _codex_set_design_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size




func _codex_update_stage_transform(stage: Control) -> void:
	if stage == null or not is_instance_valid(stage):
		return
	var viewport_size := Vector2(1920, 1080)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var design_size := Vector2(1920, 1080)
	var uniform_scale := minf(viewport_size.x / design_size.x, viewport_size.y / design_size.y)
	stage.position = (viewport_size - design_size * uniform_scale) * 0.5
	stage.size = design_size
	stage.custom_minimum_size = design_size
	stage.scale = Vector2.ONE * uniform_scale
	stage.set_meta("codex_design_scale", uniform_scale)
	stage.set_meta("codex_letterbox_offset", stage.position)
	_codex_refresh_stage_fonts(stage)




func _codex_bind_stage_font(control: Control, role: StringName, design_size: int, min_visual_size: int, max_visual_size: int) -> void:
	# SCRUM-1073 keeps the accepted Codex dossier's 17px body floor and 30px
	# section ceiling while enforcing the canonical semantic band everywhere.
	# These narrower in-band bounds prevent compact dossier drift and large-tier
	# center-title growth without weakening native token floors.
	if role == SemanticTypography.ROLE_BODY:
		min_visual_size = maxi(min_visual_size, 17)
	if role == SemanticTypography.ROLE_SECTION:
		max_visual_size = mini(max_visual_size, 30)
	control.set_meta("codex_semantic_role", role)
	control.set_meta("codex_design_font_size", design_size)
	control.set_meta("codex_min_visual_font_size", min_visual_size)
	control.set_meta("codex_max_visual_font_size", max_visual_size)
	control.add_theme_font_size_override("font_size", _codex_stage_font_size(role, design_size, min_visual_size, max_visual_size))




func _codex_refresh_stage_fonts(stage: Control) -> void:
	if stage == null or not is_instance_valid(stage):
		return
	for node in stage.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.has_meta("codex_design_font_size"):
			continue
		control.add_theme_font_size_override("font_size", _codex_stage_font_size(
			StringName(control.get_meta("codex_semantic_role", SemanticTypography.ROLE_BODY)),
			int(control.get_meta("codex_design_font_size")),
			int(control.get_meta("codex_min_visual_font_size")),
			int(control.get_meta("codex_max_visual_font_size"))
		))




func _codex_texture_style(path: String, texture_margins: Vector4, margins: Vector4, alpha := 1.0) -> StyleBox:
	return _global_texture_style(
		path,
		texture_margins,
		Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)),
		margins,
		false
	)




func _codex_panel_style(alpha: float, margins: Vector4) -> StyleBox:
	return _codex_texture_style(CODEX_PANEL_FRAME_PATH, CODEX_PANEL_TEXTURE_MARGINS, margins, alpha)




func _codex_chip_style(alpha: float, margins: Vector4) -> StyleBox:
	return _codex_texture_style(CODEX_CHIP_FRAME_PATH, CODEX_CHIP_TEXTURE_MARGINS, margins, alpha)




func _codex_dossier_style(alpha: float, margins: Vector4) -> StyleBox:
	return _codex_texture_style(CODEX_DOSSIER_FRAME_PATH, CODEX_DOSSIER_TEXTURE_MARGINS, margins, alpha)




func _codex_lore_style(margins: Vector4) -> StyleBox:
	# The square dossier art is safe for the 300x300 portrait well, but its broad
	# dragon corners enter the accepted 610x304 lore content lane when stretched
	# to 684x356. Keep that locked content rect and use the thinner Codex panel
	# frame with a restrained parchment-warm tint instead.
	return _global_texture_style(
		CODEX_PANEL_FRAME_PATH,
		CODEX_PANEL_TEXTURE_MARGINS,
		Color(1.06, 0.96, 0.82, 0.98),
		margins,
		false
	)




func _codex_inset_style(alpha: float, margins: Vector4) -> StyleBoxFlat:
	var style := _atlas_chip_style(alpha, 0.0)
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style




func _codex_clear_content_style(margins: Vector4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style




func _codex_entry_style(tint: Color) -> StyleBox:
	return _global_texture_style(
		CODEX_ENTRY_CARD_PATH,
		Vector4.ZERO,
		tint,
		Vector4(20.0, 20.0, 30.0, 20.0),
		false
	)




func _codex_apply_entry_theme(button: Button, selected := false) -> void:
	# Preserve the semantic content-row family/focus contract, then replace only
	# its painted surface with the accepted PixelLab card. Every state keeps the
	# same content margins, so selection/hover never shifts the 516x154 geometry.
	_unified_apply_row_theme(button, 10.0, selected)
	button.add_theme_stylebox_override("normal", _codex_entry_style(Color(1.08, 1.02, 0.88, 1.0) if selected else Color(0.88, 0.88, 0.88, 0.96)))
	button.add_theme_stylebox_override("hover", _codex_entry_style(Color(1.10, 1.08, 1.02, 1.0)))
	button.add_theme_stylebox_override("pressed", _codex_entry_style(Color(0.82, 0.78, 0.72, 1.0)))
	button.add_theme_stylebox_override("focus", _codex_entry_style(Color(1.12, 1.04, 0.82, 1.0)))
	button.add_theme_stylebox_override("disabled", _codex_entry_style(Color(0.50, 0.50, 0.50, 0.72)))




func _show_codex_section(content: PanelContainer, section_id: String) -> void:
	# Ленивое построение: раздел собирается при первом открытии и кэшируется
	# внутри экрана, остальные скрываются — меню не фризит на старте.
	if content == null or not is_instance_valid(content):
		return
	var detail_panel := content.get_meta("codex_detail_panel", null) as PanelContainer
	var tabs_row := content.get_meta("codex_tabs", null) as Control
	var section_host := content.get_meta("codex_section_host", content) as Control
	var section_title := content.get_meta("codex_section_title", null) as Label
	if section_host == null:
		section_host = content
	content.set_meta("codex_active_section", section_id)
	_codex_update_tab_selection(tabs_row, section_id)
	if section_title != null:
		for section in CODEX_SECTIONS:
			if str(section.get("id", "")) == section_id:
				section_title.text = str(section.get("title", "")).to_upper()
				break
	for child in section_host.get_children():
		child.visible = false
	var existing := section_host.get_node_or_null("CodexSection_%s" % section_id)
	if existing != null:
		existing.visible = true
		var default_detail: Dictionary = existing.get_meta("codex_default_detail", {})
		if detail_panel != null and not default_detail.is_empty():
			_codex_update_detail(detail_panel, default_detail)
			if existing.has_meta("codex_default_entry_button"):
				_codex_set_selected_entry(content, existing.get_meta("codex_default_entry_button") as Button)
		return

	var scroll := ScrollContainer.new()
	scroll.name = "CodexSection_%s" % section_id
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# SCRUM-813: скролл секции следует за сфокусированной карточкой (крестовина/стик).
	scroll.follow_focus = true
	section_host.add_child(scroll)

	var list_inset := MarginContainer.new()
	list_inset.name = "CodexSectionInset_%s" % section_id
	list_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_inset.add_theme_constant_override("margin_left", 8)
	list_inset.add_theme_constant_override("margin_top", 12)
	list_inset.add_theme_constant_override("margin_right", 32)
	list_inset.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(list_inset)

	var list := VBoxContainer.new()
	list.name = "CodexSectionList_%s" % section_id
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	list.set_meta("codex_detail_panel", detail_panel)
	list.set_meta("codex_section_scroll", scroll)
	list.set_meta("codex_content_panel", content)
	list_inset.add_child(list)

	match section_id:
		"characters":
			_build_codex_characters(list)
		"monsters":
			_build_codex_monsters(list)
		"artifacts":
			_build_codex_artifacts(list)
		"characteristics":
			_build_codex_stats(list, "base")
		"attributes":
			_build_codex_stats(list, "derived")
		"ascension":
			_build_codex_ascensions(list)
		"chronicle":
			_build_codex_chronicle(list)
	var default_detail: Dictionary = scroll.get_meta("codex_default_detail", {})
	if detail_panel != null and not default_detail.is_empty():
		_codex_update_detail(detail_panel, default_detail)
		if scroll.has_meta("codex_default_entry_button"):
			_codex_set_selected_entry(content, scroll.get_meta("codex_default_entry_button") as Button)




func _codex_entry_panel(list: VBoxContainer, detail_data := {}, unread_refs := []) -> HBoxContainer:
	# SCRUM-954: 516x154 authored row. Its 20px inner reserve keeps the actual
	# image well and centered Russian name clear of the leather/metal bevel.
	var panel := Button.new()
	panel.name = "CodexEntryCard"
	panel.text = ""
	panel.custom_minimum_size = Vector2(516.0, 154.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.focus_mode = Control.FOCUS_ALL
	_codex_apply_entry_theme(panel, false)
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20.0
	row.offset_top = 20.0
	row.offset_right = -86.0 if not unread_refs.is_empty() else -30.0
	row.offset_bottom = -20.0
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.set_meta("entry_button", panel)
	panel.set_meta("codex_unread_refs", unread_refs.duplicate(true))
	panel.set_meta("codex_is_unread", not unread_refs.is_empty())
	if detail_data is Dictionary:
		panel.set_meta("codex_entry_id", str((detail_data as Dictionary).get("codex_entry_id", "")))
		panel.set_meta("codex_entry_category", str((detail_data as Dictionary).get("codex_entry_category", "")))
	if not unread_refs.is_empty():
		codex_unlock_presenter.add_unread_badge(panel, "CodexUnreadBadge", 36.0, 34.0, 22.0)
	if detail_data is Dictionary and not (detail_data as Dictionary).is_empty():
		_codex_attach_entry_detail(list, row, detail_data)
	return row




# Квадрат портрета/иконки в чип-ряду записи (влезает в content-зону карточки).
func _codex_entry_portrait_size() -> Vector2:
	return Vector2(88.0, 96.0)




func _codex_portrait(row: HBoxContainer, sprite_path: String, size: Vector2, image_policy := CodexImageFit.POLICY_CHARACTER) -> Texture2D:
	var texture: Texture2D = null
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		texture = game._cached_texture(sprite_path)
	_codex_icon_slot(row, texture, size, "CodexPortraitSlot", image_policy, sprite_path)
	return texture




func _codex_icon_slot(row: HBoxContainer, texture: Texture2D, size: Vector2, node_name := "CodexPortraitSlot", image_policy := CodexImageFit.POLICY_CONTAIN, source_path := "") -> void:
	var slot := PanelContainer.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Accepted row image well: 122x114 with the live image inside 88x96.
	slot.custom_minimum_size = Vector2(122.0, 114.0)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The PixelLab entry-card already paints the recessed well. This transparent
	# content owner keeps the accepted 122x114 -> 88x96 reserve without drawing a
	# second field over that authored well.
	var slot_style := _codex_clear_content_style(Vector4(17.0, 9.0, 17.0, 9.0))
	slot.add_theme_stylebox_override("panel", slot_style)
	_codex_pl_make_nearest(slot)
	row.add_child(slot)
	var portrait := TextureRect.new()
	portrait.name = "%sTexture" % node_name
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = size
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = CodexImageFit.texture_view(texture, source_path, image_policy, size)
	portrait.set_meta("codex_source_path", source_path if not source_path.is_empty() else CodexImageFit.canonical_path(texture))
	portrait.set_meta("codex_image_policy", image_policy)
	_codex_pl_make_nearest(portrait)
	slot.add_child(portrait)




func _codex_add_entry_name(row: HBoxContainer, display_name: String) -> Label:
	var label := Label.new()
	label.name = "CodexEntryName"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = display_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.max_lines_visible = 2
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size.y = 60.0
	_codex_bind_stage_font(label, SemanticTypography.ROLE_FIELD, 24, SemanticTypography.role_min(SemanticTypography.ROLE_FIELD), SemanticTypography.role_max(SemanticTypography.ROLE_FIELD))
	label.add_theme_color_override("font_color", CODEX_PL_CARD_BODY_COLOR)
	row.add_child(label)
	return label




func _codex_label(parent: Control, text: String, font_size: int, color: Color, max_lines := 0) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_bind_stage_font(label, SemanticTypography.ROLE_BODY, font_size, SemanticTypography.role_min(SemanticTypography.ROLE_BODY), SemanticTypography.role_max(SemanticTypography.ROLE_BODY))
	label.add_theme_color_override("font_color", color)
	if max_lines > 0:
		label.clip_text = true
		label.max_lines_visible = max_lines
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.y = ceilf(float(_codex_font_size(SemanticTypography.ROLE_BODY, font_size, 17, 32) * max_lines) * 1.18)
	parent.add_child(label)
	return label




func _codex_font_size(role: StringName, base_size: int, min_size := 10, max_size := 44) -> int:
	return _codex_stage_font_size(role, base_size, min_size, max_size)




func _codex_stage_font_size(role: StringName, design_size: int, min_visual_size: int, max_visual_size: int) -> int:
	# CodexStage scales Controls and fonts together. Keep design sizes inside the
	# responsive band, but compensate locally when the visual result would fall
	# below the accepted minimum or exceed the cap.
	var viewport_size := Vector2(1920, 1080)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var stage_scale := maxf(0.01, minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0))
	return SemanticTypography.resolve_transform_aware(
		role,
		design_size,
		stage_scale,
		min_visual_size,
		max_visual_size
	)




func _codex_update_tab_selection(tabs_row: Control, section_id: String) -> void:
	# Активный/неактивные табы — модуляцией, как _atlas_apply_tab_state.
	if tabs_row == null:
		return
	for child in tabs_row.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button.name == "CodexTab_%s" % section_id
		button.modulate = Color(1.0, 0.94, 0.74, 1.0) if selected else Color(0.74, 0.76, 0.84, 0.92)




# Подсветка выбранной карточки записи: перекладываем «кожаный ряд» selected-стилем.
func _codex_set_selected_entry(content: PanelContainer, button: Button) -> void:
	if content == null or not is_instance_valid(content) or button == null or not is_instance_valid(button):
		return
	var previous: Button = null
	if content.has_meta("codex_selected_entry"):
		previous = content.get_meta("codex_selected_entry") as Button
	if previous == button:
		return
	if previous != null and is_instance_valid(previous):
		_codex_apply_entry_theme(previous, false)
	_codex_apply_entry_theme(button, true)
	content.set_meta("codex_selected_entry", button)




func _codex_attach_entry_detail(list: VBoxContainer, row: HBoxContainer, detail_data: Dictionary) -> void:
	var button := row.get_meta("entry_button", null) as Button
	var detail_panel := list.get_meta("codex_detail_panel", null) as PanelContainer
	var scroll := list.get_meta("codex_section_scroll", null) as ScrollContainer
	var content := list.get_meta("codex_content_panel", null) as PanelContainer
	if scroll != null and not scroll.has_meta("codex_default_detail"):
		scroll.set_meta("codex_default_detail", detail_data)
		if button != null:
			scroll.set_meta("codex_default_entry_button", button)
	if button == null or detail_panel == null:
		return
	button.set_meta("codex_detail_data", detail_data)
	button.pressed.connect(func() -> void:
		_codex_mark_entry_read(list, button)
		_codex_set_selected_entry(content, button)
		_codex_update_detail(detail_panel, detail_data)
	)




func _codex_mark_entry_read(list: VBoxContainer, button: Button) -> void:
	if button == null or not bool(button.get_meta("codex_is_unread", false)):
		return
	var refs: Array = button.get_meta("codex_unread_refs", []) as Array
	for raw_ref in refs:
		var ref := raw_ref as Dictionary
		game.meta_state = game.META_PROGRESSION.mark_codex_read(game.meta_state, str(ref.get("category", "")), str(ref.get("id", "")))
	game.save_meta_progression()
	button.set_meta("codex_is_unread", false)
	button.set_meta("codex_unread_refs", [])
	var badge := button.get_node_or_null("CodexUnreadBadge") as TextureRect
	if badge != null:
		badge.visible = false
	var row: HBoxContainer = null
	if button.get_child_count() > 0:
		row = button.get_child(0) as HBoxContainer
	if row != null:
		row.offset_right = -30.0
	if str(button.get_meta("codex_entry_category", "")) == "characters":
		var unread_count := 0
		for sibling in list.get_children():
			if sibling != button and bool(sibling.get_meta("codex_is_unread", false)):
				unread_count += 1
		list.move_child(button, unread_count)
	var content := list.get_meta("codex_content_panel", null) as PanelContainer
	codex_unlock_presenter.refresh_tab_badges(content)




func _codex_update_detail(detail_panel: PanelContainer, detail_data: Dictionary) -> void:
	# SCRUM-954 / accepted SCRUM-1017 geometry. One large contained preview, two
	# calm semantic chips and one lower dossier scroll replace the old split rails
	# and stray preview bars. Related stat projections live inside that same lower
	# scroll so the screen has exactly two scrollbar lanes: list and dossier.
	if detail_panel == null or not is_instance_valid(detail_panel):
		return
	for child in detail_panel.get_children():
		detail_panel.remove_child(child)
		child.queue_free()

	var detail_root := Control.new()
	detail_root.name = "CodexDetailContent"
	detail_root.custom_minimum_size = Vector2(720, 760)
	detail_panel.add_child(detail_root)

	var title := Label.new()
	title.name = "CodexDetailTitle"
	title.text = str(detail_data.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.max_lines_visible = 2
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_codex_bind_stage_font(title, SemanticTypography.ROLE_TITLE, 22, SemanticTypography.role_min(SemanticTypography.ROLE_TITLE), SemanticTypography.role_max(SemanticTypography.ROLE_TITLE))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	# Transform-aware semantic title sizing raises the compact-stage authored
	# font so its *visual* size stays in band. Give that larger local font a 60px
	# design lane; the lane still ends before the preview rail at y=76.
	_codex_set_design_rect(title, Rect2(104, 8, 508, 60))
	detail_root.add_child(title)

	# Compatibility rail names are retained for gamepad/tests, but their geometry
	# now maps directly to the accepted preview and chip zones.
	var left_rail := Control.new()
	left_rail.name = "CodexDetailLeftRail"
	_codex_set_design_rect(left_rail, Rect2(12, 76, 300, 300))
	detail_root.add_child(left_rail)
	var portrait_slot := PanelContainer.new()
	portrait_slot.name = "CodexDetailPortraitSlot"
	portrait_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	var portrait_style := _codex_dossier_style(1.0, Vector4(32.0, 26.0, 32.0, 26.0))
	portrait_slot.add_theme_stylebox_override("panel", portrait_style)
	left_rail.add_child(portrait_slot)
	var texture := detail_data.get("texture", null) as Texture2D
	var portrait := TextureRect.new()
	portrait.name = "CodexDetailPortraitTexture"
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var source_path := str(detail_data.get("texture_path", CodexImageFit.canonical_path(texture)))
	var image_policy := str(detail_data.get("image_policy", CodexImageFit.POLICY_CONTAIN))
	portrait.texture = CodexImageFit.texture_view(texture, source_path, image_policy, Vector2(236.0, 248.0))
	portrait.set_meta("codex_source_path", source_path)
	portrait.set_meta("codex_image_policy", image_policy)
	portrait.self_modulate = detail_data.get("texture_tint", Color.WHITE)
	_codex_pl_make_nearest(portrait)
	portrait_slot.add_child(portrait)

	var right_rail := Control.new()
	right_rail.name = "CodexDetailRightRail"
	_codex_set_design_rect(right_rail, Rect2(336, 102, 330, 156))
	detail_root.add_child(right_rail)
	var chips: Array = detail_data.get("chips", [])
	if not chips.is_empty():
		var chip_row := HBoxContainer.new()
		chip_row.name = "CodexDetailChipRow"
		chip_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		right_rail.add_child(chip_row)
		var chip_column := VBoxContainer.new()
		chip_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_column.add_theme_constant_override("separation", 16)
		chip_row.add_child(chip_column)
		var visible_chips: Array = chips.slice(0, mini(2, chips.size()))
		# Locked state is interaction-critical. If affinity produces a third chip,
		# keep the primary semantic chip plus «Заперто» inside the two authored rows.
		if chips.has("Заперто") and not visible_chips.has("Заперто"):
			visible_chips = [chips[0], "Заперто"]
		for chip_text in visible_chips:
			var chip := PanelContainer.new()
			chip.name = "CodexDetailChip"
			chip.custom_minimum_size = Vector2(330, 70)
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chip.add_theme_stylebox_override("panel", _codex_chip_style(0.96, Vector4(18, 14, 18, 14)))
			chip_column.add_child(chip)
			var chip_label := Label.new()
			chip_label.text = str(chip_text)
			chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			chip_label.max_lines_visible = 2
			_codex_bind_stage_font(chip_label, SemanticTypography.ROLE_BODY, 24, SemanticTypography.role_min(SemanticTypography.ROLE_BODY), SemanticTypography.role_max(SemanticTypography.ROLE_BODY))
			chip_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
			chip.add_child(chip_label)

	var parchment := PanelContainer.new()
	parchment.name = "CodexDetailParchmentInset"
	parchment.add_theme_stylebox_override("panel", _codex_lore_style(Vector4(32, 26, 42, 26)))
	_codex_set_design_rect(parchment, Rect2(12, 398, 684, 356))
	detail_root.add_child(parchment)
	var text_scroll := ScrollContainer.new()
	text_scroll.name = "CodexDetailTextScroll"
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_scroll.follow_focus = true
	parchment.add_child(text_scroll)
	var text_box := VBoxContainer.new()
	text_box.name = "CodexDetailTextBody"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 10)
	text_scroll.add_child(text_box)

	var related_entries: Array = detail_data.get("related", [])
	if not related_entries.is_empty():
		var related_panel := PanelContainer.new()
		related_panel.name = "CodexDetailRelatedPanel"
		related_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		related_panel.add_theme_stylebox_override("panel", _codex_inset_style(0.72, Vector4(14, 12, 14, 12)))
		text_box.add_child(related_panel)
		var related_box := VBoxContainer.new()
		related_box.name = "CodexDetailRelatedContent"
		related_box.add_theme_constant_override("separation", 6)
		related_panel.add_child(related_box)
		var related_title := _codex_label(related_box, str(detail_data.get("related_title", "Связанные параметры")), 24, Color(0.96, 0.90, 0.68, 1.0), 2)
		related_title.name = "CodexDetailRelatedTitle"
		var related_scroll := ScrollContainer.new()
		related_scroll.name = "CodexDetailRelatedScroll"
		related_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		related_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		related_scroll.custom_minimum_size.y = maxf(32.0, float(related_entries.size()) * 32.0)
		related_box.add_child(related_scroll)
		var related_list := VBoxContainer.new()
		related_list.name = "CodexDetailRelatedList"
		related_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		related_list.add_theme_constant_override("separation", 4)
		related_scroll.add_child(related_list)
		for related_entry in related_entries:
			var related_dict := related_entry as Dictionary
			var related_text := str(related_dict.get("title", ""))
			if related_text != "":
				_codex_label(related_list, related_text, 22, Color(0.84, 0.80, 0.70, 0.96), 2)

	# SCRUM-881: глубокое досье — структурированные секции (бронзовый заголовок →
	# титулы записей золотом → светлое тело) из СУЩЕСТВУЮЩИХ данных
	# codex_data/ProgressionData; сырой body_lines остаётся fallback-путём.
	var sections: Array = detail_data.get("sections", [])
	if sections.is_empty():
		var lines: Array = detail_data.get("body_lines", [])
		for line in lines:
			if str(line) != "":
				_codex_label(text_box, str(line), 24, Color(0.88, 0.92, 0.98, 0.96))
	else:
		var heading_index := 0
		for section in sections:
			var section_dict := section as Dictionary
			if section_dict == null or section_dict.is_empty():
				continue
			var heading := str(section_dict.get("heading", ""))
			if heading != "":
				if heading_index > 0:
					var section_gap := Control.new()
					section_gap.custom_minimum_size = Vector2(0.0, 8.0)
					text_box.add_child(section_gap)
				var heading_label := _codex_label(text_box, heading, 26, Color(0.78, 0.66, 0.44, 1.0))
				heading_label.name = "CodexDetailSectionHeading_%d" % heading_index
				heading_index += 1
			for line in section_dict.get("lines", []):
				if line is Dictionary:
					var line_dict := line as Dictionary
					var line_title := str(line_dict.get("title", ""))
					if line_title != "":
						_codex_label(text_box, line_title, 24, Color(0.96, 0.90, 0.68, 1.0))
					var line_text := str(line_dict.get("text", ""))
					if line_text != "":
						_codex_label(text_box, line_text, 24, Color(0.88, 0.92, 0.98, 0.96))
				elif str(line) != "":
					_codex_label(text_box, str(line), 24, Color(0.88, 0.92, 0.98, 0.96))




# --- SCRUM-881: секции глубокого досье. СТРОГО существующие данные из
# codex_data/ProgressionData/StatFormulas/GLOSSARY; пустое поле = секция/строка
# пропускается (никаких заглушек). Формат: [{heading, lines:[String|{title,text}]}].
func _codex_character_sections(character: Dictionary) -> Array:
	var character_id := str(character.get("id", ""))
	var sections := []
	# FAN-1080: происхождение Хранителя — осколок-мир из лора (lore_data.gd).
	var origin := LORE_DATA.class_origin(character_id)
	if origin != "":
		sections.append({"heading": "Происхождение", "lines": [origin]})
	# Идентичность/роль: описание конфига + механическая идентичность класса + плейстайл.
	var identity: Dictionary = game.PROGRESSION_DATA.class_mechanic_identity(character_id)
	var identity_lines := []
	if str(character.get("description", "")) != "":
		identity_lines.append(str(character["description"]))
	var identity_title := str(identity.get("identity_title", ""))
	var identity_summary := str(identity.get("summary", ""))
	if identity_title != "" or identity_summary != "":
		identity_lines.append({"title": identity_title, "text": identity_summary})
	if str(character.get("playstyle", "")) != "":
		identity_lines.append(str(character["playstyle"]))
	if not identity_lines.is_empty():
		sections.append({"heading": "Идентичность и роль", "lines": identity_lines})
	# Сильные и слабые стороны.
	var side_lines := []
	if str(character.get("strengths", "")) != "":
		side_lines.append("Сильное: %s" % character["strengths"])
	if str(character.get("weaknesses", "")) != "":
		side_lines.append("Слабое: %s" % character["weaknesses"])
	if not side_lines.is_empty():
		sections.append({"heading": "Сильные и слабые стороны", "lines": side_lines})
	# 8 базовых характеристик компактными парами; ★ — главный стат класса.
	var base_stats: Dictionary = game.PROGRESSION_DATA.base_stats(character_id)
	var main_attribute := str(game.PROGRESSION_DATA.class_main_attribute(character_id))
	var stat_lines := []
	var stat_pair := PackedStringArray()
	for stat_id in game.PROGRESSION_DATA.STAT_NAMES.keys():
		var stat_piece := "%s: %d" % [str(game.PROGRESSION_DATA.STAT_NAMES[stat_id]), int(roundf(float(base_stats.get(stat_id, 0.0))))]
		if str(stat_id) == main_attribute:
			stat_piece += " ★"
		stat_pair.append(stat_piece)
		if stat_pair.size() == 2:
			stat_lines.append("  ·  ".join(stat_pair))
			stat_pair = PackedStringArray()
	if stat_pair.size() > 0:
		stat_lines.append("  ·  ".join(stat_pair))
	var priorities: Array = game.PROGRESSION_DATA.attribute_priorities(character_id)
	if not priorities.is_empty():
		var priority_names := PackedStringArray()
		for priority_id in priorities:
			priority_names.append(str(game.PROGRESSION_DATA.STAT_NAMES.get(priority_id, priority_id)))
		stat_lines.append("Приоритеты прокачки: %s." % " → ".join(priority_names))
	if not stat_lines.is_empty():
		sections.append({"heading": "Базовые характеристики", "lines": stat_lines})
	# Три оружия: полное описание + identity-строка механики из ProgressionData.
	var weapon_lines := []
	for weapon in character.get("weapons", []):
		var weapon_text := str(weapon.get("description", ""))
		var weapon_identity := str(game.PROGRESSION_DATA.weapon_mechanic_identity(character_id, str(weapon.get("id", ""))))
		if weapon_identity != "":
			weapon_text += "\nМеханика: %s." % weapon_identity
		weapon_lines.append({"title": str(weapon.get("title", "")), "text": weapon_text})
	if not weapon_lines.is_empty():
		sections.append({"heading": "Оружие", "lines": weapon_lines})
	# FAN-2515: у каждого оружия своя ульта из канонического реестра — Кодекс
	# показывает ровно то, что увидят HUD и досье паузы при этом выборе.
	var ultimate_lines := []
	for weapon in character.get("weapons", []):
		var ultimate: Dictionary = (weapon as Dictionary).get("ultimate", {})
		if ultimate.is_empty():
			continue
		ultimate_lines.append({
			"title": "%s — %s" % [str((weapon as Dictionary).get("title", "")), str(ultimate.get("title", ""))],
			"text": str(ultimate.get("description", "")),
		})
	if not ultimate_lines.is_empty():
		sections.append({"heading": "Ультимейты", "lines": ultimate_lines})
	# Классовые вознесения: реальные титулы ступеней из ASCENSION_LEVELS.
	var ascension_levels: Array = game.PROGRESSION_DATA.ascension_levels(character_id)
	if not ascension_levels.is_empty():
		var ascension_names := PackedStringArray()
		for ascension_entry in ascension_levels:
			var ascension_title := str((ascension_entry as Dictionary).get("title", ""))
			if ascension_title != "":
				ascension_names.append(ascension_title)
		if not ascension_names.is_empty():
			sections.append({"heading": "Вознесения класса", "lines": ["Ступени: %s." % " → ".join(ascension_names)]})
	return sections




func _codex_monster_sections(monster: Dictionary) -> Array:
	# FAN-1080: сборка досье монстра перенесена в scripts/ui/lore_screens.gd
	# (static-quality ратчет ui_screens.gd; лор-секции живут там же).
	return LoreScreens.codex_monster_sections(self, monster)




# SCRUM-963: классовый артефакт заперт в кодексе, пока мета-Возвышение ЕГО
# класса ниже requires_ascension (тот же порог, что гейт выдачи SCRUM-961).
func _codex_artifact_locked(definition: Dictionary) -> bool:
	var required := int(definition.get("requires_ascension", 0))
	if required <= 0:
		return false
	var affinity: Array = definition.get("class_affinity", [])
	if affinity.is_empty():
		return false
	for class_id in affinity:
		if game.ascension_level_for(str(class_id)) >= required:
			return false
	return true




func _codex_artifact_unlock_condition(definition: Dictionary) -> String:
	var class_names := PackedStringArray()
	for class_id in definition.get("class_affinity", []):
		class_names.append(str(CLASS_RU.get(str(class_id), class_id)))
	return "Откроется на Возвышении %d — %s." % [int(definition.get("requires_ascension", 0)), ", ".join(class_names)]




func _codex_artifact_sections(artifact: Dictionary, definition: Dictionary, locked := false) -> Array:
	var sections := []
	# Запертая запись: эффект скрыт, досье показывает условие разблокировки.
	if locked:
		sections.append({"heading": "Как открыть", "lines": [
			_codex_artifact_unlock_condition(definition),
			"Классовые артефакты выпадают только своему классу.",
		]})
		sections.append({"heading": "Свойства", "lines": ["Редкость: %s." % _artifact_tier_text(definition)]})
		return sections
	# Полный текст эффекта + классовая пометка (SCRUM-963: «Класс: … · Возвышение N»).
	var effect_lines := []
	if str(artifact.get("description", "")) != "":
		effect_lines.append(str(artifact["description"]))
	var affinity_note := _artifact_affinity_note(definition)
	if not affinity_note.is_empty():
		effect_lines.append(str(affinity_note["text"]))
	if not effect_lines.is_empty():
		sections.append({"heading": "Эффект", "lines": effect_lines})
	# Свойства: редкость/источник, цена, активность-триггер.
	var property_lines := []
	if str(artifact.get("source", "")) == "shop":
		property_lines.append("Источник: походный магазин.")
	else:
		property_lines.append("Редкость: %s." % _artifact_tier_text(definition))
	if definition.has("cost"):
		property_lines.append("Базовая цена: %d золота." % int(definition.get("cost", 0)))
	if bool(definition.get("active", false)):
		property_lines.append("Активный артефакт: срабатывает сам по триггеру из описания эффекта.")
	if not property_lines.is_empty():
		sections.append({"heading": "Свойства", "lines": property_lines})
	# Классовый артефакт: класс-владелец + каноническое пояснение из глоссария.
	var affinity_list: Array = definition.get("class_affinity", [])
	if not affinity_list.is_empty():
		var class_names := PackedStringArray()
		for class_id in affinity_list:
			class_names.append(str(CLASS_RU.get(str(class_id), class_id)))
		var affinity_lines := ["Класс: %s." % ", ".join(class_names)]
		var affinity_term: Dictionary = GLOSSARY.definition("affinity")
		if str(affinity_term.get("desc", "")) != "":
			affinity_lines.append(str(affinity_term["desc"]))
		sections.append({"heading": "Классовый артефакт", "lines": affinity_lines})
	return sections




func _codex_stat_sections(stat: Dictionary) -> Array:
	var stat_id := str(stat.get("id", ""))
	var sections := []
	var description_lines := []
	if str(stat.get("description", "")) != "":
		description_lines.append(str(stat["description"]))
	# FAN-1927: канонические оси несут формулу в самой записи (у урон-осей — оба
	# канала); базовые характеристики по-прежнему берут её из STAT_DEFINITIONS.
	var formula := str(stat.get("formula", ""))
	if formula == "":
		formula = str((StatFormulas.STAT_DEFINITIONS.get(stat_id, {}) as Dictionary).get("formula", ""))
	if formula != "":
		description_lines.append("Формула: %s" % formula)
	if not description_lines.is_empty():
		sections.append({"heading": "Описание", "lines": description_lines})
	# FAN-1927: живые значения выбранного героя — тот же axis_snapshot, что у
	# Pause/Hero Select: сейчас/максимум/канал; ineligible ось не подаётся как
	# доступная этому герою.
	if str(stat.get("type", "")) == "derived" and game.selected_character_id != "":
		var live_lines := _codex_axis_live_lines(stat_id)
		if not live_lines.is_empty():
			sections.append({"heading": "Этот герой", "lines": live_lines})
	if str(stat.get("influences", "")) != "":
		sections.append({"heading": "Влияние", "lines": ["Влияет на: %s" % str(stat["influences"])]})
	# Связанные записи: классы, у которых этот стат — главный (identity-данные).
	if str(stat.get("type", "")) == "base":
		var main_class_names := PackedStringArray()
		for character_id in game.PROGRESSION_DATA.character_ids():
			if str(game.PROGRESSION_DATA.class_main_attribute(str(character_id))) == stat_id:
				var config: Dictionary = game.PROGRESSION_DATA.character_config(str(character_id))
				main_class_names.append(str(config.get("title", character_id)))
		if not main_class_names.is_empty():
			sections.append({"heading": "Связанные классы", "lines": ["Главный стат для: %s." % ", ".join(main_class_names)]})
	return sections




# FAN-1927: живые строки «Этот герой» оси кодекса — единый view-model
# (AttributeSurfaces.codex_axis_live_lines).
func _codex_axis_live_lines(axis_id: String) -> Array:
	return AttributeSurfaces.codex_axis_live_lines(
		axis_id, game.selected_character_id, _active_stats_snapshot(), _active_modifiers_snapshot(),
		_active_weapon_config(), game.PROGRESSION_DATA.base_stats(game.selected_character_id))




func _codex_ascension_sections(entry: Dictionary) -> Array:
	var sections := []
	if str(entry.get("description", "")) != "":
		sections.append({"heading": "Усложнение", "lines": [str(entry["description"])]})
	# Кумулятив: уровень N включает все усложнения 1..N (реальный хелпер данных).
	var cumulative_lines: Array = game.PROGRESSION_DATA.ascension_modifier_lines(int(entry.get("level", 0)))
	if not cumulative_lines.is_empty():
		sections.append({"heading": "Кумулятивно на этом уровне", "lines": cumulative_lines})
	return sections
