extends Node2D

const PROFILE_ID := "weapon_ultimate.profile.priest.priest_censer"
const EXECUTOR_ID := "weapon_ultimate.executor.priest.priest_censer"
const EFFECT_SCENE := "res://scripts/ultimates/classes/priest/priest_censer.tscn"
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/priest/priest_censer/priest_censer_spriteframes.tres")

## Ultimate Direction v2 (FAN-2535): the ward remains a prevention-funded
## counter, but a funded finish now reaches every live enemy. The visible arc
## shapes rank falloff; a per-target floor replaces its old radius/count rail.

var ultimate_damage_sink: Callable = Callable()
var stored_prevented_for_tests := 0.0
var counter_burst_for_tests := 0.0

var _activation = null
var _ultimate_host: Node = null
var _player: Node = null
var _equipped_weapon: Node = null
var _last_direction := Vector2.RIGHT
var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"ward_absorb": {"type": "number", "minimum": 0.0},
		"stored_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"stored_cap": {"type": "number", "minimum": 0.0},
		"counter_at": {"type": "number", "minimum": 0.0},
		"counter_damage_cap": {"type": "number", "minimum": 0.0},
		"counter_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"counter_floor": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	activation.apply_modifier("absorb_flat", activation.scaled_damage("ward_absorb", 0.0), "add")
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var counter_at: float = activation.param_float("counter_at", 6.3)
	if counter_at > 0.0:
		tween.tween_interval(counter_at)
	tween.tween_callback(Callable(effect, "counter_burst"))
	var lifetime: float = maxf(activation.param_float("lifetime", 7.6), counter_at)
	if lifetime > counter_at:
		tween.tween_interval(lifetime - counter_at)
	return lifetime


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	_player = _player_from_host()
	if _player == null:
		return
	_ultimate_host = activation.host
	var active_weapon = _player.get("equipped_weapon")
	if active_weapon is Node and is_instance_valid(active_weapon) and active_weapon != self:
		_equipped_weapon = active_weapon
		_sync_weapon_direction()
		_player.set("equipped_weapon", self)
	# The activation unwinds modifiers before this queued node leaves the tree.
	# Proxying its host lets Censer remove its zero-valued key synchronously.
	activation.host = self


func ultimate_host_context() -> Dictionary:
	return _ultimate_host.call("ultimate_host_context")


func ultimate_host_position() -> Vector2:
	return _ultimate_host.call("ultimate_host_position")


func ultimate_host_aim(max_range: float) -> Dictionary:
	return _ultimate_host.call("ultimate_host_aim", max_range)


func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
	return _ultimate_host.call("ultimate_host_targets", center, radius, limit)


func ultimate_host_summons(group_id: String) -> Array:
	return _ultimate_host.call("ultimate_host_summons", group_id)


func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
	_ultimate_host.call("ultimate_host_apply_damage", target, amount, feedback)


func ultimate_host_modifier(key: String, value: float, op: String) -> void:
	_ultimate_host.call("ultimate_host_modifier", key, value, op)
	if key == "absorb_flat" and _erase_zero_absorb_key():
		_restore_equipped_weapon()


func ultimate_host_effect_parent() -> Node:
	return _ultimate_host.call("ultimate_host_effect_parent")


func ultimate_host_present(event_id: String, payload: Dictionary) -> Node:
	return _ultimate_host.call("ultimate_host_present", event_id, payload)


## Optional host channel, so the proxy forwards it only when the real host
## exposes it and reports no presentation otherwise.
func ultimate_host_presentation_active() -> bool:
	return _ultimate_host.has_method("ultimate_host_presentation_active") \
		and bool(_ultimate_host.call("ultimate_host_presentation_active"))


func ultimate_host_set_active(active: bool) -> void:
	_ultimate_host.call("ultimate_host_set_active", active)


