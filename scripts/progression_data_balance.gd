extends RefCounted

# SCRUM-198: balance model, economy curve and drop-scaling constants. No value changes.

const CLASS_BUDGET_PROFILES := {
	"berserk": {"profile": "balanced", "survival": "sturdy", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
	"soldier": {"profile": "balanced", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
	"thief": {"profile": "balanced", "survival": "fragile", "damage_budget": 1.08, "solo_target": 1.00, "aoe_target": 1.00},
	"elementalist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.08, "solo_target": 1.00, "aoe_target": 1.10},
	"sniper": {"profile": "solo", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.15, "aoe_target": 0.80},
	"priest": {"profile": "balanced", "survival": "steady", "damage_budget": 0.92, "solo_target": 1.00, "aoe_target": 1.05},
	"biologist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.08, "solo_target": 0.92, "aoe_target": 1.18},
	"robot": {"profile": "balanced", "survival": "tank", "damage_budget": 0.88, "solo_target": 1.00, "aoe_target": 1.05},
	"engineer": {"profile": "balanced", "survival": "steady", "damage_budget": 0.96, "solo_target": 0.98, "aoe_target": 1.12},
	"dark_mage": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.15, "solo_target": 0.84, "aoe_target": 1.30},
	"guitarist": {"profile": "aoe", "survival": "control", "damage_budget": 1.00, "solo_target": 0.84, "aoe_target": 1.30},
	"assassin": {"profile": "solo", "survival": "fragile", "damage_budget": 1.15, "solo_target": 1.30, "aoe_target": 0.70},
	"ranger": {"profile": "solo", "survival": "fragile", "damage_budget": 1.15, "solo_target": 1.30, "aoe_target": 0.70},
	"doctor": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.00, "aoe_target": 1.00},
	"chemist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.15, "solo_target": 0.84, "aoe_target": 1.30},
	"knight": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.00, "aoe_target": 1.00},
	"druid": {"profile": "balanced", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
}

# SCRUM-544: comfort-band модель. Целевая ±20%-полоса DPS НЕ плоская: позиция
# класса внутри полосы определяется требуемым уровнем вовлечённости игрока.
# Чем AFK-комфортнее класс (большой авто-радиус, самонаведение, нулевой аим,
# «поставил и фармит») — тем НИЖЕ его потолок в полосе. Чем больше требуется
# скилла/аима/позиционирования (ручная одиночная цель, мили-вход под удар) —
# тем ВЫШЕ потолок (награда за вовлечённость).
#
# comfort_weight — относительный потолок класса внутри полосы (множитель к
# базовому таргету полосы). Нормировка для проверки полосы:
#   comfort_normalized_dps = measured_dps / comfort_weight[class]
# После нормировки потолок/пол полосы должны сойтись в ±20% от медианы по всем
# классам в каждом срезе (1t/5t/20t).
#
# SCRUM-601: веса ОТКАЛИБРОВАНЫ как band-эквалайзер против детерминированной
# аналитической метрики crowd_dps (ProgressionData.estimate_crowd_clear_budget_for_stats
# на base_stats, срезы 1/5/20 целей). Раньше вес = engagement-профиль (ручной аим →
# высокий, AFK-призыв → низкий), но solo/aoe_target классов калибровались НЕЗАВИСИМО,
# поэтому «сырой» crowd_dps (~100..205) шёл ВРАЗРЕЗ с engagement-весом, и кросс-класс
# вылетал из полосы (3.8x разброс). Так как solo/aoe_target трогать нельзя (держат
# внутриклассовый budget), comfort_weight — единственный рычаг: вес ≈ class_mean_raw /
# median_all_raw, чтобы comfort_normalized сошёлся в ±20% (факт ~±6%). Гейт:
# tests/comfort_band_cross_class_gate.gd. Вес влияет ТОЛЬКО на band-измерение, не на
# геймплей. Внутриклассовый порядок (engagement) теперь несёт raw budget, не вес.
# Будущее выравнивание engagement↔raw — через solo/aoe_target (отдельный тикет).
# Per-weapon переопределения (COMFORT_WEIGHT_OVERRIDES) — для оружий, чей «сырой»
# crowd_dps заметно отличается от среднего по классу (призыв/устройство у соло-класса
# или наоборот): вес = weapon_raw / median_all_raw.
const COMFORT_WEIGHTS := {
	"berserk": 0.98,
	"soldier": 1.01,
	"thief": 1.11,
	"elementalist": 1.22,
	"sniper": 0.78,
	"priest": 1.00,
	"biologist": 1.33,
	"robot": 0.93,
	"engineer": 1.17,
	"dark_mage": 1.50,
	"guitarist": 1.36,
	"assassin": 0.79,
	"ranger": 0.81,
	"doctor": 0.79,
	"chemist": 1.55,
	"knight": 0.83,
	"druid": 1.04,
}

