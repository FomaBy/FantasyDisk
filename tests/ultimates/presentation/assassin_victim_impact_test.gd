extends SceneTree

const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/assassin.json"
const WEAPON_IDS := ["chakrams", "shadow_daggers", "venom_wire"]
const EFFECT_SCENES := {
	"chakrams": preload("res://scripts/ultimates/classes/assassin/chakrams.tscn"),
	"shadow_daggers": preload("res://scripts/ultimates/classes/assassin/shadow_daggers.tscn"),
	"venom_wire": preload("res://scripts/ultimates/classes/assassin/venom_wire.tscn"),
}
const VICTIM_IMPACT_FRAMES := {
	"chakrams": "res://assets/sprites/effects/assassin/chakrams/victim_explosion/victim_explosion_spriteframes.tres",
	"shadow_daggers": "res://assets/sprites/effects/assassin/shadow_daggers/victim_impact/victim_impact_spriteframes.tres",
	"venom_wire": "res://assets/sprites/effects/assassin/venom_wire/victim_impact/victim_impact_spriteframes.tres",
}
const SOURCE_FIXTURE_ROOT := "user://fan3878_assassin_victim_impact_fixtures"


class VictimProbe extends Node2D:
	var flashes := 0

	func _combat_feedback_enabled() -> bool:
		return true

	func _show_hit_flash() -> void:
		flashes += 1


class ImpactActivationProbe extends RefCounted:
	var targets_list: Array = []
	var host = null
	var _values: Dictionary = {}

	func origin() -> Vector2:
		return Vector2.ZERO

	func is_finished() -> bool:
		return false

	func param_int(_key: String, fallback: int) -> int:
		return fallback

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func scaled_damage(_key: String, fallback: float) -> float:
		return maxf(fallback, 10.0)

	func primitive_value(key: String, fallback: Variant) -> Variant:
		if key == "points":
			return PackedVector2Array([
				Vector2(0.0, -142.0), Vector2(124.0, -72.0), Vector2(124.0, 72.0),
				Vector2(0.0, 142.0), Vector2(-124.0, 72.0), Vector2(-124.0, -72.0),
			])
		return fallback

	func select_targets(_center: Vector2, _radius: float, _limit: int, _order: String, _options := {}) -> Array:
		return targets_list

	func targets_in_corridor(_start: Vector2, _offset: Vector2, _length: float, _half_width: float, _limit: int) -> Array:
		return targets_list

	func record_target_value(target: Node, key: String, value: Variant, _event_id: String) -> bool:
		_values[_value_key(target, key)] = value
		return true

	func add_target_value(target: Node, key: String, value: Variant, _event_id: String) -> bool:
		var value_key := _value_key(target, key)
		_values[value_key] = float(_values.get(value_key, 0.0)) + float(value)
		return true

	func consume_target_value(target: Node, key: String, _event_id: String, fallback: Variant) -> Variant:
		var value: Variant = _values.get(_value_key(target, key), fallback)
		_values.erase(_value_key(target, key))
		return value

	func apply_control(_target: Node, _impulse: Vector2, _status_id: String, _status: Dictionary) -> Dictionary:
		return {"execute_allowed": false, "displaced": false, "status_applied": false}

	func _value_key(target: Node, key: String) -> String:
		return "%d:%s" % [target.get_instance_id(), key]


func _initialize() -> void:
	var errors: Array[String] = []
	_check_source_mapping(errors)
	_check_runtime_mapping(errors)
	_finish(errors)


