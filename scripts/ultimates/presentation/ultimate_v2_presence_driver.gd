class_name UltimateV2PresenceDriver
extends Node

## Composable presentation-only owner for Ultimate Direction v2 presence.
##
## Class scenes keep their existing root/executor scripts. This child owns only
## the viewport veil, a local AnimationPlayer hitstop, additive camera shake and
## a reference-counted SFX duck. It never writes Engine.time_scale or tree pause.

@export_node_path("AnimationPlayer") var timeline_path := NodePath("../Timeline")
@export_node_path("CanvasItem") var backdrop_path := NodePath("../BackdropVeil")

@export var release_at := 0.75
@export var impact_at := 1.0
@export var recovery_at := 3.0
@export var cancel_at := 3.7
@export_range(80.0, 150.0, 1.0) var hitstop_ms := 120.0
@export_range(0.0, 1.0, 0.01) var shake_seconds := 0.42
@export_range(0.0, 24.0, 0.1) var shake_amplitude := 7.0
@export_range(-24.0, 0.0, 0.1) var sfx_duck_db := -8.0

const REDUCED_MOTION_ALPHA := 0.55
const PHOTOSENSITIVITY_SAFE_ALPHA := 0.32
const BACKDROP_OVERSCAN_PIXELS := 4.0

## Bus-name keyed state makes overlapping scoped activations one reversible
## owner. An external volume write is never overwritten during restoration.
static var _duck_states: Dictionary = {}

var _elapsed := 0.0
var _hitstop_remaining := 0.0
var _shake_remaining := 0.0
var _impact_fired := false
var _manual_paused := false
var _finished := false

var _pause_reasons: Dictionary = {}
var _timeline_pause_owned := false
var _paused_animation := StringName()
var _paused_position := 0.0

var _duck_active := false
var _camera: Camera2D = null
var _camera_delta := Vector2.ZERO
var _backdrop: CanvasItem = null
var _backdrop_modulate_before := Color.WHITE


func _ready() -> void:
	_backdrop = get_node_or_null(backdrop_path) as CanvasItem
	if _backdrop != null:
		_backdrop_modulate_before = _backdrop.self_modulate
		_apply_accessibility_treatment()
	set_process(true)


func _process(delta: float) -> void:
	if _finished or _manual_paused:
		return
	_fit_backdrop_to_viewport()
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0001 else delta
	_elapsed += real_delta

	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(_hitstop_remaining - real_delta, 0.0)
		if _hitstop_remaining <= 0.0:
			_release_timeline_pause("hitstop")

	if not _impact_fired and _elapsed >= impact_at:
		_impact_fired = true
		_hitstop_remaining = hitstop_ms / 1000.0
		_shake_remaining = shake_seconds if _motion_enabled() else 0.0
		_request_timeline_pause("hitstop")

	if _elapsed >= release_at and _elapsed < recovery_at:
		_begin_sfx_ducking()
	else:
		_end_sfx_ducking()

	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - real_delta, 0.0)
		_apply_camera_shake()
	elif _camera != null:
		_end_camera_shake()

	if _elapsed >= cancel_at:
		finish("node_end")


func set_paused(value: bool) -> void:
	if _finished or _manual_paused == value:
		return
	_manual_paused = value
	if value:
		_request_timeline_pause("manual")
	else:
		_release_timeline_pause("manual")


func finish(_reason: String) -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	_pause_reasons.clear()
	_resume_owned_timeline()
	_end_sfx_ducking()
	_end_camera_shake()
	_restore_backdrop()
	_hitstop_remaining = 0.0
	_shake_remaining = 0.0


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		finish("node_end")


func _timeline() -> AnimationPlayer:
	return get_node_or_null(timeline_path) as AnimationPlayer


func _request_timeline_pause(reason: String) -> void:
	if _pause_reasons.has(reason):
		return
	_pause_reasons[reason] = true
	if _timeline_pause_owned:
		return
	var timeline := _timeline()
	if timeline == null or not timeline.is_playing():
		return
	_timeline_pause_owned = true
	_paused_animation = timeline.assigned_animation
	_paused_position = timeline.current_animation_position
	timeline.pause()


func _release_timeline_pause(reason: String) -> void:
	_pause_reasons.erase(reason)
	if _pause_reasons.is_empty():
		_resume_owned_timeline()


