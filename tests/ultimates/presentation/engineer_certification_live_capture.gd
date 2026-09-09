extends SceneTree

## Windowed, deterministic evidence renderer for FAN-3939.
##
## Each sheet holds the three canonical Engineer ultimate scenes in four
## presentation modes (normal, crowded, reduced motion, photosensitivity
## safe). The shipped timeline scene and victim-impact flipbooks are real
## runtime resources; only the surrounding HUD, player, and hazard fixtures
## make their readability reviewable in one stable, seeded frame per mode.

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/engineer/certification_capture_manifest.json"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/engineer/manifest.json"
## Captures are rendered from the exact dev candidate the audit failed;
## provenance is recorded without a self-referential final commit hash.
const CAPTURE_BASE_SHA := "d192be10bbe52dd89971cab0acc66eb92ccab37f"
const CAPTURE_BASE_TREE := "e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf"
const RENDERER_VERSION := "godot 4.7.stable.official.5b4e0cb0f"
const CAPTURE_SEED := 3939

const WEAPON_IDS: Array[String] = ["engineer_sentry_wrench", "engineer_repair_drone", "engineer_pressure_mines"]
const MODE_IDS: Array[String] = ["normal", "crowded", "reduced_motion", "photosensitivity_safe"]
const TIMELINE_SCENES := {
	"engineer_sentry_wrench": preload("res://scenes/vfx/ultimates/engineer/EngineerSentryWrenchUltimate.tscn"),
	"engineer_repair_drone": preload("res://scenes/vfx/ultimates/engineer/EngineerRepairDroneUltimate.tscn"),
	"engineer_pressure_mines": preload("res://scenes/vfx/ultimates/engineer/EngineerPressureMinesUltimate.tscn"),
}
const VICTIM_FRAMES := {
	"engineer_sentry_wrench": preload("res://assets/sprites/effects/engineer/sentry_wrench/sentry_wrench_spriteframes.tres"),
	"engineer_repair_drone": preload("res://assets/sprites/effects/engineer/repair_drone/repair_drone_spriteframes.tres"),
	"engineer_pressure_mines": preload("res://assets/sprites/effects/engineer/pressure_mines/pressure_mines_spriteframes.tres"),
}
## Mode -> beat name sampled from each weapon's frozen manifest timing so the
## matrix as a whole covers release, active, and recovery evidence.
const MODE_BEATS := {
	"normal": "active",
	"crowded": "release",
	"reduced_motion": "active",
	"photosensitivity_safe": "recovery",
}
## Frozen active-beat fallbacks identical to the focused timeline test's
## proven sample points, used when the manifest timing is unavailable.
const ACTIVE_BEATS := {
	"engineer_sentry_wrench": 2.2,
	"engineer_repair_drone": 2.3,
	"engineer_pressure_mines": 1.85,
}
const CAPTURES := [
	{"id": "648p", "path": "res://docs/design/reference-assets-lfs/ultimate-certification/engineer/engineer_ultimate_certification_648p.png", "size": Vector2i(1152, 648)},
	{"id": "720p", "path": "res://docs/design/reference-assets-lfs/ultimate-certification/engineer/engineer_ultimate_certification_720p.png", "size": Vector2i(1280, 720)},
	{"id": "1080p", "path": "res://docs/design/reference-assets-lfs/ultimate-certification/engineer/engineer_ultimate_certification_1080p.png", "size": Vector2i(1920, 1080)},
	{"id": "2k", "path": "res://docs/design/reference-assets-lfs/ultimate-certification/engineer/engineer_ultimate_certification_2k.png", "size": Vector2i(2560, 1440)},
]
const MODE_SPECS := [
	{
		"id": "normal", "label": "NORMAL", "victims": 3,
		"marker_color": Color(0.18, 0.76, 1.0), "panel_color": Color(0.055, 0.090, 0.135, 1.0),
	},
	{
		"id": "crowded", "label": "CROWDED", "victims": 39,
		"marker_color": Color(1.0, 0.58, 0.18), "panel_color": Color(0.125, 0.078, 0.045, 1.0),
	},
	{
		"id": "reduced_motion", "label": "REDUCED MOTION", "victims": 3,
		"marker_color": Color(0.36, 0.92, 0.48), "panel_color": Color(0.045, 0.105, 0.080, 1.0),
	},
	{
		"id": "photosensitivity_safe", "label": "PHOTOSENSITIVITY SAFE", "victims": 3,
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

var _beat_by_weapon := {}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3939 Engineer certification capture skipped (headless); run windowed for PNG evidence.")
		quit(0)
		return
	var seed_state := RandomNumberGenerator.new()
	seed_state.seed = CAPTURE_SEED
	_load_beats()
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var result := await _capture_sheet(capture, seed_state)
		if result != OK:
			push_error("FAN-3939 Engineer certification capture failed: %s" % error_string(result))
			quit(1)
			return
	quit(0)


## Beat times come from the frozen class manifest timing so each sheet's
## panels sample the recorded release/active/recovery beats, not ad-hoc skips.
func _load_beats() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CLASS_MANIFEST_PATH))
	if parsed is Dictionary:
		for raw_weapon in (parsed as Dictionary).get("weapons", []) as Array:
			if raw_weapon is Dictionary:
				var weapon := raw_weapon as Dictionary
				var timing := weapon.get("timing_seconds", {}) as Dictionary
				_beat_by_weapon[str(weapon.get("weapon_id", ""))] = timing
	for weapon_id in WEAPON_IDS:
		if not _beat_by_weapon.has(weapon_id):
			_beat_by_weapon[weapon_id] = {"active": ACTIVE_BEATS[weapon_id]}


