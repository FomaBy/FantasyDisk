class_name PresentationV2MigrationShards
extends RefCounted

## Loader for the class-owned presentation-v2 migration shards (FAN-3933).
##
## The v2 migration ratchet used to be one shared map inside
## WeaponUltimatePresentationSchema. Each class now owns
## `data/ultimates/classes/<class_id>/presentation_v2_migration.json`, so a
## class rework card removes its own pairs without editing the shared schema
## and without a concurrent edit against another class.
##
## This script has no dependency on the schema, the visual-direction contract
## or any other script: the schema preloads it, so the loader itself must stay
## a leaf of the import graph. It reads files and reports; it validates no
## manifest.

const SHARD_ROOT := "res://data/ultimates/classes"
const SHARD_FILE := "presentation_v2_migration.json"
const SHARD_SCHEMA_VERSION := 1

## The exact shard shape. Any other key is rejected, so a shard cannot carry a
## timing range, a presence rule, a budget or anything else the shared schema
## and contract own.
const SHARD_FIELDS: Array[String] = ["schema_version", "class_id", "migration_exemptions"]

## The canonical roster: every class directory carries exactly one shard, an
## empty one being the explicit statement that the class has nothing left on
## the v1 envelope. A shard for a class outside this list is refused.
const CLASS_IDS: Array[String] = [
	"assassin",
	"berserk",
	"biologist",
	"chemist",
	"dark_mage",
	"doctor",
	"druid",
	"elementalist",
	"engineer",
	"guitarist",
	"knight",
	"priest",
	"ranger",
	"robot",
	"sniper",
	"soldier",
	"thief",
]

## The frozen ratchet ceiling: the exact pairs the shared schema exempted when
## the map was split out. Like ContactSheetBeatsContract.MIGRATION_ALLOWLIST
## and ADMITTED_ADOPTION_GAPS it only shrinks and its target state is empty. A
## shard may drop one of its pairs once the pair reaches v2; it can never add
## one, so class data cannot put a pair back under the v1 envelope. Trimming a
## pair here after its class migrated is housekeeping, never a requirement.
const ADMITTED_EXEMPTIONS: Array[String] = [
	"assassin/shadow_daggers",
	"assassin/venom_wire",
	"doctor/restore_potion",
	"doctor/plague_syringe",
	"doctor/bone_saw",
	"druid/summon_amulet",
	"druid/briar_staff",
	"druid/raven_totem",
	"elementalist/elementalist_orb_ring",
	"elementalist/elementalist_prism_focus",
	"elementalist/elementalist_meteor_core",
	"guitarist/electric_guitar",
	"guitarist/bass_guitar",
	"guitarist/sound_amp",
	"knight/long_spear",
	"knight/tower_shield",
	"knight/holy_flail",
	"priest/priest_reliquary",
	"priest/priest_censer",
	"priest/priest_chime",
	"robot/robot_magnetic_anchor",
	"robot/robot_hydraulic_press",
	"robot/robot_reactor_core",
]


## The aggregated allowlist, pair key → reason, read-only; see load_shards().
static func load_allowlist(root: String = SHARD_ROOT) -> Dictionary:
	var allowlist: Dictionary = load_shards(root)["allowlist"]
	allowlist.make_read_only()
	return allowlist


## Shard validation as "v2_migration.<code>: <detail>" entries; empty when
## every canonical class carries exactly one well-formed shard.
static func shard_violations(root: String = SHARD_ROOT) -> Array[String]:
	return load_shards(root)["errors"]


