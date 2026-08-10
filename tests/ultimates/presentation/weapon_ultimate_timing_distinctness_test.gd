extends SceneTree

const MANIFEST_ROOT := "res://docs/design/references/weapon_ultimates"
const TIMELINE_ROOT := "res://scenes/vfx/ultimates"
const MIN_RHYTHM_DELTA_SECONDS := 0.1
const COMPARISON_EPSILON := 0.000001
const REQUIRED_TIMING_FIELDS := ["windup", "release", "active", "recovery", "cancel"]


func _initialize() -> void:
	var errors: Array[String] = []
	var checked_classes: Array[String] = []
	var skipped_classes: Array[String] = []
	var uncovered_classes: Array[String] = []
	var compared_weapons := {}
	var class_directories := DirAccess.get_directories_at(MANIFEST_ROOT)
	class_directories.sort()
	for class_directory in class_directories:
		var coverage := _class_timing_coverage(class_directory)
		var class_id := str(coverage["class_id"])
		match str(coverage["kind"]):
			"timings":
				var weapons := coverage["weapons"] as Array
				var reason := _timing_declaration_error(weapons)
				if reason.is_empty():
					checked_classes.append(class_id)
					for raw_weapon in weapons:
						var weapon_id := str((raw_weapon as Dictionary).get("weapon_id", ""))
						var key := "%s/%s" % [class_id, weapon_id]
						if compared_weapons.has(key):
							errors.append("duplicate compared weapon: %s" % key)
						compared_weapons[key] = true
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
			var timeline_coverage := _timeline_timing_coverage(class_id, class_directory)
			if str(timeline_coverage["kind"]) == "uncovered":
				return timeline_coverage
			if str(timeline_coverage["kind"]) == "timings":
				var agreement_error := _timing_agreement_error(
					weapons as Array, timeline_coverage["weapons"] as Array
				)
				if not agreement_error.is_empty():
					return _uncovered(class_id, agreement_error)
			return {"kind": "timings", "class_id": class_id, "weapons": weapons}
		if weapons != null and not weapons is Array:
			return _uncovered(class_id, "manifest weapons must be an array")
		return _timeline_timing_coverage(class_id, class_directory)
	return _timeline_timing_coverage(class_directory, class_directory)


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


func _timing_agreement_error(manifest_weapons: Array, timeline_weapons: Array) -> String:
	var manifest_error := _timing_declaration_error(manifest_weapons)
	var timeline_error := _timing_declaration_error(timeline_weapons)
	if not manifest_error.is_empty() or not timeline_error.is_empty():
		return "manifest/timeline declarations must both be complete: %s%s" % [
			manifest_error,
			"; %s" % timeline_error if not timeline_error.is_empty() else "",
		]
	var manifest_by_id := _timing_by_weapon_id(manifest_weapons)
	var timeline_by_id := _timing_by_weapon_id(timeline_weapons)
	var manifest_ids := manifest_by_id.keys()
	var timeline_ids := timeline_by_id.keys()
	manifest_ids.sort()
	timeline_ids.sort()
	if manifest_ids != timeline_ids:
		return "manifest/timeline weapon sets differ: %s vs %s" % [manifest_ids, timeline_ids]
	for weapon_id in manifest_ids:
		var manifest_timing := manifest_by_id[weapon_id] as Dictionary
		var timeline_timing := timeline_by_id[weapon_id] as Dictionary
		for field in REQUIRED_TIMING_FIELDS:
			if absf(float(manifest_timing[field]) - float(timeline_timing[field])) > COMPARISON_EPSILON:
				return "manifest/timeline mismatch for %s.%s" % [weapon_id, field]
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
		errors.append("manifest/timeline timing mismatches must fail closed")


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
