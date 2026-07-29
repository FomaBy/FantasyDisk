class_name RobotUltimatePresentationPack
extends RefCounted

## Class-local presentation data for Robot's three weapon ultimates.
##
## This package deliberately reuses the accepted Robot weapon VFX. It owns
## only animation timing and motion; mechanics and the shared runtime adapter
## remain outside this isolated presentation package.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const CLASS_ID := "robot"
const SFX_DIRECTORY := "res://assets/audio/sfx/"

const MAGNETIC_ANCHOR := "robot_magnetic_anchor"
const HYDRAULIC_PRESS := "robot_hydraulic_press"
const REACTOR_CORE := "robot_reactor_core"

const WEAPON_IDS: Array[String] = [MAGNETIC_ANCHOR, HYDRAULIC_PRESS, REACTOR_CORE]
const MAX_ELEMENTS_PER_ULTIMATE := 8

## These three motions must remain mechanically distinct: a radial implosion,
## a two-wall corridor crush, and rotating exhaust vents. No balance values or
## targeting decisions are declared here.
const WEAPONS := {
	MAGNETIC_ANCHOR: {
		"title": "Сингулярный Якорь",
		"asset_source": "res://docs/design/references/weapon_attack_animations/robot_magnetic_anchor/robot_magnetic_anchor_pixellab_source.png",
		"asset_runtime": "res://assets/sprites/effects/vfx_weapon_robot_magnetic_anchor.png",
		"sfx_file": "sfx_hit_magic.ogg",
		"tint": Color(0.58, 0.88, 1.0),
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {"windup": 0.0, "release": 0.45, "active": 1.05, "recovery": 4.25, "cancel": 4.75},
		"formation": {"kind": "implosion_well", "count": 8, "radius": 166.0},
		"silhouette": "one black-point anchor with eight inward-pulled cyan debris arcs",
		"motion": "concentric debris contracts into an aimed singularity, then expands as a cyan EMP ring",
		"impact": "black-point implosion followed by a single outward EMP release",
	},
	HYDRAULIC_PRESS: {
		"title": "Протокол Сжатия",
		"asset_source": "res://docs/design/references/weapon_attack_animations/robot_hydraulic_press/robot_hydraulic_press_pixellab_source.png",
		"asset_runtime": "res://assets/sprites/effects/vfx_weapon_robot_hydraulic_press.png",
		"sfx_file": "sfx_hit.ogg",
		"tint": Color(0.96, 0.76, 0.46),
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {"windup": 0.0, "release": 0.72, "active": 1.32, "recovery": 3.48, "cancel": 4.05},
		"formation": {"kind": "press_walls", "count": 2, "radius": 238.0},
		"silhouette": "two colossal steel press walls framing a narrow horizontal danger corridor",
		"motion": "warning rails hold wide, walls slam together in repeated compression beats, then recoil",
		"impact": "opposing steel crush with sparks followed by an explosive hydraulic release",
	},
	REACTOR_CORE: {
		"title": "Красная Зона",
		"asset_source": "res://docs/design/references/weapon_attack_animations/robot_reactor_core/robot_reactor_core_pixellab_source.png",
		"asset_runtime": "res://assets/sprites/effects/vfx_weapon_robot_reactor_core.png",
		"sfx_file": "sfx_boss_phase.ogg",
		"tint": Color(1.0, 0.36, 0.18),
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {"windup": 0.0, "release": 0.56, "active": 1.08, "recovery": 5.42, "cancel": 6.02},
		"formation": {"kind": "plasma_vents", "count": 8, "radius": 104.0},
		"silhouette": "eight red-orange reactor vents orbiting an exposed white-hot core",
		"motion": "vents unfold in a wheel, accelerate around the core, then lift as a cooling steam column",
		"impact": "accelerating plasma vent wave ending in a white-hot vertical exhaust",
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


static func element_source_path(weapon_id: String) -> String:
	return str(weapon_config(weapon_id).get("asset_source", ""))


static func element_runtime_path(weapon_id: String) -> String:
	return str(weapon_config(weapon_id).get("asset_runtime", ""))


static func manifest_for(registry, weapon_id: String) -> Dictionary:
	var config := weapon_config(weapon_id)
	if config.is_empty():
		return {}
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	if profile.is_empty():
		return {}
	var presentation: Dictionary = profile.get("presentation", {})
	var cast_phases: Dictionary = profile.get("cast_phases", {})
	var phases: Array[Dictionary] = []
	for binding in PHASE_BINDINGS:
		phases.append({
			"name": str(binding[0]),
			"phase_id": str(cast_phases.get(str(binding[1]), "")),
		})
	var source_path := element_source_path(weapon_id)
	var runtime_path := element_runtime_path(weapon_id)
	var sfx_path := "%s%s" % [SFX_DIRECTORY, str(config.get("sfx_file", ""))]
	return {
		"schema_version": Schema.EXPECTED_SCHEMA_VERSION,
		"class_id": CLASS_ID,
		"key": {"weapon_id": weapon_id, "action": Schema.ACTION_ULTIMATE},
		"presentation_id": str(presentation.get("presentation_id", "")),
		"animation": {
			"id": str(presentation.get("animation_id", "")),
			"source_path": source_path,
			"runtime_path": runtime_path,
		},
		"vfx": {
			"id": str(presentation.get("vfx_id", "")),
			"source_path": source_path,
			"runtime_path": runtime_path,
		},
		"sfx": {
			"id": str(presentation.get("sfx_id", "")),
			"source_path": sfx_path,
			"runtime_path": sfx_path,
		},
		"phases": phases,
		"pivot": (config.get("pivot", {}) as Dictionary).duplicate(),
		"timing": (config.get("timing", {}) as Dictionary).duplicate(),
		"headless_fallback": "no_op",
	}


static func manifests(registry) -> Dictionary:
	var result := {}
	for weapon_id in WEAPON_IDS:
		var manifest := manifest_for(registry, weapon_id)
		if not manifest.is_empty():
			result[weapon_id] = manifest
	return result


static func expected_profiles(registry) -> Dictionary:
	var profiles := {}
	for weapon_id in WEAPON_IDS:
		var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
		if not profile.is_empty():
			profiles[Schema.profile_key(CLASS_ID, weapon_id)] = profile
	return profiles


static func timeline_seconds(weapon_id: String) -> float:
	var timing: Dictionary = weapon_config(weapon_id).get("timing", {})
	var longest := 0.0
	for value in timing.values():
		longest = maxf(longest, float(value))
	return longest


static func phase_at(weapon_id: String, elapsed: float) -> Dictionary:
	var timing: Dictionary = weapon_config(weapon_id).get("timing", {})
	var current := ""
	var started := 0.0
	var ends := timeline_seconds(weapon_id)
	for binding in PHASE_BINDINGS:
		var name := str(binding[0])
		var start := float(timing.get(name, -1.0))
		if elapsed >= start and start >= started:
			current = name
			started = start
	for binding in PHASE_BINDINGS:
		var next_start := float(timing.get(str(binding[0]), -1.0))
		if next_start > started:
			ends = minf(ends, next_start)
	var span := maxf(ends - started, 0.0001)
	return {"name": current, "progress": clampf((elapsed - started) / span, 0.0, 1.0)}


static func formation_points(weapon_id: String, phase_name: String, progress: float) -> Array[Dictionary]:
	var formation: Dictionary = weapon_config(weapon_id).get("formation", {})
	var count := int(formation.get("count", 0))
	var radius := float(formation.get("radius", 0.0))
	match str(formation.get("kind", "")):
		"implosion_well":
			return _implosion_well(progress, phase_name, count, radius)
		"press_walls":
			return _press_walls(progress, phase_name, count, radius)
		"plasma_vents":
			return _plasma_vents(progress, phase_name, count, radius)
	return []


static func _implosion_well(progress: float, phase_name: String, count: int, radius: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var angle := TAU * float(index) / float(maxi(count, 1)) - PI * 0.5
		var distance := radius
		var scale := 0.30
		var alpha := 0.0
		var rotation := angle + PI * 0.5
		match phase_name:
			"windup":
				distance = radius * (0.78 + progress * 0.22)
				scale = 0.22 + progress * 0.12
				alpha = 0.20 + progress * 0.30
			"release":
				distance = lerpf(radius, 66.0, progress)
				scale = 0.34 + progress * 0.18
				alpha = 0.58 + progress * 0.32
				rotation += progress * PI
			"active":
				distance = lerpf(66.0, 4.0, progress)
				scale = 0.52 + (1.0 - progress) * 0.18
				alpha = 0.95 - progress * 0.18
				rotation += progress * TAU * 1.5
			"recovery":
				distance = lerpf(12.0, radius * 1.18, progress)
				scale = 0.46 - progress * 0.16
				alpha = 0.78 * (1.0 - progress)
				rotation += progress * TAU
			"cancel":
				distance = radius * (1.0 + progress * 0.25)
				scale = 0.22 * (1.0 - progress)
				alpha = 0.35 * (1.0 - progress)
		points.append({"position": Vector2(cos(angle), sin(angle)) * distance, "scale": scale, "alpha": alpha, "rotation": rotation})
	return points


static func _press_walls(progress: float, phase_name: String, count: int, radius: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var side := -1.0 if index == 0 else 1.0
		var distance := radius
		var scale := 0.74
		var alpha := 0.0
		match phase_name:
			"windup":
				distance = radius * (1.0 - progress * 0.12)
				scale = 0.62 + progress * 0.10
				alpha = 0.28 + progress * 0.32
			"release":
				distance = lerpf(radius * 0.88, 48.0, ease(progress, 0.45))
				scale = 0.72 + progress * 0.18
				alpha = 0.72 + progress * 0.24
			"active":
				var crush := absf(sin(progress * PI * 3.0))
				distance = lerpf(36.0, 94.0, crush)
				scale = 0.90 + crush * 0.18
				alpha = 0.94 - progress * 0.12
			"recovery":
				distance = lerpf(46.0, radius * 1.05, progress)
				scale = 0.86 - progress * 0.28
				alpha = 0.76 * (1.0 - progress)
			"cancel":
				distance = radius * (1.0 + progress * 0.10)
				scale = 0.42 * (1.0 - progress)
				alpha = 0.35 * (1.0 - progress)
		points.append({"position": Vector2(side * distance, 0.0), "scale": scale, "alpha": alpha, "rotation": 0.0 if index == 0 else PI})
	return points


static func _plasma_vents(progress: float, phase_name: String, count: int, radius: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var base_angle := TAU * float(index) / float(maxi(count, 1)) - PI * 0.5
		var angle := base_angle
		var distance := radius
		var rise := 0.0
		var scale := 0.26
		var alpha := 0.0
		match phase_name:
			"windup":
				distance = 18.0 + progress * 22.0
				scale = 0.20 + progress * 0.10
				alpha = 0.18 + progress * 0.28
			"release":
				distance = lerpf(34.0, radius, ease(progress, 0.55))
				angle += progress * PI
				scale = 0.32 + progress * 0.18
				alpha = 0.58 + progress * 0.30
			"active":
				angle += progress * TAU * 3.0
				distance = radius + sin(progress * TAU * 2.0 + float(index)) * 18.0
				scale = 0.48 + absf(sin(progress * PI * 4.0 + float(index))) * 0.20
				alpha = 0.88 + sin(progress * TAU + float(index)) * 0.08
			"recovery":
				angle += progress * TAU * 0.75
				distance = lerpf(radius, 42.0, progress)
				rise = -progress * 180.0
				scale = 0.58 - progress * 0.22
				alpha = 0.82 * (1.0 - progress)
			"cancel":
				distance = radius * (1.0 - progress * 0.5)
				rise = -progress * 44.0
				scale = 0.28 * (1.0 - progress)
				alpha = 0.30 * (1.0 - progress)
		points.append({
			"position": Vector2(cos(angle), sin(angle)) * distance + Vector2(0.0, rise),
			"scale": scale,
			"alpha": alpha,
			"rotation": angle + PI * 0.5,
		})
	return points
