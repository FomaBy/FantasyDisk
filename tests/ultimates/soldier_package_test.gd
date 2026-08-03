extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPONS := ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]
const DATA_ROOT := "res://data/ultimates/staged/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/staged/classes"
const INVALID_DATA_ROOT := "res://tests/ultimates/fixtures/packages_invalid/data"
const INVALID_SCRIPT_ROOT := "res://tests/ultimates/fixtures/packages_invalid/scripts"
const EXPECTED := {
	"soldier_rifle": {"volley_count": 3, "target_limit": 3},
	"soldier_grenade": {"grenade_count": 7, "seed": 1469},
	"soldier_bayonet": {"rank_count": 3, "target_limit": 18},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var shipped := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(shipped.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(shipped.package_validation_errors().is_empty(),
		"shipped discovery must stay clean: %s" % [shipped.package_validation_errors()])
	var base_profiles := Schema.index_documents(shipped.documents_for_tests())
	var staged := Discovery.new(DATA_ROOT, SCRIPT_ROOT)
	staged.discover(base_profiles)
	_check(staged.validation_errors().is_empty(),
		"staged Soldier discovery must stay clean: %s" % [staged.validation_errors()])
	_check(staged.pair_keys() == {
		"soldier/soldier_bayonet": true,
		"soldier/soldier_grenade": true,
		"soldier/soldier_rifle": true,
	}, "staged discovery must admit only the three exact Soldier pairs")

	var staged_profiles := base_profiles.duplicate(true)
	var executor_paths := {}
	var parameter_signatures := {}
	for weapon_id in WEAPONS:
		var key := "%s/%s" % [CLASS_ID, weapon_id]
		_check(shipped.resolution_source(CLASS_ID, weapon_id)
			== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
			"%s must remain on the shipped legacy fallback" % weapon_id)
		_check(not shipped.has_exact_executor_pair(CLASS_ID, weapon_id),
			"%s must not enter the shipped executable package set" % weapon_id)
		_test_base_contract(base_profiles[key], weapon_id)
		_test_ready_pair(staged, weapon_id, executor_paths, parameter_signatures)
		staged_profiles[key] = staged.profile_for(key)
		_check(Resolver.resolution_source(
			staged_profiles, shipped.canonical_pairs_for_tests(), CLASS_ID, weapon_id, true,
			staged.pair_keys()
		) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must become executable only through the staged injection seam" % weapon_id)
	_test_negative_controls(staged, staged_profiles, base_profiles, shipped.canonical_pairs_for_tests())
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
	discovery: Discovery,
	weapon_id: String,
	executor_paths: Dictionary,
	parameter_signatures: Dictionary
) -> void:
	var profile := discovery.profile_for("%s/%s" % [CLASS_ID, weapon_id])
	var executor = discovery.executor_for("%s/%s" % [CLASS_ID, weapon_id])
	_check(str(profile.get("implementation_state", "")) == "ready",
		"%s staged overlay must be ready" % weapon_id)
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.09),
		"%s must use Soldier's immutable 9%% boss cap" % weapon_id)
	_check(executor is GDScript, "%s staged executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var path := (executor as GDScript).resource_path
	_check(path.begins_with(SCRIPT_ROOT + "/soldier/"),
		"%s executor must stay in the non-shipped staged root" % weapon_id)
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


func _test_negative_controls(
	discovery: Discovery,
	staged_profiles: Dictionary,
	base_profiles: Dictionary,
	canonical_pairs: Dictionary
) -> void:
	for pair in [
		[CLASS_ID, "soldier_rifle_alias"],
		["sniper", "soldier_grenade"],
	]:
		_check(Resolver.resolution_source(
			staged_profiles, canonical_pairs, str(pair[0]), str(pair[1]), true, discovery.pair_keys()
		) == Resolver.SOURCE_INVALID_PAIR,
			"%s/%s must fail closed" % [pair[0], pair[1]])

	var weapon_id := "soldier_grenade"
	var relative_path := "soldier/%s.json" % weapon_id
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		DATA_ROOT + "/" + relative_path
	))
	var executor = load(SCRIPT_ROOT + "/soldier/%s.gd" % weapon_id)
	_check(document is Dictionary and executor is GDScript, "staged negative fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var malformed := (document as Dictionary).duplicate(true)
	malformed["schema_version"] = 0
	_expect_pair_error(discovery, malformed, relative_path, executor,
		base_profiles["soldier/%s" % weapon_id], "package.schema_version")
	var incomplete := (document as Dictionary).duplicate(true)
	((incomplete["executor"] as Dictionary)["params"] as Dictionary).erase("grenade_count")
	_expect_pair_error(discovery, incomplete, relative_path, executor,
		base_profiles["soldier/%s" % weapon_id], "executor_params.missing")
	var sibling := (document as Dictionary).duplicate(true)
	sibling["executor_id"] = "weapon_ultimate.executor.soldier.soldier_rifle"
	(sibling["executor"] as Dictionary)["strategy_id"] = sibling["executor_id"]
	_expect_pair_error(discovery, sibling, relative_path, executor,
		base_profiles["soldier/%s" % weapon_id], "package.executor")
	var cross_class := (document as Dictionary).duplicate(true)
	cross_class["class_id"] = "sniper"
	_expect_pair_error(discovery, cross_class, relative_path, executor,
		base_profiles["soldier/%s" % weapon_id], "package.path_identity")

	var invalid := Discovery.new(INVALID_DATA_ROOT, INVALID_SCRIPT_ROOT)
	invalid.discover(base_profiles)
	_check(invalid.pair_keys().is_empty(), "orphaned and duplicate package fixtures must admit no pair")
	for prefix in ["package.pair.duplicate", "package.pair.executor_missing", "package.pair.data_missing"]:
		_check(_has_error(invalid.validation_errors(), prefix),
			"%s must fail closed: %s" % [prefix, invalid.validation_errors()])


func _expect_pair_error(
	discovery: Discovery,
	document: Dictionary,
	relative_path: String,
	executor,
	base_profile: Dictionary,
	prefix: String
) -> void:
	var result := discovery.validate_pair(document, relative_path, executor, base_profile)
	_check(_has_error(result["errors"] as Array, prefix),
		"invalid staged pair must reject with %s: %s" % [prefix, result["errors"]])


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
