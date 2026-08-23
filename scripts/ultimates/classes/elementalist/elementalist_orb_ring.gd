extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.elementalist.elementalist_orb_ring"
const EXECUTOR_ID := "weapon_ultimate.executor.elementalist.elementalist_orb_ring"
const EFFECT_SCENE := "res://scripts/ultimates/classes/elementalist/elementalist_orb_ring.tscn"
const ELEMENTS := ["burn", "frost", "gale", "shock"]

var ultimate_damage_sink: Callable = Callable()
var beat_trace_for_tests: Array[String] = []
var nova_count_for_tests := 0

var _activation = null
var _resolved_beats := {}
var _nova_done := false
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"orbit_radius": {"type": "number", "minimum": 1.0},
		"beat_radius": {"type": "number", "minimum": 1.0},
		"nova_radius": {"type": "number", "minimum": 1.0},
		"beat_start": {"type": "number", "minimum": 0.0},
		"beat_interval": {"type": "number", "minimum": 0.01},
		"nova_at": {"type": "number", "minimum": 0.0},
		"lifetime": {"type": "number", "minimum": 0.1},
		"burn_damage": {"type": "number", "minimum": 0.0},
		"frost_damage": {"type": "number", "minimum": 0.0},
		"gale_damage": {"type": "number", "minimum": 0.0},
		"shock_damage": {"type": "number", "minimum": 0.0},
		"shock_chain_count": {"type": "integer", "minimum": 1},
		"shock_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"nova_damage": {"type": "number", "minimum": 0.0},
		"nova_status_bonus": {"type": "number", "minimum": 0.0},
		"freeze_duration": {"type": "number", "minimum": 0.0},
		"frost_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"knockback": {"type": "number", "minimum": 0.0},
		"epic_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy({
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": true, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": activation.param_float("epic_displacement", 0.35),
			"duration_multiplier": activation.param_float("epic_duration", 0.35),
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": activation.param_float("boss_displacement", 0.10),
			"duration_multiplier": activation.param_float("boss_duration", 0.15),
			"allow_movement_lock": false, "allow_execute": false,
		},
	}):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	effect.call("begin")
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var beat_start: float = activation.param_float("beat_start", 1.0)
	var beat_interval: float = activation.param_float("beat_interval", 1.2)
	var elapsed := beat_start
	tween.tween_interval(beat_start)
	for beat in ELEMENTS.size():
		if beat > 0:
			tween.tween_interval(beat_interval)
			elapsed += beat_interval
		tween.tween_callback(Callable(effect, "cast_beat").bind(beat))
	var nova_at: float = activation.param_float("nova_at", 6.0)
	if nova_at > elapsed:
		tween.tween_interval(nova_at - elapsed)
		elapsed = nova_at
	tween.tween_callback(Callable(effect, "combined_nova"))
	var lifetime: float = activation.param_float("lifetime", 8.4)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	set_meta("elementalist_ultimate", "elementalist_orb_ring")


func begin() -> void:
	if not _live():
		return
	_activation.present(EXECUTOR_ID + ".sigils", {
		"position": _activation.origin(),
		"radius": _activation.param_float("orbit_radius", 212.13203435596427),
		"shape": "ring_pulse",
	})


func cast_beat(beat: int) -> void:
	if not _live() or beat < 0 or beat >= ELEMENTS.size() or _resolved_beats.has(beat):
		return
	_resolved_beats[beat] = true
	var element := str(ELEMENTS[beat])
	beat_trace_for_tests.append(element)
	var center: Vector2 = _activation.origin()
	var points := square_points(
		center,
		_activation.param_float("orbit_radius", 212.13203435596427),
		float(beat) * 0.16
	)
	var avatar_position := points[beat]
	_activation.present(EXECUTOR_ID + "." + element, {
		"position": avatar_position,
		"radius": _activation.param_float("beat_radius", 290.0),
		"shape": "orb_burst",
	})
	var targets: Array = _activation.select_targets(
		avatar_position,
		_activation.param_float("beat_radius", 290.0),
		0,
		"nearest"
	)
	if element == "shock":
		_shock_chain(targets)
		return
	for raw_target in targets:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		_activation.record_target_value(
			target, "conclave_" + element, true, "conclave_mark:" + element
		)
		match element:
			"burn":
				_apply_status(target, element, {
					"duration": _activation.param_float("freeze_duration", 4.0) + 1.0,
					"marker_color": Color(1.0, 0.34, 0.12, 0.75),
				})
				_deal(target, _activation.scaled_damage("burn_damage", 9.0),
					"conclave:burn", "conclave_burn")
			"frost":
				_apply_status(target, element, {
					"duration": _activation.param_float("freeze_duration", 4.0),
					"speed_multiplier": _activation.param_float("frost_slow", 0.45),
					"movement_locked": true,
					"marker_color": Color(0.38, 0.82, 1.0, 0.75),
				})
				_deal(target, _activation.scaled_damage("frost_damage", 7.5),
					"conclave:frost", "conclave_frost")
			"gale":
				var direction := target.global_position - center
				if direction.length_squared() <= 0.001:
					direction = Vector2.RIGHT
				_activation.apply_control(
					target,
					direction.normalized() * _activation.param_float("knockback", 420.0),
					"",
					{}
				)
				_deal(target, _activation.scaled_damage("gale_damage", 6.0),
					"conclave:gale", "conclave_gale")


func combined_nova() -> void:
	if not _live() or _nova_done:
		return
	_nova_done = true
	nova_count_for_tests += 1
	var center: Vector2 = _activation.origin()
	var radius: float = _activation.param_float("nova_radius", 440.0)
	_activation.present(EXECUTOR_ID + ".supernova", {
		"position": center, "radius": radius, "shape": "orb_burst",
	})
	for raw_target in _activation.targets(center, radius):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var statuses := 0
		for element in ELEMENTS:
			if bool(_activation.target_value(target, "conclave_" + str(element), false)):
				statuses += 1
		var multiplier: float = 1.0 + float(statuses) \
			* _activation.param_float("nova_status_bonus", 0.10)
		_deal(target, _activation.scaled_damage("nova_damage", 15.0) * multiplier,
			"conclave:nova", "conclave_supernova")


func _shock_chain(targets: Array) -> void:
	var limit := mini(targets.size(), _activation.param_int("shock_chain_count", 6))
	for hop in limit:
		var target := targets[hop] as Node
		if target == null or not is_instance_valid(target):
			continue
		_activation.record_target_value(target, "conclave_shock", true, "conclave_mark:shock")
		var amount: float = _activation.scaled_damage("shock_damage", 7.5) \
			* pow(_activation.param_float("shock_falloff", 0.86), hop)
		_deal(target, amount, "conclave:shock:%d" % hop, "conclave_chain_shock")


func _apply_status(target: Node, element: String, config: Dictionary) -> void:
	var status_id := "elementalist_conclave_%s_%d" % [element, get_instance_id()]
	var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, config)
	if bool(result.get("status_applied", false)):
		_lease_status(target, status_id)


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


static func square_points(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in 4:
		# Corners sit exactly `radius` from the centre; the 45° offset keeps the
		# square's accepted orientation, its first sigil on the down-right diagonal.
		points.append(center + Vector2(radius, 0.0).rotated(
			rotation + PI * 0.25 + corner * PI * 0.5
		))
	return points


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
