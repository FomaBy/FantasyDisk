class_name DoctorUltimateTimelineScene
extends Node2D

## Doctor-only timeline driver. It builds a bounded set of accepted flipbooks and
## procedural telegraphs, then advances them from the frozen U5 phase timing.
##
## The weapon-local FAN-3613 packs arrive as scene exports, so each `.tscn`
## names the exact pack it draws: the cast pack animates the weapon silhouette
## through the cast, the signature pack draws the arena effect. Frames are
## indexed from phase progress, never played on a wall clock, so `preview_at()`
## stays a pure function of elapsed time and a paused timeline freezes the drawn
## frame with the rest of the pose.

const Pack := preload("res://scenes/vfx/ultimates/doctor/doctor_ultimate_presentation_pack.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const CLEANUP_REASONS: Array[String] = ["cancel", "death", "node_end"]

## The infection-wave pack draws on a 256 px canvas where the ring it replaces
## spanned 164 px, so the wave keeps the footprint the declared coverage and the
## contact-sheet composition were accepted against.
const WAVE_PACK_SCALE := 0.64

## Whole passes through the looping poison pool inside each phase. Recovery
## continues the active count instead of restarting, so the pool never seams.
const POOL_ACTIVE_PLAYS := 4.0

@export var weapon_id: String = Pack.RESTORE_POTION

## Weapon-local animated packs (FAN-3613), assigned per scene.
@export var cast_frames: SpriteFrames = null
@export var signature_frames: SpriteFrames = null

signal phase_entered(phase: Dictionary)
signal timeline_finished(reason: String)

var _timeline = null
var _visuals := {}


func _ready() -> void:
	_apply_metadata()
	set_process(false)


func begin(registry, handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	finish("node_end")
	var manifest := Pack.manifest_for(registry, weapon_id)
	if manifest.is_empty():
		push_error("DoctorUltimateTimelineScene: no manifest for %s" % weapon_id)
		return {}
	_timeline = Timeline.new(manifest, headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_build_visuals()
		preview_at(0.0)
		set_process(true)
	return snapshot


func set_paused(value: bool) -> void:
	if _timeline != null:
		_timeline.set_paused(value)


func is_active() -> bool:
	return _timeline != null and str(_timeline.snapshot().get("state", "")) == Timeline.ACTIVE_STATE


func step(delta: float) -> void:
	if _timeline == null:
		return
	for event in _timeline.advance(delta):
		phase_entered.emit(event)
	preview_at(_timeline.elapsed_seconds())
	if _timeline != null and _timeline.elapsed_seconds() >= Pack.timeline_seconds(weapon_id):
		finish("node_end")


func preview_at(elapsed: float) -> void:
	if _visuals.is_empty():
		_build_visuals()
	var phase := Pack.phase_at(weapon_id, elapsed)
	match weapon_id:
		Pack.RESTORE_POTION:
			_preview_restore(str(phase["name"]), float(phase["progress"]))
		Pack.PLAGUE_SYRINGE:
			_preview_plague(str(phase["name"]), float(phase["progress"]))
		Pack.BONE_SAW:
			_preview_saw(str(phase["name"]), float(phase["progress"]))


func finish(reason: String) -> Dictionary:
	if _timeline == null:
		return {}
	var snapshot: Dictionary = _timeline.finish(reason)
	_timeline = null
	_clear_visuals()
	set_process(false)
	timeline_finished.emit(reason)
	return snapshot


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _timeline != null:
		_timeline.finish("node_end")
		_timeline = null


func _apply_metadata() -> void:
	var config := Pack.weapon_config(weapon_id)
	set_meta("ultimate_id", "%s/%s" % [Pack.CLASS_ID, weapon_id])
	set_meta("silhouette", str(config.get("silhouette", "")))
	set_meta("motion_path", str(config.get("motion", "")))
	set_meta("impact_language", str(config.get("impact", "")))
	set_meta("max_visual_nodes", int(config.get("max_visual_nodes", 0)))
	set_meta("crowd_cap", Pack.MAX_VISUAL_NODES)


func _build_visuals() -> void:
	_clear_visuals()
	_apply_metadata()
	match weapon_id:
		Pack.RESTORE_POTION:
			_build_restore()
		Pack.PLAGUE_SYRINGE:
			_build_plague()
		Pack.BONE_SAW:
			_build_saw()


func _build_restore() -> void:
	_visuals["bottle"] = _flipbook("GiantFlask", cast_frames)
	_visuals["outer"] = _flipbook("OuterPoisonPool", signature_frames)
	_visuals["inner"] = _line("InnerHealingSpiral", _spiral_points(82.0, 28), 8.0, Color(0.94, 1.0, 0.88, 0.92))
	_visuals["shards"] = _polygon("GlassImpact", PackedVector2Array([Vector2(0, -50), Vector2(15, -14), Vector2(53, -4), Vector2(18, 13), Vector2(7, 54), Vector2(-13, 17), Vector2(-52, 5), Vector2(-16, -15)]), Color(0.58, 1.0, 0.55, 0.78))
	_visuals["shield"] = _polygon("ShieldCrystal", PackedVector2Array([Vector2(0, -58), Vector2(42, -23), Vector2(34, 42), Vector2(0, 63), Vector2(-34, 42), Vector2(-42, -23)]), Color(0.88, 1.0, 0.92, 0.78))


func _build_plague() -> void:
	_visuals["syringe"] = _flipbook("OversizedSyringe", cast_frames)
	_visuals["patient"] = _line("PatientZero", _circle_points(38.0, 20), 10.0, Color(0.12, 0.95, 0.34, 0.9), true)
	_visuals["veins_a"] = _line("PlagueVeinsA", PackedVector2Array([Vector2.ZERO, Vector2(55, -28), Vector2(106, -18), Vector2(144, -57), Vector2(190, -45)]), 8.0, Color(0.08, 0.58, 0.22, 0.84))
	_visuals["veins_b"] = _line("PlagueVeinsB", PackedVector2Array([Vector2.ZERO, Vector2(-50, 35), Vector2(-92, 22), Vector2(-132, 68), Vector2(-185, 60)]), 7.0, Color(0.18, 0.72, 0.24, 0.78))
	_visuals["wave_a"] = _flipbook("PlagueWaveOne", signature_frames)
	_visuals["wave_b"] = _flipbook("PlagueWaveTwo", signature_frames)
	_visuals["wave_c"] = _flipbook("PlagueWaveThree", signature_frames)
	_visuals["mask"] = _polygon("MaskVaporBurst", PackedVector2Array([Vector2(-52, -38), Vector2(-18, -58), Vector2(0, -38), Vector2(18, -58), Vector2(52, -38), Vector2(36, 35), Vector2(12, 58), Vector2(0, 38), Vector2(-12, 58), Vector2(-36, 35)]), Color(0.08, 0.32, 0.12, 0.82))


func _build_saw() -> void:
	for index in 3:
		_visuals["saw_%d" % index] = _flipbook("OrbitSaw%d" % (index + 1), cast_frames)
	_visuals["arc"] = _flipbook("SurgicalOrbitArc", signature_frames)
	_visuals["sparks"] = _line("MetalSparks", PackedVector2Array([Vector2(-145, -56), Vector2(-115, -24), Vector2(-154, 2), Vector2(-105, 18), Vector2(-130, 57)]), 6.0, Color(1.0, 0.68, 0.24, 0.82))
	_visuals["drain_a"] = _line("DrainRibbonRed", PackedVector2Array([Vector2(-150, 72), Vector2(-85, 30), Vector2(-28, 18), Vector2.ZERO]), 9.0, Color(0.86, 0.12, 0.18, 0.8))
	_visuals["drain_b"] = _line("DrainRibbonGreen", PackedVector2Array([Vector2(150, 68), Vector2(92, 25), Vector2(34, 14), Vector2.ZERO]), 8.0, Color(0.22, 0.92, 0.42, 0.78))
	_visuals["stitches"] = _line("ShieldStitches", PackedVector2Array([Vector2(-88, 0), Vector2(-62, -18), Vector2(-36, 14), Vector2(-10, -16), Vector2(16, 13), Vector2(42, -18), Vector2(70, 0)]), 7.0, Color(0.72, 1.0, 0.76, 0.88))


func _preview_restore(phase: String, progress: float) -> void:
	_hide_all()
	var bottle := _visuals["bottle"] as AnimatedSprite2D
	var outer := _visuals["outer"] as AnimatedSprite2D
	var inner := _visuals["inner"] as Line2D
	var shards := _visuals["shards"] as Polygon2D
	var shield := _visuals["shield"] as Polygon2D
	var target := Vector2(70, 24)
	match phase:
		"windup":
			# The flask holds its intact frame on the aimed arc and burns through
			# the cast pack only when it shatters at range.
			_play(bottle, 0.42 + progress * 0.45, 0.0)
			bottle.position = _quadratic(Vector2(-178, 54), Vector2(-40, -190), target, progress)
			bottle.rotation = -1.0 + progress * 2.1
			bottle.scale = Vector2.ONE * (0.52 + progress * 0.32)
		"release":
			_play(bottle, 1.0 - progress * 0.55, progress)
			bottle.position = target
			bottle.scale = Vector2.ONE * (0.84 + sin(progress * PI) * 0.22)
			_show(shards, 0.92)
			shards.position = target
			shards.scale = Vector2.ONE * (0.25 + progress * 1.15)
		"active":
			_play(bottle, 0.42, 1.0)
			bottle.position = target + Vector2(0, -82)
			bottle.rotation = 1.18
			bottle.scale = Vector2.ONE * 0.48
			_play(outer, 0.86 - progress * 0.20, progress * POOL_ACTIVE_PLAYS)
			outer.position = target
			outer.scale = Vector2.ONE * (0.50 + progress * 0.72)
			outer.rotation = progress * -1.3
			_show(inner, 0.96 - progress * 0.18)
			inner.position = target
			inner.scale = Vector2.ONE * (0.62 + sin(progress * PI) * 0.18)
			inner.rotation = progress * 2.6
			_show(shield, clampf((progress - 0.28) * 1.8, 0.0, 0.82))
			shield.position = Vector2(-72, 20)
			shield.scale = Vector2.ONE * (0.45 + progress * 0.42)
		"recovery":
			# The pool keeps counting from where `active` left it, so the loop
			# closes across the phase boundary instead of snapping back to frame 0.
			_play(outer, (1.0 - progress) * 0.46, POOL_ACTIVE_PLAYS + progress)
			outer.position = target
			outer.scale = Vector2.ONE * (1.22 + progress * 0.20)
			_show(inner, (1.0 - progress) * 0.68)
			inner.position = target
			inner.rotation = 2.6 + progress * 1.2
			_show(shield, (1.0 - progress) * 0.86)
			shield.position = Vector2(-72, 20)
			shield.scale = Vector2.ONE * (0.86 + sin(progress * PI) * 0.08)
		"cancel":
			_show(shield, (1.0 - progress) * 0.35)
			shield.position = Vector2(-72, 20)


func _preview_plague(phase: String, progress: float) -> void:
	_hide_all()
	var syringe := _visuals["syringe"] as AnimatedSprite2D
	var patient := _visuals["patient"] as Line2D
	var veins_a := _visuals["veins_a"] as Line2D
	var veins_b := _visuals["veins_b"] as Line2D
	var target := Vector2(24, 8)
	match phase:
		"windup":
			# The syringe is carried intact and discharges its cast pack only on
			# the pierce, then holds the emptied frame while the waves run.
			_play(syringe, 0.48 + progress * 0.46, 0.0)
			syringe.position = Vector2(-188, -96).lerp(Vector2(-52, -20), progress)
			syringe.rotation = 0.58
			syringe.scale = Vector2.ONE * (0.58 + progress * 0.20)
			_show(patient, 0.28 + progress * 0.32)
			patient.position = target
			patient.scale = Vector2.ONE * (0.72 + progress * 0.18)
		"release":
			_play(syringe, 0.98, progress)
			syringe.position = Vector2(-52, -20).lerp(target, progress)
			syringe.rotation = 0.58 + progress * 0.28
			syringe.scale = Vector2.ONE * 0.82
			_show(patient, 0.94)
			patient.position = target
			patient.scale = Vector2.ONE * (0.90 + sin(progress * PI) * 0.30)
		"active":
			_play(syringe, 0.50, 1.0)
			syringe.position = target + Vector2(-62, -38)
			syringe.rotation = 0.86
			syringe.scale = Vector2.ONE * 0.62
			_show(patient, 0.88 - progress * 0.24)
			patient.position = target
			patient.rotation = progress * 2.0
			for vein in [veins_a, veins_b]:
				_show(vein, 0.78 - progress * 0.18)
				vein.position = target
				vein.scale = Vector2.ONE * (0.35 + progress * 0.82)
			_update_wave(_visuals["wave_a"] as AnimatedSprite2D, target, progress * 3.0)
			_update_wave(_visuals["wave_b"] as AnimatedSprite2D, target, progress * 3.0 - 0.82)
			_update_wave(_visuals["wave_c"] as AnimatedSprite2D, target, progress * 3.0 - 1.64)
		"recovery":
			var mask := _visuals["mask"] as Polygon2D
			_show(mask, 0.86 * (1.0 - progress))
			mask.position = target + Vector2(0, -12)
			mask.scale = Vector2.ONE * (0.42 + progress * 1.15)
			for vein in [veins_a, veins_b]:
				_show(vein, 0.44 * (1.0 - progress))
				vein.position = target
				vein.scale = Vector2.ONE * 1.18
		"cancel":
			_show(patient, 0.26 * (1.0 - progress))
			patient.position = target


func _preview_saw(phase: String, progress: float) -> void:
	_hide_all()
	var center := Vector2.ZERO
	var radius := 56.0
	var turns := 0.0
	var alpha := 0.9
	# Turns are cumulative across the phases: a per-phase count would snap the
	# orbit — and the serration pack riding it — back to zero at every boundary.
	match phase:
		"windup":
			radius = lerpf(28.0, 58.0, progress)
			turns = progress * 0.35
			alpha = 0.45 + progress * 0.45
		"release":
			radius = lerpf(58.0, 105.0, progress)
			turns = 0.35 + progress * 1.2
		"active":
			radius = 105.0 + sin(progress * TAU * 4.0) * 12.0
			turns = 1.55 + progress * 5.5
		"recovery":
			radius = lerpf(105.0, 40.0, progress)
			turns = 7.05 + progress * 0.8
			alpha = 0.88 * (1.0 - progress * 0.45)
		"cancel":
			radius = 40.0
			turns = 7.85
			alpha = 0.42 * (1.0 - progress)
	for index in 3:
		var saw := _visuals["saw_%d" % index] as AnimatedSprite2D
		var angle := turns * TAU + TAU * float(index) / 3.0
		# The saws burn through the cast pack as they snap out of the surgical
		# stance and then hold the finished blade for the rest of the orbit.
		_play(saw, alpha, turns)
		saw.position = center + Vector2.from_angle(angle) * radius
		saw.rotation = angle + progress * 3.5
		saw.scale = Vector2.ONE * (0.38 + (0.08 if phase == "active" else 0.0))
	var arc := _visuals["arc"] as AnimatedSprite2D
	# One pass of the serration pack per revolution of the orbit it draws.
	_play(arc, 0.76 if phase in ["release", "active"] else 0.32 * (1.0 - progress), turns)
	arc.scale = Vector2.ONE * (radius / 112.0)
	arc.rotation = turns * TAU
	if phase == "active":
		var sparks := _visuals["sparks"] as Line2D
		_show(sparks, 0.78)
		sparks.rotation = turns * TAU * 0.7
		for key in ["drain_a", "drain_b"]:
			var ribbon := _visuals[key] as Line2D
			_show(ribbon, 0.68 + sin(progress * PI) * 0.18)
			ribbon.scale = Vector2.ONE * (0.72 + progress * 0.22)
	elif phase == "recovery":
		var stitches := _visuals["stitches"] as Line2D
		_show(stitches, 0.92 * (1.0 - progress))
		stitches.scale = Vector2(progress, 1.0)


## One staggered infection wave: the pack runs exactly one pass over the pulse,
## so a wave never restarts its loop while it is still on screen.
func _update_wave(wave: AnimatedSprite2D, position: Vector2, pulse: float) -> void:
	if pulse < 0.0 or pulse > 1.0:
		return
	_play(wave, sin(pulse * PI) * 0.78, pulse)
	wave.position = position
	wave.scale = Vector2.ONE * ((0.48 + pulse * 2.25) * WAVE_PACK_SCALE)


func _flipbook(node_name: String, frames: SpriteFrames) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = node_name
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var animation := _pack_animation(frames)
	if animation.is_empty():
		push_error("DoctorUltimateTimelineScene: %s/%s has no animated pack" % [weapon_id, node_name])
	else:
		sprite.sprite_frames = frames
		sprite.animation = animation
	add_child(sprite)
	return sprite


## `plays` counts whole passes through the pack, so a looping pack wraps at its
## authored loop-closure frame and a one-shot pack holds its last frame. Nothing
## reads a wall clock: the drawn frame is a function of the timeline alone.
func _play(sprite: AnimatedSprite2D, alpha: float, plays: float) -> void:
	_show(sprite, alpha)
	sprite.frame = _pack_frame(sprite, plays)


static func _pack_frame(sprite: AnimatedSprite2D, plays: float) -> int:
	var frames := sprite.sprite_frames
	if frames == null:
		return 0
	var animation := sprite.animation
	var count := frames.get_frame_count(animation)
	if count <= 0:
		return 0
	var index := floori(plays * float(count))
	if frames.get_animation_loop(animation):
		return posmod(index, count)
	return clampi(index, 0, count - 1)


## A FAN-3613 pack carries exactly one animation, named after its effect.
static func _pack_animation(frames: SpriteFrames) -> StringName:
	if frames == null:
		return &""
	var names := frames.get_animation_names()
	return StringName(names[0]) if names.size() > 0 else &""


func _line(node_name: String, points: PackedVector2Array, width: float, color: Color, closed := false) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.width = width
	line.default_color = color
	line.closed = closed
	line.antialiased = true
	add_child(line)
	return line


func _polygon(node_name: String, points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	add_child(polygon)
	return polygon


func _hide_all() -> void:
	for visual in _visuals.values():
		(visual as CanvasItem).visible = false


func _show(visual: CanvasItem, alpha: float) -> void:
	visual.visible = alpha > 0.01
	visual.modulate.a = clampf(alpha, 0.0, 1.0)


func _clear_visuals() -> void:
	for visual in _visuals.values():
		if is_instance_valid(visual):
			(visual as Node).free()
	_visuals.clear()


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count:
		points.append(Vector2.from_angle(TAU * float(index) / float(count)) * radius)
	return points


func _spiral_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count:
		var progress := float(index) / float(maxi(count - 1, 1))
		points.append(Vector2.from_angle(progress * TAU * 2.5) * radius * progress)
	return points


func _quadratic(start: Vector2, control: Vector2, finish: Vector2, weight: float) -> Vector2:
	return start * (1.0 - weight) * (1.0 - weight) + control * 2.0 * (1.0 - weight) * weight + finish * weight * weight
