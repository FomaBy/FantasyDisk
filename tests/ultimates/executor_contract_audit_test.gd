extends SceneTree

## Fail-closed contract for the registry-derived executor audit.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/executor_contract_audit_test.gd

const AUDIT_PATH := "res://docs/design/references/weapon_ultimates/executor_contract_audit.json"
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const Discovery := preload(
	"res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd"
)
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const CLASSIFICATIONS := [
	"expressible_now",
	"needs_param_generalization",
	"needs_new_generic_primitive",
]


func _initialize() -> void:
	var errors: Array[String] = []
	var audit = JSON.parse_string(FileAccess.get_file_as_string(AUDIT_PATH))
	_expect(audit is Dictionary, "audit must parse as a Dictionary", errors)
	if not audit is Dictionary:
		_report(errors)
		return

	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "canonical registry must be valid", errors)
	var canonical_pairs: Dictionary = registry.canonical_pairs_for_tests()
	var strategy_ids := Library.strategy_ids()
	var audit_errors := _validate_audit(audit, canonical_pairs, strategy_ids)
	_expect(audit_errors.is_empty(), "canonical audit must validate: %s" % str(audit_errors), errors)
	_test_persisted_packages(registry, audit, canonical_pairs, errors)
	_test_resolution_negative_matrix(registry, errors)

	var missing_pair: Dictionary = audit.duplicate(true)
	(missing_pair["profiles"] as Array).remove_at(0)
	_expect_error_code(
		missing_pair, canonical_pairs, strategy_ids, "audit.pair.missing",
		"removing a pair must fail closed", errors
	)

	var extra_pair: Dictionary = audit.duplicate(true)
	var extra_entry: Dictionary = (extra_pair["profiles"][0] as Dictionary).duplicate(true)
	extra_entry["class_id"] = "__extra_class__"
	extra_entry["weapon_id"] = "__extra_weapon__"
	(extra_pair["profiles"] as Array).append(extra_entry)
	_expect_error_code(
		extra_pair, canonical_pairs, strategy_ids, "audit.pair.extra",
		"adding an unknown pair must fail closed", errors
	)

	var duplicate_pair: Dictionary = audit.duplicate(true)
	(duplicate_pair["profiles"] as Array).append(
		(duplicate_pair["profiles"][0] as Dictionary).duplicate(true)
	)
	_expect_error_code(
		duplicate_pair, canonical_pairs, strategy_ids, "audit.pair.duplicate",
		"duplicating a pair must fail closed", errors
	)

	var invalid_classification: Dictionary = audit.duplicate(true)
	invalid_classification["profiles"][0]["classification"] = "__invalid__"
	_expect_error_code(
		invalid_classification, canonical_pairs, strategy_ids, "audit.classification.invalid",
		"an unknown classification must fail closed", errors
	)

	var unknown_family: Dictionary = audit.duplicate(true)
	unknown_family["profiles"][0]["executor_family"] = "__missing_family__"
	_expect_error_code(
		unknown_family, canonical_pairs, strategy_ids, "audit.executor_family.unknown",
		"an unknown executor family must fail closed", errors
	)

	_test_live_parameter_contract(errors)
	_report(errors)


