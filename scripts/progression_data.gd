class_name ProgressionData
extends RefCounted

const CharacterData := preload("res://scripts/progression_data_characters.gd")
const STAT_NAMES := CharacterData.STAT_NAMES
const BASE_STATS := CharacterData.BASE_STATS
const CHARACTER_CONFIGS := CharacterData.CHARACTER_CONFIGS
const ULTIMATE_CONFIGS := CharacterData.ULTIMATE_CONFIGS
const CLASS_DAMAGE_PARAMETER := CharacterData.CLASS_DAMAGE_PARAMETER
const STAT_CLASS_RELEVANCE := CharacterData.STAT_CLASS_RELEVANCE
const CLASS_INTERPRETATIONS := CharacterData.CLASS_INTERPRETATIONS
const CLASS_MECHANIC_IDENTITIES := CharacterData.CLASS_MECHANIC_IDENTITIES
const ATTRIBUTE_PRIORITIES := CharacterData.ATTRIBUTE_PRIORITIES
const ATTRIBUTE_PRIORITY_REASONS := CharacterData.ATTRIBUTE_PRIORITY_REASONS

const BalanceData := preload("res://scripts/progression_data_balance.gd")
const CLASS_BUDGET_PROFILES := BalanceData.CLASS_BUDGET_PROFILES
const CLASS_LEVEL_STAT_GROWTH_SCALARS := BalanceData.CLASS_LEVEL_STAT_GROWTH_SCALARS
const BALANCE_BASE_SOLO_DPS := BalanceData.BALANCE_BASE_SOLO_DPS
const BALANCE_BASE_AOE_DPS := BalanceData.BALANCE_BASE_AOE_DPS
const COMFORT_WEIGHTS := BalanceData.COMFORT_WEIGHTS
const COMFORT_WEIGHT_OVERRIDES := BalanceData.COMFORT_WEIGHT_OVERRIDES
const COMFORT_BAND_TOLERANCE := BalanceData.COMFORT_BAND_TOLERANCE
const COMFORT_DEFAULT_WEIGHT := BalanceData.COMFORT_DEFAULT_WEIGHT
const COMFORT_BAND_SLICES := BalanceData.COMFORT_BAND_SLICES
const COMFORT_BAND_SLICE_WEIGHTS := BalanceData.COMFORT_BAND_SLICE_WEIGHTS
const COMFORT_BAND_SLICE_OVERRIDES := BalanceData.COMFORT_BAND_SLICE_OVERRIDES
const BALANCE_WINDOW_SECONDS := BalanceData.BALANCE_WINDOW_SECONDS
const CROWD_CLEAR_TARGET_COUNTS := BalanceData.CROWD_CLEAR_TARGET_COUNTS
const CROWD_CLEAR_ENEMY_HP := BalanceData.CROWD_CLEAR_ENEMY_HP
const CROWD_CLEAR_CORRIDOR := BalanceData.CROWD_CLEAR_CORRIDOR
const CROWD_CLEAR_SOLO_CORRIDOR := BalanceData.CROWD_CLEAR_SOLO_CORRIDOR
const SURVIVABILITY_DEFENSE_CAP := BalanceData.SURVIVABILITY_DEFENSE_CAP
const SURVIVABILITY_DEFENSE_DIMINISH := BalanceData.SURVIVABILITY_DEFENSE_DIMINISH
const SURVIVABILITY_DODGE_CAP := BalanceData.SURVIVABILITY_DODGE_CAP
const SURVIVABILITY_DODGE_DIMINISH := BalanceData.SURVIVABILITY_DODGE_DIMINISH
const SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION := BalanceData.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION
const SURVIVABILITY_ABSORB_FLAT_DIMINISH := BalanceData.SURVIVABILITY_ABSORB_FLAT_DIMINISH
const SURVIVABILITY_REGEN_FLAT_MULTIPLIER := BalanceData.SURVIVABILITY_REGEN_FLAT_MULTIPLIER
const VAMPIRIC_CHANCE_CAP := BalanceData.VAMPIRIC_CHANCE_CAP
const VAMPIRIC_DAMAGE_HEAL_RATIO := BalanceData.VAMPIRIC_DAMAGE_HEAL_RATIO
const VAMPIRIC_BASE_HEAL_MULTIPLIER := BalanceData.VAMPIRIC_BASE_HEAL_MULTIPLIER
const VAMPIRIC_HEAL_CAP_DEFAULT := BalanceData.VAMPIRIC_HEAL_CAP_DEFAULT
const VAMPIRIC_HEAL_CAP_HARD := BalanceData.VAMPIRIC_HEAL_CAP_HARD
const WEAPON_DRAIN_HEAL_MULTIPLIER := BalanceData.WEAPON_DRAIN_HEAL_MULTIPLIER
const CRIT_CHANCE_CAP := BalanceData.CRIT_CHANCE_CAP
const CRIT_CHANCE_DIMINISH := BalanceData.CRIT_CHANCE_DIMINISH
const CRIT_FLAT_EFFECTIVENESS := BalanceData.CRIT_FLAT_EFFECTIVENESS
const CRIT_DAMAGE_BASE_MULTIPLIER := BalanceData.CRIT_DAMAGE_BASE_MULTIPLIER
const CRIT_DAMAGE_AGILITY_SCALE := BalanceData.CRIT_DAMAGE_AGILITY_SCALE
const CRIT_DAMAGE_FLAT_EFFECTIVENESS := BalanceData.CRIT_DAMAGE_FLAT_EFFECTIVENESS
const CRIT_DAMAGE_CAP := BalanceData.CRIT_DAMAGE_CAP
const RUN_DAMAGE_MULT_SOFTCAP := BalanceData.RUN_DAMAGE_MULT_SOFTCAP
const RUN_DAMAGE_MULT_KNEE := BalanceData.RUN_DAMAGE_MULT_KNEE
const RUN_ATTACK_SPEED_MULT_SOFTCAP := BalanceData.RUN_ATTACK_SPEED_MULT_SOFTCAP
const RUN_ATTACK_SPEED_MULT_KNEE := BalanceData.RUN_ATTACK_SPEED_MULT_KNEE
const WEAPON_ARCHETYPE_BY_MODE := BalanceData.WEAPON_ARCHETYPE_BY_MODE
const ATTRIBUTE_WEAPON_SYNERGY_MAP := BalanceData.ATTRIBUTE_WEAPON_SYNERGY_MAP
const STAGE_SCALE_BASE := BalanceData.STAGE_SCALE_BASE
const STAGE_SCALE_LINEAR := BalanceData.STAGE_SCALE_LINEAR
const ECONOMY_PRICE_MULTIPLIER := BalanceData.ECONOMY_PRICE_MULTIPLIER
const XP_CURVE_MULTIPLIER := BalanceData.XP_CURVE_MULTIPLIER
const XP_CURVE_FLAT := BalanceData.XP_CURVE_FLAT
const DROP_CLASS_MULTIPLIERS := BalanceData.DROP_CLASS_MULTIPLIERS
const COST_BY_TIER := BalanceData.COST_BY_TIER
const TIER_WEIGHTS := BalanceData.TIER_WEIGHTS

const WeaponsData := preload("res://scripts/progression_data_weapons.gd")
const BERSERK_WEAPONS := WeaponsData.BERSERK_WEAPONS
const DARK_MAGE_WEAPONS := WeaponsData.DARK_MAGE_WEAPONS
const GUITARIST_WEAPONS := WeaponsData.GUITARIST_WEAPONS
const ASSASSIN_WEAPONS := WeaponsData.ASSASSIN_WEAPONS
const RANGER_WEAPONS := WeaponsData.RANGER_WEAPONS
const DOCTOR_WEAPONS := WeaponsData.DOCTOR_WEAPONS
const CHEMIST_WEAPONS := WeaponsData.CHEMIST_WEAPONS
const KNIGHT_WEAPONS := WeaponsData.KNIGHT_WEAPONS
const DRUID_WEAPONS := WeaponsData.DRUID_WEAPONS
const SOLDIER_WEAPONS := WeaponsData.SOLDIER_WEAPONS
const THIEF_WEAPONS := WeaponsData.THIEF_WEAPONS
const ELEMENTALIST_WEAPONS := WeaponsData.ELEMENTALIST_WEAPONS
const SNIPER_WEAPONS := WeaponsData.SNIPER_WEAPONS
const PRIEST_WEAPONS := WeaponsData.PRIEST_WEAPONS
const BIOLOGIST_WEAPONS := WeaponsData.BIOLOGIST_WEAPONS
const ROBOT_WEAPONS := WeaponsData.ROBOT_WEAPONS
const ENGINEER_WEAPONS := WeaponsData.ENGINEER_WEAPONS
const WEAPONS_BY_CLASS := WeaponsData.WEAPONS_BY_CLASS

const ContentData := preload("res://scripts/progression_data_content.gd")
const STAT_REWARDS := ContentData.STAT_REWARDS
const ARTIFACTS := ContentData.ARTIFACTS
const LEVEL_UP_REWARDS := ContentData.LEVEL_UP_REWARDS
const START_BOONS := ContentData.START_BOONS  # SCRUM-618: стартовые бооны забега

