class_name LevelUpAdvisor
extends RefCounted

# SCRUM-871: честный прогноз level-up наград для экрана повышения уровня.
# Dry-run применения награды (та же семантика, что player.apply_reward /
# _apply_reward_mods) к КОПИЯМ stats/run_modifiers, затем пересчёт
# ProgressionData.derived_parameters до/после. Формулы урона/живучести здесь
# не дублируются — сравниваются готовые производные параметры, поэтому прогноз
# по построению совпадает с фактическим применением награды.

const ProgressionDataRef := preload("res://scripts/progression_data.gd")

# Опорный удар врага для absorb-части EHP-модели: absorb плоско режет удар,
# поэтому его ценность зависит от размера типового удара. 20 ~ рядовой удар
# середины забега; для сравнения карточек между собой точная величина не
# критична — важна одинаковая база у всех трёх вариантов.
const TYPICAL_ENEMY_HIT := 20.0
# Окно (сек), за которое реген/вампиризм зачитываются в запас живучести.
const SUSTAIN_WINDOW_SECONDS := 12.0
# Минимальный относительный прирост, за который выдаётся бейдж рекомендации.
const MIN_BADGE_GAIN := 0.001
# Минимальная относительная дельта производного параметра для блока «до → после».
const MIN_VISIBLE_DELTA := 0.002

# Показываемые производные параметры: порядок = приоритет при равных дельтах.
# kind: number | percent (0..1 → пп) | mult (×N) | per_second
# Изоляция типов урона (SCRUM-524): из damage/magic_damage
# наружу отдаётся только «свой» тип класса (см. _collect_deltas).
const DAMAGE_TYPE_PARAMETERS := ["damage", "magic_damage"]
const DELTA_DEFINITIONS := [
	{"id": "damage", "label": "Урон", "kind": "number"},
	{"id": "magic_damage", "label": "Маг. урон", "kind": "number"},
	{"id": "attack_speed", "label": "Атак/с", "kind": "per_second"},
	{"id": "crit_chance", "label": "Шанс крита", "kind": "percent"},
	{"id": "crit_damage_multiplier", "label": "Сила крита", "kind": "mult"},
	{"id": "health_point", "label": "Макс. HP", "kind": "number"},
	{"id": "defense", "label": "Защита", "kind": "percent"},
	{"id": "dodge", "label": "Уклонение", "kind": "percent"},
	{"id": "absorb", "label": "Поглощение", "kind": "number"},
	{"id": "regeneration", "label": "Реген/с", "kind": "per_second"},
	{"id": "vampiric_chance", "label": "Шанс вампиризма", "kind": "percent"},
	{"id": "vampiric_amount", "label": "Вампиризм-лечение", "kind": "number"},
	{"id": "dot_damage", "label": "DoT/тик", "kind": "number"},
	{"id": "dot_speed", "label": "DoT тиков/с", "kind": "per_second"},
	{"id": "move_speed", "label": "Скорость", "kind": "number"},
	{"id": "attack_range", "label": "Дальность", "kind": "number"},
	{"id": "aoe_radius", "label": "Радиус удара", "kind": "number"},
	{"id": "aura_radius", "label": "Радиус ауры", "kind": "number"},
	{"id": "sector_multiplier", "label": "Ширина сектора", "kind": "mult"},
	{"id": "knockback_power", "label": "Отталкивание", "kind": "number"},
	{"id": "projectile_speed", "label": "Снаряды", "kind": "number"},
	{"id": "pickup_radius", "label": "Подбор", "kind": "number"},
	{"id": "buff_power", "label": "Сила поддержки", "kind": "mult"},
	{"id": "summon_amount", "label": "Призывы", "kind": "number"},
	{"id": "ultimate_multiplier", "label": "Сила ульты", "kind": "mult"},
]

const BADGE_NONE := ""
const BADGE_DPS := "dps"
const BADGE_SURV := "surv"
const BADGE_BOTH := "both"


