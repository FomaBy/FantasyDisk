extends SceneTree

## Renders the Knight ultimate contact sheets from the real local scenes.
##
## It shares the panel geometry and capture timestamps with the focused gate, so
## the committed PNG evidence and the headless composition assertions cannot
## drift apart. Headless runs skip rendering instead of writing an empty sheet.

const CAPTURE_SPEC := preload("res://tests/ultimates/presentation/knight_ultimate_timelines.gd")


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-1488 Knight ultimate contact capture skipped (headless); run windowed for PNGs.")
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
			push_error("Knight ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Knight ultimate contact capture saved: %s" % output)
	quit(0)


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size), Vector2(0, size.y)])
	background.color = Color(0.032, 0.028, 0.022, 1.0)
	background.z_index = -20
	host.add_child(background)
	var title := Label.new()
	title.text = CAPTURE_SPEC.SHEET_TITLE
	title.position = CAPTURE_SPEC.sheet_title_rect(size).position
	title.add_theme_font_size_override("font_size", CAPTURE_SPEC.sheet_title_font_size(size))
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
	host.add_child(title)
	for raw_pack in CAPTURE_SPEC.PACKS:
		var pack := raw_pack as Dictionary
		var panel_rect := CAPTURE_SPEC.panel_rect(size, pack)
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([
			panel_rect.position,
			Vector2(panel_rect.end.x, panel_rect.position.y),
			panel_rect.end,
			Vector2(panel_rect.position.x, panel_rect.end.y),
		])
		panel.color = Color(0.1, 0.08, 0.06, 0.96)
		panel.z_index = -10
		host.add_child(panel)
		var label := Label.new()
		label.text = str(pack["title"])
		label.position = CAPTURE_SPEC.panel_label_rect(size, pack).position
		label.add_theme_font_size_override("font_size", CAPTURE_SPEC.panel_label_font_size(size))
		label.add_theme_color_override("font_color", pack["color"] as Color)
		host.add_child(label)
		var scene := (pack["scene"] as PackedScene).instantiate() as Node2D
		host.add_child(scene)
		CAPTURE_SPEC.seek_capture_frame(scene, pack)
		CAPTURE_SPEC.layout_capture_scene(scene, size, pack)
	return host
