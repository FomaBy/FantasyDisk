extends SceneTree

## Focused victim-impact wiring proof for every canonical thief ultimate
## (FAN-3886). Positive: each weapon's effect scene starts the shared
## UltimateVictimImpactPlayer ripple for exactly the enemies it actually hits,
## using its own integrated flipbook, without losing the white victim flash.
## Negative: the shared contract gate goes red the moment one weapon's wiring
## is missing.

const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/thief/manifest.json"
const EFFECT_SCENES := {
	"thief_coin_pouch": preload("res://scripts/ultimates/classes/thief/thief_coin_pouch.tscn"),
	"thief_shadow_cloak": preload("res://scripts/ultimates/classes/thief/thief_shadow_cloak.tscn"),
	"thief_smoke_bomb": preload("res://scripts/ultimates/classes/thief/thief_smoke_bomb.tscn"),
}
const FLIPBOOK_PATHS := {
	"thief_coin_pouch": "res://assets/sprites/effects/thief/coin_pouch/coin_pouch_spriteframes.tres",
	"thief_shadow_cloak": "res://assets/sprites/effects/thief/shadow_cloak/shadow_cloak_spriteframes.tres",
	"thief_smoke_bomb": "res://assets/sprites/effects/thief/smoke_bomb/smoke_bomb_spriteframes.tres",
}
const WIRED_FIXTURE_SOURCE := \
	"const ImpactPlayer := preload(\"res://scripts/ultimates/presentation/victim_impact_player.gd\")\n" \
	+ "func _ready() -> void:\n" \
	+ "\tvar _impacts = ImpactPlayer.new()\n"
const UNWIRED_FIXTURE_SOURCE := "func _ready() -> void:\n\tpass\n"


class VictimProbe extends Node2D:
	var flashes := 0

	func _combat_feedback_enabled() -> bool:
		return true

	func _show_hit_flash() -> void:
		flashes += 1


class ActivationProbe extends RefCounted:
	var host = null

	func origin() -> Vector2:
		return Vector2.ZERO

	func is_finished() -> bool:
		return false

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func param_int(_key: String, fallback: int) -> int:
		return fallback

	func scaled_damage(_key: String, fallback: float) -> float:
		return fallback

	func present(_phase_id: String, _payload: Dictionary) -> void:
		pass

	func apply_control(_target: Node, _impulse: Vector2, _status_id: String, _status: Dictionary) -> Dictionary:
		return {"status_applied": true}

	func apply_modifier(_key: String, _value: float, _mode: String) -> void:
		pass


