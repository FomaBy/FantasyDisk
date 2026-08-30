extends "res://scripts/ui/screens/ui_style_kit.gd"

# FAN-3824: модуль распределённого UI-класса — общий каркас экранов: unified-фон/рамки, безопасные зоны, фокус-навигация.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# --- SCRUM-879: атлас-стиль для остальных экранов --------------------------
# Слои как у «Атласа героев»: фон COVERED (без растяжки осей, fallback bg_sky),
# контент ТОЛЬКО в safe-зоне рамы, полая рама 9-slice ПОВЕРХ контента
# (_unified_add_frame звать ПОСЛЕДНИМ). Панели — _atlas_chip_style.

func _unified_add_background(root: Control, screen_id: String, shade_alpha := 0.0) -> void:
	var path := str(ATLAS_STYLE_BG_PATHS.get(screen_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		path = META40_BG_SKY_PATH
	var background := TextureRect.new()
	background.name = "UnifiedBackground_%s" % screen_id
	background.texture = game._cached_texture(path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	if shade_alpha > 0.0:
		var shade := ColorRect.new()
		shade.name = "UnifiedBackgroundShade"
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.0, 0.0, 0.0, shade_alpha)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)




func _unified_safe_margins() -> Vector4:
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	return _unified_safe_margins_for_size(vp)




func _unified_safe_margins_for_size(viewport_size: Vector2) -> Vector4:
	return _scaled_frame_margins_xy(
		ATLAS_FRAME_SOURCE_SIZE, viewport_size,
		Vector4(ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN))




func _unified_safe_rect() -> Rect2:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	return _unified_safe_rect_for_size(viewport_size)




func _unified_safe_rect_for_size(viewport_size: Vector2) -> Rect2:
	var margins := _unified_safe_margins_for_size(viewport_size)
	return Rect2(
		Vector2(margins.x, margins.y),
		Vector2(maxf(1.0, viewport_size.x - margins.x - margins.z), maxf(1.0, viewport_size.y - margins.y - margins.w))
	)




# SCRUM-1036: the texture-safe rect only clears the 9-slice border. Authored
# gold-shell screens reserve another 24px (32px on the 2K tier) before any live
# control, label, icon or hitbox may begin.
func _gold_shell_inner_rect_for_size(viewport_size: Vector2) -> Rect2:
	var reserve := 32.0 if viewport_size.y >= 1200.0 else 24.0
	return _unified_safe_rect_for_size(viewport_size).grow(-reserve)




func _unified_make_safe_area(root: Control, prefix: String) -> MarginContainer:
	var margins := _unified_safe_margins()
	var safe := MarginContainer.new()
	safe.name = "%sSafeArea" % prefix
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(margins.x))
	safe.add_theme_constant_override("margin_top", int(margins.y))
	safe.add_theme_constant_override("margin_right", int(margins.z))
	safe.add_theme_constant_override("margin_bottom", int(margins.w))
	root.add_child(safe)
	return safe




func _unified_add_frame(root: Control, prefix: String) -> Panel:
	var frame := Panel.new()
	frame.name = "%sFrame" % prefix
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.set_meta("gold_shell_asset", META40_FRAME_BORDER_PATH)
	frame.set_meta("gold_shell_draw_center", false)
	root.add_child(frame)
	_refresh_unified_frame(root, frame)
	root.resized.connect(_refresh_unified_frame.bind(root, frame))
	return frame




func _refresh_unified_frame(root: Control, frame: Panel) -> void:
	if root == null or frame == null or not is_instance_valid(root) or not is_instance_valid(frame):
		return
	var viewport_size := root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = game.get_viewport().get_visible_rect().size
	var margins := _unified_safe_margins_for_size(viewport_size)
	var safe_rect := _unified_safe_rect_for_size(viewport_size)
	var inner_rect := _gold_shell_inner_rect_for_size(viewport_size)
	frame.add_theme_stylebox_override("panel", _atlas_frame_style(margins))
	frame.set_meta("gold_shell_content_rect", safe_rect)
	frame.set_meta("gold_shell_inner_rect", inner_rect)
	root.set_meta("gold_shell_content_rect", safe_rect)
	root.set_meta("gold_shell_inner_rect", inner_rect)




