extends SceneTree

const Contract := preload("res://scripts/ultimates/presentation/contact_sheet_beats_contract.gd")
const PROFILE_ROOT := "res://data/ultimates/schema/v1/classes"


func _initialize() -> void:
	var errors: Array[String] = []
	var packages := _discover_packages(errors)
	var class_ids: Array = packages.keys()
	class_ids.sort()
	_check_allowlist(class_ids, errors)

	var checked_classes: Array[String] = []
	var pending_classes: Array[String] = []
	for raw_class_id in class_ids:
		var class_id := str(raw_class_id)
		var weapons := packages[class_id] as Array
		var declaration_errors := _declaration_errors(class_id, weapons)
		if Contract.MIGRATION_ALLOWLIST.has(class_id):
			pending_classes.append(class_id)
			if declaration_errors.is_empty():
				errors.append("stale migration allowlist entry: class %s already declares frame-local release, active, and recovery beats" % class_id)
			continue
		checked_classes.append(class_id)
		errors.append_array(declaration_errors)

	print("Weapon ultimate contact-sheet beats coverage: checked %d class(es): %s; migration allowlist %d class(es): %s." % [
		checked_classes.size(),
		", ".join(checked_classes) if not checked_classes.is_empty() else "none",
		pending_classes.size(),
		", ".join(pending_classes) if not pending_classes.is_empty() else "none",
	])
	if class_ids.is_empty():
		errors.append("zero class ultimate packages were discovered")
	if checked_classes.is_empty():
		errors.append("zero class packages satisfy the contact-sheet beats contract")
	_finish(errors)


func _discover_packages(errors: Array[String]) -> Dictionary:
	var packages := {}
	var filenames := DirAccess.get_files_at(PROFILE_ROOT)
	filenames.sort()
	for filename in filenames:
		if not filename.ends_with(".json"):
			continue
		var path := PROFILE_ROOT.path_join(filename)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			errors.append("class profile %s must contain valid JSON" % path)
			continue
		var profile := parsed as Dictionary
		var class_id := str(profile.get("class_id", ""))
		if class_id.is_empty():
			errors.append("class profile %s has an empty class_id" % path)
			continue
		if packages.has(class_id):
			errors.append("duplicate class profile declaration: %s" % class_id)
			continue
		var raw_profiles = profile.get("profiles", null)
		if not raw_profiles is Array or (raw_profiles as Array).is_empty():
			errors.append("class %s must declare non-empty profiles" % class_id)
			continue
		var weapons: Array[String] = []
		for raw_weapon in raw_profiles as Array:
			if not raw_weapon is Dictionary:
				errors.append("class %s has a non-dictionary weapon profile" % class_id)
				continue
			var weapon_id := str((raw_weapon as Dictionary).get("weapon_id", ""))
			if weapon_id.is_empty() or weapons.has(weapon_id):
				errors.append("class %s has an invalid or duplicate weapon_id: %s" % [class_id, weapon_id if not weapon_id.is_empty() else "<empty>"])
				continue
			weapons.append(weapon_id)
		if not weapons.is_empty():
			packages[class_id] = weapons
	return packages


func _check_allowlist(class_ids: Array, errors: Array[String]) -> void:
	var seen := {}
	for class_id in Contract.MIGRATION_ALLOWLIST:
		if seen.has(class_id):
			errors.append("duplicate migration allowlist entry: %s" % class_id)
		elif not class_ids.has(class_id):
			errors.append("migration allowlist entry has no class package: %s" % class_id)
		else:
			seen[class_id] = true


func _declaration_errors(class_id: String, weapons: Array) -> Array[String]:
	var errors: Array[String] = []
	var frames_by_weapon := Contract.frames_for_class(class_id)
	for raw_weapon_id in weapons:
		var weapon_id := str(raw_weapon_id)
		var raw_frames = frames_by_weapon.get(weapon_id, null)
		if not raw_frames is Array:
			for phase in Contract.REQUIRED_PHASES:
				errors.append("class %s weapon %s missing required phase %s" % [class_id, weapon_id, phase])
			continue
		var phases := {}
		for raw_frame in raw_frames as Array:
			if not raw_frame is Dictionary:
				errors.append("class %s weapon %s has a non-dictionary frame" % [class_id, weapon_id])
				continue
			var frame := raw_frame as Dictionary
			var phase := str(frame.get("phase", ""))
			if not Contract.REQUIRED_PHASES.has(phase):
				errors.append("class %s weapon %s has an unsupported frame phase %s" % [class_id, weapon_id, phase if not phase.is_empty() else "<empty>"])
			else:
				phases[phase] = true
			var time = frame.get("time", null)
			if typeof(time) != TYPE_INT and typeof(time) != TYPE_FLOAT:
				errors.append("class %s weapon %s %s frame must declare numeric time" % [class_id, weapon_id, phase])
			var nodes = frame.get("required_nodes", null)
			if not nodes is Array or (nodes as Array).is_empty():
				errors.append("class %s weapon %s %s frame must declare non-empty required_nodes" % [class_id, weapon_id, phase])
				continue
			for raw_node in nodes as Array:
				if str(raw_node).is_empty():
					errors.append("class %s weapon %s %s frame has an empty required node" % [class_id, weapon_id, phase])
		for phase in Contract.REQUIRED_PHASES:
			if not phases.has(phase):
				errors.append("class %s weapon %s missing required phase %s" % [class_id, weapon_id, phase])
	for raw_weapon_id in frames_by_weapon.keys():
		var weapon_id := str(raw_weapon_id)
		if not weapons.has(weapon_id):
			errors.append("class %s declares beats for unknown weapon %s" % [class_id, weapon_id])
	return errors


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Weapon ultimate contact-sheet beats contract passed.")
		quit(0)
		return
	for error in errors:
		push_error("Weapon ultimate contact-sheet beats contract: %s" % error)
	quit(1)
