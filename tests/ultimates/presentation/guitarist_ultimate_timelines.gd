extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/guitarist.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/guitarist/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const WEAPON_IDS := ["electric_guitar", "bass_guitar", "sound_amp"]
const SCENES := {
	"electric_guitar": preload("res://scenes/vfx/ultimates/guitarist/GuitaristElectricGuitarLastChord.tscn"),
	"bass_guitar": preload("res://scenes/vfx/ultimates/guitarist/GuitaristBassGuitarHellSubwoofer.tscn"),
	"sound_amp": preload("res://scenes/vfx/ultimates/guitarist/GuitaristSoundAmpWallOfSound.tscn"),
}
const PACKS := [
	{"weapon_id": "electric_guitar", "scene": SCENES["electric_guitar"], "time": 1.72, "position": Vector2(0.18, 0.55), "title": "ELECTRIC GUITAR — LAST CHORD", "color": Color(0.36, 0.86, 1.0), "required_nodes": ["RiffStrips/RiffOne", "RiffStrips/RiffFive", "FinalChord", "IntersectionStuns"]},
	{"weapon_id": "bass_guitar", "scene": SCENES["bass_guitar"], "time": 2.85, "position": Vector2(0.50, 0.55), "title": "BASS GUITAR — HELL SUBWOOFER", "color": Color(0.84, 0.44, 1.0), "required_nodes": ["PullRing", "WeightRing", "LaunchRing", "SubwooferShock"]},
	{"weapon_id": "sound_amp", "scene": SCENES["sound_amp"], "time": 3.64, "position": Vector2(0.82, 0.55), "title": "SOUND AMP — WALL OF SOUND", "color": Color(1.0, 0.76, 0.34), "required_nodes": ["AmpStage/NorthAmp", "AmpStage/SouthAmp", "CableSquare", "FeedbackExplosion"]},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/guitarist/guitarist_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/guitarist/guitarist_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/guitarist/guitarist_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2K", "path": "res://docs/design/references/weapon_ultimates/guitarist/guitarist_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const PHASE_BINDINGS := {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}
const SHEET_TITLE := "GUITARIST WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.245
const PANEL_LABEL_FONT_RATIO := 0.021


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var profiles := _profiles_by_weapon(_load_json(PROFILE_PATH, errors))
	var manifest := _load_json(MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_expect(str(manifest.get("class_id", "")) == "guitarist", "manifest must be class-local to Guitarist", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no-op headless fallback", errors)
	_expect(float(contract.get("max_timeline_seconds", 0.0)) == 10.0, "manifest must retain the ten-second cap", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == WEAPON_IDS.size(), "manifest must contain exactly three Guitarist weapon packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_capture_text(errors)
	_check_contact_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Guitarist ultimate timelines passed (three distinct timelines, frozen phases, cleanup, measured typography, and evidence).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_approved_assets_no_new_raster_generation", "provenance must explain the no-new-raster route", errors)
	var created = provenance.get("new_pixellab_assets", [])
	_expect(created is Array and (created as Array).is_empty(), "no PixelLab asset may be declared when no raster was generated", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(weapon_id, {}) as Dictionary
		for field in ["source_path", "runtime_path", "runtime_scene"]:
			var path := str(source.get(field, ""))
			_expect(not path.is_empty() and FileAccess.file_exists("res://%s" % path), "%s %s must exist" % [weapon_id, field], errors)


func _check_package(weapon_id: String, profile: Dictionary, package: Dictionary, errors: Array[String]) -> void:
	_expect(not profile.is_empty(), "%s frozen profile must exist" % weapon_id, errors)
	_expect(not package.is_empty(), "%s package must exist" % weapon_id, errors)
	if profile.is_empty() or package.is_empty():
		return
	_expect(str(package.get("weapon_id", "")) == weapon_id, "%s package must retain its exact weapon ID" % weapon_id, errors)
	var timing := package.get("timing_seconds", {}) as Dictionary
	var phases := package.get("phase_ids", {}) as Dictionary
	var previous := -1.0
	for phase_name in REQUIRED_PHASES:
		var timestamp := float(timing.get(phase_name, -1.0))
		_expect(timestamp >= previous and timestamp <= 10.0, "%s %s timing must be monotonic and capped" % [weapon_id, phase_name], errors)
		previous = timestamp
		var frozen_phase := str((profile.get("cast_phases", {}) as Dictionary).get(str(PHASE_BINDINGS[phase_name]), ""))
		_expect(str(phases.get(phase_name, "")) == frozen_phase, "%s %s must bind the frozen cast phase" % [weapon_id, phase_name], errors)
	_check_scene(weapon_id, package, errors)
	_check_lifecycle(weapon_id, timing, phases, errors)


func _check_scene(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	var scene := SCENES.get(weapon_id) as PackedScene
	_expect(scene != null, "%s scene must load" % weapon_id, errors)
	if scene == null:
		return
	var instance := scene.instantiate() as Node2D
	root.add_child(instance)
	var timeline := instance.get_node_or_null("Timeline") as AnimationPlayer
	_expect(timeline != null and timeline.has_animation(&"ultimate"), "%s must expose an ultimate animation" % weapon_id, errors)
	if timeline != null and timeline.has_animation(&"ultimate"):
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))), "%s animation must end at cancel" % weapon_id, errors)
		var sample := _pack_for(weapon_id)
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(float(sample.get("time", 0.0)), true)
		for node_path in sample.get("required_nodes", []) as Array:
			var item := instance.get_node_or_null(str(node_path)) as CanvasItem
			_expect(item != null and item.visible and item.modulate.a * item.self_modulate.a > 0.01, "%s required visual node must be visible: %s" % [weapon_id, node_path], errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "guitarist/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	for field in ["silhouette", "motion_path", "impact_language"]:
		_expect(str(instance.get_meta(field, "")) == str(package.get(field, "")), "%s scene %s must match manifest" % [weapon_id, field], errors)
	var performance := package.get("performance", {}) as Dictionary
	_expect(int(instance.get_meta("max_visual_nodes", 0)) == int(performance.get("max_visual_nodes", -1)), "%s visual-node budget must match manifest" % weapon_id, errors)
	_expect(int(instance.get_meta("crowd_cap", 0)) == int(performance.get("crowd_cap", -1)), "%s crowd cap must match manifest" % weapon_id, errors)
	_expect(_visual_node_count(instance) <= int(instance.get_meta("max_visual_nodes", 0)), "%s scene must stay within its visual-node budget" % weapon_id, errors)
	instance.queue_free()


func _check_lifecycle(weapon_id: String, timing: Dictionary, phase_ids: Dictionary, errors: Array[String]) -> void:
	var phases: Array[Dictionary] = []
	for phase_name in REQUIRED_PHASES:
		phases.append({"name": phase_name, "phase_id": str(phase_ids.get(phase_name, ""))})
	var fixture := {"timing": timing, "phases": phases}
	var timeline = TIMELINE.new(fixture, 0)
	timeline.begin(_handles())
	timeline.advance(0.3)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s pause must freeze the presentation timeline" % weapon_id, errors)
	timeline.set_paused(false)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup = TIMELINE.new(fixture, 0)
		var handles := _handles()
		cleanup.begin(handles)
		cleanup.finish(reason)
		_expect(cleanup.active_handle_count() == 0, "%s %s cleanup must release all handles" % [weapon_id, reason], errors)
		for handle in handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release each handle once" % [weapon_id, reason], errors)
	var headless = TIMELINE.new(fixture, 1)
	var snapshot := headless.begin(_handles()) as Dictionary
	_expect(str(snapshot.get("state", "")) == TIMELINE.HEADLESS_STATE, "%s headless timeline must no-op" % weapon_id, errors)
	_expect(int(snapshot.get("active_handle_count", -1)) == 0, "%s headless timeline must attach no handles" % weapon_id, errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "impact_language", "timing_seconds"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == WEAPON_IDS.size() and not values.has(""), "all Guitarist weapons must have unique %s" % field, errors)


func _check_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		_expect(sheet_zone.encloses(sheet_title_rect(size)), "%s sheet title must stay inside the measured sheet zone" % str(capture.get("name", "")), errors)
		_expect(sheet_title_font_size(size) >= 18 and panel_label_font_size(size) >= 12, "%s typography must remain readable" % str(capture.get("name", "")), errors)
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			_expect(panel_rect(size, pack).grow(-4.0).encloses(panel_label_rect(size, pack)), "%s label must stay inside its panel" % str(pack.get("weapon_id", "")), errors)


func _check_contact_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence missing: %s" % path, errors)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty(), "contact evidence must decode: %s" % path, errors)
		if image != null:
			_expect(image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence resolution mismatch: %s" % path, errors)


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(18, int(size.y * SHEET_TITLE_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size))
	return Rect2(Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO), text_size)


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack.get("position", Vector2.ZERO) as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(panel_center(size, pack) - half_size, half_size * 2.0)


static func panel_label_font_size(size: Vector2i) -> int:
	return maxi(10, int(size.y * PANEL_LABEL_FONT_RATIO))


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(str(pack.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, panel_label_font_size(size))
	var panel := panel_rect(size, pack)
	return Rect2(Vector2(panel.position.x + 8.0, panel_center(size, pack).y + float(size.y) * PANEL_LABEL_Y_RATIO), text_size)


func _pack_for(weapon_id: String) -> Dictionary:
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		if str(pack.get("weapon_id", "")) == weapon_id:
			return pack
	return {}


func _visual_node_count(root_node: Node) -> int:
	var count := 0
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
			if child is CanvasItem:
				count += 1
	return count


func _profiles_by_weapon(data: Dictionary) -> Dictionary:
	var result := {}
	for raw_profile in data.get("profiles", []) as Array:
		if raw_profile is Dictionary:
			var profile := raw_profile as Dictionary
			result[str(profile.get("weapon_id", ""))] = profile
	return result


func _packages_by_weapon(manifest: Dictionary) -> Dictionary:
	var result := {}
	for raw_package in manifest.get("weapons", []) as Array:
		if raw_package is Dictionary:
			var package := raw_package as Dictionary
			result[str(package.get("weapon_id", ""))] = package
	return result


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _handles() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	for error in errors:
		push_error("Guitarist ultimate timeline: %s" % error)
	quit(1)