# Дублирует семантику player.apply_reward для статов и модификаторов, не трогая
# игрока: stats складываются, mods/affinity_mods идут в run_modifiers
# (`*_multiplier` перемножаются, остальные складываются). Разовые эффекты
# (heal_percent) постоянных параметров не меняют и в прогноз не входят.
static func preview_reward_state(reward: Dictionary, stats: Dictionary, run_modifiers: Dictionary) -> Dictionary:
	var stats_after: Dictionary = stats.duplicate(true)
	var mods_after: Dictionary = run_modifiers.duplicate(true)
	if reward.has("stats"):
		for stat_id in reward["stats"].keys():
			stats_after[stat_id] = float(stats_after.get(stat_id, 0.0)) + float(reward["stats"][stat_id])
	for mods_key in ["mods", "affinity_mods"]:
		if not reward.has(mods_key):
			continue
		var mods: Dictionary = reward[mods_key]
		for modifier_id in mods.keys():
			if str(modifier_id).ends_with("_multiplier"):
				mods_after[modifier_id] = float(mods_after.get(modifier_id, 1.0)) * float(mods[modifier_id])
			else:
				mods_after[modifier_id] = float(mods_after.get(modifier_id, 0.0)) + float(mods[modifier_id])
	return {"stats": stats_after, "run_modifiers": mods_after}


# Паспортный DPS-прокси от производных параметров: урон родного типа класса ×
# атаки в секунду × ожидание крита + DoT-трек. Абсолют не равен боевому DPS
# (геометрия/попадания за скобками), но для сравнения «до/после» одного и того
# же билда монотонен по всем боевым наградам.
static func dps_score(derived: Dictionary, character_id: String) -> float:
	var damage_parameter := ProgressionDataRef.damage_parameter_for(character_id)
	var hit := float(derived.get(damage_parameter, derived.get("damage", 0.0)))
	var attack_speed := maxf(float(derived.get("attack_speed", 0.0)), 0.0)
	var crit_chance := clampf(float(derived.get("crit_chance", 0.0)), 0.0, 1.0)
	var crit_mult := maxf(float(derived.get("crit_damage_multiplier", 1.0)), 1.0)
	var crit_factor := 1.0 + crit_chance * (crit_mult - 1.0)
	var dot := maxf(float(derived.get("dot_damage", 0.0)), 0.0) * maxf(float(derived.get("dot_speed", 0.0)), 0.0)
	return hit * attack_speed * crit_factor + dot


# Живучесть = эффективный запас HP по модели боевого player.take_damage:
# absorb плоско режет типовой удар (но не ниже гарантированной доли), затем
# защита, затем шанс полного уворота; реген и вампиризм добавляют запас за
# опорное окно боя.
static func survivability_score(derived: Dictionary) -> float:
	var hp := maxf(float(derived.get("health_point", 1.0)), 1.0)
	var defense := clampf(float(derived.get("defense", 0.0)), 0.0, ProgressionDataRef.SURVIVABILITY_DEFENSE_CAP)
	var dodge := clampf(float(derived.get("dodge", 0.0)), 0.0, ProgressionDataRef.SURVIVABILITY_DODGE_CAP)
	var absorb := maxf(float(derived.get("absorb", 0.0)), 0.0)
	var absorbed_hit := maxf(TYPICAL_ENEMY_HIT - absorb, TYPICAL_ENEMY_HIT * ProgressionDataRef.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION)
	var damage_fraction := (absorbed_hit / TYPICAL_ENEMY_HIT) * (1.0 - defense) * (1.0 - dodge)
	damage_fraction = maxf(damage_fraction, 0.02)
	var sustain_per_second := maxf(float(derived.get("regeneration", 0.0)), 0.0) \
		+ clampf(float(derived.get("vampiric_chance", 0.0)), 0.0, 1.0) \
			* maxf(float(derived.get("vampiric_amount", 0.0)), 0.0) \
			* maxf(float(derived.get("attack_speed", 0.0)), 0.0)
	return (hp + sustain_per_second * SUSTAIN_WINDOW_SECONDS) / damage_fraction


