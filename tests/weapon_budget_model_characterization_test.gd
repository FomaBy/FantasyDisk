extends SceneTree

# FAN-3923 (FD16): characterization of the ProgressionData weapon-budget facade
# around the extraction of scripts/progression/weapon_budget_model.gd. Every
# fixture line pins the WHOLE result dictionary the facade returned on the
# accepted base (a53a521604cd7ab7137733838cdda11b3efaf71e) for all 17 classes
# and 51 weapon variants, so the pure model must reproduce it bit-for-bit:
#   - raw_untuned      estimate_weapon_budget(raw config, apply_budget=false)
#                      (the input path budget_tuning_for relies on)
#   - tuned_base       estimate_weapon_budget(weapon(), apply_budget=true)
#   - tuned_zero       every attribute 0 (floors and fallbacks)
#   - tuned_mid        every attribute 25 (partial caps)
#   - tuned_extreme    every attribute 500 (every cap and clamp engaged)
#   - upgrade_3        base attributes + 3 stacked run upgrades
#   - upgrade_10_noult base attributes + 10 stacked run upgrades (soft caps),
#                      include_ultimate=false
#   - tuning           budget_tuning_for(raw config)
#   - crowd_<N>        estimate_crowd_clear_budget for N in 0 (clamped to 1),
#                      5, 10, 20 at base attributes
#   - crowd_extreme_20 estimate_crowd_clear_budget_for_stats at 500 attributes
# Results are compared as canonical JSON (sorted keys, full float precision),
# so a single rounding or key drift fails the exact variant and scenario.
# weapon() budget keys are additionally checked against budget_tuning_for.
#
# Run: python3 tools/godot_gate.py --headless --path . \
#     --script res://tests/weapon_budget_model_characterization_test.gd
# Regenerate the fixture from a checkout of the accepted base (never from a
# candidate under test): WEAPON_BUDGET_GOLDEN_DUMP=1 <same command> prints
# every fixture line prefixed with "@@ "; paste the lines into GOLDEN below.

const PD := preload("res://scripts/progression_data.gd")

const EXPECTED_CLASS_COUNT := 17
const EXPECTED_VARIANT_COUNT := 51
const DUMP_ENV := "WEAPON_BUDGET_GOLDEN_DUMP"
const DUMP_PREFIX := "@@ "

const STAT_IDS := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]
const CROWD_COUNTS := [0, 5, 10, 20]


func _initialize() -> void:
	var errors: Array = []
	var records: Array = _collect(errors)
	if OS.get_environment(DUMP_ENV) == "1":
		for record in records:
			print("%s%s %s %s" % [DUMP_PREFIX, record[0], record[1], record[2]])
		print("Weapon budget golden dump: %d records." % records.size())
		quit(0)
		return

	var golden := _parse_golden(errors)
	var seen := {}
	for record in records:
		var key := "%s %s" % [record[0], record[1]]
		seen[key] = true
		if not golden.has(key):
			errors.append("%s: no fixture line (regenerate GOLDEN from the accepted base)" % key)
			continue
		if str(golden[key]) != str(record[2]):
			errors.append("%s: result drifted\n    expected %s\n    actual   %s" % [key, golden[key], record[2]])
	for key in golden:
		if not seen.has(key):
			errors.append("%s: stale fixture line without a live class/weapon" % key)

	_finish(errors)


func _collect(errors: Array) -> Array:
	var records: Array = []
	var class_ids: Array = PD.character_ids()
	if class_ids.size() != EXPECTED_CLASS_COUNT:
		errors.append("character_ids: expected %d classes, got %d" % [EXPECTED_CLASS_COUNT, class_ids.size()])
	var variants := 0
	var zero_stats := _flat_stats(0.0)
	var mid_stats := _flat_stats(25.0)
	var extreme_stats := _flat_stats(500.0)
	var upgrade_3 := _upgrade_stage_modifiers(3)
	var upgrade_10 := _upgrade_stage_modifiers(10)
	for class_id_raw in class_ids:
		var cid := str(class_id_raw)
		var base_stats: Dictionary = PD.base_stats(cid)
		var raw_weapons: Dictionary = PD.WEAPONS_BY_CLASS.get(cid, {})
		for weapon_id_raw in PD.weapon_ids(cid):
			var wid := str(weapon_id_raw)
			variants += 1
			var variant := "%s/%s" % [cid, wid]
			var raw: Dictionary = (raw_weapons.get(wid, {}) as Dictionary).duplicate(true)
			if raw.is_empty():
				errors.append("%s: WEAPONS_BY_CLASS has no raw config" % variant)
				continue
			var tuned: Dictionary = PD.weapon(cid, wid)
			var tuning: Dictionary = PD.budget_tuning_for(cid, raw)

			records.append(["raw_untuned", variant, _canonical(PD.estimate_weapon_budget(cid, raw, false))])
			records.append(["tuned_base", variant, _canonical(PD.estimate_weapon_budget(cid, tuned, true))])
			records.append(["tuned_zero", variant, _canonical(PD.estimate_weapon_budget_for_stats(cid, tuned, zero_stats, true))])
			records.append(["tuned_mid", variant, _canonical(PD.estimate_weapon_budget_for_stats(cid, tuned, mid_stats, true))])
			records.append(["tuned_extreme", variant, _canonical(PD.estimate_weapon_budget_for_stats(cid, tuned, extreme_stats, true))])
			records.append(["upgrade_3", variant, _canonical(PD.estimate_weapon_budget_for_stats(cid, tuned, base_stats, true, upgrade_3, true))])
			records.append(["upgrade_10_noult", variant, _canonical(PD.estimate_weapon_budget_for_stats(cid, tuned, base_stats, true, upgrade_10, false))])
			records.append(["tuning", variant, _canonical(tuning)])
			for count in CROWD_COUNTS:
				records.append(["crowd_%d" % int(count), variant, _canonical(PD.estimate_crowd_clear_budget(cid, tuned, int(count), true))])
			records.append(["crowd_extreme_20", variant, _canonical(PD.estimate_crowd_clear_budget_for_stats(cid, tuned, 20, extreme_stats, true))])

			# Facade contract: weapon() carries exactly the tuning it computed.
			for pair in [["budget_damage_multiplier", "damage_multiplier"], ["budget_solo_multiplier", "solo_budget_multiplier"], ["budget_aoe_multiplier", "aoe_budget_multiplier"]]:
				if not tuned.has(pair[0]):
					errors.append("%s: weapon() lost %s" % [variant, pair[0]])
				elif float(tuned[pair[0]]) != float(tuning.get(pair[1], NAN)):
					errors.append("%s: weapon().%s (%s) != budget_tuning_for().%s (%s)" % [variant, pair[0], tuned[pair[0]], pair[1], tuning.get(pair[1])])
			if not tuned.has("budget_tuning") or _canonical(tuned["budget_tuning"]) != _canonical(tuning):
				errors.append("%s: weapon().budget_tuning differs from budget_tuning_for()" % variant)
	if variants != EXPECTED_VARIANT_COUNT:
		errors.append("weapon variants: expected %d, got %d" % [EXPECTED_VARIANT_COUNT, variants])
	return records


func _flat_stats(value: float) -> Dictionary:
	var stats := {}
	for stat_id in STAT_IDS:
		stats[stat_id] = value
	return stats


# Run modifiers after `stage` stacked level-up upgrades of every kind the
# reward table offers (progression_data_content.gd LEVEL_UP_REWARDS, kind
# "upgrade"), plus a matching magic multiplier so the magic channel scales too.
func _upgrade_stage_modifiers(stage: int) -> Dictionary:
	var k := float(stage)
	return {
		"damage_multiplier": pow(1.15, k),
		"magic_damage_multiplier": pow(1.15, k),
		"attack_speed_multiplier": pow(1.12, k),
		"aoe_radius_multiplier": pow(1.15, k),
		"move_speed_multiplier": pow(1.10, k),
		"damage_flat": 4.0 * k,
		"dot_damage_flat": 3.0 * k,
		"crit_chance_flat": 0.07 * k,
		"crit_damage_flat": 0.35 * k,
		"max_health_flat": 18.0 * k,
		"defense_flat": 0.10 * k,
		"dodge_flat": 0.08 * k,
		"regeneration_flat": 1.3 * k,
		"ultimate_flat": 0.12 * k,
		"vampiric_chance_flat": 0.05 * k,
		"vampiric_amount_flat": 0.8 * k,
	}


func _canonical(value) -> String:
	return JSON.stringify(value, "", true, true)


func _parse_golden(errors: Array) -> Dictionary:
	var golden := {}
	for line_raw in GOLDEN.split("\n"):
		var line := str(line_raw).strip_edges()
		if line == "":
			continue
		var first := line.find(" ")
		var second := line.find(" ", first + 1)
		if first <= 0 or second <= first:
			errors.append("GOLDEN: malformed fixture line '%s'" % line)
			continue
		var key := line.substr(0, second)
		if golden.has(key):
			errors.append("GOLDEN: duplicate fixture line for %s" % key)
		golden[key] = line.substr(second + 1)
	if golden.is_empty():
		errors.append("GOLDEN: fixture is empty")
	return golden


func _finish(errors: Array) -> void:
	if not errors.is_empty():
		for e in errors:
			push_error("Weapon budget characterization: %s" % e)
		push_error("Weapon budget characterization test: %d errors." % errors.size())
		quit(1)
		return
	print("Weapon budget characterization test passed (%d classes, %d weapon variants, whole-result fixture matched)." % [EXPECTED_CLASS_COUNT, EXPECTED_VARIANT_COUNT])
	quit(0)


