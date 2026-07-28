class_name RangerUltimatePresentationPack
extends RefCounted

## Class-local presentation data for the three Ranger weapon ultimates.
##
## It deliberately reuses the accepted weapon VFX instead of creating new
## raster art. The shared presentation registry remains untouched; FAN-1541
## owns the future runtime adapter that selects this scene package.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const CLASS_ID := "ranger"
const ASSET_DIRECTORY := "res://assets/sprites/effects/"
const SFX_DIRECTORY := "res://assets/audio/sfx/"

const MOON_CROSSBOW := "moon_crossbow"
const STORM_LONGBOW := "storm_longbow"
const HUNTER_TRAP := "hunter_trap"

const WEAPON_IDS: Array[String] = [MOON_CROSSBOW, STORM_LONGBOW, HUNTER_TRAP]
const MAX_ELEMENTS_PER_ULTIMATE := 8

## The three rhythms, silhouettes, and motion paths are intentionally unlike:
## targeted split bolts, a long sequential storm corridor, and inward-closing
## trap jaws. This is presentation only; no targeting or combat numbers live
## here.
const WEAPONS := {
	MOON_CROSSBOW: {
		"title": "Лунная Охота",
		"asset_source": "res://docs/design/references/weapon_attack_animations/moon_crossbow/vfx_source_1024.png",
		"asset_runtime": "%svfx_weapon_moon_crossbow.png" % ASSET_DIRECTORY,
		"sfx_file": "sfx_hit_magic.ogg",
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {
			"windup": 0.0,
			"release": 0.60,
			"active": 1.15,
			"recovery": 4.15,
			"cancel": 4.80,
		},
		"formation": {"kind": "moon_mark_split", "count": 5, "radius": 132.0},
		"silhouette": "silver crescent mark, focused bolt, and four split bolts",
		"motion": "the mark blooms above prey, one bolt reaches it, then four bolts split diagonally and rejoin",
		"impact": "moon-mark flash followed by a four-way silver split",
	},
	STORM_LONGBOW: {
		"title": "Глаз Бури",
		"asset_source": "res://docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/storm_longbow_pixellab_source.png",
		"asset_runtime": "%svfx_weapon_storm_longbow.png" % ASSET_DIRECTORY,
		"sfx_file": "sfx_boss_phase.ogg",
		"pivot": {"x": 0.10, "y": 0.50},
		"timing": {
			"windup": 0.0,
			"release": 0.38,
			"active": 0.72,
			"recovery": 3.90,
			"cancel": 4.45,
		},
		"formation": {"kind": "storm_corridor", "count": 7, "radius": 242.0},
		"silhouette": "one long storm arrow corridor with tail-to-tip lightning beats",
		"motion": "a charged arrow draws a horizontal safe axis, then lightning walks from tail to tip",
		"impact": "sequential electric corridor strikes that push away from the axis",
	},
	HUNTER_TRAP: {
		"title": "Великая Западня",
		"asset_source": "res://docs/design/references/weapon_attack_animations/hunter_trap/vfx_weapon_hunter_trap_source.png",
		"asset_runtime": "%svfx_weapon_hunter_trap.png" % ASSET_DIRECTORY,
		"sfx_file": "sfx_hit_dot.ogg",
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {
			"windup": 0.0,
			"release": 0.92,
			"active": 1.45,
			"recovery": 4.85,
			"cancel": 5.35,
		},
		"formation": {"kind": "three_ring_traps", "count": 3, "radius": 172.0},
		"silhouette": "three heavy spectral trap rings with inward-facing jaws",
		"motion": "three edge sigils close toward the center in staggered jaw-lock rings",
		"impact": "green-blue jaw snap, chain net closure, and a fading bleed rune",
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
	var config := weapon_config(weapon_id)
	var formation: Dictionary = config.get("formation", {})
	match str(formation.get("kind", "")):
		"moon_mark_split":
			return _moon_mark_split(progress, phase_name, int(formation.get("count", 0)))
		"storm_corridor":
			return _storm_corridor(progress, phase_name, int(formation.get("count", 0)))
		"three_ring_traps":
			return _three_ring_traps(progress, phase_name, int(formation.get("count", 0)))
	return []


static func _moon_mark_split(progress: float, phase_name: String, count: int) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var mark := Vector2(92.0, -46.0)
	for index in count:
		var angle := TAU * float(index) / float(maxi(count - 1, 1))
		var position := mark
		var scale := 0.42
		var alpha := 0.0
		if phase_name == "windup":
			position += Vector2(cos(angle + progress * 1.5), sin(angle + progress * 1.5)) * (18.0 + progress * 28.0)
			scale = 0.24 + progress * 0.14
			alpha = 0.22 + progress * 0.45
		elif phase_name == "release":
			if index == 0:
				position = Vector2(-168.0, 64.0).lerp(mark, progress)
				alpha = 0.92
			else:
				var split := clampf((progress - 0.52) * 2.1, 0.0, 1.0)
				position = mark.lerp(mark + Vector2(cos(angle), sin(angle)) * 84.0, split)
				alpha = split * 0.88
			scale = 0.38 + progress * 0.12
		elif phase_name == "active":
			var radius := 42.0 + sin(progress * PI) * 38.0
			position = mark if index == 0 else mark + Vector2(cos(angle + progress * 2.0), sin(angle + progress * 2.0)) * radius
			scale = 0.46 + (0.10 if index == 0 else 0.0)
			alpha = 0.84 - progress * 0.18
		elif phase_name == "recovery":
			position = mark + Vector2(cos(angle), sin(angle)) * (46.0 * (1.0 - progress))
			scale = 0.40 - progress * 0.16
			alpha = 0.62 * (1.0 - progress)
		else:
			position = mark
			scale = 0.20 * (1.0 - progress)
			alpha = 0.32 * (1.0 - progress)
		points.append({"position": position, "scale": scale, "alpha": alpha, "rotation": angle})
	return points


static func _storm_corridor(progress: float, phase_name: String, count: int) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var lane := float(index) - float(count - 1) * 0.5
		var x := -202.0 + float(index) * 66.0
		var y := lane * 13.0
		var scale := 0.34
		var alpha := 0.0
		if phase_name == "windup":
			x = -86.0 + lane * 10.0
			y = lane * (9.0 + progress * 7.0)
			scale = 0.26 + progress * 0.10
			alpha = 0.18 + progress * 0.32
		elif phase_name == "release":
			var launch := clampf(progress * 1.45 - float(index) * 0.10, 0.0, 1.0)
			x = lerpf(-150.0, 228.0, launch)
			y += sin(progress * PI + lane) * 12.0
			scale = 0.34 + launch * 0.16
			alpha = 0.50 + launch * 0.38
		elif phase_name == "active":
			var beat := clampf(1.0 - absf(progress * float(count - 1) - float(index)) * 0.9, 0.20, 1.0)
			x += progress * 18.0
			y += sin(progress * TAU + lane) * 24.0
			scale = 0.30 + beat * 0.22
			alpha = 0.26 + beat * 0.68
		elif phase_name == "recovery":
			x += progress * 54.0
			y *= 1.0 - progress * 0.55
			scale = 0.42 - progress * 0.20
			alpha = (1.0 - progress) * (0.74 - float(index) * 0.04)
		else:
			x = 214.0 + lane * 5.0
			y *= 0.18
			scale = 0.20 * (1.0 - progress)
			alpha = 0.22 * (1.0 - progress)
		points.append({"position": Vector2(x, y), "scale": scale, "alpha": alpha, "rotation": 0.0})
	return points


static func _three_ring_traps(progress: float, phase_name: String, count: int) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var angle := -PI * 0.5 + TAU * float(index) / float(maxi(count, 1))
		var radius := 150.0
		var scale := 0.42
		var alpha := 0.0
		if phase_name == "windup":
			radius = 158.0 + sin(progress * PI + float(index)) * 14.0
			scale = 0.28 + progress * 0.10
			alpha = 0.22 + progress * 0.34
		elif phase_name == "release":
			radius = lerpf(164.0, 88.0, progress)
			scale = 0.38 + progress * 0.12
			alpha = 0.72 + progress * 0.18
		elif phase_name == "active":
			radius = lerpf(88.0, 26.0, progress)
			scale = 0.50 + sin(progress * PI) * 0.18
			alpha = 0.94 - progress * 0.18
		elif phase_name == "recovery":
			radius = 26.0 + progress * 38.0
			scale = 0.52 - progress * 0.22
			alpha = 0.66 * (1.0 - progress)
		else:
			radius = 64.0 + progress * 32.0
			scale = 0.24 * (1.0 - progress)
			alpha = 0.28 * (1.0 - progress)
		points.append({
			"position": Vector2(cos(angle), sin(angle)) * radius,
			"scale": scale,
			"alpha": alpha,
			"rotation": angle + PI * 0.5,
		})
	return points