func _validate_audit(
	audit: Dictionary,
	canonical_pairs: Dictionary,
	strategy_ids: Array[String]
) -> Array[String]:
	var errors: Array[String] = []
	var profiles = audit.get("profiles")
	if not profiles is Array:
		return ["audit.profiles.type: profiles must be an Array"]

	var declared_families = audit.get("executor_families")
	if not declared_families is Dictionary:
		errors.append("audit.executor_families.type: executor_families must be a Dictionary")
	else:
		var declared_ids: Array[String] = []
		for raw_id in (declared_families as Dictionary).keys():
			declared_ids.append(str(raw_id))
		declared_ids.sort()
		if declared_ids != strategy_ids:
			errors.append(
				"audit.executor_families.mismatch: expected %s, got %s"
				% [strategy_ids, declared_ids]
			)
		for family in strategy_ids:
			var declared_keys: Array[String] = []
			for raw_param in (declared_families as Dictionary).get(family, []):
				declared_keys.append(str(raw_param))
			declared_keys.sort()
			var live_keys := Library.parameter_keys(family)
			if declared_keys != live_keys:
				errors.append(
					"audit.executor_params.mismatch: %s expected %s, got %s"
					% [family, live_keys, declared_keys]
				)

	var primitive_ids := _ids_from(audit.get("missing_generic_primitives", []))
	var generalization_ids := _ids_from(audit.get("parameter_generalizations", []))
	var seen := {}
	var classified_pairs := 0
	var spotter: Dictionary = {}
	for raw_entry in profiles:
		if not raw_entry is Dictionary:
			errors.append("audit.profile.type: every profile must be a Dictionary")
			continue
		var entry := raw_entry as Dictionary
		var class_id := str(entry.get("class_id", ""))
		var weapon_id := str(entry.get("weapon_id", ""))
		var key := Resolver.profile_key(class_id, weapon_id)
		if seen.has(key):
			errors.append("audit.pair.duplicate: %s" % key)
		else:
			seen[key] = true
		if not canonical_pairs.has(key):
			errors.append("audit.pair.extra: %s" % key)

		var classification := str(entry.get("classification", ""))
		if not CLASSIFICATIONS.has(classification):
			errors.append("audit.classification.invalid: %s" % classification)
		else:
			classified_pairs += 1
		var family := str(entry.get("executor_family", ""))
		if str(entry.get("generalization_id", "")) == "aimed_sequence.marked_target_zone":
			spotter = entry
		if not strategy_ids.has(family):
			errors.append("audit.executor_family.unknown: %s" % family)

		match classification:
			"expressible_now":
				var params = entry.get("params")
				if not params is Dictionary:
					errors.append("audit.params.type: %s must declare params" % key)
				elif declared_families is Dictionary:
					var expected_keys: Array[String] = []
					for raw_param in (declared_families as Dictionary).get(family, []):
						expected_keys.append(str(raw_param))
					var actual_keys: Array[String] = []
					for raw_param in (params as Dictionary).keys():
						actual_keys.append(str(raw_param))
					expected_keys.sort()
					actual_keys.sort()
					if actual_keys != expected_keys:
						errors.append(
							"audit.params.incomplete: %s expected %s, got %s"
							% [key, expected_keys, actual_keys]
						)
					for contract_error in Library.validate_params(family, params as Dictionary):
						errors.append("audit.%s: %s" % [key, contract_error])
			"needs_param_generalization":
				var missing_parameters = entry.get("missing_parameters")
				if not missing_parameters is Array or (missing_parameters as Array).is_empty():
					errors.append("audit.missing_parameters.empty: %s" % key)
				var generalization_id := str(entry.get("generalization_id", ""))
				if not generalization_ids.has(generalization_id):
					errors.append("audit.generalization.unknown: %s" % generalization_id)
			"needs_new_generic_primitive":
				var missing_primitives = entry.get("missing_primitives")
				if not missing_primitives is Array or (missing_primitives as Array).is_empty():
					errors.append("audit.missing_primitives.empty: %s" % key)
				elif missing_primitives is Array:
					for raw_primitive_id in missing_primitives:
						if not primitive_ids.has(str(raw_primitive_id)):
							errors.append(
								"audit.primitive.unknown: %s references %s"
								% [key, raw_primitive_id]
							)

	for raw_key in canonical_pairs.keys():
		var key := str(raw_key)
		if not seen.has(key):
			errors.append("audit.pair.missing: %s" % key)
	if classified_pairs != canonical_pairs.size():
		errors.append(
			"audit.classification.counts: expected one valid classification per canonical pair, got %d"
			% classified_pairs
		)
	_validate_spotter(spotter, errors)
	return errors


func _ids_from(raw_entries) -> Array[String]:
	var ids: Array[String] = []
	if not raw_entries is Array:
		return ids
	for raw_entry in raw_entries:
		if raw_entry is Dictionary:
			ids.append(str((raw_entry as Dictionary).get("id", "")))
	return ids


