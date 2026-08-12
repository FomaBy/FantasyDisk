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
const VAMPIRIC_BASE_HEAL_MULTIPLIER := BalanceData.VAMPIRIC_BASE_HEAL_MULTIPLIER
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


# SCRUM-900 «Клятва чумного доктора»: реген класса с generic_sustain_blocked =
# только дельта от явно применённых flat'ов (base-константа+knowledge отрезаны).
# Для остальных классов — прежняя формула без изменений.
static func _class_gated_regeneration(character_id: String, knowledge: float, flat_regeneration: float) -> float:
	if not class_blocks_generic_sustain(character_id):
		return effective_regeneration(knowledge, flat_regeneration)
	return maxf(effective_regeneration(knowledge, flat_regeneration) - effective_regeneration(knowledge, 0.0), 0.0)


static func effective_vampiric_chance(raw_chance: float) -> float:
	return clampf(raw_chance, 0.0, VAMPIRIC_CHANCE_CAP)


static func effective_vampiric_cap(raw_cap: float) -> float:
	return clampf(raw_cap, 0.0, VAMPIRIC_HEAL_CAP_HARD)


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
# derived aura_radius; суммарный уворот всё равно ≤ SURVIVABILITY_DODGE_CAP.
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


# SCRUM-930 «Дальний расчёт»: каноническая формула множителя дистанции —
# ЕДИНАЯ точка правды для рантайма (ClassWeapon._class_distance_trait_multiplier),
# budget-модели (_budget_distance_trait_factors) и тестов. В пределах free_range
# ровно ×1.0 (AC: близкая цель получает базовый урон), дальше линейный рост
# per_100 за каждые 100px, жёсткий кап +cap_bonus (с дефолтами Снайпера кап
# ×1.60 достигается на 120 + 0.60/0.10×100 = 720px и держится дальше).
static func distance_trait_multiplier(per_100: float, cap_bonus: float, free_range: float, distance: float) -> float:
	if per_100 <= 0.0:
		return 1.0
	var scaled := maxf(distance - maxf(free_range, 0.0), 0.0) / 100.0 * per_100
	return 1.0 + minf(scaled, maxf(cap_bonus, 0.0))


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


# Бюджет-зеркало «Дальнего расчёта»: матожидание множителя по ТИПОВОЙ дистанции
# боя оружия (документированные допущения по attack_mode; budget_tuning_for
# затем компенсирует кит — инвестиция в позиционирование остаётся живой наградой):
#   sniper_lockshot   — винтовка сама берёт САМУЮ ДАЛЬНЮЮ цель: соло-дуэль
#     ~0.75×attack_range (около капа); по толпе часть выхода — ближний
#     самоподрыв у ног (×1.0) → бонус срезается вдвое (доля дальних хитов 0.55);
#   sniper_kill_zone  — снаряд по метке у выбранной цели: типовая зона
#     ~0.55×attack_range, все жертвы в зоне на схожей дистанции;
#   sniper_split_round — круговой веер по БЛИЖНИМ монстрам: типовая цель
#     ~0.60×aoe_radius (радиус разлёта пуль) — почти без бонуса;
#   иное оружие класса с trait'ом — консервативно 0.5×attack_range.
static func _budget_distance_trait_factors(character_id: String, config: Dictionary) -> Dictionary:
	var trait_config: Dictionary = CLASS_TRAITS.get(character_id, {})
	if float(trait_config.get("distance_damage_per_100px", 0.0)) <= 0.0:
		return {"solo": 1.0, "aoe": 1.0}
	var attack_range := float(config.get("attack_range", 240.0))
	var aoe_radius := float(config.get("aoe_radius", 120.0))
	match str(config.get("attack_mode", config.get("attack_shape", "single"))):
		"sniper_lockshot":
			var far_mult := class_distance_multiplier_at(character_id, attack_range * 0.75)
			return {"solo": far_mult, "aoe": 1.0 + (far_mult - 1.0) * 0.55}
		"sniper_kill_zone":
			var zone_mult := class_distance_multiplier_at(character_id, attack_range * 0.55)
			return {"solo": zone_mult, "aoe": zone_mult}
		"sniper_split_round":
			var spray_mult := class_distance_multiplier_at(character_id, aoe_radius * 0.60)
			return {"solo": spray_mult, "aoe": spray_mult}
	var default_mult := class_distance_multiplier_at(character_id, attack_range * 0.5)
	return {"solo": default_mult, "aoe": default_mult}


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


