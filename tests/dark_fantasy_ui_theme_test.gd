extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")
const DF_DIR := "res://assets/sprites/ui/frames/dark_fantasy/"
const MINIMAL_METAL_BUTTON_DIR := "res://assets/sprites/ui/frames/minimal_metal_buttons/"
const ORNATE_DIR := "res://assets/sprites/ui/frames/ornate/"
const UNIFIED_DIR := "res://assets/sprites/ui/frames/unified/"
const UNIFIED_METADATA_PATH := "res://docs/design/references/unified_master_frame/unified_master_frame_metadata.json"
const MINIMAL_METAL_METADATA_PATH := "res://docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json"
const MINIMAL_METAL_BUTTON_METADATA_PATH := "res://docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json"


func _initialize() -> void:
	var errors: Array[String] = []
	var unified_texture_margin := _expected_unified_texture_margin(errors)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	var start_button := main.find_child("MainMenuStartButton", true, false) as Button
	var settings_button := main.find_child("MainMenuSettingsButton", true, false) as Button
	var exit_button := main.find_child("MainMenuExitButton", true, false) as Button
	_expect_button_state_paths(start_button, "main_menu", errors)
	_expect_button_state_paths(settings_button, "main_menu", errors)
	_expect_button_state_paths(exit_button, "main_menu", errors)

	var ui = main.get("ui")
	if ui == null:
		errors.append("Main.ui is missing.")
	else:
		_expect_runtime_frame_style(ui.call("_panel_style"), "panel", errors, unified_texture_margin)
		_expect_runtime_frame_style(ui.call("_level_up_panel_style"), "level panel", errors, unified_texture_margin)
		_expect_runtime_frame_style(ui.call("_character_card_style"), "card", errors, unified_texture_margin)
		_expect_runtime_frame_style(ui.call("_hud_panel_style"), "HUD panel", errors, unified_texture_margin)
		_expect_runtime_frame_style(ui.call("_hud_card_style"), "HUD card", errors, unified_texture_margin)
		_expect_minimal_metal_frame_kit(ui, errors)
		_expect_minimal_metal_button_kit(errors)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	_write_unified_margin_dump(unified_texture_margin)
	_write_minimal_metal_dump()
	_write_minimal_metal_button_dump()
	print("Dark fantasy UI theme test passed.")
	quit(0)


func _expect_button_state_paths(button: Button, button_type: String, errors: Array[String]) -> void:
	if button == null:
		errors.append("Expected %s button to exist." % button_type)
		return
	var expected := {
		"normal": "ui_btn_minimal_metal_%s.png" % button_type,
		"hover": "ui_btn_minimal_metal_%s_hover.png" % button_type,
		"focus": "ui_btn_minimal_metal_%s_focus.png" % button_type,
		"pressed": "ui_btn_minimal_metal_%s_pressed.png" % button_type,
		"disabled": "ui_btn_minimal_metal_%s_disabled.png" % button_type,
	}
	for state in expected.keys():
		_expect_style_path(button.get_theme_stylebox(state), str(expected[state]), "%s %s" % [button.name, state], errors, MINIMAL_METAL_BUTTON_DIR)
	_expect_neutral_button_hover(button, errors)


func _expect_style_path(style: StyleBox, file_name: String, context: String, errors: Array[String], base_dir := DF_DIR) -> void:
	var texture_style := style as StyleBoxTexture
	if texture_style == null:
		errors.append("%s should use StyleBoxTexture from dark fantasy kit." % context)
		return
	if texture_style.texture == null:
		errors.append("%s StyleBoxTexture has no texture." % context)
		return
	var expected_path := base_dir + file_name
	if texture_style.texture.resource_path != expected_path:
		errors.append("%s texture mismatch: got %s, expected %s." % [context, texture_style.texture.resource_path, expected_path])


