extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.doctor.plague_syringe"
const EXECUTOR_ID := "weapon_ultimate.executor.doctor.plague_syringe"
const SELF_PATH := "res://scripts/ultimates/classes/doctor/plague_syringe.gd"


static func parameter_contract() -> Dictionary:
	return {
		"release_delay": {"type": "number", "minimum": 0.0},
		"wave_count": {"type": "integer", "minimum": 1},
		"wave_interval": {"type": "number", "minimum": 0.01},
		"wave_visual_radius": {"type": "number", "minimum": 1.0},
		"direct_damage": {"type": "number", "minimum": 0.0},
		"wave_damage": {"type": "number", "minimum": 0.0},
		"heal_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"repair_total": {"type": "number", "minimum": 0.0},
		"finale_tail": {"type": "number", "minimum": 0.0},
		# FAN-2090: declared end of the whole cast chain (release + waves +
		# finale tail) for the smoke lifecycle oracle; the executor does not read it.
		"mask_fade_at": {"type": "number", "minimum": 0.1},
	}


static func execute(activation) -> float:
	# Ultimate Direction v2: patient zero is the highest-HP target, but every
	# live enemy is infected before the five fixed waves begin.
	var infected: Array = activation.select_targets(activation.origin(), INF, 0, "highest_hp")
	if infected.is_empty() or not activation.configure_repair(activation.scaled_damage("repair_total", 9.0)):
		return 0.0
	var patient := infected[0] as Node2D
	if patient == null:
		return 0.0
	var state := {"infected": infected, "patient": patient}
	activation.present(EXECUTOR_ID + ".inject", {"position": patient.global_position, "radius": 52.0, "shape": "orb_burst"})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("release_delay", 0.42))
	tween.tween_callback(Callable(script, "direct_hit").bind(activation, state))
	var waves: int = activation.param_int("wave_count", 5)
	for wave in waves:
		tween.tween_interval(activation.param_float("wave_interval", 1.0))
		tween.tween_callback(Callable(script, "wave").bind(activation, state, wave))
	tween.tween_interval(activation.param_float("finale_tail", 0.43))
	tween.tween_callback(Callable(script, "finale").bind(activation, state))
	return activation.param_float("release_delay", 0.42) \
		+ activation.param_float("wave_interval", 1.0) * float(waves) \
		+ activation.param_float("finale_tail", 0.43)


static func direct_hit(activation, state: Dictionary) -> void:
	var patient := state.get("patient") as Node
	if activation == null or activation.is_finished() or patient == null or not is_instance_valid(patient):
		return
	var result = activation.deal_damage(
		patient,
		activation.scaled_damage("direct_damage", 1.5),
		{"ultimate_mechanic": "black_epidemic_patient_zero"},
		"plague_direct"
	)
	_repair(activation, float(result.applied), "plague_direct_repair")
	activation.present(EXECUTOR_ID + ".veins", {"position": (patient as Node2D).global_position, "radius": 90.0, "shape": "ring_pulse"})


static func wave(activation, state: Dictionary, wave_index: int) -> void:
	if activation == null or activation.is_finished():
		return
	var infected: Array = state.get("infected", [])
	var removed := 0.0
	for raw_target in infected:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var result = activation.deal_damage(
			target,
			activation.scaled_damage("wave_damage", 0.5),
			{"ultimate_mechanic": "black_epidemic_wave", "wave": wave_index},
			"plague_wave:%d:%d" % [wave_index, target.get_instance_id()],
			true
		)
		removed += float(result.applied)
	_repair(activation, removed, "plague_wave_repair:%d" % wave_index)
	activation.present(EXECUTOR_ID + ".wave", {
		"position": activation.origin(),
		"radius": activation.param_float("wave_visual_radius", 240.0),
		"shape": "ring_pulse",
	})


static func finale(activation, state: Dictionary) -> void:
	if activation == null or activation.is_finished():
		return
	var patient := state.get("patient") as Node2D
	activation.present(EXECUTOR_ID + ".mask", {
		"position": patient.global_position if patient != null and is_instance_valid(patient) else activation.origin(),
		"radius": 150.0, "shape": "orb_burst",
	})


static func _repair(activation, removed: float, event_id: String) -> void:
	var host := activation.get("host") as Node
	if host == null or not is_instance_valid(host):
		return
	var player := host.get("player") as Node
	activation.repair(
		player if player != null and is_instance_valid(player) else host,
		removed * activation.param_float("heal_ratio", 0.15),
		event_id
	)
