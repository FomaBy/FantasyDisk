extends SceneTree

# SCRUM-986 focused acceptance: both the transient victory banner and the full
# result modal stay exactly centered, visible and frame-safe at every supported
# viewport. The banner must also react to a live 2560 -> 1280 resize.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const BANNER_SIZE := Vector2(960.0, 224.0)
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _errors: PackedStringArray = []


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_resolution(viewport_size)
	await _validate_live_resize()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-986 victory banner/result centering passed at 1280x720, 1920x1080, 2560x1440 and live resize.")
	quit(0)


func _validate_resolution(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.ui._show_victory_banner(Callable())
	await create_timer(0.42).timeout
	_assert_banner(main, viewport_size, "initial")

	var click_catcher := main.find_child("VictoryBanner", true, false) as Button
	if click_catcher != null:
		click_catcher.pressed.emit()
	await _settle()

	main.set("selected_character_id", "berserk")
	main.set("run_metrics", _sample_metrics())
	main.ui._show_victory_screen()
	await _settle()
	var panel := main.find_child("PauseEndModalPanel_victory", true, false) as Control
	if panel == null:
		_errors.append("%s: missing full Victory result panel." % str(viewport_size))
	else:
		var panel_rect := panel.get_global_rect()
		_assert_center(panel_rect, Vector2(viewport_size) * 0.5, "%s result panel" % str(viewport_size))
		_assert_inside(panel_rect, _safe_rect(Vector2(viewport_size)), "%s result panel" % str(viewport_size))

	main.queue_free()
	viewport.queue_free()
	await process_frame


func _validate_live_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2560, 1440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.ui._show_victory_banner(Callable())
	await create_timer(0.42).timeout
	viewport.size = Vector2i(1280, 720)
	await _settle()
	_assert_banner(main, Vector2i(1280, 720), "live 2560->1280")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _assert_banner(main: Node, viewport_size: Vector2i, phase: String) -> void:
	var context := "%s %s" % [phase, str(viewport_size)]
	var frame := main.find_child("VictoryBannerFrame", true, false) as PanelContainer
	if frame == null:
		_errors.append("%s: missing VictoryBannerFrame." % context)
		return
	if frame.anchor_top != 0.5 or frame.anchor_bottom != 0.5:
		_errors.append("%s: VictoryBannerFrame vertical anchors must both be 0.5." % context)
	var expected := Rect2((Vector2(viewport_size) - BANNER_SIZE) * 0.5, BANNER_SIZE)
	var frame_rect := frame.get_global_rect()
	_assert_rect_near(frame_rect, expected, "%s transient banner" % context)
	_assert_center(frame_rect, Vector2(viewport_size) * 0.5, "%s transient banner" % context)
	_assert_inside(frame_rect, Rect2(Vector2.ZERO, Vector2(viewport_size)), "%s viewport" % context)
	_assert_inside(frame_rect, _safe_rect(Vector2(viewport_size)), "%s gold-shell safe area" % context)
	var label := frame.find_child("VictoryBannerLabel", true, false) as Label
	if label == null or label.text != "ПОБЕДА":
		_errors.append("%s: missing canonical VictoryBannerLabel." % context)
	elif not frame_rect.grow(1.0).encloses(label.get_global_rect()):
		_errors.append("%s: VictoryBannerLabel escapes frame rect %s." % [context, str(frame_rect)])


func _assert_center(rect: Rect2, expected_center: Vector2, label: String) -> void:
	if rect.get_center().distance_to(expected_center) > 1.1:
		_errors.append("%s center %s != %s." % [label, str(rect.get_center()), str(expected_center)])


func _assert_inside(rect: Rect2, outer: Rect2, label: String) -> void:
	if not outer.grow(1.0).encloses(rect):
		_errors.append("%s rect %s escapes %s." % [label, str(rect), str(outer)])


func _assert_rect_near(actual: Rect2, expected: Rect2, label: String) -> void:
	if actual.position.distance_to(expected.position) > 1.1 or actual.size.distance_to(expected.size) > 1.1:
		_errors.append("%s rect %s != expected %s." % [label, str(actual), str(expected)])


func _safe_rect(viewport_size: Vector2) -> Rect2:
	var margins := Vector4(
		roundf(160.0 * viewport_size.x / 1536.0),
		roundf(160.0 * viewport_size.y / 1024.0),
		roundf(160.0 * viewport_size.x / 1536.0),
		roundf(160.0 * viewport_size.y / 1024.0)
	)
	return Rect2(Vector2(margins.x, margins.y), viewport_size - Vector2(margins.x + margins.z, margins.y + margins.w))


func _sample_metrics() -> Dictionary:
	return {
		"kills": 12,
		"boss_kills": 1,
		"damage_dealt": 4200.0,
		"damage_taken": 700.0,
		"gold_collected": 300,
		"time_seconds": 120.0,
		"route_stage_reached": 4,
		"final_level": 6,
		"artifacts": [],
		"outcome_reason": "Победа",
	}


func _settle() -> void:
	for _frame in range(8):
		await process_frame
