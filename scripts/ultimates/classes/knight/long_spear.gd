extends Node2D

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.knight.long_spear"
const EXECUTOR_ID := "weapon_ultimate.executor.knight.long_spear"
const EFFECT_SCENE := "res://scripts/ultimates/classes/knight/long_spear.tscn"
const HIT_KEY := "knight_long_spear_phalanx_hit"

var row_order_for_tests: Array[int] = []

var _activation = null
var _targets: Array = []
var _direction := Vector2.RIGHT
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"aim_range": {"type": "number", "minimum": 0.01},
		"corridor_half_width": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 1},
		"row_count": {"type": "integer", "minimum": 3, "maximum": 3},
		"row_interval": {"type": "number", "minimum": 0.01},
		"damage": {"type": "number", "minimum": 0.0},
		"stagger": {"type": "number", "minimum": 0.0},
		"pin_duration": {"type": "number", "minimum": 0.0},
		"pin_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
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
		"half_width": activation.param_float("corridor_half_width", 72.0),
		"limit": activation.param_int("target_limit", 18),
	}):
		return 0.0
	var targets = activation.primitive_value("targets", [])
	var direction = activation.primitive_value("direction", Vector2.RIGHT)
	if not targets is Array or not direction is Vector2:
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets as Array, direction as Vector2)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var rows: int = activation.param_int("row_count", 3)
	var interval: float = activation.param_float("row_interval", 0.32)
	for row in rows:
		tween.tween_callback(Callable(effect, "advance_row").bind(row))
		if row < rows - 1:
			tween.tween_interval(interval)
	var elapsed := interval * float(rows - 1)
	var recover_time: float = activation.param_float("recover_time", 1.4)
	if recover_time > elapsed:
		tween.tween_interval(recover_time - elapsed)
	return maxf(recover_time, elapsed)


func configure(activation, targets: Array, direction: Vector2) -> void:
	_activation = activation
	_targets = targets.duplicate()
	_direction = direction.normalized()
	global_position = activation.origin()


## Corridor membership is snapshotted at cast start. Each target is assigned to
## one row, and the activation ledger claims it before either control or damage.
func advance_row(row: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	var rows: int = _activation.param_int("row_count", 3)
	if row < 0 or row >= rows:
		return
	row_order_for_tests.append(row + 1)
	_activation.present(EXECUTOR_ID + ".row", {
		"row": row + 1,
		"row_count": rows,
		"from": global_position,
		"to": global_position + _direction * _activation.param_float("aim_range", 780.0),
	})
	for index in _targets.size():
		if index % rows != row:
			continue
		var target := _targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		if not _activation.record_target_value(target, HIT_KEY, row + 1, "phalanx_hit"):
			continue
		if _is_normal(target):
			_apply_normal_control(target, row)
		_activation.deal_damage(
			target,
			_activation.scaled_damage("damage", 10.0),
			{
				"damage_type": "pierce",
				"ultimate_mechanic": "phalanx_pierce",
				"phalanx_row": row + 1,
			},
			"phalanx_pierce",
			false
		)


func _is_normal(target: Node) -> bool:
	return not target.is_in_group(Activation.EPIC_GROUP) and not target.is_in_group(Activation.BOSS_GROUP)


func _apply_normal_control(target: Node2D, row: int) -> void:
	var status_id := "knight_long_spear_pin_%d_%d" % [get_instance_id(), target.get_instance_id()]
	var result: Dictionary = _activation.apply_control(
		target,
		_direction * _activation.param_float("stagger", 180.0),
		status_id,
		{
			"duration": _activation.param_float("pin_duration", 1.2),
			"movement_locked": true,
			"speed_multiplier": _activation.param_float("pin_slow", 0.35),
			"knight_long_spear_pin": true,
			"phalanx_row": row + 1,
		}
	)
	if bool(result.get("status_applied", false)):
		_leased_statuses.append({"target": target, "status_id": status_id})


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
