extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.ranger.moon_crossbow"
const EXECUTOR_ID := "weapon_ultimate.executor.ranger.moon_crossbow"
const EFFECT_SCENE := "res://scripts/ultimates/classes/ranger/moon_crossbow.tscn"
const MARK_KEY := "moon_mark"

var ultimate_damage_sink: Callable = Callable()
var marked_target_for_tests: Node = null
var wave_count_for_tests := 0
var split_count_for_tests := 0
var mark_transfer_count_for_tests := 0

var _activation = null


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"windup_delay": {"type": "number", "minimum": 0.0},
		"wave_interval": {"type": "number", "minimum": 0.01},
		"wave_count": {"type": "integer", "minimum": 1},
		"max_range": {"type": "number", "minimum": 1.0},
		"prey_radius": {"type": "number", "minimum": 1.0},
		"split_radius": {"type": "number", "minimum": 1.0},
		"split_count": {"type": "integer", "minimum": 1},
		"split_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"bolt_damage": {"type": "number", "minimum": 0.0},
	}


## The aim samples the field and the priority selector names the heaviest
## silhouette inside it. An empty circle leaves the hunt without a mark — the
## declared timeline still runs, it just has nothing to shoot, and no fallback
## targeting mode is substituted for the one that was asked for.
static func execute(activation) -> float:
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": activation.param_float("max_range", 620.0),
		"target_mode": "host_aim",
	}):
		return 0.0
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "target",
		"radius": activation.param_float("prey_radius", 240.0),
		"limit": 1,
		"priority": "highest_hp",
		"hint": {},
	}):
		return 0.0
	var prey = activation.primitive_value("primary_target")
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, prey)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var windup: float = activation.param_float("windup_delay", 0.7)
	var interval: float = activation.param_float("wave_interval", 0.8)
	var waves: int = activation.param_int("wave_count", 5)
	tween.tween_interval(windup)
	for wave in waves:
		tween.tween_callback(Callable(effect, "fire").bind(wave))
		tween.tween_interval(interval)
	var elapsed: float = windup + interval * float(waves)
	var lifetime: float = activation.param_float("lifetime", 4.8)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


func configure(activation, prey) -> void:
	_activation = activation
	global_position = activation.origin()
	var marked := prey as Node2D
	if marked == null or not is_instance_valid(marked) \
			or not activation.record_target_value(marked, MARK_KEY, 1.0, "moon_hunt:mark"):
		return
	marked_target_for_tests = marked
	activation.present(EXECUTOR_ID + ".mark", {
		"position": marked.global_position,
		"radius": activation.param_float("split_radius", 200.0),
		"shape": "moon_mark",
	})


## One wave: the marked prey takes the bolt, and the split bolts spend a fixed
## share of it on up to `split_count` distinct neighbours. A wave that kills the
## prey hands the mark to the closest surviving neighbour, so the next wave has
## somewhere to land instead of dropping the rest of the hunt.
func fire(wave: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	var prey := marked_target_for_tests as Node2D
	if prey == null or not is_instance_valid(prey) \
			or _activation.target_value(prey, MARK_KEY) == null:
		return
	wave_count_for_tests += 1
	var neighbours := _neighbours(prey)
	var bolt: float = _activation.scaled_damage("bolt_damage", 25.0)
	var result = _deal(
		prey, bolt, "moon_hunt:bolt:%d" % wave, false,
		{"ultimate_mechanic": "moon_bolt", "wave": wave}
	)
	var split: float = bolt * _activation.param_float("split_ratio", 0.1)
	for index in neighbours.size():
		_deal(
			neighbours[index] as Node, split, "moon_hunt:split:%d" % wave, true,
			{"ultimate_mechanic": "moon_split", "wave": wave, "split_index": index}
		)
		split_count_for_tests += 1
	if result != null and bool(result.killed):
		_transfer_mark(prey, neighbours, wave)


## Neighbours are the split rail, so the prey itself never counts as one of the
## four and the same silhouette cannot be listed twice.
func _neighbours(prey: Node2D) -> Array:
	var wanted: int = _activation.param_int("split_count", 4)
	var neighbours: Array = []
	for raw_target in _activation.select_targets(
		prey.global_position,
		_activation.param_float("split_radius", 200.0),
		wanted + 1,
		"nearest"
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target) or target == prey:
			continue
		neighbours.append(target)
		if neighbours.size() >= wanted:
			break
	return neighbours


func _transfer_mark(prey: Node2D, neighbours: Array, wave: int) -> void:
	for raw_target in neighbours:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_health := 0.0
		if target.has("health"):
			target_health = float(target.get("health"))
		if target_health > 0.0 and _activation.transfer_target_value(
			prey, target, MARK_KEY, "moon_hunt:transfer:%d" % wave
		):
			marked_target_for_tests = target
			mark_transfer_count_for_tests += 1
			_activation.present(EXECUTOR_ID + ".mark", {
				"position": target.global_position,
				"radius": _activation.param_float("split_radius", 200.0),
				"shape": "moon_mark",
			})
			return
	if marked_target_for_tests == prey:
		marked_target_for_tests = null


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	marked_target_for_tests = null
	_activation = null
