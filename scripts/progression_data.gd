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
}

const CHARACTER_CONFIGS := {
	"berserk": {
		"id": "berserk",
		"title": "Берсерк",
		"description": "Ближний бой, cone/AoE контроль толпы, высокий HP.",
		"strengths": "Сильный melee урон, выживаемость, понятная позиционка.",
		"weaknesses": "Нужно подходить близко, плохо прощает окружение стрелками.",
		"sprite_path": "res://assets/sprites/characters/berserk_unarmed.png",
	},
	"dark_mage": {
		"id": "dark_mage",
		"title": "Темный маг",
		"description": "AoE, DoT, лучи и контроль пространства при низком HP.",
		"strengths": "Магический burst, урон по площади, pierce/DoT.",
		"weaknesses": "Хрупкий, зависит от дистанции и времени каста.",
		"sprite_path": "res://assets/sprites/characters/dark_mage.png",
	},
	"guitarist": {
		"id": "guitarist",
		"title": "Гитарист",
		"description": "Звуковые волны, пульсы, отталкивание и ауры.",
		"strengths": "Контроль толпы, knockback, стабильный AoE ритм.",
		"weaknesses": "Средний урон по одиночной жирной цели без усилений.",
		"sprite_path": "res://assets/sprites/characters/guitarist.png",
	},
}

const BERSERK_WEAPONS := {
	"sword": {
		"id": "sword",
		"title": "Двуручный меч",
		"description": "Узкая длинная полоса 120x500: быстрый точный удар по линии с высоким уроном. Passive: +10% damage.",
		"scene_path": "res://scenes/TwoHandedSword.tscn",
		"attack_shape": "strip",
		"cone_degrees": 36.0,
		"attack_range": 500.0,
		"start_distance": 0.0,
		"inner_width": 120.0,
		"outer_width": 120.0,
		"aoe_radius": 500.0,
		"sweep_degrees": 36.0,
		"damage_multiplier": 1.15,
		"passive_mods": {"damage_multiplier": 1.10},
		"fire_interval": 0.70,
		"visual_color": Color(0.62, 0.82, 1.0, 0.34),
	},
	"axe": {
		"id": "axe",
		"title": "Двуручный топор",
		"description": "Широкая дуга 140 градусов, радиус 320: контроль окружения вблизи, урон ниже меча. Passive: -10% damage.",
		"scene_path": "res://scenes/TwoHandedAxe.tscn",
		"attack_shape": "sweep",
		"cone_degrees": 140.0,
		"attack_range": 320.0,
		"start_distance": 0.0,
		"inner_width": 190.0,
		"outer_width": 560.0,
		"aoe_radius": 320.0,
		"sweep_degrees": 140.0,
		"damage_multiplier": 0.85,
		"passive_mods": {"damage_multiplier": 0.90},
		"fire_interval": 1.06,
		"visual_color": Color(1.0, 0.58, 0.24, 0.34),
	},
	"hammer": {
		"id": "hammer",
		"title": "Двуручный молот",
		"description": "Слабый старт: круг радиуса 100 и низкий урон, но усиленный рост от AoE/damage апгрейдов до огромного круга к концу забега. Passive: +20% AoE radius.",
		"scene_path": "res://scenes/TwoHandedHammer.tscn",
		"attack_shape": "circle",
		"cone_degrees": 360.0,
		"attack_range": 100.0,
		"start_distance": 0.0,
		"inner_width": 180.0,
		"outer_width": 360.0,
		"aoe_radius": 100.0,
		"sweep_degrees": 360.0,
		"damage_multiplier": 0.55,
		"passive_mods": {"aoe_radius_multiplier": 1.20},
		"upgrade_aoe_exponent": 1.8,
		"upgrade_damage_exponent": 1.45,
		"fire_interval": 1.25,
		"visual_color": Color(0.82, 0.72, 1.0, 0.32),
	},
}