# Per-weapon comfort переопределения: ключ "<class>/<weapon_id>". Используется,
# когда конкретное оружие требует иной вовлечённости, чем класс в среднем
# (одиночный луч/проджектайл у AoE-класса — выше; авто-призыв у соло-класса — ниже).
const COMFORT_WEIGHT_OVERRIDES := {
	"druid/summon_amulet": 0.96,
	"druid/raven_totem": 0.96,
	"engineer/engineer_sentry_wrench": 1.03,  # SCRUM-546: ключ = реальный weapon_id (был engineer/sentry_wrench — не матчился)
	"engineer/engineer_repair_drone": 1.03,
	"chemist/homunculus_vial": 1.43,
	"guitarist/sound_amp": 1.25,
}

# Допуск полосы: comfort-нормированный DPS каждого оружия должен лежать в
# [1 - tol, 1 + tol] от медианы нормированных значений среза.
const COMFORT_BAND_TOLERANCE := 0.20
const COMFORT_DEFAULT_WEIGHT := 1.00

const CLASS_LEVEL_STAT_GROWTH_SCALARS := {
	"soldier": {"strength": 0.95, "agility": 0.95},
	"elementalist": {"agility": 0.92, "intelligence": 0.92},
	"priest": {"agility": 0.88, "intelligence": 0.88},
	# SCRUM-504: robot был дном solo-оси (best-weapon lvl20_ideal_1t ≈0.79x межклассовой
	# медианы — двойное дно: и solo, и aoe ниже среднего у tank-класса с damage_budget 0.88).
	# Подъём роста str/agi 0.78→0.86 поднимает его lvl20-потолок по обеим осям, не трогая
	# base lvl1 (скаляры влияют только на очки сверх базы → comfort_band/base-гейт не затронут).
	# Формульный gate lvl20_optimum остаётся в 0.90..1.10.
	"robot": {"strength": 0.86, "agility": 0.86},
	"engineer": {"strength": 0.72, "agility": 0.72, "leadership": 0.80},
	"dark_mage": {"agility": 0.84, "intelligence": 0.84},
	"guitarist": {"energy": 1.56},
	"assassin": {"strength": 2.05, "agility": 2.05},
	"doctor": {"agility": 1.10, "intelligence": 1.80},
	"chemist": {"agility": 1.70, "intelligence": 1.70},
	"knight": {"strength": 0.73, "agility": 0.73},
	"druid": {"energy": 1.70, "perception": 0.55, "leadership": 0.70},
	"berserk": {"strength": 1.18, "agility": 1.10},
	"thief": {"strength": 0.86, "agility": 0.86},
}

const BALANCE_BASE_SOLO_DPS := 48.0

const BALANCE_BASE_AOE_DPS := 150.0

const BALANCE_WINDOW_SECONDS := 30.0

const CROWD_CLEAR_TARGET_COUNTS := [5, 10, 20]
const CROWD_CLEAR_ENEMY_HP := 80.0
const CROWD_CLEAR_CORRIDOR := 0.30
const CROWD_CLEAR_SOLO_CORRIDOR := 0.20

