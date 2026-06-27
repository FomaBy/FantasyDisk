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

const CLASS_LEVEL_STAT_GROWTH_SCALARS := {
	"soldier": {"strength": 0.95, "agility": 0.95},
	"elementalist": {"agility": 0.92, "intelligence": 0.92},
	"priest": {"agility": 0.88, "intelligence": 0.88},
	"robot": {"strength": 0.78, "agility": 0.78},
	"engineer": {"strength": 0.72, "agility": 0.72, "leadership": 0.80},
	"dark_mage": {"agility": 0.84, "intelligence": 0.84},
	"guitarist": {"energy": 1.56},
	"assassin": {"strength": 2.05, "agility": 2.05},
	"doctor": {"agility": 1.10, "intelligence": 1.80},
	"chemist": {"agility": 1.52, "intelligence": 1.52},
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

const XP_CURVE_MULTIPLIER := 1.42

const XP_CURVE_FLAT := 3.0

const DROP_CLASS_MULTIPLIERS := {
	"ordinary": {"xp": 1.0, "money": 1.0, "money_chance": 0.75},
	"complex": {"xp": 1.3, "money": 1.35, "money_chance": 0.85},
	"heavy": {"xp": 1.75, "money": 1.85, "money_chance": 0.95},
	"mini_elite": {"xp": 3.6, "money": 3.8, "money_chance": 1.0},
	"elite": {"xp": 8.0, "money": 8.5, "money_chance": 1.0},
	"boss": {"xp": 24.0, "money": 92.0, "money_chance": 1.0},
}

const COST_BY_TIER := {1: 30, 2: 55, 3: 95}

const TIER_WEIGHTS := {1: 1.0, 2: 0.45, 3: 0.12}