## Reads the shard of every canonical class under root once and returns
## {"allowlist": pair key → reason, "errors": Array[String]}. Anything that
## fails validation contributes nothing, so broken class data can never keep a
## pair on the v1 envelope: the pair is then asserted against the full v2
## contract by the schema and fails closed there.
static func load_shards(root: String = SHARD_ROOT) -> Dictionary:
	var allowlist := {}
	var errors: Array[String] = []
	var access := DirAccess.open(root)
	if access == null:
		errors.append("v2_migration.root_missing: %s" % root)
		return {"allowlist": allowlist, "errors": errors}
	var directories: Array[String] = []
	for directory in access.get_directories():
		directories.append(str(directory))
	for class_id in CLASS_IDS:
		if not directories.has(class_id):
			errors.append("v2_migration.shard_missing: %s" % class_id)
	directories.sort()
	var seen := {}
	for expected_class in directories:
		var path := "%s/%s/%s" % [root, expected_class, SHARD_FILE]
		if not FileAccess.file_exists(path):
			if CLASS_IDS.has(expected_class):
				errors.append("v2_migration.shard_missing: %s" % expected_class)
			continue
		if not CLASS_IDS.has(expected_class):
			errors.append("v2_migration.class_unknown: %s" % expected_class)
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
			errors.append("v2_migration.shard_parse: %s" % expected_class)
			continue
		var shard := json.data as Dictionary
		var class_id := str(shard.get("class_id", ""))
		var owned := true
		if class_id != expected_class:
			errors.append("v2_migration.shard_class_mismatch: %s declares %s" % [expected_class, class_id])
			owned = false
		if seen.has(class_id):
			errors.append(
				"v2_migration.shard_duplicate: %s is declared by %s and %s"
				% [class_id, seen[class_id], expected_class]
			)
			owned = false
		seen[class_id] = expected_class
		if not owned or not _check_shard_shape(shard, expected_class, errors):
			continue
		_merge_exemptions(shard["migration_exemptions"] as Dictionary, expected_class, allowlist, errors)
	return {"allowlist": allowlist, "errors": errors}


## Exactly the declared fields, the current schema version and a Dictionary of
## exemptions. A foreign key fails the whole shard: the shared envelope is not
## something a class may restate, let alone widen.
static func _check_shard_shape(shard: Dictionary, class_id: String, errors: Array[String]) -> bool:
	var valid := true
	for key in shard:
		if not SHARD_FIELDS.has(str(key)):
			errors.append("v2_migration.shard_field: %s declares %s" % [class_id, str(key)])
			valid = false
	for field in SHARD_FIELDS:
		if not shard.has(field):
			errors.append("v2_migration.shard_field_missing: %s/%s" % [class_id, field])
			valid = false
	if shard.has("schema_version"):
		var version: Variant = shard["schema_version"]
		if not _is_whole_number(version) or int(version) != SHARD_SCHEMA_VERSION:
			errors.append("v2_migration.shard_schema_version: %s declares %s" % [class_id, str(version)])
			valid = false
	if shard.has("migration_exemptions") and not shard["migration_exemptions"] is Dictionary:
		errors.append("v2_migration.exemptions_type: %s must declare a Dictionary" % class_id)
		valid = false
	return valid


## One shard's pair → reason entries into the aggregate. Each key must be a
## "<class_id>/<weapon_id>" pair of this very class, carry a non-empty reason,
## be admitted by the frozen ceiling and not already be aggregated; anything
## else is reported and left out.
static func _merge_exemptions(
	declared: Dictionary,
	class_id: String,
	allowlist: Dictionary,
	errors: Array[String]
) -> void:
	var keys: Array = declared.keys()
	keys.sort()
	for raw_key in keys:
		var key := str(raw_key)
		var reason: Variant = declared[raw_key]
		var parts := key.split("/")
		if parts.size() != 2 or str(parts[0]).is_empty() or str(parts[1]).is_empty():
			errors.append("v2_migration.pair_malformed: %s/%s" % [class_id, key])
			continue
		if str(parts[0]) != class_id:
			errors.append("v2_migration.pair_cross_class: %s declares %s" % [class_id, key])
			continue
		if not reason is String or str(reason).strip_edges().is_empty():
			errors.append("v2_migration.reason_missing: %s" % key)
			continue
		if not ADMITTED_EXEMPTIONS.has(key):
			errors.append("v2_migration.pair_not_admitted: %s is outside the frozen exemption ceiling" % key)
			continue
		if allowlist.has(key):
			errors.append("v2_migration.pair_duplicate: %s" % key)
			continue
		allowlist[key] = str(reason)


static func _is_whole_number(value: Variant) -> bool:
	if value is bool:
		return false
	if value is int:
		return true
	return value is float and is_finite(value) and floor(value) == value
