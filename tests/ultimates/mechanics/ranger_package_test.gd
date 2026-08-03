extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "ranger"
const WEAPONS := ["moon_crossbow", "storm_longbow", "hunter_trap"]

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(registry.package_validation_errors().is_empty(),
		"Ranger package discovery must be clean: %s" % [registry.package_validation_errors()])
	var executor_paths := {}
	var signatures := {}
	for weapon_id in WEAPONS:
		_test_pair(registry, weapon_id, executor_paths, signatures)
	_test_fail_closed_mutation()
	_report()


func _test_pair(registry, weapon_id: String, executor_paths: Dictionary, signatures: Dictionary) -> void:
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready package" % weapon_id)
	_check(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must own one exact executor pair" % weapon_id)
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var executor = registry.executor_for(CLASS_ID, weapon_id)
	_check(str(profile.get("implementation_state", "")) == "ready", "%s must be ready" % weapon_id)
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.09),
		"%s must keep the Ranger 9%% whole-activation boss cap" % weapon_id)
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "ultimate_charge_ledger",
		"%s must use the shared charge ledger" % weapon_id)
	_check(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
		"%s must use activation-owned cleanup" % weapon_id)
	_check(executor is GDScript, "%s executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var script := executor as GDScript
	var constants := script.get_script_constant_map()
	_check(str(constants.get("PROFILE_ID", "")) == "weapon_ultimate.profile.ranger.%s" % weapon_id,
		"%s PROFILE_ID must match the immutable profile" % weapon_id)
	_check(str(constants.get("EXECUTOR_ID", "")) == "weapon_ultimate.executor.ranger.%s" % weapon_id,
		"%s EXECUTOR_ID must match the immutable executor" % weapon_id)
	_check(not executor_paths.has(script.resource_path), "%s must own a distinct executor" % weapon_id)
	executor_paths[script.resource_path] = true
	var signature := JSON.stringify((profile["executor"] as Dictionary)["params"], "", true)
	_check(not signatures.has(signature), "%s must own a distinct parameter contract" % weapon_id)
	signatures[signature] = true


func _test_fail_closed_mutation() -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/ranger/moon_crossbow.json"
	))
	var executor = load("res://scripts/ultimates/classes/ranger/moon_crossbow.gd")
	_check(document is Dictionary and executor is GDScript, "mutation fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["undeclared_power"] = 999.0
	var base_profiles: Dictionary = Schema.index_documents(
		Registry.new(PD.WEAPONS_BY_CLASS).documents_for_tests()
	)
	var base: Dictionary = base_profiles["ranger/moon_crossbow"]
	var result := Discovery.new().validate_pair(mutated, "ranger/moon_crossbow.json", executor, base)
	_check(_has_error(result["errors"] as Array, "executor_params.unknown"),
		"an undeclared Ranger parameter must fail closed: %s" % [result["errors"]])


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
		print("ranger_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ranger_package_test: %s" % error)
	print("ranger_package_test: FAIL (%d)" % _errors.size())
	quit(1)
