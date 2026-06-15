extends SceneTree

# Гард публичного API ProgressionData. Помогает рефактору доменного сплита
# (SCRUM-198): поведение-сохраняющий сплит ОБЯЗАН сохранить публичные функции и
# константы фасада. Сам факт, что этот тест ВЫЗЫВАЕТ каждую функцию и ссылается
# на каждую константу, пиннит поверхность на этапе КОМПИЛЯЦИИ — удаление/
# переименование ломает компиляцию теста. Плюс рантайм-санити возвратов.
# Отдельный изолированный файл (только ЧИТАЕТ progression_data.gd).
#
# Запуск: Godot --headless --path . --script res://tests/progression_data_api_surface_test.gd

const PD := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []

	# --- Базовые аксессоры персонажей/оружия ---
	var ids: Array = PD.character_ids()
	_nonempty_array(errors, ids, "character_ids")
	var cid := str(ids[0]) if not ids.is_empty() else "berserk"

	_nonempty_dict(errors, PD.character_config(cid), "character_config")
	var stats: Dictionary = PD.base_stats(cid)
	_nonempty_dict(errors, stats, "base_stats")
	var wids: Array = PD.weapon_ids(cid)
	_nonempty_array(errors, wids, "weapon_ids")
	var wid := str(wids[0]) if not wids.is_empty() else ""
	var weapon_cfg: Dictionary = PD.weapon(cid, wid)
	_nonempty_dict(errors, weapon_cfg, "weapon")
	if not weapon_cfg.has("budget_damage_multiplier"):
		errors.append("weapon() потерял budget_damage_multiplier (регрессия тюнинга)")

	# --- Деривация/бюджет/ульта ---
	var derived: Dictionary = PD.derived_parameters(stats, {}, weapon_cfg)
	for key in ["damage", "health_point", "defense", "dodge"]:
		if not derived.has(key):
			errors.append("derived_parameters потерял ключ '%s'" % key)
	_nonempty_dict(errors, PD.ultimate_config(cid), "ultimate_config")
	_nonempty_dict(errors, PD.class_budget_profile(cid), "class_budget_profile")
	_is_dict(errors, PD.budget_tuning_for(cid, weapon_cfg), "budget_tuning_for")
	_is_dict(errors, PD.estimate_weapon_budget(cid, weapon_cfg), "estimate_weapon_budget")
	_nonempty_dict(errors, PD.class_mechanic_identity(cid), "class_mechanic_identity")
	if str(PD.class_main_attribute(cid)) == "":
		errors.append("class_main_attribute вернул пустое значение")
	if str(PD.weapon_mechanic_identity(cid, wid)) == "":
		errors.append("weapon_mechanic_identity вернул пустое значение")
	if str(PD.weapon_archetype(weapon_cfg)) == "":
		errors.append("weapon_archetype вернул пустое значение")
	if str(PD.attribute_weapon_synergy_description("strength", weapon_cfg)) == "":
		errors.append("attribute_weapon_synergy_description вернул пустое значение")
	_nonempty_dict(errors, PD.attribute_weapon_synergy_map(), "attribute_weapon_synergy_map")

	# --- Прогрессия/экономика/маршрут ---
	_is_array(errors, PD.ascension_levels(cid), "ascension_levels")
	_nonempty_array(errors, PD.ascension_modifiers(), "ascension_modifiers")
	if PD.stage_scale(1) <= 0.0:
		errors.append("stage_scale(1) <= 0")
	if PD.stage_scaled_cost(100, 1) <= 0:
		errors.append("stage_scaled_cost(100,1) <= 0")
	if PD.next_xp_requirement(5) <= 0:
		errors.append("next_xp_requirement(5) <= 0")

	# --- Награды/магазин/артефакты ---
	_nonempty_array(errors, PD.reward_pool(), "reward_pool")
	_nonempty_array(errors, PD.level_up_rewards(), "level_up_rewards")
	_is_array(errors, PD.shop_items(0), "shop_items")
	if not PD.ARTIFACTS.is_empty():
		var aid := str((PD.ARTIFACTS[0] as Dictionary).get("id", ""))
		_nonempty_dict(errors, PD.artifact_definition(aid), "artifact_definition")
	if not PD.DROP_CLASS_MULTIPLIERS.is_empty():
		var dc := str(PD.DROP_CLASS_MULTIPLIERS.keys()[0])
		_is_dict(errors, PD.drop_class_multiplier(dc), "drop_class_multiplier")

	# --- Мини-элитки (контент-аксессоры) ---
	_is_array(errors, PD.mini_elite_kinds(), "mini_elite_kinds")
	_nonempty_dict(errors, PD.enemy_size_profile("mini_elite"), "enemy_size_profile")
	if float(PD.enemy_size_profile("mini_elite").get("scale", 0.0)) >= float(PD.enemy_size_profile("elite").get("scale", 0.0)):
		errors.append("enemy_size_profile должен держать mini_elite < elite")
	_nonempty_dict(errors, PD.enemy_mechanic_catalog(), "enemy_mechanic_catalog")
	_nonempty_dict(errors, PD.elite_attack_config("iron_bastion"), "elite_attack_config")
	_nonempty_dict(errors, PD.unique_encounter_pattern("rift_warden"), "unique_encounter_pattern")
	_nonempty_dict(errors, PD.unique_encounter_patterns(), "unique_encounter_patterns")

	# --- Константы фасада (ссылка пиннит наличие на компиляции) ---
	_nonempty_dict(errors, PD.CHARACTER_CONFIGS, "CHARACTER_CONFIGS")
	_nonempty_dict(errors, PD.BASE_STATS, "BASE_STATS")
	_nonempty_dict(errors, PD.CLASS_BUDGET_PROFILES, "CLASS_BUDGET_PROFILES")
	_nonempty_dict(errors, PD.CLASS_MECHANIC_IDENTITIES, "CLASS_MECHANIC_IDENTITIES")
	_nonempty_dict(errors, PD.ENEMY_SIZE_PROFILES, "ENEMY_SIZE_PROFILES")
	_nonempty_dict(errors, PD.ENEMY_MECHANIC_CATALOG, "ENEMY_MECHANIC_CATALOG")
	_nonempty_dict(errors, PD.ELITE_ATTACK_CONFIGS, "ELITE_ATTACK_CONFIGS")
	_nonempty_dict(errors, PD.UNIQUE_ENCOUNTER_PATTERNS, "UNIQUE_ENCOUNTER_PATTERNS")
	_nonempty_dict(errors, PD.WEAPON_ARCHETYPE_BY_MODE, "WEAPON_ARCHETYPE_BY_MODE")
	_nonempty_dict(errors, PD.ATTRIBUTE_WEAPON_SYNERGY_MAP, "ATTRIBUTE_WEAPON_SYNERGY_MAP")
	_nonempty_dict(errors, PD.WEAPONS_BY_CLASS, "WEAPONS_BY_CLASS")
	_nonempty_array(errors, PD.ARTIFACTS, "ARTIFACTS")
	_nonempty_array(errors, PD.SHOP_ITEMS, "SHOP_ITEMS")
	_nonempty_dict(errors, PD.DROP_CLASS_MULTIPLIERS, "DROP_CLASS_MULTIPLIERS")
	# Числовые балансовые константы существуют и положительны.
	for pair in [["BALANCE_BASE_SOLO_DPS", PD.BALANCE_BASE_SOLO_DPS], ["BALANCE_BASE_AOE_DPS", PD.BALANCE_BASE_AOE_DPS], ["STAGE_SCALE_BASE", PD.STAGE_SCALE_BASE], ["ECONOMY_PRICE_MULTIPLIER", PD.ECONOMY_PRICE_MULTIPLIER]]:
		if float(pair[1]) <= 0.0:
			errors.append("балансовая константа %s <= 0 (%s)" % [pair[0], pair[1]])

	# --- Согласованность: WEAPONS_BY_CLASS покрывает всех персонажей ---
	for character_id in ids:
		if not PD.WEAPONS_BY_CLASS.has(character_id):
			errors.append("WEAPONS_BY_CLASS без записи для персонажа '%s'" % character_id)

	if not errors.is_empty():
		for e in errors:
			push_error("ProgressionData API surface: %s" % e)
		push_error("ProgressionData API surface test: %d ошибок." % errors.size())
		quit(1)
		return
	print("ProgressionData API surface test passed (%d персонажей, фасад-API и константы на месте)." % ids.size())
	quit(0)


func _is_array(errors: Array, v, name: String) -> void:
	if not (v is Array):
		errors.append("%s вернул не Array" % name)


func _nonempty_array(errors: Array, v, name: String) -> void:
	if not (v is Array) or (v as Array).is_empty():
		errors.append("%s вернул пустой/не-Array" % name)


func _is_dict(errors: Array, v, name: String) -> void:
	if not (v is Dictionary):
		errors.append("%s вернул не Dictionary" % name)


func _nonempty_dict(errors: Array, v, name: String) -> void:
	if not (v is Dictionary) or (v as Dictionary).is_empty():
		errors.append("%s вернул пустой/не-Dictionary" % name)
