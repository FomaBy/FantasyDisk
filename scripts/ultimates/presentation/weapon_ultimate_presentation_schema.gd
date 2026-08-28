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

## Ultimate Direction v2 (FAN-2944 §1/§3.1) envelope and presence ranges. All
## five timing values are cumulative beat timestamps, so the ranges below are
## checked on beat differences, never on raw timestamps.
const V2_TOTAL_RANGE_SECONDS := [2.5, 4.0]
const V2_WINDUP_RANGE_SECONDS := [0.6, 1.0]
const V2_MIN_ACTIVE_WINDOW_SECONDS := 1.2
const V2_HITSTOP_RANGE_MS := [80.0, 150.0]
const V2_TIME_SCALE_DIP_RANGE := [0.3, 0.5]
const V2_BACKDROP_TREATMENTS: Array[String] = ["darken", "flash"]
const V2_EPSILON := 0.000001

const V2_SEED_REASON := "shipped under the v1 envelope before FAN-2948; awaiting its class rework card"

## Ratchet with the same rules as ContactSheetBeatsContract.MIGRATION_ALLOWLIST
## and the timing test's PARITY_EXEMPTIONS: it only shrinks, its target state is
## empty, an entry for a pair that already satisfies the v2 contract fails as
## stale, an entry naming no registry pair or stating no reason fails, and a
## pair outside it is asserted against the full v2 contract fail-closed. Each
## class rework card removes its own entries.
const PRESENTATION_V2_MIGRATION_ALLOWLIST := {
	"doctor/restore_potion": V2_SEED_REASON,
	"doctor/plague_syringe": V2_SEED_REASON,
	"doctor/bone_saw": V2_SEED_REASON,
	"druid/summon_amulet": V2_SEED_REASON,
	"druid/briar_staff": V2_SEED_REASON,
	"druid/raven_totem": V2_SEED_REASON,
	"elementalist/elementalist_orb_ring": V2_SEED_REASON,
	"elementalist/elementalist_prism_focus": V2_SEED_REASON,
	"elementalist/elementalist_meteor_core": V2_SEED_REASON,
	"engineer/engineer_repair_drone": V2_SEED_REASON,
	"engineer/engineer_pressure_mines": V2_SEED_REASON,
	"guitarist/electric_guitar": V2_SEED_REASON,
	"guitarist/bass_guitar": V2_SEED_REASON,
	"guitarist/sound_amp": V2_SEED_REASON,
	"knight/long_spear": V2_SEED_REASON,
	"knight/tower_shield": V2_SEED_REASON,
	"knight/holy_flail": V2_SEED_REASON,
	"priest/priest_reliquary": V2_SEED_REASON,
	"priest/priest_censer": V2_SEED_REASON,
	"priest/priest_chime": V2_SEED_REASON,
	"ranger/moon_crossbow": V2_SEED_REASON,
	"ranger/storm_longbow": V2_SEED_REASON,
	"ranger/hunter_trap": V2_SEED_REASON,
	"robot/robot_magnetic_anchor": V2_SEED_REASON,
	"robot/robot_hydraulic_press": V2_SEED_REASON,
	"robot/robot_reactor_core": V2_SEED_REASON,
}

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


static func validate_manifest(
	manifest: Dictionary,
	expected_profile: Dictionary = {},
	allowlist: Dictionary = PRESENTATION_V2_MIGRATION_ALLOWLIST
) -> Array[String]:
	var errors: Array[String] = []
	var schema := schema_document()
	if schema.is_empty():
		_add_error(errors, "presentation.schema.missing", SCHEMA_PATH)
		return errors
	if int(schema.get("schema_version", 0)) != EXPECTED_SCHEMA_VERSION:
		_add_error(errors, "presentation.schema.version", "expected %d" % EXPECTED_SCHEMA_VERSION)
	_validate_manifest(manifest, expected_profile, schema, {}, allowlist, errors)
	return errors


