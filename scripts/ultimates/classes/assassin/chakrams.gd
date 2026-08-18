extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.assassin.chakrams"
const EXECUTOR_ID := "weapon_ultimate.executor.assassin.chakrams"
const EFFECT_SCENE := "res://scripts/ultimates/classes/assassin/chakrams.tscn"
const MARK_KEY := "chakram_outbound_mark"
const CONTROL_POLICY := {
	"normal": {
		"displacement_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"allow_movement_lock": false,
		"allow_execute": true,
	},
	"epic": {
		"displacement_multiplier": 0.0,
		"duration_multiplier": 0.5,
		"allow_movement_lock": false,
		"allow_execute": false,
	},
	"boss": {
		"displacement_multiplier": 0.0,
		"duration_multiplier": 0.25,
		"allow_movement_lock": false,
		"allow_execute": false,
	},
}

var ultimate_damage_sink: Callable = Callable()
var outbound_hits_for_tests := 0
var return_hits_for_tests := 0
var execute_count_for_tests := 0
var orbit_points_for_tests := PackedVector2Array()
var return_paths_for_tests: Array[PackedVector2Array] = []

var _activation = null
var _outbound_hit_ids := {}
var _return_hit_ids := {}
var _primary_target_id := 0


static func parameter_contract() -> Dictionary:
	return {
		"orbit_radius": {"type": "number", "minimum": 0.0},
		"trajectory_length": {"type": "number", "minimum": 0.01},
		"lane_half_width": {"type": "number", "minimum": 0.0},
		"orbit_duration": {"type": "number", "minimum": 0.0},
		"outbound_duration": {"type": "number", "minimum": 0.0},
		"return_steps": {"type": "integer", "minimum": 2},
		"return_step_interval": {"type": "number", "minimum": 0.01},
		"return_curve_offset": {"type": "number", "minimum": 0.0},
		"pass_damage": {"type": "number", "minimum": 0.0},
		"secondary_damage_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"execute_threshold": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("pattern_geometry", activation, {
		"center": "source",
		"pattern": "radial",
		"params": {
			"count": 8,
			"radius": activation.param_float("orbit_radius", 72.0),
			"rotation_degrees": 0.0,
			"arc_degrees": 360.0,
		},
		"hit_radius": 0.0,
		"target_limit": 0,
	}):
		return 0.0
	if not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	tween.tween_interval(activation.param_float("orbit_duration", 0.5))
	tween.tween_callback(Callable(effect, "launch"))
	tween.tween_interval(activation.param_float("outbound_duration", 0.5))
	var return_steps: int = activation.param_int("return_steps", 6)
	var return_interval: float = activation.param_float("return_step_interval", 0.12)
	for step in return_steps:
		tween.tween_callback(Callable(effect, "return_step").bind(step + 1))
		tween.tween_interval(return_interval)
	return activation.param_float("orbit_duration", 0.5) \
		+ activation.param_float("outbound_duration", 0.5) \
		+ float(return_steps) * return_interval


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	orbit_points_for_tests = activation.primitive_value("points", PackedVector2Array())
	return_paths_for_tests.clear()
	for direction in compass_directions():
		return_paths_for_tests.append(curved_return_path(
			activation.origin(),
			activation.origin() + direction * activation.param_float("trajectory_length", 520.0),
			activation.param_float("return_curve_offset", 132.0),
			activation.param_int("return_steps", 6)
		))


static func compass_directions() -> Array[Vector2]:
	var directions: Array[Vector2] = []
	for index in 8:
		directions.append(Vector2.RIGHT.rotated(TAU * float(index) / 8.0))
	return directions


static func curved_return_path(
	origin: Vector2, endpoint: Vector2, curve_offset: float, steps: int
) -> PackedVector2Array:
	var path := PackedVector2Array([endpoint])
	var outward := (endpoint - origin).normalized()
	var control := (endpoint + origin) * 0.5 + Vector2(-outward.y, outward.x) * curve_offset
	for step in steps:
		var t := float(step + 1) / float(steps)
		path.append(endpoint * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + origin * t * t)
	return path


