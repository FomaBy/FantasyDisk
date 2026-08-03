extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "dark_mage"
const WEAPONS := ["dark_book", "cursed_skull", "dark_wand"]
const EXPECTED_CAPS := {
	"dark_book": {"crowd_cap": 12, "reflection_cap": 2, "kill_burst_cap": 3},
	"cursed_skull": {"crowd_cap": 14, "transfer_cap": 8, "pulse_count": 4},
	"dark_wand": {"chain_cap": 10, "half_width": 72.0, "per_target_cap_fraction": 0.65},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(registry.package_validation_errors().is_empty(),
		"Dark Mage package discovery must be clean: %s" % [registry.package_validation_errors()])
	var pairs: Array[String] = []
	for key in registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			pairs.append(key)
	pairs.sort()
	_check(pairs == ["dark_mage/cursed_skull", "dark_mage/dark_book", "dark_mage/dark_wand"],
		"exactly the Dark Mage trio must be admitted, got %s" % [pairs])
	for weapon_id in WEAPONS:
		_test_pair(registry, weapon_id)
	_test_no_cross_class_leakage(registry)
	_test_fail_closed_mutation(registry)
	_report()


func _test_pair(registry: Registry, weapon_id: String) -> void:
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready package" % weapon_id)
	_check(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must own one exact executor pair" % weapon_id)
	var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
	var executor = registry.executor_for(CLASS_ID, weapon_id)
	_check(str(profile.get("implementation_state", "")) == "ready", "%s must be ready" % weapon_id)
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"%s must consume the shared rare-charge ledger" % weapon_id)
	_check(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
		"%s must use activation-owned cleanup" % weapon_id)
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.11),
		"%s must retain Dark Mage's 11%% whole-activation boss cap" % weapon_id)
	_check(executor is GDScript, "%s executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var constants := (executor as GDScript).get_script_constant_map()
	_check(str(constants.get("PROFILE_ID", "")) == "weapon_ultimate.profile.dark_mage.%s" % weapon_id,
		"%s PROFILE_ID must match the immutable catalog" % weapon_id)
	_check(str(constants.get("EXECUTOR_ID", "")) == "weapon_ultimate.executor.dark_mage.%s" % weapon_id,
		"%s EXECUTOR_ID must match the immutable catalog" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	for key in (EXPECTED_CAPS[weapon_id] as Dictionary):
		_check(params.get(key) == (EXPECTED_CAPS[weapon_id] as Dictionary)[key],
			"%s must freeze %s=%s" % [weapon_id, key, (EXPECTED_CAPS[weapon_id] as Dictionary)[key]])


func _test_no_cross_class_leakage(registry: Registry) -> void:
	var executors := {}
	var signatures := {}
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var executor = registry.executor_for(CLASS_ID, weapon_id)
		var path := (executor as GDScript).resource_path if executor is GDScript else ""
		_check(not executors.has(path), "%s must own a distinct executor" % weapon_id)
		executors[path] = weapon_id
		var signature := JSON.stringify((profile["executor"] as Dictionary)["params"], "", true)
		_check(not signatures.has(signature), "%s must own a distinct parameter contract" % weapon_id)
		signatures[signature] = weapon_id
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		if class_id == CLASS_ID:
			continue
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			var weapon_id := str(raw_weapon_id)
			var expected := Resolver.SOURCE_WEAPON_PROFILE \
				if registry.has_exact_executor_pair(class_id, weapon_id) \
				else Resolver.SOURCE_LEGACY_CLASS_FALLBACK
			_check(registry.resolution_source(class_id, weapon_id) == expected,
				"%s/%s routing must not change with the Dark Mage packages" % [class_id, weapon_id])


func _test_fail_closed_mutation(registry: Registry) -> void:
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var weapon_id := "dark_wand"
	var relative_path := "dark_mage/%s.json" % weapon_id
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/%s" % relative_path
	))
	var executor = load("res://scripts/ultimates/classes/dark_mage/%s.gd" % weapon_id)
	_check(document is Dictionary and executor is GDScript, "mutation fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["undeclared_power"] = 999.0
	var result := Discovery.new().validate_pair(
		mutated, relative_path, executor, base_profiles["dark_mage/%s" % weapon_id]
	)
	_check(_has_error(result["errors"] as Array, "executor_params.unknown"),
		"an undeclared parameter must fail closed: %s" % [result["errors"]])


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
		print("dark_mage_ultimate_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("dark_mage_ultimate_package_test: %s" % error)
	print("dark_mage_ultimate_package_test: FAIL (%d)" % _errors.size())
	quit(1)
