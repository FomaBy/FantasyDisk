extends SceneTree

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const MANIFEST_ROOT := "res://docs/design/references/weapon_ultimates"
const TIMELINE_ROOT := "res://scenes/vfx/ultimates"
const MIN_RHYTHM_DELTA_SECONDS := 0.1
const COMPARISON_EPSILON := 0.000001
const REQUIRED_TIMING_FIELDS := ["windup", "release", "active", "recovery", "cancel"]
const PACK_SUFFIX := "_ultimate_presentation_pack.gd"
const PACK_TIMING_KEY := "timing"

# Manifest timing is only trusted when a second authoritative in-repo source
# agrees with it. These classes ship scene-only packages that declare no
# absolute phase seconds anywhere else, so their manifest timing stands alone.
# The map is a ratchet like ContactSheetBeatsContract.MIGRATION_ALLOWLIST: it
# only shrinks, an entry whose class gains a timeline or a presentation pack
# fails as stale, and a class outside it without a second source fails closed.
const PARITY_EXEMPTIONS := {
	"assassin": "scene-only package: no timeline and no presentation pack",
	"berserk": "scene-only package: no timeline and no presentation pack",
	"biologist": "scene script animates normalized progress, not absolute phase seconds",
	"chemist": "scene-only package: no timeline and no presentation pack",
	"dark_mage": "scene-only package: no timeline and no presentation pack",
	"druid": "scene-only package: no timeline and no presentation pack",
	"elementalist": "scene-only package: no timeline and no presentation pack",
	"guitarist": "scene-only package: no timeline and no presentation pack",
	"knight": "scene-only package: no timeline and no presentation pack",
	"priest": "scene-only package: no timeline and no presentation pack",
	"soldier": "scene-only package: no timeline and no presentation pack",
}


func _initialize() -> void:
	var errors: Array[String] = []
	var checked_classes: Array[String] = []
	var skipped_classes: Array[String] = []
	var uncovered_classes: Array[String] = []
	var parity_classes: Array[String] = []
	var exempt_classes: Array[String] = []
	var parity_weapons := 0
	var v2_enforced_weapons := 0
	var v2_allowlisted_weapons := 0
	var compared_weapons := {}
	var class_directories := DirAccess.get_directories_at(MANIFEST_ROOT)
	class_directories.sort()
	_check_parity_exemptions(class_directories, errors)
	for class_directory in class_directories:
		var coverage := _class_timing_coverage(class_directory)
		var class_id := str(coverage["class_id"])
		match str(coverage["kind"]):
			"timings":
				var weapons := coverage["weapons"] as Array
				var reason := _timing_declaration_error(weapons)
				if reason.is_empty():
					checked_classes.append(class_id)
					var parity_source := str(coverage.get("parity_source", ""))
					if parity_source.is_empty():
						exempt_classes.append("%s (%s)" % [class_id, PARITY_EXEMPTIONS[class_id]])
					else:
						parity_classes.append("%s via %s" % [class_id, parity_source])
						parity_weapons += weapons.size()
					for raw_weapon in weapons:
						var weapon_id := str((raw_weapon as Dictionary).get("weapon_id", ""))
						var key := "%s/%s" % [class_id, weapon_id]
						if compared_weapons.has(key):
							errors.append("duplicate compared weapon: %s" % key)
						compared_weapons[key] = true
						# The v2 envelope is ratcheted: a pair still on the
						# migration allowlist keeps its v1 timing; a pair
						# outside it is asserted against the v2 ranges.
						if Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has(key):
							v2_allowlisted_weapons += 1
						else:
							v2_enforced_weapons += 1
							errors.append_array(Schema.v2_envelope_errors(
								(raw_weapon as Dictionary).get("timing_seconds"), key
							))
					_check_class(class_id, weapons, errors)
				else:
					uncovered_classes.append("%s (%s)" % [class_id, reason])
					errors.append("class %s is uncovered: %s" % [class_id, reason])
			"skipped":
				skipped_classes.append(class_id)
				errors.append("class %s is uncovered: no declared timing source" % class_id)
			"uncovered":
				var reason := str(coverage["reason"])
				uncovered_classes.append("%s (%s)" % [class_id, reason])
				errors.append("class %s is uncovered: %s" % [class_id, reason])

	print("Weapon ultimate timing distinctness coverage: checked %d class(es) / %d weapon(s); skipped %d without declared timing sources: %s; uncovered %d with unreadable timing declarations: %s." % [
		checked_classes.size(),
		compared_weapons.size(),
		skipped_classes.size(),
		", ".join(skipped_classes) if not skipped_classes.is_empty() else "none",
		uncovered_classes.size(),
		", ".join(uncovered_classes) if not uncovered_classes.is_empty() else "none",
	])
	print("Weapon ultimate timing distinctness checked classes: %s." % [", ".join(checked_classes)])
	print("Weapon ultimate timing parity coverage: %d/%d weapon(s) cross-checked against a second source (%s); %d exempt class(es): %s." % [
		parity_weapons,
		compared_weapons.size(),
		", ".join(parity_classes) if not parity_classes.is_empty() else "none",
		exempt_classes.size(),
		", ".join(exempt_classes) if not exempt_classes.is_empty() else "none",
	])
	print("Weapon ultimate v2 envelope coverage: %d weapon(s) enforced against the 2.5-4.0s envelope; %d still on the v1 migration allowlist (target: 0)." % [
		v2_enforced_weapons,
		v2_allowlisted_weapons,
	])
	if checked_classes.is_empty():
		errors.append("zero classes declare weapons[].timing_seconds")
	if checked_classes.size() != 17 or compared_weapons.size() != 51:
		errors.append("comparison set must contain exactly 17 classes / 51 unique weapons, got %d / %d" % [
			checked_classes.size(), compared_weapons.size(),
		])
	_assert_fail_closed_contract(errors)
	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate timing distinctness: %s" % error)
		quit(1)
		return
	print("Weapon ultimate timing distinctness passed at the %.2fs threshold." % MIN_RHYTHM_DELTA_SECONDS)
	quit(0)