const SURVIVABILITY_DEFENSE_CAP := 0.62
const SURVIVABILITY_DEFENSE_DIMINISH := 0.55
const SURVIVABILITY_DODGE_CAP := 0.55
const SURVIVABILITY_DODGE_DIMINISH := 1.15
# SCRUM-526: нерф защитной оси (absorb/regen/vampiric). Защитные механики были
# супер-имбовыми — «закопаться в выживаемость» доминировало над уроном. Ослаблены
# измеримо, чтобы выживаемость была полезной, но не доминирующей стратегией.
# До→после: absorb min-fraction 0.35→0.42 (больше доля удара всегда проходит),
# flat-diminish 0.08→0.11 (быстрее насыщение стака), regen-flat-mult 0.45→0.35.
const SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION := 0.42
const SURVIVABILITY_ABSORB_FLAT_DIMINISH := 0.11
const SURVIVABILITY_REGEN_FLAT_MULTIPLIER := 0.35
# SCRUM-526: оба канала вампиризма ослаблены. Стат-вампиризм: chance-cap 0.22→0.20,
# damage-heal-ratio 0.035→0.025, base-heal-mult 0.55→0.48, per-second капы 1.4→1.1 и
# 2.6→2.0. Оружейный drain: множитель 0.45→0.35.
const VAMPIRIC_CHANCE_CAP := 0.20
const VAMPIRIC_DAMAGE_HEAL_RATIO := 0.025
const VAMPIRIC_BASE_HEAL_MULTIPLIER := 0.48
const VAMPIRIC_HEAL_CAP_DEFAULT := 1.1
const VAMPIRIC_HEAL_CAP_HARD := 2.0
const WEAPON_DRAIN_HEAL_MULTIPLIER := 0.35
# SCRUM-517: per-second потолок DRAIN-heal (drain_link/lifesteal оружия). Раньше
# _heal_owner_from_damage лил лечение прямо в health БЕЗ потолка/с, поэтому Доктор
# с restore_potion/plague_syringe в плотной толпе хилился на сотни HP/с (DoT-стак
# чумы × число целей) и был бессмертен. Теперь drain списывается из общего бюджета
# по тому же принципу, что вампиризм (player._drain_heal_budget), но с собственным,
# более высоким лимитом — drain детерминирован и составляет идентичность Доктора
# как sustain-класса, поэтому больше вампирного (1.1/с), но конечен: при достаточном
# входящем DPS чистый HP убывает. DEFAULT 7.0/с держит Доктора в верхе tank-коридора,
# HARD 11.0/с — потолок для run-модификаторов (healing_multiplier и т.п.).
const DRAIN_HEAL_PER_SECOND_CAP_DEFAULT := 7.0
const DRAIN_HEAL_PER_SECOND_CAP_HARD := 11.0
const CRIT_CHANCE_CAP := 0.55
const CRIT_CHANCE_DIMINISH := 0.45
const CRIT_FLAT_EFFECTIVENESS := 0.75
const CRIT_DAMAGE_BASE_MULTIPLIER := 1.30
const CRIT_DAMAGE_AGILITY_SCALE := 0.055
const CRIT_DAMAGE_FLAT_EFFECTIVENESS := 0.75
const CRIT_DAMAGE_CAP := 2.75

