extends SceneTree

# SCRUM-853: deterministic guard for monster pressure and stretched XP pacing.
# It is a formula projection, not live combat telemetry: drops come from
# ProgressionData, pressure formulas come from CombatDirector, and two contrasting
# class/weapon profiles provide a small kill-throughput sensitivity check.

const ProgressionData := preload("res://scripts/progression_data.gd")
const CombatDirector := preload("res://scripts/combat_director.gd")

const START_XP_TO_NEXT := 5
const OLD_XP_CURVE_MULTIPLIER := 1.038
const OLD_XP_CURVE_FLAT := 0.8
const TARGET_ACT1_MIN_LEVEL := 10
const TARGET_ACT1_MAX_LEVEL := 15
const TARGET_ACT2_MIN_LEVEL := 20
const TARGET_ACT2_MAX_LEVEL := 25
const TARGET_RUN_MIN_LEVEL := 30
const TARGET_RUN_MAX_LEVEL := 35
const CROWD_DPS_REFERENCE := 210.0

const PROFILE_FIXTURES := [
	{"character": "berserk", "weapon": "hammer", "label": "berserk/hammer"},
	{"character": "dark_mage", "weapon": "dark_book", "label": "dark_mage/dark_book"},
]

const FIGHT_PLAN := [
	{"act": 1, "type": "battle", "stage": 0},
	{"act": 1, "type": "battle", "stage": 1},
	{"act": 1, "type": "battle", "stage": 2},
	{"act": 1, "type": "elite", "stage": 3},
	{"act": 1, "type": "battle", "stage": 4},
	{"act": 1, "type": "boss", "stage": 5},
	{"act": 2, "type": "battle", "stage": 4},
	{"act": 2, "type": "battle", "stage": 5},
	{"act": 2, "type": "elite", "stage": 6},
	{"act": 2, "type": "battle", "stage": 7},
	{"act": 2, "type": "battle", "stage": 8},
	{"act": 2, "type": "battle", "stage": 9},
	{"act": 2, "type": "boss", "stage": 10},
	{"act": 3, "type": "battle", "stage": 8},
	{"act": 3, "type": "battle", "stage": 9},
	{"act": 3, "type": "elite", "stage": 10},
	{"act": 3, "type": "battle", "stage": 11},
	{"act": 3, "type": "battle", "stage": 12},
	{"act": 3, "type": "battle", "stage": 13},
	{"act": 3, "type": "boss", "stage": 14},
]


func _initialize() -> void:
	var errors: Array = []
	_check_xp_targets(errors)
	_check_pressure_monotonicity(errors)
	_check_boss_reward_ordering(errors)
	if not errors.is_empty():
		for error in errors:
			push_error("SCRUM-853 pacing: %s" % str(error))
		quit(1)
		return
	print("SCRUM-853 monster XP/pressure pacing passed.")
	quit(0)


func _check_xp_targets(errors: Array) -> void:
	for profile in PROFILE_FIXTURES:
		var result := _projection_for_profile(profile as Dictionary)
		_expect_range(errors, "%s Act 1 final level" % result["label"], int(result["act1"]["level"]), TARGET_ACT1_MIN_LEVEL, TARGET_ACT1_MAX_LEVEL)
		_expect_range(errors, "%s Act 2 final level" % result["label"], int(result["act2"]["level"]), TARGET_ACT2_MIN_LEVEL, TARGET_ACT2_MAX_LEVEL)
		_expect_range(errors, "%s 20-fight final level" % result["label"], int(result["run"]["level"]), TARGET_RUN_MIN_LEVEL, TARGET_RUN_MAX_LEVEL)
		if int(result["old_run"]["level"]) <= int(result["run"]["level"]):
			errors.append("%s old XP curve should produce a higher runaway level than SCRUM-853 curve." % result["label"])
		print("SCRUM-853 XP %s: scalar %.2f, kills %.1f, XP act1 %.1f -> lvl %d, act2 %.1f -> lvl %d, run %.1f -> lvl %d (old curve lvl %d)" % [
			result["label"],
			float(result["kill_scalar"]),
			float(result["kills"]),
			float(result["act1"]["xp"]),
			int(result["act1"]["level"]),
			float(result["act2"]["xp"]),
			int(result["act2"]["level"]),
			float(result["run"]["xp"]),
			int(result["run"]["level"]),
			int(result["old_run"]["level"]),
		])


