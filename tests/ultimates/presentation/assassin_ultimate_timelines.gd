extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/assassin.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/assassin/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const WEAPON_IDS := ["chakrams", "shadow_daggers", "venom_wire"]
const SCENES := {
	"chakrams": preload("res://scenes/vfx/ultimates/assassin/AssassinChakramsEightMoons.tscn"),
	"shadow_daggers": preload("res://scenes/vfx/ultimates/assassin/AssassinShadowDaggersMomentBeforeDeath.tscn"),
	"venom_wire": preload("res://scenes/vfx/ultimates/assassin/AssassinVenomWireBlackWeb.tscn"),
}
const REQUIRED_NODES := {
	"chakrams": ["Orbit/MoonOne", "Orbit/MoonEight", "ReturnCrescents"],
	"shadow_daggers": ["FreezeMarks", "Afterimages/BackstabOne", "FinalReveal"],
	"venom_wire": ["Anchors/NeedleOne", "Anchors/NeedleSix", "HexWeb", "SnapCollapse"],
}
const CAPTURES := [
	{"path": "res://docs/design/references/weapon_ultimates/assassin/assassin_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"path": "res://docs/design/references/weapon_ultimates/assassin/assassin_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"path": "res://docs/design/references/weapon_ultimates/assassin/assassin_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"path": "res://docs/design/references/weapon_ultimates/assassin/assassin_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const PHASE_BINDINGS := {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}
const MAX_TIMELINE_SECONDS := 10.0


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
	_expect(str(manifest.get("class_id", "")) == "assassin", "manifest must be class-local to Assassin", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no-op headless fallback", errors)
	_expect(float(contract.get("max_timeline_seconds", 0.0)) == MAX_TIMELINE_SECONDS, "manifest must retain the ten-second cap", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == WEAPON_IDS.size(), "manifest must contain exactly three Assassin weapon packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(str(weapon_id), profiles.get(str(weapon_id), {}) as Dictionary, packages.get(str(weapon_id), {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_contact_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Assassin ultimate timelines passed (frozen phases, distinct scenes, lifecycle, provenance, budgets, and evidence).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_approved_assets_no_new_raster_generation", "provenance must explain the no-new-raster route", errors)
	var created = provenance.get("new_pixellab_assets", [])
	_expect(created is Array and (created as Array).is_empty(), "no PixelLab asset may be declared when no raster was generated", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(str(weapon_id), {}) as Dictionary
		var source_path := str(source.get("source_path", ""))
		var runtime_scene := str(source.get("runtime_scene", ""))
		_expect(not source_path.is_empty() and FileAccess.file_exists("res://%s" % source_path), "%s approved source must exist" % weapon_id, errors)
		_expect(not runtime_scene.is_empty() and FileAccess.file_exists("res://%s" % runtime_scene), "%s runtime scene must exist" % weapon_id, errors)


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
		var seconds := float(timing.get(phase_name, -1.0))
		_expect(seconds >= previous and seconds <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and under the cap" % [weapon_id, phase_name], errors)
		previous = seconds
		var expected := str((profile.get("cast_phases", {}) as Dictionary).get(str(PHASE_BINDINGS[phase_name]), ""))
		_expect(str(phases.get(phase_name, "")) == expected, "%s %s must bind to its frozen Cast phase ID" % [weapon_id, phase_name], errors)
	_check_scene(weapon_id, package, errors)
	_check_lifecycle(weapon_id, timing, phases, errors)


func _check_scene(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	var scene := SCENES.get(weapon_id) as PackedScene
	_expect(scene != null, "%s scene must load" % weapon_id, errors)
	if scene == null:
		return
	var instance := scene.instantiate() as Node2D
	root.add_child(instance)
	var animation := instance.get_node_or_null("Timeline") as AnimationPlayer
	_expect(animation != null and animation.has_animation(&"ultimate"), "%s must expose an ultimate animation" % weapon_id, errors)
	if animation != null and animation.has_animation(&"ultimate"):
		var cancel_time := float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))
		_expect(is_equal_approx(animation.get_animation(&"ultimate").length, cancel_time), "%s animation must end at the cancel phase" % weapon_id, errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "assassin/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	for field in ["silhouette", "motion_path", "impact_language"]:
		_expect(str(instance.get_meta(field, "")) == str(package.get(field, "")), "%s scene %s must match provenance" % [weapon_id, field], errors)
	var performance := package.get("performance", {}) as Dictionary
	_expect(int(instance.get_meta("max_visual_nodes", 0)) == int(performance.get("max_visual_nodes", -1)), "%s scene node budget must match manifest" % weapon_id, errors)
	_expect(int(instance.get_meta("crowd_cap", 0)) == int(performance.get("crowd_cap", -1)), "%s scene crowd cap must match manifest" % weapon_id, errors)
	_expect(_visual_node_count(instance) <= int(instance.get_meta("max_visual_nodes", 0)), "%s scene must stay within its visual-node budget" % weapon_id, errors)
	for node_path in REQUIRED_NODES.get(weapon_id, []) as Array:
		_expect(instance.get_node_or_null(str(node_path)) != null, "%s required silhouette node missing: %s" % [weapon_id, node_path], errors)
	instance.queue_free()


func _check_lifecycle(weapon_id: String, timing: Dictionary, phase_ids: Dictionary, errors: Array[String]) -> void:
	var phases: Array[Dictionary] = []
	for phase_name in REQUIRED_PHASES:
		phases.append({"name": phase_name, "phase_id": str(phase_ids.get(phase_name, ""))})
	var fixture := {"timing": timing, "phases": phases}
	var timeline = TIMELINE.new(fixture, 0)
	var handles := _handles()
	timeline.begin(handles)
	timeline.advance(0.3)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s pause must freeze the presentation timeline" % weapon_id, errors)
	timeline.set_paused(false)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup = TIMELINE.new(fixture, 0)
		var cleanup_handles := _handles()
		cleanup.begin(cleanup_handles)
		cleanup.finish(reason)
		_expect(cleanup.active_handle_count() == 0, "%s %s cleanup must release all handles" % [weapon_id, reason], errors)
		for handle in cleanup_handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release each handle once" % [weapon_id, reason], errors)
	var headless = TIMELINE.new(fixture, 1)
	var headless_snapshot := headless.begin(_handles()) as Dictionary
	_expect(str(headless_snapshot.get("state", "")) == TIMELINE.HEADLESS_STATE, "%s headless timeline must no-op" % weapon_id, errors)
	_expect(int(headless_snapshot.get("active_handle_count", -1)) == 0, "%s headless timeline must attach no handles" % weapon_id, errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "impact_language", "timing_seconds"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(str(weapon_id), {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == WEAPON_IDS.size() and not values.has(""), "all Assassin weapons must have unique %s" % field, errors)


func _check_contact_evidence(errors: Array[String]) -> void:
	for capture in CAPTURES:
		var path := str((capture as Dictionary).get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence missing: %s" % path, errors)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty(), "contact evidence must decode: %s" % path, errors)
		if image != null:
			_expect(image.get_size() == (capture as Dictionary).get("size", Vector2i.ZERO), "contact evidence resolution mismatch: %s" % path, errors)


func _handles() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


func _visual_node_count(root_node: Node) -> int:
	var count := 0
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
			if current is CanvasItem:
				count += 1
	return count - 1


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


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	for error in errors:
		push_error("Assassin ultimate timeline: %s" % error)
	quit(1)
