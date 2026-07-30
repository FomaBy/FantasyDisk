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

	_demo_sniper_in_memory_distinctness(registry, errors)
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

	var primitive_ids := _ids_from(audit.get("missing_generic_primitives", []))
	var generalization_ids := _ids_from(audit.get("parameter_generalizations", []))
	var seen := {}
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
		var family := str(entry.get("executor_family", ""))
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
	return errors


func _ids_from(raw_entries) -> Array[String]:
	var ids: Array[String] = []
	if not raw_entries is Array:
		return ids
	for raw_entry in raw_entries:
		if raw_entry is Dictionary:
			ids.append(str((raw_entry as Dictionary).get("id", "")))
	return ids


## Exactly one class demonstrates the reusable in-memory contract technique.
func _demo_sniper_in_memory_distinctness(registry, errors: Array[String]) -> void:
	var result := Distinctness.resolve_class_contracts(registry, "sniper", {
		"sniper_deadeye_rifle": {
			"executor_family": "aimed_sequence",
			"params": {"radius": 900.0, "damage": 3.0, "shot_count": 1, "interval": 0.05},
		},
		"sniper_spotter_scope": {
			"executor_family": "aimed_sequence",
			"params": {"radius": 620.0, "damage": 1.0, "shot_count": 9, "interval": 0.28},
		},
		"sniper_shatter_rounds": {
			"executor_family": "chained_projectile",
			"params": {"radius": 260.0, "damage": 0.6, "jumps": 15, "hop_delay": 0.04, "falloff": 0.92},
		},
	})
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
				== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
			"helper must not change persisted %s resolution" % weapon_id,
			errors
		)


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
