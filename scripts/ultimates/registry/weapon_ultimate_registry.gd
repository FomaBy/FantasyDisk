class_name WeaponUltimateRegistry
extends RefCounted

## Directory-composed catalog for the 17 x 3 weapon-ultimate declarations.
##
## Construct once with the canonical WEAPONS_BY_CLASS source and cache the
## instance at the integration boundary. Every public Dictionary/Array is a deep
## copy so consumers cannot mutate the catalog.

const CATALOG_DIRECTORY := "res://data/ultimates/schema/v1/classes"
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const PackageDiscovery := preload(
	"res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd"
)
const Text := preload("res://scripts/ultimates/registry/weapon_ultimate_text.gd")

var _documents: Array = []
var _profiles_by_key: Dictionary = {}
var _canonical_pairs: Dictionary = {}
var _errors: Array[String] = []
var _text_errors: Array[String] = []
var _package_errors: Array[String] = []
var _package_executors: Dictionary = {}
var _package_pairs: Dictionary = {}


func _init(weapons_by_class: Dictionary = {}) -> void:
	if not weapons_by_class.is_empty():
		load_catalog(weapons_by_class)


func load_catalog(weapons_by_class: Dictionary) -> void:
	_documents.clear()
	_profiles_by_key.clear()
	_package_errors.clear()
	_package_executors.clear()
	_package_pairs.clear()
	_canonical_pairs = Schema.canonical_pairs(weapons_by_class)
	_errors.clear()
	_text_errors.clear()
	_read_documents()
	_errors.append_array(Schema.validate_documents(_documents, weapons_by_class))
	if _errors.is_empty():
		_profiles_by_key = Schema.index_documents(_documents)
		_apply_canonical_text()
		var discovery := PackageDiscovery.new()
		discovery.discover(_profiles_by_key)
		_package_errors = discovery.validation_errors()
		_package_pairs = discovery.pair_keys()
		for raw_key in _package_pairs.keys():
			var key := str(raw_key)
			_profiles_by_key[key] = discovery.profile_for(key)
			_package_executors[key] = discovery.executor_for(key)


func is_valid() -> bool:
	return _errors.is_empty() and _profiles_by_key.size() == Schema.EXPECTED_WEAPON_COUNT


func validation_errors() -> Array[String]:
	return _errors.duplicate()


func package_validation_errors() -> Array[String]:
	return _package_errors.duplicate()


func text_validation_errors() -> Array[String]:
	return _text_errors.duplicate()


## Player-facing title/mechanics of the SELECTED weapon ultimate. Empty only
## when the pair is not canonical — the legacy class ultimate is never a text
## fallback here.
func ultimate_text(class_id: String, weapon_id: String) -> Dictionary:
	var profile := catalog_profile_for(class_id, weapon_id)
	var text = profile.get("text")
	return text if text is Dictionary else {}


func profile_count() -> int:
	return _profiles_by_key.size()


func catalog_profile_for(class_id: String, weapon_id: String) -> Dictionary:
	return Resolver.select_catalog_profile(_profiles_by_key, class_id, weapon_id)


func resolution_source(
	class_id: String,
	weapon_id: String,
	allow_legacy_fallback := true
) -> String:
	return Resolver.resolution_source(
		_profiles_by_key,
		_canonical_pairs,
		class_id,
		weapon_id,
		allow_legacy_fallback,
		_package_pairs
	)


func resolve_executable(
	class_id: String,
	weapon_id: String,
	legacy_class_fallback: Dictionary,
	allow_legacy_fallback := true
) -> Dictionary:
	return Resolver.resolve_executable(
		_profiles_by_key,
		_canonical_pairs,
		class_id,
		weapon_id,
		legacy_class_fallback,
		allow_legacy_fallback,
		_package_pairs
	)


func executor_for(class_id: String, weapon_id: String):
	return _package_executors.get(Schema.profile_key(class_id, weapon_id))


func has_exact_executor_pair(class_id: String, weapon_id: String) -> bool:
	return _package_pairs.has(Schema.profile_key(class_id, weapon_id))


func package_pair_keys() -> Array[String]:
	var keys: Array[String] = []
	for raw_key in _package_pairs.keys():
		keys.append(str(raw_key))
	keys.sort()
	return keys


func profile_keys() -> Array[String]:
	var keys: Array[String] = []
	for raw_key in _profiles_by_key.keys():
		keys.append(str(raw_key))
	keys.sort()
	return keys


func class_ids() -> Array[String]:
	var ordered: Array = []
	var seen := {}
	for document in _documents:
		if not document is Dictionary:
			continue
		var class_id := str((document as Dictionary).get("class_id", ""))
		if class_id.is_empty() or seen.has(class_id):
			continue
		seen[class_id] = true
		ordered.append(
			{
				"class_id": class_id,
				"class_order": int((document as Dictionary).get("class_order", -1)),
			}
		)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["class_order"]) < int(right["class_order"])
	)
	var result: Array[String] = []
	for entry in ordered:
		result.append(str((entry as Dictionary)["class_id"]))
	return result


func weapon_ids(class_id: String) -> Array[String]:
	var ordered: Array = []
	for raw_profile in _profiles_by_key.values():
		if not raw_profile is Dictionary:
			continue
		var profile := raw_profile as Dictionary
		if str(profile.get("class_id", "")) != class_id:
			continue
		ordered.append(
			{
				"weapon_id": str(profile.get("weapon_id", "")),
				"profile_order": int(profile.get("profile_order", -1)),
			}
		)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["profile_order"]) < int(right["profile_order"])
	)
	var result: Array[String] = []
	for entry in ordered:
		result.append(str((entry as Dictionary)["weapon_id"]))
	return result


func profiles_for_tests() -> Dictionary:
	return _profiles_by_key.duplicate(true)


func documents_for_tests() -> Array:
	return _documents.duplicate(true)


func canonical_pairs_for_tests() -> Dictionary:
	return _canonical_pairs.duplicate(true)


## Canonical text rides on the profile itself, so every consumer that already
## resolves a profile — HUD, Codex, pause dossier, package overlays — reads the
## same title/mechanics for the same pair.
func _apply_canonical_text() -> void:
	var text_records := Text.records()
	_text_errors = Text.validate_records(_profiles_by_key.keys(), text_records)
	for raw_key in _profiles_by_key.keys():
		var key := str(raw_key)
		var record = text_records.get(key)
		(_profiles_by_key[key] as Dictionary)["text"] = \
			(record as Dictionary).duplicate() if record is Dictionary else {}


func _read_documents() -> void:
	var directory := DirAccess.open(CATALOG_DIRECTORY)
	if directory == null:
		_errors.append("catalog.directory_missing: %s" % CATALOG_DIRECTORY)
		return
	var file_names := DirAccess.get_files_at(CATALOG_DIRECTORY)
	file_names.sort()
	for file_name in file_names:
		if not file_name.ends_with(".json"):
			continue
		var path := "%s/%s" % [CATALOG_DIRECTORY, file_name]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			_errors.append("catalog.parse: %s" % path)
			continue
		var document := (parsed as Dictionary).duplicate(true)
		document["_source_path"] = path
		_documents.append(document)