const AscensionData := preload("res://scripts/progression_data_ascension.gd")
const ASCENSION_MODIFIERS := AscensionData.ASCENSION_MODIFIERS
const ASCENSION_DIFFICULTY_DEFAULTS := AscensionData.ASCENSION_DIFFICULTY_DEFAULTS
const ASCENSION_LEVELS := AscensionData.ASCENSION_LEVELS

const ShopData := preload("res://scripts/progression_data_shop.gd")
const SHOP_ITEMS := ShopData.SHOP_ITEMS

const EnemyData := preload("res://scripts/progression_data_enemies.gd")
const ENEMY_SIZE_PROFILES := EnemyData.ENEMY_SIZE_PROFILES
const MINI_ELITE_KINDS := EnemyData.MINI_ELITE_KINDS
const ENEMY_MECHANIC_CATALOG := EnemyData.ENEMY_MECHANIC_CATALOG
const ELITE_ATTACK_CONFIGS := EnemyData.ELITE_ATTACK_CONFIGS
const UNIQUE_ENCOUNTER_PATTERNS := EnemyData.UNIQUE_ENCOUNTER_PATTERNS

static func artifact_definition(artifact_id: String) -> Dictionary:
	for artifact in ARTIFACTS:
		if str(artifact.get("id", "")) == artifact_id:
			return artifact
	for item in SHOP_ITEMS:
		if str(item.get("id", "")) == artifact_id:
			return item
	return {}


# --- Стартовые бооны забега (SCRUM-618) ---

static func start_boons() -> Array:
	return START_BOONS


static func start_boon_definition(boon_id: String) -> Dictionary:
	for boon in START_BOONS:
		if str(boon.get("id", "")) == boon_id:
			return boon
	return {}


# Mods выбранного боона (пустой dict, если боон не выбран/неизвестен — тождественность).
static func start_boon_mods(boon_id: String) -> Dictionary:
	if boon_id == "":
		return {}
	var boon := start_boon_definition(boon_id)
	if boon.is_empty():
		return {}
	return (boon.get("mods", {}) as Dictionary).duplicate(true)


static func damage_parameter_for(character_id: String) -> String:
	return str(CLASS_DAMAGE_PARAMETER.get(character_id, "damage"))


static func is_stat_relevant(stat_id: String, character_id: String) -> bool:
	return true


static func is_reward_relevant(reward: Dictionary, character_id: String) -> bool:
	return true


static func class_interpretation_text(character_id: String, stat_or_parameter_id: String) -> String:
	var class_map: Dictionary = CLASS_INTERPRETATIONS.get(character_id, {})
	var direct := str(class_map.get(stat_or_parameter_id, ""))
	if direct != "":
		return direct
	match stat_or_parameter_id:
		"leadership", "summon_amount":
			return "Для этого класса работает как частота вспомогательных эхо-эффектов и поддержки."
		"intelligence", "magic_damage":
			return "Для этого класса работает как зачарование оружия или магический splash."
		"sound_wave_damage", "aura_radius":
			return "Для этого класса работает как боевой клич и ближний контроль пространства."
		"knowledge", "dot_damage", "dot_speed":
			return "Для этого класса добавляет малый bleed/burn/poison след к ударам."
		"energy", "ultimate_multiplier":
			return "Ускоряет уникальную механику класса и усиливает reserved ultimate-scaling."
		"strength", "damage":
			return "Дает физическую весомость атакам, knockback и прямой урон."
		_:
			return "Универсально полезно через формулы персонажа и текущий class kit."


static func attribute_priorities(character_id: String) -> Array:
	return (ATTRIBUTE_PRIORITIES.get(character_id, []) as Array).duplicate()


static func class_mechanic_identity(character_id: String) -> Dictionary:
	var fallback: Dictionary = CLASS_MECHANIC_IDENTITIES.get("berserk", {}) as Dictionary
	var identity: Dictionary = CLASS_MECHANIC_IDENTITIES.get(character_id, fallback) as Dictionary
	return identity.duplicate(true)


static func class_main_attribute(character_id: String) -> String:
	var identity: Dictionary = class_mechanic_identity(character_id)
	var main_attribute: String = str(identity.get("main_attribute", ""))
	if main_attribute != "":
		return main_attribute
	var priorities: Array = attribute_priorities(character_id)
	if not priorities.is_empty():
		return str(priorities[0])
	return "strength"


static func weapon_mechanic_identity(character_id: String, weapon_id: String) -> String:
	var identity: Dictionary = class_mechanic_identity(character_id)
	var weapon_identities: Dictionary = identity.get("weapon_identities", {}) as Dictionary
	return str(weapon_identities.get(weapon_id, ""))


static func weapon_archetype(weapon_config: Dictionary) -> String:
	if int(weapon_config.get("max_summons", 0)) > 0 or weapon_config.has("summon_damage_multiplier") or str(weapon_config.get("summon_role", "")) != "":
		return "summon"
	var mode := str(weapon_config.get("attack_mode", weapon_config.get("attack_shape", "single")))
	return str(WEAPON_ARCHETYPE_BY_MODE.get(mode, "projectile"))


static func attribute_weapon_synergy_map() -> Dictionary:
	return ATTRIBUTE_WEAPON_SYNERGY_MAP.duplicate(true)


static func attribute_weapon_synergy_description(stat_id: String, weapon_config: Dictionary) -> String:
	var stat_map: Dictionary = ATTRIBUTE_WEAPON_SYNERGY_MAP.get(stat_id, {}) as Dictionary
	return str(stat_map.get(weapon_archetype(weapon_config), "Универсально усиливает текущую схему оружия."))


static func attribute_priority_reason(character_id: String, stat_id: String) -> String:
	var prefix := "Приоритет класса: " if attribute_priorities(character_id).has(stat_id) else ""
	var class_text := class_interpretation_text(character_id, stat_id)
	var base_text := str(ATTRIBUTE_PRIORITY_REASONS.get(stat_id, "универсально полезно для билда"))
	if prefix != "":
		return "%s%s. База: %s." % [prefix, class_text, base_text]
	return "База: %s. %s" % [base_text, class_text]


static func attribute_priority_weight(character_id: String, stat_id: String) -> float:
	var stats: Dictionary = base_stats(character_id)
	var stat_value := float(stats.get(stat_id, 4.0))
	var priority_index := attribute_priorities(character_id).find(stat_id)
	var priority_bonus := 1.0
	if priority_index >= 0:
		priority_bonus = 1.65 - float(priority_index) * 0.12
	return maxf(0.35, (0.35 + stat_value / 10.0) * priority_bonus)


static func reward_attribute_dependency(reward: Dictionary) -> String:
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return str(stat_keys[0])
	var mods: Dictionary = reward.get("mods", {})
	for key in mods.keys():
		match str(key):
			"damage_multiplier", "knockback_multiplier":
				return "strength"
			"attack_speed_multiplier", "move_speed_multiplier", "crit_chance_flat", "crit_damage_flat", "dodge_flat", "projectile_speed_flat":
				return "agility"
			"aoe_radius_multiplier", "pickup_radius_flat", "range_multiplier", "aura_radius_flat":
				return "perception"
			"defense_flat", "max_health_flat", "max_health_multiplier", "absorb_flat":
				return "endurance"
			"dot_damage_flat", "dot_speed_flat", "regeneration_flat":
				return "knowledge"
			"ultimate_flat", "vampiric_amount_flat", "vampiric_chance_flat":
				return "energy"
			"buff_power_flat", "summon_bonus":
				return "leadership"
	return ""


static func level_up_reward_weight(reward: Dictionary, character_id: String) -> float:
	var dependency := reward_attribute_dependency(reward)
	if dependency == "":
		return float(reward.get("weight", 1.0))
	return maxf(0.25, float(reward.get("weight", 1.0)) * attribute_priority_weight(character_id, dependency))


static func ultimate_config(character_id: String) -> Dictionary:
	return ULTIMATE_CONFIGS.get(character_id, ULTIMATE_CONFIGS["berserk"]).duplicate(true)


static func _diminishing_percent(raw_value: float, cap: float, curve: float) -> float:
	var raw := maxf(raw_value, 0.0)
	var softened := raw / (1.0 + raw * curve)
	return clampf(softened, 0.0, cap)


# SCRUM-503: diminishing returns на ЗАБЕГОВЫЙ боевой множитель. Сжимает ТОЛЬКО
# избыток множителя над 1.0 по кривой excess/(1+excess*knee), клампит избыток к
# (softcap-1.0) и возвращает 1.0 + сжатый_избыток. Тождественно при multiplier
# <= 1.0 (excess<=0 → возвращает сам множитель): при пустых run_modifiers
# (estimate_weapon_budget) и на базе lvl1 cap нейтрален, поэтому формульные гейты
# и стартовые числа не меняются — нерф строго «сверху базы». Понижение множителя
# (<1.0, напр. замедление атаки оружием) проходит без сжатия.
static func _soft_capped_run_multiplier(multiplier: float, softcap: float, knee: float) -> float:
	if multiplier <= 1.0:
		return multiplier
	var excess := multiplier - 1.0
	var softened := excess / (1.0 + excess * knee)
	return 1.0 + clampf(softened, 0.0, maxf(softcap - 1.0, 0.0))


