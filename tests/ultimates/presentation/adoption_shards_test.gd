extends SceneTree

## Focused gate for the class-owned presentation adoption shards (FAN-3910).
##
## It proves four things: the live shards aggregate to exactly the adoption
## map the shared contract carried before the split, less the pairs classes
## have since adopted (FAN-3941: Thief phases/direction/capture/provenance and
## quality, Ranger quality, Soldier quality; FAN-3942: Assassin and Druid
## quality), the public ADOPTION_GAPS the
## roster gate and the per-class suites read is that aggregate, every live
## exemption is still needed and every live failure is still exempted, and the
## loader rejects what class data must never be able to do: go missing, claim
## another class, name an unknown gate, leave a reason empty, restate a shared
## ceiling, or exempt a pair the shared ratchet never admitted.

const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const EXPECTED_CLASS_COUNT := 17
const REFERENCE_CLASS := "doctor"
const FIXTURE_ROOT := "user://fan3910_adoption_shards"

## The shared map exactly as the contract carried it at the integrated Ranger
## update (cffc4e486bb6455b6e0f2bca63ff9ae3fc9a9047), before the shards, minus
## the pairs adopted since: FAN-3941 retired Thief's phases, direction, capture
## and provenance gaps and the Ranger, Soldier and Thief quality gaps; FAN-3942
## retired the Assassin and Druid quality gaps.
const LEGACY_ADOPTION_GAPS := {
	"phases": {},
	"direction": {},
	"capture": {},
	"provenance": {},
	"quality": {
		"elementalist": "awaiting the readability/accessibility declaration",
		"guitarist": "awaiting the readability/accessibility declaration",
		"knight": "awaiting the readability/accessibility declaration",
		"priest": "awaiting the readability/accessibility declaration",
		"robot": "awaiting the readability/accessibility declaration",
	},
	"victim_impact": {},
}


func _initialize() -> void:
	var errors: Array[String] = []
	_check_live_shards(errors)
	_check_ceiling(errors)
	_check_ratchet(errors)
	_check_loader_goes_red(errors)
	_finish(errors)


## Every class directory carries one valid shard, the roster is the manifest
## roster, and the aggregate is the legacy map through both public readers.
func _check_live_shards(errors: Array[String]) -> void:
	for violation in Contract.adoption_shard_violations():
		errors.append("live shards must validate: %s" % violation)
	var shard_classes := _shard_classes(Contract.ADOPTION_SHARD_ROOT)
	var roster := Contract.class_ids()
	if shard_classes.size() != EXPECTED_CLASS_COUNT:
		errors.append("expected %d adoption shards, found %d" % [EXPECTED_CLASS_COUNT, shard_classes.size()])
	if shard_classes != roster:
		errors.append("shard classes %s must equal the manifest roster %s" % [str(shard_classes), str(roster)])
	_expect_same_gaps(Contract.load_adoption_gaps(), LEGACY_ADOPTION_GAPS, "loader aggregate", errors)
	_expect_same_gaps(Contract.ADOPTION_GAPS, LEGACY_ADOPTION_GAPS, "ADOPTION_GAPS", errors)
	for gate in Contract.GATES:
		if not Contract.ADOPTION_GAPS.has(gate):
			errors.append("ADOPTION_GAPS must carry every gate, %s is absent" % gate)


## The shared ceiling names only real gates and roster classes, and every
## admitted pair is still a pair a live shard could claim.
func _check_ceiling(errors: Array[String]) -> void:
	var roster := Contract.class_ids()
	for raw_gate in Contract.ADMITTED_ADOPTION_GAPS:
		var gate := str(raw_gate)
		if not Contract.GATES.has(gate):
			errors.append("ratchet ceiling names unknown gate %s" % gate)
		for class_id in Contract.ADMITTED_ADOPTION_GAPS[raw_gate]:
			if not roster.has(str(class_id)):
				errors.append("ratchet ceiling names unknown class %s/%s" % [gate, class_id])


## No live exemption is stale and no live failure is unlisted.
func _check_ratchet(errors: Array[String]) -> void:
	for class_id in Contract.class_ids():
		var manifest := Contract.load_manifest(class_id)
		if manifest.is_empty():
			errors.append("class %s has no readable manifest" % class_id)
			continue
		for violation in Contract.adoption_violations(class_id, manifest, Contract.ADOPTION_GAPS):
			errors.append("live ratchet: %s" % violation)


