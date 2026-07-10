extends SceneTree

# SCRUM-983 focused acceptance for the real Escape/pause dossier. The oracle
# validates authored content zones, semantic stat rows, compact values,
# complete tooltips, focus reachability and live responsive relayout.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FRAME_PATH_SUFFIX := "meta40/frame_border.png"
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const BASE_IDS := [
	"strength", "agility", "intelligence", "perception",
	"energy", "knowledge", "endurance", "leadership",
]
const DERIVED_IDS := [
	"damage", "attack_speed", "crit_chance", "crit_damage_multiplier", "knockback_power",
	"magic_damage", "aoe_radius", "projectile_speed", "attack_range", "range_multiplier",
	"aura_radius", "buff_power", "knockback_distance", "dot_damage", "dot_speed",
]
const SURVIVAL_IDS := ["health_point", "defense", "dodge", "regeneration"]
const ACTION_NAMES := [
	"PauseResumeButton", "PauseSettingsButton", "PauseEndRunButton", "PauseMainMenuButton",
]

var _errors := PackedStringArray()


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_resolution(viewport_size)
	await _validate_live_resize()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-983 Escape dossier passed 720p/1080p/2K geometry, content, tooltip, focus and live-resize gates.")
	quit(0)


func _validate_resolution(viewport_size: Vector2i) -> void:
	var fixture := await _open_fixture(viewport_size)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var pause := fixture["pause"] as Control
	var context := "%dx%d" % [viewport_size.x, viewport_size.y]
	if pause == null:
		_errors.append("%s: pause dossier did not open." % context)
		_cleanup_fixture(viewport, main)
		return

	var contract := _expected_contract(Vector2(viewport_size))
	_assert_frame(pause, contract, context)
	_assert_reserve_masks(pause, viewport_size, contract, context)
	_assert_major_geometry(pause, contract, context)
	_assert_semantic_stats(pause, viewport_size, contract, context)
	await _assert_focus_contract(pause, contract, context)
	_assert_action_styles(pause, context)
	_cleanup_fixture(viewport, main)
	await process_frame


func _validate_live_resize() -> void:
	var fixture := await _open_fixture(Vector2i(2560, 1440))
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var pause := fixture["pause"] as Control
	viewport.size = Vector2i(1280, 720)
	await _settle()
	var contract := _expected_contract(Vector2(1280, 720))
	_assert_frame(pause, contract, "live 2560x1440 -> 1280x720")
	_assert_reserve_masks(pause, Vector2i(1280, 720), contract, "live 2560x1440 -> 1280x720")
	_assert_major_geometry(pause, contract, "live 2560x1440 -> 1280x720")
	var base_grid := pause.find_child("BaseStatsGrid", true, false) as GridContainer
	if base_grid == null or base_grid.columns != 1:
		_errors.append("live resize: BaseStatsGrid must relayout to one compact column.")
	_cleanup_fixture(viewport, main)
	await process_frame


func _open_fixture(viewport_size: Vector2i) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 2)
	main.call("_start_combat")
	await _settle()
	main.ui._show_pause_menu(true)
	await _settle()
	return {
		"viewport": viewport,
		"main": main,
		"pause": main.find_child("PauseStatsMenuRoot", true, false) as Control,
	}


