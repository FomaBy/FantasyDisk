class_name ThiefUltimatePresentationPack
extends RefCounted

## Class-local presentation data for the three Thief weapon ultimates.
## It reads frozen IDs from the registry and deliberately leaves the shared
## presentation bridge untouched; FAN-1541 owns that runtime integration.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const CLASS_ID := "thief"
const ACCEPTED_VFX_PREFIX := "res://assets/sprites/effects/vfx_weapon_"
const ACCEPTED_VFX_SUFFIX := ".png"
const SFX_DIRECTORY := "res://assets/audio/sfx/"

const COIN_POUCH := "thief_coin_pouch"
const SHADOW_CLOAK := "thief_shadow_cloak"
const SMOKE_BOMB := "thief_smoke_bomb"
const WEAPON_IDS: Array[String] = [COIN_POUCH, SHADOW_CLOAK, SMOKE_BOMB]

## One ultimate never emits more than 13 class-local sprites.
const MAX_ELEMENTS_PER_ULTIMATE := 13

const WEAPONS := {
	COIN_POUCH: {
		"title": "Джекпот Короля",
		"sfx_file": "sfx_pickup_money.ogg",
		"pivot": {"x": 0.5, "y": 0.5},
		"timing": {"windup": 0.0, "release": 0.70, "active": 1.10, "recovery": 2.30, "cancel": 3.05},
		"formation": {"kind": "coin_ricochet", "count": 13, "radius": 118.0},
		"silhouette": "gold coin burst with a small leather pouch",
		"motion": "thirteen staggered coins zig-zag across unique target glints, then return in a crown burst",
		"impact": "bright gold ricochet glints with a final inward jackpot",
	},
	SHADOW_CLOAK: {
		"title": "Безмолвный Приговор",
		"sfx_file": "sfx_hit_magic.ogg",
		"pivot": {"x": 0.5, "y": 0.5},
		"timing": {"windup": 0.0, "release": 0.82, "active": 1.22, "recovery": 2.57, "cancel": 3.20},
		"formation": {"kind": "shadow_stab_chain", "count": 8, "radius": 106.0},
		"silhouette": "violet cloak crescent with a dagger-eye sweep",
		"motion": "eight marked targets receive sequential phantom backstabs along a tightening ellipse",
		"impact": "staggered violet slash arrivals followed by one red-line collapse",
	},
	SMOKE_BOMB: {
		"title": "Идеальное Ограбление",
		"sfx_file": "sfx_dodge.ogg",
		"pivot": {"x": 0.5, "y": 0.5},
		"timing": {"windup": 0.0, "release": 0.94, "active": 1.34, "recovery": 2.84, "cancel": 3.42},
		"formation": {"kind": "smoke_dome", "count": 7, "radius": 112.0},
		"silhouette": "blue-grey smoke dome with violet pressure motes",
		"motion": "a central dome expands around the hero while six outlined pressure marks drift at its edge",
		"impact": "the full dome snap-collapses into an outward pressure burst",
	},
}

const PHASE_BINDINGS: Array[Array] = [
	["windup", "windup"], ["release", "execute"], ["active", "active"],
	["recovery", "recover"], ["cancel", "cleanup"],
]


static func weapon_config(weapon_id: String) -> Dictionary:
	var config = WEAPONS.get(weapon_id, {})
	return (config as Dictionary).duplicate(true) if config is Dictionary else {}


static func asset_path(weapon_id: String) -> String:
	return "%s%s%s" % [ACCEPTED_VFX_PREFIX, weapon_id, ACCEPTED_VFX_SUFFIX]