func _initialize() -> void:
	# One real frame first: the effect scripts reach get_tree() from inside
	# _play_impacts, which is null until the tree has ticked once.
	await process_frame
	var errors: Array[String] = []
	var manifest := _load_json(MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	var weapons := _typed_weapons(manifest.get("weapons", []) as Array)
	_expect(weapons.size() == 3, "manifest must enumerate the thief trio, found %d" % weapons.size(), errors)
	for weapon in weapons:
		var weapon_id := str((weapon as Dictionary).get("weapon_id", ""))
		_expect(EFFECT_SCENES.has(weapon_id), "manifest weapon %s has no canonical thief effect scene" % weapon_id, errors)
	for weapon_id in EFFECT_SCENES:
		_check_runtime_contour(weapon_id, errors)
	_check_real_mapping(weapons, errors)
	_check_negative_probes(weapons, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Thief victim impact passed (all three ultimates wired, runtime contour clean, negative probes red).")
	quit(0)


## Runtime contour (acceptance 3): each real effect scene is instantiated, its
## damage entry point is driven, and the shared ripple must cover every hit
## victim with no missing-resource or script errors.
func _check_runtime_contour(weapon_id: String, errors: Array[String]) -> void:
	var effect := (EFFECT_SCENES[weapon_id] as PackedScene).instantiate() as Node2D
	root.add_child(effect)
	effect.set("ultimate_damage_sink", Callable(self, "_damage_sink"))
	var activation := ActivationProbe.new()
	var victims: Array = []
	for index in 3:
		var victim := VictimProbe.new()
		victim.position = Vector2(80.0 + float(index) * 120.0, 0.0)
		root.add_child(victim)
		victims.append(victim)
	var before := _impact_player_ids()
	match weapon_id:
		"thief_coin_pouch":
			effect.call("configure", activation, victims)
			for index in victims.size():
				effect.call("hit", index)
		"thief_shadow_cloak":
			effect.call("configure", activation, victims)
			effect.call("stab", 0)
		"thief_smoke_bomb":
			effect.call("configure", activation, victims)
			effect.call("collapse")
	# A previous weapon's ripple may still be inside its own release window on
	# the shared root, so this weapon's ripple is the new node, not the first.
	var impacts := _impact_player(before)
	_expect(impacts != null, "%s must start the shared weapon-local victim impact" % weapon_id, errors)
	if impacts != null:
		var planned := impacts.call("snapshot") as Dictionary
		_expect(int(planned.get("victims", 0)) == victims.size(),
			"%s must enqueue every actually affected enemy (planned %s)" % [weapon_id, str(planned)], errors)
		_expect(int(planned.get("stagger_frames", 0)) >= ImpactPlayer.STAGGER_MIN_FRAMES \
				and int(planned.get("stagger_frames", 0)) <= ImpactPlayer.STAGGER_MAX_FRAMES,
			"%s victim ripple must stagger outward by 3-8 frames" % weapon_id, errors)
		impacts.call("advance", 1.0)
		var played := impacts.call("snapshot") as Dictionary
		_expect(int(played.get("flashes", 0)) == victims.size(),
			"%s degradation must never drop the existing white victim flash" % weapon_id, errors)
		var burst := impacts.find_child("VictimImpact0", true, false) as AnimatedSprite2D
		_expect(burst != null and burst.sprite_frames != null \
				and burst.sprite_frames.resource_path == str(FLIPBOOK_PATHS[weapon_id]),
			"%s victim impact must use its own integrated flipbook" % weapon_id, errors)
	effect.queue_free()
	for victim in victims:
		(victim as Node).queue_free()


## The shared gate agrees with the live class schema and manifest (acceptance 1, 2).
## The aggregate contract file itself is locked by this card (AC-6), so the
## victim_impact adoption ratchet still names thief; only the class-local
## mapping is proven here.
func _check_real_mapping(weapons: Array, errors: Array[String]) -> void:
	_expect(DirectionContract.victim_impact_violations_from_sources("thief", weapons).is_empty(),
		"every canonical thief weapon must route victims through UltimateVictimImpactPlayer: %s" % [
			str(DirectionContract.victim_impact_violations_from_sources("thief", weapons)),
		], errors)


## Negative probes (acceptance 4): removing or breaking exactly one mapping
## must turn the same gate red — on the real tree and on isolated fixtures.
func _check_negative_probes(weapons: Array, errors: Array[String]) -> void:
	var missing := _typed_weapons(weapons.duplicate(true))
	(missing[0] as Dictionary)["weapon_id"] = "thief_missing_weapon"
	var missing_errors := DirectionContract.victim_impact_violations_from_sources("thief", missing)
	_expect(missing_errors.size() == 1 and str(missing_errors[0]).contains("victim_impact.unwired: thief/thief_missing_weapon"),
		"a removed weapon mapping must fail closed with exactly one unwired error, got: %s" % str(missing_errors), errors)

	var fixture_root := "user://fan3886_victim_impact_fixture"
	_write_fixture("%s/scripts/ultimates/classes/thief/thief_wired.gd" % fixture_root, WIRED_FIXTURE_SOURCE)
	_write_fixture("%s/scripts/ultimates/classes/thief/thief_unwired.gd" % fixture_root, UNWIRED_FIXTURE_SOURCE)
	_expect(DirectionContract.victim_impact_violations_from_sources("thief",
		_typed_weapons([{"weapon_id": "thief_wired"}]), fixture_root).is_empty(),
		"wired fixture must clear the gate", errors)
	var fixture_errors := DirectionContract.victim_impact_violations_from_sources("thief",
		_typed_weapons([{"weapon_id": "thief_wired"}, {"weapon_id": "thief_unwired"}]), fixture_root)
	_expect(fixture_errors.size() == 1 and str(fixture_errors[0]).contains("victim_impact.unwired: thief/thief_unwired"),
		"a single broken script must fail closed with exactly one unwired error, got: %s" % str(fixture_errors), errors)


func _typed_weapons(raw: Array) -> Array[Dictionary]:
	var weapons: Array[Dictionary] = []
	for entry in raw:
		if entry is Dictionary:
			weapons.append(entry as Dictionary)
	return weapons


## The ripple outlives the activation-owned effect (FAN-3886 lifecycle fix),
## so it is looked up on the scene root, not under the effect node; `exclude`
## skips ripples left over from earlier weapons in this same run.
func _impact_player(exclude: Dictionary = {}) -> Node:
	var parent := current_scene
	if parent == null:
		parent = root
	for child in parent.get_children():
		if child.get_script() == ImpactPlayer and not exclude.has(child.get_instance_id()):
			return child
	return null


func _impact_player_ids() -> Dictionary:
	var ids := {}
	var parent := current_scene
	if parent == null:
		parent = root
	for child in parent.get_children():
		if child.get_script() == ImpactPlayer:
			ids[child.get_instance_id()] = true
	return ids


func _damage_sink(_target: Node, _amount: float, _feedback: Dictionary, _event_id: String, _secondary: bool) -> Dictionary:
	return {"killed": false}


func _write_fixture(path: String, source: String) -> void:
	var dir := DirAccess.open("user://")
	dir.make_dir_recursive(path.trim_prefix("user://").get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()


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
		push_error("Thief victim impact: %s" % error)
	quit(1)
