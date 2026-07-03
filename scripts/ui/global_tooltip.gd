class_name GlobalTooltip
extends RefCounted

const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")

const DEFAULT_PANEL_NAME := "GlobalTooltipPanel"
const DEFAULT_LABEL_NAME := "GlobalTooltipLabel"
const DEFAULT_MAX_WIDTH := 460.0
const DEFAULT_FONT_SIZE := 14
const DEFAULT_GAP := 18.0
const DEFAULT_VIEWPORT_MARGIN := 16.0
const POSITIONING_PANEL_SCRIPT := preload("res://scripts/ui/global_tooltip_panel.gd")


static func make_minimal_metal_style(tint := Color.WHITE) -> StyleBox:
	return make_texture_style(
		UIThemePaths.MINIMAL_METAL_FRAME_PATHS["tooltip"],
		UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS["tooltip"],
		UIThemePaths.MINIMAL_METAL_FRAME_CONTENT["tooltip"],
		tint
	)


static func make_texture_style(path: String, margins: Vector4, content: Vector4, tint := Color.WHITE) -> StyleBox:
	var texture := load(path) as Texture2D
	if texture == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.025, 0.030, 0.040, 0.98)
		fallback.border_color = Color(0.86, 0.66, 0.28, 0.95)
		fallback.set_border_width_all(2)
		fallback.set_corner_radius_all(6)
		_apply_content_margins(fallback, content)
		return fallback

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.draw_center = true
	style.modulate_color = tint
	_apply_content_margins(style, content)
	return style


static func make_theme() -> Theme:
	var theme := Theme.new()
	var panel_style := make_minimal_metal_style()
	theme.set_stylebox("panel", "TooltipPanel", panel_style)
	theme.set_color("font_color", "TooltipLabel", Color(0.94, 0.90, 0.78, 1.0))
	theme.set_color("font_shadow_color", "TooltipLabel", Color(0.01, 0.01, 0.012, 0.92))
	theme.set_constant("shadow_offset_x", "TooltipLabel", 1)
	theme.set_constant("shadow_offset_y", "TooltipLabel", 1)
	theme.set_font_size("font_size", "TooltipLabel", DEFAULT_FONT_SIZE)
	return theme


static func make_text_panel(
	for_text: String,
	style: StyleBox,
	max_width := DEFAULT_MAX_WIDTH,
	panel_name := DEFAULT_PANEL_NAME,
	label_name := DEFAULT_LABEL_NAME,
	font_size := DEFAULT_FONT_SIZE,
	font_color := Color(0.94, 0.90, 0.78, 1.0)
) -> PanelContainer:
	var tooltip := PanelContainer.new()
	tooltip.set_script(POSITIONING_PANEL_SCRIPT)
	tooltip.name = panel_name
	tooltip.process_mode = Node.PROCESS_MODE_ALWAYS
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.custom_minimum_size = Vector2(max_width, 0.0)
	tooltip.add_theme_stylebox_override("panel", style)
	tooltip.set_meta("global_tooltip_gap", DEFAULT_GAP)
	tooltip.set_meta("global_tooltip_viewport_margin", DEFAULT_VIEWPORT_MARGIN)

	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(maxf(40.0, max_width - _style_horizontal_content(style)), 0.0)
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	tooltip.add_child(label)
	return tooltip


static func install_on_tree(root: Node, tooltip_script: Script) -> void:
	if root == null or tooltip_script == null:
		return
	var nodes := [root]
	nodes.append_array(root.find_children("*", "Control", true, false))
	for node in nodes:
		var control := node as Control
		if control == null:
			continue
		if control.tooltip_text.strip_edges() == "":
			continue
		if bool(control.get_meta("global_tooltip_skin", false)):
			continue
		if control.get_script() != null:
			continue
		if not _is_supported_tooltip_control(control):
			continue
		control.set_script(tooltip_script)
		control.set_meta("global_tooltip_skin", true)
		control.set_meta("global_tooltip_install_mode", "custom_tooltip_script")


static func place_near_anchor(tooltip: Control, anchor_rect: Rect2, viewport_size: Vector2, gap := DEFAULT_GAP, margin := DEFAULT_VIEWPORT_MARGIN) -> void:
	if tooltip == null:
		return
	var size := tooltip.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = tooltip.get_combined_minimum_size()
	tooltip.size = size

	var candidates := _placement_candidates(anchor_rect, size, viewport_size, gap)
	for candidate in candidates:
		if _fits_viewport(candidate, size, viewport_size, margin) and not Rect2(candidate, size).intersects(anchor_rect):
			tooltip.global_position = candidate
			return

	for candidate in candidates:
		var clamped := _clamp_position(candidate, size, viewport_size, margin)
		if not Rect2(clamped, size).intersects(anchor_rect):
			tooltip.global_position = clamped
			return

	tooltip.global_position = _clamp_position(candidates[0] if not candidates.is_empty() else anchor_rect.end + Vector2(gap, gap), size, viewport_size, margin)


static func cursor_anchor_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var mouse_pos := control.get_viewport().get_mouse_position()
	return Rect2(mouse_pos, Vector2.ONE)


static func _placement_candidates(anchor_rect: Rect2, size: Vector2, viewport_size: Vector2, gap: float) -> Array[Vector2]:
	var center := anchor_rect.get_center()
	var right := Vector2(anchor_rect.end.x + gap, center.y - size.y * 0.5)
	var left := Vector2(anchor_rect.position.x - size.x - gap, center.y - size.y * 0.5)
	var below := Vector2(center.x - size.x * 0.5, anchor_rect.end.y + gap)
	var above := Vector2(center.x - size.x * 0.5, anchor_rect.position.y - size.y - gap)
	if center.x <= viewport_size.x * 0.5:
		return [right, left, below, above]
	return [left, right, below, above]


static func _fits_viewport(position: Vector2, size: Vector2, viewport_size: Vector2, margin: float) -> bool:
	return (
		position.x >= margin
		and position.y >= margin
		and position.x + size.x <= viewport_size.x - margin
		and position.y + size.y <= viewport_size.y - margin
	)


static func _clamp_position(position: Vector2, size: Vector2, viewport_size: Vector2, margin: float) -> Vector2:
	return Vector2(
		clampf(position.x, margin, maxf(margin, viewport_size.x - size.x - margin)),
		clampf(position.y, margin, maxf(margin, viewport_size.y - size.y - margin))
	)


static func _style_horizontal_content(style: StyleBox) -> float:
	if style == null:
		return 0.0
	return maxf(0.0, style.content_margin_left) + maxf(0.0, style.content_margin_right)


static func _is_supported_tooltip_control(control: Control) -> bool:
	return (
		control is BaseButton
		or control is Range
		or control is Container
		or control is PanelContainer
		or control is TextureRect
		or control is Label
	)


static func _apply_content_margins(style: StyleBox, content: Vector4) -> void:
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