static func manifest_for(registry, weapon_id: String) -> Dictionary:
	var config := weapon_config(weapon_id)
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	if config.is_empty() or profile.is_empty():
		return {}
	var presentation: Dictionary = profile.get("presentation", {})
	var cast_phases: Dictionary = profile.get("cast_phases", {})
	var path := asset_path(weapon_id)
	var phases: Array[Dictionary] = []
	for binding in PHASE_BINDINGS:
		phases.append({"name": str(binding[0]), "phase_id": str(cast_phases.get(str(binding[1]), ""))})
	return {
		"schema_version": Schema.EXPECTED_SCHEMA_VERSION,
		"class_id": CLASS_ID,
		"key": {"weapon_id": weapon_id, "action": Schema.ACTION_ULTIMATE},
		"presentation_id": str(presentation.get("presentation_id", "")),
		"animation": {"id": str(presentation.get("animation_id", "")), "source_path": path, "runtime_path": path},
		"vfx": {"id": str(presentation.get("vfx_id", "")), "source_path": path, "runtime_path": path},
		"sfx": {
			"id": str(presentation.get("sfx_id", "")),
			"source_path": "%s%s" % [SFX_DIRECTORY, str(config.get("sfx_file", ""))],
			"runtime_path": "%s%s" % [SFX_DIRECTORY, str(config.get("sfx_file", ""))],
		},
		"phases": phases,
		"pivot": config.get("pivot", {}).duplicate(),
		"timing": config.get("timing", {}).duplicate(),
		"headless_fallback": "no_op",
		"presence": {"fullscreen_footprint": true, "backdrop": "darken", "camera_shake": true, "hitstop_ms": 100.0, "time_scale_dip": 0.4, "sfx_ducking": true},
		"identity": {"cast_pose_id": "thief_ultimate_crouched_toss", "weapon_silhouette_asset": path, "class_palette_id": "thief_gold_violet_smoke"},
	}


static func manifests(registry) -> Dictionary:
	var result := {}
	for weapon_id in WEAPON_IDS:
		result[weapon_id] = manifest_for(registry, weapon_id)
	return result


static func expected_profiles(registry) -> Dictionary:
	var profiles := {}
	for weapon_id in WEAPON_IDS:
		var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
		profiles[Schema.profile_key(CLASS_ID, weapon_id)] = profile
	return profiles


static func timeline_seconds(weapon_id: String) -> float:
	var longest := 0.0
	for value in (weapon_config(weapon_id).get("timing", {}) as Dictionary).values():
		longest = maxf(longest, float(value))
	return longest


static func phase_at(weapon_id: String, elapsed: float) -> Dictionary:
	var timing: Dictionary = weapon_config(weapon_id).get("timing", {})
	var current := "windup"
	var started := 0.0
	var ends := timeline_seconds(weapon_id)
	for binding in PHASE_BINDINGS:
		var name := str(binding[0])
		var start := float(timing.get(name, -1.0))
		if elapsed >= start and start >= started:
			current = name
			started = start
	for binding in PHASE_BINDINGS:
		var start := float(timing.get(str(binding[0]), -1.0))
		if start > started:
			ends = minf(ends, start)
	return {"name": current, "progress": clampf((elapsed - started) / maxf(ends - started, 0.0001), 0.0, 1.0)}


static func formation_points(weapon_id: String, phase_name: String, progress: float) -> Array[Dictionary]:
	var formation: Dictionary = weapon_config(weapon_id).get("formation", {})
	var count := int(formation.get("count", 0))
	var radius := float(formation.get("radius", 0.0))
	match str(formation.get("kind", "")):
		"coin_ricochet": return _coin_ricochet(count, radius, phase_name, progress)
		"shadow_stab_chain": return _shadow_stab_chain(count, radius, phase_name, progress)
		"smoke_dome": return _smoke_dome(count, radius, phase_name, progress)
	return []