const DARK_MAGE_WEAPONS := {
	"dark_book": {
		"id": "dark_book",
		"title": "Книга тьмы",
		"description": "Два AoE-снаряда: летят в две ближайшие цели и взрываются по области.",
		"scene_path": "res://scenes/DarkBook.tscn",
		"attack_mode": "aoe_projectile",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.95,
		"projectile_count": 2,
		"fire_interval": 1.31,
		"attack_range": 620.0,
		"aoe_radius": 175.0,
		"projectile_speed": 520.0,
		"visual_color": Color(0.45, 0.15, 0.88, 0.38),
		"passive_mods": {"aoe_radius_multiplier": 1.10},
	},
	"cursed_skull": {
		"id": "cursed_skull",
		"title": "Проклятый череп",
		"description": "Быстрое проклятие: цель получает удар и несколько DoT-тиков.",
		"scene_path": "res://scenes/CursedSkull.tscn",
		"attack_mode": "homing_curse",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.75,
		"fire_interval": 0.99,
		"attack_range": 560.0,
		"aoe_radius": 115.0,
		"dot_ticks": 5,
		"projectile_speed": 680.0,
		"visual_color": Color(0.78, 0.16, 1.0, 0.42),
		"passive_mods": {"damage_multiplier": 0.95},
	},
	"dark_wand": {
		"id": "dark_wand",
		"title": "Темная палочка",
		"description": "Два pierce-луча веером: пробивают несколько врагов каждый, но бьют реже.",
		"scene_path": "res://scenes/DarkWand.tscn",
		"attack_mode": "beam",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.95,
		"fire_interval": 1.54,
		"attack_range": 720.0,
		"aoe_radius": 70.0,
		"beam_width": 56.0,
		"beam_count": 2,
		"beam_fan_degrees": 14.0,
		"pierce_count": 5,
		"visual_color": Color(0.28, 0.95, 1.0, 0.45),
		"passive_mods": {"range_multiplier": 1.08},
	},
}

const GUITARIST_WEAPONS := {
	"electric_guitar": {
		"id": "electric_guitar",
		"title": "Электрогитара",
		"description": "Направленная звуковая волна: широкий удар вперед с легким отталкиванием.",
		"scene_path": "res://scenes/ElectricGuitar.tscn",
		"attack_mode": "sound_wave",
		"damage_parameter": "sound_wave_damage",
		"damage_multiplier": 1.0,
		"fire_interval": 0.96,
		"attack_range": 560.0,
		"aoe_radius": 230.0,
		"wave_width": 240.0,
		"knockback": 90.0,
		"visual_color": Color(0.18, 0.95, 0.85, 0.36),
		"passive_mods": {"attack_speed_multiplier": 1.15},
	},
	"bass_guitar": {
		"id": "bass_guitar",
		"title": "Бас-гитара",
		"description": "Частый слабый бас-пульс вокруг героя: минимальный урон, максимальный контроль отталкиванием.",
		"scene_path": "res://scenes/BassGuitar.tscn",
		"attack_mode": "pulse",
		"damage_parameter": "sound_wave_damage",
		"damage_multiplier": 0.30,
		"fire_interval": 0.85,
		"attack_range": 280.0,
		"aoe_radius": 280.0,
		"knockback": 180.0,
		"visual_color": Color(1.0, 0.78, 0.18, 0.34),
		"passive_mods": {"attack_speed_multiplier": 1.10},
	},
	"sound_amp": {
		"id": "sound_amp",
		"title": "Звуковой усилитель",
		"description": "Деплой: усилитель стоит на земле ~7с и пульсирует сам; одновременно 1 + Лидерство/4 ампов.",
		"scene_path": "res://scenes/SoundAmp.tscn",
		"attack_mode": "amp",
		"damage_parameter": "sound_wave_damage",
		"damage_multiplier": 0.82,
		"fire_interval": 2.80,
		"attack_range": 520.0,
		"aoe_radius": 235.0,
		"knockback": 130.0,
		"amp_lifetime": 7.0,
		"amp_pulse_interval": 1.1,
		"max_summons": 1,
		"visual_color": Color(1.0, 0.35, 0.72, 0.35),
		"passive_mods": {"pickup_radius_flat": 30.0},
	},
}

const WEAPONS_BY_CLASS := {
	"berserk": BERSERK_WEAPONS,
	"dark_mage": DARK_MAGE_WEAPONS,
	"guitarist": GUITARIST_WEAPONS,
}

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
]

