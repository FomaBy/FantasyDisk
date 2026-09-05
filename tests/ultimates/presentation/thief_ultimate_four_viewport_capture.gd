extends SceneTree

## Windowed, deterministic evidence renderer for FAN-3890.
##
## Each sheet contains the three canonical Thief ultimate scenes in four
## presentation modes. The timeline scene and victim-impact flipbook are real
## shipped runtime resources; only the surrounding HUD, player, and hazard
## fixtures make their readability reviewable in one stable frame.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/thief/fan3890_capture_manifest.json"
const VICTIM_IMPACT_INTEGRATION_SHA := "245af1bd2390e0b82be4f596b53278ff7d9ee874"
const VICTIM_IMPACT_INTEGRATION_TREE := "058d8d80a6cf60f59680c4deaf83b9202d201d1c"
const CAPTURE_BASE_SHA := "612279e7ee83a5d60468cbae2e1d039f8715a91d"
const CAPTURE_BASE_TREE := "8be184e13edd88d88da1e3aa0257e070c121d695"

const WEAPON_IDS: Array[String] = ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]
const MODE_IDS: Array[String] = ["normal", "crowded", "reduced_motion", "photosensitivity_safe"]
const TIMELINE_SCENES := {
	"thief_coin_pouch": preload("res://scenes/vfx/ultimates/thief/ThiefCoinPouchUltimate.tscn"),
	"thief_shadow_cloak": preload("res://scenes/vfx/ultimates/thief/ThiefShadowCloakUltimate.tscn"),
	"thief_smoke_bomb": preload("res://scenes/vfx/ultimates/thief/ThiefSmokeBombUltimate.tscn"),
}
const EFFECT_SCENE_PATHS := {
	"thief_coin_pouch": "res://scripts/ultimates/classes/thief/thief_coin_pouch.tscn",
	"thief_shadow_cloak": "res://scripts/ultimates/classes/thief/thief_shadow_cloak.tscn",
	"thief_smoke_bomb": "res://scripts/ultimates/classes/thief/thief_smoke_bomb.tscn",
}
const VICTIM_FRAMES := {
	"thief_coin_pouch": preload("res://assets/sprites/effects/thief/coin_pouch/coin_pouch_spriteframes.tres"),
	"thief_shadow_cloak": preload("res://assets/sprites/effects/thief/shadow_cloak/shadow_cloak_spriteframes.tres"),
	"thief_smoke_bomb": preload("res://assets/sprites/effects/thief/smoke_bomb/smoke_bomb_spriteframes.tres"),
}
const CAPTURES := [
	{"id": "648p", "path": "res://docs/design/reference-assets-lfs/thief-ultimate-timelines-fan3890/thief_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"id": "720p", "path": "res://docs/design/reference-assets-lfs/thief-ultimate-timelines-fan3890/thief_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"id": "1080p", "path": "res://docs/design/reference-assets-lfs/thief-ultimate-timelines-fan3890/thief_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"id": "2k", "path": "res://docs/design/reference-assets-lfs/thief-ultimate-timelines-fan3890/thief_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const MODE_SPECS := [
	{
		"id": "normal", "label": "NORMAL", "victims": 3, "timeline_seconds": 1.34,
		"marker_color": Color(0.18, 0.76, 1.0), "panel_color": Color(0.055, 0.090, 0.135, 1.0),
	},
	{
		"id": "crowded", "label": "CROWDED", "victims": 39, "timeline_seconds": 1.34,
		"marker_color": Color(1.0, 0.58, 0.18), "panel_color": Color(0.125, 0.078, 0.045, 1.0),
	},
	{
		"id": "reduced_motion", "label": "REDUCED MOTION", "victims": 3, "timeline_seconds": 1.10,
		"marker_color": Color(0.36, 0.92, 0.48), "panel_color": Color(0.045, 0.105, 0.080, 1.0),
	},
	{
		"id": "photosensitivity_safe", "label": "PHOTOSENSITIVITY SAFE", "victims": 3, "timeline_seconds": 1.10,
		"marker_color": Color(0.78, 0.48, 1.0), "panel_color": Color(0.090, 0.060, 0.125, 1.0),
	},
]

const BACKGROUND_COLOR := Color(0.018, 0.025, 0.040, 1.0)
const HUD_COLOR := Color(0.080, 0.115, 0.165, 1.0)
const PLAYER_COLOR := Color(0.68, 0.92, 1.0, 1.0)
const HAZARD_COLOR := Color(1.0, 0.32, 0.16, 1.0)
const GRID_COLOR := Color(0.24, 0.31, 0.42, 1.0)
const PANEL_TOP_RATIO := 0.180
const PANEL_BOTTOM_RATIO := 0.895
const PANEL_MARGIN_RATIO := 0.010


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3890 Thief four-viewport capture skipped (headless); run windowed for PNG evidence.")
		quit(0)
		return
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var result := await _capture_sheet(capture)
		if result != OK:
			push_error("FAN-3890 Thief capture failed: %s" % error_string(result))
			quit(1)
			return
	quit(0)


func _capture_sheet(capture: Dictionary) -> int:
	var size := capture.get("size", Vector2i.ZERO) as Vector2i
	var output := str(capture.get("path", ""))
	if size == Vector2i.ZERO or output.is_empty():
		return ERR_INVALID_PARAMETER
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	if directory_result != OK:
		return directory_result
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_make_sheet(size))
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	viewport.queue_free()
	await process_frame
	if result == OK:
		print("FAN-3890 Thief four-viewport capture saved: %s" % output)
	return result


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	_add_rect(host, Rect2(Vector2.ZERO, Vector2(size)), BACKGROUND_COLOR, -100)
	var heading := Label.new()
	heading.text = "THIEF ULTIMATES — LIVE VICTIM-IMPACT CAPTURE MATRIX"
	heading.position = Vector2(size.x * 0.025, size.y * 0.027)
	heading.add_theme_font_size_override("font_size", maxi(16, roundi(size.y * 0.031)))
	heading.add_theme_color_override("font_color", Color(0.90, 0.82, 0.58))
	heading.z_index = 3904
	host.add_child(heading)
	_add_hud(host, size)
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	for weapon_index in WEAPON_IDS.size():
		for mode_index in MODE_IDS.size():
			_add_panel(host, size, weapon_index, mode_index, registry)
	return host


