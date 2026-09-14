extends SceneTree

## Focused gate for the class-owned presentation-v2 migration shards (FAN-3933).
##
## It proves five things: the live shards aggregate to the exact ratcheted map
## while the immutable 23-pair ceiling from the split remains intact, the public
## PRESENTATION_V2_MIGRATION_ALLOWLIST every consumer reads is that aggregate,
## every aggregate gate outcome (catalog, single manifest, visual-direction
## contract) is identical whether it reads the shards or the legacy map, the
## loader is a leaf of the import graph, and the loader rejects what class data
## must never be able to do: go missing, claim another class or an unknown one,
## name a pair of another class or one the frozen ceiling never admitted, write
## the same pair or the same member twice in its raw text, leave a reason
## empty, restate a shared envelope value, or keep a stale entry.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const Shards := preload("res://scripts/ultimates/presentation/presentation_v2_migration_shards.gd")

const SHARDS_SCRIPT_PATH := "res://scripts/ultimates/presentation/presentation_v2_migration_shards.gd"
const SCHEMA_SCRIPT_PATH := "res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd"
const EXPECTED_CLASS_COUNT := 17
const EXPECTED_PAIR_COUNT := 15
const FROZEN_CEILING_PAIR_COUNT := 23
const EXPECTED_CATALOG_SIZE := 51
const REFERENCE_CLASS := "doctor"
const MIGRATED_KEY := "berserk/sword"
const FIXTURE_ROOT := "user://fan3933_migration_shards"

const LEGACY_REASON := "shipped under the v1 envelope before FAN-2948; awaiting its class rework card"

## The shared map exactly as WeaponUltimatePresentationSchema carried it at the
## starting candidate (d192be10bbe52dd89971cab0acc66eb92ccab37f), before the
## shards.
const FROZEN_CEILING_ALLOWLIST := {
	"assassin/shadow_daggers": LEGACY_REASON,
	"assassin/venom_wire": LEGACY_REASON,
	"doctor/restore_potion": LEGACY_REASON,
	"doctor/plague_syringe": LEGACY_REASON,
	"doctor/bone_saw": LEGACY_REASON,
	"druid/summon_amulet": LEGACY_REASON,
	"druid/briar_staff": LEGACY_REASON,
	"druid/raven_totem": LEGACY_REASON,
	"elementalist/elementalist_orb_ring": LEGACY_REASON,
	"elementalist/elementalist_prism_focus": LEGACY_REASON,
	"elementalist/elementalist_meteor_core": LEGACY_REASON,
	"guitarist/electric_guitar": LEGACY_REASON,
	"guitarist/bass_guitar": LEGACY_REASON,
	"guitarist/sound_amp": LEGACY_REASON,
	"knight/long_spear": LEGACY_REASON,
	"knight/tower_shield": LEGACY_REASON,
	"knight/holy_flail": LEGACY_REASON,
	"priest/priest_reliquary": LEGACY_REASON,
	"priest/priest_censer": LEGACY_REASON,
	"priest/priest_chime": LEGACY_REASON,
	"robot/robot_magnetic_anchor": LEGACY_REASON,
	"robot/robot_hydraulic_press": LEGACY_REASON,
	"robot/robot_reactor_core": LEGACY_REASON,
}

## FAN-3942 removes only its eight now-certified pairs. This is deliberately an
## exact expectation rather than a copy of the live aggregate, so an accidental
## shard deletion still fails closed.
const EXPECTED_LIVE_ALLOWLIST := {
	"elementalist/elementalist_orb_ring": LEGACY_REASON,
	"elementalist/elementalist_prism_focus": LEGACY_REASON,
	"elementalist/elementalist_meteor_core": LEGACY_REASON,
	"guitarist/electric_guitar": LEGACY_REASON,
	"guitarist/bass_guitar": LEGACY_REASON,
	"guitarist/sound_amp": LEGACY_REASON,
	"knight/long_spear": LEGACY_REASON,
	"knight/tower_shield": LEGACY_REASON,
	"knight/holy_flail": LEGACY_REASON,
	"priest/priest_reliquary": LEGACY_REASON,
	"priest/priest_censer": LEGACY_REASON,
	"priest/priest_chime": LEGACY_REASON,
	"robot/robot_magnetic_anchor": LEGACY_REASON,
	"robot/robot_hydraulic_press": LEGACY_REASON,
	"robot/robot_reactor_core": LEGACY_REASON,
}

