class_name EngineerUltimatePresentationPack
extends RefCounted

## Class-local presentation pack for the three Engineer weapon ultimates.
##
## The pack owns engineer data only: per-weapon timing rhythm, formation motion,
## and class-local source/runtime frames. Immutable profile, presentation, and
## cast-phase IDs stay owned by the v1 weapon-ultimate registry, and every
## manifest emitted here is validated by the shared presentation schema.
##
## The pack deliberately does not edit the shared presentation bridge and does
## not redirect the shared runtime paths, so nothing it declares reaches live
## combat on its own; FAN-1541 owns the shared runtime adapter.

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const CLASS_ID := "engineer"
const ASSET_DIRECTORY := "res://assets/sprites/effects/ultimates/engineer/"
const ACCEPTED_VFX_PREFIX := "res://assets/sprites/effects/vfx_weapon_"
const ACCEPTED_VFX_SUFFIX := ".png"
const SFX_DIRECTORY := "res://assets/audio/sfx/"

const SENTRY_WRENCH := "engineer_sentry_wrench"
const REPAIR_DRONE := "engineer_repair_drone"
const PRESSURE_MINES := "engineer_pressure_mines"

const WEAPON_IDS: Array[String] = [SENTRY_WRENCH, REPAIR_DRONE, PRESSURE_MINES]

## Crowd performance cap. One engineer ultimate instance may never place more
## simultaneous presentation sprites than this, so a crowded arena cannot turn
## a single cast into an unbounded sprite burst.
const MAX_ELEMENTS_PER_ULTIMATE := 16

## Weapons whose formation element is an animated frame pack instead of a single
## forged frame. Every frame shares one canvas and one pivot, so switching the
## texture animates the element without moving it.
##
## `engineer_sentry_wrench` plays the FAN-2565 PixelLab deploy cycle: the pylon
## stands up, fires, and vents. A weapon absent from this map keeps its single
## forged frame, which is why `element_runtime_path()` still answers for all
## three and the driver needs no per-weapon branch.
const ANIMATION_FRAMES := {
	SENTRY_WRENCH: {
		"runtime_directory": "res://assets/sprites/effects/ultimates/engineer/sentry_wrench_deploy/",
		"source_directory": "res://docs/design/references/weapon_ultimates/engineer/source/pixellab_sentry_wrench/",
		"runtime_prefix": "sentry_pylon_%02d.png",
		"source_prefix": "sentry_pylon_f%02d.png",
		"count": 9,
	},
}

## Firing beats the sentry crossfire shows during `active`. It mirrors the
## `volley_count` of the frozen executor params so a muzzle flash lands on each
## volley; it drives presentation frames only and changes no mechanic.
const SENTRY_VOLLEY_BEATS := 8