func _expect_runtime_frame_style(style: StyleBox, context: String, errors: Array[String], expected_margin: float) -> void:
	var texture_style := style as StyleBoxTexture
	if texture_style == null:
		errors.append("%s should use StyleBoxTexture from the runtime frame kit." % context)
		return
	if texture_style.texture == null:
		errors.append("%s StyleBoxTexture has no texture." % context)
		return
	if [UNIFIED_DIR + "ui_frame_unified_master.png", UNIFIED_DIR + "ui_frame_unified_master_fill.png"].has(texture_style.texture.resource_path):
		if texture_style.texture_margin_left != expected_margin or texture_style.texture_margin_top != expected_margin or texture_style.texture_margin_right != expected_margin or texture_style.texture_margin_bottom != expected_margin:
			errors.append("%s unified frame should use %dpx 9-slice texture margins from metadata." % [context, int(expected_margin)])
	else:
		var expected_margins := {}
		for frame_type in UIThemePaths.MINIMAL_METAL_FRAME_PATHS.keys():
			expected_margins[UIThemePaths.MINIMAL_METAL_FRAME_PATHS[frame_type]] = UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS[frame_type]
		if not expected_margins.has(texture_style.texture.resource_path):
			errors.append("%s texture mismatch: got %s, expected SCRUM-451 minimal-metal runtime kit." % [context, texture_style.texture.resource_path])
		elif not context.begins_with("HUD "):
			var margins: Vector4 = expected_margins[texture_style.texture.resource_path]
			if texture_style.texture_margin_left != margins.x or texture_style.texture_margin_top != margins.y or texture_style.texture_margin_right != margins.z or texture_style.texture_margin_bottom != margins.w:
				errors.append("%s minimal-metal frame margins mismatch: got %s,%s,%s,%s expected %s." % [context, texture_style.texture_margin_left, texture_style.texture_margin_top, texture_style.texture_margin_right, texture_style.texture_margin_bottom, str(margins)])
	if texture_style.axis_stretch_horizontal != StyleBoxTexture.AXIS_STRETCH_MODE_TILE or texture_style.axis_stretch_vertical != StyleBoxTexture.AXIS_STRETCH_MODE_TILE:
		errors.append("%s runtime frame should tile both axes." % context)


func _expect_minimal_metal_frame_kit(ui: Object, errors: Array[String]) -> void:
	var metadata := _load_json(MINIMAL_METAL_METADATA_PATH, errors)
	var assets: Dictionary = metadata.get("assets", {})
	for frame_type in ["modal", "panel", "card", "tooltip", "hud_strip", "field"]:
		var asset_id := "ui_frame_minimal_metal_%s" % frame_type
		var asset_meta: Dictionary = assets.get(asset_id, {})
		if asset_meta.is_empty():
			errors.append("Minimal-metal metadata missing %s." % asset_id)
			continue
		var expected_path := "res://%s" % str(asset_meta.get("path", ""))
		var expected_texture := _vector4_from_array(asset_meta.get("texture_margins_ltrb", []), Vector4.ZERO)
		var expected_content := _vector4_from_array(asset_meta.get("content_margins_ltrb", []), Vector4.ZERO)
		var expected_safe := _rect2_from_array(asset_meta.get("content_rect_xywh", []), Rect2())
		if str(UIThemePaths.MINIMAL_METAL_FRAME_PATHS.get(frame_type, "")) != expected_path:
			errors.append("Minimal-metal %s path mismatch: got %s expected %s." % [frame_type, str(UIThemePaths.MINIMAL_METAL_FRAME_PATHS.get(frame_type, "")), expected_path])
		if not ResourceLoader.exists(expected_path):
			errors.append("Minimal-metal runtime texture missing: %s." % expected_path)
		if UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS.get(frame_type, Vector4.ZERO) != expected_texture:
			errors.append("Minimal-metal %s texture margins mismatch: got %s expected %s." % [frame_type, str(UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS.get(frame_type, Vector4.ZERO)), str(expected_texture)])
		if UIThemePaths.MINIMAL_METAL_FRAME_CONTENT.get(frame_type, Vector4.ZERO) != expected_content:
			errors.append("Minimal-metal %s content margins mismatch: got %s expected %s." % [frame_type, str(UIThemePaths.MINIMAL_METAL_FRAME_CONTENT.get(frame_type, Vector4.ZERO)), str(expected_content)])
		if UIThemePaths.MINIMAL_METAL_FRAME_SAFE_RECTS.get(frame_type, Rect2()) != expected_safe:
			errors.append("Minimal-metal %s safe rect mismatch: got %s expected %s." % [frame_type, str(UIThemePaths.MINIMAL_METAL_FRAME_SAFE_RECTS.get(frame_type, Rect2())), str(expected_safe)])
		if not _content_encloses_texture(expected_content, expected_texture):
			errors.append("Minimal-metal %s content margins must be >= texture margins: content=%s texture=%s." % [frame_type, str(expected_content), str(expected_texture)])
		var style := ui.call("_minimal_metal_frame_style", frame_type) as StyleBoxTexture
		if style == null:
			errors.append("Minimal-metal %s helper should return StyleBoxTexture." % frame_type)
			continue
		if style.texture == null or style.texture.resource_path != expected_path:
			errors.append("Minimal-metal %s helper texture mismatch: got %s expected %s." % [frame_type, str(style.texture.resource_path if style.texture != null else ""), expected_path])
		if style.texture_margin_left != expected_texture.x or style.texture_margin_top != expected_texture.y or style.texture_margin_right != expected_texture.z or style.texture_margin_bottom != expected_texture.w:
			errors.append("Minimal-metal %s helper texture margins mismatch." % frame_type)
		if style.content_margin_left != expected_content.x or style.content_margin_top != expected_content.y or style.content_margin_right != expected_content.z or style.content_margin_bottom != expected_content.w:
			errors.append("Minimal-metal %s helper content margins mismatch." % frame_type)
		if style.axis_stretch_horizontal != StyleBoxTexture.AXIS_STRETCH_MODE_TILE or style.axis_stretch_vertical != StyleBoxTexture.AXIS_STRETCH_MODE_TILE:
			errors.append("Minimal-metal %s helper should tile both axes." % frame_type)