func _class_timing_coverage(class_directory: String) -> Dictionary:
	var manifest_path := MANIFEST_ROOT.path_join(class_directory).path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = _load_json(manifest_path)
		if not parsed is Dictionary:
			return _uncovered(class_directory, "invalid manifest JSON: %s" % manifest_path)
		var manifest := parsed as Dictionary
		var class_id := str(manifest.get("class_id", class_directory))
		if class_id.is_empty():
			return _uncovered(class_directory, "manifest class_id must not be empty")
		var weapons = manifest.get("weapons", null)
		if weapons is Array and not weapons.is_empty():
			var second_source := _second_timing_source(class_id, class_directory)
			if str(second_source["kind"]) == "uncovered":
				return second_source
			if str(second_source["kind"]) == "timings":
				if PARITY_EXEMPTIONS.has(class_id):
					return _uncovered(class_id, "stale parity exemption: %s timing is now declared by %s" % [
						class_id, str(second_source["source"]),
					])
				var agreement_error := _timing_agreement_error(
					weapons as Array, second_source["weapons"] as Array
				)
				if not agreement_error.is_empty():
					return _uncovered(class_id, agreement_error)
				return {
					"kind": "timings",
					"class_id": class_id,
					"weapons": weapons,
					"parity_source": str(second_source["source"]),
				}
			if not PARITY_EXEMPTIONS.has(class_id):
				return _uncovered(class_id, "manifest timing has no second authoritative source: no *.timeline.json and no %s%s" % [
					class_directory, PACK_SUFFIX,
				])
			return {"kind": "timings", "class_id": class_id, "weapons": weapons}
		if weapons != null and not weapons is Array:
			return _uncovered(class_id, "manifest weapons must be an array")
		return _timeline_timing_coverage(class_id, class_directory)
	return _timeline_timing_coverage(class_directory, class_directory)


## Resolves the non-manifest timing declaration a class ships, if any: a
## `*.timeline.json` set first, otherwise its class-local presentation pack.
func _second_timing_source(class_id: String, class_directory: String) -> Dictionary:
	var timeline_coverage := _timeline_timing_coverage(class_id, class_directory)
	if str(timeline_coverage["kind"]) != "skipped":
		timeline_coverage["source"] = "timeline"
		return timeline_coverage
	var pack_coverage := _pack_timing_coverage(class_id, class_directory)
	pack_coverage["source"] = "presentation pack"
	return pack_coverage


