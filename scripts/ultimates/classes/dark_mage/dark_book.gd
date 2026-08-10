extends Node2D

const PROFILE_ID := "weapon_ultimate.profile.dark_mage.dark_book"
const EXECUTOR_ID := "weapon_ultimate.executor.dark_mage.dark_book"
const EFFECT_SCENE := "res://scripts/ultimates/classes/dark_mage/dark_book.tscn"

var ultimate_damage_sink: Callable = Callable()
var pair_count_for_tests := 0
var kill_reflection_count_for_tests := 0

var _activation = null
var _targets: Array = []
var _origin := Vector2.ZERO
var _kill_reflections := {}


static func parameter_contract() -> Dictionary:
	return {
		"radius": {"type": "number", "minimum": 0.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"pair_interval": {"type": "number", "minimum": 0.01},
		"original_damage": {"type": "number", "minimum": 0.0},
		"reflection_damage": {"type": "number", "minimum": 0.0},
		"reflection_radius": {"type": "number", "minimum": 0.0},
		"reflection_cap": {"type": "integer", "minimum": 1},
		"kill_burst_damage": {"type": "number", "minimum": 0.0},
		"kill_burst_radius": {"type": "number", "minimum": 0.0},
		"kill_burst_cap": {"type": "integer", "minimum": 1},
		"lifetime": {"type": "number", "minimum": 0.1},
	}


static func execute(activation) -> float:
	var targets: Array = activation.select_targets(
		activation.origin(),
		activation.param_float("radius", 620.0),
		activation.param_int("crowd_cap", 12),
		"nearest"
	)
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets)
	activation.present("weapon_ultimate.phase.dark_mage.dark_book.execute", {
		"position": activation.origin(),
		"radius": activation.param_float("radius", 620.0) * 0.32,
		"shape": "orb_burst",
	})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.6)
	tween.tween_interval(release_delay)
	for index in targets.size():
		if index > 0:
			tween.tween_interval(activation.param_float("pair_interval", 0.24))
		tween.tween_callback(Callable(effect, "detonate_pair").bind(index))
	var elapsed: float = release_delay + activation.param_float("pair_interval", 0.24) \
		* float(maxi(targets.size() - 1, 0))
	var lifetime: float = activation.param_float("lifetime", 5.2)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


func configure(activation, targets: Array) -> void:
	_activation = activation
	_targets = targets.duplicate()
	_origin = activation.origin()
	global_position = _origin


## One original and one mirrored point are resolved as one pair. A lethal
## original may burst at its reflection once; the burst never enters this path.
func detonate_pair(index: int) -> void:
	if _activation == null or _activation.is_finished() or index < 0 or index >= _targets.size():
		return
	var original := _targets[index] as Node2D
	if not _alive(original):
		return
	var mirror_point := _origin * 2.0 - original.global_position
	pair_count_for_tests += 1
	var original_result = _deal(
		original,
		_activation.scaled_damage("original_damage", 0.0),
		"abyss_original:%d" % index,
		false,
		{"ultimate_mechanic": "abyss_original", "pair": index}
	)
	for raw_target in _activation.select_targets(
		mirror_point,
		_activation.param_float("reflection_radius", 150.0),
		_activation.param_int("reflection_cap", 2),
		"nearest"
	):
		var reflected := raw_target as Node2D
		if reflected == null or not is_instance_valid(reflected):
			continue
		var reflected_result = _deal(
			reflected,
			_activation.scaled_damage("reflection_damage", 0.0),
			"abyss_reflection:%d" % index,
			true,
			{"ultimate_mechanic": "abyss_reflection", "pair": index}
		)
		if reflected_result != null and float(reflected_result.applied) > 0.0 \
			and bool(reflected_result.killed):
			_trigger_kill_reflection(reflected, index)
	_activation.present("weapon_ultimate.phase.dark_mage.dark_book.active", {
		"position": mirror_point,
		"radius": _activation.param_float("reflection_radius", 150.0),
		"shape": "orb_burst",
	})
	if original_result != null and bool(original_result.killed):
		_trigger_kill_reflection(original, index)


func _trigger_kill_reflection(killed: Node2D, pair_index: int) -> void:
	if killed == null or not is_instance_valid(killed):
		return
	var killed_id := killed.get_instance_id()
	if _kill_reflections.has(killed_id):
		return
	_kill_reflections[killed_id] = true
	_kill_reflection(_origin * 2.0 - killed.global_position, pair_index)


func _kill_reflection(center: Vector2, pair_index: int) -> void:
	kill_reflection_count_for_tests += 1
	for raw_target in _activation.select_targets(
		center,
		_activation.param_float("kill_burst_radius", 135.0),
		_activation.param_int("kill_burst_cap", 3),
		"nearest"
	):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		_deal(
			target,
			_activation.scaled_damage("kill_burst_damage", 0.0),
			"abyss_kill_reflection:%d" % pair_index,
			true,
			{"ultimate_mechanic": "abyss_kill_reflection", "pair": pair_index}
		)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _alive(target: Node2D) -> bool:
	return target != null and is_instance_valid(target) \
		and (target.get("health") == null or float(target.get("health")) > 0.0)


func _exit_tree() -> void:
	_targets.clear()
	_kill_reflections.clear()
	_activation = null
