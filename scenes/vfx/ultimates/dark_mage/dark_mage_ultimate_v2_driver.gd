class_name DarkMageUltimateV2Driver
extends Node2D

## Runtime presence for the Dark Mage's V2 ultimate trio. The authored scene
## retains its weapon-specific animation; this driver owns only the shared
## screen-scale backdrop, hero pose, silhouette and first-impact feedback.
##
## Accessibility (FAN-3946) is read from the production snapshot Main publishes
## on the scene-tree root (`scripts/settings/ultimate_accessibility_settings.gd`):
##
## - reduced motion selects the scene's authored `ultimate_reduced_motion`
##   variant (same length, same phase beats, no travel), never moves the camera,
##   never dips Engine.time_scale, holds the hero pose/silhouette static and eases
##   every backdrop beat instead of stepping it;
## - photosensitivity-safe replaces the per-phase backdrop steps (and the skull's
##   violet flash tint) with one low, slowly ramped darken veil and caps the
##   flipbook luminance through `self_modulate`, which the authored alpha tracks
##   never touch;
## - both together apply the union: the reduced-motion variant with the
##   photosensitivity-safe backdrop and luminance caps. Gameplay, phase timing
##   and SFX ducking are identical in every mode.

const ACCESSIBILITY := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/manifest.json"
const BACKDROP_OVERSCAN := 1.08
const SFX_DUCK_DB := -8.0
const TIMELINE_NODE := "Timeline"
const NORMAL_ANIMATION := &"ultimate"
const REDUCED_MOTION_ANIMATION := &"ultimate_reduced_motion"
## Reduced motion eases a backdrop beat at this alpha-per-second rate instead
## of stepping it, so the calm variant fades where the ordinary one pops.
const REDUCED_MOTION_BACKDROP_RATE := 0.6
## Photosensitivity-safe backdrop: one constant darken veil, ramped at a bounded
## rate. 0.24/s reaches the veil in half a second and never approaches a flash.
const PHOTOSAFE_BACKDROP_ALPHA := 0.12
const PHOTOSAFE_BACKDROP_RATE := 0.24
const PHOTOSAFE_FLIPBOOK_ALPHA := 0.6
const PHOTOSAFE_IDENTITY_ALPHA := 0.75

@export var weapon_id := ""

var _manifest: Dictionary = {}
var _timing: Dictionary = {}
var _presence: Dictionary = {}
var _identity: Dictionary = {}
var _headless_mode := -1
var _elapsed := 0.0
var _paused := false
var _release_applied := false
var _visible_phase := ""
var _reduced_motion := false
var _photosensitivity_safe := false
var _timeline_animation := ""
var _backdrop: Sprite2D = null
var _backdrop_alpha := 0.0
var _backdrop_target_alpha := 0.0
var _backdrop_max_alpha_step := 0.0
var _cast_pose: Sprite2D = null
var _silhouette: Sprite2D = null
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _ducked_bus_index := -1
var _ducked_previous_db := 0.0
var _hitstop_previous_scale := 1.0
var _hitstop_active := false
var _presence_state := {}


## The authored Timeline autoplays on its own clock from the scene's _ready,
## before the runtime ever calls begin(), so the variant is selected here and
## re-asserted in begin() with a fresh snapshot read.
func _ready() -> void:
	_read_accessibility_modes()
	_apply_modes_to_timeline()


func begin(_handles: Dictionary, headless_mode := -1) -> Dictionary:
	_headless_mode = headless_mode
	_manifest = _manifest_for_weapon()
	_timing = _manifest.get("timing_seconds", {}) as Dictionary
	_presence = _manifest.get("presence", {}) as Dictionary
	_identity = _manifest.get("identity", {}) as Dictionary
	_elapsed = 0.0
	_paused = false
	_release_applied = false
	_read_accessibility_modes()
	_apply_modes_to_timeline()
	_clear_presence()
	_build_presence_nodes()
	_show_phase("windup")
	return {"state": "active"}


