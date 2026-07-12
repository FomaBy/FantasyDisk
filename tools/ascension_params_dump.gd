extends SceneTree

# FAN-1028/FAN-1029: дамп балансовых параметров для матрицы жизнеспособности
# возвышений (A0/A1/A5). Формульный слой, сцены не инстанцируются.
#
# Запуск:
#   godot --headless --path . --script res://tools/ascension_params_dump.gd
#
# Пишет build/ascension_params.json; потребитель — tools/ascension_viability_report.py,
# который совмещает дамп с живым CSV (tools/character_balance_csv.gd) и сценовыми
# базами боссов (scenes/Boss*.tscn) в build/ascension_viability_report.md.

const ProgressionDataScript = preload("res://scripts/progression_data.gd")
const MainScript = preload("res://scripts/main.gd")

const ASCENSION_POINTS := [0, 1, 5]
const STAGE_MAX := 16


func _init() -> void:
	var data := {
		"generated_by": "tools/ascension_params_dump.gd",
		"classes": {},
		"ascension_difficulty": {},
		"stage_scale": [],
		"enemy_balance": MainScript.ENEMY_BALANCE,
	}

	for level in ASCENSION_POINTS:
		data["ascension_difficulty"][str(level)] = ProgressionDataScript.ascension_difficulty_mods(level)

	for stage in range(STAGE_MAX + 1):
		data["stage_scale"].append(ProgressionDataScript.stage_scale(stage))

	for character_id in ProgressionDataScript.BASE_STATS.keys():
		var stats: Dictionary = ProgressionDataScript.base_stats(character_id)
		var entry := {
			"base_stats": stats,
			"ascension_mods": {},
			"derived_base": _derived_survival_slice(stats, {}),
			"derived_a5": {},
			"weapons": {},
		}
		for level in ASCENSION_POINTS:
			entry["ascension_mods"][str(level)] = ProgressionDataScript.ascension_mods(character_id, level)
		# Возвышенские награды класса кладутся в run_modifiers (main.gd, apply_ascension_bonuses)
		# и проходят те же softcap-ы, что и внутрирановые бонусы.
		entry["derived_a5"] = _derived_survival_slice(stats, ProgressionDataScript.ascension_mods(character_id, 5))

		var weapons: Dictionary = ProgressionDataScript.WEAPONS_BY_CLASS.get(character_id, {})
		for weapon_id in weapons.keys():
			var config: Dictionary = weapons[weapon_id]
			var tuning: Dictionary = ProgressionDataScript.budget_tuning_for(character_id, config)
			var tuned_config := config.duplicate(true)
			tuned_config["budget_damage_multiplier"] = tuning.get("damage_multiplier", 1.0)
			var budget: Dictionary = ProgressionDataScript.estimate_weapon_budget(character_id, tuned_config, true)
			entry["weapons"][weapon_id] = {
				"solo_dps": budget.get("solo_dps", 0.0),
				"aoe_dps": budget.get("aoe_dps", 0.0),
				"ehp": budget.get("ehp", 0.0),
				"interval": budget.get("interval", 0.0),
				"tuning": tuning,
			}
		data["classes"][character_id] = entry

	var dir := DirAccess.open("res://")
	if dir != null and not dir.dir_exists("build"):
		dir.make_dir("build")
	var file := FileAccess.open("res://build/ascension_params.json", FileAccess.WRITE)
	if file == null:
		push_error("cannot open build/ascension_params.json for write")
		quit(1)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Ascension params dump written: build/ascension_params.json (classes=%d)" % data["classes"].size())
	quit(0)


func _derived_survival_slice(stats: Dictionary, run_modifiers: Dictionary) -> Dictionary:
	var derived: Dictionary = ProgressionDataScript.derived_parameters(stats, run_modifiers, {})
	return {
		"max_health": derived.get("health_point", 0.0),
		"defense": derived.get("defense", 0.0),
		"dodge": derived.get("dodge", 0.0),
		"absorb": derived.get("absorb", 0.0),
		"regeneration": derived.get("regeneration", 0.0),
		"damage": derived.get("damage", 0.0),
		"magic_damage": derived.get("magic_damage", 0.0),
		"attack_speed": derived.get("attack_speed", 0.0),
	}