static func effective_defense(raw_defense: float) -> float:
	return _diminishing_percent(raw_defense, SURVIVABILITY_DEFENSE_CAP, SURVIVABILITY_DEFENSE_DIMINISH)


static func effective_dodge(raw_dodge: float) -> float:
	return _diminishing_percent(raw_dodge, SURVIVABILITY_DODGE_CAP, SURVIVABILITY_DODGE_DIMINISH)


static func effective_absorb(endurance: float, flat_absorb: float) -> float:
	var base_absorb := maxf(endurance, 0.0) * 0.145  # SCRUM-526: 0.16→0.145, поджать базовый absorb стойкости (танк остаётся крепче fragile)
	var positive_flat := maxf(flat_absorb, 0.0)
	var negative_flat := minf(flat_absorb, 0.0)
	var softened_flat := positive_flat / (1.0 + positive_flat * SURVIVABILITY_ABSORB_FLAT_DIMINISH)
	return maxf(0.0, base_absorb + softened_flat + negative_flat)


static func effective_regeneration(knowledge: float, flat_regeneration: float) -> float:
	var positive_flat := maxf(flat_regeneration, 0.0) * SURVIVABILITY_REGEN_FLAT_MULTIPLIER
	var negative_flat := minf(flat_regeneration, 0.0)
	var regen_base := maxf(0.0, 0.16 + positive_flat + negative_flat)  # SCRUM-526: база реген 0.22→0.16
	var knowledge_scale := 0.45 + maxf(knowledge, 0.0) / 12.0
	return regen_base * knowledge_scale


static func effective_vampiric_chance(raw_chance: float) -> float:
	return clampf(raw_chance, 0.0, VAMPIRIC_CHANCE_CAP)


static func effective_vampiric_cap(raw_cap: float) -> float:
	return clampf(raw_cap, 0.0, VAMPIRIC_HEAL_CAP_HARD)


static func effective_crit_chance(raw_chance: float) -> float:
	var raw := maxf(raw_chance, 0.0)
	var softened := raw / (1.0 + raw * CRIT_CHANCE_DIMINISH)
	return clampf(softened, 0.0, CRIT_CHANCE_CAP)


static func effective_crit_damage_multiplier(agility: float, flat_bonus: float) -> float:
	var positive_flat := maxf(flat_bonus, 0.0) * CRIT_DAMAGE_FLAT_EFFECTIVENESS
	var negative_flat := minf(flat_bonus, 0.0)
	var multiplier := CRIT_DAMAGE_BASE_MULTIPLIER + maxf(agility, 0.0) * CRIT_DAMAGE_AGILITY_SCALE + positive_flat + negative_flat
	return clampf(multiplier, 1.0, CRIT_DAMAGE_CAP)


# SCRUM-524: архетип-множитель урона удалён. Он зависел от ВСЕХ атрибутов и
# одинаково домножал все типы урона, из-за чего прокачка одного атрибута протекала
# в чужие типы. Классовый баланс по DPS теперь полностью держит budget_tuning_for.


static func base_stats(character_id: String) -> Dictionary:
	return BASE_STATS.get(character_id, BASE_STATS["berserk"]).duplicate(true)


static func ascension_levels(character_id: String) -> Array:
	return ASCENSION_LEVELS.get(character_id, [])


static func ascension_mods(character_id: String, level: int) -> Dictionary:
	# Суммарные бонусы открытых уровней: каждый уровень включает предыдущие.
	var combined := {}
	var levels := ascension_levels(character_id)
	for level_index in range(clampi(level, 0, levels.size())):
		var level_mods: Dictionary = levels[level_index].get("mods", {})
		for modifier_id in level_mods.keys():
			if str(modifier_id).ends_with("_multiplier"):
				combined[modifier_id] = float(combined.get(modifier_id, 1.0)) * float(level_mods[modifier_id])
			else:
				combined[modifier_id] = float(combined.get(modifier_id, 0.0)) + float(level_mods[modifier_id])
	return combined


static func ascension_modifiers() -> Array:
	return ASCENSION_MODIFIERS


static func ascension_difficulty_mods(level: int) -> Dictionary:
	# Кумулятивно: уровень N включает усложнения 1..N. Множители перемножаются,
	# флаги/шансы складываются (берётся максимум для флагов через add — 0/1).
	var combined: Dictionary = ASCENSION_DIFFICULTY_DEFAULTS.duplicate(true)
	var clamped := clampi(level, 0, ASCENSION_MODIFIERS.size())
	for entry in ASCENSION_MODIFIERS:
		if int(entry.get("level", 0)) > clamped:
			continue
		for key in (entry.get("mods", {}) as Dictionary).keys():
			if str(key).ends_with("_mult"):
				combined[key] = float(combined.get(key, 1.0)) * float(entry["mods"][key])
			elif str(key) in ["elite_instant_phase", "boss_extra_phase", "first_wave_boost"]:
				combined[key] = maxf(float(combined.get(key, 0.0)), float(entry["mods"][key]))
			else:
				combined[key] = float(combined.get(key, 0.0)) + float(entry["mods"][key])
	return combined


static func ascension_modifier_lines(level: int) -> Array:
	# Читаемый кумулятивный список активных усложнений для UI (1..level).
	var lines := []
	var clamped := clampi(level, 0, ASCENSION_MODIFIERS.size())
	for entry in ASCENSION_MODIFIERS:
		if int(entry.get("level", 0)) <= clamped:
			lines.append("%s. %s — %s" % [entry["level"], entry["title"], entry["description"]])
	return lines


static func ascension_level_change_line(level: int) -> String:
	# Дельта конкретного уровня для компактного текста у кнопки старта.
	var clamped := clampi(level, 0, ASCENSION_MODIFIERS.size())
	if clamped <= 0:
		return "Уровень 0: без усложнений."
	for entry in ASCENSION_MODIFIERS:
		if int(entry.get("level", 0)) == clamped:
			return "Уровень %d: %s — %s" % [clamped, str(entry.get("title", "")), str(entry.get("description", ""))]
	return "Уровень %d: без новых усложнений." % clamped


static func stage_scale(route_stage: int) -> float:
	var stage := maxf(float(route_stage), 0.0)
	return snappedf(pow(STAGE_SCALE_BASE, stage) + STAGE_SCALE_LINEAR * stage, 0.001)


static func stage_scaled_cost(base_cost: int, route_stage: int) -> int:
	return maxi(1, int(ceil(float(base_cost) * stage_scale(route_stage) * ECONOMY_PRICE_MULTIPLIER)))


static func next_xp_requirement(current_requirement: int) -> int:
	return maxi(1, int(ceil(float(current_requirement) * XP_CURVE_MULTIPLIER + XP_CURVE_FLAT)))


static func drop_class_multiplier(drop_class: String) -> Dictionary:
	return (DROP_CLASS_MULTIPLIERS.get(drop_class, DROP_CLASS_MULTIPLIERS["ordinary"]) as Dictionary).duplicate(true)


static func drop_class_rewards(drop_class: String, route_stage: int, wave_index := 0) -> Dictionary:
	var multipliers := drop_class_multiplier(drop_class)
	var scale := stage_scale(route_stage)
	var wave_bonus := maxf(float(wave_index), 0.0)
	if drop_class == "boss":
		return {
			"xp": maxi(1, int(round(float(multipliers.get("xp", 1.0)) * scale))),
			"money": maxi(1, int(round(float(multipliers.get("money", 1.0)) * scale))),
			"money_chance": clampf(float(multipliers.get("money_chance", 1.0)), 0.0, 1.0),
		}
	var base_xp := maxi(1, int(round(1.0 + maxf(scale - 1.0, 0.0) * 0.35 + wave_bonus * 0.008)))
	var base_money := maxi(1, int(round(1.0 + maxf(scale - 1.0, 0.0) * 0.25 + wave_bonus * 0.006)))
	return {
		"xp": maxi(1, int(ceil(float(base_xp) * float(multipliers.get("xp", 1.0))))),
		"money": maxi(1, int(ceil(float(base_money) * float(multipliers.get("money", 1.0))))),
		"money_chance": clampf(float(multipliers.get("money_chance", 0.75)), 0.0, 1.0),
	}


static func character_ids() -> Array:
	return CHARACTER_CONFIGS.keys()


static func character_config(character_id: String) -> Dictionary:
	return CHARACTER_CONFIGS.get(character_id, CHARACTER_CONFIGS["berserk"]).duplicate(true)


static func berserk_weapon(weapon_id: String) -> Dictionary:
	return BERSERK_WEAPONS.get(weapon_id, BERSERK_WEAPONS["sword"]).duplicate(true)


static func berserk_weapon_ids() -> Array:
	return BERSERK_WEAPONS.keys()


static func weapon_ids(character_id: String) -> Array:
	var weapons: Dictionary = WEAPONS_BY_CLASS.get(character_id, BERSERK_WEAPONS)
	return weapons.keys()


