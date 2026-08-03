extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.soldier.soldier_bayonet"
const EXECUTOR_ID := "weapon_ultimate.executor.soldier.soldier_bayonet"
const EFFECT_SCENE := "res://scripts/ultimates/classes/soldier/soldier_bayonet.tscn"
const GUARD_KEY := "soldier_bayonet_guard_prevention"
const PIN_KEY := "soldier_bayonet_pinned"
const CONTROL_POLICY := {
	"normal": {
		"displacement_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"allow_movement_lock": true,
		"allow_execute": false,
	},
	"epic": {
		"displacement_multiplier": 0.25,
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

var _activation = null
var _targets: Array = []
var _direction := Vector2.RIGHT
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"aim_range": {"type": "number", "minimum": 0.01},
		"corridor_half_width": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 1},
		"rank_count": {"type": "integer", "minimum": 1},
		"rank_interval": {"type": "number", "minimum": 0.01},
		"damage": {"type": "number", "minimum": 0.0},
		"knockback": {"type": "number", "minimum": 0.0},
		"pin_duration": {"type": "number", "minimum": 0.0},
		"pin_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"guard_defense": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"recover_time": {"type": "number", "minimum": 0.01},
	}


static func execute(activation) -> float:
	var aim_range: float = activation.param_float("aim_range", 780.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": aim_range,
		"target_mode": "host_aim",
	}):
		return 0.0
	if not Library.execute_primitive("line_pierce_geometry", activation, {
		"start": "source",
		"direction": "aim",
		"length": aim_range,
		"half_width": activation.param_float("corridor_half_width", 78.0),
		"limit": activation.param_int("target_limit", 18),
	}):
		return 0.0
	if not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	var targets = activation.primitive_value("targets", [])
	var direction = activation.primitive_value("direction", Vector2.RIGHT)
	if not targets is Array or not direction is Vector2:
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets as Array, direction as Vector2)
	activation.composition_step("control")
	var guard: float = activation.param_float("guard_defense", 0.25)
	activation.apply_modifier("defense_flat", guard, "add")
	var guard_owner := activation.host as Node
	if guard_owner != null:
		activation.record_target_value(
			guard_owner, GUARD_KEY, guard, "soldier_bayonet_guard_open"
		)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var ranks: int = activation.param_int("rank_count", 3)
	var interval: float = activation.param_float("rank_interval", 0.48)
	for rank in ranks:
		tween.tween_interval(interval)
		tween.tween_callback(Callable(effect, "charge_rank").bind(rank))
	var elapsed := interval * float(ranks)
	var recover_time: float = activation.param_float("recover_time", 4.25)
	if recover_time > elapsed:
		tween.tween_interval(recover_time - elapsed)
	return maxf(recover_time, elapsed)


func configure(activation, targets: Array, direction: Vector2) -> void:
	_activation = activation
	_targets = targets.duplicate()
	_direction = direction.normalized()
	global_position = activation.origin()


## Each silhouette belongs to exactly one time-offset rank. The activation
## ledger claims the pin before either control or damage, so a repeated rank or
## overlapping corridor can never hit the same target twice.
func charge_rank(rank: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	var rank_count: int = _activation.param_int("rank_count", 3)
	for index in _targets.size():
		if index % rank_count != rank:
			continue
		var target := _targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		if not _activation.record_target_value(
			target, PIN_KEY, 1.0, "soldier_bayonet_pin"
		):
			continue
		var status_id := "soldier_bayonet_pin_%d_%d" % [get_instance_id(), target.get_instance_id()]
		var result: Dictionary = _activation.apply_control(
			target,
			_direction * _activation.param_float("knockback", 260.0),
			status_id,
			{
				"duration": _activation.param_float("pin_duration", 2.4),
				"movement_locked": true,
				"speed_multiplier": _activation.param_float("pin_slow", 0.35),
				"soldier_bayonet_pin": true,
			}
		)
		if bool(result.get("status_applied", false)):
			_leased_statuses.append({"target": target, "status_id": status_id})
		_activation.deal_damage(
			target,
			_activation.scaled_damage("damage", 100.0),
			{"ultimate_mechanic": "last_charge", "rank": rank},
			"soldier_bayonet_hit",
			false
		)
	_activation.present(EXECUTOR_ID + ".rank", {
		"shape": "beam",
		"from": global_position,
		"to": global_position + _direction * _activation.param_float("aim_range", 780.0),
	})


func guard_value_for_tests() -> float:
	if _activation == null or _activation.host == null:
		return 0.0
	return float(_activation.target_value(_activation.host, GUARD_KEY, 0.0))


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_targets.clear()
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