func _expect_minimal_metal_button_kit(errors: Array[String]) -> void:
	var metadata := _load_json(MINIMAL_METAL_BUTTON_METADATA_PATH, errors)
	var assets: Dictionary = metadata.get("assets", {})
	for asset_id in assets.keys():
		var asset_meta: Dictionary = assets.get(asset_id, {})
		var path := "res://%s" % str(asset_meta.get("path", ""))
		var file_name := path.get_file()
		var button_type := file_name.trim_prefix("ui_btn_minimal_metal_").trim_suffix(".png")
		for suffix in ["_hover", "_focus", "_pressed", "_disabled"]:
			button_type = button_type.trim_suffix(suffix)
		var expected_texture := _vector4_from_array(asset_meta.get("texture_margins_ltrb", []), Vector4.ZERO)
		var expected_content := _vector4_from_array(asset_meta.get("content_margins_ltrb", []), Vector4.ZERO)
		if not ResourceLoader.exists(path):
			errors.append("Minimal-metal button texture missing: %s." % path)
		if UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS.get(button_type, Vector4.ZERO) != expected_texture:
			errors.append("Minimal-metal button %s texture margins mismatch: got %s expected %s." % [button_type, str(UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS.get(button_type, Vector4.ZERO)), str(expected_texture)])
		if UIThemePaths.MINIMAL_METAL_BUTTON_CONTENT.get(button_type, Vector4.ZERO) != expected_content:
			errors.append("Minimal-metal button %s content margins mismatch: got %s expected %s." % [button_type, str(UIThemePaths.MINIMAL_METAL_BUTTON_CONTENT.get(button_type, Vector4.ZERO)), str(expected_content)])
		if not _content_encloses_texture(expected_content, expected_texture):
			errors.append("Minimal-metal button %s content margins must be >= texture margins: content=%s texture=%s." % [button_type, str(expected_content), str(expected_texture)])


func _expect_neutral_button_hover(button: Button, errors: Array[String]) -> void:
	var hover_style := button.get_theme_stylebox("hover") as StyleBoxTexture
	var focus_style := button.get_theme_stylebox("focus") as StyleBoxTexture
	if hover_style == null or focus_style == null:
		errors.append("%s hover/focus should use StyleBoxTexture." % button.name)
		return
	if hover_style.texture == null or focus_style.texture == null:
		errors.append("%s hover/focus should have textures." % button.name)
		return
	var hover_tint := hover_style.modulate_color
	var focus_tint := focus_style.modulate_color
	if not _is_neutral_bright_tint(hover_tint) or not _is_neutral_bright_tint(focus_tint):
		errors.append("%s hover/focus tint should be neutral bright, got hover=%s focus=%s." % [button.name, str(hover_tint), str(focus_tint)])
	var hover_font := button.get_theme_color("font_hover_color")
	var focus_font := button.get_theme_color("font_focus_color")
	if not _is_neutral_font_color(hover_font) or not _is_neutral_font_color(focus_font):
		errors.append("%s hover/focus font should be neutral near-white, got hover=%s focus=%s." % [button.name, str(hover_font), str(focus_font)])


func _is_neutral_bright_tint(color: Color) -> bool:
	return color.r >= 1.0 and color.g >= 1.0 and color.b >= 1.0 and absf(color.r - color.g) <= 0.015 and absf(color.g - color.b) <= 0.015


func _is_neutral_font_color(color: Color) -> bool:
	return color.r >= 0.98 and color.g >= 0.98 and color.b >= 0.98 and absf(color.r - color.g) <= 0.015 and absf(color.g - color.b) <= 0.015


