extends SceneTree

## Fail-closed contract for the 51-profile executor audit.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/executor_contract_audit_test.gd

const AUDIT_PATH := "res://docs/design/references/weapon_ultimates/executor_contract_audit.json"
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const Distinctness := preload("res://tests/ultimates/weapon_ultimate_distinctness_helper.gd")

const CLASSIFICATIONS := [
	"expressible_now",
	"needs_param_generalization",
	"needs_new_generic_primitive",
]
const EXPECTED_CLASSIFICATION_COUNTS := {
	"expressible_now": 0,
	"needs_param_generalization": 6,
	"needs_new_generic_primitive": 45,
}


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
	_demo_sniper_in_memory_distinctness(registry, audit, errors)
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
	var classification_counts: Dictionary = {
		"expressible_now": 0,
		"needs_param_generalization": 0,
		"needs_new_generic_primitive": 0,
	}
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
		classification_counts[classification] = int(classification_counts.get(classification, 0)) + 1
		if not CLASSIFICATIONS.has(classification):
			errors.append("audit.classification.invalid: %s" % classification)
		var family := str(entry.get("executor_family", ""))
		if key == "sniper/sniper_spotter_scope":
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
	if classification_counts != EXPECTED_CLASSIFICATION_COUNTS:
		errors.append(
			"audit.classification.counts: expected %s, got %s"
			% [EXPECTED_CLASSIFICATION_COUNTS, classification_counts]
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


## Exactly one class demonstrates the reusable in-memory contract technique.
func _demo_sniper_in_memory_distinctness(registry, audit: Dictionary, errors: Array[String]) -> void:
	var result := Distinctness.resolve_class_contracts(registry, audit, "sniper", _sniper_contracts())
	_expect(
		(result["errors"] as Array).is_empty(),
		"sniper in-memory contracts must resolve distinctly: %s" % str(result["errors"]),
		errors
	)
	_expect(
		(result["contracts"] as Dictionary).size() == 3,
		"sniper demonstration must resolve exactly three contracts",
		errors
	)
	for weapon_id in registry.weapon_ids("sniper"):
		_expect(
			str(registry.resolution_source("sniper", weapon_id))
				== Resolver.SOURCE_WEAPON_PROFILE,
			"helper must preserve persisted ready %s resolution" % weapon_id,
			errors
		)

	var unknown_family := _sniper_contracts()
	unknown_family["sniper_deadeye_rifle"]["executor_family"] = "__missing_family__"
	_expect_distinctness_error(
		registry, audit, unknown_family,
		"sniper/sniper_deadeye_rifle executor_family.unknown:",
		"unknown executor family must fail closed", errors
	)

	var unknown_parameter := _sniper_contracts()
	unknown_parameter["sniper_deadeye_rifle"]["params"]["__unknown_param__"] = 1.0
	_expect_distinctness_error(
		registry, audit, unknown_parameter,
		"sniper/sniper_deadeye_rifle executor_params.unknown:",
		"unknown executor parameter must fail closed", errors
	)

	var invalid_parameter := _sniper_contracts()
	invalid_parameter["sniper_deadeye_rifle"]["params"]["radius"] = "not-a-number"
	_expect_distinctness_error(
		registry, audit, invalid_parameter,
		"sniper/sniper_deadeye_rifle executor_params.type:",
		"invalid executor parameter must fail closed", errors
	)

	var audit_family_mismatch := _sniper_contracts()
	audit_family_mismatch["sniper_deadeye_rifle"] = {
		"executor_family": "burst",
		"params": {"radius": 900.0, "damage": 3.0, "target_limit": 1},
	}
	_expect_distinctness_error(
		registry, audit, audit_family_mismatch,
		"sniper/sniper_deadeye_rifle executor_family.audit_mismatch:",
		"audit/helper executor family mismatch must fail closed", errors
	)


func _sniper_contracts() -> Dictionary:
	return {
		"sniper_deadeye_rifle": {
			"executor_family": "aimed_sequence",
			"params": {"radius": 900.0, "damage": 3.0, "shot_count": 1, "interval": 0.05},
		},
		"sniper_spotter_scope": {
			"executor_family": "aimed_sequence",
			"params": {"radius": 620.0, "damage": 1.0, "shot_count": 9, "interval": 0.28},
		},
		"sniper_shatter_rounds": {
			"executor_family": "aimed_sequence",
			"params": {"radius": 760.0, "damage": 1.4, "shot_count": 5, "interval": 0.08},
		},
	}


func _expect_distinctness_error(
	registry,
	audit: Dictionary,
	contracts: Dictionary,
	expected_prefix: String,
	message: String,
	errors: Array[String]
) -> void:
	var result := Distinctness.resolve_class_contracts(registry, audit, "sniper", contracts)
	for validation_error in result["errors"]:
		if str(validation_error).begins_with(expected_prefix):
			return
	errors.append("%s; got %s" % [message, result["errors"]])


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
			+ "(51 exact pairs, three classifications, seven live families, "
			+ "missing/extra/duplicate mutations rejected)."
		)
		quit(0)
		return
	for error in errors:
		push_error("executor_contract_audit_test: %s" % error)
	print("executor_contract_audit_test: FAIL (%d)" % errors.size())
	quit(1)
