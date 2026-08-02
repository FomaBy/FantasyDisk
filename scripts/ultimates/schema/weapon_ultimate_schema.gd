class_name WeaponUltimateSchema
extends RefCounted

## Versioned validator for the weapon-ultimate declaration catalog.
##
## The validator receives the canonical weapon inventory from its caller. This
## keeps the foundation independent from ProgressionData and avoids a future
## facade <-> registry preload cycle when integration starts using this module.

const SCHEMA_PATH := "res://data/ultimates/schema/v1/weapon_ultimate_profile.schema.json"
const EXPECTED_SCHEMA_VERSION := 1
const EXPECTED_CLASS_COUNT := 17
const EXPECTED_WEAPON_COUNT := 51

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


static func canonical_pairs(weapons_by_class: Dictionary) -> Dictionary:
	var pairs := {}
	for raw_class_id in weapons_by_class.keys():
		var class_id := str(raw_class_id)
		var raw_weapons = weapons_by_class.get(raw_class_id)
		if not raw_weapons is Dictionary:
			continue
		for raw_weapon_id in (raw_weapons as Dictionary).keys():
			pairs[profile_key(class_id, str(raw_weapon_id))] = true
	return pairs


static func validate_documents(documents: Array, weapons_by_class: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema := schema_document()
	if schema.is_empty():
		_add_error(errors, "schema.missing", SCHEMA_PATH)
		return errors
	if int(schema.get("schema_version", 0)) != EXPECTED_SCHEMA_VERSION:
		_add_error(errors, "schema.version", "expected %d" % EXPECTED_SCHEMA_VERSION)
	if weapons_by_class.size() != EXPECTED_CLASS_COUNT:
		_add_error(
			errors,
			"inventory.class_count",
			"expected %d, got %d" % [EXPECTED_CLASS_COUNT, weapons_by_class.size()]
		)

	var expected_pairs := canonical_pairs(weapons_by_class)
	if expected_pairs.size() != EXPECTED_WEAPON_COUNT:
		_add_error(
			errors,
			"inventory.weapon_count",
			"expected %d, got %d" % [EXPECTED_WEAPON_COUNT, expected_pairs.size()]
		)
	if documents.size() != EXPECTED_CLASS_COUNT:
		_add_error(
			errors,
			"catalog.file_count",
			"expected %d, got %d" % [EXPECTED_CLASS_COUNT, documents.size()]
		)

	var expected_class_order := {}
	var order := 0
	for raw_class_id in weapons_by_class.keys():
		expected_class_order[str(raw_class_id)] = order
		order += 1

	var seen_classes := {}
	var seen_pairs := {}
	var unique_ids := {}
	var seen_phase_ids := {}
	var profile_count := 0
	for raw_document in documents:
		if not raw_document is Dictionary:
			_add_error(errors, "catalog.document_type", "class document must be a Dictionary")
			continue
		var document := raw_document as Dictionary
		var source := str(document.get("_source_path", "<memory>"))
		var class_id := str(document.get("class_id", ""))
		var schema_version := int(document.get("schema_version", 0))
		var class_order := int(document.get("class_order", -1))
		if schema_version != EXPECTED_SCHEMA_VERSION:
			_add_error(
				errors,
				"catalog.schema_version",
				"%s expected %d, got %d" % [source, EXPECTED_SCHEMA_VERSION, schema_version]
			)
		if class_id.is_empty():
			_add_error(errors, "catalog.class_id.empty", source)
		elif not weapons_by_class.has(class_id):
			_add_error(errors, "catalog.class_id.unknown", "%s: %s" % [source, class_id])
		elif seen_classes.has(class_id):
			_add_error(errors, "catalog.class_id.duplicate", class_id)
		else:
			seen_classes[class_id] = source
			var expected_order := int(expected_class_order.get(class_id, -1))
			if class_order != expected_order:
				_add_error(
					errors,
					"catalog.class_order",
					"%s expected %d, got %d" % [class_id, expected_order, class_order]
				)
			if source != "<memory>" and source.get_file().get_basename() != class_id:
				_add_error(
					errors,
					"catalog.file_name",
					"%s must be stored in %s.json" % [class_id, class_id]
				)

		var profiles = document.get("profiles", [])
		if not profiles is Array:
			_add_error(errors, "catalog.profiles_type", "%s profiles must be an Array" % source)
			continue
		var expected_weapon_ids := _weapon_ids_for_class(weapons_by_class, class_id)
		if (profiles as Array).size() != expected_weapon_ids.size():
			_add_error(
				errors,
				"catalog.class_profile_count",
				"%s expected %d, got %d" % [class_id, expected_weapon_ids.size(), (profiles as Array).size()]
			)
		for profile_order in (profiles as Array).size():
			var raw_profile = (profiles as Array)[profile_order]
			if not raw_profile is Dictionary:
				_add_error(errors, "profile.type", "%s[%d]" % [class_id, profile_order])
				continue
			profile_count += 1
			var profile := normalized_profile(
				raw_profile as Dictionary,
				class_id,
				class_order,
				profile_order,
				schema_version
			)
			var weapon_id := str(profile.get("weapon_id", ""))
			var key := profile_key(class_id, weapon_id)
			if weapon_id.is_empty():
				_add_error(errors, "profile.weapon_id.empty", "%s[%d]" % [class_id, profile_order])
			elif not expected_pairs.has(key):
				_add_error(errors, "profile.weapon_id.unknown", key)
			elif seen_pairs.has(key):
				_add_error(errors, "profile.pair.duplicate", key)
			else:
				seen_pairs[key] = true
			if profile_order < expected_weapon_ids.size():
				var expected_weapon_id := str(expected_weapon_ids[profile_order])
				if weapon_id != expected_weapon_id:
					_add_error(
						errors,
						"profile.weapon_order",
						"%s[%d] expected %s, got %s"
						% [class_id, profile_order, expected_weapon_id, weapon_id]
					)
			_validate_profile(profile, key, schema, unique_ids, seen_phase_ids, errors)

	for expected_key in expected_pairs.keys():
		if not seen_pairs.has(expected_key):
			_add_error(errors, "catalog.pair.missing", str(expected_key))
	for actual_key in seen_pairs.keys():
		if not expected_pairs.has(actual_key):
			_add_error(errors, "catalog.pair.extra", str(actual_key))
	if profile_count != EXPECTED_WEAPON_COUNT:
		_add_error(
			errors,
			"catalog.profile_count",
			"expected %d, got %d" % [EXPECTED_WEAPON_COUNT, profile_count]
		)
	return errors


static func index_documents(documents: Array) -> Dictionary:
	var profiles_by_key := {}
	for raw_document in documents:
		if not raw_document is Dictionary:
			continue
		var document := raw_document as Dictionary
		var class_id := str(document.get("class_id", ""))
		var schema_version := int(document.get("schema_version", 0))
		var class_order := int(document.get("class_order", -1))
		var profiles = document.get("profiles", [])
		if not profiles is Array:
			continue
		for profile_order in (profiles as Array).size():
			var raw_profile = (profiles as Array)[profile_order]
			if not raw_profile is Dictionary:
				continue
			var profile := normalized_profile(
				raw_profile as Dictionary,
				class_id,
				class_order,
				profile_order,
				schema_version
			)
			profiles_by_key[profile_key(class_id, str(profile.get("weapon_id", "")))] = profile
	return profiles_by_key


## Validate one class-local ready overlay after it has been merged onto its
## immutable catalog declaration. Package admission deliberately avoids the
## 17 x 3 inventory checks: the base catalog already owns that completeness.
static func validate_package_profile(profile: Dictionary, base_profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema := schema_document()
	if schema.is_empty():
		_add_error(errors, "schema.missing", SCHEMA_PATH)
		return errors
	var key := profile_key(str(profile.get("class_id", "")), str(profile.get("weapon_id", "")))
	if base_profile.is_empty():
		_add_error(errors, "package.base.missing", key)
		return errors
	for field in ["class_id", "weapon_id", "class_order", "profile_order", "schema_version"]:
		if profile.get(field) != base_profile.get(field):
			_add_error(errors, "package.base.%s" % field, key)
	if profile.get("identity") != base_profile.get("identity"):
		_add_error(errors, "package.base.identity", key)
	if profile.get("cast_phases") != base_profile.get("cast_phases"):
		_add_error(errors, "package.base.cast_phases", key)
	if profile.get("presentation") != base_profile.get("presentation"):
		_add_error(errors, "package.base.presentation", key)
	if str(profile.get("implementation_state", "")) != "ready":
		_add_error(errors, "package.implementation_state", key)
	_validate_profile(profile, key, schema, {}, {}, errors)
	return errors


static func normalized_profile(
	raw_profile: Dictionary,
	class_id: String,
	class_order: int,
	profile_order: int,
	schema_version: int
) -> Dictionary:
	var profile := raw_profile.duplicate(true)
	profile["class_id"] = class_id
	profile["class_order"] = class_order
	profile["profile_order"] = profile_order
	profile["schema_version"] = schema_version
	return profile


static func _validate_profile(
	profile: Dictionary,
	key: String,
	schema: Dictionary,
	unique_ids: Dictionary,
	seen_phase_ids: Dictionary,
	errors: Array[String]
) -> void:
	var class_id := str(profile.get("class_id", ""))
	var weapon_id := str(profile.get("weapon_id", ""))
	var id_suffix := "%s.%s" % [class_id, weapon_id]
	var state := str(profile.get("implementation_state", ""))
	var allowed_states = schema.get("implementation_states", [])
	if not allowed_states is Array or not (allowed_states as Array).has(state):
		_add_error(errors, "profile.implementation_state", "%s: %s" % [key, state])
	if str(profile.get("fallback_policy_id", "")) != "legacy_class_ultimate":
		_add_error(errors, "profile.fallback_policy", key)

	var identity = profile.get("identity")
	if not identity is Dictionary:
		_add_error(errors, "profile.identity", key)
	else:
		_validate_scoped_id(
			identity as Dictionary,
			"profile_id",
			"weapon_ultimate.profile.%s" % id_suffix,
			"identity.profile_id",
			key,
			unique_ids,
			errors
		)
		_validate_scoped_id(
			identity as Dictionary,
			"title_id",
			"weapon_ultimate.title.%s" % id_suffix,
			"identity.title_id",
			key,
			unique_ids,
			errors
		)
		_validate_scoped_id(
			identity as Dictionary,
			"mechanic_id",
			"weapon_ultimate.mechanic.%s" % id_suffix,
			"identity.mechanic_id",
			key,
			unique_ids,
			errors
		)

	var targeting = profile.get("targeting")
	if not targeting is Dictionary:
		_add_error(errors, "profile.targeting", key)
	else:
		_validate_scoped_id(
			targeting as Dictionary,
			"aim_id",
			"weapon_ultimate.aim.%s" % id_suffix,
			"targeting.aim_id",
			key,
			unique_ids,
			errors
		)
		_validate_binding(targeting as Dictionary, "targeting", key, state, errors)

	var charge = profile.get("charge")
	if not charge is Dictionary:
		_add_error(errors, "profile.charge", key)
	else:
		_validate_scoped_id(
			charge as Dictionary,
			"policy_id",
			"weapon_ultimate.charge.%s" % id_suffix,
			"charge.policy_id",
			key,
			unique_ids,
			errors
		)
		_validate_binding(charge as Dictionary, "charge", key, state, errors)

	var cast_phases = profile.get("cast_phases")
	var required_phase_kinds = schema.get("required_phase_kinds", [])
	if not cast_phases is Dictionary:
		_add_error(errors, "profile.cast_phases", key)
	elif not required_phase_kinds is Array:
		_add_error(errors, "schema.required_phase_kinds", "must be an Array")
	else:
		if (cast_phases as Dictionary).size() != (required_phase_kinds as Array).size():
			_add_error(errors, "profile.cast_phase_count", key)
		for raw_kind in required_phase_kinds as Array:
			var kind := str(raw_kind)
			var phase_id := str((cast_phases as Dictionary).get(kind, ""))
			var expected_phase_id := "weapon_ultimate.phase.%s.%s" % [id_suffix, kind]
			if phase_id != expected_phase_id:
				_add_error(
					errors,
					"profile.phase_id",
					"%s/%s expected %s, got %s" % [key, kind, expected_phase_id, phase_id]
				)
			elif seen_phase_ids.has(phase_id):
				_add_error(errors, "profile.phase_id.duplicate", phase_id)
			else:
				seen_phase_ids[phase_id] = key

	var executor = profile.get("executor")
	if not executor is Dictionary:
		_add_error(errors, "profile.executor", key)
	else:
		_validate_scoped_id(
			executor as Dictionary,
			"executor_id",
			"weapon_ultimate.executor.%s" % id_suffix,
			"executor.executor_id",
			key,
			unique_ids,
			errors
		)
		_validate_binding(executor as Dictionary, "executor", key, state, errors)

	var boss_cap = profile.get("total_boss_cap")
	if state == "declared":
		if boss_cap != null:
			_add_error(errors, "profile.total_boss_cap.declared", key)
	elif not _is_number(boss_cap):
		_add_error(errors, "profile.total_boss_cap.type", key)
	else:
		var boss_cap_value := float(boss_cap)
		if not is_finite(boss_cap_value) or boss_cap_value <= 0.0 or boss_cap_value > 1.0:
			_add_error(errors, "profile.total_boss_cap.range", key)

	var presentation = profile.get("presentation")
	if not presentation is Dictionary:
		_add_error(errors, "profile.presentation", key)
	else:
		for field in ["presentation_id", "animation_id", "vfx_id", "sfx_id"]:
			_validate_scoped_id(
				presentation as Dictionary,
				field,
				"weapon_ultimate.%s.%s" % [field.trim_suffix("_id"), id_suffix],
				"presentation.%s" % field,
				key,
				unique_ids,
				errors
			)
		_validate_params(presentation as Dictionary, "presentation", key, errors)

	var cleanup = profile.get("cleanup_policy")
	if not cleanup is Dictionary:
		_add_error(errors, "profile.cleanup_policy", key)
	else:
		_validate_scoped_id(
			cleanup as Dictionary,
			"policy_id",
			"weapon_ultimate.cleanup.%s" % id_suffix,
			"cleanup.policy_id",
			key,
			unique_ids,
			errors
		)
		_validate_binding(cleanup as Dictionary, "cleanup", key, state, errors)


static func _validate_binding(
	binding: Dictionary,
	family: String,
	key: String,
	state: String,
	errors: Array[String]
) -> void:
	var strategy_id := str(binding.get("strategy_id", ""))
	if state == "declared":
		if strategy_id != "unbound":
			_add_error(errors, "profile.%s.declared_strategy" % family, key)
	elif strategy_id.is_empty() or strategy_id == "unbound":
		_add_error(errors, "profile.%s.ready_strategy" % family, key)
	_validate_params(binding, family, key, errors)


static func _validate_params(
	container: Dictionary,
	family: String,
	key: String,
	errors: Array[String]
) -> void:
	if not container.get("params") is Dictionary:
		_add_error(errors, "profile.%s.params" % family, key)


static func _validate_scoped_id(
	container: Dictionary,
	field: String,
	expected: String,
	family: String,
	key: String,
	unique_ids: Dictionary,
	errors: Array[String]
) -> void:
	var value := str(container.get(field, ""))
	if value != expected:
		_add_error(errors, "profile.%s.namespace" % family, "%s expected %s, got %s" % [key, expected, value])
	if value.is_empty():
		_add_error(errors, "profile.%s.empty" % family, key)
		return
	var unique_key := "%s::%s" % [family, value]
	if unique_ids.has(unique_key):
		_add_error(errors, "profile.%s.duplicate" % family, value)
	else:
		unique_ids[unique_key] = key


static func _weapon_ids_for_class(weapons_by_class: Dictionary, class_id: String) -> Array[String]:
	var ids: Array[String] = []
	var raw_weapons = weapons_by_class.get(class_id)
	if raw_weapons is Dictionary:
		for raw_weapon_id in (raw_weapons as Dictionary).keys():
			ids.append(str(raw_weapon_id))
	return ids


static func _is_number(value) -> bool:
	return (value is int or value is float) and not value is bool


static func _add_error(errors: Array[String], code: String, detail: String) -> void:
	errors.append("%s: %s" % [code, detail])
