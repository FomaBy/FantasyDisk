class_name WeaponUltimatePackageDiscovery
extends RefCounted

## Convention-only discovery for class-local weapon implementations.
##
## A package is executable only when one JSON overlay and one GDScript executor
## occupy the identical relative path below their respective roots. Invalid,
## orphaned, duplicated, or incomplete pairs are omitted without weakening the
## immutable 51-profile base catalog.

const DATA_ROOT := "res://data/ultimates/classes"
const EXECUTOR_ROOT := "res://scripts/ultimates/classes"
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const DOCUMENT_FIELDS := [
	"schema_version",
	"class_id",
	"weapon_id",
	"profile_id",
	"executor_id",
	"implementation_state",
	"targeting",
	"charge",
	"executor",
	"total_boss_cap",
	"cleanup_policy",
]
const BINDING_FIELDS := ["strategy_id", "params"]
const BINDING_NAMES := ["targeting", "charge", "executor", "cleanup_policy"]
## Class-owned data files that live beside the weapon overlays but are not
## packages. Only these exact names are skipped; any other JSON without an
## executor is still an orphan (FAN-3910).
const RESERVED_DATA_FILES: Array[String] = ["presentation_adoption.json"]

var _data_root: String
var _executor_root: String
var _profiles_by_key: Dictionary = {}
var _executors_by_key: Dictionary = {}
var _pair_keys: Dictionary = {}
var _errors: Array[String] = []
# FAN-3934 lazy residency: in lazy mode discovery defers ONLY the executor
# script load/admission; documents, pairing and orphan detection stay eager.
var _lazy_executors := false
var _documents_by_key: Dictionary = {}
var _document_paths_by_key: Dictionary = {}
var _base_profiles := {}
var _admitted_executors: Dictionary = {}
var _admission_errors_by_key: Dictionary = {}


func _init(data_root := DATA_ROOT, executor_root := EXECUTOR_ROOT) -> void:
	_data_root = data_root
	_executor_root = executor_root


func discover(base_profiles: Dictionary, lazy_executors := false) -> void:
	_lazy_executors = lazy_executors
	_base_profiles = base_profiles
	_documents_by_key.clear()
	_document_paths_by_key.clear()
	_admitted_executors.clear()
	_profiles_by_key.clear()
	_executors_by_key.clear()
	_pair_keys.clear()
	_errors.clear()
	var data_files: Array[String] = []
	for relative_path in _relative_files(_data_root, ".json"):
		if not is_reserved_data_file(relative_path):
			data_files.append(relative_path)
	var executor_files := _relative_files(_executor_root, ".gd")
	var executor_set := {}
	for relative_path in executor_files:
		executor_set[relative_path] = true
	var matched_executors := {}
	var seen_keys := {}
	var rejected_keys := {}
	for data_relative in data_files:
		var executor_relative := data_relative.trim_suffix(".json") + ".gd"
		if not executor_set.has(executor_relative):
			_errors.append("package.pair.executor_missing: %s" % data_relative)
			continue
		matched_executors[executor_relative] = true
		var source_path := "%s/%s" % [_data_root, data_relative]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		if not parsed is Dictionary:
			_errors.append("package.data.parse: %s" % data_relative)
			continue
		var document := (parsed as Dictionary).duplicate(true)
		var key := Schema.profile_key(
			str(document.get("class_id", "")), str(document.get("weapon_id", ""))
		)
		if seen_keys.has(key):
			rejected_keys[key] = true
			_profiles_by_key.erase(key)
			_executors_by_key.erase(key)
			_pair_keys.erase(key)
			_errors.append("package.pair.duplicate: %s" % key)
			continue
		seen_keys[key] = true
		var executor_path := "%s/%s" % [_executor_root, executor_relative]
		if lazy_executors:
			# Script-free admission: identical document/pair validation, script
			# checks and param normalization deferred to admit_executor().
			var document_result := validate_document(document, data_relative, base_profiles.get(key, {}))
			var document_errors := document_result.get("errors", []) as Array
			if not document_errors.is_empty():
				for error in document_errors:
					_errors.append("%s: %s" % [data_relative, str(error)])
				continue
			_documents_by_key[key] = document
			_document_paths_by_key[key] = {"path": executor_path, "relative": executor_relative, "data_relative": data_relative}
			_profiles_by_key[key] = (document_result["profile"] as Dictionary).duplicate(true)
			_pair_keys[key] = true
			continue
		var executor_script = load(executor_path)
		var result := validate_pair(
			document, data_relative, executor_script, base_profiles.get(key, {})
		)
		var pair_errors := result.get("errors", []) as Array
		if not pair_errors.is_empty():
			for error in pair_errors:
				_errors.append("%s: %s" % [data_relative, str(error)])
			continue
		_profiles_by_key[key] = (result["profile"] as Dictionary).duplicate(true)
		_executors_by_key[key] = executor_script
		_pair_keys[key] = true
	for executor_relative in executor_files:
		if not matched_executors.has(executor_relative):
			_errors.append("package.pair.data_missing: %s" % executor_relative)
	for raw_key in rejected_keys.keys():
		var key := str(raw_key)
		_profiles_by_key.erase(key)
		_executors_by_key.erase(key)
		_pair_keys.erase(key)