## Every rejection the loader owns must be reachable, and a rejected shard must
## contribute nothing to the aggregate.
func _check_loader_goes_red(errors: Array[String]) -> void:
	var quality_gap := {"quality": "awaiting the readability/accessibility declaration"}

	var missing := _case("missing")
	_write_shard(missing, REFERENCE_CLASS, _shard(REFERENCE_CLASS, {}))
	_write_shard(missing, "thief", _shard("thief", quality_gap))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/sniper" % missing))
	var missing_result := Contract.load_adoption_shards(missing)
	_expect_error(missing_result, "adoption.shard_missing: sniper", errors)
	_expect_gap(missing_result, "quality", "thief", true, "a missing sibling shard", errors)

	var duplicate := _case("duplicate")
	_write_shard(duplicate, "ranger", _shard("ranger", quality_gap))
	_write_shard(duplicate, "thief", _shard("ranger", quality_gap))
	var duplicate_result := Contract.load_adoption_shards(duplicate)
	_expect_error(duplicate_result, "adoption.shard_class_mismatch: thief declares ranger", errors)
	_expect_error(duplicate_result, "adoption.shard_duplicate: ranger is declared by ranger and thief", errors)
	_expect_gap(duplicate_result, "quality", "ranger", true, "the owning shard", errors)
	_expect_gap(duplicate_result, "quality", "thief", false, "a shard claiming another class", errors)

	var unknown_gate := _case("unknown_gate")
	_write_shard(unknown_gate, "thief", _shard("thief", {"telegraphs": "misspelled gate"}))
	_expect_error(Contract.load_adoption_shards(unknown_gate), "adoption.gate_unknown: thief/telegraphs", errors)

	var empty_reason := _case("empty_reason")
	_write_shard(empty_reason, "thief", _shard("thief", {"phases": "   "}))
	var empty_reason_result := Contract.load_adoption_shards(empty_reason)
	_expect_error(empty_reason_result, "adoption.reason_missing: thief/phases", errors)
	_expect_gap(empty_reason_result, "phases", "thief", false, "an empty reason", errors)

	# A class restating a shared ceiling in its own data: the whole shard is
	# refused, so it cannot smuggle the widened number in beside valid gaps.
	var ceiling := _case("ceiling")
	var widened := _shard("thief", quality_gap)
	widened["max_visual_nodes_ceiling"] = Contract.MAX_VISUAL_NODES_CEILING * 2
	_write_shard(ceiling, "thief", widened)
	var ceiling_result := Contract.load_adoption_shards(ceiling)
	_expect_error(ceiling_result, "adoption.shard_field: thief declares max_visual_nodes_ceiling", errors)
	_expect_gap(ceiling_result, "quality", "thief", false, "a shard carrying a ceiling", errors)

	# A class exempting itself from a gate the shared ratchet never admitted:
	# the pair is refused, so the budget ceiling still applies to it.
	var not_admitted := _case("not_admitted")
	_write_shard(not_admitted, REFERENCE_CLASS, _shard(REFERENCE_CLASS, {"budget": "needs more nodes"}))
	var not_admitted_result := Contract.load_adoption_shards(not_admitted)
	_expect_error(not_admitted_result, "adoption.gap_not_admitted: doctor/budget", errors)
	_expect_gap(not_admitted_result, "budget", REFERENCE_CLASS, false, "an unadmitted exemption", errors)

	var version := _case("version")
	var future := _shard("thief", quality_gap)
	future["schema_version"] = Contract.ADOPTION_SHARD_SCHEMA_VERSION + 1
	_write_shard(version, "thief", future)
	_expect_error(Contract.load_adoption_shards(version), "adoption.shard_schema_version: thief declares", errors)

	var partial := _case("partial")
	_write_shard(partial, "thief", {"schema_version": 1, "class_id": "thief"})
	_expect_error(Contract.load_adoption_shards(partial), "adoption.shard_field_missing: thief/adoption_gaps", errors)

	var wrong_type := _case("wrong_type")
	_write_shard(wrong_type, "thief", {"schema_version": 1, "class_id": "thief", "adoption_gaps": ["quality"]})
	_expect_error(Contract.load_adoption_shards(wrong_type), "adoption.gaps_type: thief", errors)

	var unparsable := _case("unparsable")
	_write_text("%s/thief/%s" % [unparsable, Contract.ADOPTION_SHARD_FILE], "{not json")
	_expect_error(Contract.load_adoption_shards(unparsable), "adoption.shard_parse: thief", errors)

	_expect_error(Contract.load_adoption_shards("%s/never_created" % FIXTURE_ROOT), "adoption.root_missing:", errors)

	_check_ratchet_goes_red(errors)


