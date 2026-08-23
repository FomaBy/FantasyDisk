extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "doctor"
const WEAPONS := ["restore_potion", "plague_syringe", "bone_saw"]

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "immutable catalog must remain valid")
	_check(registry.package_validation_errors().is_empty(), "Doctor package must validate")
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must resolve through its exact package" % weapon_id)
		_check(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
			"%s must have a paired executor" % weapon_id)
		_check(str(profile.get("implementation_state", "")) == "ready", "%s must be ready" % weapon_id)
		_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
			"%s must retain the U3 rare-charge contract" % weapon_id)
		_check(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
			"%s must use activation-owned cleanup" % weapon_id)
		_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.08),
			"%s must retain the 8%% whole-activation boss cap" % weapon_id)
		var executor = registry.executor_for(CLASS_ID, weapon_id)
		_check(executor is GDScript, "%s executor must load" % weapon_id)
		if executor is GDScript:
			var constants := (executor as GDScript).get_script_constant_map()
			_check(str(constants.get("PROFILE_ID", "")) == "weapon_ultimate.profile.doctor.%s" % weapon_id,
				"%s PROFILE_ID must match the frozen declaration" % weapon_id)
			if weapon_id == "restore_potion":
				var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
				var contract: Dictionary = (executor as GDScript).parameter_contract()
				_check(not params.has("target_cap") and not contract.has("target_cap"),
					"Life and Death must not carry a count-shaped target cap")
	_test_fail_closed(registry)
	_report()


func _test_fail_closed(registry: Registry) -> void:
	var base := Schema.index_documents(registry.documents_for_tests())
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/doctor/restore_potion.json"))
	var executor = load("res://scripts/ultimates/classes/doctor/restore_potion.gd")
	if not document is Dictionary or not executor is GDScript:
		_check(false, "mutation fixture must load")
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["unbounded_damage"] = 999.0
	var result := Discovery.new().validate_pair(mutated, "doctor/restore_potion.json", executor,
		base["doctor/restore_potion"])
	_check(_has_error(result["errors"] as Array, "executor_params.unknown"),
		"unknown package parameters must fail closed")


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
		print("doctor_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("doctor_package_test: %s" % error)
	quit(1)
