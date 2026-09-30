class_name WeaponUltimatePresentationManifest
extends RefCounted

## Deterministic bridge from immutable weapon profile IDs to presentation data.
##
## The bridge intentionally supplies no gameplay strategy, scene instantiation,
## or pool ownership. It resolves the accepted class-local presentation record
## by the exact class/weapon pair; a missing record is an error, never a
## bootstrap-texture fallback.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const DEFAULT_SFX_PATH := "res://assets/audio/sfx/sfx_hit_magic.ogg"
## FAN-3985: the runtime reads only the derived class documents under
## `data/ultimates/presentation/<class>.json`. The authored source stays
## `docs/design/references/weapon_ultimates/<class>/manifest.json`, but
## `docs/*` is excluded from every export preset, so the exported build never
## sees it; `tools/build_ultimate_presentation_runtime_data.py` derives the
## runtime documents and the Python unit gate fails when they drift.
const PRESENTATION_ROOT := "res://data/ultimates/presentation"


static func catalog_for_registry(registry) -> Dictionary:
	var catalog := {}
	for raw_key in registry.profile_keys():
		var parts := str(raw_key).split("/", false, 1)
		if parts.size() != 2:
			continue
		var profile: Dictionary = registry.catalog_profile_for(parts[0], parts[1])
		if profile.is_empty():
			continue
		catalog[str(raw_key)] = manifest_for_profile(profile)
	return catalog


static func expected_profiles_for_registry(registry) -> Dictionary:
	var profiles := {}
	for raw_key in registry.profile_keys():
		var parts := str(raw_key).split("/", false, 1)
		if parts.size() != 2:
			continue
		var profile: Dictionary = registry.catalog_profile_for(parts[0], parts[1])
		if not profile.is_empty():
			profiles[str(raw_key)] = profile
	return profiles


static func manifest_for_profile(profile: Dictionary) -> Dictionary:
	var class_id := str(profile.get("class_id", ""))
	var weapon_id := str(profile.get("weapon_id", ""))
	var local := class_weapon_record(class_id, weapon_id)
	if local.is_empty():
		return {}
	var presentation: Dictionary = profile.get("presentation", {})
	var cast_phases: Dictionary = profile.get("cast_phases", {})
	var scene_path := str(local.get("scene_path", ""))
	var timing: Dictionary = local.get("timing", {}) as Dictionary
	var manifest := {
		"schema_version": Schema.EXPECTED_SCHEMA_VERSION,
		"class_id": class_id,
		"key": {
			"weapon_id": weapon_id,
			"action": Schema.ACTION_ULTIMATE,
		},
		"presentation_id": str(presentation.get("presentation_id", "")),
		"animation": _asset(str(presentation.get("animation_id", "")), scene_path),
		"vfx": _asset(str(presentation.get("vfx_id", "")), scene_path),
		"sfx": _asset(str(presentation.get("sfx_id", "")), DEFAULT_SFX_PATH),
		"phases": [
			{"name": "windup", "phase_id": str(cast_phases.get("windup", ""))},
			{"name": "release", "phase_id": str(cast_phases.get("execute", ""))},
			{"name": "active", "phase_id": str(cast_phases.get("active", ""))},
			{"name": "recovery", "phase_id": str(cast_phases.get("recover", ""))},
			{"name": "cancel", "phase_id": str(cast_phases.get("cleanup", ""))},
		],
		"pivot": _pivot(local.get("pivot", {})),
		"timing": timing,
		"headless_fallback": "no_op",
		"runtime": {
			"scene_path": scene_path,
			"max_visual_nodes": int(local.get("max_visual_nodes", 0)),
			"crowd_cap": int(local.get("crowd_cap", 0)),
			"max_unique_materials": local.get("max_unique_materials"),
			"max_fullscreen_materials": local.get("max_fullscreen_materials"),
		},
	}
	# v2 presence/identity declarations pass through only when the class-local
	# record ships them, so v1 manifests keep their exact shape until reworked.
	# `quality` rides along so the runtime can honor the declared flash budget
	# (`full_screen_flash_hz`, `max_flash_coverage_ratio`).
	for block in ["presence", "identity", "quality"]:
		if local.has(block):
			manifest[block] = local[block]
	return manifest


