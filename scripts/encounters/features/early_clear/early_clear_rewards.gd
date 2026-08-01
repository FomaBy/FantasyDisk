extends RefCounted
## Data-backed, capped performance bonus. Base combat drops are never changed.

const CONFIG_PATH := "res://data/encounters/rewards/early_clear_rewards.json"

static var _cached: Dictionary = {}


static func config() -> Dictionary:
	if not _cached.is_empty():
		return _cached.duplicate(true)
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("EarlyClearRewards: missing %s" % CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_error("EarlyClearRewards: invalid JSON in %s" % CONFIG_PATH)
		return {}
	_cached = (parsed as Dictionary).duplicate(true)
	return _cached.duplicate(true)


static func performance_bonus(kills: int) -> Dictionary:
	var reward: Dictionary = config().get("performance_bonus", {})
	var counted_kills := maxi(kills, 0)
	return {
		"xp": mini(counted_kills * int(reward.get("xp_per_kill", 0)), int(reward.get("xp_cap", 0))),
		"gold": mini(counted_kills * int(reward.get("gold_per_kill", 0)), int(reward.get("gold_cap", 0))),
	}
