extends "res://scripts/encounters/encounter_feature.gd"
## Default-off, act-scoped opt-in contract. Its own manifest is the only
## registration point; no shared encounter registry needs an edit.

const OFFER_SCENE := preload("res://scenes/ui/encounter_contract_offer.tscn")
const RISK_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const LEDGER := preload("res://scripts/encounters/features/contracts/contract_reward_ledger.gd")

const FEATURE_ID := "next_phase_contract"
const RISK_META := &"next_phase_contract_risk"

var _settings: Dictionary = {}
var _context = null
var _offer: Control = null
var _risk_enemies: Array[Node2D] = []
var _pending_enemy_ids := {}
var _mode := ""
var _resolved := false
var _status := STATUS_ABORTED
var _reason := ""
var _reward: Dictionary = {"xp": 0, "gold": 0}
var _reward_claimed := false


func id() -> String:
	return FEATURE_ID


func is_eligible(context) -> bool:
	if context == null or not context.is_normal_battle():
		return false
	var state: Dictionary = context.act_feature_state(FEATURE_ID)
	if bool(state.get("quarantined", false)):
		return false
	if state.is_empty():
		return true
	return str(state.get("decision", "")) == "accepted" \
		and (str(state.get("risk", "")) == "armed" \
			or (str(state.get("risk", "")) == "succeeded" and int(state.get("claim_count", 0)) == 0))


func plan(context, beat_def: Dictionary) -> Dictionary:
	_settings = LEDGER.settings(beat_def)
	if _settings.is_empty() or not is_eligible(context):
		return {}
	# The choice happens before this feature creates its explicitly marked phase.
	return {"trigger_at": 0.0, "window": float(_settings["timeout_seconds"])}


func on_trigger(context, beat_def: Dictionary) -> bool:
	_settings = LEDGER.settings(beat_def)
	if _settings.is_empty() or not is_eligible(context):
		return false
	_context = context
	var state: Dictionary = context.act_feature_state(FEATURE_ID)
	if str(state.get("risk", "")) == "armed":
		return _begin_risk_phase()
	if str(state.get("risk", "")) == "succeeded" and int(state.get("claim_count", 0)) == 0:
		return _claim_reward()
	return _show_offer()


func on_tick(_context_ref, _delta: float) -> void:
	if _resolved or _mode != "risk":
		return
	for enemy in _risk_enemies:
		if enemy == null or not is_instance_valid(enemy) \
				or (enemy.is_queued_for_deletion() and _pending_enemy_ids.has(enemy.get_instance_id())):
			_finish_risk(false, "risk_interrupted")
			return


func is_resolved() -> bool:
	return _resolved


func resolve(_context_ref, reason: String) -> Dictionary:
	if not _resolved:
		_status = STATUS_ABORTED
		_reason = reason
		_resolved = true
	_cleanup()
	return make_outcome(id(), _status, {
		"reason": _reason,
		"risk": str(_state().get("risk", "")),
		"reward": _reward.duplicate(true),
		"reward_claimed": _reward_claimed,
	})


func _show_offer() -> bool:
	if _context == null or _context.game == null:
		return false
	_offer = OFFER_SCENE.instantiate() as Control
	if _offer == null:
		return false
	var host: Node = _context.game.hud_layer if _context.game.get("hud_layer") != null else _context.game
	host.add_child(_offer)
	_offer.decision_made.connect(_on_offer_decision)
	var stage := int(_context.route_scaling_stage)
	_reward = LEDGER.reward_for_stage(_settings, stage)
	_offer.present({
		"timeout_seconds": float(_settings["timeout_seconds"]),
		"risk_percent": int(round((float(_settings["risk_multiplier"]) - 1.0) * 100.0)),
		"risk_enemies": LEDGER.risk_enemy_count(_settings, stage),
		"reward_xp": int(_reward["xp"]),
		"reward_gold": int(_reward["gold"]),
		"reward_capped": bool(_reward["capped"]),
	})
	_mode = "offer"
	return true


func _on_offer_decision(decision: String, reason: String) -> void:
	if _resolved or _context == null:
		return
	_offer = null
	if decision != "accepted":
		if _checkpoint("declined", "", 0, "decline:contract"):
			_finish(STATUS_ABORTED, reason)
		else:
			_finish(STATUS_FAILED, "decline_checkpoint_failed")
		return
	if not _checkpoint("accepted", "armed", 0, "offer:contract"):
		_finish(STATUS_FAILED, "accept_checkpoint_failed")
		return
	_begin_risk_phase()


