extends Node2D

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

@export var victim_frames: SpriteFrames

var _impacts: Node2D = null
var _impacts_started := false


func present(_event_id: String, payload: Dictionary) -> void:
	var raw_victims: Variant = payload.get("victims")
	if not raw_victims is Array or (raw_victims as Array).is_empty() or victim_frames == null:
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(raw_victims as Array, global_position)
	else:
		_impacts.play(victim_frames, raw_victims as Array, global_position)
		_impacts_started = true


func finish(_reason: String) -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()


func _exit_tree() -> void:
	_impacts = null
	_impacts_started = false