func _beat_time(weapon_id: String, beat_name: String) -> float:
	var timing := _beat_by_weapon.get(weapon_id, {}) as Dictionary
	var sample := float(timing.get(beat_name, -1.0))
	if sample < 0.0:
		sample = float(timing.get("active", ACTIVE_BEATS.get(weapon_id, 1.5)))
	return sample


func _capture_sheet(capture: Dictionary, seed_state: RandomNumberGenerator) -> int:
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
	viewport.add_child(_make_sheet(size, seed_state))
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	viewport.queue_free()
	await process_frame
	if result == OK:
		print("FAN-3939 Engineer certification capture saved: %s" % output)
	return result


func _make_sheet(size: Vector2i, seed_state: RandomNumberGenerator) -> Node2D:
	var host := Node2D.new()
	_add_rect(host, Rect2(Vector2.ZERO, Vector2(size)), BACKGROUND_COLOR, -100)
	var heading := Label.new()
	heading.text = "ENGINEER ULTIMATES — LIVE FOUR-MODE CERTIFICATION MATRIX"
	heading.position = Vector2(size.x * 0.025, size.y * 0.027)
	heading.add_theme_font_size_override("font_size", maxi(16, roundi(size.y * 0.031)))
	heading.add_theme_color_override("font_color", Color(0.55, 0.95, 0.85))
	heading.z_index = 3904
	host.add_child(heading)
	_add_hud(host, size)
	for weapon_index in WEAPON_IDS.size():
		for mode_index in MODE_IDS.size():
			_add_panel(host, size, weapon_index, mode_index, seed_state)
	return host


func _add_hud(host: Node2D, size: Vector2i) -> void:
	var top := Rect2(Vector2(size.x * 0.018, size.y * 0.105), Vector2(size.x * 0.964, size.y * 0.045))
	var bottom := Rect2(Vector2(size.x * 0.018, size.y * 0.918), Vector2(size.x * 0.964, size.y * 0.045))
	_add_rect(host, top, HUD_COLOR, 3900)
	_add_rect(host, bottom, HUD_COLOR, 3900)
	var status := Label.new()
	status.text = "ENGINEER  HP 100%   •   ULTIMATE READY   •   SENTRY / DRONE / MINES HAZARD READOUT"
	status.position = top.position + Vector2(size.x * 0.012, size.y * 0.003)
	status.add_theme_font_size_override("font_size", maxi(10, roundi(size.y * 0.017)))
	status.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	status.z_index = 3901
	host.add_child(status)
	var footer := Label.new()
	footer.text = "LIVE SCENE • NORMAL / CROWDED / REDUCED-MOTION / PHOTO-SAFE • HUD AND HAZARDS HELD VISIBLE"
	footer.position = bottom.position + Vector2(size.x * 0.012, size.y * 0.003)
	footer.add_theme_font_size_override("font_size", maxi(9, roundi(size.y * 0.015)))
	footer.add_theme_color_override("font_color", Color(0.70, 0.79, 0.90))
	footer.z_index = 3901
	host.add_child(footer)