func _validate_spotter(spotter: Dictionary, errors: Array[String]) -> void:
	if str(spotter.get("classification", "")) != "needs_param_generalization":
		errors.append("audit.spotter.classification: must need parameter generalization")
	if str(spotter.get("executor_family", "")) != "aimed_sequence":
		errors.append("audit.spotter.family: must retain aimed_sequence as closest family")
	var expected := [
		"anchor_retention",
		"marked_target_anchor",
		"zone_membership",
		"zone_radius",
		"zone_scoped_reacquisition",
	]
	var actual: Array[String] = []
	for raw_parameter in spotter.get("missing_parameters", []):
		actual.append(str(raw_parameter))
	actual.sort()
	if actual != expected:
		errors.append("audit.spotter.missing_parameters: expected %s, got %s" % [expected, actual])


func _test_persisted_packages(
	registry,
	audit: Dictionary,
	canonical_pairs: Dictionary,
	errors: Array[String]
) -> void:
	var package_keys: Array[String] = registry.package_pair_keys()
	_expect(
		registry.package_validation_errors().is_empty(),
		"shipped package discovery must be valid: %s" % [registry.package_validation_errors()],
		errors
	)
	_expect(
		not package_keys.is_empty(),
		"shipped package discovery must expose at least one exact-ready pair",
		errors
	)
	var audited_pairs := _audit_pair_keys(audit)
	var package_pairs := {}
	var executor_paths := {}
	for key in package_keys:
		package_pairs[key] = true
		var parts: Array = key.split("/", false)
		_expect(parts.size() == 2, "package pair must have class/weapon identity: %s" % key, errors)
		if parts.size() != 2:
			continue
		var class_id := str(parts[0])
		var weapon_id := str(parts[1])
		_expect(audited_pairs.has(key), "exact-ready pair is missing from the audit: %s" % key, errors)
		var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
		_expect(
			str(profile.get("implementation_state", "")) == "ready",
			"exact-ready pair must resolve a ready profile: %s" % key,
			errors
		)
		var executor = registry.executor_for(class_id, weapon_id)
		_expect(executor is GDScript, "exact-ready pair must load its executor: %s" % key, errors)
		if not executor is GDScript:
			continue
		var executor_path := (executor as GDScript).resource_path
		_expect(
			executor_path == "res://scripts/ultimates/classes/%s/%s.gd" % [class_id, weapon_id],
			"exact-ready pair must use its class-local executor: %s" % key,
			errors
		)
		_expect(
			not executor_paths.has(executor_path),
			"exact-ready pair must not alias another executor: %s and %s"
			% [key, executor_paths.get(executor_path, "")],
			errors
		)
		executor_paths[executor_path] = key
		var constants := (executor as GDScript).get_script_constant_map()
		var expected_profile_id := "weapon_ultimate.profile.%s.%s" % [class_id, weapon_id]
		var expected_executor_id := "weapon_ultimate.executor.%s.%s" % [class_id, weapon_id]
		_expect(
			str(constants.get("PROFILE_ID", "")) == expected_profile_id,
			"executor PROFILE_ID must retain its own pair identity: %s" % key,
			errors
		)
		_expect(
			str(constants.get("EXECUTOR_ID", "")) == expected_executor_id,
			"executor EXECUTOR_ID must retain its own pair identity: %s" % key,
			errors
		)
		var executor_binding = profile.get("executor", {})
		_expect(executor_binding is Dictionary, "ready profile must declare executor binding: %s" % key, errors)
		if not executor_binding is Dictionary:
			continue
		_expect(
			str((executor_binding as Dictionary).get("strategy_id", "")) == expected_executor_id,
			"ready profile must bind its own executor identity: %s" % key,
			errors
		)
		var normalized := Library.normalize_custom_params(
			(executor_binding as Dictionary).get("params", {}),
			(executor as GDScript).call("parameter_contract")
		)
		_expect(
			(normalized["errors"] as Array).is_empty(),
			"persisted exact-ready params must satisfy the executor contract: %s" % key,
			errors
		)
		_expect(
			registry.resolution_source(class_id, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
			"exact-ready pair must resolve through the weapon profile: %s" % key,
			errors
		)
		var resolved: Dictionary = registry.resolve_executable(
			class_id, weapon_id, PD.ultimate_config(class_id)
		)
		_expect(
			str(resolved.get("class_id", "")) == class_id
				and str(resolved.get("weapon_id", "")) == weapon_id,
			"resolved executable must retain its exact pair identity: %s" % key,
			errors
		)

	var non_ready_pairs := 0
	for raw_key in canonical_pairs.keys():
		var key := str(raw_key)
		if package_pairs.has(key):
			continue
		var parts: Array = key.split("/", false)
		if parts.size() != 2:
			continue
		var class_id := str(parts[0])
		var weapon_id := str(parts[1])
		var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
		if str(profile.get("implementation_state", "")) == "ready":
			_expect(
				registry.resolution_source(class_id, weapon_id, false) == Resolver.SOURCE_UNAVAILABLE,
				"ready data without an exact package must not resolve executable: %s" % key,
				errors
			)
			continue
		non_ready_pairs += 1
		var legacy := PD.ultimate_config(class_id)
		_expect(
			registry.resolution_source(class_id, weapon_id) == Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
			"only a non-ready pair may use legacy fallback: %s" % key,
			errors
		)
		_expect(
			registry.resolve_executable(class_id, weapon_id, legacy) == legacy,
			"non-ready pair must preserve its class fallback: %s" % key,
			errors
		)
	_expect(
		non_ready_pairs == canonical_pairs.size() - package_keys.size(),
		"every canonical pair must be either discovered exact-ready or non-ready",
		errors
	)


func _test_resolution_negative_matrix(registry, errors: Array[String]) -> void:
	var package_keys: Array[String] = registry.package_pair_keys()
	if package_keys.is_empty():
		return
	var selected_key: String = package_keys[0]
	var selected_parts: Array = selected_key.split("/", false)
	if selected_parts.size() != 2:
		return
	var selected_class := str(selected_parts[0])
	var selected_weapon := str(selected_parts[1])
	var profiles: Dictionary = registry.profiles_for_tests()
	var executable_pairs := {selected_key: true}
	var pairs: Dictionary = registry.canonical_pairs_for_tests()
	_expect_unavailable(
		profiles, pairs, selected_class, selected_weapon, {}, {},
		"ready profile without its discovered executor must fail closed", errors
	)
	var declared_profiles := profiles.duplicate(true)
	(declared_profiles[selected_key] as Dictionary)["implementation_state"] = "declared"
	_expect_unavailable(
		declared_profiles, pairs, selected_class, selected_weapon, {}, executable_pairs,
		"non-ready profile must not use a false executor pair", errors
	)

	var same_class_weapons: Array[String] = registry.weapon_ids(selected_class)
	var sibling_weapon := ""
	for weapon_id in same_class_weapons:
		if weapon_id != selected_weapon:
			sibling_weapon = weapon_id
			break
	if not sibling_weapon.is_empty():
		_expect_unavailable(
			profiles, pairs, selected_class, sibling_weapon, {}, executable_pairs,
			"sibling pair must not inherit another weapon executor", errors
		)

	var cross_class := ""
	var cross_weapon := ""
	for class_id in registry.class_ids():
		if class_id == selected_class:
			continue
		var weapons: Array[String] = registry.weapon_ids(class_id)
		if weapons.is_empty():
			continue
		cross_class = class_id
		cross_weapon = weapons[0]
		break
	if not cross_class.is_empty():
		_expect_unavailable(
			profiles, pairs, cross_class, cross_weapon, {}, executable_pairs,
			"cross-class pair must not inherit another class executor", errors
		)

	for invalid_pair in [
		["__unknown_class__", "__unknown_weapon__"],
		["__orphan_class__", "__orphan_weapon__"],
	]:
		var class_id := str(invalid_pair[0])
		var weapon_id := str(invalid_pair[1])
		var invalid_key := Resolver.profile_key(class_id, weapon_id)
		var source := Resolver.resolution_source(
			profiles, pairs, class_id, weapon_id, false, {invalid_key: true}
		)
		_expect(source == Resolver.SOURCE_INVALID_PAIR,
			"unknown/orphan pair must fail closed: %s" % invalid_key, errors)
		_expect(
			Resolver.resolve_executable(profiles, pairs, class_id, weapon_id, {}, false, {invalid_key: true}).is_empty(),
			"unknown/orphan pair must not resolve an executable: %s" % invalid_key,
			errors
		)

	_test_discovery_mutations(registry, selected_key, selected_class, selected_weapon, errors)


func _expect_unavailable(
	profiles: Dictionary,
	pairs: Dictionary,
	class_id: String,
	weapon_id: String,
	legacy: Dictionary,
	executable_pairs: Dictionary,
	message: String,
	errors: Array[String]
) -> void:
	_expect(
		Resolver.resolution_source(
			profiles, pairs, class_id, weapon_id, false, executable_pairs
		) == Resolver.SOURCE_UNAVAILABLE,
		"%s: %s/%s" % [message, class_id, weapon_id],
		errors
	)
	_expect(
		Resolver.resolve_executable(
			profiles, pairs, class_id, weapon_id, legacy, false, executable_pairs
		).is_empty(),
		"%s must not return a profile: %s/%s" % [message, class_id, weapon_id],
		errors
	)


func _test_discovery_mutations(
	registry,
	selected_key: String,
	selected_class: String,
	selected_weapon: String,
	errors: Array[String]
) -> void:
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var relative_path := "%s/%s.json" % [selected_class, selected_weapon]
	var document = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/ultimates/classes/%s" % relative_path)
	)
	var executor = load("res://scripts/ultimates/classes/%s/%s.gd" % [selected_class, selected_weapon])
	_expect(document is Dictionary and executor is GDScript,
		"selected package mutation fixture must load: %s" % selected_key, errors)
	if not document is Dictionary or not executor is GDScript:
		return
	var base_profile: Dictionary = base_profiles.get(selected_key, {})
	var discovery := Discovery.new()

	var malformed := (document as Dictionary).duplicate(true)
	malformed["implementation_state"] = "declared"
	_expect_discovery_error(
		discovery, malformed, relative_path, executor, base_profile, "package.implementation_state",
		"malformed ready declaration must fail closed", errors
	)

	var incomplete := (document as Dictionary).duplicate(true)
	var incomplete_params := incomplete["executor"]["params"] as Dictionary
	if not incomplete_params.is_empty():
		incomplete_params.erase(incomplete_params.keys()[0])
	_expect_discovery_error(
		discovery, incomplete, relative_path, executor, base_profile, "executor_params.missing",
		"incomplete executor params must fail closed", errors
	)

	var sibling_weapon := ""
	for weapon_id in registry.weapon_ids(selected_class):
		if weapon_id != selected_weapon:
			sibling_weapon = weapon_id
			break
	if not sibling_weapon.is_empty():
		var alias := (document as Dictionary).duplicate(true)
		var sibling_profile: Dictionary = registry.catalog_profile_for(selected_class, sibling_weapon)
		var sibling_executor_id := str((sibling_profile["executor"] as Dictionary).get("executor_id", ""))
		alias["executor_id"] = sibling_executor_id
		(alias["executor"] as Dictionary)["strategy_id"] = sibling_executor_id
		_expect_discovery_error(
			discovery, alias, relative_path, executor, base_profile, "package.executor",
			"aliased executor identity must fail closed", errors
		)

		var sibling := (document as Dictionary).duplicate(true)
		sibling["weapon_id"] = sibling_weapon
		_expect_discovery_error(
			discovery, sibling, relative_path, executor, base_profile, "package.path_identity",
			"sibling pair must fail closed", errors
		)

	var cross_class := ""
	for class_id in registry.class_ids():
		if class_id != selected_class:
			cross_class = class_id
			break
	if not cross_class.is_empty():
		var cross_class_document := (document as Dictionary).duplicate(true)
		cross_class_document["class_id"] = cross_class
		_expect_discovery_error(
			discovery, cross_class_document, relative_path, executor, base_profile, "package.path_identity",
			"cross-class pair must fail closed", errors
		)


