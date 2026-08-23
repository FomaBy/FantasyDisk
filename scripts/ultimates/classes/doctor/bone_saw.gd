extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.doctor.bone_saw"
const EXECUTOR_ID := "weapon_ultimate.executor.doctor.bone_saw"
const SELF_PATH := "res://scripts/ultimates/classes/doctor/bone_saw.gd"


static func parameter_contract() -> Dictionary:
	return {
		"orbit_radius": {"type": "number", "minimum": 1.0},
		"tick_count": {"type": "integer", "minimum": 1},
		"tick_interval": {"type": "number", "minimum": 0.01},
		"tick_damage": {"type": "number", "minimum": 0.0},
		"drain_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"repair_total": {"type": "number", "minimum": 0.0},
		"vitality_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"shield_cap": {"type": "number", "minimum": 0.0},
		"shield_duration": {"type": "number", "minimum": 0.1},
		# FAN-2090: declared end of the whole cast chain (orbit ticks + stitch
		# shield) for the smoke lifecycle oracle; the executor does not read it.
		"shield_fade_at": {"type": "number", "minimum": 0.1},
		"armor_shred": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not activation.configure_repair(activation.scaled_damage("repair_total", 10.0)):
		return 0.0
	var state := {"vitality": 0.0}
	activation.present(EXECUTOR_ID + ".stance", {"position": activation.origin(), "radius": 110.0, "shape": "ring_pulse"})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	var ticks: int = activation.param_int("tick_count", 6)
	for tick in ticks:
		if tick > 0:
			tween.tween_interval(activation.param_float("tick_interval", 0.5))
		tween.tween_callback(Callable(script, "tick").bind(activation, state, tick))
	tween.tween_callback(Callable(script, "shield").bind(activation, state))
	tween.tween_interval(activation.param_float("shield_duration", 1.35))
	return activation.param_float("tick_interval", 0.5) * float(ticks - 1) \
		+ activation.param_float("shield_duration", 1.35)


static func tick(activation, state: Dictionary, tick_index: int) -> void:
	if activation == null or activation.is_finished():
		return
	var removed := 0.0
	for raw_target in activation.targets(
		activation.origin(),
		activation.param_float("orbit_radius", 240.0)
	):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var result = activation.deal_damage(
			target,
			activation.scaled_damage("tick_damage", 0.7),
			{
				"ultimate_mechanic": "emergency_surgery_orbit",
				"armor_shred": activation.param_float("armor_shred", 0.18),
				"tick": tick_index,
			},
			"saw_tick:%d:%d" % [tick_index, target.get_instance_id()],
			tick_index > 0
		)
		removed += float(result.applied)
	state["vitality"] = float(state.get("vitality", 0.0)) + removed \
		* activation.param_float("vitality_ratio", 0.4)
	var host := activation.get("host") as Node
	if host != null and is_instance_valid(host):
		var player := host.get("player") as Node
		activation.repair(
			player if player != null and is_instance_valid(player) else host,
			removed * activation.param_float("drain_ratio", 0.4),
			"saw_repair:%d" % tick_index
		)
	activation.present(EXECUTOR_ID + ".orbit", {"position": activation.origin(), "radius": activation.param_float("orbit_radius", 240.0), "shape": "ring_pulse"})


static func shield(activation, state: Dictionary) -> void:
	if activation == null or activation.is_finished():
		return
	var absorb := minf(float(state.get("vitality", 0.0)), activation.scaled_damage("shield_cap", 9.0))
	if absorb <= 0.0:
		return
	activation.apply_modifier("absorb_flat", absorb, "add")
	activation.present(EXECUTOR_ID + ".stitch_shield", {"position": activation.origin(), "radius": 105.0, "shape": "ring_pulse"})
