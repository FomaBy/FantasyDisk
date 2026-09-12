extends SceneTree

# FAN-3934: focused regression for bounded lazy executor residency in the
# weapon-ultimate registry. Gates:
#   A. LAZY PARITY: lazy discovery admits the same pair set with the same
#      (zero) validation errors as eager discovery on the real catalog.
#   B. NON-RESIDENCY: before any admission, executor scripts other than the
#      resolved one are not resident in the resource cache.
#   C. FIRST-USE ADMISSION: registry.executor_for returns the same GDScript
#      the eager path admits, with parameter_contract/execute, and stays
#      cached (same instance) on repeated calls.
#   D. FAIL-CLOSED STABILITY: a fixture pair whose executor script fails
#      script-content admission returns null from admit_executor with stable,
#      non-empty errors on every call, while eager discovery rejects the same
#      fixture with the same core error.
#
# Запуск: Godot --headless --path . --script res://tests/p3_executor_residency_test.gd

const RegistryScript := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const DiscoveryScript := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

const FIXTURE_EXECUTOR_TEMPLATE := """const PROFILE_ID := "%s"
const EXECUTOR_ID := "%s"


static func parameter_contract() -> Dictionary:
	return {"duration": {"type": "float", "default": 1.0}}


static func execute(_activation) -> float:
	return 1.0
"""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var registry = RegistryScript.new(ProgressionData.WEAPONS_BY_CLASS)
	if not registry.is_valid():
		failures.append("lazy registry is not valid: %s" % str(registry.validation_errors()))
	var lazy_pair_count: int = registry.package_pair_keys().size()

	# B: non-residency must be checked BEFORE any eager discovery or admission
	# pollutes the script cache.
	var resident_before := 0
	for key in ["ranger/bow", "knight/sword", "priest/staff"]:
		if ResourceLoader.has_cached("res://scripts/ultimates/classes/%s.gd" % key):
			resident_before += 1
	if resident_before > 0:
		failures.append("%d untouched executor scripts are resident before any admission" % resident_before)

	# C: first-use admission through the registry (the controller's pre-charge
	# resolution point).
	var axe = registry.executor_for("berserk", "axe")
	if not axe is GDScript:
		failures.append("registry.executor_for(berserk, axe) did not return a GDScript")
	else:
		if not axe.has_method("parameter_contract") or not axe.has_method("execute"):
			failures.append("admitted executor lacks parameter_contract/execute")
		if registry.executor_for("berserk", "axe") != axe:
			failures.append("repeated executor_for returned a different instance — active-lifetime cache broken")

	# A: eager parity on the real catalog.
	var base_profiles := _base_profiles_from_documents(registry)
	var eager = DiscoveryScript.new()
	eager.discover(base_profiles, false)
	var lazy = DiscoveryScript.new()
	lazy.discover(base_profiles, true)
	var eager_errors: Array[String] = eager.validation_errors()
	var lazy_errors: Array[String] = lazy.validation_errors()
	if not eager_errors.is_empty():
		failures.append("eager discovery on the real catalog reported errors: %s" % str(eager_errors.slice(0, 3)))
	if not lazy_errors.is_empty():
		failures.append("lazy discovery on the real catalog reported errors: %s" % str(lazy_errors.slice(0, 3)))
	if eager.pair_keys().size() != lazy.pair_keys().size() \
			or eager.pair_keys().hash() != lazy.pair_keys().hash():
		failures.append("lazy pair set differs from eager: %d vs %d" % [lazy.pair_keys().size(), eager.pair_keys().size()])
	if lazy_pair_count != eager.pair_keys().size():
		failures.append("lazy registry pair count %d differs from eager discovery %d" % [lazy_pair_count, eager.pair_keys().size()])
	var eager_axe = eager.executor_for(Schema.profile_key("berserk", "axe"))
	if eager_axe != null and axe != null and eager_axe != axe:
		failures.append("lazy admission returned a different script than eager discovery")

	# D: fail-closed stability on a fixture with a mismatched EXECUTOR_ID.
	var fixture := _write_fixture("knight", "sword", "fixture_profile", "fixture_exec", "fixture_exec_WRONG")
	var fixture_discovery = DiscoveryScript.new(fixture.data_root, fixture.executor_root)
	var base := {
		"identity": {"profile_id": "fixture_profile"},
		"executor": {"executor_id": "fixture_exec"},
	}
	fixture_discovery.discover({"knight/sword": base}, true)
	if fixture_discovery.pair_keys().is_empty():
		failures.append("lazy fixture pair was rejected at document stage — script checks must be the deferred part")
	else:
		var admitted = fixture_discovery.admit_executor("knight/sword")
		if admitted != null:
			failures.append("broken fixture executor was admitted")
		var first_errors: Array[String] = fixture_discovery.admission_errors_for("knight/sword")
		if first_errors.is_empty():
			failures.append("failed fixture admission produced no errors")
		elif not str(first_errors[0]).contains("package.executor.EXECUTOR_ID"):
			failures.append("fixture admission error is %s, expected package.executor.EXECUTOR_ID" % str(first_errors[0]))
		fixture_discovery.admit_executor("knight/sword")
		var second_errors: Array[String] = fixture_discovery.admission_errors_for("knight/sword")
		if str(second_errors) != str(first_errors):
			failures.append("failed admission is not stable across repeated calls")
		# Eager parity for the same fixture: same core rejection.
		var eager_fixture = DiscoveryScript.new(fixture.data_root, fixture.executor_root)
		eager_fixture.discover({"knight/sword": base}, false)
		var eager_fixture_errors: Array[String] = eager_fixture.validation_errors()
		var has_core_error := false
		for error in eager_fixture_errors:
			if str(error).contains("package.executor.EXECUTOR_ID"):
				has_core_error = true
		if not has_core_error:
			failures.append("eager discovery did not reject the broken fixture with package.executor.EXECUTOR_ID")

	if failures.is_empty():
		print("P3_EXECUTOR_RESIDENCY_TEST PASS")
		quit(0)
	else:
		for failure in failures:
			printerr("P3_EXECUTOR_RESIDENCY_TEST FAIL: " + failure)
		quit(1)


