extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "biologist"
const WEAPONS := [
	"biologist_spore_lens",
	"biologist_sample_injector",
	"biologist_symbiote_seed",
]
const EXPECTED_CAPS := {
	"biologist_spore_lens": {"crowd_cap": 18, "secondary_bloom_cap": 3},
	"biologist_sample_injector": {
		"crowd_cap": 16, "analysis_pulses": 3, "sample_window": 10.0,
	},
	"biologist_symbiote_seed": {"crowd_cap": 22, "larva_count": 6},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(
		registry.package_validation_errors().is_empty(),
		"Biologist package discovery must be clean: %s" % [registry.package_validation_errors()]
	)
	var biologist_pairs: Array[String] = []
	for key in registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			biologist_pairs.append(key)
	_check(
		biologist_pairs == [
			"biologist/biologist_sample_injector",
			"biologist/biologist_spore_lens",
			"biologist/biologist_symbiote_seed",
		],
		"exactly the Biologist trio must be admitted, got %s" % [biologist_pairs]
	)
	for weapon_id in WEAPONS:
		_test_pair(registry, weapon_id)
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
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.09),
		"%s must keep the frozen 9%% whole-activation boss cap" % weapon_id)
	_check(executor is GDScript, "%s executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var constants := (executor as GDScript).get_script_constant_map()
	_check(
		str(constants.get("PROFILE_ID", "")) == "weapon_ultimate.profile.biologist.%s" % weapon_id,
		"%s PROFILE_ID must match the immutable catalog" % weapon_id
	)
	_check(
		str(constants.get("EXECUTOR_ID", "")) == "weapon_ultimate.executor.biologist.%s" % weapon_id,
		"%s EXECUTOR_ID must match the immutable catalog" % weapon_id
	)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	for key in (EXPECTED_CAPS[weapon_id] as Dictionary):
		_check(
			params.get(key) == (EXPECTED_CAPS[weapon_id] as Dictionary)[key],
			"%s must freeze %s=%s" % [weapon_id, key, (EXPECTED_CAPS[weapon_id] as Dictionary)[key]]
		)


func _test_fail_closed_mutation(registry: Registry) -> void:
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var weapon_id := "biologist_sample_injector"
	var relative_path := "biologist/%s.json" % weapon_id
	var data_path := "res://data/ultimates/classes/%s" % relative_path
	var document = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	var executor = load("res://scripts/ultimates/classes/biologist/%s.gd" % weapon_id)
	_check(document is Dictionary and executor is GDScript, "mutation fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["undeclared_power"] = 999.0
	var result := Discovery.new().validate_pair(
		mutated,
		relative_path,
		executor,
		base_profiles["biologist/%s" % weapon_id]
	)
	_check(
		_has_error(result["errors"] as Array, "executor_params.unknown"),
		"an undeclared parameter must fail closed: %s" % [result["errors"]]
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
		print("biologist_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("biologist_package_test: %s" % error)
	print("biologist_package_test: FAIL (%d)" % _errors.size())
	quit(1)