static func estimate_weapon_budget_for_stats(character_id: String, weapon_config: Dictionary, stats: Dictionary, apply_budget := true, run_modifiers := {}, include_ultimate := true) -> Dictionary:
	var config := weapon_config.duplicate(true)
	config["character_id"] = character_id
	if not apply_budget:
		config.erase("budget_damage_multiplier")
		config.erase("budget_tuning")
	var params := derived_parameters(stats, run_modifiers, config)
	var damage_parameter := str(config.get("damage_parameter", damage_parameter_for(character_id)))
	var base_damage := float(params.get(damage_parameter, params.get("damage", 1.0)))
	var crit_factor := 1.0 + float(params.get("crit_chance", 0.0)) * maxf(float(params.get("crit_damage_multiplier", 1.0)) - 1.0, 0.0)
	var interval := maxf(float(config.get("fire_interval", 1.0)) / maxf(float(params.get("attack_speed", 1.0)), 0.1), 0.18)
	var direct_dps := base_damage * crit_factor / interval
	if _is_pure_summon_weapon(config):
		direct_dps = 0.0
	elif bool(config.get("curse_only", false)):
		# SCRUM-940: curse-only оружие (cursed_skull) прямого урона не наносит —
		# весь его выход идёт через dot-ось (_budget_dot_dps), как и в рантайме.
		direct_dps = 0.0
	elif str(config.get("attack_mode", "")) == "engineer_orbit_drone":
		# SCRUM-906: оружие само не стреляет — обслуживает парк дронов; весь
		# урон контактный (summon-канал, _budget_orbit_drone_dps).
		direct_dps = 0.0
	elif str(config.get("summon_role", "")) != "":
		direct_dps *= _budget_summon_role_damage_factor(config, params, stats)
	var hit_model := _budget_hit_model(config)
	var melee_unique_budget := _budget_melee_unique_bonus(config)
	var dot_dps := _budget_dot_dps(config, params, interval, stats)
	var pool_dps := _budget_pool_dps(config, params, interval)
	var summon_dps := _budget_summon_dps(config, params, stats)
	# SCRUM-905/906: у устройств инженера собственные summon-модели, зеркалящие
	# рантайм (боезапас турелей / орбитальный контакт дронов); они замещают
	# generic _budget_summon_dps и пишут свой crowd-фактор в summon_targets.
	var sentry_model := _budget_sentry_ammo_model(config, params, stats)
	if not sentry_model.is_empty():
		summon_dps = float(sentry_model.get("summon_dps", summon_dps))
		hit_model["summon_targets"] = float(sentry_model.get("summon_targets", 1.0))
	var orbit_model := _budget_orbit_drone_dps(config, params, stats)
	if not orbit_model.is_empty():
		summon_dps = float(orbit_model.get("summon_dps", summon_dps))
		hit_model["summon_targets"] = float(orbit_model.get("summon_targets", 1.0))
	# SCRUM-935 «Двойное действие»: echo-trait создаёт полную копию действия оружия
	# с шансом p ⇒ матожидание выхода действия ×(1+p). Фактор применяется к
	# action-компонентам (direct/dot/pool), но НЕ к призывам (деплой исключён из
	# эха) и НЕ к ульте (не действие оружия). Благодаря этому budget_tuning_for
	# автоматически компенсирует урон кита (AC SCRUM-935: кит сопоставим с ростером).
	var action_echo_factor := 1.0 + class_action_echo_chance(character_id)
	# SCRUM-946: периодические волны гомункула-кастера; по толпе волна накрывает
	# нескольких целей радиусом (зеркало клампа pool_targets: 1 + r/130, кап 4).
	# Волны — канал призыва (как summon_dps), echo-фактор действий на них не действует.
	var wave_dps := _budget_summon_wave_dps(config, params)
	var wave_targets := clampf(1.0 + float(config.get("summon_wave_radius", 130.0)) / 130.0, 1.0, 4.0)
	# SCRUM-1005 «Разбор образцов»: прямой урон по целям под собственным DoT
	# усилен (Биолог ×1.20). Инфекция оружия с dot_ticks>0 живёт дольше
	# интервала каста (калибровка длительности в SCRUM-896), но первый хит боя
	# идёт по чистой цели — документированный uptime 0.75. Фактор применяется
	# ТОЛЬКО к прямому компоненту (не к dot/pool/summon/wave/ульте); у оружия без
	# собственного DoT (dot_ticks<=0) бонус в модели не учитывается.
	var infected_direct_factor := 1.0
	if float(config.get("dot_ticks", 0.0)) > 0.0:
		infected_direct_factor = 1.0 + (class_infected_direct_multiplier(character_id) - 1.0) * 0.75
	# SCRUM-930 «Дальний расчёт»: матожидание дистанс-множителя Снайпера по
	# типовой дистанции боя оружия (только ПРЯМОЙ компонент — тики DoT trait не
	# скейлит, зеркало гейта в ClassWeapon._damage_enemy). budget_tuning_for
	# компенсирует кит, как у прочих trait-факторов.
	var distance_factors := _budget_distance_trait_factors(character_id, config)
	var distance_solo_factor := float(distance_factors.get("solo", 1.0))
	var distance_aoe_factor := float(distance_factors.get("aoe", 1.0))
	# SCRUM-902 «Аура дикой силы»: постоянный классовый бафф урона владельца И
	# призывов — множит ВСЕ каналы выхода (в отличие от echo, который не трогает
	# призывы). budget_tuning_for компенсирует кит (см. class_wild_aura_damage_factor).
	var wild_aura_factor := class_wild_aura_damage_factor(character_id, params)
	# SCRUM-930 «Дальний расчёт» (distance_*_factor) впаян в объявления; сеть
	# устройств и Ярость домножают ниже — все trait-факторы кита сохранены.
	var solo_dps := ((direct_dps * infected_direct_factor * distance_solo_factor * float(hit_model.get("solo_hits", 1.0)) * float(melee_unique_budget.get("solo", 1.0)) + dot_dps + pool_dps) * action_echo_factor + summon_dps + wave_dps) * wild_aura_factor
	var aoe_dps := ((direct_dps * infected_direct_factor * distance_aoe_factor * float(hit_model.get("five_hits", 1.0)) * float(melee_unique_budget.get("aoe", 1.0)) + dot_dps * float(hit_model.get("dot_targets", 1.0)) + pool_dps * float(hit_model.get("pool_targets", 1.0))) * action_echo_factor + summon_dps * float(hit_model.get("summon_targets", 1.0)) + wave_dps * wave_targets) * wild_aura_factor
	# SCRUM-908 «Сеть мастерской»: ожидаемые стеки устройств усиливают выход
	# оружия-устройства (ульта НЕ устройство — фактор до её добавления).
	var network_factor := _budget_network_factor(config, params, stats)
	solo_dps *= network_factor
	aoe_dps *= network_factor

	# SCRUM-1004 «Ярость»: матожидание low-HP бонуса Берсерка (кап 0.40 ×
	# ожидаемое missing_hp 0.30 ⇒ ×1.12) — trait множит ВЕСЬ исходящий урон
	# оружий кита (BerserkWeapon._rolled_damage), поэтому фактор применяется ко
	# всем канальным выходам ДО ульты (ульта не действие оружия — паттерн
	# action_echo); budget_tuning_for компенсирует кит. Другим классам фактор 1.0.
	var rage_factor := class_rage_expected_damage_factor(character_id)
	solo_dps *= rage_factor
	aoe_dps *= rage_factor
	if include_ultimate:
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


static func estimate_crowd_clear_budget_for_stats(character_id: String, weapon_config: Dictionary, target_count: int, stats: Dictionary, apply_budget := true, run_modifiers := {}, include_ultimate := true) -> Dictionary:
	var count: int = maxi(target_count, 1)
	var profile := class_budget_profile(character_id)
	var metrics := estimate_weapon_budget_for_stats(character_id, weapon_config, stats, apply_budget, run_modifiers, include_ultimate)
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
	elif ["aoe_projectile", "grenade_fuse", "smoke_bomb", "meteor_shards", "bio_spore_bloom", "engineer_pressure_mines", "dark_mirror_blast"].has(mode):
		factor *= 1.04
	return clampf(factor, 0.82, 1.12)


static func _crowd_clear_target_factor(config: Dictionary, target_count: int) -> float:
	var archetype := weapon_archetype(config)
	var count := float(maxi(target_count, 1))
	var factor := 1.0
	if count >= 20.0 and ["aoe", "aura", "summon"].has(archetype):
		factor = 1.04
	return factor


# FAN-1031 3c-final (peer review MAJOR): калибровочная база силы взрыва ворона для бюджет-модели.
# raven_damage_multiplier — per-hit СИЛА (рантайм), не hit-COUNT: держим модель на этой фикс-базе,
# чтобы доводка множителя двигала живой per-hit «сверх бюджета», а не съедалась авто-тюнером bdm.
const RAVEN_BUDGET_REF_MULTIPLIER := 0.85


