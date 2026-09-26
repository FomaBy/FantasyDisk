extends SceneTree

const SPEC := preload("res://tests/ultimates/presentation/engineer_ultimate_timelines.gd")


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3749 Engineer ultimate contact capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	var output_dir := _capture_output_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("Engineer ultimate contact capture could not create %s: %s" % [output_dir, error_string(mkdir_error)])
		quit(1)
		return
	for raw_capture in SPEC.CAPTURES:
		var capture := raw_capture as Dictionary
		var viewport := SubViewport.new()
		viewport.size = capture.get("size", Vector2i.ZERO) as Vector2i
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(_make_sheet(viewport.size))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var output := output_dir.path_join(str(capture.get("file", "")))
		var error := viewport.get_texture().get_image().save_png(output)
		viewport.queue_free()
		if error != OK:
			push_error("Engineer ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
	print("Engineer ultimate contact capture wrote %d sheets." % SPEC.CAPTURES.size())
	quit(0)


func _capture_output_dir() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			return ProjectSettings.globalize_path(argument.trim_prefix("--output-dir="))
	return ProjectSettings.globalize_path("user://fan_3749_engineer_evidence")


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	background.color = Color(0.016, 0.03, 0.036, 1.0)
	background.z_index = -20
	host.add_child(background)
	var heading := Label.new()
	heading.text = SPEC.SHEET_TITLE
	heading.position = SPEC.sheet_title_rect(size).position
	heading.add_theme_font_size_override("font_size", SPEC.sheet_title_font_size(size))
	heading.add_theme_color_override("font_color", Color(0.72, 0.98, 0.9))
	host.add_child(heading)
	for raw_pack in SPEC.PACKS:
		var pack := raw_pack as Dictionary
		var panel_rect := SPEC.panel_rect(size, pack)
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([
			panel_rect.position,
			panel_rect.position + Vector2(panel_rect.size.x, 0),
			panel_rect.end,
			panel_rect.position + Vector2(0, panel_rect.size.y),
		])
		panel.color = Color(0.05, 0.09, 0.1, 0.9)
		panel.z_index = -10
		host.add_child(panel)
		var label := Label.new()
		label.text = str(pack.get("title", ""))
		label.position = SPEC.panel_label_rect(size, pack).position
		label.add_theme_font_size_override("font_size", SPEC.panel_label_font_size(size))
		label.add_theme_color_override("font_color", pack.get("color", Color.WHITE) as Color)
		host.add_child(label)
		var scene := (pack.get("scene") as PackedScene).instantiate() as Node2D
		var timeline := scene.get_node("Timeline") as AnimationPlayer
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(float(pack.get("time", 0.0)), true)
		scene.scale = Vector2.ONE * minf(float(size.y) / 1440.0, 1.0)
		scene.position = SPEC.panel_center(size, pack) + Vector2(0, -float(size.y) * 0.035)
		host.add_child(scene)
	return host
