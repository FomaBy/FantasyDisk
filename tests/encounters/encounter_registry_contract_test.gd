extends SceneTree

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const SCRIPT_PATH := "res://scripts/encounters/features/marked_target_feature.gd"

var errors: Array[String] = []


func _initialize() -> void:
	_check_production_registry()
	_check_enabled_and_sorted_discovery()
	_check_fail_closed_entries()
	_check_copy_isolation()
	CONFIG._reset_cache_for_tests()
	CONFIG.clear_enabled_override()
	if not errors.is_empty():
		for error in errors:
			push_error("encounter-registry: " + error)
		quit(1)
		return
	print("FAN-2022 encounter registry contract passed.")
	quit(0)


func _definition(feature_id: String, enabled := true, primary := false) -> Dictionary:
	return {
		"schema_version": CONFIG.CONTRACT_VERSION,
		"id": feature_id,
		"type": CONFIG.FEATURE_TYPE,
		"enabled": enabled,
		"primary": primary,
		"capabilities": ["primary_beat"] if primary else [],
		"script": SCRIPT_PATH,
	}


func _catalog(definitions: Array) -> Dictionary:
	return {
		"schema_version": CONFIG.CONTRACT_VERSION,
		"contract": CONFIG.CONTRACT,
		"enabled": false,
		"feature_roots": [],
		"beats": definitions,
	}


func _check_production_registry() -> void:
	CONFIG._reset_cache_for_tests()
	CONFIG.clear_enabled_override()
	var features := CONFIG.all_features()
	var marked := features.filter(func(entry): return str(entry.get("id", "")) == "marked_target")
	_expect(marked.size() == 1, "production registry must expose marked_target exactly once")
	if marked.size() == 1:
		_expect(bool(marked[0].get("enabled", false)), "marked_target definition must be explicitly enabled")
	_expect(not CONFIG.is_enabled(), "global encounter package must remain default-off")


func _check_enabled_and_sorted_discovery() -> void:
	var definitions := [
		_definition("zulu_probe", false),
		_definition("alpha_probe", true),
		_definition("marked_target", true, true),
	]
	CONFIG._set_catalog_for_tests(_catalog(definitions))
	var validated := CONFIG.all_features()
	var ids := validated.map(func(entry): return str(entry["id"]))
	_expect(ids == ["alpha_probe", "marked_target", "zulu_probe"], "definitions must be sorted by id")
	var enabled_ids := CONFIG.enabled_features() \
		.map(func(entry): return str(entry["id"]))
	_expect(enabled_ids == ["alpha_probe", "marked_target"], "only explicit enabled=true definitions may execute")


func _check_fail_closed_entries() -> void:
	var duplicate_a := _definition("duplicate_probe")
	var duplicate_b := _definition("duplicate_probe")
	_expect(CONFIG._validated_feature_definitions_for_tests([duplicate_a, duplicate_b]).is_empty(),
		"all duplicate ids must be rejected")

	var unknown_type := _definition("unknown_type")
	unknown_type["type"] = "mystery"
	var string_schema := _definition("string_schema")
	string_schema["schema_version"] = "1"
	var foreign_path := _definition("foreign_path")
	foreign_path["script"] = "res://scripts/main.gd"
	var missing_resource := _definition("missing_resource")
	missing_resource["script"] = "res://scripts/encounters/features/missing_feature.gd"
	var non_bool_enabled := _definition("non_bool")
	non_bool_enabled["enabled"] = 1
	for invalid in [unknown_type, string_schema, foreign_path, missing_resource, non_bool_enabled]:
		_expect(CONFIG._validated_feature_definitions_for_tests([invalid]).is_empty(),
			"invalid definition must fail closed: %s" % str(invalid.get("id", "?")))

	var valid := _definition("valid_sibling")
	var mixed := CONFIG._validated_feature_definitions_for_tests([missing_resource, valid])
	_expect(mixed.size() == 1 and str(mixed[0].get("id", "")) == "valid_sibling",
		"a malformed sibling must never activate but may not hide an unrelated valid id")


func _check_copy_isolation() -> void:
	var source := _definition("copy_probe")
	CONFIG._set_catalog_for_tests(_catalog([source]))
	var first := CONFIG.all_features()
	first[0]["id"] = "mutated"
	var second := CONFIG.all_features()
	_expect(str(second[0].get("id", "")) == "copy_probe", "registry results must be deep-copy isolated")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