func _base_profiles_from_documents(registry) -> Dictionary:
	var documents: Array = registry.documents_for_tests()
	var weapons: Dictionary = ProgressionData.WEAPONS_BY_CLASS
	var schema_errors: Array[String] = Schema.validate_documents(documents, weapons)
	if not schema_errors.is_empty():
		return {}
	return Schema.index_documents(documents)


func _write_fixture(class_id: String, weapon_id: String, profile_id: String, executor_id: String, script_executor_id: String) -> Dictionary:
	var root := "user://p3_residency_fixture"
	var data_root := "%s/data" % root
	var executor_root := "%s/executors" % root
	DirAccess.make_dir_recursive_absolute("%s/%s" % [data_root, class_id])
	DirAccess.make_dir_recursive_absolute("%s/%s" % [executor_root, class_id])
	var document := {
		"schema_version": Schema.EXPECTED_SCHEMA_VERSION,
		"class_id": class_id,
		"weapon_id": weapon_id,
		"profile_id": profile_id,
		"executor_id": executor_id,
		"implementation_state": "ready",
		"targeting": {"strategy_id": "fixture_targeting", "params": {}},
		"charge": {"strategy_id": "fixture_charge", "params": {}},
		"executor": {"strategy_id": executor_id, "params": {}},
		"total_boss_cap": 1.0,
		"cleanup_policy": {"strategy_id": "fixture_cleanup", "params": {}},
	}
	var data_file := FileAccess.open("%s/%s/%s.json" % [data_root, class_id, weapon_id], FileAccess.WRITE)
	data_file.store_string(JSON.stringify(document))
	data_file.close()
	var script_file := FileAccess.open("%s/%s/%s.gd" % [executor_root, class_id, weapon_id], FileAccess.WRITE)
	script_file.store_string(FIXTURE_EXECUTOR_TEMPLATE % [profile_id, script_executor_id])
	script_file.close()
	return {"data_root": data_root, "executor_root": executor_root}