## Stale and unlisted both go red on the reference package, independent of
## which roster classes are currently behind.
func _check_ratchet_goes_red(errors: Array[String]) -> void:
	var baseline := Contract.load_manifest(REFERENCE_CLASS)
	if baseline.is_empty():
		errors.append("reference class %s has no manifest" % REFERENCE_CLASS)
		return
	var stale := Contract.adoption_violations(REFERENCE_CLASS, baseline, {"quality": {REFERENCE_CLASS: "pending"}})
	_expect_listed(stale, "adoption.stale: doctor already satisfies the quality gate", errors)

	var undeclared := baseline.duplicate(true)
	((undeclared["weapons"] as Array)[0] as Dictionary).erase("quality")
	var unlisted := Contract.adoption_violations(REFERENCE_CLASS, undeclared, {})
	_expect_listed(unlisted, "adoption.unlisted: doctor fails the quality gate: quality.missing:", errors)

	var exempted := Contract.adoption_violations(REFERENCE_CLASS, undeclared, {"quality": {REFERENCE_CLASS: "pending"}})
	if not exempted.is_empty():
		errors.append("an admitted exemption must satisfy the ratchet, got: %s" % str(exempted))


func _shard_classes(root: String) -> Array[String]:
	var found: Array[String] = []
	for directory in DirAccess.get_directories_at(root):
		if FileAccess.file_exists("%s/%s/%s" % [root, directory, Contract.ADOPTION_SHARD_FILE]):
			found.append(str(directory))
	found.sort()
	return found


func _expect_same_gaps(actual: Dictionary, expected: Dictionary, label: String, errors: Array[String]) -> void:
	for gate in Contract.GATES:
		var actual_gate: Dictionary = actual.get(gate, {})
		var expected_gate: Dictionary = expected.get(gate, {})
		for class_id in expected_gate:
			if not actual_gate.has(class_id):
				errors.append("%s lost %s/%s" % [label, gate, class_id])
			elif str(actual_gate[class_id]) != str(expected_gate[class_id]):
				errors.append("%s changed the %s/%s reason to %s" % [label, gate, class_id, str(actual_gate[class_id])])
		for class_id in actual_gate:
			if not expected_gate.has(class_id):
				errors.append("%s gained %s/%s" % [label, gate, class_id])
	for gate in actual:
		if not Contract.GATES.has(str(gate)):
			errors.append("%s carries unknown gate %s" % [label, str(gate)])


func _shard(class_id: String, gaps: Dictionary) -> Dictionary:
	return {
		"schema_version": Contract.ADOPTION_SHARD_SCHEMA_VERSION,
		"class_id": class_id,
		"adoption_gaps": gaps,
	}


func _case(name: String) -> String:
	return "%s/%s" % [FIXTURE_ROOT, name]


func _write_shard(root: String, directory: String, shard: Dictionary) -> void:
	_write_text("%s/%s/%s" % [root, directory, Contract.ADOPTION_SHARD_FILE], JSON.stringify(shard, "  "))


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _expect_error(result: Dictionary, expected_prefix: String, errors: Array[String]) -> void:
	_expect_listed(result["errors"] as Array[String], expected_prefix, errors)


func _expect_listed(reported: Array[String], expected_prefix: String, errors: Array[String]) -> void:
	for entry in reported:
		if entry.begins_with(expected_prefix):
			return
	errors.append("expected %s, got: %s" % [expected_prefix, ", ".join(reported) if not reported.is_empty() else "no violation"])


func _expect_gap(
	result: Dictionary,
	gate: String,
	class_id: String,
	present: bool,
	control: String,
	errors: Array[String]
) -> void:
	var listed := ((result["gaps"] as Dictionary).get(gate, {}) as Dictionary).has(class_id)
	if listed != present:
		errors.append(
			"%s must %s %s/%s in the aggregate, got %s"
			% [control, "keep" if present else "drop", gate, class_id, str(result["gaps"])]
		)


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Presentation adoption shards passed (%d class shards equal the legacy map, live ratchet clean, every loader rejection red)." % EXPECTED_CLASS_COUNT)
		quit(0)
		return
	for error in errors:
		push_error("Presentation adoption shards: %s" % error)
	quit(1)
