extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPONS := ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]
const EXPECTED := {
	"soldier_rifle": {"volley_count": 3, "target_limit": 3},
	"soldier_grenade": {"grenade_count": 7, "seed": 1469},
	"soldier_bayonet": {"rank_count": 3, "target_limit": 18},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(registry.package_validation_errors().is_empty(),
		"Soldier discovery must stay clean: %s" % [registry.package_validation_errors()])
	var soldier_pairs: Array[String] = []
	for key in registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			soldier_pairs.append(key)
	soldier_pairs.sort()
	_check(soldier_pairs == [
		"soldier/soldier_bayonet",
		"soldier/soldier_grenade",
		"soldier/soldier_rifle",
	], "exactly three Soldier pairs must be admitted, got %s" % [soldier_pairs])
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var executor_paths := {}
	var parameter_signatures := {}
	for weapon_id in WEAPONS:
		_test_base_contract(base_profiles["soldier/%s" % weapon_id], weapon_id)
		_test_ready_pair(registry, weapon_id, executor_paths, parameter_signatures)
	_test_negative_controls(registry, base_profiles)
	_report()


func _test_base_contract(base: Dictionary, weapon_id: String) -> void:
	_check(str(base.get("implementation_state", "")) == "declared",
		"%s base profile must remain declared" % weapon_id)
	_check(str(base.get("fallback_policy_id", "")) == "legacy_class_ultimate",
		"%s must retain legacy fallback semantics" % weapon_id)
	for binding_name in ["targeting", "charge", "executor", "cleanup_policy"]:
		var binding := base.get(binding_name, {}) as Dictionary
		_check(str(binding.get("strategy_id", "")) == "unbound"
			and (binding.get("params", {}) as Dictionary).is_empty(),
			"%s base %s binding must remain frozen" % [weapon_id, binding_name])


func _test_ready_pair(
	registry: Registry,
	weapon_id: String,
	executor_paths: Dictionary,
	parameter_signatures: Dictionary
) -> void:
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready pair" % weapon_id)
	_check(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must own an exact executor" % weapon_id)
	var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
	var executor = registry.executor_for(CLASS_ID, weapon_id)
	_check(str(profile.get("implementation_state", "")) == "ready",
		"%s overlay must be ready" % weapon_id)
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.09),
		"%s must use Soldier's immutable 9%% boss cap" % weapon_id)
	_check(executor is GDScript, "%s executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var path := (executor as GDScript).resource_path
	_check(not executor_paths.has(path), "%s must not alias another executor" % weapon_id)
	executor_paths[path] = true
	var constants := (executor as GDScript).get_script_constant_map()
	_check(str(constants.get("PROFILE_ID", ""))
		== "weapon_ultimate.profile.soldier.%s" % weapon_id,
		"%s PROFILE_ID must be exact" % weapon_id)
	_check(str(constants.get("EXECUTOR_ID", ""))
		== "weapon_ultimate.executor.soldier.%s" % weapon_id,
		"%s EXECUTOR_ID must be exact" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var signature := JSON.stringify(params, "", true)
	_check(not parameter_signatures.has(signature),
		"%s must not share another weapon's parameter contract" % weapon_id)
	parameter_signatures[signature] = true
	for key in EXPECTED[weapon_id]:
		_check(params.get(key) == (EXPECTED[weapon_id] as Dictionary)[key],
			"%s must freeze %s=%s" % [weapon_id, key, (EXPECTED[weapon_id] as Dictionary)[key]])


func _test_negative_controls(registry: Registry, base_profiles: Dictionary) -> void:
	_check(registry.resolution_source(CLASS_ID, "soldier_rifle_alias")
		== Resolver.SOURCE_INVALID_PAIR, "an alias must fail closed")
	_check(registry.resolution_source(CLASS_ID, "sniper_deadeye_rifle")
		== Resolver.SOURCE_INVALID_PAIR, "a cross-class weapon must fail closed")
	var weapon_id := "soldier_grenade"
	var relative_path := "soldier/%s.json" % weapon_id
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/%s" % relative_path
	))
	var executor = load("res://scripts/ultimates/classes/soldier/%s.gd" % weapon_id)
	_check(document is Dictionary and executor is GDScript, "negative fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var missing := (document as Dictionary).duplicate(true)
	((missing["executor"] as Dictionary)["params"] as Dictionary).erase("grenade_count")
	var missing_result := Discovery.new().validate_pair(
		missing, relative_path, executor, base_profiles["soldier/%s" % weapon_id]
	)
	_check(_has_error(missing_result["errors"] as Array, "executor_params.missing"),
		"an incomplete parameter set must fail closed: %s" % [missing_result["errors"]])
	var sibling := (document as Dictionary).duplicate(true)
	sibling["executor_id"] = "weapon_ultimate.executor.soldier.soldier_rifle"
	(sibling["executor"] as Dictionary)["strategy_id"] = sibling["executor_id"]
	var sibling_result := Discovery.new().validate_pair(
		sibling, relative_path, executor, base_profiles["soldier/%s" % weapon_id]
	)
	_check(_has_error(sibling_result["errors"] as Array, "package.executor"),
		"a sibling executor identity must fail closed: %s" % [sibling_result["errors"]])


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
		print("soldier_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("soldier_package_test: %s" % error)
	print("soldier_package_test: FAIL (%d)" % _errors.size())
	quit(1)