func advance(delta_seconds: float) -> Array[Dictionary]:
	if _paused or _timing.is_empty():
		return []
	_elapsed += maxf(delta_seconds, 0.0)
	_fit_backdrop_to_viewport()
	var phase := _phase_at(_elapsed)
	if phase != _visible_phase:
		_show_phase(phase)
	if not _release_applied and _elapsed >= float(_timing.get("release", INF)):
		_release_applied = true
		_apply_release_presence()
	_step_backdrop(maxf(delta_seconds, 0.0))
	return []


func set_paused(value: bool) -> void:
	_paused = value


func finish(_reason: String) -> void:
	_clear_presence()
	_elapsed = 0.0
	_release_applied = false
	_visible_phase = ""


func visible_phase_name() -> String:
	return _visible_phase


## Focused runtime tests read the state while platform-facing devices remain
## guarded in headless mode. The mode keys, the bound timeline animation and
## the backdrop alpha history report what actually happened, not the request.
func presence_state_for_tests() -> Dictionary:
	return _presence_state.duplicate(true)


func _read_accessibility_modes() -> void:
	var snapshot := ACCESSIBILITY.read_snapshot(get_tree().root if is_inside_tree() else null)
	_reduced_motion = bool(snapshot[ACCESSIBILITY.REDUCED_MOTION_KEY])
	_photosensitivity_safe = bool(snapshot[ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY])


## Reduced motion plays the scene's authored substitute at the same position
## the ordinary timeline reached; photosensitivity-safe caps every flipbook
## through self_modulate, which the animation's modulate tracks never touch.
func _apply_modes_to_timeline() -> void:
	var timeline := get_node_or_null(TIMELINE_NODE) as AnimationPlayer
	if timeline != null:
		var wanted := NORMAL_ANIMATION
		if _reduced_motion and timeline.has_animation(REDUCED_MOTION_ANIMATION):
			wanted = REDUCED_MOTION_ANIMATION
		if timeline.current_animation != String(wanted) or not timeline.is_playing():
			var position := timeline.current_animation_position if timeline.is_playing() else 0.0
			timeline.play(wanted)
			timeline.seek(position, true)
		_timeline_animation = String(wanted)
	var flipbook_alpha := PHOTOSAFE_FLIPBOOK_ALPHA if _photosensitivity_safe else 1.0
	for child in get_children():
		if child is AnimatedSprite2D:
			(child as AnimatedSprite2D).self_modulate.a = flipbook_alpha


func _manifest_for_weapon() -> Dictionary:
	if weapon_id.is_empty() or not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not document is Dictionary:
		return {}
	for raw_weapon in (document as Dictionary).get("weapons", []) as Array:
		if raw_weapon is Dictionary and str((raw_weapon as Dictionary).get("weapon_id", "")) == weapon_id:
			return (raw_weapon as Dictionary).duplicate(true)
	return {}


func _phase_at(seconds: float) -> String:
	if seconds >= float(_timing.get("cancel", INF)):
		return "cancel"
	if seconds >= float(_timing.get("recovery", INF)):
		return "recovery"
	if seconds >= float(_timing.get("active", INF)):
		return "active"
	if seconds >= float(_timing.get("release", INF)):
		return "release"
	return "windup"


func _show_phase(phase_name: String) -> void:
	_visible_phase = phase_name
	_apply_presence_pose(phase_name)


