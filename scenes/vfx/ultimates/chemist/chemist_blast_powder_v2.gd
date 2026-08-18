class_name ChemistBlastPowderV2
extends Node2D

## Ultimate Direction v2 runtime driver for «Философский Взрыв» (FAN-2957).
##
## The AnimationPlayer owns every drawn beat (backdrop veil, hero glow, the
## PixelLab blast_powder frames, the arena-wide pentagram sigile). This script
## owns only the node-free weight devices the v2 presence block declares:
## viewport-fitted backdrop coverage, camera shake, the hitstop freeze on the
## first impact and SFX ducking during release. Every device restores its
## exact pre-cast state on pause, finish, scene exit and repeated activation,
## so no orphan offsets, buses or timers survive the effect.

const RELEASE_AT := 0.95
const IMPACT_AT := 1.3
const RECOVERY_AT := 2.9
const CANCEL_AT := 3.6
const HITSTOP_MS := 110.0
const SHAKE_SECONDS := 0.55
const SHAKE_AMPLITUDE := 9.0
const SFX_DUCK_DB := -9.0

var _elapsed := 0.0
var _paused := false
var _hitstop_remaining := 0.0
var _shake_remaining := 0.0
var _impact_fired := false
var _duck_active := false
var _sfx_bus_index := -1
var _sfx_volume_before_duck_db := 0.0
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _paused:
		return
	_fit_backdrop_to_viewport()
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(_hitstop_remaining - delta, 0.0)
		if _hitstop_remaining <= 0.0:
			_resume_timeline()
		else:
			return
	_elapsed += delta
	if not _impact_fired and _elapsed >= IMPACT_AT:
		_impact_fired = true
		_hitstop_remaining = HITSTOP_MS / 1000.0
		_shake_remaining = SHAKE_SECONDS
		_pause_timeline()
	if _elapsed >= RELEASE_AT and _elapsed < RECOVERY_AT:
		_begin_sfx_ducking()
	elif _duck_active:
		_end_sfx_ducking()
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - delta, 0.0)
		_apply_camera_shake(_shake_remaining)
	if _elapsed >= CANCEL_AT:
		finish("node_end")


func set_paused(value: bool) -> void:
	_paused = value
	var timeline := get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null:
		timeline.paused = value


func finish(reason: String) -> void:
	set_process(false)
	_resume_timeline()
	_end_sfx_ducking()
	_end_camera_shake()
	_hitstop_remaining = 0.0
	_shake_remaining = 0.0
	_elapsed = 0.0
	_impact_fired = false


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		finish("node_end")


## The backdrop veil is a top-level child so the moving hero never shifts the
## full-screen treatment; it is refitted every frame to the visible rect.
func _fit_backdrop_to_viewport() -> void:
	var veil := get_node_or_null("BackdropVeil") as Polygon2D
	if veil == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect()
	var origin := viewport.get_canvas_transform().affine_inverse() * rect.position
	veil.top_level = true
	veil.position = origin
	veil.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(rect.size.x, 0.0),
		rect.size,
		Vector2(0.0, rect.size.y),
	])


func _pause_timeline() -> void:
	var timeline := get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null and timeline.is_playing():
		timeline.pause()


func _resume_timeline() -> void:
	var timeline := get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null and not timeline.is_playing() and not _paused:
		timeline.play()


## The first-impact freeze: the drawn timeline holds for HITSTOP_MS while the
## rest of the match keeps running, then resumes exactly where it stopped.
func _apply_camera_shake(remaining: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = _find_current_camera()
		if _camera == null:
			return
		_camera_offset_before_shake = _camera.offset
	var strength := SHAKE_AMPLITUDE * (remaining / SHAKE_SECONDS)
	_camera.offset = _camera_offset_before_shake + Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)
	if remaining <= 0.0:
		_end_camera_shake()


func _end_camera_shake() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset_before_shake
	_camera = null


func _find_current_camera() -> Camera2D:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	for node in tree.root.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		if camera != null and camera.is_current() and camera.enabled:
			return camera
	return null


func _begin_sfx_ducking() -> void:
	if _duck_active:
		return
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	if _sfx_bus_index == -1:
		return
	_duck_active = true
	_sfx_volume_before_duck_db = AudioServer.get_bus_volume_db(_sfx_bus_index)
	AudioServer.set_bus_volume_db(_sfx_bus_index, _sfx_volume_before_duck_db + SFX_DUCK_DB)


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	if _sfx_bus_index != -1 \
			and is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), _sfx_volume_before_duck_db + SFX_DUCK_DB):
		AudioServer.set_bus_volume_db(_sfx_bus_index, _sfx_volume_before_duck_db)
	_sfx_bus_index = -1
