extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.ranger.storm_longbow"
const EXECUTOR_ID := "weapon_ultimate.executor.ranger.storm_longbow"
const EFFECT_SCENE := "res://scripts/ultimates/classes/ranger/storm_longbow.tscn"
const CONTROL_POLICY := {
	"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": false, "allow_execute": true},
	"epic": {"displacement_multiplier": 0.5, "duration_multiplier": 0.5, "allow_movement_lock": false, "allow_execute": true},
	"boss": {"displacement_multiplier": 0.25, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
}

var ultimate_damage_sink: Callable = Callable()
var beat_count_for_tests := 0
var corridor_size_for_tests := 0

var _activation = null
var _corridor: Array = []
var _direction := Vector2.RIGHT


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"half_width": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 1},
		"beat_count": {"type": "integer", "minimum": 1},
		"beat_interval": {"type": "number", "minimum": 0.01},
		"storm_damage": {"type": "number", "minimum": 0.0},
		"knockback": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	var max_range: float = activation.param_float("max_range", 980.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": max_range,
		"target_mode": "host_aim",
	}) or not Library.execute_primitive("line_pierce_geometry", activation, {
		"start": "source",
		"direction": "aim",
		"length": max_range,
		"half_width": activation.param_float("half_width", 72.0),
		"limit": activation.param_int("target_limit", 12),
	}) or not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	var corridor = activation.primitive_value("targets", [])
	if not corridor is Array:
		corridor = []
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, corridor as Array, activation.aim_direction(max_range))
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var beats: int = activation.param_int("beat_count", 7)
	for beat in beats:
		if beat > 0:
			tween.tween_interval(activation.param_float("beat_interval", 0.45))
		tween.tween_callback(Callable(effect, "strike").bind(beat))
	return float(maxi(beats - 1, 0)) * activation.param_float("beat_interval", 0.45)


func configure(activation, corridor: Array, direction: Vector2) -> void:
	_activation = activation
	_corridor = corridor.duplicate()
	_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	corridor_size_for_tests = _corridor.size()
	global_position = activation.origin()
	activation.present("weapon_ultimate.presentation.ranger.storm_longbow", {
		"weapon_id": "storm_longbow", "phase": "corridor", "direction": _direction,
	})


func strike(beat: int) -> void:
	if _activation == null or _activation.is_finished() or _corridor.is_empty():
		return
	var target := _target_for_beat(beat)
	if target == null:
		return
	beat_count_for_tests += 1
	_deal(
		target,
		_activation.scaled_damage("storm_damage", 0.0),
		"storm_beat:%d" % beat,
		false,
		{"ultimate_mechanic": "storm_corridor", "beat": beat}
	)
	_activation.apply_control(
		target,
		_direction * _activation.param_float("knockback", 150.0),
		"",
		{}
	)
	_activation.present("weapon_ultimate.presentation.ranger.storm_longbow", {
		"weapon_id": "storm_longbow", "phase": "beat", "beat": beat,
	})


func _target_for_beat(beat: int) -> Node2D:
	for offset in _corridor.size():
		var index := (beat + offset) % _corridor.size()
		var target := _corridor[index] as Node2D
		if target != null and is_instance_valid(target) and _alive(target):
			return target
	return null


func _alive(target: Node2D) -> bool:
	var health = target.get("health")
	return health == null or float(health) > 0.0


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_activation = null
	_corridor.clear()