# Полный прогноз одной награды: derived до/после, видимые дельты и скоры.
static func forecast_reward(reward: Dictionary, stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Dictionary:
	var character_id := str(weapon_config.get("character_id", ""))
	var before: Dictionary = ProgressionDataRef.derived_parameters(stats, run_modifiers, weapon_config)
	var preview := preview_reward_state(reward, stats, run_modifiers)
	var after: Dictionary = ProgressionDataRef.derived_parameters(preview["stats"], preview["run_modifiers"], weapon_config)
	return {
		"before": before,
		"after": after,
		"deltas": _collect_deltas(before, after, character_id),
		"dps_before": dps_score(before, character_id),
		"dps_after": dps_score(after, character_id),
		"surv_before": survivability_score(before),
		"surv_after": survivability_score(after),
	}


# Прогнозы для всего набора карточек + индексы лучших. Бейдж выдаётся только за
# положительный прирост; одна карточка может быть лучшей и в уроне, и в
# живучести (badges[i] == BADGE_BOTH).
static func recommend(rewards: Array, stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Dictionary:
	var forecasts: Array = []
	for reward in rewards:
		forecasts.append(forecast_reward(reward, stats, run_modifiers, weapon_config))
	var dps_index := -1
	var surv_index := -1
	var best_dps_gain := MIN_BADGE_GAIN
	var best_surv_gain := MIN_BADGE_GAIN
	for index in range(forecasts.size()):
		var forecast: Dictionary = forecasts[index]
		var dps_gain := _relative_gain(float(forecast["dps_before"]), float(forecast["dps_after"]))
		var surv_gain := _relative_gain(float(forecast["surv_before"]), float(forecast["surv_after"]))
		if dps_gain > best_dps_gain:
			best_dps_gain = dps_gain
			dps_index = index
		if surv_gain > best_surv_gain:
			best_surv_gain = surv_gain
			surv_index = index
	var badges: Array = []
	for index in range(forecasts.size()):
		if index == dps_index and index == surv_index:
			badges.append(BADGE_BOTH)
		elif index == dps_index:
			badges.append(BADGE_DPS)
		elif index == surv_index:
			badges.append(BADGE_SURV)
		else:
			badges.append(BADGE_NONE)
	return {
		"forecasts": forecasts,
		"badges": badges,
		"dps_index": dps_index,
		"surv_index": surv_index,
		"dps_gain": best_dps_gain if dps_index >= 0 else 0.0,
		"surv_gain": best_surv_gain if surv_index >= 0 else 0.0,
	}


static func format_value(kind: String, value: float) -> String:
	match kind:
		"percent":
			return "%d%%" % int(roundf(value * 100.0))
		"mult":
			return "x%.2f" % value
		"per_second":
			return ("%.2f" % value) if value < 10.0 else ("%.1f" % value)
		_:
			if absf(value) >= 100.0:
				return "%d" % int(roundf(value))
			return "%.1f" % value


# Строка изменения для карточки/тултипа: «Урон: 145 -> 167 (+15%)»;
# для percent-параметров прирост в процентных пунктах: «Защита: 22% -> 29% (+7 пп)».
# ASCII «->» — контракт смоук/матрица-тестов и гарантированно есть в шрифте.
static func delta_line(delta: Dictionary) -> String:
	var kind := str(delta.get("kind", "number"))
	var before := float(delta.get("before", 0.0))
	var after := float(delta.get("after", 0.0))
	var gain_text: String
	if kind == "percent":
		gain_text = "%+d пп" % int(roundf((after - before) * 100.0))
	elif absf(before) <= 0.0001 and after > before:
		# База нулевая (эффект появляется впервые) — процент прироста бессмыслен.
		gain_text = "новое"
	else:
		gain_text = "%+d%%" % int(roundf(_relative_gain(before, after) * 100.0))
	return "%s: %s -> %s (%s)" % [str(delta.get("label", "")), format_value(kind, before), format_value(kind, after), gain_text]


static func _relative_gain(before: float, after: float) -> float:
	return (after - before) / maxf(absf(before), 0.001)


static func _collect_deltas(before: Dictionary, after: Dictionary, character_id := "") -> Array:
	var class_damage := ProgressionDataRef.damage_parameter_for(character_id) if character_id != "" else "damage"
	var deltas: Array = []
	for definition in DELTA_DEFINITIONS:
		var parameter_id: String = definition["id"]
		if parameter_id in DAMAGE_TYPE_PARAMETERS and parameter_id != class_damage:
			continue
		var value_before := float(before.get(parameter_id, 0.0))
		var value_after := float(after.get(parameter_id, 0.0))
		if absf(value_after - value_before) <= 0.000001:
			continue
		# Кап на сортировочную величину: «эффект с нулевой базы» ранжируется высоко,
		# но не взрывает порядок бесконечным относительным приростом.
		var relative: float = minf(absf(_relative_gain(value_before, value_after)), 10.0)
		if relative < MIN_VISIBLE_DELTA:
			continue
		deltas.append({
			"id": parameter_id,
			"label": definition["label"],
			"kind": definition["kind"],
			"before": value_before,
			"after": value_after,
			"relative": relative,
		})
	deltas.sort_custom(func(a, b): return float(a["relative"]) > float(b["relative"]))
	return deltas