func _build_presence_nodes() -> void:
	_presence_state = {
		"backdrop_visible": false,
		"backdrop_alpha": 0.0,
		"backdrop_max_alpha_step": 0.0,
		"camera_shake_triggered": false,
		"hitstop_ms": 0.0,
		"sfx_ducked": false,
		"cast_pose_id": str(_identity.get("cast_pose_id", "")),
		"cast_pose_asset": str(_identity.get("cast_pose_asset", "")),
		"cast_pose_bound": false,
		"silhouette_asset": str(_identity.get("weapon_silhouette_asset", "")),
		"silhouette_bound": false,
		"reduced_motion": _reduced_motion,
		"photosensitivity_safe": _photosensitivity_safe,
		"timeline_animation": _timeline_animation,
		"flipbook_alpha_cap": PHOTOSAFE_FLIPBOOK_ALPHA if _photosensitivity_safe else 1.0,
	}
	if _presence.is_empty() or _identity.is_empty():
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.width = 64
	texture.height = 64
	_backdrop = Sprite2D.new()
	_backdrop.name = "BackdropTreatment"
	_backdrop.texture = texture
	_backdrop.centered = false
	_backdrop.modulate = _backdrop_color(0.0)
	_backdrop.z_index = -2
	_backdrop.top_level = true
	add_child(_backdrop)
	_fit_backdrop_to_viewport()

	var identity_alpha := PHOTOSAFE_IDENTITY_ALPHA if _photosensitivity_safe else 1.0
	var pose_texture := load(str(_identity.get("cast_pose_asset", ""))) as Texture2D
	if pose_texture != null:
		_cast_pose = Sprite2D.new()
		_cast_pose.name = "HeroCastPose"
		_cast_pose.texture = pose_texture
		_cast_pose.scale = Vector2.ONE * 0.30
		_cast_pose.modulate = _palette_color(0.0)
		_cast_pose.self_modulate.a = identity_alpha
		_cast_pose.z_index = 1
		add_child(_cast_pose)
		_presence_state["cast_pose_bound"] = true

	var silhouette_texture := load(str(_identity.get("weapon_silhouette_asset", ""))) as Texture2D
	if silhouette_texture != null:
		_silhouette = Sprite2D.new()
		_silhouette.name = "WeaponSilhouette"
		_silhouette.texture = silhouette_texture
		_silhouette.scale = Vector2.ONE * 0.54
		_silhouette.modulate = _palette_color(0.0)
		_silhouette.self_modulate.a = identity_alpha
		_silhouette.z_index = 2
		add_child(_silhouette)
		_presence_state["silhouette_bound"] = true


func _apply_presence_pose(phase_name: String) -> void:
	if _backdrop == null:
		return
	_backdrop_target_alpha = _phase_backdrop_alpha(phase_name)
	if not _reduced_motion and not _photosensitivity_safe:
		_set_backdrop_alpha(_backdrop_target_alpha)
	# Reduced motion holds the hero read at its released size from the first
	# frame: the windup-to-release scale pop is a motion beat, not a timing one.
	var settled := _reduced_motion or phase_name != "windup"
	if _cast_pose != null:
		_cast_pose.visible = phase_name != "cancel"
		_cast_pose.modulate = _palette_color(0.9 if _cast_pose.visible else 0.0)
		_cast_pose.scale = Vector2.ONE * (0.40 if settled else 0.30)
	if _silhouette != null:
		_silhouette.visible = phase_name != "cancel"
		_silhouette.modulate = _palette_color(0.92 if _silhouette.visible else 0.0)
		_silhouette.scale = Vector2.ONE * (0.72 if settled else 0.54)


## Photosensitivity-safe keeps one low veil through every drawn phase, so the
## screen never steps between darken levels or into the skull's flash tint.
func _phase_backdrop_alpha(phase_name: String) -> float:
	if _photosensitivity_safe:
		return 0.0 if phase_name == "cancel" else PHOTOSAFE_BACKDROP_ALPHA
	match phase_name:
		"windup":
			return 0.14
		"release":
			return 0.30 if str(_presence.get("backdrop", "")) == "flash" else 0.35
		"active":
			return 0.22
		"recovery":
			return 0.08
	return 0.0


## Only the accessibility variants ramp; the ordinary presentation keeps its
## authored per-phase steps.
func _step_backdrop(delta_seconds: float) -> void:
	if _backdrop == null or (not _reduced_motion and not _photosensitivity_safe):
		return
	var rate := PHOTOSAFE_BACKDROP_RATE if _photosensitivity_safe else REDUCED_MOTION_BACKDROP_RATE
	_set_backdrop_alpha(move_toward(_backdrop_alpha, _backdrop_target_alpha, rate * delta_seconds))


func _set_backdrop_alpha(alpha: float) -> void:
	_backdrop_max_alpha_step = maxf(_backdrop_max_alpha_step, absf(alpha - _backdrop_alpha))
	_backdrop_alpha = alpha
	_backdrop.modulate = _backdrop_color(alpha)
	_backdrop.visible = alpha > 0.0
	_presence_state["backdrop_visible"] = _backdrop.visible
	_presence_state["backdrop_alpha"] = alpha
	_presence_state["backdrop_max_alpha_step"] = _backdrop_max_alpha_step