## Ultimate Direction v2 (FAN-2952): the eight lanes decide WHICH chakram claims
## an enemy and how its hit is attributed — never whether it is reached. Every
## live enemy on the map takes the outbound pass, on screen and off; the curved
## return is the geometric second hit layered on top of that floor.
##
## The fan is still walked lane by lane, nearest silhouette first inside a lane,
## so the duel target the first chakram claims is the same one the corridor
## sweep claimed before the conversion — and it is deterministic, because the
## activation hands its targets over in a stable order.
func launch() -> void:
	if _activation == null or _activation.is_finished():
		return
	var origin: Vector2 = _activation.origin()
	var fan: Array[Array] = []
	for _lane in compass_directions().size():
		fan.append([])
	for raw_target in _activation.select_targets(origin, INF, 0, "nearest"):
		var target := raw_target as Node2D
		if _alive(target):
			fan[lane_for(origin, target.global_position)].append(target)
	for lane in fan.size():
		for raw_target in fan[lane]:
			var target := raw_target as Node2D
			if _outbound_hit_ids.has(target.get_instance_id()):
				continue
			_outbound_hit_ids[target.get_instance_id()] = true
			if _primary_target_id == 0:
				_primary_target_id = target.get_instance_id()
			var ratio: float = 1.0 if target.get_instance_id() == _primary_target_id \
				else _activation.param_float("secondary_damage_ratio", 0.12)
			_activation.record_target_value(target, MARK_KEY, ratio, "outbound_mark")
			outbound_hits_for_tests += 1
			_deal(target, _activation.scaled_damage("pass_damage", 0.0) * ratio, "outbound:%d" % lane, ratio < 1.0, {
				"ultimate_mechanic": "eight_moons_outbound",
				"compass_lane": lane,
			})


## The compass lane an enemy belongs to: the nearest of the eight launch
## directions. Lane membership is attribution, not admission.
static func lane_for(origin: Vector2, position: Vector2) -> int:
	var offset := position - origin
	if offset.length_squared() <= 0.001:
		return 0
	return posmod(roundi(offset.angle() / (TAU / 8.0)), 8)


func return_step(step: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	for lane in return_paths_for_tests.size():
		var path := return_paths_for_tests[lane]
		if step <= 0 or step >= path.size():
			continue
		var start := path[step - 1]
		var offset := path[step] - start
		for raw_target in _activation.targets_in_corridor(
			start,
			offset,
			offset.length(),
			_activation.param_float("lane_half_width", 48.0),
			0
		):
			var target := raw_target as Node2D
			if not _alive(target) or _return_hit_ids.has(target.get_instance_id()):
				continue
			var damage_ratio = _activation.consume_target_value(target, MARK_KEY, "return_consume", null)
			if damage_ratio == null:
				continue
			_return_hit_ids[target.get_instance_id()] = true
			return_hits_for_tests += 1
			var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, "", {})
			if bool(result.get("execute_allowed", false)) and _health_ratio(target) \
					<= _activation.param_float("execute_threshold", 0.25):
				execute_count_for_tests += 1
				_deal(target, float(target.get("health")), "return_execute", false, {
					"ultimate_mechanic": "eight_moons_return_execute",
					"compass_lane": lane,
				})
			else:
				_deal(target, _activation.scaled_damage("pass_damage", 0.0) * float(damage_ratio), "return:%d" % lane, float(damage_ratio) < 1.0, {
					"ultimate_mechanic": "eight_moons_return",
					"compass_lane": lane,
				})


func _health_ratio(target: Node) -> float:
	var maximum = target.get("max_health")
	if maximum == null or float(maximum) <= 0.0:
		return 1.0
	return maxf(float(target.get("health")), 0.0) / float(maximum)


func _alive(target: Node2D) -> bool:
	return target != null and is_instance_valid(target) \
		and (target.get("health") == null or float(target.get("health")) > 0.0)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_activation = null
	_outbound_hit_ids.clear()
	_return_hit_ids.clear()
	_primary_target_id = 0
	return_paths_for_tests.clear()