func _add_panel(host: Node2D, size: Vector2i, weapon_index: int, mode_index: int, seed_state: RandomNumberGenerator) -> void:
	var weapon_id := WEAPON_IDS[weapon_index]
	var mode_id := MODE_IDS[mode_index]
	var mode := mode_spec(mode_id)
	var beat_name := str(MODE_BEATS.get(mode_id, "active"))
	var rect := panel_rect(size, weapon_index, mode_index)
	_add_rect(host, rect, mode.get("panel_color", Color.DIM_GRAY) as Color, -20)
	_add_outline(host, rect, GRID_COLOR, 3800)
	var marker_center := mode_marker_probe(size, weapon_index, mode_index)
	var marker_radius := maxi(4.0, float(size.y) * 0.008)
	_add_rect(host, Rect2(Vector2(marker_center) - Vector2.ONE * marker_radius, Vector2.ONE * marker_radius * 2.0), mode.get("marker_color", Color.WHITE) as Color, 3902)
	var label := Label.new()
	label.text = "%s · %s · %s BEAT" % [str(mode.get("label", "")), weapon_id.to_upper(), beat_name.to_upper()]
	label.position = rect.position + Vector2(size.x * 0.018, size.y * 0.018)
	label.add_theme_font_size_override("font_size", maxi(9, roundi(size.y * 0.014)))
	label.add_theme_color_override("font_color", mode.get("marker_color", Color.WHITE) as Color)
	label.z_index = 3903
	host.add_child(label)
	_add_live_timeline(host, rect, weapon_id, mode_id, beat_name)
	_add_live_impacts(host, rect, weapon_id, mode_id, seed_state)
	_add_player(host, player_probe(size, weapon_index, mode_index), size)
	_add_hazard(host, hazard_probe(size, weapon_index, mode_index), size)


## The shipped scene is instanced for real and driven through its frozen
## `ultimate` AnimationPlayer timeline: play, deterministic seek to the mode's
## recorded beat, then freeze so the captured frame cannot drift with pacing.
func _add_live_timeline(host: Node2D, rect: Rect2, weapon_id: String, mode_id: String, beat_name: String) -> void:
	var scene := (TIMELINE_SCENES.get(weapon_id) as PackedScene).instantiate() as Node2D
	scene.position = rect.get_center() + Vector2(0.0, rect.size.y * 0.04)
	scene.scale = Vector2.ONE * minf(rect.size.x / 620.0, rect.size.y / 520.0) * 0.82
	if mode_id == "reduced_motion":
		scene.scale *= 0.90
		root.set_meta("screen_shake", false)
	elif mode_id == "photosensitivity_safe":
		scene.modulate = Color(0.82, 0.84, 0.96, 1.0)
	host.add_child(scene)
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null and timeline.has_animation(&"ultimate"):
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(_beat_time(weapon_id, beat_name), true)
	scene.set_process(false)
	for child in scene.get_children():
		child.set_process(false)
	if mode_id != "reduced_motion":
		root.set_meta("screen_shake", true)


func _add_live_impacts(host: Node2D, rect: Rect2, weapon_id: String, mode_id: String, seed_state: RandomNumberGenerator) -> void:
	var impacts: Node2D = ImpactPlayer.new()
	impacts.extra_hit_flash = mode_id != "photosensitivity_safe"
	host.add_child(impacts)
	var markers: Array[Node2D] = []
	var mode := mode_spec(mode_id)
	var victim_count := int(mode.get("victims", 3))
	for index in victim_count:
		var marker := Node2D.new()
		var jitter := Vector2(seed_state.randf_range(-0.01, 0.01), seed_state.randf_range(-0.01, 0.01))
		marker.global_position = victim_position(rect, index, victim_count) + rect.size * jitter
		host.add_child(marker)
		markers.append(marker)
	impacts.play(VICTIM_FRAMES.get(weapon_id) as SpriteFrames, markers, rect.get_center())
	impacts.advance(0.14 if mode_id == "crowded" else 0.12)
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
