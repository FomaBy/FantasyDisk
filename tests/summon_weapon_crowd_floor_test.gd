extends SceneTree

# SCRUM-506: deterministic summon crowd-floor gate.
#
# The earlier live-scene probe used real Player/Enemy nodes and occasionally reported
# a single inflated lvl1 sample for druid/summon_amulet. This gate checks the same
# acceptance intent on the deterministic balance model used by the CSV generator:
# summon weapons must be clearly alive at lvl20 on 20 targets, while their lvl1
# 20-target budget must stay near the documented floor.

const ProgressionData := preload("res://scripts/progression_data.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")

const TARGET_LEVEL := 20
const LEVELUPS := 19
const TARGET_COUNT := 20

const WEAPONS := [
	{"cid": "druid", "wid": "summon_amulet", "min_lvl20": 600.0, "max_lvl1": 150.0},
	{"cid": "chemist", "wid": "homunculus_vial", "min_lvl20": 580.0, "max_lvl1": 215.0},
	{"cid": "engineer", "wid": "engineer_sentry_wrench", "min_lvl20": 620.0, "max_lvl1": 155.0},
]


func _initialize() -> void:
	var errors: Array = []
	for pair in WEAPONS:
		var cid := str(pair["cid"])
		var wid := str(pair["wid"])
		var min_l20 := float(pair["min_lvl20"])
		var max_l1 := float(pair["max_lvl1"])
		var lvl1 := _budget_20t(cid, wid, ProgressionData.base_stats(cid))
		var lvl20 := _budget_20t(cid, wid, _optimized_stats(cid, ProgressionData.base_stats(cid)))
		print("  SCRUM-506 SUMMON FLOOR: %s/%s 20t lvl1=%.1f lvl20_ideal=%.1f (gate: lvl20>=%.0f, lvl1<=%.0f)" % [
			cid, wid, lvl1, lvl20, min_l20, max_l1])
		if lvl20 < min_l20:
			errors.append("%s/%s lvl20_ideal 20t=%.1f below deterministic revival floor %.1f." % [
				cid, wid, lvl20, min_l20])
		if lvl1 > max_l1:
			errors.append("%s/%s lvl1 20t=%.1f above deterministic floor %.1f." % [
				cid, wid, lvl1, max_l1])

	if not errors.is_empty():
		for error in errors:
			push_error("Summon crowd floor: %s" % error)
		push_error("Summon weapon crowd floor test FAILED: %d errors." % errors.size())
		quit(1)
		return
	print("Summon weapon crowd floor test passed.")
	quit(0)


func _budget_20t(character_id: String, weapon_id: String, stats: Dictionary) -> float:
	var weapon_config: Dictionary = ProgressionData.weapon(character_id, weapon_id)
	var budget: Dictionary = ProgressionData.estimate_crowd_clear_budget_for_stats(
		character_id,
		weapon_config,
		TARGET_COUNT,
		stats,
		true
	)
	return float(budget.get("crowd_dps", 0.0))


func _optimized_stats(character_id: String, base_stats: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	for _point in range(LEVELUPS):
		var best_stat := str(StatFormulas.BASE_STAT_ORDER[0])
		var best_score := -INF
		for stat_id_value in StatFormulas.BASE_STAT_ORDER:
			var stat_id := str(stat_id_value)
			var candidate := stats.duplicate(true)
			candidate[stat_id] = float(candidate.get(stat_id, 0.0)) + 1.0
			var score := _fast_build_score(character_id, candidate)
			if score > best_score + 0.0001 or (absf(score - best_score) <= 0.0001 and stat_id < best_stat):
				best_score = score
				best_stat = stat_id
		stats[best_stat] = float(stats.get(best_stat, 0.0)) + 1.0
	return stats


func _fast_build_score(character_id: String, stats: Dictionary) -> float:
	var total := 0.0
	var count := 0.0
	for weapon_id in ProgressionData.weapon_ids(character_id):
		var weapon_config: Dictionary = ProgressionData.weapon(character_id, str(weapon_id))
		var one_and_five: Dictionary = ProgressionData.estimate_weapon_budget_for_stats(character_id, weapon_config, stats, true)
		var twenty: Dictionary = ProgressionData.estimate_crowd_clear_budget_for_stats(character_id, weapon_config, TARGET_COUNT, stats, true)
		var tuning: Dictionary = weapon_config.get("budget_tuning", {})
		var solo_target := maxf(float(tuning.get("solo_target", ProgressionData.BALANCE_BASE_SOLO_DPS)), 0.001)
		var aoe_target := maxf(float(tuning.get("aoe_target", ProgressionData.BALANCE_BASE_AOE_DPS)), 0.001)
		var target_20 := maxf(float(twenty.get("target_dps", aoe_target)), 0.001)
		total += (
			float(one_and_five.get("solo_dps", 0.0)) / solo_target
			+ float(one_and_five.get("aoe_dps", 0.0)) / aoe_target
			+ float(twenty.get("crowd_dps", 0.0)) / target_20
		) / 3.0
		count += 1.0
	return total / maxf(count, 1.0)