func _projection_for_profile(profile: Dictionary) -> Dictionary:
	var character_id := str(profile["character"])
	var weapon_id := str(profile["weapon"])
	var kill_scalar := _profile_kill_scalar(character_id, weapon_id)
	var act1 := _level_for_fights(FIGHT_PLAN.slice(0, 6), kill_scalar, ProgressionData.XP_CURVE_MULTIPLIER, ProgressionData.XP_CURVE_FLAT)
	var act2 := _level_for_fights(FIGHT_PLAN.slice(0, 13), kill_scalar, ProgressionData.XP_CURVE_MULTIPLIER, ProgressionData.XP_CURVE_FLAT)
	var run := _level_for_fights(FIGHT_PLAN, kill_scalar, ProgressionData.XP_CURVE_MULTIPLIER, ProgressionData.XP_CURVE_FLAT)
	var old_run := _level_for_fights(FIGHT_PLAN, kill_scalar, OLD_XP_CURVE_MULTIPLIER, OLD_XP_CURVE_FLAT)
	return {
		"label": str(profile["label"]),
		"kill_scalar": kill_scalar,
		"kills": float(run["kills"]),
		"act1": act1,
		"act2": act2,
		"run": run,
		"old_run": old_run,
	}


func _profile_kill_scalar(character_id: String, weapon_id: String) -> float:
	var weapon := ProgressionData.weapon(character_id, weapon_id)
	var crowd := ProgressionData.estimate_crowd_clear_budget(character_id, weapon, 20, true)
	var crowd_dps := float(crowd.get("crowd_dps", CROWD_DPS_REFERENCE))
	return clampf(crowd_dps / CROWD_DPS_REFERENCE, 0.94, 1.06)


func _level_for_fights(fights: Array, kill_scalar: float, curve_mult: float, curve_flat: float) -> Dictionary:
	var total_xp := 0.0
	var total_kills := 0.0
	for fight in fights:
		var encounter := _encounter_totals(str((fight as Dictionary)["type"]), int((fight as Dictionary)["stage"]), kill_scalar)
		total_xp += float(encounter["xp"])
		total_kills += float(encounter["kills"])
	return _level_for_xp(total_xp, curve_mult, curve_flat).merged({"xp": total_xp, "kills": total_kills})


func _encounter_totals(node_type: String, stage: int, kill_scalar: float) -> Dictionary:
	var total_xp := 0.0
	var total_kills := 0.0
	var mix := _encounter_mix(node_type, stage)
	for drop_class in mix.keys():
		var rewards: Dictionary = ProgressionData.drop_class_rewards(str(drop_class), stage, 0)
		var count := float(mix[drop_class])
		if ["ordinary", "complex", "heavy"].has(str(drop_class)):
			count *= kill_scalar
		total_xp += float(rewards.get("xp", 0)) * count
		total_kills += count
	return {"xp": total_xp, "kills": total_kills}


func _encounter_mix(node_type: String, stage: int) -> Dictionary:
	match node_type:
		"elite":
			return {
				"ordinary": 13.0 + float(stage),
				"complex": 5.0 + floorf(float(stage) * 0.35),
				"heavy": 3.0 + floorf(float(stage) * 0.25),
				"elite": 1.0,
			}
		"boss":
			return {
				"ordinary": 12.0 + float(stage) * 0.5,
				"complex": 4.0,
				"heavy": 2.0,
				"boss": 1.0,
			}
		_:
			return {
				"ordinary": 20.0 + float(stage) * 2.0,
				"complex": 4.0 + floorf(float(stage) * 0.45),
				"heavy": 2.0 + floorf(float(stage) * 0.30),
			}


func _level_for_xp(expected_xp: float, curve_mult: float, curve_flat: float) -> Dictionary:
	var xp := int(round(expected_xp))
	var xp_to_next := START_XP_TO_NEXT
	var level := 1
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = maxi(1, int(ceil(float(xp_to_next) * curve_mult + curve_flat)))
	return {"level": level, "xp_left": xp, "xp_to_next": xp_to_next}