func _cleanup_fixture(viewport: SubViewport, main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()


func _assert_frame(pause: Control, contract: Dictionary, context: String) -> void:
	var frame := pause.find_child("EscapeStatsPanelFrame", true, false) as PanelContainer
	if frame == null:
		_errors.append("%s: missing EscapeStatsPanelFrame." % context)
		return
	var style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null or style.texture == null or style.draw_center:
		_errors.append("%s: frame must be a hollow StyleBoxTexture." % context)
		return
	if not style.texture.resource_path.ends_with(FRAME_PATH_SUFFIX):
		_errors.append("%s: frame uses %s." % [context, style.texture.resource_path])
	if style.texture_margin_left != 160.0 or style.texture_margin_top != 160.0 \
		or style.texture_margin_right != 160.0 or style.texture_margin_bottom != 160.0:
		_errors.append("%s: frame source margins must remain 160 on every edge." % context)
	if frame.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_errors.append("%s: decorative frame must ignore mouse input." % context)
	_assert_rect(frame.get_meta("gold_shell_content_rect", Rect2()) as Rect2, contract["safe"], "%s safe meta" % context)
	_assert_rect(frame.get_meta("dossier_inner_content_rect", Rect2()) as Rect2, contract["inner"], "%s inner meta" % context)
	var content := pause.find_child("DossierContentRoot", true, false) as Control
	if content == null or frame.get_index() <= content.get_index():
		_errors.append("%s: decorative frame must remain the final dossier layer." % context)


func _assert_reserve_masks(pause: Control, viewport_size: Vector2i, contract: Dictionary, context: String) -> void:
	var inner: Rect2 = contract["inner"]
	var content := pause.find_child("DossierContentRoot", true, false) as Control
	var frame := pause.find_child("EscapeStatsPanelFrame", true, false) as Control
	var expected := [
		Rect2(Vector2.ZERO, Vector2(viewport_size.x, inner.position.y)),
		Rect2(Vector2(0.0, inner.end.y), Vector2(viewport_size.x, viewport_size.y - inner.end.y)),
		Rect2(Vector2(0.0, inner.position.y), Vector2(inner.position.x, inner.size.y)),
		Rect2(Vector2(inner.end.x, inner.position.y), Vector2(viewport_size.x - inner.end.x, inner.size.y)),
	]
	var total_area := 0.0
	for index in range(expected.size()):
		var side: String = ["Top", "Bottom", "Left", "Right"][index]
		var mask := pause.find_child("DossierReserveMask%s" % side, true, false) as ColorRect
		if mask == null:
			_errors.append("%s: missing opaque %s reserve mask." % [context, side])
			continue
		_assert_rect(mask.get_global_rect(), expected[index], "%s %s reserve mask" % [context, side])
		if mask.color.a < 0.999 or mask.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_errors.append("%s: %s reserve mask must be opaque and mouse-ignore." % [context, side])
		if content == null or frame == null or mask.get_index() >= content.get_index() or mask.get_index() >= frame.get_index():
			_errors.append("%s: %s reserve mask must render below dossier content and final frame." % [context, side])
		total_area += mask.get_global_rect().size.x * mask.get_global_rect().size.y
	var expected_area := float(viewport_size.x * viewport_size.y) - inner.size.x * inner.size.y
	if absf(total_area - expected_area) > 1.0:
		_errors.append("%s: reserve masks cover %.1fpx², expected viewport-minus-inner %.1fpx²." % [context, total_area, expected_area])


func _assert_major_geometry(pause: Control, contract: Dictionary, context: String) -> void:
	var header := pause.find_child("DossierHeader", true, false) as Control
	var body := pause.find_child("DossierBody", true, false) as Control
	var hero := pause.find_child("HeroCard", true, false) as Control
	var right := pause.find_child("DerivedStatsPanel", true, false) as Control
	var actions := pause.find_child("PauseControlButtons", true, false) as HBoxContainer
	if header == null or body == null or hero == null or right == null or actions == null:
		_errors.append("%s: incomplete header/body/footer hierarchy." % context)
		return
	_assert_rect(header.get_global_rect(), contract["header"], "%s header" % context)
	_assert_rect(body.get_global_rect(), contract["body"], "%s body" % context)
	_assert_rect(hero.get_global_rect(), contract["hero"], "%s hero" % context)
	_assert_rect(right.get_global_rect(), contract["derived"], "%s derived" % context)
	_assert_rect(actions.get_global_rect(), contract["actions"], "%s actions" % context)
	for node in [header, hero, right, actions]:
		_assert_inside(node.get_global_rect(), contract["inner"], "%s %s" % [context, node.name])
	if hero.get_global_rect().intersects(right.get_global_rect()) or body.get_global_rect().intersects(actions.get_global_rect()):
		_errors.append("%s: body siblings/footer overlap." % context)
	var buttons: Array[Button] = []
	for button_name in ACTION_NAMES:
		var button := pause.find_child(button_name, true, false) as Button
		if button == null:
			_errors.append("%s: missing %s." % [context, button_name])
			continue
		buttons.append(button)
		_assert_inside(button.get_global_rect(), contract["inner"], "%s %s" % [context, button_name])
	for i in range(buttons.size()):
		for j in range(i + 1, buttons.size()):
			if buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()):
				_errors.append("%s: %s overlaps %s." % [context, buttons[i].name, buttons[j].name])
	var hero_scroll := pause.find_child("HeroCardScroll", true, false) as ScrollContainer
	var derived_scroll := pause.find_child("DerivedStatsScroll", true, false) as ScrollContainer
	for scroll in [hero_scroll, derived_scroll]:
		if scroll == null or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or not scroll.follow_focus:
			_errors.append("%s: both dossier scrolls must be vertical-only and follow focus." % context)


