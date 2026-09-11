class_name RobotUltimateTimelineScene
extends Node2D

## Scene driver for one Robot ultimate presentation timeline.
## It owns only its local sprites and delegates pause and every teardown path
## to the shared, testable timeline lifecycle.

const Pack := preload("res://scenes/vfx/ultimates/robot/robot_ultimate_presentation_pack.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const IMPACT_FRAMES := {
	Pack.MAGNETIC_ANCHOR: preload("res://assets/sprites/effects/robot/magnetic_anchor/magnetic_anchor_spriteframes.tres"),
	Pack.HYDRAULIC_PRESS: preload("res://assets/sprites/effects/robot/hydraulic_press/hydraulic_press_spriteframes.tres"),
	Pack.REACTOR_CORE: preload("res://assets/sprites/effects/robot/reactor_core/reactor_core_spriteframes.tres"),
}

const CLEANUP_REASONS: Array[String] = ["cancel", "death", "node_end"]
const BACKDROP_OVERSCAN := 1.02

@export var weapon_id: String = Pack.MAGNETIC_ANCHOR

signal phase_entered(phase: Dictionary)
signal timeline_finished(reason: String)

var _timeline = null
var _manifest: Dictionary = {}
var _elements: Array[Sprite2D] = []
var _impacts: Node2D = null
var _impacts_started := false
var _paused := false
var _impact_fired := false
var _hitstop_remaining := 0.0
var _hitstop_pose := 0.0
var _shake_remaining := 0.0
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _duck_active := false
var _sfx_bus_index := -1
static var _duck_refs := 0
static var _duck_volume_before_db := 0.0
static var _duck_applied_db := 0.0


func _enter_tree() -> void:
	_apply_identity_metadata()
	_ensure_backdrop()


func _ready() -> void:
	_reset_backdrop()
	set_process(false)


