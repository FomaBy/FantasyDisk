class_name AssassinUltimateV2Driver
extends Node2D

## Class-local weight and accessibility devices for the Assassin v2 trio.
## The authored AnimationPlayer remains the visual source of truth; this driver
## owns only camera/audio weight, a frame-local hitstop and safe substitutions.

const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const PresentationManifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const CAST_POSE_FRAMES := {
	"assassin/chakrams": preload("res://assets/sprites/effects/assassin/chakrams/trail/trail_spriteframes.tres"),
	"assassin/shadow_daggers": preload("res://assets/sprites/effects/assassin/shadow_daggers/tornado/tornado_spriteframes.tres"),
	"assassin/venom_wire": preload("res://assets/sprites/effects/assassin/venom_wire/pulse/pulse_spriteframes.tres"),
}

@export var release_at := 0.8
@export var impact_at := 1.0
@export var recovery_at := 3.0
@export var cancel_at := 3.6
@export var hitstop_ms := 110.0
@export_range(0.0, 0.5, 0.01) var time_scale_dip := 0.0
@export var shake_seconds := 0.48
@export var shake_amplitude := 7.0
@export var sfx_duck_db := -8.0
@export var photosensitive_nodes := PackedStringArray()

const BACKDROP_PATH := NodePath("BackdropLayer/BackdropVeil")
const REDUCED_BACKDROP_ALPHA := 0.72
const PHOTO_BACKDROP_ALPHA := 0.58
const REDUCED_CHAKRAMS_ORBIT_SCALE := Vector2(2.8, 2.8)

static var _duck_refs := 0
static var _duck_volume_before_db := 0.0

var _elapsed := 0.0
var _paused := false
var _impact_fired := false
var _hitstop_remaining := 0.0
var _time_scale_before_dip := 1.0
var _time_scale_dip_active := false
var _minimum_time_scale_observed := 1.0
var _shake_remaining := 0.0
var _reduced_motion := false
var _photosensitivity_safe := false
var _disabled_tracks: Array[int] = []
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _duck_active := false
var _sfx_bus_index := -1
var _externally_driven := false
var _shake_rng := RandomNumberGenerator.new()
var _cast_pose: Sprite2D = null
var _cast_pose_backdrop: Sprite2D = null
var _cast_pose_highlight: AnimatedSprite2D = null
var _player_body: CanvasItem = null
var _player_body_was_visible := true
var _cast_pose_binding_error := "not_started"


func _ready() -> void:
	process_priority = 1000
	# The legacy executor scenes still embed these presentation scenes. Keep
	# those copies inert; WeaponUltimatePresentationRuntime owns the one live
	# instance and explicitly activates it through begin().
	hide()
	_apply_accessibility_snapshot()
	set_process(false)


## Runtime-compatible signature. The registry and handles stay owned by the
## shared presentation runtime; the scene only restarts its authored timeline.
func begin(registry = null, _handles: Dictionary = {}, _headless_mode := -1) -> Dictionary:
	_reset_run()
	show()
	_apply_accessibility_snapshot()
	_bind_cast_pose(registry)
	_shake_rng.seed = hash(str(get_meta("ultimate_id", name)))
	var timeline := _timeline()
	if timeline != null:
		timeline.play(&"ultimate")
		timeline.seek(0.0, true)
		timeline.pause()
	_externally_driven = true
	set_process(false)
	return presence_snapshot()


func _process(delta: float) -> void:
	if _externally_driven:
		return
	_step(delta)


## WeaponUltimatePresentationRuntime supplies wall-clock delta. Keeping the
## authored AnimationPlayer on that same clock prevents Engine.time_scale from
## making the scene lag behind the host's release/recovery/cancel envelope.
func advance(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	if _paused:
		return
	var elapsed_before := _elapsed
	_elapsed += maxf(delta, 0.0)
	var hitstop_step := delta
	if not _impact_fired and _elapsed >= impact_at:
		_impact_fired = true
		_hitstop_remaining = hitstop_ms / 1000.0
		_shake_remaining = shake_seconds
		_pause_timeline()
		_begin_time_scale_dip()
		hitstop_step = maxf(_elapsed - impact_at, 0.0) if elapsed_before < impact_at else delta
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(_hitstop_remaining - hitstop_step, 0.0)
		if _hitstop_remaining <= 0.0:
			_end_time_scale_dip()
			_resume_timeline_at_clock()
	if _elapsed >= release_at and _elapsed < recovery_at:
		_begin_sfx_ducking()
	else:
		_end_sfx_ducking()
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - delta, 0.0)
		_apply_camera_shake(_shake_remaining)
	if _hitstop_remaining <= 0.0:
		_seek_timeline_to_clock()
	_apply_frame_safety()
	_update_cast_pose_highlight()
	_apply_executor_impact_safety()
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
	_externally_driven = false
	var timeline := _timeline()
	if timeline != null:
		timeline.stop()
	_end_sfx_ducking()
	_end_camera_shake()
	_end_time_scale_dip()
	_hitstop_remaining = 0.0
	_shake_remaining = 0.0
	_release_cast_pose()
	hide()


