extends SceneTree

## Convention discovery, exact pair admission, fail-closed migration and the
## controller's class-local executor seam.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Discovery := preload(
	"res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd"
)
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")

const CLASS_ID := "fixture_class"
const WEAPON_ID := "fixture_weapon"
const KEY := "fixture_class/fixture_weapon"
const DATA_ROOT := "res://tests/ultimates/fixtures/packages/data"
const SCRIPT_ROOT := "res://tests/ultimates/fixtures/packages/scripts"
const INVALID_DATA_ROOT := "res://tests/ultimates/fixtures/packages_invalid/data"
const INVALID_SCRIPT_ROOT := "res://tests/ultimates/fixtures/packages_invalid/scripts"
const DOCUMENT_PATH := DATA_ROOT + "/fixture_class/fixture_weapon.json"
const EXECUTOR_PATH := SCRIPT_ROOT + "/fixture_class/fixture_weapon.gd"


class FixtureTarget extends Node2D:
	var health := 100.0
	var max_health := 100.0

	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)


class FixtureHost extends Node2D:
	var target: FixtureTarget
	var active := false

	func ultimate_host_context() -> Dictionary:
		return {"damage": 10.0, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * max_range, "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, _limit: int) -> Array:
		return [target] if is_instance_valid(target) \
			and target.global_position.distance_to(center) <= radius else []

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_apply_damage(victim: Node, amount: float, feedback: Dictionary) -> void:
		victim.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


class FixtureRegistry extends RefCounted:
	var profile: Dictionary
	var executor

	func resolution_source(class_id: String, weapon_id: String, _allow_legacy := true) -> String:
		return Resolver.SOURCE_WEAPON_PROFILE if class_id == CLASS_ID and weapon_id == WEAPON_ID \
			else Resolver.SOURCE_INVALID_PAIR

	func catalog_profile_for(_class_id: String, _weapon_id: String) -> Dictionary:
		return profile.duplicate(true)

	func executor_for(_class_id: String, _weapon_id: String):
		return executor


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	var base_profile := _base_profile()
	var discovery := Discovery.new(DATA_ROOT, SCRIPT_ROOT)
	discovery.discover({KEY: base_profile})
	_test_valid_pair(discovery, base_profile)
	_test_invalid_pair_admission(discovery, base_profile)
	_test_invalid_discovery_set(base_profile)
	await _test_controller_executes_discovered_pair(discovery)
	_holder.queue_free()
	await process_frame
	_report()


func _test_valid_pair(discovery: Discovery, base_profile: Dictionary) -> void:
	_check(discovery.validation_errors().is_empty(),
		"valid pair must discover without errors: %s" % [discovery.validation_errors()])
	_check(discovery.pair_keys() == {KEY: true}, "discovery must expose exactly one pair")
	var profile := discovery.profile_for(KEY)
	_check(str(profile.get("implementation_state", "")) == "ready",
		"valid overlay must promote only its immutable base profile")
	if profile.is_empty():
		return
	_check(profile.get("identity") == base_profile.get("identity") \
			and profile.get("cast_phases") == base_profile.get("cast_phases") \
			and profile.get("presentation") == base_profile.get("presentation"),
		"overlay merge must preserve immutable catalog identity and presentation")
	_check((profile["executor"] as Dictionary)["params"] == {
		"damage": 1.0, "radius": 300.0, "target_limit": 0,
	}, "package params must use the shared deterministic normalizer")
	var profiles := {KEY: profile}
	var canonical := {KEY: true}
	_check(Resolver.resolution_source(
		profiles, canonical, CLASS_ID, WEAPON_ID, true, discovery.pair_keys()
	) == Resolver.SOURCE_WEAPON_PROFILE, "admitted exact pair must resolve to its weapon profile")
	_check(Resolver.resolution_source(
		profiles, canonical, CLASS_ID, WEAPON_ID, true, {}
	) == Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
		"ready data without an exact executor pair must remain legacy-safe")


func _test_invalid_pair_admission(discovery: Discovery, base_profile: Dictionary) -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(DOCUMENT_PATH))
	var executor = load(EXECUTOR_PATH)
	_check(document is Dictionary and executor is GDScript, "fixture pair must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var declared := (document as Dictionary).duplicate(true)
	declared["implementation_state"] = "declared"
	_expect_pair_error(discovery, declared, executor, base_profile, "package.implementation_state")
	var mismatch := (document as Dictionary).duplicate(true)
	mismatch["executor_id"] = "weapon_ultimate.executor.fixture_class.mismatch"
	_expect_pair_error(discovery, mismatch, executor, base_profile, "package.executor")
	var incomplete := (document as Dictionary).duplicate(true)
	(incomplete["executor"] as Dictionary)["params"].erase("target_limit")
	_expect_pair_error(discovery, incomplete, executor, base_profile, "executor_params.missing")


func _test_invalid_discovery_set(base_profile: Dictionary) -> void:
	var invalid := Discovery.new(INVALID_DATA_ROOT, INVALID_SCRIPT_ROOT)
	invalid.discover({KEY: base_profile})
	var errors := invalid.validation_errors()
	_check(invalid.pair_keys().is_empty(), "duplicated package key must admit no executor pair")
	for prefix in ["package.pair.duplicate", "package.pair.executor_missing", "package.pair.data_missing"]:
		_check(_has_error(errors, prefix), "%s must fail closed: %s" % [prefix, errors])


func _test_controller_executes_discovered_pair(discovery: Discovery) -> void:
	var host := FixtureHost.new()
	_holder.add_child(host)
	host.target = FixtureTarget.new()
	host.target.global_position = Vector2.RIGHT * 50.0
	host.add_child(host.target)
	var registry := FixtureRegistry.new()
	registry.profile = discovery.profile_for(KEY)
	registry.executor = discovery.executor_for(KEY)
	var controller := Controller.new(host, registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID),
		"controller must execute an admitted class-local executor")
	_check(is_equal_approx(host.target.health, 90.0) and not controller.is_active() and not host.active,
		"class-local executor must use the shared activation ledger and lifecycle")
	host.queue_free()
	await process_frame


