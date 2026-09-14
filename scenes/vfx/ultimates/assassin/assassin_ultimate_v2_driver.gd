class_name AssassinUltimateV2Driver
extends Node2D

## Class-local weight and accessibility devices for the Assassin v2 trio.
## The authored AnimationPlayer remains the visual source of truth; this driver
## owns only camera/audio weight, a frame-local hitstop and safe substitutions.

const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")

@export var release_at := 0.8
@export var impact_at := 1.0
@export var recovery_at := 3.0
@export var cancel_at := 3.6
@export var hitstop_ms := 110.0
@export var shake_seconds := 0.48
@export var shake_amplitude := 7.0
@export var sfx_duck_db := -8.0
@export var photosensitive_nodes := PackedStringArray()

const BACKDROP_PATH := NodePath("BackdropLayer/BackdropVeil")
const REDUCED_BACKDROP_ALPHA := 0.72
const PHOTO_BACKDROP_ALPHA := 0.58

static var _duck_refs := 0
static var _duck_volume_before_db := 0.0

var _elapsed := 0.0
var _paused := false
var _impact_fired := false
var _hitstop_remaining := 0.0
var _shake_remaining := 0.0
var _reduced_motion := false
var _photosensitivity_safe := false
var _disabled_tracks: Array[int] = []
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _duck_active := false
var _sfx_bus_index := -1


func _ready() -> void:
	process_priority = 1000
	_apply_accessibility_snapshot()
	set_process(true)


## Runtime-compatible signature. The registry and handles stay owned by the
## shared presentation runtime; the scene only restarts its authored timeline.
func begin(registry = null, _handles: Dictionary = {}, _headless_mode := -1) -> Dictionary:
	_reset_run()
	_apply_accessibility_snapshot()
	var timeline := _timeline()
	if timeline != null:
		timeline.play(&"ultimate")
		timeline.seek(0.0, true)
	set_process(true)
	return presence_snapshot()


func _process(delta: float) -> void:
	if _paused:
		return
	_elapsed += maxf(delta, 0.0)
	if not _impact_fired and _elapsed >= impact_at:
		_impact_fired = true
		_hitstop_remaining = hitstop_ms / 1000.0
		_shake_remaining = shake_seconds
		_pause_timeline()
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(_hitstop_remaining - delta, 0.0)
		if _hitstop_remaining <= 0.0:
			_resume_timeline_at_clock()
	if _elapsed >= release_at and _elapsed < recovery_at:
		_begin_sfx_ducking()
	else:
		_end_sfx_ducking()
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - delta, 0.0)
		_apply_camera_shake(_shake_remaining)
	_apply_frame_safety()
	if _elapsed >= cancel_at:
		finish("node_end")


func set_paused(value: bool) -> void:
	_paused = value
	if value:
		_pause_timeline()
	elif _hitstop_remaining <= 0.0:
		_resume_timeline_at_clock()


func finish(_reason: String) -> void:
	set_process(false)
	var timeline := _timeline()
	if timeline != null:
		timeline.stop()
	_end_sfx_ducking()
	_end_camera_shake()
	_hitstop_remaining = 0.0
	_shake_remaining = 0.0


func presence_snapshot() -> Dictionary:
	return {
		"reduced_motion": _reduced_motion,
		"photosensitivity_safe": _photosensitivity_safe,
		"motion_tracks_disabled": _disabled_tracks.size(),
		"photosensitive_nodes": photosensitive_nodes.size(),
		"hitstop_ms": hitstop_ms,
		"camera_shake": not _reduced_motion and _screen_shake_enabled(),
		"sfx_ducking": true,
	}


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_end_sfx_ducking()
		_end_camera_shake()


func _reset_run() -> void:
	_end_sfx_ducking()
	_end_camera_shake()
	_elapsed = 0.0
	_paused = false
	_impact_fired = false
	_hitstop_remaining = 0.0
	_shake_remaining = 0.0
	_restore_motion_tracks()


func _apply_accessibility_snapshot() -> void:
	var tree := get_tree() if is_inside_tree() else null
	var snapshot := Accessibility.read_snapshot(tree.root if tree != null else null)
	_reduced_motion = bool(snapshot[Accessibility.REDUCED_MOTION_KEY])
	_photosensitivity_safe = bool(snapshot[Accessibility.PHOTOSENSITIVITY_SAFE_KEY])
	set_meta(Accessibility.REDUCED_MOTION_KEY, _reduced_motion)
	set_meta(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, _photosensitivity_safe)
	_restore_motion_tracks()
	if _reduced_motion:
		_disable_fast_motion_tracks()
	_apply_frame_safety()