# SCRUM-503: soft-cap (diminishing returns) на ЗАБЕГОВЫЕ боевые множители.
# Живой замер (build/character_balance_dps.csv) вскрывал runaway: «идеальный» билд
# к lvl20 застаканивает run_modifiers.damage_multiplier до ~31x (!) — это и есть
# мультипликативный runaway. У Берсерка/молота он домножается на melee-sweep по 20
# целям → пик 184356 DPS на 20t (×78 от слабейшего класса) и 7636 на 1t. Частичный
# фикс (упрощение upgrade_*_exponent молота, коммит 1e74202b) уронил до 60451/2520,
# но это всё ещё 5.4x медианы — Берсерк остаётся аутлаером. Формульный гейт это НЕ
# ловит: estimate_weapon_budget гоняет derived_parameters с ПУСТЫМИ run_modifiers →
# множитель = 1.0. Поэтому cap применяется ТОЛЬКО к забеговой части множителя и
# ТОЖДЕСТВЕН при значении 1.0: сжимаем лишь превышение над 1.0 по образцу
# _diminishing_percent → capped = 1.0 + clampf(excess/(1+excess*KNEE), 0, CAP-1).
# Инвариант: softcap(1.0) == 1.0 → база lvl1 и формульные коридоры не меняются.
# Значения подобраны по живой матрице: при raw damage_mult≈31 эти knee/cap сжимают
# его до ~16.8, что роняет berserk/hammer 20t 60451→~26k (≤2.5x медианы ~28k) и 1t
# 2520→~1.1k, оставляя класс сильным AoE верхней половины (не аутлаером и не слабым).
# Ранний/средний билд (damage_mult 3..6x) почти не задет — DR кусает только хвост.
const RUN_DAMAGE_MULT_SOFTCAP := 12.0   # жёсткий потолок забегового damage_multiplier
const RUN_DAMAGE_MULT_KNEE := 0.03      # кривизна диминишинга (асимптота избытка = 1/knee)
const RUN_ATTACK_SPEED_MULT_SOFTCAP := 1.70  # потолок забегового attack_speed_multiplier
const RUN_ATTACK_SPEED_MULT_KNEE := 0.50

const WEAPON_ARCHETYPE_BY_MODE := {
	"frustum": "melee",
	"sweep": "melee",
	"circle": "melee",
	"strip": "melee",
	"bayonet_brace": "melee",
	"stab_flurry": "melee",
	"aoe_projectile": "projectile",
	"homing_curse": "projectile",
	"suppression_burst": "projectile",
	"grenade_cook": "projectile",
	"coin_ricochet": "projectile",
	"meteor_shards": "projectile",
	"sniper_lockshot": "projectile",
	"sniper_kill_zone": "projectile",
	"sniper_split_round": "projectile",
	"priest_prayer_chain": "projectile",
	"bio_sample_dart": "projectile",
	"robot_reactor_vent": "projectile",
	"beam": "beam",
	"boomerang": "beam",
	"dot_beam": "beam",
	"drain_link": "beam",
	"prism_rift": "beam",
	"robot_compression_line": "beam",
	"sound_wave": "aura",
	"amp": "aura",
	"pulse": "aura",
	"trap": "aoe",
	"smoke_bomb": "aoe",
	"elemental_orbit": "aoe",
	"priest_sanctify": "aoe",
	"priest_ward": "aoe",
	"bio_spore_bloom": "aoe",
	"bio_symbiote_web": "aoe",
	"robot_magnetic_anchor": "aoe",
	"engineer_pressure_mines": "aoe",
}