# Кожаный чип-заголовок экрана: эмблема PixelLab + титул золотом (шапка как
# валютные чипы Атласа).
func _unified_header_chip(prefix: String, title: String, screen_id: String, s: float) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "%sTitleChip" % prefix
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, roundf(10.0 * s)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(roundf(10.0 * s)))
	chip.add_child(row)
	var emblem_path := str(ATLAS_STYLE_EMBLEM_PATHS.get(screen_id, ""))
	if emblem_path != "" and ResourceLoader.exists(emblem_path):
		var icon := TextureRect.new()
		icon.name = "%sTitleEmblem" % prefix
		icon.texture = game._cached_texture(emblem_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var icon_px := maxf(26.0, roundf(44.0 * s))
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var label := Label.new()
	label.name = "%sTitleLabel" % prefix
	label.text = title
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 22))
	label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	row.add_child(label)
	return chip




# Тема «кожаного ряда» для списочных Button-контролов (карточки кодекса,
# слоты карусели, строки статов): это НЕ действие-кнопки глобального кита,
# а контентные ряды в языке чипов Атласа.
func _unified_apply_row_theme(button: Button, pad := 10.0, selected := false) -> void:
	UIButtonFamily.assign(button, UIButtonFamily.FAMILY_CONTENT_ROW)
	var normal := _atlas_chip_style(0.72, pad)
	var hover := _atlas_chip_style(0.82, pad)
	hover.border_color = Color(0.72, 0.58, 0.34, 0.95)
	var pressed := _atlas_chip_style(0.92, pad)
	pressed.bg_color = Color(0.11, 0.09, 0.07, 0.94)
	var focus := _atlas_chip_style(0.84, pad)
	focus.border_color = Color(0.93, 0.77, 0.40, 0.95)
	if selected:
		normal = _atlas_chip_style(0.88, pad)
		normal.border_color = Color(0.93, 0.77, 0.40, 0.95)
		normal.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", _atlas_translucent_style(0.45, 10.0))
	button.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))




# Орнамент-разделитель PixelLab фикс-высоты (KEEP_ASPECT_CENTERED — без растяжки).
func _unified_add_divider(parent: Control, s: float, name_suffix := "") -> void:
	if not ResourceLoader.exists(ATLAS_STYLE_DIVIDER_PATH):
		return
	var divider := TextureRect.new()
	divider.name = "UnifiedDivider%s" % name_suffix
	divider.texture = game._cached_texture(ATLAS_STYLE_DIVIDER_PATH)
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	divider.custom_minimum_size = Vector2(0.0, maxf(18.0, roundf(28.0 * s)))
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)