# FAN-1031 3c-final (peer review MINOR): Σ диминиш-факторов по `count` целям — зеркало рантайм-капа
# `_damage_enemies_in_circle_capped` (ближние `full` полный вес, дальше 1/(1+(rank−full+1)·diminish)).
# Сентинел override <0 → (full_default/diminish_default). Дробный count — линейно на последней цели.
static func _capped_coverage(count: float, full_override: int, diminish_override: float, full_default: int, diminish_default: float) -> float:
	var full := full_override if full_override >= 0 else full_default
	var diminish := diminish_override if diminish_override >= 0.0 else diminish_default
	var total := 0.0
	var whole := int(floor(count))
	for i in range(whole):
		total += 1.0 if i < full else 1.0 / (1.0 + float(i - full + 1) * diminish)
	var frac := count - float(whole)
	if frac > 0.0:
		total += frac * (1.0 if whole < full else 1.0 / (1.0 + float(whole - full + 1) * diminish))
	return total


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
			# SCRUM-923: спиральный каст (spiral_steps>0) кроет диск не мгновенно —
			# фронт дуги достигает внешнего кольца только к концу оборота, часть
			# внешних целей остаётся за фронтом (рантайм: BerserkWeapon._run_spiral_step,
			# 1 хит/цель/каст). Документированное среднее покрытие диска за оборот 0.85.
			if float(config.get("spiral_steps", 0.0)) > 0.0:
				return {"solo_hits": 1.0, "five_hits": clampf(1.0 + (aoe_radius / 72.0) * 0.85, 1.0, 5.0)}
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 72.0, 1.0, 5.0)}
		"strip":
			# SCRUM-921: тройной укол (thrust_count>1) — веер полос под ±fan°:
			# покрытие толпы растёт от углового размаха на дистанции. Дедуп
			# рантайма (1 хит/цель/цикл, BerserkWeapon._run_thrust_step) держит
			# solo_hits=1.0 — по одиночной цели цикл стоит столько же, сколько
			# один укол; веер оплачивается aoe-осью тюнинга.
			var strip_five := 1.0 + float(config.get("inner_width", 60.0)) / 160.0
			var thrust_count := float(config.get("thrust_count", 1.0))
			var thrust_fan := float(config.get("thrust_fan_degrees", 0.0))
			if thrust_count > 1.0 and thrust_fan > 0.0:
				strip_five += (attack_range * sin(deg_to_rad(thrust_fan))) / 260.0
				return {"solo_hits": 1.0, "five_hits": clampf(strip_five, 1.0, 3.2)}
			return {"solo_hits": 1.0, "five_hits": clampf(strip_five, 1.0, 2.1)}
		"aoe_projectile":
			var projectile_count := float(config.get("projectile_count", 1.0))
			var blast_hits := clampf(1.0 + aoe_radius / 145.0, 1.0, 3.0)
			# FAN-1031 3c-final (peer review MINOR): зеркалим per-weapon кап прямого AoE-взрыва
			# (S1 aoe_full_targets/aoe_target_diminish) в оценку hits. Без этого для оружий с
			# override (restore_potion F=1/D=4.0) модель считала полный blast_hits, завышая
			# aoe_dps ×1.7 → bdm не отражал живой срез. Сентинел <0 → дефолт (mirror class_weapon
			# AOE_PROJECTILE_* = 5/2.0); при blast_hits ≤ 3 < full=5 diminish не срабатывает →
			# нулевое изменение для всех оружий, кроме тех, у кого full < blast_hits (restore_potion).
			var capped_blast := _capped_coverage(blast_hits, int(config.get("aoe_full_targets", -1)), float(config.get("aoe_target_diminish", -1.0)), 5, 2.0)
			return {"solo_hits": 1.0, "five_hits": clampf(projectile_count * capped_blast, 1.0, 5.0), "pool_targets": clampf(1.0 + aoe_radius / 130.0, 1.0, 4.0)}
		"homing_curse":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 180.0, 1.0, 2.0), "dot_targets": 1.0}
		"dark_chain_burst":
			# SCRUM-939: цепь до chain_targets целей со спадом pierce_damage_falloff
			# по прыжкам; на каждом попадании малый бурст (chain_burst_ratio от
			# урона хита) бьёт СОСЕДЕЙ жертвы (сама жертва исключена). Solo: одна
			# цель = только первый хит, бурсту некого задевать → 1.0.
			var chain_count := clampf(float(config.get("chain_targets", 3.0)), 1.0, 5.0)
			var chain_falloff := clampf(float(config.get("pierce_damage_falloff", 0.82)), 0.1, 1.0)
			var chain_direct := 0.0
			for chain_index in range(int(chain_count)):
				chain_direct += pow(chain_falloff, float(chain_index))
			var burst_ratio := clampf(float(config.get("chain_burst_ratio", 0.45)), 0.0, 1.0)
			var burst_neighbors := clampf(aoe_radius / 95.0, 0.0, 2.0)
			return {"solo_hits": 1.0, "five_hits": clampf(chain_direct + chain_count * burst_ratio * burst_neighbors, 1.0, 5.0)}
		"skull_curse_burn":
			# SCRUM-940: прямого урона нет (curse_only гасит direct_dps выше);
			# solo = 1 проклятая цель, в толпе зона курсит несколько целей разом.
			return {"solo_hits": 1.0, "five_hits": 1.0, "dot_targets": clampf(1.0 + aoe_radius / 110.0, 1.0, 4.0)}
		"dark_mirror_blast":
			# SCRUM-941: пара взрывов. Первичный кроет кластер у цели; зеркальный
			# в среднем добавляет mirror-долю покрытия (в кластерном 5t-сценарии
			# зеркало чаще бьёт по краю/пустоте — коэффициент 0.45 покрытия).
			var mirror_ratio := maxf(float(config.get("mirror_damage_ratio", 1.0)), 0.0)
			var primary_blast := clampf(1.0 + aoe_radius / 145.0, 1.0, 3.0)
			return {"solo_hits": 1.0, "five_hits": clampf(primary_blast * (1.0 + mirror_ratio * 0.45), 1.0, 5.0), "pool_targets": clampf(1.0 + aoe_radius / 130.0, 1.0, 4.0)}
		"beam":
			var beam_count := float(config.get("beam_count", 1.0))
			var pierce := float(config.get("pierce_count", 1.0))
			return {"solo_hits": clampf(beam_count, 1.0, 2.0), "five_hits": clampf(beam_count * pierce, 1.0, 5.0)}
		"moon_split_shot":
			# SCRUM-910: болт бьёт первичную цель + расщепляется в до split_count
			# РАЗНЫХ соседей с тем же уроном. Соло — ровно 1 хит (веткам нужны
			# соседи), 5-пак — первичная + все ветки (без повторных хитов).
			var moon_splits := clampf(float(config.get("split_count", 4.0)), 0.0, 4.0)
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + moon_splits, 1.0, 5.0)}
		"storm_pierce_cone":
			# SCRUM-911: конус пробивающих стрел. Соло — один хит (дедуп на весь
			# залп: цель у вершины не собирает несколько стрел). Толпа — покрытие
			# раствором конуса на дальней дистанции (модель sweep) + пирс вглубь.
			var storm_cone := float(config.get("cone_degrees", 34.0))
			var cone_range := float(config.get("attack_range", 900.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + (storm_cone / 45.0) * (cone_range / 320.0), 1.0, 5.0)}
		"sound_wave":
			var wave_width := float(config.get("wave_width", 180.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + wave_width / 78.0, 1.0, 5.0)}
		"riff_strip":
			# SCRUM-899: узкая передняя полоса Гитариста — ПОСТОЯННАЯ полная
			# ширина wave_width на всю attack_range (в отличие от расширяющейся
			# sound_wave). В кластере из 5 ловит ~2 цели: узость — цена частых
			# хитов, позиционирование корпусом обязательное.
			var strip_width := float(config.get("wave_width", 118.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + strip_width / 105.0 + attack_range / 2600.0, 1.0, 2.6)}
		"amp":
			# SCRUM-903 raven_homing: тотемы пускают самонаводящихся воронов раз в
			# amp_pulse_interval каждый; взрыв кроет explosion_targets целей
			# (зеркало _launch_totem_raven/_resolve_raven_impact: полный урон
			# первым 3, дальше диминиш). Одновременные тотемы ограничены
			# lifetime/deploy-темпом и жёстким капом (Leadership-скейл лимита
			# сверх — рантайм-бонус, как у прочих лимитов вне модели).
			if bool(config.get("raven_homing", false)):
				var deploy_interval := maxf(float(config.get("fire_interval", 2.35)), 0.25)
				var raven_pulse := maxf(float(config.get("amp_pulse_interval", 1.1)), 0.2)
				var raven_lifetime := maxf(float(config.get("amp_lifetime", 8.0)), deploy_interval)
				var totems := minf(raven_lifetime / deploy_interval, maxf(float(config.get("max_summons_cap", 6.0)), 1.0))
				# FAN-1031 3c-final fix (peer review MAJOR): raven_damage_multiplier — это per-hit
				# СИЛА взрыва (рантайм _resolve_raven_impact: _rolled_damage × множитель), НЕ hit-COUNT.
				# Раньше она зеркалилась в hits → авто-тюнер (bdm) компенсировал ×1.59-буст оживления
				# вдвое (bdm 1.671→1.235, live per-hit +17% вместо +59%). Модель нормирует по СТРУКТУРНОМУ
				# числу воронов (rate × totems) при ФИКСИРОВАННОЙ калибровочной силе взрыва
				# RAVEN_BUDGET_REF_MULTIPLIER, поэтому доводка raven_damage_multiplier двигает живой
				# per-hit «сверх бюджета» напрямую (как summon-множители у pure_summon) и НЕ сдвигает bdm.
				var ravens_per_deploy := (deploy_interval / raven_pulse) * totems * RAVEN_BUDGET_REF_MULTIPLIER
				var explosion_targets := clampf(1.0 + float(config.get("raven_explosion_radius", 120.0)) / 145.0, 1.0, 3.0)
				return {"solo_hits": clampf(ravens_per_deploy, 1.0, 8.0), "five_hits": clampf(ravens_per_deploy * explosion_targets, 1.0, 16.0)}
			var active_ratio := float(config.get("amp_lifetime", 6.0)) / maxf(float(config.get("fire_interval", 2.0)), 0.25)
			return {"solo_hits": clampf(active_ratio / 4.0, 1.0, 2.0), "five_hits": clampf((1.0 + aoe_radius / 80.0) * active_ratio / 3.5, 1.0, 5.0)}
		"boomerang":
			# SCRUM-894: возврат идёт ЛЕВОЙ дугой, а не тем же коридором — соло-цель
			# на прямой получает гарантированно 1 проход, двойной проход требует
			# позиционирования (у разворота/у героя). Бюджетное матожидание 1.6
			# (позиционная средняя), навык двойного прохода — награда сверх бюджета.
			return {"solo_hits": 1.6, "five_hits": clampf(1.6 + float(config.get("beam_width", 48.0)) / 34.0, 1.6, 3.4)}
		"stab_flurry":
			var targets := float(config.get("projectile_count", 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(targets, 1.0, 4.0), "dot_targets": clampf(targets, 1.0, 4.0)}
		"saw_sector":
			# SCRUM-900 bone_saw: melee-сектор 120-150° — покрытие толпы растёт от
			# ширины дуги и дистанции; диминиш по целям учтён sector_full_targets.
			var cone := float(config.get("cone_degrees", 130.0))
			var full_targets := float(config.get("sector_full_targets", 4.0))
			var sector_hits := clampf(1.0 + (cone / 52.0) * (attack_range / 300.0), 1.0, minf(full_targets + 0.6, 5.0))
			return {"solo_hits": 1.0, "five_hits": sector_hits}
		"plague_dart":
			# SCRUM-900 plague_syringe: прямой дротик бьёт одну цель; ценность в
			# толпе — распространение заразы (dot_targets = ожидаемое число
			# одновременно заражённых из 5-пака при spread-шансе за тик).
			var spread_chance := clampf(float(config.get("plague_spread_chance", 0.0)), 0.0, 1.0)
			var infected := clampf(1.0 + spread_chance * 10.0, 1.0, minf(float(config.get("plague_max_infected", 5.0)), 4.4))
			return {"solo_hits": 1.0, "five_hits": 1.0, "dot_targets": infected}
		"dot_beam":
			var pierce := float(config.get("pierce_count", 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(pierce, 1.0, 5.0), "dot_targets": clampf(pierce, 1.0, 5.0)}
		"drain_link":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + float(config.get("beam_width", 40.0)) / 120.0, 1.0, 1.6), "dot_targets": 1.0}
		"trap":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 85.0, 1.0, 4.2)}
		"arquebus_shot":
			# SCRUM-936: одна взрывная пуля — полный урон цели + малый AoE соседям
			# с falloff (модель как aoe_projectile при projectile_count=1).
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 145.0, 1.0, 3.0)}
		"grenade_fuse":
			# SCRUM-937: медленный снаряд + фитиль; вся ценность — тяжёлый AoE-взрыв.
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 72.0, 1.0, 5.0)}
		"bayonet_cone":
			# SCRUM-938: ближний конус + редкий авто-выстрел (chance*mult добавкой к
			# обеим осям — пуля бьёт одну цель за конусом).
			var cone := float(config.get("cone_degrees", 100.0))
			var shot_bonus := clampf(float(config.get("bayonet_auto_shot_chance", 0.0)), 0.0, 1.0) * float(config.get("bayonet_shot_damage_multiplier", 0.7))
			var cone_hits := 1.0 + (cone / 110.0) * (attack_range / 260.0) * 1.9
			return {"solo_hits": 1.0 + shot_bonus, "five_hits": clampf(cone_hits + shot_bonus, 1.0, 4.4)}
		"coin_ricochet":
			# SCRUM-897 «Кошель Рикошета»: цепь = projectile_count прыжков (рантайм
			# капит COIN_CHAIN_HARD_CAP=8 в class_weapon.gd), урон убывает монотонно
			# до damage_falloff-доли (0.5) на ПОСЛЕДНЕМ прыжке: hit_i = tail^(i/(n-1)).
			# Толпа из 5 = сумма долей первых 5 звеньев цепи (зеркало _fire_coin_ricochet).
			var chain_count := clampf(float(config.get("projectile_count", 3.0)), 1.0, 8.0)
			var chain_tail := clampf(float(config.get("damage_falloff", 0.5)), 0.1, 1.0)
			var chain_crowd := 0.0
			for chain_index in range(mini(int(chain_count), 5)):
				chain_crowd += pow(chain_tail, float(chain_index) / maxf(chain_count - 1.0, 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(chain_crowd, 1.0, 5.0)}
		"shadow_backstab":
			# SCRUM-897 «Отравленный Кинжал»: фантом бьёт 1.22 ролла; удар в спину
			# (цель смотрит прочь от фантома — чейзеры, uptime ~0.75) даёт ×1.35
			# (BACKSTAB_* в class_weapon.gd) → соло ≈ 1.22×(1+0.35×0.75) = 1.54.
			# Соседи у точки удара получают 0.35 ролла (aoe/150 ≈ 2.7 соседа × 0.35).
			var backstab_solo := 1.22 * (1.0 + 0.35 * 0.75)
			return {"solo_hits": backstab_solo, "five_hits": clampf(backstab_solo + aoe_radius / 150.0, backstab_solo, 3.4)}
		"smoke_bomb":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 84.0, 1.0, 4.4)}
		"elemental_orbit":
			# SCRUM-948: квадрат четырёх стихий. Соло за каст = полный ролл магии
			# + физ.доля SQUARE_PHYSICAL_SHARE (0.45 × канал damage ≈ +11% на
			# базе Элементалиста, см. class_weapon.gd), периодика — dot_ticks
			# (отдельная ось _budget_dot_dps). Толпа — по площади квадрата.
			return {"solo_hits": 1.11, "five_hits": clampf(1.0 + aoe_radius / 60.0, 1.0, 5.0), "dot_targets": clampf(1.0 + aoe_radius / 90.0, 1.0, 4.0)}
		"prism_rift":
			# SCRUM-949: полнокартный X. Соло у фокуса = луч (0.72) + центр (0.55)
			# = 1.27 ролла; толпа — пирс двух диагоналей через всю арену + центр
			# (доли PRISM_* в class_weapon.gd).
			var prism_width := float(config.get("beam_width", 58.0))
			return {"solo_hits": 1.27, "five_hits": clampf(2.5 + prism_width / 45.0, 2.5, 5.0)}
		"meteor_shards":
			# SCRUM-950: одиночный тяжёлый нюк (веер осколков удалён). Соло =
			# полный центр; толпа — большой AoE с falloff (×0.78 средняя доля);
			# догорающая зона — dot_ticks по dot-оси со спадом по рангу
			# (METEOR_ZONE_* в class_weapon.gd → dot_targets ≈ 3 на 5 целях).
			return {"solo_hits": 1.0, "five_hits": clampf((1.0 + aoe_radius / 95.0) * 0.78, 1.0, 5.0), "dot_targets": 3.0}
		"sniper_lockshot":
			# SCRUM-931 (preferred-вариант): тяжёлый хит ×1.34 по САМОЙ ДАЛЬНЕЙ
			# цели + терминальный взрыв на конце (DEADEYE_ENDPOINT_BLAST_RATIO
			# 0.35, цель в центре ловит полную долю) → соло 1.69. Толпа: соло +
			# overpen-коридор (damage_falloff-доля ~1 попутчику) + сосед взрыва
			# (×0.7 средний falloff) + ближний самоподрыв close_burst_ratio от
			# хита винтовки по врагам у ног (зеркало _fire_sniper_lockshot).
			var endpoint_ratio := 0.35
			var lockshot_solo := 1.34 * (1.0 + endpoint_ratio / 1.34)
			var close_targets := clampf(float(config.get("close_burst_radius", 150.0)) / 95.0, 1.0, 2.2)
			var close_share := clampf(float(config.get("close_burst_ratio", 0.8)), 0.0, 1.5) * 1.34 * close_targets
			return {"solo_hits": lockshot_solo, "five_hits": clampf(lockshot_solo + float(config.get("damage_falloff", 0.38)) + endpoint_ratio * 0.7 + close_share, lockshot_solo, 4.6)}
		"sniper_kill_zone":
			# SCRUM-932: отложенный артиллерийский снаряд по красной метке —
			# ОДИН тяжёлый AoE через grenade_delay (~1с), серия прицельных
			# ударов удалена. Соло: полный ролл в центре зоны. Толпа: по площади
			# зоны с усреднённой falloff-долей 0.85 (зеркало
			# _damage_enemies_in_circle_falloff в _land_spotter_shell).
			return {"solo_hits": 1.0, "five_hits": clampf((1.0 + aoe_radius / 85.0) * 0.85, 1.0, 4.6)}
		"sniper_split_round":
			# SCRUM-933: скорострельный круговой веер пуль по ближним монстрам
			# (сплит-чейн удалён). Соло: одна цель ловит не больше
			# SHATTER_VOLLEY_HIT_LIMIT (2) пуль за залп (анти-runaway кап,
			# зеркало _fire_sniper_split_round). Толпа: почти все пули находят
			# цель round-robin'ом (эффективность прицеливания 0.92); пули без
			# цели уходят радиально и урона не наносят.
			var spray_bullets := float(config.get("projectile_count", 6.0))
			return {"solo_hits": minf(spray_bullets, 2.0), "five_hits": clampf(spray_bullets * 0.92, 1.0, 5.2)}
		"priest_sanctify":
			# SCRUM-927: бурст «тик-тик-тик» — серия storm_ticks вспышек по
			# sanctify_tick_ratio ролла каждая; соло-цель ловит ВСЕ тики (знак
			# ведёт цель), толпа — по малому радиусу с falloff (зеркало
			# class_weapon._sanctify_burst_tick). Лечения у оружия нет.
			var sanctify_ticks := maxf(float(config.get("storm_ticks", 3.0)), 1.0)
			var sanctify_ratio := clampf(float(config.get("sanctify_tick_ratio", 0.38)), 0.05, 1.0)
			var sanctify_total := sanctify_ticks * sanctify_ratio
			return {"solo_hits": clampf(sanctify_total, 0.5, 2.4), "five_hits": clampf(sanctify_total * (1.0 + aoe_radius / 145.0), 1.0, 4.8)}
		"priest_ward":
			# SCRUM-928: редкие тяжёлые волны вокруг Священника, последняя —
			# ПОЛНЫЙ aoe_radius (радиусный AoE-специалист с медленной каденцией;
			# зеркало lerp(0.80,1.0) в class_weapon._fire_priest_ward — соло-цель
			# вплотную ловит обе волны, 0.85-дисконт за раскрытие радиуса).
			var ward_ticks := float(config.get("storm_ticks", 2.0))
			return {"solo_hits": clampf(ward_ticks * 0.85, 1.0, 2.6), "five_hits": clampf(1.0 + aoe_radius / 70.0, 1.0, 4.5)}
		"priest_dual_toll":
			# SCRUM-929: dual toll — два одновременных взрыва (у цели и у Жреца)
			# с общим дедупом (враг ≤ 1 взрыв за каст) → соло ровно 1 полный хит.
			# Толпа: покрытие цели (1 + aoe/95 с запасом на второй центр у Жреца,
			# ~0.55 средней добавки — часть толпы прессует героя), кап 4.4.
			return {"solo_hits": 1.0, "five_hits": clampf(1.55 + aoe_radius / 105.0, 1.0, 4.4)}
		"bio_spore_bloom":
			# SCRUM-896: три расширяющихся кольца у персонажа — соло-цель ловит
			# все кольца с falloff (1+0.7+0.49≈2.19 → сохранена 0.34-модель),
			# толпа — по радиусу; биоинфекция вешается на ВСЕХ задетых
			# (dot_targets), зеркало class_weapon._bio_spore_pulse.
			var bloom_ticks := float(config.get("storm_ticks", 3.0))
			return {"solo_hits": clampf(1.0 + bloom_ticks * 0.34, 1.0, 2.4), "five_hits": clampf(1.0 + aoe_radius / 58.0, 1.0, 5.0), "dot_targets": clampf(1.0 + aoe_radius / 85.0, 1.0, 4.0)}
		"bio_sample_dart":
			# SCRUM-896: пирсинг-луч на всю длину (полный ролл каждому на линии)
			# + малый бурст анализа на конце (tip_burst_ratio) + физ.доля
			# INJECTOR_PHYSICAL_SHARE канала damage на каждый хит луча: базовый
			# факт-фактор 1.13 = 1 + 0.5×(damage/magic на базе Биолога 3/11.2),
			# зеркало class_weapon._fire_bio_sample_dart. Инфекция — только
			# ближайший на луче (dot_targets 1).
			var tip_ratio := clampf(float(config.get("tip_burst_ratio", 0.55)), 0.0, 1.0)
			var line_hits := clampf(1.0 + (attack_range / 420.0) * (float(config.get("beam_width", 46.0)) / 60.0), 1.0, 3.2)
			var injector_phys_factor := 1.13
			return {"solo_hits": (1.0 + tip_ratio) * injector_phys_factor, "five_hits": clampf((line_hits + tip_ratio * clampf(aoe_radius / 145.0, 0.0, 2.0)) * injector_phys_factor, 1.0, 4.8), "dot_targets": 1.0}
		"bio_symbiote_web":
			# SCRUM-896: семя-зона с прорастанием — стартовый маг.хит
			# seed_impact_ratio с falloff по области, главный пейофф в
			# биоинфекции всех задетых (dot-ось), зеркало
			# class_weapon._germinate_symbiote_seed.
			var impact_ratio := clampf(float(config.get("seed_impact_ratio", 0.85)), 0.0, 1.5)
			return {"solo_hits": impact_ratio, "five_hits": clampf(impact_ratio * (1.0 + aoe_radius / 110.0), 0.5, 4.0), "dot_targets": clampf(1.0 + aoe_radius / 95.0, 1.0, 4.0)}
		"robot_magnetic_anchor":
			# SCRUM-915: тяжёлый AoE-пулл — рядовые стягиваются к центру зоны
			# (конвергенция 0.85, ClassWeapon._pull_enemies_toward), поэтому
			# следующие касты бьют сгруппированную толпу ближе к falloff-центру:
			# группировка учтена мягким бонусом плотности +12% к толпе. Элитки/
			# боссы не смещаются (контроль-ось, в DPS-модель не входит).
			return {"solo_hits": 1.0, "five_hits": clampf((1.0 + aoe_radius / 80.0) * 1.12, 1.0, 4.8)}
		"robot_compression_line":
			# SCRUM-916: урон по ВСЕЙ ширине коридора suppression_width
			# (зеркало _fire_robot_compression_line: width_override), компрессия
			# к оси — контроль-ось. Толпа — от полной ширины коридора.
			var compression_width := float(config.get("suppression_width", 220.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + compression_width / 82.0, 1.0, 4.6)}
		"robot_reactor_vent":
			# SCRUM-918: вращающийся веер — ровно 4 фикс-вентиля (без
			# самонаведения), пер-вентильный урон = ролл × vent_ratio (зеркало
			# ClassWeapon.REACTOR_VENT_DAMAGE_RATIO). Соло: identity ближнего
			# контроля — чейзер на контактной дистанции покрыт лопастью
			# (coverage ~1.0) => один вентиль за каст = vent_ratio ролла; толпа —
			# прежняя форма «вентили + площадь», масштабированная vent_ratio.
			var vent_count := float(config.get("projectile_count", 4.0))
			var vent_ratio := 0.42
			return {"solo_hits": vent_ratio, "five_hits": clampf((1.0 + vent_count * 0.70 + aoe_radius / 150.0) * vent_ratio, 0.5, 5.0)}
		"engineer_sentry_link":
			# SCRUM-888: турели. Прямой компонент — мгновенный первый выстрел при
			# развёртке (1 цель); сустейн стрельбы турелей считает _budget_summon_dps
			# (max_summons × damage × summon_damage_multiplier / summon_attack_interval).
			# Толпу добирают: залп по РАЗНЫМ ближайшим целям (projectile_count со
			# спадом damage_falloff^i; одиночная цель получает только 1-й снаряд —
			# соло-ось не греется) и сплэш снаряда (cap целей со спадом 1/(1+0.75i))
			# — зеркала sentry_turret.try_fire и _damage_engineer_sentry_splash.
			var sentry_splash_bonus := 0.0
			if float(config.get("sentry_splash_radius", 0.0)) > 0.0:
				var sentry_splash_cap := maxi(int(config.get("sentry_splash_target_cap", 0)), 0)
				var sentry_splash_mult := maxf(float(config.get("sentry_splash_damage_multiplier", 0.0)), 0.0)
				for sentry_splash_index in range(sentry_splash_cap):
					sentry_splash_bonus += sentry_splash_mult / (1.0 + float(sentry_splash_index) * 0.75)
			var sentry_volley := maxi(int(config.get("projectile_count", 1)), 1)
			var sentry_volley_falloff := clampf(float(config.get("damage_falloff", 0.55)), 0.05, 1.0)
			var sentry_volley_crowd := 1.0
			for sentry_volley_index in range(1, sentry_volley):
				sentry_volley_crowd += pow(sentry_volley_falloff, float(sentry_volley_index))
			var sentry_crowd_factor := sentry_volley_crowd * (1.0 + sentry_splash_bonus)
			return {"solo_hits": 1.0, "five_hits": sentry_crowd_factor, "summon_targets": sentry_crowd_factor}
		"engineer_orbit_drone":
			# SCRUM-906: прямого канала нет (direct_dps = 0); crowd-фактор
			# контакта пишет _budget_orbit_drone_dps в summon_targets.
			return {"solo_hits": 1.0, "five_hits": 1.0}
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


