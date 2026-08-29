class_name RangerUltimateTimelineScene
extends Node2D

## Scene driver shared by Ranger's class-local ultimate scenes.
## It owns only the sprites it builds and hands supplied handles to the frozen
## presentation timeline, so pause and every teardown path are deterministic.
##
## FAN-3736 added the Ultimate Direction v2 weight devices the presence block
## declares: the authored arena-wide backdrop veil, the hero cast pose, camera
## shake and the first-impact hitstop, plus SFX ducking across the release
## window. The devices are node-free apart from the two authored sprites, and
## every one of them restores its exact pre-cast state on pause, finish, scene
## exit and repeated activation.

const Pack := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_presentation_pack.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")

const CLEANUP_REASONS: Array[String] = ["cancel", "death", "node_end"]

## A hair of overscan keeps the screen edges covered instead of a rounding seam.
const BACKDROP_OVERSCAN := 1.02

@export var weapon_id: String = Pack.MOON_CROSSBOW

signal phase_entered(phase: Dictionary)
signal timeline_finished(reason: String)

## Overlapping activations share one duck: the first to duck records the
## pre-cast volume, the last to release restores it.
static var _duck_refs := 0
static var _duck_volume_before_db := 0.0
static var _duck_applied_db := 0.0

var _timeline = null
var _manifest: Dictionary = {}
var _elements: Array[Sprite2D] = []
var _paused := false
var _impact_fired := false
var _hitstop_remaining := 0.0
var _hitstop_pose := 0.0
var _shake_remaining := 0.0
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _duck_active := false
var _sfx_bus_index := -1


## Declarations land on entering the tree, not on `_ready`: a headless contract
## run adds the scene before the tree's first iteration, so a deferred READY
## would leave the budget and v2 metadata unreadable to the gates.
func _enter_tree() -> void:
	_apply_identity_metadata()
	_reset_presence_nodes()


func _ready() -> void:
	set_process(false)