func _timeline_timing_coverage(class_id: String, class_directory: String) -> Dictionary:
	var timeline_directory := TIMELINE_ROOT.path_join(class_directory)
	var timeline_files: Array[String] = []
	for filename in DirAccess.get_files_at(timeline_directory):
		if filename.ends_with(".timeline.json"):
			timeline_files.append(filename)
	if timeline_files.is_empty():
		return {"kind": "skipped", "class_id": class_id}
	timeline_files.sort()
	var weapons: Array = []
	for filename in timeline_files:
		var timeline_path := timeline_directory.path_join(filename)
		var parsed: Variant = _load_json(timeline_path)
		if not parsed is Dictionary:
			return _uncovered(class_id, "invalid timeline JSON: %s" % timeline_path)
		var timeline := parsed as Dictionary
		var manifest = timeline.get("manifest", null)
		if not manifest is Dictionary:
			return _uncovered(class_id, "timeline %s must declare manifest" % timeline_path)
		var timeline_manifest := manifest as Dictionary
		if str(timeline_manifest.get("class_id", "")) != class_id:
			return _uncovered(class_id, "timeline %s has a different class_id" % timeline_path)
		var key = timeline_manifest.get("key", null)
		if not key is Dictionary:
			return _uncovered(class_id, "timeline %s must declare manifest.key" % timeline_path)
		weapons.append({
			"weapon_id": str((key as Dictionary).get("weapon_id", "")),
			"timing_seconds": timeline_manifest.get("timing", null),
		})
	return {"kind": "timings", "class_id": class_id, "weapons": weapons}


func _pack_timing_coverage(class_id: String, class_directory: String) -> Dictionary:
	var pack_path := TIMELINE_ROOT.path_join(class_directory).path_join("%s%s" % [class_directory, PACK_SUFFIX])
	if not FileAccess.file_exists(pack_path):
		return {"kind": "skipped", "class_id": class_id}
	var pack := load(pack_path) as GDScript
	if pack == null:
		return _uncovered(class_id, "unreadable presentation pack: %s" % pack_path)
	var constants := pack.get_script_constant_map()
	if str(constants.get("CLASS_ID", "")) != class_id:
		return _uncovered(class_id, "presentation pack %s declares a different CLASS_ID" % pack_path)
	var declared = constants.get("WEAPONS", null)
	if not declared is Dictionary or (declared as Dictionary).is_empty():
		return _uncovered(class_id, "presentation pack %s must declare a non-empty WEAPONS map" % pack_path)
	var weapon_ids := (declared as Dictionary).keys()
	weapon_ids.sort()
	var weapons: Array = []
	for weapon_id in weapon_ids:
		var config = (declared as Dictionary)[weapon_id]
		if not config is Dictionary:
			return _uncovered(class_id, "presentation pack %s has a non-dictionary weapon entry" % pack_path)
		weapons.append({
			"weapon_id": str(weapon_id),
			"timing_seconds": (config as Dictionary).get(PACK_TIMING_KEY, null),
		})
	return {"kind": "timings", "class_id": class_id, "weapons": weapons}


func _check_parity_exemptions(class_directories: PackedStringArray, errors: Array[String]) -> void:
	for class_id in PARITY_EXEMPTIONS:
		if not class_directories.has(class_id):
			errors.append("parity exemption has no class package: %s" % class_id)
		elif str(PARITY_EXEMPTIONS[class_id]).is_empty():
			errors.append("parity exemption %s must state a reason" % class_id)


func _uncovered(class_id: String, reason: String) -> Dictionary:
	return {"kind": "uncovered", "class_id": class_id, "reason": reason}


func _timing_declaration_error(weapons: Array) -> String:
	if weapons.size() != 3:
		return "must declare exactly three weapons for pairwise timing checks"
	var seen := {}
	for raw_weapon in weapons:
		if not raw_weapon is Dictionary:
			return "contains a non-dictionary weapon entry"
		var weapon := raw_weapon as Dictionary
		var weapon_id := str(weapon.get("weapon_id", ""))
		var timing = weapon.get("timing_seconds", null)
		if weapon_id.is_empty() or not timing is Dictionary:
			return "weapon %s must declare timing_seconds" % [weapon_id if not weapon_id.is_empty() else "<missing-id>"]
		if seen.has(weapon_id):
			return "duplicate weapon_id %s" % weapon_id
		seen[weapon_id] = true
		var previous := -1.0
		for field in REQUIRED_TIMING_FIELDS:
			var value = (timing as Dictionary).get(field, null)
			if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) \
					or not is_finite(float(value)) or float(value) < previous:
				return "weapon %s timing_seconds.%s must be numeric" % [weapon_id, field]
			previous = float(value)
	return ""


