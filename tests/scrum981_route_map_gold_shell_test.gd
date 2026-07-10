extends SceneTree

# SCRUM-981 focused gate for the Route Map half of the unified gold menu shell.
# It verifies the authored 1280/1920/2560 matrix, the hollow meta40 frame, and
# the hard rule that every route interaction remains inside the empty frame zone.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FRAME_PATH_SUFFIX := "meta40/frame_border.png"
const EPSILON := 2.0
const MATRIX := {
	"1280x720": {
		"viewport": Vector2i(1280, 720),
		"safe": Rect2(133, 113, 1014, 494),
		"inner": Rect2(157, 137, 966, 446),
		"header": Rect2(157, 137, 966, 92),
		"title": Rect2(173, 149, 520, 68),
		"resources": Rect2(731, 149, 376, 68),
		"scroll": Rect2(157, 245, 966, 322),
		"scrollbar_lane": 14.0,
	},
	"1920x1080": {
		"viewport": Vector2i(1920, 1080),
		"safe": Rect2(200, 169, 1520, 742),
		"inner": Rect2(224, 193, 1472, 694),
		"header": Rect2(224, 193, 1472, 104),
		"title": Rect2(248, 209, 700, 70),
		"resources": Rect2(1128, 209, 544, 70),
		"scroll": Rect2(224, 317, 1472, 550),
		"scrollbar_lane": 18.0,
	},
	"2560x1440": {
		"viewport": Vector2i(2560, 1440),
		"safe": Rect2(267, 225, 2026, 990),
		"inner": Rect2(299, 257, 1962, 926),
		"header": Rect2(299, 257, 1962, 112),
		"title": Rect2(323, 273, 960, 80),
		"resources": Rect2(1573, 273, 664, 80),
		"scroll": Rect2(299, 393, 1962, 766),
		"scrollbar_lane": 18.0,
	},
}


func _initialize() -> void:
	for key in ["1280x720", "1920x1080", "2560x1440"]:
		if not await _check_matrix_entry(key, MATRIX[key]):
			return
	print("[SCRUM-981 Route Map gold shell] PASSED")
	quit(0)


