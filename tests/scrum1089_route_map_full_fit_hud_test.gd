extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const EPSILON := 2.0
const TARGETS := {
	Vector2i(1280,720): {"header_y": 114.0, "legacy_header_y": 137.0, "legacy_hud_visible": Vector2(304.2623,58.0), "hud": Rect2(335,176,610,116), "nodes": Rect2(173,314,934,276)},
	Vector2i(1920,1080): {"header_y": 159.0, "legacy_header_y": 193.0, "legacy_hud_visible": Vector2(333.9130,64.0), "hud": Rect2(1012,167,668,128), "nodes": Rect2(240,319,1440,586)},
	Vector2i(2560,1440): {"header_y": 212.0, "legacy_header_y": 257.0, "legacy_hud_visible": Vector2(419.6721,80.0), "hud": Rect2(1398,220,839,160), "nodes": Rect2(323,408,1914,796)},
}


func _initialize() -> void:
	for target in TARGETS:
		if not await _check_target(target, TARGETS[target]):
			return
	print("[SCRUM-1089 Route Map full fit + HUD 2x] PASSED")
	quit(0)


func _check_target(target: Vector2i, expected: Dictionary) -> bool:
	var viewport := SubViewport.new()
	viewport.size = target
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 0)
	main.set("route_nodes", main.route._generate_route())
	main.route._show_battle_map()
	for _frame in range(5):
		await process_frame

	var screen := main.find_child("RouteMapScreen", true, false) as Control
	var header := main.find_child("RouteMapHeader", true, false) as Control
	var title := main.find_child("RouteMapTitleProgress", true, false) as Control
	var hud := main.find_child("RunResourceHud", true, false) as Control
	var scroll := main.find_child("RouteMapScroll", true, false) as ScrollContainer
	var canvas := main.find_child("VerticalRouteMap", true, false) as Control
	if screen == null or header == null or title == null or hud == null or scroll == null or canvas == null:
		return _fail("%s: required Route Map controls missing." % str(target))
	if not bool(screen.get_meta("scrum1089_full_fit", false)):
		return _fail("%s: screen does not publish SCRUM-1089 full-fit metadata." % str(target))
	if header.global_position.y > float(expected["header_y"]) + EPSILON or header.global_position.y >= float(expected["legacy_header_y"]):
		return _fail("%s: header was not raised: y=%.1f." % [str(target), header.global_position.y])
	if not _rect_near(hud.get_global_rect(), expected["hud"]):
		return _fail("%s: HUD is not the authored 2x visible rect: %s vs %s." % [str(target), hud.get_global_rect(), expected["hud"]])
	var legacy_hud_size: Vector2 = expected["legacy_hud_visible"]
	var actual_multiplier := hud.get_global_rect().size / legacy_hud_size
	if absf(actual_multiplier.x - 2.0) > 0.02 or absf(actual_multiplier.y - 2.0) > 0.02:
		return _fail("%s: HUD scale is not 2.00x SCRUM-1079 baseline: %s." % [str(target), actual_multiplier])
	var header_rect := header.get_global_rect()
	if title.get_global_rect().intersects(hud.get_global_rect(), true):
		return _fail("%s: title/progress overlaps the 2x HUD." % str(target))
	if not header_rect.grow(EPSILON).encloses(title.get_global_rect()) or not header_rect.grow(EPSILON).encloses(hud.get_global_rect()):
		return _fail("%s: title or HUD leaves the authored header safe-zone." % str(target))
	for child in hud.find_children("*", "Control", true, false):
		var child_control := child as Control
		if child_control != null and child_control.visible and not header_rect.grow(EPSILON).encloses(child_control.get_global_rect()):
			return _fail("%s: visible HUD child %s leaves the authored header safe-zone: %s." % [str(target), child_control.name, child_control.get_global_rect()])
	if not _rect_near(scroll.get_global_rect(), expected["nodes"]):
		return _fail("%s: expanded route viewport drifted: %s vs %s." % [str(target), scroll.get_global_rect(), expected["nodes"]])
	if canvas.custom_minimum_size.distance_to(scroll.size) > EPSILON:
		return _fail("%s: canvas does not fit viewport exactly." % str(target))
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return _fail("%s: a scrollbar axis remains enabled." % str(target))
	if scroll.scroll_horizontal != 0 or scroll.scroll_vertical != 0:
		return _fail("%s: full map viewport is not pinned to zero." % str(target))
	if scroll.get_h_scroll_bar().visible or scroll.get_v_scroll_bar().visible:
		return _fail("%s: hidden scrollbar still draws a lane." % str(target))

	var steps := {}
	var viewport_rect := scroll.get_global_rect()
	for child in canvas.get_children():
		var button := child as Button
		if button == null or not str(button.name).begins_with("RouteNode_"):
			continue
		var step := int(button.get_meta("route_step", -1))
		if step < 0 or step > 8:
			return _fail("%s: invalid route_step %d on %s." % [str(target), step, button.name])
		steps[step] = true
		if not viewport_rect.grow(EPSILON).encloses(button.get_global_rect()):
			return _fail("%s: route node %s is not simultaneously visible." % [str(target), button.name])
	if steps.size() != 9:
		return _fail("%s: only %d of 9 route columns are visible/rendered." % [str(target), steps.size()])
	for required_step in range(9):
		if not steps.has(required_step):
			return _fail("%s: exact route step set 0..8 is missing %d." % [str(target), required_step])

	viewport.queue_free()
	await process_frame
	return true


func _rect_near(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= EPSILON and actual.size.distance_to(expected.size) <= EPSILON


func _fail(message: String) -> bool:
	push_error("[SCRUM-1089 Route Map full fit + HUD 2x] " + message)
	quit(1)
	return false