func presence_snapshot() -> Dictionary:
	return {
		"reduced_motion": _reduced_motion,
		"photosensitivity_safe": _photosensitivity_safe,
		"motion_tracks_disabled": _disabled_tracks.size(),
		"photosensitive_nodes": photosensitive_nodes.size(),
		"hitstop_ms": hitstop_ms,
		"time_scale_dip": time_scale_dip,
		"minimum_time_scale_observed": _minimum_time_scale_observed,
		"elapsed_seconds": _elapsed,
		"camera_shake": not _reduced_motion and _screen_shake_enabled(),
		"sfx_ducking": true,
		"cast_pose_bound": _cast_pose != null and is_instance_valid(_cast_pose),
		"cast_pose_binding_error": _cast_pose_binding_error,
	}


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_end_sfx_ducking()
		_end_camera_shake()
		_end_time_scale_dip()


func _reset_run() -> void:
	_end_sfx_ducking()
	_end_camera_shake()
	_end_time_scale_dip()
	_elapsed = 0.0
	_paused = false
	_impact_fired = false
	_hitstop_remaining = 0.0
	_minimum_time_scale_observed = Engine.time_scale
	_shake_remaining = 0.0
	_release_cast_pose()
	_restore_motion_tracks()


## The host advances the presentation on wall time, so the global gameplay dip
## can add impact weight without stretching release/recovery/cancel timing.
## Reduced motion suppresses the global speed change together with camera shake.
func _begin_time_scale_dip() -> void:
	if time_scale_dip <= 0.0 or _reduced_motion or _time_scale_dip_active or Engine.time_scale < 0.99:
		return
	_time_scale_before_dip = Engine.time_scale
	Engine.time_scale = time_scale_dip
	_time_scale_dip_active = true
	_minimum_time_scale_observed = minf(_minimum_time_scale_observed, Engine.time_scale)


func _end_time_scale_dip() -> void:
	if not _time_scale_dip_active:
		return
	if is_equal_approx(Engine.time_scale, time_scale_dip):
		Engine.time_scale = _time_scale_before_dip
	_time_scale_dip_active = false


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
		_apply_reduced_motion_substitute()
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
	# Scene-authored transforms are the reduced-motion substitute. In
	# particular, the Chakrams scene's eight distinct compass positions and
	# 0.24 disc scale must not collapse to one default transform.


func _apply_reduced_motion_substitute() -> void:
	if str(get_meta("ultimate_id", "")) != "assassin/chakrams":
		return
	var orbit := get_node_or_null("Orbit") as Node2D
	if orbit == null:
		return
	# Autoplay can apply the 0.14 windup key before `_ready()`. Once the fast
	# scale track is disabled, preserving that sampled value would collapse the
	# eight moons into an unreadable dot. Hold a deliberate arena-scale compass
	# instead; alpha still carries the exact release/active/recovery envelope.
	orbit.rotation = 0.0
	orbit.scale = REDUCED_CHAKRAMS_ORBIT_SCALE


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
	if _externally_driven:
		timeline.pause()


func _seek_timeline_to_clock() -> void:
	var timeline := _timeline()
	if timeline == null or _paused:
		return
	timeline.seek(minf(_elapsed, cancel_at), true)
	if _externally_driven and timeline.is_playing():
		timeline.pause()


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
		_shake_rng.randf_range(-strength, strength), _shake_rng.randf_range(-strength, strength)
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


