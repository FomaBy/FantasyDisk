extends SceneTree

## Mutation-driven validation test for the directory-composed 17 x 3 catalog.
##
## Run:
## Godot --headless --path . \
##   --script res://tests/ultimates/registry_validator_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	var valid_documents: Array = registry.documents_for_tests()

	_expect(
		Schema.validate_documents(valid_documents, PD.WEAPONS_BY_CLASS).is_empty(),
		"canonical documents must validate",
		errors
	)

	var missing_pair := valid_documents.duplicate(true)
	(missing_pair[0]["profiles"] as Array).remove_at(2)
	_expect_error_code(
		missing_pair,
		"catalog.pair.missing",
		"missing canonical pair must be rejected",
		errors
	)

	var duplicate_pair := valid_documents.duplicate(true)
	(duplicate_pair[0]["profiles"] as Array).append(
		(duplicate_pair[0]["profiles"][0] as Dictionary).duplicate(true)
	)
	_expect_error_code(
		duplicate_pair,
		"profile.pair.duplicate",
		"duplicate class/weapon pair must be rejected",
		errors
	)

	var unknown_class := valid_documents.duplicate(true)
	unknown_class[0]["class_id"] = "__unknown_class__"
	_expect_error_code(
		unknown_class,
		"catalog.class_id.unknown",
		"unknown class must be rejected",
		errors
	)

	var unknown_weapon := valid_documents.duplicate(true)
	unknown_weapon[0]["profiles"][0]["weapon_id"] = "__unknown_weapon__"
	_expect_error_code(
		unknown_weapon,
		"profile.weapon_id.unknown",
		"unknown weapon must be rejected",
		errors
	)

	_expect_duplicate_id_rejected(
		valid_documents,
		"identity",
		"profile_id",
		"profile.identity.profile_id.duplicate",
		errors
	)
	_expect_duplicate_id_rejected(
		valid_documents,
		"identity",
		"title_id",
		"profile.identity.title_id.duplicate",
		errors
	)
	_expect_duplicate_id_rejected(
		valid_documents,
		"identity",
		"mechanic_id",
		"profile.identity.mechanic_id.duplicate",
		errors
	)
	_expect_duplicate_id_rejected(
		valid_documents,
		"presentation",
		"presentation_id",
		"profile.presentation.presentation_id.duplicate",
		errors
	)

	var declared_executor := valid_documents.duplicate(true)
	declared_executor[0]["profiles"][0]["executor"]["strategy_id"] = "premature_binding"
	_expect_error_code(
		declared_executor,
		"profile.executor.declared_strategy",
		"declared profile must not bind an executor",
		errors
	)

	var ready_without_cap := valid_documents.duplicate(true)
	ready_without_cap[0]["profiles"][0]["implementation_state"] = "ready"
	for binding_field in ["targeting", "charge", "executor", "cleanup_policy"]:
		ready_without_cap[0]["profiles"][0][binding_field]["strategy_id"] = "test_ready"
	_expect_error_code(
		ready_without_cap,
		"profile.total_boss_cap.type",
		"ready profile must declare a whole-activation boss cap",
		errors
	)

	# A profile flagged ready while its executor is still unbound is the exact
	# state that would let a placeholder executor run in game, so it must be
	# rejected even when every other ready requirement is satisfied.
	var ready_unbound_executor := valid_documents.duplicate(true)
	ready_unbound_executor[0]["profiles"][0]["implementation_state"] = "ready"
	ready_unbound_executor[0]["profiles"][0]["total_boss_cap"] = 0.5
	for binding_field in ["targeting", "charge", "cleanup_policy"]:
		ready_unbound_executor[0]["profiles"][0][binding_field]["strategy_id"] = "test_ready"
	_expect_error_code(
		ready_unbound_executor,
		"profile.executor.ready_strategy",
		"ready profile must not keep an unbound executor",
		errors
	)

	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate registry validator: %s" % error)
		push_error("Weapon ultimate registry validator test: %d errors." % errors.size())
		quit(1)
		return
	print(
		"Weapon ultimate registry validator passed "
		+ "(missing/duplicate/unknown pairs and unique IDs are fail-closed)."
	)
	quit(0)


func _expect_duplicate_id_rejected(
	valid_documents: Array,
	container_name: String,
	field_name: String,
	expected_code: String,
	errors: Array[String]
) -> void:
	var documents := valid_documents.duplicate(true)
	var first_container: Dictionary = documents[0]["profiles"][0][container_name]
	var second_container: Dictionary = documents[0]["profiles"][1][container_name]
	second_container[field_name] = first_container[field_name]
	_expect_error_code(
		documents,
		expected_code,
		"duplicate %s/%s must be rejected" % [container_name, field_name],
		errors
	)


func _expect_error_code(
	documents: Array,
	expected_code: String,
	message: String,
	errors: Array[String]
) -> void:
	var validation_errors := Schema.validate_documents(documents, PD.WEAPONS_BY_CLASS)
	for validation_error in validation_errors:
		if str(validation_error).begins_with("%s:" % expected_code):
			return
	errors.append("%s; got %s" % [message, validation_errors])


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
