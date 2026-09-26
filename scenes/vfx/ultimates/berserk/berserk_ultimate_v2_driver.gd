class_name BerserkUltimateV2Driver
extends Node2D

## Shared Ultimate Direction v2 runtime driver for the Berserk trio (FAN-3012).
##
## Same device contract as ChemistAcidFlaskV2 (FAN-2958): the AnimationPlayer
## owns every drawn beat (the FAN-3005 flipbooks, the cast flash, the collapse
## flare, the backdrop veil tint), this script owns only the node-free weight
## devices the v2 presence block declares — viewport-fitted backdrop coverage,
## camera shake, the hitstop freeze on the first bite and SFX ducking during
## release. Per-scene beats arrive as export overrides so one driver serves
## sword, axe and hammer without per-scene script forks. Every device restores
## its exact pre-cast state on pause, finish, scene exit and repeated
## activation, so no orphan offsets, buses or timers survive the effect.

## Cumulative beats, mirrored from the class manifest timing_seconds.
@export var release_at := 0.75
@export var impact_at := 1.0
@export var recovery_at := 3.1
@export var cancel_at := 3.8

## Presence knobs from the manifest presence block.
@export var hitstop_ms := 120.0
@export var shake_seconds := 0.55
@export var shake_amplitude := 9.0
@export var sfx_duck_db := -9.0

## Reduced motion: every flash beat keeps its timing at a damped peak, so the
## calm variant is a fade, never a flash.
const REDUCED_MOTION_FLASH_ALPHA := 0.45

## The veil is refitted from a float division by the camera zoom; a hair of
## overscan keeps the screen edges covered instead of showing a rounding seam.
const BACKDROP_OVERSCAN := 1.02

## Overlapping activations share one duck: the first one that ducks records the
## pre-cast volume, the last one that releases restores it.
static var _duck_refs := 0
static var _duck_volume_before_db := 0.0

var _elapsed := 0.0
var _paused := false
var _hitstop_remaining := 0.0
var _shake_remaining := 0.0
var _impact_fired := false
var _duck_active := false
var _sfx_bus_index := -1
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO


func _ready() -> void:
	set_process(true)
	if not _screen_shake_enabled():
		_apply_reduced_motion()


## The hitstop freezes the drawn timeline, never the envelope clock: the shared
## presentation timeline keeps counting real time, so a clock that skipped the
## freeze would drift behind every declared beat and outlive the manifest
## cancel by the same amount.
func _process(delta: float) -> void:
	if _paused:
		return
	_fit_backdrop_to_viewport()
	_elapsed += delta
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(_hitstop_remaining - delta, 0.0)
		if _hitstop_remaining <= 0.0:
			_resume_timeline()
		else:
			return
	if not _impact_fired and _elapsed >= impact_at:
		_impact_fired = true
		_hitstop_remaining = hitstop_ms / 1000.0
		_shake_remaining = shake_seconds
		_pause_timeline()
	if _elapsed >= release_at and _elapsed < recovery_at:
		_begin_sfx_ducking()
	elif _duck_active:
		_end_sfx_ducking()
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - delta, 0.0)
		_apply_camera_shake(_shake_remaining)
	if _elapsed >= cancel_at:
		finish("node_end")


## AnimationPlayer has no `paused` property; pause()/play() is the whole API.
## An in-flight hitstop keeps the timeline held after the game unpauses.
func set_paused(value: bool) -> void:
	_paused = value
	if value:
		_pause_timeline()
	elif _hitstop_remaining <= 0.0:
		_resume_timeline()


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
	var veil := get_node_or_null("BackdropVeil") as Sprite2D
	if veil == null or veil.texture == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()
	# The veil draws in world units, the visible rect is screen pixels: without
	# the zoom division a battle zoom below 1 leaves the screen edges uncovered.
	var visible_size: Vector2 = rect.size / camera.zoom if camera != null else rect.size
	var overscan := visible_size * (BACKDROP_OVERSCAN - 1.0) * 0.5
	var size := visible_size + overscan * 2.0
	veil.top_level = true
	veil.position = viewport.get_canvas_transform().affine_inverse() * rect.position - overscan
	veil.scale = size / veil.texture.get_size()


func _pause_timeline() -> void:
	var timeline := get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null and timeline.is_playing():
		timeline.pause()


## play() without a name resumes the assigned animation; with nothing ever
## assigned (a scene stepped before autoplay) there is nothing to resume.
func _resume_timeline() -> void:
	var timeline := get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null and not timeline.is_playing() and not _paused \
			and not timeline.assigned_animation.is_empty():
		timeline.play()


## Motion toggle, read exactly like enemy.gd and combat_director: main mirrors
## GameSettings.screen_shake onto the tree root for scripts without a game ref.
func _screen_shake_enabled() -> bool:
	var tree := get_tree()
	return tree == null or bool(tree.root.get_meta("screen_shake", true))


## Reduced-motion variant, declared in the class manifest quality record: the
## camera never moves and every flash beat plays as a damped fade.
func _apply_reduced_motion() -> void:
	var veil := get_node_or_null("BackdropVeil") as CanvasItem
	if veil != null:
		veil.self_modulate.a = REDUCED_MOTION_FLASH_ALPHA


## Impact shake, decaying with the remaining window. The player's screen_shake
## toggle is the whole gate: with it off the camera offset never moves.
func _apply_camera_shake(remaining: float) -> void:
	if not _screen_shake_enabled():
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = _find_current_camera()
		if _camera == null:
			return
		_camera_offset_before_shake = _camera.offset
	var strength := shake_amplitude * (remaining / shake_seconds)
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
	if _duck_refs == 0:
		_duck_volume_before_db = AudioServer.get_bus_volume_db(_sfx_bus_index)
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db + sfx_duck_db)
	_duck_refs += 1


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	_duck_refs = maxi(_duck_refs - 1, 0)
	if _duck_refs == 0 and _sfx_bus_index != -1 \
			and is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), _duck_volume_before_db + sfx_duck_db):
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db)
	_sfx_bus_index = -1