func _resume_owned_timeline() -> void:
	if not _timeline_pause_owned:
		return
	var timeline := _timeline()
	if timeline != null and not timeline.is_playing() \
			and timeline.assigned_animation == _paused_animation \
			and is_equal_approx(timeline.current_animation_position, _paused_position):
		timeline.play()
	_timeline_pause_owned = false
	_paused_animation = StringName()
	_paused_position = 0.0


func _fit_backdrop_to_viewport() -> void:
	if _backdrop == null or not is_instance_valid(_backdrop):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect().grow(BACKDROP_OVERSCAN_PIXELS)
	var inverse := viewport.get_canvas_transform().affine_inverse()
	var corners := PackedVector2Array([
		inverse * rect.position,
		inverse * Vector2(rect.end.x, rect.position.y),
		inverse * rect.end,
		inverse * Vector2(rect.position.x, rect.end.y),
	])
	if _backdrop is Polygon2D:
		var polygon := _backdrop as Polygon2D
		polygon.top_level = true
		polygon.global_position = Vector2.ZERO
		polygon.polygon = corners
	elif _backdrop is Sprite2D:
		var sprite := _backdrop as Sprite2D
		if sprite.texture == null:
			return
		var bounds := Rect2(corners[0], Vector2.ZERO)
		for point in corners:
			bounds = bounds.expand(point)
		sprite.top_level = true
		sprite.global_position = bounds.get_center()
		sprite.scale = bounds.size / sprite.texture.get_size()


func _apply_accessibility_treatment() -> void:
	if _backdrop == null:
		return
	var multiplier := 1.0
	if not _combat_feedback_enabled():
		multiplier = PHOTOSENSITIVITY_SAFE_ALPHA
	elif not _screen_shake_enabled():
		multiplier = REDUCED_MOTION_ALPHA
	var treated := _backdrop_modulate_before
	treated.a *= multiplier
	_backdrop.self_modulate = treated


func _restore_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.self_modulate = _backdrop_modulate_before


func _motion_enabled() -> bool:
	return _screen_shake_enabled() and _combat_feedback_enabled()


func _screen_shake_enabled() -> bool:
	var tree := get_tree()
	return tree == null or bool(tree.root.get_meta("screen_shake", true))


func _combat_feedback_enabled() -> bool:
	var tree := get_tree()
	return tree == null or bool(tree.root.get_meta("combat_feedback", true))


func _apply_camera_shake() -> void:
	if not _motion_enabled() or shake_seconds <= 0.0:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = _find_current_camera()
		_camera_delta = Vector2.ZERO
	if _camera == null:
		return
	var base := _camera.offset - _camera_delta
	var strength := shake_amplitude * (_shake_remaining / shake_seconds)
	_camera_delta = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	_camera.offset = base + _camera_delta


func _end_camera_shake() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset -= _camera_delta
	_camera = null
	_camera_delta = Vector2.ZERO


func _find_current_camera() -> Camera2D:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	for node in tree.root.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		if camera != null and camera.enabled and camera.is_current():
			return camera
	return null


func _begin_sfx_ducking() -> void:
	if _duck_active:
		return
	var bus_index := AudioServer.get_bus_index("SFX")
	if bus_index == -1:
		return
	_duck_active = true
	var state := _duck_states.get("SFX", {}) as Dictionary
	if state.is_empty():
		var before := AudioServer.get_bus_volume_db(bus_index)
		state = {"refs": 0, "before": before, "owned": before + sfx_duck_db}
		AudioServer.set_bus_volume_db(bus_index, float(state["owned"]))
	state["refs"] = int(state.get("refs", 0)) + 1
	_duck_states["SFX"] = state


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	var state := _duck_states.get("SFX", {}) as Dictionary
	if state.is_empty():
		return
	state["refs"] = maxi(int(state.get("refs", 1)) - 1, 0)
	if int(state["refs"]) > 0:
		_duck_states["SFX"] = state
		return
	var bus_index := AudioServer.get_bus_index("SFX")
	if bus_index != -1 and is_equal_approx(
		AudioServer.get_bus_volume_db(bus_index), float(state.get("owned", 0.0))
	):
		AudioServer.set_bus_volume_db(bus_index, float(state.get("before", 0.0)))
	_duck_states.erase("SFX")