func _expect_discovery_error(
	discovery,
	document: Dictionary,
	relative_path: String,
	executor,
	base_profile: Dictionary,
	prefix: String,
	message: String,
	errors: Array[String]
) -> void:
	var result: Dictionary = discovery.validate_pair(document, relative_path, executor, base_profile)
	for validation_error in result["errors"]:
		if str(validation_error).contains(prefix):
			return
	errors.append("%s: %s" % [message, result["errors"]])


func _audit_pair_keys(audit: Dictionary) -> Dictionary:
	var result := {}
	var profiles = audit.get("profiles", [])
	if not profiles is Array:
		return result
	for raw_entry in profiles:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		result[Resolver.profile_key(str(entry.get("class_id", "")), str(entry.get("weapon_id", "")))] = true
	return result


func _test_live_parameter_contract(errors: Array[String]) -> void:
	for family in Library.strategy_ids():
		var params := _example_params(family)
		var normalized := Library.normalize_params(family, params)
		_expect(
			(normalized["errors"] as Array).is_empty(),
			"%s positive contract must normalize: %s" % [family, normalized["errors"]],
			errors
		)
		_expect(
			not Library.canonical_parameter_signature(family, params).is_empty(),
			"%s positive contract must have a canonical signature" % family,
			errors
		)

	_expect_param_error(
		"__missing_family__", _example_params("burst"), "executor_family.unknown",
		"unknown executor family must reject with its stable code", errors
	)
	var unknown_key := _example_params("burst")
	unknown_key["__unknown__"] = 1
	_expect_param_error(
		"burst", unknown_key, "executor_params.unknown",
		"unknown executor key must reject with its stable code", errors
	)
	var missing_key := _example_params("burst")
	missing_key.erase("radius")
	_expect_param_error(
		"burst", missing_key, "executor_params.missing",
		"missing executor key must reject with its stable code", errors
	)
	var wrong_type := _example_params("burst")
	wrong_type["radius"] = "not-a-number"
	_expect_param_error(
		"burst", wrong_type, "executor_params.type",
		"wrong executor type must reject with its stable code", errors
	)
	for non_finite in [NAN, INF, -INF]:
		var invalid_number := _example_params("burst")
		invalid_number["radius"] = non_finite
		_expect_param_error(
			"burst", invalid_number, "executor_params.non_finite",
			"non-finite executor number must reject with its stable code", errors
		)
	var negative_radius := _example_params("burst")
	negative_radius["radius"] = -1.0
	_expect_param_error(
		"burst", negative_radius, "executor_params.range",
		"negative radius must reject instead of clamping", errors
	)
	var fractional_count := _example_params("aimed_sequence")
	fractional_count["shot_count"] = 1.5
	_expect_param_error(
		"aimed_sequence", fractional_count, "executor_params.integer",
		"fractional count must reject instead of truncating", errors
	)
	var clamped_interval := _example_params("aimed_sequence")
	clamped_interval["interval"] = 0.0
	_expect_param_error(
		"aimed_sequence", clamped_interval, "executor_params.range",
		"clamped timing alias must reject", errors
	)
	var non_finite_nested := _example_params("status_zone")
	non_finite_nested["status"] = {"duration": {"nested": NAN}}
	_expect_param_error(
		"status_zone", non_finite_nested, "executor_params.non_finite",
		"non-finite nested status leaf must reject", errors
	)
	var missing_modifier_field := _example_params("timed_modifier")
	missing_modifier_field["modifiers"] = {"speed": {"value": 1.2}}
	_expect_param_error(
		"timed_modifier", missing_modifier_field, "executor_params.missing",
		"discarded modifier defaults must reject", errors
	)

	var status_left := _example_params("status_zone")
	status_left["status"] = {"duration": 2.0, "speed_multiplier": 0.5}
	var status_right := _example_params("status_zone")
	status_right["status"] = {"speed_multiplier": 0.5, "duration": 2.0}
	_expect(
		Library.canonical_parameter_signature("status_zone", status_left)
			== Library.canonical_parameter_signature("status_zone", status_right),
		"nested dictionary order must not change a signature",
		errors
	)
	var status_with_dot := status_left.duplicate(true)
	status_with_dot["status"]["dot_damage"] = 99.0
	_expect(
		Library.canonical_parameter_signature("status_zone", status_left)
			== Library.canonical_parameter_signature("status_zone", status_with_dot),
		"executor-discarded dot damage must not create a distinct signature",
		errors
	)
	var properties_left := _example_params("deploy_summon")
	properties_left["properties"] = {"first": {"value": 1}, "second": true}
	var properties_right := _example_params("deploy_summon")
	properties_right["properties"] = {"second": true, "first": {"value": 1}}
	_expect(
		Library.canonical_parameter_signature("deploy_summon", properties_left)
			== Library.canonical_parameter_signature("deploy_summon", properties_right),
		"nested property order must not change a signature",
		errors
	)
	var modifiers_left := _example_params("timed_modifier")
	modifiers_left["modifiers"] = {
		"attack_speed": {"value": 1.2, "op": "mul"},
		"armor": {"value": 5.0, "op": "add"},
	}
	var modifiers_right := _example_params("timed_modifier")
	modifiers_right["modifiers"] = {
		"armor": {"op": "add", "value": 5.0},
		"attack_speed": {"op": "mul", "value": 1.2},
	}
	_expect(
		Library.canonical_parameter_signature("timed_modifier", modifiers_left)
			== Library.canonical_parameter_signature("timed_modifier", modifiers_right),
		"nested modifier order must not change a signature",
		errors
	)