## Rotation, travel, scale rushes and flipbook stepping are the fast channels.
## Alpha tracks keep the release/active/recovery composition and exact timing.
func _disable_fast_motion_tracks() -> void:
	var timeline := _timeline()
	if timeline == null or not timeline.has_animation(&"ultimate"):
		return
	var animation := timeline.get_animation(&"ultimate")
	for track in animation.get_track_count():
		var property := str(animation.track_get_path(track).get_concatenated_subnames())
		if property == "rotation" or property == "position" or property == "scale" or property == "frame":
			animation.track_set_enabled(track, false)
			_disabled_tracks.append(track)
			if property == "scale":
				var target_path := NodePath(str(animation.track_get_path(track).get_concatenated_names()))
				var target := get_node_or_null(target_path) as Node2D
				if target != null:
					target.scale = Vector2.ONE


func _restore_motion_tracks() -> void:
	var timeline := _timeline()
	if timeline != null and timeline.has_animation(&"ultimate"):
		var animation := timeline.get_animation(&"ultimate")
		for track in _disabled_tracks:
			if track >= 0 and track < animation.get_track_count():
				animation.track_set_enabled(track, true)
	_disabled_tracks.clear()
	for path in photosensitive_nodes:
		var item := get_node_or_null(NodePath(path)) as CanvasItem
		if item != null:
			item.show()


func _apply_frame_safety() -> void:
	var backdrop := get_node_or_null(BACKDROP_PATH) as CanvasItem
	if backdrop != null:
		var cap := 1.0
		if _reduced_motion:
			cap = minf(cap, REDUCED_BACKDROP_ALPHA)
		if _photosensitivity_safe:
			cap = minf(cap, PHOTO_BACKDROP_ALPHA)
		backdrop.modulate.a = minf(backdrop.modulate.a, cap)
	for path in photosensitive_nodes:
		var item := get_node_or_null(NodePath(path)) as CanvasItem
		if item != null:
			if _photosensitivity_safe:
				item.modulate.a = minf(item.modulate.a, 0.12)


func _timeline() -> AnimationPlayer:
	return get_node_or_null("Timeline") as AnimationPlayer


func _pause_timeline() -> void:
	var timeline := _timeline()
	if timeline != null and timeline.is_playing():
		timeline.pause()


func _resume_timeline_at_clock() -> void:
	var timeline := _timeline()
	if timeline == null or _paused:
		return
	timeline.play(&"ultimate")
	timeline.seek(minf(_elapsed, cancel_at), true)


func _screen_shake_enabled() -> bool:
	var tree := get_tree() if is_inside_tree() else null
	return tree == null or bool(tree.root.get_meta("screen_shake", true))


func _apply_camera_shake(remaining: float) -> void:
	if _reduced_motion or not _screen_shake_enabled():
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = _find_current_camera()
		if _camera == null:
			return
		_camera_offset_before_shake = _camera.offset
	var strength := shake_amplitude * remaining / maxf(shake_seconds, 0.001)
	_camera.offset = _camera_offset_before_shake + Vector2(
		randf_range(-strength, strength), randf_range(-strength, strength)
	)
	if remaining <= 0.0:
		_end_camera_shake()


func _find_current_camera() -> Camera2D:
	var tree := get_tree() if is_inside_tree() else null
	if tree == null:
		return null
	for node in tree.root.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		if camera != null and camera.enabled and camera.is_current():
			return camera
	return null


func _end_camera_shake() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset_before_shake
	_camera = null


func _begin_sfx_ducking() -> void:
	if _duck_active:
		return
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	if _sfx_bus_index < 0:
		return
	_duck_active = true
	if _duck_refs == 0:
		_duck_volume_before_db = AudioServer.get_bus_volume_db(_sfx_bus_index)
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db + sfx_duck_db)
	_duck_refs += 1


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	_duck_refs = maxi(_duck_refs - 1, 0)
	if _duck_refs == 0 and _sfx_bus_index >= 0:
		var ducked := _duck_volume_before_db + sfx_duck_db
		if is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), ducked):
			AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db)
	_sfx_bus_index = -1
