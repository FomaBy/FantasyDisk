extends SceneTree

const MANIFEST_ROOT := "res://docs/design/references/weapon_ultimates"
const MIN_RHYTHM_DELTA_SECONDS := 0.1
const COMPARISON_EPSILON := 0.000001
const REQUIRED_TIMING_FIELDS := ["active", "recovery", "cancel"]


func _initialize() -> void:
	var errors: Array[String] = []
	var checked_classes: Array[String] = []
	var skipped_classes: Array[String] = []
	var class_directories := DirAccess.get_directories_at(MANIFEST_ROOT)
	class_directories.sort()
	for class_directory in class_directories:
		var manifest_path := MANIFEST_ROOT.path_join(class_directory).path_join("manifest.json")
		if not FileAccess.file_exists(manifest_path):
			continue
		var parsed: Variant = _load_json(manifest_path, errors)
		if not parsed is Dictionary:
			continue
		var manifest := parsed as Dictionary
		var class_id := str(manifest.get("class_id", class_directory))
		var weapons = manifest.get("weapons", null)
		if not weapons is Array or weapons.is_empty():
			skipped_classes.append(class_id)
			continue
		checked_classes.append(class_id)
		_check_class(class_id, weapons as Array, errors)

	print("Weapon ultimate timing distinctness coverage: checked %d class(es); skipped %d without weapons[].timing_seconds: %s." % [
		checked_classes.size(),
		skipped_classes.size(),
		", ".join(skipped_classes) if not skipped_classes.is_empty() else "none",
	])
	if checked_classes.is_empty():
		errors.append("zero classes declare weapons[].timing_seconds")
	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate timing distinctness: %s" % error)
		quit(1)
		return
	print("Weapon ultimate timing distinctness passed at the %.2fs threshold." % MIN_RHYTHM_DELTA_SECONDS)
	quit(0)


func _check_class(class_id: String, weapons: Array, errors: Array[String]) -> void:
	if weapons.size() < 2:
		errors.append("class %s must declare at least two weapons for pairwise timing checks" % class_id)
		return
	var timings: Array[Dictionary] = []
	for raw_weapon in weapons:
		if not raw_weapon is Dictionary:
			errors.append("class %s contains a non-dictionary weapon entry" % class_id)
			continue
		var weapon := raw_weapon as Dictionary
		var weapon_id := str(weapon.get("weapon_id", ""))
		var timing = weapon.get("timing_seconds", null)
		if weapon_id.is_empty() or not timing is Dictionary:
			errors.append("class %s weapon %s must declare timing_seconds" % [class_id, weapon_id if not weapon_id.is_empty() else "<missing-id>"])
			continue
		var valid := true
		for field in REQUIRED_TIMING_FIELDS:
			var value = (timing as Dictionary).get(field, null)
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				errors.append("class %s weapon %s timing_seconds.%s must be numeric" % [class_id, weapon_id, field])
				valid = false
		if valid:
			var values := timing as Dictionary
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


func _load_json(path: String, errors: Array[String]) -> Variant:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid manifest JSON: %s" % path)
		return null
	return parsed
