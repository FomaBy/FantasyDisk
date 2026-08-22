extends SceneTree

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")

const CLASS_ID := "biologist"
const WEAPONS := ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"]
const ROOT := "res://scenes/vfx/ultimates/biologist"

var _errors: Array[String] = []


func _initialize() -> void:
	var direction_manifest := DirectionContract.load_manifest(CLASS_ID)
	_check(DirectionContract.violations(CLASS_ID, direction_manifest).is_empty(),
		"Biologist must satisfy every visual-direction gate: %s" % [str(DirectionContract.violations(CLASS_ID, direction_manifest))])
	for gate in DirectionContract.GATES:
		_check(not (DirectionContract.ADOPTION_GAPS.get(gate, {}) as Dictionary).has(CLASS_ID),
			"Biologist must not remain in the %s visual-direction allowlist" % gate)
	var timings := {}
	for weapon_id in WEAPONS:
		var definition := _definition(weapon_id)
		var manifest := definition.get("manifest", {}) as Dictionary
		_check(not manifest.is_empty(), "%s manifest must parse" % weapon_id)
		_check(not Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has("%s/%s" % [CLASS_ID, weapon_id]),
			"%s must leave the presentation migration allowlist" % weapon_id)
		_check(Schema.v2_envelope_errors(manifest.get("timing", {}), weapon_id).is_empty(),
			"%s must fit the v2 timing envelope" % weapon_id)
		var presence := manifest.get("presence", {}) as Dictionary
		_check(presence.get("fullscreen_footprint") == true and presence.get("camera_shake") == true,
			"%s must declare its arena footprint and camera shake" % weapon_id)
		_check(float(presence.get("hitstop_ms", 0.0)) >= 80.0 and float(presence.get("hitstop_ms", 0.0)) <= 150.0,
			"%s must declare first-impact hitstop in the v2 range" % weapon_id)
		var identity := manifest.get("identity", {}) as Dictionary
		_check(not str(identity.get("cast_pose_id", "")).is_empty()
			and FileAccess.file_exists(str(identity.get("cast_pose_asset", "")))
			and FileAccess.file_exists(str(identity.get("weapon_silhouette_asset", "")))
			and str(identity.get("cast_pose_asset", "")) != str(identity.get("weapon_silhouette_asset", ""))
			and str(identity.get("class_palette_id", "")) == "biologist.viridian_outbreak",
			"%s must bind separate Biologist hero pose art, weapon silhouette and palette" % weapon_id)
		var scene_path := str(definition.get("scene_path", ""))
		var packed := load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
		_check(packed != null, "%s timeline scene must load" % weapon_id)
		if packed != null:
			var scene := packed.instantiate()
			for raw_node_path in (definition.get("visual_contract", {}) as Dictionary).get("required_nodes", []) as Array:
				_check(scene.get_node_or_null(str(raw_node_path)) != null,
					"%s timeline scene must declare its contracted node: %s" % [weapon_id, str(raw_node_path)])
			scene.free()
		timings[JSON.stringify(manifest.get("timing", {}), "", true)] = true
	_check(timings.size() == WEAPONS.size(), "Biologist ultimates must have distinct v2 timing rhythms")
	_report()


func _definition(weapon_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.timeline.json" % [ROOT, weapon_id]))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("biologist_ultimate_timelines: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("biologist_ultimate_timelines: %s" % error)
	quit(1)
