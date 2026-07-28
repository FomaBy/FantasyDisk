extends SceneTree

const SPEC := preload("res://tests/ultimates/presentation/doctor_ultimate_timelines.gd")


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-1486 Doctor ultimate contact capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	for raw_capture in SPEC.CAPTURES:
		var capture := raw_capture as Dictionary
		var viewport := SubViewport.new()
		viewport.size = capture["size"]
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		await process_frame
		viewport.add_child(_make_sheet(capture["size"]))
		await process_frame
		await RenderingServer.frame_post_draw
		var output := str(capture["path"])
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		viewport.queue_free()
		await process_frame
		if error != OK:
			push_error("Doctor ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Doctor ultimate contact capture saved: %s" % output)
	quit(0)


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size), Vector2(0, size.y)])
	background.color = Color(0.022, 0.034, 0.027, 1.0)
	background.z_index = -20
	host.add_child(background)
	var title := Label.new()
	title.text = SPEC.SHEET_TITLE
	title.position = SPEC.sheet_title_rect(size).position
	title.add_theme_font_size_override("font_size", SPEC.sheet_title_font_size(size))
	title.add_theme_color_override("font_color", Color(0.88, 0.96, 0.78))
	host.add_child(title)
	for raw_pack in SPEC.PACKS:
		var pack := raw_pack as Dictionary
		var panel_rect := SPEC.panel_rect(size, pack)
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([
			panel_rect.position,
			Vector2(panel_rect.end.x, panel_rect.position.y),
			panel_rect.end,
			Vector2(panel_rect.position.x, panel_rect.end.y),
		])
		panel.color = Color(0.055, 0.085, 0.065, 0.98)
		panel.z_index = -10
		host.add_child(panel)
		var label := Label.new()
		label.text = str(pack["title"])
		label.position = SPEC.panel_label_rect(size, pack).position
		label.add_theme_font_size_override("font_size", SPEC.panel_label_font_size(size))
		label.add_theme_color_override("font_color", pack["color"] as Color)
		host.add_child(label)
		var scene := (pack["scene"] as PackedScene).instantiate() as Node2D
		host.add_child(scene)
		SPEC.seek_capture_frame(scene, pack)
		SPEC.layout_capture_scene(scene, size, pack)
	return host