# SCRUM-812: единая разводка фокус-навигации внутризабеговых экранов под геймпад
# и стрелки. primary — основной ряд/столбец интерактивных контролов (карточки или
# кнопки меню); axis_h=true — горизонтальный ряд (лево/право по кругу), false —
# вертикальный столбец (верх/низ по кругу). secondary — вспомогательные кнопки
# («Позже»/«Назад»), доступные с перпендикулярной оси и связанные обратно в круг.
# initial — стартовый фокус (по умолчанию первый доступный контрол).
# Опирается на встроенные ui_*-экшены Godot (у них дефолтные joypad-биндинги
# A/B/крестовина/стик), поэтому не зависит от ядра InputDeviceManager (SCRUM-811).
func _wire_run_ui_focus(primary: Array, axis_h: bool, secondary: Array = [], initial: Control = null) -> void:
	_ensure_run_ui_gamepad_bindings()
	var ring := _collect_focusable_controls(primary)
	var extra := _collect_focusable_controls(secondary)
	for i in range(ring.size()):
		var cur := ring[i]
		var prev := ring[(i - 1 + ring.size()) % ring.size()]
		var nxt := ring[(i + 1) % ring.size()]
		var cross_first: Control = extra[0] if not extra.is_empty() else cur
		var cross_last: Control = extra[extra.size() - 1] if not extra.is_empty() else cur
		if axis_h:
			cur.focus_neighbor_left = prev.get_path()
			cur.focus_neighbor_right = nxt.get_path()
			cur.focus_neighbor_bottom = cross_first.get_path()
			cur.focus_neighbor_top = cross_last.get_path()
		else:
			cur.focus_neighbor_top = prev.get_path()
			cur.focus_neighbor_bottom = nxt.get_path()
			cur.focus_neighbor_right = cross_first.get_path()
			cur.focus_neighbor_left = cur.get_path()
	var ring_head: Control = ring[0] if not ring.is_empty() else null
	for j in range(extra.size()):
		var cur2 := extra[j]
		var back: Control = ring_head if ring_head != null else cur2
		var prev2: Control = extra[j - 1] if j > 0 else back
		var nxt2: Control = extra[j + 1] if j < extra.size() - 1 else back
		if axis_h:
			cur2.focus_neighbor_top = prev2.get_path()
			cur2.focus_neighbor_bottom = nxt2.get_path()
			cur2.focus_neighbor_left = cur2.get_path()
			cur2.focus_neighbor_right = cur2.get_path()
		else:
			cur2.focus_neighbor_left = prev2.get_path()
			cur2.focus_neighbor_right = nxt2.get_path()
			cur2.focus_neighbor_top = cur2.get_path()
			cur2.focus_neighbor_bottom = cur2.get_path()
	var target := initial
	if target == null or not is_instance_valid(target):
		target = ring_head if ring_head != null else (extra[0] if not extra.is_empty() else null)
	if target != null and is_instance_valid(target):
		target.call_deferred("grab_focus")




func _wire_main_menu_column_focus(buttons: Array, gratitude: Control, initial: Control = null) -> void:
	# SCRUM-1081: Up/Down wraps the canonical action column. Gratitude is the
	# separate bottom-right utility: Right enters it; Left/Up returns to Exit.
	_ensure_run_ui_gamepad_bindings()
	var column := _collect_focusable_controls(buttons)
	if column.is_empty():
		return
	for index in range(column.size()):
		var current := column[index]
		var previous := column[(index - 1 + column.size()) % column.size()]
		var following := column[(index + 1) % column.size()]
		current.focus_neighbor_left = current.get_path()
		current.focus_neighbor_right = gratitude.get_path() if gratitude != null and is_instance_valid(gratitude) else current.get_path()
		current.focus_neighbor_top = previous.get_path()
		current.focus_neighbor_bottom = following.get_path()
	if gratitude != null and is_instance_valid(gratitude):
		gratitude.focus_mode = Control.FOCUS_ALL
		gratitude.focus_neighbor_left = column[column.size() - 1].get_path()
		gratitude.focus_neighbor_right = gratitude.get_path()
		gratitude.focus_neighbor_top = column[column.size() - 1].get_path()
		gratitude.focus_neighbor_bottom = column[0].get_path()
	var target := initial if initial != null and is_instance_valid(initial) else column[0]
	(target as Control).call_deferred("grab_focus")




# SCRUM-812: собирает валидные фокусируемые контролы (не disabled), проставляя им
# FOCUS_ALL. Порядок сохраняется — соседи разводятся по позиции в списке.
func _collect_focusable_controls(controls: Array) -> Array[Control]:
	var out: Array[Control] = []
	for c in controls:
		if c is Control and is_instance_valid(c):
			var ctrl := c as Control
			if ctrl is Button and (ctrl as Button).disabled:
				continue
			ctrl.focus_mode = Control.FOCUS_ALL
			out.append(ctrl)
	return out




