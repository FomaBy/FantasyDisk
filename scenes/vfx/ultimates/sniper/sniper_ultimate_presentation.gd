class_name SniperUltimatePresentationScene
extends Node2D

## Class-local visual runner for a frozen sniper ultimate timeline.
##
## FAN-1541 owns the shared adapter which will instantiate these scenes. This
## runner deliberately owns only its presentation nodes and delegates timing,
## pause, headless behavior, and handle cleanup to the frozen contract class.

const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")

@export_file("*.json") var definition_path := ""

var _definition: Dictionary = {}
var _timeline: RefCounted
var _visible_phase := ""


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
	_reset_phase_nodes()
	_timeline = Timeline.new(manifest(), headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_apply_emitted_phases(_timeline.advance(0.0))
	return snapshot


func advance(delta_seconds: float) -> Array[Dictionary]:
	if _timeline == null:
		return []
	var emitted: Array[Dictionary] = _timeline.advance(delta_seconds)
	_apply_emitted_phases(emitted)
	return emitted


func set_paused(value: bool) -> void:
	if _timeline != null:
		_timeline.set_paused(value)


func finish(reason: String) -> Dictionary:
	if _timeline == null:
		_reset_phase_nodes()
		return {}
	var snapshot: Dictionary = _timeline.finish(reason)
	_reset_phase_nodes()
	return snapshot


func visible_phase_name() -> String:
	return _visible_phase


func _load_definition_if_needed() -> void:
	if not _definition.is_empty() or definition_path.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(definition_path))
	if parsed is Dictionary:
		_definition = (parsed as Dictionary).duplicate(true)


func _apply_emitted_phases(emitted: Array[Dictionary]) -> void:
	for phase in emitted:
		_show_phase(str(phase.get("name", "")))


func _show_phase(phase_name: String) -> void:
	var phase_nodes := get_node_or_null("PhaseNodes")
	if phase_nodes == null:
		return
	_visible_phase = phase_name
	for node in phase_nodes.get_children():
		if node is CanvasItem:
			(node as CanvasItem).visible = node.name.to_lower() == phase_name


func _reset_phase_nodes() -> void:
	_visible_phase = ""
	var phase_nodes := get_node_or_null("PhaseNodes")
	if phase_nodes == null:
		return
	for node in phase_nodes.get_children():
		if node is CanvasItem:
			(node as CanvasItem).visible = false