## Per-weapon class-local presentation data.
##
## `timing` holds phase start timestamps in seconds. The shared schema requires
## them to be monotonic and inside `max_timeline_seconds`, and the three rhythms
## are deliberately different shapes rather than one curve in three colors:
## the wrench telegraphs briefly and holds a long crossfire, the drone swarm
## opens slowly and trails a long dome, and the mine field telegraphs longest
## and detonates in a short burst.
const WEAPONS := {
	SENTRY_WRENCH: {
		"title": "Гнездо Часовых",
		"element": "engineer_sentry_pylon",
		"sfx_file": "sfx_hit.ogg",
		"pivot": {"x": 0.5, "y": 0.85},
		# Ultimate Direction v2 (FAN-2944 §1, reworked by FAN-2960): 0.8s cast
		# ceremony, 2.3s release+crossfire window, 0.7s visible fold-out.
		"timing": {
			"windup": 0.0,
			"release": 0.8,
			"active": 1.15,
			"recovery": 3.1,
			"cancel": 3.8,
		},
		"formation": {
			# Arena-wide hexagon: the deployed nest frames the whole viewport
			# instead of the v1 close ring around the hero.
			"kind": "hex_crossfire",
			"count": 6,
			"radius": 520.0,
		},
		## FAN-2944 §3.1 presence and identity declarations for the migrated
		## pair; the schema fails closed on them once the pair leaves
		## PRESENTATION_V2_MIGRATION_ALLOWLIST. The scene driver applies the
		## declared weight effects at the release beat.
		"presence": {
			"fullscreen_footprint": true,
			"backdrop": "darken",
			"camera_shake": true,
			"hitstop_ms": 110,
			"sfx_ducking": true,
		},
		"identity": {
			"cast_pose_id": "cast_pose.engineer.wrench_overhead_brace",
			"weapon_silhouette_asset": "res://assets/sprites/effects/vfx_weapon_engineer_sentry_wrench.png",
			"class_palette_id": "class_palette.engineer.workshop_teal",
		},
		## Class-local geometry of the v2 full-screen layers. The identity
		## silhouette asset above is the sigil texture, so the declared visual
		## core and the rendered one cannot drift apart.
		"v2_overlay": {
			"backdrop_half_size": {"x": 1400.0, "y": 800.0},
			"backdrop_color": {"r": 0.016, "g": 0.043, "b": 0.055},
			"backdrop_peak_alpha": 0.42,
			"chord_color": {"r": 0.62, "g": 0.94, "b": 0.86},
		},
		"silhouette": "colossal translucent sentry-wrench sigil over the hero, hub of six tall pylons on an arena-wide hexagon",
		"motion": "wrench sigil rises over the hero while pylon ghosts sweep out to arena seats, slams at release, crossfire holds the frame",
		"impact": "hitstop slam of the wrench sigil, then synchronized turret volleys along arena-wide hex chords",
	},
	REPAIR_DRONE: {
		"title": "Рой Аварийного Ремонта",
		"element": "engineer_repair_microdrone",
		"sfx_file": "sfx_artifact_reveal.ogg",
		"pivot": {"x": 0.5, "y": 0.5},
		"timing": {
			"windup": 0.0,
			"release": 0.70,
			"active": 1.20,
			"recovery": 3.35,
			"cancel": 4.00,
		},
		"formation": {
			"kind": "double_helix",
			"count": 12,
			"radius": 96.0,
		},
		"silhouette": "wide flat rotor bar over a small orb body",
		"motion": "canister column unwinds into two counter-phased helix strands",
		"impact": "alternating intercept and ram streaks, then a protective dome",
	},
	PRESSURE_MINES: {
		"title": "Минное Поле Омега",
		"element": "engineer_smart_mine",
		"sfx_file": "sfx_boss_phase.ogg",
		"pivot": {"x": 0.5, "y": 0.75},
		"timing": {
			"windup": 0.0,
			"release": 0.90,
			"active": 1.70,
			"recovery": 3.10,
			"cancel": 3.60,
		},
		"formation": {
			# Wide enough that the gaps between mines still read as the safe
			# lanes the ultimate is supposed to leave open.
			"kind": "lattice_grid",
			"count": 16,
			"radius": 132.0,
		},
		"silhouette": "squat prong-topped dome on a wide base plate",
		"motion": "blueprint lattice flashes, mines burrow up in place, links latch",
		"impact": "ordered outer-to-inner chain detonation",
	},
}

## Presentation phase name -> registry `cast_phases` key, mirroring the frozen
## `phase_id_bindings` of the shared schema document.
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
	var frames: Dictionary = ANIMATION_FRAMES.get(weapon_id, {})
	if not frames.is_empty():
		return _frame_path(frames, "source_directory", "source_prefix", 0)
	return "%s%s_source.png" % [ASSET_DIRECTORY, str(weapon_config(weapon_id).get("element", ""))]


## The element frame the pack identifies the weapon by. For an animated weapon
## that is frame 0 of its pack, so silhouette, pivot and readability checks keep
## reading one canonical frame.
static func element_runtime_path(weapon_id: String) -> String:
	var frames: Dictionary = ANIMATION_FRAMES.get(weapon_id, {})
	if not frames.is_empty():
		return _frame_path(frames, "runtime_directory", "runtime_prefix", 0)
	return "%s%s.png" % [ASSET_DIRECTORY, str(weapon_config(weapon_id).get("element", ""))]


## Every runtime frame of the weapon, in play order. A weapon without an
## animation pack answers with its single element frame.
static func element_frame_paths(weapon_id: String) -> Array[String]:
	var frames: Dictionary = ANIMATION_FRAMES.get(weapon_id, {})
	if frames.is_empty():
		return [element_runtime_path(weapon_id)] as Array[String]
	var paths: Array[String] = []
	for index in int(frames.get("count", 0)):
		paths.append(_frame_path(frames, "runtime_directory", "runtime_prefix", index))
	return paths