func _fit_backdrop_to_viewport() -> void:
	if _backdrop == null or _backdrop.texture == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()
	var visible_size: Vector2 = rect.size / camera.zoom if camera != null else rect.size
	var overscan := visible_size * (BACKDROP_OVERSCAN - 1.0) * 0.5
	var size := visible_size + overscan * 2.0
	_backdrop.position = viewport.get_canvas_transform().affine_inverse() * rect.position - overscan
	_backdrop.scale = size / _backdrop.texture.get_size()


## Reduced motion suppresses the two motion devices outright; the SFX duck is
## not motion and plays in every mode.
func _apply_release_presence() -> void:
	if _presence.get("camera_shake") == true and not _reduced_motion:
		_presence_state["camera_shake_triggered"] = true
		_shake_camera()
	var hitstop_ms := float(_presence.get("hitstop_ms", 0.0))
	if hitstop_ms > 0.0 and not _reduced_motion:
		_presence_state["hitstop_ms"] = hitstop_ms
		_start_hitstop(hitstop_ms)
	if _presence.get("sfx_ducking") == true:
		_presence_state["sfx_ducked"] = true
		_duck_sfx()


func _backdrop_color(alpha: float) -> Color:
	if str(_presence.get("backdrop", "")) == "flash" and not _photosensitivity_safe:
		return Color(0.42, 0.14, 0.56, alpha)
	return Color(0.025, 0.006, 0.065, alpha)


func _palette_color(alpha: float) -> Color:
	match weapon_id:
		"cursed_skull":
			return Color(0.72, 1.0, 0.46, alpha)
		"dark_wand":
			return Color(0.56, 0.84, 1.0, alpha)
		_:
			return Color(0.82, 0.52, 1.0, alpha)


func _is_headless() -> bool:
	return not is_inside_tree() or DisplayServer.get_name() == "headless" or _headless_mode == 1


func _shake_camera() -> void:
	if _is_headless() or not bool(get_tree().root.get_meta("screen_shake", true)):
		return
	_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return
	_camera_offset_before_shake = _camera.offset
	var tween := _camera.create_tween()
	for index in 4:
		var strength := 7.0 * (1.0 - float(index) / 4.0)
		tween.tween_property(_camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	tween.tween_property(_camera, "offset", _camera_offset_before_shake, 0.04)


func _start_hitstop(hitstop_ms: float) -> void:
	if _is_headless() or _hitstop_active or Engine.time_scale < 0.99:
		return
	_hitstop_previous_scale = Engine.time_scale
	Engine.time_scale = float(_presence.get("time_scale_dip", 0.4))
	_hitstop_active = true
	var timer := get_tree().create_timer(hitstop_ms / 1000.0, true, false, true)
	timer.timeout.connect(_restore_hitstop)


func _restore_hitstop() -> void:
	if not _hitstop_active:
		return
	if is_equal_approx(Engine.time_scale, float(_presence.get("time_scale_dip", 0.4))):
		Engine.time_scale = _hitstop_previous_scale
	_hitstop_active = false


func _duck_sfx() -> void:
	if _is_headless() or _ducked_bus_index != -1:
		return
	var bus_index := AudioServer.get_bus_index("SFX")
	if bus_index == -1:
		return
	_ducked_bus_index = bus_index
	_ducked_previous_db = AudioServer.get_bus_volume_db(bus_index)
	AudioServer.set_bus_volume_db(bus_index, _ducked_previous_db + SFX_DUCK_DB)


func _clear_presence() -> void:
	_restore_hitstop()
	if _ducked_bus_index != -1 and AudioServer.get_bus_index("SFX") == _ducked_bus_index:
		AudioServer.set_bus_volume_db(_ducked_bus_index, _ducked_previous_db)
	_ducked_bus_index = -1
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset_before_shake
	_camera = null
	for node in [_backdrop, _cast_pose, _silhouette]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_backdrop = null
	_backdrop_alpha = 0.0
	_backdrop_target_alpha = 0.0
	_backdrop_max_alpha_step = 0.0
	_cast_pose = null
	_silhouette = null


func _exit_tree() -> void:
	_clear_presence()