func _check_source_mapping(errors: Array[String]) -> void:
	var schema: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	var canonical_ids: Array = []
	if schema is Dictionary:
		var profiles: Variant = (schema as Dictionary).get("profiles", [])
		if profiles is Array:
			for raw_profile in profiles as Array:
				if raw_profile is Dictionary:
					canonical_ids.append(str((raw_profile as Dictionary).get("weapon_id", "")))
		canonical_ids.sort()
	var expected_ids: Array = WEAPON_IDS.duplicate()
	expected_ids.sort()
	_expect(canonical_ids == expected_ids, "live Assassin schema must enumerate the canonical trio", errors)
	var mapped_ids: Array = EFFECT_SCENES.keys()
	mapped_ids.sort()
	_expect(mapped_ids == canonical_ids, "every schema weapon must have exactly one local effect mapping", errors)

	var weapons: Array[Dictionary] = []
	for weapon_id in canonical_ids:
		weapons.append({"weapon_id": str(weapon_id)})
	var live_violations := Contract.victim_impact_violations_from_sources("assassin", weapons)
	_expect(live_violations.is_empty(), "live Assassin mapping must be complete: %s" % [live_violations], errors)

	var fixture_root := ProjectSettings.globalize_path(SOURCE_FIXTURE_ROOT)
	var executor_root := fixture_root.path_join("scripts/ultimates/classes/assassin")
	DirAccess.make_dir_recursive_absolute(executor_root)
	for weapon_id in WEAPON_IDS:
		var player_path := "res://scripts/ultimates/presentation/victim_impact_player.gd"
		if weapon_id == "shadow_daggers":
			player_path = "res://scripts/ultimates/presentation/missing_player.gd"
		_write_source_fixture(
			executor_root.path_join("%s.gd" % weapon_id),
			"const ImpactPlayer := preload(\"%s\")\nfunc _wire() -> void:\n\tvar impact := ImpactPlayer.new()\n" % player_path
		)
	var broken_violations := Contract.victim_impact_violations_from_sources(
		"assassin", weapons, fixture_root
	)
	_expect(
		broken_violations.size() == 1 and "assassin/shadow_daggers" in broken_violations[0],
		"one broken Assassin mapping must fail closed: %s" % [broken_violations],
		errors
	)
	_cleanup_source_fixtures(fixture_root)


func _check_runtime_mapping(errors: Array[String]) -> void:
	for weapon_id in WEAPON_IDS:
		var effect := (EFFECT_SCENES[weapon_id] as PackedScene).instantiate() as Node2D
		root.add_child(effect)
		effect.set("ultimate_damage_sink", Callable(self, "_damage_sink"))
		var activation := ImpactActivationProbe.new()
		var victims: Array[VictimProbe] = []
		for index in 4:
			var victim := VictimProbe.new()
			victim.position = Vector2(40.0 + float(index) * 24.0, float(index % 2) * 18.0)
			root.add_child(victim)
			victims.append(victim)
		activation.targets_list = victims
		match weapon_id:
			"chakrams":
				effect.call("configure", activation)
				effect.call("launch")
			"shadow_daggers":
				effect.call("configure", activation, victims)
				effect.call("backstab_wave", 0, 1)
				effect.call("reveal")
			"venom_wire":
				effect.call("configure", activation)
				effect.call("cut_pulse", 0)
		var impacts := _impact_player(effect)
		_expect(impacts != null, "%s must create victim impact player" % weapon_id, errors)
		if impacts != null:
			var planned := impacts.call("snapshot") as Dictionary
			_expect(int(planned.get("victims", 0)) == victims.size(), "%s must queue every struck victim" % weapon_id, errors)
			impacts.call("advance", 10.0)
			var played := impacts.call("snapshot") as Dictionary
			_expect(int(played.get("flashes", 0)) == victims.size(), "%s must flash every struck victim" % weapon_id, errors)
			var frames := ResourceLoader.load(str(VICTIM_IMPACT_FRAMES[weapon_id])) as SpriteFrames
			var burst := impacts.find_child("VictimImpact0", true, false) as AnimatedSprite2D
			_expect(frames != null and burst != null and burst.sprite_frames == frames,
				"%s must use its own loadable impact frames" % weapon_id, errors)
		effect.free()
		for victim in victims:
			victim.free()


func _impact_player(effect: Node) -> Node:
	for child in effect.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


func _damage_sink(_target: Node, amount: float, _feedback: Dictionary, _event_id: String, _secondary: bool) -> Dictionary:
	return {"applied": amount, "killed": false}


func _write_source_fixture(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()


func _cleanup_source_fixtures(root_path: String) -> void:
	for weapon_id in WEAPON_IDS:
		DirAccess.remove_absolute(root_path.path_join("scripts/ultimates/classes/assassin/%s.gd" % weapon_id))
	DirAccess.remove_absolute(root_path.path_join("scripts/ultimates/classes/assassin"))
	DirAccess.remove_absolute(root_path.path_join("scripts/ultimates/classes"))
	DirAccess.remove_absolute(root_path.path_join("scripts/ultimates"))
	DirAccess.remove_absolute(root_path.path_join("scripts"))
	DirAccess.remove_absolute(root_path)


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Assassin victim impact mapping passed (complete source mapping, fail-closed negative probe, and runtime contour).")
		quit(0)
		return
	for error in errors:
		push_error("Assassin victim impact mapping: %s" % error)
	quit(1)