# SCRUM-900: старт ramp-фактора чумного тика (первые тики слабее — «давление
# по карте», а не мгновенный бурст; растёт до 1.0 за plague_ramp_ticks).
const PLAGUE_RAMP_START := 0.45


# SCRUM-900: единый профиль чумного DoT — источник истины и для рантайма
# (ClassWeapon._apply_plague_infection), и для budget-модели (_budget_dot_dps),
# чтобы тюнинг-гейт считал ту же чуму, что тикает в бою.
# Скейл: тик = magic_damage × plague_tick_ratio + dot_damage × plague_dot_coupling;
# интервал тика ускоряется статом dot_speed; длительность фиксирована конфигом.
static func plague_tick_profile(config: Dictionary, params: Dictionary) -> Dictionary:
	var magic := float(params.get("magic_damage", params.get("damage", 1.0)))
	var dot_damage := float(params.get("dot_damage", 1.0))
	var dot_speed := maxf(float(params.get("dot_speed", 1.0)), 0.2)
	var tick_interval := maxf(float(config.get("plague_tick_interval", 2.0)) / dot_speed, 0.45)
	var duration := maxf(float(config.get("plague_duration", 24.0)), tick_interval)
	var ticks := maxi(int(floor(duration / tick_interval)), 1)
	var ramp_ticks := maxi(int(config.get("plague_ramp_ticks", 5)), 1)
	var tick_damage := magic * float(config.get("plague_tick_ratio", 0.22)) \
		+ dot_damage * float(config.get("plague_dot_coupling", 0.6))
	var ramp_sum := 0.0
	for tick_index in range(ticks):
		ramp_sum += plague_ramp_factor(tick_index, ramp_ticks)
	return {
		"tick_damage": tick_damage,
		"tick_interval": tick_interval,
		"ticks": ticks,
		"ramp_average": ramp_sum / float(ticks),
	}


