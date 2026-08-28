class_name DoctorUltimatePresentationPack
extends RefCounted

## Class-local data for the three Doctor weapon-ultimate presentations.
## Gameplay, balance, shared registries, and the future runtime adapter remain
## outside this package.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const CLASS_ID := "doctor"
const RESTORE_POTION := "restore_potion"
const PLAGUE_SYRINGE := "plague_syringe"
const BONE_SAW := "bone_saw"
const WEAPON_IDS: Array[String] = [RESTORE_POTION, PLAGUE_SYRINGE, BONE_SAW]
const MAX_VISUAL_NODES := 12

const WEAPONS := {
	RESTORE_POTION: {
		"title": "Эликсир Жизни и Смерти",
		"source_path": "res://docs/design/references/weapon_attack_animations/restore_potion/vfx_source_1024.png",
		"runtime_path": "res://assets/sprites/effects/vfx_weapon_restore_potion.png",
		"weapon_path": "res://assets/sprites/weapons/restore_potion.png",
		"sfx_path": "res://assets/audio/sfx/sfx_hit_magic.ogg",
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {"windup": 0.0, "release": 0.85, "active": 1.35, "recovery": 2.85, "cancel": 3.40},
		"capture_time": 2.10,
		"formation": "aimed_flask_dual_zone",
		"silhouette": "giant overhead flask, wide poison pool, tight white healing spiral, and offset shield crystal",
		"motion": "the flask follows a high aimed arc, shatters at range, then the outer and inner zones counter-rotate",
		"impact": "green glass blast and poison ring resolve inward as a white healing spiral and crystallized absorb shield",
		"max_visual_nodes": 5,
	},
	PLAGUE_SYRINGE: {
		"title": "Чёрная Эпидемия",
		"source_path": "res://docs/design/references/weapon_attack_animations/plague_syringe/vfx_source_1024.png",
		"runtime_path": "res://assets/sprites/effects/vfx_weapon_plague_syringe.png",
		"weapon_path": "res://assets/sprites/weapons/plague_syringe.png",
		"sfx_path": "res://assets/audio/sfx/sfx_hit_dot.ogg",
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {"windup": 0.0, "release": 0.75, "active": 1.20, "recovery": 3.30, "cancel": 3.90},
		"capture_time": 2.60,
		"formation": "patient_zero_plague_waves",
		"silhouette": "oversized diagonal syringe, pinned patient-zero mark, branching veins, three arena waves, and mask vapor",
		"motion": "the syringe pierces one target before staggered infection waves expand through the arena",
		"impact": "black-green vascular bloom ticks outward and ends in a sharp plague-mask vapor burst",
		"max_visual_nodes": 8,
	},
	BONE_SAW: {
		"title": "Экстренная Операция",
		"source_path": "res://docs/design/references/weapon_attack_animations/bone_saw/vfx_weapon_bone_saw_source.png",
		"runtime_path": "res://assets/sprites/effects/vfx_weapon_bone_saw.png",
		"weapon_path": "res://assets/sprites/weapons/bone_saw.png",
		"sfx_path": "res://assets/audio/sfx/sfx_hit.ogg",
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {"windup": 0.0, "release": 0.65, "active": 1.05, "recovery": 2.35, "cancel": 2.80},
		"capture_time": 1.70,
		"formation": "close_orbit_surgery",
		"silhouette": "three close-orbit saws, bright surgical arc, metal sparks, paired drain ribbons, and stitched shield seam",
		"motion": "the saws snap from a surgical stance into a fast close orbit while vitality ribbons pull inward",
		"impact": "bone-white serration and sparks cut repeatedly before red drain ribbons turn green and stitch shut",
		"max_visual_nodes": 8,
	},
}

const PHASE_BINDINGS: Array[Array] = [
	["windup", "windup"],
	["release", "execute"],
	["active", "active"],
	["recovery", "recover"],
	["cancel", "cleanup"],
]


static func weapon_config(weapon_id: String) -> Dictionary:
	var config = WEAPONS.get(weapon_id, {})
	return (config as Dictionary).duplicate(true) if config is Dictionary else {}


static func timeline_seconds(weapon_id: String) -> float:
	return float((weapon_config(weapon_id).get("timing", {}) as Dictionary).get("cancel", 0.0))


static func phase_at(weapon_id: String, elapsed: float) -> Dictionary:
	var timing: Dictionary = weapon_config(weapon_id).get("timing", {})
	var current := "windup"
	var start := 0.0
	var end := timeline_seconds(weapon_id)
	for index in PHASE_BINDINGS.size():
		var name := str(PHASE_BINDINGS[index][0])
		var timestamp := float(timing.get(name, INF))
		if elapsed >= timestamp:
			current = name
			start = timestamp
			if index + 1 < PHASE_BINDINGS.size():
				end = float(timing.get(str(PHASE_BINDINGS[index + 1][0]), end))
	return {
		"name": current,
		"progress": clampf((elapsed - start) / maxf(end - start, 0.0001), 0.0, 1.0),
	}


static func manifest_for(registry, weapon_id: String) -> Dictionary:
	var config := weapon_config(weapon_id)
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	if config.is_empty() or profile.is_empty():
		return {}
	var presentation: Dictionary = profile.get("presentation", {})
	var cast_phases: Dictionary = profile.get("cast_phases", {})
	var phases: Array[Dictionary] = []
	for binding in PHASE_BINDINGS:
		phases.append({
			"name": str(binding[0]),
			"phase_id": str(cast_phases.get(str(binding[1]), "")),
		})
	var source_path := str(config.get("source_path", ""))
	var runtime_path := str(config.get("runtime_path", ""))
	var sfx_path := str(config.get("sfx_path", ""))
	return {
		"schema_version": Schema.EXPECTED_SCHEMA_VERSION,
		"class_id": CLASS_ID,
		"key": {"weapon_id": weapon_id, "action": Schema.ACTION_ULTIMATE},
		"presentation_id": str(presentation.get("presentation_id", "")),
		"animation": {"id": str(presentation.get("animation_id", "")), "source_path": source_path, "runtime_path": runtime_path},
		"vfx": {"id": str(presentation.get("vfx_id", "")), "source_path": source_path, "runtime_path": runtime_path},
		"sfx": {"id": str(presentation.get("sfx_id", "")), "source_path": sfx_path, "runtime_path": sfx_path},
		"phases": phases,
		"pivot": (config.get("pivot", {}) as Dictionary).duplicate(),
		"timing": (config.get("timing", {}) as Dictionary).duplicate(),
		"headless_fallback": "no_op",
	}


static func manifests(registry) -> Dictionary:
	var result := {}
	for weapon_id in WEAPON_IDS:
		result[weapon_id] = manifest_for(registry, weapon_id)
	return result


static func expected_profiles(registry) -> Dictionary:
	var result := {}
	for weapon_id in WEAPON_IDS:
		var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
		if not profile.is_empty():
			result[Schema.profile_key(CLASS_ID, weapon_id)] = profile
	return result