func _add_hud(host: Node2D, size: Vector2i) -> void:
	var top := Rect2(Vector2(size.x * 0.018, size.y * 0.105), Vector2(size.x * 0.964, size.y * 0.045))
	var bottom := Rect2(Vector2(size.x * 0.018, size.y * 0.918), Vector2(size.x * 0.964, size.y * 0.045))
	_add_rect(host, top, HUD_COLOR, 3900)
	_add_rect(host, bottom, HUD_COLOR, 3900)
	var status := Label.new()
	status.text = "PLAYER  HP 100%   •   ULTIMATE READY   •   HAZARD READOUT ENABLED"
	status.position = top.position + Vector2(size.x * 0.012, size.y * 0.003)
	status.add_theme_font_size_override("font_size", maxi(10, roundi(size.y * 0.017)))
	status.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	status.z_index = 3901
	host.add_child(status)
	var footer := Label.new()
	footer.text = "LIVE SCENE • NORMAL / CROWD / REDUCED-MOTION / PHOTO-SAFE • HUD AND HAZARDS HELD VISIBLE"
	footer.position = bottom.position + Vector2(size.x * 0.012, size.y * 0.003)
	footer.add_theme_font_size_override("font_size", maxi(9, roundi(size.y * 0.015)))
	footer.add_theme_color_override("font_color", Color(0.70, 0.79, 0.90))
	footer.z_index = 3901
	host.add_child(footer)


func _add_panel(host: Node2D, size: Vector2i, weapon_index: int, mode_index: int, registry) -> void:
	var weapon_id := WEAPON_IDS[weapon_index]
	var mode_id := MODE_IDS[mode_index]
	var mode := mode_spec(mode_id)
	var rect := panel_rect(size, weapon_index, mode_index)
	_add_rect(host, rect, mode.get("panel_color", Color.DIM_GRAY) as Color, -20)
	_add_outline(host, rect, GRID_COLOR, 3800)
	var marker_center := mode_marker_probe(size, weapon_index, mode_index)
	var marker_radius := maxi(4.0, float(size.y) * 0.008)
	_add_rect(host, Rect2(Vector2(marker_center) - Vector2.ONE * marker_radius, Vector2.ONE * marker_radius * 2.0), mode.get("marker_color", Color.WHITE) as Color, 3902)
	var label := Label.new()
	label.text = "%s · %s" % [str(mode.get("label", "")), weapon_id.to_upper()]
	label.position = rect.position + Vector2(size.x * 0.018, size.y * 0.018)
	label.add_theme_font_size_override("font_size", maxi(9, roundi(size.y * 0.014)))
	label.add_theme_color_override("font_color", mode.get("marker_color", Color.WHITE) as Color)
	label.z_index = 3903
	host.add_child(label)
	_add_live_timeline(host, rect, weapon_id, mode, registry)
	_add_live_impacts(host, rect, weapon_id, mode)
	_add_player(host, player_probe(size, weapon_index, mode_index), size)
	_add_hazard(host, hazard_probe(size, weapon_index, mode_index), size)


func _add_live_timeline(host: Node2D, rect: Rect2, weapon_id: String, mode: Dictionary, registry) -> void:
	var scene := (TIMELINE_SCENES.get(weapon_id) as PackedScene).instantiate() as Node2D
	scene.position = rect.get_center() + Vector2(0.0, rect.size.y * 0.04)
	scene.scale = Vector2.ONE * minf(rect.size.x / 620.0, rect.size.y / 520.0) * 0.82
	if str(mode.get("id", "")) == "reduced_motion":
		scene.scale *= 0.90
	elif str(mode.get("id", "")) == "photosensitivity_safe":
		scene.modulate = Color(0.82, 0.84, 0.96, 1.0)
	host.add_child(scene)
	scene.call("begin", registry, {}, 0)
	scene.call("step", float(mode.get("timeline_seconds", 1.10)))
	scene.set_process(false)