func _check_pressure_monotonicity(errors: Array) -> void:
	var spawn_start := CombatDirector.normal_spawn_pressure_multiplier(0, 0, 0.0)
	var spawn_wave := CombatDirector.normal_spawn_pressure_multiplier(0, 6, 0.0)
	var spawn_elapsed := CombatDirector.normal_spawn_pressure_multiplier(0, 0, 1.0)
	var spawn_late := CombatDirector.normal_spawn_pressure_multiplier(12, 8, 0.9)
	if spawn_start <= 1.0:
		errors.append("normal spawn pressure must be above 1.0 from stage 0.")
	if spawn_wave <= spawn_start:
		errors.append("normal spawn pressure must grow by wave.")
	if spawn_elapsed <= spawn_start:
		errors.append("normal spawn pressure must grow by elapsed combat time.")
	if spawn_late <= spawn_wave or spawn_late <= spawn_elapsed:
		errors.append("late route pressure must exceed isolated wave/elapsed pressure.")

	var hp_start := CombatDirector.enemy_health_pressure_multiplier(0, 0, 0.0)
	var hp_late := CombatDirector.enemy_health_pressure_multiplier(12, 8, 0.9)
	var dmg_start := CombatDirector.enemy_damage_pressure_multiplier(0, 0, 0.0)
	var dmg_late := CombatDirector.enemy_damage_pressure_multiplier(12, 8, 0.9)
	if hp_start <= 1.0 or dmg_start <= 1.0:
		errors.append("enemy HP/contact pressure must be above 1.0 from stage 0.")
	if hp_late <= hp_start or dmg_late <= dmg_start:
		errors.append("enemy HP/contact pressure must grow into Act 2/3.")

	var shooter_early := CombatDirector.advanced_spawn_weight_multiplier("shooter", 0)
	var shooter_late := CombatDirector.advanced_spawn_weight_multiplier("shooter", 12)
	var summoner_late := CombatDirector.advanced_spawn_weight_multiplier("summoner", 12)
	var heavy_late := CombatDirector.advanced_spawn_weight_multiplier("heavy", 12)
	if shooter_early != 1.0:
		errors.append("advanced mob weighting should not boost stage 0 shooters before the early-game dampener.")
	if shooter_late <= shooter_early or summoner_late <= shooter_early or heavy_late <= shooter_early:
		errors.append("Act 2/3 advanced mob weights must grow above ordinary early weights.")

	var mini_start := CombatDirector.mini_elite_pressure_chance(0, 0, 0.0)
	var mini_late := CombatDirector.mini_elite_pressure_chance(12, 8, 0.9)
	if mini_start <= 0.0:
		errors.append("mini-elite pressure chance should exist from stage 0.")
	if mini_late <= mini_start:
		errors.append("mini-elite pressure chance should grow by stage/wave/time.")
	print("SCRUM-853 pressure: spawn %.2f -> %.2f, hp %.2f -> %.2f, dmg %.2f -> %.2f, advanced shooter %.2f -> %.2f, mini %.3f -> %.3f" % [
		spawn_start, spawn_late, hp_start, hp_late, dmg_start, dmg_late, shooter_early, shooter_late, mini_start, mini_late,
	])


func _check_boss_reward_ordering(errors: Array) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/combat_director.gd")
	if src.is_empty():
		errors.append("could not read combat_director.gd for boss reward ordering.")
		return
	var end_combat_index := src.find("func _end_combat")
	var boss_reward_index := src.find("_grant_boss_completion_rewards()", end_combat_index)
	var clear_world_index := src.find("game._clear_world()", end_combat_index)
	if boss_reward_index == -1 or clear_world_index == -1 or boss_reward_index > clear_world_index:
		errors.append("boss completion rewards must be granted before _clear_world() so XP/artifacts enter the run snapshot.")


func _expect_range(errors: Array, label: String, value: int, min_value: int, max_value: int) -> void:
	if value < min_value or value > max_value:
		errors.append("%s expected %d..%d, got %d." % [label, min_value, max_value, value])