const LEVEL_UP_REWARDS := [
	{"id": "damage_up", "title": "+Damage", "description": "+15% damage.", "kind": "upgrade", "mods": {"damage_multiplier": 1.15}},
	{"id": "attack_speed_up", "title": "+Attack Speed", "description": "+12% attack speed.", "kind": "upgrade", "mods": {"attack_speed_multiplier": 1.12}},
	{"id": "max_hp_up", "title": "+Max HP", "description": "+18 maximum HP.", "kind": "upgrade", "mods": {"max_health_flat": 18.0}},
	{"id": "move_speed_up", "title": "+Move Speed", "description": "+10% move speed.", "kind": "upgrade", "mods": {"move_speed_multiplier": 1.10}},
	{"id": "aoe_radius_up", "title": "+AoE Radius", "description": "+15% cone/radius coverage.", "kind": "upgrade", "mods": {"aoe_radius_multiplier": 1.15, "range_multiplier": 1.08}},
	{"id": "pickup_radius_up", "title": "+Pickup Radius", "description": "+45 pickup radius.", "kind": "upgrade", "mods": {"pickup_radius_flat": 45.0}},
	{"id": "defense_up", "title": "+Defense", "description": "+8% damage reduction.", "kind": "upgrade", "mods": {"defense_flat": 0.08}},
	{"id": "magic_focus_up", "title": "+Magic Focus", "description": "+14% magic/sound damage.", "kind": "upgrade", "relevant_classes": ["dark_mage", "guitarist"], "mods": {"damage_multiplier": 1.14}},
	{"id": "knockback_up", "title": "+Knockback", "description": "+18% knockback and pulse control.", "kind": "upgrade", "mods": {"knockback_multiplier": 1.18}},
]

# Классовая релевантность урона: какой derived-параметр является «своим» уроном класса.
const CLASS_DAMAGE_PARAMETER := {
	"berserk": "damage",
	"dark_mage": "magic_damage",
	"guitarist": "sound_wave_damage",
}
# Атрибуты, дающие силу только перечисленным классам (по формулам derived_parameters):
# strength питает только физический урон, intelligence — только магический,
# energy — магический и звуковой. Отсутствие в карте = атрибут универсален.
const STAT_CLASS_RELEVANCE := {
	"strength": ["berserk"],
	"intelligence": ["dark_mage"],
	"energy": ["dark_mage", "guitarist"],
}

# Базовая цена артефакта в магазине по тиру (редкость и сила растут вместе).
const COST_BY_TIER := {1: 30, 2: 55, 3: 95}
# Вес появления артефакта в наградах/магазине по тиру (выше тир — реже).
const TIER_WEIGHTS := {1: 1.0, 2: 0.45, 3: 0.12}

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
}