var _catalog: Dictionary = {}
var _profiles: Dictionary = {}


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_catalog = Manifest.catalog_for_registry(registry)
	_profiles = Manifest.expected_profiles_for_registry(registry)
	if _catalog.size() != EXPECTED_CATALOG_SIZE:
		errors.append("expected the %d-pair catalog, got %d" % [EXPECTED_CATALOG_SIZE, _catalog.size()])
	_check_live_shards(errors)
	_check_ceiling(errors)
	_check_ratchet(errors)
	_check_gate_outcomes_match(errors)
	_check_dependency_graph(errors)
	_check_loader_goes_red(errors)
	_finish(errors)


## Every canonical class carries one valid shard, the shard roster is the
## manifest roster, and the aggregate is the exact ratcheted map through both
## public readers.
func _check_live_shards(errors: Array[String]) -> void:
	for violation in Shards.shard_violations():
		errors.append("live shards must validate: %s" % violation)
	var shard_classes := _shard_classes(Shards.SHARD_ROOT)
	var roster := Contract.class_ids()
	if shard_classes.size() != EXPECTED_CLASS_COUNT:
		errors.append("expected %d migration shards, found %d" % [EXPECTED_CLASS_COUNT, shard_classes.size()])
	if shard_classes != roster:
		errors.append("shard classes %s must equal the manifest roster %s" % [str(shard_classes), str(roster)])
	var canonical: Array[String] = Shards.CLASS_IDS.duplicate()
	canonical.sort()
	if canonical != roster:
		errors.append("loader roster %s must equal the manifest roster %s" % [str(canonical), str(roster)])
	_expect_same_allowlist(Shards.load_allowlist(), EXPECTED_LIVE_ALLOWLIST, "loader aggregate", errors)
	_expect_same_allowlist(Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST, EXPECTED_LIVE_ALLOWLIST, "PRESENTATION_V2_MIGRATION_ALLOWLIST", errors)
	if Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.size() != EXPECTED_PAIR_COUNT:
		errors.append("expected %d live exemptions, got %d" % [EXPECTED_PAIR_COUNT, Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.size()])
	if not Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.is_read_only():
		errors.append("the live allowlist must be read-only, exactly like the const it replaces")
	for class_id in roster:
		var shard := _read_shard(Shards.SHARD_ROOT, class_id)
		var declared: Dictionary = shard.get("migration_exemptions", {})
		var legacy_count := 0
		for key in EXPECTED_LIVE_ALLOWLIST:
			if str(key).begins_with("%s/" % class_id):
				legacy_count += 1
		if declared.size() != legacy_count:
			errors.append("%s shard declares %d pair(s), the ratcheted map expects %d" % [class_id, declared.size(), legacy_count])


## The frozen ceiling is exactly the legacy key set, names only live registry
## pairs of roster classes, and carries no duplicate.
func _check_ceiling(errors: Array[String]) -> void:
	var seen := {}
	for raw_key in Shards.ADMITTED_EXEMPTIONS:
		var key := str(raw_key)
		if seen.has(key):
			errors.append("frozen ceiling lists %s twice" % key)
		seen[key] = true
		if not FROZEN_CEILING_ALLOWLIST.has(key):
			errors.append("frozen ceiling admits %s, which the legacy map never carried" % key)
		if not _profiles.has(key):
			errors.append("frozen ceiling names unknown registry pair %s" % key)
		if not Shards.CLASS_IDS.has(key.get_slice("/", 0)):
			errors.append("frozen ceiling names unknown class in %s" % key)
	for key in FROZEN_CEILING_ALLOWLIST:
		if not seen.has(str(key)):
			errors.append("frozen ceiling lost legacy pair %s" % str(key))
	if seen.size() != FROZEN_CEILING_PAIR_COUNT:
		errors.append("frozen ceiling must retain %d pairs, found %d" % [FROZEN_CEILING_PAIR_COUNT, seen.size()])