# Fixture: "<scenario> <class>/<weapon> <canonical JSON>" per line, generated
# on the accepted base with WEAPON_BUDGET_GOLDEN_DUMP=1 (see header).
const GOLDEN := """
raw_untuned berserk/sword {"aoe_dps":238.11,"direct_dps":59.89,"ehp":117.2,"hit_model":{"five_hits":3.430555555555556,"solo_hits":1.0},"interval":0.33,"solo_dps":69.47}
tuned_base berserk/sword {"aoe_dps":123.02,"direct_dps":32.4,"ehp":117.2,"hit_model":{"five_hits":3.430555555555556,"solo_hits":1.0},"interval":0.33,"solo_dps":39.35}
tuned_zero berserk/sword {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.430555555555556,"solo_hits":1.0},"interval":5.8,"solo_dps":0.0}
tuned_mid berserk/sword {"aoe_dps":779.12,"direct_dps":205.36,"ehp":561.04,"hit_model":{"five_hits":3.430555555555556,"solo_hits":1.0},"interval":0.18,"solo_dps":249.13}
tuned_extreme berserk/sword {"aoe_dps":73789.12,"direct_dps":19411.97,"ehp":30242.12,"hit_model":{"five_hits":3.430555555555556,"solo_hits":1.0},"interval":0.18,"solo_dps":23609.82}
upgrade_3 berserk/sword {"aoe_dps":544.98,"direct_dps":143.6,"ehp":282.39,"hit_model":{"five_hits":3.430555555555556,"solo_hits":1.0},"interval":0.247,"solo_dps":174.28}
upgrade_10_noult berserk/sword {"aoe_dps":3690.37,"direct_dps":974.3100000000001,"ehp":794.58,"hit_model":{"five_hits":3.430555555555556,"solo_hits":1.0},"interval":0.194,"solo_dps":1179.3700000000001}
tuning berserk/sword {"aoe_budget_multiplier":0.9550000000000001,"aoe_target":123.0,"base_aoe_dps":238.11,"base_solo_dps":69.47,"damage_multiplier":0.541,"solo_budget_multiplier":1.047,"solo_target":39.36}
crowd_0 berserk/sword {"cct":0.66,"cct_dev":0.02,"crowd_dps":120.56,"enemy_hp":80.0,"target_cct":0.65,"target_count":1,"target_dps":123.0}
crowd_5 berserk/sword {"cct":3.3200000000000003,"cct_dev":0.02,"crowd_dps":120.56,"enemy_hp":80.0,"target_cct":3.25,"target_count":5,"target_dps":123.0}
crowd_10 berserk/sword {"cct":6.91,"cct_dev":0.063,"crowd_dps":115.74000000000001,"enemy_hp":80.0,"target_cct":6.5,"target_count":10,"target_dps":123.0}
crowd_20 berserk/sword {"cct":14.71,"cct_dev":0.131,"crowd_dps":108.79,"enemy_hp":80.0,"target_cct":13.01,"target_count":20,"target_dps":123.0}
crowd_extreme_20 berserk/sword {"cct":0.02,"cct_dev":-0.998,"crowd_dps":65255.560000000005,"enemy_hp":80.0,"target_cct":13.01,"target_count":20,"target_dps":123.0}
raw_untuned berserk/axe {"aoe_dps":112.51,"direct_dps":19.82,"ehp":117.2,"hit_model":{"five_hits":4.125,"solo_hits":1.0},"interval":0.604,"solo_dps":23.62}
tuned_base berserk/axe {"aoe_dps":123.02,"direct_dps":26.75,"ehp":117.2,"hit_model":{"five_hits":4.125,"solo_hits":1.0},"interval":0.604,"solo_dps":39.38}
tuned_zero berserk/axe {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":4.125,"solo_hits":1.0},"interval":10.6,"solo_dps":0.0}
tuned_mid berserk/axe {"aoe_dps":1422.23,"direct_dps":309.90000000000003,"ehp":561.04,"hit_model":{"five_hits":4.125,"solo_hits":1.0},"interval":0.18,"solo_dps":454.5}
tuned_extreme berserk/axe {"aoe_dps":134620.48,"direct_dps":29293.89,"ehp":30242.12,"hit_model":{"five_hits":4.125,"solo_hits":1.0},"interval":0.18,"solo_dps":43069.35}
upgrade_3 berserk/axe {"aoe_dps":464.78000000000003,"direct_dps":101.14,"ehp":282.39,"hit_model":{"five_hits":4.125,"solo_hits":1.0},"interval":0.452,"solo_dps":148.70000000000002}
upgrade_10_noult berserk/axe {"aoe_dps":3057.26,"direct_dps":666.94,"ehp":794.58,"hit_model":{"five_hits":4.125,"solo_hits":1.0},"interval":0.355,"solo_dps":976.01}
tuning berserk/axe {"aoe_budget_multiplier":0.81,"aoe_target":123.0,"base_aoe_dps":112.51,"base_solo_dps":23.62,"damage_multiplier":1.35,"solo_budget_multiplier":1.235,"solo_target":39.36}
crowd_0 berserk/axe {"cct":0.66,"cct_dev":0.02,"crowd_dps":120.56,"enemy_hp":80.0,"target_cct":0.65,"target_count":1,"target_dps":123.0}
crowd_5 berserk/axe {"cct":3.3200000000000003,"cct_dev":0.02,"crowd_dps":120.56,"enemy_hp":80.0,"target_cct":3.25,"target_count":5,"target_dps":123.0}
crowd_10 berserk/axe {"cct":6.91,"cct_dev":0.063,"crowd_dps":115.74000000000001,"enemy_hp":80.0,"target_cct":6.5,"target_count":10,"target_dps":123.0}
crowd_20 berserk/axe {"cct":14.71,"cct_dev":0.131,"crowd_dps":108.79,"enemy_hp":80.0,"target_cct":13.01,"target_count":20,"target_dps":123.0}
crowd_extreme_20 berserk/axe {"cct":0.01,"cct_dev":-0.999,"crowd_dps":119051.89,"enemy_hp":80.0,"target_cct":13.01,"target_count":20,"target_dps":123.0}
raw_untuned berserk/hammer {"aoe_dps":46.33,"direct_dps":12.08,"ehp":117.2,"hit_model":{"five_hits":3.0833333333333335,"solo_hits":1.0},"interval":0.712,"solo_dps":15.040000000000001}
tuned_base berserk/hammer {"aoe_dps":122.99000000000001,"direct_dps":31.85,"ehp":117.2,"hit_model":{"five_hits":3.0833333333333335,"solo_hits":1.0},"interval":0.712,"solo_dps":39.38}
tuned_zero berserk/hammer {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.0833333333333335,"solo_hits":1.0},"interval":12.5,"solo_dps":0.0}
tuned_mid berserk/hammer {"aoe_dps":1673.69,"direct_dps":435.04,"ehp":561.04,"hit_model":{"five_hits":3.0833333333333335,"solo_hits":1.0},"interval":0.18,"solo_dps":535.46}
tuned_extreme berserk/hammer {"aoe_dps":158524.17,"direct_dps":41123.48,"ehp":30242.12,"hit_model":{"five_hits":3.0833333333333335,"solo_hits":1.0},"interval":0.18,"solo_dps":50736.380000000005}
upgrade_3 berserk/hammer {"aoe_dps":425.62,"direct_dps":110.34,"ehp":282.39,"hit_model":{"five_hits":3.0833333333333335,"solo_hits":1.0},"interval":0.533,"solo_dps":136.24}
upgrade_10_noult berserk/hammer {"aoe_dps":2818.77,"direct_dps":733.95,"ehp":794.58,"hit_model":{"five_hits":3.0833333333333335,"solo_hits":1.0},"interval":0.419,"solo_dps":901.49}
tuning berserk/hammer {"aoe_budget_multiplier":1.0070000000000001,"aoe_target":123.0,"base_aoe_dps":46.33,"base_solo_dps":15.040000000000001,"damage_multiplier":2.636,"solo_budget_multiplier":0.993,"solo_target":39.36}
crowd_0 berserk/hammer {"cct":0.66,"cct_dev":0.02,"crowd_dps":120.53,"enemy_hp":80.0,"target_cct":0.65,"target_count":1,"target_dps":123.0}
crowd_5 berserk/hammer {"cct":3.3200000000000003,"cct_dev":0.02,"crowd_dps":120.53,"enemy_hp":80.0,"target_cct":3.25,"target_count":5,"target_dps":123.0}
crowd_10 berserk/hammer {"cct":6.91,"cct_dev":0.063,"crowd_dps":115.71000000000001,"enemy_hp":80.0,"target_cct":6.5,"target_count":10,"target_dps":123.0}
crowd_20 berserk/hammer {"cct":14.71,"cct_dev":0.131,"crowd_dps":108.77,"enemy_hp":80.0,"target_cct":13.01,"target_count":20,"target_dps":123.0}
crowd_extreme_20 berserk/hammer {"cct":0.01,"cct_dev":-0.999,"crowd_dps":140191.17,"enemy_hp":80.0,"target_cct":13.01,"target_count":20,"target_dps":123.0}
raw_untuned soldier/soldier_rifle {"aoe_dps":56.14,"direct_dps":22.39,"ehp":100.95,"hit_model":{"five_hits":1.6551724137931034,"solo_hits":1.0},"interval":0.296,"solo_dps":33.69}
tuned_base soldier/soldier_rifle {"aoe_dps":101.98,"direct_dps":29.71,"ehp":100.95,"hit_model":{"five_hits":1.6551724137931034,"solo_hits":1.0},"interval":0.296,"solo_dps":32.64}
tuned_zero soldier/soldier_rifle {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":1.6551724137931034,"solo_hits":1.0},"interval":6.2,"solo_dps":0.0}
tuned_mid soldier/soldier_rifle {"aoe_dps":725.82,"direct_dps":211.93,"ehp":556.5600000000001,"hit_model":{"five_hits":1.6551724137931034,"solo_hits":1.0},"interval":0.18,"solo_dps":232.65}
tuned_extreme soldier/soldier_rifle {"aoe_dps":65792.64,"direct_dps":19047.600000000002,"ehp":30012.54,"hit_model":{"five_hits":1.6551724137931034,"solo_hits":1.0},"interval":0.18,"solo_dps":20969.3}
upgrade_3 soldier/soldier_rifle {"aoe_dps":499.6,"direct_dps":145.85,"ehp":263.43,"hit_model":{"five_hits":1.6551724137931034,"solo_hits":1.0},"interval":0.221,"solo_dps":160.12}
upgrade_10_noult soldier/soldier_rifle {"aoe_dps":3282.38,"direct_dps":965.72,"ehp":772.9,"hit_model":{"five_hits":1.6551724137931034,"solo_hits":1.0},"interval":0.18,"solo_dps":1057.46}
tuning soldier/soldier_rifle {"aoe_budget_multiplier":1.369,"aoe_target":102.0,"base_aoe_dps":56.14,"base_solo_dps":33.69,"damage_multiplier":1.327,"solo_budget_multiplier":0.73,"solo_target":32.64}
crowd_0 soldier/soldier_rifle {"cct":0.78,"cct_dev":0.0,"crowd_dps":101.98,"enemy_hp":80.0,"target_cct":0.78,"target_count":1,"target_dps":102.0}
crowd_5 soldier/soldier_rifle {"cct":3.92,"cct_dev":0.0,"crowd_dps":101.98,"enemy_hp":80.0,"target_cct":3.92,"target_count":5,"target_dps":102.0}
crowd_10 soldier/soldier_rifle {"cct":8.17,"cct_dev":0.042,"crowd_dps":97.9,"enemy_hp":80.0,"target_cct":7.84,"target_count":10,"target_dps":102.0}
crowd_20 soldier/soldier_rifle {"cct":17.39,"cct_dev":0.108,"crowd_dps":92.03,"enemy_hp":80.0,"target_cct":15.69,"target_count":20,"target_dps":102.0}
crowd_extreme_20 soldier/soldier_rifle {"cct":0.03,"cct_dev":-0.998,"crowd_dps":59371.28,"enemy_hp":80.0,"target_cct":15.69,"target_count":20,"target_dps":102.0}
raw_untuned soldier/soldier_grenade {"aoe_dps":97.88,"direct_dps":17.54,"ehp":100.95,"hit_model":{"five_hits":3.638888888888889,"solo_hits":1.0},"interval":1.48,"solo_dps":26.740000000000002}
tuned_base soldier/soldier_grenade {"aoe_dps":102.02,"direct_dps":19.78,"ehp":100.95,"hit_model":{"five_hits":3.638888888888889,"solo_hits":1.0},"interval":1.48,"solo_dps":32.63}
tuned_zero soldier/soldier_grenade {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.638888888888889,"solo_hits":1.0},"interval":31.0,"solo_dps":0.0}
tuned_mid soldier/soldier_grenade {"aoe_dps":1800.4,"direct_dps":354.52,"ehp":556.5600000000001,"hit_model":{"five_hits":3.638888888888889,"solo_hits":1.0},"interval":0.358,"solo_dps":578.29}
tuned_extreme soldier/soldier_grenade {"aoe_dps":322199.4,"direct_dps":63415.46,"ehp":30012.54,"hit_model":{"five_hits":3.638888888888889,"solo_hits":1.0},"interval":0.18,"solo_dps":103476.83}
upgrade_3 soldier/soldier_grenade {"aoe_dps":328.7,"direct_dps":64.04,"ehp":263.43,"hit_model":{"five_hits":3.638888888888889,"solo_hits":1.0},"interval":1.107,"solo_dps":105.27}
upgrade_10_noult soldier/soldier_grenade {"aoe_dps":2044.51,"direct_dps":405.37,"ehp":772.9,"hit_model":{"five_hits":3.638888888888889,"solo_hits":1.0},"interval":0.87,"solo_dps":657.92}
tuning soldier/soldier_grenade {"aoe_budget_multiplier":0.924,"aoe_target":102.0,"base_aoe_dps":97.88,"base_solo_dps":26.740000000000002,"damage_multiplier":1.1280000000000001,"solo_budget_multiplier":1.082,"solo_target":32.64}
crowd_0 soldier/soldier_grenade {"cct":0.75,"cct_dev":-0.039,"crowd_dps":106.10000000000001,"enemy_hp":80.0,"target_cct":0.78,"target_count":1,"target_dps":102.0}
crowd_5 soldier/soldier_grenade {"cct":3.77,"cct_dev":-0.039,"crowd_dps":106.10000000000001,"enemy_hp":80.0,"target_cct":3.92,"target_count":5,"target_dps":102.0}
crowd_10 soldier/soldier_grenade {"cct":7.8500000000000005,"cct_dev":0.001,"crowd_dps":101.86,"enemy_hp":80.0,"target_cct":7.84,"target_count":10,"target_dps":102.0}
crowd_20 soldier/soldier_grenade {"cct":16.71,"cct_dev":0.065,"crowd_dps":95.75,"enemy_hp":80.0,"target_cct":15.69,"target_count":20,"target_dps":102.0}
crowd_extreme_20 soldier/soldier_grenade {"cct":0.01,"cct_dev":-1.0,"crowd_dps":302382.85000000003,"enemy_hp":80.0,"target_cct":15.69,"target_count":20,"target_dps":102.0}
raw_untuned soldier/soldier_bayonet {"aoe_dps":103.82000000000001,"direct_dps":25.96,"ehp":102.95,"hit_model":{"five_hits":2.555982517482517,"solo_hits":1.126},"interval":0.391,"solo_dps":45.53}
tuned_base soldier/soldier_bayonet {"aoe_dps":102.0,"direct_dps":21.78,"ehp":102.95,"hit_model":{"five_hits":2.555982517482517,"solo_hits":1.126},"interval":0.391,"solo_dps":32.63}
tuned_zero soldier/soldier_bayonet {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.555982517482517,"solo_hits":1.126},"interval":8.2,"solo_dps":0.0}
tuned_mid soldier/soldier_bayonet {"aoe_dps":959.07,"direct_dps":205.45000000000002,"ehp":563.2,"hit_model":{"five_hits":2.555982517482517,"solo_hits":1.126},"interval":0.18,"solo_dps":307.33}
tuned_extreme soldier/soldier_bayonet {"aoe_dps":86660.97,"direct_dps":18465.79,"ehp":30021.170000000002,"hit_model":{"five_hits":2.555982517482517,"solo_hits":1.126},"interval":0.18,"solo_dps":27689.29}
upgrade_3 soldier/soldier_bayonet {"aoe_dps":507.56,"direct_dps":108.55,"ehp":266.37,"hit_model":{"five_hits":2.555982517482517,"solo_hits":1.126},"interval":0.293,"solo_dps":162.49}
upgrade_10_noult soldier/soldier_bayonet {"aoe_dps":3460.53,"direct_dps":744.87,"ehp":776.84,"hit_model":{"five_hits":2.555982517482517,"solo_hits":1.126},"interval":0.23,"solo_dps":1111.79}
tuning soldier/soldier_bayonet {"aoe_budget_multiplier":1.171,"aoe_target":102.0,"base_aoe_dps":103.82000000000001,"base_solo_dps":45.53,"damage_multiplier":0.839,"solo_budget_multiplier":0.854,"solo_target":32.64}
crowd_0 soldier/soldier_bayonet {"cct":0.8,"cct_dev":0.02,"crowd_dps":99.96000000000001,"enemy_hp":80.0,"target_cct":0.78,"target_count":1,"target_dps":102.0}
crowd_5 soldier/soldier_bayonet {"cct":4.0,"cct_dev":0.02,"crowd_dps":99.96000000000001,"enemy_hp":80.0,"target_cct":3.92,"target_count":5,"target_dps":102.0}
crowd_10 soldier/soldier_bayonet {"cct":8.34,"cct_dev":0.063,"crowd_dps":95.96000000000001,"enemy_hp":80.0,"target_cct":7.84,"target_count":10,"target_dps":102.0}
crowd_20 soldier/soldier_bayonet {"cct":17.740000000000002,"cct_dev":0.131,"crowd_dps":90.2,"enemy_hp":80.0,"target_cct":15.69,"target_count":20,"target_dps":102.0}
crowd_extreme_20 soldier/soldier_bayonet {"cct":0.02,"cct_dev":-0.999,"crowd_dps":76638.8,"enemy_hp":80.0,"target_cct":15.69,"target_count":20,"target_dps":102.0}
raw_untuned thief/thief_coin_pouch {"aoe_dps":86.12,"direct_dps":22.16,"ehp":68.05,"hit_model":{"five_hits":3.8625119794362877,"solo_hits":1.0},"interval":0.3,"solo_dps":22.27}
tuned_base thief/thief_coin_pouch {"aoe_dps":162.04,"direct_dps":46.39,"ehp":68.05,"hit_model":{"five_hits":3.8625119794362877,"solo_hits":1.0},"interval":0.3,"solo_dps":51.870000000000005}
tuned_zero thief/thief_coin_pouch {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.8625119794362877,"solo_hits":1.0},"interval":8.8,"solo_dps":0.0}
tuned_mid thief/thief_coin_pouch {"aoe_dps":1438.8700000000001,"direct_dps":412.33,"ehp":552.76,"hit_model":{"five_hits":3.8625119794362877,"solo_hits":1.0},"interval":0.18,"solo_dps":460.68}
tuned_extreme thief/thief_coin_pouch {"aoe_dps":126534.98,"direct_dps":36046.61,"ehp":29718.43,"hit_model":{"five_hits":3.8625119794362877,"solo_hits":1.0},"interval":0.18,"solo_dps":40458.31}
upgrade_3 thief/thief_coin_pouch {"aoe_dps":672.27,"direct_dps":192.71,"ehp":215.13,"hit_model":{"five_hits":3.8625119794362877,"solo_hits":1.0},"interval":0.225,"solo_dps":215.26}
upgrade_10_noult thief/thief_coin_pouch {"aoe_dps":4278.66,"direct_dps":1232.19,"ehp":695.58,"hit_model":{"five_hits":3.8625119794362877,"solo_hits":1.0},"interval":0.18,"solo_dps":1371.43}
tuning thief/thief_coin_pouch {"aoe_budget_multiplier":0.899,"aoe_target":162.0,"base_aoe_dps":86.12,"base_solo_dps":22.27,"damage_multiplier":2.093,"solo_budget_multiplier":1.113,"solo_target":51.84}
crowd_0 thief/thief_coin_pouch {"cct":0.49,"cct_dev":0.0,"crowd_dps":162.04,"enemy_hp":80.0,"target_cct":0.49,"target_count":1,"target_dps":162.0}
crowd_5 thief/thief_coin_pouch {"cct":2.47,"cct_dev":0.0,"crowd_dps":162.04,"enemy_hp":80.0,"target_cct":2.47,"target_count":5,"target_dps":162.0}
crowd_10 thief/thief_coin_pouch {"cct":5.14,"cct_dev":0.041,"crowd_dps":155.56,"enemy_hp":80.0,"target_cct":4.94,"target_count":10,"target_dps":162.0}
crowd_20 thief/thief_coin_pouch {"cct":10.94,"cct_dev":0.108,"crowd_dps":146.22,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
crowd_extreme_20 thief/thief_coin_pouch {"cct":0.01,"cct_dev":-0.999,"crowd_dps":114185.17,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
raw_untuned thief/thief_shadow_cloak {"aoe_dps":53.94,"direct_dps":21.56,"ehp":68.05,"hit_model":{"five_hits":2.473583333333333,"solo_hits":1.54025},"interval":0.368,"solo_dps":33.33}
tuned_base thief/thief_shadow_cloak {"aoe_dps":162.01,"direct_dps":46.59,"ehp":68.05,"hit_model":{"five_hits":2.473583333333333,"solo_hits":1.54025},"interval":0.368,"solo_dps":51.86}
tuned_zero thief/thief_shadow_cloak {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.473583333333333,"solo_hits":1.54025},"interval":10.8,"solo_dps":0.0}
tuned_mid thief/thief_shadow_cloak {"aoe_dps":1777.57,"direct_dps":513.14,"ehp":552.76,"hit_model":{"five_hits":2.473583333333333,"solo_hits":1.54025},"interval":0.18,"solo_dps":570.4300000000001}
tuned_extreme thief/thief_shadow_cloak {"aoe_dps":152367.18,"direct_dps":43571.99,"ehp":29718.43,"hit_model":{"five_hits":2.473583333333333,"solo_hits":1.54025},"interval":0.18,"solo_dps":48585.1}
upgrade_3 thief/thief_shadow_cloak {"aoe_dps":631.65,"direct_dps":182.14000000000001,"ehp":215.13,"hit_model":{"five_hits":2.473583333333333,"solo_hits":1.54025},"interval":0.276,"solo_dps":202.55}
upgrade_10_noult thief/thief_shadow_cloak {"aoe_dps":4009.5,"direct_dps":1166.13,"ehp":695.58,"hit_model":{"five_hits":2.473583333333333,"solo_hits":1.54025},"interval":0.217,"solo_dps":1293.22}
tuning thief/thief_shadow_cloak {"aoe_budget_multiplier":1.3900000000000001,"aoe_target":162.0,"base_aoe_dps":53.94,"base_solo_dps":33.33,"damage_multiplier":2.161,"solo_budget_multiplier":0.72,"solo_target":51.84}
crowd_0 thief/thief_shadow_cloak {"cct":0.49,"cct_dev":0.0,"crowd_dps":162.01,"enemy_hp":80.0,"target_cct":0.49,"target_count":1,"target_dps":162.0}
crowd_5 thief/thief_shadow_cloak {"cct":2.47,"cct_dev":0.0,"crowd_dps":162.01,"enemy_hp":80.0,"target_cct":2.47,"target_count":5,"target_dps":162.0}
crowd_10 thief/thief_shadow_cloak {"cct":5.14,"cct_dev":0.042,"crowd_dps":155.53,"enemy_hp":80.0,"target_cct":4.94,"target_count":10,"target_dps":162.0}
crowd_20 thief/thief_shadow_cloak {"cct":10.94,"cct_dev":0.108,"crowd_dps":146.20000000000002,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
crowd_extreme_20 thief/thief_shadow_cloak {"cct":0.01,"cct_dev":-0.999,"crowd_dps":137496.14,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
raw_untuned thief/thief_smoke_bomb {"aoe_dps":72.76,"direct_dps":23.78,"ehp":68.05,"hit_model":{"five_hits":3.0238095238095237,"solo_hits":1.0},"interval":0.457,"solo_dps":23.95}
tuned_base thief/thief_smoke_bomb {"aoe_dps":161.95000000000002,"direct_dps":52.21,"ehp":68.05,"hit_model":{"five_hits":3.0238095238095237,"solo_hits":1.0},"interval":0.457,"solo_dps":51.84}
tuned_zero thief/thief_smoke_bomb {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.0238095238095237,"solo_hits":1.0},"interval":13.4,"solo_dps":0.0}
tuned_mid thief/thief_smoke_bomb {"aoe_dps":2180.39,"direct_dps":706.65,"ehp":552.76,"hit_model":{"five_hits":3.0238095238095237,"solo_hits":1.0},"interval":0.18,"solo_dps":699.42}
tuned_extreme thief/thief_smoke_bomb {"aoe_dps":192056.45,"direct_dps":61776.130000000005,"ehp":29718.43,"hit_model":{"five_hits":3.0238095238095237,"solo_hits":1.0},"interval":0.18,"solo_dps":61425.08}
upgrade_3 thief/thief_smoke_bomb {"aoe_dps":564.46,"direct_dps":182.45000000000002,"ehp":215.13,"hit_model":{"five_hits":3.0238095238095237,"solo_hits":1.0},"interval":0.342,"solo_dps":180.88}
upgrade_10_noult thief/thief_smoke_bomb {"aoe_dps":3522.03,"direct_dps":1148.68,"ehp":695.58,"hit_model":{"five_hits":3.0238095238095237,"solo_hits":1.0},"interval":0.269,"solo_dps":1132.6000000000001}
tuning thief/thief_smoke_bomb {"aoe_budget_multiplier":1.014,"aoe_target":162.0,"base_aoe_dps":72.76,"base_solo_dps":23.95,"damage_multiplier":2.195,"solo_budget_multiplier":0.986,"solo_target":51.84}
crowd_0 thief/thief_smoke_bomb {"cct":0.45,"cct_dev":-0.084,"crowd_dps":176.85,"enemy_hp":80.0,"target_cct":0.49,"target_count":1,"target_dps":162.0}
crowd_5 thief/thief_smoke_bomb {"cct":2.2600000000000002,"cct_dev":-0.084,"crowd_dps":176.85,"enemy_hp":80.0,"target_cct":2.47,"target_count":5,"target_dps":162.0}
crowd_10 thief/thief_smoke_bomb {"cct":4.71,"cct_dev":-0.046,"crowd_dps":169.78,"enemy_hp":80.0,"target_cct":4.94,"target_count":10,"target_dps":162.0}
crowd_20 thief/thief_smoke_bomb {"cct":10.03,"cct_dev":0.056,"crowd_dps":159.59,"enemy_hp":80.0,"target_cct":9.5,"target_count":20,"target_dps":168.48}
crowd_extreme_20 thief/thief_smoke_bomb {"cct":0.01,"cct_dev":-0.999,"crowd_dps":189256.42,"enemy_hp":80.0,"target_cct":9.5,"target_count":20,"target_dps":168.48}
raw_untuned elementalist/elementalist_orb_ring {"aoe_dps":158.85,"direct_dps":19.580000000000002,"ehp":50.34,"hit_model":{"dot_targets":3.5555555555555554,"five_hits":4.833333333333334,"solo_hits":1.11},"interval":0.899,"solo_dps":39.65}
tuned_base elementalist/elementalist_orb_ring {"aoe_dps":104.04,"direct_dps":13.280000000000001,"ehp":50.34,"hit_model":{"dot_targets":3.5555555555555554,"five_hits":4.833333333333334,"solo_hits":1.11},"interval":0.899,"solo_dps":27.82}
tuned_zero elementalist/elementalist_orb_ring {"aoe_dps":1.52,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":3.5555555555555554,"five_hits":4.833333333333334,"solo_hits":1.11},"interval":15.200000000000001,"solo_dps":0.45}
tuned_mid elementalist/elementalist_orb_ring {"aoe_dps":1688.1000000000001,"direct_dps":262.42,"ehp":554.42,"hit_model":{"dot_targets":3.5555555555555554,"five_hits":4.833333333333334,"solo_hits":1.11},"interval":0.18,"solo_dps":442.36}
tuned_extreme elementalist/elementalist_orb_ring {"aoe_dps":111303.66,"direct_dps":25368.24,"ehp":29917.47,"hit_model":{"dot_targets":3.5555555555555554,"five_hits":4.833333333333334,"solo_hits":1.11},"interval":0.18,"solo_dps":27393.77}
upgrade_3 elementalist/elementalist_orb_ring {"aoe_dps":529.45,"direct_dps":77.54,"ehp":195.65,"hit_model":{"dot_targets":3.5555555555555554,"five_hits":4.833333333333334,"solo_hits":1.11},"interval":0.673,"solo_dps":139.5}
upgrade_10_noult elementalist/elementalist_orb_ring {"aoe_dps":5853.22,"direct_dps":1088.17,"ehp":678.48,"hit_model":{"dot_targets":3.5555555555555554,"five_hits":4.833333333333334,"solo_hits":1.11},"interval":0.529,"solo_dps":1497.1200000000001}
tuning elementalist/elementalist_orb_ring {"aoe_budget_multiplier":0.8140000000000001,"aoe_target":103.95,"base_aoe_dps":158.85,"base_solo_dps":39.65,"damage_multiplier":0.678,"solo_budget_multiplier":0.855,"solo_target":27.82}
crowd_0 elementalist/elementalist_orb_ring {"cct":0.73,"cct_dev":-0.048,"crowd_dps":109.24000000000001,"enemy_hp":80.0,"target_cct":0.77,"target_count":1,"target_dps":103.95}
crowd_5 elementalist/elementalist_orb_ring {"cct":3.66,"cct_dev":-0.048,"crowd_dps":109.24000000000001,"enemy_hp":80.0,"target_cct":3.85,"target_count":5,"target_dps":103.95}
crowd_10 elementalist/elementalist_orb_ring {"cct":7.63,"cct_dev":-0.009000000000000001,"crowd_dps":104.87,"enemy_hp":80.0,"target_cct":7.7,"target_count":10,"target_dps":103.95}
crowd_20 elementalist/elementalist_orb_ring {"cct":16.23,"cct_dev":0.097,"crowd_dps":98.58,"enemy_hp":80.0,"target_cct":14.8,"target_count":20,"target_dps":108.11}
crowd_extreme_20 elementalist/elementalist_orb_ring {"cct":0.02,"cct_dev":-0.999,"crowd_dps":105462.44,"enemy_hp":80.0,"target_cct":14.8,"target_count":20,"target_dps":108.11}
raw_untuned elementalist/elementalist_prism_focus {"aoe_dps":71.45,"direct_dps":18.21,"ehp":50.34,"hit_model":{"five_hits":3.7888888888888888,"solo_hits":1.27},"interval":1.361,"solo_dps":23.62}
tuned_base elementalist/elementalist_prism_focus {"aoe_dps":103.9,"direct_dps":23.84,"ehp":50.34,"hit_model":{"five_hits":3.7888888888888888,"solo_hits":1.27},"interval":1.361,"solo_dps":27.82}
tuned_zero elementalist/elementalist_prism_focus {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.7888888888888888,"solo_hits":1.27},"interval":23.0,"solo_dps":0.0}
tuned_mid elementalist/elementalist_prism_focus {"aoe_dps":2003.02,"direct_dps":471.90000000000003,"ehp":554.42,"hit_model":{"five_hits":3.7888888888888888,"solo_hits":1.27},"interval":0.272,"solo_dps":542.07}
tuned_extreme elementalist/elementalist_prism_focus {"aoe_dps":293564.91000000003,"direct_dps":68931.88,"ehp":29917.47,"hit_model":{"five_hits":3.7888888888888888,"solo_hits":1.27},"interval":0.18,"solo_dps":79339.87}
upgrade_3 elementalist/elementalist_prism_focus {"aoe_dps":491.22,"direct_dps":113.54,"ehp":195.65,"hit_model":{"five_hits":3.7888888888888888,"solo_hits":1.27},"interval":1.018,"solo_dps":131.93}
upgrade_10_noult elementalist/elementalist_prism_focus {"aoe_dps":7367.46,"direct_dps":1750.22,"ehp":678.48,"hit_model":{"five_hits":3.7888888888888888,"solo_hits":1.27},"interval":0.8,"solo_dps":2000.5}
tuning elementalist/elementalist_prism_focus {"aoe_budget_multiplier":1.111,"aoe_target":103.95,"base_aoe_dps":71.45,"base_solo_dps":23.62,"damage_multiplier":1.309,"solo_budget_multiplier":0.9,"solo_target":27.82}
crowd_0 elementalist/elementalist_prism_focus {"cct":0.79,"cct_dev":0.021,"crowd_dps":101.82000000000001,"enemy_hp":80.0,"target_cct":0.77,"target_count":1,"target_dps":103.95}
crowd_5 elementalist/elementalist_prism_focus {"cct":3.93,"cct_dev":0.021,"crowd_dps":101.82000000000001,"enemy_hp":80.0,"target_cct":3.85,"target_count":5,"target_dps":103.95}
crowd_10 elementalist/elementalist_prism_focus {"cct":8.18,"cct_dev":0.063,"crowd_dps":97.75,"enemy_hp":80.0,"target_cct":7.7,"target_count":10,"target_dps":103.95}
crowd_20 elementalist/elementalist_prism_focus {"cct":17.41,"cct_dev":0.131,"crowd_dps":91.88,"enemy_hp":80.0,"target_cct":15.39,"target_count":20,"target_dps":103.95}
crowd_extreme_20 elementalist/elementalist_prism_focus {"cct":0.01,"cct_dev":-1.0,"crowd_dps":259614.72,"enemy_hp":80.0,"target_cct":15.39,"target_count":20,"target_dps":103.95}
raw_untuned elementalist/elementalist_meteor_core {"aoe_dps":90.8,"direct_dps":14.780000000000001,"ehp":50.34,"hit_model":{"dot_targets":3.0,"five_hits":2.7505263157894735,"solo_hits":1.0},"interval":2.662,"solo_dps":30.98}
tuned_base elementalist/elementalist_meteor_core {"aoe_dps":103.95,"direct_dps":14.98,"ehp":50.34,"hit_model":{"dot_targets":3.0,"five_hits":2.7505263157894735,"solo_hits":1.0},"interval":2.662,"solo_dps":27.830000000000002}
tuned_zero elementalist/elementalist_meteor_core {"aoe_dps":1.58,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":3.0,"five_hits":2.7505263157894735,"solo_hits":1.0},"interval":45.0,"solo_dps":0.41000000000000003}
tuned_mid elementalist/elementalist_meteor_core {"aoe_dps":1623.3400000000001,"direct_dps":296.58,"ehp":554.42,"hit_model":{"dot_targets":3.0,"five_hits":2.7505263157894735,"solo_hits":1.0},"interval":0.532,"solo_dps":444.33}
tuned_extreme elementalist/elementalist_meteor_core {"aoe_dps":301774.52,"direct_dps":84761.02,"ehp":29917.47,"hit_model":{"dot_targets":3.0,"five_hits":2.7505263157894735,"solo_hits":1.0},"interval":0.18,"solo_dps":84755.97}
upgrade_3 elementalist/elementalist_meteor_core {"aoe_dps":461.67,"direct_dps":69.60000000000001,"ehp":195.65,"hit_model":{"dot_targets":3.0,"five_hits":2.7505263157894735,"solo_hits":1.0},"interval":1.992,"solo_dps":124.19}
upgrade_10_noult elementalist/elementalist_meteor_core {"aoe_dps":5023.5,"direct_dps":1086.04,"ehp":678.48,"hit_model":{"dot_targets":3.0,"five_hits":2.7505263157894735,"solo_hits":1.0},"interval":1.566,"solo_dps":1394.24}
tuning elementalist/elementalist_meteor_core {"aoe_budget_multiplier":1.137,"aoe_target":103.95,"base_aoe_dps":90.8,"base_solo_dps":30.98,"damage_multiplier":1.014,"solo_budget_multiplier":0.892,"solo_target":27.82}
crowd_0 elementalist/elementalist_meteor_core {"cct":0.74,"cct_dev":-0.038,"crowd_dps":108.11,"enemy_hp":80.0,"target_cct":0.77,"target_count":1,"target_dps":103.95}
crowd_5 elementalist/elementalist_meteor_core {"cct":3.7,"cct_dev":-0.038,"crowd_dps":108.11,"enemy_hp":80.0,"target_cct":3.85,"target_count":5,"target_dps":103.95}
crowd_10 elementalist/elementalist_meteor_core {"cct":7.71,"cct_dev":0.002,"crowd_dps":103.78,"enemy_hp":80.0,"target_cct":7.7,"target_count":10,"target_dps":103.95}
crowd_20 elementalist/elementalist_meteor_core {"cct":16.4,"cct_dev":0.066,"crowd_dps":97.56,"enemy_hp":80.0,"target_cct":15.39,"target_count":20,"target_dps":103.95}
crowd_extreme_20 elementalist/elementalist_meteor_core {"cct":0.01,"cct_dev":-1.0,"crowd_dps":283214.18,"enemy_hp":80.0,"target_cct":15.39,"target_count":20,"target_dps":103.95}
raw_untuned sniper/sniper_deadeye_rifle {"aoe_dps":119.65,"direct_dps":22.36,"ehp":119.44,"hit_model":{"five_hits":4.007631578947369,"solo_hits":1.6900000000000002},"interval":0.536,"solo_dps":60.14}
tuned_base sniper/sniper_deadeye_rifle {"aoe_dps":161.91,"direct_dps":28.96,"ehp":119.44,"hit_model":{"five_hits":4.007631578947369,"solo_hits":1.6900000000000002},"interval":0.536,"solo_dps":74.54}
tuned_zero sniper/sniper_deadeye_rifle {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":4.007631578947369,"solo_hits":1.6900000000000002},"interval":14.200000000000001,"solo_dps":0.0}
tuned_mid sniper/sniper_deadeye_rifle {"aoe_dps":2537.03,"direct_dps":456.37,"ehp":559.32,"hit_model":{"five_hits":4.007631578947369,"solo_hits":1.6900000000000002},"interval":0.18,"solo_dps":1171.8700000000001}
tuned_extreme sniper/sniper_deadeye_rifle {"aoe_dps":225860.49,"direct_dps":40422.01,"ehp":30159.33,"hit_model":{"five_hits":4.007631578947369,"solo_hits":1.6900000000000002},"interval":0.18,"solo_dps":104006.3}
upgrade_3 sniper/sniper_deadeye_rifle {"aoe_dps":647.99,"direct_dps":116.17,"ehp":282.19,"hit_model":{"five_hits":4.007631578947369,"solo_hits":1.6900000000000002},"interval":0.401,"solo_dps":298.7}
upgrade_10_noult sniper/sniper_deadeye_rifle {"aoe_dps":4171.2,"direct_dps":753.54,"ehp":787.34,"hit_model":{"five_hits":4.007631578947369,"solo_hits":1.6900000000000002},"interval":0.315,"solo_dps":1931.68}
tuning sniper/sniper_deadeye_rifle {"aoe_budget_multiplier":1.045,"aoe_target":162.0,"base_aoe_dps":119.65,"base_solo_dps":60.14,"damage_multiplier":1.295,"solo_budget_multiplier":0.9570000000000001,"solo_target":74.52}
crowd_0 sniper/sniper_deadeye_rifle {"cct":0.54,"cct_dev":0.088,"crowd_dps":148.96,"enemy_hp":80.0,"target_cct":0.49,"target_count":1,"target_dps":162.0}
crowd_5 sniper/sniper_deadeye_rifle {"cct":2.69,"cct_dev":0.088,"crowd_dps":148.96,"enemy_hp":80.0,"target_cct":2.47,"target_count":5,"target_dps":162.0}
crowd_10 sniper/sniper_deadeye_rifle {"cct":5.59,"cct_dev":0.133,"crowd_dps":143.0,"enemy_hp":80.0,"target_cct":4.94,"target_count":10,"target_dps":162.0}
crowd_20 sniper/sniper_deadeye_rifle {"cct":11.9,"cct_dev":0.20500000000000002,"crowd_dps":134.42000000000002,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
crowd_extreme_20 sniper/sniper_deadeye_rifle {"cct":0.01,"cct_dev":-0.999,"crowd_dps":187511.19,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
raw_untuned sniper/sniper_spotter_scope {"aoe_dps":100.19,"direct_dps":23.28,"ehp":119.44,"hit_model":{"five_hits":3.25,"solo_hits":1.0},"interval":0.849,"solo_dps":30.61}
tuned_base sniper/sniper_spotter_scope {"aoe_dps":162.0,"direct_dps":46.19,"ehp":119.44,"hit_model":{"five_hits":3.25,"solo_hits":1.0},"interval":0.849,"solo_dps":74.53}
tuned_zero sniper/sniper_spotter_scope {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.25,"solo_hits":1.0},"interval":22.5,"solo_dps":0.0}
tuned_mid sniper/sniper_spotter_scope {"aoe_dps":2816.06,"direct_dps":812.76,"ehp":559.32,"hit_model":{"five_hits":3.25,"solo_hits":1.0},"interval":0.253,"solo_dps":1300.98}
tuned_extreme sniper/sniper_spotter_scope {"aoe_dps":361995.13,"direct_dps":104059.99,"ehp":30159.33,"hit_model":{"five_hits":3.25,"solo_hits":1.0},"interval":0.18,"solo_dps":167004.04}
upgrade_3 sniper/sniper_spotter_scope {"aoe_dps":501.28000000000003,"direct_dps":143.55,"ehp":282.19,"hit_model":{"five_hits":3.25,"solo_hits":1.0},"interval":0.635,"solo_dps":230.95000000000002}
upgrade_10_noult sniper/sniper_spotter_scope {"aoe_dps":3045.35,"direct_dps":885.77,"ehp":787.34,"hit_model":{"five_hits":3.25,"solo_hits":1.0},"interval":0.499,"solo_dps":1410.72}
tuning sniper/sniper_spotter_scope {"aoe_budget_multiplier":0.8150000000000001,"aoe_target":162.0,"base_aoe_dps":100.19,"base_solo_dps":30.61,"damage_multiplier":1.984,"solo_budget_multiplier":1.227,"solo_target":74.52}
crowd_0 sniper/sniper_spotter_scope {"cct":0.49,"cct_dev":0.0,"crowd_dps":162.0,"enemy_hp":80.0,"target_cct":0.49,"target_count":1,"target_dps":162.0}
crowd_5 sniper/sniper_spotter_scope {"cct":2.47,"cct_dev":0.0,"crowd_dps":162.0,"enemy_hp":80.0,"target_cct":2.47,"target_count":5,"target_dps":162.0}
crowd_10 sniper/sniper_spotter_scope {"cct":5.14,"cct_dev":0.042,"crowd_dps":155.52,"enemy_hp":80.0,"target_cct":4.94,"target_count":10,"target_dps":162.0}
crowd_20 sniper/sniper_spotter_scope {"cct":10.94,"cct_dev":0.108,"crowd_dps":146.19,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
crowd_extreme_20 sniper/sniper_spotter_scope {"cct":0.0,"cct_dev":-1.0,"crowd_dps":326664.41000000003,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
raw_untuned sniper/sniper_shatter_rounds {"aoe_dps":116.99000000000001,"direct_dps":20.68,"ehp":119.44,"hit_model":{"five_hits":5.2,"solo_hits":2.0},"interval":0.196,"solo_dps":44.92}
tuned_base sniper/sniper_shatter_rounds {"aoe_dps":162.11,"direct_dps":31.36,"ehp":119.44,"hit_model":{"five_hits":5.2,"solo_hits":2.0},"interval":0.196,"solo_dps":74.5}
tuned_zero sniper/sniper_shatter_rounds {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":5.2,"solo_hits":2.0},"interval":5.5,"solo_dps":0.0}
tuned_mid sniper/sniper_shatter_rounds {"aoe_dps":923.47,"direct_dps":178.5,"ehp":559.32,"hit_model":{"five_hits":5.2,"solo_hits":2.0},"interval":0.18,"solo_dps":424.29}
tuned_extreme sniper/sniper_shatter_rounds {"aoe_dps":84672.12,"direct_dps":16290.59,"ehp":30159.33,"hit_model":{"five_hits":5.2,"solo_hits":2.0},"interval":0.18,"solo_dps":38815.62}
upgrade_3 sniper/sniper_shatter_rounds {"aoe_dps":802.8100000000001,"direct_dps":155.31,"ehp":282.19,"hit_model":{"five_hits":5.2,"solo_hits":2.0},"interval":0.18,"solo_dps":368.99}
upgrade_10_noult sniper/sniper_shatter_rounds {"aoe_dps":4369.89,"direct_dps":848.19,"ehp":787.34,"hit_model":{"five_hits":5.2,"solo_hits":2.0},"interval":0.18,"solo_dps":2011.72}
tuning sniper/sniper_shatter_rounds {"aoe_budget_multiplier":0.914,"aoe_target":162.0,"base_aoe_dps":116.99000000000001,"base_solo_dps":44.92,"damage_multiplier":1.516,"solo_budget_multiplier":1.094,"solo_target":74.52}
crowd_0 sniper/sniper_shatter_rounds {"cct":0.49,"cct_dev":-0.001,"crowd_dps":162.11,"enemy_hp":80.0,"target_cct":0.49,"target_count":1,"target_dps":162.0}
crowd_5 sniper/sniper_shatter_rounds {"cct":2.47,"cct_dev":-0.001,"crowd_dps":162.11,"enemy_hp":80.0,"target_cct":2.47,"target_count":5,"target_dps":162.0}
crowd_10 sniper/sniper_shatter_rounds {"cct":5.14,"cct_dev":0.041,"crowd_dps":155.63,"enemy_hp":80.0,"target_cct":4.94,"target_count":10,"target_dps":162.0}
crowd_20 sniper/sniper_shatter_rounds {"cct":10.94,"cct_dev":0.107,"crowd_dps":146.29,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
crowd_extreme_20 sniper/sniper_shatter_rounds {"cct":0.02,"cct_dev":-0.998,"crowd_dps":76408.12,"enemy_hp":80.0,"target_cct":9.88,"target_count":20,"target_dps":162.0}
raw_untuned priest/priest_reliquary {"aoe_dps":61.980000000000004,"direct_dps":26.310000000000002,"ehp":84.14,"hit_model":{"five_hits":2.3193103448275862,"solo_hits":1.1400000000000001},"interval":0.423,"solo_dps":30.18}
tuned_base priest/priest_reliquary {"aoe_dps":135.41,"direct_dps":47.7,"ehp":84.14,"hit_model":{"five_hits":2.3193103448275862,"solo_hits":1.1400000000000001},"interval":0.423,"solo_dps":45.42}
tuned_zero priest/priest_reliquary {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.3193103448275862,"solo_hits":1.1400000000000001},"interval":7.2,"solo_dps":0.0}
tuned_mid priest/priest_reliquary {"aoe_dps":1098.17,"direct_dps":389.14,"ehp":550.03,"hit_model":{"five_hits":2.3193103448275862,"solo_hits":1.1400000000000001},"interval":0.18,"solo_dps":369.66}
tuned_extreme priest/priest_reliquary {"aoe_dps":96002.94,"direct_dps":33618.590000000004,"ehp":29677.21,"hit_model":{"five_hits":2.3193103448275862,"solo_hits":1.1400000000000001},"interval":0.18,"solo_dps":32091.87}
upgrade_3 priest/priest_reliquary {"aoe_dps":642.69,"direct_dps":227.13,"ehp":253.01000000000002,"hit_model":{"five_hits":2.3193103448275862,"solo_hits":1.1400000000000001},"interval":0.317,"solo_dps":216.0}
upgrade_10_noult priest/priest_reliquary {"aoe_dps":8538.73,"direct_dps":3055.25,"ehp":782.45,"hit_model":{"five_hits":2.3193103448275862,"solo_hits":1.1400000000000001},"interval":0.249,"solo_dps":2890.88}
tuning priest/priest_reliquary {"aoe_budget_multiplier":1.205,"aoe_target":135.45,"base_aoe_dps":61.980000000000004,"base_solo_dps":30.18,"damage_multiplier":1.813,"solo_budget_multiplier":0.8300000000000001,"solo_target":45.410000000000004}
crowd_0 priest/priest_reliquary {"cct":0.56,"cct_dev":-0.047,"crowd_dps":142.18,"enemy_hp":80.0,"target_cct":0.59,"target_count":1,"target_dps":135.45}
crowd_5 priest/priest_reliquary {"cct":2.81,"cct_dev":-0.047,"crowd_dps":142.18,"enemy_hp":80.0,"target_cct":2.95,"target_count":5,"target_dps":135.45}
crowd_10 priest/priest_reliquary {"cct":5.86,"cct_dev":-0.008,"crowd_dps":136.49,"enemy_hp":80.0,"target_cct":5.91,"target_count":10,"target_dps":135.45}
crowd_20 priest/priest_reliquary {"cct":12.47,"cct_dev":0.098,"crowd_dps":128.3,"enemy_hp":80.0,"target_cct":11.36,"target_count":20,"target_dps":140.87}
crowd_extreme_20 priest/priest_reliquary {"cct":0.02,"cct_dev":-0.998,"crowd_dps":90964.71,"enemy_hp":80.0,"target_cct":11.36,"target_count":20,"target_dps":140.87}
raw_untuned priest/priest_censer {"aoe_dps":24.740000000000002,"direct_dps":5.37,"ehp":85.26,"hit_model":{"five_hits":4.5,"solo_hits":1.7},"interval":1.2530000000000001,"solo_dps":9.24}
tuned_base priest/priest_censer {"aoe_dps":135.48,"direct_dps":15.030000000000001,"ehp":85.26,"hit_model":{"five_hits":4.5,"solo_hits":1.7},"interval":1.2530000000000001,"solo_dps":45.410000000000004}
tuned_zero priest/priest_censer {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":4.5,"solo_hits":1.7},"interval":20.5,"solo_dps":0.0}
tuned_mid priest/priest_censer {"aoe_dps":2277.75,"direct_dps":256.95,"ehp":554.42,"hit_model":{"five_hits":4.5,"solo_hits":1.7},"interval":0.254,"solo_dps":769.49}
tuned_extreme priest/priest_censer {"aoe_dps":279207.29,"direct_dps":31368.7,"ehp":29682.9,"hit_model":{"five_hits":4.5,"solo_hits":1.7},"interval":0.18,"solo_dps":94144.8}
upgrade_3 priest/priest_censer {"aoe_dps":651.72,"direct_dps":72.66,"ehp":254.8,"hit_model":{"five_hits":4.5,"solo_hits":1.7},"interval":0.937,"solo_dps":218.96}
upgrade_10_noult priest/priest_censer {"aoe_dps":8550.0,"direct_dps":971.37,"ehp":784.98,"hit_model":{"five_hits":4.5,"solo_hits":1.7},"interval":0.737,"solo_dps":2898.08}
tuning priest/priest_censer {"aoe_budget_multiplier":1.956,"aoe_target":135.45,"base_aoe_dps":24.740000000000002,"base_solo_dps":9.24,"damage_multiplier":2.8000000000000003,"solo_budget_multiplier":1.7550000000000001,"solo_target":45.410000000000004}
crowd_0 priest/priest_censer {"cct":0.56,"cct_dev":-0.048,"crowd_dps":142.25,"enemy_hp":80.0,"target_cct":0.59,"target_count":1,"target_dps":135.45}
crowd_5 priest/priest_censer {"cct":2.81,"cct_dev":-0.048,"crowd_dps":142.25,"enemy_hp":80.0,"target_cct":2.95,"target_count":5,"target_dps":135.45}
crowd_10 priest/priest_censer {"cct":5.86,"cct_dev":-0.008,"crowd_dps":136.56,"enemy_hp":80.0,"target_cct":5.91,"target_count":10,"target_dps":135.45}
crowd_20 priest/priest_censer {"cct":12.46,"cct_dev":0.097,"crowd_dps":128.37,"enemy_hp":80.0,"target_cct":11.36,"target_count":20,"target_dps":140.87}
crowd_extreme_20 priest/priest_censer {"cct":0.01,"cct_dev":-0.999,"crowd_dps":264554.49,"enemy_hp":80.0,"target_cct":11.36,"target_count":20,"target_dps":140.87}
raw_untuned priest/priest_chime {"aoe_dps":40.22,"direct_dps":11.26,"ehp":84.14,"hit_model":{"five_hits":3.5023809523809524,"solo_hits":1.0},"interval":0.782,"solo_dps":11.42}
tuned_base priest/priest_chime {"aoe_dps":135.47,"direct_dps":31.54,"ehp":84.14,"hit_model":{"five_hits":3.5023809523809524,"solo_hits":1.0},"interval":0.782,"solo_dps":45.4}
tuned_zero priest/priest_chime {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.5023809523809524,"solo_hits":1.0},"interval":12.8,"solo_dps":0.0}
tuned_mid priest/priest_chime {"aoe_dps":2017.5900000000001,"direct_dps":475.78000000000003,"ehp":550.03,"hit_model":{"five_hits":3.5023809523809524,"solo_hits":1.0},"interval":0.18,"solo_dps":678.67}
tuned_extreme priest/priest_chime {"aoe_dps":175683.63,"direct_dps":41103.81,"ehp":29677.21,"hit_model":{"five_hits":3.5023809523809524,"solo_hits":1.0},"interval":0.18,"solo_dps":58957.200000000004}
upgrade_3 priest/priest_chime {"aoe_dps":617.7,"direct_dps":144.4,"ehp":253.01000000000002,"hit_model":{"five_hits":3.5023809523809524,"solo_hits":1.0},"interval":0.585,"solo_dps":207.24}
upgrade_10_noult priest/priest_chime {"aoe_dps":8318.99,"direct_dps":1974.43,"ehp":782.45,"hit_model":{"five_hits":3.5023809523809524,"solo_hits":1.0},"interval":0.46,"solo_dps":2803.69}
tuning priest/priest_chime {"aoe_budget_multiplier":1.203,"aoe_target":135.45,"base_aoe_dps":40.22,"base_solo_dps":11.42,"damage_multiplier":2.8000000000000003,"solo_budget_multiplier":1.42,"solo_target":45.410000000000004}
crowd_0 priest/priest_chime {"cct":0.56,"cct_dev":-0.048,"crowd_dps":142.24,"enemy_hp":80.0,"target_cct":0.59,"target_count":1,"target_dps":135.45}
crowd_5 priest/priest_chime {"cct":2.81,"cct_dev":-0.048,"crowd_dps":142.24,"enemy_hp":80.0,"target_cct":2.95,"target_count":5,"target_dps":135.45}
crowd_10 priest/priest_chime {"cct":5.86,"cct_dev":-0.008,"crowd_dps":136.55,"enemy_hp":80.0,"target_cct":5.91,"target_count":10,"target_dps":135.45}
crowd_20 priest/priest_chime {"cct":12.46,"cct_dev":0.097,"crowd_dps":128.36,"enemy_hp":80.0,"target_cct":11.36,"target_count":20,"target_dps":140.87}
crowd_extreme_20 priest/priest_chime {"cct":0.01,"cct_dev":-0.999,"crowd_dps":166463.75,"enemy_hp":80.0,"target_cct":11.36,"target_count":20,"target_dps":140.87}
raw_untuned biologist/biologist_spore_lens {"aoe_dps":192.66,"direct_dps":12.24,"ehp":68.54,"hit_model":{"dot_targets":3.4705882352941178,"five_hits":4.620689655172414,"solo_hits":2.02},"interval":0.63,"solo_dps":65.15}
tuned_base biologist/biologist_spore_lens {"aoe_dps":191.16,"direct_dps":10.43,"ehp":68.54,"hit_model":{"dot_targets":3.4705882352941178,"five_hits":4.620689655172414,"solo_hits":2.02},"interval":0.63,"solo_dps":47.7}
tuned_zero biologist/biologist_spore_lens {"aoe_dps":7.25,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":3.4705882352941178,"five_hits":4.620689655172414,"solo_hits":2.02},"interval":11.8,"solo_dps":1.57}
tuned_mid biologist/biologist_spore_lens {"aoe_dps":1590.8600000000001,"direct_dps":147.14000000000001,"ehp":559.32,"hit_model":{"dot_targets":3.4705882352941178,"five_hits":4.620689655172414,"solo_hits":2.02},"interval":0.18,"solo_dps":434.48}
tuned_extreme biologist/biologist_spore_lens {"aoe_dps":87143.21,"direct_dps":13427.91,"ehp":30159.33,"hit_model":{"dot_targets":3.4705882352941178,"five_hits":4.620689655172414,"solo_hits":2.02},"interval":0.18,"solo_dps":27099.59}
upgrade_3 biologist/biologist_spore_lens {"aoe_dps":882.96,"direct_dps":72.31,"ehp":234.58,"hit_model":{"dot_targets":3.4705882352941178,"five_hits":4.620689655172414,"solo_hits":2.02},"interval":0.47100000000000003,"solo_dps":235.24}
upgrade_10_noult biologist/biologist_spore_lens {"aoe_dps":7779.45,"direct_dps":845.54,"ehp":761.11,"hit_model":{"dot_targets":3.4705882352941178,"five_hits":4.620689655172414,"solo_hits":2.02},"interval":0.37,"solo_dps":2203.83}
tuning biologist/biologist_spore_lens {"aoe_budget_multiplier":1.045,"aoe_target":191.16,"base_aoe_dps":192.66,"base_solo_dps":65.15,"damage_multiplier":0.852,"solo_budget_multiplier":0.783,"solo_target":47.69}
crowd_0 biologist/biologist_spore_lens {"cct":0.38,"cct_dev":-0.084,"crowd_dps":208.75,"enemy_hp":80.0,"target_cct":0.42,"target_count":1,"target_dps":191.16}
crowd_5 biologist/biologist_spore_lens {"cct":1.92,"cct_dev":-0.084,"crowd_dps":208.75,"enemy_hp":80.0,"target_cct":2.09,"target_count":5,"target_dps":191.16}
crowd_10 biologist/biologist_spore_lens {"cct":3.99,"cct_dev":-0.046,"crowd_dps":200.4,"enemy_hp":80.0,"target_cct":4.18,"target_count":10,"target_dps":191.16}
crowd_20 biologist/biologist_spore_lens {"cct":8.49,"cct_dev":0.055,"crowd_dps":188.37,"enemy_hp":80.0,"target_cct":8.05,"target_count":20,"target_dps":198.81}
crowd_extreme_20 biologist/biologist_spore_lens {"cct":0.02,"cct_dev":-0.998,"crowd_dps":85872.73,"enemy_hp":80.0,"target_cct":8.05,"target_count":20,"target_dps":198.81}
raw_untuned biologist/biologist_sample_injector {"aoe_dps":71.77,"direct_dps":17.89,"ehp":68.54,"hit_model":{"dot_targets":1.0,"five_hits":2.8616028461959497,"solo_hits":1.7514999999999998},"interval":0.56,"solo_dps":48.230000000000004}
tuned_base biologist/biologist_sample_injector {"aoe_dps":191.19,"direct_dps":29.04,"ehp":68.54,"hit_model":{"dot_targets":1.0,"five_hits":2.8616028461959497,"solo_hits":1.7514999999999998},"interval":0.56,"solo_dps":47.71}
tuned_zero biologist/biologist_sample_injector {"aoe_dps":1.01,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":1.0,"five_hits":2.8616028461959497,"solo_hits":1.7514999999999998},"interval":10.5,"solo_dps":0.39}
tuned_mid biologist/biologist_sample_injector {"aoe_dps":2349.33,"direct_dps":367.85,"ehp":559.32,"hit_model":{"dot_targets":1.0,"five_hits":2.8616028461959497,"solo_hits":1.7514999999999998},"interval":0.18,"solo_dps":582.27}
tuned_extreme biologist/biologist_sample_injector {"aoe_dps":196128.99,"direct_dps":32942.95,"ehp":30159.33,"hit_model":{"dot_targets":1.0,"five_hits":2.8616028461959497,"solo_hits":1.7514999999999998},"interval":0.18,"solo_dps":46246.73}
upgrade_3 biologist/biologist_sample_injector {"aoe_dps":943.71,"direct_dps":148.05,"ehp":234.58,"hit_model":{"dot_targets":1.0,"five_hits":2.8616028461959497,"solo_hits":1.7514999999999998},"interval":0.419,"solo_dps":232.18}
upgrade_10_noult biologist/biologist_sample_injector {"aoe_dps":11692.89,"direct_dps":1934.96,"ehp":761.11,"hit_model":{"dot_targets":1.0,"five_hits":2.8616028461959497,"solo_hits":1.7514999999999998},"interval":0.33,"solo_dps":2828.25}
tuning biologist/biologist_sample_injector {"aoe_budget_multiplier":1.754,"aoe_target":191.16,"base_aoe_dps":71.77,"base_solo_dps":48.230000000000004,"damage_multiplier":1.623,"solo_budget_multiplier":0.674,"solo_target":47.69}
crowd_0 biologist/biologist_sample_injector {"cct":0.42,"cct_dev":0.0,"crowd_dps":191.19,"enemy_hp":80.0,"target_cct":0.42,"target_count":1,"target_dps":191.16}
crowd_5 biologist/biologist_sample_injector {"cct":2.09,"cct_dev":0.0,"crowd_dps":191.19,"enemy_hp":80.0,"target_cct":2.09,"target_count":5,"target_dps":191.16}
crowd_10 biologist/biologist_sample_injector {"cct":4.36,"cct_dev":0.042,"crowd_dps":183.54,"enemy_hp":80.0,"target_cct":4.18,"target_count":10,"target_dps":191.16}
crowd_20 biologist/biologist_sample_injector {"cct":9.27,"cct_dev":0.108,"crowd_dps":172.53,"enemy_hp":80.0,"target_cct":8.370000000000001,"target_count":20,"target_dps":191.16}
crowd_extreme_20 biologist/biologist_sample_injector {"cct":0.01,"cct_dev":-0.999,"crowd_dps":176986.80000000002,"enemy_hp":80.0,"target_cct":8.370000000000001,"target_count":20,"target_dps":191.16}
raw_untuned biologist/biologist_symbiote_seed {"aoe_dps":93.98,"direct_dps":10.59,"ehp":68.54,"hit_model":{"dot_targets":2.5789473684210527,"five_hits":2.009090909090909,"solo_hits":0.85},"interval":0.662,"solo_dps":37.19}
tuned_base biologist/biologist_symbiote_seed {"aoe_dps":191.15,"direct_dps":17.11,"ehp":68.54,"hit_model":{"dot_targets":2.5789473684210527,"five_hits":2.009090909090909,"solo_hits":0.85},"interval":0.662,"solo_dps":47.69}
tuned_zero biologist/biologist_symbiote_seed {"aoe_dps":5.7700000000000005,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":2.5789473684210527,"five_hits":2.009090909090909,"solo_hits":0.85},"interval":12.4,"solo_dps":1.4000000000000001}
tuned_mid biologist/biologist_symbiote_seed {"aoe_dps":2492.21,"direct_dps":253.55,"ehp":559.32,"hit_model":{"dot_targets":2.5789473684210527,"five_hits":2.009090909090909,"solo_hits":0.85},"interval":0.18,"solo_dps":626.16}
tuned_extreme biologist/biologist_symbiote_seed {"aoe_dps":118874.58,"direct_dps":23139.22,"ehp":30159.33,"hit_model":{"dot_targets":2.5789473684210527,"five_hits":2.009090909090909,"solo_hits":0.85},"interval":0.18,"solo_dps":30695.86}
upgrade_3 biologist/biologist_symbiote_seed {"aoe_dps":847.07,"direct_dps":95.96000000000001,"ehp":234.58,"hit_model":{"dot_targets":2.5789473684210527,"five_hits":2.009090909090909,"solo_hits":0.85},"interval":0.495,"solo_dps":213.15}
upgrade_10_noult biologist/biologist_symbiote_seed {"aoe_dps":7867.92,"direct_dps":1208.17,"ehp":761.11,"hit_model":{"dot_targets":2.5789473684210527,"five_hits":2.009090909090909,"solo_hits":0.85},"interval":0.389,"solo_dps":2016.5}
tuning biologist/biologist_symbiote_seed {"aoe_budget_multiplier":1.747,"aoe_target":191.16,"base_aoe_dps":93.98,"base_solo_dps":37.19,"damage_multiplier":1.615,"solo_budget_multiplier":1.093,"solo_target":47.69}
crowd_0 biologist/biologist_symbiote_seed {"cct":0.4,"cct_dev":-0.048,"crowd_dps":200.71,"enemy_hp":80.0,"target_cct":0.42,"target_count":1,"target_dps":191.16}
crowd_5 biologist/biologist_symbiote_seed {"cct":1.99,"cct_dev":-0.048,"crowd_dps":200.71,"enemy_hp":80.0,"target_cct":2.09,"target_count":5,"target_dps":191.16}
crowd_10 biologist/biologist_symbiote_seed {"cct":4.15,"cct_dev":-0.008,"crowd_dps":192.68,"enemy_hp":80.0,"target_cct":4.18,"target_count":10,"target_dps":191.16}
crowd_20 biologist/biologist_symbiote_seed {"cct":8.83,"cct_dev":0.098,"crowd_dps":181.12,"enemy_hp":80.0,"target_cct":8.05,"target_count":20,"target_dps":198.81}
crowd_extreme_20 biologist/biologist_symbiote_seed {"cct":0.01,"cct_dev":-0.998,"crowd_dps":112636.04000000001,"enemy_hp":80.0,"target_cct":8.05,"target_count":20,"target_dps":198.81}
raw_untuned robot/robot_magnetic_anchor {"aoe_dps":61.29,"direct_dps":13.0,"ehp":178.70000000000002,"hit_model":{"five_hits":4.62,"solo_hits":1.0},"interval":1.471,"solo_dps":13.25}
tuned_base robot/robot_magnetic_anchor {"aoe_dps":118.09,"direct_dps":30.77,"ehp":178.70000000000002,"hit_model":{"five_hits":4.62,"solo_hits":1.0},"interval":1.471,"solo_dps":38.53}
tuned_zero robot/robot_magnetic_anchor {"aoe_dps":0.0,"direct_dps":0.0,"ehp":12.0,"hit_model":{"five_hits":4.62,"solo_hits":1.0},"interval":20.5,"solo_dps":0.0}
tuned_mid robot/robot_magnetic_anchor {"aoe_dps":1828.82,"direct_dps":484.02,"ehp":458.02,"hit_model":{"five_hits":4.62,"solo_hits":1.0},"interval":0.292,"solo_dps":597.45}
tuned_extreme robot/robot_magnetic_anchor {"aoe_dps":244024.45,"direct_dps":64549.9,"ehp":21521.91,"hit_model":{"five_hits":4.62,"solo_hits":1.0},"interval":0.18,"solo_dps":79716.21}
upgrade_3 robot/robot_magnetic_anchor {"aoe_dps":341.40000000000003,"direct_dps":89.32000000000001,"ehp":362.46,"hit_model":{"five_hits":4.62,"solo_hits":1.0},"interval":1.101,"solo_dps":111.43}
upgrade_10_noult robot/robot_magnetic_anchor {"aoe_dps":2113.31,"direct_dps":561.95,"ehp":906.77,"hit_model":{"five_hits":4.62,"solo_hits":1.0},"interval":0.866,"solo_dps":690.63}
tuning robot/robot_magnetic_anchor {"aoe_budget_multiplier":0.8140000000000001,"aoe_target":118.13,"base_aoe_dps":61.29,"base_solo_dps":13.25,"damage_multiplier":2.367,"solo_budget_multiplier":1.229,"solo_target":38.52}
crowd_0 robot/robot_magnetic_anchor {"cct":0.65,"cct_dev":-0.047,"crowd_dps":123.99000000000001,"enemy_hp":80.0,"target_cct":0.68,"target_count":1,"target_dps":118.13}
crowd_5 robot/robot_magnetic_anchor {"cct":3.23,"cct_dev":-0.047,"crowd_dps":123.99000000000001,"enemy_hp":80.0,"target_cct":3.39,"target_count":5,"target_dps":118.13}
crowd_10 robot/robot_magnetic_anchor {"cct":6.72,"cct_dev":-0.008,"crowd_dps":119.03,"enemy_hp":80.0,"target_cct":6.7700000000000005,"target_count":10,"target_dps":118.13}
crowd_20 robot/robot_magnetic_anchor {"cct":14.3,"cct_dev":0.098,"crowd_dps":111.89,"enemy_hp":80.0,"target_cct":13.02,"target_count":20,"target_dps":122.86}
crowd_extreme_20 robot/robot_magnetic_anchor {"cct":0.01,"cct_dev":-0.999,"crowd_dps":231218.05000000002,"enemy_hp":80.0,"target_cct":13.02,"target_count":20,"target_dps":122.86}
raw_untuned robot/robot_hydraulic_press {"aoe_dps":62.34,"direct_dps":13.370000000000001,"ehp":170.67000000000002,"hit_model":{"five_hits":4.6,"solo_hits":1.0},"interval":0.969,"solo_dps":13.540000000000001}
tuned_base robot/robot_hydraulic_press {"aoe_dps":118.13,"direct_dps":31.05,"ehp":170.67000000000002,"hit_model":{"five_hits":4.6,"solo_hits":1.0},"interval":0.969,"solo_dps":38.54}
tuned_zero robot/robot_hydraulic_press {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":4.6,"solo_hits":1.0},"interval":13.5,"solo_dps":0.0}
tuned_mid robot/robot_hydraulic_press {"aoe_dps":1839.0900000000001,"direct_dps":488.43,"ehp":451.72,"hit_model":{"five_hits":4.6,"solo_hits":1.0},"interval":0.192,"solo_dps":600.53}
tuned_extreme robot/robot_hydraulic_press {"aoe_dps":161862.54,"direct_dps":42896.04,"ehp":21518.13,"hit_model":{"five_hits":4.6,"solo_hits":1.0},"interval":0.18,"solo_dps":52845.35}
upgrade_3 robot/robot_hydraulic_press {"aoe_dps":368.34000000000003,"direct_dps":97.08,"ehp":354.89,"hit_model":{"five_hits":4.6,"solo_hits":1.0},"interval":0.725,"solo_dps":120.2}
upgrade_10_noult robot/robot_hydraulic_press {"aoe_dps":2336.3,"direct_dps":622.42,"ehp":899.62,"hit_model":{"five_hits":4.6,"solo_hits":1.0},"interval":0.5700000000000001,"solo_dps":763.08}
tuning robot/robot_hydraulic_press {"aoe_budget_multiplier":0.8160000000000001,"aoe_target":118.13,"base_aoe_dps":62.34,"base_solo_dps":13.540000000000001,"damage_multiplier":2.322,"solo_budget_multiplier":1.226,"solo_target":38.52}
crowd_0 robot/robot_hydraulic_press {"cct":0.6900000000000001,"cct_dev":0.02,"crowd_dps":115.77,"enemy_hp":80.0,"target_cct":0.68,"target_count":1,"target_dps":118.13}
crowd_5 robot/robot_hydraulic_press {"cct":3.46,"cct_dev":0.02,"crowd_dps":115.77,"enemy_hp":80.0,"target_cct":3.39,"target_count":5,"target_dps":118.13}
crowd_10 robot/robot_hydraulic_press {"cct":7.2,"cct_dev":0.063,"crowd_dps":111.14,"enemy_hp":80.0,"target_cct":6.7700000000000005,"target_count":10,"target_dps":118.13}
crowd_20 robot/robot_hydraulic_press {"cct":15.32,"cct_dev":0.131,"crowd_dps":104.47,"enemy_hp":80.0,"target_cct":13.540000000000001,"target_count":20,"target_dps":118.13}
crowd_extreme_20 robot/robot_hydraulic_press {"cct":0.01,"cct_dev":-0.999,"crowd_dps":143143.46,"enemy_hp":80.0,"target_cct":13.540000000000001,"target_count":20,"target_dps":118.13}
raw_untuned robot/robot_reactor_core {"aoe_dps":27.11,"direct_dps":13.08,"ehp":170.18,"hit_model":{"five_hits":2.03,"solo_hits":0.42},"interval":0.66,"solo_dps":5.61}
tuned_base robot/robot_reactor_core {"aoe_dps":118.12,"direct_dps":36.62,"ehp":170.18,"hit_model":{"five_hits":2.03,"solo_hits":0.42},"interval":0.66,"solo_dps":38.52}
tuned_zero robot/robot_reactor_core {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.92,"hit_model":{"five_hits":2.03,"solo_hits":0.42},"interval":9.200000000000001,"solo_dps":0.0}
tuned_mid robot/robot_reactor_core {"aoe_dps":1331.79,"direct_dps":418.85,"ehp":451.7,"hit_model":{"five_hits":2.03,"solo_hits":0.42},"interval":0.18,"solo_dps":434.47}
tuned_extreme robot/robot_reactor_core {"aoe_dps":110224.85,"direct_dps":34484.32,"ehp":21565.47,"hit_model":{"five_hits":2.03,"solo_hits":0.42},"interval":0.18,"solo_dps":35952.32}
upgrade_3 robot/robot_reactor_core {"aoe_dps":386.91,"direct_dps":120.47,"ehp":353.94,"hit_model":{"five_hits":2.03,"solo_hits":0.42},"interval":0.494,"solo_dps":126.18}
upgrade_10_noult robot/robot_reactor_core {"aoe_dps":2469.15,"direct_dps":781.7,"ehp":898.25,"hit_model":{"five_hits":2.03,"solo_hits":0.42},"interval":0.388,"solo_dps":805.69}
tuning robot/robot_reactor_core {"aoe_budget_multiplier":1.556,"aoe_target":118.13,"base_aoe_dps":27.11,"base_solo_dps":5.61,"damage_multiplier":2.8000000000000003,"solo_budget_multiplier":2.454,"solo_target":38.52}
crowd_0 robot/robot_reactor_core {"cct":0.68,"cct_dev":0.0,"crowd_dps":118.12,"enemy_hp":80.0,"target_cct":0.68,"target_count":1,"target_dps":118.13}
crowd_5 robot/robot_reactor_core {"cct":3.39,"cct_dev":0.0,"crowd_dps":118.12,"enemy_hp":80.0,"target_cct":3.39,"target_count":5,"target_dps":118.13}
crowd_10 robot/robot_reactor_core {"cct":7.05,"cct_dev":0.042,"crowd_dps":113.4,"enemy_hp":80.0,"target_cct":6.7700000000000005,"target_count":10,"target_dps":118.13}
crowd_20 robot/robot_reactor_core {"cct":15.01,"cct_dev":0.108,"crowd_dps":106.59,"enemy_hp":80.0,"target_cct":13.540000000000001,"target_count":20,"target_dps":118.13}
crowd_extreme_20 robot/robot_reactor_core {"cct":0.02,"cct_dev":-0.999,"crowd_dps":99466.90000000001,"enemy_hp":80.0,"target_cct":13.540000000000001,"target_count":20,"target_dps":118.13}
raw_untuned engineer/engineer_sentry_wrench {"aoe_dps":150.32,"direct_dps":6.98,"ehp":83.57000000000001,"hit_model":{"five_hits":2.2833714285714284,"solo_hits":1.0,"summon_targets":1.1416857142857144},"interval":1.453,"solo_dps":123.36}
tuned_base engineer/engineer_sentry_wrench {"aoe_dps":161.35,"direct_dps":4.38,"ehp":83.57000000000001,"hit_model":{"five_hits":2.2833714285714284,"solo_hits":1.0,"summon_targets":1.1416857142857144},"interval":1.453,"solo_dps":45.17}
tuned_zero engineer/engineer_sentry_wrench {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.2833714285714284,"solo_hits":1.0,"summon_targets":0.0},"interval":27.0,"solo_dps":0.0}
tuned_mid engineer/engineer_sentry_wrench {"aoe_dps":5036.47,"direct_dps":145.96,"ehp":542.53,"hit_model":{"five_hits":2.2833714285714284,"solo_hits":1.0,"summon_targets":1.1416857142857144},"interval":0.365,"solo_dps":1398.02}
tuned_extreme engineer/engineer_sentry_wrench {"aoe_dps":314268.05,"direct_dps":25056.32,"ehp":29142.45,"hit_model":{"five_hits":2.2833714285714284,"solo_hits":1.0,"summon_targets":1.5856746031746034},"interval":0.18,"solo_dps":58783.8}
upgrade_3 engineer/engineer_sentry_wrench {"aoe_dps":1900.13,"direct_dps":61.89,"ehp":242.57,"hit_model":{"five_hits":2.2833714285714284,"solo_hits":1.0,"summon_targets":1.1416857142857144},"interval":1.087,"solo_dps":524.73}
upgrade_10_noult engineer/engineer_sentry_wrench {"aoe_dps":14424.210000000001,"direct_dps":778.97,"ehp":748.51,"hit_model":{"five_hits":2.2833714285714284,"solo_hits":1.0,"summon_targets":1.1416857142857142},"interval":0.855,"solo_dps":3787.34}
tuning engineer/engineer_sentry_wrench {"aoe_budget_multiplier":1.712,"aoe_target":161.28,"base_aoe_dps":150.32,"base_solo_dps":123.36,"damage_multiplier":0.627,"solo_budget_multiplier":0.584,"solo_target":45.160000000000004}
crowd_0 engineer/engineer_sentry_wrench {"cct":0.52,"cct_dev":0.041,"crowd_dps":154.9,"enemy_hp":80.0,"target_cct":0.5,"target_count":1,"target_dps":161.28}
crowd_5 engineer/engineer_sentry_wrench {"cct":2.58,"cct_dev":0.041,"crowd_dps":154.9,"enemy_hp":80.0,"target_cct":2.48,"target_count":5,"target_dps":161.28}
crowd_10 engineer/engineer_sentry_wrench {"cct":5.38,"cct_dev":0.085,"crowd_dps":148.70000000000002,"enemy_hp":80.0,"target_cct":4.96,"target_count":10,"target_dps":161.28}
crowd_20 engineer/engineer_sentry_wrench {"cct":11.450000000000001,"cct_dev":0.2,"crowd_dps":139.78,"enemy_hp":80.0,"target_cct":9.540000000000001,"target_count":20,"target_dps":167.73}
crowd_extreme_20 engineer/engineer_sentry_wrench {"cct":0.01,"cct_dev":-0.999,"crowd_dps":272251.67,"enemy_hp":80.0,"target_cct":9.540000000000001,"target_count":20,"target_dps":167.73}
raw_untuned engineer/engineer_repair_drone {"aoe_dps":293.63,"direct_dps":0.0,"ehp":83.57000000000001,"hit_model":{"five_hits":1.0,"solo_hits":1.0,"summon_targets":4.224137931034482},"interval":0.646,"solo_dps":69.45}
tuned_base engineer/engineer_repair_drone {"aoe_dps":161.37,"direct_dps":0.0,"ehp":83.57000000000001,"hit_model":{"five_hits":1.0,"solo_hits":1.0,"summon_targets":4.224137931034482},"interval":0.646,"solo_dps":45.18}
tuned_zero engineer/engineer_repair_drone {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":1.0,"solo_hits":1.0,"summon_targets":4.224137931034482},"interval":12.0,"solo_dps":0.0}
tuned_mid engineer/engineer_repair_drone {"aoe_dps":5416.07,"direct_dps":0.0,"ehp":542.53,"hit_model":{"five_hits":1.0,"solo_hits":1.0,"summon_targets":5.0},"interval":0.18,"solo_dps":1282.41}
tuned_extreme engineer/engineer_repair_drone {"aoe_dps":103216.84,"direct_dps":0.0,"ehp":29142.45,"hit_model":{"five_hits":1.0,"solo_hits":1.0,"summon_targets":5.0},"interval":0.18,"solo_dps":24439.59}
upgrade_3 engineer/engineer_repair_drone {"aoe_dps":519.29,"direct_dps":0.0,"ehp":242.57,"hit_model":{"five_hits":1.0,"solo_hits":1.0,"summon_targets":4.224137931034482},"interval":0.483,"solo_dps":145.36}
upgrade_10_noult engineer/engineer_repair_drone {"aoe_dps":1495.33,"direct_dps":0.0,"ehp":748.51,"hit_model":{"five_hits":1.0,"solo_hits":1.0,"summon_targets":4.224137931034482},"interval":0.38,"solo_dps":419.09000000000003}
tuning engineer/engineer_repair_drone {"aoe_budget_multiplier":0.919,"aoe_target":161.28,"base_aoe_dps":293.63,"base_solo_dps":69.45,"damage_multiplier":0.598,"solo_budget_multiplier":1.088,"solo_target":45.160000000000004}
crowd_0 engineer/engineer_repair_drone {"cct":0.52,"cct_dev":0.041,"crowd_dps":154.92000000000002,"enemy_hp":80.0,"target_cct":0.5,"target_count":1,"target_dps":161.28}
crowd_5 engineer/engineer_repair_drone {"cct":2.58,"cct_dev":0.041,"crowd_dps":154.92000000000002,"enemy_hp":80.0,"target_cct":2.48,"target_count":5,"target_dps":161.28}
crowd_10 engineer/engineer_repair_drone {"cct":5.38,"cct_dev":0.084,"crowd_dps":148.72,"enemy_hp":80.0,"target_cct":4.96,"target_count":10,"target_dps":161.28}
crowd_20 engineer/engineer_repair_drone {"cct":11.450000000000001,"cct_dev":0.2,"crowd_dps":139.8,"enemy_hp":80.0,"target_cct":9.540000000000001,"target_count":20,"target_dps":167.73}
crowd_extreme_20 engineer/engineer_repair_drone {"cct":0.02,"cct_dev":-0.998,"crowd_dps":89417.16,"enemy_hp":80.0,"target_cct":9.540000000000001,"target_count":20,"target_dps":167.73}
raw_untuned engineer/engineer_pressure_mines {"aoe_dps":108.14,"direct_dps":28.67,"ehp":83.57000000000001,"hit_model":{"five_hits":3.4705882352941178,"solo_hits":1.0},"interval":0.786,"solo_dps":30.92}
tuned_base engineer/engineer_pressure_mines {"aoe_dps":161.37,"direct_dps":42.31,"ehp":83.57000000000001,"hit_model":{"five_hits":3.4705882352941178,"solo_hits":1.0},"interval":0.786,"solo_dps":45.18}
tuned_zero engineer/engineer_pressure_mines {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.4705882352941178,"solo_hits":1.0},"interval":14.6,"solo_dps":0.0}
tuned_mid engineer/engineer_pressure_mines {"aoe_dps":3564.25,"direct_dps":952.9300000000001,"ehp":542.53,"hit_model":{"five_hits":3.4705882352941178,"solo_hits":1.0},"interval":0.197,"solo_dps":1003.75}
tuned_extreme engineer/engineer_pressure_mines {"aoe_dps":332995.27,"direct_dps":88458.88,"ehp":29142.45,"hit_model":{"five_hits":3.4705882352941178,"solo_hits":1.0},"interval":0.18,"solo_dps":93594.29000000001}
upgrade_3 engineer/engineer_pressure_mines {"aoe_dps":504.44,"direct_dps":132.11,"ehp":242.57,"hit_model":{"five_hits":3.4705882352941178,"solo_hits":1.0},"interval":0.588,"solo_dps":141.17000000000002}
upgrade_10_noult engineer/engineer_pressure_mines {"aoe_dps":3104.12,"direct_dps":835.07,"ehp":748.51,"hit_model":{"five_hits":3.4705882352941178,"solo_hits":1.0},"interval":0.462,"solo_dps":875.83}
tuning engineer/engineer_pressure_mines {"aoe_budget_multiplier":1.0110000000000001,"aoe_target":161.28,"base_aoe_dps":108.14,"base_solo_dps":30.92,"damage_multiplier":1.476,"solo_budget_multiplier":0.99,"solo_target":45.160000000000004}
crowd_0 engineer/engineer_pressure_mines {"cct":0.45,"cct_dev":-0.085,"crowd_dps":176.22,"enemy_hp":80.0,"target_cct":0.5,"target_count":1,"target_dps":161.28}
crowd_5 engineer/engineer_pressure_mines {"cct":2.27,"cct_dev":-0.085,"crowd_dps":176.22,"enemy_hp":80.0,"target_cct":2.48,"target_count":5,"target_dps":161.28}
crowd_10 engineer/engineer_pressure_mines {"cct":4.73,"cct_dev":-0.047,"crowd_dps":169.17000000000002,"enemy_hp":80.0,"target_cct":4.96,"target_count":10,"target_dps":161.28}
crowd_20 engineer/engineer_pressure_mines {"cct":10.06,"cct_dev":0.055,"crowd_dps":159.02,"enemy_hp":80.0,"target_cct":9.540000000000001,"target_count":20,"target_dps":167.73}
crowd_extreme_20 engineer/engineer_pressure_mines {"cct":0.0,"cct_dev":-0.999,"crowd_dps":328140.47000000003,"enemy_hp":80.0,"target_cct":9.540000000000001,"target_count":20,"target_dps":167.73}
raw_untuned dark_mage/dark_book {"aoe_dps":45.27,"direct_dps":13.76,"ehp":49.96,"hit_model":{"five_hits":3.1999999999999997,"pool_targets":2.3461538461538463,"solo_hits":1.0},"interval":0.994,"solo_dps":14.06}
tuned_base dark_mage/dark_book {"aoe_dps":93.60000000000001,"direct_dps":20.56,"ehp":49.96,"hit_model":{"five_hits":3.1999999999999997,"pool_targets":2.3461538461538463,"solo_hits":1.0},"interval":0.994,"solo_dps":15.200000000000001}
tuned_zero dark_mage/dark_book {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.1999999999999997,"pool_targets":2.3461538461538463,"solo_hits":1.0},"interval":13.1,"solo_dps":0.0}
tuned_mid dark_mage/dark_book {"aoe_dps":1417.24,"direct_dps":317.85,"ehp":548.91,"hit_model":{"five_hits":3.1999999999999997,"pool_targets":2.3461538461538463,"solo_hits":1.0},"interval":0.18,"solo_dps":231.14000000000001}
tuned_extreme dark_mage/dark_book {"aoe_dps":121665.41,"direct_dps":27031.74,"ehp":29639.190000000002,"hit_model":{"five_hits":3.1999999999999997,"pool_targets":2.3461538461538463,"solo_hits":1.0},"interval":0.18,"solo_dps":19801.350000000002}
upgrade_3 dark_mage/dark_book {"aoe_dps":437.72,"direct_dps":96.71000000000001,"ehp":194.86,"hit_model":{"five_hits":3.1999999999999997,"pool_targets":2.3461538461538463,"solo_hits":1.0},"interval":0.744,"solo_dps":71.15}
upgrade_10_noult dark_mage/dark_book {"aoe_dps":5794.36,"direct_dps":1309.28,"ehp":677.23,"hit_model":{"five_hits":3.1999999999999997,"pool_targets":2.3461538461538463,"solo_hits":1.0},"interval":0.585,"solo_dps":946.61}
tuning dark_mage/dark_book {"aoe_budget_multiplier":1.383,"aoe_target":93.60000000000001,"base_aoe_dps":45.27,"base_solo_dps":14.06,"damage_multiplier":1.495,"solo_budget_multiplier":0.723,"solo_target":15.21}
crowd_0 dark_mage/dark_book {"cct":0.8200000000000001,"cct_dev":-0.038,"crowd_dps":97.34,"enemy_hp":80.0,"target_cct":0.85,"target_count":1,"target_dps":93.60000000000001}
crowd_5 dark_mage/dark_book {"cct":4.11,"cct_dev":-0.038,"crowd_dps":97.34,"enemy_hp":80.0,"target_cct":4.2700000000000005,"target_count":5,"target_dps":93.60000000000001}
crowd_10 dark_mage/dark_book {"cct":8.56,"cct_dev":0.002,"crowd_dps":93.45,"enemy_hp":80.0,"target_cct":8.55,"target_count":10,"target_dps":93.60000000000001}
crowd_20 dark_mage/dark_book {"cct":18.21,"cct_dev":0.066,"crowd_dps":87.84,"enemy_hp":80.0,"target_cct":17.09,"target_count":20,"target_dps":93.60000000000001}
crowd_extreme_20 dark_mage/dark_book {"cct":0.01,"cct_dev":-0.999,"crowd_dps":114182.5,"enemy_hp":80.0,"target_cct":17.09,"target_count":20,"target_dps":93.60000000000001}
raw_untuned dark_mage/cursed_skull {"aoe_dps":95.0,"direct_dps":0.0,"ehp":49.96,"hit_model":{"dot_targets":2.5,"five_hits":1.0,"solo_hits":1.0},"interval":0.683,"solo_dps":37.79}
tuned_base dark_mage/cursed_skull {"aoe_dps":93.57000000000001,"direct_dps":0.0,"ehp":49.96,"hit_model":{"dot_targets":2.5,"five_hits":1.0,"solo_hits":1.0},"interval":0.683,"solo_dps":15.22}
tuned_zero dark_mage/cursed_skull {"aoe_dps":1.98,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":2.5,"five_hits":1.0,"solo_hits":1.0},"interval":9.0,"solo_dps":0.32}
tuned_mid dark_mage/cursed_skull {"aoe_dps":1506.92,"direct_dps":0.0,"ehp":548.91,"hit_model":{"dot_targets":2.5,"five_hits":1.0,"solo_hits":1.0},"interval":0.18,"solo_dps":245.76}
tuned_extreme dark_mage/cursed_skull {"aoe_dps":334498.52,"direct_dps":0.0,"ehp":29639.190000000002,"hit_model":{"dot_targets":2.5,"five_hits":1.0,"solo_hits":1.0},"interval":0.18,"solo_dps":54559.36}
upgrade_3 dark_mage/cursed_skull {"aoe_dps":405.13,"direct_dps":0.0,"ehp":194.86,"hit_model":{"dot_targets":2.5,"five_hits":1.0,"solo_hits":1.0},"interval":0.511,"solo_dps":65.88}
upgrade_10_noult dark_mage/cursed_skull {"aoe_dps":2867.19,"direct_dps":0.0,"ehp":677.23,"hit_model":{"dot_targets":2.5,"five_hits":1.0,"solo_hits":1.0},"interval":0.402,"solo_dps":468.02}
tuning dark_mage/cursed_skull {"aoe_budget_multiplier":0.99,"aoe_target":93.60000000000001,"base_aoe_dps":95.0,"base_solo_dps":37.79,"damage_multiplier":0.63,"solo_budget_multiplier":0.404,"solo_target":15.21}
crowd_0 dark_mage/cursed_skull {"cct":0.81,"cct_dev":-0.047,"crowd_dps":98.25,"enemy_hp":80.0,"target_cct":0.85,"target_count":1,"target_dps":93.60000000000001}
crowd_5 dark_mage/cursed_skull {"cct":4.07,"cct_dev":-0.047,"crowd_dps":98.25,"enemy_hp":80.0,"target_cct":4.2700000000000005,"target_count":5,"target_dps":93.60000000000001}
crowd_10 dark_mage/cursed_skull {"cct":8.48,"cct_dev":-0.008,"crowd_dps":94.32000000000001,"enemy_hp":80.0,"target_cct":8.55,"target_count":10,"target_dps":93.60000000000001}
crowd_20 dark_mage/cursed_skull {"cct":18.05,"cct_dev":0.098,"crowd_dps":88.66,"enemy_hp":80.0,"target_cct":16.44,"target_count":20,"target_dps":97.34}
crowd_extreme_20 dark_mage/cursed_skull {"cct":0.01,"cct_dev":-1.0,"crowd_dps":316944.04,"enemy_hp":80.0,"target_cct":16.44,"target_count":20,"target_dps":97.34}
raw_untuned dark_mage/dark_wand {"aoe_dps":51.59,"direct_dps":13.35,"ehp":49.96,"hit_model":{"five_hits":3.7713473684210523,"solo_hits":1.0},"interval":1.025,"solo_dps":13.65}
tuned_base dark_mage/dark_wand {"aoe_dps":93.61,"direct_dps":18.98,"ehp":49.96,"hit_model":{"five_hits":3.7713473684210523,"solo_hits":1.0},"interval":1.025,"solo_dps":15.200000000000001}
tuned_zero dark_mage/dark_wand {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.7713473684210523,"solo_hits":1.0},"interval":13.5,"solo_dps":0.0}
tuned_mid dark_mage/dark_wand {"aoe_dps":1464.15,"direct_dps":302.33,"ehp":548.91,"hit_model":{"five_hits":3.7713473684210523,"solo_hits":1.0},"interval":0.18,"solo_dps":238.1}
tuned_extreme dark_mage/dark_wand {"aoe_dps":125516.08,"direct_dps":25711.8,"ehp":29639.190000000002,"hit_model":{"five_hits":3.7713473684210523,"solo_hits":1.0},"interval":0.18,"solo_dps":20397.49}
upgrade_3 dark_mage/dark_wand {"aoe_dps":442.77,"direct_dps":90.22,"ehp":194.86,"hit_model":{"five_hits":3.7713473684210523,"solo_hits":1.0},"interval":0.766,"solo_dps":71.92}
upgrade_10_noult dark_mage/dark_wand {"aoe_dps":5852.02,"direct_dps":1216.07,"ehp":677.23,"hit_model":{"five_hits":3.7713473684210523,"solo_hits":1.0},"interval":0.603,"solo_dps":952.1800000000001}
tuning dark_mage/dark_wand {"aoe_budget_multiplier":1.276,"aoe_target":93.60000000000001,"base_aoe_dps":51.59,"base_solo_dps":13.65,"damage_multiplier":1.422,"solo_budget_multiplier":0.783,"solo_target":15.21}
crowd_0 dark_mage/dark_wand {"cct":0.85,"cct_dev":0.0,"crowd_dps":93.61,"enemy_hp":80.0,"target_cct":0.85,"target_count":1,"target_dps":93.60000000000001}
crowd_5 dark_mage/dark_wand {"cct":4.2700000000000005,"cct_dev":0.0,"crowd_dps":93.61,"enemy_hp":80.0,"target_cct":4.2700000000000005,"target_count":5,"target_dps":93.60000000000001}
crowd_10 dark_mage/dark_wand {"cct":8.9,"cct_dev":0.042,"crowd_dps":89.87,"enemy_hp":80.0,"target_cct":8.55,"target_count":10,"target_dps":93.60000000000001}
crowd_20 dark_mage/dark_wand {"cct":18.94,"cct_dev":0.108,"crowd_dps":84.47,"enemy_hp":80.0,"target_cct":17.09,"target_count":20,"target_dps":93.60000000000001}
crowd_extreme_20 dark_mage/dark_wand {"cct":0.01,"cct_dev":-0.999,"crowd_dps":113265.71,"enemy_hp":80.0,"target_cct":17.09,"target_count":20,"target_dps":93.60000000000001}
raw_untuned guitarist/electric_guitar {"aoe_dps":80.45,"direct_dps":34.32,"ehp":67.03,"hit_model":{"five_hits":2.323809523809524,"solo_hits":1.0},"interval":0.223,"solo_dps":34.47}
tuned_base guitarist/electric_guitar {"aoe_dps":292.46,"direct_dps":94.57000000000001,"ehp":67.03,"hit_model":{"five_hits":2.323809523809524,"solo_hits":1.0},"interval":0.223,"solo_dps":72.0}
tuned_zero guitarist/electric_guitar {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.323809523809524,"solo_hits":1.0},"interval":5.5,"solo_dps":0.0}
tuned_mid guitarist/electric_guitar {"aoe_dps":2126.14,"direct_dps":687.78,"ehp":414.07,"hit_model":{"five_hits":2.323809523809524,"solo_hits":1.0},"interval":0.18,"solo_dps":523.52}
tuned_extreme guitarist/electric_guitar {"aoe_dps":182772.0,"direct_dps":58714.44,"ehp":21423.08,"hit_model":{"five_hits":2.323809523809524,"solo_hits":1.0},"interval":0.18,"solo_dps":44845.82}
upgrade_3 guitarist/electric_guitar {"aoe_dps":1301.03,"direct_dps":421.51,"ehp":216.39000000000001,"hit_model":{"five_hits":2.323809523809524,"solo_hits":1.0},"interval":0.18,"solo_dps":320.6}
upgrade_10_noult guitarist/electric_guitar {"aoe_dps":13554.77,"direct_dps":4422.29,"ehp":703.53,"hit_model":{"five_hits":2.323809523809524,"solo_hits":1.0},"interval":0.18,"solo_dps":3352.09}
tuning guitarist/electric_guitar {"aoe_budget_multiplier":1.319,"aoe_target":292.5,"base_aoe_dps":80.45,"base_solo_dps":34.47,"damage_multiplier":2.7560000000000002,"solo_budget_multiplier":0.758,"solo_target":72.0}
crowd_0 guitarist/electric_guitar {"cct":0.26,"cct_dev":-0.047,"crowd_dps":307.08,"enemy_hp":80.0,"target_cct":0.27,"target_count":1,"target_dps":292.5}
crowd_5 guitarist/electric_guitar {"cct":1.3,"cct_dev":-0.047,"crowd_dps":307.08,"enemy_hp":80.0,"target_cct":1.37,"target_count":5,"target_dps":292.5}
crowd_10 guitarist/electric_guitar {"cct":2.71,"cct_dev":-0.008,"crowd_dps":294.8,"enemy_hp":80.0,"target_cct":2.74,"target_count":10,"target_dps":292.5}
crowd_20 guitarist/electric_guitar {"cct":5.7700000000000005,"cct_dev":0.098,"crowd_dps":277.11,"enemy_hp":80.0,"target_cct":5.26,"target_count":20,"target_dps":304.2}
crowd_extreme_20 guitarist/electric_guitar {"cct":0.01,"cct_dev":-0.998,"crowd_dps":173180.13,"enemy_hp":80.0,"target_cct":5.26,"target_count":20,"target_dps":304.2}
raw_untuned guitarist/bass_guitar {"aoe_dps":44.78,"direct_dps":8.9,"ehp":67.03,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.331,"solo_dps":8.96}
tuned_base guitarist/bass_guitar {"aoe_dps":292.54,"direct_dps":24.93,"ehp":67.03,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.331,"solo_dps":72.0}
tuned_zero guitarist/bass_guitar {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":7.8,"solo_dps":0.0}
tuned_mid guitarist/bass_guitar {"aoe_dps":3147.48,"direct_dps":268.76,"ehp":414.07,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.18,"solo_dps":774.5600000000001}
tuned_extreme guitarist/bass_guitar {"aoe_dps":269569.64,"direct_dps":22943.010000000002,"ehp":21423.08,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.18,"solo_dps":66349.87}
upgrade_3 guitarist/bass_guitar {"aoe_dps":1857.42,"direct_dps":158.52,"ehp":216.39000000000001,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.247,"solo_dps":457.1}
upgrade_10_noult guitarist/bass_guitar {"aoe_dps":22191.06,"direct_dps":1902.3600000000001,"ehp":703.53,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.195,"solo_dps":5459.78}
tuning guitarist/bass_guitar {"aoe_budget_multiplier":2.333,"aoe_target":292.5,"base_aoe_dps":44.78,"base_solo_dps":8.96,"damage_multiplier":2.8000000000000003,"solo_budget_multiplier":2.87,"solo_target":72.0}
crowd_0 guitarist/bass_guitar {"cct":0.26,"cct_dev":-0.048,"crowd_dps":307.17,"enemy_hp":80.0,"target_cct":0.27,"target_count":1,"target_dps":292.5}
crowd_5 guitarist/bass_guitar {"cct":1.3,"cct_dev":-0.048,"crowd_dps":307.17,"enemy_hp":80.0,"target_cct":1.37,"target_count":5,"target_dps":292.5}
crowd_10 guitarist/bass_guitar {"cct":2.71,"cct_dev":-0.008,"crowd_dps":294.88,"enemy_hp":80.0,"target_cct":2.74,"target_count":10,"target_dps":292.5}
crowd_20 guitarist/bass_guitar {"cct":5.7700000000000005,"cct_dev":0.097,"crowd_dps":277.19,"enemy_hp":80.0,"target_cct":5.26,"target_count":20,"target_dps":304.2}
crowd_extreme_20 guitarist/bass_guitar {"cct":0.01,"cct_dev":-0.999,"crowd_dps":255422.63,"enemy_hp":80.0,"target_cct":5.26,"target_count":20,"target_dps":304.2}
raw_untuned guitarist/sound_amp {"aoe_dps":82.32000000000001,"direct_dps":9.73,"ehp":67.03,"hit_model":{"five_hits":3.2812500000000004,"solo_hits":1.0},"interval":1.12,"solo_dps":59.32}
tuned_base guitarist/sound_amp {"aoe_dps":292.55,"direct_dps":20.21,"ehp":67.03,"hit_model":{"five_hits":3.2812500000000004,"solo_hits":1.0},"interval":1.12,"solo_dps":71.96000000000001}
tuned_zero guitarist/sound_amp {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.2812500000000004,"solo_hits":1.0},"interval":24.0,"solo_dps":0.0}
tuned_mid guitarist/sound_amp {"aoe_dps":6819.47,"direct_dps":399.34000000000003,"ehp":414.07,"hit_model":{"five_hits":3.2812500000000004,"solo_hits":1.0},"interval":0.332,"solo_dps":1788.8600000000001}
tuned_extreme guitarist/sound_amp {"aoe_dps":1787467.6500000001,"direct_dps":62969.54,"ehp":21423.08,"hit_model":{"five_hits":3.2812500000000004,"solo_hits":1.0},"interval":0.18,"solo_dps":525157.52}
upgrade_3 guitarist/sound_amp {"aoe_dps":1049.76,"direct_dps":95.8,"ehp":216.39000000000001,"hit_model":{"five_hits":3.2812500000000004,"solo_hits":1.0},"interval":0.837,"solo_dps":227.33}
upgrade_10_noult guitarist/sound_amp {"aoe_dps":10065.73,"direct_dps":1285.69,"ehp":703.53,"hit_model":{"five_hits":3.2812500000000004,"solo_hits":1.0},"interval":0.659,"solo_dps":1722.78}
tuning guitarist/sound_amp {"aoe_budget_multiplier":1.711,"aoe_target":292.5,"base_aoe_dps":82.32000000000001,"base_solo_dps":59.32,"damage_multiplier":2.077,"solo_budget_multiplier":0.584,"solo_target":72.0}
crowd_0 guitarist/sound_amp {"cct":0.28,"cct_dev":0.041,"crowd_dps":280.85,"enemy_hp":80.0,"target_cct":0.27,"target_count":1,"target_dps":292.5}
crowd_5 guitarist/sound_amp {"cct":1.42,"cct_dev":0.041,"crowd_dps":280.85,"enemy_hp":80.0,"target_cct":1.37,"target_count":5,"target_dps":292.5}
crowd_10 guitarist/sound_amp {"cct":2.97,"cct_dev":0.085,"crowd_dps":269.61,"enemy_hp":80.0,"target_cct":2.74,"target_count":10,"target_dps":292.5}
crowd_20 guitarist/sound_amp {"cct":6.3100000000000005,"cct_dev":0.2,"crowd_dps":253.44,"enemy_hp":80.0,"target_cct":5.26,"target_count":20,"target_dps":304.2}
crowd_extreme_20 guitarist/sound_amp {"cct":0.0,"cct_dev":-1.0,"crowd_dps":1548490.3800000001,"enemy_hp":80.0,"target_cct":5.26,"target_count":20,"target_dps":304.2}
raw_untuned assassin/chakrams {"aoe_dps":74.11,"direct_dps":22.72,"ehp":85.79,"hit_model":{"five_hits":3.2470588235294118,"solo_hits":1.6},"interval":0.202,"solo_dps":36.42}
tuned_base assassin/chakrams {"aoe_dps":120.72,"direct_dps":40.72,"ehp":85.79,"hit_model":{"five_hits":3.2470588235294118,"solo_hits":1.6},"interval":0.202,"solo_dps":71.79}
tuned_zero assassin/chakrams {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.2470588235294118,"solo_hits":1.6},"interval":6.2,"solo_dps":0.0}
tuned_mid assassin/chakrams {"aoe_dps":1387.55,"direct_dps":468.15000000000003,"ehp":586.42,"hit_model":{"five_hits":3.2470588235294118,"solo_hits":1.6},"interval":0.18,"solo_dps":825.34}
tuned_extreme assassin/chakrams {"aoe_dps":158266.11000000002,"direct_dps":53181.94,"ehp":31384.940000000002,"hit_model":{"five_hits":3.2470588235294118,"solo_hits":1.6},"interval":0.18,"solo_dps":93913.77}
upgrade_3 assassin/chakrams {"aoe_dps":575.02,"direct_dps":194.04,"ehp":239.76,"hit_model":{"five_hits":3.2470588235294118,"solo_hits":1.6},"interval":0.18,"solo_dps":342.06}
upgrade_10_noult assassin/chakrams {"aoe_dps":3430.0,"direct_dps":1162.09,"ehp":731.7,"hit_model":{"five_hits":3.2470588235294118,"solo_hits":1.6},"interval":0.18,"solo_dps":2045.28}
tuning assassin/chakrams {"aoe_budget_multiplier":0.909,"aoe_target":120.75,"base_aoe_dps":74.11,"base_solo_dps":36.42,"damage_multiplier":1.792,"solo_budget_multiplier":1.1,"solo_target":71.76}
crowd_0 assassin/chakrams {"cct":0.68,"cct_dev":0.021,"crowd_dps":118.31,"enemy_hp":80.0,"target_cct":0.66,"target_count":1,"target_dps":120.75}
crowd_5 assassin/chakrams {"cct":3.38,"cct_dev":0.021,"crowd_dps":118.31,"enemy_hp":80.0,"target_cct":3.31,"target_count":5,"target_dps":120.75}
crowd_10 assassin/chakrams {"cct":7.04,"cct_dev":0.063,"crowd_dps":113.57000000000001,"enemy_hp":80.0,"target_cct":6.63,"target_count":10,"target_dps":120.75}
crowd_20 assassin/chakrams {"cct":14.99,"cct_dev":0.131,"crowd_dps":106.76,"enemy_hp":80.0,"target_cct":13.25,"target_count":20,"target_dps":120.75}
crowd_extreme_20 assassin/chakrams {"cct":0.01,"cct_dev":-0.999,"crowd_dps":139962.95,"enemy_hp":80.0,"target_cct":13.25,"target_count":20,"target_dps":120.75}
raw_untuned assassin/shadow_daggers {"aoe_dps":110.0,"direct_dps":31.36,"ehp":85.79,"hit_model":{"dot_targets":3.0,"five_hits":3.0,"solo_hits":1.0},"interval":0.18,"solo_dps":36.61}
tuned_base assassin/shadow_daggers {"aoe_dps":120.7,"direct_dps":46.01,"ehp":85.79,"hit_model":{"dot_targets":3.0,"five_hits":3.0,"solo_hits":1.0},"interval":0.18,"solo_dps":71.76}
tuned_zero assassin/shadow_daggers {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":3.0,"five_hits":3.0,"solo_hits":1.0},"interval":3.8000000000000003,"solo_dps":0.0}
tuned_mid assassin/shadow_daggers {"aoe_dps":1254.43,"direct_dps":478.11,"ehp":586.42,"hit_model":{"dot_targets":3.0,"five_hits":3.0,"solo_hits":1.0},"interval":0.18,"solo_dps":745.73}
tuned_extreme assassin/shadow_daggers {"aoe_dps":137624.84,"direct_dps":52248.68,"ehp":31384.940000000002,"hit_model":{"dot_targets":3.0,"five_hits":3.0,"solo_hits":1.0},"interval":0.18,"solo_dps":81687.66}
upgrade_3 assassin/shadow_daggers {"aoe_dps":521.07,"direct_dps":198.62,"ehp":239.76,"hit_model":{"dot_targets":3.0,"five_hits":3.0,"solo_hits":1.0},"interval":0.18,"solo_dps":309.78000000000003}
upgrade_10_noult assassin/shadow_daggers {"aoe_dps":3105.32,"direct_dps":1187.96,"ehp":731.7,"hit_model":{"dot_targets":3.0,"five_hits":3.0,"solo_hits":1.0},"interval":0.18,"solo_dps":1848.8}
tuning assassin/shadow_daggers {"aoe_budget_multiplier":0.748,"aoe_target":120.75,"base_aoe_dps":110.0,"base_solo_dps":36.61,"damage_multiplier":1.467,"solo_budget_multiplier":1.336,"solo_target":71.76}
crowd_0 assassin/shadow_daggers {"cct":0.68,"cct_dev":0.021,"crowd_dps":118.29,"enemy_hp":80.0,"target_cct":0.66,"target_count":1,"target_dps":120.75}
crowd_5 assassin/shadow_daggers {"cct":3.38,"cct_dev":0.021,"crowd_dps":118.29,"enemy_hp":80.0,"target_cct":3.31,"target_count":5,"target_dps":120.75}
crowd_10 assassin/shadow_daggers {"cct":7.05,"cct_dev":0.063,"crowd_dps":113.55,"enemy_hp":80.0,"target_cct":6.63,"target_count":10,"target_dps":120.75}
crowd_20 assassin/shadow_daggers {"cct":14.99,"cct_dev":0.131,"crowd_dps":106.74000000000001,"enemy_hp":80.0,"target_cct":13.25,"target_count":20,"target_dps":120.75}
crowd_extreme_20 assassin/shadow_daggers {"cct":0.01,"cct_dev":-0.999,"crowd_dps":121708.8,"enemy_hp":80.0,"target_cct":13.25,"target_count":20,"target_dps":120.75}
raw_untuned assassin/venom_wire {"aoe_dps":522.97,"direct_dps":26.98,"ehp":85.79,"hit_model":{"dot_targets":4.0,"five_hits":4.0,"solo_hits":1.0},"interval":0.255,"solo_dps":130.72}
tuned_base assassin/venom_wire {"aoe_dps":120.53,"direct_dps":9.61,"ehp":85.79,"hit_model":{"dot_targets":4.0,"five_hits":4.0,"solo_hits":1.0},"interval":0.255,"solo_dps":71.81}
tuned_zero assassin/venom_wire {"aoe_dps":2.18,"direct_dps":0.0,"ehp":2.16,"hit_model":{"dot_targets":4.0,"five_hits":4.0,"solo_hits":1.0},"interval":7.8,"solo_dps":1.3}
tuned_mid assassin/venom_wire {"aoe_dps":625.88,"direct_dps":137.75,"ehp":586.42,"hit_model":{"dot_targets":4.0,"five_hits":4.0,"solo_hits":1.0},"interval":0.18,"solo_dps":372.88}
tuned_extreme assassin/venom_wire {"aoe_dps":24879.0,"direct_dps":15964.44,"ehp":31384.940000000002,"hit_model":{"dot_targets":4.0,"five_hits":4.0,"solo_hits":1.0},"interval":0.18,"solo_dps":14810.95}
upgrade_3 assassin/venom_wire {"aoe_dps":655.2,"direct_dps":120.02,"ehp":239.76,"hit_model":{"dot_targets":4.0,"five_hits":4.0,"solo_hits":1.0},"interval":0.191,"solo_dps":390.36}
upgrade_10_noult assassin/venom_wire {"aoe_dps":4151.08,"direct_dps":818.38,"ehp":731.7,"hit_model":{"dot_targets":4.0,"five_hits":4.0,"solo_hits":1.0},"interval":0.18,"solo_dps":2473.48}
tuning assassin/venom_wire {"aoe_budget_multiplier":0.266,"aoe_target":120.75,"base_aoe_dps":522.97,"base_solo_dps":130.72,"damage_multiplier":0.356,"solo_budget_multiplier":0.634,"solo_target":71.76}
crowd_0 assassin/venom_wire {"cct":0.68,"cct_dev":0.022,"crowd_dps":118.12,"enemy_hp":80.0,"target_cct":0.66,"target_count":1,"target_dps":120.75}
crowd_5 assassin/venom_wire {"cct":3.39,"cct_dev":0.022,"crowd_dps":118.12,"enemy_hp":80.0,"target_cct":3.31,"target_count":5,"target_dps":120.75}
crowd_10 assassin/venom_wire {"cct":7.0600000000000005,"cct_dev":0.065,"crowd_dps":113.39,"enemy_hp":80.0,"target_cct":6.63,"target_count":10,"target_dps":120.75}
crowd_20 assassin/venom_wire {"cct":15.01,"cct_dev":0.133,"crowd_dps":106.59,"enemy_hp":80.0,"target_cct":13.25,"target_count":20,"target_dps":120.75}
crowd_extreme_20 assassin/venom_wire {"cct":0.07,"cct_dev":-0.995,"crowd_dps":22001.79,"enemy_hp":80.0,"target_cct":13.25,"target_count":20,"target_dps":120.75}
raw_untuned ranger/moon_crossbow {"aoe_dps":146.97,"direct_dps":29.18,"ehp":67.11,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.401,"solo_dps":29.39}
tuned_base ranger/moon_crossbow {"aoe_dps":144.92000000000002,"direct_dps":49.61,"ehp":67.11,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.401,"solo_dps":86.15}
tuned_zero ranger/moon_crossbow {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":9.5,"solo_dps":0.0}
tuned_mid ranger/moon_crossbow {"aoe_dps":1457.16,"direct_dps":500.42,"ehp":559.32,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.18,"solo_dps":866.26}
tuned_extreme ranger/moon_crossbow {"aoe_dps":133596.08000000002,"direct_dps":45669.520000000004,"ehp":30159.33,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.18,"solo_dps":79420.57}
upgrade_3 ranger/moon_crossbow {"aoe_dps":522.47,"direct_dps":179.15,"ehp":213.44,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.3,"solo_dps":310.6}
upgrade_10_noult ranger/moon_crossbow {"aoe_dps":3345.83,"direct_dps":1153.73,"ehp":693.04,"hit_model":{"five_hits":5.0,"solo_hits":1.0},"interval":0.23600000000000002,"solo_dps":1989.04}
tuning ranger/moon_crossbow {"aoe_budget_multiplier":0.58,"aoe_target":144.9,"base_aoe_dps":146.97,"base_solo_dps":29.39,"damage_multiplier":1.7,"solo_budget_multiplier":1.724,"solo_target":86.11}
crowd_0 ranger/moon_crossbow {"cct":0.55,"cct_dev":0.0,"crowd_dps":144.92000000000002,"enemy_hp":80.0,"target_cct":0.55,"target_count":1,"target_dps":144.9}
crowd_5 ranger/moon_crossbow {"cct":2.7600000000000002,"cct_dev":0.0,"crowd_dps":144.92000000000002,"enemy_hp":80.0,"target_cct":2.7600000000000002,"target_count":5,"target_dps":144.9}
crowd_10 ranger/moon_crossbow {"cct":5.75,"cct_dev":0.042,"crowd_dps":139.12,"enemy_hp":80.0,"target_cct":5.5200000000000005,"target_count":10,"target_dps":144.9}
crowd_20 ranger/moon_crossbow {"cct":12.23,"cct_dev":0.108,"crowd_dps":130.78,"enemy_hp":80.0,"target_cct":11.040000000000001,"target_count":20,"target_dps":144.9}
crowd_extreme_20 ranger/moon_crossbow {"cct":0.01,"cct_dev":-0.999,"crowd_dps":120557.1,"enemy_hp":80.0,"target_cct":11.040000000000001,"target_count":20,"target_dps":144.9}
raw_untuned ranger/storm_longbow {"aoe_dps":114.77,"direct_dps":34.17,"ehp":67.11,"hit_model":{"five_hits":3.3138888888888887,"solo_hits":1.0},"interval":0.505,"solo_dps":34.480000000000004}
tuned_base ranger/storm_longbow {"aoe_dps":144.93,"direct_dps":60.68,"ehp":67.11,"hit_model":{"five_hits":3.3138888888888887,"solo_hits":1.0},"interval":0.505,"solo_dps":86.15}
tuned_zero ranger/storm_longbow {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.3138888888888887,"solo_hits":1.0},"interval":11.5,"solo_dps":0.0}
tuned_mid ranger/storm_longbow {"aoe_dps":1829.58,"direct_dps":771.74,"ehp":559.32,"hit_model":{"five_hits":3.3138888888888887,"solo_hits":1.0},"interval":0.18,"solo_dps":1090.28}
tuned_extreme ranger/storm_longbow {"aoe_dps":168129.92,"direct_dps":70430.85,"ehp":30159.33,"hit_model":{"five_hits":3.3138888888888887,"solo_hits":1.0},"interval":0.18,"solo_dps":99960.0}
upgrade_3 ranger/storm_longbow {"aoe_dps":467.23,"direct_dps":196.20000000000002,"ehp":213.44,"hit_model":{"five_hits":3.3138888888888887,"solo_hits":1.0},"interval":0.378,"solo_dps":278.01}
upgrade_10_noult ranger/storm_longbow {"aoe_dps":2903.62,"direct_dps":1232.34,"ehp":693.04,"hit_model":{"five_hits":3.3138888888888887,"solo_hits":1.0},"interval":0.297,"solo_dps":1733.91}
tuning ranger/storm_longbow {"aoe_budget_multiplier":0.711,"aoe_target":144.9,"base_aoe_dps":114.77,"base_solo_dps":34.480000000000004,"damage_multiplier":1.776,"solo_budget_multiplier":1.407,"solo_target":86.11}
crowd_0 ranger/storm_longbow {"cct":0.55,"cct_dev":0.0,"crowd_dps":144.93,"enemy_hp":80.0,"target_cct":0.55,"target_count":1,"target_dps":144.9}
crowd_5 ranger/storm_longbow {"cct":2.7600000000000002,"cct_dev":0.0,"crowd_dps":144.93,"enemy_hp":80.0,"target_cct":2.7600000000000002,"target_count":5,"target_dps":144.9}
crowd_10 ranger/storm_longbow {"cct":5.75,"cct_dev":0.041,"crowd_dps":139.13,"enemy_hp":80.0,"target_cct":5.5200000000000005,"target_count":10,"target_dps":144.9}
crowd_20 ranger/storm_longbow {"cct":12.23,"cct_dev":0.108,"crowd_dps":130.78,"enemy_hp":80.0,"target_cct":11.040000000000001,"target_count":20,"target_dps":144.9}
crowd_extreme_20 ranger/storm_longbow {"cct":0.01,"cct_dev":-0.999,"crowd_dps":151720.44,"enemy_hp":80.0,"target_cct":11.040000000000001,"target_count":20,"target_dps":144.9}
raw_untuned ranger/hunter_trap {"aoe_dps":140.97,"direct_dps":16.32,"ehp":67.11,"hit_model":{"five_hits":2.764705882352941,"solo_hits":1.0},"interval":0.6960000000000001,"solo_dps":111.35000000000001}
tuned_base ranger/hunter_trap {"aoe_dps":144.96,"direct_dps":14.56,"ehp":67.11,"hit_model":{"five_hits":2.764705882352941,"solo_hits":1.0},"interval":0.6960000000000001,"solo_dps":86.12}
tuned_zero ranger/hunter_trap {"aoe_dps":2.58,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.764705882352941,"solo_hits":1.0},"interval":16.5,"solo_dps":1.9100000000000001}
tuned_mid ranger/hunter_trap {"aoe_dps":1901.92,"direct_dps":247.93,"ehp":559.32,"hit_model":{"five_hits":2.764705882352941,"solo_hits":1.0},"interval":0.185,"solo_dps":1055.18}
tuned_extreme ranger/hunter_trap {"aoe_dps":89171.21,"direct_dps":23278.41,"ehp":30159.33,"hit_model":{"five_hits":2.764705882352941,"solo_hits":1.0},"interval":0.18,"solo_dps":32822.65}
upgrade_3 ranger/hunter_trap {"aoe_dps":685.97,"direct_dps":67.61,"ehp":213.44,"hit_model":{"five_hits":2.764705882352941,"solo_hits":1.0},"interval":0.521,"solo_dps":409.93}
upgrade_10_noult ranger/hunter_trap {"aoe_dps":4955.8,"direct_dps":455.90000000000003,"ehp":693.04,"hit_model":{"five_hits":2.764705882352941,"solo_hits":1.0},"interval":0.40900000000000003,"solo_dps":3021.7200000000003}
tuning ranger/hunter_trap {"aoe_budget_multiplier":1.066,"aoe_target":144.9,"base_aoe_dps":140.97,"base_solo_dps":111.35000000000001,"damage_multiplier":0.892,"solo_budget_multiplier":0.786,"solo_target":86.11}
crowd_0 ranger/hunter_trap {"cct":0.53,"cct_dev":-0.048,"crowd_dps":152.21,"enemy_hp":80.0,"target_cct":0.55,"target_count":1,"target_dps":144.9}
crowd_5 ranger/hunter_trap {"cct":2.63,"cct_dev":-0.048,"crowd_dps":152.21,"enemy_hp":80.0,"target_cct":2.7600000000000002,"target_count":5,"target_dps":144.9}
crowd_10 ranger/hunter_trap {"cct":5.47,"cct_dev":-0.008,"crowd_dps":146.12,"enemy_hp":80.0,"target_cct":5.5200000000000005,"target_count":10,"target_dps":144.9}
crowd_20 ranger/hunter_trap {"cct":11.65,"cct_dev":0.097,"crowd_dps":137.35,"enemy_hp":80.0,"target_cct":10.620000000000001,"target_count":20,"target_dps":150.70000000000002}
crowd_extreme_20 ranger/hunter_trap {"cct":0.02,"cct_dev":-0.998,"crowd_dps":84491.5,"enemy_hp":80.0,"target_cct":10.620000000000001,"target_count":20,"target_dps":150.70000000000002}
raw_untuned doctor/restore_potion {"aoe_dps":53.120000000000005,"direct_dps":42.49,"ehp":92.5,"hit_model":{"five_hits":1.203831417624521,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.737,"solo_dps":42.96}
tuned_base doctor/restore_potion {"aoe_dps":127.53,"direct_dps":64.15,"ehp":92.5,"hit_model":{"five_hits":1.203831417624521,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.737,"solo_dps":40.81}
tuned_zero doctor/restore_potion {"aoe_dps":0.0,"direct_dps":0.0,"ehp":6.72,"hit_model":{"five_hits":1.203831417624521,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":11.5,"solo_dps":0.0}
tuned_mid doctor/restore_potion {"aoe_dps":1491.76,"direct_dps":770.8000000000001,"ehp":425.93,"hit_model":{"five_hits":1.203831417624521,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.18,"solo_dps":486.40000000000003}
tuned_extreme doctor/restore_potion {"aoe_dps":119695.3,"direct_dps":61266.04,"ehp":21510.94,"hit_model":{"five_hits":1.203831417624521,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.18,"solo_dps":38768.74}
upgrade_3 doctor/restore_potion {"aoe_dps":529.46,"direct_dps":268.38,"ehp":269.93,"hit_model":{"five_hits":1.203831417624521,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.551,"solo_dps":170.32}
upgrade_10_noult doctor/restore_potion {"aoe_dps":7302.4000000000005,"direct_dps":3815.07,"ehp":832.89,"hit_model":{"five_hits":1.203831417624521,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.433,"solo_dps":2399.68}
tuning doctor/restore_potion {"aoe_budget_multiplier":1.59,"aoe_target":127.5,"base_aoe_dps":53.120000000000005,"base_solo_dps":42.96,"damage_multiplier":1.51,"solo_budget_multiplier":0.629,"solo_target":40.800000000000004}
crowd_0 doctor/restore_potion {"cct":0.6,"cct_dev":-0.039,"crowd_dps":132.63,"enemy_hp":80.0,"target_cct":0.63,"target_count":1,"target_dps":127.5}
crowd_5 doctor/restore_potion {"cct":3.02,"cct_dev":-0.039,"crowd_dps":132.63,"enemy_hp":80.0,"target_cct":3.14,"target_count":5,"target_dps":127.5}
crowd_10 doctor/restore_potion {"cct":6.28,"cct_dev":0.001,"crowd_dps":127.33,"enemy_hp":80.0,"target_cct":6.2700000000000005,"target_count":10,"target_dps":127.5}
crowd_20 doctor/restore_potion {"cct":13.370000000000001,"cct_dev":0.065,"crowd_dps":119.69,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
crowd_extreme_20 doctor/restore_potion {"cct":0.01,"cct_dev":-0.999,"crowd_dps":112333.56,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
raw_untuned doctor/plague_syringe {"aoe_dps":57.38,"direct_dps":32.17,"ehp":86.38,"hit_model":{"dot_targets":3.2,"five_hits":1.0,"solo_hits":1.0},"interval":0.865,"solo_dps":39.92}
tuned_base doctor/plague_syringe {"aoe_dps":127.47,"direct_dps":48.480000000000004,"ehp":86.38,"hit_model":{"dot_targets":3.2,"five_hits":1.0,"solo_hits":1.0},"interval":0.865,"solo_dps":40.800000000000004}
tuned_zero doctor/plague_syringe {"aoe_dps":0.61,"direct_dps":0.0,"ehp":5.04,"hit_model":{"dot_targets":3.2,"five_hits":1.0,"solo_hits":1.0},"interval":13.5,"solo_dps":0.08}
tuned_mid doctor/plague_syringe {"aoe_dps":1331.43,"direct_dps":611.33,"ehp":402.28000000000003,"hit_model":{"dot_targets":3.2,"five_hits":1.0,"solo_hits":1.0},"interval":0.201,"solo_dps":477.52}
tuned_extreme doctor/plague_syringe {"aoe_dps":93749.05,"direct_dps":54350.51,"ehp":20352.98,"hit_model":{"dot_targets":3.2,"five_hits":1.0,"solo_hits":1.0},"interval":0.18,"solo_dps":39021.36}
upgrade_3 doctor/plague_syringe {"aoe_dps":513.97,"direct_dps":205.47,"ehp":256.63,"hit_model":{"dot_targets":3.2,"five_hits":1.0,"solo_hits":1.0},"interval":0.647,"solo_dps":169.41}
upgrade_10_noult doctor/plague_syringe {"aoe_dps":5882.72,"direct_dps":2904.12,"ehp":794.7,"hit_model":{"dot_targets":3.2,"five_hits":1.0,"solo_hits":1.0},"interval":0.509,"solo_dps":2209.42}
tuning doctor/plague_syringe {"aoe_budget_multiplier":1.579,"aoe_target":127.5,"base_aoe_dps":57.38,"base_solo_dps":39.92,"damage_multiplier":1.5070000000000001,"solo_budget_multiplier":0.6990000000000001,"solo_target":40.800000000000004}
crowd_0 doctor/plague_syringe {"cct":0.63,"cct_dev":0.0,"crowd_dps":127.47,"enemy_hp":80.0,"target_cct":0.63,"target_count":1,"target_dps":127.5}
crowd_5 doctor/plague_syringe {"cct":3.14,"cct_dev":0.0,"crowd_dps":127.47,"enemy_hp":80.0,"target_cct":3.14,"target_count":5,"target_dps":127.5}
crowd_10 doctor/plague_syringe {"cct":6.54,"cct_dev":0.042,"crowd_dps":122.37,"enemy_hp":80.0,"target_cct":6.2700000000000005,"target_count":10,"target_dps":127.5}
crowd_20 doctor/plague_syringe {"cct":13.91,"cct_dev":0.108,"crowd_dps":115.03,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
crowd_extreme_20 doctor/plague_syringe {"cct":0.02,"cct_dev":-0.998,"crowd_dps":84599.14,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
raw_untuned doctor/bone_saw {"aoe_dps":113.39,"direct_dps":35.96,"ehp":93.78,"hit_model":{"five_hits":2.8605769230769234,"solo_hits":1.0},"interval":0.397,"solo_dps":39.28}
tuned_base doctor/bone_saw {"aoe_dps":127.48,"direct_dps":38.87,"ehp":93.78,"hit_model":{"five_hits":2.8605769230769234,"solo_hits":1.0},"interval":0.397,"solo_dps":40.800000000000004}
tuned_zero doctor/bone_saw {"aoe_dps":0.0,"direct_dps":0.0,"ehp":14.280000000000001,"hit_model":{"five_hits":2.8605769230769234,"solo_hits":1.0},"interval":6.2,"solo_dps":0.0}
tuned_mid doctor/bone_saw {"aoe_dps":2928.36,"direct_dps":916.16,"ehp":400.51,"hit_model":{"five_hits":2.8605769230769234,"solo_hits":1.0},"interval":0.18,"solo_dps":944.64}
tuned_extreme doctor/bone_saw {"aoe_dps":255396.24000000002,"direct_dps":79652.95,"ehp":19598.33,"hit_model":{"five_hits":2.8605769230769234,"solo_hits":1.0},"interval":0.18,"solo_dps":82307.18000000001}
upgrade_3 doctor/bone_saw {"aoe_dps":482.32,"direct_dps":147.70000000000002,"ehp":259.91,"hit_model":{"five_hits":2.8605769230769234,"solo_hits":1.0},"interval":0.297,"solo_dps":154.58}
upgrade_10_noult doctor/bone_saw {"aoe_dps":3123.08,"direct_dps":981.47,"ehp":782.12,"hit_model":{"five_hits":2.8605769230769234,"solo_hits":1.0},"interval":0.234,"solo_dps":1008.83}
tuning doctor/bone_saw {"aoe_budget_multiplier":1.04,"aoe_target":127.5,"base_aoe_dps":113.39,"base_solo_dps":39.28,"damage_multiplier":1.081,"solo_budget_multiplier":0.961,"solo_target":40.800000000000004}
crowd_0 doctor/bone_saw {"cct":0.64,"cct_dev":0.021,"crowd_dps":124.93,"enemy_hp":80.0,"target_cct":0.63,"target_count":1,"target_dps":127.5}
crowd_5 doctor/bone_saw {"cct":3.2,"cct_dev":0.021,"crowd_dps":124.93,"enemy_hp":80.0,"target_cct":3.14,"target_count":5,"target_dps":127.5}
crowd_10 doctor/bone_saw {"cct":6.67,"cct_dev":0.063,"crowd_dps":119.93,"enemy_hp":80.0,"target_cct":6.2700000000000005,"target_count":10,"target_dps":127.5}
crowd_20 doctor/bone_saw {"cct":14.19,"cct_dev":0.131,"crowd_dps":112.74000000000001,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
crowd_extreme_20 doctor/bone_saw {"cct":0.01,"cct_dev":-0.999,"crowd_dps":225860.18,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
raw_untuned chemist/blast_powder {"aoe_dps":87.7,"direct_dps":21.03,"ehp":50.74,"hit_model":{"five_hits":4.017241379310345,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.384,"solo_dps":21.72}
tuned_base chemist/blast_powder {"aoe_dps":155.9,"direct_dps":34.17,"ehp":50.74,"hit_model":{"five_hits":4.017241379310345,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.384,"solo_dps":32.26}
tuned_zero chemist/blast_powder {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":4.017241379310345,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":6.2,"solo_dps":0.0}
tuned_mid chemist/blast_powder {"aoe_dps":3882.7200000000003,"direct_dps":879.07,"ehp":424.61,"hit_model":{"five_hits":4.017241379310345,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.18,"solo_dps":806.94}
tuned_extreme chemist/blast_powder {"aoe_dps":345745.68,"direct_dps":77953.07,"ehp":22442.95,"hit_model":{"five_hits":4.017241379310345,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.18,"solo_dps":71815.29000000001}
upgrade_3 chemist/blast_powder {"aoe_dps":624.33,"direct_dps":137.81,"ehp":199.46,"hit_model":{"five_hits":4.017241379310345,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.28700000000000003,"solo_dps":129.31}
upgrade_10_noult chemist/blast_powder {"aoe_dps":4069.69,"direct_dps":926.01,"ehp":690.26,"hit_model":{"five_hits":4.017241379310345,"pool_targets":2.1538461538461537,"solo_hits":1.0},"interval":0.226,"solo_dps":846.37}
tuning chemist/blast_powder {"aoe_budget_multiplier":1.094,"aoe_target":156.0,"base_aoe_dps":87.7,"base_solo_dps":21.72,"damage_multiplier":1.625,"solo_budget_multiplier":0.914,"solo_target":32.26}
crowd_0 chemist/blast_powder {"cct":0.49,"cct_dev":-0.038,"crowd_dps":162.14000000000001,"enemy_hp":80.0,"target_cct":0.51,"target_count":1,"target_dps":156.0}
crowd_5 chemist/blast_powder {"cct":2.47,"cct_dev":-0.038,"crowd_dps":162.14000000000001,"enemy_hp":80.0,"target_cct":2.56,"target_count":5,"target_dps":156.0}
crowd_10 chemist/blast_powder {"cct":5.14,"cct_dev":0.002,"crowd_dps":155.65,"enemy_hp":80.0,"target_cct":5.13,"target_count":10,"target_dps":156.0}
crowd_20 chemist/blast_powder {"cct":10.94,"cct_dev":0.066,"crowd_dps":146.31,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
crowd_extreme_20 chemist/blast_powder {"cct":0.0,"cct_dev":-1.0,"crowd_dps":324480.94,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
raw_untuned chemist/acid_flask {"aoe_dps":78.4,"direct_dps":4.04,"ehp":50.74,"hit_model":{"five_hits":2.4482758620689653,"pool_targets":2.6153846153846154,"solo_hits":1.0},"interval":0.774,"solo_dps":30.19}
tuned_base chemist/acid_flask {"aoe_dps":156.01,"direct_dps":5.9,"ehp":50.74,"hit_model":{"five_hits":2.4482758620689653,"pool_targets":2.6153846153846154,"solo_hits":1.0},"interval":0.774,"solo_dps":32.26}
tuned_zero chemist/acid_flask {"aoe_dps":44.36,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.4482758620689653,"pool_targets":2.6153846153846154,"solo_hits":1.0},"interval":12.5,"solo_dps":9.09}
tuned_mid chemist/acid_flask {"aoe_dps":604.11,"direct_dps":73.2,"ehp":424.61,"hit_model":{"five_hits":2.4482758620689653,"pool_targets":2.6153846153846154,"solo_hits":1.0},"interval":0.18,"solo_dps":128.19}
tuned_extreme chemist/acid_flask {"aoe_dps":32135.65,"direct_dps":6049.53,"ehp":22442.95,"hit_model":{"five_hits":2.4482758620689653,"pool_targets":2.6153846153846154,"solo_hits":1.0},"interval":0.18,"solo_dps":6930.6}
upgrade_3 chemist/acid_flask {"aoe_dps":625.74,"direct_dps":48.44,"ehp":199.46,"hit_model":{"five_hits":2.4482758620689653,"pool_targets":2.6153846153846154,"solo_hits":1.0},"interval":0.579,"solo_dps":130.8}
upgrade_10_noult chemist/acid_flask {"aoe_dps":4667.99,"direct_dps":539.14,"ehp":690.26,"hit_model":{"five_hits":2.4482758620689653,"pool_targets":2.6153846153846154,"solo_hits":1.0},"interval":0.455,"solo_dps":990.74}
tuning chemist/acid_flask {"aoe_budget_multiplier":1.8780000000000001,"aoe_target":156.0,"base_aoe_dps":78.4,"base_solo_dps":30.19,"damage_multiplier":1.458,"solo_budget_multiplier":1.006,"solo_target":32.26}
crowd_0 chemist/acid_flask {"cct":0.49,"cct_dev":-0.039,"crowd_dps":162.25,"enemy_hp":80.0,"target_cct":0.51,"target_count":1,"target_dps":156.0}
crowd_5 chemist/acid_flask {"cct":2.47,"cct_dev":-0.039,"crowd_dps":162.25,"enemy_hp":80.0,"target_cct":2.56,"target_count":5,"target_dps":156.0}
crowd_10 chemist/acid_flask {"cct":5.14,"cct_dev":0.002,"crowd_dps":155.76,"enemy_hp":80.0,"target_cct":5.13,"target_count":10,"target_dps":156.0}
crowd_20 chemist/acid_flask {"cct":10.93,"cct_dev":0.065,"crowd_dps":146.41,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
crowd_extreme_20 chemist/acid_flask {"cct":0.05,"cct_dev":-0.995,"crowd_dps":30159.18,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
raw_untuned chemist/homunculus_vial {"aoe_dps":785.83,"direct_dps":0.0,"ehp":57.65,"hit_model":{"five_hits":2.6,"solo_hits":1.0,"summon_targets":2.0},"interval":2.477,"solo_dps":388.8}
tuned_base chemist/homunculus_vial {"aoe_dps":155.93,"direct_dps":0.0,"ehp":57.65,"hit_model":{"five_hits":2.6,"solo_hits":1.0,"summon_targets":2.0},"interval":2.477,"solo_dps":32.29}
tuned_zero chemist/homunculus_vial {"aoe_dps":7.82,"direct_dps":0.0,"ehp":8.52,"hit_model":{"five_hits":2.6,"solo_hits":1.0,"summon_targets":2.0},"interval":40.0,"solo_dps":1.18}
tuned_mid chemist/homunculus_vial {"aoe_dps":2791.12,"direct_dps":0.0,"ehp":434.05,"hit_model":{"five_hits":2.6,"solo_hits":1.0,"summon_targets":2.0},"interval":0.548,"solo_dps":595.2}
tuned_extreme chemist/homunculus_vial {"aoe_dps":771746.26,"direct_dps":0.0,"ehp":22469.91,"hit_model":{"five_hits":2.6,"solo_hits":1.0,"summon_targets":2.0},"interval":0.18,"solo_dps":165159.75}
upgrade_3 chemist/homunculus_vial {"aoe_dps":1031.58,"direct_dps":0.0,"ehp":209.27,"hit_model":{"five_hits":2.6,"solo_hits":1.0,"summon_targets":2.0},"interval":1.853,"solo_dps":216.71}
upgrade_10_noult chemist/homunculus_vial {"aoe_dps":8038.29,"direct_dps":0.0,"ehp":705.2,"hit_model":{"five_hits":2.6,"solo_hits":1.0,"summon_targets":2.0},"interval":1.457,"solo_dps":1689.76}
tuning chemist/homunculus_vial {"aoe_budget_multiplier":0.654,"aoe_target":156.0,"base_aoe_dps":785.83,"base_solo_dps":388.8,"damage_multiplier":0.28,"solo_budget_multiplier":0.28,"solo_target":32.26}
crowd_0 chemist/homunculus_vial {"cct":0.53,"cct_dev":0.042,"crowd_dps":149.69,"enemy_hp":80.0,"target_cct":0.51,"target_count":1,"target_dps":156.0}
crowd_5 chemist/homunculus_vial {"cct":2.67,"cct_dev":0.042,"crowd_dps":149.69,"enemy_hp":80.0,"target_cct":2.56,"target_count":5,"target_dps":156.0}
crowd_10 chemist/homunculus_vial {"cct":5.57,"cct_dev":0.08600000000000001,"crowd_dps":143.71,"enemy_hp":80.0,"target_cct":5.13,"target_count":10,"target_dps":156.0}
crowd_20 chemist/homunculus_vial {"cct":11.84,"cct_dev":0.201,"crowd_dps":135.08,"enemy_hp":80.0,"target_cct":9.86,"target_count":20,"target_dps":162.24}
crowd_extreme_20 chemist/homunculus_vial {"cct":0.0,"cct_dev":-1.0,"crowd_dps":668566.87,"enemy_hp":80.0,"target_cct":9.86,"target_count":20,"target_dps":162.24}
raw_untuned knight/long_spear {"aoe_dps":104.42,"direct_dps":43.38,"ehp":173.81,"hit_model":{"five_hits":2.2599775851583828,"solo_hits":1.0},"interval":0.853,"solo_dps":46.03}
tuned_base knight/long_spear {"aoe_dps":127.45,"direct_dps":46.24,"ehp":173.81,"hit_model":{"five_hits":2.2599775851583828,"solo_hits":1.0},"interval":0.853,"solo_dps":42.83}
tuned_zero knight/long_spear {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.2599775851583828,"solo_hits":1.0},"interval":10.0,"solo_dps":0.0}
tuned_mid knight/long_spear {"aoe_dps":1761.29,"direct_dps":645.0,"ehp":436.37,"hit_model":{"five_hits":2.2599775851583828,"solo_hits":1.0},"interval":0.18,"solo_dps":593.61}
tuned_extreme knight/long_spear {"aoe_dps":140908.79,"direct_dps":51476.0,"ehp":19827.97,"hit_model":{"five_hits":2.2599775851583828,"solo_hits":1.0},"interval":0.18,"solo_dps":47455.31}
upgrade_3 knight/long_spear {"aoe_dps":377.41,"direct_dps":137.25,"ehp":358.83,"hit_model":{"five_hits":2.2599775851583828,"solo_hits":1.0},"interval":0.638,"solo_dps":126.93}
upgrade_10_noult knight/long_spear {"aoe_dps":2364.2200000000003,"direct_dps":868.62,"ehp":904.3000000000001,"hit_model":{"five_hits":2.2599775851583828,"solo_hits":1.0},"interval":0.502,"solo_dps":797.61}
tuning knight/long_spear {"aoe_budget_multiplier":1.145,"aoe_target":127.5,"base_aoe_dps":104.42,"base_solo_dps":46.03,"damage_multiplier":1.066,"solo_budget_multiplier":0.873,"solo_target":42.84}
crowd_0 knight/long_spear {"cct":0.64,"cct_dev":0.021,"crowd_dps":124.9,"enemy_hp":80.0,"target_cct":0.63,"target_count":1,"target_dps":127.5}
crowd_5 knight/long_spear {"cct":3.2,"cct_dev":0.021,"crowd_dps":124.9,"enemy_hp":80.0,"target_cct":3.14,"target_count":5,"target_dps":127.5}
crowd_10 knight/long_spear {"cct":6.67,"cct_dev":0.063,"crowd_dps":119.9,"enemy_hp":80.0,"target_cct":6.2700000000000005,"target_count":10,"target_dps":127.5}
crowd_20 knight/long_spear {"cct":14.200000000000001,"cct_dev":0.131,"crowd_dps":112.71000000000001,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
crowd_extreme_20 knight/long_spear {"cct":0.01,"cct_dev":-0.999,"crowd_dps":124612.97,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
raw_untuned knight/tower_shield {"aoe_dps":32.44,"direct_dps":12.700000000000001,"ehp":189.8,"hit_model":{"five_hits":2.4184027777777777,"solo_hits":1.0},"interval":0.7000000000000001,"solo_dps":13.38}
tuned_base knight/tower_shield {"aoe_dps":127.53,"direct_dps":35.550000000000004,"ehp":189.8,"hit_model":{"five_hits":2.4184027777777777,"solo_hits":1.0},"interval":0.7000000000000001,"solo_dps":42.82}
tuned_zero knight/tower_shield {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.4184027777777777,"solo_hits":1.0},"interval":8.2,"solo_dps":0.0}
tuned_mid knight/tower_shield {"aoe_dps":1449.08,"direct_dps":406.61,"ehp":474.93,"hit_model":{"five_hits":2.4184027777777777,"solo_hits":1.0},"interval":0.18,"solo_dps":487.42}
tuned_extreme knight/tower_shield {"aoe_dps":115913.68000000001,"direct_dps":32450.16,"ehp":21389.33,"hit_model":{"five_hits":2.4184027777777777,"solo_hits":1.0},"interval":0.18,"solo_dps":38966.0}
upgrade_3 knight/tower_shield {"aoe_dps":415.81,"direct_dps":116.11,"ehp":387.85,"hit_model":{"five_hits":2.4184027777777777,"solo_hits":1.0},"interval":0.523,"solo_dps":139.69}
upgrade_10_noult knight/tower_shield {"aoe_dps":2672.59,"direct_dps":752.21,"ehp":971.74,"hit_model":{"five_hits":2.4184027777777777,"solo_hits":1.0},"interval":0.41200000000000003,"solo_dps":899.6700000000001}
tuning knight/tower_shield {"aoe_budget_multiplier":1.4040000000000001,"aoe_target":127.5,"base_aoe_dps":32.44,"base_solo_dps":13.38,"damage_multiplier":2.8000000000000003,"solo_budget_multiplier":1.143,"solo_target":42.84}
crowd_0 knight/tower_shield {"cct":0.64,"cct_dev":0.02,"crowd_dps":124.98,"enemy_hp":80.0,"target_cct":0.63,"target_count":1,"target_dps":127.5}
crowd_5 knight/tower_shield {"cct":3.2,"cct_dev":0.02,"crowd_dps":124.98,"enemy_hp":80.0,"target_cct":3.14,"target_count":5,"target_dps":127.5}
crowd_10 knight/tower_shield {"cct":6.67,"cct_dev":0.063,"crowd_dps":119.98,"enemy_hp":80.0,"target_cct":6.2700000000000005,"target_count":10,"target_dps":127.5}
crowd_20 knight/tower_shield {"cct":14.19,"cct_dev":0.131,"crowd_dps":112.78,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
crowd_extreme_20 knight/tower_shield {"cct":0.02,"cct_dev":-0.999,"crowd_dps":102508.49,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
raw_untuned knight/holy_flail {"aoe_dps":49.83,"direct_dps":10.540000000000001,"ehp":168.86,"hit_model":{"five_hits":3.7743055555555554,"solo_hits":1.0},"interval":1.0070000000000001,"solo_dps":10.65}
tuned_base knight/holy_flail {"aoe_dps":127.53,"direct_dps":29.51,"ehp":168.86,"hit_model":{"five_hits":3.7743055555555554,"solo_hits":1.0},"interval":1.0070000000000001,"solo_dps":42.83}
tuned_zero knight/holy_flail {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.7743055555555554,"solo_hits":1.0},"interval":11.8,"solo_dps":0.0}
tuned_mid knight/holy_flail {"aoe_dps":2086.78,"direct_dps":485.67,"ehp":426.97,"hit_model":{"five_hits":3.7743055555555554,"solo_hits":1.0},"interval":0.18,"solo_dps":699.07}
tuned_extreme knight/holy_flail {"aoe_dps":166747.41,"direct_dps":38759.92,"ehp":19810.69,"hit_model":{"five_hits":3.7743055555555554,"solo_hits":1.0},"interval":0.18,"solo_dps":55891.04}
upgrade_3 knight/holy_flail {"aoe_dps":399.24,"direct_dps":92.5,"ehp":352.62,"hit_model":{"five_hits":3.7743055555555554,"solo_hits":1.0},"interval":0.753,"solo_dps":134.01}
upgrade_10_noult knight/holy_flail {"aoe_dps":2545.87,"direct_dps":593.49,"ehp":896.9300000000001,"hit_model":{"five_hits":3.7743055555555554,"solo_hits":1.0},"interval":0.592,"solo_dps":852.25}
tuning knight/holy_flail {"aoe_budget_multiplier":0.914,"aoe_target":127.5,"base_aoe_dps":49.83,"base_solo_dps":10.65,"damage_multiplier":2.8000000000000003,"solo_budget_multiplier":1.436,"solo_target":42.84}
crowd_0 knight/holy_flail {"cct":0.64,"cct_dev":0.02,"crowd_dps":124.98,"enemy_hp":80.0,"target_cct":0.63,"target_count":1,"target_dps":127.5}
crowd_5 knight/holy_flail {"cct":3.2,"cct_dev":0.02,"crowd_dps":124.98,"enemy_hp":80.0,"target_cct":3.14,"target_count":5,"target_dps":127.5}
crowd_10 knight/holy_flail {"cct":6.67,"cct_dev":0.063,"crowd_dps":119.98,"enemy_hp":80.0,"target_cct":6.2700000000000005,"target_count":10,"target_dps":127.5}
crowd_20 knight/holy_flail {"cct":14.19,"cct_dev":0.131,"crowd_dps":112.78,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
crowd_extreme_20 knight/holy_flail {"cct":0.01,"cct_dev":-0.999,"crowd_dps":147463.41,"enemy_hp":80.0,"target_cct":12.55,"target_count":20,"target_dps":127.5}
raw_untuned druid/summon_amulet {"aoe_dps":941.64,"direct_dps":0.0,"ehp":82.54,"hit_model":{"five_hits":3.5,"solo_hits":1.0,"summon_targets":4.0},"interval":1.858,"solo_dps":235.41}
tuned_base druid/summon_amulet {"aoe_dps":150.02,"direct_dps":0.0,"ehp":82.54,"hit_model":{"five_hits":3.5,"solo_hits":1.0,"summon_targets":4.0},"interval":1.858,"solo_dps":47.99}
tuned_zero druid/summon_amulet {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":3.5,"solo_hits":1.0,"summon_targets":4.0},"interval":30.0,"solo_dps":0.0}
tuned_mid druid/summon_amulet {"aoe_dps":2270.9,"direct_dps":0.0,"ehp":400.28000000000003,"hit_model":{"five_hits":3.5,"solo_hits":1.0,"summon_targets":4.0},"interval":0.37,"solo_dps":726.37}
tuned_extreme druid/summon_amulet {"aoe_dps":478353.85000000003,"direct_dps":0.0,"ehp":20287.260000000002,"hit_model":{"five_hits":3.5,"solo_hits":1.0,"summon_targets":4.0},"interval":0.18,"solo_dps":153005.98}
upgrade_3 druid/summon_amulet {"aoe_dps":1624.3400000000001,"direct_dps":0.0,"ehp":237.76,"hit_model":{"five_hits":3.5,"solo_hits":1.0,"summon_targets":4.0},"interval":1.3900000000000001,"solo_dps":519.5600000000001}
upgrade_10_noult druid/summon_amulet {"aoe_dps":6509.84,"direct_dps":0.0,"ehp":735.35,"hit_model":{"five_hits":3.5,"solo_hits":1.0,"summon_targets":4.0},"interval":1.093,"solo_dps":2082.23}
tuning druid/summon_amulet {"aoe_budget_multiplier":0.5690000000000001,"aoe_target":150.0,"base_aoe_dps":941.64,"base_solo_dps":235.41,"damage_multiplier":0.28,"solo_budget_multiplier":0.728,"solo_target":48.0}
crowd_0 druid/summon_amulet {"cct":0.56,"cct_dev":0.042,"crowd_dps":144.02,"enemy_hp":80.0,"target_cct":0.53,"target_count":1,"target_dps":150.0}
crowd_5 druid/summon_amulet {"cct":2.7800000000000002,"cct_dev":0.042,"crowd_dps":144.02,"enemy_hp":80.0,"target_cct":2.67,"target_count":5,"target_dps":150.0}
crowd_10 druid/summon_amulet {"cct":5.79,"cct_dev":0.085,"crowd_dps":138.26,"enemy_hp":80.0,"target_cct":5.33,"target_count":10,"target_dps":150.0}
crowd_20 druid/summon_amulet {"cct":12.31,"cct_dev":0.2,"crowd_dps":129.96,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
crowd_extreme_20 druid/summon_amulet {"cct":0.0,"cct_dev":-1.0,"crowd_dps":414399.85000000003,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
raw_untuned druid/briar_staff {"aoe_dps":44.12,"direct_dps":4.39,"ehp":82.54,"hit_model":{"five_hits":2.310344827586207,"pool_targets":2.4615384615384617,"solo_hits":1.0},"interval":0.743,"solo_dps":18.2}
tuned_base druid/briar_staff {"aoe_dps":149.98,"direct_dps":12.290000000000001,"ehp":82.54,"hit_model":{"five_hits":2.310344827586207,"pool_targets":2.4615384615384617,"solo_hits":1.0},"interval":0.743,"solo_dps":47.99}
tuned_zero druid/briar_staff {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":2.310344827586207,"pool_targets":2.4615384615384617,"solo_hits":1.0},"interval":12.0,"solo_dps":0.0}
tuned_mid druid/briar_staff {"aoe_dps":5494.06,"direct_dps":516.55,"ehp":400.28000000000003,"hit_model":{"five_hits":2.310344827586207,"pool_targets":2.4615384615384617,"solo_hits":1.0},"interval":0.18,"solo_dps":1766.25}
tuned_extreme druid/briar_staff {"aoe_dps":255075.89,"direct_dps":46866.4,"ehp":20287.260000000002,"hit_model":{"five_hits":2.310344827586207,"pool_targets":2.4615384615384617,"solo_hits":1.0},"interval":0.18,"solo_dps":83813.5}
upgrade_3 druid/briar_staff {"aoe_dps":610.28,"direct_dps":57.88,"ehp":237.76,"hit_model":{"five_hits":2.310344827586207,"pool_targets":2.4615384615384617,"solo_hits":1.0},"interval":0.556,"solo_dps":195.78}
upgrade_10_noult druid/briar_staff {"aoe_dps":2824.87,"direct_dps":399.03000000000003,"ehp":735.35,"hit_model":{"five_hits":2.310344827586207,"pool_targets":2.4615384615384617,"solo_hits":1.0},"interval":0.437,"solo_dps":916.52}
tuning druid/briar_staff {"aoe_budget_multiplier":1.214,"aoe_target":150.0,"base_aoe_dps":44.12,"base_solo_dps":18.2,"damage_multiplier":2.8000000000000003,"solo_budget_multiplier":0.9420000000000001,"solo_target":48.0}
crowd_0 druid/briar_staff {"cct":0.51,"cct_dev":-0.038,"crowd_dps":155.98,"enemy_hp":80.0,"target_cct":0.53,"target_count":1,"target_dps":150.0}
crowd_5 druid/briar_staff {"cct":2.56,"cct_dev":-0.038,"crowd_dps":155.98,"enemy_hp":80.0,"target_cct":2.67,"target_count":5,"target_dps":150.0}
crowd_10 druid/briar_staff {"cct":5.34,"cct_dev":0.002,"crowd_dps":149.74,"enemy_hp":80.0,"target_cct":5.33,"target_count":10,"target_dps":150.0}
crowd_20 druid/briar_staff {"cct":11.370000000000001,"cct_dev":0.066,"crowd_dps":140.76,"enemy_hp":80.0,"target_cct":10.67,"target_count":20,"target_dps":150.0}
crowd_extreme_20 druid/briar_staff {"cct":0.01,"cct_dev":-0.999,"crowd_dps":239387.7,"enemy_hp":80.0,"target_cct":10.67,"target_count":20,"target_dps":150.0}
raw_untuned druid/raven_totem {"aoe_dps":88.51,"direct_dps":5.38,"ehp":82.54,"hit_model":{"five_hits":14.562613430127042,"solo_hits":7.157894736842106},"interval":1.455,"solo_dps":43.46}
tuned_base druid/raven_totem {"aoe_dps":150.03,"direct_dps":7.36,"ehp":82.54,"hit_model":{"five_hits":14.562613430127042,"solo_hits":7.157894736842106},"interval":1.455,"solo_dps":47.980000000000004}
tuned_zero druid/raven_totem {"aoe_dps":0.0,"direct_dps":0.0,"ehp":2.16,"hit_model":{"five_hits":14.562613430127042,"solo_hits":7.157894736842106},"interval":23.5,"solo_dps":0.0}
tuned_mid druid/raven_totem {"aoe_dps":3685.37,"direct_dps":173.62,"ehp":400.28000000000003,"hit_model":{"five_hits":14.562613430127042,"solo_hits":7.157894736842106},"interval":0.29,"solo_dps":1179.39}
tuned_extreme druid/raven_totem {"aoe_dps":414361.5,"direct_dps":17645.82,"ehp":20287.260000000002,"hit_model":{"five_hits":14.562613430127042,"solo_hits":7.157894736842106},"interval":0.18,"solo_dps":132583.68}
upgrade_3 druid/raven_totem {"aoe_dps":1146.26,"direct_dps":56.230000000000004,"ehp":237.76,"hit_model":{"five_hits":14.562613430127042,"solo_hits":7.157894736842106},"interval":1.089,"solo_dps":366.65000000000003}
upgrade_10_noult druid/raven_totem {"aoe_dps":13010.04,"direct_dps":639.29,"ehp":735.35,"hit_model":{"five_hits":14.562613430127042,"solo_hits":7.157894736842106},"interval":0.856,"solo_dps":4165.11}
tuning druid/raven_totem {"aoe_budget_multiplier":1.239,"aoe_target":150.0,"base_aoe_dps":88.51,"base_solo_dps":43.46,"damage_multiplier":1.368,"solo_budget_multiplier":0.807,"solo_target":48.0}
crowd_0 druid/raven_totem {"cct":0.56,"cct_dev":0.041,"crowd_dps":144.03,"enemy_hp":80.0,"target_cct":0.53,"target_count":1,"target_dps":150.0}
crowd_5 druid/raven_totem {"cct":2.7800000000000002,"cct_dev":0.041,"crowd_dps":144.03,"enemy_hp":80.0,"target_cct":2.67,"target_count":5,"target_dps":150.0}
crowd_10 druid/raven_totem {"cct":5.79,"cct_dev":0.085,"crowd_dps":138.27,"enemy_hp":80.0,"target_cct":5.33,"target_count":10,"target_dps":150.0}
crowd_20 druid/raven_totem {"cct":12.31,"cct_dev":0.2,"crowd_dps":129.97,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
crowd_extreme_20 druid/raven_totem {"cct":0.0,"cct_dev":-1.0,"crowd_dps":358963.02,"enemy_hp":80.0,"target_cct":10.26,"target_count":20,"target_dps":156.0}
"""