const SHOP_ITEMS := [
	{"id": "shop_damage", "title": "Точильный камень", "description": "+10% damage.", "cost": 42, "mods": {"damage_multiplier": 1.10}},
	{"id": "shop_heal", "title": "Полевой бинт", "description": "Восстановить 35% максимального HP.", "cost": 28, "heal_percent": 0.35},
	{"id": "shop_pickup", "title": "Магнитный талисман", "description": "+35 pickup radius.", "cost": 35, "mods": {"pickup_radius_flat": 35.0}},
	{"id": "shop_speed", "title": "Легкие сапоги", "description": "+8% move speed.", "cost": 35, "mods": {"move_speed_multiplier": 1.08}},
	{"id": "shop_weapon_cooldown", "title": "Масло темпа", "description": "+10% attack speed.", "cost": 46, "mods": {"attack_speed_multiplier": 1.10}},
	{"id": "shop_range", "title": "Линза охоты", "description": "+12% attack range.", "cost": 42, "mods": {"range_multiplier": 1.12}},
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
	var relevant: Array = STAT_CLASS_RELEVANCE.get(stat_id, [])
	return relevant.is_empty() or relevant.has(character_id)


static func is_reward_relevant(reward: Dictionary, character_id: String) -> bool:
	var relevant_classes: Array = reward.get("relevant_classes", [])
	if not relevant_classes.is_empty() and not relevant_classes.has(character_id):
		return false
	for stat_id in (reward.get("stats", {}) as Dictionary).keys():
		if not is_stat_relevant(str(stat_id), character_id):
			return false
	return true


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


static func weapon(character_id: String, weapon_id: String) -> Dictionary:
	var weapons: Dictionary = WEAPONS_BY_CLASS.get(character_id, BERSERK_WEAPONS)
	var fallback_id := str(weapons.keys()[0])
	return weapons.get(weapon_id, weapons[fallback_id]).duplicate(true)


static func derived_parameters(stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Dictionary:
	var strength := float(stats.get("strength", 0.0))
	var agility := float(stats.get("agility", 0.0))
	var intelligence := float(stats.get("intelligence", 0.0))
	var perception := float(stats.get("perception", 0.0))
	var energy := float(stats.get("energy", 0.0))
	var knowledge := float(stats.get("knowledge", 0.0))
	var endurance := float(stats.get("endurance", 0.0))
	var leadership := float(stats.get("leadership", 0.0))
	var weapon_damage_multiplier := float(weapon_config.get("damage_multiplier", 1.0))
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

	return {
		"damage": (15.0 * strength / 10.0) * weapon_damage_multiplier * damage_multiplier + float(run_modifiers.get("damage_flat", 0.0)),
		"magic_damage": (14.0 * intelligence / 10.0 + energy * 0.65) * weapon_damage_multiplier * damage_multiplier + float(run_modifiers.get("damage_flat", 0.0)),
		"sound_wave_damage": (12.0 * (perception + energy) / 12.0 + leadership * 0.45) * weapon_damage_multiplier * damage_multiplier + float(run_modifiers.get("damage_flat", 0.0)),
		"attack_speed": max(0.1, (9.0 * 3.0 * agility / 100.0) * attack_speed_multiplier),
		"crit_chance": clamp(0.05 + agility / 100.0 + float(run_modifiers.get("crit_chance_flat", 0.0)), 0.0, 0.8),
		"crit_damage_multiplier": 1.0 + 2.0 * agility / 20.0 + float(run_modifiers.get("crit_damage_flat", 0.0)),
		"move_speed": (282.0 + agility * 6.2) * move_speed_multiplier,
		"dodge": clamp(0.02 + agility * 0.012 + float(run_modifiers.get("dodge_flat", 0.0)), 0.0, 0.8),
		"defense": clamp(0.04 + endurance * 0.018 + defense_flat, 0.0, 0.75),
		"health_point": (50.0 * endurance / 4.0 + max_health_flat) * max_health_multiplier,
		"attack_range": (float(weapon_config.get("attack_range", 240.0)) + perception * 2.5) * range_multiplier,
		"aoe_radius": (float(weapon_config.get("aoe_radius", 190.0)) + perception * 3.5) * aoe_radius_multiplier,
		"pickup_radius": 105.0 + perception * 7.0 + pickup_radius_flat,
		"dot_damage": max(1.0, (4.0 + knowledge * 0.65) * damage_multiplier),
		"dot_speed": max(0.45, 0.65 + knowledge * 0.08),
		"projectile_speed": float(weapon_config.get("projectile_speed", 460.0)) + perception * 18.0 + agility * 9.0,
		"aura_radius": (float(weapon_config.get("aoe_radius", 180.0)) + leadership * 5.0) * aoe_radius_multiplier,
		"buff_power": 1.0 + leadership * 0.025,
		"knockback_power": (float(weapon_config.get("knockback", 60.0)) + endurance * 4.0 + leadership * 3.0) * knockback_multiplier,
		"summon_amount": leadership,
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


static func shop_items() -> Array:
	var items := []
	for item in SHOP_ITEMS:
		items.append(item.duplicate(true))
	for artifact in ARTIFACTS:
		var shop_artifact: Dictionary = artifact.duplicate(true)
		shop_artifact["cost"] = int(shop_artifact.get("cost", COST_BY_TIER.get(int(shop_artifact.get("tier", 1)), 30)))
		shop_artifact["kind"] = "artifact"
		shop_artifact["weight"] = TIER_WEIGHTS.get(int(shop_artifact.get("tier", 1)), 1.0)
		items.append(shop_artifact)
	return items


static func display_stats(stats: Dictionary) -> String:
	var parts := []
	for stat_id in STAT_NAMES.keys():
		parts.append("%s %.0f" % [STAT_NAMES[stat_id], float(stats.get(stat_id, 0.0))])
	return " | ".join(parts)


static func display_derived_parameters(parameters: Dictionary) -> String:
	return "Damage %.1f | Magic %.1f | Sound %.1f | AS %.2f | Crit %.0f%% | Defense %.0f%% | Range %.0f | AoE %.0f | Pickup %.0f" % [
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