func _base_profile() -> Dictionary:
	var id_suffix := "%s.%s" % [CLASS_ID, WEAPON_ID]
	return {
		"class_id": CLASS_ID,
		"weapon_id": WEAPON_ID,
		"class_order": 0,
		"profile_order": 0,
		"schema_version": 1,
		"implementation_state": "declared",
		"fallback_policy_id": "legacy_class_ultimate",
		"identity": {
			"profile_id": "weapon_ultimate.profile.%s" % id_suffix,
			"title_id": "weapon_ultimate.title.%s" % id_suffix,
			"mechanic_id": "weapon_ultimate.mechanic.%s" % id_suffix,
		},
		"targeting": {
			"aim_id": "weapon_ultimate.aim.%s" % id_suffix,
			"strategy_id": "unbound", "params": {},
		},
		"charge": {
			"policy_id": "weapon_ultimate.charge.%s" % id_suffix,
			"strategy_id": "unbound", "params": {},
		},
		"cast_phases": {
			"acquire": "weapon_ultimate.phase.%s.acquire" % id_suffix,
			"windup": "weapon_ultimate.phase.%s.windup" % id_suffix,
			"execute": "weapon_ultimate.phase.%s.execute" % id_suffix,
			"active": "weapon_ultimate.phase.%s.active" % id_suffix,
			"recover": "weapon_ultimate.phase.%s.recover" % id_suffix,
			"cleanup": "weapon_ultimate.phase.%s.cleanup" % id_suffix,
		},
		"executor": {
			"executor_id": "weapon_ultimate.executor.%s" % id_suffix,
			"strategy_id": "unbound", "params": {},
		},
		"total_boss_cap": null,
		"presentation": {
			"presentation_id": "weapon_ultimate.presentation.%s" % id_suffix,
			"animation_id": "weapon_ultimate.animation.%s" % id_suffix,
			"vfx_id": "weapon_ultimate.vfx.%s" % id_suffix,
			"sfx_id": "weapon_ultimate.sfx.%s" % id_suffix,
			"params": {},
		},
		"cleanup_policy": {
			"policy_id": "weapon_ultimate.cleanup.%s" % id_suffix,
			"strategy_id": "unbound", "params": {},
		},
	}


func _expect_pair_error(
	discovery: Discovery,
	document: Dictionary,
	executor,
	base_profile: Dictionary,
	prefix: String
) -> void:
	var result := discovery.validate_pair(
		document, "fixture_class/fixture_weapon.json", executor, base_profile
	)
	_check(_has_error(result["errors"] as Array, prefix),
		"invalid pair must reject with %s: %s" % [prefix, result["errors"]])


func _has_error(errors: Array, prefix: String) -> bool:
	for error in errors:
		if str(error).contains(prefix):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("registry_package_discovery_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("registry_package_discovery_test: %s" % error)
	print("registry_package_discovery_test: FAIL (%d)" % _errors.size())
	quit(1)
