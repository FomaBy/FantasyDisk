extends SceneTree

const Contract := preload("res://scripts/ultimates/presentation/contact_sheet_beats_contract.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const WeaponRegistry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PROFILE_ROOT := "res://data/ultimates/schema/v1/classes"
const CERTIFIED_CLASS_IDS: Array[String] = [
	"berserk", "biologist", "chemist", "druid", "elementalist", "engineer", "guitarist",
	"knight", "priest", "ranger", "robot", "sniper", "soldier", "thief",
]
const EVIDENCE_CLASS_IDS: Array[String] = ["chemist", "knight", "priest", "ranger", "robot", "sniper", "soldier", "thief"]
const VISIBILITY_ALPHA_EPSILON := 0.01

var _robot_registry = WeaponRegistry.new(ProgressionData.WEAPONS_BY_CLASS)


func _initialize() -> void:
	var errors: Array[String] = []
	var packages := _discover_packages(errors)
	var class_ids: Array = packages.keys()
	class_ids.sort()
	_check_allowlist(class_ids, errors)
	_check_certified_classes(errors)

	var checked_classes: Array[String] = []
	var pending_classes: Array[String] = []
	for raw_class_id in class_ids:
		var class_id := str(raw_class_id)
		var weapons := packages[class_id] as Array
		var requires_evidence := EVIDENCE_CLASS_IDS.has(class_id)
		var declaration_errors := _declaration_errors(
			class_id,
			weapons,
			Contract.frames_for_class(class_id),
			Contract.evidence_for_class(class_id) if requires_evidence else null,
			requires_evidence
		)
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
	_check_negative_probes(errors)
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


func _check_certified_classes(errors: Array[String]) -> void:
	for class_id in CERTIFIED_CLASS_IDS:
		if Contract.MIGRATION_ALLOWLIST.has(class_id):
			errors.append("certified class remains on migration allowlist: %s" % class_id)


func _declaration_errors(
	class_id: String,
	weapons: Array,
	frames_by_weapon: Dictionary,
	evidence: Variant,
	require_evidence: bool
) -> Array[String]:
	var errors: Array[String] = []
	var evidence_by_weapon := {}
	if require_evidence:
		if not evidence is Dictionary:
			errors.append("class %s is missing evidence source" % class_id)
		else:
			evidence_by_weapon = _load_evidence_by_weapon(class_id, weapons, evidence as Dictionary, errors)
	for raw_weapon_id in weapons:
		var weapon_id := str(raw_weapon_id)
		var raw_frames = frames_by_weapon.get(weapon_id, null)
		if not raw_frames is Array:
			for phase in Contract.REQUIRED_PHASES:
				errors.append("class %s weapon %s missing required phase %s" % [class_id, weapon_id, phase])
			continue
		var phases := {}
		var phase_times := {}
		for raw_frame in raw_frames as Array:
			if not raw_frame is Dictionary:
				errors.append("class %s weapon %s has a non-dictionary frame" % [class_id, weapon_id])
				continue
			var frame := raw_frame as Dictionary
			var phase := str(frame.get("phase", ""))
			if not Contract.REQUIRED_PHASES.has(phase):
				errors.append("class %s weapon %s has an unsupported frame phase %s" % [class_id, weapon_id, phase if not phase.is_empty() else "<empty>"])
			elif phases.has(phase):
				errors.append("class %s weapon %s has a duplicate frame phase %s" % [class_id, weapon_id, phase])
			else:
				phases[phase] = true
			var time = frame.get("time", null)
			if typeof(time) != TYPE_INT and typeof(time) != TYPE_FLOAT:
				errors.append("class %s weapon %s %s frame must declare numeric time" % [class_id, weapon_id, phase])
			elif float(time) <= 0.0:
				errors.append("class %s weapon %s %s frame time must be inside the timeline" % [class_id, weapon_id, phase])
			elif Contract.REQUIRED_PHASES.has(phase):
				phase_times[phase] = float(time)
			var nodes = frame.get("required_nodes", null)
			if not nodes is Array or (nodes as Array).is_empty():
				errors.append("class %s weapon %s %s frame must declare non-empty required_nodes" % [class_id, weapon_id, phase])
				continue
			for raw_node in nodes as Array:
				if str(raw_node).is_empty():
					errors.append("class %s weapon %s %s frame has an empty required node" % [class_id, weapon_id, phase])
		var previous_time := 0.0
		for phase in Contract.REQUIRED_PHASES:
			if not phases.has(phase):
				errors.append("class %s weapon %s missing required phase %s" % [class_id, weapon_id, phase])
			elif phase_times.has(phase):
				var time := float(phase_times[phase])
				if time <= previous_time:
					errors.append("class %s weapon %s %s frame time is out of phase order" % [class_id, weapon_id, phase])
				previous_time = time
		if require_evidence:
			_check_frame_evidence(
				class_id,
				weapon_id,
				raw_frames,
				evidence_by_weapon.get(weapon_id, null),
				errors
			)
	for raw_weapon_id in frames_by_weapon.keys():
		var weapon_id := str(raw_weapon_id)
		if not weapons.has(weapon_id):
			errors.append("class %s declares beats for unknown weapon %s" % [class_id, weapon_id])
	return errors


func _load_evidence_by_weapon(
	class_id: String,
	weapons: Array,
	evidence: Dictionary,
	errors: Array[String]
) -> Dictionary:
	var source_kind := str(evidence.get("source_kind", ""))
	match source_kind:
		"class_manifest":
			return _load_class_manifest_evidence(class_id, weapons, evidence, errors)
		"weapon_timelines":
			return _load_weapon_timeline_evidence(class_id, weapons, evidence, errors)
		_:
			errors.append("class %s has an unsupported evidence source kind %s" % [class_id, source_kind if not source_kind.is_empty() else "<empty>"])
	return {}


func _load_class_manifest_evidence(
	class_id: String,
	weapons: Array,
	evidence: Dictionary,
	errors: Array[String]
) -> Dictionary:
	var path := str(evidence.get("path", ""))
	var manifest := _read_evidence_json(path, class_id, errors)
	if manifest.is_empty():
		return {}
	if str(manifest.get("class_id", "")) != class_id:
		errors.append("class %s evidence manifest names %s" % [class_id, str(manifest.get("class_id", "<empty>"))])
	var raw_entries = manifest.get("weapons", null)
	if not raw_entries is Array:
		errors.append("class %s evidence manifest must contain weapons" % class_id)
		return {}
	var requires_frame_evidence := bool(evidence.get("frame_evidence", false))
	var frame_evidence_by_weapon := {}
	if requires_frame_evidence:
		var manifest_evidence = manifest.get("evidence", null)
		if not manifest_evidence is Dictionary:
			errors.append("class %s evidence manifest must contain an evidence block" % class_id)
		else:
			var raw_frame_evidence = (manifest_evidence as Dictionary).get("frame_local_beats", null)
			if not raw_frame_evidence is Dictionary:
				errors.append("class %s evidence manifest must contain frame_local_beats" % class_id)
			else:
				frame_evidence_by_weapon = raw_frame_evidence as Dictionary
	var by_weapon := {}
	for raw_entry in raw_entries as Array:
		if not raw_entry is Dictionary:
			errors.append("class %s evidence manifest has a non-dictionary weapon entry" % class_id)
			continue
		var entry := raw_entry as Dictionary
		var weapon_id := str(entry.get("weapon_id", ""))
		if weapon_id.is_empty() or by_weapon.has(weapon_id):
			errors.append("class %s evidence manifest has an invalid or duplicate weapon_id: %s" % [class_id, weapon_id if not weapon_id.is_empty() else "<empty>"])
			continue
		if not weapons.has(weapon_id):
			errors.append("class %s evidence manifest declares an unknown weapon %s" % [class_id, weapon_id])
			continue
		var scene_path := _resource_path(str(entry.get("scene_path", "")))
		var timing = entry.get("timing_seconds", null)
		if scene_path.is_empty():
			errors.append("class %s weapon %s evidence is missing scene_path" % [class_id, weapon_id])
		if not timing is Dictionary:
			errors.append("class %s weapon %s evidence is missing timing_seconds" % [class_id, weapon_id])
		by_weapon[weapon_id] = {
			"source_path": path,
			"scene_path": scene_path,
			"timing": timing,
			"frame_local_beats": frame_evidence_by_weapon.get(weapon_id, null),
			"requires_frame_evidence": requires_frame_evidence,
		}
	for raw_weapon_id in weapons:
		var weapon_id := str(raw_weapon_id)
		if not by_weapon.has(weapon_id):
			errors.append("class %s weapon %s is missing evidence" % [class_id, weapon_id])
	return by_weapon


func _load_weapon_timeline_evidence(
	class_id: String,
	weapons: Array,
	evidence: Dictionary,
	errors: Array[String]
) -> Dictionary:
	var raw_paths = evidence.get("paths_by_weapon", null)
	if not raw_paths is Dictionary:
		errors.append("class %s evidence is missing paths_by_weapon" % class_id)
		return {}
	var paths := raw_paths as Dictionary
	for raw_weapon_id in paths.keys():
		var weapon_id := str(raw_weapon_id)
		if not weapons.has(weapon_id):
			errors.append("class %s evidence declares an unknown weapon %s" % [class_id, weapon_id])
	var by_weapon := {}
	for raw_weapon_id in weapons:
		var weapon_id := str(raw_weapon_id)
		var path := str(paths.get(weapon_id, ""))
		var definition := _read_evidence_json(path, "%s/%s" % [class_id, weapon_id], errors)
		if definition.is_empty():
			continue
		var manifest = definition.get("manifest", null)
		if not manifest is Dictionary:
			errors.append("class %s weapon %s evidence is missing manifest" % [class_id, weapon_id])
			continue
		var typed_manifest := manifest as Dictionary
		var key = typed_manifest.get("key", {}) as Dictionary
		if str(typed_manifest.get("class_id", "")) != class_id or str(key.get("weapon_id", "")) != weapon_id:
			errors.append("class %s weapon %s evidence has the wrong canonical key" % [class_id, weapon_id])
		var scene_path := _resource_path(str(definition.get("scene_path", "")))
		var timing = typed_manifest.get("timing", null)
		if scene_path.is_empty():
			errors.append("class %s weapon %s evidence is missing scene_path" % [class_id, weapon_id])
		if not timing is Dictionary:
			errors.append("class %s weapon %s evidence is missing timing" % [class_id, weapon_id])
		by_weapon[weapon_id] = {"source_path": path, "scene_path": scene_path, "timing": timing}
	return by_weapon


func _read_evidence_json(path: String, label: String, errors: Array[String]) -> Dictionary:
	if path.is_empty():
		errors.append("%s evidence path is missing" % label)
		return {}
	if not FileAccess.file_exists(path):
		errors.append("%s evidence is missing: %s" % [label, path])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s evidence must contain valid JSON: %s" % [label, path])
		return {}
	return (parsed as Dictionary).duplicate(true)


func _check_frame_evidence(
	class_id: String,
	weapon_id: String,
	raw_frames: Variant,
	raw_evidence: Variant,
	errors: Array[String]
) -> void:
	if not raw_evidence is Dictionary:
		errors.append("class %s weapon %s is missing evidence" % [class_id, weapon_id])
		return
	if not raw_frames is Array:
		return
	var evidence := raw_evidence as Dictionary
	var timing = evidence.get("timing", null)
	if not timing is Dictionary:
		errors.append("class %s weapon %s evidence has no timing" % [class_id, weapon_id])
		return
	var typed_timing := timing as Dictionary
	var raw_cancel = typed_timing.get("cancel", null)
	if typeof(raw_cancel) != TYPE_INT and typeof(raw_cancel) != TYPE_FLOAT:
		errors.append("class %s weapon %s evidence has no numeric cancel time" % [class_id, weapon_id])
		return
	var cancel_time := float(raw_cancel)
	if bool(evidence.get("requires_frame_evidence", false)):
		_check_frame_local_evidence(
			class_id,
			weapon_id,
			raw_frames,
			evidence.get("frame_local_beats", null),
			errors
		)
	var scene_path := str(evidence.get("scene_path", ""))
	var packed: PackedScene = load(scene_path) as PackedScene if not scene_path.is_empty() else null
	if packed == null:
		errors.append("class %s weapon %s evidence scene is missing: %s" % [class_id, weapon_id, scene_path if not scene_path.is_empty() else "<empty>"])
	for raw_frame in raw_frames as Array:
		if not raw_frame is Dictionary:
			continue
		var frame := raw_frame as Dictionary
		var phase := str(frame.get("phase", ""))
		var raw_time = frame.get("time", null)
		if typeof(raw_time) != TYPE_INT and typeof(raw_time) != TYPE_FLOAT:
			continue
		var time := float(raw_time)
		var expected_time = typed_timing.get(phase, null)
		if typeof(expected_time) != TYPE_INT and typeof(expected_time) != TYPE_FLOAT:
			errors.append("class %s weapon %s evidence is missing phase time %s" % [class_id, weapon_id, phase])
		elif not is_equal_approx(time, float(expected_time)):
			errors.append("class %s weapon %s %s frame time must match evidence" % [class_id, weapon_id, phase])
		if time >= cancel_time:
			errors.append("class %s weapon %s %s frame time is outside evidence timeline" % [class_id, weapon_id, phase])
		if packed != null and time > 0.0 and time < cancel_time:
			_check_visible_evidence_nodes(class_id, weapon_id, phase, time, frame.get("required_nodes", []), packed, errors)


func _check_frame_local_evidence(
	class_id: String,
	weapon_id: String,
	raw_frames: Variant,
	raw_manifest_frames: Variant,
	errors: Array[String]
) -> void:
	if not raw_manifest_frames is Array:
		errors.append("class %s weapon %s evidence is missing frame_local_beats" % [class_id, weapon_id])
		return
	var declared_by_phase := {}
	for raw_declared in raw_manifest_frames as Array:
		if not raw_declared is Dictionary:
			errors.append("class %s weapon %s frame_local_beats has a non-dictionary frame" % [class_id, weapon_id])
			continue
		var declared := raw_declared as Dictionary
		var phase := str(declared.get("phase", ""))
		if not Contract.REQUIRED_PHASES.has(phase):
			errors.append("class %s weapon %s frame_local_beats has unsupported phase %s" % [class_id, weapon_id, phase if not phase.is_empty() else "<empty>"])
			continue
		if declared_by_phase.has(phase):
			errors.append("class %s weapon %s frame_local_beats has duplicate phase %s" % [class_id, weapon_id, phase])
			continue
		var time = declared.get("time", null)
		if typeof(time) != TYPE_INT and typeof(time) != TYPE_FLOAT:
			errors.append("class %s weapon %s %s frame_local_beats time must be numeric" % [class_id, weapon_id, phase])
		var nodes = declared.get("required_nodes", null)
		if not nodes is Array or (nodes as Array).is_empty():
			errors.append("class %s weapon %s %s frame_local_beats must declare required_nodes" % [class_id, weapon_id, phase])
		declared_by_phase[phase] = declared
	if not raw_frames is Array:
		return
	for phase in Contract.REQUIRED_PHASES:
		var declared = declared_by_phase.get(phase, null)
		if declared == null:
			errors.append("class %s weapon %s frame_local_beats is missing phase %s" % [class_id, weapon_id, phase])
			continue
		for raw_frame in raw_frames as Array:
			if not raw_frame is Dictionary or str((raw_frame as Dictionary).get("phase", "")) != phase:
				continue
			var frame := raw_frame as Dictionary
			var frame_time = frame.get("time", null)
			var declared_time = declared.get("time", null)
			if (typeof(frame_time) == TYPE_INT or typeof(frame_time) == TYPE_FLOAT) \
					and (typeof(declared_time) == TYPE_INT or typeof(declared_time) == TYPE_FLOAT) \
					and not is_equal_approx(float(frame_time), float(declared_time)):
				errors.append("class %s weapon %s %s frame_local_beats time must match contract" % [class_id, weapon_id, phase])
			if _node_list(frame.get("required_nodes", [])) != _node_list(declared.get("required_nodes", [])):
				errors.append("class %s weapon %s %s frame_local_beats required_nodes must match contract" % [class_id, weapon_id, phase])
			break


func _check_visible_evidence_nodes(
	class_id: String,
	weapon_id: String,
	phase: String,
	time: float,
	raw_nodes: Variant,
	packed: PackedScene,
	errors: Array[String]
) -> void:
	if not raw_nodes is Array:
		return
	var instance := packed.instantiate()
	if not instance is Node2D:
		errors.append("class %s weapon %s evidence scene must instantiate as Node2D" % [class_id, weapon_id])
		return
	var scene := instance as Node2D
	root.add_child(scene)
	_seek_evidence_scene(scene, class_id, weapon_id, phase, time, errors)
	if class_id == "robot" and not _has_visible_robot_element(scene):
		errors.append("class %s weapon %s %s evidence scene has no visible formation element" % [class_id, weapon_id, phase])
	for raw_node in raw_nodes as Array:
		var node_path := str(raw_node)
		var node := _evidence_node(scene, node_path)
		if node == null:
			errors.append("class %s weapon %s %s evidence node is missing: %s" % [class_id, weapon_id, phase, node_path])
			continue
		if not node is CanvasItem:
			errors.append("class %s weapon %s %s evidence node is not visual: %s" % [class_id, weapon_id, phase, node_path])
			continue
		if not _is_evidence_node_visible(node as CanvasItem, scene):
			errors.append("class %s weapon %s %s evidence node is not visible: %s" % [class_id, weapon_id, phase, node_path])
	if (class_id == "ranger" or class_id == "thief" or class_id == "sniper") and scene.has_method("finish"):
		scene.call("finish", "node_end")
	scene.free()


func _seek_evidence_scene(
	scene: Node2D,
	class_id: String,
	weapon_id: String,
	phase: String,
	time: float,
	errors: Array[String]
) -> void:
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null:
		if not timeline.has_animation(&"ultimate"):
			errors.append("class %s weapon %s evidence scene has no ultimate animation" % [class_id, weapon_id])
			return
		var animation := timeline.get_animation(&"ultimate")
		if animation == null or time >= animation.length:
			errors.append("class %s weapon %s %s frame time is outside visual timeline" % [class_id, weapon_id, phase])
			return
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(time, true)
		return
	if class_id == "sniper":
		if not scene.has_method("begin") or not scene.has_method("advance"):
			errors.append("class %s weapon %s evidence scene cannot seek phase %s" % [class_id, weapon_id, phase])
			return
		scene.call("begin", {}, 0)
		scene.call("advance", time)
		return
	if class_id == "robot":
		if not scene.has_method("begin") or not scene.has_method("step"):
			errors.append("class %s weapon %s evidence scene cannot seek phase %s" % [class_id, weapon_id, phase])
			return
		var snapshot = scene.call("begin", _robot_registry, {}, 0)
		if not snapshot is Dictionary or str((snapshot as Dictionary).get("state", "")) != "active":
			errors.append("class %s weapon %s evidence scene cannot start a visual timeline" % [class_id, weapon_id])
			return
		scene.call("step", time)
		return
	if class_id == "ranger" or class_id == "thief":
		if not scene.has_method("begin") or not scene.has_method("step"):
			errors.append("class %s weapon %s evidence scene cannot seek phase %s" % [class_id, weapon_id, phase])
			return
		var snapshot = scene.call("begin", _robot_registry, {}, 0)
		if not snapshot is Dictionary or str((snapshot as Dictionary).get("state", "")) != "active":
			errors.append("class %s weapon %s evidence scene cannot start a visual timeline" % [class_id, weapon_id])
			return
		scene.call("step", time)


static func _evidence_node(scene: Node2D, node_path: String) -> Node:
	if node_path == Contract.VISIBLE_EFFECT_NODE:
		return _find_visible_effect_node(scene, scene)
	if node_path == "." or node_path == scene.name:
		return scene
	return scene.get_node_or_null(node_path)


static func _node_list(raw_nodes: Variant) -> Array[String]:
	var nodes: Array[String] = []
	if raw_nodes is Array:
		for raw_node in raw_nodes as Array:
			nodes.append(str(raw_node))
	return nodes


static func _find_visible_effect_node(parent: Node, scene: Node2D) -> Node:
	for child in parent.get_children():
		if child is CanvasItem and _is_evidence_node_visible(child as CanvasItem, scene):
			return child
		var descendant := _find_visible_effect_node(child, scene)
		if descendant != null:
			return descendant
	return null


static func _is_evidence_node_visible(item: CanvasItem, scene: Node2D) -> bool:
	var current: Node = item
	while current != null:
		if current is CanvasItem:
			var canvas_item := current as CanvasItem
			if not canvas_item.visible or canvas_item.modulate.a * canvas_item.self_modulate.a <= VISIBILITY_ALPHA_EPSILON:
				return false
		if current == scene:
			break
		current = current.get_parent()
	if item is Polygon2D and (item as Polygon2D).color.a <= VISIBILITY_ALPHA_EPSILON:
		return false
	if item is Line2D and (item as Line2D).default_color.a <= VISIBILITY_ALPHA_EPSILON:
		return false
	return true


static func _has_visible_robot_element(scene: Node2D) -> bool:
	for child in scene.get_children():
		if child is Sprite2D and _is_evidence_node_visible(child as Sprite2D, scene):
			return true
	return false


static func _resource_path(path: String) -> String:
	if path.is_empty():
		return ""
	return path if path.begins_with("res://") else "res://%s" % path


func _check_negative_probes(errors: Array[String]) -> void:
	var class_id := "chemist"
	var weapons: Array[String] = ["blast_powder", "acid_flask", "homunculus_vial"]
	var frames := Contract.frames_for_class(class_id)
	var evidence := Contract.evidence_for_class(class_id)

	var unknown_weapon := frames.duplicate(true)
	unknown_weapon["unknown_weapon"] = []
	_expect_probe_error(
		"unknown weapon",
		_declaration_errors(class_id, weapons, unknown_weapon, null, false),
		"declares beats for unknown weapon unknown_weapon",
		errors
	)

	var unknown_node := frames.duplicate(true)
	var unknown_node_frames := unknown_node.get("blast_powder", []) as Array
	(unknown_node_frames[0] as Dictionary)["required_nodes"] = ["NoSuchNode"]
	_expect_probe_error(
		"unknown node",
		_declaration_errors(class_id, weapons, unknown_node, evidence, true),
		"evidence node is missing: NoSuchNode",
		errors
	)

	var missing_phase := frames.duplicate(true)
	var missing_phase_frames := missing_phase.get("blast_powder", []) as Array
	missing_phase_frames.remove_at(1)
	_expect_probe_error(
		"missing phase",
		_declaration_errors(class_id, weapons, missing_phase, evidence, true),
		"missing required phase active",
		errors
	)

	var missing_time := frames.duplicate(true)
	var missing_time_frames := missing_time.get("acid_flask", []) as Array
	(missing_time_frames[0] as Dictionary).erase("time")
	_expect_probe_error(
		"missing time",
		_declaration_errors(class_id, weapons, missing_time, evidence, true),
		"frame must declare numeric time",
		errors
	)

	var out_of_range := frames.duplicate(true)
	var out_of_range_frames := out_of_range.get("homunculus_vial", []) as Array
	(out_of_range_frames[0] as Dictionary)["time"] = 99.0
	_expect_probe_error(
		"out-of-range time",
		_declaration_errors(class_id, weapons, out_of_range, evidence, true),
		"frame time is outside evidence timeline",
		errors
	)

	_expect_probe_error(
		"missing evidence",
		_declaration_errors(class_id, weapons, frames, {}, true),
		"unsupported evidence source kind <empty>",
		errors
	)


func _expect_probe_error(
	probe_name: String,
	probe_errors: Array[String],
	expected_fragment: String,
	errors: Array[String]
) -> void:
	for probe_error in probe_errors:
		if probe_error.contains(expected_fragment):
			return
	errors.append("negative %s probe must fail with %s, got: %s" % [probe_name, expected_fragment, str(probe_errors)])


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Weapon ultimate contact-sheet beats contract passed.")
		quit(0)
		return
	for error in errors:
		push_error("Weapon ultimate contact-sheet beats contract: %s" % error)
	quit(1)
