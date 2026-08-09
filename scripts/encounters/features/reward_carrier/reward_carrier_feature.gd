extends "res://scripts/encounters/encounter_feature.gd"
## Default-off fleeing normal target with a single capped reward transfer.

const CARRIER_SCENE := preload("res://scenes/encounters/reward_carrier.tscn")
const SPAWN_SALT := 0x52CA771D
const ROUND_TAIL_MARGIN := 2.0
const MAX_REWARD_XP := 12
const MAX_REWARD_MONEY := 12

var _settings: Dictionary = {}
var _carrier: Node2D = null
var _player: Node = null
var _active_time := 0.0
var _confirmed_defeat := false
var _reward_transferred := false
var _resolved := false
var _status := ""
var _reason := ""


func id() -> String:
	return "reward_carrier"


func is_eligible(context) -> bool:
	return context.is_normal_battle()


func plan(context, beat_def: Dictionary) -> Dictionary:
	if not _load_settings(beat_def):
		return {}
	var latest := float(context.round_duration) - float(_settings["duration_seconds"]) - ROUND_TAIL_MARGIN
	if latest < float(_settings["min_seconds"]):
		return {}
	var rng: RandomNumberGenerator = context.aspect_rng(int(_settings["seed_salt"]))
	if rng.randf() > float(_settings["spawn_chance"]):
		return {}
	return {"trigger_at": minf(rng.randf_range(_settings["min_seconds"], _settings["max_seconds"]), latest)}


func on_trigger(context, beat_def: Dictionary) -> bool:
	if not _load_settings(beat_def) or not context.is_normal_battle() or context.game == null:
		return false
	var carrier := CARRIER_SCENE.instantiate() as Node2D
	if carrier == null:
		return false
	context.game.add_child(carrier)
	carrier.add_to_group("enemies")
	carrier.set_physics_process(false)
	carrier.set("move_speed", float(_settings["flee_speed"]))
	carrier.global_position = _spawn_position(context)
	if not context.exclude_from_wave_quota(carrier):
		carrier.queue_free()
		return false
	carrier.set_meta("reward_carrier", true)
	carrier.set_meta("reward_carrier_reward_xp", int(_settings["reward_xp"]))
	carrier.set_meta("reward_carrier_reward_money", int(_settings["reward_money"]))
	_carrier = carrier
	_player = context.player()
	if carrier.has_signal("died") and not carrier.died.is_connected(_on_carrier_died):
		carrier.died.connect(_on_carrier_died)
	return true


func on_tick(context, delta: float) -> void:
	if _resolved:
		return
	_active_time += delta
	if not _is_live(_carrier):
		_finish(STATUS_FAILED, "carrier_lost")
		return
	if _active_time >= float(_settings["duration_seconds"]):
		_finish(STATUS_FAILED, "carrier_escaped")
		return
	var direction: Vector2 = _carrier.global_position - context.player_position()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	_carrier.global_position += direction.normalized() * float(_settings["flee_speed"]) * delta


func is_resolved() -> bool:
	return _resolved


func resolve(_context, reason: String) -> Dictionary:
	_transfer_confirmed_reward()
	if not _resolved:
		_finish(STATUS_ABORTED if reason == "no_target" else STATUS_FAILED, reason)
	_cleanup()
	return make_outcome(id(), _status, {
		"duration": _active_time,
		"reason": _reason,
		"confirmed_defeat": _confirmed_defeat,
		"reward_transferred": _reward_transferred,
	})


func _load_settings(beat_def: Dictionary) -> bool:
	var window = beat_def.get("trigger_window")
	var payload = beat_def.get("payload")
	if not (window is Dictionary) or not (payload is Dictionary):
		return false
	var min_seconds = window.get("min_seconds")
	var max_seconds = window.get("max_seconds")
	var duration = beat_def.get("duration_seconds")
	var seed_salt = beat_def.get("seed_salt")
	var spawn_chance = beat_def.get("spawn_chance")
	var safe_radius = payload.get("safe_radius")
	var flee_speed = payload.get("flee_speed")
	var reward_xp = payload.get("reward_xp")
	var reward_money = payload.get("reward_money")
	if not _number_between(min_seconds, 2.0, 55.0) or not _number_between(max_seconds, float(min_seconds), 55.0) \
			or not _number_between(duration, 2.0, 15.0) or not _number_between(spawn_chance, 0.05, 1.0) or not (seed_salt is int) \
			or not _number_between(safe_radius, 420.0, 900.0) or not _number_between(flee_speed, 80.0, 480.0) \
			or not _whole_between(reward_xp, 1, MAX_REWARD_XP) or not _whole_between(reward_money, 1, MAX_REWARD_MONEY):
		return false
	_settings = {
		"min_seconds": float(min_seconds), "max_seconds": float(max_seconds),
		"duration_seconds": float(duration), "seed_salt": seed_salt, "spawn_chance": float(spawn_chance),
		"safe_radius": float(safe_radius), "flee_speed": float(flee_speed),
		"reward_xp": int(reward_xp), "reward_money": int(reward_money),
	}
	return true


func _spawn_position(context) -> Vector2:
	var rng: RandomNumberGenerator = context.aspect_rng(int(_settings["seed_salt"]) ^ SPAWN_SALT)
	return context.player_position() + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * float(_settings["safe_radius"])


func _on_carrier_died(enemy: Node2D) -> void:
	if _resolved or _confirmed_defeat or enemy != _carrier:
		return
	_confirmed_defeat = true
	_transfer_confirmed_reward()
	_finish(STATUS_COMPLETED, "carrier_defeated")


func _transfer_confirmed_reward() -> void:
	if not _confirmed_defeat or _reward_transferred or not _is_live(_player) \
			or not _player.has_method("gain_xp") or not _player.has_method("gain_money"):
		return
	_player.gain_xp(int(_settings.get("reward_xp", 0)))
	_player.gain_money(int(_settings.get("reward_money", 0)))
	_reward_transferred = true


func _finish(status: String, reason: String) -> void:
	if _resolved:
		return
	_status = status
	_reason = reason
	_resolved = true


func _cleanup() -> void:
	if _is_live(_carrier):
		if _carrier.has_signal("died") and _carrier.died.is_connected(_on_carrier_died):
			_carrier.died.disconnect(_on_carrier_died)
		_carrier.queue_free()
	_carrier = null


static func _number_between(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and float(value) >= minimum and float(value) <= maximum


static func _whole_between(value: Variant, minimum: int, maximum: int) -> bool:
	return _number_between(value, minimum, maximum) and float(value) == floorf(float(value))


static func _is_live(node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


func debug_carrier() -> Node2D:
	return _carrier