func begin(registry, handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	finish("node_end")
	_apply_identity_metadata()
	_manifest = Pack.manifest_for(registry, weapon_id)
	if _manifest.is_empty():
		push_error("RobotUltimateTimelineScene: no manifest for %s" % weapon_id)
		return {}
	_timeline = Timeline.new(_manifest, headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_build_elements()
		_apply_presence(0.0)
		_apply_formation(0.0)
		set_process(true)
	return snapshot


func set_paused(value: bool) -> void:
	_paused = value
	if _timeline != null:
		_timeline.set_paused(value)


func is_active() -> bool:
	return _timeline != null and str(_timeline.snapshot().get("state", "")) == Timeline.ACTIVE_STATE


func finish(reason: String) -> Dictionary:
	if _timeline == null:
		_clear_elements()
		_finish_impacts()
		_end_camera_shake()
		_end_sfx_ducking()
		_reset_backdrop()
		return {}
	var snapshot := _release_handles(reason)
	_clear_elements()
	_finish_impacts()
	_end_camera_shake()
	_end_sfx_ducking()
	_reset_backdrop()
	_impact_fired = false
	_hitstop_remaining = 0.0
	_shake_remaining = 0.0
	_paused = false
	set_process(false)
	timeline_finished.emit(reason)
	return snapshot


func step(delta: float) -> void:
	if _timeline == null:
		return
	for event in _timeline.advance(delta):
		phase_entered.emit(event)
	var elapsed: float = _timeline.elapsed_seconds()
	if not _paused:
		_advance_presence(delta, elapsed)
	_apply_presence(_drawn_elapsed(elapsed))
	_apply_formation(_drawn_elapsed(elapsed))
	if _timeline != null and elapsed >= Pack.timeline_seconds(weapon_id):
		finish("node_end")


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_handles("node_end")
		_end_camera_shake()
		_end_sfx_ducking()


func _apply_identity_metadata() -> void:
	var config := Pack.weapon_config(weapon_id)
	set_meta("ultimate_id", "%s/%s" % [Pack.CLASS_ID, weapon_id])
	set_meta("silhouette", str(config.get("silhouette", "")))
	set_meta("motion_path", str(config.get("motion", "")))
	set_meta("impact_language", str(config.get("impact", "")))
	set_meta("max_visual_nodes", int((config.get("formation", {}) as Dictionary).get("count", 0)) + 1)
	set_meta("crowd_cap", Pack.MAX_ELEMENTS_PER_ULTIMATE)
	set_meta("max_unique_materials", Pack.MAX_UNIQUE_MATERIALS)
	set_meta("max_fullscreen_materials", Pack.MAX_FULLSCREEN_MATERIALS)
	set_meta("presence", Pack.presence_for(weapon_id))
	set_meta("identity", Pack.identity_for(weapon_id))


func _ensure_backdrop() -> void:
	if get_node_or_null(Pack.BACKDROP_NODE) != null:
		return
	var veil := Polygon2D.new()
	veil.name = Pack.BACKDROP_NODE
	veil.z_index = -100
	veil.set_meta("fullscreen_layer", true)
	add_child(veil)


func _backdrop() -> Polygon2D:
	return get_node_or_null(Pack.BACKDROP_NODE) as Polygon2D


func _reset_backdrop() -> void:
	var veil := _backdrop()
	if veil != null:
		veil.visible = false
		veil.color.a = 1.0
		veil.self_modulate.a = 0.0


func _apply_presence(elapsed: float) -> void:
	var veil := _backdrop()
	if veil == null or not is_inside_tree():
		return
	var config := Pack.weapon_config(weapon_id)
	var timing := config.get("timing", {}) as Dictionary
	var release := float(timing.get("release", 0.8))
	var recovery := float(timing.get("recovery", 3.2))
	var cancel := float(timing.get("cancel", 3.8))
	var alpha := 0.0
	if elapsed < release:
		alpha = lerpf(0.0, 0.62, elapsed / maxf(release, 0.001))
	elif elapsed < recovery:
		alpha = 0.62
	else:
		alpha = lerpf(0.62, 0.0, (elapsed - recovery) / maxf(cancel - recovery, 0.001))
	if not _screen_shake_enabled():
		alpha = minf(alpha, 0.42)
	var tint: Color = config.get("backdrop_tint", Color.BLACK)
	veil.color = Color(tint.r, tint.g, tint.b, 1.0)
	veil.self_modulate = Color(1.0, 1.0, 1.0, alpha)
	veil.visible = alpha > 0.0
	_fit_backdrop_to_viewport()


func _fit_backdrop_to_viewport() -> void:
	var veil := _backdrop()
	if veil == null or not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()
	var visible_size: Vector2 = rect.size / camera.zoom if camera != null else rect.size
	var overscan := visible_size * (BACKDROP_OVERSCAN - 1.0) * 0.5
	var origin: Vector2 = viewport.get_canvas_transform().affine_inverse() * rect.position - overscan
	var size := visible_size + overscan * 2.0
	veil.top_level = true
	veil.polygon = PackedVector2Array([origin, origin + Vector2(size.x, 0.0), origin + size, origin + Vector2(0.0, size.y)])


func _drawn_elapsed(elapsed: float) -> float:
	return _hitstop_pose if _hitstop_remaining > 0.0 else elapsed


func _advance_presence(delta: float, elapsed: float) -> void:
	var config := Pack.weapon_config(weapon_id)
	var presence := config.get("presence", {}) as Dictionary
	var shake := config.get("shake", {}) as Dictionary
	var timing := config.get("timing", {}) as Dictionary
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(_hitstop_remaining - delta, 0.0)
	elif not _impact_fired and elapsed >= float(timing.get("active", INF)):
		_impact_fired = true
		_hitstop_pose = elapsed
		_hitstop_remaining = float(presence.get("hitstop_ms", 0.0)) / 1000.0
		_shake_remaining = float(shake.get("seconds", 0.0))
	if elapsed >= float(timing.get("release", INF)) and elapsed < float(timing.get("recovery", 0.0)):
		_begin_sfx_ducking(float(shake.get("duck_db", 0.0)))
	elif _duck_active:
		_end_sfx_ducking()
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - delta, 0.0)
		_apply_camera_shake(_shake_remaining, float(shake.get("seconds", 1.0)), float(shake.get("amplitude", 0.0)))


func _screen_shake_enabled() -> bool:
	return not is_inside_tree() or bool(get_tree().root.get_meta("screen_shake", true))


func _apply_camera_shake(remaining: float, window: float, amplitude: float) -> void:
	if not _screen_shake_enabled() or amplitude <= 0.0:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
		if _camera == null:
			return
		_camera_offset_before_shake = _camera.offset
	var strength := amplitude * remaining / maxf(window, 0.001)
	_camera.offset = _camera_offset_before_shake + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


func _end_camera_shake() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset_before_shake
	_camera = null


func _begin_sfx_ducking(duck_db: float) -> void:
	if _duck_active or duck_db >= 0.0:
		return
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	if _sfx_bus_index == -1:
		return
	_duck_active = true
	if _duck_refs == 0:
		_duck_volume_before_db = AudioServer.get_bus_volume_db(_sfx_bus_index)
		_duck_applied_db = _duck_volume_before_db + duck_db
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_applied_db)
	_duck_refs += 1


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	_duck_refs = maxi(_duck_refs - 1, 0)
	if _duck_refs == 0 and _sfx_bus_index != -1 and is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), _duck_applied_db):
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db)
	_sfx_bus_index = -1


