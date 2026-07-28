extends SceneTree

## Renders the Soldier ultimate contact sheets from the real local scenes.
##
## It shares the panel geometry and capture timestamps with the focused gate, so
## the committed PNG evidence and the headless composition assertions cannot
## drift apart. Headless runs skip rendering instead of writing an empty sheet.

const CAPTURE_SPEC := preload("res://tests/ultimates/presentation/soldier_ultimate_timelines.gd")


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-1468 Soldier ultimate contact capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	for capture in CAPTURE_SPEC.CAPTURES:
		var spec := capture as Dictionary
		var viewport := SubViewport.new()
		viewport.size = spec["size"]
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		await process_frame
		var host := _make_sheet(spec["size"])
		viewport.add_child(host)
		await process_frame
		await RenderingServer.frame_post_draw
		var output := str(spec["path"])
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		viewport.queue_free()
		await process_frame
		if error != OK:
			push_error("Soldier ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Soldier ultimate contact capture saved: %s" % output)
	quit(0)


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size), Vector2(0, size.y)])
	background.color = Color(0.024, 0.030, 0.034, 1.0)
	background.z_index = -20
	host.add_child(background)
	var title := Label.new()
	title.text = "SOLDIER WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
	title.position = Vector2(size.x * 0.5 - minf(size.x * 0.38, 470.0), size.y * 0.075)
	title.add_theme_font_size_override("font_size", maxi(18, int(size.y * 0.036)))
	title.add_theme_color_override("font_color", Color(0.88, 0.92, 0.78))
	host.add_child(title)
	for raw_pack in CAPTURE_SPEC.PACKS:
		var pack := raw_pack as Dictionary
		var center := CAPTURE_SPEC.panel_center(size, pack)
		var panel_rect := CAPTURE_SPEC.panel_rect(size, pack)
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([
			panel_rect.position,
			Vector2(panel_rect.end.x, panel_rect.position.y),
			panel_rect.end,
			Vector2(panel_rect.position.x, panel_rect.end.y),
		])
		panel.color = Color(0.07, 0.085, 0.075, 0.96)
		panel.z_index = -10
		host.add_child(panel)
		var label := Label.new()
		label.text = str(pack["title"])
		label.position = center + Vector2(-size.x * 0.14, size.y * CAPTURE_SPEC.PANEL_LABEL_Y_RATIO)
		label.add_theme_font_size_override("font_size", maxi(12, int(size.y * 0.021)))
		label.add_theme_color_override("font_color", pack["color"] as Color)
		host.add_child(label)
		var scene := (pack["scene"] as PackedScene).instantiate() as Node2D
		host.add_child(scene)
		CAPTURE_SPEC.seek_capture_frame(scene, pack)
		CAPTURE_SPEC.layout_capture_scene(scene, size, pack)
	return host