func _add_live_impacts(host: Node2D, rect: Rect2, weapon_id: String, mode: Dictionary) -> void:
	var impacts: Node2D = ImpactPlayer.new()
	impacts.extra_hit_flash = false
	host.add_child(impacts)
	var markers: Array[Node2D] = []
	var victim_count := int(mode.get("victims", 3))
	for index in victim_count:
		var marker := Node2D.new()
		marker.global_position = victim_position(rect, index, victim_count)
		host.add_child(marker)
		markers.append(marker)
	impacts.play(VICTIM_FRAMES.get(weapon_id) as SpriteFrames, markers, rect.get_center())
	impacts.advance(0.14 if str(mode.get("id", "")) == "crowded" else 0.12)
	impacts.set_paused(true)


func _add_player(host: Node2D, center: Vector2i, size: Vector2i) -> void:
	var radius := maxi(6.0, float(size.y) * 0.012)
	var player := Polygon2D.new()
	player.polygon = PackedVector2Array([
		Vector2(center.x, center.y - radius), Vector2(center.x + radius, center.y),
		Vector2(center.x, center.y + radius), Vector2(center.x - radius, center.y),
	])
	player.color = PLAYER_COLOR
	player.z_index = 4000
	host.add_child(player)


func _add_hazard(host: Node2D, center: Vector2i, size: Vector2i) -> void:
	var radius := maxi(5.0, float(size.y) * 0.010)
	var hazard := Polygon2D.new()
	hazard.polygon = PackedVector2Array([
		Vector2(center.x, center.y - radius), Vector2(center.x + radius, center.y + radius),
		Vector2(center.x - radius, center.y + radius),
	])
	hazard.color = HAZARD_COLOR
	hazard.z_index = 4001
	host.add_child(hazard)


func _add_rect(host: Node2D, rect: Rect2, color: Color, z_index: int) -> void:
	var node := Polygon2D.new()
	node.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])
	node.color = color
	node.z_index = z_index
	host.add_child(node)


func _add_outline(host: Node2D, rect: Rect2, color: Color, z_index: int) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y), rect.position,
	])
	line.width = 1.5
	line.default_color = color
	line.z_index = z_index
	host.add_child(line)


static func capture_for_id(capture_id: String) -> Dictionary:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		if str(capture.get("id", "")) == capture_id:
			return capture.duplicate(true)
	return {}


static func mode_spec(mode_id: String) -> Dictionary:
	for raw_mode in MODE_SPECS:
		var mode := raw_mode as Dictionary
		if str(mode.get("id", "")) == mode_id:
			return mode.duplicate(true)
	return {}


static func panel_rect(size: Vector2i, weapon_index: int, mode_index: int) -> Rect2:
	var column_width := float(size.x) / float(MODE_IDS.size())
	var top := float(size.y) * PANEL_TOP_RATIO
	var bottom := float(size.y) * PANEL_BOTTOM_RATIO
	var row_height := (bottom - top) / float(WEAPON_IDS.size())
	var margin := maxf(4.0, float(size.y) * PANEL_MARGIN_RATIO)
	return Rect2(
		Vector2(float(mode_index) * column_width + margin, top + float(weapon_index) * row_height + margin),
		Vector2(column_width - margin * 2.0, row_height - margin * 2.0)
	)


static func mode_marker_probe(size: Vector2i, weapon_index: int, mode_index: int) -> Vector2i:
	var rect := panel_rect(size, weapon_index, mode_index)
	var offset := maxi(4.0, float(size.y) * 0.008)
	return Vector2i(roundi(rect.position.x + offset), roundi(rect.position.y + offset))


static func player_probe(size: Vector2i, weapon_index: int, mode_index: int) -> Vector2i:
	var rect := panel_rect(size, weapon_index, mode_index)
	return Vector2i(roundi(rect.get_center().x), roundi(rect.position.y + rect.size.y * 0.76))


static func hazard_probe(size: Vector2i, weapon_index: int, mode_index: int) -> Vector2i:
	var rect := panel_rect(size, weapon_index, mode_index)
	return Vector2i(roundi(rect.position.x + rect.size.x * 0.12), roundi(rect.position.y + rect.size.y * 0.77))


static func hud_probe(size: Vector2i) -> Vector2i:
	return Vector2i(roundi(size.x * 0.020), roundi(size.y * 0.120))


static func victim_position(rect: Rect2, index: int, total: int) -> Vector2:
	var columns := mini(8, maxi(1, total))
	var rows := ceili(float(total) / float(columns))
	var column := index % columns
	var row := index / columns
	var x_ratio := 0.20 + 0.60 * (float(column) / float(maxi(columns - 1, 1)))
	var y_ratio := 0.33 + 0.28 * (float(row) / float(maxi(rows - 1, 1)))
	return rect.position + Vector2(rect.size.x * x_ratio, rect.size.y * y_ratio)