## Every live exemption names a registry pair with a reason, none is stale, and
## each one is still needed: asserted against v2 without it, the pair fails.
func _check_ratchet(errors: Array[String]) -> void:
	for violation in Schema.allowlist_integrity_errors(_profiles):
		errors.append("live allowlist integrity: %s" % violation)
	for violation in Schema.validate_catalog(_manifest_array(), _profiles):
		errors.append("live catalog with the shard allowlist: %s" % violation)
	for raw_key in Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST:
		var key := str(raw_key)
		if not _catalog.has(key):
			continue
		var enforced := Schema.validate_catalog([_catalog[key]], {key: _profiles[key]}, {})
		if not _has_code_prefix(enforced, "presentation.v2."):
			errors.append("%s is exempted but already satisfies v2 outside the allowlist: %s" % [key, str(enforced)])


## Old and new aggregate gate outcomes are identical: the catalog gate, the
## runtime single-manifest gate and the visual-direction contract report the
## same violations whether they read the shards (default argument) or the
## exact live map (explicit override), and an explicit empty override still asserts
## the full v2 contract.
func _check_gate_outcomes_match(errors: Array[String]) -> void:
	var manifests := _manifest_array()
	var default_catalog := Schema.validate_catalog(manifests, _profiles)
	var legacy_catalog := Schema.validate_catalog(manifests, _profiles, EXPECTED_LIVE_ALLOWLIST)
	if default_catalog != legacy_catalog:
		errors.append("catalog outcome differs: shards %s vs legacy %s" % [str(default_catalog), str(legacy_catalog)])
	var enforced := Schema.validate_catalog(manifests, _profiles, {})
	if enforced.is_empty():
		errors.append("an explicit empty allowlist must still assert the full v2 contract on the v1 pairs")
	for raw_key in EXPECTED_LIVE_ALLOWLIST:
		if not _has_code_detail(enforced, "presentation.v2.", str(raw_key)):
			errors.append("explicit empty allowlist must report %s" % str(raw_key))
	var keys: Array = _catalog.keys()
	keys.sort()
	for raw_key in keys:
		var key := str(raw_key)
		var by_default := Schema.validate_manifest(_catalog[key], _profiles[key])
		var by_legacy := Schema.validate_manifest(_catalog[key], _profiles[key], EXPECTED_LIVE_ALLOWLIST)
		if by_default != by_legacy:
			errors.append("single-manifest outcome differs for %s: %s vs %s" % [key, str(by_default), str(by_legacy)])
	for class_id in Contract.class_ids():
		var manifest := Contract.load_manifest(class_id)
		if manifest.is_empty():
			errors.append("class %s has no readable manifest" % class_id)
			continue
		var by_default := Contract.violations(class_id, manifest)
		var by_legacy := Contract.violations(class_id, manifest, EXPECTED_LIVE_ALLOWLIST)
		if by_default != by_legacy:
			errors.append("contract outcome differs for %s: %s vs %s" % [class_id, str(by_default), str(by_legacy)])
		var enforced_default := Contract.violations(class_id, manifest, {})
		var enforced_legacy := Contract.violations(class_id, manifest, {})
		if enforced_default != enforced_legacy:
			errors.append("contract empty-override outcome is not deterministic for %s" % class_id)


## The loader is a leaf: it preloads nothing and names neither the schema nor
## the contract, while the schema is the one importing it. That is what keeps
## Schema -> Shards free of a cycle back into Schema or VisualDirection.
func _check_dependency_graph(errors: Array[String]) -> void:
	var source := _code_lines(FileAccess.get_file_as_string(SHARDS_SCRIPT_PATH))
	if source.is_empty():
		errors.append("loader source must be readable at %s" % SHARDS_SCRIPT_PATH)
		return
	for forbidden in ["preload(", "load(", "WeaponUltimatePresentationSchema", "UltimateVisualDirectionContract", "Schema.", "Contract.", "class_name Weapon"]:
		if source.contains(forbidden):
			errors.append("loader must stay dependency-free, found %s" % forbidden)
	var schema_source := FileAccess.get_file_as_string(SCHEMA_SCRIPT_PATH)
	if not schema_source.contains("preload(\"%s\")" % SHARDS_SCRIPT_PATH):
		errors.append("the schema must be the importer of the loader")
	if schema_source.contains("ultimate_visual_direction_contract.gd"):
		errors.append("the schema must not import the visual-direction contract")