func _bind_cast_pose(registry) -> void:
	_cast_pose_binding_error = "registry_unavailable"
	if registry == null or not registry.has_method("catalog_profile_for"):
		return
	var key := str(get_meta("ultimate_id", ""))
	var parts := key.split("/", false, 1)
	_cast_pose_binding_error = "invalid_ultimate_id:%s" % key
	if parts.size() != 2:
		return
	var manifest := PresentationManifest.manifest_for_profile(
		registry.call("catalog_profile_for", parts[0], parts[1]) as Dictionary
	)
	var asset := str((manifest.get("identity", {}) as Dictionary).get("weapon_silhouette_asset", ""))
	var texture := load(asset) as Texture2D
	_cast_pose_binding_error = "silhouette_unavailable:%s" % asset
	if texture == null:
		return
	var halo_frames := CAST_POSE_FRAMES.get(key, null) as SpriteFrames
	_cast_pose_binding_error = "cast_halo_unavailable:%s" % key
	if halo_frames == null or halo_frames.get_animation_names().is_empty():
		return
	var player := _nearest_player()
	_cast_pose_binding_error = "eligible_player_unavailable"
	if player == null:
		return
	var visual_root := player.get_node_or_null("VisualRoot") as Node2D
	_player_body = player.get_node_or_null("VisualRoot/Body") as CanvasItem
	_cast_pose_binding_error = "player_visual_tree_unavailable"
	if visual_root == null or _player_body == null:
		return
	_player_body_was_visible = _player_body.visible
	_player_body.visible = false
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var backdrop_texture := GradientTexture2D.new()
	backdrop_texture.gradient = gradient
	backdrop_texture.fill = GradientTexture2D.FILL_RADIAL
	backdrop_texture.width = 64
	backdrop_texture.height = 64
	_cast_pose_backdrop = Sprite2D.new()
	_cast_pose_backdrop.name = "UltimateCastPoseBackdrop"
	_cast_pose_backdrop.texture = backdrop_texture
	_cast_pose_backdrop.scale = Vector2.ONE * (84.0 / 64.0)
	_cast_pose_backdrop.modulate = Color(0.025, 0.018, 0.035, 0.92)
	# The presentation runtime mounts its scene after Player in the arena tree.
	# Keep the cast identity above that later sibling so wide attack layers do
	# not flatten the player's contrast at release or recovery.
	_cast_pose_backdrop.z_index = 100
	visual_root.add_child(_cast_pose_backdrop)
	_cast_pose_highlight = AnimatedSprite2D.new()
	_cast_pose_highlight.name = "UltimateCastPoseHighlight"
	_cast_pose_highlight.sprite_frames = halo_frames
	_cast_pose_highlight.animation = StringName(halo_frames.get_animation_names()[0])
	_cast_pose_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cast_pose_highlight.scale = Vector2.ONE * 0.32
	_cast_pose_highlight.modulate.a = 0.78
	_cast_pose_highlight.z_index = 101
	visual_root.add_child(_cast_pose_highlight)
	_cast_pose = Sprite2D.new()
	_cast_pose.name = "UltimateCastPose"
	_cast_pose.texture = texture
	_cast_pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cast_pose.self_modulate = Color(1.25, 1.25, 1.25, 1.0)
	_cast_pose.scale = Vector2.ONE * clampf(72.0 / maxf(texture.get_size().x, texture.get_size().y), 0.12, 0.7)
	_cast_pose.z_index = 102
	visual_root.add_child(_cast_pose)
	_cast_pose_binding_error = ""


func _update_cast_pose_highlight() -> void:
	if _cast_pose_highlight == null or not is_instance_valid(_cast_pose_highlight):
		return
	var count := _cast_pose_highlight.sprite_frames.get_frame_count(_cast_pose_highlight.animation)
	if count <= 0:
		return
	_cast_pose_highlight.frame = count / 2 if _reduced_motion or _photosensitivity_safe else clampi(floori(_elapsed / maxf(cancel_at, 0.001) * count), 0, count - 1)
	_cast_pose_highlight.modulate.a = 0.48 if _photosensitivity_safe else 0.78


func _release_cast_pose() -> void:
	if _cast_pose != null and is_instance_valid(_cast_pose):
		_cast_pose.free()
	_cast_pose = null
	if _cast_pose_highlight != null and is_instance_valid(_cast_pose_highlight):
		_cast_pose_highlight.free()
	_cast_pose_highlight = null
	if _cast_pose_backdrop != null and is_instance_valid(_cast_pose_backdrop):
		_cast_pose_backdrop.free()
	_cast_pose_backdrop = null
	if _player_body != null and is_instance_valid(_player_body):
		_player_body.visible = _player_body_was_visible
	_player_body = null


func _nearest_player() -> Node2D:
	var tree := get_tree() if is_inside_tree() else null
	if tree == null:
		return null
	var nearest: Node2D = null
	var distance := INF
	for raw_player in tree.get_nodes_in_group("player"):
		var player := raw_player as Node2D
		if player == null \
				or not player.get_node_or_null("VisualRoot") is Node2D \
				or not player.get_node_or_null("VisualRoot/Body") is CanvasItem:
			continue
		var candidate := player.global_position.distance_squared_to(global_position)
		if candidate < distance:
			distance = candidate
			nearest = player
	return nearest


## Assassin executors own their victim flipbooks. Adapt only players below an
## Assassin executor node, after its tween callback, so unrelated combat VFX
## and gameplay RNG/state are untouched.
func _apply_executor_impact_safety() -> void:
	if not _photosensitivity_safe or get_tree() == null:
		return
	for raw_sprite in get_tree().root.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_sprite as AnimatedSprite2D
		if sprite == null or not _is_class_impact(sprite):
			continue
		sprite.stop()
		sprite.frame = clampi(4, 0, maxi(sprite.sprite_frames.get_frame_count(sprite.animation) - 1, 0)) \
			if sprite.sprite_frames != null else 0
		sprite.scale = Vector2.ONE * 0.24
		sprite.modulate.a = minf(sprite.modulate.a, 0.12)
		sprite.set_meta("photosensitivity_safe", true)


func _is_class_impact(node: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		var script := cursor.get_script() as Script
		if script != null and script.resource_path.contains("/scripts/ultimates/classes/assassin/"):
			return true
		cursor = cursor.get_parent()
	return false


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
