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
const CLASS_TRAITS := CharacterData.CLASS_TRAITS  # SCRUM-935: data-driven class traits
const ATTRIBUTE_PRIORITIES := CharacterData.ATTRIBUTE_PRIORITIES
const ATTRIBUTE_PRIORITY_REASONS := CharacterData.ATTRIBUTE_PRIORITY_REASONS
const ATTRIBUTE_REGISTRY := CharacterData.ATTRIBUTE_REGISTRY  # SCRUM-695: канон-реестр атрибутов
const ATTRIBUTE_RELEVANCE := CharacterData.ATTRIBUTE_RELEVANCE  # SCRUM-695: матрица 2/8/7

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
const BOSS_HAZARD_MAX_HP_FRACTION := BalanceData.BOSS_HAZARD_MAX_HP_FRACTION  # FAN-1031 S2: кап зон/сламов босса долей max HP
# Compatibility re-exports; BalanceData is the single live owner of these
# defensive ceiling and diminishing-curve declarations.
const SURVIVABILITY_DEFENSE_CAP := BalanceData.SURVIVABILITY_DEFENSE_CAP
const SURVIVABILITY_DEFENSE_DIMINISH := BalanceData.SURVIVABILITY_DEFENSE_DIMINISH
const SURVIVABILITY_DODGE_CAP := BalanceData.SURVIVABILITY_DODGE_CAP
const SURVIVABILITY_DODGE_DIMINISH := BalanceData.SURVIVABILITY_DODGE_DIMINISH
const SMOKE_CLOUD_DODGE_CAP := BalanceData.SMOKE_CLOUD_DODGE_CAP  # SCRUM-897: кап уворота в дым-облаке Вора
const SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION := BalanceData.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION
const SURVIVABILITY_ABSORB_FLAT_DIMINISH := BalanceData.SURVIVABILITY_ABSORB_FLAT_DIMINISH
const SURVIVABILITY_REGEN_FLAT_MULTIPLIER := BalanceData.SURVIVABILITY_REGEN_FLAT_MULTIPLIER
const VAMPIRIC_CHANCE_CAP := BalanceData.VAMPIRIC_CHANCE_CAP
const VAMPIRIC_DAMAGE_HEAL_RATIO := BalanceData.VAMPIRIC_DAMAGE_HEAL_RATIO
const VAMPIRIC_HEAL_CAP_DEFAULT := BalanceData.VAMPIRIC_HEAL_CAP_DEFAULT
const VAMPIRIC_HEAL_CAP_HARD := BalanceData.VAMPIRIC_HEAL_CAP_HARD
const WEAPON_DRAIN_HEAL_MULTIPLIER := BalanceData.WEAPON_DRAIN_HEAL_MULTIPLIER
const CRIT_CHANCE_CAP := BalanceData.CRIT_CHANCE_CAP
const CRIT_CHANCE_CAP_MAX := BalanceData.CRIT_CHANCE_CAP_MAX
const CRIT_CHANCE_CAP_AGILITY_SCALE := BalanceData.CRIT_CHANCE_CAP_AGILITY_SCALE
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

const DefensiveAttributeRuntime := preload("res://scripts/defensive_attribute_runtime.gd")  # FAN-2287: защита/уворот/поглощение/реген/вампиризм вынесены под line-ratchet, точки ниже — делегаторы

# FAN-3923 (FD16): pure weapon-budget formulas (estimate, auto-tuning,
# crowd-clear, hit/dot/pool/summon/device models, EHP) live in
# WeaponBudgetModel; the budget entrypoints below are thin facades.
const WeaponBudgetModel := preload("res://scripts/progression/weapon_budget_model.gd")

# FAN-1891: снятые прогрессионные оси и геометрический контракт вынесены в
# ModifiersData (FAN-2171, line-ratchet этого файла).
const ModifiersData := preload("res://scripts/progression_data_modifiers.gd")

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
	# SCRUM-960: для семьи (rarity_scaling) возвращает запись КАК ЕСТЬ (корень =
	# т1-база + tiers) — материализация оффера происходит только в сэмплерах.
	for artifact in ARTIFACTS:
		if str(artifact.get("id", "")) == artifact_id:
			return artifact
	for item in SHOP_ITEMS:
		if str(item.get("id", "")) == artifact_id:
			return item
	return {}


# --- SCRUM-960: универсальные семьи артефактов с роллом редкости ---
# Семья (rarity_scaling:true, artifact_system_matrix §1.3) хранит tiers{1,2,3};
# тир роллится ПРИ ВЫДАЧЕ (offer-time) по нормализованным весам, оффер
# материализуется в плоскую запись — дальше пайплайн (карточки, магазин,
# apply_reward) работает без изменений. Вес самой семьи в пуле = 1.0.

# Ролл тира семьи. Пустой аргумент = канонические TIER_WEIGHTS (нормализация
# даёт ≈0.64/0.29/0.08); кастомные веса — для depth-логики элиток/сундуков.
static func roll_artifact_family_tier(weights: Dictionary = {}) -> int:
	var tier_weights: Dictionary = weights if not weights.is_empty() else TIER_WEIGHTS
	var tiers: Array = tier_weights.keys()
	tiers.sort()
	var total := 0.0
	for tier in tiers:
		total += maxf(float(tier_weights[tier]), 0.0)
	if total <= 0.0:
		return 1
	var roll := randf() * total
	var cursor := 0.0
	for tier in tiers:
		cursor += maxf(float(tier_weights[tier]), 0.0)
		if roll <= cursor:
			return int(tier)
	return int(tiers.back())


# Материализация оффера семьи на выбранном тире: плоская запись
# {id, title, tier, cost=COST_BY_TIER[tier], description, stats|mods,
#  rarity_scaling:true} — эффект тира ЗАМЕЩАЕТ корневой (т1-базовый).
# kind/weight не ставятся здесь — их добавляет вызывающий сэмплер.
static func materialize_family_offer(family: Dictionary, tier: int) -> Dictionary:
	var tiers: Dictionary = family.get("tiers", {}) as Dictionary
	var tier_key := tier if tiers.has(tier) else 1
	var tier_data: Dictionary = tiers.get(tier_key, {}) as Dictionary
	var offer: Dictionary = family.duplicate(true)
	offer.erase("tiers")
	offer.erase("stats")
	offer.erase("mods")
	offer["tier"] = tier_key
	offer["cost"] = int(COST_BY_TIER.get(tier_key, int(family.get("cost", 30))))
	offer["description"] = str(tier_data.get("description", family.get("description", "")))
	if tier_data.has("stats"):
		offer["stats"] = (tier_data.get("stats") as Dictionary).duplicate(true)
	if tier_data.has("mods"):
		offer["mods"] = (tier_data.get("mods") as Dictionary).duplicate(true)
	offer["rarity_scaling"] = true
	return offer


# --- Стартовые бооны забега (SCRUM-618) ---

static func canonical_start_boon_id(boon_id: String) -> String:
	match boon_id:
		"glass_edge":
			return "boon_glass_edge"
		_:
			return boon_id


static func start_boons(character_id := "") -> Array:
	if character_id == "":
		return START_BOONS
	var boons := []
	for boon in START_BOONS:
		if is_reward_relevant(boon, character_id):
			boons.append((boon as Dictionary).duplicate(true))
	return boons


static func start_boon_definition(boon_id: String) -> Dictionary:
	var canonical_id := canonical_start_boon_id(boon_id)
	for boon in START_BOONS:
		if str(boon.get("id", "")) == canonical_id:
			return boon
	return {}


# Mods выбранного боона (пустой dict, если боон не выбран/неизвестен — тождественность).
static func start_boon_mods(boon_id: String, character_id := "") -> Dictionary:
	if boon_id == "":
		return {}
	var boon := start_boon_definition(boon_id)
	if boon.is_empty():
		return {}
	if character_id != "" and not is_reward_relevant(boon, character_id):
		return {}
	return (boon.get("mods", {}) as Dictionary).duplicate(true)


static func damage_parameter_for(character_id: String) -> String:
	return str(CLASS_DAMAGE_PARAMETER.get(character_id, "damage"))



static func is_stat_relevant(stat_id: String, character_id: String) -> bool:
	return true