## FAN-3934 lazy residency: resolve, validate and cache ONE executor script on
## first demand. Runs the exact same script-content admission as eager
## validate_pair (constants, method signatures, param normalization) and is
## stable: a failed admission is remembered and returns the same result on
## every later call. Returns the admitted GDScript or null.
func admit_executor(key: String):
	if not _lazy_executors:
		return _executors_by_key.get(key)
	if _admitted_executors.has(key):
		return _admitted_executors[key]
	if not _document_paths_by_key.has(key):
		return null
	var record: Dictionary = _document_paths_by_key[key]
	var executor_script = load(str(record["path"]))
	var result := validate_pair(
		_documents_by_key[key], str(record["data_relative"]), executor_script, _base_profiles.get(key, {})
	)
	var pair_errors := result.get("errors", []) as Array
	if not pair_errors.is_empty():
		var errors: Array[String] = []
		for error in pair_errors:
			errors.append("%s: %s" % [str(record["data_relative"]), str(error)])
		_admission_errors_by_key[key] = errors
		_admitted_executors[key] = null
		return null
	_admission_errors_by_key.erase(key)
	_profiles_by_key[key] = (result["profile"] as Dictionary).duplicate(true)
	_executors_by_key[key] = executor_script
	_admitted_executors[key] = executor_script
	return executor_script


## Errors from the failed lazy admit_executor() for a key (empty when the key
## was never admitted or admitted successfully). Stable across calls.
func admission_errors_for(key: String) -> Array[String]:
	var stored = _admission_errors_by_key.get(key)
	return (stored as Array[String]).duplicate() if stored is Array[String] else []


## True while discovery runs in lazy-executor mode (FAN-3934).
func is_lazy() -> bool:
	return _lazy_executors


