extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/berserk.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/berserk/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const SCENES := {
	"sword": preload("res://scenes/vfx/ultimates/berserk/BerserkSwordScarletWhirlwind.tscn"),
	"axe": preload("res://scenes/vfx/ultimates/berserk/BerserkAxeExecutionLoop.tscn"),
	"hammer": preload("res://scenes/vfx/ultimates/berserk/BerserkHammerFourfoldRift.tscn"),
}
const CAPTURES := [
	{"path": "res://docs/design/references/weapon_ultimates/berserk/berserk_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"path": "res://docs/design/references/weapon_ultimates/berserk/berserk_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"path": "res://docs/design/references/weapon_ultimates/berserk/berserk_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"path": "res://docs/design/references/weapon_ultimates/berserk/berserk_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const MAX_TIMELINE_SECONDS := 10.0


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var profile_root := _load_json(PROFILE_PATH, errors)
	var manifest := _load_json(MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_expect(str(manifest.get("class_id", "")) == "berserk", "manifest must be class-local to Berserk", errors)
	_expect(str((manifest.get("contract", {}) as Dictionary).get("headless_fallback", "")) == "no_op", "manifest must declare no_op headless fallback", errors)
	_expect(not str((manifest.get("contract", {}) as Dictionary).get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var profiles := _profiles_by_weapon(profile_root)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == 3, "manifest must contain exactly three Berserk weapon packages", errors)
	for weapon_id in ["sword", "axe", "hammer"]:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_capture_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Berserk ultimate timelines passed (three distinct scenes, frozen phases, lifecycle, evidence, and crowd budgets).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_approved_assets_no_new_raster_generation", "provenance route must explain why no new raster source was generated", errors)
	_expect(str(provenance.get("pixellab_mcp_config_smoke", "")).begins_with("PASS"), "PixelLab MCP config smoke must be recorded as PASS", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in ["sword", "axe", "hammer"]:
		var source := sources.get(weapon_id, {}) as Dictionary
		_expect(FileAccess.file_exists("res://%s" % str(source.get("runtime_scene", ""))), "%s runtime scene must be recorded and exist" % weapon_id, errors)
		_expect(not str(source.get("source_path", "")).is_empty(), "%s source path must be recorded" % weapon_id, errors)
	for weapon_id in ["axe", "hammer"]:
		var source := sources.get(weapon_id, {}) as Dictionary
		_expect(not str(source.get("pixellab_object_id", "")).is_empty(), "%s must retain accepted PixelLab object provenance" % weapon_id, errors)
		_expect(not str(source.get("pixellab_animation_group_id", "")).is_empty(), "%s must retain accepted PixelLab animation-group provenance" % weapon_id, errors)


func _check_package(weapon_id: String, profile: Dictionary, package: Dictionary, errors: Array[String]) -> void:
	_expect(not profile.is_empty(), "%s frozen profile must exist" % weapon_id, errors)
	_expect(not package.is_empty(), "%s presentation package must exist" % weapon_id, errors)
	if profile.is_empty() or package.is_empty():
		return
	_expect(str(package.get("weapon_id", "")) == weapon_id, "%s package weapon ID must be exact" % weapon_id, errors)
	var timing := package.get("timing_seconds", {}) as Dictionary
	var phases := package.get("phase_ids", {}) as Dictionary
	var previous := -1.0
	for phase_name in REQUIRED_PHASES:
		var value = timing.get(phase_name, -1.0)
		_expect(value is float or value is int, "%s %s timing must be numeric" % [weapon_id, phase_name], errors)
		var seconds := float(value)
		_expect(seconds >= previous and seconds <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and within the ten-second cap" % [weapon_id, phase_name], errors)
		previous = seconds
		var expected_phase := str((profile.get("cast_phases", {}) as Dictionary).get(_cast_phase_name(phase_name), ""))
		_expect(str(phases.get(phase_name, "")) == expected_phase, "%s %s must bind to frozen Cast phase ID" % [weapon_id, phase_name], errors)
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
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))), "%s scene animation length must end on its cancel phase" % weapon_id, errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "berserk/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	_expect(not str(instance.get_meta("silhouette", "")).is_empty(), "%s silhouette declaration missing" % weapon_id, errors)
	_expect(not str(instance.get_meta("motion_path", "")).is_empty(), "%s motion path declaration missing" % weapon_id, errors)
	_expect(not str(instance.get_meta("impact_language", "")).is_empty(), "%s impact language declaration missing" % weapon_id, errors)
	_expect(instance.get_child_count() <= int(instance.get_meta("crowd_cap", 0)), "%s visual-node count must stay within crowd cap" % weapon_id, errors)
	_expect(int(instance.get_meta("max_visual_nodes", 0)) <= int(instance.get_meta("crowd_cap", 0)), "%s declared visual budget must stay within crowd cap" % weapon_id, errors)
	instance.queue_free()


func _check_lifecycle(weapon_id: String, timing: Dictionary, phases: Dictionary, errors: Array[String]) -> void:
	var phase_entries: Array[Dictionary] = []
	for name in REQUIRED_PHASES:
		phase_entries.append({"name": name, "phase_id": str(phases.get(name, ""))})
	var fixture := {
		"timing": timing,
		"phases": phase_entries,
	}
	var timeline = TIMELINE.new(fixture, 0)
	var handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
	timeline.begin(handles)
	timeline.advance(0.05)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s timeline pause must freeze elapsed time" % weapon_id, errors)
	timeline.set_paused(false)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup_timeline = TIMELINE.new(fixture, 0)
		var cleanup_handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
		cleanup_timeline.begin(cleanup_handles)
		cleanup_timeline.finish(reason)
		_expect(cleanup_timeline.active_handle_count() == 0, "%s %s cleanup must release all handles" % [weapon_id, reason], errors)
		for handle in cleanup_handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s cleanup must release each handle exactly once" % [weapon_id, reason], errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "impact_language"]:
		var values := {}
		for weapon_id in ["sword", "axe", "hammer"]:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == 3 and not values.has(""), "all three weapons must have different %s values" % field, errors)


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence is missing: %s" % path, errors)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty(), "contact evidence must decode: %s" % path, errors)
		if image != null:
			_expect(image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence resolution mismatch: %s" % path, errors)


func _profiles_by_weapon(root_data: Dictionary) -> Dictionary:
	var result := {}
	for raw_profile in root_data.get("profiles", []) as Array:
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


func _cast_phase_name(presentation_name: String) -> String:
	return {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}.get(presentation_name, "")


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	for error in errors:
		push_error("Berserk ultimate timeline: %s" % error)
	quit(1)
