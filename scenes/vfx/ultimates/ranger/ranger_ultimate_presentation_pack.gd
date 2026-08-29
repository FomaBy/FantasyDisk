class_name RangerUltimatePresentationPack
extends RefCounted

## Class-local presentation data for the three Ranger weapon ultimates.
##
## It deliberately reuses the accepted weapon VFX instead of creating new
## raster art. The shared presentation registry remains untouched; FAN-1541
## owns the future runtime adapter that selects this scene package.
##
## FAN-3736 moved the trio onto the Ultimate Direction v2 envelope: every
## timeline lands inside 2.5-4.0 s with at least 1.2 s of active presentation,
## and each weapon declares the v2 presence/identity blocks the shared schema
## fails closed on. The gameplay executors keep their own `lifetime` clock —
## presentation and gameplay windows are independent by contract
## (docs/design/systems/weapon_ultimate_presentation.md, "Two independent
## clocks"), so shortening the show never touches damage, control or charge.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const CLASS_ID := "ranger"
const ASSET_DIRECTORY := "res://assets/sprites/effects/"
const SFX_DIRECTORY := "res://assets/audio/sfx/"

const MOON_CROSSBOW := "moon_crossbow"
const STORM_LONGBOW := "storm_longbow"
const HUNTER_TRAP := "hunter_trap"

const WEAPON_IDS: Array[String] = [MOON_CROSSBOW, STORM_LONGBOW, HUNTER_TRAP]
const MAX_ELEMENTS_PER_ULTIMATE := 8

## The two authored v2 nodes every Ranger scene adds on top of its formation:
## the arena-wide backdrop veil and the hero cast pose.
const PRESENCE_NODE_COUNT := 2
## Formation elements plus the two presence nodes, with the same headroom the
## v1 package carried. Well under the shared 32-node ceiling.
const CROWD_CAP := 12
## The package draws untinted sprites and one gradient veil: no CanvasItem or
## particle material is authored, so the declaration is pure headroom for the
## backdrop layer. Both stay inside the shared 16/2 ceilings.
const MAX_UNIQUE_MATERIALS := 1
const MAX_FULLSCREEN_MATERIALS := 1

## v2 identity (FAN-2944 §3.1). The cast pose is hero-specific and shared by the
## whole Ranger trio; the weapon silhouette is each weapon's own accepted frame,
## so no two pairs share a generic burst.
const CAST_POSE_ID := "cast_pose.ranger.hunter_draw"
const CAST_POSE_ASSET := "res://assets/sprites/characters/full_frame/ranger_pixellab/ranger_idle_south.png"
const CLASS_PALETTE_ID := "palette.ranger.moonlit_hunt"
## The palette the three effects resolve their colors from; a weapon names one
## role, so the trio reads as one class without three identical tints.
const CLASS_PALETTE := {
	"moonlight": Color(0.82, 0.88, 1.0),
	"storm": Color(0.45, 0.92, 1.0),
	"thicket": Color(0.48, 0.95, 0.72),
}