## Player routes every measured prevention through the equipped weapon's generic
## owner-event seam. While active, this node observes that payload and forwards
## the event unchanged to the real weapon.
func constellation_owner_event(event: String, context := {}, enemy: Node2D = null) -> Dictionary:
	var payload: Dictionary = context if context is Dictionary else {}
	if event == "damage_absorbed":
		_store_actual_prevention(payload)
	if _equipped_weapon != null and is_instance_valid(_equipped_weapon) \
			and _equipped_weapon.has_method("constellation_owner_event"):
		return _equipped_weapon.call("constellation_owner_event", event, payload, enemy)
	if _player != null and is_instance_valid(_player) \
			and _player.has_method("constellation_weapon_event"):
		return _player.call(
			"constellation_weapon_event", str(_player.get("weapon_id")), event, payload, enemy
		)
	return {"valid": true, "triggered": false}


func _store_actual_prevention(context: Dictionary) -> void:
	if _activation == null or _activation.is_finished():
		return
	var prevented := maxf(float(context.get("absorbed_amount", 0.0)), 0.0)
	if prevented <= 0.0:
		return
	var cap: float = _activation.scaled_damage("stored_cap", 0.0)
	stored_prevented_for_tests = minf(
		stored_prevented_for_tests + prevented * _activation.param_float("stored_ratio", 0.0),
		cap
	)


func _process(_delta: float) -> void:
	_sync_weapon_direction()


func _sync_weapon_direction() -> void:
	if _equipped_weapon == null or not is_instance_valid(_equipped_weapon):
		return
	var direction = _equipped_weapon.get("_last_direction")
	if direction is Vector2:
		_last_direction = direction


func counter_burst() -> void:
	if _activation == null or _activation.is_finished() or stored_prevented_for_tests <= 0.0:
		return
	counter_burst_for_tests = minf(
		stored_prevented_for_tests,
		_activation.scaled_damage("counter_damage_cap", 0.0)
	)
	if counter_burst_for_tests <= 0.0:
		return
	var targets: Array = _activation.select_targets(
		_activation.origin(),
		INF,
		0,
		"nearest"
	)
	for index in targets.size():
		var target := targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		_deal(
			target,
			counter_burst_for_tests * maxf(
				pow(_activation.param_float("counter_falloff", 1.0), float(index)),
				_activation.param_float("counter_floor", 0.0)
			),
			"censer_counter:%d" % target.get_instance_id(),
			true,
			{"ultimate_mechanic": "censer_stored_counter", "prevented_damage": stored_prevented_for_tests}
		)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)
		_play_impacts([target])


func _play_impacts(victims: Array) -> void:
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(victims, global_position)
	else:
		_impacts.play(VICTIM_FRAMES, victims, global_position)
		_impacts_started = true


func _player_from_host() -> Node:
	if _activation == null or _activation.host == null or not is_instance_valid(_activation.host):
		return null
	var player = _activation.host.get("player")
	return player as Node if player is Node and is_instance_valid(player) else null


func _exit_tree() -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()
	_impacts = null
	_impacts_started = false
	_restore_equipped_weapon()
	_erase_zero_absorb_key()
	_ultimate_host = null
	_equipped_weapon = null
	_player = null
	_activation = null


func _restore_equipped_weapon() -> void:
	if _player != null and is_instance_valid(_player) and _player.get("equipped_weapon") == self:
		_player.set(
			"equipped_weapon",
			_equipped_weapon if _equipped_weapon != null and is_instance_valid(_equipped_weapon) else null
		)


func _erase_zero_absorb_key() -> bool:
	var modifiers = _player.get("run_modifiers") if _player != null and is_instance_valid(_player) else null
	if not modifiers is Dictionary and _activation != null \
			and _activation.host != null and is_instance_valid(_activation.host):
		modifiers = _activation.host.get("modifiers")
	if modifiers is Dictionary and modifiers.has("absorb_flat") \
			and is_zero_approx(float(modifiers.get("absorb_flat", 0.0))):
		modifiers.erase("absorb_flat")
		return true
	return false