func _expected_unified_texture_margin(errors: Array[String]) -> float:
	var metadata := _load_json(UNIFIED_METADATA_PATH, errors)
	var texture_margins: Dictionary = metadata.get("texture_margins", {})
	var expected_texture := Vector4(
		float(texture_margins.get("left", 72.0)),
		float(texture_margins.get("top", 72.0)),
		float(texture_margins.get("right", 72.0)),
		float(texture_margins.get("bottom", 72.0))
	)
	var expected_margin := expected_texture.x
	if expected_texture != Vector4(expected_margin, expected_margin, expected_margin, expected_margin):
		errors.append("Unified frame metadata should keep symmetric texture margins, got %s." % str(expected_texture))
	if UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS != expected_texture:
		errors.append("UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS mismatch: got %s, expected metadata %s." % [str(UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS), str(expected_texture)])
	var safe_rect_values: Array = metadata.get("strict_safe_rect", [])
	if safe_rect_values.size() >= 4:
		var expected_safe := Rect2(float(safe_rect_values[0]), float(safe_rect_values[1]), float(safe_rect_values[2]), float(safe_rect_values[3]))
		if UIThemePaths.UNIFIED_FRAME_SAFE_RECT != expected_safe:
			errors.append("UIThemePaths.UNIFIED_FRAME_SAFE_RECT mismatch: got %s, expected metadata %s." % [str(UIThemePaths.UNIFIED_FRAME_SAFE_RECT), str(expected_safe)])
	else:
		errors.append("Unified frame metadata should define strict_safe_rect.")
	return expected_margin


func _vector4_from_array(values: Array, fallback: Vector4) -> Vector4:
	if values.size() < 4:
		return fallback
	return Vector4(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _rect2_from_array(values: Array, fallback: Rect2) -> Rect2:
	if values.size() < 4:
		return fallback
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _content_encloses_texture(content: Vector4, texture: Vector4) -> bool:
	return content.x >= texture.x and content.y >= texture.y and content.z >= texture.z and content.w >= texture.w


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Could not read %s." % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		errors.append("Expected %s to contain a JSON object." % path)
		return {}
	return parsed


func _write_unified_margin_dump(texture_margin: float) -> void:
	var dir := ProjectSettings.globalize_path("res://build/qa/scrum392")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("unified_frame_margins.md"), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("# Unified Frame Runtime Margins")
	file.store_line("")
	file.store_line("- Metadata: `%s`" % UNIFIED_METADATA_PATH)
	file.store_line("- Texture margins: `%dpx`" % int(texture_margin))
	file.store_line("- Runtime `UNIFIED_FRAME_TEXTURE_MARGINS`: `%s`" % str(UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS))
	file.store_line("- Runtime `UNIFIED_FRAME_SAFE_RECT`: `%s`" % str(UIThemePaths.UNIFIED_FRAME_SAFE_RECT))


func _write_minimal_metal_dump() -> void:
	var dir := ProjectSettings.globalize_path("res://build/qa/scrum452_minimal_metal")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("minimal_metal_runtime_frame_kit.md"), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("# SCRUM-452 Minimal Metal Runtime Frame Kit")
	file.store_line("")
	file.store_line("- Metadata: `%s`" % MINIMAL_METAL_METADATA_PATH)
	for frame_type in ["modal", "panel", "card", "tooltip", "hud_strip", "field"]:
		file.store_line("- `%s`: path `%s`, texture `%s`, content `%s`, safe `%s`" % [
			frame_type,
			str(UIThemePaths.MINIMAL_METAL_FRAME_PATHS.get(frame_type, "")),
			str(UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS.get(frame_type, Vector4.ZERO)),
			str(UIThemePaths.MINIMAL_METAL_FRAME_CONTENT.get(frame_type, Vector4.ZERO)),
			str(UIThemePaths.MINIMAL_METAL_FRAME_SAFE_RECTS.get(frame_type, Rect2())),
		])
	file.close()


func _write_minimal_metal_button_dump() -> void:
	var dir := ProjectSettings.globalize_path("res://build/qa/scrum450_minimal_metal_buttons")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("minimal_metal_button_runtime_kit.md"), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("# SCRUM-450 Minimal Metal Runtime Button Kit")
	file.store_line("")
	file.store_line("- Metadata: `%s`" % MINIMAL_METAL_BUTTON_METADATA_PATH)
	for button_type in UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS.keys():
		file.store_line("- `%s`: texture `%s`, content `%s`" % [
			button_type,
			str(UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS.get(button_type, Vector4.ZERO)),
			str(UIThemePaths.MINIMAL_METAL_BUTTON_CONTENT.get(button_type, Vector4.ZERO)),
		])
	file.close()
