class_name WeaponUltimatePresentationManifest
extends RefCounted

## Deterministic bridge from immutable weapon profile IDs to presentation data.
##
## The bridge intentionally supplies no gameplay strategy, scene instantiation,
## or pool ownership. Class packages can replace the reviewed source/runtime
## paths later, while FAN-1541 owns the shared runtime adapter.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const DEFAULT_SFX_PATH := "res://assets/audio/sfx/sfx_hit_magic.ogg"
const VFX_SOURCE_PREFIX := "res://assets/sprites/effects/vfx_weapon_"
const VFX_SOURCE_SUFFIX := ".png"


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
	var presentation: Dictionary = profile.get("presentation", {})
	var cast_phases: Dictionary = profile.get("cast_phases", {})
	var vfx_path := "%s%s%s" % [VFX_SOURCE_PREFIX, weapon_id, VFX_SOURCE_SUFFIX]
	return {
		"schema_version": Schema.EXPECTED_SCHEMA_VERSION,
		"class_id": class_id,
		"key": {
			"weapon_id": weapon_id,
			"action": Schema.ACTION_ULTIMATE,
		},
		"presentation_id": str(presentation.get("presentation_id", "")),
		"animation": _asset(str(presentation.get("animation_id", "")), vfx_path),
		"vfx": _asset(str(presentation.get("vfx_id", "")), vfx_path),
		"sfx": _asset(str(presentation.get("sfx_id", "")), DEFAULT_SFX_PATH),
		"phases": [
			{"name": "windup", "phase_id": str(cast_phases.get("windup", ""))},
			{"name": "release", "phase_id": str(cast_phases.get("execute", ""))},
			{"name": "active", "phase_id": str(cast_phases.get("active", ""))},
			{"name": "recovery", "phase_id": str(cast_phases.get("recover", ""))},
			{"name": "cancel", "phase_id": str(cast_phases.get("cleanup", ""))},
		],
		"pivot": {"x": 0.5, "y": 0.5},
		"timing": {
			"windup": 0.0,
			"release": 0.12,
			"active": 0.20,
			"recovery": 0.45,
			"cancel": 0.45,
		},
		"headless_fallback": "no_op",
	}


static func _asset(id: String, path: String) -> Dictionary:
	return {
		"id": id,
		"source_path": path,
		"runtime_path": path,
	}