static func class_budget_profile(character_id: String) -> Dictionary:
	return CLASS_BUDGET_PROFILES.get(character_id, CLASS_BUDGET_PROFILES["berserk"]).duplicate(true)


# SCRUM-544: comfort-вес класса/оружия — относительный потолок внутри ±20%-полосы.
# Per-weapon override > class weight > дефолт. Чем выше — тем больше «сырого» DPS
# классу позволено (плата за вовлечённость игрока).
static func comfort_weight(character_id: String, weapon_id := "") -> float:
	if weapon_id != "":
		var key := "%s/%s" % [character_id, weapon_id]
		if COMFORT_WEIGHT_OVERRIDES.has(key):
			return float(COMFORT_WEIGHT_OVERRIDES[key])
	return float(COMFORT_WEIGHTS.get(character_id, COMFORT_DEFAULT_WEIGHT))


# Comfort-нормированный DPS: measured / comfort_weight. Для проверки полосы все
# классы/оружия сравниваются в этой нормированной шкале.
static func comfort_normalized_dps(character_id: String, weapon_id: String, measured_dps: float) -> float:
	return measured_dps / maxf(comfort_weight(character_id, weapon_id), 0.001)


# SCRUM-544: per-slice comfort-вес для CSV-полосы (ось вовлечённости зависит от
# числа целей). Per-weapon override > class slice-вес > плоский comfort_weight.
# slice ∈ COMFORT_BAND_SLICES ("ideal_1"/"ideal_5"/"ideal_20").
static func comfort_slice_weight(character_id: String, weapon_id: String, slice: String) -> float:
	var override_key := "%s/%s" % [character_id, weapon_id]
	if COMFORT_BAND_SLICE_OVERRIDES.has(override_key):
		var ov: Dictionary = COMFORT_BAND_SLICE_OVERRIDES[override_key]
		if ov.has(slice):
			return float(ov[slice])
	if COMFORT_BAND_SLICE_WEIGHTS.has(character_id):
		var cw: Dictionary = COMFORT_BAND_SLICE_WEIGHTS[character_id]
		if cw.has(slice):
			return float(cw[slice])
	# Фоллбэк на плоский вес, если срез не задан в таблице.
	return comfort_weight(character_id, weapon_id)


# Per-slice comfort-нормированный DPS: measured / comfort_slice_weight.
static func comfort_slice_normalized_dps(character_id: String, weapon_id: String, slice: String, measured_dps: float) -> float:
	return measured_dps / maxf(comfort_slice_weight(character_id, weapon_id, slice), 0.001)


static func budget_tuning_for(character_id: String, weapon_config: Dictionary) -> Dictionary:
	var profile := class_budget_profile(character_id)
	var base_metrics := estimate_weapon_budget(character_id, weapon_config, false)
	var solo_target := BALANCE_BASE_SOLO_DPS * float(profile.get("solo_target", 1.0)) * float(profile.get("damage_budget", 1.0))
	var aoe_target := BALANCE_BASE_AOE_DPS * float(profile.get("aoe_target", 1.0)) * float(profile.get("damage_budget", 1.0))
	var solo_dps := maxf(float(base_metrics.get("solo_dps", 0.0)), 0.001)
	var aoe_dps := maxf(float(base_metrics.get("aoe_dps", 0.0)), 0.001)
	var solo_scale := solo_target / solo_dps
	var aoe_scale := aoe_target / aoe_dps
	var damage_multiplier := clampf(sqrt(solo_scale * aoe_scale), 0.28, 2.80)
	var scaled_config := weapon_config.duplicate(true)
	scaled_config["budget_damage_multiplier"] = damage_multiplier
	var scaled_metrics := estimate_weapon_budget(character_id, scaled_config, true)
	var scaled_solo := maxf(float(scaled_metrics.get("solo_dps", solo_dps)), 0.001)
	var scaled_aoe := maxf(float(scaled_metrics.get("aoe_dps", aoe_dps)), 0.001)
	return {
		"damage_multiplier": snappedf(damage_multiplier, 0.001),
		"solo_budget_multiplier": snappedf(solo_target / scaled_solo, 0.001),
		"aoe_budget_multiplier": snappedf(aoe_target / scaled_aoe, 0.001),
		"solo_target": snappedf(solo_target, 0.01),
		"aoe_target": snappedf(aoe_target, 0.01),
		"base_solo_dps": snappedf(solo_dps, 0.01),
		"base_aoe_dps": snappedf(aoe_dps, 0.01),
	}


static func estimate_weapon_budget(character_id: String, weapon_config: Dictionary, apply_budget := true) -> Dictionary:
	return estimate_weapon_budget_for_stats(character_id, weapon_config, base_stats(character_id), apply_budget)


static func estimate_weapon_budget_for_stats(character_id: String, weapon_config: Dictionary, stats: Dictionary, apply_budget := true) -> Dictionary:
	var config := weapon_config.duplicate(true)
	config["character_id"] = character_id
	if not apply_budget:
		config.erase("budget_damage_multiplier")
		config.erase("budget_tuning")
	var params := derived_parameters(stats, {}, config)
	var damage_parameter := str(config.get("damage_parameter", damage_parameter_for(character_id)))
	var base_damage := float(params.get(damage_parameter, params.get("damage", 1.0)))
	var crit_factor := 1.0 + float(params.get("crit_chance", 0.0)) * maxf(float(params.get("crit_damage_multiplier", 1.0)) - 1.0, 0.0)
	var interval := maxf(float(config.get("fire_interval", 1.0)) / maxf(float(params.get("attack_speed", 1.0)), 0.1), 0.18)
	var direct_dps := base_damage * crit_factor / interval
	if _is_pure_summon_weapon(config):
		direct_dps = 0.0
	elif str(config.get("summon_role", "")) != "":
		direct_dps *= _budget_summon_role_damage_factor(config, params, stats)
	var hit_model := _budget_hit_model(config)
	var melee_unique_budget := _budget_melee_unique_bonus(config)
	var dot_dps := _budget_dot_dps(config, params, interval)
	var pool_dps := _budget_pool_dps(config, params, interval)
	var summon_dps := _budget_summon_dps(config, params, stats)
	var solo_dps := direct_dps * float(hit_model.get("solo_hits", 1.0)) * float(melee_unique_budget.get("solo", 1.0)) + dot_dps + pool_dps + summon_dps
	var aoe_dps := direct_dps * float(hit_model.get("five_hits", 1.0)) * float(melee_unique_budget.get("aoe", 1.0)) + dot_dps * float(hit_model.get("dot_targets", 1.0)) + pool_dps * float(hit_model.get("pool_targets", 1.0)) + summon_dps * float(hit_model.get("summon_targets", 1.0))
	var ultimate := _budget_ultimate_dps(character_id, params)
	solo_dps += float(ultimate.get("solo", 0.0))
	aoe_dps += float(ultimate.get("aoe", 0.0))
	if apply_budget:
		solo_dps *= float(config.get("budget_solo_multiplier", 1.0))
		aoe_dps *= float(config.get("budget_aoe_multiplier", 1.0))
	return {
		"solo_dps": snappedf(solo_dps, 0.01),
		"aoe_dps": snappedf(aoe_dps, 0.01),
		"ehp": snappedf(_budget_ehp(config, params), 0.01),
		"interval": snappedf(interval, 0.001),
		"direct_dps": snappedf(direct_dps, 0.01),
		"hit_model": hit_model,
	}


static func estimate_crowd_clear_budget(character_id: String, weapon_config: Dictionary, target_count: int, apply_budget := true) -> Dictionary:
	return estimate_crowd_clear_budget_for_stats(character_id, weapon_config, target_count, base_stats(character_id), apply_budget)


static func estimate_crowd_clear_budget_for_stats(character_id: String, weapon_config: Dictionary, target_count: int, stats: Dictionary, apply_budget := true) -> Dictionary:
	var count: int = maxi(target_count, 1)
	var profile := class_budget_profile(character_id)
	var metrics := estimate_weapon_budget_for_stats(character_id, weapon_config, stats, apply_budget)
	var tuning: Dictionary = weapon_config.get("budget_tuning", {})
	var aoe_target := float(tuning.get(
		"aoe_target",
		BALANCE_BASE_AOE_DPS * float(profile.get("aoe_target", 1.0)) * float(profile.get("damage_budget", 1.0))
	))
	var crowd_dps := maxf(float(metrics.get("aoe_dps", 0.0)) * _crowd_clear_density_factor(weapon_config, count), 0.001)
	var target_dps := maxf(aoe_target * _crowd_clear_target_factor(weapon_config, count), 0.001)
	var total_hp := CROWD_CLEAR_ENEMY_HP * float(count)
	var cct := total_hp / crowd_dps
	var target_cct := total_hp / target_dps
	return {
		"target_count": count,
		"crowd_dps": snappedf(crowd_dps, 0.01),
		"target_dps": snappedf(target_dps, 0.01),
		"cct": snappedf(cct, 0.01),
		"target_cct": snappedf(target_cct, 0.01),
		"cct_dev": snappedf(cct / maxf(target_cct, 0.001) - 1.0, 0.001),
		"enemy_hp": CROWD_CLEAR_ENEMY_HP,
	}