func _begin_risk_phase() -> bool:
	if _context == null or _context.game == null:
		return false
	_mode = "risk"
	var count := LEDGER.risk_enemy_count(_settings, int(_context.route_scaling_stage))
	for index in range(count):
		var enemy := RISK_ENEMY_SCENE.instantiate() as Node2D
		if enemy == null:
			_finish_risk(false, "risk_spawn_failed")
			return false
		enemy.name = "ContractRiskEnemy%d" % (index + 1)
		enemy.set_meta(RISK_META, true)
		enemy.set("reward_xp", 0)
		enemy.set("reward_money", 0)
		enemy.set("max_health", float(enemy.get("max_health")) * float(_settings["risk_multiplier"]))
		enemy.set("contact_damage", float(enemy.get("contact_damage")) * float(_settings["risk_multiplier"]))
		enemy.global_position = _risk_position(index, count)
		_context.game.add_child(enemy)
		if not enemy.has_signal("died"):
			enemy.queue_free()
			_finish_risk(false, "risk_signal_missing")
			return false
		enemy.died.connect(_on_risk_enemy_died)
		_risk_enemies.append(enemy)
		_pending_enemy_ids[enemy.get_instance_id()] = true
	return not _risk_enemies.is_empty()


func _risk_position(index: int, count: int) -> Vector2:
	var angle := TAU * float(index) / float(maxi(count, 1))
	return _context.player_position() + Vector2.RIGHT.rotated(angle) * 480.0


func _on_risk_enemy_died(enemy: Node2D) -> void:
	if _resolved or _mode != "risk" or enemy == null:
		return
	_pending_enemy_ids.erase(enemy.get_instance_id())
	if _pending_enemy_ids.is_empty():
		_finish_risk(true, "risk_cleared")


func _finish_risk(succeeded: bool, reason: String) -> void:
	if _resolved:
		return
	if not succeeded:
		if _checkpoint("accepted", "failed", 0, "risk:failed"):
			_finish(STATUS_FAILED, reason)
		else:
			_finish(STATUS_FAILED, "failure_checkpoint_failed")
		return
	if not _checkpoint("accepted", "succeeded", 0, "risk:cleared"):
		_finish(STATUS_FAILED, "success_checkpoint_failed")
		return
	if not _claim_reward():
		return
	_finish(STATUS_COMPLETED, reason)


func _claim_reward() -> bool:
	if _context == null:
		return false
	var player: Node = _context.player()
	if player == null or not player.has_method("gain_xp") or not player.has_method("gain_money"):
		_finish(STATUS_FAILED, "reward_target_missing")
		return false
	if _reward.is_empty() or not _reward.has("stage"):
		_reward = LEDGER.reward_for_stage(_settings, int(_context.route_scaling_stage))
	# Claim is persisted before the transfer: a retry can never duplicate reward.
	if not _checkpoint("accepted", "succeeded", 1, "reward:claimed"):
		_finish(STATUS_FAILED, "claim_checkpoint_failed")
		return false
	player.gain_xp(int(_reward["xp"]))
	player.gain_money(int(_reward["gold"]))
	_reward_claimed = true
	return true


func _checkpoint(decision: String, risk: String, claim_count: int, checkpoint_id: String) -> bool:
	if _context == null:
		return false
	var current := _state()
	var ids: Array = (current.get("checkpoint_ids", []) as Array).duplicate()
	if checkpoint_id not in ids:
		ids.append(checkpoint_id)
	return _context.checkpoint_act_feature_state(FEATURE_ID, {
		"decision": decision,
		"offer_count": 1,
		"risk": risk,
		"claim_count": claim_count,
		"checkpoint_ids": ids,
	})


func _state() -> Dictionary:
	return _context.act_feature_state(FEATURE_ID) if _context != null else {}


func _finish(status: String, reason: String) -> void:
	if _resolved:
		return
	_status = status
	_reason = reason
	_resolved = true
	_cleanup()


func _cleanup() -> void:
	if _offer != null and is_instance_valid(_offer):
		if _offer.decision_made.is_connected(_on_offer_decision):
			_offer.decision_made.disconnect(_on_offer_decision)
		_offer.queue_free()
	_offer = null
	for enemy in _risk_enemies:
		if enemy != null and is_instance_valid(enemy):
			if enemy.has_signal("died") and enemy.died.is_connected(_on_risk_enemy_died):
				enemy.died.disconnect(_on_risk_enemy_died)
			enemy.queue_free()
	_risk_enemies.clear()
	_pending_enemy_ids.clear()


func debug_offer() -> Control:
	return _offer


func debug_risk_enemies() -> Array[Node2D]:
	return _risk_enemies.duplicate()
