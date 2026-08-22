extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const PROFILE_ID := "weapon_ultimate.profile.biologist.biologist_sample_injector"
const EXECUTOR_ID := "weapon_ultimate.executor.biologist.biologist_sample_injector"
const EFFECT_SCENE := "res://scripts/ultimates/classes/biologist/biologist_sample_injector.tscn"

var ultimate_damage_sink: Callable = Callable()
var analysis_pulse_count_for_tests := 0
var primary_target_for_tests: Node = null

var _activation = null
var _corridor_targets: Array = []
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"release_delay": {"type": "number", "minimum": 0.0},
		"sample_window": {"type": "number", "minimum": 0.1},
		"analysis_pulses": {"type": "integer", "minimum": 1},
		"analysis_first_delay": {"type": "number", "minimum": 0.01},
		"analysis_interval": {"type": "number", "minimum": 0.01},
		"arena_radius": {"type": "number", "minimum": 0.01},
		"extraction_damage": {"type": "number", "minimum": 0.0},
		"analysis_damage": {"type": "number", "minimum": 0.0},
		"tissue_damage_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"swarm_bonus": {"type": "number", "minimum": 1.0},
		"ranged_bonus": {"type": "number", "minimum": 1.0},
		"durable_bonus": {"type": "number", "minimum": 1.0},
	}


## Ultimate Direction v2: the needle still opens on the highest-HP silhouette
## on its priority rail, but every analysis pulse now reads the whole arena —
## the primary takes the full scan while every other live enemy takes the
## tissue echo, so reach is bounded per TARGET, never per count.
static func execute(activation) -> float:
	var max_range: float = activation.param_float("max_range", 760.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": max_range,
		"target_mode": "host_aim",
	}):
		return 0.0
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": activation.param_float("arena_radius", 100000.0),
		"limit": 0,
		"priority": "highest_hp",
		"hint": {},
	}):
		return 0.0
	var targets = activation.primitive_value("targets", [])
	if not targets is Array:
		targets = []
	var primary: Node2D = _priority_target(targets as Array)
	if primary != null:
		activation.set_primitive_state({"primary_target": primary})
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets as Array, primary)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.8)
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(effect, "extract"))
	tween.tween_interval(activation.param_float("analysis_first_delay", 0.35))
	var pulses: int = activation.param_int("analysis_pulses", 3)
	for pulse in pulses:
		if pulse > 0:
			tween.tween_interval(activation.param_float("analysis_interval", 0.55))
		tween.tween_callback(Callable(effect, "analysis_pulse").bind(pulse))
	var elapsed: float = release_delay + activation.param_float("analysis_first_delay", 0.35) \
		+ activation.param_float("analysis_interval", 0.55) * float(maxi(pulses - 1, 0))
	var lifetime: float = release_delay + activation.param_float("sample_window", 2.2)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


static func _priority_target(targets: Array) -> Node2D:
	var selected: Node2D = null
	var highest_hp := -INF
	for raw_target in targets:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var health_value = target.get("health")
		var health := float(health_value) if health_value != null else 0.0
		if selected == null or health > highest_hp:
			selected = target
			highest_hp = health
	return selected


static func archetype_multiplier(target: Node, params: Dictionary) -> float:
	if target == null or not is_instance_valid(target):
		return 1.0
	if target.is_in_group(Activation.BOSS_GROUP) or target.is_in_group(Activation.EPIC_GROUP):
		return float(params.get("durable_bonus", 1.35))
	var archetype := str(_property_value(target, "archetype", "")).to_lower()
	if archetype in ["durable", "bruiser", "tank"]:
		return float(params.get("durable_bonus", 1.35))
	if archetype in ["ranged", "caster", "support"]:
		return float(params.get("ranged_bonus", 1.25))
	return float(params.get("swarm_bonus", 1.15))


static func _property_value(target: Object, property_name: String, fallback):
	for property in target.get_property_list():
		if str((property as Dictionary).get("name", "")) == property_name:
			return target.get(property_name)
	return fallback


func configure(activation, targets: Array, primary: Node2D) -> void:
	_activation = activation
	_corridor_targets = targets.duplicate()
	primary_target_for_tests = primary
	global_position = activation.origin()


func extract() -> void:
	if not _valid_primary():
		return
	var status_id := "biologist_ultimate_sample_%d" % get_instance_id()
	StatusEffects.apply_status(primary_target_for_tests, status_id, {
		"duration": _activation.param_float("sample_window", 2.2),
		"sampled": true,
		"direct_hit_bonus": _sample_bonus(),
	})
	_leased_statuses.append({"target": primary_target_for_tests, "status_id": status_id})
	_activation.record_target_value(
		primary_target_for_tests,
		"sample_direct_hit_bonus",
		_sample_bonus(),
		"sample_extracted"
	)
	_deal(
		primary_target_for_tests,
		_activation.scaled_damage("extraction_damage", 0.0) * _sample_bonus(),
		"sample_extraction",
		false,
		{"ultimate_mechanic": "sample_extraction", "archetype_bonus": _sample_bonus()}
	)


func analysis_pulse(pulse: int) -> void:
	if pulse >= _activation.param_int("analysis_pulses", 3):
		return
	analysis_pulse_count_for_tests += 1
	var amount: float = _activation.scaled_damage("analysis_damage", 0.0)
	if _valid_primary():
		_deal(
			primary_target_for_tests,
			amount * _sample_bonus(),
			"sample_analysis:%d" % pulse,
			false,
			{"ultimate_mechanic": "analysis_pulse", "analysis_pulse": pulse}
		)
	# The tissue echo reaches every live enemy in the arena, not a capped
	# neighbourhood of the primary: the per-enemy floor is the contract.
	var nearby: Array = _activation.select_targets(
		(primary_target_for_tests as Node2D).global_position if _valid_primary() else _activation.origin(),
		_activation.param_float("arena_radius", 100000.0),
		0,
		"nearest"
	)
	for raw_target in nearby:
		var target := raw_target as Node2D
		if target == null or target == primary_target_for_tests or not _corridor_targets.has(target):
			continue
		_deal(
			target,
			amount * _activation.param_float("tissue_damage_ratio", 0.35),
			"sample_tissue:%d" % pulse,
			true,
			{"ultimate_mechanic": "analysis_tissue", "analysis_pulse": pulse}
		)


func _sample_bonus() -> float:
	if not _valid_primary():
		return 1.0
	return archetype_multiplier(primary_target_for_tests, _activation.params)


func _valid_primary() -> bool:
	return _activation != null and not _activation.is_finished() \
		and primary_target_for_tests != null and is_instance_valid(primary_target_for_tests)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
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
