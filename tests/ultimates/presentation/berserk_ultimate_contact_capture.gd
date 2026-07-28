extends SceneTree

const OUTPUT_DIR := "res://docs/design/references/weapon_ultimates/berserk"
const PACKS := [

	{
		"scene": preload("res://scenes/vfx/ultimates/berserk/BerserkSwordScarletWhirlwind.tscn"),
		"time": 7.48,
		"title": "SWORD — SCARLET WHIRLWIND / inward cross-slash",
		"position": Vector2(0.18, 0.54),
		"color": Color(1.0, 0.32, 0.34),
	},
	{
		"scene": preload("res://scenes/vfx/ultimates/berserk/BerserkAxeExecutionLoop.tscn"),
		"time": 3.18,
		"title": "AXE — EXECUTION LOOP / boundary turn",
		"position": Vector2(0.5, 0.54),
		"color": Color(1.0, 0.56, 0.20),
	},
	{
		"scene": preload("res://scenes/vfx/ultimates/berserk/BerserkHammerFourfoldRift.tscn"),
		"time": 2.76,
		"title": "HAMMER — FOURFOLD RIFT / central quake",
		"position": Vector2(0.82, 0.54),
		"color": Color(1.0, 0.82, 0.40),
	},
]

const CAPTURES := [
	{"name": "648p", "size": Vector2i(1152, 648)},
	{"name": "720p", "size": Vector2i(1280, 720)},
	{"name": "1080p", "size": Vector2i(1920, 1080)},
	{"name": "2k", "size": Vector2i(2560, 1440)},
]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Berserk ultimate contact capture requires a rendering display server.")
		quit(1)
		return
	for capture in CAPTURES:
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
		var output := "%s/berserk_ultimate_timelines_%s.png" % [OUTPUT_DIR, str(spec["name"])]
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		viewport.queue_free()
		await process_frame
		if error != OK:
			push_error("Berserk ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Berserk ultimate contact capture saved: %s" % output)
	quit(0)


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size), Vector2(0, size.y)])
	background.color = Color(0.028, 0.020, 0.040, 1.0)
	background.z_index = -20
	host.add_child(background)
	var title := Label.new()
	title.text = "BERSERK WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
	title.position = Vector2(size.x * 0.5 - minf(size.x * 0.38, 470.0), size.y * 0.075)
	title.add_theme_font_size_override("font_size", maxi(18, int(size.y * 0.036)))
	title.add_theme_color_override("font_color", Color(0.97, 0.86, 0.68))
	host.add_child(title)
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		var center := Vector2(size) * (pack["position"] as Vector2)
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([
			center + Vector2(-size.x * 0.145, -size.y * 0.30),
			center + Vector2(size.x * 0.145, -size.y * 0.30),
			center + Vector2(size.x * 0.145, size.y * 0.30),
			center + Vector2(-size.x * 0.145, size.y * 0.30),
		])
		panel.color = Color(0.09, 0.06, 0.11, 0.96)
		panel.z_index = -10
		host.add_child(panel)
		var label := Label.new()
		label.text = str(pack["title"])
		label.position = center + Vector2(-size.x * 0.14, size.y * 0.25)
		label.add_theme_font_size_override("font_size", maxi(12, int(size.y * 0.021)))
		label.add_theme_color_override("font_color", pack["color"] as Color)
		host.add_child(label)
		var scene := (pack["scene"] as PackedScene).instantiate() as Node2D
		scene.position = center
		scene.scale = Vector2.ONE * clampf(float(size.y) / 1040.0, 0.54, 1.28)
		host.add_child(scene)
		var timeline := scene.get_node("Timeline") as AnimationPlayer
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(float(pack["time"]), true)
	return host
