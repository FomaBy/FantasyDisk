extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")

var errors := PackedStringArray()


func _initialize() -> void:
	var state := Meta.default_state()
	state["skill_nodes"] = [
		"berserk_sword_b1",
		"berserk_sword_b2",
		"berserk_sword_b3",
		"berserk_sword_b4",
		"berserk_sword_b5",
		"berserk_h0",
	]
	var profiles := Meta.skill_profiles_for_class(state, "berserk")
	var sword_profile: Dictionary = profiles.get("sword", {})
	var axe_profile: Dictionary = profiles.get("axe", {})
	_check(bool(sword_profile.get("valid", false)), "owning sword profile must be valid")
	_check((sword_profile.get("node_ids", []) as Array).size() == 6, "sword profile must contain five boons plus purchased hidden")
	_check(is_equal_approx(float((sword_profile.get("amounts", {}) as Dictionary).get("weapon_damage_flat", 0.0)), 10.0), "sword flat damage must aggregate to +10")
	_check((axe_profile.get("node_ids", []) as Array).is_empty(), "unpurchased axe profile must remain neutral")
	_check(not bool(Meta.skill_modifiers_for_weapon(state, "berserk", "foreign_weapon").get("valid", true)), "foreign weapon id must fail closed")

	var player = PlayerScript.new()
	player.configure_character("berserk")
	var sword = BerserkWeaponScript.new()
	sword.weapon_id = "sword"
	var axe = BerserkWeaponScript.new()
	axe.weapon_id = "axe"
	player._apply_weapon_scaling(sword)
	player._apply_weapon_scaling(axe)
	var sword_damage_before := float(sword.damage)
	var sword_interval_before := float(sword.fire_interval)
	var sword_range_before := float(sword.attack_range)
	var axe_damage_before := float(axe.damage)
	var axe_interval_before := float(axe.fire_interval)
	player.apply_constellation_weapon_profiles(profiles)
	# Mutating the source after application must not mutate a saved/run profile.
	(sword_profile.get("amounts", {}) as Dictionary)["weapon_damage_flat"] = 999.0
	player._apply_weapon_scaling(sword)
	player._apply_weapon_scaling(axe)
	_check(is_equal_approx(float(sword.damage), sword_damage_before + 10.0), "sword must receive exactly its +10 flat damage once")
	_check(is_equal_approx(float(sword.fire_interval), sword_interval_before / 1.08), "sword cadence must receive exactly its ×1.08 profile")
	_check(is_equal_approx(float(sword.attack_range), sword_range_before * 1.12), "sword geometry must receive exactly its ×1.12 profile")
	_check(is_equal_approx(float(axe.damage), axe_damage_before), "sword damage profile leaked into axe")
	_check(is_equal_approx(float(axe.fire_interval), axe_interval_before), "sword cadence profile leaked into axe")
	_check(is_equal_approx(player.meta_damage_multiplier({"weapon_id": "sword"}), 1.12 * 1.08 * 1.08), "sword identity/solo/hidden axis multipliers mismatch")
	_check(is_equal_approx(player.meta_damage_multiplier({"weapon_id": "axe"}), 1.0), "sword axis power leaked into axe")

	sword.free()
	axe.free()
	player.free()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 typed weapon profiles passed exact flat/cadence/geometry/axis ownership and foreign controls.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
