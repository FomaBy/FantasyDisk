class_name GlobalTooltip
extends RefCounted

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")

const DEFAULT_LABEL_NAME := "GlobalTooltipLabel"
# Единственную рамку тултипа рисует движковый попап стилем "TooltipPanel" из make_theme();
# кастомный контент — голый Label/столбец лейблов, иначе получается рамка в рамке.
const DEFAULT_MAX_WIDTH := 460.0
const WIDE_MAX_WIDTH := 620.0
const WIDE_TEXT_THRESHOLD := 360
const DEFAULT_FONT_SIZE := SemanticTypography.TARGET_TOOLTIP
# SCRUM-890: отступ тултипа от курсора 16px, кламп в вьюпорт с полем 16px.
const DEFAULT_GAP := 16.0
const DEFAULT_VIEWPORT_MARGIN := 16.0
# SCRUM-890: цвета атлас-языка — титул золотом, тело светлым.
const TITLE_COLOR := Color(0.96, 0.90, 0.68, 1.0)
const BODY_COLOR := Color(0.88, 0.92, 0.98, 1.0)


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", make_atlas_chip_panel_style())
	theme.set_color("font_color", "TooltipLabel", Color(0.94, 0.90, 0.78, 1.0))
	theme.set_color("font_shadow_color", "TooltipLabel", Color(0.01, 0.01, 0.012, 0.92))
	theme.set_constant("shadow_offset_x", "TooltipLabel", 1)
	theme.set_constant("shadow_offset_y", "TooltipLabel", 1)
	theme.set_font_size("font_size", "TooltipLabel", SemanticTypography.resolve_fixed(SemanticTypography.ROLE_TOOLTIP, DEFAULT_FONT_SIZE))
	return theme


# SCRUM-890: панель глобального тултипа — плотный чип Атласа (тёмная кожа,
# латунный кант). Числа = ui_screens._atlas_chip_style(0.97, 12).
static func make_atlas_chip_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.070, 0.055, 0.97)
	style.border_color = Color(0.52, 0.41, 0.24, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.8
	style.content_margin_right = 16.8
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


static func make_tooltip_label(
	for_text: String,
	label_name := DEFAULT_LABEL_NAME,
	font_size := DEFAULT_FONT_SIZE,
	font_color := Color(0.94, 0.90, 0.78, 1.0),
	width_scale := 1.0
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = for_text
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(SemanticTypography.ROLE_TOOLTIP, font_size))
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var wrap_width := wrap_width_for_text(for_text, font_size, width_scale)
	if wrap_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(wrap_width, 0.0)
	return label


# Короткий текст живёт в окне по своему размеру; длинный переносится на ~460·s px,
# «супердетали» получают широкое окно ~620·s px — не мельчить шрифтом, а растить окно.
static func wrap_width_for_text(for_text: String, font_size := DEFAULT_FONT_SIZE, width_scale := 1.0) -> float:
	var default_width := DEFAULT_MAX_WIDTH * width_scale
	var wide_width := WIDE_MAX_WIDTH * width_scale
	var font := ThemeDB.fallback_font
	if font == null:
		return default_width
	var text_width := font.get_multiline_string_size(
		for_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	).x
	if text_width <= default_width:
		return 0.0
	if for_text.length() >= WIDE_TEXT_THRESHOLD or text_width >= default_width * 2.5:
		return wide_width
	return default_width


# SCRUM-890: масштаб ширины тултипа от вьюпорта (база 2560×1440); на компактных
# экранах не сужаем ниже канонических 460/620.
static func width_scale_for(anchor: Control) -> float:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return 1.0
	var vp := anchor.get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return 1.0
	return maxf(1.0, minf(vp.x / 2560.0, vp.y / 1440.0))


# SCRUM-890: контент глобального тултипа — титул золотом (первая строка) + тело
# светлым; рамку рисует TooltipPanel-чип попапа. anchor — наведённый контрол:
# по нему считаются ширина и позиция попапа (16px от курсора, кламп в вьюпорт,
# без перекрытия карточки под курсором где возможно).
static func make_tooltip_content(for_text: String, anchor: Control = null) -> Control:
	var newline := for_text.find("\n")
	var title_text := for_text if newline == -1 else for_text.substr(0, newline)
	var body_text := "" if newline == -1 else for_text.substr(newline + 1).strip_edges()
	var width_scale := width_scale_for(anchor)

	var box := VBoxContainer.new()
	box.name = "GlobalTooltipContent"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	var title := make_tooltip_label(title_text, "GlobalTooltipTitleLabel", DEFAULT_FONT_SIZE + 1, TITLE_COLOR, width_scale)
	box.add_child(title)
	if body_text != "":
		var body := make_tooltip_label(body_text, "GlobalTooltipBodyLabel", DEFAULT_FONT_SIZE, BODY_COLOR, width_scale)
		box.add_child(body)

	if anchor != null:
		box.tree_entered.connect(func() -> void:
			_schedule_popup_reposition(box, anchor)
		, CONNECT_DEFERRED)
	return box


static func _schedule_popup_reposition(content: Control, anchor: Control) -> void:
	if content == null or not is_instance_valid(content) or not content.is_inside_tree():
		return
	reposition_tooltip_popup(content, anchor)


# Позиция попапа: кандидаты от курсора — вправо-вниз, при нехватке влево
# (затем вверх), без пересечения прямоугольника наведённой карточки, кламп в
# вьюпорт с полем 16px. Громоздкий анкор (широкая строка/панель) заменяется
# точкой курсора — иначе тултип негде разместить.
static func reposition_tooltip_popup(content: Control, anchor: Control) -> void:
	if content == null or not is_instance_valid(content) or not content.is_inside_tree():
		return
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var popup := content.get_window() as Popup
	if popup == null or popup == anchor.get_window():
		return
	var viewport_size := anchor.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var mouse := anchor.get_viewport().get_mouse_position()
	var anchor_rect := anchor.get_global_rect()
	if anchor_rect.size.x > viewport_size.x * 0.6 or anchor_rect.size.y > viewport_size.y * 0.4:
		anchor_rect = Rect2(mouse - Vector2(4.0, 4.0), Vector2(8.0, 8.0))
	var size := Vector2(popup.size)
	if size.x <= 1.0 or size.y <= 1.0:
		size = content.get_combined_minimum_size()

	var candidates: Array[Vector2] = [
		mouse + Vector2(DEFAULT_GAP, DEFAULT_GAP),
		Vector2(mouse.x - size.x - DEFAULT_GAP, mouse.y + DEFAULT_GAP),
		Vector2(mouse.x + DEFAULT_GAP, mouse.y - size.y - DEFAULT_GAP),
		Vector2(mouse.x - size.x - DEFAULT_GAP, mouse.y - size.y - DEFAULT_GAP),
	]
	var chosen := Vector2.ZERO
	var found := false
	for candidate in candidates:
		if _fits_viewport(candidate, size, viewport_size, DEFAULT_VIEWPORT_MARGIN) and not Rect2(candidate, size).intersects(anchor_rect):
			chosen = candidate
			found = true
			break
	if not found:
		for candidate in candidates:
			if _fits_viewport(candidate, size, viewport_size, DEFAULT_VIEWPORT_MARGIN):
				chosen = candidate
				found = true
				break
	if not found:
		chosen = _clamp_position(candidates[0], size, viewport_size, DEFAULT_VIEWPORT_MARGIN)
	popup.position = Vector2i(_clamp_position(chosen, size, viewport_size, DEFAULT_VIEWPORT_MARGIN).round())


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
