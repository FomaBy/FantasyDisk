class_name ChemistHomunculusVialV2
extends Node2D

## Ultimate Direction v2 runtime driver for «Совершенный Гомункул» (FAN-2959).
##
## The AnimationPlayer owns every drawn beat (backdrop veil, fusion glow, the
## converging pair, the arena-wide alchemical circle, the PixelLab avatar stomp
## frames, the taunt halo, the stomp waves and the toxic cascade). This script
## owns only the node-free weight devices the v2 presence block declares:
## viewport-fitted backdrop coverage, camera shake, the hitstop freeze on the
## first stomp and SFX ducking during release. Every device restores its exact
## pre-cast state on pause, finish, scene exit and repeated activation, so no
## orphan offsets, buses or timers survive the effect.
##
## The envelope shrank from the v1 5.40s to 3.80s without touching mechanics:
## the executor keeps fuse_at 0.9, beat_interval 0.85 and beat_count 3, so the
## three stomps still land at 1.75s, 2.60s and 3.45s — all inside the drawn
## active window. Only the drawn convergence and split were tightened.
##
## FAN-3879: this script also owns the per-victim read. Each stomp beat names
## the enemies it actually damaged (`victims` payload key); this scene is the
## only live effect channel the Chemist package spawns, so the burst rides its
## own `present()` exactly like the Doctor package.

const RELEASE_AT := 0.9
const IMPACT_AT := 1.75
const RECOVERY_AT := 3.6
const CANCEL_AT := 3.8
const HITSTOP_MS := 120.0
const SHAKE_SECONDS := 0.55
const SHAKE_AMPLITUDE := 11.0
const SFX_DUCK_DB := -9.0

## The executor's stomp beats (fuse_at + beat_interval * n). Each one is a real
## damage tick, so each one re-arms the shake; only the first takes the hitstop,
## which the v2 contract scopes to the first impact.
const STOMP_BEATS: Array[float] = [1.75, 2.6, 3.45]

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/chemist/homunculus_vial/victim_impact_spriteframes.tres")

## Beat payload key naming the enemies a stomp actually damaged.
const VICTIMS_KEY := "victims"

## Reduced motion: the fusion flash keeps its beats at a damped peak instead of
## the full emerald burst, so the calm variant is a fade, not a flash.
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
var _next_stomp := 0
var _duck_active := false
var _sfx_bus_index := -1
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _impacts: Node2D = null


func _ready() -> void:
	set_process(true)
	if not _screen_shake_enabled():
		_apply_reduced_motion()


## The hitstop freezes the drawn timeline, never the envelope clock: the shared
## presentation timeline keeps counting real time, so a clock that skipped the
## freeze would drift 120ms behind every declared beat and outlive the manifest
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
	if _next_stomp < STOMP_BEATS.size() and _elapsed >= STOMP_BEATS[_next_stomp]:
		_next_stomp += 1
		_shake_remaining = SHAKE_SECONDS
		if not _impact_fired:
			_impact_fired = true
			_hitstop_remaining = HITSTOP_MS / 1000.0
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
	_next_stomp = 0
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()
		_impacts.free()
	_impacts = null


## One executor beat. A stomp that names the enemies it actually damaged gets
## the shared victim-impact burst on each of them; every other beat draws
## nothing here, so an unaffected target can never receive one.
func present(_event_id: String, payload: Dictionary) -> void:
	var victims: Array = payload.get(VICTIMS_KEY, [])
	if victims.is_empty():
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts.play(VICTIM_FRAMES, victims, global_position)
		return
	_impacts.enqueue(victims, global_position)


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
## moves and the fusion flash plays as a damped fade. Every phase keeps its
## declared timing — only the intensity of the two motion devices changes.
func _apply_reduced_motion() -> void:
	for node_name in ["BackdropVeil", "FusionGlow"]:
		var item := get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.self_modulate.a = REDUCED_MOTION_FLASH_ALPHA


## Stomp shake, decaying with the remaining window. The player's screen_shake
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