static func plague_ramp_factor(tick_index: int, ramp_ticks: int) -> float:
	var progress := clampf(float(tick_index) / float(maxi(ramp_ticks, 1)), 0.0, 1.0)
	return lerpf(PLAGUE_RAMP_START, 1.0, progress)


static func _budget_dot_dps(config: Dictionary, params: Dictionary, interval: float, stats := {}) -> float:
	# SCRUM-900 plague_dart: длинная зараза (24с) с рефрешем при повторном
	# попадании ⇒ на одиночной цели устойчивый DoT-поток, независимый от
	# fire_interval (перезаражение лишь поддерживает 100% uptime).
	if str(config.get("attack_mode", "")) == "plague_dart":
		var profile := plague_tick_profile(config, params)
		return float(profile.get("tick_damage", 0.0)) * float(profile.get("ramp_average", 1.0)) \
			/ maxf(float(profile.get("tick_interval", 1.0)), 0.18) \
			* class_periodic_damage_multiplier(str(config.get("character_id", "")))
	var ticks := float(config.get("dot_ticks", 0.0))
	if ticks <= 0.0:
		return 0.0
	# SCRUM-940: документированный curse-пайплайн черепа — сила тика =
	# dot_damage * curse_tick_multiplier * (1 + Интеллект * curse_int_scale);
	# зеркалит class_weapon._apply_skull_curse_zone. Для прочих оружий
	# multiplier=1.0 / int_scale=0.0 — формула тождественна прежней.
	var tick_multiplier := maxf(float(config.get("curse_tick_multiplier", 1.0)), 0.0)
	# SCRUM-896: биоинфекции — status-based с refresh (1 стак): перекаст НЕ
	# мультиплицирует тики, поэтому устоявшийся DPS = тик × каденция
	# (dot_speed × curse_tick_rate; интервал ≥0.1с — кламп StatusEffects.tick),
	# а НЕ ticks/каст. Ось скейлится dot_damage/dot_speed (Знание/Энергия), не
	# скоростью атаки; длительность (dot_ticks+0.99)×интервал перекрывает
	# интервал каста — uptime в затяжном бою ≈1. Зеркало —
	# class_weapon._apply_bio_infection (рантайм применяет статус через
	# StatusEffects.apply_status_from — классовый периодический множитель
	# SCRUM-942 запекается там же; у Биолога он 1.0).
	if str(config.get("attack_mode", "")).begins_with("bio_"):
		var bio_rate := maxf(float(config.get("curse_tick_rate", 1.0)), 0.2)
		var bio_interval := maxf(1.0 / (maxf(float(params.get("dot_speed", 1.0)), 0.2) * bio_rate), 0.1)
		return float(params.get("dot_damage", 1.0)) * tick_multiplier / bio_interval \
			* class_periodic_damage_multiplier(str(config.get("character_id", "")))
	var stats_map: Dictionary = stats if stats is Dictionary else {}
	var curse_depth := 1.0 + maxf(float(stats_map.get("intelligence", 0.0)), 0.0) * maxf(float(config.get("curse_int_scale", 0.0)), 0.0)
	# SCRUM-942: DoT-тики — периодический канал, множится классовым trait'ом
	# (у классов без trait'а множитель 1.0 — формула тождественна прежней).
	return float(params.get("dot_damage", 1.0)) * tick_multiplier * curse_depth * ticks / maxf(interval, 0.18) \
		* class_periodic_damage_multiplier(str(config.get("character_id", "")))


