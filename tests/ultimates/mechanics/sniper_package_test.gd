extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "sniper"
const WEAPONS := [
	"sniper_deadeye_rifle",
	"sniper_spotter_scope",
	"sniper_shatter_rounds",
]
const EXPECTED_PARAMS := {
	"sniper_deadeye_rifle": {"arena_radius": 100000.0, "headshot_multiplier": 1.5},
	"sniper_spotter_scope": {"arena_radius": 100000.0, "pulse_count": 9},
	"sniper_shatter_rounds": {"arena_radius": 100000.0, "wave_count": 5},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(
		registry.package_validation_errors().is_empty(),
		"Sniper package discovery must be clean: %s" % [registry.package_validation_errors()]
	)
	var sniper_pairs: Array[String] = []
	for key in registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			sniper_pairs.append(key)
	sniper_pairs.sort()
	_check(
		sniper_pairs == [
			"sniper/sniper_deadeye_rifle",
			"sniper/sniper_shatter_rounds",
			"sniper/sniper_spotter_scope",
		],
		"exactly the Sniper trio must be admitted, got %s" % [sniper_pairs]
	)
	for weapon_id in WEAPONS:
		_test_pair(registry, weapon_id)
	_test_no_cross_class_leakage(registry)
	_test_fail_closed_mutation(registry)
	_report()


func _test_pair(registry: Registry, weapon_id: String) -> void:
	_check(
		registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready package" % weapon_id
	)
	_check(
		registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must own one exact executor pair" % weapon_id
	)
	var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
	var executor = registry.executor_for(CLASS_ID, weapon_id)
	_check(str(profile.get("implementation_state", "")) == "ready", "%s must be ready" % weapon_id)
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.10),
		"%s must keep the frozen 10%% whole-activation boss cap" % weapon_id)
	_check(executor is GDScript, "%s executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var constants := (executor as GDScript).get_script_constant_map()
	_check(
		str(constants.get("PROFILE_ID", "")) == "weapon_ultimate.profile.sniper.%s" % weapon_id,
		"%s PROFILE_ID must match the immutable catalog" % weapon_id
	)
	_check(
		str(constants.get("EXECUTOR_ID", "")) == "weapon_ultimate.executor.sniper.%s" % weapon_id,
		"%s EXECUTOR_ID must match the immutable catalog" % weapon_id
	)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	for key in (EXPECTED_PARAMS[weapon_id] as Dictionary):
		_check(
			params.get(key) == (EXPECTED_PARAMS[weapon_id] as Dictionary)[key],
			"%s must freeze %s=%s" % [weapon_id, key, (EXPECTED_PARAMS[weapon_id] as Dictionary)[key]]
		)


## Three exact weapon IDs, three distinct executable contracts: no parameter
## dictionary, executor script or catalog identity may be shared, and no sibling
## Sniper or foreign class pair may be dragged out of legacy fallback.
func _test_no_cross_class_leakage(registry: Registry) -> void:
	var executors := {}
	var signatures := {}
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var executor = registry.executor_for(CLASS_ID, weapon_id)
		var executor_path := (executor as GDScript).resource_path if executor is GDScript else ""
		_check(not executors.has(executor_path), "%s must own a distinct executor" % weapon_id)
		executors[executor_path] = weapon_id
		var signature := JSON.stringify((profile["executor"] as Dictionary)["params"], "", true)
		_check(not signatures.has(signature), "%s must own a distinct parameter contract" % weapon_id)
		signatures[signature] = weapon_id
		_check(
			str((profile["executor"] as Dictionary)["strategy_id"])
				== "weapon_ultimate.executor.sniper.%s" % weapon_id,
			"%s must bind its own executor identity" % weapon_id
		)
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		if class_id == CLASS_ID:
			continue
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			var weapon_id := str(raw_weapon_id)
			var expected := Resolver.SOURCE_WEAPON_PROFILE \
				if registry.has_exact_executor_pair(class_id, weapon_id) \
				else Resolver.SOURCE_LEGACY_CLASS_FALLBACK
			_check(
				registry.resolution_source(class_id, weapon_id) == expected,
				"%s/%s routing must not change with the Sniper packages" % [class_id, weapon_id]
			)


func _test_fail_closed_mutation(registry: Registry) -> void:
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var weapon_id := "sniper_spotter_scope"
	var relative_path := "sniper/%s.json" % weapon_id
	var data_path := "res://data/ultimates/classes/%s" % relative_path
	var document = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	var executor = load("res://scripts/ultimates/classes/sniper/%s.gd" % weapon_id)
	_check(document is Dictionary and executor is GDScript, "mutation fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["undeclared_power"] = 999.0
	var result := Discovery.new().validate_pair(
		mutated,
		relative_path,
		executor,
		base_profiles["sniper/%s" % weapon_id]
	)
	_check(
		_has_error(result["errors"] as Array, "executor_params.unknown"),
		"an undeclared parameter must fail closed: %s" % [result["errors"]]
	)
	var foreign := (document as Dictionary).duplicate(true)
	foreign["executor_id"] = "weapon_ultimate.executor.sniper.sniper_deadeye_rifle"
	(foreign["executor"] as Dictionary)["strategy_id"] = foreign["executor_id"]
	var foreign_result := Discovery.new().validate_pair(
		foreign,
		relative_path,
		executor,
		base_profiles["sniper/%s" % weapon_id]
	)
	_check(
		_has_error(foreign_result["errors"] as Array, "package.executor"),
		"a sibling executor identity must fail closed: %s" % [foreign_result["errors"]]
	)


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
		print("sniper_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("sniper_package_test: %s" % error)
	print("sniper_package_test: FAIL (%d)" % _errors.size())
	quit(1)
