class_name ProgressionData
extends RefCounted

const STAT_NAMES := {
	"strength": "Сила",
	"agility": "Ловкость",
	"intelligence": "Интеллект",
	"perception": "Восприятие",
	"energy": "Энергия",
	"knowledge": "Знание",
	"endurance": "Выносливость",
	"leadership": "Лидерство",
}

const BASE_STATS := {
	"berserk": {
		"strength": 10.0,
		"agility": 5.0,
		"intelligence": 2.0,
		"perception": 5.0,
		"energy": 4.0,
		"knowledge": 4.0,
		"endurance": 7.0,
		"leadership": 3.0,
	},
	"soldier": {
		"strength": 7.0,
		"agility": 6.0,
		"intelligence": 2.0,
		"perception": 8.0,
		"energy": 4.0,
		"knowledge": 5.0,
		"endurance": 6.0,
		"leadership": 5.0,
	},
	"thief": {
		"strength": 5.0,
		"agility": 9.0,
		"intelligence": 3.0,
		"perception": 8.0,
		"energy": 5.0,
		"knowledge": 4.0,
		"endurance": 4.0,
		"leadership": 5.0,
	},
	"elementalist": {
		"strength": 2.0,
		"agility": 4.0,
		"intelligence": 9.0,
		"perception": 7.0,
		"energy": 8.0,
		"knowledge": 6.0,
		"endurance": 3.0,
		"leadership": 5.0,
	},
	"sniper": {
		"strength": 6.0,
		"agility": 8.0,
		"intelligence": 2.0,
		"perception": 10.0,
		"energy": 3.0,
		"knowledge": 3.0,
		"endurance": 7.0,
		"leadership": 1.0,
	},
	"priest": {
		"strength": 2.0,
		"agility": 4.0,
		"intelligence": 8.0,
		"perception": 6.0,
		"energy": 7.0,
		"knowledge": 9.0,
		"endurance": 5.0,
		"leadership": 6.0,
	},
	"biologist": {
		"strength": 2.0,
		"agility": 5.0,
		"intelligence": 8.0,
		"perception": 7.0,
		"energy": 6.0,
		"knowledge": 10.0,
		"endurance": 4.0,
		"leadership": 4.0,
	},
	"robot": {
		"strength": 8.0,
		"agility": 3.0,
		"intelligence": 5.0,
		"perception": 5.0,
		"energy": 7.0,
		"knowledge": 4.0,
		"endurance": 10.0,
		"leadership": 4.0,
	},
	"engineer": {
		"strength": 4.0,
		"agility": 5.0,
		"intelligence": 7.0,
		"perception": 6.0,
		"energy": 6.0,
		"knowledge": 6.0,
		"endurance": 5.0,
		"leadership": 10.0,
	},
	"dark_mage": {
		"strength": 2.0,
		"agility": 3.0,
		"intelligence": 10.0,
		"perception": 5.0,
		"energy": 7.0,
		"knowledge": 6.0,
		"endurance": 2.0,
		"leadership": 5.0,
	},
	"guitarist": {
		"strength": 4.0,
		"agility": 6.0,
		"intelligence": 4.0,
		"perception": 7.0,
		"energy": 6.0,
		"knowledge": 5.0,
		"endurance": 4.0,
		"leadership": 7.0,
	},
	"assassin": {"strength": 6.0, "agility": 10.0, "intelligence": 2.0, "perception": 6.0, "energy": 3.0, "knowledge": 4.0, "endurance": 5.0, "leadership": 4.0},
	"ranger": {"strength": 7.0, "agility": 7.0, "intelligence": 2.0, "perception": 9.0, "energy": 4.0, "knowledge": 4.0, "endurance": 4.0, "leadership": 3.0},
	"doctor": {"strength": 2.0, "agility": 4.0, "intelligence": 8.0, "perception": 5.0, "energy": 6.0, "knowledge": 8.0, "endurance": 5.0, "leadership": 2.0},
	"chemist": {"strength": 2.0, "agility": 4.0, "intelligence": 9.0, "perception": 6.0, "energy": 7.0, "knowledge": 7.0, "endurance": 3.0, "leadership": 2.0},
	"knight": {"strength": 8.0, "agility": 3.0, "intelligence": 2.0, "perception": 4.0, "energy": 3.0, "knowledge": 4.0, "endurance": 10.0, "leadership": 6.0},
	"druid": {"strength": 3.0, "agility": 4.0, "intelligence": 4.0, "perception": 7.0, "energy": 6.0, "knowledge": 5.0, "endurance": 5.0, "leadership": 9.0},
}

const CHARACTER_CONFIGS := {
	"berserk": {
		"id": "berserk",
		"title": "Берсерк",
		"description": "Ближний бой по области и высокий риск.",
		"strengths": "урон, здоровье, толпа.",
		"weaknesses": "нужна близость.",
		"sprite_path": "res://assets/sprites/characters/berserk_unarmed.png",
	},
	"soldier": {
		"id": "soldier",
		"title": "Солдат",
		"description": "Тактика, залпы и контроль позиции.",
		"strengths": "дальность, стабильность, контроль.",
		"weaknesses": "нужна линия огня.",
		"sprite_path": "res://assets/sprites/characters/soldier.png",
	},
	"thief": {
		"id": "thief",
		"title": "Вор",
		"description": "Уловки, рывки и карманная экономика.",
		"strengths": "мобильность, крит, золото.",
		"weaknesses": "мало здоровья.",
		"sprite_path": "res://assets/sprites/characters/thief.png",
	},
	"elementalist": {
		"id": "elementalist",
		"title": "Элементалист",
		"description": "Смена стихий, орбиты и разломы.",
		"strengths": "области поражения, контроль зон, взрывной урон.",
		"weaknesses": "хрупкий, требует позицию.",
		"sprite_path": "res://assets/sprites/characters/elementalist.png",
	},
	"sniper": {
		"id": "sniper",
		"title": "Снайпер",
		"description": "Точные выстрелы, метки и зоны поражения.",
		"strengths": "дальность, одиночные цели, фокус элиток.",
		"weaknesses": "слабее против плотной толпы рядом.",
		"sprite_path": "res://assets/sprites/characters/sniper.png",
	},
	"priest": {
		"id": "priest",
		"title": "Священник",
		"description": "Благословения, печати и священное восстановление.",
		"strengths": "лечение, защита, стабильность.",
		"weaknesses": "меньше взрывного урона по одиночной цели.",
		"sprite_path": "res://assets/sprites/characters/priest.png",
	},
	"biologist": {
		"id": "biologist",
		"title": "Биолог",
		"description": "Образцы, споры и симбиотические реакции.",
		"strengths": "контроль биомассой, периодический урон, адаптация.",
		"weaknesses": "нужны цели для цепных реакций.",
		"sprite_path": "res://assets/sprites/characters/biologist.png",
	},
	"robot": {
		"id": "robot",
		"title": "Робот",
		"description": "Тяжелая броня, магнитный контроль и реакторные выбросы.",
		"strengths": "выживаемость, контроль, стабильный урон.",
		"weaknesses": "медленный, зависит от позиционирования.",
		"sprite_path": "res://assets/sprites/characters/robot.png",
	},
	"engineer": {
		"id": "engineer",
		"title": "Инженер",
		"description": "Мастерская устройств, дронов и минных сеток.",
		"strengths": "устройства, зона контроля, поддержка.",
		"weaknesses": "нужно заранее ставить позицию.",
		"sprite_path": "res://assets/sprites/characters/engineer.png",
	},
	"dark_mage": {
		"id": "dark_mage",
		"title": "Темный маг",
		"description": "Области поражения, лучи и проклятия.",
		"strengths": "площадь, периодический урон, пробивание.",
		"weaknesses": "хрупкий.",
		"sprite_path": "res://assets/sprites/characters/dark_mage.png",
	},
	"guitarist": {
		"id": "guitarist",
		"title": "Гитарист",
		"description": "Ритм, волны и контроль.",
		"strengths": "отталкивание, области поражения, темп.",
		"weaknesses": "слабее по боссам.",
		"sprite_path": "res://assets/sprites/characters/guitarist.png",
	},
	"assassin": {
		"id": "assassin", "title": "Ассасин",
		"description": "Криты, скорость и яд.",
		"strengths": "криты, уворот, темп.",
		"weaknesses": "мало здоровья.",
		"sprite_path": "res://assets/sprites/characters/assassin.png",
	},
	"ranger": {
		"id": "ranger", "title": "Рейнджер",
		"description": "Дальние линии и ловушки.",
		"strengths": "дальность, пробивание.",
		"weaknesses": "плох вблизи.",
		"sprite_path": "res://assets/sprites/characters/ranger.png",
	},
	"doctor": {
		"id": "doctor", "title": "Доктор",
		"description": "Лечение через урон.",
		"strengths": "восстановление, яд, стабильность.",
		"weaknesses": "низкий взрывной урон.",
		"sprite_path": "res://assets/sprites/characters/doctor.png",
	},
	"chemist": {
		"id": "chemist", "title": "Химик",
		"description": "Взрывы и ядовитые зоны.",
		"strengths": "зоны, периодический урон, области поражения.",
		"weaknesses": "хрупкий.",
		"sprite_path": "res://assets/sprites/characters/chemist.png",
	},
	"knight": {
		"id": "knight", "title": "Рыцарь",
		"description": "Танк, копье и щит.",
		"strengths": "здоровье, защита, контроль.",
		"weaknesses": "медленный.",
		"sprite_path": "res://assets/sprites/characters/knight.png",
	},
	"druid": {
		"id": "druid", "title": "Друид",
		"description": "Стая, тернии и тотемы.",
		"strengths": "призывы, зоны.",
		"weaknesses": "слаб один.",
		"sprite_path": "res://assets/sprites/characters/druid.png",
	},
}

const CLASS_BUDGET_PROFILES := {
	"berserk": {"profile": "balanced", "survival": "sturdy", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
	"soldier": {"profile": "balanced", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
	"thief": {"profile": "balanced", "survival": "fragile", "damage_budget": 1.08, "solo_target": 1.00, "aoe_target": 1.00},
	"elementalist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.08, "solo_target": 0.95, "aoe_target": 1.10},
	"sniper": {"profile": "solo", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.15, "aoe_target": 0.80},
	"priest": {"profile": "balanced", "survival": "steady", "damage_budget": 0.92, "solo_target": 0.95, "aoe_target": 1.05},
	"biologist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.08, "solo_target": 0.82, "aoe_target": 1.18},
	"robot": {"profile": "balanced", "survival": "tank", "damage_budget": 0.88, "solo_target": 0.95, "aoe_target": 1.05},
	"engineer": {"profile": "balanced", "survival": "steady", "damage_budget": 0.96, "solo_target": 0.90, "aoe_target": 1.12},
	"dark_mage": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.15, "solo_target": 0.70, "aoe_target": 1.30},
	"guitarist": {"profile": "aoe", "survival": "control", "damage_budget": 1.00, "solo_target": 0.70, "aoe_target": 1.30},
	"assassin": {"profile": "solo", "survival": "fragile", "damage_budget": 1.15, "solo_target": 1.30, "aoe_target": 0.70},
	"ranger": {"profile": "solo", "survival": "fragile", "damage_budget": 1.15, "solo_target": 1.30, "aoe_target": 0.70},
	"doctor": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.00, "aoe_target": 1.00},
	"chemist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.15, "solo_target": 0.70, "aoe_target": 1.30},
	"knight": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.00, "aoe_target": 1.00},
	"druid": {"profile": "balanced", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
}

