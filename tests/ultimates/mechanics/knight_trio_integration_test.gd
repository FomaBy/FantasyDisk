extends SceneTree

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "knight"
const WEAPONS := {
	"long_spear": {
		"profile_id": "weapon_ultimate.profile.knight.long_spear",
		"executor": "res://scripts/ultimates/classes/knight/long_spear.gd",
	},
	"tower_shield": {
		"profile_id": "weapon_ultimate.profile.knight.tower_shield",
		"executor": "res://scripts/ultimates/classes/knight/tower_shield.gd",
	},
	"holy_flail": {
		"profile_id": "weapon_ultimate.profile.knight.holy_flail",
		"executor": "res://scripts/ultimates/classes/knight/holy_flail.gd",
	},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable catalog must remain valid")
	_check(registry.package_validation_errors().is_empty(),
		"the three independent Knight leaves must all admit: %s" % [registry.package_validation_errors()])
	var knight_pairs: Array[String] = []
	for key in registry.package_pair_keys():
		if str(key).begins_with(CLASS_ID + "/"):
			knight_pairs.append(str(key))
	knight_pairs.sort()
	_check(knight_pairs == ["knight/holy_flail", "knight/long_spear", "knight/tower_shield"],
		"only the three exact Knight weapon IDs may be ready")
	for weapon_id in WEAPONS:
		_check_weapon(registry, weapon_id, WEAPONS[weapon_id] as Dictionary)
	_check(registry.executor_for(CLASS_ID, "long_spear") != registry.executor_for(CLASS_ID, "tower_shield")
		and registry.executor_for(CLASS_ID, "tower_shield") != registry.executor_for(CLASS_ID, "holy_flail")
		and registry.executor_for(CLASS_ID, "long_spear") != registry.executor_for(CLASS_ID, "holy_flail"),
		"Knight leaf executors must remain distinct and cannot leak into one another")
	_check(registry.resolution_source("robot", "tower_shield") != Resolver.SOURCE_WEAPON_PROFILE
		and registry.resolution_source(CLASS_ID, "sword") != Resolver.SOURCE_WEAPON_PROFILE,
		"the completed Knight trio must not promote foreign or undeclared pairs")
	if _errors.is_empty():
		print("knight_trio_integration_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("knight_trio_integration_test: %s" % error)
	print("knight_trio_integration_test: FAIL (%d)" % _errors.size())
	quit(1)


func _check_weapon(registry: Registry, weapon_id: String, expected: Dictionary) -> void:
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var executor = registry.executor_for(CLASS_ID, weapon_id)
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact local profile" % weapon_id)
	_check(str((profile.get("identity", {}) as Dictionary).get("profile_id", "")) == str(expected["profile_id"])
		and str(profile.get("weapon_id", "")) == weapon_id
		and str(profile.get("implementation_state", "")) == "ready",
		"%s must retain its exact ready profile identity" % weapon_id)
	_check(executor is GDScript and (executor as GDScript).resource_path == str(expected["executor"]),
		"%s must retain its own class-local executor without cross-leaf substitution" % weapon_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
