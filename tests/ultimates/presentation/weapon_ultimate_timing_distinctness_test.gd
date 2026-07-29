extends SceneTree

const MANIFEST_ROOT := "res://docs/design/references/weapon_ultimates"
const TIMELINE_ROOT := "res://scenes/vfx/ultimates"
const MIN_RHYTHM_DELTA_SECONDS := 0.1
const COMPARISON_EPSILON := 0.000001
const REQUIRED_TIMING_FIELDS := ["active", "recovery", "cancel"]


func _initialize() -> void:
	var errors: Array[String] = []
	var checked_classes: Array[String] = []
	var skipped_classes: Array[String] = []
	var uncovered_classes: Array[String] = []
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
					_check_class(class_id, weapons, errors)
				else:
					uncovered_classes.append("%s (%s)" % [class_id, reason])
					errors.append("class %s is uncovered: %s" % [class_id, reason])
			"skipped":
				skipped_classes.append(class_id)
			"uncovered":
				var reason := str(coverage["reason"])
				uncovered_classes.append("%s (%s)" % [class_id, reason])
				errors.append("class %s is uncovered: %s" % [class_id, reason])

	print("Weapon ultimate timing distinctness coverage: checked %d class(es); skipped %d without declared timing sources: %s; uncovered %d with unreadable timing declarations: %s." % [
		checked_classes.size(),
		skipped_classes.size(),
		", ".join(skipped_classes) if not skipped_classes.is_empty() else "none",
		uncovered_classes.size(),
		", ".join(uncovered_classes) if not uncovered_classes.is_empty() else "none",
	])
	print("Weapon ultimate timing distinctness checked classes: %s." % [", ".join(checked_classes)])
	if checked_classes.is_empty():
		errors.append("zero classes declare weapons[].timing_seconds")
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
	if weapons.size() < 2:
		return "must declare at least two weapons for pairwise timing checks"
	for raw_weapon in weapons:
		if not raw_weapon is Dictionary:
			return "contains a non-dictionary weapon entry"
		var weapon := raw_weapon as Dictionary
		var weapon_id := str(weapon.get("weapon_id", ""))
		var timing = weapon.get("timing_seconds", null)
		if weapon_id.is_empty() or not timing is Dictionary:
			return "weapon %s must declare timing_seconds" % [weapon_id if not weapon_id.is_empty() else "<missing-id>"]
		for field in REQUIRED_TIMING_FIELDS:
			var value = (timing as Dictionary).get(field, null)
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return "weapon %s timing_seconds.%s must be numeric" % [weapon_id, field]
	return ""


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
