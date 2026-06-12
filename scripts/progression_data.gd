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
		"description": "Мили-AoE и высокий риск.",
		"strengths": "урон, HP, толпа.",
		"weaknesses": "нужна близость.",
		"sprite_path": "res://assets/sprites/characters/berserk_unarmed.png",
	},
	"dark_mage": {
		"id": "dark_mage",
		"title": "Темный маг",
		"description": "AoE, лучи и проклятия.",
		"strengths": "площадь, DoT, pierce.",
		"weaknesses": "хрупкий.",
		"sprite_path": "res://assets/sprites/characters/dark_mage.png",
	},
	"guitarist": {
		"id": "guitarist",
		"title": "Гитарист",
		"description": "Ритм, волны и контроль.",
		"strengths": "knockback, AoE, темп.",
		"weaknesses": "слабее по боссам.",
		"sprite_path": "res://assets/sprites/characters/guitarist.png",
	},
	"assassin": {
		"id": "assassin", "title": "Ассасин",
		"description": "Криты, скорость и яд.",
		"strengths": "криты, уворот, темп.",
		"weaknesses": "мало HP.",
		"sprite_path": "res://assets/sprites/characters/assassin.png",
	},
	"ranger": {
		"id": "ranger", "title": "Рейнджер",
		"description": "Дальние линии и ловушки.",
		"strengths": "дальность, pierce.",
		"weaknesses": "плох вблизи.",
		"sprite_path": "res://assets/sprites/characters/ranger.png",
	},
	"doctor": {
		"id": "doctor", "title": "Доктор",
		"description": "Лечение через урон.",
		"strengths": "sustain, яд, стабильность.",
		"weaknesses": "низкий burst.",
		"sprite_path": "res://assets/sprites/characters/doctor.png",
	},
	"chemist": {
		"id": "chemist", "title": "Химик",
		"description": "Взрывы и ядовитые зоны.",
		"strengths": "зоны, DoT, AoE.",
		"weaknesses": "хрупкий.",
		"sprite_path": "res://assets/sprites/characters/chemist.png",
	},
	"knight": {
		"id": "knight", "title": "Рыцарь",
		"description": "Танк, копье и щит.",
		"strengths": "HP, защита, контроль.",
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

const BERSERK_WEAPONS := {
	"sword": {
		"id": "sword",
		"title": "Двуручный меч",
		"description": "Широкий усеченный замах 90 градусов, радиус 600: надежно достает врагов рядом и впереди. Passive: +10% damage.",
		"scene_path": "res://scenes/TwoHandedSword.tscn",
		"attack_shape": "frustum",
		"cone_degrees": 90.0,
		"attack_range": 600.0,
		"start_distance": 0.0,
		"inner_width": 150.0,
		"outer_width": 1200.0,
		"aoe_radius": 600.0,
		"sweep_degrees": 90.0,
		"damage_multiplier": 1.15,
		"passive_mods": {"damage_multiplier": 1.10},
		"fire_interval": 0.58,
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

const ASSASSIN_WEAPONS := {
	"chakrams": {
		"id": "chakrams", "title": "Чакрамы",
		"description": "Возвращающиеся клинки: режут коридор до цели и обратно (два прохода урона).",
		"scene_path": "res://scenes/Chakrams.tscn",
		"attack_mode": "boomerang", "damage_parameter": "damage",
		"damage_multiplier": 0.45, "fire_interval": 0.62,
		"attack_range": 460.0, "aoe_radius": 60.0, "beam_width": 56.0,
		"projectile_speed": 760.0,
		"dash_on_crit_distance": 115.0,
		"visual_color": Color(0.72, 0.30, 1.0, 0.40),
		"passive_mods": {"crit_chance_flat": 0.06},
	},
	"shadow_daggers": {
		"id": "shadow_daggers", "title": "Теневые кинжалы",
		"description": "Серия быстрых коротких выпадов по ближайшим целям в узкой зоне. Критовый мили-стиль Ассасина.",
		"scene_path": "res://scenes/ShadowDaggers.tscn",
		"attack_mode": "stab_flurry", "damage_parameter": "damage",
		"damage_multiplier": 0.54, "fire_interval": 0.38,
		"attack_range": 230.0, "aoe_radius": 82.0, "wave_width": 190.0,
		"projectile_count": 3, "knockback": 35.0,
		"dash_on_crit_distance": 78.0,
		"visual_color": Color(0.55, 0.18, 0.88, 0.42),
		"passive_mods": {"crit_chance_flat": 0.10, "attack_speed_multiplier": 1.08},
	},
	"venom_wire": {
		"id": "venom_wire", "title": "Ядовитая струна",
		"description": "Тонкая ядовитая линия-гаррота: пробивает ряд врагов и оставляет poison DoT.",
		"scene_path": "res://scenes/VenomWire.tscn",
		"attack_mode": "dot_beam", "damage_parameter": "damage",
		"damage_multiplier": 0.68, "fire_interval": 0.78,
		"attack_range": 520.0, "aoe_radius": 75.0, "beam_width": 32.0,
		"pierce_count": 4, "dot_ticks": 4,
		"dash_on_crit_distance": 92.0,
		"visual_color": Color(0.32, 0.95, 0.28, 0.46),
		"passive_mods": {"crit_chance_flat": 0.04},
	},
}

const RANGER_WEAPONS := {
	"moon_crossbow": {
		"id": "moon_crossbow", "title": "Лунный арбалет",
		"description": "Заряжаемый болт: чем дольше Рейнджер стоит на месте, тем сильнее пробивающий выстрел.",
		"scene_path": "res://scenes/MoonCrossbow.tscn",
		"attack_mode": "beam", "damage_parameter": "damage",
		"damage_multiplier": 1.55, "fire_interval": 0.95,
		"attack_range": 900.0, "aoe_radius": 40.0, "beam_width": 26.0,
		"beam_count": 1, "pierce_count": 1,
		"charge_seconds": 1.25, "charge_max_multiplier": 1.70,
		"visual_color": Color(0.75, 0.85, 1.0, 0.50),
		"passive_mods": {"range_multiplier": 1.10},
	},
	"storm_longbow": {
		"id": "storm_longbow", "title": "Грозовой длинный лук",
		"description": "Заряжаемый грозовой веер: стойка усиливает дальние линии и пробивание.",
		"scene_path": "res://scenes/StormLongbow.tscn",
		"attack_mode": "beam", "damage_parameter": "damage",
		"damage_multiplier": 0.88, "fire_interval": 1.05,
		"attack_range": 780.0, "aoe_radius": 72.0, "beam_width": 34.0,
		"beam_count": 3, "beam_fan_degrees": 16.0, "pierce_count": 3,
		"charge_seconds": 1.45, "charge_max_multiplier": 1.55,
		"visual_color": Color(0.28, 0.72, 1.0, 0.48),
		"passive_mods": {"range_multiplier": 1.06, "attack_speed_multiplier": 0.96},
	},
	"hunter_trap": {
		"id": "hunter_trap", "title": "Охотничий капкан",
		"description": "Ставит ловушку перед Рейнджером: стойка ускоряет подготовку, первый враг запускает взрыв и отбрасывание.",
		"scene_path": "res://scenes/HunterTrap.tscn",
		"attack_mode": "trap", "damage_parameter": "damage",
		"damage_multiplier": 1.18, "fire_interval": 1.65,
		"attack_range": 380.0, "aoe_radius": 150.0, "pool_duration": 4.0,
		"pool_tick_interval": 0.20, "knockback": 150.0,
		"charge_seconds": 1.15, "charge_max_multiplier": 1.35,
		"visual_color": Color(0.86, 0.62, 0.22, 0.42),
		"passive_mods": {"pickup_radius_flat": 18.0},
	},
}

const DOCTOR_WEAPONS := {
	"restore_potion": {
		"id": "restore_potion", "title": "Зелье восстановления",
		"description": "Дренажная связь: вытягивает жизнь из ближайшей цели и лечит Доктора от нанесенного урона.",
		"scene_path": "res://scenes/RestorePotion.tscn",
		"attack_mode": "drain_link", "damage_parameter": "magic_damage",
		"damage_multiplier": 1.0, "fire_interval": 1.05,
		"attack_range": 560.0, "aoe_radius": 150.0, "beam_width": 46.0,
		"heal_percent_of_damage": 0.34,
		"visual_color": Color(0.35, 0.95, 0.55, 0.42),
		"passive_mods": {"max_health_multiplier": 1.10},
	},
	"plague_syringe": {
		"id": "plague_syringe", "title": "Чумной шприц",
		"description": "Тонкая чумная связь: одиночная цель получает яд, часть урона возвращается лечением.",
		"scene_path": "res://scenes/PlagueSyringe.tscn",
		"attack_mode": "drain_link", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.64, "fire_interval": 0.78,
		"attack_range": 590.0, "aoe_radius": 80.0, "beam_width": 30.0, "dot_ticks": 6,
		"projectile_speed": 700.0, "heal_percent_of_damage": 0.26,
		"visual_color": Color(0.36, 0.95, 0.42, 0.46),
		"passive_mods": {"max_health_multiplier": 1.04},
	},
	"bone_saw": {
		"id": "bone_saw", "title": "Костяная пила",
		"description": "Короткий кровавый arc: ближний риск, частые удары и малое лечение за атаку.",
		"scene_path": "res://scenes/BoneSaw.tscn",
		"attack_mode": "stab_flurry", "damage_parameter": "damage",
		"damage_multiplier": 0.82, "fire_interval": 0.58,
		"attack_range": 190.0, "aoe_radius": 70.0, "wave_width": 220.0,
		"projectile_count": 2, "dot_ticks": 3, "heal_percent_of_damage": 0.18,
		"visual_color": Color(0.88, 0.22, 0.18, 0.42),
		"passive_mods": {"defense_flat": 0.02},
	},
}

const CHEMIST_WEAPONS := {
	"blast_powder": {
		"id": "blast_powder", "title": "Взрывная пыль",
		"description": "Взрыв по области и ядовитое облако: тики DoT 3 секунды.",
		"scene_path": "res://scenes/BlastPowder.tscn",
		"attack_mode": "aoe_projectile", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.8, "fire_interval": 1.25,
		"attack_range": 580.0, "aoe_radius": 170.0, "projectile_speed": 500.0,
		"leaves_pool": true, "pool_element": "spark", "combo_clouds": true, "pool_duration": 3.0, "pool_tick_interval": 0.6,
		"visual_color": Color(0.62, 0.95, 0.18, 0.42),
		"passive_mods": {"aoe_radius_multiplier": 1.12},
	},
	"acid_flask": {
		"id": "acid_flask", "title": "Кислотная колба",
		"description": "Кислотный бросок: слабый взрыв, но большая едкая лужа с частыми DoT-тиками.",
		"scene_path": "res://scenes/AcidFlask.tscn",
		"attack_mode": "aoe_projectile", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.58, "fire_interval": 1.08,
		"attack_range": 600.0, "aoe_radius": 215.0, "projectile_speed": 520.0,
		"leaves_pool": true, "pool_element": "poison", "combo_clouds": true, "pool_duration": 4.2, "pool_tick_interval": 0.48,
		"visual_color": Color(0.22, 0.95, 0.26, 0.44),
		"passive_mods": {"aoe_radius_multiplier": 1.08},
	},
	"homunculus_vial": {
		"id": "homunculus_vial", "title": "Склянка гомункула",
		"description": "Временный алхимический приспешник: лимит небольшой, урон растет от магического урона.",
		"scene_path": "res://scenes/HomunculusVial.tscn",
		"damage_parameter": "magic_damage",
		"summon_damage_multiplier": 0.42,
		"damage_multiplier": 0.90, "fire_interval": 4.0,
		"attack_range": 420.0, "aoe_radius": 70.0,
		"max_summons": 1,
		"visual_color": Color(0.54, 0.96, 0.48, 0.42),
		"passive_mods": {"max_health_flat": 6.0},
	},
}

const KNIGHT_WEAPONS := {
	"long_spear": {
		"id": "long_spear", "title": "Копье",
		"description": "Длинный точечный выпад: узкая полоса 90 x 540, медленно и тяжело. Пассив: +5% защиты.",
		"scene_path": "res://scenes/LongSpear.tscn",
		"attack_shape": "strip", "cone_degrees": 24.0,
		"attack_range": 540.0, "start_distance": 0.0,
		"inner_width": 90.0, "outer_width": 90.0, "aoe_radius": 540.0,
		"sweep_degrees": 24.0, "damage_multiplier": 3.0, "fire_interval": 1.0,
		"visual_color": Color(0.80, 0.86, 0.95, 0.36),
		"passive_mods": {"defense_flat": 0.05, "block_reduction": 0.45, "counter_damage_multiplier": 0.55, "counter_cooldown": 2.6},
	},
	"tower_shield": {
		"id": "tower_shield", "title": "Башенный щит",
		"description": "Короткий фронтальный bash: меньше урона, сильная защита и отбрасывающая зона перед Рыцарем.",
		"scene_path": "res://scenes/TowerShield.tscn",
		"attack_shape": "sweep", "cone_degrees": 95.0,
		"attack_range": 215.0, "start_distance": 0.0,
		"inner_width": 150.0, "outer_width": 290.0, "aoe_radius": 215.0,
		"sweep_degrees": 95.0, "damage_multiplier": 0.72, "fire_interval": 0.82,
		"visual_color": Color(0.74, 0.78, 0.92, 0.36),
		"passive_mods": {"defense_flat": 0.08, "max_health_multiplier": 1.08, "block_reduction": 0.58, "counter_damage_multiplier": 0.42, "counter_cooldown": 2.2},
	},
	"holy_flail": {
		"id": "holy_flail", "title": "Освященный кистень",
		"description": "Тяжелый круговой замах средней дальности: медленнее щита, но лучше чистит толпу вокруг.",
		"scene_path": "res://scenes/HolyFlail.tscn",
		"attack_shape": "circle", "cone_degrees": 360.0,
		"attack_range": 235.0, "start_distance": 0.0,
		"inner_width": 180.0, "outer_width": 360.0, "aoe_radius": 235.0,
		"sweep_degrees": 360.0, "damage_multiplier": 0.86, "fire_interval": 1.18,
		"visual_color": Color(1.0, 0.84, 0.32, 0.34),
		"passive_mods": {"knockback_multiplier": 1.20, "block_reduction": 0.34, "counter_damage_multiplier": 0.72, "counter_cooldown": 2.9},
	},
}

const DRUID_WEAPONS := {
	"summon_amulet": {
		"id": "summon_amulet", "title": "Амулет призыва",
		"description": "Зовет зверей: стая бьется за друида, размер растет от Лидерства.",
		"scene_path": "res://scenes/SummonAmulet.tscn",
		"damage_parameter": "sound_wave_damage",
		"damage_multiplier": 1.0, "fire_interval": 3.0,
		"attack_range": 420.0, "aoe_radius": 60.0,
		"max_summons": 2,
		"command_mode": "attack_target",
		"visual_color": Color(0.45, 0.80, 0.35, 0.42),
		"passive_mods": {"buff_power_note": 0.0},
	},
	"briar_staff": {
		"id": "briar_staff", "title": "Посох терний",
		"description": "Бросок семени-терновника: зона шипов наносит DoT и держит толпу на дистанции.",
		"scene_path": "res://scenes/BriarStaff.tscn",
		"attack_mode": "aoe_projectile", "damage_parameter": "sound_wave_damage",
		"damage_multiplier": 0.70, "fire_interval": 1.20,
		"attack_range": 560.0, "aoe_radius": 190.0, "projectile_speed": 500.0,
		"leaves_pool": true, "pool_duration": 3.6, "pool_tick_interval": 0.55,
		"pool_element": "briar",
		"visual_color": Color(0.32, 0.78, 0.28, 0.44),
		"passive_mods": {"aoe_radius_multiplier": 1.08},
	},
	"raven_totem": {
		"id": "raven_totem", "title": "Вороний тотем",
		"description": "Ставит тотем воронов: автономные пульсы зоны, лимит растет от Лидерства.",
		"scene_path": "res://scenes/RavenTotem.tscn",
		"attack_mode": "amp", "damage_parameter": "sound_wave_damage",
		"damage_multiplier": 0.66, "fire_interval": 2.35,
		"attack_range": 470.0, "aoe_radius": 255.0, "knockback": 70.0,
		"amp_lifetime": 6.5, "amp_pulse_interval": 0.95, "max_summons": 1,
		"visual_color": Color(0.20, 0.72, 0.42, 0.40),
		"passive_mods": {"pickup_radius_flat": 20.0},
	},
}

const WEAPONS_BY_CLASS := {
	"berserk": BERSERK_WEAPONS,
	"dark_mage": DARK_MAGE_WEAPONS,
	"guitarist": GUITARIST_WEAPONS,
	"assassin": ASSASSIN_WEAPONS,
	"ranger": RANGER_WEAPONS,
	"doctor": DOCTOR_WEAPONS,
	"chemist": CHEMIST_WEAPONS,
	"knight": KNIGHT_WEAPONS,
	"druid": DRUID_WEAPONS,
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
	{"id": "leech_fang", "title": "Клык Пиявки", "tier": 2, "cost": 55, "class_affinity": [], "description": "+25% шанса вампиризма, +2 к силе вампиризма (лечение при ударе).", "mods": {"vampiric_chance_flat": 0.25, "vampiric_amount_flat": 2.0}},
]

const LEVEL_UP_REWARDS := [
	{"id": "damage_up", "title": "+Damage", "description": "+15% damage.", "kind": "upgrade", "mods": {"damage_multiplier": 1.15}},
	{"id": "attack_speed_up", "title": "+Attack Speed", "description": "+12% attack speed.", "kind": "upgrade", "mods": {"attack_speed_multiplier": 1.12}},
	{"id": "max_hp_up", "title": "+Max HP", "description": "+18 maximum HP.", "kind": "upgrade", "mods": {"max_health_flat": 18.0}},
	{"id": "move_speed_up", "title": "+Move Speed", "description": "+10% move speed.", "kind": "upgrade", "mods": {"move_speed_multiplier": 1.10}},
	{"id": "aoe_radius_up", "title": "+AoE Radius", "description": "+15% cone/radius coverage.", "kind": "upgrade", "mods": {"aoe_radius_multiplier": 1.15, "range_multiplier": 1.08}},
	{"id": "pickup_radius_up", "title": "+Pickup Radius", "description": "+45 pickup radius.", "kind": "upgrade", "mods": {"pickup_radius_flat": 45.0}},
	{"id": "defense_up", "title": "+Defense", "description": "+8% damage reduction.", "kind": "upgrade", "mods": {"defense_flat": 0.08}},
	{"id": "magic_focus_up", "title": "+Magic Focus", "description": "+14% magic/sound damage or weapon enchantment.", "kind": "upgrade", "mods": {"damage_multiplier": 1.14}},
	{"id": "knockback_up", "title": "+Knockback", "description": "+18% knockback and pulse control.", "kind": "upgrade", "mods": {"knockback_multiplier": 1.18}},
	{"id": "crit_chance_up", "title": "+Crit Chance", "description": "+7% crit chance.", "kind": "upgrade", "mods": {"crit_chance_flat": 0.07}},
	{"id": "crit_damage_up", "title": "+Crit Damage", "description": "+35% critical damage multiplier.", "kind": "upgrade", "mods": {"crit_damage_flat": 0.35}},
	{"id": "dodge_up", "title": "+Dodge", "description": "+6% dodge chance.", "kind": "upgrade", "mods": {"dodge_flat": 0.06}},
	{"id": "range_up", "title": "+Attack Range", "description": "+12% attack range.", "kind": "upgrade", "mods": {"range_multiplier": 1.12}},
	{"id": "dot_damage_up", "title": "+DoT Damage", "description": "+3 periodic damage. Non-DoT classes add small bleed/burn.", "kind": "upgrade", "mods": {"dot_damage_flat": 3.0}},
	{"id": "dot_speed_up", "title": "+DoT Speed", "description": "+0.25 DoT ticks per second.", "kind": "upgrade", "mods": {"dot_speed_flat": 0.25}},
	{"id": "projectile_speed_up", "title": "+Projectile Speed", "description": "+90 projectile speed and projectile weight.", "kind": "upgrade", "mods": {"projectile_speed_flat": 90.0}},
	{"id": "aura_radius_up", "title": "+Aura Radius", "description": "+55 aura radius. Non-aura classes gain stronger close battle-shout space.", "kind": "upgrade", "mods": {"aura_radius_flat": 55.0}},
	{"id": "buff_power_up", "title": "+Buff Power", "description": "+0.18 support/buff power.", "kind": "upgrade", "mods": {"buff_power_flat": 0.18}},
	{"id": "summon_amount_up", "title": "+Summon Amount", "description": "+2 summon power. Non-summoners trigger echo weapons/companions.", "kind": "upgrade", "mods": {"summon_bonus": 2.0}},
	{"id": "absorb_up", "title": "+Absorb", "description": "+4 flat damage absorption.", "kind": "upgrade", "mods": {"absorb_flat": 4.0}},
	{"id": "regeneration_up", "title": "+Regeneration", "description": "+0.8 regeneration base.", "kind": "upgrade", "mods": {"regeneration_flat": 0.8}},
	{"id": "vampiric_amount_up", "title": "+Vampiric Heal", "description": "+2 heal on vampiric hits.", "kind": "upgrade", "mods": {"vampiric_amount_flat": 2.0}},
	{"id": "vampiric_chance_up", "title": "+Vampiric Chance", "description": "+8% chance to heal on hit.", "kind": "upgrade", "mods": {"vampiric_chance_flat": 0.08}},
	{"id": "ultimate_power_up", "title": "+Ultimate Power", "description": "+0.12 ultimate power for class ultimate effects.", "kind": "upgrade", "mods": {"ultimate_flat": 0.12}},
]

const ULTIMATE_CONFIGS := {
	"berserk": {"title": "Неистовство", "description": "На несколько секунд ускоряется и каждый удар поднимает эхо-волну.", "duration": 5.5, "radius": 180.0, "damage": 0.75, "damage_charge_rate": 0.030, "taken_charge_rate": 1.35, "boss_cap": 0.10},
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


static func stage_scale(route_stage: int) -> float:
	var stage := maxf(float(route_stage), 0.0)
	return snappedf(pow(STAGE_SCALE_BASE, stage) + STAGE_SCALE_LINEAR * stage, 0.001)


static func stage_scaled_cost(base_cost: int, route_stage: int) -> int:
	return maxi(1, int(ceil(float(base_cost) * stage_scale(route_stage))))


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
		"dodge": clamp(0.02 + agility * 0.012 + float(run_modifiers.get("dodge_flat", 0.0)), 0.0, 0.8),
		"defense": clamp(0.04 + endurance * 0.018 + defense_flat, 0.0, 0.75),
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
		"regeneration": (0.3 + float(run_modifiers.get("regeneration_flat", 0.0))) * knowledge / 5.0,
		"vampiric_chance": clampf(float(run_modifiers.get("vampiric_chance_flat", 0.0)), 0.0, 0.6),
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
