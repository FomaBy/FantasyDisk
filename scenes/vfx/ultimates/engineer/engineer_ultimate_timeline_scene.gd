class_name EngineerUltimateTimelineScene
extends Node2D

## Class-local scene driver for one engineer weapon ultimate timeline.
##
## The driver owns only the formation sprites it creates itself. It never
## touches shared VFX pools, and it delegates the whole lifecycle to
## `WeaponUltimatePresentationTimeline`, so pause, cancel, death, and node
## teardown behave exactly as the frozen presentation contract requires.
##
## FAN-1541 owns the shared runtime adapter that will eventually select this
## scene for a ready weapon; until then the scene is driven by tests and by the
## contact-sheet renderer.

const Pack := preload("res://scenes/vfx/ultimates/engineer/engineer_ultimate_presentation_pack.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")

## Cleanup reasons the frozen timeline contract requires this scene to survive.
const CLEANUP_REASONS: Array[String] = ["cancel", "death", "node_end"]

@export var weapon_id: String = Pack.SENTRY_WRENCH

signal phase_entered(phase: Dictionary)
signal timeline_finished(reason: String)

var _timeline = null
var _manifest: Dictionary = {}
var _elements: Array[Sprite2D] = []


func _ready() -> void:
	set_process(false)


## Start the timeline for the configured weapon.
##
## `handles` are the animation/VFX/SFX handles the caller owns; the timeline
## releases every one of them on any cleanup reason. Pass `headless_mode` 1 or
## 0 to force deterministic behavior in tests.
func begin(registry, handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	finish("node_end")
	_manifest = Pack.manifest_for(registry, weapon_id)
	if _manifest.is_empty():
		push_error("EngineerUltimateTimelineScene: no manifest for %s" % weapon_id)
		return {}
	_timeline = Timeline.new(_manifest, headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_build_elements()
		_apply_formation(0.0)
		set_process(true)
	return snapshot


func set_paused(value: bool) -> void:
	if _timeline == null:
		return
	_timeline.set_paused(value)


func is_active() -> bool:
	return _timeline != null and str(_timeline.snapshot().get("state", "")) == Timeline.ACTIVE_STATE


## Release every handle and every sprite this scene created.
func finish(reason: String) -> Dictionary:
	if _timeline == null:
		return {}
	var snapshot := _release_handles(reason)
	_clear_elements()
	set_process(false)
	timeline_finished.emit(reason)
	return snapshot


## Hand every owned handle back to the timeline without touching nodes.
##
## Kept separate from `finish` so the predelete path can run during destruction,
## where freeing children or emitting signals is not safe.
func _release_handles(reason: String) -> Dictionary:
	if _timeline == null:
		return {}
	var snapshot: Dictionary = _timeline.finish(reason)
	_timeline = null
	return snapshot


func _process(delta: float) -> void:
	step(delta)


## Advance the timeline by `delta` seconds and restate the formation.
##
## Exposed so tests and the contact-sheet renderer drive the same code the
## frame loop drives, instead of a second copy of the motion.
func step(delta: float) -> void:
	if _timeline == null:
		return
	for event in _timeline.advance(delta):
		phase_entered.emit(event)
	var elapsed: float = _timeline.elapsed_seconds()
	_apply_formation(elapsed)
	if elapsed >= Pack.timeline_seconds(weapon_id):
		finish("node_end")


func _exit_tree() -> void:
	# Node teardown must never orphan a handle, even mid-timeline.
	finish("node_end")


func _notification(what: int) -> void:
	# A scene freed before it ever entered the tree never gets `_exit_tree`, so
	# predelete is the last guaranteed chance to release the owned handles.
	if what == NOTIFICATION_PREDELETE:
		_release_handles("node_end")


func _build_elements() -> void:
	_clear_elements()
	var texture: Texture2D = load(Pack.element_runtime_path(weapon_id))
	if texture == null:
		push_error("EngineerUltimateTimelineScene: missing runtime frame for %s" % weapon_id)
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
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
