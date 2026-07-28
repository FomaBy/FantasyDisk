class_name ThiefUltimateTimelineScene
extends Node2D

## Local driver only: pooled runtime integration remains owned by FAN-1541.
const Pack := preload("res://scenes/vfx/ultimates/thief/thief_ultimate_presentation_pack.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const CLEANUP_REASONS: Array[String] = ["cancel", "death", "node_end"]

@export var weapon_id: String = Pack.COIN_POUCH

var _timeline = null
var _manifest: Dictionary = {}
var _elements: Array[Sprite2D] = []


func _ready() -> void:
	set_process(false)


func begin(registry, handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	finish("node_end")
	_manifest = Pack.manifest_for(registry, weapon_id)
	if _manifest.is_empty():
		push_error("ThiefUltimateTimelineScene: no manifest for %s" % weapon_id)
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
		return {}
	var snapshot: Dictionary = _timeline.finish(reason)
	_timeline = null
	_clear_elements()
	set_process(false)
	return snapshot


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _timeline == null:
		return
	_timeline.advance(delta)
	_apply_formation(_timeline.elapsed_seconds())
	if _timeline.elapsed_seconds() >= Pack.timeline_seconds(weapon_id):
		finish("node_end")


func _exit_tree() -> void:
	finish("node_end")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _timeline != null:
		_timeline.finish("node_end")
		_timeline = null


func _build_elements() -> void:
	_clear_elements()
	var texture: Texture2D = load(Pack.asset_path(weapon_id))
	if texture == null:
		push_error("ThiefUltimateTimelineScene: missing accepted asset for %s" % weapon_id)
		return
	var pivot: Dictionary = _manifest.get("pivot", {})
	var count := mini(int((Pack.weapon_config(weapon_id).get("formation", {}) as Dictionary).get("count", 0)), Pack.MAX_ELEMENTS_PER_ULTIMATE)
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


func _apply_formation(elapsed: float) -> void:
	if _elements.is_empty():
		return
	var phase := Pack.phase_at(weapon_id, elapsed)
	var points := Pack.formation_points(weapon_id, str(phase.get("name", "")), float(phase.get("progress", 0.0)))
	for index in _elements.size():
		var sprite := _elements[index]
		var point: Dictionary = points[index]
		var alpha := float(point.get("alpha", 0.0))
		sprite.visible = alpha > 0.0
		sprite.position = point.get("position", Vector2.ZERO)
		sprite.scale = Vector2.ONE * float(point.get("scale", 1.0))
		sprite.rotation = float(point.get("rotation", 0.0))
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
