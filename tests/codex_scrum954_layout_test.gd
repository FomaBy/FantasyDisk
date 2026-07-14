extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const MainCompileGuard := preload("res://tests/main_compile_guard.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const LoreData := preload("res://scripts/lore_data.gd")
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const ASCENSION_ICON_PATH := "res://assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_icon_ascension.png"
const CODEX_RUNTIME_DIR := "res://assets/sprites/ui/atlas_style/codex/"
const CODEX_BG_PATH := CODEX_RUNTIME_DIR + "bg_codex_sanctum.png"
const CODEX_PANEL_PATH := CODEX_RUNTIME_DIR + "panel_9slice.png"
const CODEX_ENTRY_PATH := CODEX_RUNTIME_DIR + "entry_card_516x154.png"
const CODEX_DOSSIER_PATH := CODEX_RUNTIME_DIR + "dossier_frame.png"
const CODEX_CREST_PATH := CODEX_RUNTIME_DIR + "codex_crest.png"
const EXPECTED_TABS := [
	["characters", "Персонажи"], ["monsters", "Монстры"],
	["artifacts", "Артефакты"], ["characteristics", "Параметры"],
	["attributes", "Атрибуты"], ["ascension", "Возвыш."],
	["chronicle", "Летопись"],
]

var errors := PackedStringArray()
var report := PackedStringArray(["# SCRUM-954 Codex Layout Matrix", ""])


func _initialize() -> void:
	# FAN-1087: компиляция/инстанцирование Main — жёсткий гейт, не false-green.
	var gate_problems := MainCompileGuard.blocking_errors()
	if not gate_problems.is_empty():
		for problem in gate_problems:
			push_error("FAN-1087 main-dependency gate: %s" % problem)
		quit(1)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum954")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var report_file := FileAccess.open("%s/codex_layout_matrix.md" % qa_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report))
		report_file.close()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-954 Codex layout test passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.ui._show_codex_screen()
	for _frame_index in range(6):
		await process_frame

	var context := "Codex %s" % str(viewport_size)
	report.append("## %s" % context)
	var stage := main.find_child("CodexStage", true, false) as Control
	if stage == null:
		errors.append("%s: missing CodexStage." % context)
		viewport.queue_free()
		await process_frame
		return
	var expected_scale := minf(float(viewport_size.x) / 1920.0, float(viewport_size.y) / 1080.0)
	var expected_offset := (Vector2(viewport_size) - Vector2(1920, 1080) * expected_scale) * 0.5
	if not is_equal_approx(stage.scale.x, expected_scale) or stage.position.distance_to(expected_offset) > 1.0:
		errors.append("%s: stage scale/letterbox is %s @ %s, expected %.4f @ %s." % [context, str(stage.scale), str(stage.position), expected_scale, str(expected_offset)])

	var rect_contract := {
		"CodexTitleFrame": Rect2(72, 36, 340, 112),
		"CodexBackButton": Rect2(1580, 46, 268, 96),
		"CodexCrest": Rect2(908, 24, 104, 104),
		"CodexNavPanel": Rect2(72, 172, 324, 840),
		"CodexContent": Rect2(420, 172, 620, 840),
		"CodexCenterListHost": Rect2(452, 278, 556, 690),
		"CodexEntryCard": Rect2(460, 290, 516, 154),
		"CodexPortraitSlot": Rect2(480, 310, 122, 114),
		"CodexEntryName": Rect2(616, 337, 330, 60),
		"CodexDetailPanel": Rect2(1064, 172, 784, 840),
		"CodexDetailTitle": Rect2(1200, 216, 508, 60),
		"CodexDetailPortraitSlot": Rect2(1108, 284, 300, 300),
		"CodexDetailPortraitTexture": Rect2(1140, 310, 236, 248),
		"CodexDetailParchmentInset": Rect2(1108, 606, 684, 356),
	}
	for node_name in rect_contract:
		var control := main.find_child(str(node_name), true, false) as Control
		if control == null:
			errors.append("%s: missing %s." % [context, node_name])
			continue
		var expected := _scaled_rect(viewport_size, rect_contract[node_name])
		var actual := control.get_global_rect()
		report.append("- `%s`: `%s`" % [node_name, str(actual)])
		if not _rect_near(actual, expected, 1.5):
			errors.append("%s: %s rect %s != %s." % [context, node_name, str(actual), str(expected)])
	var background := main.find_child("UnifiedBackground_codex", true, false) as TextureRect
	if background == null or background.texture == null or background.texture.resource_path != CODEX_BG_PATH:
		errors.append("%s: Codex background is not the FAN-1069 sanctum skin." % context)
	var crest := main.find_child("CodexCrest", true, false) as TextureRect
	if crest == null or crest.texture == null or crest.texture.resource_path != CODEX_CREST_PATH:
		errors.append("%s: missing FAN-1069 Codex crest." % context)
	for panel_name in ["CodexTitleFrame", "CodexNavPanel", "CodexContent", "CodexDetailPanel"]:
		var panel := main.find_child(panel_name, true, false) as PanelContainer
		if panel == null or _style_texture_path(panel.get_theme_stylebox("panel")) != CODEX_PANEL_PATH:
			errors.append("%s: %s does not use the FAN-1069 panel skin." % [context, panel_name])
	var first_card := main.find_child("CodexEntryCard", true, false) as Button
	if first_card == null or _style_texture_path(first_card.get_theme_stylebox("normal")) != CODEX_ENTRY_PATH:
		errors.append("%s: first Codex entry does not use the FAN-1069 entry card." % context)
	var dossier_slot := main.find_child("CodexDetailPortraitSlot", true, false) as PanelContainer
	var dossier_scroll := main.find_child("CodexDetailParchmentInset", true, false) as PanelContainer
	if dossier_slot == null or _style_texture_path(dossier_slot.get_theme_stylebox("panel")) != CODEX_DOSSIER_PATH:
		errors.append("%s: dossier frame is missing from CodexDetailPortraitSlot." % context)
	if dossier_scroll == null or _style_texture_path(dossier_scroll.get_theme_stylebox("panel")) != CODEX_PANEL_PATH:
		errors.append("%s: lore scroll does not use the ornament-safe FAN-1069 panel frame." % context)
	var codex_back := main.find_child("CodexBackButton", true, false) as Button
	if codex_back != null:
		_check_button_family(codex_back, "text/back_260x104", "%s back" % context)

	# FAN-1080: 7 вкладок с шагом 104 (Летопись добавлена последней).
	var nav_y := [234.0, 338.0, 442.0, 546.0, 650.0, 754.0, 858.0]
	for tab_index in range(EXPECTED_TABS.size()):
		var tab_spec: Array = EXPECTED_TABS[tab_index]
		var tab := main.find_child("CodexTab_%s" % str(tab_spec[0]), true, false) as Button
		if tab == null:
			errors.append("%s: missing tab %s." % [context, tab_spec[0]])
			continue
		if tab.text != str(tab_spec[1]) or tab.icon != null or tab.alignment != HORIZONTAL_ALIGNMENT_CENTER:
			errors.append("%s: tab %s must be centered Russian-only text without an emblem." % [context, tab_spec[0]])
		_check_button_family(tab, UIButtonFamily.FAMILY_MAIN_MENU, "%s tab %s" % [context, tab_spec[0]])
		var expected_tab_rect := _scaled_rect(viewport_size, Rect2(104, nav_y[tab_index], 260, 72))
		if not _rect_near(tab.get_global_rect(), expected_tab_rect, 1.5):
			errors.append("%s: tab %s rect %s != %s." % [context, tab_spec[0], str(tab.get_global_rect()), str(expected_tab_rect)])
		var tab_style := tab.get_theme_stylebox("normal") as StyleBoxTexture
		if tab_style == null or tab_style.texture == null or tab_style.texture.resource_path.contains("minimal_metal_codex_tab"):
			errors.append("%s: tab %s still uses the retired yellow Codex plate." % [context, tab_spec[0]])
		elif tab.get_minimum_size().x > tab.size.x + 0.5:
			errors.append("%s: tab %s text/content safe zone clips at %s." % [context, tab_spec[0], str(tab.size)])

	var section_instance_ids := {}
	for tab_spec in EXPECTED_TABS:
		var section_id := str(tab_spec[0])
		var tab := main.find_child("CodexTab_%s" % section_id, true, false) as Button
		if tab == null:
			continue
		tab.pressed.emit()
		await process_frame
		await process_frame
		var section := main.find_child("CodexSection_%s" % section_id, true, false) as ScrollContainer
		var list := main.find_child("CodexSectionList_%s" % section_id, true, false) as VBoxContainer
		if section == null or list == null or not section.is_visible_in_tree():
			errors.append("%s: %s did not lazy-build into a visible cached section." % [context, section_id])
			continue
		section_instance_ids[section_id] = section.get_instance_id()
		var expected_entries := _expected_entries(section_id)
		var cards := list.get_children()
		if cards.size() != expected_entries.size():
			errors.append("%s: %s has %d rows, expected %d." % [context, section_id, cards.size(), expected_entries.size()])
		var checked_rows := mini(cards.size(), expected_entries.size())
		for row_index in range(checked_rows):
			_check_entry_card(cards[row_index] as Button, expected_entries[row_index] as Dictionary, expected_scale, "%s %s row %d" % [context, section_id, row_index])
		var preview := main.find_child("CodexDetailPortraitTexture", true, false) as TextureRect
		if not expected_entries.is_empty():
			var expected_preview_path := str((expected_entries[0] as Dictionary)["texture"])
			if preview == null or preview.texture == null or _canonical_texture_path(preview.texture) != expected_preview_path or preview.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				errors.append("%s: %s dossier preview is not the first canonical entry image %s." % [context, section_id, expected_preview_path])
		if section_id == "artifacts":
			await _check_locked_artifact(main, cards, context)
		var related_scroll := main.find_child("CodexDetailRelatedScroll", true, false) as ScrollContainer
		if related_scroll != null and related_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			errors.append("%s: %s related projection creates a third scrollbar lane." % [context, section_id])

	# Reopening a section must reuse the original lazy cache node.
	for tab_spec in EXPECTED_TABS:
		var section_id := str(tab_spec[0])
		var tab := main.find_child("CodexTab_%s" % section_id, true, false) as Button
		if tab == null or not section_instance_ids.has(section_id):
			continue
		tab.pressed.emit()
		await process_frame
		var reopened := main.find_child("CodexSection_%s" % section_id, true, false)
		if reopened == null or reopened.get_instance_id() != int(section_instance_ids[section_id]):
			errors.append("%s: %s section was rebuilt instead of reused from lazy cache." % [context, section_id])

	# Default character dossier is long enough to expose exactly the two accepted
	# active lanes: center list + lower detail text.
	var characters_tab := main.find_child("CodexTab_characters", true, false) as Button
	characters_tab.pressed.emit()
	await process_frame
	var active_vertical_scrollbars := 0
	for node in main.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll != null and scroll.is_visible_in_tree() and scroll.get_v_scroll_bar().is_visible_in_tree():
			active_vertical_scrollbars += 1
	if active_vertical_scrollbars != 2:
		errors.append("%s: expected exactly two active vertical scrollbar lanes, got %d." % [context, active_vertical_scrollbars])
	_check_effective_typography(main, context)
	if DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		if image != null:
			var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum954")
			DirAccess.make_dir_recursive_absolute(qa_dir)
			image.save_png("%s/codex_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])
	if viewport_size == Vector2i(1920, 1080):
		await _check_same_instance_resize(viewport, main, context)

	viewport.queue_free()
	await process_frame


func _expected_entries(section_id: String) -> Array:
	var result := []
	match section_id:
		"characters":
			for entry in CodexData.characters():
				result.append({"title": str(entry["title"]), "texture": str(entry["sprite"])})
		"monsters":
			for kind in ["standard", "elite", "mini_elite", "boss"]:
				for entry in CodexData.monsters():
					if str(entry["kind"]) == kind:
						result.append({"title": str(entry["title"]), "texture": str(entry["sprite"])})
		"artifacts":
			for entry in CodexData.artifacts():
				var artifact_id := str(entry["id"])
				var texture_path := "res://assets/sprites/ui/icons/artifacts/artifact_%s.png" % artifact_id
				if artifact_id.begins_with("shop_"):
					texture_path = "res://assets/sprites/ui/icons/shop/shop_%s.png" % artifact_id
				result.append({"title": str(entry["title"]), "texture": texture_path})
		"characteristics":
			for entry in CodexData.characteristics():
				var texture := UIIconRegistry.texture_for(str(entry["id"]))
				result.append({"title": str(entry["title"]), "texture": texture.resource_path if texture != null else ""})
		"attributes":
			for entry in CodexData.attributes():
				var texture := UIIconRegistry.texture_for(str(entry["id"]))
				result.append({"title": str(entry["title"]), "texture": texture.resource_path if texture != null else ""})
		"ascension":
			for entry in CodexData.ascensions():
				result.append({"title": "%d. %s" % [entry["level"], entry["title"]], "texture": ASCENSION_ICON_PATH})
		"chronicle":
			for entry in LoreData.chronicle_entries():
				result.append({"title": str(entry["title"]), "texture": str(entry["icon"])})
	return result


func _check_entry_card(card: Button, expected: Dictionary, stage_scale: float, context: String) -> void:
	if card == null:
		errors.append("%s: missing entry card." % context)
		return
	if str(card.get_meta(UIButtonFamily.META_FAMILY, "")) != UIButtonFamily.FAMILY_CONTENT_ROW:
		errors.append("%s: Codex entry must use the shared content_row family." % context)
	var names := card.find_children("CodexEntryName", "Label", true, false)
	var textures := card.find_children("*Texture", "TextureRect", true, false)
	if names.size() != 1 or textures.size() != 1:
		errors.append("%s: expected exactly one display-name and one image, got %d/%d." % [context, names.size(), textures.size()])
		return
	var name := names[0] as Label
	var texture_rect := textures[0] as TextureRect
	if name.text != str(expected["title"]) or name.text.contains(" — ") or name.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		errors.append("%s: row label '%s' is not the exact centered canonical display-name '%s'." % [context, name.text, str(expected["title"])])
	if texture_rect.texture == null or _canonical_texture_path(texture_rect.texture) != str(expected["texture"]):
		errors.append("%s: image path '%s' != canonical '%s'." % [context, _canonical_texture_path(texture_rect.texture), str(expected["texture"])])
	var image_well := texture_rect.get_parent() as Control
	if image_well == null or image_well.get_global_rect().size.x + 1.0 < 122.0 * stage_scale or image_well.get_global_rect().size.y + 1.0 < 114.0 * stage_scale:
		errors.append("%s: image well is smaller than 122x114 design pixels." % context)


func _check_locked_artifact(main: Node, cards: Array, context: String) -> void:
	for node in cards:
		var card := node as Button
		if card == null:
			continue
		var detail_data: Dictionary = card.get_meta("codex_detail_data", {})
		if not (detail_data.get("chips", []) as Array).has("Заперто"):
			continue
		card.pressed.emit()
		await process_frame
		var locked_chip_visible := false
		var chip_row := main.find_child("CodexDetailChipRow", true, false) as Control
		var rendered_chips := PackedStringArray()
		for chip_label_node in chip_row.find_children("*", "Label", true, false) if chip_row != null else []:
			var chip_label := chip_label_node as Label
			rendered_chips.append(chip_label.text)
			if chip_label.text == "Заперто":
				locked_chip_visible = true
		if not locked_chip_visible:
			errors.append("%s: locked artifact dossier dropped «Заперто»; rendered chips=%s." % [context, str(rendered_chips)])
		return
	errors.append("%s: artifact section did not expose a locked-state row for verification." % context)


func _check_effective_typography(main: Node, context: String) -> void:
	var stage := main.find_child("CodexStage", true, false) as Control
	var scale := stage.scale.x if stage != null else 1.0
	for node_name in ["CodexTab_characters", "CodexCenterTitle", "CodexEntryName", "CodexDetailTitle"]:
		var text_control := main.find_child(node_name, true, false) as Control
		if text_control == null:
			continue
		var effective_size := float(text_control.get_theme_font_size("font_size")) * scale
		if effective_size < 15.0 - 0.1 or effective_size > 30.0 + 0.1:
			errors.append("%s: %s effective font %.2f is outside 15..30px." % [context, node_name, effective_size])
	var body := main.find_child("CodexDetailTextBody", true, false) as Control
	if body == null:
		errors.append("%s: missing CodexDetailTextBody." % context)
		return
	for node in body.find_children("*", "Label", true, false):
		var label := node as Label
		var effective_size := float(label.get_theme_font_size("font_size")) * scale
		if effective_size < 17.0 - 0.1 or effective_size > 32.0 + 0.1:
			errors.append("%s: dossier label %s effective font %.2f is outside 17..32px." % [context, label.name, effective_size])


func _check_same_instance_resize(viewport: SubViewport, main: Node, context: String) -> void:
	for resized_to in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		viewport.size = resized_to
		for _frame_index in range(4):
			await process_frame
		var resize_context := "%s live-resized to %s" % [context, str(resized_to)]
		var stage := main.find_child("CodexStage", true, false) as Control
		var expected_scale := minf(float(resized_to.x) / 1920.0, float(resized_to.y) / 1080.0)
		if stage == null or not is_equal_approx(stage.scale.x, expected_scale):
			errors.append("%s: stage did not recompute uniform scale %.4f." % [resize_context, expected_scale])
			continue
		var nav_panel := main.find_child("CodexNavPanel", true, false) as Control
		var expected_nav := _scaled_rect(resized_to, Rect2(72, 172, 324, 840))
		if nav_panel == null or not _rect_near(nav_panel.get_global_rect(), expected_nav, 1.5):
			errors.append("%s: nav geometry did not follow the resized stage." % resize_context)
		_check_effective_typography(main, resize_context)


func _scaled_rect(viewport_size: Vector2, design_rect: Rect2) -> Rect2:
	var scale := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	var offset := (viewport_size - Vector2(1920, 1080) * scale) * 0.5
	return Rect2(offset + design_rect.position * scale, design_rect.size * scale)


func _rect_near(actual: Rect2, expected: Rect2, tolerance: float) -> bool:
	return actual.position.distance_to(expected.position) <= tolerance \
		and actual.size.distance_to(expected.size) <= tolerance


func _canonical_texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture.has_meta("codex_source_path"):
		return str(texture.get_meta("codex_source_path"))
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		return atlas.resource_path if atlas != null else ""
	return texture.resource_path


func _style_texture_path(style: StyleBox) -> String:
	if not (style is StyleBoxTexture):
		return ""
	var texture := (style as StyleBoxTexture).texture
	return texture.resource_path if texture != null else ""


func _check_button_family(button: Button, expected_family: String, context: String) -> void:
	var actual_family := str(button.get_meta(UIButtonFamily.META_FAMILY, ""))
	if actual_family != expected_family:
		errors.append("%s: family '%s' != '%s'." % [context, actual_family, expected_family])
		return
	var baseline_content := Vector4.ZERO
	for state in UIButtonFamily.STATES:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		var descriptor := UIButtonFamily.descriptor(expected_family, state)
		if style == null or style.texture == null:
			errors.append("%s: %s state is not a textured shared-family style." % [context, state])
			continue
		if style.texture.resource_path != str(descriptor.get("path", "")):
			errors.append("%s: %s texture '%s' != '%s'." % [context, state, style.texture.resource_path, str(descriptor.get("path", ""))])
		var content := Vector4(style.content_margin_left, style.content_margin_top, style.content_margin_right, style.content_margin_bottom)
		if state == "normal":
			baseline_content = content
		elif content != baseline_content:
			errors.append("%s: %s content margins shift geometry (%s != %s)." % [context, state, str(content), str(baseline_content)])
