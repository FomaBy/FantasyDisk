extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.elementalist.elementalist_prism_focus"
const EXECUTOR_ID := "weapon_ultimate.executor.elementalist.elementalist_prism_focus"
const EFFECT_SCENE := "res://scripts/ultimates/classes/elementalist/elementalist_prism_focus.tscn"

var ultimate_damage_sink: Callable = Callable()
var sweep_count_for_tests := 0
var shatter_count_for_tests := 0

var _activation = null
var _focus := Vector2.ZERO
var _resolved_sweeps := {}
var _shattered := false
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"half_reach": {"type": "number", "minimum": 1.0},
		"half_width": {"type": "number", "minimum": 0.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"sweep_count": {"type": "integer", "minimum": 1},
		"sweep_start": {"type": "number", "minimum": 0.0},
		"sweep_interval": {"type": "number", "minimum": 0.01},
		"rotation_step_degrees": {"type": "number"},
		"lattice_hit_cap": {"type": "integer", "minimum": 1},
		"lattice_damage": {"type": "number", "minimum": 0.0},
		"focus_radius": {"type": "number", "minimum": 0.0},
		"focus_orbit_radius": {"type": "number", "minimum": 0.0},
		"focus_multiplier": {"type": "number", "minimum": 1.0},
		"shatter_at": {"type": "number", "minimum": 0.0},
		"shatter_radius": {"type": "number", "minimum": 0.0},
		"shatter_damage": {"type": "number", "minimum": 0.0},
		"fracture_duration": {"type": "number", "minimum": 0.0},
		"fracture_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"lifetime": {"type": "number", "minimum": 0.1},
	}


static func execute(activation) -> float:
	var aim: Dictionary = activation.aim_context(activation.param_float("max_range", 800.0))
	if aim.is_empty():
		return 0.0
	if not activation.set_control_resistance_policy({
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": activation.param_float("epic_duration", 0.50),
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": activation.param_float("boss_duration", 0.25),
			"allow_movement_lock": false, "allow_execute": false,
		},
	}):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, aim["target"] as Vector2)
	effect.call("begin")
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var sweep_start: float = activation.param_float("sweep_start", 0.85)
	var interval: float = activation.param_float("sweep_interval", 0.9)
	var elapsed := sweep_start
	tween.tween_interval(sweep_start)
	for sweep in activation.param_int("sweep_count", 6):
		if sweep > 0:
			tween.tween_interval(interval)
			elapsed += interval
		tween.tween_callback(Callable(effect, "fire_sweep").bind(sweep))
	var shatter_at: float = activation.param_float("shatter_at", 6.4)
	if shatter_at > elapsed:
		tween.tween_interval(shatter_at - elapsed)
		elapsed = shatter_at
	tween.tween_callback(Callable(effect, "shatter"))
	var lifetime: float = activation.param_float("lifetime", 7.2)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


func configure(activation, focus: Vector2) -> void:
	_activation = activation
	_focus = focus
	global_position = focus
	set_meta("elementalist_ultimate", "elementalist_prism_focus")


func begin() -> void:
	if not _live():
		return
	_activation.present(EXECUTOR_ID + ".unfold", {
		"position": _focus, "radius": 90.0, "shape": "orb_burst",
	})