const BALANCE_BASE_SOLO_DPS := 48.0
const BALANCE_BASE_AOE_DPS := 150.0
const BALANCE_WINDOW_SECONDS := 30.0
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

const WeaponsData := preload("res://scripts/progression_data_weapons.gd")
const BERSERK_WEAPONS := WeaponsData.BERSERK_WEAPONS
const WEAPONS_BY_CLASS := WeaponsData.WEAPONS_BY_CLASS

const STAT_REWARDS := [
	{
		"id": "strength_training",
		"title": "Сила +1",
		"description": "+physical damage and heavier melee impact.",
		"stats": {"strength": 1.0},
	},
	{
		"id": "agility_training",
		"title": "Ловкость +1",
		"description": "+move speed, attack speed, crit and dodge.",
		"stats": {"agility": 1.0},
	},
	{
		"id": "intelligence_training",
		"title": "Интеллект +1",
		"description": "+magic scaling and crit damage foundations.",
		"stats": {"intelligence": 1.0},
	},
	{
		"id": "perception_training",
		"title": "Восприятие +1",
		"description": "+range, attack cadence and projectile control.",
		"stats": {"perception": 1.0},
	},
	{
		"id": "energy_training",
		"title": "Энергия +1",
		"description": "+regen and magic resource potential.",
		"stats": {"energy": 1.0},
	},
	{
		"id": "knowledge_training",
		"title": "Знание +1",
		"description": "+healing, DoT and regeneration scaling.",
		"stats": {"knowledge": 1.0},
	},
	{
		"id": "endurance_training",
		"title": "Выносливость +1",
		"description": "+maximum HP and defenses.",
		"stats": {"endurance": 1.0},
	},
	{
		"id": "leadership_training",
		"title": "Лидерство +1",
		"description": "+summon count, summon speed and aura power.",
		"stats": {"leadership": 1.0},
	},
]