func seek_for_capture(seconds: float) -> void:
	if _elements.is_empty():
		_build_elements()
	_apply_presence(seconds)
	_apply_formation(seconds)
	set_meta("capture_seconds", seconds)
	set_process(false)
	set_meta("capture_seconds", seconds)
	set_process(false)


func _release_handles(reason: String) -> Dictionary:
	if _timeline == null:
		return {}
	var snapshot: Dictionary = _timeline.finish(reason)
	_timeline = null
	return snapshot


func _build_elements() -> void:
	_clear_elements()
	var texture: Texture2D = load(Pack.element_runtime_path(weapon_id))
	if texture == null:
		push_error("RobotUltimateTimelineScene: missing runtime frame for %s" % weapon_id)
		return
	var pivot: Dictionary = _manifest.get("pivot", {})
	var formation: Dictionary = Pack.weapon_config(weapon_id).get("formation", {})
	var count := mini(int(formation.get("count", 0)), Pack.MAX_ELEMENTS_PER_ULTIMATE)
	for index in count:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = -Vector2(texture.get_width() * float(pivot.get("x", 0.5)), texture.get_height() * float(pivot.get("y", 0.5)))
		add_child(sprite)
		_elements.append(sprite)


func _clear_elements() -> void:
	for sprite in _elements:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_elements.clear()


func present(_event_id: String, payload: Dictionary) -> void:
	var victims: Variant = payload.get("victims", [])
	if not victims is Array or (victims as Array).is_empty():
		return
	var frames := IMPACT_FRAMES.get(weapon_id, null) as SpriteFrames
	if frames == null:
		push_error("RobotUltimateTimelineScene: missing victim-impact frames for %s" % weapon_id)
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(victims as Array, global_position)
	else:
		_impacts.play(frames, victims as Array, global_position)
		_impacts_started = true


func _finish_impacts() -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()
	_impacts = null
	_impacts_started = false


func _apply_formation(elapsed: float) -> void:
	if _elements.is_empty():
		return
	var phase := Pack.phase_at(weapon_id, elapsed)
	var points := Pack.formation_points(weapon_id, str(phase.get("name", "")), float(phase.get("progress", 0.0)))
	for index in _elements.size():
		var sprite := _elements[index]
		if index >= points.size():
			sprite.visible = false
			continue
		var point: Dictionary = points[index]
		var alpha := float(point.get("alpha", 1.0))
		var tint: Color = Pack.weapon_config(weapon_id).get("tint", Color.WHITE)
		sprite.visible = alpha > 0.0
		sprite.position = point.get("position", Vector2.ZERO)
		sprite.scale = Vector2.ONE * float(point.get("scale", 1.0))
		sprite.rotation = float(point.get("rotation", 0.0))
		sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)