func _example_params(family: String) -> Dictionary:
	match family:
		"aimed_sequence":
			return {"radius": 620.0, "damage": 1.0, "shot_count": 1, "interval": 0.05}
		"burst":
			return {"radius": 320.0, "damage": 1.0, "target_limit": 0}
		"chained_projectile":
			return {"radius": 260.0, "damage": 1.0, "jumps": 1, "hop_delay": 0.05, "falloff": 0.5}
		"control":
			return {
				"radius": 340.0, "damage": 0.0, "target_limit": 0, "knockback": 0.0,
				"status_id": "", "status": {},
			}
		"deploy_summon":
			return {
				"scene": "res://scenes/AllyMinion.tscn", "count": 1, "spawn_radius": 0.0,
				"lifetime": 0.2, "damage": 1.0, "properties": {},
			}
		"status_zone":
			return {
				"radius": 260.0, "damage": 1.0, "duration": 0.2, "interval": 0.05,
				"follow_host": false, "status_id": "", "status": {},
			}
		"timed_modifier":
			return {"duration": 0.2, "radius": 200.0, "modifiers": {}}
	return {}


func _expect_param_error(
	family: String,
	params: Dictionary,
	code: String,
	message: String,
	errors: Array[String]
) -> void:
	for validation_error in Library.validate_params(family, params):
		if str(validation_error).begins_with("%s:" % code):
			return
	errors.append("%s; got %s" % [message, Library.validate_params(family, params)])


func _expect_error_code(
	audit: Dictionary,
	canonical_pairs: Dictionary,
	strategy_ids: Array[String],
	code: String,
	message: String,
	errors: Array[String]
) -> void:
	for validation_error in _validate_audit(audit, canonical_pairs, strategy_ids):
		if str(validation_error).begins_with("%s:" % code):
			return
	errors.append(message)


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _report(errors: Array[String]) -> void:
	if errors.is_empty():
		print(
			"executor_contract_audit_test: PASS "
			+ "(registry-derived exact-ready pairs, non-ready fallback, "
			+ "executor/discovery mutations rejected)."
		)
		quit(0)
		return
	for error in errors:
		push_error("executor_contract_audit_test: %s" % error)
	print("executor_contract_audit_test: FAIL (%d)" % errors.size())
	quit(1)