# SCRUM-862 + SCRUM-900 «Клятва чумного доктора»: реестр generic-сустейна,
# отрезанного trait'ом CLASS_TRAITS.*.generic_sustain_blocked (data-driven —
# сейчас только doctor). Три потребителя:
#   - is_reward_relevant: не предлагать такие награды в пулах level-up/артефактов;
#   - Player._apply_reward_mods / apply_meta_skill_modifiers: не применять моды
#     (is_blocked_sustain_mod_key), если награда не помечена doctor_friendly;
#   - derived_parameters: отрезать базовый пассивный реген (константа+knowledge).
# Пометка reward["doctor_friendly"] = true — явный допуск предмета для Доктора:
# оффер проходит фильтр, моды применяются в обычные run-ключи и работают штатно.
# Route/rest/shop-лечение (аптечки-пикапы, отдых на маршруте) сознательно НЕ
# блокируется — отсекается именно КОМБАТ/билд-сустейн (решение тикета).
const DOCTOR_FORBIDDEN_SUSTAIN_ATTRS := {
	"regeneration": true,
	"vampiric": true,  # FAN-1034: единая ось (мерж vampiric_amount + vampiric_chance)
}
const DOCTOR_FORBIDDEN_SUSTAIN_REWARD_IDS := {
	"leech_heart": true,
	"leech_fang": true,
	"field_kit": true,
	"vital_siphon": true,
	"breather_totem": true,
	"soul_harvest": true,
	"second_wind": true,
	"swiftfoot": true,
	"shop_heal": true,
}
const DOCTOR_FORBIDDEN_SUSTAIN_MOD_KEYS := {
	"regeneration_flat": true,
	"vampiric_chance_flat": true,
	"vampiric_amount_flat": true,
	"vampiric_heal_per_second_cap": true,
	"kill_heal_percent": true,
	"room_clear_heal_percent": true,
	"kill_streak_heal_every": true,
	"lowhp_regen_bonus": true,
	"heal_percent": true,
}


static func _is_doctor_forbidden_sustain_reward(reward: Dictionary) -> bool:
	var reward_id := str(reward.get("id", ""))
	if DOCTOR_FORBIDDEN_SUSTAIN_REWARD_IDS.has(reward_id):
		return true
	var attr_id := str(reward.get("attr", ""))
	if DOCTOR_FORBIDDEN_SUSTAIN_ATTRS.has(attr_id):
		return true
	var mods: Dictionary = reward.get("mods", {}) as Dictionary
	for key in mods.keys():
		if DOCTOR_FORBIDDEN_SUSTAIN_MOD_KEYS.has(str(key)):
			return true
	if reward.has("heal_percent"):
		return true
	return false


# SCRUM-900: data-driven чтение trait-флага «сустейн только от оружия».
static func class_blocks_generic_sustain(character_id: String) -> bool:
	return float((CLASS_TRAITS.get(character_id, {}) as Dictionary).get("generic_sustain_blocked", 0.0)) > 0.0


# SCRUM-900: запрещён ли run-ключ мода для класса с trait'ом plague_oath.
# Потребители — Player._apply_reward_mods / apply_meta_skill_modifiers.
static func is_blocked_sustain_mod_key(key: String) -> bool:
	return DOCTOR_FORBIDDEN_SUSTAIN_MOD_KEYS.has(key)


# FAN-1887: data-driven summon/deploy capability класса — строго из конфигов его
# оружий (max_summons / summon_role / summon_damage_multiplier / deploy_role),
# а не из текстовых «эхо»-интерпретаций. Сейчас это гитарист/химик/друид/инженер;
# множество проверяется тестом, а не поддерживается вручную.
static func class_summon_capable(character_id: String) -> bool:
	for weapon_id_value in weapon_ids(character_id):
		var config := weapon(character_id, str(weapon_id_value))
		if weapon_archetype(config) == "summon" or str(config.get("deploy_role", "")) != "":
			return true
	return false


# FAN-1887: consumability-гейт редких базовых характеристик. Лидерство без
# настоящего summon/deploy-потребителя не предлагается (level-up rare слот,
# Attribute Shop, stat-пулы наград); остальные 8-стат оси универсальны.
static func is_base_stat_consumable(stat_id: String, character_id: String) -> bool:
	if character_id == "":
		return true
	if stat_id == "leadership":
		return class_summon_capable(character_id)
	return true


static func is_reward_relevant(reward: Dictionary, character_id: String, ascension_level := 0, cross_class_ids: Array = []) -> bool:
	# SCRUM-900: trait-гейт вместо хардкода класса; явная пометка doctor_friendly
	# пропускает предмет в пул (и Player применит его моды штатно).
	if class_blocks_generic_sustain(character_id) and not bool(reward.get("doctor_friendly", false)) \
			and _is_doctor_forbidden_sustain_reward(reward):
		return false
	# FAN-1887: summon-награды (attr/зависимость summon_amount) и чисто
	# лидерские stat-награды доступны только фактически summon-способным классам.
	if character_id != "":
		var dependency := reward_attribute_dependency(reward)
		if dependency == "summon_amount" and not class_summon_capable(character_id):
			return false
		var reward_stats: Dictionary = reward.get("stats", {}) as Dictionary
		if reward_stats.size() == 1 and not is_base_stat_consumable(str(reward_stats.keys()[0]), character_id):
			return false
	# SCRUM-961 (artifact_system_matrix §1.4): классовые артефакты заперты гейтом
	# «свой класс И мета-Возвышение >= requires_ascension». Пустой class_affinity =
	# универсал (гейта нет). cross_class_ids — run-исключение «Украденного герба»
	# (§5): перечисленные id проходят сквозь гейт независимо от класса/возвышения.
	var affinity: Array = reward.get("class_affinity", []) as Array
	if affinity.is_empty():
		return true
	if cross_class_ids.has(str(reward.get("id", ""))):
		return true
	return character_id in affinity and ascension_level >= int(reward.get("requires_ascension", 0))


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
		"aoe_radius":
			return "Для этого класса работает как объявленная область удара, ауры и ближний контроль пространства."
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
	return WeaponBudgetModel.weapon_archetype(weapon_config)


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


# SCRUM-695: уровень релевантности атрибута для класса напрямую из матрицы
# (primary/secondary/optional). Источник правды — CharacterData.ATTRIBUTE_RELEVANCE.
static func attribute_relevance(attr_id: String, character_id: String) -> String:
	var row: Dictionary = ATTRIBUTE_RELEVANCE.get(attr_id, {})
	if (row.get("primary", []) as Array).has(character_id):
		return "primary"
	if (row.get("secondary", []) as Array).has(character_id):
		return "secondary"
	return "optional"


# SCRUM-695: вес выбора level-up-награды от релевантности (primary > secondary >> optional).
# optional держим выше нуля, чтобы небазовые атрибуты оставались доступны (контракт теста).
# Магнитуды подобраны близко к старому per-stat взвешиванию для сильных DPS-карт, чтобы
# «идеальный» билд не раздувался выше balance-потолков (pool_dot/berserk runaway-гейты).
static func attribute_relevance_weight(attr_id: String, character_id: String) -> float:
	match attribute_relevance(attr_id, character_id):
		"primary":
			return 1.4
		"secondary":
			return 0.7
		_:
			return 0.4