func _assert_semantic_stats(pause: Control, viewport_size: Vector2i, contract: Dictionary, context: String) -> void:
	var base_list := pause.find_child("BaseStatsList", true, false) as VBoxContainer
	var base_grid := pause.find_child("BaseStatsGrid", true, false) as GridContainer
	if base_list == null or base_grid == null:
		_errors.append("%s: missing semantic BaseStatsList/BaseStatsGrid." % context)
		return
	if base_grid.get_child_count() != BASE_IDS.size():
		_errors.append("%s: BaseStatsGrid has %d rows, expected %d real rows." % [context, base_grid.get_child_count(), BASE_IDS.size()])
	if base_list.find_children("BaseStatsCompatibilitySlot_*", "Control", true, false).size() != 0:
		_errors.append("%s: compatibility/dummy stat nodes are forbidden." % context)
	var expected_columns := 1 if viewport_size.y < 900 else 2
	if base_grid.columns != expected_columns:
		_errors.append("%s: BaseStatsGrid columns %d != %d." % [context, base_grid.columns, expected_columns])
	var stat_targets: Array[Control] = []
	for stat_id in BASE_IDS:
		_validate_stat_target(pause, "BaseStatRow_%s" % stat_id, "BaseStatName_%s" % stat_id, "BaseStatValue_%s" % stat_id, contract["inner"], context, stat_targets)
		if viewport_size == Vector2i(1920, 1080):
			var base_name := pause.find_child("BaseStatName_%s" % stat_id, true, false) as Label
			if base_name != null:
				var font := base_name.get_theme_font("font")
				var short_name_width := font.get_string_size(
					"Сила", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					base_name.get_theme_font_size("font_size")
				).x
				if base_name.size.x + 0.5 < short_name_width:
					_errors.append("%s: %s name lane %.1fpx cannot render even short localized label 'Сила' (%.1fpx)." % [context, stat_id, base_name.size.x, short_name_width])
	for stat_id in SURVIVAL_IDS:
		_validate_stat_target(pause, "SurvivalStatRow_%s" % stat_id, "SurvivalStatName_%s" % stat_id, "SurvivalStatValue_%s" % stat_id, contract["inner"], context, stat_targets)
	for stat_id in DERIVED_IDS:
		_validate_stat_target(pause, "DerivedStatChip_%s" % stat_id, "DerivedStatName_%s" % stat_id, "DerivedStatValue_%s" % stat_id, contract["inner"], context, stat_targets)
	var attack_speed := pause.find_child("DerivedStatValue_attack_speed", true, false) as Label
	var crit_chance := pause.find_child("DerivedStatValue_crit_chance", true, false) as Label
	var crit_power := pause.find_child("DerivedStatValue_crit_damage_multiplier", true, false) as Label
	if attack_speed == null or not attack_speed.text.ends_with("/с"):
		_errors.append("%s: attack speed must use localized /с units." % context)
	if crit_chance == null or not crit_chance.text.ends_with("%"):
		_errors.append("%s: crit chance must use percent units." % context)
	if crit_power == null or not crit_power.text.begins_with("×"):
		_errors.append("%s: crit multiplier must use × prefix." % context)


