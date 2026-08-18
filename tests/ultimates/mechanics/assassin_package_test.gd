extends SceneTree

const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "assassin"
const WEAPONS := ["chakrams", "shadow_daggers", "venom_wire"]
const EXPECTED := {
	"chakrams": {"return_steps": 6, "execute_threshold": 0.25},
	"shadow_daggers": {"backstab_waves": 7, "untargetable_duration": 1.75},
	"venom_wire": {"cut_pulses": 3, "max_cuts_per_pulse": 3},
}

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(registry.package_validation_errors().is_empty(),
		"Assassin package discovery must be clean: %s" % [registry.package_validation_errors()])
	var pairs: Array[String] = []
	for key in registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			pairs.append(key)
	pairs.sort()
	_check(pairs == ["assassin/chakrams", "assassin/shadow_daggers", "assassin/venom_wire"],
		"exactly the Assassin trio must be admitted, got %s" % [pairs])
	for weapon_id in WEAPONS:
		_test_pair(registry, weapon_id)
	_test_distinct_and_class_local(registry)
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
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.08),
		"%s must keep the frozen 8%% whole-activation boss cap" % weapon_id)
	_check(executor is GDScript, "%s executor must load" % weapon_id)
	if not executor is GDScript:
		return
	var constants := (executor as GDScript).get_script_constant_map()
	_check(str(constants.get("PROFILE_ID", "")) == "weapon_ultimate.profile.assassin.%s" % weapon_id,
		"%s PROFILE_ID must match the immutable catalog" % weapon_id)
	_check(str(constants.get("EXECUTOR_ID", "")) == "weapon_ultimate.executor.assassin.%s" % weapon_id,
		"%s EXECUTOR_ID must match the immutable catalog" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	for key in (EXPECTED[weapon_id] as Dictionary):
		_check(params.get(key) == (EXPECTED[weapon_id] as Dictionary)[key],
			"%s must freeze %s=%s" % [weapon_id, key, (EXPECTED[weapon_id] as Dictionary)[key]])
	var scene = load("res://scripts/ultimates/classes/assassin/%s.tscn" % weapon_id)
	_check(scene is PackedScene, "%s mechanics scene must load" % weapon_id)
	if scene is PackedScene:
		var instance := (scene as PackedScene).instantiate()
		var presentation := instance.get_node_or_null("Presentation")
		_check(presentation != null, "%s must embed its accepted presentation scene" % weapon_id)
		if presentation != null:
			_check(str(presentation.get_meta("ultimate_id", "")) == "assassin/%s" % weapon_id,
				"%s presentation must retain its exact profile key" % weapon_id)
		instance.free()


func _test_distinct_and_class_local(registry: Registry) -> void:
	var executor_paths := {}
	var signatures := {}
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var executor = registry.executor_for(CLASS_ID, weapon_id)
		var path := (executor as GDScript).resource_path if executor is GDScript else ""
		_check(not executor_paths.has(path), "%s must own a distinct executor" % weapon_id)
		executor_paths[path] = true
		var signature := JSON.stringify((profile["executor"] as Dictionary)["params"], "", true)
		_check(not signatures.has(signature), "%s must own distinct mechanics parameters" % weapon_id)
		signatures[signature] = true
	for raw_class_id in PD.WEAPONS_BY_CLASS:
		var class_id := str(raw_class_id)
		if class_id == CLASS_ID:
			continue
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary):
			var weapon_id := str(raw_weapon_id)
			var expected := Resolver.SOURCE_WEAPON_PROFILE \
				if registry.has_exact_executor_pair(class_id, weapon_id) \
				else Resolver.SOURCE_LEGACY_CLASS_FALLBACK
			_check(registry.resolution_source(class_id, weapon_id) == expected,
				"%s/%s routing must not change" % [class_id, weapon_id])


func _test_fail_closed_mutation(registry: Registry) -> void:
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var path := "assassin/chakrams.json"
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/%s" % path
	))
	var executor = load("res://scripts/ultimates/classes/assassin/chakrams.gd")
	_check(document is Dictionary and executor is GDScript, "mutation fixture must load")
	if not document is Dictionary or not executor is GDScript:
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["ninth_moon"] = true
	var result := Discovery.new().validate_pair(mutated, path, executor, base_profiles["assassin/chakrams"])
	_check(_has_error(result["errors"] as Array, "executor_params.unknown"),
		"undeclared mechanics power must fail closed: %s" % [result["errors"]])


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
		print("assassin_package_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("assassin_package_test: %s" % error)
	print("assassin_package_test: FAIL (%d)" % _errors.size())
	quit(1)