static func _budget_pool_dps(config: Dictionary, params: Dictionary, interval: float) -> float:
	if not bool(config.get("leaves_pool", false)):
		return 0.0
	# SCRUM-903: терновая зона Друида — повторные ФИЗИЧЕСКИЕ хиты с капом на
	# врага/зону (зеркало class_weapon._briar_zone_tick): хит = damage-параметр
	# оружия × briar_hit_multiplier, хитов на врага с одной зоны =
	# min(briar_hit_cap, duration/tick). Периодик-множители НЕ применяются —
	# это не dot-ось (dot_damage в терновом канале не участвует).
	if bool(config.get("briar_zone", false)):
		var briar_tick := maxf(float(config.get("pool_tick_interval", 0.6)), 0.18)
		var briar_hits := minf(float(config.get("briar_hit_cap", 5)), floor(maxf(float(config.get("pool_duration", 3.0)), briar_tick) / briar_tick))
		var briar_hit_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) * maxf(float(config.get("briar_hit_multiplier", 0.34)), 0.0)
		return briar_hit_damage * briar_hits / maxf(interval, 0.18)
	var tick_interval := maxf(float(config.get("pool_tick_interval", 0.6)), 0.18)
	var uptime := minf(float(config.get("pool_duration", 3.0)) / maxf(interval, 0.18), 1.0)
	# SCRUM-944: per-weapon скалер тика лужи (зеркало ClassWeapon._spawn_damage_pool).
	var tick_scale := maxf(float(config.get("pool_tick_damage_multiplier", 1.0)), 0.0)
	# SCRUM-942: тики лужи — периодический канал, множится классовым trait'ом.
	var periodic_mult := class_periodic_damage_multiplier(str(config.get("character_id", "")))
	var pool_dps := float(params.get("dot_damage", 1.0)) * tick_scale / tick_interval * uptime * periodic_mult
	return pool_dps + _budget_pool_charge_dps(config, params, periodic_mult)


