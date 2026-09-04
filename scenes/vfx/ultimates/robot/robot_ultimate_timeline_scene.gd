class_name RobotUltimateTimelineScene
extends Node2D

## Scene driver for one Robot ultimate presentation timeline.
## It owns only its local sprites and delegates pause and every teardown path
## to the shared, testable timeline lifecycle.

const Pack := preload("res://scenes/vfx/ultimates/robot/robot_ultimate_presentation_pack.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const IMPACT_FRAMES := {
	Pack.MAGNETIC_ANCHOR: preload("res://assets/sprites/effects/robot/magnetic_anchor/magnetic_anchor_spriteframes.tres"),
	Pack.HYDRAULIC_PRESS: preload("res://assets/sprites/effects/robot/hydraulic_press/hydraulic_press_spriteframes.tres"),
	Pack.REACTOR_CORE: preload("res://assets/sprites/effects/robot/reactor_core/reactor_core_spriteframes.tres"),
}

const CLEANUP_REASONS: Array[String] = ["cancel", "death", "node_end"]

@export var weapon_id: String = Pack.MAGNETIC_ANCHOR

signal phase_entered(phase: Dictionary)
signal timeline_finished(reason: String)

var _timeline = null
var _manifest: Dictionary = {}
var _elements: Array[Sprite2D] = []
var _impacts: Node2D = null
var _impacts_started := false


func _ready() -> void:
	_apply_identity_metadata()
	set_process(false)


func begin(registry, handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	finish("node_end")
	_apply_identity_metadata()
	_manifest = Pack.manifest_for(registry, weapon_id)
	if _manifest.is_empty():
		push_error("RobotUltimateTimelineScene: no manifest for %s" % weapon_id)
		return {}
	_timeline = Timeline.new(_manifest, headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_build_elements()
		_apply_formation(0.0)
		set_process(true)
	return snapshot


func set_paused(value: bool) -> void:
	if _timeline != null:
		_timeline.set_paused(value)


func is_active() -> bool:
	return _timeline != null and str(_timeline.snapshot().get("state", "")) == Timeline.ACTIVE_STATE


func finish(reason: String) -> Dictionary:
	if _timeline == null:
		_finish_impacts()
		return {}
	var snapshot := _release_handles(reason)
	_clear_elements()
	_finish_impacts()
	set_process(false)
	timeline_finished.emit(reason)
	return snapshot


func step(delta: float) -> void:
	if _timeline == null:
		return
	for event in _timeline.advance(delta):
		phase_entered.emit(event)
	_apply_formation(_timeline.elapsed_seconds())
	if _timeline != null and _timeline.elapsed_seconds() >= Pack.timeline_seconds(weapon_id):
		finish("node_end")


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_handles("node_end")


func _apply_identity_metadata() -> void:
	var config := Pack.weapon_config(weapon_id)
	set_meta("ultimate_id", "%s/%s" % [Pack.CLASS_ID, weapon_id])
	set_meta("silhouette", str(config.get("silhouette", "")))
	set_meta("motion_path", str(config.get("motion", "")))
	set_meta("impact_language", str(config.get("impact", "")))
	set_meta("max_visual_nodes", int((config.get("formation", {}) as Dictionary).get("count", 0)))
	set_meta("crowd_cap", Pack.MAX_ELEMENTS_PER_ULTIMATE)


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
		push_error("RobotUltimateTimelineScene: missing runtime frame for %s" % weapon_id)
		return
	var pivot: Dictionary = _manifest.get("pivot", {})
	var formation: Dictionary = Pack.weapon_config(weapon_id).get("formation", {})
	var count := mini(int(formation.get("count", 0)), Pack.MAX_ELEMENTS_PER_ULTIMATE)
	for index in count:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = -Vector2(texture.get_width() * float(pivot.get("x", 0.5)), texture.get_height() * float(pivot.get("y", 0.5)))
		add_child(sprite)
		_elements.append(sprite)


func _clear_elements() -> void:
	for sprite in _elements:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_elements.clear()


func present(_event_id: String, payload: Dictionary) -> void:
	var victims: Variant = payload.get("victims", [])
	if not victims is Array or (victims as Array).is_empty():
		return
	var frames := IMPACT_FRAMES.get(weapon_id, null) as SpriteFrames
	if frames == null:
		push_error("RobotUltimateTimelineScene: missing victim-impact frames for %s" % weapon_id)
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(victims as Array, global_position)
	else:
		_impacts.play(frames, victims as Array, global_position)
		_impacts_started = true


func _finish_impacts() -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()
	_impacts = null
	_impacts_started = false


func _apply_formation(elapsed: float) -> void:
	if _elements.is_empty():
		return
	var phase := Pack.phase_at(weapon_id, elapsed)
	var points := Pack.formation_points(weapon_id, str(phase.get("name", "")), float(phase.get("progress", 0.0)))
	for index in _elements.size():
		var sprite := _elements[index]
		if index >= points.size():
			sprite.visible = false
			continue
		var point: Dictionary = points[index]
		var alpha := float(point.get("alpha", 1.0))
		var tint: Color = Pack.weapon_config(weapon_id).get("tint", Color.WHITE)
		sprite.visible = alpha > 0.0
		sprite.position = point.get("position", Vector2.ZERO)
		sprite.scale = Vector2.ONE * float(point.get("scale", 1.0))
		sprite.rotation = float(point.get("rotation", 0.0))
		sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)