# SCRUM-812: в текущей сборке у ui_accept/ui_cancel НЕТ joypad-событий (проверено:
# только клавиатура; крестовина/стик у ui_up/down/left/right есть). Без A→ui_accept и
# B→ui_cancel геймпад не подтверждает/не отменяет на внутризабеговых экранах. Идемпотентно
# доводим их в рантайме, чтобы SCRUM-812 работал самостоятельно. Полную раскладку геймпада
# формализует ядро SCRUM-811 (InputDeviceManager) — гард ниже исключает дубли при слиянии.
func _ensure_run_ui_gamepad_bindings() -> void:
	_ensure_action_joy_button("ui_accept", JOY_BUTTON_A)
	_ensure_action_joy_button("ui_cancel", JOY_BUTTON_B)




func _ensure_action_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	InputMap.action_add_event(action, ev)




# SCRUM-813: LB/RB листают вкладки настроек / секции кодекса. Роутинг из main._input
# (raw JOY_BUTTON_LEFT/RIGHT_SHOULDER) в этот диспетчер — локально по открытому мета-экрану.
# dir: -1 = предыдущая (LB), +1 = следующая (RB). Возвращает true, если обработано.
func _handle_menu_shoulder_nav(dir: int) -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	if game.ui_layer.find_child("SettingsV2Root", true, false) != null:
		return _cycle_settings_tab(dir)
	if game.ui_layer.find_child("CodexScreen", true, false) != null:
		return _cycle_codex_section(dir)
	# SCRUM-827: LB/RB листают вкладки Атласа героев (Созвездие ↔ Гильдия).
	if game.ui_layer.find_child("AtlasScreen", true, false) != null:
		return _atlas_cycle_tab(dir)
	return false




func _cycle_settings_tab(dir: int) -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	var root_node: Node = game.ui_layer.find_child("SettingsV2Root", true, false)
	if root_node == null:
		return false
	var tab_containers: Array = root_node.find_children("*", "TabContainer", true, false)
	if tab_containers.is_empty():
		return false
	var tabs := tab_containers[0] as TabContainer
	var count := tabs.get_tab_count()
	if count <= 0:
		return false
	tabs.current_tab = (tabs.current_tab + dir + count) % count
	var tab_btn := root_node.find_child("SettingsTabButton_%d" % tabs.current_tab, true, false) as Button
	if tab_btn != null:
		tab_btn.call_deferred("grab_focus")
	return true




func _cycle_codex_section(dir: int) -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	var content: PanelContainer = null
	for node in game.ui_layer.find_children("*", "PanelContainer", true, false):
		if node.has_meta("codex_active_section"):
			content = node as PanelContainer
			break
	if content == null:
		return false
	var ids: Array = []
	for section in CODEX_SECTIONS:
		ids.append(str(section["id"]))
	if ids.is_empty():
		return false
	var cur := str(content.get_meta("codex_active_section", ids[0]))
	var idx := ids.find(cur)
	if idx < 0:
		idx = 0
	var next_id := str(ids[(idx + dir + ids.size()) % ids.size()])
	_show_codex_section(content, next_id)
	var tabs_row := content.get_meta("codex_tabs", null) as Control
	if tabs_row != null:
		var tab_btn := tabs_row.get_node_or_null("CodexTab_%s" % next_id) as Button
		if tab_btn != null:
			tab_btn.call_deferred("grab_focus")
	return true




func _current_ui_screen_name() -> String:
	if game.ui_layer != null and is_instance_valid(game.ui_layer):
		for child in game.ui_layer.get_children():
			if child is Control and not str(child.name).begins_with("ScreenBackground"):
				return str(child.name)
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		return str(game.pause_overlay_layer.name)
	if game.combat_active:
		return "Combat"
	return "World"
