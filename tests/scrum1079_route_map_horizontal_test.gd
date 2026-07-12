extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [
	Vector2i(1152,648), Vector2i(1280,720), Vector2i(1600,900),
	Vector2i(1920,1080), Vector2i(2560,1440),
]


func _initialize() -> void:
	for target in TARGETS:
		if not await _check_target(target):
			return
	print("[SCRUM-1079 horizontal Route Map] PASSED")
	quit(0)


func _check_target(target: Vector2i) -> bool:
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
	for _frame in range(4):
		await process_frame

	var screen := main.find_child("RouteMapScreen", true, false) as Control
	var scroll := main.find_child("RouteMapScroll", true, false) as ScrollContainer
	var canvas := main.find_child("VerticalRouteMap", true, false) as Control
	if screen == null or scroll == null or canvas == null:
		return _fail("%s: missing horizontal Route Map runtime nodes." % str(target))
	if str(canvas.get_meta("route_orientation", "")) != "horizontal":
		return _fail("%s: canvas does not publish horizontal orientation." % str(target))
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		return _fail("%s: horizontal scrolling is not automatic." % str(target))
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or scroll.scroll_vertical != 0:
		return _fail("%s: vertical scroll contract failed." % str(target))

	var by_step := {}
	for child in canvas.get_children():
		var button := child as Button
		if button == null or not str(button.name).begins_with("RouteNode_"):
			continue
		var step := int(button.get_meta("route_step", -1))
		if step < 0:
			return _fail("%s: route node lacks step metadata." % str(target))
		if not by_step.has(step):
			by_step[step] = []
		by_step[step].append(button)
	if by_step.size() != (main.get("route_nodes") as Array).size():
		return _fail("%s: rendered columns do not match route data." % str(target))

	var previous_center_x := -INF
	for step in range(by_step.size()):
		var column: Array = by_step[step]
		var center_x := (column[0] as Button).position.x + (column[0] as Button).size.x * 0.5
		if center_x <= previous_center_x:
			return _fail("%s: step %d does not advance left-to-right." % [str(target), step])
		previous_center_x = center_x
		var previous_y := -INF
		var previous_rect := Rect2()
		column.sort_custom(func(a: Button, b: Button) -> bool: return a.position.y < b.position.y)
		for button in column:
			if button.position.y <= previous_y:
				return _fail("%s: branches overlap in column %d." % [str(target), step])
			if previous_rect.has_area() and previous_rect.intersects(button.get_rect(), true):
				return _fail("%s: branch hitboxes overlap in column %d." % [str(target), step])
			previous_y = button.position.y
			previous_rect = button.get_rect()
			if button.position.y < -1.0 or button.position.y + button.size.y > canvas.custom_minimum_size.y + 1.0:
				return _fail("%s: node leaves vertical viewport." % str(target))

	for line_node in canvas.find_children("RouteMapLine", "ColorRect", true, false):
		var line := line_node as ColorRect
		var end := line.position + Vector2(line.size.x, 0.0).rotated(line.rotation)
		if end.x <= line.position.x:
			return _fail("%s: connection does not advance left-to-right." % str(target))
		if line.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return _fail("%s: connection intercepts pointer input." % str(target))

	var before := scroll.scroll_horizontal
	main.route._pan_route_map_scroll(scroll, Vector2(-96.0, 80.0))
	if scroll.scroll_horizontal <= before or scroll.scroll_vertical != 0:
		return _fail("%s: drag did not pan horizontally-only." % str(target))
	var focused := viewport.gui_get_focus_owner() as Button
	if focused == null or int(focused.get_meta("route_step", -1)) != 0:
		return _fail("%s: initial gamepad focus is not in the available start column." % str(target))

	viewport.queue_free()
	await process_frame
	return true


func _fail(message: String) -> bool:
	push_error("[SCRUM-1079 horizontal Route Map] " + message)
	quit(1)
	return false