## Authored node names the scenes bind their v2 presence to.
const BACKDROP_NODE := "BackdropVeil"
const HERO_POSE_NODE := "HeroPose"
## The backdrop must actually reach its declared weight, not merely exist.
const MIN_BACKDROP_PEAK_ALPHA := 0.15
## A `flash` backdrop is a single shot inside one activation, so the flash rate
## stays at 0 Hz — far under the WCAG 2.3.1 3 Hz threshold.
const FLASH_RISE_SECONDS := 0.06
const FLASH_TAIL_RATIO := 0.25

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
			"release": 0.70,
			"active": 1.05,
			"recovery": 2.60,
			"cancel": 3.10,
		},
		"formation": {"kind": "moon_mark_split", "count": 5, "radius": 132.0},
		"silhouette": "silver crescent mark, focused bolt, and four split bolts",
		"motion": "the mark blooms above prey, one bolt reaches it, then four bolts split diagonally and rejoin",
		"impact": "moon-mark flash followed by a four-way silver split",
		"palette_role": "moonlight",
		"backdrop_tint": Color(0.06, 0.08, 0.14),
		"backdrop_peak_alpha": 0.30,
		"presence": {
			"fullscreen_footprint": true,
			"backdrop": "darken",
			"camera_shake": true,
			"hitstop_ms": 95,
			"sfx_ducking": true,
		},
		"shake": {"seconds": 0.35, "amplitude": 6.0, "duck_db": -6.0},
	},
	STORM_LONGBOW: {
		"title": "Глаз Бури",
		"asset_source": "res://docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/storm_longbow_pixellab_source.png",
		"asset_runtime": "%svfx_weapon_storm_longbow.png" % ASSET_DIRECTORY,
		"sfx_file": "sfx_boss_phase.ogg",
		"pivot": {"x": 0.10, "y": 0.50},
		"timing": {
			"windup": 0.0,
			"release": 0.60,
			"active": 0.95,
			"recovery": 2.85,
			"cancel": 3.45,
		},
		"formation": {"kind": "storm_corridor", "count": 7, "radius": 242.0},
		"silhouette": "one long storm arrow corridor with tail-to-tip lightning beats",
		"motion": "a charged arrow draws a horizontal safe axis, then lightning walks from tail to tip",
		"impact": "sequential electric corridor strikes that push away from the axis",
		"palette_role": "storm",
		"backdrop_tint": Color(0.62, 0.86, 1.0),
		"backdrop_peak_alpha": 0.28,
		"presence": {
			"fullscreen_footprint": true,
			"backdrop": "flash",
			"camera_shake": true,
			"hitstop_ms": 120,
			"sfx_ducking": true,
		},
		"shake": {"seconds": 0.50, "amplitude": 8.0, "duck_db": -9.0},
	},
	HUNTER_TRAP: {
		"title": "Великая Западня",
		"asset_source": "res://docs/design/references/weapon_attack_animations/hunter_trap/vfx_weapon_hunter_trap_source.png",
		"asset_runtime": "%svfx_weapon_hunter_trap.png" % ASSET_DIRECTORY,
		"sfx_file": "sfx_hit_dot.ogg",
		"pivot": {"x": 0.50, "y": 0.50},
		"timing": {
			"windup": 0.0,
			"release": 0.95,
			"active": 1.40,
			"recovery": 2.70,
			"cancel": 3.80,
		},
		"formation": {"kind": "three_ring_traps", "count": 3, "radius": 172.0},
		"silhouette": "three heavy spectral trap rings with inward-facing jaws",
		"motion": "three edge sigils close toward the center in staggered jaw-lock rings",
		"impact": "green-blue jaw snap, chain net closure, and a fading bleed rune",
		"palette_role": "thicket",
		"backdrop_tint": Color(0.05, 0.12, 0.09),
		"backdrop_peak_alpha": 0.34,
		"presence": {
			"fullscreen_footprint": true,
			"backdrop": "darken",
			"camera_shake": true,
			"hitstop_ms": 145,
			"sfx_ducking": true,
		},
		"shake": {"seconds": 0.65, "amplitude": 11.0, "duck_db": -7.0},
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
		"presence": presence_for(weapon_id),
		"identity": identity_for(weapon_id),
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


## v2 presence block (FAN-2944 §3.1) exactly as the shared schema reads it.
static func presence_for(weapon_id: String) -> Dictionary:
	var presence = weapon_config(weapon_id).get("presence", {})
	return (presence as Dictionary).duplicate(true) if presence is Dictionary else {}


## v2 identity block. The silhouette is the weapon's own accepted runtime frame,
## so no two Ranger pairs — and no other class — can share a generic burst.
static func identity_for(weapon_id: String) -> Dictionary:
	if weapon_config(weapon_id).is_empty():
		return {}
	return {
		"cast_pose_id": CAST_POSE_ID,
		"weapon_silhouette_asset": element_runtime_path(weapon_id),
		"class_palette_id": CLASS_PALETTE_ID,
	}


## The class palette color a weapon resolves its elements from.
static func palette_color(weapon_id: String) -> Color:
	var role := str(weapon_config(weapon_id).get("palette_role", ""))
	return CLASS_PALETTE.get(role, Color.WHITE)


## Drawn nodes one activation adds: its formation plus the two presence nodes.
static func max_visual_nodes(weapon_id: String) -> int:
	var formation: Dictionary = weapon_config(weapon_id).get("formation", {})
	return mini(int(formation.get("count", 0)), MAX_ELEMENTS_PER_ULTIMATE) + PRESENCE_NODE_COUNT


## Arena-wide backdrop weight over the timeline. `darken` swells with the cast
## and holds through the active window; `flash` is one shot at release with a
## decaying tail, so a single activation never repeats a full-screen flash.
static func backdrop_alpha(weapon_id: String, elapsed: float) -> float:
	var config := weapon_config(weapon_id)
	var timing: Dictionary = config.get("timing", {})
	if timing.is_empty():
		return 0.0
	var release := float(timing.get("release", 0.0))
	var active := float(timing.get("active", 0.0))
	var recovery := float(timing.get("recovery", 0.0))
	var cancel := float(timing.get("cancel", 0.0))
	var peak := float(config.get("backdrop_peak_alpha", 0.0))
	if elapsed <= 0.0 or elapsed >= cancel:
		return 0.0
	if str((config.get("presence", {}) as Dictionary).get("backdrop", "")) == "flash":
		if elapsed < release:
			return 0.0
		if elapsed < release + FLASH_RISE_SECONDS:
			return peak * _ratio(elapsed - release, FLASH_RISE_SECONDS)
		if elapsed < active:
			return lerpf(
				peak,
				peak * FLASH_TAIL_RATIO,
				_ratio(elapsed - release - FLASH_RISE_SECONDS, active - release - FLASH_RISE_SECONDS)
			)
		return peak * FLASH_TAIL_RATIO * (1.0 - _ratio(elapsed - active, cancel - active))
	if elapsed < active:
		return peak * _ratio(elapsed, active)
	if elapsed < recovery:
		return peak
	return peak * (1.0 - _ratio(elapsed - recovery, cancel - recovery))


## Hero cast pose weight: the archer holds the draw through the cast ceremony
## and fades out shortly after the release beat.
static func hero_pose_alpha(weapon_id: String, elapsed: float) -> float:
	var timing: Dictionary = weapon_config(weapon_id).get("timing", {})
	if timing.is_empty():
		return 0.0
	var release := float(timing.get("release", 0.0))
	var active := float(timing.get("active", 0.0))
	if elapsed <= 0.0:
		return 0.0
	if elapsed < release:
		return 0.35 + 0.55 * _ratio(elapsed, release)
	if elapsed < active:
		return 0.90 * (1.0 - _ratio(elapsed - release, active - release))
	return 0.0


static func _ratio(value: float, span: float) -> float:
	return clampf(value / maxf(span, 0.0001), 0.0, 1.0)


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


## Every v2 gate this package owns at the scene level, as "<code>: <detail>".
##
## The focused contract test drives it both ways: an untouched scene reports
## nothing, and a scene with one binding removed reports exactly that code. The
## envelope, presence and identity declarations themselves are validated by the
## shared schema, which this deliberately does not duplicate.
static func scene_violations(scene: Node, weapon_id: String) -> Array[String]:
	var violations: Array[String] = []
	var key := "%s/%s" % [CLASS_ID, weapon_id]
	if scene == null or not is_instance_valid(scene):
		violations.append("ranger.v2.scene_missing: %s" % key)
		return violations
	if str(scene.get_meta("ultimate_id", "")) != key:
		violations.append("ranger.v2.ultimate_id: %s" % key)

	var veil := scene.get_node_or_null(BACKDROP_NODE) as Sprite2D
	if veil == null or veil.texture == null:
		violations.append("ranger.v2.backdrop_node: %s must author %s" % [key, BACKDROP_NODE])
	elif not bool(veil.get_meta("fullscreen_layer", false)):
		violations.append("ranger.v2.fullscreen_footprint: %s veil is not an arena-wide layer" % key)

	var pose := scene.get_node_or_null(HERO_POSE_NODE) as Sprite2D
	if pose == null or pose.texture == null:
		violations.append("ranger.v2.hero_pose_node: %s must author %s" % [key, HERO_POSE_NODE])

	# A broken declaration can be any type at all, so the blocks are compared as
	# dictionaries only once both sides are dictionaries.
	if not _same_block(scene.get_meta("presence", {}), presence_for(weapon_id)):
		violations.append("ranger.v2.presence_meta: %s" % key)
	if not _same_block(scene.get_meta("identity", {}), identity_for(weapon_id)):
		violations.append("ranger.v2.identity_meta: %s" % key)
	if int(scene.get_meta("max_visual_nodes", 0)) != max_visual_nodes(weapon_id):
		violations.append("ranger.v2.max_visual_nodes: %s" % key)
	if int(scene.get_meta("crowd_cap", 0)) != CROWD_CAP:
		violations.append("ranger.v2.crowd_cap: %s" % key)
	if int(scene.get_meta("max_unique_materials", 0)) != MAX_UNIQUE_MATERIALS \
			or int(scene.get_meta("max_fullscreen_materials", 0)) != MAX_FULLSCREEN_MATERIALS:
		violations.append("ranger.v2.material_budget: %s" % key)

	var shake: Dictionary = weapon_config(weapon_id).get("shake", {})
	if float(shake.get("seconds", 0.0)) <= 0.0 or float(shake.get("amplitude", 0.0)) <= 0.0:
		violations.append("ranger.v2.camera_shake: %s declares no shake window" % key)
	violations.append_array(curve_violations(weapon_id))
	return violations


static func _same_block(declared, expected: Dictionary) -> bool:
	if not declared is Dictionary:
		return false
	var block := declared as Dictionary
	if block.size() != expected.size():
		return false
	for field in expected:
		if not block.has(field) or block[field] != expected[field]:
			return false
	return true


## The backdrop and hero pose must reach real weight and end at zero, so a
## declared presence block cannot pass with an invisible treatment behind it.
static func curve_violations(weapon_id: String) -> Array[String]:
	var violations: Array[String] = []
	var key := "%s/%s" % [CLASS_ID, weapon_id]
	var cancel := timeline_seconds(weapon_id)
	if cancel <= 0.0:
		violations.append("ranger.v2.timeline: %s has no timeline" % key)
		return violations
	var backdrop_peak := 0.0
	var pose_peak := 0.0
	for step in 121:
		var elapsed := cancel * float(step) / 120.0
		backdrop_peak = maxf(backdrop_peak, backdrop_alpha(weapon_id, elapsed))
		pose_peak = maxf(pose_peak, hero_pose_alpha(weapon_id, elapsed))
	if backdrop_peak < MIN_BACKDROP_PEAK_ALPHA:
		violations.append("ranger.v2.backdrop_weight: %s peaks at %.2f" % [key, backdrop_peak])
	if not is_zero_approx(backdrop_alpha(weapon_id, cancel)):
		violations.append("ranger.v2.backdrop_cleanup: %s ends lit" % key)
	if pose_peak <= 0.0:
		violations.append("ranger.v2.hero_pose_weight: %s never shows its cast pose" % key)
	return violations


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
