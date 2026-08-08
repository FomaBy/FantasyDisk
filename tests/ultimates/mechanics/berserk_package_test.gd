extends SceneTree

## FAN-2131: the three Berserk packages are admitted as exact ready pairs, the
## immutable catalog entry stays `declared`/`unbound` under the overlay, and the
## shared executor library keeps exactly its seven families.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/berserk_package_test.gd

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "berserk"
const WEAPONS := ["sword", "axe", "hammer"]
const CATALOG_PATH := "res://data/ultimates/schema/v1/classes/berserk.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/berserk/manifest.json"
const EXPECTED_FAMILIES := [
	"aimed_sequence",
	"burst",
	"chained_projectile",
	"control",
	"deploy_summon",
	"status_zone",
	"timed_modifier",
]
const EXPECTED := {
	"sword": {"blade_count": 3, "sweep_count": 11, "crowd_cap": 24, "lifetime": 7.45},
	"axe": {"boss_pass_cap": 2, "crowd_cap": 18, "lifetime": 5.85},
	"hammer": {"crowd_cap": 20, "lifetime": 3.4},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(registry.package_validation_errors().is_empty(),
		"Berserk package discovery must be clean: %s" % [registry.package_validation_errors()])
	var berserk_pairs: Array[String] = []
	for key in registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			berserk_pairs.append(key)
	berserk_pairs.sort()
	_check(berserk_pairs == ["berserk/axe", "berserk/hammer", "berserk/sword"],
		"exactly the Berserk trio must be admitted, got %s" % [berserk_pairs])
	for weapon_id in WEAPONS:
		_test_pair(registry, weapon_id)
	_test_catalog_untouched()
	_test_authorized_manifest(registry)
	_test_shared_library_untouched()
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
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.1),
		"%s must keep the frozen 10%% whole-activation Berserk boss cap" % weapon_id)
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"%s must declare the one-activation-per-encounter charge ledger" % weapon_id)
	_check(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
		"%s must keep activation-owned cleanup" % weapon_id)
	_check(executor is GDScript, "%s executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var constants := (executor as GDScript).get_script_constant_map()
	_check(str(constants.get("PROFILE_ID", "")) == "weapon_ultimate.profile.berserk.%s" % weapon_id,
		"%s PROFILE_ID must match the immutable catalog" % weapon_id)
	_check(str(constants.get("EXECUTOR_ID", "")) == "weapon_ultimate.executor.berserk.%s" % weapon_id,
		"%s EXECUTOR_ID must match the immutable catalog" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	for key in (EXPECTED[weapon_id] as Dictionary):
		var expected = (EXPECTED[weapon_id] as Dictionary)[key]
		_check(is_equal_approx(float(params.get(key, -1.0)), float(expected)),
			"%s must freeze %s=%s, got %s" % [weapon_id, key, expected, params.get(key)])


## The package is an overlay: the immutable schema-v1 catalog entry stays
## `declared`/`unbound` exactly as FAN-1477 left elementalist.
func _test_catalog_untouched() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_check(parsed is Dictionary, "the Berserk catalog document must parse")
	if not parsed is Dictionary:
		return
	for raw_profile in (parsed as Dictionary).get("profiles", []) as Array:
		var profile := raw_profile as Dictionary
		var weapon_id := str(profile.get("weapon_id", ""))
		_check(str(profile.get("implementation_state", "")) == "declared",
			"catalog %s must stay declared" % weapon_id)
		for binding in ["targeting", "charge", "executor", "cleanup_policy"]:
			_check(str((profile.get(binding, {}) as Dictionary).get("strategy_id", "")) == "unbound",
				"catalog %s.%s must stay unbound" % [weapon_id, binding])


## Each executor lifetime and crowd cap is read back from the authorized
## presentation manifest instead of being duplicated as a literal here, so a
## drift on either side reddens rather than quietly diverging.
func _test_authorized_manifest(registry: Registry) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(parsed is Dictionary, "the authorized Berserk manifest must parse")
	if not parsed is Dictionary:
		return
	var seen := {}
	for raw_weapon in (parsed as Dictionary).get("weapons", []) as Array:
		var weapon := raw_weapon as Dictionary
		var weapon_id := str(weapon.get("weapon_id", ""))
		seen[weapon_id] = true
		var params := (registry.catalog_profile_for(CLASS_ID, weapon_id)["executor"] \
			as Dictionary)["params"] as Dictionary
		var timing := weapon.get("timing_seconds", {}) as Dictionary
		_check(is_equal_approx(float(params.get("lifetime", -1.0)), float(timing.get("recovery", 0.0))),
			"%s lifetime must equal the authorized recovery %s, got %s" % [
				weapon_id, timing.get("recovery"), params.get("lifetime"),
			])
		var performance := weapon.get("performance", {}) as Dictionary
		_check(int(params.get("crowd_cap", -1)) == int(performance.get("crowd_cap", 0)),
			"%s crowd cap must equal the authorized %s" % [weapon_id, performance.get("crowd_cap")])
	for weapon_id in WEAPONS:
		_check(seen.has(weapon_id), "the manifest must authorize %s" % weapon_id)


## No Berserk primitive was pushed into the shared library: the audited family
## set is still exactly the seven central executors.
func _test_shared_library_untouched() -> void:
	var families := Library.strategy_ids()
	_check(families == EXPECTED_FAMILIES,
		"the shared executor library must keep exactly its seven families, got %s" % [families])


func _test_fail_closed_mutation(registry: Registry) -> void:
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var weapon_id := "hammer"
	var relative_path := "%s/%s.json" % [CLASS_ID, weapon_id]
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/%s" % relative_path
	))
	var executor = load("res://scripts/ultimates/classes/%s/%s.gd" % [CLASS_ID, weapon_id])
	_check(document is Dictionary and executor is GDScript, "mutation fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["unbounded_rift"] = 99
	var result := Discovery.new().validate_pair(
		mutated, relative_path, executor, base_profiles["%s/%s" % [CLASS_ID, weapon_id]]
	)
	_check(_has_error(result["errors"] as Array, "executor_params.unknown"),
		"an undeclared parameter must fail closed: %s" % [result["errors"]])

	var declared := (document as Dictionary).duplicate(true)
	declared["implementation_state"] = "declared"
	var declared_result := Discovery.new().validate_pair(
		declared, relative_path, executor, base_profiles["%s/%s" % [CLASS_ID, weapon_id]]
	)
	_check(_has_error(declared_result["errors"] as Array, "package.implementation_state"),
		"a non-ready package must fail closed: %s" % [declared_result["errors"]])


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
		print("berserk_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("berserk_package_test: %s" % error)
	quit(1)