static func crowd_clear_counts() -> Array:
	return CROWD_CLEAR_TARGET_COUNTS.duplicate(true)


static func _crowd_clear_density_factor(config: Dictionary, target_count: int) -> float:
	var mode := str(config.get("attack_mode", config.get("attack_shape", "single")))
	var archetype := weapon_archetype(config)
	var count := float(maxi(target_count, 1))
	var factor := 1.0
	if count >= 10.0:
		factor *= 0.96
	if count >= 20.0:
		factor *= 0.94
	match archetype:
		"aoe", "aura":
			factor *= 1.05
		"summon":
			factor *= 0.96
		"beam":
			factor *= 0.98
		"melee":
			factor *= 0.98
	if ["sniper_lockshot", "moon_crossbow", "drain_link"].has(mode):
		factor *= 0.92
	elif ["aoe_projectile", "grenade_cook", "smoke_bomb", "meteor_shards", "bio_spore_bloom", "engineer_pressure_mines"].has(mode):
		factor *= 1.04
	return clampf(factor, 0.82, 1.12)


static func _crowd_clear_target_factor(config: Dictionary, target_count: int) -> float:
	var archetype := weapon_archetype(config)
	var count := float(maxi(target_count, 1))
	var factor := 1.0
	if count >= 20.0 and ["aoe", "aura", "summon"].has(archetype):
		factor = 1.04
	return factor


static func _budget_hit_model(config: Dictionary) -> Dictionary:
	var mode := str(config.get("attack_mode", config.get("attack_shape", "single")))
	var attack_range := float(config.get("attack_range", 240.0))
	var aoe_radius := float(config.get("aoe_radius", 120.0))
	match mode:
		"frustum":
			var outer_width := float(config.get("outer_width", aoe_radius))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + outer_width / 290.0, 1.0, 5.0)}
		"sweep":
			var sweep := float(config.get("sweep_degrees", config.get("cone_degrees", 90.0)))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + (sweep / 45.0) * (attack_range / 320.0), 1.0, 5.0)}
		"circle", "pulse":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 72.0, 1.0, 5.0)}
		"strip":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + float(config.get("inner_width", 60.0)) / 160.0, 1.0, 2.1)}
		"aoe_projectile":
			var projectile_count := float(config.get("projectile_count", 1.0))
			var blast_hits := clampf(1.0 + aoe_radius / 145.0, 1.0, 3.0)
			return {"solo_hits": 1.0, "five_hits": clampf(projectile_count * blast_hits, 1.0, 5.0), "pool_targets": clampf(1.0 + aoe_radius / 130.0, 1.0, 4.0)}
		"homing_curse":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 180.0, 1.0, 2.0), "dot_targets": 1.0}
		"beam":
			var beam_count := float(config.get("beam_count", 1.0))
			var pierce := float(config.get("pierce_count", 1.0))
			return {"solo_hits": clampf(beam_count, 1.0, 2.0), "five_hits": clampf(beam_count * pierce, 1.0, 5.0)}
		"sound_wave":
			var wave_width := float(config.get("wave_width", 180.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + wave_width / 78.0, 1.0, 5.0)}
		"amp":
			var active_ratio := float(config.get("amp_lifetime", 6.0)) / maxf(float(config.get("fire_interval", 2.0)), 0.25)
			return {"solo_hits": clampf(active_ratio / 4.0, 1.0, 2.0), "five_hits": clampf((1.0 + aoe_radius / 80.0) * active_ratio / 3.5, 1.0, 5.0)}
		"boomerang":
			return {"solo_hits": 2.0, "five_hits": clampf(2.0 + float(config.get("beam_width", 48.0)) / 36.0, 2.0, 4.0)}
		"stab_flurry":
			var targets := float(config.get("projectile_count", 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(targets, 1.0, 4.0), "dot_targets": clampf(targets, 1.0, 4.0)}
		"dot_beam":
			var pierce := float(config.get("pierce_count", 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(pierce, 1.0, 5.0), "dot_targets": clampf(pierce, 1.0, 5.0)}
		"drain_link":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + float(config.get("beam_width", 40.0)) / 120.0, 1.0, 1.6), "dot_targets": 1.0}
		"trap":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 85.0, 1.0, 4.2)}
		"suppression_burst":
			var burst_count := float(config.get("projectile_count", 3.0))
			var suppression_width := float(config.get("suppression_width", 120.0))
			return {"solo_hits": clampf(burst_count, 1.0, 4.0), "five_hits": clampf(burst_count * (1.0 + suppression_width / 210.0), 1.0, 5.0)}
		"grenade_cook":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 72.0, 1.0, 5.0)}
		"bayonet_brace":
			var brace_width := float(config.get("beam_width", 120.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + brace_width / 56.0, 1.0, 4.0)}
		"coin_ricochet":
			var chain_count := float(config.get("projectile_count", 3.0))
			return {"solo_hits": 1.0, "five_hits": clampf(chain_count * 0.76, 1.0, 5.0)}
		"shadow_backstab":
			return {"solo_hits": 1.22, "five_hits": clampf(1.22 + aoe_radius / 150.0, 1.22, 3.0)}
		"smoke_bomb":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 84.0, 1.0, 4.4)}
		"elemental_orbit":
			var orbit_ticks := float(config.get("storm_ticks", 4.0))
			return {"solo_hits": clampf(orbit_ticks * 0.55, 1.0, 3.0), "five_hits": clampf(1.0 + aoe_radius / 55.0, 1.0, 5.0)}
		"prism_rift":
			var prism_width := float(config.get("beam_width", 64.0))
			return {"solo_hits": 1.05, "five_hits": clampf(2.0 + prism_width / 48.0, 2.0, 5.0)}
		"meteor_shards":
			var meteor_shards := float(config.get("shard_count", 3.0))
			return {"solo_hits": 1.06, "five_hits": clampf(1.0 + aoe_radius / 95.0 + meteor_shards * 0.32, 1.0, 5.0)}
		"sniper_lockshot":
			return {"solo_hits": 1.34, "five_hits": clampf(1.34 + float(config.get("beam_width", 34.0)) / 38.0, 1.34, 2.4)}
		"sniper_kill_zone":
			var kill_zone_shots := float(config.get("projectile_count", 3.0))
			return {"solo_hits": 1.0, "five_hits": clampf(kill_zone_shots * 0.82, 1.0, 4.2)}
		"sniper_split_round":
			var split_targets := float(config.get("split_count", 3.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + split_targets * 0.55, 1.0, 3.4)}
		"priest_sanctify":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 78.0, 1.0, 4.8)}
		"priest_ward":
			var ward_ticks := float(config.get("storm_ticks", 3.0))
			return {"solo_hits": clampf(ward_ticks * 0.72, 1.0, 2.6), "five_hits": clampf(1.0 + aoe_radius / 70.0, 1.0, 4.5)}
		"priest_prayer_chain":
			var prayer_jumps := float(config.get("projectile_count", 4.0))
			return {"solo_hits": 1.0, "five_hits": clampf(prayer_jumps * 0.72, 1.0, 4.2)}
		"bio_spore_bloom":
			var bloom_ticks := float(config.get("storm_ticks", 3.0))
			return {"solo_hits": clampf(1.0 + bloom_ticks * 0.34, 1.0, 2.4), "five_hits": clampf(1.0 + aoe_radius / 58.0, 1.0, 5.0)}
		"bio_sample_dart":
			var analysis_pulses := float(config.get("projectile_count", 2.0))
			return {"solo_hits": clampf(1.0 + analysis_pulses * 0.52, 1.0, 2.5), "five_hits": clampf(1.0 + analysis_pulses * 0.72 + aoe_radius / 115.0, 1.0, 4.8)}
		"bio_symbiote_web":
			var web_links := float(config.get("projectile_count", 4.0))
			return {"solo_hits": 1.18, "five_hits": clampf(1.0 + web_links * 0.62, 1.0, 4.6)}
		"robot_magnetic_anchor":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 80.0, 1.0, 4.8)}
		"robot_compression_line":
			var compression_width := float(config.get("suppression_width", 220.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + compression_width / 82.0, 1.0, 4.6)}
		"robot_reactor_vent":
			var vent_count := float(config.get("projectile_count", 4.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + vent_count * 0.70 + aoe_radius / 150.0, 1.0, 5.0)}
		"engineer_sentry_link":
			var sentry_shots := float(config.get("projectile_count", 4.0))
			return {"solo_hits": clampf(sentry_shots * 0.66, 1.0, 3.2), "five_hits": clampf(sentry_shots * 0.96, 1.0, 5.0)}
		"engineer_repair_drone":
			var drone_links := float(config.get("projectile_count", 4.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + drone_links * 0.68, 1.0, 4.6)}
		"engineer_pressure_mines":
			var mine_count := float(config.get("projectile_count", 3.0))
			return {"solo_hits": 1.0, "five_hits": clampf(mine_count * (1.0 + aoe_radius / 170.0), 1.0, 5.0)}
		_:
			if int(config.get("max_summons", 0)) > 0:
				return {"solo_hits": 1.0, "five_hits": clampf(1.0 + float(config.get("max_summons", 1)) * 0.8, 1.0, 3.5), "summon_targets": clampf(float(config.get("max_summons", 1)), 1.0, 4.0)}
	return {"solo_hits": 1.0, "five_hits": 1.0}