func begin(registry, handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	finish("node_end")
	_apply_identity_metadata()
	_manifest = Pack.manifest_for(registry, weapon_id)
	if _manifest.is_empty():
		push_error("RangerUltimateTimelineScene: no manifest for %s" % weapon_id)
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
		return {}
	var snapshot := _release_handles(reason)
	_clear_elements()
	_end_camera_shake()
	_end_sfx_ducking()
	_reset_presence_nodes()
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
		_advance_weight_devices(delta, elapsed)
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
	set_meta("max_visual_nodes", Pack.max_visual_nodes(weapon_id))
	set_meta("crowd_cap", Pack.CROWD_CAP)
	set_meta("max_unique_materials", Pack.MAX_UNIQUE_MATERIALS)
	set_meta("max_fullscreen_materials", Pack.MAX_FULLSCREEN_MATERIALS)
	set_meta("presence", Pack.presence_for(weapon_id))
	set_meta("identity", Pack.identity_for(weapon_id))


## The two authored presence nodes are invisible outside an activation, so an
## instanced but never-cast scene draws nothing.
func _reset_presence_nodes() -> void:
	var veil := _backdrop()
	if veil != null:
		veil.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		veil.visible = false
	var pose := _hero_pose()
	if pose != null:
		pose.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		pose.visible = false


func _backdrop() -> Sprite2D:
	return get_node_or_null(Pack.BACKDROP_NODE) as Sprite2D


func _hero_pose() -> Sprite2D:
	return get_node_or_null(Pack.HERO_POSE_NODE) as Sprite2D


## Arena-wide backdrop plus hero cast pose, both driven from the same declared
## timeline the manifest publishes.
func _apply_presence(elapsed: float) -> void:
	var config := Pack.weapon_config(weapon_id)
	var veil := _backdrop()
	if veil != null:
		var alpha := Pack.backdrop_alpha(weapon_id, elapsed)
		var tint: Color = config.get("backdrop_tint", Color.BLACK)
		veil.self_modulate = Color(tint.r, tint.g, tint.b, alpha)
		veil.visible = alpha > 0.0
		_fit_backdrop_to_viewport(veil)
	var pose := _hero_pose()
	if pose != null:
		var pose_alpha := Pack.hero_pose_alpha(weapon_id, elapsed)
		var palette := Pack.palette_color(weapon_id)
		pose.self_modulate = Color(palette.r, palette.g, palette.b, pose_alpha)
		pose.visible = pose_alpha > 0.0


## The veil draws in world units while the visible rect is screen pixels, so the
## camera zoom has to divide out or a battle zoom below 1 uncovers the edges.
func _fit_backdrop_to_viewport(veil: Sprite2D) -> void:
	if veil.texture == null or not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()
	var visible_size: Vector2 = rect.size / camera.zoom if camera != null else rect.size
	var overscan := visible_size * (BACKDROP_OVERSCAN - 1.0) * 0.5
	veil.top_level = true
	veil.position = viewport.get_canvas_transform().affine_inverse() * rect.position - overscan
	veil.scale = (visible_size + overscan * 2.0) / Vector2(veil.texture.get_size())


## The hitstop freezes the drawn pose, never the envelope clock: the shared
## timeline keeps counting real time, so no beat drifts past the declared cancel.
func _drawn_elapsed(elapsed: float) -> float:
	return _hitstop_pose if _hitstop_remaining > 0.0 else elapsed


func _advance_weight_devices(delta: float, elapsed: float) -> void:
	var config := Pack.weapon_config(weapon_id)
	var presence: Dictionary = config.get("presence", {})
	var shake: Dictionary = config.get("shake", {})
	var timing: Dictionary = config.get("timing", {})
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


## Motion toggle, read exactly like berserk's v2 driver: main mirrors
## GameSettings.screen_shake onto the tree root for scripts without a game ref.
func _screen_shake_enabled() -> bool:
	if not is_inside_tree():
		return true
	var tree := get_tree()
	return tree == null or bool(tree.root.get_meta("screen_shake", true))


func _apply_camera_shake(remaining: float, window: float, amplitude: float) -> void:
	if not _screen_shake_enabled() or amplitude <= 0.0:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = _find_current_camera()
		if _camera == null:
			return
		_camera_offset_before_shake = _camera.offset
	var strength := amplitude * (remaining / maxf(window, 0.0001))
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
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	for node in tree.root.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		if camera != null and camera.is_current() and camera.enabled:
			return camera
	return null


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


## The pre-cast volume is only restored while the bus still carries the exact
## duck this effect applied, so an unrelated mixer change is never stomped.
func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	_duck_refs = maxi(_duck_refs - 1, 0)
	if _duck_refs == 0 and _sfx_bus_index != -1 \
			and is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), _duck_applied_db):
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db)
	_sfx_bus_index = -1


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
		push_error("RangerUltimateTimelineScene: missing runtime frame for %s" % weapon_id)
		return
	var pivot: Dictionary = _manifest.get("pivot", {})
	var formation: Dictionary = Pack.weapon_config(weapon_id).get("formation", {})
	var count := mini(int(formation.get("count", 0)), Pack.MAX_ELEMENTS_PER_ULTIMATE)
	for index in count:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = -Vector2(
			texture.get_width() * float(pivot.get("x", 0.5)),
			texture.get_height() * float(pivot.get("y", 0.5))
		)
		add_child(sprite)
		_elements.append(sprite)


func _clear_elements() -> void:
	for sprite in _elements:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_elements.clear()


func _apply_formation(elapsed: float) -> void:
	if _elements.is_empty():
		return
	var phase := Pack.phase_at(weapon_id, elapsed)
	var points := Pack.formation_points(weapon_id, str(phase.get("name", "")), float(phase.get("progress", 0.0)))
	# The class palette is the effect's color source, so the trio reads as one
	# Ranger kit instead of three white sprite washes.
	var palette := Pack.palette_color(weapon_id)
	for index in _elements.size():
		var sprite := _elements[index]
		if index >= points.size():
			sprite.visible = false
			continue
		var point: Dictionary = points[index]
		var alpha := float(point.get("alpha", 1.0))
		sprite.visible = alpha > 0.0
		sprite.position = point.get("position", Vector2.ZERO)
		sprite.scale = Vector2.ONE * float(point.get("scale", 1.0))
		sprite.rotation = float(point.get("rotation", 0.0))
		sprite.modulate = Color(palette.r, palette.g, palette.b, alpha)