## Every rejection the loader owns must be reachable, and a rejected shard or
## entry must contribute nothing to the aggregate.
func _check_loader_goes_red(errors: Array[String]) -> void:
	var doctor_pairs := _legacy_pairs_of(REFERENCE_CLASS)

	var missing := _case("missing")
	_write_shard(missing, REFERENCE_CLASS, _shard(REFERENCE_CLASS, doctor_pairs))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/sniper" % missing))
	var missing_result := Shards.load_shards(missing)
	_expect_error(missing_result, "v2_migration.shard_missing: sniper", errors)
	_expect_error(missing_result, "v2_migration.shard_missing: thief", errors)
	_expect_pair(missing_result, "doctor/bone_saw", true, "a missing sibling shard", errors)

	# Removing entries is the one edit a class may make: fewer pairs, no error.
	var shrunk := _case("shrunk")
	var partial_pairs := {"doctor/restore_potion": LEGACY_REASON}
	_write_shard(shrunk, REFERENCE_CLASS, _shard(REFERENCE_CLASS, partial_pairs))
	var shrunk_result := Shards.load_shards(shrunk)
	_expect_no_error_for(shrunk_result, REFERENCE_CLASS, errors)
	_expect_pair(shrunk_result, "doctor/restore_potion", true, "a shrunk shard", errors)
	_expect_pair(shrunk_result, "doctor/bone_saw", false, "a shrunk shard", errors)

	var duplicate := _case("duplicate")
	_write_shard(duplicate, REFERENCE_CLASS, _shard(REFERENCE_CLASS, doctor_pairs))
	_write_shard(duplicate, "ranger", _shard(REFERENCE_CLASS, doctor_pairs))
	var duplicate_result := Shards.load_shards(duplicate)
	_expect_error(duplicate_result, "v2_migration.shard_class_mismatch: ranger declares doctor", errors)
	_expect_error(duplicate_result, "v2_migration.shard_duplicate: doctor is declared by doctor and ranger", errors)
	_expect_pair(duplicate_result, "doctor/bone_saw", true, "the owning shard", errors)

	# FAN-3933-QA-1: a pair written twice in the raw shard text. JSON.parse
	# keeps only the last member, so the loader reads the raw members before
	# the collapse: the pair is reported and omitted, its siblings survive, and
	# the surviving reason is not silently the second one.
	var duplicate_pair := _case("duplicate_pair")
	_write_text(
		"%s/%s/%s" % [duplicate_pair, REFERENCE_CLASS, Shards.SHARD_FILE],
		"""{
  "schema_version": 1,
  "class_id": "doctor",
  "migration_exemptions": {
    "doctor/restore_potion": "%s",
    "doctor/bone_saw": "first reason",
    "doctor/plague_syringe": "%s",
    "doctor/bone_saw": "second reason"
  }
}""" % [LEGACY_REASON, LEGACY_REASON]
	)
	var duplicate_pair_result := Shards.load_shards(duplicate_pair)
	_expect_error(duplicate_pair_result, "v2_migration.pair_duplicate: doctor/bone_saw", errors)
	_expect_pair(duplicate_pair_result, "doctor/bone_saw", false, "a pair written twice", errors)
	_expect_pair(duplicate_pair_result, "doctor/restore_potion", true, "a sibling of a pair written twice", errors)
	_expect_pair(duplicate_pair_result, "doctor/plague_syringe", true, "a sibling of a pair written twice", errors)

	# The same pair spelled with a JSON escape is still the same key.
	var escaped_pair := _case("escaped_pair")
	_write_text(
		"%s/%s/%s" % [escaped_pair, REFERENCE_CLASS, Shards.SHARD_FILE],
		'{"schema_version": 1, "class_id": "doctor", "migration_exemptions": {"doctor/bone_saw": "a", "doctor\\/bone_saw": "b"}}'
	)
	var escaped_pair_result := Shards.load_shards(escaped_pair)
	_expect_error(escaped_pair_result, "v2_migration.pair_duplicate: doctor/bone_saw", errors)
	_expect_pair(escaped_pair_result, "doctor/bone_saw", false, "an escaped duplicate pair", errors)

	# A pair key quoted inside a reason, or a member of a nested value, is not
	# a member: the raw scan must not over-report.
	var quoted_reason := _case("quoted_reason")
	_write_text(
		"%s/%s/%s" % [quoted_reason, REFERENCE_CLASS, Shards.SHARD_FILE],
		'{"schema_version": 1, "class_id": "doctor", "migration_exemptions": {"doctor/bone_saw": "see \\"doctor/bone_saw\\": {\\"doctor/bone_saw\\": 1} }"}}'
	)
	var quoted_reason_result := Shards.load_shards(quoted_reason)
	_expect_no_error_for(quoted_reason_result, REFERENCE_CLASS, errors)
	_expect_pair(quoted_reason_result, "doctor/bone_saw", true, "a reason quoting the pair key", errors)

	# A top-level member written twice is rejected with the whole shard, so a
	# second class_id or a second exemptions block cannot override the first.
	var duplicate_member := _case("duplicate_member")
	_write_text(
		"%s/%s/%s" % [duplicate_member, REFERENCE_CLASS, Shards.SHARD_FILE],
		'{"schema_version": 1, "class_id": "doctor", "migration_exemptions": {}, "migration_exemptions": {"doctor/bone_saw": "late"}}'
	)
	var duplicate_member_result := Shards.load_shards(duplicate_member)
	_expect_error(duplicate_member_result, "v2_migration.shard_field_duplicate: doctor declares migration_exemptions twice", errors)
	_expect_pair(duplicate_member_result, "doctor/bone_saw", false, "a member written twice", errors)

	var unknown_class := _case("unknown_class")
	_write_shard(unknown_class, "necromancer", _shard("necromancer", {"necromancer/skull": "not a class"}))
	var unknown_class_result := Shards.load_shards(unknown_class)
	_expect_error(unknown_class_result, "v2_migration.class_unknown: necromancer", errors)
	_expect_pair(unknown_class_result, "necromancer/skull", false, "an unknown class", errors)

	var cross_class := _case("cross_class")
	var cross_pairs := doctor_pairs.duplicate()
	cross_pairs["knight/long_spear"] = LEGACY_REASON
	_write_shard(cross_class, REFERENCE_CLASS, _shard(REFERENCE_CLASS, cross_pairs))
	var cross_result := Shards.load_shards(cross_class)
	_expect_error(cross_result, "v2_migration.pair_cross_class: doctor declares knight/long_spear", errors)
	_expect_pair(cross_result, "knight/long_spear", false, "a cross-class entry", errors)
	_expect_pair(cross_result, "doctor/bone_saw", true, "a cross-class sibling entry", errors)

	var malformed := _case("malformed")
	_write_shard(malformed, REFERENCE_CLASS, _shard(REFERENCE_CLASS, {"bone_saw": LEGACY_REASON}))
	var malformed_result := Shards.load_shards(malformed)
	_expect_error(malformed_result, "v2_migration.pair_malformed: doctor/bone_saw", errors)
	_expect_pair(malformed_result, "bone_saw", false, "a malformed pair key", errors)

	var empty_reason := _case("empty_reason")
	_write_shard(empty_reason, REFERENCE_CLASS, _shard(REFERENCE_CLASS, {"doctor/bone_saw": "   "}))
	var empty_reason_result := Shards.load_shards(empty_reason)
	_expect_error(empty_reason_result, "v2_migration.reason_missing: doctor/bone_saw", errors)
	_expect_pair(empty_reason_result, "doctor/bone_saw", false, "an empty reason", errors)

	# A class exempting a pair the frozen ceiling never admitted, whether the
	# pair exists in the registry or not: the entry is refused, so the pair
	# stays asserted against the full v2 contract.
	var not_admitted := _case("not_admitted")
	_write_shard(not_admitted, "berserk", _shard("berserk", {MIGRATED_KEY: "back to v1"}))
	_write_shard(not_admitted, REFERENCE_CLASS, _shard(REFERENCE_CLASS, {"doctor/new_weapon": "never shipped"}))
	var not_admitted_result := Shards.load_shards(not_admitted)
	_expect_error(not_admitted_result, "v2_migration.pair_not_admitted: %s" % MIGRATED_KEY, errors)
	_expect_error(not_admitted_result, "v2_migration.pair_not_admitted: doctor/new_weapon", errors)
	_expect_pair(not_admitted_result, MIGRATED_KEY, false, "a re-added migrated pair", errors)
	_expect_pair(not_admitted_result, "doctor/new_weapon", false, "an unknown pair", errors)

	# A class restating a shared envelope value in its own data: the whole
	# shard is refused, so it cannot smuggle the weakened range in beside valid
	# entries.
	var envelope := _case("envelope")
	var widened := _shard(REFERENCE_CLASS, doctor_pairs)
	widened["v2_total_range_seconds"] = [0.0, 99.0]
	_write_shard(envelope, REFERENCE_CLASS, widened)
	var envelope_result := Shards.load_shards(envelope)
	_expect_error(envelope_result, "v2_migration.shard_field: doctor declares v2_total_range_seconds", errors)
	_expect_pair(envelope_result, "doctor/bone_saw", false, "a shard carrying an envelope value", errors)

	var version := _case("version")
	var future := _shard(REFERENCE_CLASS, doctor_pairs)
	future["schema_version"] = Shards.SHARD_SCHEMA_VERSION + 1
	_write_shard(version, REFERENCE_CLASS, future)
	var version_result := Shards.load_shards(version)
	_expect_error(version_result, "v2_migration.shard_schema_version: doctor declares", errors)
	_expect_pair(version_result, "doctor/bone_saw", false, "a future schema version", errors)

	var partial := _case("partial")
	_write_shard(partial, REFERENCE_CLASS, {"schema_version": 1, "class_id": REFERENCE_CLASS})
	_expect_error(Shards.load_shards(partial), "v2_migration.shard_field_missing: doctor/migration_exemptions", errors)

	var wrong_type := _case("wrong_type")
	_write_shard(wrong_type, REFERENCE_CLASS, {"schema_version": 1, "class_id": REFERENCE_CLASS, "migration_exemptions": ["doctor/bone_saw"]})
	var wrong_type_result := Shards.load_shards(wrong_type)
	_expect_error(wrong_type_result, "v2_migration.exemptions_type: doctor", errors)
	_expect_pair(wrong_type_result, "doctor/bone_saw", false, "a non-Dictionary exemptions block", errors)

	var unparsable := _case("unparsable")
	_write_text("%s/%s/%s" % [unparsable, REFERENCE_CLASS, Shards.SHARD_FILE], "{not json")
	_expect_error(Shards.load_shards(unparsable), "v2_migration.shard_parse: doctor", errors)

	_expect_error(Shards.load_shards("%s/never_created" % FIXTURE_ROOT), "v2_migration.root_missing:", errors)

	# Broken class data reaches the schema as a smaller allowlist, never a
	# larger one. Every still-live exemption dropped by this incomplete fixture
	# is asserted against v2 and fails closed. The Doctor fixture itself is now
	# intentionally v2 and remains useful only for the loader's frozen ceiling.
	var fail_closed: Dictionary = envelope_result["allowlist"]
	for raw_key in EXPECTED_LIVE_ALLOWLIST:
		var key := str(raw_key)
		var outcome := Schema.validate_catalog([_catalog[key]], {key: _profiles[key]}, fail_closed)
		if not _has_code_prefix(outcome, "presentation.v2."):
			errors.append("a pair dropped by a rejected shard must fail the v2 contract, %s passed" % key)

	_check_stale_goes_red(errors)


