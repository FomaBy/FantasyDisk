extends SceneTree

## Windowed evidence capture for the Robot ultimate presentation pack.
## Its title and labels share the measured layout functions in the focused test.

const CaptureSpec := preload("res://tests/ultimates/presentation/robot_ultimate_presentation_test.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-1490 Robot ultimate contact capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	for capture in CaptureSpec.CAPTURES:
		var spec := capture as Dictionary
		var viewport := SubViewport.new()
		viewport.size = spec.get("size", Vector2i.ZERO) as Vector2i
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		await process_frame
		viewport.add_child(_make_sheet(viewport.size))
		await process_frame
		await RenderingServer.frame_post_draw
		var output := str(spec.get("path", ""))
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		viewport.queue_free()
		await process_frame
		if error != OK:
			push_error("Robot ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Robot ultimate contact capture saved: %s" % output)
	quit(0)


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size), Vector2(0, size.y)])
	background.color = Color(0.028, 0.032, 0.045, 1.0)
	background.z_index = -20
	host.add_child(background)
	var title := Label.new()
	title.text = CaptureSpec.SHEET_TITLE
	title.position = CaptureSpec.sheet_title_rect(size).position
	title.add_theme_font_size_override("font_size", CaptureSpec.sheet_title_font_size(size))
	title.add_theme_color_override("font_color", Color(0.78, 0.91, 1.0))
	host.add_child(title)
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	for raw_pack in CaptureSpec.CAPTURE_PACKS:
		var pack := raw_pack as Dictionary
		var panel_rect := CaptureSpec.panel_rect(size, pack)
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([panel_rect.position, Vector2(panel_rect.end.x, panel_rect.position.y), panel_rect.end, Vector2(panel_rect.position.x, panel_rect.end.y)])
		panel.color = Color(0.07, 0.09, 0.12, 0.96)
		panel.z_index = -10
		host.add_child(panel)
		var label := Label.new()
		label.text = str(pack.get("title", ""))
		label.position = CaptureSpec.panel_label_rect(size, pack).position
		label.add_theme_font_size_override("font_size", CaptureSpec.panel_label_font_size(size))
		label.add_theme_color_override("font_color", pack.get("color", Color.WHITE) as Color)
		host.add_child(label)
		var scene_path := str(CaptureSpec.SCENE_PATHS.get(str(pack.get("weapon_id", "")), ""))
		var scene := (load(scene_path) as PackedScene).instantiate() as Node2D
		scene.position = CaptureSpec.panel_center(size, pack)
		scene.scale = Vector2.ONE * (float(size.y) / 1080.0) * 0.42
		host.add_child(scene)
		scene.begin(registry, {}, 0)
		scene.step(float(pack.get("time", 0.0)))
	return host
