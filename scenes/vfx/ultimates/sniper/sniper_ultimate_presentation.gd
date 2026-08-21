class_name SniperUltimatePresentationScene
extends Node2D

## Class-local visual runner for a frozen sniper ultimate timeline.
##
## FAN-1541 owns the shared adapter which will instantiate these scenes. This
## runner deliberately owns only its presentation nodes and delegates timing,
## pause, headless behavior, and handle cleanup to the frozen contract class.

const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")

const BACKDROP_OVERSCAN := 1.08
const SFX_DUCK_DB := -8.0

@export_file("*.json") var definition_path := ""

var _definition: Dictionary = {}
var _timeline: RefCounted
var _visible_phase := ""
var _headless_mode := -1
var _presence: Dictionary = {}
var _identity: Dictionary = {}
var _backdrop: Polygon2D = null
var _cast_pose: Sprite2D = null
var _silhouette: Sprite2D = null
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _ducked_bus_index := -1
var _ducked_previous_db := 0.0
var _hitstop_previous_scale := 1.0
var _hitstop_active := false
var _presence_state := {
	"backdrop_visible": false,
	"camera_shake_triggered": false,
	"hitstop_ms": 0.0,
	"sfx_ducked": false,
	"cast_pose_id": "",
	"cast_pose_asset": "",
	"cast_pose_bound": false,
	"silhouette_asset": "",
	"silhouette_bound": false,
}


func _ready() -> void:
	_load_definition_if_needed()
	_reset_phase_nodes()


func definition() -> Dictionary:
	_load_definition_if_needed()
	return _definition.duplicate(true)


func manifest() -> Dictionary:
	return definition().get("manifest", {}).duplicate(true)


func begin(handles: Dictionary, headless_mode := -1) -> Dictionary:
	_load_definition_if_needed()
	_clear_presence()
	_reset_phase_nodes()
	_headless_mode = headless_mode
	_presence = manifest().get("presence", {}) as Dictionary
	_identity = manifest().get("identity", {}) as Dictionary
	_build_presence_nodes()
	_timeline = Timeline.new(manifest(), headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_apply_emitted_phases(_timeline.advance(0.0))
	return snapshot


func advance(delta_seconds: float) -> Array[Dictionary]:
	if _timeline == null:
		return []
	_fit_backdrop_to_viewport()
	var emitted: Array[Dictionary] = _timeline.advance(delta_seconds)
	_apply_emitted_phases(emitted)
	return emitted


func set_paused(value: bool) -> void:
	if _timeline != null:
		_timeline.set_paused(value)


func finish(reason: String) -> Dictionary:
	if _timeline == null:
		_clear_presence()
		_reset_phase_nodes()
		return {}
	var snapshot: Dictionary = _timeline.finish(reason)
	_reset_phase_nodes()
	_clear_presence()
	return snapshot


func visible_phase_name() -> String:
	return _visible_phase


## Runtime-facing proof that the authored V2 weight, rather than manifest-only
## declarations, is active. The focused headless test reads this state while
## actual camera, time-scale, and mix changes stay guarded below.
func presence_state_for_tests() -> Dictionary:
	return _presence_state.duplicate(true)


func _load_definition_if_needed() -> void:
	if not _definition.is_empty() or definition_path.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(definition_path))
	if parsed is Dictionary:
		_definition = (parsed as Dictionary).duplicate(true)


func _apply_emitted_phases(emitted: Array[Dictionary]) -> void:
	for phase in emitted:
		var phase_name := str(phase.get("name", ""))
		_show_phase(phase_name)
		if phase_name == "release":
			_apply_release_presence()


func _show_phase(phase_name: String) -> void:
	var phase_nodes := get_node_or_null("PhaseNodes")
	if phase_nodes == null:
		return
	_visible_phase = phase_name
	for node in phase_nodes.get_children():
		if node is CanvasItem:
			(node as CanvasItem).visible = node.name.to_lower() == phase_name
	_apply_presence_pose(phase_name)


func _reset_phase_nodes() -> void:
	_visible_phase = ""
	var phase_nodes := get_node_or_null("PhaseNodes")
	if phase_nodes == null:
		return
	for node in phase_nodes.get_children():
		if node is CanvasItem:
			(node as CanvasItem).visible = false