# SCRUM-944: бюджет перманентных контактных зарядов лужи (кислотная колба).
# Зеркалит ClassWeapon._apply_pool_contact_statuses: враг копит по одному вечному
# DoT-заряду с каждой РАЗНОЙ лужи (кап pool_charge_cap), тик = dot_damage ×
# pool_charge_tick_multiplier / pool_charge_tick_interval. Ramp-фактор 0.5 —
# заряды набираются по мере прохода луж, к концу бюджет-окна выходят на кап.
static func _budget_pool_charge_dps(config: Dictionary, params: Dictionary, periodic_mult: float) -> float:
	if not bool(config.get("pool_contact_charges", false)):
		return 0.0
	var cap := maxf(float(config.get("pool_charge_cap", 5.0)), 1.0)
	var tick_multiplier := maxf(float(config.get("pool_charge_tick_multiplier", 0.30)), 0.0)
	var tick_interval := maxf(float(config.get("pool_charge_tick_interval", 0.9)), 0.18)
	const CHARGE_RAMP_FACTOR := 0.5
	return float(params.get("dot_damage", 1.0)) * tick_multiplier * cap * CHARGE_RAMP_FACTOR / tick_interval * periodic_mult


# SCRUM-946: бюджет волн гомункула-кастера (пара «танк+кастер»). Зеркалит
# summoner_weapon._update_homunculus_pair: неуязвимый кастер каждые
# summon_wave_interval вешает вечный DoT-заряд (кап summon_wave_stack_cap),
# тик = dot_damage × summon_wave_dot_multiplier / summon_wave_dot_interval.
# Ramp-фактор 0.5 — стаки волн копятся к капу за первые ~cap×interval секунд окна.
static func _budget_summon_wave_dps(config: Dictionary, params: Dictionary) -> float:
	if float(config.get("summon_wave_interval", 0.0)) <= 0.0:
		return 0.0
	var cap := maxf(float(config.get("summon_wave_stack_cap", 4.0)), 1.0)
	var tick_multiplier := maxf(float(config.get("summon_wave_dot_multiplier", 0.35)), 0.0)
	var tick_interval := maxf(float(config.get("summon_wave_dot_interval", 1.0)), 0.18)
	const WAVE_RAMP_FACTOR := 0.5
	return float(params.get("dot_damage", 1.0)) * tick_multiplier * cap * WAVE_RAMP_FACTOR / tick_interval \
		* class_periodic_damage_multiplier(str(config.get("character_id", "")))


static func _budget_summon_dps(config: Dictionary, params: Dictionary, stats := {}) -> float:
	if int(config.get("max_summons", 0)) <= 0 and not config.has("summon_damage_multiplier"):
		return 0.0
	# SCRUM-903: выход вороньего тотема ЦЕЛИКОМ смоделирован amp-веткой
	# _budget_hit_model (raven_homing) — фантомный summon-канал от max_summons
	# создал бы двойной счёт одного и того же урона.
	if bool(config.get("raven_homing", false)):
		return 0.0
	var summon_count: float = maxf(float(config.get("max_summons", 1.0)), 1.0) + floor(float(params.get("summon_amount", 0.0)) / 4.0)
	var summon_amount := float(params.get("summon_amount", 0.0))
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var attack_interval := maxf(float(config.get("summon_attack_interval", 0.45)) / (1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)), 0.18)
	var role_factor := _budget_summon_role_damage_factor(config, params, stats)
	# SCRUM-902: ростер-оружие (амулет Друида) — базовый стат КОМПОЗИЦИОННО
	# взвешен по семьям ростера: physical-звери растут от damage (Сила),
	# magic-духи — от magic_damage (Интеллект). Зеркалит summoner_weapon
	# ._summon_profile (family_parameter per запись; дальние духи бьют реже, но
	# тяжелее — per-body DPS равен melee, отдельная модель темпа не нужна).
	var base_stat := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0)))
	var roster: Array = config.get("summon_roster", [])
	if not roster.is_empty():
		var weighted := 0.0
		for entry_raw in roster:
			var entry: Dictionary = entry_raw if entry_raw is Dictionary else {}
			var family_parameter := "magic_damage" if str(entry.get("family", "")) == "magic" else "damage"
			weighted += float(params.get(family_parameter, params.get("damage", 1.0)))
		base_stat = weighted / float(roster.size())
	var summon_damage := base_stat * float(config.get("summon_damage_multiplier", 0.36)) * role_factor
	return summon_count * summon_damage / attack_interval


# SCRUM-905: пропускная способность турелей с боезапасом — зеркало
# scripts/sentry_turret.gd + class_weapon._engineer_turret_limit 1:1.
# Спрос парка = capacity выстрелов раз в effective-pulse (pulse / tempo-lift /
# attack_speed, пол 0.10с; соло — 1 снаряд/пульс на турель, толпа — залп
# projectile_count); предложение = magazine выстрелов с каждым деплоем
# (fire_interval / attack_speed). Устойчивый DPS = min(спрос, предложение) —
# скорость атаки ускоряет и стрельбу, и восполнение (AC SCRUM-905), Лидерство
# растит capacity (2 + floor(summon_amount/4), рельс max_summons_cap).
static func _budget_sentry_ammo_model(config: Dictionary, params: Dictionary, stats := {}) -> Dictionary:
	if str(config.get("attack_mode", "")) != "engineer_sentry_link" or int(config.get("sentry_shot_magazine", 0)) <= 0:
		return {}
	var magazine := float(config.get("sentry_shot_magazine", 15))
	var attack_speed := maxf(float(params.get("attack_speed", 1.0)), 0.1)
	var deploy_interval := maxf(float(config.get("fire_interval", 2.7)) / attack_speed, 0.18)
	var supply_rate := magazine / deploy_interval
	var summon_amount := maxf(float(params.get("summon_amount", 0.0)), 0.0)
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var tempo := 1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)
	var pulse := maxf(maxf(float(config.get("amp_pulse_interval", 0.55)), 0.18) / tempo / attack_speed, 0.10)
	var capacity := maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(summon_amount / 4.0), 1.0)
	if int(config.get("max_summons_cap", 0)) > 0:
		capacity = minf(capacity, float(config.get("max_summons_cap", 6)))
	var demand_solo := capacity / pulse
	var volley := maxi(int(config.get("projectile_count", 1)), 1)
	var falloff := clampf(float(config.get("damage_falloff", 0.55)), 0.05, 1.0)
	var volley_quality := 0.0
	for volley_index in range(volley):
		volley_quality += pow(falloff, float(volley_index))
	var splash_bonus := 0.0
	if float(config.get("sentry_splash_radius", 0.0)) > 0.0:
		var splash_cap := maxi(int(config.get("sentry_splash_target_cap", 0)), 0)
		var splash_mult := maxf(float(config.get("sentry_splash_damage_multiplier", 0.0)), 0.0)
		for splash_index in range(splash_cap):
			splash_bonus += splash_mult / (1.0 + float(splash_index) * 0.75)
	var role_factor := _budget_summon_role_damage_factor(config, params, stats)
	var shot_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) 		* float(config.get("summon_damage_multiplier", 1.0)) * role_factor
	var solo_dps := minf(demand_solo, supply_rate) * shot_damage
	var aoe_dps := minf(demand_solo * float(volley), supply_rate) * shot_damage 		* (volley_quality / float(volley)) * (1.0 + splash_bonus)
	return {
		"summon_dps": solo_dps,
		"summon_targets": aoe_dps / maxf(solo_dps, 0.001),
	}