func _validate_stat_target(pause: Control, row_name: String, label_name: String, value_name: String, inner: Rect2, context: String, out: Array[Control]) -> void:
	var row := pause.find_child(row_name, true, false) as Control
	var label := pause.find_child(label_name, true, false) as Label
	var value := pause.find_child(value_name, true, false) as Label
	if row == null or label == null or value == null:
		_errors.append("%s: incomplete %s semantic row." % [context, row_name])
		return
	if row.focus_mode != Control.FOCUS_ALL:
		_errors.append("%s: %s is not keyboard/gamepad focusable." % [context, row_name])
	if row.tooltip_text.strip_edges() == "" or not row.tooltip_text.contains("Формула / источник:") or not row.tooltip_text.contains("Влияет:"):
		_errors.append("%s: %s lacks complete StatFormulas tooltip data." % [context, row_name])
	if label.text.strip_edges() == "" or value.text.strip_edges() == "":
		_errors.append("%s: %s has an empty compact label/value." % [context, row_name])
	var visible_rect := _clipped_visible_rect(row)
	if visible_rect.has_area():
		_assert_inside(visible_rect, inner, "%s %s visible rect" % [context, row_name])
	out.append(row)


func _assert_focus_contract(pause: Control, contract: Dictionary, context: String) -> void:
	var resume := pause.find_child("PauseResumeButton", true, false) as Button
	await process_frame
	if pause.get_viewport().gui_get_focus_owner() != resume:
		_errors.append("%s: initial focus is not Continue." % context)
	var required: Array[Control] = []
	for button_name in ACTION_NAMES:
		required.append(pause.find_child(button_name, true, false) as Control)
	for stat_id in BASE_IDS:
		required.append(pause.find_child("BaseStatRow_%s" % stat_id, true, false) as Control)
	for stat_id in SURVIVAL_IDS:
		required.append(pause.find_child("SurvivalStatRow_%s" % stat_id, true, false) as Control)
	for stat_id in DERIVED_IDS:
		required.append(pause.find_child("DerivedStatChip_%s" % stat_id, true, false) as Control)
	var reachable := _focus_reachable(resume)
	for target in required:
		if target == null or not reachable.has(target.get_instance_id()):
			_errors.append("%s: focus graph cannot reach %s." % [context, target.name if target != null else "missing target"])
	var base_grid := pause.find_child("BaseStatsGrid", true, false) as GridContainer
	if base_grid != null and base_grid.columns == 2:
		var rows: Array[Control] = []
		for child in base_grid.get_children():
			rows.append(child as Control)
		for row_index in range(0, rows.size(), 2):
			var left := rows[row_index]
			var right := rows[row_index + 1]
			if _resolved_neighbor(left, left.focus_neighbor_right) != right or _resolved_neighbor(right, right.focus_neighbor_left) != left:
				_errors.append("%s: base-stat left/right focus does not cross its geometric row." % context)
		for row_index in range(2, rows.size()):
			var current := rows[row_index]
			var expected_up := rows[row_index - 2]
			if _resolved_neighbor(current, current.focus_neighbor_top) != expected_up:
				_errors.append("%s: base-stat up focus changes logical column at %s." % [context, current.name])
	var focus_target := pause.find_child("DerivedStatChip_dot_speed", true, false) as Control
	if focus_target != null:
		focus_target.grab_focus()
		await _settle()
		var tooltip := pause.find_child("DossierFocusTooltip", true, false) as PanelContainer
		var tooltip_label := pause.find_child("DossierFocusTooltipLabel", true, false) as Label
		if tooltip == null or not tooltip.visible or tooltip_label == null or not tooltip_label.text.contains("Формула / источник:"):
			_errors.append("%s: focus does not expose the complete stat tooltip." % context)
		elif tooltip.size.x > 430.1 or tooltip.size.y > 288.1:
			_errors.append("%s: focus tooltip exceeds 430x288." % context)
		else:
			_assert_inside(tooltip.get_global_rect(), contract["inner"], "%s focus tooltip" % context)
		var derived_scroll := pause.find_child("DerivedStatsScroll", true, false) as ScrollContainer
		if derived_scroll != null:
			_assert_inside(_clipped_visible_rect(focus_target), derived_scroll.get_global_rect().grow(1.0), "%s focused derived row" % context)
	resume.grab_focus()
	await process_frame


func _resolved_neighbor(source: Control, path: NodePath) -> Control:
	if source == null or path.is_empty():
		return null
	return source.get_node_or_null(path) as Control


