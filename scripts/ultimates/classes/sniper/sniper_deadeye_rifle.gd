extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/sniper/deadeye_rifle/deadeye_rifle_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.sniper.sniper_deadeye_rifle"
const EXECUTOR_ID := "weapon_ultimate.executor.sniper.sniper_deadeye_rifle"
const EFFECT_SCENE := "res://scripts/ultimates/classes/sniper/sniper_deadeye_rifle.tscn"

var ultimate_damage_sink: Callable = Callable()
var priority_target_for_tests: Node = null
var rail_size_for_tests := 0

var _activation = null
var _rail: Array = []
var _impacts = null


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"arena_radius": {"type": "number", "minimum": 0.01},
		"recover_delay": {"type": "number", "minimum": 0.0},
		"shot_damage": {"type": "number", "minimum": 0.0},
		"headshot_multiplier": {"type": "number", "minimum": 1.0},
	}


static func execute(activation) -> float:
	var max_range: float = activation.param_float("max_range", 940.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": max_range,
		"target_mode": "host_aim",
	}):
		return 0.0
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": activation.param_float("arena_radius", 100000.0),
		"limit": 0,
		"priority": "highest_hp",
		"hint": {},
	}):
		return 0.0
	var rail = activation.primitive_value("targets", [])
	if not rail is Array:
		rail = []
	var priority: Node2D = _priority_target(rail as Array)
	if priority != null:
		activation.set_primitive_state({"primary_target": priority})
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, rail as Array, priority)
	# The lock is presentation; the shot itself is the ultimate, so it resolves
	# on the activation frame and only the recovery window is scheduled.
	effect.call("fire")
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var recover_delay: float = activation.param_float("recover_delay", 0.25)
	tween.tween_interval(recover_delay)
	return recover_delay


## The rail is ordered by projection, but the shot answers to threat: the
## highest-HP silhouette on it takes the headshot wherever it stands.
static func _priority_target(rail: Array) -> Node2D:
	var selected: Node2D = null
	var highest_hp := -INF
	for raw_target in rail:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var health_value = target.get("health")
		var health := float(health_value) if health_value != null else 0.0
		if selected == null or health > highest_hp:
			selected = target
			highest_hp = health
	return selected


func configure(activation, rail: Array, priority: Node2D) -> void:
	_activation = activation
	_rail = rail.duplicate()
	rail_size_for_tests = _rail.size()
	priority_target_for_tests = priority
	global_position = activation.origin()


## One shot, one map-wide pass. The priority silhouette gets the headshot while
## every other living enemy receives the same non-trivial Deadeye floor.
func fire() -> void:
	if _activation == null or _activation.is_finished():
		return
	var shot: float = _activation.scaled_damage("shot_damage", 0.0)
	var victims: Array[Node2D] = []
	for index in _rail.size():
		var target := _rail[index] as Node2D
		if not _alive(target):
			continue
		var amount := shot
		var mechanic := "deadeye_floor"
		if target == priority_target_for_tests:
			amount = shot * _activation.param_float("headshot_multiplier", 1.5)
		_deal(
			target,
			amount,
			"deadeye_shot:%d" % index,
			mechanic == "deadeye_floor",
			{"ultimate_mechanic": mechanic}
		)
		victims.append(target)
	_play_impacts(victims)


func _play_impacts(victims: Array) -> void:
	if victims.is_empty():
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts.play(VICTIM_FRAMES, victims, global_position)
		return
	_impacts.enqueue(victims, global_position)


func _alive(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var health_value = target.get("health")
	return health_value == null or float(health_value) > 0.0


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_activation = null
	_rail.clear()
	_impacts = null