## Public validation seam keeps tooling and fixture tests on the exact same
## admission path used by recursive discovery.
## FAN-3934 lazy residency: the script-free stage of validate_pair — every
## document/base/binding check with identical error strings. validate_pair
## delegates to this stage so eager and lazy admission share one code path.
func validate_document(
	document: Dictionary,
	relative_path: String,
	base_profile: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	_validate_exact_fields(document, DOCUMENT_FIELDS, "package.data", errors)
	var schema_version = document.get("schema_version")
	if not (schema_version is int or schema_version is float) or schema_version is bool \
			or not is_finite(float(schema_version)) \
			or floor(float(schema_version)) != float(schema_version) \
			or int(schema_version) != Schema.EXPECTED_SCHEMA_VERSION:
		errors.append("package.schema_version")
	for field in ["class_id", "weapon_id", "profile_id", "executor_id", "implementation_state"]:
		if not document.get(field) is String or str(document.get(field, "")).is_empty():
			errors.append("package.%s.type" % field)
	var class_id := str(document.get("class_id", ""))
	var weapon_id := str(document.get("weapon_id", ""))
	var path_parts := relative_path.split("/", false)
	if path_parts.size() < 2 or str(path_parts[0]) != class_id \
			or relative_path.get_file().get_basename() != weapon_id:
		errors.append("package.path_identity")
	if str(document.get("implementation_state", "")) != "ready":
		errors.append("package.implementation_state")
	for binding_name in BINDING_NAMES:
		var binding = document.get(binding_name)
		if not binding is Dictionary:
			errors.append("package.%s.type" % binding_name)
			continue
		_validate_exact_fields(binding as Dictionary, BINDING_FIELDS, "package.%s" % binding_name, errors)
		if not (binding as Dictionary).get("strategy_id") is String \
				or str((binding as Dictionary).get("strategy_id", "")).is_empty() \
				or str((binding as Dictionary).get("strategy_id", "")) == "unbound":
			errors.append("package.%s.strategy_id" % binding_name)
		if not (binding as Dictionary).get("params") is Dictionary:
			errors.append("package.%s.params" % binding_name)
	if errors.is_empty() and str((document["executor"] as Dictionary)["strategy_id"]) \
			!= str(document.get("executor_id", "")):
		errors.append("package.executor.strategy_identity")
	if base_profile.is_empty():
		errors.append("package.base.missing")
	else:
		var identity = base_profile.get("identity", {})
		var base_executor = base_profile.get("executor", {})
		if not identity is Dictionary \
				or str((identity as Dictionary).get("profile_id", "")) != str(document.get("profile_id", "")):
			errors.append("package.profile_id")
		if not base_executor is Dictionary \
				or str((base_executor as Dictionary).get("executor_id", "")) != str(document.get("executor_id", "")):
			errors.append("package.executor_id")
	if not errors.is_empty():
		return {"profile": {}, "errors": errors}
	return {"profile": _merge_profile(base_profile, document), "errors": errors}


func validate_pair(
	document: Dictionary,
	relative_path: String,
	executor_script,
	base_profile: Dictionary
) -> Dictionary:
	var stage := validate_document(document, relative_path, base_profile)
	var errors: Array[String] = stage["errors"]
	if not errors.is_empty():
		return {"profile": {}, "errors": errors}
	if executor_script == null or not executor_script is GDScript:
		errors.append("package.executor.script")
	else:
		var constant_map := (executor_script as GDScript).get_script_constant_map()
		if str(constant_map.get("PROFILE_ID", "")) != str(document.get("profile_id", "")):
			errors.append("package.executor.PROFILE_ID")
		if str(constant_map.get("EXECUTOR_ID", "")) != str(document.get("executor_id", "")):
			errors.append("package.executor.EXECUTOR_ID")
		_validate_executor_method(
			executor_script as GDScript, "parameter_contract", 0, TYPE_DICTIONARY, errors
		)
		_validate_executor_method(executor_script as GDScript, "execute", 1, TYPE_FLOAT, errors)
	if not errors.is_empty():
		return {"profile": {}, "errors": errors}
	var profile: Dictionary = stage["profile"]
	var contract = executor_script.call("parameter_contract")
	var normalized := Library.normalize_custom_params(
		(profile["executor"] as Dictionary).get("params", {}), contract
	)
	errors.append_array(normalized["errors"] as Array[String])
	if errors.is_empty():
		(profile["executor"] as Dictionary)["params"] = normalized["params"]
		errors.append_array(Schema.validate_package_profile(profile, base_profile))
	if not errors.is_empty():
		return {"profile": {}, "errors": errors}
	return {"profile": profile, "errors": errors}


func profile_for(key: String) -> Dictionary:
	var profile = _profiles_by_key.get(key)
	return (profile as Dictionary).duplicate(true) if profile is Dictionary else {}


func executor_for(key: String):
	return _executors_by_key.get(key)


func pair_keys() -> Dictionary:
	return _pair_keys.duplicate()


func validation_errors() -> Array[String]:
	return _errors.duplicate()


static func _merge_profile(base_profile: Dictionary, document: Dictionary) -> Dictionary:
	var profile := base_profile.duplicate(true)
	profile["implementation_state"] = "ready"
	profile["total_boss_cap"] = document.get("total_boss_cap")
	for binding_name in BINDING_NAMES:
		var merged_binding := (profile.get(binding_name, {}) as Dictionary).duplicate(true)
		var overlay := document[binding_name] as Dictionary
		merged_binding["strategy_id"] = overlay["strategy_id"]
		merged_binding["params"] = (overlay["params"] as Dictionary).duplicate(true)
		profile[binding_name] = merged_binding
	return profile


static func _validate_exact_fields(
	document: Dictionary,
	required_fields: Array,
	prefix: String,
	errors: Array[String]
) -> void:
	for raw_field in required_fields:
		var field := str(raw_field)
		if not document.has(field):
			errors.append("%s.missing: %s" % [prefix, field])
	for raw_field in document.keys():
		var field := str(raw_field)
		if not required_fields.has(field):
			errors.append("%s.unknown: %s" % [prefix, field])


static func _validate_executor_method(
	script: GDScript,
	method_name: String,
	argument_count: int,
	return_type: int,
	errors: Array[String]
) -> void:
	for raw_method in script.get_script_method_list():
		var method := raw_method as Dictionary
		if str(method.get("name", "")) != method_name:
			continue
		if int(method.get("flags", 0)) & METHOD_FLAG_STATIC == 0:
			errors.append("package.executor.%s.static" % method_name)
		if (method.get("args", []) as Array).size() != argument_count:
			errors.append("package.executor.%s.arguments" % method_name)
		if int((method.get("return", {}) as Dictionary).get("type", TYPE_NIL)) != return_type:
			errors.append("package.executor.%s.return" % method_name)
		return
	errors.append("package.executor.%s" % method_name)


## True for a class-owned data file that never pairs with an executor.
static func is_reserved_data_file(relative_path: String) -> bool:
	return RESERVED_DATA_FILES.has(relative_path.get_file())


static func _relative_files(root: String, extension: String) -> Array[String]:
	var files: Array[String] = []
	if DirAccess.open(root) == null:
		return files
	_collect_relative_files(root, "", extension, files)
	files.sort()
	return files


static func _collect_relative_files(
	root: String,
	relative_directory: String,
	extension: String,
	files: Array[String]
) -> void:
	var directory_path := root if relative_directory.is_empty() else "%s/%s" % [root, relative_directory]
	var file_names := DirAccess.get_files_at(directory_path)
	file_names.sort()
	for file_name in file_names:
		if file_name.ends_with(extension):
			files.append(file_name if relative_directory.is_empty() else "%s/%s" % [relative_directory, file_name])
	var directory_names := DirAccess.get_directories_at(directory_path)
	directory_names.sort()
	for directory_name in directory_names:
		var child := directory_name if relative_directory.is_empty() else "%s/%s" % [relative_directory, directory_name]
		_collect_relative_files(root, child, extension, files)
