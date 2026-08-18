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

	_check_v2_contract(catalog, expected_profiles, errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate presentation validator: %s" % error)
		push_error("Weapon ultimate presentation validator test: %d errors." % errors.size())
		quit(1)
		return
	print("Weapon ultimate presentation validator passed (phases, assets, IDs, paths, pivots, timing and the v2 envelope/presence/identity/ratchet fail closed).")
	quit(0)


## Every v2 assertion (envelope, presence, identity, ratchet) must be provable
## red: each negative control below flips exactly one declaration on a
## v2-ready fixture validated with an EMPTY allowlist.
func _check_v2_contract(catalog: Dictionary, expected_profiles: Dictionary, errors: Array[String]) -> void:
	var key := "berserk/sword"
	var v2_profiles := {key: expected_profiles[key]}
	var v2_ready := [_v2_ready_manifest(catalog, key, "berserk_cast_overhead")]
	_expect(
		Schema.validate_catalog(v2_ready, v2_profiles, {}).is_empty(),
		"v2-ready manifest must validate outside the allowlist; got %s" % [Schema.validate_catalog(v2_ready, v2_profiles, {})],
		errors
	)
	_expect(
		not Schema.validate_catalog(_manifest_array(catalog), expected_profiles, {}).is_empty(),
		"v1 catalog outside the allowlist must be asserted against v2 and fail closed",
		errors
	)

	_expect_v2_code(catalog, v2_profiles, key, "timing", {"cancel": 4.6}, "presentation.v2.total_range", errors)
	_expect_v2_code(catalog, v2_profiles, key, "timing", {"release": 0.4}, "presentation.v2.windup_range", errors)
	_expect_v2_code(catalog, v2_profiles, key, "timing", {"recovery": 1.9}, "presentation.v2.active_window", errors)
	_expect_v2_code(catalog, v2_profiles, key, "timing", {"recovery": 3.0}, "presentation.v2.recovery_window", errors)
	_expect_v2_code(catalog, v2_profiles, key, "", {"presence": null}, "presentation.v2.presence", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"fullscreen_footprint": false}, "presentation.v2.footprint", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"backdrop": "sparkle"}, "presentation.v2.backdrop", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"camera_shake": null}, "presentation.v2.camera_shake", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"hitstop_ms": 60}, "presentation.v2.hitstop", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"hitstop_ms": 200}, "presentation.v2.hitstop", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"hitstop_ms": null}, "presentation.v2.hitstop", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"time_scale_dip": 0.7}, "presentation.v2.time_scale_dip", errors)
	_expect_v2_code(catalog, v2_profiles, key, "presence", {"sfx_ducking": false}, "presentation.v2.sfx_ducking", errors)
	_expect_v2_code(catalog, v2_profiles, key, "", {"identity": null}, "presentation.v2.identity", errors)
	_expect_v2_code(catalog, v2_profiles, key, "identity", {"cast_pose_id": ""}, "presentation.v2.cast_pose", errors)
	_expect_v2_code(catalog, v2_profiles, key, "identity", {"weapon_silhouette_asset": "res://assets/sprites/effects/__missing_core__.png"}, "presentation.v2.weapon_silhouette", errors)
	_expect_v2_code(catalog, v2_profiles, key, "identity", {"weapon_silhouette_asset": "res://assets/sprites/effects/placeholder_burst.png"}, "presentation.v2.weapon_silhouette", errors)
	_expect_v2_code(catalog, v2_profiles, key, "identity", {"class_palette_id": ""}, "presentation.v2.class_palette", errors)

	# A generic burst asset shared across two (class_id, weapon_id) keys fails
	# closed; a cast pose shared inside one class stays legal.
	var second_key := "berserk/axe"
	var pair_profiles := {key: expected_profiles[key], second_key: expected_profiles[second_key]}
	var shared_burst := [
		_v2_ready_manifest(catalog, key, "berserk_cast_overhead"),
		_v2_ready_manifest(catalog, second_key, "berserk_cast_overhead"),
	]
	(shared_burst[1]["identity"] as Dictionary)["weapon_silhouette_asset"] = \
		(shared_burst[0]["identity"] as Dictionary)["weapon_silhouette_asset"]
	_expect_catalog_code(shared_burst, pair_profiles, "presentation.v2.generic_burst", "generic burst reuse must fail closed", errors)

	var distinct_pair := [
		_v2_ready_manifest(catalog, key, "berserk_cast_overhead"),
		_v2_ready_manifest(catalog, second_key, "berserk_cast_overhead"),
	]
	_expect(
		Schema.validate_catalog(distinct_pair, pair_profiles, {}).is_empty(),
		"one class sharing its hero cast pose across its trio must stay valid; got %s" % [Schema.validate_catalog(distinct_pair, pair_profiles, {})],
		errors
	)

	var foreign_key := "assassin/chakrams"
	var cross_profiles := {key: expected_profiles[key], foreign_key: expected_profiles[foreign_key]}
	var cross_pose := [
		_v2_ready_manifest(catalog, key, "berserk_cast_overhead"),
		_v2_ready_manifest(catalog, foreign_key, "berserk_cast_overhead"),
	]
	_expect_catalog_code(cross_pose, cross_profiles, "presentation.v2.cast_pose_reuse", "cross-class cast pose reuse must fail closed", errors)

	# Ratchet semantics: a listed pair that already satisfies v2 is stale; an
	# entry naming no registry pair or stating no reason fails.
	var stale := [_v2_ready_manifest(catalog, key, "berserk_cast_overhead")]
	var stale_errors := Schema.validate_catalog(stale, v2_profiles, {key: "listed reason"})
	_expect_code_present(stale_errors, "presentation.v2_allowlist.stale", "stale allowlist entry must fail closed", errors)
	_expect_code_present(
		Schema.allowlist_integrity_errors(v2_profiles, {"nobody/nothing": "reason"}),
		"presentation.v2_allowlist.unknown",
		"allowlist entry naming no registry pair must fail closed",
		errors
	)
	_expect_code_present(
		Schema.allowlist_integrity_errors(v2_profiles, {key: "  "}),
		"presentation.v2_allowlist.reason",
		"allowlist entry stating no reason must fail closed",
		errors
	)
	_expect(
		Schema.allowlist_integrity_errors(expected_profiles).is_empty(),
		"shipped allowlist must satisfy its own integrity rules",
		errors
	)