static func _budget_melee_unique_bonus(config: Dictionary) -> Dictionary:
	var solo_bonus := 1.0
	var aoe_bonus := 1.0
	var close_multiplier := float(config.get("melee_close_damage_multiplier", 1.0))
	if float(config.get("melee_close_bonus_radius", 0.0)) > 0.0 and close_multiplier > 1.0:
		var close_uptime := 0.58 if weapon_archetype(config) == "melee" else 0.34
		solo_bonus += (close_multiplier - 1.0) * close_uptime
		aoe_bonus += (close_multiplier - 1.0) * close_uptime
	var execute_multiplier := float(config.get("melee_execute_multiplier", 1.0))
	var execute_threshold := float(config.get("melee_execute_threshold", 0.0))
	if execute_threshold > 0.0 and execute_multiplier > 1.0:
		var execute_uptime := clampf(execute_threshold, 0.0, 0.55) * 0.72
		solo_bonus += (execute_multiplier - 1.0) * execute_uptime
		aoe_bonus += (execute_multiplier - 1.0) * execute_uptime
	var followup_radius := float(config.get("melee_arc_followup_radius", 0.0))
	var followup_multiplier := float(config.get("melee_arc_followup_multiplier", 0.0))
	if followup_radius > 0.0 and followup_multiplier > 0.0:
		var followup_targets := clampf(followup_radius / 115.0, 0.45, 2.4)
		aoe_bonus += followup_multiplier * followup_targets
	return {"solo": solo_bonus, "aoe": aoe_bonus}


static func _budget_dot_dps(config: Dictionary, params: Dictionary, interval: float) -> float:
	var ticks := float(config.get("dot_ticks", 0.0))
	if ticks <= 0.0:
		return 0.0
	return float(params.get("dot_damage", 1.0)) * ticks / maxf(interval, 0.18)


static func _budget_pool_dps(config: Dictionary, params: Dictionary, interval: float) -> float:
	if not bool(config.get("leaves_pool", false)):
		return 0.0
	var tick_interval := maxf(float(config.get("pool_tick_interval", 0.6)), 0.18)
	var uptime := minf(float(config.get("pool_duration", 3.0)) / maxf(interval, 0.18), 1.0)
	return float(params.get("dot_damage", 1.0)) / tick_interval * uptime


static func _budget_summon_dps(config: Dictionary, params: Dictionary, stats := {}) -> float:
	if int(config.get("max_summons", 0)) <= 0 and not config.has("summon_damage_multiplier"):
		return 0.0
	var summon_count: float = maxf(float(config.get("max_summons", 1.0)), 1.0) + floor(float(params.get("summon_amount", 0.0)) / 4.0)
	var summon_amount := float(params.get("summon_amount", 0.0))
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var attack_interval := maxf(float(config.get("summon_attack_interval", 0.45)) / (1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)), 0.18)
	var role_factor := _budget_summon_role_damage_factor(config, params, stats)
	var summon_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) * float(config.get("summon_damage_multiplier", 0.36)) * role_factor
	return summon_count * summon_damage / attack_interval


static func _is_pure_summon_weapon(config: Dictionary) -> bool:
	return config.has("summon_damage_multiplier") and not config.has("attack_mode") and not config.has("attack_shape")


static func _budget_summon_role_damage_factor(config: Dictionary, params: Dictionary, stats := {}) -> float:
	var summon_amount := float(params.get("summon_amount", 0.0))
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var knowledge := float(stats.get("knowledge", 0.0)) if stats is Dictionary else 0.0
	var intelligence := float(stats.get("intelligence", 0.0)) if stats is Dictionary else 0.0
	var energy := float(stats.get("energy", 0.0)) if stats is Dictionary else 0.0
	# SCRUM-546: Лидерство — главный драйвер силы саммонов. Коэффициент и потолок
	# подняты (0.020/0.42 → 0.060/1.15), чтобы прокачка саммонера ощутимо усиливала
	# питомцев. Зеркалит summoner_weapon._summon_profile (тот же runtime-расчёт).
	var leadership_damage := 1.0 + minf(leadership * 0.060, 1.15)
	var attribute_damage := 1.0 + minf(summon_amount * 0.016 + knowledge * 0.004 + intelligence * 0.004 + energy * 0.003, 0.40)
	return float(config.get("summon_role_damage_multiplier", 1.0)) * leadership_damage * attribute_damage


static func _budget_ultimate_dps(character_id: String, params: Dictionary) -> Dictionary:
	var config := ultimate_config(character_id)
	var multiplier := float(params.get("ultimate_multiplier", 1.0))
	var base_damage := maxf(maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0))), float(params.get("sound_wave_damage", 1.0)))
	var damage := base_damage * float(config.get("damage", 1.0)) * multiplier
	var target_count := float(config.get("target_count", 5.0))
	if not config.has("target_count"):
		target_count = clampf(1.0 + float(config.get("radius", 250.0)) / 115.0, 1.0, 5.0)
	var charge_window_factor := 0.42
	return {
		"solo": damage * charge_window_factor / BALANCE_WINDOW_SECONDS,
		"aoe": damage * minf(target_count, 5.0) * charge_window_factor / BALANCE_WINDOW_SECONDS,
	}


static func _budget_ehp(config: Dictionary, params: Dictionary) -> float:
	var health := float(params.get("health_point", 1.0))
	var defense := clampf(float(params.get("defense", 0.0)), 0.0, SURVIVABILITY_DEFENSE_CAP)
	var dodge := clampf(float(params.get("dodge", 0.0)), 0.0, SURVIVABILITY_DODGE_CAP)
	var absorb := float(params.get("absorb", 0.0))
	var regen := float(params.get("regeneration", 0.0))
	var lifesteal := (
		float(config.get("heal_percent_of_damage", 0.0)) * 120.0
		+ float(config.get("heal_percent_on_attack", 0.0)) * health * 2.0
	) * WEAPON_DRAIN_HEAL_MULTIPLIER
	return health / maxf(1.0 - defense, 0.10) / maxf(1.0 - dodge, 0.10) + absorb * 6.0 + regen * BALANCE_WINDOW_SECONDS + lifesteal


static func weapon(character_id: String, weapon_id: String) -> Dictionary:
	var weapons: Dictionary = WEAPONS_BY_CLASS.get(character_id, BERSERK_WEAPONS)
	var fallback_id := str(weapons.keys()[0])
	var config: Dictionary = weapons.get(weapon_id, weapons[fallback_id]).duplicate(true)
	var tuning := budget_tuning_for(character_id, config)
	config["character_id"] = character_id
	config["budget_profile"] = class_budget_profile(character_id)
	config["budget_damage_multiplier"] = float(tuning.get("damage_multiplier", 1.0))
	config["budget_solo_multiplier"] = float(tuning.get("solo_budget_multiplier", 1.0))
	config["budget_aoe_multiplier"] = float(tuning.get("aoe_budget_multiplier", 1.0))
	config["budget_tuning"] = tuning
	return config


static func _class_stat_growth_scalar(character_id: String, stat_id: String) -> float:
	var class_scalars = CLASS_LEVEL_STAT_GROWTH_SCALARS.get(character_id, 1.0)
	if class_scalars is Dictionary:
		return float((class_scalars as Dictionary).get(stat_id, 1.0))
	return float(class_scalars)


static func _scaled_stat_growth(character_id: String, stat_id: String, value: float, base_stats_map: Dictionary) -> float:
	var base_value := float(base_stats_map.get(stat_id, value))
	var delta := value - base_value
	if delta <= 0.0:
		return value
	return base_value + delta * _class_stat_growth_scalar(character_id, stat_id)


