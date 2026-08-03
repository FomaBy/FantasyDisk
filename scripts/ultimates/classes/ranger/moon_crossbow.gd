extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.ranger.moon_crossbow"
const EXECUTOR_ID := "weapon_ultimate.executor.ranger.moon_crossbow"
const EFFECT_SCENE := "res://scripts/ultimates/classes/ranger/moon_crossbow.tscn"

var ultimate_damage_sink: Callable = Callable()
var mark_target_for_tests: Node2D = null
var wave_count_for_tests := 0
var split_hits_for_tests := 0
var transfer_count_for_tests := 0

var _activation = null


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"aim_assist_radius": {"type": "number", "minimum": 0.0},
		"wave_count": {"type": "integer", "minimum": 1},
		"wave_interval": {"type": "number", "minimum": 0.01},
		"mark_damage": {"type": "number", "minimum": 0.0},
		"split_damage": {"type": "number", "minimum": 0.0},
		"split_count": {"type": "integer", "minimum": 1},
		"split_radius": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	var max_range: float = activation.param_float("max_range", 900.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": max_range,
		"target_mode": "host_aim",
	}):
		return 0.0
	var mark := _pick_mark(activation, max_range, activation.param_float("aim_assist_radius", 90.0))
	if mark == null:
		return 0.0
	activation.record_target_value(mark, "moon_mark", true, "moon_mark_open")
	activation.set_primitive_state({"primary_target": mark})
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, mark)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var waves: int = activation.param_int("wave_count", 3)
	for wave in waves:
		if wave > 0:
			tween.tween_interval(activation.param_float("wave_interval", 0.65))
		tween.tween_callback(Callable(effect, "fire_wave").bind(wave))
	return float(maxi(waves - 1, 0)) * activation.param_float("wave_interval", 0.65)


static func _pick_mark(activation, max_range: float, aim_assist_radius: float) -> Node2D:
	var aim_point: Vector2 = activation.aim_point(max_range)
	for raw_target in activation.select_targets(
		aim_point, aim_assist_radius, 1, "aimed", {"point": aim_point}
	):
		var aimed := raw_target as Node2D
		if _alive(aimed):
			return aimed
	for raw_target in activation.select_targets(
		activation.origin(), max_range, 0, "highest_hp"
	):
		var highest_hp := raw_target as Node2D
		if _alive(highest_hp):
			return highest_hp
	return null


static func _alive(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var health = target.get("health")
	return health == null or float(health) > 0.0


func configure(activation, marked: Node2D) -> void:
	_activation = activation
	mark_target_for_tests = marked
	global_position = activation.origin()
	activation.present("weapon_ultimate.presentation.ranger.moon_crossbow", {
		"weapon_id": "moon_crossbow", "phase": "mark", "target": marked,
	})


func fire_wave(wave: int) -> void:
	if _activation == null or _activation.is_finished() \
			or wave >= _activation.param_int("wave_count", 3):
		return
	if not _ensure_mark(wave):
		return
	var marked := mark_target_for_tests
	var neighbors := _neighbors(marked)
	wave_count_for_tests += 1
	_deal(
		marked,
		_activation.scaled_damage("mark_damage", 0.0),
		"moon_mark:%d" % wave,
		false,
		{"ultimate_mechanic": "moon_mark", "wave": wave}
	)
	for index in neighbors.size():
		var neighbor := neighbors[index] as Node2D
		_deal(
			neighbor,
			_activation.scaled_damage("split_damage", 0.0),
			"moon_split:%d:%d" % [wave, index],
			true,
		{"ultimate_mechanic": "moon_split", "wave": wave, "split_index": index}
		)
		split_hits_for_tests += 1
	_activation.present("weapon_ultimate.presentation.ranger.moon_crossbow", {
		"weapon_id": "moon_crossbow", "phase": "wave", "wave": wave,
	})
	if not _alive(marked):
		_transfer_mark(marked, wave)


func _ensure_mark(wave: int) -> bool:
	if _alive(mark_target_for_tests):
		return true
	_transfer_mark(mark_target_for_tests, wave)
	return _alive(mark_target_for_tests)


func _neighbors(marked: Node2D) -> Array:
	var neighbors: Array = []
	for raw_target in _activation.select_targets(
		marked.global_position,
		_activation.param_float("split_radius", 260.0),
		0,
		"nearest"
	):
		var target := raw_target as Node2D
		if target == marked or not _alive(target):
			continue
		neighbors.append(target)
		if neighbors.size() >= _activation.param_int("split_count", 4):
			break
	return neighbors


func _transfer_mark(previous: Node2D, wave: int) -> void:
	if _activation == null:
		return
	var next := _pick_mark(
		_activation,
		_activation.param_float("max_range", 900.0),
		_activation.param_float("aim_assist_radius", 90.0)
	)
	if next == null or next == previous:
		return
	if previous != null and is_instance_valid(previous):
		_activation.transfer_target_value(previous, next, "moon_mark", "moon_mark_transfer:%d" % wave)
	else:
		_activation.record_target_value(next, "moon_mark", true, "moon_mark_transfer:%d" % wave)
	mark_target_for_tests = next
	transfer_count_for_tests += 1
	_activation.present("weapon_ultimate.presentation.ranger.moon_crossbow", {
		"weapon_id": "moon_crossbow", "phase": "transfer", "target": next,
	})


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_activation = null
	mark_target_for_tests = null
