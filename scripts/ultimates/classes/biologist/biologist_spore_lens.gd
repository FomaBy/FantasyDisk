extends Node2D

## Doubles as the root script of the authored presentation scene
## (BiologistSporeLensWorldMycelium.tscn): the static half executes the
## mechanics, the effect half runs infection waves, and the presentation
## instance receives beat payloads while the scene is the live channel and
## plays the shared per-victim impact for the enemies each wave actually hit.

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/biologist/spore_lens/spore_lens_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.biologist.biologist_spore_lens"
const EXECUTOR_ID := "weapon_ultimate.executor.biologist.biologist_spore_lens"
const EFFECT_SCENE := "res://scripts/ultimates/classes/biologist/biologist_spore_lens.tscn"

var ultimate_damage_sink: Callable = Callable()
var bloom_count_for_tests := 0
var propagation_count_for_tests := 0

var _activation = null
var _leased_statuses: Array[Dictionary] = []
var _targets: Array = []
var _origin := Vector2.ZERO
var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"propagation_interval": {"type": "number", "minimum": 0.01},
		"propagation_waves": {"type": "integer", "minimum": 1},
		"infection_damage": {"type": "number", "minimum": 0.0},
		"infection_duration": {"type": "number", "minimum": 0.1},
		"root_duration": {"type": "number", "minimum": 0.1},
		"slow_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"secondary_bloom_cap": {"type": "integer", "minimum": 0},
		"secondary_bloom_radius": {"type": "number", "minimum": 0.0},
		"secondary_bloom_targets": {"type": "integer", "minimum": 1},
		"secondary_bloom_damage": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not Library.execute_primitive("control_resistance_policy", activation, _control_policy()):
		return 0.0
	var waves: int = activation.param_int("propagation_waves", 3)
	var selected: Array = activation.select_targets(
		activation.origin(), INF, 0, "nearest"
	)
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, selected)
	# Contact germination is immediate so activation always has a measurable
	# gameplay result; the accepted 0.9s release remains the first outward branch.
	effect.call("propagate", 0)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.9)
	var interval: float = activation.param_float("propagation_interval", 1.45)
	for wave in range(1, waves):
		if wave == 1:
			tween.tween_interval(release_delay)
		else:
			tween.tween_interval(interval)
		tween.tween_callback(Callable(effect, "propagate").bind(wave))
	var elapsed: float = release_delay + interval * float(maxi(waves - 2, 0)) \
		if waves > 1 else 0.0
	var tail := maxf(activation.param_float("lifetime", 8.6) - elapsed, 0.0)
	if tail > 0.0:
		tween.tween_interval(tail)
	return activation.param_float("lifetime", 8.6)


static func _control_policy() -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 1.0,
			"allow_movement_lock": true,
			"allow_execute": true,
		},
		"epic": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 0.45,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 0.2,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
	}


func configure(activation, selected: Array) -> void:
	_activation = activation
	_targets = selected.duplicate()
	_origin = activation.origin()
	global_position = _origin


func propagate(wave: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	propagation_count_for_tests += 1
	var victims: Array = []
	for raw_target in _targets:
		if raw_target == null or not is_instance_valid(raw_target):
			continue
		var target := raw_target as Node2D
		if target == null:
			continue
		_ensure_infected(target)
		var result = _deal(
			target,
			_activation.scaled_damage("infection_damage", 0.0),
			"spore_infection:%d" % wave,
			false,
			{"ultimate_mechanic": "spore_infection", "propagation_wave": wave}
		)
		victims.append(target)
		if result != null and bool(result.killed) and bool(result.creditable):
			_secondary_bloom(target, wave, victims)
	_activation.present(EXECUTOR_ID + ".propagate:%d" % wave, {
		"shape": "ring_pulse", "position": _origin, "radius": 240.0,
		"victims": victims,
	})


func _ensure_infected(target: Node2D) -> void:
	for lease in _leased_statuses:
		if lease.get("target") == target:
			return
	var status_id := "biologist_ultimate_spore_%d" % get_instance_id()
	var applied: Dictionary = _activation.apply_control(
		target,
		Vector2.ZERO,
		status_id,
		{
			"duration": _activation.param_float("root_duration", 5.0),
			"movement_locked": true,
			"speed_multiplier": _activation.param_float("slow_multiplier", 0.45),
			"infection": true,
		}
	)
	if bool(applied.get("status_applied", false)):
		_leased_statuses.append({"target": target, "status_id": status_id})


func _secondary_bloom(source: Node2D, wave: int, victims: Array) -> void:
	if bloom_count_for_tests >= _activation.param_int("secondary_bloom_cap", 3):
		return
	bloom_count_for_tests += 1
	var neighbors: Array = _activation.select_targets(
		source.global_position,
		_activation.param_float("secondary_bloom_radius", 150.0),
		_activation.param_int("secondary_bloom_targets", 3) + 1,
		"nearest"
	)
	var hit_count := 0
	for raw_neighbor in neighbors:
		if raw_neighbor == null or not is_instance_valid(raw_neighbor):
			continue
		var neighbor := raw_neighbor as Node2D
		if neighbor == null or neighbor == source:
			continue
		_deal(
			neighbor,
			_activation.scaled_damage("secondary_bloom_damage", 0.0),
			"spore_bloom:%d:%d" % [wave, bloom_count_for_tests],
			true,
			{"ultimate_mechanic": "secondary_bloom", "bloom": bloom_count_for_tests}
		)
		victims.append(neighbor)
		hit_count += 1
		if hit_count >= _activation.param_int("secondary_bloom_targets", 3):
			break


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func present(_event_id: String, payload: Dictionary) -> void:
	_play_impacts(payload.get("victims"))


func finish(_reason: String) -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()


func _play_impacts(raw_victims: Variant) -> void:
	if not raw_victims is Array or (raw_victims as Array).is_empty():
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(raw_victims as Array, global_position)
	else:
		_impacts.play(VICTIM_FRAMES, raw_victims as Array, global_position)
		_impacts_started = true


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_activation = null
	_impacts = null
	_impacts_started = false


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
