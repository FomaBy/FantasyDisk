extends SceneTree

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const CLASS_ID := "sniper"
const WEAPONS := ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"]
const ROOT := "res://scenes/vfx/ultimates/sniper"
const EFFECT_SCENES := {
	"sniper_deadeye_rifle": preload("res://scripts/ultimates/classes/sniper/sniper_deadeye_rifle.tscn"),
	"sniper_spotter_scope": preload("res://scripts/ultimates/classes/sniper/sniper_spotter_scope.tscn"),
	"sniper_shatter_rounds": preload("res://scripts/ultimates/classes/sniper/sniper_shatter_rounds.tscn"),
}
const IMPACT_FRAME_PATHS := {
	"sniper_deadeye_rifle": "res://assets/sprites/effects/sniper/deadeye_rifle/deadeye_rifle_spriteframes.tres",
	"sniper_spotter_scope": "res://assets/sprites/effects/sniper/spotter_scope/spotter_scope_spriteframes.tres",
	"sniper_shatter_rounds": "res://assets/sprites/effects/sniper/shatter_rounds/shatter_rounds_spriteframes.tres",
}


class VictimProbe extends Node2D:
	var health := 100.0
	var flashes := 0

	func _combat_feedback_enabled() -> bool:
		return true

	func _show_hit_flash() -> void:
		flashes += 1


class ImpactActivationProbe extends RefCounted:
	func origin() -> Vector2:
		return Vector2.ZERO

	func is_finished() -> bool:
		return false

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func scaled_damage(_key: String, fallback: float) -> float:
		return fallback

	func apply_control(_target: Node, _impulse: Vector2, _status_id: String, _status: Dictionary) -> Dictionary:
		return {"status_applied": true}

var _errors: Array[String] = []


func _initialize() -> void:
	var direction_manifest := DirectionContract.load_manifest(CLASS_ID)
	var direction_violations := DirectionContract.violations(CLASS_ID, direction_manifest)
	_check(direction_violations.is_empty(),
		"Sniper must satisfy every visual-direction gate: %s" % [str(direction_violations)])
	for gate in DirectionContract.GATES:
		if gate == "victim_impact":
			continue
		_check(not (DirectionContract.ADOPTION_GAPS.get(gate, {}) as Dictionary).has(CLASS_ID),
			"Sniper must not remain in the %s visual-direction allowlist" % gate)
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
			and str(identity.get("class_palette_id", "")) == "sniper.glacial_crimson",
			"%s must bind separate Sniper hero pose art, weapon silhouette and palette" % weapon_id)
		timings[JSON.stringify(manifest.get("timing", {}), "", true)] = true
	_check(timings.size() == WEAPONS.size(), "Sniper ultimates must have distinct v2 timing rhythms")
	_test_weapon_local_impacts()
	_test_missing_impact_mapping_fails()
	_report()


func _test_weapon_local_impacts() -> void:
	for weapon_id in WEAPONS:
		var effect := (EFFECT_SCENES[weapon_id] as PackedScene).instantiate() as Node2D
		root.add_child(effect)
		effect.set("ultimate_damage_sink", Callable(self, "_damage_sink"))
		var activation := ImpactActivationProbe.new()
		var victims: Array[VictimProbe] = []
		for index in 2:
			var victim := VictimProbe.new()
			victim.position = Vector2(80.0 + float(index) * 80.0, 0.0)
			root.add_child(victim)
			victims.append(victim)
		match weapon_id:
			"sniper_deadeye_rifle":
				effect.call("configure", activation, victims, victims[0])
				effect.call("fire")
			"sniper_spotter_scope":
				effect.call("configure", activation, Vector2.ZERO, victims)
				effect.call("strike", 0)
			"sniper_shatter_rounds":
				effect.call("configure", activation, victims)
				effect.call("impact", 0)
		var impacts := _impact_player(effect)
		_check(impacts != null, "%s must create UltimateVictimImpactPlayer for real hit victims" % weapon_id)
		if impacts != null:
			var planned := impacts.call("snapshot") as Dictionary
			_check(int(planned.get("victims", 0)) == victims.size(), "%s must route every damaged victim into its impact player" % weapon_id)
			impacts.call("advance", 10.0)
			var played := impacts.call("snapshot") as Dictionary
			_check(int(played.get("flashes", 0)) == victims.size(), "%s must preserve every victim hit flash" % weapon_id)
			var burst := impacts.find_child("VictimImpact0", true, false) as AnimatedSprite2D
			_check(burst != null and burst.sprite_frames != null and burst.sprite_frames.resource_path == IMPACT_FRAME_PATHS[weapon_id], "%s must load its class-local impact flipbook" % weapon_id)
		effect.queue_free()
		for victim in victims:
			victim.queue_free()


func _test_missing_impact_mapping_fails() -> void:
	var probe_root := "user://fan_3884_sniper_impact_probe"
	var scripts_dir := ProjectSettings.globalize_path(probe_root.path_join("scripts/ultimates/classes/sniper"))
	_check(DirAccess.make_dir_recursive_absolute(scripts_dir) == OK, "negative impact probe directory must be writable")
	for weapon_id in WEAPONS:
		var probe_path := probe_root.path_join("scripts/ultimates/classes/sniper/%s.gd" % weapon_id)
		var probe := FileAccess.open(probe_path, FileAccess.WRITE)
		_check(probe != null, "%s negative impact probe must be writable" % weapon_id)
		if probe != null:
			var source := "const ImpactPlayer := preload(\"res://scripts/ultimates/presentation/victim_impact_player.gd\")\nfunc play() -> void:\n\tvar impact := ImpactPlayer.new()\n"
			if weapon_id == "sniper_shatter_rounds":
				source = "func play() -> void:\n\tpass\n"
			probe.store_string(source)
			probe.close()
	var weapons: Array[Dictionary] = []
	for weapon_id in WEAPONS:
		weapons.append({"weapon_id": weapon_id})
	var violations := DirectionContract.victim_impact_violations_from_sources(CLASS_ID, weapons, probe_root)
	_check(violations == ["victim_impact.unwired: sniper/sniper_shatter_rounds routes no victim through UltimateVictimImpactPlayer"], "a broken required Sniper impact mapping must fail closed: %s" % [str(violations)])
	for weapon_id in WEAPONS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_root.path_join("scripts/ultimates/classes/sniper/%s.gd" % weapon_id)))
	DirAccess.remove_absolute(scripts_dir)


func _impact_player(effect: Node) -> Node:
	for child in effect.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


func _damage_sink(_target: Node, amount: float, _feedback: Dictionary, _event_id: String, _secondary: bool) -> Dictionary:
	return {"applied": amount, "killed": false}


func _definition(weapon_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.timeline.json" % [ROOT, weapon_id]))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("sniper_ultimate_timelines: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("sniper_ultimate_timelines: %s" % error)
	quit(1)