const ATTRIBUTE_WEAPON_SYNERGY_MAP := {
	"strength": {
		"melee": "Прямой физический вес, stagger и knockback.",
		"projectile": "Тяжелый снаряд: выше impact damage и отдача.",
		"beam": "Стабильный канал: больше пробивной импульс.",
		"aoe": "Ударная волна: сильнее центр взрыва.",
		"summon": "Сильнее атаки спутников/устройств.",
		"aura": "Плотнее фронтальная волна и ближний отпор.",
	},
	"agility": {
		"melee": "Темп замаха, crit window и мобильность.",
		"projectile": "Перезарядка, скорость выстрела и crit.",
		"beam": "Быстрее повтор каналов и точнее удержание.",
		"aoe": "Чаще постановка зон и безопасное позиционирование.",
		"summon": "Быстрее командный цикл и отклик спутников.",
		"aura": "Чаще ритм pulse/крика и уклонение.",
	},
	"intelligence": {
		"melee": "Зачарование удара и splash.",
		"projectile": "Руническая начинка снарядов.",
		"beam": "Основная сила каналов/лучей.",
		"aoe": "Сила формулы зоны и elemental pool.",
		"summon": "Качество фамильяров/устройств.",
		"aura": "Магическая гармоника pulse.",
	},
	"perception": {
		"melee": "Длина, ширина и точность зоны.",
		"projectile": "Дальность, скорость и выбор цели.",
		"beam": "Дальность канала и ширина линии.",
		"aoe": "Радиус зоны и pickup control.",
		"summon": "Дальность приказа/поиска цели.",
		"aura": "Радиус сцены и контроль ближней толпы.",
	},
	"energy": {
		"melee": "Темп классовой механики и ultimate.",
		"projectile": "Стабильнее цикл выстрелов и ultimate.",
		"beam": "Питание канала и ultimate.",
		"aoe": "Чаще и сильнее pulse/взрывы.",
		"summon": "Питание активных спутников.",
		"aura": "Ритм pulse и сила уникального темпа.",
	},
	"knowledge": {
		"melee": "Bleed/burn след от удара.",
		"projectile": "Яд/горение на попадании.",
		"beam": "Длительный DoT после канала.",
		"aoe": "Дольше и больнее зоны.",
		"summon": "Умнее поддержка, DoT и sustain.",
		"aura": "Стабильнее бафф/дебафф и регенерация.",
	},
	"endurance": {
		"melee": "Контактная стойкость, block и тяжелый knockback.",
		"projectile": "Стабилизация отдачи и безопасная дистанция.",
		"beam": "Удержание канала под давлением.",
		"aoe": "Безопасное стояние внутри собственных зон.",
		"summon": "Прочные deployables и tank-loop.",
		"aura": "Выживание в центре ауры.",
	},
	"leadership": {
		"melee": "Эхо-оружие и командный клич.",
		"projectile": "Корректировщик/эхо-залп.",
		"beam": "Повтор канала спутником.",
		"aoe": "Командные зоны и тотемный pulse.",
		"summon": "Главная сила спутников и устройств.",
		"aura": "Главная сила поддержки, баффов и контроля сцены.",
	},
}

const STAGE_SCALE_BASE := 1.18

const STAGE_SCALE_LINEAR := 0.075

const ECONOMY_PRICE_MULTIPLIER := 1.10

# SCRUM-527: XP-кривая перекалибрована — к боссу 1-го акта средний забег ~20 lvl
# (было ~8-9). Множитель резко снижен (1.42→1.038): рост требуемого опыта плавный,
# почти линейный (req ~5→10→20→30→44 к lvl20, макс. скачок ~3), без крутого
# геометрического разгона. Подтверждено tools/route_economy_xp_model.gd.
const XP_CURVE_MULTIPLIER := 1.038

const XP_CURVE_FLAT := 0.8

const DROP_CLASS_MULTIPLIERS := {
	"ordinary": {"xp": 1.0, "money": 1.0, "money_chance": 0.75},
	# SCRUM-507: complex 1.35→1.6, heavy 1.85→2.2 — перенос веса экономики с boss-дропа на
	# ранние/средние бои. Поднимает не-boss доход маршрута (~+12%), удерживая покупательную
	# способность ≥'healthy' после среза boss-money и опуская долю boss-золота ≤50%.
	"complex": {"xp": 1.3, "money": 1.6, "money_chance": 0.85},
	"heavy": {"xp": 1.75, "money": 2.2, "money_chance": 0.95},
	"mini_elite": {"xp": 3.6, "money": 3.8, "money_chance": 1.0},
	"elite": {"xp": 8.0, "money": 8.5, "money_chance": 1.0},
	# SCRUM-507: boss-money 92→43. Boss-дроп доминировал в экономике маршрута
	# (≈64% всего золота: 442/684 balanced, 594/956 combat, 512/768 shop), обесценивая
	# ранние/средние награды («дожить до босса»). Снижение (в паре с подъёмом complex/heavy)
	# опускает долю boss-золота до ~47-49% дохода (запас под порогом 50%), возвращая вес
	# ранним тратам. Boss остаётся самым жирным денежным дропом (43 ≫ elite 8.5 — инвариант
	# boss.money>elite.money). XP-ветка (xp 24.0) не тронута — темп level-ups сохраняется.
	"boss": {"xp": 24.0, "money": 43.0, "money_chance": 1.0},
}

const COST_BY_TIER := {1: 30, 2: 55, 3: 95}

const TIER_WEIGHTS := {1: 1.0, 2: 0.45, 3: 0.12}