func _v2_ready_manifest(catalog: Dictionary, key: String, cast_pose_id: String) -> Dictionary:
	var manifest: Dictionary = (catalog[key] as Dictionary).duplicate(true)
	manifest["timing"] = {"windup": 0.0, "release": 0.8, "active": 1.6, "recovery": 2.4, "cancel": 3.0}
	manifest["presence"] = {
		"fullscreen_footprint": true,
		"backdrop": "darken",
		"camera_shake": true,
		"hitstop_ms": 110,
		"time_scale_dip": 0.4,
		"sfx_ducking": true,
	}
	manifest["identity"] = {
		"cast_pose_id": cast_pose_id,
		"weapon_silhouette_asset": str((manifest["vfx"] as Dictionary)["source_path"]),
		"class_palette_id": "%s_palette" % str(manifest.get("class_id", "")),
	}
	return manifest


## Applies one mutation to the v2-ready fixture and expects the exact code.
## An empty block mutates the manifest root; a null value erases the field.
func _expect_v2_code(
	catalog: Dictionary,
	v2_profiles: Dictionary,
	key: String,
	block: String,
	mutation: Dictionary,
	expected_code: String,
	errors: Array[String]
) -> void:
	var manifest := _v2_ready_manifest(catalog, key, "berserk_cast_overhead")
	var target: Dictionary = manifest
	if not block.is_empty():
		target = manifest[block] as Dictionary
	for field in mutation:
		if mutation[field] == null:
			target.erase(field)
		else:
			target[field] = mutation[field]
	_expect_catalog_code([manifest], v2_profiles, expected_code, "%s must fail closed" % expected_code, errors)


func _expect_catalog_code(
	manifests: Array,
	profiles: Dictionary,
	expected_code: String,
	message: String,
	errors: Array[String]
) -> void:
	_expect_code_present(Schema.validate_catalog(manifests, profiles, {}), expected_code, message, errors)


func _expect_code_present(validation_errors: Array[String], expected_code: String, message: String, errors: Array[String]) -> void:
	for validation_error in validation_errors:
		if str(validation_error).begins_with("%s:" % expected_code):
			return
	errors.append("%s; got %s" % [message, validation_errors])


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
