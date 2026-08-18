class_name ChemistAcidFlaskV2
extends Node2D

## Ultimate Direction v2 runtime driver for «Царь-Колба» (FAN-2958).
##
## The AnimationPlayer owns every drawn beat (backdrop veil, hero glow, the
## PixelLab acid_flask frames, the arena-wide lake shoreline, the charge pillars
## and the evaporation smoke). This script owns only the node-free weight
## devices the v2 presence block declares: viewport-fitted backdrop coverage,
## camera shake, the hitstop freeze on the first impact and SFX ducking during
## release. Every device restores its exact pre-cast state on pause, finish,
## scene exit and repeated activation, so no orphan offsets, buses or timers
## survive the effect.

const RELEASE_AT := 0.85
const IMPACT_AT := 1.0
const RECOVERY_AT := 3.35
const CANCEL_AT := 3.95
const HITSTOP_MS := 110.0
const SHAKE_SECONDS := 0.55
const SHAKE_AMPLITUDE := 9.0
const SFX_DUCK_DB := -9.0

## Reduced motion: the release flash keeps its beats at a damped peak instead of
## the full acid-white burst, so the calm variant is a fade, not a flash.
const REDUCED_MOTION_FLASH_ALPHA := 0.45

## The veil is refitted from a float division by the camera zoom; a hair of
## overscan keeps the screen edges covered instead of showing a rounding seam.
const BACKDROP_OVERSCAN := 1.02

## Overlapping activations share one duck: the first one that ducks records the
## pre-cast volume, the last one that releases restores it. Per-instance capture
## cannot do this — a second cast records the already-ducked value as "before".
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
## freeze would drift 110ms behind every declared beat and outlive the manifest
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
## full-screen treatment; it is refitted every frame to the visible rect. The
## veil draws its gradient texture uncentered, so the fit is a top-left position
## plus a scale, exactly the corners the polygon used to carry.
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
	# the zoom division a battle zoom below 1 leaves the screen edges uncovered
	# (same conversion as aim_controller._view_rect).
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
## assigned (a scene stepped before autoplay) there is simply nothing to resume.
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


## Reduced-motion variant, declared in the class manifest: the camera never
## moves and the release flash plays as a damped fade. Every phase keeps its
## declared timing — only the intensity of the two motion devices changes.
func _apply_reduced_motion() -> void:
	for node_name in ["BackdropVeil", "AcidSurgeGlow"]:
		var item := get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.self_modulate.a = REDUCED_MOTION_FLASH_ALPHA


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
	if _duck_refs == 0:
		_duck_volume_before_db = AudioServer.get_bus_volume_db(_sfx_bus_index)
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db + SFX_DUCK_DB)
	_duck_refs += 1


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	_duck_refs = maxi(_duck_refs - 1, 0)
	if _duck_refs == 0 and _sfx_bus_index != -1 \
			and is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), _duck_volume_before_db + SFX_DUCK_DB):
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db)
	_sfx_bus_index = -1
