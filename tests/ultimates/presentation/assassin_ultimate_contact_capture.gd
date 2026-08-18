extends SceneTree

const SPEC := preload("res://tests/ultimates/presentation/assassin_ultimate_timelines.gd")
const PACKS := [
	{"weapon_id": "chakrams", "scene": preload("res://scenes/vfx/ultimates/assassin/AssassinChakramsEightMoons.tscn"), "time": 2.4, "position": Vector2(0.18, 0.55), "title": "CHAKRAMS — EIGHT MOONS / arena compass sweep", "color": Color(0.79, 0.62, 1.0)},
	{"weapon_id": "shadow_daggers", "scene": preload("res://scenes/vfx/ultimates/assassin/AssassinShadowDaggersMomentBeforeDeath.tscn"), "time": 2.6, "position": Vector2(0.50, 0.55), "title": "SHADOW DAGGERS — MOMENT BEFORE DEATH / freeze reveal", "color": Color(0.74, 0.35, 1.0)},
	{"weapon_id": "venom_wire", "scene": preload("res://scenes/vfx/ultimates/assassin/AssassinVenomWireBlackWeb.tscn"), "time": 2.8, "position": Vector2(0.82, 0.55), "title": "VENOM WIRE — BLACK WEB / hex collapse", "color": Color(0.42, 1.0, 0.32)},
]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-1838 Assassin ultimate contact capture skipped (headless); run windowed for PNGs.")
		quit(0)
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
		var path := str(capture.get("path", ""))
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		viewport.queue_free()
		if error != OK:
			push_error("Assassin ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Assassin ultimate contact capture saved: %s" % path)
	quit(0)


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size), Vector2(0, size.y)])
	background.color = Color(0.018, 0.016, 0.030, 1.0)
	background.z_index = -20
	host.add_child(background)
	var heading := Label.new()
	heading.text = "ASSASSIN WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
	heading.position = Vector2(size.x * 0.20, size.y * 0.075)
	heading.add_theme_font_size_override("font_size", maxi(18, int(size.y * 0.036)))
	heading.add_theme_color_override("font_color", Color(0.91, 0.82, 1.0))
	host.add_child(heading)
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		var center := Vector2(size) * (pack.get("position", Vector2.ZERO) as Vector2)
		var half_size := Vector2(size.x * 0.145, size.y * 0.30)
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([center - half_size, Vector2(center.x + half_size.x, center.y - half_size.y), center + half_size, Vector2(center.x - half_size.x, center.y + half_size.y)])
		panel.color = Color(0.055, 0.042, 0.085, 0.96)
		panel.z_index = -10
		host.add_child(panel)
		var label := Label.new()
		label.text = str(pack.get("title", ""))
		label.position = center + Vector2(-half_size.x + 10, half_size.y - size.y * 0.055)
		label.add_theme_font_size_override("font_size", maxi(11, int(size.y * 0.019)))
		label.add_theme_color_override("font_color", pack.get("color", Color.WHITE) as Color)
		host.add_child(label)
		var scene := (pack.get("scene") as PackedScene).instantiate() as Node2D
		var timeline := scene.get_node("Timeline") as AnimationPlayer
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(float(pack.get("time", 0.0)), true)
		scene.scale = Vector2.ONE * minf(float(size.y) / 1080.0, 1.0)
		scene.position = center + Vector2(0, -size.y * 0.035)
		host.add_child(scene)
	return host
