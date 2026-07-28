class_name WeaponUltimatePresentationSchema
extends RefCounted

## Validator for the weapon-keyed ultimate presentation bridge.
##
## It validates data supplied by class-local animation packages without
## importing their scenes or touching shared VFX pooling. The immutable profile
## and lifecycle IDs remain owned by the v1 weapon-ultimate registry.

const SCHEMA_PATH := "res://data/ultimates/presentation_schema/v1/weapon_ultimate_presentation_manifest.schema.json"
const EXPECTED_SCHEMA_VERSION := 1
const ACTION_ULTIMATE := "ultimate"

static var _schema_cache: Dictionary = {}


static func schema_document() -> Dictionary:
	if not _schema_cache.is_empty():
		return _schema_cache.duplicate(true)
	if not FileAccess.file_exists(SCHEMA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	if not parsed is Dictionary:
		return {}
	_schema_cache = (parsed as Dictionary).duplicate(true)
	return _schema_cache.duplicate(true)


static func clear_cache_for_tests() -> void:
	_schema_cache.clear()


static func profile_key(class_id: String, weapon_id: String) -> String:
	return "%s/%s" % [class_id, weapon_id]


static func validate_manifest(manifest: Dictionary, expected_profile: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	var schema := schema_document()
	if schema.is_empty():
		_add_error(errors, "presentation.schema.missing", SCHEMA_PATH)
		return errors
	if int(schema.get("schema_version", 0)) != EXPECTED_SCHEMA_VERSION:
		_add_error(errors, "presentation.schema.version", "expected %d" % EXPECTED_SCHEMA_VERSION)
	_validate_manifest(manifest, expected_profile, schema, {}, errors)
	return errors


static func validate_catalog(manifests: Array, expected_profiles: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema := schema_document()
	if schema.is_empty():
		_add_error(errors, "presentation.schema.missing", SCHEMA_PATH)
		return errors
	if int(schema.get("schema_version", 0)) != EXPECTED_SCHEMA_VERSION:
		_add_error(errors, "presentation.schema.version", "expected %d" % EXPECTED_SCHEMA_VERSION)

	var seen_keys := {}
	# Keep a sentinel so _validate_id can distinguish a catalog-wide uniqueness
	# pass from a standalone single-manifest validation with no shared ID scope.
	var seen_ids := {"__catalog_tracking__": true}
	for raw_manifest in manifests:
		if not raw_manifest is Dictionary:
			_add_error(errors, "presentation.manifest.type", "manifest must be a Dictionary")
			continue
		var manifest := raw_manifest as Dictionary
		var class_id := str(manifest.get("class_id", ""))
		var key_data = manifest.get("key", {})
		var weapon_id := str((key_data as Dictionary).get("weapon_id", "")) if key_data is Dictionary else ""
		var key := profile_key(class_id, weapon_id)
		if seen_keys.has(key):
			_add_error(errors, "presentation.profile.duplicate", key)
		else:
			seen_keys[key] = true
		var expected_profile = expected_profiles.get(key, {})
		if not expected_profile is Dictionary:
			_add_error(errors, "presentation.profile.unknown", key)
			expected_profile = {}
		_validate_manifest(manifest, expected_profile as Dictionary, schema, seen_ids, errors)

	for expected_key in expected_profiles.keys():
		if not seen_keys.has(expected_key):
			_add_error(errors, "presentation.profile.missing", str(expected_key))
	return errors


static func _validate_manifest(
	manifest: Dictionary,
	expected_profile: Dictionary,
	schema: Dictionary,
	seen_ids: Dictionary,
	errors: Array[String]
) -> void:
	if int(manifest.get("schema_version", 0)) != EXPECTED_SCHEMA_VERSION:
		_add_error(errors, "presentation.manifest.version", "expected %d" % EXPECTED_SCHEMA_VERSION)
	var class_id := str(manifest.get("class_id", ""))
	if class_id.is_empty():
		_add_error(errors, "presentation.class_id.empty", "manifest")
	var key_data = manifest.get("key", {})
	if not key_data is Dictionary:
		_add_error(errors, "presentation.key", class_id)
		key_data = {}
	var key := key_data as Dictionary
	var weapon_id := str(key.get("weapon_id", ""))
	if weapon_id.is_empty():
		_add_error(errors, "presentation.key.weapon_id", class_id)
	if str(key.get("action", "")) != ACTION_ULTIMATE:
		_add_error(errors, "presentation.key.action", "%s/%s" % [class_id, weapon_id])
	var profile_key_value := profile_key(class_id, weapon_id)

	if not expected_profile.is_empty():
		if str(expected_profile.get("class_id", "")) != class_id:
			_add_error(errors, "presentation.class_id.mismatch", profile_key_value)
		if str(expected_profile.get("weapon_id", "")) != weapon_id:
			_add_error(errors, "presentation.key.weapon_mismatch", profile_key_value)
	var expected_presentation = expected_profile.get("presentation", {})
	if not expected_presentation is Dictionary:
		expected_presentation = {}
	var expected = expected_presentation as Dictionary

	_validate_id(
		str(manifest.get("presentation_id", "")),
		str(expected.get("presentation_id", "")),
		"presentation_id",
		profile_key_value,
		seen_ids,
		errors
	)
	for channel in schema.get("required_asset_channels", []) as Array:
		var channel_name := str(channel)
		var asset_data = manifest.get(channel_name, {})
		if not asset_data is Dictionary:
			_add_error(errors, "presentation.asset.%s" % channel_name, profile_key_value)
			continue
		_validate_asset(
			asset_data as Dictionary,
			channel_name,
			str(expected.get("%s_id" % channel_name, "")),
			profile_key_value,
			seen_ids,
			errors
		)

	_validate_phases(manifest.get("phases", []), expected_profile, schema, profile_key_value, errors)
	_validate_pivot(manifest.get("pivot", {}), schema, profile_key_value, errors)
	_validate_timing(manifest.get("timing", {}), manifest.get("phases", []), schema, profile_key_value, errors)
	if str(manifest.get("headless_fallback", "")) != str(schema.get("headless_fallback", "")):
		_add_error(errors, "presentation.headless_fallback", profile_key_value)


static func _validate_id(
	value: String,
	expected: String,
	family: String,
	profile_key_value: String,
	seen_ids: Dictionary,
	errors: Array[String]
) -> void:
	if value.is_empty():
		_add_error(errors, "presentation.%s.empty" % family, profile_key_value)
		return
	if _contains_placeholder(value):
		_add_error(errors, "presentation.%s.placeholder" % family, value)
	if not expected.is_empty() and value != expected:
		_add_error(errors, "presentation.%s.contract" % family, "%s expected %s, got %s" % [profile_key_value, expected, value])
	if not seen_ids.is_empty():
		var unique_key := "%s::%s" % [family, value]
		if seen_ids.has(unique_key):
			_add_error(errors, "presentation.%s.duplicate" % family, value)
		else:
			seen_ids[unique_key] = profile_key_value


static func _validate_asset(
	asset: Dictionary,
	channel: String,
	expected_id: String,
	profile_key_value: String,
	seen_ids: Dictionary,
	errors: Array[String]
) -> void:
	_validate_id(
		str(asset.get("id", "")),
		expected_id,
		"%s_id" % channel,
		profile_key_value,
		seen_ids,
		errors
	)
	for path_field in ["source_path", "runtime_path"]:
		var path := str(asset.get(path_field, ""))
		if not _is_valid_resource_path(path):
			_add_error(errors, "presentation.asset.%s.%s" % [channel, path_field], path)
			continue
		if _contains_placeholder(path):
			_add_error(errors, "presentation.asset.%s.placeholder" % channel, path)
		if not FileAccess.file_exists(path):
			var kind := "source_missing" if path_field == "source_path" else "runtime_missing"
			_add_error(errors, "presentation.asset.%s.%s" % [channel, kind], path)


static func _validate_phases(
	raw_phases,
	expected_profile: Dictionary,
	schema: Dictionary,
	profile_key_value: String,
	errors: Array[String]
) -> void:
	if not raw_phases is Array:
		_add_error(errors, "presentation.phases", profile_key_value)
		return
	var phases := raw_phases as Array
	var phase_groups = schema.get("required_phase_groups", [])
	if not phase_groups is Array:
		_add_error(errors, "presentation.schema.phase_groups", "must be an Array")
		return
	if phases.size() != (phase_groups as Array).size():
		_add_error(errors, "presentation.phase_count", profile_key_value)
	var phase_bindings = schema.get("phase_id_bindings", {})
	if not phase_bindings is Dictionary:
		phase_bindings = {}
	var cast_phases = expected_profile.get("cast_phases", {})
	if not cast_phases is Dictionary:
		cast_phases = {}
	var seen_names := {}
	var seen_ids := {}
	for raw_phase in phases:
		if not raw_phase is Dictionary:
			_add_error(errors, "presentation.phase.type", profile_key_value)
			continue
		var phase := raw_phase as Dictionary
		var name := str(phase.get("name", ""))
		if not (phase_bindings as Dictionary).has(name):
			_add_error(errors, "presentation.phase.name", "%s/%s" % [profile_key_value, name])
			continue
		if seen_names.has(name):
			_add_error(errors, "presentation.phase.duplicate", "%s/%s" % [profile_key_value, name])
		else:
			seen_names[name] = true
		var phase_id := str(phase.get("phase_id", ""))
		if phase_id.is_empty():
			_add_error(errors, "presentation.phase_id.empty", "%s/%s" % [profile_key_value, name])
		elif seen_ids.has(phase_id):
			_add_error(errors, "presentation.phase_id.duplicate", phase_id)
		else:
			seen_ids[phase_id] = true
		var cast_phase_name := str((phase_bindings as Dictionary).get(name, ""))
		var expected_phase_id := str((cast_phases as Dictionary).get(cast_phase_name, ""))
		if not expected_phase_id.is_empty() and phase_id != expected_phase_id:
			_add_error(
				errors,
				"presentation.phase_id.contract",
				"%s/%s expected %s, got %s" % [profile_key_value, name, expected_phase_id, phase_id]
			)
	for raw_group in phase_groups as Array:
		if not raw_group is Array:
			continue
		var group := raw_group as Array
		var count := 0
		for raw_name in group:
			if seen_names.has(str(raw_name)):
				count += 1
		if count != 1:
			var group_name := "/".join(group)
			var code := "presentation.phase.active_or_impact" if group_name == "active/impact" else "presentation.phase.missing"
			_add_error(errors, code, "%s/%s" % [profile_key_value, group_name])


static func _validate_pivot(raw_pivot, schema: Dictionary, profile_key_value: String, errors: Array[String]) -> void:
	if not raw_pivot is Dictionary:
		_add_error(errors, "presentation.pivot", profile_key_value)
		return
	var pivot := raw_pivot as Dictionary
	var range = schema.get("pivot_range", [])
	if not range is Array or (range as Array).size() != 2:
		_add_error(errors, "presentation.schema.pivot_range", "must contain min/max")
		return
	var minimum := float((range as Array)[0])
	var maximum := float((range as Array)[1])
	for axis in ["x", "y"]:
		var value = pivot.get(axis)
		if not _is_number(value):
			_add_error(errors, "presentation.pivot.type", "%s/%s" % [profile_key_value, axis])
			continue
		var coordinate := float(value)
		if not is_finite(coordinate) or coordinate < minimum or coordinate > maximum:
			_add_error(errors, "presentation.pivot.range", "%s/%s" % [profile_key_value, axis])


static func _validate_timing(
	raw_timing,
	raw_phases,
	schema: Dictionary,
	profile_key_value: String,
	errors: Array[String]
) -> void:
	if not raw_timing is Dictionary:
		_add_error(errors, "presentation.timing", profile_key_value)
		return
	if not raw_phases is Array:
		return
	var timing := raw_timing as Dictionary
	var phase_names: Array[String] = []
	for raw_phase in raw_phases as Array:
		if raw_phase is Dictionary:
			phase_names.append(str((raw_phase as Dictionary).get("name", "")))
	var ordered_names: Array[String] = ["windup", "release"]
	if phase_names.has("active"):
		ordered_names.append("active")
	elif phase_names.has("impact"):
		ordered_names.append("impact")
	ordered_names.append_array(["recovery", "cancel"])
	var maximum := float(schema.get("max_timeline_seconds", 0.0))
	var previous := -1.0
	for name in ordered_names:
		var value = timing.get(name)
		if not _is_number(value):
			_add_error(errors, "presentation.timing.type", "%s/%s" % [profile_key_value, name])
			continue
		var timestamp := float(value)
		if not is_finite(timestamp) or timestamp < 0.0 or timestamp > maximum:
			_add_error(errors, "presentation.timing.range", "%s/%s" % [profile_key_value, name])
		elif timestamp < previous:
			_add_error(errors, "presentation.timing.order", "%s/%s" % [profile_key_value, name])
		previous = timestamp


static func _is_valid_resource_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	var relative := path.trim_prefix("res://")
	return not relative.is_empty() and not relative.contains("..") and not relative.contains("//")


static func _contains_placeholder(value: String) -> bool:
	return value.to_lower().contains("placeholder")


static func _is_number(value) -> bool:
	return (value is int or value is float) and not value is bool


static func _add_error(errors: Array[String], code: String, detail: String) -> void:
	errors.append("%s: %s" % [code, detail])