## The frame index the element shows at `phase_name`/`progress`.
##
## The pylon stands up through windup and release, cycles its firing frames once
## per executor volley while the crossfire holds, then plays shutdown and vent
## on the way out — so the frame a player sees always names the phase.
static func frame_index(weapon_id: String, phase_name: String, progress: float) -> int:
	if not ANIMATION_FRAMES.has(weapon_id):
		return 0
	var t := clampf(progress, 0.0, 1.0)
	match phase_name:
		"release":
			return 1
		"active":
			return 2 + int(t * float(SENTRY_VOLLEY_BEATS) * 4.0) % 4
		"recovery":
			return 6
		"cancel":
			return 7 + int(round(t))
	return 0


static func _frame_path(frames: Dictionary, directory_key: String, prefix_key: String, index: int) -> String:
	return "%s%s" % [str(frames.get(directory_key, "")), str(frames.get(prefix_key, "")) % index]


static func accepted_vfx_path(weapon_id: String) -> String:
	return "%s%s%s" % [ACCEPTED_VFX_PREFIX, weapon_id, ACCEPTED_VFX_SUFFIX]


## Build the class-local manifest for one engineer weapon.
##
## Every immutable ID is read back from the registry profile instead of being
## restated here, so the pack cannot drift from the frozen catalog.
static func manifest_for(registry, weapon_id: String) -> Dictionary:
	var config := weapon_config(weapon_id)
	if config.is_empty():
		return {}
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	if profile.is_empty():
		return {}
	var presentation: Dictionary = profile.get("presentation", {})
	var cast_phases: Dictionary = profile.get("cast_phases", {})
	var accepted_vfx := accepted_vfx_path(weapon_id)
	var sfx_path := "%s%s" % [SFX_DIRECTORY, str(config.get("sfx_file", ""))]

	var phases: Array[Dictionary] = []
	for binding in PHASE_BINDINGS:
		phases.append({
			"name": str(binding[0]),
			"phase_id": str(cast_phases.get(str(binding[1]), "")),
		})

	var manifest := {
		"schema_version": Schema.EXPECTED_SCHEMA_VERSION,
		"class_id": CLASS_ID,
		"key": {
			"weapon_id": weapon_id,
			"action": Schema.ACTION_ULTIMATE,
		},
		"presentation_id": str(presentation.get("presentation_id", "")),
		# Animation is the class-local formation element; VFX stays on the
		# accepted weapon burst because redirecting shared runtime paths is
		# owned elsewhere.
		"animation": {
			"id": str(presentation.get("animation_id", "")),
			"source_path": element_source_path(weapon_id),
			"runtime_path": element_runtime_path(weapon_id),
		},
		"vfx": {
			"id": str(presentation.get("vfx_id", "")),
			"source_path": accepted_vfx,
			"runtime_path": accepted_vfx,
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
	# v2 presence/identity pass through only for migrated weapons, mirroring
	# the shared bridge, so v1 siblings keep their exact manifest shape.
	for block in ["presence", "identity"]:
		if config.get(block) is Dictionary:
			manifest[block] = (config[block] as Dictionary).duplicate(true)
	return manifest


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


## Total timeline length, i.e. the last phase start in the rhythm.
static func timeline_seconds(weapon_id: String) -> float:
	var timing: Dictionary = weapon_config(weapon_id).get("timing", {})
	var longest := 0.0
	for value in timing.values():
		longest = maxf(longest, float(value))
	return longest


## Resolve the phase a timeline is inside at `elapsed`, plus its local 0..1
## progress.
##
## `cancel` is the terminal cleanup marker rather than a beat that plays after
## recovery — the shared bridge makes the same statement by giving recovery and
## cancel the same default timestamp. So a run that is never aborted plays
## windup through recovery and then ends, and the cancel pose is what an abort
## shows. It still owns a distinct timestamp here so the fold-out tail has a
## place on the timeline.
static func phase_at(weapon_id: String, elapsed: float) -> Dictionary:
	var timing: Dictionary = weapon_config(weapon_id).get("timing", {})
	var current := ""
	var started := 0.0
	var ends := timeline_seconds(weapon_id)
	for binding in PHASE_BINDINGS:
		var name := str(binding[0])
		if not timing.has(name):
			continue
		var start := float(timing[name])
		if elapsed >= start and start >= started:
			current = name
			started = start
	for binding in PHASE_BINDINGS:
		var name := str(binding[0])
		var start := float(timing.get(name, -1.0))
		if start > started:
			ends = minf(ends, start)
	var span := maxf(ends - started, 0.0001)
	return {
		"name": current,
		"progress": clampf((elapsed - started) / span, 0.0, 1.0),
	}


## Class-local motion. Returns one entry per formation element with
## `position` (pixels, ultimate origin at 0,0), `scale`, `alpha`, `rotation`.
##
## The scene driver and the contact-sheet renderer both consume this function,
## so the published evidence shows the same motion the scene plays.
static func formation_points(weapon_id: String, phase_name: String, progress: float) -> Array[Dictionary]:
	var config := weapon_config(weapon_id)
	var formation: Dictionary = config.get("formation", {})
	var kind := str(formation.get("kind", ""))
	var count := int(formation.get("count", 0))
	var radius := float(formation.get("radius", 0.0))
	var t := clampf(progress, 0.0, 1.0)
	match kind:
		"hex_crossfire":
			return _hex_crossfire(count, radius, phase_name, t)
		"double_helix":
			return _double_helix(count, radius, phase_name, t)
		"lattice_grid":
			return _lattice_grid(count, radius, phase_name, t)
	return []


## Six pylons on a fixed hexagon. The silhouette never orbits: it snaps up in
## place, holds a static crossfire, then folds inward into sparks.
static func _hex_crossfire(count: int, radius: float, phase_name: String, t: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for index in count:
		var angle := TAU * float(index) / float(maxi(count, 1)) - PI * 0.5
		var seat := Vector2(cos(angle), sin(angle) * 0.62) * radius
		var position := seat
		var scale := 1.0
		var alpha := 1.0
		var rotation := 0.0
		match phase_name:
			"windup":
				# Cast ceremony: blueprint ghosts sweep from the hero out to
				# their arena seats, acknowledging the ground they will hold.
				position = seat * lerpf(0.12, 1.0, ease(t, 0.55))
				scale = lerpf(0.30, 0.55, t)
				alpha = lerpf(0.10, 0.38, t)
			"release":
				position = seat + Vector2(0.0, lerpf(34.0, 0.0, ease(t, 0.35)))
				scale = lerpf(0.55, 1.0, ease(t, 0.35))
				alpha = lerpf(0.38, 1.0, t)
			"active":
				# Turret heads track priority targets; bodies stay planted.
				position = seat
				rotation = sin((t * 6.0 + float(index)) * PI) * 0.18
				scale = 1.0 + sin((t * 8.0 + float(index) * 0.5) * PI) * 0.04
			"recovery":
				position = seat.lerp(Vector2.ZERO, ease(t, 2.2) * 0.35)
				scale = lerpf(1.0, 0.55, t)
				alpha = lerpf(1.0, 0.45, t)
			"cancel":
				position = seat.lerp(seat * 1.35, t)
				scale = lerpf(0.55, 0.22, t)
				alpha = lerpf(0.45, 0.0, t)
		points.append(_point(position, scale, alpha, rotation))
	return points


## Twelve microdrones on two counter-phased strands. The silhouette is always
## travelling: the swarm never holds a fixed ring.
static func _double_helix(count: int, radius: float, phase_name: String, t: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var per_strand := maxi(count / 2, 1)
	for index in count:
		var strand := index % 2
		var slot := float(index / 2)
		var phase := TAU * slot / float(per_strand) + (PI if strand == 1 else 0.0)
		var span := lerpf(-1.0, 1.0, slot / maxf(float(per_strand - 1), 1.0))
		var position := Vector2.ZERO
		var scale := 1.0
		var alpha := 1.0
		var rotation := 0.0
		match phase_name:
			"windup":
				# Stacked inside the canister, barely visible.
				position = Vector2(sin(slot * 1.7) * 4.0, span * lerpf(6.0, 18.0, t))
				scale = lerpf(0.34, 0.52, t)
				alpha = lerpf(0.15, 0.55, t)
			"release":
				var open := ease(t, 0.4)
				position = Vector2(
					cos(phase + t * PI) * radius * open,
					span * radius * 0.52 * open
				)
				scale = lerpf(0.52, 1.0, open)
				alpha = lerpf(0.55, 1.0, open)
				rotation = phase + t * PI
			"active":
				# Even indices intercept inward, odd indices ram outward.
				var spin := phase + t * TAU
				var reach := 0.58 if index % 2 == 0 else 1.0
				var beat := absf(sin((t * 5.0 + float(index) * 0.4) * PI))
				position = Vector2(
					cos(spin) * radius * lerpf(reach, reach + 0.22, beat),
					span * radius * 0.52 + sin(spin) * 14.0
				)
				scale = lerpf(0.86, 1.12, beat)
				rotation = spin
			"recovery":
				# Collapse onto a protective dome above the hero.
				var dome_angle := PI + PI * slot / maxf(float(per_strand - 1), 1.0)
				var dome := Vector2(cos(dome_angle), sin(dome_angle) * 0.55) * radius * 0.78
				var spin_out := phase + TAU
				var travel := Vector2(cos(spin_out) * radius, span * radius * 0.52)
				position = travel.lerp(dome, ease(t, 0.5))
				scale = lerpf(1.0, 0.72, t)
				alpha = lerpf(1.0, 0.8, t)
				rotation = lerpf(spin_out, 0.0, t)
			"cancel":
				var dome_angle_out := PI + PI * slot / maxf(float(per_strand - 1), 1.0)
				var dome_seat := Vector2(cos(dome_angle_out), sin(dome_angle_out) * 0.55) * radius * 0.78
				position = dome_seat + Vector2(0.0, -lerpf(0.0, 34.0, t))
				scale = lerpf(0.72, 0.3, t)
				alpha = lerpf(0.8, 0.0, t)
		points.append(_point(position, scale, alpha, rotation))
	return points


## A seeded 4x4 lattice. Mines never travel: the motion is the ordered
## outer-to-inner removal, which is the finale this ultimate is named for.
static func _lattice_grid(count: int, radius: float, phase_name: String, t: float) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var side := int(round(sqrt(float(maxi(count, 1)))))
	var step := radius * 2.0 / float(maxi(side - 1, 1))
	for index in count:
		var column := index % side
		var row := index / side
		var seat := Vector2(
			-radius + step * float(column),
			(-radius + step * float(row)) * 0.6
		)
		# Rank 0 is the outer ring, rank 1 the inner core: the detonation order.
		var is_outer := column == 0 or row == 0 or column == side - 1 or row == side - 1
		var position := seat
		var scale := 1.0
		var alpha := 1.0
		var rotation := 0.0
		match phase_name:
			"windup":
				# Arena blueprint grid flash. The seats stay large enough to
				# read as safe-lane telegraph even on the 648p floor.
				scale = lerpf(0.32, 0.48, t)
				alpha = lerpf(0.12, 0.45, t) * (1.0 if is_outer else 0.75)
			"release":
				# Mines burrow up in place and settle.
				var rise := ease(clampf(t * 1.15 - (0.15 if not is_outer else 0.0), 0.0, 1.0), 0.45)
				position = seat + Vector2(0.0, lerpf(10.0, 0.0, rise))
				scale = lerpf(0.48, 1.0, rise)
				alpha = lerpf(0.45, 1.0, rise)
			"active":
				# Proximity links latch; armed mines breathe in place.
				var pulse := absf(sin((t * 4.0 + float(index) * 0.3) * PI))
				position = seat
				scale = 1.0 + pulse * 0.05
				alpha = lerpf(0.88, 1.0, pulse)
			"recovery":
				# Outer ring detonates first, core stays armed.
				if is_outer:
					scale = lerpf(1.0, 1.5, t)
					alpha = lerpf(1.0, 0.0, ease(t, 0.6))
				else:
					scale = 1.0 + sin(t * PI * 3.0) * 0.06
			"cancel":
				# Core detonates last, outward-in finale complete.
				if is_outer:
					alpha = 0.0
					scale = 0.0
				else:
					scale = lerpf(1.06, 1.7, t)
					alpha = lerpf(1.0, 0.0, ease(t, 0.6))
		points.append(_point(position, scale, alpha, rotation))
	return points


static func _point(position: Vector2, scale: float, alpha: float, rotation: float) -> Dictionary:
	return {
		"position": position,
		"scale": maxf(scale, 0.0),
		"alpha": clampf(alpha, 0.0, 1.0),
		"rotation": rotation,
	}