static func _coin_ricochet(count: int, radius: float, phase_name: String, progress: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var target := _coin_target(index, radius)
		var seed := Vector2(cos(float(index) * 2.4), sin(float(index) * 1.7) * 0.55) * 18.0
		var position := target
		var scale := 0.36
		var alpha := 1.0
		var rotation := float(index) * 0.35
		match phase_name:
			"windup":
				position = seed
				scale = lerpf(0.12, 0.22, progress)
				alpha = lerpf(0.12, 0.42, progress)
			"release":
				position = seed.lerp(target * 0.35, ease(progress, 0.45))
				scale = lerpf(0.22, 0.30, progress)
			"active":
				var hop := clampf(progress * 1.35 - float(index % 4) * 0.10, 0.0, 1.0)
				position = seed.lerp(target, hop)
				scale = 0.30 + absf(sin((progress * 5.0 + float(index) * 0.3) * PI)) * 0.10
			"recovery":
				position = target.lerp(Vector2(0.0, -radius * 0.34), ease(progress, 0.55))
				scale = lerpf(0.34, 0.62, progress)
				alpha = lerpf(1.0, 0.42, progress)
			"cancel":
				position = target.lerp(Vector2(0.0, -radius * 0.9), progress)
				scale = lerpf(0.30, 0.08, progress)
				alpha = lerpf(0.72, 0.0, progress)
		points.append(_point(position, scale, alpha, rotation))
	return points


static func _coin_target(index: int, radius: float) -> Vector2:
	return Vector2(
		-radius + fposmod(float(index) * radius * 0.78, radius * 2.0),
		sin(float(index) * 2.21) * radius * 0.58
	)


static func _shadow_stab_chain(count: int, radius: float, phase_name: String, progress: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var angle := TAU * float(index) / float(maxi(count, 1)) - PI * 0.5
		var target := Vector2(cos(angle) * radius, sin(angle) * radius * 0.58)
		var position := target
		var scale := 0.34
		var alpha := 1.0
		var rotation := angle + PI * 0.5
		match phase_name:
			"windup":
				position = target * lerpf(0.04, 0.22, progress)
				scale = lerpf(0.10, 0.22, progress)
				alpha = lerpf(0.08, 0.28, progress)
			"release":
				var mark := clampf(progress * 1.65 - float(index) * 0.12, 0.0, 1.0)
				position = target * mark
				scale = lerpf(0.22, 0.34, mark)
				alpha = lerpf(0.28, 1.0, mark)
			"active":
				var stab := clampf(progress * 2.0 - float(index) * 0.16, 0.0, 1.0)
				position = target + Vector2(cos(angle), sin(angle)) * lerpf(34.0, -8.0, ease(stab, 0.35))
				scale = lerpf(0.28, 0.52, sin(stab * PI))
				alpha = lerpf(0.26, 1.0, sin(stab * PI))
			"recovery":
				position = target.lerp(Vector2(0.0, 8.0), ease(progress, 0.75))
				scale = lerpf(0.36, 0.18, progress)
				alpha = lerpf(0.92, 0.12, progress)
			"cancel":
				position = target.lerp(Vector2.ZERO, progress)
				scale = lerpf(0.20, 0.04, progress)
				alpha = lerpf(0.22, 0.0, progress)
		points.append(_point(position, scale, alpha, rotation))
	return points


static func _smoke_dome(count: int, radius: float, phase_name: String, progress: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var is_core := index == 0
		var angle := TAU * float(maxi(index - 1, 0)) / float(maxi(count - 1, 1))
		var edge := Vector2(cos(angle), sin(angle) * 0.58) * radius
		var position := Vector2.ZERO if is_core else edge
		var scale := 1.0 if is_core else 0.22
		var alpha := 0.72 if is_core else 0.42
		match phase_name:
			"windup":
				position = edge * (0.0 if is_core else 0.08)
				scale = lerpf(0.10, 0.24 if is_core else 0.14, progress)
				alpha = lerpf(0.08, 0.30, progress)
			"release":
				position = edge * (0.0 if is_core else ease(progress, 0.5))
				scale = lerpf(0.24 if is_core else 0.14, 0.94 if is_core else 0.28, progress)
				alpha = lerpf(0.30, 0.72 if is_core else 0.48, progress)
			"active":
				position = Vector2(sin(progress * TAU) * 7.0, 0.0) if is_core else edge * (0.86 + sin((progress + float(index) * 0.11) * PI) * 0.08)
				scale = 0.94 + sin(progress * PI) * 0.10 if is_core else 0.26
				alpha = 0.74 if is_core else 0.46
			"recovery":
				position = Vector2.ZERO if is_core else edge * lerpf(0.88, 1.22, progress)
				scale = lerpf(1.04 if is_core else 0.28, 1.44 if is_core else 0.12, progress)
				alpha = lerpf(0.74 if is_core else 0.46, 0.0, ease(progress, 0.55))
			"cancel":
				position = edge * (0.0 if is_core else lerpf(1.0, 0.3, progress))
				scale = lerpf(0.42 if is_core else 0.16, 0.02, progress)
				alpha = lerpf(0.28, 0.0, progress)
		points.append(_point(position, scale, alpha, angle))
	return points


static func _point(position: Vector2, scale: float, alpha: float, rotation: float) -> Dictionary:
	return {"position": position, "scale": maxf(scale, 0.0), "alpha": clampf(alpha, 0.0, 1.0), "rotation": rotation}
