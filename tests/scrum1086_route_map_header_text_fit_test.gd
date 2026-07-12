extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [
	Vector2i(1152,648), Vector2i(1280,720), Vector2i(1600,900),
	Vector2i(1920,1080), Vector2i(2560,1440),
]
const EPSILON := 1.0


func _initialize() -> void:
	for target in TARGETS:
		if not await _check_target(target):
			return
	if not await _check_live_resize():
		return
	print("[SCRUM-1086 Route Map header text fit] PASSED")
	quit(0)


func _build_route_map(viewport: SubViewport) -> Node:
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
	return main


func _check_target(target: Vector2i) -> bool:
	var viewport := SubViewport.new()
	viewport.size = target
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := await _build_route_map(viewport)
	var label := main.find_child("RouteMapStageLabel", true, false) as Label
	if not _assert_label_fit(label, target):
		return false
	viewport.queue_free()
	await process_frame
	return true


func _check_live_resize() -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := await _build_route_map(viewport)
	viewport.size = Vector2i(1152,648)
	for _frame in range(5):
		await process_frame
	var label := main.find_child("RouteMapStageLabel", true, false) as Label
	if not _assert_label_fit(label, Vector2i(1152,648)):
		return false
	viewport.queue_free()
	await process_frame
	return true


func _assert_label_fit(label: Label, target: Vector2i) -> bool:
	if label == null:
		return _fail("%s: RouteMapStageLabel missing." % str(target))
	var compact := target.x <= 1280 or target.y <= 720
	var required := ["Шаг ", "Сила ", "Бой ", "Выбор пути необратим"] if compact else ["Прогресс:", "Сила маршрута:", "Следующий бой:", "Выбранный путь фиксируется"]
	for token in required:
		if not label.text.contains(token):
			return _fail("%s: meaningful status token missing: %s; text=%s" % [str(target), token, label.text])
	if label.text.contains("...") or label.text.contains("…"):
		return _fail("%s: status copy already contains ellipsis." % str(target))
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font == null or font_size <= 0:
		return _fail("%s: themed font metrics unavailable." % str(target))
	var rendered_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	if rendered_width > label.size.x + EPSILON:
		return _fail("%s: rendered status width %.1f exceeds label %.1f: %s" % [str(target), rendered_width, label.size.x, label.text])
	var title_zone: Rect2 = label.get_parent().get_global_rect() if label.get_parent() is Control else Rect2()
	if not title_zone.grow(EPSILON).encloses(label.get_global_rect()):
		return _fail("%s: stage label leaves title/progress safe zone." % str(target))
	return true


func _fail(message: String) -> bool:
	push_error("[SCRUM-1086 Route Map header text fit] " + message)
	quit(1)
	return false
