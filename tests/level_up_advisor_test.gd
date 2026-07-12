extends SceneTree

# SCRUM-871: гейт советника level-up — честность прогноза и бейджей.
# Проверяет: (1) DPS-бейдж достаётся карточке с максимальным приростом расчётного
# DPS, бейдж выживаемости — с максимальным приростом EHP; (2) утилити-награды без
# боевого/защитного прироста бейджей не получают; (3) изоляция типов урона в
# дельтах; (4) семантика preview_reward_state идентична player._apply_reward_mods
# (умножение *_multiplier, сложение остального); (5) формат строк «до -> после».
#
# Запуск: Godot --headless --path . --script res://tests/level_up_advisor_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")
const LevelUpAdvisor := preload("res://scripts/level_up_advisor.gd")

var _failed := false


func _fail(message: String) -> void:
	push_error("[levelup-advisor] FAIL: %s" % message)
	_failed = true


func _reward_by_id(reward_id: String) -> Dictionary:
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		if str(reward.get("id", "")) == reward_id:
			return (reward as Dictionary).duplicate(true)
	_fail("Награда %s не найдена в LEVEL_UP_REWARDS." % reward_id)
	return {}


func _initialize() -> void:
	var character_id := "berserk"
	var stats: Dictionary = ProgressionData.base_stats(character_id)
	var mods: Dictionary = {}
	var weapon_config: Dictionary = ProgressionData.weapon(character_id, "sword")

	# 1) Классический набор: урон против HP против утилити-подбора.
	var damage_up := _reward_by_id("damage_up")
	var hp_up := _reward_by_id("max_hp_up")
	var pickup_up := _reward_by_id("pickup_radius_up")
	var advice := LevelUpAdvisor.recommend([damage_up, hp_up, pickup_up], stats, mods, weapon_config)
	if int(advice["dps_index"]) != 0:
		_fail("Ожидался DPS-бейдж на «+Урон» (индекс 0), получен %d." % int(advice["dps_index"]))
	if int(advice["surv_index"]) != 1:
		_fail("Ожидался бейдж выживаемости на «+Макс. здоровье» (индекс 1), получен %d." % int(advice["surv_index"]))
	var badges: Array = advice["badges"]
	if str(badges[0]) != LevelUpAdvisor.BADGE_DPS or str(badges[1]) != LevelUpAdvisor.BADGE_SURV or str(badges[2]) != LevelUpAdvisor.BADGE_NONE:
		_fail("Ожидались бейджи [dps, surv, нет], получено %s." % str(badges))
	if float(advice["dps_gain"]) < 0.10:
		_fail("Прирост DPS от «+Урон» подозрительно мал: %.4f." % float(advice["dps_gain"]))
	var pickup_forecast: Dictionary = (advice["forecasts"] as Array)[2]
	if absf(float(pickup_forecast["dps_after"]) - float(pickup_forecast["dps_before"])) > 0.0001:
		_fail("«+Радиус подбора» не должен менять DPS-скор.")
	if absf(float(pickup_forecast["surv_after"]) - float(pickup_forecast["surv_before"])) > 0.0001:
		_fail("«+Радиус подбора» не должен менять скор живучести.")

	# 2) Урон-мультипликатор сильнее скорости атаки того же порядка: damage_multiplier
	# растит и удар, и DoT-трек, attack_speed — только удары в секунду.
	var attack_speed_up := _reward_by_id("attack_speed_up")
	var duel := LevelUpAdvisor.recommend([attack_speed_up, damage_up], stats, mods, weapon_config)
	if int(duel["dps_index"]) != 1:
		_fail("В дуэли скорость-vs-урон DPS-бейдж должен взять «+Урон» (+15%% и удару, и DoT).")

	# 3) Защитные награды двигают только ось живучести.
	var defense_up := _reward_by_id("defense_up")
	var regen_up := _reward_by_id("regeneration_up")
	var defensive := LevelUpAdvisor.recommend([defense_up, regen_up, hp_up], stats, mods, weapon_config)
	if int(defensive["dps_index"]) != -1:
		_fail("Защитный набор не должен выдавать DPS-бейдж, получен индекс %d." % int(defensive["dps_index"]))
	if int(defensive["surv_index"]) == -1:
		_fail("Защитный набор обязан выдать бейдж выживаемости.")

	# 4) Крит двигает DPS-ось.
	var crit_up := _reward_by_id("crit_chance_up")
	var crit_forecast: Dictionary = LevelUpAdvisor.forecast_reward(crit_up, stats, mods, weapon_config)
	if float(crit_forecast["dps_after"]) <= float(crit_forecast["dps_before"]):
		_fail("«+Шанс крита» обязан увеличивать DPS-скор.")

	# 5) Набор из трёх утилити-наград — без бейджей вовсе (FAN-1034: карты
	# knockback/projectile_speed удалены; утилити-набор — подбор/область/призыв,
	# ни одна не двигает dps_score/survivability_score).
	var aoe_up := _reward_by_id("aoe_radius_up")
	var summon_up := _reward_by_id("summon_amount_up")
	var utility := LevelUpAdvisor.recommend([pickup_up, aoe_up, summon_up], stats, mods, weapon_config)
	if int(utility["dps_index"]) != -1 or int(utility["surv_index"]) != -1:
		_fail("Утилити-набор не должен получать бейджи, получено dps=%d surv=%d." % [int(utility["dps_index"]), int(utility["surv_index"])])

	# 6) Совпадение осей на одной карточке -> единый бейдж «Лучший выбор».
	var hybrid := {"id": "test_hybrid", "title": "+Гибрид", "kind": "upgrade",
		"mods": {"damage_multiplier": 1.15, "max_health_flat": 30.0}}
	var hybrid_advice := LevelUpAdvisor.recommend([hybrid, pickup_up, aoe_up], stats, mods, weapon_config)
	if str((hybrid_advice["badges"] as Array)[0]) != LevelUpAdvisor.BADGE_BOTH:
		_fail("Гибридная лучшая карточка должна получить бейдж both, получено %s." % str(hybrid_advice["badges"]))

	# 7) Изоляция типов урона: у берсерка дельты «+Урон» показывают физический
	# damage и не показывают чужой magic-тип (SCRUM-898: звуковая ось удалена).
	var damage_forecast: Dictionary = (advice["forecasts"] as Array)[0]
	var delta_ids: Array = []
	for delta in (damage_forecast["deltas"] as Array):
		delta_ids.append(str(delta["id"]))
	if not delta_ids.has("damage"):
		_fail("Дельты «+Урон» берсерка обязаны включать параметр damage, получено %s." % str(delta_ids))
	if delta_ids.has("magic_damage") or delta_ids.has("sound_wave_damage"):
		_fail("Дельты берсерка не должны показывать чужие/удалённые типы урона, получено %s." % str(delta_ids))

	# 8) Rare-награда «+1 Сила»: базовый атрибут двигает урон, дельта видима.
	var strength_reward := {"id": "levelup_stat_strength", "title": "Сила +1", "kind": "stat", "stats": {"strength": 1.0}, "rare": true}
	var strength_forecast: Dictionary = LevelUpAdvisor.forecast_reward(strength_reward, stats, mods, weapon_config)
	if float(strength_forecast["dps_after"]) <= float(strength_forecast["dps_before"]):
		_fail("«Сила +1» обязана увеличивать DPS-скор берсерка.")
	if (strength_forecast["deltas"] as Array).is_empty():
		_fail("«Сила +1» обязана давать видимые дельты производных статов.")

	# 9) Семантика preview_reward_state = player._apply_reward_mods:
	# *_multiplier перемножается, плоские ключи складываются.
	var seeded_mods := {"damage_multiplier": 1.20, "defense_flat": 0.05}
	var preview := LevelUpAdvisor.preview_reward_state(
		{"mods": {"damage_multiplier": 1.15, "defense_flat": 0.10}}, stats, seeded_mods)
	var preview_mods: Dictionary = preview["run_modifiers"]
	if absf(float(preview_mods["damage_multiplier"]) - 1.20 * 1.15) > 0.0001:
		_fail("damage_multiplier должен перемножаться: ожидалось %.4f, получено %.4f." % [1.20 * 1.15, float(preview_mods["damage_multiplier"])])
	if absf(float(preview_mods["defense_flat"]) - 0.15) > 0.0001:
		_fail("defense_flat должен складываться: ожидалось 0.15, получено %.4f." % float(preview_mods["defense_flat"]))
	if not seeded_mods.has("damage_multiplier") or absf(float(seeded_mods["damage_multiplier"]) - 1.20) > 0.0001:
		_fail("preview_reward_state не должен мутировать исходные run_modifiers.")

	# 10) Формат строки дельты: ASCII «->» (контракт смоук/матрицы) и знак прироста.
	var sample_delta: Dictionary = (damage_forecast["deltas"] as Array)[0]
	var line := LevelUpAdvisor.delta_line(sample_delta)
	if not line.contains("->") or not line.contains("(+"):
		_fail("Строка дельты должна содержать «->» и «(+», получено «%s»." % line)

	if _failed:
		push_error("Level-up advisor gate FAILED.")
		quit(1)
		return
	print("Level-up advisor gate passed: бейджи DPS/выживаемости честные, изоляция типов урона и семантика применения наград соблюдены.")
	quit(0)
