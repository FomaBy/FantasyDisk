extends RefCounted
## Pure, bounded contract economics. Only decision/risk/claim facts go through
## the shared act-state envelope; this helper derives the visible reward again.

const MAX_STAGE := 64


static func settings(definition: Dictionary) -> Dictionary:
	var payload := definition.get("payload", {}) as Dictionary
	var reward := payload.get("reward", {}) as Dictionary
	var timeout = payload.get("timeout_seconds")
	var multiplier = payload.get("risk_multiplier")
	var base_enemies = payload.get("risk_base_enemies")
	var max_enemies = payload.get("risk_max_enemies")
	var base_xp = reward.get("base_xp")
	var base_gold = reward.get("base_gold")
	var per_stage = reward.get("per_stage")
	var xp_cap = reward.get("xp_cap")
	var gold_cap = reward.get("gold_cap")
	if not _number_between(timeout, 4.0, 30.0) or not _number_between(multiplier, 1.05, 2.0) \
			or not _whole_between(base_enemies, 1, 8) or not _whole_between(max_enemies, int(base_enemies), 8) \
			or not _whole_between(base_xp, 1, 30) or not _whole_between(base_gold, 1, 30) \
			or not _whole_between(per_stage, 0, 12) or not _whole_between(xp_cap, int(base_xp), 30) \
			or not _whole_between(gold_cap, int(base_gold), 30):
		return {}
	return {
		"timeout_seconds": float(timeout),
		"risk_multiplier": float(multiplier),
		"risk_base_enemies": int(base_enemies),
		"risk_max_enemies": int(max_enemies),
		"base_xp": int(base_xp),
		"base_gold": int(base_gold),
		"per_stage": int(per_stage),
		"xp_cap": int(xp_cap),
		"gold_cap": int(gold_cap),
	}


static func reward_for_stage(config: Dictionary, stage: int) -> Dictionary:
	var safe_stage := clampi(stage, 0, MAX_STAGE)
	var xp := mini(int(config.get("xp_cap", 0)), int(config.get("base_xp", 0)) \
		+ safe_stage * int(config.get("per_stage", 0)))
	var gold := mini(int(config.get("gold_cap", 0)), int(config.get("base_gold", 0)) \
		+ safe_stage * int(config.get("per_stage", 0)))
	return {
		"xp": maxi(xp, 0),
		"gold": maxi(gold, 0),
		"stage": safe_stage,
		"capped": xp >= int(config.get("xp_cap", 0)) or gold >= int(config.get("gold_cap", 0)),
	}


static func risk_enemy_count(config: Dictionary, stage: int) -> int:
	var growth := clampi(stage, 0, MAX_STAGE) / 2
	return mini(int(config.get("risk_base_enemies", 0)) + growth, int(config.get("risk_max_enemies", 0)))


static func _number_between(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and float(value) >= minimum and float(value) <= maximum


static func _whole_between(value: Variant, minimum: int, maximum: int) -> bool:
	return _number_between(value, minimum, maximum) and float(value) == floorf(float(value))
