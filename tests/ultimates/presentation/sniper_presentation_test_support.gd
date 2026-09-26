class_name SniperPresentationTestSupport
extends RefCounted

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const ROOT := "res://scenes/vfx/ultimates/sniper"
const CLASS_PROFILE := "res://data/ultimates/schema/v1/classes/sniper.json"


class HandleProbe extends RefCounted:
	var attached := 1
	var released := 0

	func release() -> void:
		released += 1

	func orphan_handle_count() -> int:
		return attached - released


static func run_weapon(weapon_id: String) -> Array[String]:
	var errors: Array[String] = []
	var definition := _definition_for(weapon_id)
	_expect(not definition.is_empty(), "%s definition must parse" % weapon_id, errors)
	if definition.is_empty():
		return errors

	var manifest = definition.get("manifest", {})
	_expect(manifest is Dictionary, "%s manifest must be an object" % weapon_id, errors)
	if not manifest is Dictionary:
		return errors
	var typed_manifest := manifest as Dictionary
	var profile := _profile_for(weapon_id)
	_expect(not profile.is_empty(), "%s frozen profile must exist" % weapon_id, errors)
	_expect(Schema.validate_manifest(typed_manifest, profile).is_empty(), "%s manifest must satisfy presentation schema" % weapon_id, errors)

	var scene_path := str(definition.get("scene_path", ""))
	_expect(ResourceLoader.exists(scene_path), "%s scene must exist" % weapon_id, errors)
	if not ResourceLoader.exists(scene_path):
		return errors
	var scene := (load(scene_path) as PackedScene).instantiate()
	_expect(scene != null, "%s scene must instantiate" % weapon_id, errors)
	if scene == null:
		return errors
	for required_node in definition.get("visual_contract", {}).get("required_nodes", []) as Array:
		_expect(scene.get_node_or_null(str(required_node)) != null, "%s must include %s" % [weapon_id, required_node], errors)
	_expect(_count_type(scene, "Line2D") > 0, "%s must use a directional line path" % weapon_id, errors)
	_expect(_count_type(scene, "Sprite2D") > 0, "%s must use an authored PixelLab sprite" % weapon_id, errors)
	_test_visual_contract(weapon_id, definition, errors)
	_test_lifecycle(scene, weapon_id, errors)
	scene.free()
	return errors


static func _test_visual_contract(weapon_id: String, definition: Dictionary, errors: Array[String]) -> void:
	var visual = definition.get("visual_contract", {})
	_expect(visual is Dictionary, "%s visual contract must be an object" % weapon_id, errors)
	if not visual is Dictionary:
		return
	var contract := visual as Dictionary
	for property in ["silhouette", "motion_path", "timing_rhythm", "impact_language"]:
		var value := str(contract.get(property, ""))
		_expect(not value.is_empty(), "%s must declare %s" % [weapon_id, property], errors)
		_expect(not value.contains("ring-only"), "%s cannot use a generic ring-only language" % weapon_id, errors)
	var readability = contract.get("readability", {})
	_expect(readability is Dictionary, "%s readability contract must exist" % weapon_id, errors)
	if readability is Dictionary:
		var heights = (readability as Dictionary).get("viewport_heights", [])
		for height in [648, 720, 1080, 1440]:
			var covered := false
			for raw_height in heights as Array:
				covered = covered or int(raw_height) == height
			_expect(covered, "%s must cover %dp" % [weapon_id, height], errors)
		_expect(int((readability as Dictionary).get("minimum_visible_extent_px", 0)) >= 80, "%s must preserve an 80px readable extent" % weapon_id, errors)
	var budget = contract.get("scene_node_budget", {})
	_expect(budget is Dictionary, "%s crowd budget must exist" % weapon_id, errors)
	if budget is Dictionary:
		_expect(int((budget as Dictionary).get("line_segments", 0)) <= 24, "%s must stay under the 24-line crowd cap" % weapon_id, errors)
		_expect(int((budget as Dictionary).get("simultaneous_emitters", 0)) <= 15, "%s must stay under the 15-emitter crowd cap" % weapon_id, errors)
	if weapon_id == "sniper_spotter_scope":
		_expect(int(contract.get("pulse_count", 0)) == 9, "spotter scope must retain its nine-barrage rhythm", errors)
		_expect(not str(contract.get("motion_path", "")).contains("aimed zone"),
			"spotter scope must not present a selected-target kill zone", errors)
	if weapon_id == "sniper_shatter_rounds":
		_expect(int(contract.get("wave_count", 0)) == 5, "shatter rounds must retain five arena waves", errors)
		_expect(not str(contract.get("motion_path", "")).contains("ricochet"),
			"shatter rounds must not present a ricochet route", errors)