static func _asset(id: String, path: String) -> Dictionary:
	return {
		"id": id,
		"source_path": path,
		"runtime_path": path,
	}


## Resolves the one accepted presentation scene and its declared visual budget.
## All callers use this exact key; no class/default asset is substituted.
static func class_weapon_record(class_id: String, weapon_id: String) -> Dictionary:
	if class_id.is_empty() or weapon_id.is_empty():
		return {}
	var document := class_document(class_id)
	if document.is_empty():
		return {}
	var weapon: Dictionary = _weapon_record(document, weapon_id)
	if weapon.is_empty():
		return {}
	var scene_path: String = _resource_path(str(weapon.get("scene_path", "")))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return {}
	var performance: Dictionary = weapon.get("performance", {}) as Dictionary
	var timing = weapon.get("timing_seconds")
	if not timing is Dictionary:
		return {}
	var normalized_timing: Dictionary = _timing(timing as Dictionary)
	if normalized_timing.is_empty():
		return {}
	var max_visual_nodes := int((performance as Dictionary).get("max_visual_nodes", 0))
	var crowd_cap := int((performance as Dictionary).get("crowd_cap", 0))
	if max_visual_nodes > 0 and crowd_cap > 0 and max_visual_nodes > crowd_cap:
		return {}
	var record := {
		"scene_path": scene_path,
		"timing": normalized_timing,
		"pivot": weapon.get("pivot", {}),
		"max_visual_nodes": max_visual_nodes,
		"crowd_cap": crowd_cap,
		"max_unique_materials": (performance as Dictionary).get("max_unique_materials"),
		"max_fullscreen_materials": (performance as Dictionary).get("max_fullscreen_materials"),
	}
	for block in ["presence", "identity", "quality"]:
		if weapon.get(block) is Dictionary:
			record[block] = (weapon[block] as Dictionary).duplicate(true)
	return record


## The runtime document of one class: `{}` when it is absent, unparsable or
## declares another class. Every runtime read of presentation data goes
## through this path, so a document missing from an export fails closed here.
static func class_document(class_id: String) -> Dictionary:
	if class_id.is_empty():
		return {}
	var document_path := class_document_path(class_id)
	if not FileAccess.file_exists(document_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(document_path))
	if not parsed is Dictionary or str((parsed as Dictionary).get("class_id", "")) != class_id:
		return {}
	return parsed as Dictionary


static func class_document_path(class_id: String) -> String:
	return "%s/%s.json" % [PRESENTATION_ROOT, class_id]


static func _weapon_record(document: Dictionary, weapon_id: String) -> Dictionary:
	var weapons = document.get("weapons", [])
	if weapons is Array:
		for raw_weapon in weapons as Array:
			if raw_weapon is Dictionary and str((raw_weapon as Dictionary).get("weapon_id", "")) == weapon_id:
				return (raw_weapon as Dictionary).duplicate(true)
	return {}


static func _resource_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	return "res://%s" % path if not path.is_empty() else ""


static func _pivot(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return {"x": float((raw as Dictionary).get("x", 0.5)), "y": float((raw as Dictionary).get("y", 0.5))}
	if raw is Array and (raw as Array).size() == 2:
		return {"x": float((raw as Array)[0]), "y": float((raw as Array)[1])}
	return {"x": 0.5, "y": 0.5}


static func _timing(raw: Dictionary) -> Dictionary:
	var result := {}
	var previous := -1.0
	for phase in ["windup", "release", "active", "recovery", "cancel"]:
		var value: Variant = raw.get(phase)
		if not (value is int or value is float) or value is bool or not is_finite(float(value)) \
				or float(value) < previous or float(value) > 10.0:
			return {}
		result[phase] = float(value)
		previous = float(value)
	return result