func fire_sweep(sweep: int) -> void:
	if not _live() or sweep < 0 \
			or sweep >= _activation.param_int("sweep_count", 6) \
			or _resolved_sweeps.has(sweep):
		return
	_resolved_sweeps[sweep] = true
	sweep_count_for_tests += 1
	var angle := deg_to_rad(45.0 + float(sweep) \
		* _activation.param_float("rotation_step_degrees", 7.5))
	var directions := [Vector2.RIGHT.rotated(angle), Vector2.RIGHT.rotated(angle + PI * 0.5)]
	var targets: Array = []
	var seen := {}
	for direction in directions:
		var half_reach: float = _activation.param_float("half_reach", 2400.0)
		var start := _focus - (direction as Vector2) * half_reach
		var finish := _focus + (direction as Vector2) * half_reach
		_activation.present(EXECUTOR_ID + ".lattice", {
			"from": start, "to": finish, "position": finish, "shape": "beam",
		})
		for raw_target in _activation.targets_in_corridor(
			start,
			direction,
			half_reach * 2.0,
			_activation.param_float("half_width", 74.0),
			0
		):
			var target := raw_target as Node
			if target == null or not is_instance_valid(target) or seen.has(target.get_instance_id()):
				continue
			seen[target.get_instance_id()] = true
			targets.append(target)
	var focus_points := _focus_points(angle)
	for raw_target in targets:
		var target := raw_target as Node2D
		var hits := int(_activation.target_value(target, "prism_lattice_hits", 0))
		if hits >= _activation.param_int("lattice_hit_cap", 3):
			continue
		if not _activation.add_target_value(
			target, "prism_lattice_hits", 1.0, "prism_hit:%d" % sweep
		):
			continue
		var multiplier := 1.0
		for point in focus_points:
			if target.global_position.distance_to(point) \
					<= _activation.param_float("focus_radius", 100.0):
				multiplier = _activation.param_float("focus_multiplier", 1.20)
				break
		_deal(target, _activation.scaled_damage("lattice_damage", 5.0) * multiplier,
			"prism:lattice:%d" % sweep, "prism_lattice")
	for point in focus_points:
		_activation.present(EXECUTOR_ID + ".focus", {
			"position": point, "radius": _activation.param_float("focus_radius", 100.0),
			"shape": "ring_pulse",
		})


func shatter() -> void:
	if not _live() or _shattered:
		return
	_shattered = true
	shatter_count_for_tests += 1
	var radius: float = _activation.param_float("shatter_radius", 260.0)
	_activation.present(EXECUTOR_ID + ".shatter", {
		"position": _focus, "radius": radius, "shape": "orb_burst",
	})
	for raw_target in _activation.select_targets(_focus, radius, 0, "nearest"):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		_deal(target, _activation.scaled_damage("shatter_damage", 3.5),
			"prism:shatter", "prism_fracture")
		var status_id := "elementalist_prism_fracture_%d" % get_instance_id()
		var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
			"duration": _activation.param_float("fracture_duration", 2.4),
			"speed_multiplier": _activation.param_float("fracture_slow", 0.70),
			"marker_color": Color(0.72, 0.48, 1.0, 0.75),
		})
		if bool(result.get("status_applied", false)):
			_lease_status(target, status_id)


func hit_count_for(target: Node) -> int:
	return int(_activation.target_value(target, "prism_lattice_hits", 0)) if _live() else 0


func _focus_points(angle: float) -> PackedVector2Array:
	var offset: Vector2 = Vector2.RIGHT.rotated(angle + PI * 0.25) \
		* _activation.param_float("focus_orbit_radius", 180.0)
	return PackedVector2Array([_focus + offset, _focus - offset])


func _lease_status(target: Node, status_id: String) -> void:
	for lease in _leased_statuses:
		if lease.get("target") == target and str(lease.get("status_id", "")) == status_id:
			return
	_leased_statuses.append({"target": target, "status_id": status_id})


func _deal(target: Node, amount: float, event_id: String, mechanic: String) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(target, amount, {
			"ultimate_mechanic": mechanic,
		}, event_id, false)


func _live() -> bool:
	return _activation != null and not _activation.is_finished()


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_activation = null


static func _remove_leased_status(lease: Dictionary) -> void:
	var target = lease.get("target")
	if target == null or not is_instance_valid(target) or not (target as Node).has_meta(StatusEffects.META_KEY):
		return
	var statuses = (target as Node).get_meta(StatusEffects.META_KEY)
	if not statuses is Dictionary:
		return
	var owned := (statuses as Dictionary).duplicate(true)
	owned.erase(str(lease.get("status_id", "")))
	if owned.is_empty():
		(target as Node).remove_meta(StatusEffects.META_KEY)
	else:
		(target as Node).set_meta(StatusEffects.META_KEY, owned)