func _focus_reachable(start: Control) -> Dictionary:
	var result := {}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var current := queue.pop_front() as Control
		if current == null or result.has(current.get_instance_id()):
			continue
		result[current.get_instance_id()] = true
		for path in [current.focus_neighbor_left, current.focus_neighbor_right, current.focus_neighbor_top, current.focus_neighbor_bottom]:
			if path.is_empty():
				continue
			var neighbor := current.get_node_or_null(path) as Control
			if neighbor != null and not result.has(neighbor.get_instance_id()):
				queue.append(neighbor)
	return result


func _assert_action_styles(pause: Control, context: String) -> void:
	for index in range(ACTION_NAMES.size()):
		var button := pause.find_child(ACTION_NAMES[index], true, false) as Button
		if button == null:
			continue
		for state in ["normal", "hover", "focus", "pressed", "disabled"]:
			var style := button.get_theme_stylebox(state) as StyleBoxTexture
			if style == null:
				_errors.append("%s: %s missing %s texture state." % [context, button.name, state])
				continue
			var tint := style.modulate_color
			if index == 2:
				if tint.r <= tint.g + 0.10:
					_errors.append("%s: End Run %s state is not danger-red." % [context, state])
			elif absf(tint.r - tint.g) > 0.08 or absf(tint.g - tint.b) > 0.08:
				_errors.append("%s: neutral %s inherits a colored danger tint in %s." % [context, button.name, state])


func _expected_contract(viewport_size: Vector2) -> Dictionary:
	var margin_x := roundf(160.0 * viewport_size.x / 1536.0)
	var margin_y := roundf(160.0 * viewport_size.y / 1024.0)
	var safe := Rect2(Vector2(margin_x, margin_y), viewport_size - Vector2(margin_x * 2.0, margin_y * 2.0))
	var compact := viewport_size.y < 900.0
	var large := viewport_size.y >= 1200.0
	var reserve := 32.0 if large else 24.0
	var inner := safe.grow(-reserve)
	var header_h := 60.0 if compact else (104.0 if large else 72.0)
	var header_gap := 12.0 if compact else (24.0 if large else 16.0)
	var footer_gap := 12.0 if compact else (40.0 if large else 28.0)
	var footer_bottom := 16.0 if compact else 36.0
	var hero_w := 320.0 if compact else (520.0 if large else 420.0)
	var column_gap := 12.0 if compact else (24.0 if large else 20.0)
	var widths := [220.0, 220.0, 260.0, 220.0] if compact else ([280.0, 280.0, 320.0, 300.0] if large else [260.0, 260.0, 280.0, 280.0])
	var action_gap := 8.0 if compact else (20.0 if large else 16.0)
	var action_w := float(widths[0] + widths[1] + widths[2] + widths[3]) + action_gap * 3.0
	var action_h := 60.0 if compact else 72.0
	var actions := Rect2(Vector2(inner.get_center().x - action_w * 0.5, inner.end.y - footer_bottom - action_h), Vector2(action_w, action_h))
	var body_y := inner.position.y + header_h + header_gap
	var body := Rect2(Vector2(inner.position.x, body_y), Vector2(inner.size.x, actions.position.y - footer_gap - body_y))
	return {
		"safe": safe,
		"inner": inner,
		"header": Rect2(inner.position, Vector2(inner.size.x, header_h)),
		"body": body,
		"hero": Rect2(body.position, Vector2(hero_w, body.size.y)),
		"derived": Rect2(Vector2(body.position.x + hero_w + column_gap, body.position.y), Vector2(body.size.x - hero_w - column_gap, body.size.y)),
		"actions": actions,
	}


func _clipped_visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		var ancestor_control := ancestor as Control
		if ancestor_control != null and (ancestor_control.clip_contents or ancestor_control is ScrollContainer):
			rect = rect.intersection(ancestor_control.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


func _assert_rect(actual: Rect2, expected: Rect2, label: String) -> void:
	if actual.position.distance_to(expected.position) > 1.1 or actual.size.distance_to(expected.size) > 1.1:
		_errors.append("%s rect %s != %s." % [label, str(actual), str(expected)])


func _assert_inside(rect: Rect2, outer: Rect2, label: String) -> void:
	if rect.has_area() and not outer.grow(1.0).encloses(rect):
		_errors.append("%s rect %s escapes %s." % [label, str(rect), str(outer)])


func _settle() -> void:
	for _frame in range(10):
		await process_frame