func _build_presence_nodes() -> void:
	_presence_state = {
		"backdrop_visible": false,
		"camera_shake_triggered": false,
		"hitstop_ms": 0.0,
		"sfx_ducked": false,
		"cast_pose_id": str(_identity.get("cast_pose_id", "")),
		"cast_pose_asset": str(_identity.get("cast_pose_asset", "")),
		"cast_pose_bound": false,
		"silhouette_asset": str(_identity.get("weapon_silhouette_asset", "")),
		"silhouette_bound": false,
	}
	if _presence.is_empty() or _identity.is_empty():
		return
	_backdrop = Polygon2D.new()
	_backdrop.name = "BackdropTreatment"
	_backdrop.color = _backdrop_color(0.0)
	_backdrop.z_index = -2
	_backdrop.top_level = true
	add_child(_backdrop)
	_fit_backdrop_to_viewport()

	var pose_texture := load(str(_identity.get("cast_pose_asset", ""))) as Texture2D
	if pose_texture != null:
		_cast_pose = Sprite2D.new()
		_cast_pose.name = "HeroCastPose"
		_cast_pose.texture = pose_texture
		_cast_pose.scale = Vector2.ONE * 0.30
		_cast_pose.modulate = _palette_color(0.0)
		_cast_pose.z_index = 1
		add_child(_cast_pose)
		_presence_state["cast_pose_bound"] = true

	var silhouette := load(str(_identity.get("weapon_silhouette_asset", ""))) as Texture2D
	if silhouette != null:
		_silhouette = Sprite2D.new()
		_silhouette.name = "WeaponSilhouette"
		_silhouette.texture = silhouette
		_silhouette.scale = Vector2.ONE * 0.46
		_silhouette.modulate = _palette_color(0.0)
		_silhouette.z_index = 2
		add_child(_silhouette)
		_presence_state["silhouette_bound"] = true


func _apply_presence_pose(phase_name: String) -> void:
	if _backdrop == null:
		return
	var alpha := 0.0
	match phase_name:
		"windup":
			alpha = 0.16
		"release":
			alpha = 0.34 if str(_presence.get("backdrop", "")) == "flash" else 0.42
		"active":
			alpha = 0.24
		"recovery":
			alpha = 0.10
	_backdrop.color = _backdrop_color(alpha)
	_backdrop.visible = alpha > 0.0
	_presence_state["backdrop_visible"] = _backdrop.visible
	if _cast_pose != null:
		_cast_pose.visible = phase_name != "cancel"
		_cast_pose.modulate = _palette_color(0.9 if _cast_pose.visible else 0.0)
		_cast_pose.scale = Vector2.ONE * (0.30 if phase_name == "windup" else 0.40)
	if _silhouette != null:
		_silhouette.visible = phase_name != "cancel"
		_silhouette.modulate = _palette_color(0.9 if _silhouette.visible else 0.0)
		_silhouette.scale = Vector2.ONE * (0.46 if phase_name == "windup" else 0.72)


## The treatment is top-level and re-fitted to the actual camera every step.
## A player-centred polygon leaves gaps whenever the camera reaches an arena
## limit, because the player is then offset from the viewport centre.
func _fit_backdrop_to_viewport() -> void:
	if _backdrop == null:
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
	_backdrop.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])


func _apply_release_presence() -> void:
	if _presence.is_empty():
		return
	if _presence.get("camera_shake") == true:
		_presence_state["camera_shake_triggered"] = true
		_shake_camera()
	var hitstop_ms := float(_presence.get("hitstop_ms", 0.0))
	if hitstop_ms > 0.0:
		_presence_state["hitstop_ms"] = hitstop_ms
		_start_hitstop(hitstop_ms)
	if _presence.get("sfx_ducking") == true:
		_presence_state["sfx_ducked"] = true
		_duck_sfx()


func _backdrop_color(alpha: float) -> Color:
	if str(_presence.get("backdrop", "")) == "flash":
		return Color(0.64, 0.06, 0.12, alpha)
	return Color(0.015, 0.035, 0.08, alpha)


func _palette_color(alpha: float) -> Color:
	var weapon_id := str((manifest().get("key", {}) as Dictionary).get("weapon_id", ""))
	if weapon_id == "sniper_spotter_scope":
		return Color(1.0, 0.38, 0.32, alpha)
	if weapon_id == "sniper_shatter_rounds":
		return Color(0.64, 0.90, 1.0, alpha)
	return Color(0.68, 0.90, 1.0, alpha)


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
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_free()
	_backdrop = null
	if _cast_pose != null and is_instance_valid(_cast_pose):
		_cast_pose.queue_free()
	_cast_pose = null
	if _silhouette != null and is_instance_valid(_silhouette):
		_silhouette.queue_free()
	_silhouette = null


func _exit_tree() -> void:
	_clear_presence()