## An exemption for a pair that already satisfies v2 is stale in catalog scope,
## and the runtime single-manifest path never rejects a live activation over it.
func _check_stale_goes_red(errors: Array[String]) -> void:
	if not _catalog.has(MIGRATED_KEY) or EXPECTED_LIVE_ALLOWLIST.has(MIGRATED_KEY):
		errors.append("%s must be a migrated registry pair for the stale control" % MIGRATED_KEY)
		return
	var stale_allowlist := {MIGRATED_KEY: "listed although migrated"}
	var stale := Schema.validate_catalog([_catalog[MIGRATED_KEY]], {MIGRATED_KEY: _profiles[MIGRATED_KEY]}, stale_allowlist)
	_expect_listed(stale, "presentation.v2_allowlist.stale: %s" % MIGRATED_KEY, errors)
	var runtime := Schema.validate_manifest(_catalog[MIGRATED_KEY], _profiles[MIGRATED_KEY], stale_allowlist)
	if not runtime.is_empty():
		errors.append("the single-manifest path must not reject a live activation over a stale entry: %s" % str(runtime))


## The script without its comment lines, so documentation may name the
## schema and the contract while the code must not.
func _code_lines(source: String) -> String:
	var kept: Array[String] = []
	for line in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


func _legacy_pairs_of(class_id: String) -> Dictionary:
	var pairs := {}
	for key in FROZEN_CEILING_ALLOWLIST:
		if str(key).begins_with("%s/" % class_id):
			pairs[str(key)] = str(FROZEN_CEILING_ALLOWLIST[key])
	return pairs