func _timing_agreement_error(manifest_weapons: Array, source_weapons: Array) -> String:
	var manifest_error := _timing_declaration_error(manifest_weapons)
	var source_error := _timing_declaration_error(source_weapons)
	if not manifest_error.is_empty() or not source_error.is_empty():
		return "manifest/second-source declarations must both be complete: %s%s" % [
			manifest_error,
			"; %s" % source_error if not source_error.is_empty() else "",
		]
	var manifest_by_id := _timing_by_weapon_id(manifest_weapons)
	var source_by_id := _timing_by_weapon_id(source_weapons)
	var manifest_ids := manifest_by_id.keys()
	var source_ids := source_by_id.keys()
	manifest_ids.sort()
	source_ids.sort()
	if manifest_ids != source_ids:
		return "manifest/second-source weapon sets differ: %s vs %s" % [manifest_ids, source_ids]
	for weapon_id in manifest_ids:
		var manifest_timing := manifest_by_id[weapon_id] as Dictionary
		var source_timing := source_by_id[weapon_id] as Dictionary
		for field in REQUIRED_TIMING_FIELDS:
			if absf(float(manifest_timing[field]) - float(source_timing[field])) > COMPARISON_EPSILON:
				return "manifest/second-source mismatch for %s.%s" % [weapon_id, field]
	return ""


func _timing_by_weapon_id(weapons: Array) -> Dictionary:
	var result := {}
	for raw_weapon in weapons:
		var weapon := raw_weapon as Dictionary
		result[str(weapon["weapon_id"])] = (weapon["timing_seconds"] as Dictionary).duplicate(true)
	return result


func _assert_fail_closed_contract(errors: Array[String]) -> void:
	var complete := [
		{"weapon_id": "a", "timing_seconds": {"windup": 0.0, "release": 0.2, "active": 0.4, "recovery": 0.8, "cancel": 1.0}},
		{"weapon_id": "b", "timing_seconds": {"windup": 0.0, "release": 0.3, "active": 0.5, "recovery": 0.9, "cancel": 1.1}},
		{"weapon_id": "c", "timing_seconds": {"windup": 0.0, "release": 0.4, "active": 0.6, "recovery": 1.0, "cancel": 1.2}},
	]
	var missing := complete.duplicate(true)
	((missing[0] as Dictionary)["timing_seconds"] as Dictionary).erase("release")
	if _timing_declaration_error(missing).is_empty():
		errors.append("missing timing data must fail closed")
	var mismatch := complete.duplicate(true)
	((mismatch[1] as Dictionary)["timing_seconds"] as Dictionary)["active"] = 0.55
	if _timing_agreement_error(complete, mismatch).is_empty():
		errors.append("manifest/second-source timing mismatches must fail closed")
	var absent := complete.duplicate(true)
	(absent[2] as Dictionary)["timing_seconds"] = null
	if _timing_agreement_error(complete, absent).is_empty():
		errors.append("a second source without timing data must fail closed")
	var renamed := complete.duplicate(true)
	(renamed[0] as Dictionary)["weapon_id"] = "d"
	if _timing_agreement_error(complete, renamed).is_empty():
		errors.append("manifest/second-source weapon-set drift must fail closed")
	var v1_scale := {"windup": 0.0, "release": 0.2, "active": 0.4, "recovery": 0.8, "cancel": 1.0}
	if Schema.v2_envelope_errors(v1_scale, "self-check").is_empty():
		errors.append("v1-scale timing must violate the v2 envelope")
	var v2_scale := {"windup": 0.0, "release": 0.8, "active": 1.6, "recovery": 2.4, "cancel": 3.0}
	if not Schema.v2_envelope_errors(v2_scale, "self-check").is_empty():
		errors.append("v2-scale timing must satisfy the v2 envelope")


func _check_class(class_id: String, weapons: Array, errors: Array[String]) -> void:
	var timings: Array[Dictionary] = []
	for raw_weapon in weapons:
		var weapon := raw_weapon as Dictionary
		var weapon_id := str(weapon.get("weapon_id", ""))
		var values := weapon["timing_seconds"] as Dictionary
		timings.append({
			"weapon_id": weapon_id,
			"total": float(values["cancel"]),
			"active_window": float(values["recovery"]) - float(values["active"]),
		})

	for first_index in range(timings.size() - 1):
		for second_index in range(first_index + 1, timings.size()):
			var first := timings[first_index]
			var second := timings[second_index]
			_check_axis(class_id, first, second, "total length (cancel)", "total", errors)
			_check_axis(class_id, first, second, "active window (recovery - active)", "active_window", errors)


func _check_axis(class_id: String, first: Dictionary, second: Dictionary, axis: String, value_key: String, errors: Array[String]) -> void:
	var first_value := float(first[value_key])
	var second_value := float(second[value_key])
	if absf(first_value - second_value) + COMPARISON_EPSILON < MIN_RHYTHM_DELTA_SECONDS:
		errors.append("class %s weapons %s / %s axis %s must differ by at least %.2fs (%.2fs vs %.2fs)" % [
			class_id,
			str(first["weapon_id"]),
			str(second["weapon_id"]),
			axis,
			MIN_RHYTHM_DELTA_SECONDS,
			first_value,
			second_value,
		])


func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