static func validate_catalog(
	manifests: Array,
	expected_profiles: Dictionary,
	allowlist: Dictionary = PRESENTATION_V2_MIGRATION_ALLOWLIST
) -> Array[String]:
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
		_validate_manifest(manifest, expected_profile as Dictionary, schema, seen_ids, allowlist, errors)

	for expected_key in expected_profiles.keys():
		if not seen_keys.has(expected_key):
			_add_error(errors, "presentation.profile.missing", str(expected_key))
	return errors


static func _validate_manifest(
	manifest: Dictionary,
	expected_profile: Dictionary,
	schema: Dictionary,
	seen_ids: Dictionary,
	allowlist: Dictionary,
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

	var catalog_scope := seen_ids.has("__catalog_tracking__")
	if allowlist.has(profile_key_value):
		# Stale-entry detection only runs with catalog scope so the runtime
		# single-manifest path never rejects a live activation over the ratchet.
		if catalog_scope and _v2_violations(manifest, profile_key_value, seen_ids, false).is_empty():
			_add_error(errors, "presentation.v2_allowlist.stale", "%s already satisfies the v2 contract" % profile_key_value)
	else:
		errors.append_array(_v2_violations(manifest, profile_key_value, seen_ids, catalog_scope))


## Every allowlist entry must name a live registry pair and state a reason.
## Enforced by the shared contract test on the full catalog, exactly like the
## other ratchets; kept here so tests can also prove it goes red.
static func allowlist_integrity_errors(
	expected_profiles: Dictionary,
	allowlist: Dictionary = PRESENTATION_V2_MIGRATION_ALLOWLIST
) -> Array[String]:
	var errors: Array[String] = []
	for raw_key in allowlist:
		var key := str(raw_key)
		if not expected_profiles.has(key):
			_add_error(errors, "presentation.v2_allowlist.unknown", key)
		if str(allowlist[raw_key]).strip_edges().is_empty():
			_add_error(errors, "presentation.v2_allowlist.reason", key)
	return errors


## The v2 envelope on the cumulative beat timestamps. Public so the shared
## timing distinctness test asserts the identical ranges on class declarations.
static func v2_envelope_errors(raw_timing, profile_key_value: String) -> Array[String]:
	var errors: Array[String] = []
	if not raw_timing is Dictionary:
		_add_error(errors, "presentation.v2.timing", profile_key_value)
		return errors
	var timing := raw_timing as Dictionary
	for name in ["windup", "release", "recovery", "cancel"]:
		if not _is_number(timing.get(name)):
			_add_error(errors, "presentation.v2.timing", "%s/%s" % [profile_key_value, name])
			return errors
	var windup := float(timing["windup"])
	var release := float(timing["release"])
	var recovery := float(timing["recovery"])
	var cancel := float(timing["cancel"])
	var total := cancel - windup
	if total + V2_EPSILON < float(V2_TOTAL_RANGE_SECONDS[0]) or total - V2_EPSILON > float(V2_TOTAL_RANGE_SECONDS[1]):
		_add_error(errors, "presentation.v2.total_range", "%s is %.2fs" % [profile_key_value, total])
	var windup_window := release - windup
	if windup_window + V2_EPSILON < float(V2_WINDUP_RANGE_SECONDS[0]) \
			or windup_window - V2_EPSILON > float(V2_WINDUP_RANGE_SECONDS[1]):
		_add_error(errors, "presentation.v2.windup_range", "%s is %.2fs" % [profile_key_value, windup_window])
	if recovery - release + V2_EPSILON < V2_MIN_ACTIVE_WINDOW_SECONDS:
		_add_error(errors, "presentation.v2.active_window", "%s is %.2fs" % [profile_key_value, recovery - release])
	if cancel - recovery <= V2_EPSILON:
		_add_error(errors, "presentation.v2.recovery_window", "%s has no visible recovery" % profile_key_value)
	return errors


static func _v2_violations(
	manifest: Dictionary,
	profile_key_value: String,
	seen_ids: Dictionary,
	register: bool
) -> Array[String]:
	var violations := v2_envelope_errors(manifest.get("timing", {}), profile_key_value)
	_v2_check_presence(manifest.get("presence"), profile_key_value, violations)
	_v2_check_identity(manifest, profile_key_value, seen_ids, register, violations)
	return violations


static func _v2_check_presence(raw_presence, profile_key_value: String, violations: Array[String]) -> void:
	if not raw_presence is Dictionary:
		_add_error(violations, "presentation.v2.presence", profile_key_value)
		return
	var presence := raw_presence as Dictionary
	if presence.get("fullscreen_footprint") != true:
		_add_error(violations, "presentation.v2.footprint", profile_key_value)
	if not V2_BACKDROP_TREATMENTS.has(str(presence.get("backdrop", ""))):
		_add_error(violations, "presentation.v2.backdrop", profile_key_value)
	if presence.get("camera_shake") != true:
		_add_error(violations, "presentation.v2.camera_shake", profile_key_value)
	var hitstop = presence.get("hitstop_ms")
	if not _is_number(hitstop) or float(hitstop) < float(V2_HITSTOP_RANGE_MS[0]) \
			or float(hitstop) > float(V2_HITSTOP_RANGE_MS[1]):
		_add_error(violations, "presentation.v2.hitstop", "%s declares %s" % [profile_key_value, str(hitstop)])
	if presence.has("time_scale_dip"):
		var dip = presence["time_scale_dip"]
		if not _is_number(dip) or float(dip) < float(V2_TIME_SCALE_DIP_RANGE[0]) \
				or float(dip) > float(V2_TIME_SCALE_DIP_RANGE[1]):
			_add_error(violations, "presentation.v2.time_scale_dip", "%s declares %s" % [profile_key_value, str(dip)])
	if presence.get("sfx_ducking") != true:
		_add_error(violations, "presentation.v2.sfx_ducking", profile_key_value)


static func _v2_check_identity(
	manifest: Dictionary,
	profile_key_value: String,
	seen_ids: Dictionary,
	register: bool,
	violations: Array[String]
) -> void:
	var raw_identity = manifest.get("identity")
	if not raw_identity is Dictionary:
		_add_error(violations, "presentation.v2.identity", profile_key_value)
		return
	var identity := raw_identity as Dictionary
	var class_id := str(manifest.get("class_id", ""))
	var catalog_scope := seen_ids.has("__catalog_tracking__")

	var cast_pose := str(identity.get("cast_pose_id", ""))
	if cast_pose.is_empty() or _contains_placeholder(cast_pose):
		_add_error(violations, "presentation.v2.cast_pose", profile_key_value)
	elif catalog_scope:
		# The cast pose is hero-specific: one class may share it across its
		# trio, a second class reusing it fails closed.
		var pose_key := "v2_cast_pose::%s" % cast_pose
		if seen_ids.has(pose_key) and str(seen_ids[pose_key]) != class_id:
			_add_error(violations, "presentation.v2.cast_pose_reuse", "%s reuses %s" % [profile_key_value, cast_pose])
		elif register:
			seen_ids[pose_key] = class_id

	var silhouette := str(identity.get("weapon_silhouette_asset", ""))
	if not _is_valid_resource_path(silhouette) or _contains_placeholder(silhouette) \
			or not FileAccess.file_exists(silhouette):
		_add_error(violations, "presentation.v2.weapon_silhouette", "%s: %s" % [profile_key_value, silhouette])
	elif catalog_scope:
		# A generic burst asset reused across two (class_id, weapon_id) keys
		# fails closed: the weapon silhouette is the visual core per pair.
		var burst_key := "v2_silhouette::%s" % silhouette
		if seen_ids.has(burst_key) and str(seen_ids[burst_key]) != profile_key_value:
			_add_error(
				violations,
				"presentation.v2.generic_burst",
				"%s and %s share %s" % [profile_key_value, str(seen_ids[burst_key]), silhouette]
			)
		elif register:
			seen_ids[burst_key] = profile_key_value

	var palette := str(identity.get("class_palette_id", ""))
	if palette.is_empty() or _contains_placeholder(palette):
		_add_error(violations, "presentation.v2.class_palette", profile_key_value)


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