static func derived_parameters(stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Dictionary:
	var character_id := str(weapon_config.get("character_id", ""))
	var base_for_growth := base_stats(character_id) if character_id != "" else {}
	var strength := float(stats.get("strength", 0.0))
	var agility := float(stats.get("agility", 0.0))
	var intelligence := float(stats.get("intelligence", 0.0))
	var perception := float(stats.get("perception", 0.0))
	var energy := float(stats.get("energy", 0.0))
	var knowledge := float(stats.get("knowledge", 0.0))
	var endurance := float(stats.get("endurance", 0.0))
	var leadership := float(stats.get("leadership", 0.0))
	if character_id != "":
		strength = _scaled_stat_growth(character_id, "strength", strength, base_for_growth)
		agility = _scaled_stat_growth(character_id, "agility", agility, base_for_growth)
		intelligence = _scaled_stat_growth(character_id, "intelligence", intelligence, base_for_growth)
		perception = _scaled_stat_growth(character_id, "perception", perception, base_for_growth)
		energy = _scaled_stat_growth(character_id, "energy", energy, base_for_growth)
		knowledge = _scaled_stat_growth(character_id, "knowledge", knowledge, base_for_growth)
		endurance = _scaled_stat_growth(character_id, "endurance", endurance, base_for_growth)
		leadership = _scaled_stat_growth(character_id, "leadership", leadership, base_for_growth)
	var weapon_damage_multiplier := float(weapon_config.get("damage_multiplier", 1.0)) * float(weapon_config.get("budget_damage_multiplier", 1.0))
	var passive_mods: Dictionary = weapon_config.get("passive_mods", {})

	# upgrade_*_exponent (>1 у молота) усиливает рост именно от апгрейдов забега,
	# не трогая пассивы оружия и стартовые значения.
	var upgrade_damage_exponent := float(weapon_config.get("upgrade_damage_exponent", 1.0))
	var upgrade_aoe_exponent := float(weapon_config.get("upgrade_aoe_exponent", 1.0))
	# SCRUM-503: diminishing returns на ЗАБЕГОВУЮ часть боевых множителей (до экспоненты
	# апгрейда и до пассивов оружия) — гасит мультипликативный runaway идеального билда.
	# Тождественно при множителе 1.0 (пустые run_modifiers формульного гейта) → база и
	# формульные коридоры не меняются. Пассивы оружия (passive_mods) НЕ капятся — это база.
	var run_damage_multiplier := _soft_capped_run_multiplier(float(run_modifiers.get("damage_multiplier", 1.0)), RUN_DAMAGE_MULT_SOFTCAP, RUN_DAMAGE_MULT_KNEE)
	var run_attack_speed_multiplier := _soft_capped_run_multiplier(float(run_modifiers.get("attack_speed_multiplier", 1.0)), RUN_ATTACK_SPEED_MULT_SOFTCAP, RUN_ATTACK_SPEED_MULT_KNEE)
	var damage_multiplier := pow(run_damage_multiplier, upgrade_damage_exponent) * float(passive_mods.get("damage_multiplier", 1.0))
	# «Кровавый Рубеж» (tier 3): бонус урона активен, пока HP ниже порога (low_hp_active ставит player).
	damage_multiplier *= 1.0 + float(run_modifiers.get("low_hp_damage_bonus", 0.0)) * float(run_modifiers.get("low_hp_active", 0.0))
	var attack_speed_multiplier := run_attack_speed_multiplier * float(passive_mods.get("attack_speed_multiplier", 1.0))
	var move_speed_multiplier := float(run_modifiers.get("move_speed_multiplier", 1.0)) * float(passive_mods.get("move_speed_multiplier", 1.0))
	# «Призрачный Шаг» (tier 3): рывок скорости после уворота (dodge_rush_active ставит player).
	move_speed_multiplier *= 1.0 + float(run_modifiers.get("dodge_rush_bonus", 0.0)) * float(run_modifiers.get("dodge_rush_active", 0.0))
	# SCRUM-500 «Импульс Крита»: короткий рывок скорости по криту (crit_speed_burst_active ставит player).
	move_speed_multiplier *= 1.0 + float(run_modifiers.get("crit_speed_burst", 0.0)) * float(run_modifiers.get("crit_speed_burst_active", 0.0))
	var max_health_multiplier := float(run_modifiers.get("max_health_multiplier", 1.0)) * float(passive_mods.get("max_health_multiplier", 1.0))
	var range_multiplier := float(run_modifiers.get("range_multiplier", 1.0)) * float(passive_mods.get("range_multiplier", 1.0))
	var aoe_radius_multiplier := pow(float(run_modifiers.get("aoe_radius_multiplier", 1.0)), upgrade_aoe_exponent) * float(passive_mods.get("aoe_radius_multiplier", 1.0))
	var knockback_multiplier := float(run_modifiers.get("knockback_multiplier", 1.0)) * float(passive_mods.get("knockback_multiplier", 1.0))
	var defense_flat := float(run_modifiers.get("defense_flat", 0.0)) + float(passive_mods.get("defense_flat", 0.0))
	var absorb_flat := float(run_modifiers.get("absorb_flat", 0.0)) + float(passive_mods.get("absorb_flat", 0.0))
	var regeneration_flat := float(run_modifiers.get("regeneration_flat", 0.0)) + float(passive_mods.get("regeneration_flat", 0.0))
	var pickup_radius_flat := float(run_modifiers.get("pickup_radius_flat", 0.0)) + float(passive_mods.get("pickup_radius_flat", 0.0))
	var max_health_flat := float(run_modifiers.get("max_health_flat", 0.0)) + float(passive_mods.get("max_health_flat", 0.0))
	var projectile_speed_flat := float(run_modifiers.get("projectile_speed_flat", 0.0)) + float(passive_mods.get("projectile_speed_flat", 0.0))
	var aura_radius_flat := float(run_modifiers.get("aura_radius_flat", 0.0)) + float(passive_mods.get("aura_radius_flat", 0.0))
	var buff_power_flat := float(run_modifiers.get("buff_power_flat", 0.0)) + float(passive_mods.get("buff_power_flat", 0.0))
	var run_dot_damage_flat := minf(maxf(float(run_modifiers.get("dot_damage_flat", 0.0)), 0.0), 12.0) + minf(float(run_modifiers.get("dot_damage_flat", 0.0)), 0.0)
	var run_dot_speed_flat := minf(maxf(float(run_modifiers.get("dot_speed_flat", 0.0)), 0.0), 1.0) + minf(float(run_modifiers.get("dot_speed_flat", 0.0)), 0.0)
	var dot_damage_flat := run_dot_damage_flat + float(passive_mods.get("dot_damage_flat", 0.0))
	var dot_speed_flat := run_dot_speed_flat + float(passive_mods.get("dot_speed_flat", 0.0))
	var crit_chance_flat := (float(run_modifiers.get("crit_chance_flat", 0.0)) + float(passive_mods.get("crit_chance_flat", 0.0))) * CRIT_FLAT_EFFECTIVENESS
	var crit_damage_flat := float(run_modifiers.get("crit_damage_flat", 0.0)) + float(passive_mods.get("crit_damage_flat", 0.0))
	if passive_mods.has("crit_damage_multiplier"):
		crit_damage_flat += float(passive_mods.get("crit_damage_multiplier", 1.0)) - 1.0
	# SCRUM-524: урон каждого ТИПА масштабируется ТОЛЬКО от своего атрибута.
	# Изоляция по типам урона — жёсткий инвариант: прокачка атрибута типа X меняет
	# урон ТОЛЬКО типа X и НИКАК не влияет на остальные типы (см. систему типов
	# урона SCRUM-523 и гейт tests/damage_type_isolation_test.gd). Поэтому здесь
	# НЕТ «splash»-вкладов чужих атрибутов и НЕТ архетип-множителя: он зависел от
	# ВСЕХ атрибутов и одинаково домножал все три типа, протекая между ними.
	# Владельцы атрибутов по типам: сила→физический, интеллект→магический,
	# восприятие+энергия→звуковой, знание→периодический (DoT). damage_flat и
	# dot_damage_flat — забеговые/пассивные модификаторы (не атрибуты), поэтому
	# общий вклад в типы инвариант изоляции не нарушает (тест проверяет атрибуты).
	# Баланс по DPS добирается классовым budget-множителем (budget_tuning_for).
	var universal_damage_flat := float(run_modifiers.get("damage_flat", 0.0))
	var physical_base := 15.0 * strength / 10.0
	var magic_base := 14.0 * intelligence / 10.0
	var sound_base := perception + energy
	var universal_attack_stat := agility + energy * 0.18 + perception * 0.10 + endurance * 0.04
	var dot_attribute_base := 4.0 + knowledge * 0.65 + dot_damage_flat

	return {
		"damage": physical_base * weapon_damage_multiplier * damage_multiplier + universal_damage_flat,
		"magic_damage": magic_base * weapon_damage_multiplier * damage_multiplier + universal_damage_flat,
		"sound_wave_damage": sound_base * weapon_damage_multiplier * damage_multiplier + universal_damage_flat,
		"attack_speed": max(0.1, (9.0 * 3.0 * universal_attack_stat / 100.0) * attack_speed_multiplier),
		"crit_chance": effective_crit_chance(0.04 + agility * 0.0075 + crit_chance_flat),
		"crit_damage_multiplier": effective_crit_damage_multiplier(agility, crit_damage_flat),
		"move_speed": (282.0 + agility * 6.2) * move_speed_multiplier,
		"dodge": effective_dodge(0.02 + agility * 0.010 + float(run_modifiers.get("dodge_flat", 0.0))),
		"defense": effective_defense(0.04 + endurance * 0.018 + defense_flat),
		"health_point": (50.0 * endurance / 4.0 + max_health_flat) * max_health_multiplier,
		"attack_range": (float(weapon_config.get("attack_range", 240.0)) + perception * 2.5 + intelligence * 0.35 + endurance * 0.25 + leadership * 0.35) * range_multiplier,
		"aoe_radius": (float(weapon_config.get("aoe_radius", 190.0)) + perception * 3.5 + intelligence * 0.45 + knowledge * 0.35 + leadership * 0.30) * aoe_radius_multiplier,
		"pickup_radius": 105.0 + perception * 7.0 + pickup_radius_flat,
		"dot_damage": max(1.0, dot_attribute_base * damage_multiplier),
		"dot_speed": max(0.45, 0.65 + knowledge * 0.08 + energy * 0.015 + agility * 0.010 + dot_speed_flat),
		"projectile_speed": float(weapon_config.get("projectile_speed", 460.0)) + perception * 18.0 + agility * 9.0 + energy * 4.0 + knowledge * 2.0 + projectile_speed_flat,
		"aura_radius": (float(weapon_config.get("aoe_radius", 180.0)) + leadership * 5.0 + perception * 0.80 + energy * 0.65 + knowledge * 0.45 + aura_radius_flat) * aoe_radius_multiplier,
		"buff_power": 1.0 + leadership * 0.025 + knowledge * 0.006 + energy * 0.004 + buff_power_flat,
		"knockback_power": (float(weapon_config.get("knockback", 60.0)) + endurance * 4.0 + leadership * 3.0) * knockback_multiplier,
		"summon_amount": leadership + knowledge * 0.18 + intelligence * 0.12 + energy * 0.10,
		# SCRUM-546: профильное (growth-масштабированное) Лидерство как драйвер силы
		# саммонов — читается runtime deploy/sentry-пайплайном (class_weapon
		# ._summon_role_damage_factor) и саммон-профилем (summoner_weapon).
		"leadership": leadership,
		# Подключение полного набора атрибутов (аудит 2026-06-11):
		"absorb": effective_absorb(endurance, absorb_flat),
		"regeneration": effective_regeneration(knowledge, regeneration_flat),
		"vampiric_chance": effective_vampiric_chance(float(run_modifiers.get("vampiric_chance_flat", 0.0))),
		"vampiric_amount": float(run_modifiers.get("vampiric_amount_flat", 0.0)) * VAMPIRIC_BASE_HEAL_MULTIPLIER,
		"knockback_distance": (float(weapon_config.get("knockback", 60.0)) + endurance * 4.0 + leadership * 3.0) * knockback_multiplier * endurance / 20.0,
		"range_multiplier": range_multiplier,
		# Усиливает классовую ульту: урон, радиус, длительность или число целей.
		"ultimate_multiplier": 1.0 + energy * 0.02 + (strength + agility + intelligence + perception + knowledge + endurance + leadership) * 0.002 + float(run_modifiers.get("ultimate_flat", 0.0)),
	}


static func reward_pool(character_id := "") -> Array:
	var rewards := []
	for reward in STAT_REWARDS:
		if character_id != "" and not is_reward_relevant(reward, character_id):
			continue
		var stat_reward: Dictionary = reward.duplicate(true)
		stat_reward["kind"] = "stat"
		rewards.append(stat_reward)
	for artifact in ARTIFACTS:
		var artifact_reward: Dictionary = artifact.duplicate(true)
		artifact_reward["kind"] = "artifact"
		artifact_reward["weight"] = TIER_WEIGHTS.get(int(artifact.get("tier", 1)), 1.0)
		rewards.append(artifact_reward)
	return rewards


static func level_up_rewards(character_id := "") -> Array:
	var rewards := []
	for reward in LEVEL_UP_REWARDS:
		if character_id != "" and not is_reward_relevant(reward, character_id):
			continue
		rewards.append(reward.duplicate(true))
	return rewards


static func main_stat_level_up_rewards(_character_id := "") -> Array:
	# Редкий пул level-up: рост основной характеристики на +1. Помечены rare=true
	# для визуального выделения; классовая интерпретация считается на карточке.
	var rewards := []
	for stat_id in STAT_NAMES.keys():
		rewards.append({
			"id": "levelup_stat_%s" % stat_id,
			"title": "%s +1" % STAT_NAMES[stat_id],
			"description": "Редкий рост основной характеристики: +1 к параметру «%s»." % STAT_NAMES[stat_id],
			"kind": "stat",
			"stats": {stat_id: 1.0},
			"rare": true,
		})
	return rewards


# Виды мини-элиток (свита Возвышения L7). Data-driven: каждый вид задаёт базовую
# elite-сцену (placeholder-арт до SCRUM-156), профиль статов и тинт-идентичность.
# `behavior` — ближайший существующий elite-паттерн атаки (бихейвиор-полиш —
# парный art-пасс); `tint` — RGB множитель спрайта для различимости.
static func mini_elite_kinds() -> Array:
	var kinds := []
	for kind in MINI_ELITE_KINDS:
		kinds.append(kind.duplicate(true))
	return kinds


static func mini_elite_kind_by_id(kind_id: String) -> Dictionary:
	for kind in MINI_ELITE_KINDS:
		if str(kind.get("id", "")) == kind_id:
			return kind.duplicate(true)
	return {}


static func enemy_size_profile(profile_id: String) -> Dictionary:
	var fallback: Dictionary = ENEMY_SIZE_PROFILES.get("ordinary", {"scale": 1.0}) as Dictionary
	var profile: Dictionary = ENEMY_SIZE_PROFILES.get(profile_id, fallback) as Dictionary
	return profile.duplicate(true)


static func enemy_mechanic_catalog() -> Dictionary:
	return ENEMY_MECHANIC_CATALOG.duplicate(true)


static func elite_attack_config(behavior_id: String) -> Dictionary:
	var config: Dictionary = ELITE_ATTACK_CONFIGS.get(behavior_id, {}) as Dictionary
	return config.duplicate(true)


static func unique_encounter_pattern(entity_id: String) -> Dictionary:
	var pattern: Dictionary = UNIQUE_ENCOUNTER_PATTERNS.get(entity_id, {}) as Dictionary
	return pattern.duplicate(true)


static func unique_encounter_patterns() -> Dictionary:
	return UNIQUE_ENCOUNTER_PATTERNS.duplicate(true)


static func shop_items(route_stage := 0) -> Array:
	var items := []
	for item in SHOP_ITEMS:
		var shop_item: Dictionary = item.duplicate(true)
		shop_item["cost"] = stage_scaled_cost(int(shop_item.get("cost", 0)), route_stage)
		items.append(shop_item)
	for artifact in ARTIFACTS:
		var shop_artifact: Dictionary = artifact.duplicate(true)
		shop_artifact["cost"] = stage_scaled_cost(int(shop_artifact.get("cost", COST_BY_TIER.get(int(shop_artifact.get("tier", 1)), 30))), route_stage)
		shop_artifact["kind"] = "artifact"
		shop_artifact["weight"] = TIER_WEIGHTS.get(int(shop_artifact.get("tier", 1)), 1.0)
		items.append(shop_artifact)
	return items


static func elite_artifact_choices(route_stage: int, count := 3) -> Array:
	var pool := []
	var scale := stage_scale(route_stage)
	for artifact in ARTIFACTS:
		var candidate: Dictionary = artifact.duplicate(true)
		var tier := int(candidate.get("tier", 1))
		var depth_weight := 1.0
		if tier == 2:
			depth_weight = 0.75 + scale * 0.25
		elif tier == 3:
			depth_weight = 0.22 + maxf(float(route_stage) - 2.0, 0.0) * 0.18
		candidate["kind"] = "artifact"
		candidate["weight"] = maxf(TIER_WEIGHTS.get(tier, 1.0) * depth_weight, 0.05)
		pool.append(candidate)
	var choices := []
	while choices.size() < count and not pool.is_empty():
		var total_weight := 0.0
		for reward in pool:
			total_weight += float(reward.get("weight", 1.0))
		var roll := randf() * maxf(total_weight, 0.001)
		var cursor := 0.0
		var selected_index := 0
		for index in range(pool.size()):
			cursor += float(pool[index].get("weight", 1.0))
			if roll <= cursor:
				selected_index = index
				break
		choices.append(pool[selected_index])
		pool.remove_at(selected_index)
	return choices


static func display_stats(stats: Dictionary) -> String:
	var parts := []
	for stat_id in STAT_NAMES.keys():
		parts.append("%s %.0f" % [STAT_NAMES[stat_id], float(stats.get(stat_id, 0.0))])
	return " | ".join(parts)


static func display_derived_parameters(parameters: Dictionary) -> String:
	return "Урон %.1f | Магия %.1f | Звук %.1f | Атаки %.2f | Крит %.0f%% | Защита %.0f%% | Дальность %.0f | Область %.0f | Подбор %.0f" % [
		float(parameters.get("damage", 0.0)),
		float(parameters.get("magic_damage", 0.0)),
		float(parameters.get("sound_wave_damage", 0.0)),
		float(parameters.get("attack_speed", 0.0)),
		float(parameters.get("crit_chance", 0.0)) * 100.0,
		float(parameters.get("defense", 0.0)) * 100.0,
		float(parameters.get("attack_range", 0.0)),
		float(parameters.get("aoe_radius", 0.0)),
		float(parameters.get("pickup_radius", 0.0)),
	]