static func _test_lifecycle(scene: Node, weapon_id: String, errors: Array[String]) -> void:
	for reason in ["cancel", "death", "node_end"]:
		var probes := _probes()
		var result: Dictionary = scene.begin(probes, 0)
		_expect(str(result.get("state", "")) == "active", "%s must begin a live fixture timeline" % weapon_id, errors)
		scene.advance(0.0)
		_expect(scene.visible_phase_name() == "windup", "%s must enter windup first" % weapon_id, errors)
		var elapsed_before_pause: float = scene.get("_timeline").elapsed_seconds()
		scene.set_paused(true)
		scene.advance(1.0)
		_expect(is_equal_approx(scene.get("_timeline").elapsed_seconds(), elapsed_before_pause), "%s pause must freeze the timeline" % weapon_id, errors)
		scene.set_paused(false)
		var emitted: Array[Dictionary] = scene.advance(10.0)
		var emitted_names: Array[String] = []
		for phase in emitted:
			emitted_names.append(str(phase.get("name", "")))
		for expected_phase in ["release", "active", "recovery", "cancel"]:
			_expect(emitted_names.has(expected_phase), "%s must emit %s after resume" % [weapon_id, expected_phase], errors)
		_expect(scene.visible_phase_name() == "cancel", "%s must expose the final cancel phase" % weapon_id, errors)
		var finish_result: Dictionary = scene.finish(reason)
		_expect(str(finish_result.get("reason", "")) == reason, "%s must preserve %s cleanup reason" % [weapon_id, reason], errors)
		for channel in probes:
			_expect((probes[channel] as HandleProbe).orphan_handle_count() == 0, "%s must release %s on %s" % [weapon_id, channel, reason], errors)
		_expect(scene.visible_phase_name().is_empty(), "%s must hide phase nodes after %s" % [weapon_id, reason], errors)


static func _definition_for(weapon_id: String) -> Dictionary:
	var path := "%s/%s.timeline.json" % [ROOT, weapon_id]
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func run_visual_distinction() -> Array[String]:
	var errors: Array[String] = []
	var weapon_ids := ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"]
	for field in ["silhouette", "motion_path", "timing_rhythm", "impact_language"]:
		var seen := {}
		for weapon_id in weapon_ids:
			var visual = _definition_for(weapon_id).get("visual_contract", {})
			if visual is Dictionary:
				seen[str((visual as Dictionary).get(field, ""))] = true
		_expect(seen.size() == weapon_ids.size(), "sniper timelines must have distinct %s values" % field, errors)
	for weapon_id in weapon_ids:
		var timing = _definition_for(weapon_id).get("manifest", {}).get("timing", {})
		_expect(float(timing.get("cancel", 11.0)) <= 10.0, "%s must stay within the 10s schema limit" % weapon_id, errors)
	return errors


static func _profile_for(weapon_id: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CLASS_PROFILE))
	if not parsed is Dictionary:
		return {}
	var class_id := str((parsed as Dictionary).get("class_id", ""))
	for raw_profile in (parsed as Dictionary).get("profiles", []) as Array:
		if raw_profile is Dictionary and str((raw_profile as Dictionary).get("weapon_id", "")) == weapon_id:
			var profile := (raw_profile as Dictionary).duplicate(true)
			profile["class_id"] = class_id
			return profile
	return {}


static func _probes() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


static func _count_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_type(child, type_name)
	return count


static func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