const ARTIFACTS := [
	{"id": "warrior_charm", "title": "Warrior Charm", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Сила.", "stats": {"strength": 5.0}},
	{"id": "fox_boots", "title": "Fox Boots", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Ловкость.", "stats": {"agility": 5.0}},
	{"id": "glass_orb", "title": "Glass Orb", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Интеллект.", "stats": {"intelligence": 5.0}},
	{"id": "hawk_lens", "title": "Hawk Lens", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Восприятие.", "stats": {"perception": 5.0}},
	{"id": "ember_core", "title": "Ember Core", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Энергия.", "stats": {"energy": 5.0}},
	{"id": "old_codex", "title": "Old Codex", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Знание.", "stats": {"knowledge": 5.0}},
	{"id": "stone_heart", "title": "Stone Heart", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Выносливость.", "stats": {"endurance": 5.0}},
	{"id": "banner_seed", "title": "Banner Seed", "tier": 1, "cost": 30, "class_affinity": [], "description": "+5 Лидерство.", "stats": {"leadership": 5.0}},
	{"id": "red_whetstone", "title": "Red Whetstone", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Сила, +3 Ловкость.", "stats": {"strength": 3.0, "agility": 3.0}},
	{"id": "star_compass", "title": "Star Compass", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Восприятие, +3 Знание.", "stats": {"perception": 3.0, "knowledge": 3.0}},
	{"id": "living_root", "title": "Living Root", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Выносливость, +3 Энергия.", "stats": {"endurance": 3.0, "energy": 3.0}},
	{"id": "captains_coin", "title": "Captain's Coin", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Лидерство, +3 Сила.", "stats": {"leadership": 3.0, "strength": 3.0}},
	{"id": "quickstring", "title": "Quickstring", "tier": 1, "cost": 30, "class_affinity": [], "description": "+37% скорости атаки.", "mods": {"attack_speed_multiplier": 1.37}},
	{"id": "heavy_totem", "title": "Heavy Totem", "tier": 2, "cost": 55, "class_affinity": [], "description": "+62% максимального HP, -5% скорости движения.", "mods": {"max_health_multiplier": 1.62, "move_speed_multiplier": 0.95}},
	{"id": "splinter_gloves", "title": "Splinter Gloves", "tier": 1, "cost": 30, "class_affinity": [], "description": "+50% урона.", "mods": {"damage_multiplier": 1.5}},
	{"id": "wide_sigil", "title": "Wide Sigil", "tier": 1, "cost": 30, "class_affinity": [], "description": "+50% дальности атаки.", "mods": {"range_multiplier": 1.5}},
	{"id": "swift_ink", "title": "Swift Ink", "tier": 1, "cost": 30, "class_affinity": [], "description": "+30% скорости движения.", "mods": {"move_speed_multiplier": 1.3}},
	{"id": "summoners_bell", "title": "Summoner's Bell", "tier": 1, "cost": 30, "class_affinity": [], "description": "+2 призыв.", "mods": {"summon_bonus": 2.5}},
	{"id": "blood_sigil", "title": "Кровавая печать", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "description": "+20 max HP. Берсерк: +45% урона.", "mods": {"max_health_flat": 20.0}, "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "void_ink", "title": "Чернила пустоты", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "description": "+50% радиуса AoE. Темный маг: +50% урона.", "mods": {"aoe_radius_multiplier": 1.5}, "affinity_mods": {"damage_multiplier": 1.5}},
	{"id": "echo_pick", "title": "Медиатор эха", "tier": 2, "cost": 55, "class_affinity": ["guitarist"], "description": "+40% отталкивания. Гитарист: +45% скорости атаки.", "mods": {"knockback_multiplier": 1.4}, "affinity_mods": {"attack_speed_multiplier": 1.45}},
	{"id": "sturdy_amulet", "title": "Крепкий амулет", "tier": 1, "cost": 30, "class_affinity": [], "description": "+60 max HP.", "mods": {"max_health_flat": 60.0}},
	{"id": "fast_boots", "title": "Быстрые сапоги", "tier": 1, "cost": 30, "class_affinity": [], "description": "+25% скорости движения.", "mods": {"move_speed_multiplier": 1.25}},
	{"id": "magnetic_buckle", "title": "Магнитная пряжка", "tier": 1, "cost": 30, "class_affinity": [], "description": "+138 радиуса подбора.", "mods": {"pickup_radius_flat": 137.5}},
	{"id": "silver_coin", "title": "Серебряная монета", "tier": 1, "cost": 30, "class_affinity": [], "description": "+62% золота.", "mods": {"money_gain_multiplier": 1.62}},
	{"id": "survival_manual", "title": "Учебник выживания", "tier": 1, "cost": 30, "class_affinity": [], "description": "+55% опыта.", "mods": {"xp_gain_multiplier": 1.55}},
	{"id": "cracked_shield", "title": "Треснувший щит", "tier": 2, "cost": 55, "class_affinity": [], "description": "+30% защиты, -6% скорости движения.", "mods": {"defense_flat": 0.3, "move_speed_multiplier": 0.94}},
	{"id": "sharp_talisman", "title": "Острый талисман", "tier": 1, "cost": 30, "class_affinity": [], "description": "+20% шанса крита.", "mods": {"crit_chance_flat": 0.2}},
	{"id": "jagged_blade", "title": "Зазубренное лезвие", "tier": 1, "cost": 30, "class_affinity": ["berserk"], "description": "Берсерк: +45% урона.", "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "heavy_grip", "title": "Тяжелая рукоять", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "description": "-8% скорости атаки. Берсерк: +60% отталкивания.", "mods": {"attack_speed_multiplier": 0.92}, "affinity_mods": {"knockback_multiplier": 1.6}},
	{"id": "war_belt", "title": "Боевой ремень", "tier": 1, "cost": 30, "class_affinity": ["berserk"], "description": "Берсерк: +55% радиуса AoE.", "affinity_mods": {"aoe_radius_multiplier": 1.55}},
	{"id": "warriors_rage", "title": "Ярость воина", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "description": "-10% максимального HP. Берсерк: +50% урона.", "mods": {"max_health_multiplier": 0.9}, "affinity_mods": {"damage_multiplier": 1.5}},
	{"id": "dark_crystal", "title": "Темный кристалл", "tier": 1, "cost": 30, "class_affinity": ["dark_mage"], "description": "Темный маг: +45% урона.", "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "ash_page", "title": "Пепельная страница", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "description": "+25% урона. Темный маг: +45% радиуса AoE.", "mods": {"damage_multiplier": 1.25}, "affinity_mods": {"aoe_radius_multiplier": 1.45}},
	{"id": "skull_resonator", "title": "Черепной резонатор", "tier": 1, "cost": 30, "class_affinity": ["dark_mage"], "description": "Темный маг: +50% дальности атаки.", "affinity_mods": {"range_multiplier": 1.5}},
	{"id": "ink_candle", "title": "Чернильная свеча", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "description": "-6% скорости движения. Темный маг: +55% урона.", "mods": {"move_speed_multiplier": 0.94}, "affinity_mods": {"damage_multiplier": 1.55}},
	{"id": "copper_string", "title": "Медная струна", "tier": 1, "cost": 30, "class_affinity": ["guitarist"], "description": "Гитарист: +45% урона.", "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "broken_pick", "title": "Сломанный медиатор", "tier": 1, "cost": 30, "class_affinity": ["guitarist"], "description": "Гитарист: +30% шанса крита.", "affinity_mods": {"crit_chance_flat": 0.3}},
	{"id": "loud_amp", "title": "Громкий усилитель", "tier": 1, "cost": 30, "class_affinity": ["guitarist"], "description": "Гитарист: +50% радиуса AoE.", "affinity_mods": {"aoe_radius_multiplier": 1.5}},
	{"id": "bass_cable", "title": "Басовый кабель", "tier": 2, "cost": 55, "class_affinity": ["guitarist"], "description": "+25% радиуса AoE. Гитарист: +45% отталкивания.", "mods": {"aoe_radius_multiplier": 1.25}, "affinity_mods": {"knockback_multiplier": 1.45}},
	{"id": "cursed_crown", "title": "Проклятая корона", "tier": 2, "cost": 55, "class_affinity": [], "description": "+75% урона, -18% максимального HP.", "mods": {"damage_multiplier": 1.75, "max_health_multiplier": 0.82}},
	{"id": "fragile_heart", "title": "Хрупкое сердце", "tier": 2, "cost": 55, "class_affinity": [], "description": "+62% скорости атаки, -10% защиты.", "mods": {"attack_speed_multiplier": 1.62, "defense_flat": -0.1}},
	{"id": "greedy_purse", "title": "Жадный кошелек", "tier": 2, "cost": 55, "class_affinity": [], "description": "+112% золота, враги: +37% HP.", "mods": {"money_gain_multiplier": 2.12, "enemy_health_multiplier": 1.37}},
	{"id": "burning_shard", "title": "Горящий осколок", "tier": 2, "cost": 55, "class_affinity": [], "description": "+50% радиуса AoE, -20% лечения.", "mods": {"aoe_radius_multiplier": 1.5, "healing_multiplier": 0.8}},
	{"id": "golden_route_mark", "title": "Золотая метка пути", "tier": 2, "cost": 55, "class_affinity": [], "description": "+37% опыта, +37% золота.", "mods": {"xp_gain_multiplier": 1.37, "money_gain_multiplier": 1.37}},
	{"id": "glass_edge", "title": "Стеклянная кромка", "tier": 2, "cost": 55, "class_affinity": [], "description": "+50% урона крита, -8 max HP.", "mods": {"crit_damage_flat": 0.5, "max_health_flat": -8.0}},
	{"id": "echo_core", "title": "Эхо Разлома", "tier": 3, "cost": 95, "class_affinity": [], "description": "Каждый 5-й удар по врагу вызывает взрыв эха: 80% урона по области вокруг цели.", "mods": {"echo_blast_every": 5.0}},
	{"id": "split_core", "title": "Ядро Расщепления", "tier": 3, "cost": 95, "class_affinity": ["dark_mage", "guitarist"], "description": "Темный маг/Гитарист: +1 снаряд и луч всем атакам.", "affinity_mods": {"extra_projectile": 1.0}},
	{"id": "blood_pact", "title": "Кровавый Рубеж", "tier": 3, "cost": 95, "class_affinity": [], "description": "Пока здоровье ниже 30% — +50% урона. Риск, достойный награды.", "mods": {"low_hp_damage_bonus": 0.5}},
	{"id": "leech_heart", "title": "Сердце Пиявки", "tier": 3, "cost": 95, "class_affinity": [], "description": "Каждое убийство возвращает 2% максимального здоровья.", "mods": {"kill_heal_percent": 0.02}},
	{"id": "thorn_pact", "title": "Договор Шипов", "tier": 3, "cost": 95, "class_affinity": [], "description": "Получив урон, выплескиваешь 200% этого урона на всех врагов рядом.", "mods": {"thorn_reflect_multiplier": 2.0}},
	{"id": "phantom_step", "title": "Призрачный Шаг", "tier": 3, "cost": 95, "class_affinity": [], "description": "Успешный уворот дает +40% скорости движения на 2 секунды.", "mods": {"dodge_rush_bonus": 0.4}},
	{"id": "leech_fang", "title": "Клык Пиявки", "tier": 2, "cost": 55, "class_affinity": [], "description": "+14% шанса вампиризма, +1 к лечению от вампиризма. Вампиризм ограничен лечением в секунду.", "mods": {"vampiric_chance_flat": 0.14, "vampiric_amount_flat": 1.0, "vampiric_heal_per_second_cap": 1.0}},
]

const LEVEL_UP_REWARDS := [
	{"id": "damage_up", "title": "+Урон", "description": "+15% к урону.", "kind": "upgrade", "mods": {"damage_multiplier": 1.15}},
	{"id": "attack_speed_up", "title": "+Скорость атаки", "description": "+12% к скорости атаки.", "kind": "upgrade", "mods": {"attack_speed_multiplier": 1.12}},
	{"id": "max_hp_up", "title": "+Максимальное здоровье", "description": "+18 к максимальному здоровью.", "kind": "upgrade", "mods": {"max_health_flat": 18.0}},
	{"id": "move_speed_up", "title": "+Скорость движения", "description": "+10% к скорости движения.", "kind": "upgrade", "mods": {"move_speed_multiplier": 1.10}},
	{"id": "aoe_radius_up", "title": "+Радиус области", "description": "+15% к конусам и радиусам атак.", "kind": "upgrade", "mods": {"aoe_radius_multiplier": 1.15, "range_multiplier": 1.08}},
	{"id": "pickup_radius_up", "title": "+Радиус подбора", "description": "+45 к радиусу подбора.", "kind": "upgrade", "mods": {"pickup_radius_flat": 45.0}},
	{"id": "defense_up", "title": "+Защита", "description": "+10% к снижению входящего урона.", "kind": "upgrade", "mods": {"defense_flat": 0.10}},
	{"id": "magic_focus_up", "title": "+Магический фокус", "description": "+14% к магическому/звуковому урону или зачарованию оружия.", "kind": "upgrade", "mods": {"damage_multiplier": 1.14}},
	{"id": "knockback_up", "title": "+Отталкивание", "description": "+18% к отталкиванию и импульсному контролю.", "kind": "upgrade", "mods": {"knockback_multiplier": 1.18}},
	{"id": "crit_chance_up", "title": "+Шанс крита", "description": "+7% к шансу критического удара.", "kind": "upgrade", "mods": {"crit_chance_flat": 0.07}},
	{"id": "crit_damage_up", "title": "+Урон крита", "description": "+35% к множителю критического урона.", "kind": "upgrade", "mods": {"crit_damage_flat": 0.35}},
	{"id": "dodge_up", "title": "+Уклонение", "description": "+8% к шансу уклонения.", "kind": "upgrade", "mods": {"dodge_flat": 0.08}},
	{"id": "range_up", "title": "+Дальность атаки", "description": "+12% к дальности атаки.", "kind": "upgrade", "mods": {"range_multiplier": 1.12}},
	{"id": "dot_damage_up", "title": "+Периодический урон", "description": "+3 к периодическому урону. Классы без яда получают малое кровотечение или горение.", "kind": "upgrade", "mods": {"dot_damage_flat": 3.0}},
	{"id": "dot_speed_up", "title": "+Скорость тиков", "description": "+0.25 тика периодического урона в секунду.", "kind": "upgrade", "mods": {"dot_speed_flat": 0.25}},
	{"id": "projectile_speed_up", "title": "+Скорость снарядов", "description": "+90 к скорости и весу снарядов.", "kind": "upgrade", "mods": {"projectile_speed_flat": 90.0}},
	{"id": "aura_radius_up", "title": "+Радиус ауры", "description": "+55 к радиусу ауры. Классы без аур получают более сильный ближний боевой клич.", "kind": "upgrade", "mods": {"aura_radius_flat": 55.0}},
	{"id": "buff_power_up", "title": "+Сила поддержки", "description": "+0.18 к силе поддержки и усилений.", "kind": "upgrade", "mods": {"buff_power_flat": 0.18}},
	{"id": "summon_amount_up", "title": "+Сила призыва", "description": "+2 к силе призывов. Непризывные классы получают эхо-оружие или спутника.", "kind": "upgrade", "mods": {"summon_bonus": 2.0}},
	{"id": "absorb_up", "title": "+Absorb", "description": "+4 flat damage absorption.", "kind": "upgrade", "mods": {"absorb_flat": 4.0}},
	{"id": "regeneration_up", "title": "+Regeneration", "description": "+1.3 regeneration base.", "kind": "upgrade", "mods": {"regeneration_flat": 1.3}},
	{"id": "vampiric_amount_up", "title": "+Vampiric Heal", "description": "+1 heal on vampiric hits and +1 heal/sec cap.", "kind": "upgrade", "mods": {"vampiric_amount_flat": 1.0, "vampiric_heal_per_second_cap": 1.0}},
	{"id": "vampiric_chance_up", "title": "+Vampiric Chance", "description": "+5% chance to heal on hit.", "kind": "upgrade", "mods": {"vampiric_chance_flat": 0.05}},
	{"id": "ultimate_power_up", "title": "+Ultimate Power", "description": "+0.12 ultimate power for class ultimate effects.", "kind": "upgrade", "mods": {"ultimate_flat": 0.12}},
]

const ULTIMATE_CONFIGS := {
	"berserk": {"title": "Неистовство", "description": "На несколько секунд ускоряется и каждый удар поднимает эхо-волну.", "duration": 5.5, "radius": 180.0, "damage": 0.75, "damage_charge_rate": 0.030, "taken_charge_rate": 1.35, "boss_cap": 0.10},
	"soldier": {"title": "Приказ: Огонь", "description": "Серия прицельных залпов по ближайшим целям; сильнее по плотной толпе, но ограничена по боссу.", "duration": 0.0, "radius": 560.0, "damage": 1.08, "target_count": 9, "damage_charge_rate": 0.033, "taken_charge_rate": 1.12, "boss_cap": 0.09},
	"thief": {"title": "Большой Куш", "description": "Мгновенный налет по ближайшим целям: урон, золотые нити и небольшой денежный выигрыш.", "duration": 0.0, "radius": 500.0, "damage": 1.02, "target_count": 8, "damage_charge_rate": 0.036, "taken_charge_rate": 1.00, "boss_cap": 0.08},
	"elementalist": {"title": "Стихийная Сверхнова", "description": "Сверхнова четырех стихий взрывается вокруг героя и оставляет вторичные вспышки по ближайшим целям.", "duration": 0.0, "radius": 430.0, "damage": 1.18, "target_count": 6, "damage_charge_rate": 0.035, "taken_charge_rate": 1.04, "boss_cap": 0.10},
	"sniper": {"title": "Последний Выстрел", "description": "Снайпер отмечает опасные цели и выпускает серию смертельных дальних попаданий.", "duration": 0.0, "radius": 760.0, "damage": 1.35, "target_count": 5, "damage_charge_rate": 0.034, "taken_charge_rate": 0.95, "boss_cap": 0.10},
	"priest": {"title": "Хор Искупления", "description": "Священная волна поражает врагов вокруг и превращает часть урона в лечение.", "duration": 0.0, "radius": 410.0, "damage": 1.05, "target_count": 8, "heal_ratio": 0.45, "damage_charge_rate": 0.031, "taken_charge_rate": 1.22, "boss_cap": 0.08},
	"biologist": {"title": "Пробуждение Колонии", "description": "Биолог запускает рост живой колонии: несколько биоимпульсов поражают ближайших врагов и оставляют слабый реген.", "duration": 0.0, "radius": 440.0, "damage": 1.10, "target_count": 9, "heal_ratio": 0.18, "damage_charge_rate": 0.033, "taken_charge_rate": 1.05, "boss_cap": 0.09},
	"robot": {"title": "Аварийная Перегрузка", "description": "Робот включает аварийный контур: получает временное поглощение, выпускает ударную волну и несколько раз прожигает ближайших врагов.", "duration": 4.5, "radius": 380.0, "damage": 0.78, "target_count": 8, "damage_charge_rate": 0.030, "taken_charge_rate": 1.55, "boss_cap": 0.08},
	"engineer": {"title": "Аварийная Мастерская", "description": "Инженер быстро разворачивает временную сеть устройств: лучи, ремонт и взрывные узлы вокруг себя.", "duration": 4.2, "radius": 430.0, "damage": 0.92, "target_count": 9, "heal_ratio": 0.12, "damage_charge_rate": 0.031, "taken_charge_rate": 1.18, "boss_cap": 0.08},
	"dark_mage": {"title": "Темная буря", "description": "Вихрь темной магии проклинает всех врагов вокруг.", "duration": 0.0, "radius": 360.0, "damage": 1.35, "damage_charge_rate": 0.034, "taken_charge_rate": 1.05, "boss_cap": 0.11},
	"guitarist": {"title": "Соло", "description": "Гигантская звуковая волна отбрасывает и глушит толпу.", "duration": 0.0, "radius": 430.0, "damage": 1.15, "damage_charge_rate": 0.033, "taken_charge_rate": 1.10, "boss_cap": 0.09},
	"assassin": {"title": "Танец клинков", "description": "Серия мгновенных рывков-ударов по ближайшим целям.", "duration": 0.0, "radius": 520.0, "damage": 1.05, "target_count": 7, "damage_charge_rate": 0.036, "taken_charge_rate": 1.05, "boss_cap": 0.08},
	"ranger": {"title": "Лунный залп", "description": "Дождь болтов поражает большую область вокруг героя.", "duration": 0.0, "radius": 480.0, "damage": 1.18, "target_count": 14, "damage_charge_rate": 0.034, "taken_charge_rate": 1.0, "boss_cap": 0.09},
	"doctor": {"title": "Переливание", "description": "Массовый drain врагов вокруг; избыток лечения становится щитом-поглощением.", "duration": 0.0, "radius": 360.0, "damage": 0.95, "damage_charge_rate": 0.032, "taken_charge_rate": 1.25, "boss_cap": 0.08},
	"chemist": {"title": "Цепная реакция", "description": "Алхимический каскад детонирует ближайшие зоны и врагов.", "duration": 0.0, "radius": 420.0, "damage": 1.25, "damage_charge_rate": 0.034, "taken_charge_rate": 1.05, "boss_cap": 0.10},
	"knight": {"title": "Бастион", "description": "Короткая непробиваемость, таунт давления и усиленная контратака.", "duration": 5.0, "radius": 260.0, "damage": 0.70, "damage_charge_rate": 0.029, "taken_charge_rate": 1.55, "boss_cap": 0.07},
	"druid": {"title": "Зов стаи", "description": "Временно призывает сверхлимитную стаю союзников.", "duration": 6.0, "radius": 260.0, "damage": 0.80, "target_count": 4, "damage_charge_rate": 0.031, "taken_charge_rate": 1.10, "boss_cap": 0.08},
}

# Классовая релевантность урона: какой derived-параметр является «своим» уроном класса.
const CLASS_DAMAGE_PARAMETER := {
	"berserk": "damage",
	"soldier": "damage",
	"thief": "damage",
	"elementalist": "magic_damage",
	"sniper": "damage",
	"priest": "magic_damage",
	"biologist": "magic_damage",
	"robot": "damage",
	"engineer": "damage",
	"dark_mage": "magic_damage",
	"guitarist": "sound_wave_damage",
	"assassin": "damage",
	"ranger": "damage",
	"knight": "damage",
	"doctor": "magic_damage",
	"chemist": "magic_damage",
	"druid": "sound_wave_damage",
}
# Атрибуты, дающие силу только перечисленным классам (по формулам derived_parameters):
# strength питает только физический урон, intelligence — только магический,
# energy — магический и звуковой. Отсутствие в карте = атрибут универсален.
const STAT_CLASS_RELEVANCE := {}

const CLASS_INTERPRETATIONS := {
	"berserk": {
		"strength": "Прямо усиливает двуручное оружие.",
		"intelligence": "Зачаровывает удары: часть магической силы взрывается искрой вокруг цели.",
		"energy": "Ускоряет темп уникальных срабатываний и усиливает магическое зачарование.",
		"leadership": "Каждые несколько ударов вызывает призрачное эхо-оружие.",
		"magic_damage": "Работает как зачарование физического удара.",
		"sound_wave_damage": "Дает боевой клич: периодическая волна отталкивания вокруг Берсерка.",
		"dot_damage": "Добавляет малое кровотечение к ударам.",
		"summon_amount": "Повышает частоту эхо-оружия.",
	},
	"soldier": {
		"strength": "Усиливает залпы, штык и вес гранат.",
		"intelligence": "Добавляет рунический воспламенитель к гранатам и выстрелам.",
		"energy": "Ускоряет тактические циклы: фитиль, залп и готовность ульты.",
		"knowledge": "Добавляет горение/кровотечение к пораженным целям.",
		"leadership": "Командный клич периодически вызывает эхо-залп строя.",
		"magic_damage": "Работает как зачарованный порох и руническая осколочная искра.",
		"sound_wave_damage": "Работает как команда строя: ближний боевой окрик отталкивает толпу.",
		"dot_damage": "Добавляет малый burn/bleed от пороха и штыка.",
		"summon_amount": "Повышает частоту эхо-залпов и поддержку строя.",
	},
	"thief": {
		"strength": "Добавляет вес backstab-ударам и рикошетам.",
		"agility": "Главный стат: ускоряет темп уловок, крит и выживание через движение.",
		"intelligence": "Зачаровывает дым и монеты теневой искрой.",
		"perception": "Расширяет цепь рикошета, дальность захода и зону дыма.",
		"energy": "Быстрее заряжает Большой Куш и снижает темп провалов.",
		"knowledge": "Добавляет яд/кровотечение к скрытым ударам.",
		"endurance": "Компенсирует низкое HP через устойчивость к ошибкам.",
		"leadership": "Подкупленная тень периодически повторяет удар.",
		"magic_damage": "Работает как теневое зачарование монет и клинков.",
		"sound_wave_damage": "Работает как отвлекающий свист: ближний контроль пространства.",
		"dot_damage": "Добавляет малый яд/bleed к backstab и дыму.",
		"summon_amount": "Учащает подкупленные эхо-удары.",
	},
	"elementalist": {
		"strength": "Утяжеляет метеоры и усиливает knockback от стихийных ударов.",
		"agility": "Ускоряет цикл переключения стихий, движение и шанс крита.",
		"intelligence": "Главный стат: усиливает магический урон всех стихий.",
		"perception": "Расширяет разломы, орбиты и точность выбора зоны.",
		"energy": "Ускоряет заряд Сверхновы и питает длительность стихийных паттернов.",
		"knowledge": "Усиливает burn/frost-like DoT от остаточных вспышек.",
		"endurance": "Компенсирует хрупкость защитой и HP.",
		"leadership": "Фамильяр-искра периодически повторяет малую стихийную вспышку.",
		"damage": "Работает как физический импульс метеорных осколков.",
		"sound_wave_damage": "Работает как громовой хлопок после стихийного удара.",
		"dot_damage": "Добавляет малые burn/frost тики к зонам.",
		"summon_amount": "Учащает фамильярные эхо-вспышки.",
	},
	"sniper": {
		"strength": "Усиливает отдачу тяжелых патронов и knockback lockshot.",
		"agility": "Ускоряет перезарядку, смену позиции и шанс крита.",
		"intelligence": "Зачаровывает патроны малым arcane splash.",
		"perception": "Главный стат: дальность, точность, радиус kill-zone и pickup.",
		"energy": "Быстрее заряжает Последний Выстрел и стабилизирует прицел.",
		"knowledge": "Добавляет bleed/armor-pierce DoT к marked shots.",
		"endurance": "Позволяет пережить ошибку при игре на дистанции.",
		"leadership": "Корректировщик периодически повторяет малый прицельный выстрел.",
		"magic_damage": "Работает как зачарованный наконечник пули.",
		"sound_wave_damage": "Работает как оглушающий дульный хлопок вблизи.",
		"dot_damage": "Добавляет кровотечение к lockshot и split-round.",
		"summon_amount": "Учащает корректировочные эхо-выстрелы.",
	},
	"priest": {
		"strength": "Придает вес кадилу и усиливает knockback священных волн.",
		"agility": "Ускоряет чтение молитв, движение и шанс крита.",
		"intelligence": "Усиливает священный магический урон печатей и молитв.",
		"perception": "Расширяет зоны печатей, дальность реликвария и радиус подбора.",
		"energy": "Быстрее заряжает Хор Искупления и поддерживает частые благословения.",
		"knowledge": "Главный стат: усиливает священные формулы, DoT-покаяние и эффективность лечения.",
		"endurance": "Дает HP/защиту, чтобы удерживать ближнюю ward-зону.",
		"leadership": "Приходская поддержка периодически повторяет малую молитву.",
		"damage": "Работает как физический импульс кадила и реликвария.",
		"sound_wave_damage": "Работает как церковный звон: ближний отталкивающий клич.",
		"dot_damage": "Добавляет покаянное горение к освященным целям.",
		"summon_amount": "Учащает эхо-молитвы прихожан.",
	},
	"biologist": {
		"strength": "Утяжеляет капсулы и повышает knockback биореакций.",
		"agility": "Ускоряет сбор образцов, смену позиции и шанс крита.",
		"intelligence": "Усиливает магическую биохимию спор и симбионтов.",
		"perception": "Расширяет зоны роста, дальность инъектора и радиус подбора.",
		"energy": "Быстрее заряжает Пробуждение Колонии и ускоряет реакционные циклы.",
		"knowledge": "Главный стат: усиливает анализ образцов, DoT и точность биореакций.",
		"endurance": "Компенсирует хрупкость HP/защитой при игре рядом с зонами.",
		"leadership": "Лабораторный ассистент периодически повторяет малую биореакцию.",
		"damage": "Работает как давление капсул и механический импульс инъектора.",
		"sound_wave_damage": "Работает как биоакустический отпугивающий импульс.",
		"dot_damage": "Усиливает споры, инфекционные тики и остаточную биомассу.",
		"summon_amount": "Учащает ассистентские эхо-реакции без добавления отдельного питомца.",
	},
	"robot": {
		"strength": "Главный стат: усиливает сервоприводы, гидравлику и физический импульс оружия.",
		"agility": "Сокращает инерцию корпуса: быстрее перезарядка, движение и шанс крита.",
		"intelligence": "Улучшает боевой алгоритм и добавляет маготехнический splash.",
		"perception": "Расширяет магнитные зоны, дальность захвата и радиус подбора.",
		"energy": "Питает реактор, быстрее заряжает Перегрузку и ускоряет контуры оружия.",
		"knowledge": "Стабилизирует перегрев: усиливает DoT/реген и снижает цену ошибок.",
		"endurance": "Ключевой защитный стат: HP, броня, поглощение и выдержка под давлением.",
		"leadership": "Автопилотный протокол периодически повторяет малый механический импульс.",
		"magic_damage": "Работает как рунический аккумулятор внутри механизма.",
		"sound_wave_damage": "Работает как сирена давления: ближний отталкивающий выброс.",
		"dot_damage": "Добавляет перегрев/искрение к реакторным и прессовым ударам.",
		"summon_amount": "Учащает эхо-протоколы сервоприводов без отдельного питомца.",
	},
	"engineer": {
		"strength": "Усиливает тяжелые инструменты, мины и отдачу турелей.",
		"agility": "Ускоряет сборку устройств, перезарядку и смену позиции.",
		"intelligence": "Улучшает схемы, target-logic и маготехнические импульсы.",
		"perception": "Расширяет сетку датчиков, радиус мин и дальность турелей.",
		"energy": "Питает мастерскую, ускоряет ультимейт и длительность активных контуров.",
		"knowledge": "Повышает качество ремонта, DoT-перегрев и стабильность устройств.",
		"endurance": "Дает запас прочности, чтобы успеть развернуть устройства под давлением.",
		"leadership": "Главный стат: повышает лимит/частоту устройств и протоколы поддержки.",
		"magic_damage": "Работает как руническая схема внутри механизмов.",
		"sound_wave_damage": "Работает как сирена мастерской: ближний контроль толпы.",
		"dot_damage": "Добавляет перегрев, искрение и шрапнель к устройствам.",
		"summon_amount": "Усиливает количество активных инженерных устройств и эхо-сборок.",
	},
	"dark_mage": {
		"strength": "Придает вес снарядам: больше knockback и физическая устойчивость.",
		"leadership": "Усиливает фамильярные эхо-касты и поддержку.",
		"sound_wave_damage": "Проявляется как разломный клич, отталкивающий ближайших врагов.",
		"summon_amount": "Учащает вспомогательные эхо-срабатывания.",
	},
	"guitarist": {
		"strength": "Делает волны тяжелее и сильнее отталкивает.",
		"intelligence": "Добавляет магический резонанс к звуку.",
		"dot_damage": "Добавляет жгучий feedback-DoT.",
		"summon_amount": "Увеличивает сценические deploy/echo-срабатывания.",
	},
	"assassin": {
		"intelligence": "Зачаровывает лезвия фиолетовой искрой по области.",
		"sound_wave_damage": "Дает тихий боевой клич-рывок контроля вокруг себя.",
		"leadership": "Фантом-двойник периодически повторяет удар.",
		"summon_amount": "Повышает частоту фантомного повторного удара.",
	},
	"ranger": {
		"intelligence": "Зачаровывает болты магическим splash.",
		"energy": "Быстрее заряжает стойку охотника.",
		"sound_wave_damage": "Боевой окрик отталкивает врагов, если подпустили близко.",
		"leadership": "Сокол-метка периодически повторяет урон по цели.",
	},
	"doctor": {
		"strength": "Утяжеляет инструменты и повышает контроль ближней пилы.",
		"sound_wave_damage": "Командный окрик раздвигает толпу вокруг пациента.",
		"leadership": "Санитарная команда усиливает эхо-лечение/повтор ударов.",
	},
	"chemist": {
		"strength": "Утяжеляет колбы и повышает knockback.",
		"sound_wave_damage": "Хлопок реагентов отталкивает врагов рядом.",
		"leadership": "Автономный помощник/эхо-реакция чаще повторяет удар.",
	},
	"knight": {
		"intelligence": "Зачаровывает сталь магическим splash.",
		"energy": "Сокращает cooldown контратаки.",
		"sound_wave_damage": "Боевой клич щита отталкивает врагов вокруг.",
		"leadership": "Знаменосец-аура чаще вызывает эхо-контроль.",
	},
	"druid": {
		"strength": "Усиливает когти/тернии и knockback.",
		"magic_damage": "Подпитывает природные заклинания и зачарованные зоны.",
		"sound_wave_damage": "Зов стаи работает как контрольная волна.",
		"energy": "Ускоряет природные циклы и уникальные cooldown.",
	},
}

const ATTRIBUTE_PRIORITIES := {
	"berserk": ["strength", "endurance", "agility", "perception", "leadership"],
	"soldier": ["perception", "strength", "agility", "endurance", "leadership"],
	"thief": ["agility", "perception", "strength", "energy", "leadership"],
	"elementalist": ["intelligence", "energy", "perception", "knowledge", "leadership"],
	"sniper": ["perception", "agility", "strength", "endurance", "knowledge"],
	"priest": ["knowledge", "intelligence", "energy", "leadership", "endurance"],
	"biologist": ["knowledge", "intelligence", "perception", "energy", "agility"],
	"robot": ["endurance", "strength", "energy", "perception", "knowledge"],
	"engineer": ["leadership", "intelligence", "perception", "energy", "knowledge"],
	"dark_mage": ["intelligence", "energy", "knowledge", "perception", "leadership"],
	"guitarist": ["leadership", "perception", "energy", "agility", "knowledge"],
	"assassin": ["agility", "strength", "perception", "energy", "leadership"],
	"ranger": ["perception", "agility", "strength", "knowledge", "energy"],
	"doctor": ["knowledge", "intelligence", "energy", "endurance", "perception"],
	"chemist": ["intelligence", "knowledge", "energy", "perception", "agility"],
	"knight": ["endurance", "strength", "leadership", "knowledge", "agility"],
	"druid": ["leadership", "perception", "energy", "knowledge", "endurance"],
}

const ATTRIBUTE_PRIORITY_REASONS := {
	"strength": "усиливает физический урон, контроль оружия и классовые физические интерпретации",
	"agility": "ускоряет атаки и движение, повышает критический шанс и уворот",
	"intelligence": "усиливает магический урон, зачарования и магические классовые механики",
	"perception": "увеличивает дальность, радиусы, pickup и точность позиционирования",
	"energy": "ускоряет уникальные механики, ультимейт и магический/звуковой темп",
	"knowledge": "усиливает DoT, лечение, регенерацию и стабильность билда",
	"endurance": "дает HP, защиту, поглощение и устойчивость под давлением",
	"leadership": "усиливает призывы, эхо-оружие, поддержку и ауры",
}

# Базовая цена артефакта в магазине по тиру (редкость и сила растут вместе).
const COST_BY_TIER := {1: 30, 2: 55, 3: 95}
# Вес появления артефакта в наградах/магазине по тиру (выше тир — реже).
const TIER_WEIGHTS := {1: 1.0, 2: 0.45, 3: 0.12}

const ASCENSION_MODIFIERS := [
	{"id": "asc_hardened_foes", "level": 1, "title": "Закалённые враги", "description": "Монстры: +15% HP и +10% урона.",
		"mods": {"enemy_hp_mult": 1.15, "enemy_damage_mult": 1.10}},
	{"id": "asc_greedy_merchants", "level": 2, "title": "Жадные торговцы", "description": "Все цены (магазин, докачка, reroll): +25%.",
		"mods": {"price_mult": 1.25}},
	{"id": "asc_swift_horde", "level": 3, "title": "Быстрая орда", "description": "Волны спавнятся чаще, плотность +20%.",
		"mods": {"spawn_count_mult": 1.20, "spawn_cooldown_mult": 0.83}},
	{"id": "asc_fierce_elites", "level": 4, "title": "Свирепые элитки", "description": "Элитки: +20% HP, боевая фаза открывается сразу.",
		"mods": {"elite_hp_mult": 1.20, "elite_instant_phase": 1.0}},
	{"id": "asc_scarce_spoils", "level": 5, "title": "Скудные трофеи", "description": "Золото и опыт с боёв: -20%.",
		"mods": {"reward_mult": 0.80}},
	{"id": "asc_thinned_flesh", "level": 6, "title": "Истончённая плоть", "description": "Всё лечение (зелья, регенерация, вампиризм, drain): -30%.",
		"mods": {"healing_mult": 0.70}},
	{"id": "asc_abyssal_echo", "level": 7, "title": "Эхо бездны", "description": "В обычных волнах может появиться мини-элитка со свитой.",
		"mods": {"mini_elite_chance": 0.20}},
	{"id": "asc_long_watch", "level": 8, "title": "Длинная вахта", "description": "Таймер боя +25%, спавн не ослабевает.",
		"mods": {"round_duration_mult": 1.25}},
	{"id": "asc_warden_wrath", "level": 9, "title": "Гнев стража", "description": "Босс: +1 опасная фаза, +20% HP, телеграфы короче.",
		"mods": {"boss_hp_mult": 1.20, "boss_extra_phase": 1.0, "boss_telegraph_mult": 0.75}},
	{"id": "asc_edge_of_madness", "level": 10, "title": "Грань безумия", "description": "Игрок: -20% макс. HP; стартовая волна каждого боя усилена.",
		"mods": {"player_max_hp_mult": 0.80, "first_wave_boost": 1.0}},
]
# Нейтральные значения модификаторов сложности (уровень 0 = текущая игра).
const ASCENSION_DIFFICULTY_DEFAULTS := {
	"enemy_hp_mult": 1.0, "enemy_damage_mult": 1.0,
	"price_mult": 1.0,
	"spawn_count_mult": 1.0, "spawn_cooldown_mult": 1.0,
	"elite_hp_mult": 1.0, "elite_instant_phase": 0.0,
	"reward_mult": 1.0,
	"healing_mult": 1.0,
	"mini_elite_chance": 0.0,
	"round_duration_mult": 1.0,
	"boss_hp_mult": 1.0, "boss_extra_phase": 0.0, "boss_telegraph_mult": 1.0,
	"player_max_hp_mult": 1.0, "first_wave_boost": 0.0,
}


const ASCENSION_LEVELS := {
	"berserk": [
		{"id": "berserk_asc_1", "title": "Кровавая закалка", "mods": {"damage_multiplier": 1.05}},
		{"id": "berserk_asc_2", "title": "Шкура зверя", "mods": {"max_health_flat": 8.0}},
		{"id": "berserk_asc_3", "title": "Боевой ритм", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "berserk_asc_4", "title": "Железная воля", "mods": {"defense_flat": 0.02}},
		{"id": "berserk_asc_5", "title": "Ярость предков", "mods": {"damage_multiplier": 1.07}},
		{"id": "berserk_asc_6", "title": "Несокрушимость", "mods": {"max_health_flat": 12.0}},
		{"id": "berserk_asc_7", "title": "Хищный глаз", "mods": {"crit_chance_flat": 0.03}},
		{"id": "berserk_asc_8", "title": "Вихрь стали", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "berserk_asc_9", "title": "Каменная кожа", "mods": {"defense_flat": 0.03}},
		{"id": "berserk_asc_10", "title": "Аватар войны", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
	"soldier": [
		{"id": "soldier_asc_1", "title": "Строевая Выучка", "mods": {"damage_multiplier": 1.05}},
		{"id": "soldier_asc_2", "title": "Плотный Мундир", "mods": {"max_health_flat": 8.0}},
		{"id": "soldier_asc_3", "title": "Быстрая Перезарядка", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "soldier_asc_4", "title": "Окопная Привычка", "mods": {"defense_flat": 0.02}},
		{"id": "soldier_asc_5", "title": "Пороховая Дисциплина", "mods": {"damage_multiplier": 1.07}},
		{"id": "soldier_asc_6", "title": "Марш-Бросок", "mods": {"max_health_flat": 12.0}},
		{"id": "soldier_asc_7", "title": "Верный Прицел", "mods": {"crit_chance_flat": 0.03}},
		{"id": "soldier_asc_8", "title": "Команда Залпа", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "soldier_asc_9", "title": "Держать Линию", "mods": {"defense_flat": 0.03}},
		{"id": "soldier_asc_10", "title": "Капитан Разлома", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
	"thief": [
		{"id": "thief_asc_1", "title": "Легкие Пальцы", "mods": {"damage_multiplier": 1.05}},
		{"id": "thief_asc_2", "title": "Запасной Кинжал", "mods": {"max_health_flat": 7.0}},
		{"id": "thief_asc_3", "title": "Быстрая Рука", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "thief_asc_4", "title": "Уход в Тень", "mods": {"dodge_flat": 0.02}},
		{"id": "thief_asc_5", "title": "Сорванный Кошель", "mods": {"money_gain_multiplier": 1.06}},
		{"id": "thief_asc_6", "title": "Тайный Карман", "mods": {"max_health_flat": 11.0}},
		{"id": "thief_asc_7", "title": "Прицельный Рикошет", "mods": {"crit_chance_flat": 0.03}},
		{"id": "thief_asc_8", "title": "Дымный Выход", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "thief_asc_9", "title": "Ни Следа", "mods": {"dodge_flat": 0.03}},
		{"id": "thief_asc_10", "title": "Король Карманов", "mods": {"damage_multiplier": 1.10, "money_gain_multiplier": 1.08}},
	],
	"elementalist": [
		{"id": "elementalist_asc_1", "title": "Искра Первостихии", "mods": {"damage_multiplier": 1.05}},
		{"id": "elementalist_asc_2", "title": "Кожух Пепла", "mods": {"max_health_flat": 6.0}},
		{"id": "elementalist_asc_3", "title": "Быстрый Поток", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "elementalist_asc_4", "title": "Широкая Мандала", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "elementalist_asc_5", "title": "Раскаленное Ядро", "mods": {"damage_multiplier": 1.07}},
		{"id": "elementalist_asc_6", "title": "Хрустальный Щит", "mods": {"max_health_flat": 10.0}},
		{"id": "elementalist_asc_7", "title": "Дальняя Призма", "mods": {"range_multiplier": 1.06}},
		{"id": "elementalist_asc_8", "title": "Четверной Круг", "mods": {"aoe_radius_multiplier": 1.06}},
		{"id": "elementalist_asc_9", "title": "Живая Молния", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "elementalist_asc_10", "title": "Архонт Стихий", "mods": {"damage_multiplier": 1.10, "aoe_radius_multiplier": 1.06}},
	],
	"sniper": [
		{"id": "sniper_asc_1", "title": "Холодная Мушка", "mods": {"damage_multiplier": 1.05}},
		{"id": "sniper_asc_2", "title": "Запасной Плащ", "mods": {"max_health_flat": 8.0}},
		{"id": "sniper_asc_3", "title": "Сухой Спуск", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "sniper_asc_4", "title": "Дальний Глаз", "mods": {"range_multiplier": 1.05}},
		{"id": "sniper_asc_5", "title": "Бронебойный Заряд", "mods": {"damage_multiplier": 1.07}},
		{"id": "sniper_asc_6", "title": "Низкая Позиция", "mods": {"defense_flat": 0.02}},
		{"id": "sniper_asc_7", "title": "Точный Расчет", "mods": {"crit_chance_flat": 0.03}},
		{"id": "sniper_asc_8", "title": "Быстрая Перезарядка", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "sniper_asc_9", "title": "Сквозной Прицел", "mods": {"crit_damage_multiplier": 1.06}},
		{"id": "sniper_asc_10", "title": "Мастер Одного Выстрела", "mods": {"damage_multiplier": 1.10, "range_multiplier": 1.06}},
	],
	"priest": [
		{"id": "priest_asc_1", "title": "Тихая Литания", "mods": {"damage_multiplier": 1.04}},
		{"id": "priest_asc_2", "title": "Теплый Плащ", "mods": {"max_health_flat": 8.0}},
		{"id": "priest_asc_3", "title": "Быстрая Молитва", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "priest_asc_4", "title": "Широкий Круг", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "priest_asc_5", "title": "Священная Формула", "mods": {"damage_multiplier": 1.06}},
		{"id": "priest_asc_6", "title": "Обет Стойкости", "mods": {"defense_flat": 0.025}},
		{"id": "priest_asc_7", "title": "Дальний Хор", "mods": {"range_multiplier": 1.05}},
		{"id": "priest_asc_8", "title": "Благодатный Ритм", "mods": {"regeneration_flat": 0.28}},
		{"id": "priest_asc_9", "title": "Звон Защиты", "mods": {"aoe_radius_multiplier": 1.06}},
		{"id": "priest_asc_10", "title": "Пастырь Разлома", "mods": {"damage_multiplier": 1.09, "max_health_flat": 12.0}},
	],
	"biologist": [
		{"id": "biologist_asc_1", "title": "Чистая Культура", "mods": {"damage_multiplier": 1.04}},
		{"id": "biologist_asc_2", "title": "Плотная Мембрана", "mods": {"max_health_flat": 7.0}},
		{"id": "biologist_asc_3", "title": "Быстрый Анализ", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "biologist_asc_4", "title": "Широкий Посев", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "biologist_asc_5", "title": "Сильный Реагент", "mods": {"damage_multiplier": 1.07}},
		{"id": "biologist_asc_6", "title": "Стерильный Костюм", "mods": {"defense_flat": 0.02}},
		{"id": "biologist_asc_7", "title": "Дальняя Проба", "mods": {"range_multiplier": 1.05}},
		{"id": "biologist_asc_8", "title": "Живой Катализ", "mods": {"dot_damage_flat": 2.0}},
		{"id": "biologist_asc_9", "title": "Быстрая Митоза", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "biologist_asc_10", "title": "Архив Генома", "mods": {"damage_multiplier": 1.09, "aoe_radius_multiplier": 1.06}},
	],
	"robot": [
		{"id": "robot_asc_1", "title": "Смазанные Шестерни", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "robot_asc_2", "title": "Толстый Корпус", "mods": {"max_health_flat": 10.0}},
		{"id": "robot_asc_3", "title": "Магнитная Обмотка", "mods": {"aoe_radius_multiplier": 1.04}},
		{"id": "robot_asc_4", "title": "Усиленный Сервопривод", "mods": {"damage_multiplier": 1.05}},
		{"id": "robot_asc_5", "title": "Пластинчатая Броня", "mods": {"defense_flat": 0.025}},
		{"id": "robot_asc_6", "title": "Стабильный Реактор", "mods": {"regeneration_flat": 0.22}},
		{"id": "robot_asc_7", "title": "Дальний Захват", "mods": {"range_multiplier": 1.05}},
		{"id": "robot_asc_8", "title": "Искровой Контур", "mods": {"dot_damage_flat": 2.0}},
		{"id": "robot_asc_9", "title": "Амортизаторы", "mods": {"move_speed_multiplier": 1.04}},
		{"id": "robot_asc_10", "title": "Неостановимый Протокол", "mods": {"damage_multiplier": 1.08, "max_health_flat": 14.0}},
	],
	"engineer": [
		{"id": "engineer_asc_1", "title": "Быстрая Сборка", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "engineer_asc_2", "title": "Запасные Пластины", "mods": {"max_health_flat": 8.0}},
		{"id": "engineer_asc_3", "title": "Дополнительный Модуль", "mods": {"summon_bonus": 1.0}},
		{"id": "engineer_asc_4", "title": "Точная Разметка", "mods": {"range_multiplier": 1.05}},
		{"id": "engineer_asc_5", "title": "Усиленный Привод", "mods": {"damage_multiplier": 1.06}},
		{"id": "engineer_asc_6", "title": "Ремонтный Контур", "mods": {"regeneration_flat": 0.24}},
		{"id": "engineer_asc_7", "title": "Широкая Сетка", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "engineer_asc_8", "title": "Искровые Контакты", "mods": {"dot_damage_flat": 2.0}},
		{"id": "engineer_asc_9", "title": "Полевой Инструмент", "mods": {"defense_flat": 0.02}},
		{"id": "engineer_asc_10", "title": "Главный Механик Разлома", "mods": {"damage_multiplier": 1.08, "summon_bonus": 1.0}},
	],
	"dark_mage": [
		{"id": "dark_mage_asc_1", "title": "Темный фокус", "mods": {"damage_multiplier": 1.05}},
		{"id": "dark_mage_asc_2", "title": "Пелена пустоты", "mods": {"max_health_flat": 6.0}},
		{"id": "dark_mage_asc_3", "title": "Расширение разлома", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "dark_mage_asc_4", "title": "Скороговорка заклятий", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "dark_mage_asc_5", "title": "Глубинная магия", "mods": {"damage_multiplier": 1.07}},
		{"id": "dark_mage_asc_6", "title": "Щит из тени", "mods": {"defense_flat": 0.03}},
		{"id": "dark_mage_asc_7", "title": "Дальний взор", "mods": {"range_multiplier": 1.06}},
		{"id": "dark_mage_asc_8", "title": "Резонанс проклятий", "mods": {"aoe_radius_multiplier": 1.06}},
		{"id": "dark_mage_asc_9", "title": "Жизнь из праха", "mods": {"max_health_flat": 10.0}},
		{"id": "dark_mage_asc_10", "title": "Владыка разлома", "mods": {"damage_multiplier": 1.10, "aoe_radius_multiplier": 1.06}},
	],
	"guitarist": [
		{"id": "guitarist_asc_1", "title": "Чистый звук", "mods": {"damage_multiplier": 1.05}},
		{"id": "guitarist_asc_2", "title": "Сценическая выдержка", "mods": {"max_health_flat": 7.0}},
		{"id": "guitarist_asc_3", "title": "Широкий резонанс", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "guitarist_asc_4", "title": "Быстрый перебор", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "guitarist_asc_5", "title": "Мощный рифф", "mods": {"damage_multiplier": 1.07}},
		{"id": "guitarist_asc_6", "title": "Ударная волна", "mods": {"knockback_multiplier": 1.08}},
		{"id": "guitarist_asc_7", "title": "Лёгкая походка", "mods": {"move_speed_multiplier": 1.04}},
		{"id": "guitarist_asc_8", "title": "Глубокий бас", "mods": {"aoe_radius_multiplier": 1.06}},
		{"id": "guitarist_asc_9", "title": "Кураж толпы", "mods": {"max_health_flat": 11.0}},
		{"id": "guitarist_asc_10", "title": "Легенда сцены", "mods": {"damage_multiplier": 1.10, "knockback_multiplier": 1.10}},
	],
	"assassin": [
		{"id": "assassin_asc_1", "title": "Первая Кровь", "mods": {"damage_multiplier": 1.05}},
		{"id": "assassin_asc_2", "title": "Тихий Шаг", "mods": {"max_health_flat": 8.0}},
		{"id": "assassin_asc_3", "title": "Острие Ночи", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "assassin_asc_4", "title": "Холодный Расчет", "mods": {"defense_flat": 0.02}},
		{"id": "assassin_asc_5", "title": "Двойной Росчерк", "mods": {"damage_multiplier": 1.07}},
		{"id": "assassin_asc_6", "title": "Тень Клинка", "mods": {"max_health_flat": 12.0}},
		{"id": "assassin_asc_7", "title": "Хватка Ужаса", "mods": {"crit_chance_flat": 0.03}},
		{"id": "assassin_asc_8", "title": "Безупречный Срез", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "assassin_asc_9", "title": "Глаз Бури", "mods": {"defense_flat": 0.03}},
		{"id": "assassin_asc_10", "title": "Властелин Теней", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
	"ranger": [
		{"id": "ranger_asc_1", "title": "Верный Прицел", "mods": {"damage_multiplier": 1.05}},
		{"id": "ranger_asc_2", "title": "Длинный Выдох", "mods": {"max_health_flat": 8.0}},
		{"id": "ranger_asc_3", "title": "Лунная Тетива", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "ranger_asc_4", "title": "Зоркость", "mods": {"defense_flat": 0.02}},
		{"id": "ranger_asc_5", "title": "Тяжелый Болт", "mods": {"damage_multiplier": 1.07}},
		{"id": "ranger_asc_6", "title": "Ветер Чащи", "mods": {"max_health_flat": 12.0}},
		{"id": "ranger_asc_7", "title": "Хищный Расчет", "mods": {"crit_chance_flat": 0.03}},
		{"id": "ranger_asc_8", "title": "Серебряный След", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "ranger_asc_9", "title": "Сердце Леса", "mods": {"defense_flat": 0.03}},
		{"id": "ranger_asc_10", "title": "Лунный Страж", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
	"doctor": [
		{"id": "doctor_asc_1", "title": "Полевые Швы", "mods": {"damage_multiplier": 1.05}},
		{"id": "doctor_asc_2", "title": "Крепкий Настой", "mods": {"max_health_flat": 8.0}},
		{"id": "doctor_asc_3", "title": "Чистые Руки", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "doctor_asc_4", "title": "Горький Тоник", "mods": {"defense_flat": 0.02}},
		{"id": "doctor_asc_5", "title": "Вторая Доза", "mods": {"damage_multiplier": 1.07}},
		{"id": "doctor_asc_6", "title": "Стальные Нервы", "mods": {"max_health_flat": 12.0}},
		{"id": "doctor_asc_7", "title": "Эликсир Стойкости", "mods": {"crit_chance_flat": 0.03}},
		{"id": "doctor_asc_8", "title": "Точная Инъекция", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "doctor_asc_9", "title": "Клятва Жизни", "mods": {"defense_flat": 0.03}},
		{"id": "doctor_asc_10", "title": "Архилекарь", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
	"chemist": [
		{"id": "chemist_asc_1", "title": "Едкая Смесь", "mods": {"damage_multiplier": 1.05}},
		{"id": "chemist_asc_2", "title": "Колба Праха", "mods": {"max_health_flat": 8.0}},
		{"id": "chemist_asc_3", "title": "Летучий Реагент", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "chemist_asc_4", "title": "Кислотный След", "mods": {"defense_flat": 0.02}},
		{"id": "chemist_asc_5", "title": "Нестабильный Состав", "mods": {"damage_multiplier": 1.07}},
		{"id": "chemist_asc_6", "title": "Пары Гнили", "mods": {"max_health_flat": 12.0}},
		{"id": "chemist_asc_7", "title": "Катализатор", "mods": {"crit_chance_flat": 0.03}},
		{"id": "chemist_asc_8", "title": "Цепная Реакция", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "chemist_asc_9", "title": "Формула Распада", "mods": {"defense_flat": 0.03}},
		{"id": "chemist_asc_10", "title": "Алхимия Конца", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
	"knight": [
		{"id": "knight_asc_1", "title": "Крепкий Щит", "mods": {"damage_multiplier": 1.05}},
		{"id": "knight_asc_2", "title": "Тяжелый Шаг", "mods": {"max_health_flat": 8.0}},
		{"id": "knight_asc_3", "title": "Несгибаемость", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "knight_asc_4", "title": "Клятва Стали", "mods": {"defense_flat": 0.02}},
		{"id": "knight_asc_5", "title": "Башня", "mods": {"damage_multiplier": 1.07}},
		{"id": "knight_asc_6", "title": "Сталь и Кровь", "mods": {"max_health_flat": 12.0}},
		{"id": "knight_asc_7", "title": "Бастион", "mods": {"crit_chance_flat": 0.03}},
		{"id": "knight_asc_8", "title": "Железная Воля", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "knight_asc_9", "title": "Страж Рубежа", "mods": {"defense_flat": 0.03}},
		{"id": "knight_asc_10", "title": "Паладин Разлома", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
	"druid": [
		{"id": "druid_asc_1", "title": "Зов Чащи", "mods": {"damage_multiplier": 1.05}},
		{"id": "druid_asc_2", "title": "Первый Зверь", "mods": {"max_health_flat": 8.0}},
		{"id": "druid_asc_3", "title": "Дикий Союз", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "druid_asc_4", "title": "Корни Силы", "mods": {"defense_flat": 0.02}},
		{"id": "druid_asc_5", "title": "Стая", "mods": {"damage_multiplier": 1.07}},
		{"id": "druid_asc_6", "title": "Шепот Леса", "mods": {"max_health_flat": 12.0}},
		{"id": "druid_asc_7", "title": "Когти и Клыки", "mods": {"crit_chance_flat": 0.03}},
		{"id": "druid_asc_8", "title": "Вожак", "mods": {"attack_speed_multiplier": 1.05}},
		{"id": "druid_asc_9", "title": "Сердце Чащи", "mods": {"defense_flat": 0.03}},
		{"id": "druid_asc_10", "title": "Аватар Природы", "mods": {"damage_multiplier": 1.10, "max_health_flat": 14.0}},
	],
}

const SHOP_ITEMS := [
	{"id": "shop_damage", "title": "Точильный камень", "description": "+10% к урону.", "cost": 42, "mods": {"damage_multiplier": 1.10}},
	{"id": "shop_heal", "title": "Полевой бинт", "description": "Восстановить 35% максимального здоровья.", "cost": 28, "heal_percent": 0.35},
	{"id": "shop_pickup", "title": "Магнитный талисман", "description": "+35 к радиусу подбора.", "cost": 35, "mods": {"pickup_radius_flat": 35.0}},
	{"id": "shop_speed", "title": "Легкие сапоги", "description": "+8% к скорости движения.", "cost": 35, "mods": {"move_speed_multiplier": 1.08}},
	{"id": "shop_weapon_cooldown", "title": "Масло темпа", "description": "+10% к скорости атаки.", "cost": 46, "mods": {"attack_speed_multiplier": 1.10}},
	{"id": "shop_range", "title": "Линза охоты", "description": "+12% к дальности атаки.", "cost": 42, "mods": {"range_multiplier": 1.12}},
	{"id": "shop_artifact", "title": "Пыльный артефакт", "description": "+1 случайная характеристика через Восприятие.", "cost": 52, "stats": {"perception": 1.0}},
]


static func artifact_definition(artifact_id: String) -> Dictionary:
	for artifact in ARTIFACTS:
		if str(artifact.get("id", "")) == artifact_id:
			return artifact
	for item in SHOP_ITEMS:
		if str(item.get("id", "")) == artifact_id:
			return item
	return {}


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
	var config := weapon_config.duplicate(true)
	if not apply_budget:
		config.erase("budget_damage_multiplier")
		config.erase("budget_tuning")
	var stats := base_stats(character_id)
	var params := derived_parameters(stats, {}, config)
	var damage_parameter := str(config.get("damage_parameter", damage_parameter_for(character_id)))
	var base_damage := float(params.get(damage_parameter, params.get("damage", 1.0)))
	var crit_factor := 1.0 + float(params.get("crit_chance", 0.0)) * maxf(float(params.get("crit_damage_multiplier", 1.0)) - 1.0, 0.0)
	var interval := maxf(float(config.get("fire_interval", 1.0)) / maxf(float(params.get("attack_speed", 1.0)), 0.1), 0.18)
	var direct_dps := base_damage * crit_factor / interval
	var hit_model := _budget_hit_model(config)
	var dot_dps := _budget_dot_dps(config, params, interval)
	var pool_dps := _budget_pool_dps(config, params, interval)
	var summon_dps := _budget_summon_dps(config, params)
	var solo_dps := direct_dps * float(hit_model.get("solo_hits", 1.0)) + dot_dps + pool_dps + summon_dps
	var aoe_dps := direct_dps * float(hit_model.get("five_hits", 1.0)) + dot_dps * float(hit_model.get("dot_targets", 1.0)) + pool_dps * float(hit_model.get("pool_targets", 1.0)) + summon_dps * float(hit_model.get("summon_targets", 1.0))
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


static func _budget_summon_dps(config: Dictionary, params: Dictionary) -> float:
	if int(config.get("max_summons", 0)) <= 0 and not config.has("summon_damage_multiplier"):
		return 0.0
	var summon_count: float = maxf(float(config.get("max_summons", 1.0)), 1.0) + floor(float(params.get("summon_amount", 0.0)) / 4.0)
	var summon_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) * float(config.get("summon_damage_multiplier", 0.36))
	return summon_count * summon_damage / 0.95


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
	var defense := clampf(float(params.get("defense", 0.0)), 0.0, 0.75)
	var dodge := clampf(float(params.get("dodge", 0.0)), 0.0, 0.8)
	var absorb := float(params.get("absorb", 0.0))
	var regen := float(params.get("regeneration", 0.0))
	var lifesteal := float(config.get("heal_percent_of_damage", 0.0)) * 120.0 + float(config.get("heal_percent_on_attack", 0.0)) * health * 2.0
	return health / maxf(1.0 - defense, 0.05) / maxf(1.0 - dodge, 0.05) + absorb * 10.0 + regen * BALANCE_WINDOW_SECONDS + lifesteal


static func weapon(character_id: String, weapon_id: String) -> Dictionary:
	var weapons: Dictionary = WEAPONS_BY_CLASS.get(character_id, BERSERK_WEAPONS)
	var fallback_id := str(weapons.keys()[0])
	var config: Dictionary = weapons.get(weapon_id, weapons[fallback_id]).duplicate(true)
	var tuning := budget_tuning_for(character_id, config)
	config["budget_profile"] = class_budget_profile(character_id)
	config["budget_damage_multiplier"] = float(tuning.get("damage_multiplier", 1.0))
	config["budget_solo_multiplier"] = float(tuning.get("solo_budget_multiplier", 1.0))
	config["budget_aoe_multiplier"] = float(tuning.get("aoe_budget_multiplier", 1.0))
	config["budget_tuning"] = tuning
	return config


static func derived_parameters(stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Dictionary:
	var strength := float(stats.get("strength", 0.0))
	var agility := float(stats.get("agility", 0.0))
	var intelligence := float(stats.get("intelligence", 0.0))
	var perception := float(stats.get("perception", 0.0))
	var energy := float(stats.get("energy", 0.0))
	var knowledge := float(stats.get("knowledge", 0.0))
	var endurance := float(stats.get("endurance", 0.0))
	var leadership := float(stats.get("leadership", 0.0))
	var weapon_damage_multiplier := float(weapon_config.get("damage_multiplier", 1.0)) * float(weapon_config.get("budget_damage_multiplier", 1.0))
	var passive_mods: Dictionary = weapon_config.get("passive_mods", {})

	# upgrade_*_exponent (>1 у молота) усиливает рост именно от апгрейдов забега,
	# не трогая пассивы оружия и стартовые значения.
	var upgrade_damage_exponent := float(weapon_config.get("upgrade_damage_exponent", 1.0))
	var upgrade_aoe_exponent := float(weapon_config.get("upgrade_aoe_exponent", 1.0))
	var damage_multiplier := pow(float(run_modifiers.get("damage_multiplier", 1.0)), upgrade_damage_exponent) * float(passive_mods.get("damage_multiplier", 1.0))
	# «Кровавый Рубеж» (tier 3): бонус урона активен, пока HP ниже порога (low_hp_active ставит player).
	damage_multiplier *= 1.0 + float(run_modifiers.get("low_hp_damage_bonus", 0.0)) * float(run_modifiers.get("low_hp_active", 0.0))
	var attack_speed_multiplier := float(run_modifiers.get("attack_speed_multiplier", 1.0)) * float(passive_mods.get("attack_speed_multiplier", 1.0))
	var move_speed_multiplier := float(run_modifiers.get("move_speed_multiplier", 1.0)) * float(passive_mods.get("move_speed_multiplier", 1.0))
	# «Призрачный Шаг» (tier 3): рывок скорости после уворота (dodge_rush_active ставит player).
	move_speed_multiplier *= 1.0 + float(run_modifiers.get("dodge_rush_bonus", 0.0)) * float(run_modifiers.get("dodge_rush_active", 0.0))
	var max_health_multiplier := float(run_modifiers.get("max_health_multiplier", 1.0)) * float(passive_mods.get("max_health_multiplier", 1.0))
	var range_multiplier := float(run_modifiers.get("range_multiplier", 1.0)) * float(passive_mods.get("range_multiplier", 1.0))
	var aoe_radius_multiplier := pow(float(run_modifiers.get("aoe_radius_multiplier", 1.0)), upgrade_aoe_exponent) * float(passive_mods.get("aoe_radius_multiplier", 1.0))
	var knockback_multiplier := float(run_modifiers.get("knockback_multiplier", 1.0)) * float(passive_mods.get("knockback_multiplier", 1.0))
	var defense_flat := float(run_modifiers.get("defense_flat", 0.0)) + float(passive_mods.get("defense_flat", 0.0))
	var pickup_radius_flat := float(run_modifiers.get("pickup_radius_flat", 0.0)) + float(passive_mods.get("pickup_radius_flat", 0.0))
	var max_health_flat := float(run_modifiers.get("max_health_flat", 0.0)) + float(passive_mods.get("max_health_flat", 0.0))
	var projectile_speed_flat := float(run_modifiers.get("projectile_speed_flat", 0.0)) + float(passive_mods.get("projectile_speed_flat", 0.0))
	var aura_radius_flat := float(run_modifiers.get("aura_radius_flat", 0.0)) + float(passive_mods.get("aura_radius_flat", 0.0))
	var buff_power_flat := float(run_modifiers.get("buff_power_flat", 0.0)) + float(passive_mods.get("buff_power_flat", 0.0))
	var dot_damage_flat := float(run_modifiers.get("dot_damage_flat", 0.0)) + float(passive_mods.get("dot_damage_flat", 0.0))
	var dot_speed_flat := float(run_modifiers.get("dot_speed_flat", 0.0)) + float(passive_mods.get("dot_speed_flat", 0.0))

	return {
		"damage": (15.0 * strength / 10.0) * weapon_damage_multiplier * damage_multiplier + float(run_modifiers.get("damage_flat", 0.0)),
		"magic_damage": (14.0 * intelligence / 10.0 + energy * 0.65) * weapon_damage_multiplier * damage_multiplier + float(run_modifiers.get("damage_flat", 0.0)),
		"sound_wave_damage": (12.0 * (perception + energy) / 12.0 + leadership * 0.45) * weapon_damage_multiplier * damage_multiplier + float(run_modifiers.get("damage_flat", 0.0)),
		"attack_speed": max(0.1, (9.0 * 3.0 * agility / 100.0) * attack_speed_multiplier),
		"crit_chance": clamp(0.05 + agility / 100.0 + float(run_modifiers.get("crit_chance_flat", 0.0)), 0.0, 0.8),
		"crit_damage_multiplier": 1.0 + 2.0 * agility / 20.0 + float(run_modifiers.get("crit_damage_flat", 0.0)),
		"move_speed": (282.0 + agility * 6.2) * move_speed_multiplier,
		"dodge": clamp(0.03 + agility * 0.014 + float(run_modifiers.get("dodge_flat", 0.0)), 0.0, 0.75),
		"defense": clamp(0.06 + endurance * 0.022 + defense_flat, 0.0, 0.75),
		"health_point": (50.0 * endurance / 4.0 + max_health_flat) * max_health_multiplier,
		"attack_range": (float(weapon_config.get("attack_range", 240.0)) + perception * 2.5) * range_multiplier,
		"aoe_radius": (float(weapon_config.get("aoe_radius", 190.0)) + perception * 3.5) * aoe_radius_multiplier,
		"pickup_radius": 105.0 + perception * 7.0 + pickup_radius_flat,
		"dot_damage": max(1.0, (4.0 + knowledge * 0.65 + dot_damage_flat) * damage_multiplier),
		"dot_speed": max(0.45, 0.65 + knowledge * 0.08 + dot_speed_flat),
		"projectile_speed": float(weapon_config.get("projectile_speed", 460.0)) + perception * 18.0 + agility * 9.0 + projectile_speed_flat,
		"aura_radius": (float(weapon_config.get("aoe_radius", 180.0)) + leadership * 5.0 + aura_radius_flat) * aoe_radius_multiplier,
		"buff_power": 1.0 + leadership * 0.025 + buff_power_flat,
		"knockback_power": (float(weapon_config.get("knockback", 60.0)) + endurance * 4.0 + leadership * 3.0) * knockback_multiplier,
		"summon_amount": leadership,
		# Подключение полного набора атрибутов (аудит 2026-06-11):
		"absorb": endurance * 0.25 + float(run_modifiers.get("absorb_flat", 0.0)),
		"regeneration": (0.55 + float(run_modifiers.get("regeneration_flat", 0.0))) * (0.65 + knowledge / 5.0),
		"vampiric_chance": clampf(float(run_modifiers.get("vampiric_chance_flat", 0.0)), 0.0, 0.35),
		"vampiric_amount": float(run_modifiers.get("vampiric_amount_flat", 0.0)),
		"knockback_distance": (float(weapon_config.get("knockback", 60.0)) + endurance * 4.0 + leadership * 3.0) * knockback_multiplier * endurance / 20.0,
		"range_multiplier": range_multiplier,
		# Усиливает классовую ульту: урон, радиус, длительность или число целей.
		"ultimate_multiplier": 1.0 + energy * 0.02 + float(run_modifiers.get("ultimate_flat", 0.0)),
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
const MINI_ELITE_KINDS := [
	{"id": "mini_scavenger_reaper", "title": "Жнец-Падальщик", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.42, "speed_mult": 1.28, "damage_mult": 1.05, "tint": [0.86, 0.96, 0.78], "desc": "Быстрый падальщик: рывками косит по дуге, добивая раненых первыми."},
	{"id": "mini_plague_bellringer", "title": "Чумной Звонарь", "scene": "poisoned", "behavior": "plague_prophet", "hp_mult": 0.60, "speed_mult": 0.72, "damage_mult": 0.85, "tint": [0.72, 0.96, 0.62], "desc": "Медлительный звонарь чумы: сеет ядовитые лужи вокруг себя."},
	{"id": "mini_bone_warden", "title": "Костяной Страж", "scene": "armored", "behavior": "iron_bastion", "hp_mult": 0.86, "speed_mult": 0.66, "damage_mult": 1.0, "tint": [0.94, 0.92, 0.84], "desc": "Костяной танк: бьёт ударной волной и держит строй, прикрывая свиту."},
	{"id": "mini_spark_wight", "title": "Искровик", "scene": "commander", "behavior": "shard_marshal", "hp_mult": 0.50, "speed_mult": 0.92, "damage_mult": 0.95, "tint": [0.72, 0.86, 1.0], "desc": "Дальнобойный дух искр: бьёт залпом веером с предупреждающим телеграфом."},
	{"id": "mini_rot_hound", "title": "Гнилая Гончая", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.40, "speed_mult": 1.32, "damage_mult": 1.0, "tint": [0.82, 0.70, 0.60], "desc": "Стайная гончая гнили: налетает рывком, оставляя кровоточащие раны."},
	{"id": "mini_shadow_devourer", "title": "Теневой Пожиратель", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.52, "speed_mult": 1.08, "damage_mult": 1.12, "tint": [0.56, 0.50, 0.76], "desc": "Тень-пожиратель: телепортируется к жертве после короткого телеграфа."},
]


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