# SCRUM-906: контактный DPS орбитальных дронов — зеркало
# scripts/engineer_orbit_drone.gd + class_weapon._engineer_drone_target_count.
# Число дронов = max_summons + floor(max(summon_amount - threshold, 0) / step),
# рельс max_summons_cap (база Инженера ~12.5 → ровно 2 дрона). Оборотов/с =
# drone_orbit_speed × attack_speed / TAU (скорость атаки крутит RPM, AC);
# хитов/с на дрона по одной цели = min(обороты, 1/hit_cooldown) — дрон
# пересекает угловую позицию цели раз за оборот, per-enemy кулдаун гейтит
# сверху. Толпа: кольцо орбиты накрывает clamp(1 + (внешний радиус спирали +
# контакт)/58, 1, 5) целей бюджет-пятёрки.
static func _budget_orbit_drone_dps(config: Dictionary, params: Dictionary, stats := {}) -> Dictionary:
	if str(config.get("attack_mode", "")) != "engineer_orbit_drone":
		return {}
	var attack_speed := maxf(float(params.get("attack_speed", 1.0)), 0.1)
	var rev_rate := maxf(float(config.get("drone_orbit_speed", 3.6)), 0.5) * attack_speed / TAU
	var hit_cooldown := maxf(float(config.get("drone_hit_cooldown", 0.85)), 0.1)
	var pass_rate := minf(rev_rate, 1.0 / hit_cooldown)
	var summon_amount := maxf(float(params.get("summon_amount", 0.0)), 0.0)
	var threshold := float(config.get("drone_count_threshold", 12.0))
	var step := maxf(float(config.get("drone_count_step", 4.0)), 0.5)
	var count := maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(maxf(summon_amount - threshold, 0.0) / step), 1.0)
	if int(config.get("max_summons_cap", 0)) > 0:
		count = minf(count, float(config.get("max_summons_cap", 6)))
	var role_factor := _budget_summon_role_damage_factor(config, params, stats)
	var contact_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) 		* float(config.get("summon_damage_multiplier", 0.9)) * role_factor
	var solo_dps := count * contact_damage * pass_rate
	# FAN-1075: стартовая пара находится на одном кольце; спираль начинается
	# с третьего дрона и зеркалит engineer_orbit_drone._orbit_radius.
	var outer_slot := 0.0
	if count > 2.0:
		outer_slot = count - 1.0
	var outer_radius := maxf(float(config.get("drone_orbit_radius", 121.0)), 24.0) * (1.0 + 0.14 * outer_slot)
	var ring_coverage := clampf(1.0 + (outer_radius + maxf(float(config.get("drone_contact_radius", 44.0)), 8.0)) / 58.0, 1.0, 5.0)
	return {
		"summon_dps": solo_dps,
		"summon_targets": ring_coverage,
	}


# SCRUM-908 «Сеть мастерской»: бюджет-зеркало ClassWeapon._workshop_network_factor.
# Ожидаемые стеки в устойчивом бою (по типу устройства):
#   - турели: min(capacity, жизнь магазина / интервал деплоя) — боезапас
#     ограничивает одновременный парк;
#   - дроны: постоянный парк = число дронов;
#   - мины: кап × вес 0.5 × заполненность 0.33 (в бою мины детонируют быстро).
# Стеки клампятся капом сети (cap_base + floor(Лидерство/step)); фактор =
# 1 + стеки × per_stack. У классов без trait'а per_stack = 0 → фактор 1.0.
static func _budget_network_factor(config: Dictionary, params: Dictionary, stats := {}) -> float:
	var trait_config: Dictionary = CLASS_TRAITS.get(str(config.get("character_id", "")), {}) as Dictionary
	var per_stack := float(trait_config.get("network_damage_per_stack", 0.0))
	if per_stack <= 0.0:
		return 1.0
	var summon_amount := maxf(float(params.get("summon_amount", 0.0)), 0.0)
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var cap := maxf(float(trait_config.get("network_stack_cap_base", 3.0)) 		+ floor(maxf(leadership, 0.0) / maxf(float(trait_config.get("network_cap_leadership_step", 6.0)), 1.0)), 0.0)
	var mode := str(config.get("attack_mode", ""))
	var expected := 0.0
	match mode:
		"engineer_sentry_link":
			var attack_speed := maxf(float(params.get("attack_speed", 1.0)), 0.1)
			var tempo := 1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)
			var pulse := maxf(maxf(float(config.get("amp_pulse_interval", 0.55)), 0.18) / tempo / attack_speed, 0.10)
			var magazine_life := float(config.get("sentry_shot_magazine", 15)) * pulse
			var deploy_interval := maxf(float(config.get("fire_interval", 2.7)) / attack_speed, 0.18)
			var capacity := maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(summon_amount / 4.0), 1.0)
			if int(config.get("max_summons_cap", 0)) > 0:
				capacity = minf(capacity, float(config.get("max_summons_cap", 6)))
			expected = minf(capacity, magazine_life / deploy_interval)
		"engineer_orbit_drone":
			var threshold := float(config.get("drone_count_threshold", 12.0))
			var step := maxf(float(config.get("drone_count_step", 4.0)), 0.5)
			expected = maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(maxf(summon_amount - threshold, 0.0) / step), 1.0)
			if int(config.get("max_summons_cap", 0)) > 0:
				expected = minf(expected, float(config.get("max_summons_cap", 6)))
		"engineer_pressure_mines":
			expected = float(config.get("mine_active_cap", 6)) * float(trait_config.get("network_mine_weight", 0.5)) * 0.33
		_:
			return 1.0
	return 1.0 + minf(expected, cap) * per_stack


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
	var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
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
		aura_radius = base_area + leadership * 5.0 + float(stats.get("perception", 0.0)) * 0.80 + float(stats.get("energy", 0.0)) * 0.65 + float(stats.get("knowledge", 0.0)) * 0.45

	return {
		"damage": (physical_base * weapon_damage_multiplier * damage_multiplier + universal_damage_flat) * sandbox_damage_multiplier,
		"magic_damage": (magic_base * weapon_damage_multiplier * damage_multiplier * magic_damage_multiplier + universal_damage_flat) * sandbox_damage_multiplier,
		"attack_speed": attack_speed,
		"attack_cadence_multiplier": attack_cadence_multiplier,
		"crit_chance": effective_crit_chance(crit_chance_raw, float(crit_profile.get("cap", CRIT_CHANCE_CAP)), float(crit_profile.get("diminish", CRIT_CHANCE_DIMINISH))),
		"crit_damage_multiplier": effective_crit_damage_multiplier(agility, crit_damage_flat),
		"move_speed": (282.0 + agility * 6.2) * move_speed_multiplier,
		"dodge": effective_dodge(0.02 + agility * 0.010 + float(run_modifiers.get("dodge_flat", 0.0)) + clampf(float(run_modifiers.get("flurry_tempo_dodge_bonus", 0.0)), 0.0, 0.20) * flurry_tempo_active),
		"defense": effective_defense(0.04 + endurance * 0.018 + defense_flat),
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
		"vampiric_amount": float(run_modifiers.get("vampiric_amount_flat", 0.0)) * VAMPIRIC_BASE_HEAL_MULTIPLIER,
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