func _shard_classes(root: String) -> Array[String]:
	var found: Array[String] = []
	for directory in DirAccess.get_directories_at(root):
		if FileAccess.file_exists("%s/%s/%s" % [root, directory, Shards.SHARD_FILE]):
			found.append(str(directory))
	found.sort()
	return found


func _read_shard(root: String, class_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/%s" % [root, class_id, Shards.SHARD_FILE]))
	return parsed as Dictionary if parsed is Dictionary else {}


func _manifest_array() -> Array:
	var manifests: Array = []
	var keys: Array = _catalog.keys()
	keys.sort()
	for key in keys:
		manifests.append((_catalog[key] as Dictionary).duplicate(true))
	return manifests


func _expect_same_allowlist(actual: Dictionary, expected: Dictionary, label: String, errors: Array[String]) -> void:
	for key in expected:
		if not actual.has(key):
			errors.append("%s lost %s" % [label, str(key)])
		elif str(actual[key]) != str(expected[key]):
			errors.append("%s changed the %s reason to %s" % [label, str(key), str(actual[key])])
	for key in actual:
		if not expected.has(key):
			errors.append("%s gained %s" % [label, str(key)])


func _shard(class_id: String, exemptions: Dictionary) -> Dictionary:
	return {
		"schema_version": Shards.SHARD_SCHEMA_VERSION,
		"class_id": class_id,
		"migration_exemptions": exemptions,
	}


func _case(name: String) -> String:
	return "%s/%s" % [FIXTURE_ROOT, name]


func _write_shard(root: String, directory: String, shard: Dictionary) -> void:
	_write_text("%s/%s/%s" % [root, directory, Shards.SHARD_FILE], JSON.stringify(shard, "  "))


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _expect_error(result: Dictionary, expected_prefix: String, errors: Array[String]) -> void:
	_expect_listed(result["errors"] as Array[String], expected_prefix, errors)


func _expect_no_error_for(result: Dictionary, class_id: String, errors: Array[String]) -> void:
	for entry in result["errors"] as Array[String]:
		if entry.contains(class_id):
			errors.append("a shard that only removed entries must validate, got: %s" % entry)


func _expect_listed(reported: Array[String], expected_prefix: String, errors: Array[String]) -> void:
	for entry in reported:
		if entry.begins_with(expected_prefix):
			return
	errors.append("expected %s, got: %s" % [expected_prefix, ", ".join(reported) if not reported.is_empty() else "no violation"])


func _expect_pair(result: Dictionary, key: String, present: bool, control: String, errors: Array[String]) -> void:
	var listed := (result["allowlist"] as Dictionary).has(key)
	if listed != present:
		errors.append(
			"%s must %s %s in the aggregate, got %s"
			% [control, "keep" if present else "drop", key, str(result["allowlist"])]
		)


func _has_code_prefix(reported: Array[String], prefix: String) -> bool:
	for entry in reported:
		if entry.begins_with(prefix):
			return true
	return false


func _has_code_detail(reported: Array[String], prefix: String, detail: String) -> bool:
	for entry in reported:
		if entry.begins_with(prefix) and entry.contains(detail):
			return true
	return false


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Presentation v2 migration shards passed (%d class shards equal the ratcheted %d-pair map, frozen %d-pair ceiling intact, gate outcomes identical, loader dependency-free, every rejection red)." % [EXPECTED_CLASS_COUNT, EXPECTED_PAIR_COUNT, FROZEN_CEILING_PAIR_COUNT])
		quit(0)
		return
	for error in errors:
		push_error("Presentation v2 migration shards: %s" % error)
	quit(1)
