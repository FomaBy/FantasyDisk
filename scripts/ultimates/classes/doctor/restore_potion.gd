extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.doctor.restore_potion"
const EXECUTOR_ID := "weapon_ultimate.executor.doctor.restore_potion"
const SELF_PATH := "res://scripts/ultimates/classes/doctor/restore_potion.gd"


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 1.0},
		"release_delay": {"type": "number", "minimum": 0.0},
		"outer_radius": {"type": "number", "minimum": 1.0},
		"inner_radius": {"type": "number", "minimum": 1.0},
		"pulse_count": {"type": "integer", "minimum": 1},
		"pulse_interval": {"type": "number", "minimum": 0.01},
		"outer_damage": {"type": "number", "minimum": 0.0},
		"heal_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"repair_total": {"type": "number", "minimum": 0.0},
		"shield_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"shield_cap": {"type": "number", "minimum": 0.0},
		"shield_duration": {"type": "number", "minimum": 0.1},
		# FAN-2090: declared end of the whole cast chain (release + pulses +
		# shield) for the smoke lifecycle oracle; the executor does not read it.
		"shield_fade_at": {"type": "number", "minimum": 0.1},
	}


static func execute(activation) -> float:
	var point: Vector2 = activation.aim_point(activation.param_float("max_range", 650.0))
	if point == Vector2.ZERO:
		return 0.0
	if not activation.configure_repair(activation.scaled_damage("repair_total", 10.0)):
		return 0.0
	activation.present(EXECUTOR_ID + ".release", {"position": point, "radius": 48.0, "shape": "orb_burst"})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("release_delay", 0.45))
	var pulses: int = activation.param_int("pulse_count", 4)
	for pulse in pulses:
		if pulse > 0:
			tween.tween_interval(activation.param_float("pulse_interval", 0.8))
		tween.tween_callback(Callable(script, "pulse").bind(activation, point, pulse))
	tween.tween_interval(activation.param_float("shield_duration", 1.2))
	return activation.param_float("release_delay", 0.45) \
		+ activation.param_float("pulse_interval", 0.8) * float(pulses - 1) \
		+ activation.param_float("shield_duration", 1.2)


static func pulse(activation, point: Vector2, pulse_index: int) -> void:
	if activation == null or activation.is_finished():
		return
	var removed := 0.0
	var struck: Array = []
	# Ultimate Direction v2: the outer pool is map-wide; its radius remains a
	# presentation shape, not a reach or count limit.
	for raw_target in activation.targets(activation.origin(), INF):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var result = activation.deal_damage(
			target,
			activation.scaled_damage("outer_damage", 0.9),
			{"ultimate_mechanic": "life_death_outer_dot", "pulse": pulse_index},
			"restore_dot:%d" % pulse_index,
			pulse_index > 0
		)
		removed += float(result.applied)
		if float(result.applied) > 0.0:
			struck.append(target)
	# The pulse beat carries the enemies this tick actually damaged, so the
	# authored scene plays one victim burst per hit enemy and none anywhere else.
	activation.present(EXECUTOR_ID + ".pulse", {"position": point, "victims": struck})
	var hero := _hero(activation)
	if hero != null:
		activation.repair(
			hero,
			removed * activation.param_float("heal_ratio", 0.25),
			"restore_repair:%d" % pulse_index
		)
	if pulse_index == 0:
		activation.present(EXECUTOR_ID + ".outer_ring", {
			"position": point, "radius": activation.param_float("outer_radius", 220.0), "shape": "ring_pulse",
		})
		activation.present(EXECUTOR_ID + ".inner_spiral", {
			"position": activation.origin(), "radius": activation.param_float("inner_radius", 100.0), "shape": "ring_pulse",
		})
	if pulse_index == activation.param_int("pulse_count", 4) - 1:
		var absorb := minf(
			removed * activation.param_float("shield_ratio", 0.4),
			activation.scaled_damage("shield_cap", 8.0)
		)
		if absorb > 0.0:
			activation.apply_modifier("absorb_flat", absorb, "add")
			activation.present(EXECUTOR_ID + ".shield", {"position": activation.origin(), "radius": 90.0, "shape": "ring_pulse"})


static func _hero(activation) -> Node:
	var host := activation.get("host") as Node
	if host == null or not is_instance_valid(host):
		return null
	var player := host.get("player") as Node
	return player if player != null and is_instance_valid(player) else host
