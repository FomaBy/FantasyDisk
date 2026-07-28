extends SceneTree

## Mutation-driven fail-closed coverage for the presentation manifest validator.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	var catalog := Manifest.catalog_for_registry(registry)
	var expected_profiles := Manifest.expected_profiles_for_registry(registry)
	var valid := _manifest_array(catalog)
	_expect(Schema.validate_catalog(valid, expected_profiles).is_empty(), "canonical manifest must validate", errors)

	var missing_phase := _manifest_array(catalog)
	(missing_phase[0]["phases"] as Array).remove_at(4)
	_expect_error_code(missing_phase, expected_profiles, "presentation.phase.missing", "missing phase must fail closed", errors)

	var duplicate_phase := _manifest_array(catalog)
	duplicate_phase[0]["phases"][4]["name"] = "windup"
	_expect_error_code(duplicate_phase, expected_profiles, "presentation.phase.duplicate", "duplicate phase must fail closed", errors)

	var missing_asset := _manifest_array(catalog)
	missing_asset[0]["vfx"]["source_path"] = "res://assets/sprites/effects/__missing_ultimate_vfx__.png"
	_expect_error_code(missing_asset, expected_profiles, "presentation.asset.vfx.source_missing", "missing asset must fail closed", errors)

	_expect_duplicate_id(catalog, expected_profiles, "presentation_id", "presentation.presentation_id.duplicate", errors)
	for channel in ["animation", "vfx", "sfx"]:
		_expect_duplicate_id(catalog, expected_profiles, "%s.id" % channel, "presentation.%s_id.duplicate" % channel, errors)

	var placeholder_reuse := _manifest_array(catalog)
	placeholder_reuse[0]["vfx"]["source_path"] = "res://assets/sprites/effects/placeholder_ultimate.png"
	_expect_error_code(placeholder_reuse, expected_profiles, "presentation.asset.vfx.placeholder", "placeholder reuse must fail closed", errors)

	var invalid_path := _manifest_array(catalog)
	invalid_path[0]["animation"]["runtime_path"] = "../outside.tres"
	_expect_error_code(invalid_path, expected_profiles, "presentation.asset.animation.runtime_path", "invalid runtime path must fail closed", errors)

	var invalid_pivot := _manifest_array(catalog)
	invalid_pivot[0]["pivot"]["x"] = 1.1
	_expect_error_code(invalid_pivot, expected_profiles, "presentation.pivot.range", "out-of-range pivot must fail closed", errors)

	var invalid_timing := _manifest_array(catalog)
	invalid_timing[0]["timing"]["windup"] = -0.1
	_expect_error_code(invalid_timing, expected_profiles, "presentation.timing.range", "out-of-range timing must fail closed", errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate presentation validator: %s" % error)
		push_error("Weapon ultimate presentation validator test: %d errors." % errors.size())
		quit(1)
		return
	print("Weapon ultimate presentation validator passed (phases, assets, IDs, paths, pivots and timing fail closed).")
	quit(0)


func _expect_duplicate_id(catalog: Dictionary, expected_profiles: Dictionary, field: String, expected_code: String, errors: Array[String]) -> void:
	var manifests := _manifest_array(catalog)
	if field == "presentation_id":
		manifests[1][field] = manifests[0][field]
	else:
		var parts := field.split(".")
		manifests[1][parts[0]][parts[1]] = manifests[0][parts[0]][parts[1]]
	_expect_error_code(manifests, expected_profiles, expected_code, "duplicate %s must fail closed" % field, errors)


func _expect_error_code(manifests: Array, expected_profiles: Dictionary, expected_code: String, message: String, errors: Array[String]) -> void:
	var validation_errors := Schema.validate_catalog(manifests, expected_profiles)
	for validation_error in validation_errors:
		if str(validation_error).begins_with("%s:" % expected_code):
			return
	errors.append("%s; got %s" % [message, validation_errors])


func _manifest_array(catalog: Dictionary) -> Array:
	var manifests: Array = []
	for key in catalog.keys():
		manifests.append((catalog[key] as Dictionary).duplicate(true))
	return manifests


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
