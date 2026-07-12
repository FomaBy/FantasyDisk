extends SceneTree

# SCRUM-981 gold-shell regression + SCRUM-1057 horizontal Route Map matrix.
# It verifies all accepted responsive targets, the hollow meta40 frame, and the
# hard rule that every route interaction remains inside the empty frame zone.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FRAME_PATH_SUFFIX := "meta40/frame_border.png"
const EPSILON := 2.0
const MATRIX := {
	"1280x720": {
		"viewport": Vector2i(1280, 720),
		"safe": Rect2(133, 113, 1014, 494),
		"inner": Rect2(157, 137, 966, 446),
		"header": Rect2(157,137,966,80), "title": Rect2(173,141,450,58),
		"resources": Rect2(731,141,376,58), "route": Rect2(157,229,966,354),
		"nodes": Rect2(175,249,834,286), "lane": Rect2(175,549,834,14),
		"scroll": Rect2(175,249,834,314), "node_size": 60.0,
	},
	"1920x1080": {
		"viewport": Vector2i(1920, 1080),
		"safe": Rect2(200, 169, 1520, 742),
		"inner": Rect2(224, 193, 1472, 694),
		"header": Rect2(224,193,1472,88), "title": Rect2(248,197,700,64),
		"resources": Rect2(1128,197,544,64), "route": Rect2(224,297,1472,590),
		"nodes": Rect2(248,321,1328,500), "lane": Rect2(248,845,1328,18),
		"scroll": Rect2(248,321,1328,542), "node_size": 72.0,
	},
	"2560x1440": {
		"viewport": Vector2i(2560, 1440),
		"safe": Rect2(267, 225, 2026, 990),
		"inner": Rect2(299, 257, 1962, 926),
		"header": Rect2(299,257,1962,104), "title": Rect2(331,263,940,80),
		"resources": Rect2(1557,263,672,80), "route": Rect2(299,385,1962,798),
		"nodes": Rect2(331,417,1786,694), "lane": Rect2(331,1139,1786,20),
		"scroll": Rect2(331,417,1786,742), "node_size": 88.0,
	},
	"1152x648": {"viewport": Vector2i(1152,648), "safe": Rect2(120,101,912,446), "inner": Rect2(140,121,872,406), "header": Rect2(140,121,872,76), "title": Rect2(154,125,416,54), "resources": Rect2(666,125,332,54), "route": Rect2(140,209,872,318), "nodes": Rect2(158,227,740,258), "lane": Rect2(158,497,740,14), "scroll": Rect2(158,227,740,284), "node_size": 56.0},
	"1600x900": {"viewport": Vector2i(1600,900), "safe": Rect2(167,141,1266,618), "inner": Rect2(191,165,1218,570), "header": Rect2(191,165,1218,84), "title": Rect2(211,169,580,62), "resources": Rect2(965,169,424,62), "route": Rect2(191,265,1218,470), "nodes": Rect2(215,289,1074,392), "lane": Rect2(215,701,1074,16), "scroll": Rect2(215,289,1074,428), "node_size": 68.0},
}


func _initialize() -> void:
	for key in ["1152x648", "1280x720", "1600x900", "1920x1080", "2560x1440"]:
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
	if not _rect_near(screen.get_meta("scrum1057_route_rect", Rect2()), expected["route"]):
		return _fail("%s: authored route body drifted." % context)
	if not _rect_near(screen.get_meta("scrum1057_node_viewport_rect", Rect2()), expected["nodes"]):
		return _fail("%s: authored node viewport drifted." % context)
	if not _rect_near(screen.get_meta("scrum1057_horizontal_lane_rect", Rect2()), expected["lane"]):
		return _fail("%s: authored horizontal lane drifted." % context)

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

	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		return _fail("%s: horizontal route scrolling must be automatic." % context)
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or scroll.scroll_vertical != 0:
		return _fail("%s: vertical scrolling must be disabled and pinned to zero." % context)
	if map_area.custom_minimum_size.x <= expected["nodes"].size.x + EPSILON:
		return _fail("%s: long route canvas must overflow horizontally." % context)
	if absf(map_area.custom_minimum_size.y - expected["nodes"].size.y) > EPSILON:
		return _fail("%s: route canvas height must match the node viewport." % context)

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
		if not str(button.name).contains("_boss_") and absf(button.size.x - float(expected["node_size"])) > EPSILON:
			return _fail("%s: normal route node size drifted: %s." % [context, str(button.size)])
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
