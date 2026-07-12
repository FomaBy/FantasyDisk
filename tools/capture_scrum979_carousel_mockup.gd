extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
const OUTPUT_DIR := "res://docs/design/mockups/scrum979_hero_carousel_window"

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	for viewport_size in VIEWPORTS:
		await _capture(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	print("SCRUM-979 existing-PixelLab-source mockups captured.")
	quit(0)


func _capture(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	for _frame_index in range(5):
		await process_frame
	var carousel := main.find_child("HS4Carousel", true, false) as Control
	var prev := main.find_child("HS4CarouselPrevButton", true, false) as Button
	var next := main.find_child("HS4CarouselNextButton", true, false) as Button
	var first_slot := main.find_child("HS4CarouselSlot_00", true, false) as Button
	if carousel == null or prev == null or next == null or first_slot == null:
		push_error("SCRUM-979 mockup capture is missing carousel controls.")
		quit(1)
		return
	var arrow_h := clampf(roundf(first_slot.size.y * 0.52), 84.0, 140.0)
	var arrow_size := Vector2(roundf(arrow_h * 0.75), arrow_h)
	prev.position = Vector2(0.0, roundf((carousel.size.y - arrow_size.y) * 0.5))
	prev.size = arrow_size
	prev.custom_minimum_size = arrow_size
	next.position = Vector2(carousel.size.x - arrow_size.x, prev.position.y)
	next.size = arrow_size
	next.custom_minimum_size = arrow_size
	for entry in [[prev, "carousel_left"], [next, "carousel_right"]]:
		var button := entry[0] as Button
		var slot := str(entry[1])
		button.add_theme_stylebox_override("normal", main.ui.call("_hs4_pixellab_style", slot, arrow_size, Color.WHITE))
		button.add_theme_stylebox_override("hover", main.ui.call("_hs4_pixellab_style", slot, arrow_size, Color(1.08, 1.04, 0.92, 1.0)))
		button.add_theme_stylebox_override("focus", main.ui.call("_hs4_pixellab_style", slot, arrow_size, Color(1.08, 1.04, 0.92, 1.0)))
		button.add_theme_font_size_override("font_size", clampi(int(roundf(arrow_h * 0.15)), 14, 20))
	for _frame_index in range(4):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("SCRUM-979 mockup capture returned an empty image.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	image.save_png("%s/existing_pixellab_reuse_mockup_%dx%d.png" % [
		ProjectSettings.globalize_path(OUTPUT_DIR), viewport_size.x, viewport_size.y])
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		push_error("SCRUM-979 mockup teardown failed: %s" % "; ".join(teardown_errors))
		quit(1)
