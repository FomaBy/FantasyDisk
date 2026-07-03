class_name GlobalTooltip
extends RefCounted

const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")

const DEFAULT_LABEL_NAME := "GlobalTooltipLabel"
# Единственную рамку тултипа рисует движковый попап стилем "TooltipPanel" из make_theme();
# кастомный контент — голый Label (make_tooltip_label), иначе получается рамка в рамке.
const DEFAULT_MAX_WIDTH := 460.0
const WIDE_MAX_WIDTH := 620.0
const WIDE_TEXT_THRESHOLD := 360
const DEFAULT_FONT_SIZE := 20
const DEFAULT_GAP := 18.0
const DEFAULT_VIEWPORT_MARGIN := 16.0


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


static func make_tooltip_label(
	for_text: String,
	label_name := DEFAULT_LABEL_NAME,
	font_size := DEFAULT_FONT_SIZE,
	font_color := Color(0.94, 0.90, 0.78, 1.0)
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = for_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var wrap_width := wrap_width_for_text(for_text, font_size)
	if wrap_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(wrap_width, 0.0)
	return label


# Короткий текст живёт в окне по своему размеру; длинный переносится на 460 px,
# «супердетали» получают широкое окно 620 px — не мельчить шрифтом, а растить окно.
static func wrap_width_for_text(for_text: String, font_size := DEFAULT_FONT_SIZE) -> float:
	var font := ThemeDB.fallback_font
	if font == null:
		return DEFAULT_MAX_WIDTH
	var text_width := font.get_multiline_string_size(
		for_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	).x
	if text_width <= DEFAULT_MAX_WIDTH:
		return 0.0
	if for_text.length() >= WIDE_TEXT_THRESHOLD or text_width >= DEFAULT_MAX_WIDTH * 2.5:
		return WIDE_MAX_WIDTH
	return DEFAULT_MAX_WIDTH


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