func _check_matrix_entry(context: String, expected: Dictionary) -> bool:
	var viewport := SubViewport.new()
	viewport.size = expected["viewport"]
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
	await process_frame
	await process_frame
	await process_frame

	var screen := main.find_child("RouteMapScreen", true, false) as Control
	var frame := main.find_child("RouteMapFrame", true, false) as Panel
	var header := main.find_child("RouteMapHeader", true, false) as Control
	var title := main.find_child("RouteMapTitleProgress", true, false) as Control
	var resources := main.find_child("RunResourceHud", true, false) as Control
	var scroll := main.find_child("RouteMapScroll", true, false) as ScrollContainer
	var map_area := main.find_child("VerticalRouteMap", true, false) as Control
	if screen == null or frame == null or header == null or title == null or resources == null or scroll == null or map_area == null:
		return _fail("%s: missing Route Map shell/control node." % context)
	if main.find_child("UpgradeFabButton", true, false) != null:
		return _fail("%s: SCRUM-982 Route Map must not expose manual Attribute Shop FAB." % context)

	if screen.get_child(screen.get_child_count() - 1) != frame:
		return _fail("%s: RouteMapFrame must be the final child above all content." % context)
	if frame.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return _fail("%s: RouteMapFrame must ignore mouse input." % context)
	var frame_style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if frame_style == null or frame_style.texture == null:
		return _fail("%s: RouteMapFrame must use a StyleBoxTexture." % context)
	if frame_style.draw_center:
		return _fail("%s: RouteMapFrame must be hollow (draw_center=false)." % context)
	if not frame_style.texture.resource_path.ends_with(FRAME_PATH_SUFFIX):
		return _fail("%s: unexpected RouteMapFrame texture %s." % [context, frame_style.texture.resource_path])

	if not _rect_near(screen.get_meta("scrum981_safe_rect", Rect2()), expected["safe"]):
		return _fail("%s: safe rect drifted: %s vs %s." % [context, screen.get_meta("scrum981_safe_rect"), expected["safe"]])
	if not _rect_near(screen.get_meta("scrum981_inner_rect", Rect2()), expected["inner"]):
		return _fail("%s: inner content rect drifted: %s vs %s." % [context, screen.get_meta("scrum981_inner_rect"), expected["inner"]])
	if not _rect_near(header.get_global_rect(), expected["header"]):
		return _fail("%s: header rect drifted: %s vs %s." % [context, header.get_global_rect(), expected["header"]])
	if not _rect_near(title.get_global_rect(), expected["title"]):
		return _fail("%s: title/progress rect drifted: %s vs %s." % [context, title.get_global_rect(), expected["title"]])
	if not _rect_near(scroll.get_global_rect(), expected["scroll"]):
		return _fail("%s: scroll rect drifted: %s vs %s." % [context, scroll.get_global_rect(), expected["scroll"]])

	var inner_rect: Rect2 = expected["inner"]
	var resource_zone: Rect2 = expected["resources"]
	if not _encloses_with_epsilon(inner_rect, header.get_global_rect()):
		return _fail("%s: header touches the frame reserve/ornament." % context)
	if not _encloses_with_epsilon(expected["title"], title.get_global_rect()):
		return _fail("%s: title/progress leaves its authored zone." % context)
	if not _encloses_with_epsilon(resource_zone, resources.get_global_rect()):
		return _fail("%s: resource HUD leaves its authored safe zone: %s not in %s." % [context, resources.get_global_rect(), resource_zone])
	if not _encloses_with_epsilon(inner_rect, scroll.get_global_rect()):
		return _fail("%s: route scroll touches the frame reserve/ornament." % context)
	if header.get_global_rect().intersects(scroll.get_global_rect()):
		return _fail("%s: header overlaps route scroll." % context)

	for label_name in ["RouteMapTitleProgress"]:
		var label_host := main.find_child(label_name, true, false) as Control
		if label_host == null or not _encloses_with_epsilon(expected["title"], label_host.get_global_rect()):
			return _fail("%s: title/progress content is not contained." % context)
	for label in title.find_children("*", "Label", true, false):
		var typed_label := label as Label
		if typed_label != null and not _encloses_with_epsilon(expected["title"], typed_label.get_global_rect()):
			return _fail("%s: label %s overflows title/progress zone: %s." % [context, typed_label.name, typed_label.get_global_rect()])

	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return _fail("%s: horizontal route scrolling must stay disabled." % context)
	var expected_scroll: Rect2 = expected["scroll"]
	var max_canvas_width: float = expected_scroll.size.x - float(expected["scrollbar_lane"])
	if map_area.custom_minimum_size.x > max_canvas_width + EPSILON:
		return _fail("%s: map canvas enters the reserved scrollbar lane: %.1f > %.1f." % [context, map_area.custom_minimum_size.x, max_canvas_width])
	if scroll.scroll_horizontal != 0:
		return _fail("%s: horizontal route offset must remain zero." % context)

	var route_button_count := 0
	for child in map_area.get_children():
		var button := child as Button
		if button == null or not str(button.name).begins_with("RouteNode_"):
			continue
		route_button_count += 1
		var local_rect := button.get_rect()
		var canvas_rect := Rect2(Vector2.ZERO, map_area.custom_minimum_size)
		if not _encloses_with_epsilon(canvas_rect, local_rect):
			return _fail("%s: route node %s leaves the clipped map canvas: %s." % [context, button.name, local_rect])
		var visible_part := button.get_global_rect().intersection(scroll.get_global_rect())
		if visible_part.size.x > 0.0 and visible_part.size.y > 0.0 and not _encloses_with_epsilon(expected["scroll"], visible_part):
			return _fail("%s: visible hitbox %s leaves the route scroll safe zone." % [context, button.name])
	if route_button_count == 0:
		return _fail("%s: route map rendered no interactive route nodes." % context)

	viewport.queue_free()
	await process_frame
	await process_frame
	return true


func _rect_near(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= EPSILON and actual.size.distance_to(expected.size) <= EPSILON


func _encloses_with_epsilon(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(EPSILON).encloses(inner)


func _fail(message: String) -> bool:
	push_error("[SCRUM-981 Route Map gold shell] " + message)
	quit(1)
	return false
