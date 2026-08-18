extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.assassin.venom_wire"
const EXECUTOR_ID := "weapon_ultimate.executor.assassin.venom_wire"
const EFFECT_SCENE := "res://scripts/ultimates/classes/assassin/venom_wire.tscn"
const STACK_KEY := "venom_wire_stacks"
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
var web_points_for_tests := PackedVector2Array()
var web_segments_for_tests: Array[PackedVector2Array] = []
var cut_count_for_tests := 0
var pull_count_for_tests := 0
var burst_count_for_tests := 0

var _activation = null
var _affected: Dictionary = {}
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"web_radius": {"type": "number", "minimum": 0.01},
		"wire_half_width": {"type": "number", "minimum": 0.0},
		"cut_pulses": {"type": "integer", "minimum": 1},
		"cut_interval": {"type": "number", "minimum": 0.01},
		"max_cuts_per_pulse": {"type": "integer", "minimum": 1},
		"cut_damage": {"type": "number", "minimum": 0.0},
		"burst_damage": {"type": "number", "minimum": 0.0},
		"stack_bonus": {"type": "number", "minimum": 0.0},
		"pull_strength": {"type": "number", "minimum": 0.0},
		"poison_duration": {"type": "number", "minimum": 0.0},
		"poison_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("pattern_geometry", activation, {
		"center": "source",
		"pattern": "polygon",
		"params": {
			"count": 6,
			"radius": activation.param_float("web_radius", 300.0),
			"rotation_degrees": -90.0,
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
	var pulses: int = activation.param_int("cut_pulses", 3)
	var interval: float = activation.param_float("cut_interval", 0.35)
	for pulse in pulses:
		tween.tween_callback(Callable(effect, "cut_pulse").bind(pulse))
		tween.tween_interval(interval)
	tween.tween_callback(Callable(effect, "toxin_burst"))
	return float(pulses) * interval


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	web_points_for_tests = activation.primitive_value("points", PackedVector2Array())
	web_segments_for_tests = web_segments(web_points_for_tests)


## Six perimeter edges plus three opposing chords are the Black Web. Keeping
## the formation as segment data makes the same geometry drive runtime hits and
## focused proof instead of inferring mechanics from presentation sprites.
static func web_segments(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if points.size() != 6:
		return segments
	for index in 6:
		segments.append(PackedVector2Array([points[index], points[(index + 1) % 6]]))
	for index in 3:
		segments.append(PackedVector2Array([points[index], points[index + 3]]))
	return segments


## Ultimate Direction v2 (FAN-2952): the Black Web is map-wide. Every live enemy
## takes the pulse's base cut wherever it stands, on screen or off; the nine
## shipped wires raise that to one cut per crossing, bounded by
## `max_cuts_per_pulse` — a per-target shaping bound, never a reach bound.
func cut_pulse(pulse: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	var hits_by_target: Dictionary = {}
	for raw_target in _activation.select_targets(global_position, INF, 0, "nearest"):
		var target := raw_target as Node2D
		if _alive(target):
			hits_by_target[target.get_instance_id()] = {"target": target, "crossings": 0}
	for segment in web_segments_for_tests:
		var offset := segment[1] - segment[0]
		for raw_target in _activation.targets_in_corridor(
			segment[0],
			offset,
			offset.length(),
			_activation.param_float("wire_half_width", 32.0),
			0
		):
			var target := raw_target as Node2D
			if target == null or not hits_by_target.has(target.get_instance_id()):
				continue
			var crossed := hits_by_target[target.get_instance_id()] as Dictionary
			crossed["crossings"] = int(crossed["crossings"]) + 1
	for target_id in hits_by_target:
		var entry := hits_by_target[target_id] as Dictionary
		var target := entry["target"] as Node2D
		var cuts := clampi(
			int(entry["crossings"]), 1, _activation.param_int("max_cuts_per_pulse", 3)
		)
		var first_contact := not _affected.has(target_id)
		_affected[target_id] = target
		_activation.add_target_value(target, STACK_KEY, float(cuts), "cuts:%d" % pulse)
		cut_count_for_tests += cuts
		_deal(
			target,
			_activation.scaled_damage("cut_damage", 0.0) * float(cuts),
			"cut:%d" % pulse,
			false,
			{"ultimate_mechanic": "black_web_poison_cut", "cuts": cuts, "pulse": pulse}
		)
		_pull_and_poison(target, first_contact)


func toxin_burst() -> void:
	if _activation == null or _activation.is_finished():
		return
	for target_id in _affected.keys():
		var target := _affected[target_id] as Node
		if target == null or not is_instance_valid(target):
			continue
		var stacks = _activation.consume_target_value(target, STACK_KEY, "toxin_burst", null)
		if stacks == null or float(stacks) <= 0.0:
			continue
		burst_count_for_tests += 1
		var multiplier: float = 1.0 + maxf(float(stacks) - 1.0, 0.0) \
			* _activation.param_float("stack_bonus", 0.08)
		_deal(
			target,
			_activation.scaled_damage("burst_damage", 0.0) * multiplier,
			"toxin_burst",
			false,
			{"ultimate_mechanic": "black_web_toxin_burst", "poison_stacks": stacks}
		)


func _pull_and_poison(target: Node2D, first_contact: bool) -> void:
	var toward_center := global_position - target.global_position
	var impulse := toward_center.normalized() * minf(
		_activation.param_float("pull_strength", 360.0), toward_center.length()
	) if toward_center.length_squared() > 0.001 else Vector2.ZERO
	# The poison is leased once per silhouette; every later pulse only drags it
	# toward the center. Re-writing an identical status on every pulse bought
	# nothing but a refreshed timer.
	if not first_contact:
		if bool(_activation.apply_control(target, impulse, "", {}).get("displaced", false)):
			pull_count_for_tests += 1
		return
	var status_id := "assassin_ultimate_black_web_%d_%d" % [get_instance_id(), target.get_instance_id()]
	var result: Dictionary = _activation.apply_control(target, impulse, status_id, {
		"duration": _activation.param_float("poison_duration", 3.0),
		"speed_multiplier": _activation.param_float("poison_slow", 0.72),
		"venom_wire_poisoned": true,
	})
	if bool(result.get("displaced", false)):
		pull_count_for_tests += 1
	if bool(result.get("status_applied", false)):
		_leased_statuses.append({"target": target, "status_id": status_id})


func _alive(target: Node2D) -> bool:
	return target != null and is_instance_valid(target) \
		and (target.get("health") == null or float(target.get("health")) > 0.0)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_affected.clear()
	web_segments_for_tests.clear()
	_activation = null


func _remove_leased_status(lease: Dictionary) -> void:
	var raw_target = lease.get("target")
	if raw_target == null or not is_instance_valid(raw_target):
		return
	var target := raw_target as Node
	if target == null or not target.has_meta(StatusEffects.META_KEY):
		return
	var statuses = target.get_meta(StatusEffects.META_KEY)
	if not statuses is Dictionary:
		return
	var owned := (statuses as Dictionary).duplicate(true)
	owned.erase(str(lease.get("status_id", "")))
	if owned.is_empty():
		target.remove_meta(StatusEffects.META_KEY)
	else:
		target.set_meta(StatusEffects.META_KEY, owned)
