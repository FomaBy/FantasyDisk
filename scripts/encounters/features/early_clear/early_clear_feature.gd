extends "res://scripts/encounters/encounter_feature.gd"
## Default-off normal-battle early clear. Registration stays outside this pack.

const OBJECTIVE_STATE := preload("res://scripts/encounters/features/early_clear/encounter_objective_state.gd")
const REWARDS := preload("res://scripts/encounters/features/early_clear/early_clear_rewards.gd")

var _settings: Dictionary = {}
var _objective
var _initial_kills := 0
var _captain: Node2D = null
var _end_requested := false
var _reward_granted := false
var _bonus := {"xp": 0, "gold": 0}


func id() -> String:
	return "normal_early_clear"


func is_eligible(context) -> bool:
	return context.is_normal_battle()


func plan(context, _beat_def: Dictionary) -> Dictionary:
	_settings = REWARDS.config()
	var minimum_elapsed := float(_settings.get("minimum_elapsed_seconds", 0.0))
	if context.round_duration <= minimum_elapsed:
		return {}
	_initial_kills = _kills(context)
	return {"trigger_at": minimum_elapsed, "window": context.round_duration - minimum_elapsed}


func on_trigger(context, _beat_def: Dictionary) -> bool:
	if _settings.is_empty():
		_settings = REWARDS.config()
	_objective = OBJECTIVE_STATE.new()
	_objective.configure(
		float(_settings.get("minimum_elapsed_seconds", 0.0)),
		int(_settings.get("quota_kills", 0)),
		bool(_settings.get("captain_required", false)),
	)
	_captain = _pick_captain(context)
	if bool(_settings.get("captain_required", false)) and _captain == null:
		return false
	if _captain != null and _captain.has_signal("died"):
		_captain.died.connect(_on_captain_died)
	return true


func on_tick(context, _delta: float) -> void:
	if _end_requested or _objective == null:
		return
	_objective.advance(context.elapsed)
	_objective.record_kills(_kills(context) - _initial_kills)
	if not _objective.is_ready() or float(context.game.round_time_left) <= 0.0:
		return
	if context.combat == null or not is_instance_valid(context.combat) or not context.combat.has_method("_end_combat"):
		return
	_grant_bonus(context)
	_end_requested = true
	# Deferred avoids re-entering EncounterBeatDirector while it is ticking us.
	context.combat.call_deferred("_end_combat", true)


func is_resolved() -> bool:
	# Timer survival and the requested native combat end both resolve via shutdown().
	return false


func resolve(context, reason: String) -> Dictionary:
	_disconnect_captain()
	var timer_survival := not _end_requested and float(context.game.round_time_left) <= 0.0
	var status := STATUS_COMPLETED if _end_requested or timer_survival else STATUS_FAILED
	var outcome_reason := "early_clear" if _end_requested else ("timer_survival" if timer_survival else reason)
	return make_outcome(id(), status, {
		"reason": outcome_reason,
		"performance_bonus": _bonus.duplicate(true),
		"timer_survival": timer_survival,
	})


func _pick_captain(context) -> Node2D:
	var candidates: Array = context.alive_normal_enemies()
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	return candidates[0] as Node2D


func _on_captain_died(_enemy: Node2D) -> void:
	if _objective != null:
		_objective.mark_captain_complete()


func _kills(context) -> int:
	if context.game == null:
		return 0
	return int((context.game.run_metrics as Dictionary).get("kills", 0))


func _grant_bonus(context) -> void:
	if _reward_granted:
		return
	_bonus = REWARDS.performance_bonus(_kills(context) - _initial_kills)
	var player: Node = context.player()
	if player != null:
		if int(_bonus.get("xp", 0)) > 0 and player.has_method("gain_xp"):
			player.gain_xp(int(_bonus["xp"]))
		if int(_bonus.get("gold", 0)) > 0 and player.has_method("gain_money"):
			player.gain_money(int(_bonus["gold"]))
	_reward_granted = true


func _disconnect_captain() -> void:
	if _captain != null and is_instance_valid(_captain) and _captain.has_signal("died") \
			and _captain.died.is_connected(_on_captain_died):
		_captain.died.disconnect(_on_captain_died)


func debug_objective() -> RefCounted:
	return _objective


func debug_bonus() -> Dictionary:
	return _bonus.duplicate(true)