# SCRUM-1064: deterministic Hero Select projection. Values sort descending;
# ties keep the canonical STAT_NAMES declaration order so every class follows
# exactly the same rule and the UI never carries a hand-written priority list.
static func leading_base_stats(character_id: String, count := 3) -> Array:
	var stats: Dictionary = base_stats(character_id)
	var canonical_order: Array = STAT_NAMES.keys()
	var rows: Array = []
	for stat_id_value in canonical_order:
		var stat_id := str(stat_id_value)
		rows.append({
			"id": stat_id,
			"name": str(STAT_NAMES.get(stat_id, stat_id)),
			"value": float(stats.get(stat_id, 0.0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av := float(a.get("value", 0.0))
		var bv := float(b.get("value", 0.0))
		if not is_equal_approx(av, bv):
			return av > bv
		return canonical_order.find(str(a.get("id", ""))) < canonical_order.find(str(b.get("id", "")))
	)
	var limit := clampi(count, 0, rows.size())
	return rows.slice(0, limit)


# FAN-1887: Hero Select показывает только то, что герой реально может получить
# (primary/secondary в каноническом порядке реестра). Optional-оси (нет настоящего
# потребителя) исключены из выдачи и не отображаются — рейла «Слабые атрибуты»
# больше нет, исключения не подаются как выбор.
static func hero_attribute_relevance_groups(character_id: String) -> Dictionary:
	var groups := {"primary": [], "secondary": []}
	for entry_value in ATTRIBUTE_REGISTRY:
		var entry := entry_value as Dictionary
		var attr_id := str(entry.get("id", ""))
		if attr_id.is_empty():
			continue
		var category := attribute_relevance(attr_id, character_id)
		if not groups.has(category):
			continue
		(groups[category] as Array).append({
			"id": attr_id,
			"name": str(entry.get("name", attr_id)),
		})
	return groups


# Uniform data contract consumed by Hero Select and focused schema tests. Codex
# keeps its existing richer prose projection because it does not consume these
# Hero-only fields.
static func hero_select_dossier(character_id: String) -> Dictionary:
	var config := character_config(character_id)
	var weapons: Array = []
	for weapon_id_value in weapon_ids(character_id):
		var weapon_id := str(weapon_id_value)
		var weapon_config := weapon(character_id, weapon_id)
		weapons.append({
			"id": weapon_id,
			"name": str(weapon_config.get("title", weapon_id)),
		})
	var trait_record := class_trait(character_id)
	if str(trait_record.get("title", "")).strip_edges().is_empty():
		trait_record = {}
	return {
		"id": character_id,
		"name": str(config.get("title", character_id)),
		"trait": trait_record,
		"weapons": weapons,
		"leading_base_stats": leading_base_stats(character_id, 3),
		"attribute_relevance": hero_attribute_relevance_groups(character_id),
	}


static func reward_attribute_dependency(reward: Dictionary) -> String:
	# SCRUM-695: каноничный attr-id из реестра (LEVEL_UP_REWARDS теперь его несут).
	var attr := str(reward.get("attr", ""))
	if attr != "":
		return attr
	# Базовые stat-награды (Сила/Ловкость…) остаются на старом 8-стат пути.
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return str(stat_keys[0])
	# Фолбэк для синтетических наград без поля attr: вывести attr-id из ключа mods.
	var mods: Dictionary = reward.get("mods", {})
	for key in mods.keys():
		match str(key):
			"damage_flat":
				return "damage_flat"
			"damage_multiplier":
				return "damage"
			"attack_speed_multiplier":
				return "attack_speed"
			"max_health_flat", "max_health_multiplier":
				return "max_health"
			"move_speed_multiplier":
				return "move_speed"
			# FAN-1891: единая ось геометрии (сектор/радиус/аура).
			"aoe_radius_multiplier":
				return "aoe_radius"
			"pickup_radius_flat":
				return "pickup_radius"
			"defense_flat":
				return "defense"
			"crit_chance_flat":
				return "crit_chance"
			"crit_damage_flat":
				return "crit_damage"
			"dodge_flat":
				return "dodge"
			# FAN-1034: темп тиков слит в ось dot_damage. projectile_speed/knockback
			# больше не level-up атрибуты: их источники (артефакты) взвешиваются
			# нейтрально через пустую зависимость. FAN-1887: то же для снятых с
			# player-facing реестра снятых ключей.
			"dot_damage_flat":
				return "dot_damage"
			"summon_bonus":
				return "summon_amount"
			"regeneration_flat":
				return "regeneration"
			"vampiric_amount_flat", "vampiric_chance_flat":
				return "vampiric"
			"ultimate_flat":
				return "ultimate_power"
	return ""


static func level_up_reward_weight(reward: Dictionary, character_id: String) -> float:
	var dependency := reward_attribute_dependency(reward)
	if dependency == "":
		return float(reward.get("weight", 1.0))
	# Каноничные атрибуты — через матрицу релевантности (SCRUM-695).
	if ATTRIBUTE_RELEVANCE.has(dependency):
		return maxf(0.4, float(reward.get("weight", 1.0)) * attribute_relevance_weight(dependency, character_id))
	# Базовые stat-награды — старый 8-стат путь.
	return maxf(0.25, float(reward.get("weight", 1.0)) * attribute_priority_weight(character_id, dependency))


# SCRUM-695: для текущего класса награда «необязательна» (optional), если она несёт
# каноничный attr и тот в матрице optional. Базовые stat-награды и award без attr —
# не optional (всегда усиливают билд).
static func reward_is_optional(reward: Dictionary, character_id: String) -> bool:
	var attr := str(reward.get("attr", ""))
	if attr == "" or not ATTRIBUTE_RELEVANCE.has(attr):
		return false
	return attribute_relevance(attr, character_id) == "optional"


# FAN-1031 S4 (random-floor): урон-оси level-up наград. Карта релевантна УРОНУ класса, если
# несёт одну из этих осей И ось для класса НЕ optional (matrix primary/secondary).
# FAN-1887: magic_focus снят с реестра — оба урон-канала кроют универсальные
# damage_flat («Добавление урона») и damage («Увеличение урона»).
const DAMAGE_RELEVANT_ATTRS := ["damage_flat", "damage", "attack_speed", "crit_chance", "crit_damage", "dot_damage"]


static func reward_is_damage_relevant(reward: Dictionary, character_id: String) -> bool:
	var attr := str(reward.get("attr", ""))
	if not DAMAGE_RELEVANT_ATTRS.has(attr):
		return false
	return attribute_relevance(attr, character_id) != "optional"


static func _reg_has_damage_relevant(pool: Array, character_id: String) -> bool:
	for reward in pool:
		if reward_is_damage_relevant(reward, character_id):
			return true
	return false


# SCRUM-695: взвешенный индекс выбора из пула (детерминированно через переданный rng).
static func weighted_level_up_index(pool: Array, character_id: String, rng: RandomNumberGenerator) -> int:
	if pool.size() <= 1:
		return 0
	var total := 0.0
	var weights := []
	for reward in pool:
		var weight: float = level_up_reward_weight(reward, character_id)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return rng.randi_range(0, pool.size() - 1)
	var roll: float = rng.randf() * total
	for index in range(pool.size()):
		roll -= float(weights[index])
		if roll <= 0.0:
			return index
	return pool.size() - 1


static func ultimate_config(character_id: String) -> Dictionary:
	return ULTIMATE_CONFIGS.get(character_id, ULTIMATE_CONFIGS["berserk"]).duplicate(true)


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


# SCRUM-947 «Проводник стихий»: класс-trait Элементалиста, data-driven запись
static func _magic_bonus_effectiveness_for(character_id: String) -> float:
	if character_id == "":
		return 1.0
	return maxf(float((CLASS_TRAITS.get(character_id, {}) as Dictionary).get("magic_bonus_effectiveness", 1.0)), 1.0)


# SCRUM-897 «Воровская хватка»: класс-trait Вора, data-driven запись
# CLASS_TRAITS.thief.pickup_radius_multiplier = 1.85 (реестр class_traits_registry).
# Множитель применяется к СТАРТОВОЙ части pickup_radius (база 105 + perception×7)
# в derived_parameters; flat-источники забега/пассивов (pickup_radius_flat) идут
# поверх БЕЗ усиления — «сильно увеличенный стартовый радиус», а не runaway-скейл.
static func _pickup_radius_trait_multiplier(character_id: String) -> float:
	if character_id == "":
		return 1.0
	return maxf(float((CLASS_TRAITS.get(character_id, {}) as Dictionary).get("pickup_radius_multiplier", 1.0)), 1.0)


# Усиливает БОНУСНУЮ часть множителя: 1.15 → 1.0 + 0.15*effectiveness. Штрафы
# (multiplier <= 1.0) проходят без изменения — trait усиливает бонусы, не дебаффы.
static func _amplified_bonus_multiplier(multiplier: float, effectiveness: float) -> float:
	if effectiveness == 1.0 or multiplier <= 1.0:
		return multiplier
	return 1.0 + (multiplier - 1.0) * effectiveness


static func effective_defense(raw_defense: float) -> float:
	return DefensiveAttributeRuntime.effective_defense(raw_defense)


static func effective_dodge(raw_dodge: float) -> float:
	return DefensiveAttributeRuntime.effective_dodge(raw_dodge)


static func raw_defense_for_effective(effective_defense_value: float) -> float:
	return DefensiveAttributeRuntime.raw_defense_for_effective(effective_defense_value)


static func raw_dodge_for_effective(effective_dodge_value: float) -> float:
	return DefensiveAttributeRuntime.raw_dodge_for_effective(effective_dodge_value)


static func effective_absorb(endurance: float, flat_absorb: float) -> float:
	return DefensiveAttributeRuntime.effective_absorb(endurance, flat_absorb)


static func effective_regeneration(knowledge: float, flat_regeneration: float) -> float:
	return DefensiveAttributeRuntime.effective_regeneration(knowledge, flat_regeneration)


# SCRUM-900 «Клятва чумного доктора»: реген класса с generic_sustain_blocked =
# только дельта от явно применённых flat'ов (base-константа+knowledge отрезаны).
# Для остальных классов — прежняя формула без изменений.
static func _class_gated_regeneration(character_id: String, knowledge: float, flat_regeneration: float) -> float:
	if not class_blocks_generic_sustain(character_id):
		return effective_regeneration(knowledge, flat_regeneration)
	return maxf(effective_regeneration(knowledge, flat_regeneration) - effective_regeneration(knowledge, 0.0), 0.0)


static func effective_vampiric_chance(raw_chance: float) -> float:
	return DefensiveAttributeRuntime.effective_vampiric_chance(raw_chance)


static func effective_vampiric_amount(knowledge: float, flat_amount: float) -> float:
	return DefensiveAttributeRuntime.effective_vampiric_amount(knowledge, flat_amount)


static func effective_vampiric_cap(raw_cap: float) -> float:
	return DefensiveAttributeRuntime.effective_vampiric_cap(raw_cap)


# SCRUM-894: кап/diminish параметризованы под class trait «Хладнокровие»
# (class_crit_profile). Дефолты — прежние глобальные константы, все старые
# вызовы без аргументов тождественны.
static func effective_crit_chance(raw_chance: float, cap := CRIT_CHANCE_CAP, diminish := CRIT_CHANCE_DIMINISH) -> float:
	var raw := maxf(raw_chance, 0.0)
	var softened := raw / (1.0 + raw * maxf(diminish, 0.0))
	return clampf(softened, 0.0, clampf(cap, 0.0, 1.0))


static func ordinary_crit_chance_cap(agility: float) -> float:
	return clampf(CRIT_CHANCE_CAP + maxf(agility, 0.0) * CRIT_CHANCE_CAP_AGILITY_SCALE, CRIT_CHANCE_CAP, CRIT_CHANCE_CAP_MAX)


static func effective_crit_damage_multiplier(agility: float, flat_bonus: float) -> float:
	var positive_flat := maxf(flat_bonus, 0.0) * CRIT_DAMAGE_FLAT_EFFECTIVENESS
	var negative_flat := minf(flat_bonus, 0.0)
	var raw := CRIT_DAMAGE_BASE_MULTIPLIER + maxf(agility, 0.0) * CRIT_DAMAGE_AGILITY_SCALE + positive_flat + negative_flat
	if raw <= CRIT_DAMAGE_CAP:
		return maxf(raw, 1.0)
	return CRIT_DAMAGE_CAP + sqrt(raw - CRIT_DAMAGE_CAP)


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


# SCRUM-935: канонический доступ к class trait (пусто у классов без trait'а).
static func class_trait(character_id: String) -> Dictionary:
	return (CLASS_TRAITS.get(character_id, {}) as Dictionary).duplicate(true)


# SCRUM-935 «Двойное действие»: шанс полной копии действия оружия (Солдат = 0.5).
static func class_action_echo_chance(character_id: String) -> float:
	return clampf(float((CLASS_TRAITS.get(character_id, {}) as Dictionary).get("action_echo_chance", 0.0)), 0.0, 1.0)


# SCRUM-925 «Молитва боя»: пул молитв класса для выбора на старте боя.
# Data-driven: молитва входит в пул, только если её trait-ключ задан у класса в
# CLASS_TRAITS (у классов без battle_prayer-ключей пул пуст — утечки нет).
# Записи: {id, title, description, trait_key, value} — русский player-facing
# текст для обязательного UI SCRUM-926 и численный эффект. Порядок пула =
# порядок UI.
static func class_battle_prayers(character_id: String) -> Array:
	var trait_config: Dictionary = CLASS_TRAITS.get(character_id, {})
	var pool: Array = []
	for prayer_raw in CharacterData.BATTLE_PRAYERS:
		var prayer: Dictionary = prayer_raw
		var value := float(trait_config.get(str(prayer.get("trait_key", "")), 0.0))
		if value <= 0.0:
			continue
		var entry: Dictionary = prayer.duplicate(true)
		entry["value"] = value
		pool.append(entry)
	return pool


# SCRUM-894 «Хладнокровие»: крит-профиль класса из CLASS_TRAITS. Без trait-записи —
# обычный Agility-cap 55→75%, diminish 0.45, без overflow. Ассасин: кап 1.0,
# diminish 0.0 (крит-вложения окупаются полностью), overflow 0.5 — избыток
# raw-шанса сверх капа переливается в crit_damage_flat. Выше raw 2.75 сила крита
# продолжает расти через убывающий sqrt-tail без верхнего потолка.
static func class_crit_profile(character_id: String, ordinary_cap := CRIT_CHANCE_CAP) -> Dictionary:
	var trait_config: Dictionary = CLASS_TRAITS.get(character_id, {})
	return {
		"cap": clampf(float(trait_config.get("crit_chance_cap", ordinary_cap)), 0.0, 1.0),
		"diminish": maxf(float(trait_config.get("crit_chance_diminish", CRIT_CHANCE_DIMINISH)), 0.0),
		"overflow": clampf(float(trait_config.get("crit_overflow_to_crit_damage", 0.0)), 0.0, 1.0),
	}


# SCRUM-894 «Теневая завеса»: величина бонуса уворота самоцентричной ауры класса
# (у классов без veil-записи — 0). Масштаб от support_multiplier, жёсткий кап
# veil_dodge_cap; применяется Player.current_dodge_chance ТОЛЬКО при враге внутри
# derived aura_radius; суммарный уворот остаётся строго ниже
# SURVIVABILITY_DODGE_CAP.
static func class_veil_dodge_bonus(character_id: String, support_multiplier: float) -> float:
	var trait_config: Dictionary = CLASS_TRAITS.get(character_id, {})
	var base := float(trait_config.get("veil_dodge_bonus", 0.0))
	if base <= 0.0:
		return 0.0
	var cap := maxf(float(trait_config.get("veil_dodge_cap", 0.18)), 0.0)
	return clampf(base * maxf(support_multiplier, 0.0), 0.0, cap)


# SCRUM-1005 «Разбор образцов»: множитель ПРЯМОГО урона по целям под собственным
# периодическим эффектом (Биолог = 1.20; классы без trait'а — 1.0).
static func class_infected_direct_multiplier(character_id: String) -> float:
	return maxf(float((CLASS_TRAITS.get(character_id, {}) as Dictionary).get("infected_direct_hit_multiplier", 1.0)), 1.0)


# SCRUM-902 «Аура дикой силы»: величина постоянного аура-баффа урона класса
# (у классов без wild_aura-записи — 0). Масштаб от support_multiplier, жёсткий кап
# wild_aura_damage_cap. ЕДИНАЯ точка чтения для рантайма
# (Player.wild_aura_damage_multiplier + статус "wild_force_aura" призывам) и
# budget-модели (class_wild_aura_damage_factor в estimate_weapon_budget_for_stats):
# live-бой и формульный гейт видят один и тот же бафф.
static func class_wild_aura_damage_bonus(character_id: String, support_multiplier: float) -> float:
	var trait_config: Dictionary = CLASS_TRAITS.get(character_id, {})
	var base := float(trait_config.get("wild_aura_damage_bonus", 0.0))
	if base <= 0.0:
		return 0.0
	var cap := maxf(float(trait_config.get("wild_aura_damage_cap", 0.30)), 0.0)
	return clampf(base * maxf(support_multiplier, 0.0), 0.0, cap)


# Бюджет-фактор ауры: аура постоянна и баффает И владельца, И призывы — фактор
# применяется ко ВСЕМ каналам выхода кита (budget_tuning_for компенсирует урон,
# как у action_echo Солдата) — кит остаётся в общем коридоре, а инвестиции в
# support_multiplier/area сверх базы остаются живой наградой в забеге.
static func class_wild_aura_damage_factor(character_id: String, params: Dictionary) -> float:
	return 1.0 + class_wild_aura_damage_bonus(character_id, float(params.get("support_multiplier", 1.0)))


# SCRUM-1004 «Ярость»: средне-ожидаемая доля НЕДОСТАЮЩЕГО здоровья Берсерка за
# забег для budget-зеркала trait'а. Берсерк живёт в гуще боя (постоянный
# контакт-чип), но огромный запас крови + сустейн держат его большую часть
# времени в средне-высоком HP: принято матожидание missing_hp = 30% ⇒
# ожидаемый бонус 0.40×0.30 = +12% (фактор 1.12). budget_tuning_for
# компенсирует кит этим фактором: на полном HP Берсерк слегка НИЖЕ коридора
# (≈−11%), на почти пустом — до ≈+25% ВЫШЕ (риск/награда — решение SCRUM-1004).
const RAGE_BUDGET_EXPECTED_MISSING_HP := 0.30


# SCRUM-1004 «Ярость»: непрерывный бонус исходящего урона от недостающего HP.
# ЕДИНАЯ точка формулы для рантайма (Player.rage_damage_multiplier), бюджета и
# тестов: бонус = cap × clamp(1 − health/max_health, 0, 1) — полное HP → 0.0,
# половина → cap/2 (+20%), пустое/отрицательное → ровно cap (+40%); линейная
# шкала без ступенек. Невалидное max_health (<=0) и классы без rage-ключа
# дают 0.0 — утечки другим классам нет, NaN/бесконечность невозможны.
static func class_rage_damage_bonus(character_id: String, health: float, max_health: float) -> float:
	var cap := maxf(float((CLASS_TRAITS.get(character_id, {}) as Dictionary).get("rage_damage_bonus_cap", 0.0)), 0.0)
	if cap <= 0.0 or max_health <= 0.0:
		return 0.0
	var missing_ratio := clampf(1.0 - health / max_health, 0.0, 1.0)
	return cap * missing_ratio


# Бюджет-фактор «Ярости»: матожидание low-HP бонуса (кап × ожидаемое missing_hp,
# см. RAGE_BUDGET_EXPECTED_MISSING_HP) — множит канальные выходы кита в
# estimate_weapon_budget_for_stats (trait действует на весь исходящий урон
# оружий Берсерка), budget_tuning_for компенсирует кит, как у ауры Друида.
static func class_rage_expected_damage_factor(character_id: String) -> float:
	var cap := maxf(float((CLASS_TRAITS.get(character_id, {}) as Dictionary).get("rage_damage_bonus_cap", 0.0)), 0.0)
	return 1.0 + cap * RAGE_BUDGET_EXPECTED_MISSING_HP


# SCRUM-930 «Дальний расчёт»: the canonical distance multiplier formula (single
# point of truth for ClassWeapon._class_distance_trait_multiplier, the budget
# model and tests) lives in WeaponBudgetModel; the facade delegates.
static func distance_trait_multiplier(per_100: float, cap_bonus: float, free_range: float, distance: float) -> float:
	return WeaponBudgetModel.distance_trait_multiplier(per_100, cap_bonus, free_range, distance)


# Множитель «Дальнего расчёта» класса на конкретной дистанции (1.0 у классов
# без distance-ключей в CLASS_TRAITS — утечки другим классам нет).
static func class_distance_multiplier_at(character_id: String, distance: float) -> float:
	var trait_config: Dictionary = CLASS_TRAITS.get(character_id, {})
	return distance_trait_multiplier(
		float(trait_config.get("distance_damage_per_100px", 0.0)),
		float(trait_config.get("distance_damage_cap_bonus", 0.0)),
		float(trait_config.get("distance_damage_free_range", 0.0)),
		distance
	)


static func berserk_weapon(weapon_id: String) -> Dictionary:
	return BERSERK_WEAPONS.get(weapon_id, BERSERK_WEAPONS["sword"]).duplicate(true)


static func berserk_weapon_ids() -> Array:
	return BERSERK_WEAPONS.keys()


static func weapon_ids(character_id: String) -> Array:
	var weapons: Dictionary = WEAPONS_BY_CLASS.get(character_id, BERSERK_WEAPONS)
	return weapons.keys()


static func class_budget_profile(character_id: String) -> Dictionary:
	return CLASS_BUDGET_PROFILES.get(character_id, CLASS_BUDGET_PROFILES["berserk"]).duplicate(true)


# SCRUM-942 «Катализатор»: множитель ПЕРИОДИЧЕСКОГО урона класса (1.0 = без trait'а).
# Единая точка чтения для рантайма (player.periodic_damage_multiplier) и
# бюджет-формул (_budget_dot_dps/_budget_pool_dps/_budget_summon_wave_dps) —
# live-замер и формульный гейт видят одну и ту же периодику.
static func class_periodic_damage_multiplier(character_id: String) -> float:
	var trait_config = CLASS_TRAITS.get(character_id, {})
	if not (trait_config is Dictionary):
		return 1.0
	return maxf(float((trait_config as Dictionary).get("periodic_damage_multiplier", 1.0)), 0.0)


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


# Auto-tuning of a weapon onto its class budget profile: the pure formulas live
# in WeaponBudgetModel (tuning_damage_multiplier/budget_tuning); the facade only
# runs the two estimates they need (untuned, then with the multiplier applied).
static func budget_tuning_for(character_id: String, weapon_config: Dictionary) -> Dictionary:
	var profile := class_budget_profile(character_id)
	var base_metrics := estimate_weapon_budget(character_id, weapon_config, false)
	var scaled_config := weapon_config.duplicate(true)
	scaled_config["budget_damage_multiplier"] = WeaponBudgetModel.tuning_damage_multiplier(profile, base_metrics)
	var scaled_metrics := estimate_weapon_budget(character_id, scaled_config, true)
	return WeaponBudgetModel.budget_tuning(profile, base_metrics, scaled_metrics)


static func estimate_weapon_budget(character_id: String, weapon_config: Dictionary, apply_budget := true) -> Dictionary:
	return estimate_weapon_budget_for_stats(character_id, weapon_config, base_stats(character_id), apply_budget)


static func estimate_weapon_budget_for_stats(character_id: String, weapon_config: Dictionary, stats: Dictionary, apply_budget := true, run_modifiers := {}, include_ultimate := true) -> Dictionary:
	var config := WeaponBudgetModel.prepare_config(character_id, weapon_config, apply_budget)
	var params := derived_parameters(stats, run_modifiers, config)
	return WeaponBudgetModel.estimate(config, params, stats, _weapon_budget_class_context(character_id, params), apply_budget, include_ultimate)


# FAN-3923 (FD16): class-side inputs of the pure weapon-budget model. The model
# never reads CLASS_TRAITS or ULTIMATE_CONFIGS itself; the facade resolves every
# trait factor here with the same formulas the runtime reads, so live combat
# and the formula gate keep seeing one value per trait.
static func _weapon_budget_class_context(character_id: String, params: Dictionary) -> Dictionary:
	return {
		"damage_parameter": damage_parameter_for(character_id),
		"trait_config": CLASS_TRAITS.get(character_id, {}),
		"action_echo_chance": class_action_echo_chance(character_id),
		"infected_direct_multiplier": class_infected_direct_multiplier(character_id),
		"wild_aura_factor": class_wild_aura_damage_factor(character_id, params),
		"rage_factor": class_rage_expected_damage_factor(character_id),
		"periodic_damage_multiplier": class_periodic_damage_multiplier(character_id),
		"ultimate_config": ultimate_config(character_id),
	}


static func estimate_crowd_clear_budget(character_id: String, weapon_config: Dictionary, target_count: int, apply_budget := true) -> Dictionary:
	return estimate_crowd_clear_budget_for_stats(character_id, weapon_config, target_count, base_stats(character_id), apply_budget)


static func estimate_crowd_clear_budget_for_stats(character_id: String, weapon_config: Dictionary, target_count: int, stats: Dictionary, apply_budget := true, run_modifiers := {}, include_ultimate := true) -> Dictionary:
	var metrics := estimate_weapon_budget_for_stats(character_id, weapon_config, stats, apply_budget, run_modifiers, include_ultimate)
	return WeaponBudgetModel.crowd_clear_budget(weapon_config, target_count, metrics, class_budget_profile(character_id))


static func crowd_clear_counts() -> Array:
	return CROWD_CLEAR_TARGET_COUNTS.duplicate(true)


# FAN-3923 (FD16): the budget internals (_budget_* hit/dot/pool/summon/device
# models, crowd-clear factors, EHP) live in WeaponBudgetModel. Shared formula
# points the runtime reads through the facade stay re-exported here.
const RAVEN_BUDGET_REF_MULTIPLIER := WeaponBudgetModel.RAVEN_BUDGET_REF_MULTIPLIER
const PLAGUE_RAMP_START := WeaponBudgetModel.PLAGUE_RAMP_START


# SCRUM-900: single plague DoT profile for the runtime
# (ClassWeapon._apply_plague_infection) and the budget model; see WeaponBudgetModel.
static func plague_tick_profile(config: Dictionary, params: Dictionary) -> Dictionary:
	return WeaponBudgetModel.plague_tick_profile(config, params)


static func plague_ramp_factor(tick_index: int, ramp_ticks: int) -> float:
	return WeaponBudgetModel.plague_ramp_factor(tick_index, ramp_ticks)


# Budget internals that balance suites and reports call through the facade
# (tests/balance/engineer/engineer_kit_test.gd, tests/a5_balance_report_integrity_test.gd,
# tools/a5_balance_report.gd) keep their original signatures; the class lookups
# the model no longer performs stay on this side.
static func _budget_sentry_ammo_model(config: Dictionary, params: Dictionary, stats := {}) -> Dictionary:
	return WeaponBudgetModel._budget_sentry_ammo_model(config, params, stats)


static func _budget_orbit_drone_dps(config: Dictionary, params: Dictionary, stats := {}) -> Dictionary:
	return WeaponBudgetModel._budget_orbit_drone_dps(config, params, stats)


static func _budget_network_factor(config: Dictionary, params: Dictionary, stats := {}) -> float:
	return WeaponBudgetModel._budget_network_factor(config, params, stats, CLASS_TRAITS.get(str(config.get("character_id", "")), {}) as Dictionary)


static func _budget_ultimate_dps(character_id: String, params: Dictionary) -> Dictionary:
	return WeaponBudgetModel._budget_ultimate_dps(ultimate_config(character_id), params)


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
	config["geometry_capabilities"] = ModifiersData.geometry_capabilities(character_id, config)
	return config


static func is_removed_progression_modifier(key: String) -> bool:
	return ModifiersData.is_removed_progression_modifier(key)


static func sanitize_run_modifiers(modifiers: Dictionary) -> Dictionary:
	return ModifiersData.sanitize_run_modifiers(modifiers)


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
	var run_magic_damage_multiplier := _soft_capped_run_multiplier(float(run_modifiers.get("magic_damage_multiplier", 1.0)), RUN_DAMAGE_MULT_SOFTCAP, RUN_DAMAGE_MULT_KNEE)
	var run_attack_speed_multiplier := _soft_capped_run_multiplier(float(run_modifiers.get("attack_speed_multiplier", 1.0)), RUN_ATTACK_SPEED_MULT_SOFTCAP, RUN_ATTACK_SPEED_MULT_KNEE)
	# SCRUM-947 «Проводник стихий»: magic-tagged бонусы Элементалиста на 30%
	# эффективнее (CLASS_TRAITS.elementalist.magic_bonus_effectiveness). Порядок
	# и полный список источников — у _magic_bonus_effectiveness_for. Каждый
	# источник усиливается ровно
	# один раз ЗДЕСЬ (точка агрегации), до перемножения — двойного применения
	# при нескольких магических множителях нет.
	var magic_bonus_effectiveness := _magic_bonus_effectiveness_for(character_id)
	run_magic_damage_multiplier = _amplified_bonus_multiplier(run_magic_damage_multiplier, magic_bonus_effectiveness)
	var damage_multiplier := pow(run_damage_multiplier, upgrade_damage_exponent) * float(passive_mods.get("damage_multiplier", 1.0))
	var magic_damage_multiplier := pow(run_magic_damage_multiplier, upgrade_damage_exponent) * _amplified_bonus_multiplier(float(passive_mods.get("magic_damage_multiplier", 1.0)), magic_bonus_effectiveness)
	# SCRUM-961 «Четки молитвы»: открывающий бафф первых секунд боя усиливает
	# магический канал (prayer_opening_active ставит player.on_battle_start).
	# SCRUM-947: magic-tagged бафф — добавка усиливается trait'ом Элементалиста.
	magic_damage_multiplier *= 1.0 + float(run_modifiers.get("prayer_opening_power", 0.0)) * float(run_modifiers.get("prayer_opening_active", 0.0)) * magic_bonus_effectiveness
	var kill_momentum_attack_speed_bonus := clampf(float(run_modifiers.get("kill_momentum_attack_speed_bonus", 0.0)), 0.0, 0.12)
	var kill_momentum_crit_damage_bonus := clampf(float(run_modifiers.get("kill_momentum_crit_damage_bonus", 0.0)), 0.0, 0.09)
	# SCRUM-961 «Багровая рукоять»: стаки ярости за melee-удары — пишет player
	# ._refresh_rage_hit_modifiers по образцу kill_momentum; капы = пик 5 стаков.
	var rage_hit_damage_bonus := clampf(float(run_modifiers.get("rage_hit_damage_bonus", 0.0)), 0.0, 0.10)
	var rage_hit_attack_speed_bonus := clampf(float(run_modifiers.get("rage_hit_attack_speed_bonus", 0.0)), 0.0, 0.075)
	damage_multiplier *= 1.0 + rage_hit_damage_bonus
	# «Кровавый Рубеж» (tier 3): бонус урона активен, пока HP ниже порога (low_hp_active ставит player).
	damage_multiplier *= 1.0 + float(run_modifiers.get("low_hp_damage_bonus", 0.0)) * float(run_modifiers.get("low_hp_active", 0.0))
	# SCRUM-834 (Мета 4.1): условные keystone — бонус урона по типу условия. Гейты
	# (*_active 0/1, swarm_fraction 0..1) ставит player._update_conditional_keystones/
	# _trigger_rush_window; неактивное условие даёт 0 (keystone «спит»).
	damage_multiplier *= 1.0 \
		+ float(run_modifiers.get("hurt_damage_bonus", 0.0)) * float(run_modifiers.get("hurt_active", 0.0)) \
		+ float(run_modifiers.get("stance_damage_bonus", 0.0)) * float(run_modifiers.get("stance_active", 0.0)) \
		+ float(run_modifiers.get("rush_damage_bonus", 0.0)) * float(run_modifiers.get("rush_window_active", 0.0)) \
		+ float(run_modifiers.get("swarm_damage_bonus", 0.0)) * float(run_modifiers.get("swarm_fraction", 0.0))
	var attack_speed_multiplier := run_attack_speed_multiplier * float(passive_mods.get("attack_speed_multiplier", 1.0))
	attack_speed_multiplier *= 1.0 + kill_momentum_attack_speed_bonus
	attack_speed_multiplier *= 1.0 + rage_hit_attack_speed_bonus
	# SCRUM-834a: условный keystone «стойка → скорострельность» (soldier «Шквал»).
	# Гейт stance_active ставит player._update_conditional_keystones; спит вне стойки.
	attack_speed_multiplier *= 1.0 + float(run_modifiers.get("stance_attack_speed_bonus", 0.0)) * float(run_modifiers.get("stance_active", 0.0))
	# SCRUM-961 «Медиатор овердрайва»: темп-бонус активной рифф-серии (riff_streak_active
	# ставит player._update_meta_keystone_runtime; урон-бонус серии — в meta_damage_multiplier).
	attack_speed_multiplier *= 1.0 + float(run_modifiers.get("riff_streak_attack_speed_bonus", 0.0)) * float(run_modifiers.get("riff_streak_active", 0.0))
	# SCRUM-976: sandbox — final exact layer, intentionally outside release
	# softcaps/exponents so 0.5/2.0 remain exact and do not retune canonical data.
	var sandbox_damage_multiplier := clampf(float(run_modifiers.get("sandbox_player_damage_multiplier", 1.0)), 0.5, 2.0)
	attack_speed_multiplier *= clampf(float(run_modifiers.get("sandbox_player_attack_speed_multiplier", 1.0)), 0.5, 2.0)
	var move_speed_multiplier := float(run_modifiers.get("move_speed_multiplier", 1.0)) * float(passive_mods.get("move_speed_multiplier", 1.0))
	# «Призрачный Шаг» (tier 3): рывок скорости после уворота (dodge_rush_active ставит player).
	move_speed_multiplier *= 1.0 + float(run_modifiers.get("dodge_rush_bonus", 0.0)) * float(run_modifiers.get("dodge_rush_active", 0.0))
	# SCRUM-500 «Импульс Крита»: короткий рывок скорости по криту (crit_speed_burst_active ставит player).
	move_speed_multiplier *= 1.0 + float(run_modifiers.get("crit_speed_burst", 0.0)) * float(run_modifiers.get("crit_speed_burst_active", 0.0))
	# SCRUM-894 «Рывок темпа»: короткий бафф скорости+уворота после серии Теневых
	# кинжалов (flurry_tempo_active ставит Player.trigger_flurry_tempo с внутренним
	# кулдауном — перманентного аптайма нет; величины зажаты от runaway).
	var flurry_tempo_active := clampf(float(run_modifiers.get("flurry_tempo_active", 0.0)), 0.0, 1.0)
	move_speed_multiplier *= 1.0 + clampf(float(run_modifiers.get("flurry_tempo_speed_bonus", 0.0)), 0.0, 0.25) * flurry_tempo_active
	var max_health_multiplier := float(run_modifiers.get("max_health_multiplier", 1.0)) * float(passive_mods.get("max_health_multiplier", 1.0))
	var aoe_radius_multiplier := pow(float(run_modifiers.get("aoe_radius_multiplier", 1.0)), upgrade_aoe_exponent) * float(passive_mods.get("aoe_radius_multiplier", 1.0))
	var knockback_multiplier := float(run_modifiers.get("knockback_multiplier", 1.0)) * float(passive_mods.get("knockback_multiplier", 1.0))
	var defense_flat := float(run_modifiers.get("defense_flat", 0.0)) + float(passive_mods.get("defense_flat", 0.0))
	var absorb_flat := float(run_modifiers.get("absorb_flat", 0.0)) + float(passive_mods.get("absorb_flat", 0.0))
	var regeneration_flat := float(run_modifiers.get("regeneration_flat", 0.0)) + float(passive_mods.get("regeneration_flat", 0.0))
	var pickup_radius_flat := float(run_modifiers.get("pickup_radius_flat", 0.0)) + float(passive_mods.get("pickup_radius_flat", 0.0))
	var max_health_flat := float(run_modifiers.get("max_health_flat", 0.0)) + float(passive_mods.get("max_health_flat", 0.0))
	var run_dot_damage_flat := float(run_modifiers.get("dot_damage_flat", 0.0))
	var dot_damage_flat := run_dot_damage_flat + float(passive_mods.get("dot_damage_flat", 0.0))
	# SCRUM-834a: условный keystone «рывок → крит-шанс» (thief «Из тени»). Гейт
	# rush_window_active ставит player._trigger_rush_window; 0 вне окна. Проходит
	# ту же CRIT_FLAT_EFFECTIVENESS, что и базовый крит-шанс (тождество весов).
	var crit_chance_flat := (float(run_modifiers.get("crit_chance_flat", 0.0)) + float(run_modifiers.get("rush_crit_bonus", 0.0)) * float(run_modifiers.get("rush_window_active", 0.0)) + float(passive_mods.get("crit_chance_flat", 0.0))) * CRIT_FLAT_EFFECTIVENESS
	var crit_damage_flat := float(run_modifiers.get("crit_damage_flat", 0.0)) + kill_momentum_crit_damage_bonus + float(passive_mods.get("crit_damage_flat", 0.0))
	if passive_mods.has("crit_damage_multiplier"):
		crit_damage_flat += float(passive_mods.get("crit_damage_multiplier", 1.0)) - 1.0
	# SCRUM-894 «Хладнокровие»: per-class крит-профиль (кап/diminish из
	# CLASS_TRAITS; дефолт — глобальные константы). Избыток raw-шанса СВЕРХ капа
	# конвертируется в crit_damage_flat с коэффициентом overflow (только у классов
	# с trait-ключом; выше raw 2.75 итог идёт в убывающий sqrt-tail без потолка).
	var crit_profile := class_crit_profile(character_id, ordinary_crit_chance_cap(agility))
	var crit_chance_raw := 0.04 + agility * 0.0075 + crit_chance_flat
	var crit_overflow_ratio := float(crit_profile.get("overflow", 0.0))
	if crit_overflow_ratio > 0.0:
		crit_damage_flat += maxf(crit_chance_raw - float(crit_profile.get("cap", CRIT_CHANCE_CAP)), 0.0) * crit_overflow_ratio
	# SCRUM-524: урон каждого ТИПА масштабируется ТОЛЬКО от своего атрибута.
	var universal_damage_flat := float(run_modifiers.get("damage_flat", 0.0))
	var physical_base := 15.0 * strength / 10.0
	# SCRUM-947: атрибутный источник магического бонуса — дельта интеллекта НАД
	# базой класса (после growth-скаляра) на 30% эффективнее для Элементалиста.
	# База класса не трогается (стартовые числа и формульные гейты неизменны),
	# усиление действует ТОЛЬКО в канале magic_damage (изоляция типов SCRUM-524).
	var magic_intelligence := intelligence
	if magic_bonus_effectiveness != 1.0 and not base_for_growth.is_empty():
		var base_intelligence := float(base_for_growth.get("intelligence", intelligence))
		var intelligence_delta := intelligence - base_intelligence
		# The trait amplifies only a positive bonus. A below-base value is a
		# penalty and must pass through unchanged, just like multiplier penalties
		# in _amplified_bonus_multiplier(). Clamping the delta to zero here would
		# silently restore debuffed Intelligence to the class base (SCRUM-1019).
		if intelligence_delta > 0.0:
			magic_intelligence = base_intelligence + intelligence_delta * magic_bonus_effectiveness
	var magic_base := 14.0 * magic_intelligence / 10.0
	var universal_attack_stat := agility + energy * 0.18 + perception * 0.10 + endurance * 0.04
	var attack_speed := maxf(0.1, (9.0 * 3.0 * universal_attack_stat / 100.0) * attack_speed_multiplier)
	var base_attack_stat := universal_attack_stat
	if not base_for_growth.is_empty():
		base_attack_stat = float(base_for_growth.get("agility", agility)) + float(base_for_growth.get("energy", energy)) * 0.18 + float(base_for_growth.get("perception", perception)) * 0.10 + float(base_for_growth.get("endurance", endurance)) * 0.04
	var base_attack_speed := maxf(9.0 * 3.0 * base_attack_stat / 100.0, 0.1)
	var attack_cadence_multiplier := maxf(attack_speed / base_attack_speed, 0.1)
	var dot_attribute_base := 4.0 + knowledge * 0.65 + dot_damage_flat
	var base_dot_speed := maxf(0.45, 0.65 + knowledge * 0.08 + energy * 0.015 + agility * 0.010)
	var radius_perception := perception
	var radius_intelligence := intelligence
	var radius_knowledge := knowledge
	var radius_leadership := leadership
	if bool(weapon_config.get("geometry_stat_growth_from_delta", false)) and not base_for_growth.is_empty():
		radius_perception = maxf(0.0, perception - float(base_for_growth.get("perception", 0.0)))
		radius_intelligence = maxf(0.0, intelligence - float(base_for_growth.get("intelligence", 0.0)))
		radius_knowledge = maxf(0.0, knowledge - float(base_for_growth.get("knowledge", 0.0)))
		radius_leadership = maxf(0.0, leadership - float(base_for_growth.get("leadership", 0.0)))
	var aoe_intelligence_weight := float(weapon_config.get("aoe_radius_intelligence_weight", 0.45))
	var base_area := maxf(float(weapon_config.get("aoe_radius", 190.0)), 1.0)
	var attack_area_multiplier := (base_area + radius_perception * 3.5 + radius_intelligence * aoe_intelligence_weight + radius_knowledge * 0.35 + radius_leadership * 0.30) * aoe_radius_multiplier / base_area
	var aura_radius := base_area * attack_area_multiplier
	# Support effects derive at one aggregation point. Druid's existing summon
	# support inputs live here too, so Player and summons cannot scale them twice.
	var support_multiplier := maxf(run_damage_multiplier, 0.0)
	if character_id == "druid":
		support_multiplier = 1.0 + leadership * 0.025 + float(stats.get("knowledge", 0.0)) * 0.006 + float(stats.get("energy", 0.0)) * 0.004
		# Друид считает свой радиус ауры от собственных support-атрибутов, но общий
		# множитель области применяется ровно один раз — как и у остальной геометрии.
		aura_radius = (base_area + leadership * 5.0 + float(stats.get("perception", 0.0)) * 0.80 + float(stats.get("energy", 0.0)) * 0.65 + float(stats.get("knowledge", 0.0)) * 0.45) * aoe_radius_multiplier
	var raw_dodge := 0.02 + agility * 0.010 + float(run_modifiers.get("dodge_flat", 0.0)) + clampf(float(run_modifiers.get("flurry_tempo_dodge_bonus", 0.0)), 0.0, 0.20) * flurry_tempo_active
	var raw_defense := 0.04 + endurance * 0.018 + defense_flat

	return {
		"damage": (physical_base * weapon_damage_multiplier * damage_multiplier + universal_damage_flat) * sandbox_damage_multiplier,
		"magic_damage": (magic_base * weapon_damage_multiplier * damage_multiplier * magic_damage_multiplier + universal_damage_flat) * sandbox_damage_multiplier,
		"attack_speed": attack_speed,
		"attack_cadence_multiplier": attack_cadence_multiplier,
		"crit_chance": effective_crit_chance(crit_chance_raw, float(crit_profile.get("cap", CRIT_CHANCE_CAP)), float(crit_profile.get("diminish", CRIT_CHANCE_DIMINISH))),
		"crit_damage_multiplier": effective_crit_damage_multiplier(agility, crit_damage_flat),
		"move_speed": (282.0 + agility * 6.2) * move_speed_multiplier,
		"raw_dodge": raw_dodge,
		"dodge": effective_dodge(raw_dodge),
		"raw_defense": raw_defense,
		"defense": effective_defense(raw_defense),
		"health_point": (50.0 * endurance / 4.0 + max_health_flat) * max_health_multiplier,
		"attack_range": float(weapon_config.get("attack_range", 240.0)),
		"attack_area_multiplier": attack_area_multiplier,
		"aoe_radius": base_area * attack_area_multiplier,
		# SCRUM-897 «Воровская хватка»: стартовая часть радиуса подбора усилена
		# trait-множителем (у Вора ×1.85); flat-добавки — поверх без усиления.
		"pickup_radius": (105.0 + perception * 7.0) * _pickup_radius_trait_multiplier(character_id) + pickup_radius_flat,
		"dot_damage": max(1.0, dot_attribute_base * damage_multiplier) * sandbox_damage_multiplier,
		"dot_speed": base_dot_speed * attack_cadence_multiplier,
		"projectile_speed": float(weapon_config.get("projectile_speed", 460.0)),
		"aura_radius": aura_radius,
		"support_multiplier": support_multiplier,
		"knockback_power": (float(weapon_config.get("knockback", 60.0)) + strength * 4.0) * knockback_multiplier,
		"summon_amount": leadership + knowledge * 0.18 + intelligence * 0.12 + energy * 0.10,
		# SCRUM-546: профильное (growth-масштабированное) Лидерство как драйвер силы
		# саммонов — читается runtime deploy/sentry-пайплайном (class_weapon
		# ._summon_role_damage_factor) и саммон-профилем (summoner_weapon).
		"leadership": leadership,
		# Подключение полного набора атрибутов (аудит 2026-06-11):
		"absorb": effective_absorb(endurance, absorb_flat),
		# SCRUM-900 «Клятва чумного доктора»: при generic_sustain_blocked базовый
		# пассивный реген (константа 0.16 + скейл knowledge) отрезан — остаётся
		# только вклад явно применённых flat'ов (их пускает лишь doctor_friendly
		# гейт Player._apply_reward_mods), с тем же knowledge-скейлом формулы.
		"regeneration": _class_gated_regeneration(character_id, knowledge, regeneration_flat),
		"vampiric_chance": effective_vampiric_chance(float(run_modifiers.get("vampiric_chance_flat", 0.0))),
		"vampiric_amount": effective_vampiric_amount(knowledge, float(run_modifiers.get("vampiric_amount_flat", 0.0))),
		# Усиливает классовую ульту: урон, радиус, длительность или число целей.
		"ultimate_multiplier": 1.0 + energy * 0.02 + (strength + agility + intelligence + perception + knowledge + endurance + leadership) * 0.002 + float(run_modifiers.get("ultimate_flat", 0.0)),
	}


static func reward_pool(character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array:
	var rewards := []
	for reward in STAT_REWARDS:
		if character_id != "" and not is_reward_relevant(reward, character_id, ascension_level, cross_class_ids):
			continue
		var stat_reward: Dictionary = reward.duplicate(true)
		stat_reward["kind"] = "stat"
		rewards.append(stat_reward)
	for artifact in ARTIFACTS:
		if character_id != "" and not is_reward_relevant(artifact, character_id, ascension_level, cross_class_ids):
			continue
		var artifact_reward: Dictionary
		if bool(artifact.get("rarity_scaling", false)):
			# SCRUM-960: семья — ролл тира по нормализованным TIER_WEIGHTS,
			# в пул входит материализованный оффер с весом семьи (1.0).
			artifact_reward = materialize_family_offer(artifact, roll_artifact_family_tier())
			artifact_reward["weight"] = 1.0
		else:
			artifact_reward = artifact.duplicate(true)
			artifact_reward["weight"] = TIER_WEIGHTS.get(int(artifact.get("tier", 1)), 1.0)
		artifact_reward["kind"] = "artifact"
		rewards.append(artifact_reward)
	return rewards


static func level_up_rewards(character_id := "") -> Array:
	var rewards := []
	for reward in LEVEL_UP_REWARDS:
		if character_id != "" and not is_reward_relevant(reward, character_id):
			continue
		# FAN-1887: optional-ось (нет настоящего потребителя у класса) вообще
		# не входит в классовый пул — строгий фильтр начинается с источника.
		if character_id != "" and reward_is_optional(reward, character_id):
			continue
		rewards.append(reward.duplicate(true))
	return rewards


static func main_stat_level_up_rewards(character_id := "") -> Array:
	# Редкий пул level-up: рост основной характеристики на +1. Помечены rare=true
	# для визуального выделения; классовая интерпретация считается на карточке.
	# FAN-1887: редкие базовые характеристики тоже проходят consumability-фильтр —
	# Лидерство не предлагается классу без настоящего summon/deploy-потребителя.
	var rewards := []
	for stat_id in STAT_NAMES.keys():
		if not is_base_stat_consumable(str(stat_id), character_id):
			continue
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


static func shop_items(route_stage := 0, character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array:
	var items := []
	for item in SHOP_ITEMS:
		if character_id != "" and not is_reward_relevant(item, character_id, ascension_level, cross_class_ids):
			continue
		var shop_item: Dictionary = item.duplicate(true)
		shop_item["cost"] = stage_scaled_cost(int(shop_item.get("cost", 0)), route_stage)
		items.append(shop_item)
	for artifact in ARTIFACTS:
		if character_id != "" and not is_reward_relevant(artifact, character_id, ascension_level, cross_class_ids):
			continue
		var shop_artifact: Dictionary
		if bool(artifact.get("rarity_scaling", false)):
			# SCRUM-960: семья — ролл тира (нормализованные TIER_WEIGHTS), цена
			# материализованного тира затем масштабируется глубиной как обычно.
			shop_artifact = materialize_family_offer(artifact, roll_artifact_family_tier())
			shop_artifact["weight"] = 1.0
		else:
			shop_artifact = artifact.duplicate(true)
			shop_artifact["weight"] = TIER_WEIGHTS.get(int(shop_artifact.get("tier", 1)), 1.0)
		shop_artifact["cost"] = stage_scaled_cost(int(shop_artifact.get("cost", COST_BY_TIER.get(int(shop_artifact.get("tier", 1)), 30))), route_stage)
		shop_artifact["kind"] = "artifact"
		items.append(shop_artifact)
	return items


static func _elite_tier_depth_weight(tier: int, route_stage: int, scale: float) -> float:
	# Существующая depth-формула элиток/сундуков: глубже по маршруту — чаще т2/т3.
	if tier == 2:
		return 0.75 + scale * 0.25
	elif tier == 3:
		return 0.22 + maxf(float(route_stage) - 2.0, 0.0) * 0.18
	return 1.0


static func elite_artifact_choices(route_stage: int, count := 3, character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array:
	var pool := []
	var scale := stage_scale(route_stage)
	for artifact in ARTIFACTS:
		if character_id != "" and not is_reward_relevant(artifact, character_id, ascension_level, cross_class_ids):
			continue
		var candidate: Dictionary
		if bool(artifact.get("rarity_scaling", false)):
			# SCRUM-960: семья — тир роллится по TIER_WEIGHTS × depth_weight
			# (существующая формула глубины), вес семьи в пуле = 1.0.
			var depth_weights := {}
			for tier_key in TIER_WEIGHTS:
				depth_weights[tier_key] = float(TIER_WEIGHTS[tier_key]) * _elite_tier_depth_weight(int(tier_key), route_stage, scale)
			candidate = materialize_family_offer(artifact, roll_artifact_family_tier(depth_weights))
			candidate["kind"] = "artifact"
			candidate["weight"] = 1.0
			pool.append(candidate)
			continue
		candidate = artifact.duplicate(true)
		var tier := int(candidate.get("tier", 1))
		var depth_weight := _elite_tier_depth_weight(tier, route_stage, scale)
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


static func boss_completion_artifact_rewards(character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array:
	var rewards := []
	for artifact in ARTIFACTS:
		var is_family := bool(artifact.get("rarity_scaling", false))
		# SCRUM-960: семьи попадают в boss-пул ФИКСИРОВАННО тиром 3 (эпический);
		# плоские записи — как раньше, только tier >= 3.
		if not is_family and int(artifact.get("tier", 1)) < 3:
			continue
		if character_id != "" and not is_reward_relevant(artifact, character_id, ascension_level, cross_class_ids):
			continue
		var reward: Dictionary = materialize_family_offer(artifact, 3) if is_family else artifact.duplicate(true)
		reward["kind"] = "artifact"
		rewards.append(reward)
	return rewards


static func boss_completion_artifact_choices(count := 3, character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array:
	# SCRUM-873: награда за акт-босса — выбор 1 из `count` СУПЕРРЕДКИХ артефактов.
	# «Суперредкие» = верхний тир пула (tier >= 3, boss-only оффер); внутри тира
	# выборка равновероятная и БЕЗ дублей. Пул уже отфильтрован по релевантности
	# классу в boss_completion_artifact_rewards; нейтральные артефакты добивают
	# набор до count естественно (они проходят is_reward_relevant для всех).
	var pool := boss_completion_artifact_rewards(character_id, ascension_level, cross_class_ids)
	var choices := []
	while choices.size() < count and not pool.is_empty():
		var index := randi_range(0, pool.size() - 1)
		choices.append(pool[index])
		pool.remove_at(index)
	return choices


static func display_stats(stats: Dictionary) -> String:
	var parts := []
	for stat_id in STAT_NAMES.keys():
		parts.append("%s %.0f" % [STAT_NAMES[stat_id], float(stats.get(stat_id, 0.0))])
	return " | ".join(parts)


static func display_derived_parameters(parameters: Dictionary) -> String:
	return "Урон %.1f | Магия %.1f | Атаки %.2f | Крит %.0f%% | Защита %.0f%% | Дальность %.0f | Область %.0f | Подбор %.0f" % [
		float(parameters.get("damage", 0.0)),
		float(parameters.get("magic_damage", 0.0)),
		float(parameters.get("attack_speed", 0.0)),
		float(parameters.get("crit_chance", 0.0)) * 100.0,
		float(parameters.get("defense", 0.0)) * 100.0,
		float(parameters.get("attack_range", 0.0)),
		float(parameters.get("aoe_radius", 0.0)),
		float(parameters.get("pickup_radius", 0.0)),
	]
