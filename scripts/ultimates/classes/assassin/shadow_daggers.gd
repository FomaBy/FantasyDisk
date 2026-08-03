extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.assassin.shadow_daggers"
const EXECUTOR_ID := "weapon_ultimate.executor.assassin.shadow_daggers"
const EFFECT_SCENE := "res://scripts/ultimates/classes/assassin/shadow_daggers.tscn"
const STORED_DAMAGE_KEY := "shadow_dagger_stored_damage"

var ultimate_damage_sink: Callable = Callable()
var marked_count_for_tests := 0
var backstab_count_for_tests := 0
var reveal_count_for_tests := 0
var owner_untargetable_for_tests := false

var _activation = null
var _targets: Array = []
var _leased_player: Node = null
var _previous_invisibility := 0.0
var _leased_invisibility := 0.0


static func parameter_contract() -> Dictionary:
	return {
		"radius": {"type": "number", "minimum": 0.0},
		"target_count": {"type": "integer", "minimum": 1},
		"mark_delay": {"type": "number", "minimum": 0.0},
		"backstab_interval": {"type": "number", "minimum": 0.01},
		"reveal_delay": {"type": "number", "minimum": 0.0},
		"backstab_damage": {"type": "number", "minimum": 0.0},
		"secondary_damage_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"untargetable_duration": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": activation.param_float("radius", 520.0),
		"limit": activation.param_int("target_count", 7),
		"priority": "highest_hp",
		"hint": {},
	}):
		return 0.0
	var targets = activation.primitive_value("targets", [])
	if not targets is Array:
		targets = []
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets as Array)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	tween.tween_interval(activation.param_float("mark_delay", 0.45))
	for index in (targets as Array).size():
		tween.tween_callback(Callable(effect, "backstab").bind(index))
		tween.tween_interval(activation.param_float("backstab_interval", 0.16))
	tween.tween_interval(activation.param_float("reveal_delay", 0.15))
	tween.tween_callback(Callable(effect, "reveal"))
	return activation.param_float("mark_delay", 0.45) \
		+ float((targets as Array).size()) * activation.param_float("backstab_interval", 0.16) \
		+ activation.param_float("reveal_delay", 0.15)


func configure(activation, targets: Array) -> void:
	_activation = activation
	_targets = targets.duplicate()
	global_position = activation.origin()
	for raw_target in _targets:
		var target := raw_target as Node
		if target != null and is_instance_valid(target) \
				and activation.record_target_value(target, STORED_DAMAGE_KEY, 0.0, "mark"):
			marked_count_for_tests += 1
	_lease_owner_untargetable(activation.param_float("untargetable_duration", 1.75))


func backstab(index: int) -> void:
	if _activation == null or _activation.is_finished() or index < 0 or index >= _targets.size():
		return
	var target := _targets[index] as Node
	if target == null or not is_instance_valid(target):
		return
	var ratio: float = 1.0 if index == 0 else _activation.param_float("secondary_damage_ratio", 0.1)
	if _activation.add_target_value(
		target,
		STORED_DAMAGE_KEY,
		_activation.scaled_damage("backstab_damage", 0.0) * ratio,
		"backstab:%d" % index
	):
		backstab_count_for_tests += 1


func reveal() -> void:
	if _activation == null or _activation.is_finished():
		return
	for index in _targets.size():
		var target := _targets[index] as Node
		if target == null or not is_instance_valid(target):
			continue
		var stored = _activation.consume_target_value(
			target, STORED_DAMAGE_KEY, "reveal:%d" % index, null
		)
		if stored == null or float(stored) <= 0.0:
			continue
		reveal_count_for_tests += 1
		_deal(target, float(stored), "reveal:%d" % index, index > 0, {
			"ultimate_mechanic": "moment_before_death_reveal",
			"sequence_index": index,
		})


## Player already owns the canonical short invisibility gate used by Assassin
## shadow bursts. The class-local executor leases that existing field through
## the Player host and restores it on cancellation; no second immunity system
## or shared runtime branch is introduced.
func _lease_owner_untargetable(duration: float) -> void:
	if duration <= 0.0 or _activation == null:
		return
	var host = _activation.host
	if host == null or not is_instance_valid(host) or not "player" in host:
		return
	var player = host.get("player")
	if not player is Node or not is_instance_valid(player) or not "_shadow_invisible_left" in player:
		return
	_leased_player = player as Node
	_previous_invisibility = float(_leased_player.get("_shadow_invisible_left"))
	_leased_invisibility = maxf(_previous_invisibility, duration)
	_leased_player.set("_shadow_invisible_left", _leased_invisibility)
	owner_untargetable_for_tests = true


func _release_owner_untargetable() -> void:
	if _leased_player == null or not is_instance_valid(_leased_player):
		return
	var current := float(_leased_player.get("_shadow_invisible_left"))
	if current > _previous_invisibility and current <= _leased_invisibility + 0.05:
		_leased_player.set("_shadow_invisible_left", _previous_invisibility)
	_leased_player = null
	owner_untargetable_for_tests = false


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_release_owner_untargetable()
	_targets.clear()
	_activation = null
