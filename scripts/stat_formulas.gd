class_name StatFormulas
extends RefCounted

const STRENGTH := "strength"
const AGILITY := "agility"
const INTELLIGENCE := "intelligence"
const PERCEPTION := "perception"
const ENERGY := "energy"
const KNOWLEDGE := "knowledge"
const ENDURANCE := "endurance"
const LEADERSHIP := "leadership"

const BASE_STAT_ORDER := [
	STRENGTH,
	AGILITY,
	INTELLIGENCE,
	PERCEPTION,
	ENERGY,
	KNOWLEDGE,
	ENDURANCE,
	LEADERSHIP,
]

const DERIVED_STAT_ORDER := [
	"damage",
	"magic_damage",
	"crit_chance",
	"crit_damage_multiplier",
	"attack_speed",
	"dodge",
	"move_speed",
	"defense",
	"absorb",
	"health_point",
	"knockback_distance",
	"summon_amount",
	"attack_range",
	"range_multiplier",
	"regeneration",
	"vampiric_amount",
	"vampiric_chance",
	"dot_damage",
	"dot_speed",
	"aoe_radius",
	"aura_radius",
	"buff_power",
	"knockback_power",
	"projectile_speed",
	"ultimate_multiplier",
	"pickup_radius",
]

# SCRUM-1021: machine-readable base-characteristic dependencies for every
# player-facing derived attribute. This matrix mirrors the real equations in
# ProgressionData.derived_parameters(); localized prose is presentation only
# and must never be parsed as data. Each row is filtered from BASE_STAT_ORDER so
# Codex related rails remain stable and auditable in canonical order.
const DERIVED_BASE_DEPENDENCIES := {
	"damage": [STRENGTH],
	"magic_damage": [INTELLIGENCE],
	"crit_chance": [AGILITY],
	"crit_damage_multiplier": [AGILITY],
	"attack_speed": [AGILITY, PERCEPTION, ENERGY, ENDURANCE],
	"dodge": [AGILITY],
	"move_speed": [AGILITY],
	"defense": [ENDURANCE],
	"absorb": [ENDURANCE],
	"health_point": [ENDURANCE],
	"knockback_distance": [ENDURANCE, LEADERSHIP],
	"summon_amount": [INTELLIGENCE, ENERGY, KNOWLEDGE, LEADERSHIP],
	"attack_range": [INTELLIGENCE, PERCEPTION, ENDURANCE, LEADERSHIP],
	"range_multiplier": [],
	"regeneration": [KNOWLEDGE],
	"vampiric_amount": [],
	"vampiric_chance": [],
	"dot_damage": [KNOWLEDGE],
	"dot_speed": [AGILITY, ENERGY, KNOWLEDGE],
	"aoe_radius": [INTELLIGENCE, PERCEPTION, KNOWLEDGE, LEADERSHIP],
	"aura_radius": [PERCEPTION, ENERGY, KNOWLEDGE, LEADERSHIP],
	"buff_power": [ENERGY, KNOWLEDGE, LEADERSHIP],
	"knockback_power": [ENDURANCE, LEADERSHIP],
	"projectile_speed": [AGILITY, PERCEPTION, ENERGY, KNOWLEDGE],
	"ultimate_multiplier": [STRENGTH, AGILITY, INTELLIGENCE, PERCEPTION, ENERGY, KNOWLEDGE, ENDURANCE, LEADERSHIP],
	"pickup_radius": [PERCEPTION],
}

# FAN-1887: канонический player-facing порядок для Codex «Атрибуты» и других
# справочных проекций — только оси реестра CharacterData.ATTRIBUTE_REGISTRY в его
# порядке (оба урон-канала представляют оси «Добавление/Увеличение урона»;
# вампиризм — одна строка vampiric_amount, шанс срабатывания описан в её тексте).
# Полный DERIVED_STAT_ORDER остаётся внутренним контрактом формул/зависимостей.
const PLAYER_FACING_ATTRIBUTE_ORDER := [
	"damage",
	"magic_damage",
	"attack_speed",
	"health_point",
	"move_speed",
	"aoe_radius",
	"pickup_radius",
	"defense",
	"crit_chance",
	"crit_damage_multiplier",
	"dodge",
	"dot_damage",
	"summon_amount",
	"regeneration",
	"vampiric_amount",
	"ultimate_multiplier",
]

const STAT_DEFINITIONS := {
	STRENGTH: {
		"name_ru": "Сила",
		"name_en": "Strength",
		"type": "base",
		"description": "Влияет на физический урон, силу попадания, отталкивание и малый вклад в любой архетип оружия.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Физический урон и силовые эффекты ближнего боя.",
		"format": "plain",
	},
	AGILITY: {
		"name_ru": "Ловкость",
		"name_en": "Agility",
		"type": "base",
		"description": "Влияет на скорость атаки, скорость движения, шанс крита и уворот.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Скорость атаки, скорость движения, шанс и сила критического удара, уворот.",
		"format": "plain",
	},
	INTELLIGENCE: {
		"name_ru": "Интеллект",
		"name_en": "Intelligence",
		"type": "base",
		"description": "Влияет на магический урон, зачарования и малый дополнительный рост любого оружия.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Магический урон, магические взрывы по площади и зачарования.",
		"format": "plain",
	},
	PERCEPTION: {
		"name_ru": "Восприятие",
		"name_en": "Perception",
		"type": "base",
		"description": "Влияет на дальность, радиус атак/зон, скорость снарядов и радиус подбора.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Дальность атаки, радиус области, радиус подбора и скорость снарядов.",
		"format": "plain",
	},
	ENERGY: {
		"name_ru": "Энергия",
		"name_en": "Energy",
		"type": "base",
		"description": "Ускоряет уникальную механику класса, ультимативное умение и в малой степени темп оружия.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Магический урон, перезарядка и накопление уникальной механики класса.",
		"format": "plain",
	},
	KNOWLEDGE: {
		"name_ru": "Знание",
		"name_en": "Knowledge",
		"type": "base",
		"description": "Влияет на лечение, периодический урон, частоту его тиков и регенерацию.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Регенерация, периодический урон и частота его тиков.",
		"format": "plain",
	},
	ENDURANCE: {
		"name_ru": "Выносливость",
		"name_en": "Endurance",
		"type": "base",
		"description": "Влияет на максимальное здоровье, защиту, отталкивание и стабилизацию оружия.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Максимальное здоровье, защита и дальность отталкивания.",
		"format": "plain",
	},
	LEADERSHIP: {
		"name_ru": "Лидерство",
		"name_en": "Leadership",
		"type": "base",
		"description": "Влияет на количество и силу призывов, ауры и бафы.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Количество призывов, радиус ауры, сила усилений, эхо и спутники класса.",
		"format": "plain",
	},
	"damage": {
		"name_ru": "Урон",
		"name_en": "Damage",
		"type": "derived",
		"description": "Текущий урон оружия до крита.",
		"formula": "15 × Сила / 10 × множитель оружия × общий урон + плоская прибавка.",
		"influences": "Сила, оружие и награды на общий урон. Магический урон не усиливает физический канал.",
		"format": "decimal",
	},
	"magic_damage": {
		"name_ru": "Магический урон",
		"name_en": "Magic Damage",
		"type": "derived",
		"description": "Базовый урон магических атак до крита и эффектов оружия.",
		"formula": "14 × Интеллект / 10 × множитель оружия × общий урон × магическая мощь.",
		"influences": "Интеллект, оружие, общий урон и награды на магическую мощь. Не усиливает физический канал.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"crit_chance": {
		"name_ru": "Шанс крита",
		"name_en": "Crit Chance",
		"type": "derived",
		"description": "Вероятность нанести критический удар. С 0.1.5 использует убывающую отдачу, чтобы крит не заменял стабильный урон.",
		"formula": "Эффективное значение от 4% + Ловкость × 0,75% + плоская прибавка; предел 55%.",
		"influences": "Ловкость и награды на шанс критического удара.",
		"format": "percent",
	},
	"crit_damage_multiplier": {
		"name_ru": "Сила крита",
		"name_en": "Crit Damage Multiplier",
		"type": "derived",
		"description": "Множитель урона при критическом ударе.",
		"formula": "Ограничение от 1,30 + Ловкость × 0,055 + плоская прибавка в диапазоне 1,0–2,75.",
		"influences": "Ловкость и награды на силу критического удара.",
		"format": "multiplier",
	},
	"attack_speed": {
		"name_ru": "Скорость атаки",
		"name_en": "Attack Speed",
		"type": "derived",
		"description": "Количество атак в секунду. Перезарядка оружия пересчитывается от этого значения.",
		"formula": "Не менее 0,1; 27 × (Ловкость + Энергия × 0,18 + Восприятие × 0,10 + Выносливость × 0,04) / 100 × множитель.",
		"influences": "Ловкость, Энергия, Восприятие, Выносливость и награды на скорость атаки.",
		"format": "per_second",
	},
	"dodge": {
		"name_ru": "Уклонение",
		"name_en": "Dodge",
		"type": "derived",
		"description": "Шанс избежать входящего урона. Имеет убывающую отдачу и не может стать полной неуязвимостью.",
		"formula": "2% + Ловкость × 1% + плоская прибавка, затем убывающая отдача; предел 55%.",
		"influences": "Ловкость и награды на уворот.",
		"format": "percent",
	},
	"move_speed": {
		"name_ru": "Скорость движения",
		"name_en": "Move Speed",
		"type": "derived",
		"description": "Скорость перемещения персонажа.",
		"formula": "(282 + Ловкость × 6.2) × множитель скорости движения.",
		"influences": "Ловкость и награды на скорость движения.",
		"format": "units",
	},
	"defense": {
		"name_ru": "Защита",
		"name_en": "Defense",
		"type": "derived",
		"description": "Снижает входящий урон.",
		"formula": "4% + Выносливость × 1,8% + плоская прибавка, затем убывающая отдача; предел 62%.",
		"influences": "Выносливость и награды на защиту.",
		"format": "percent",
	},
	"absorb": {
		"name_ru": "Поглощение",
		"name_en": "Absorb",
		"type": "derived",
		"description": "Плоское поглощение перед основным уроном.",
		"formula": "Выносливость × 0,16 + смягчённые плоские награды. Срезает удар до защиты, но пропускает минимум 35% урона.",
		"influences": "Выносливость, предметы и защитные эффекты.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"health_point": {
		"name_ru": "Максимальное здоровье",
		"name_en": "HealthPoint",
		"type": "derived",
		"description": "Максимальное здоровье персонажа.",
		"formula": "(50 × Выносливость / 4 + плоское здоровье) × множитель максимального здоровья.",
		"influences": "Выносливость и награды на максимальное здоровье.",
		"format": "integer",
	},
	"knockback_distance": {
		"name_ru": "Отталкивание",
		"name_en": "Knockback Distance",
		"type": "derived",
		"description": "Отображаемая дистанция отталкивания врагов.",
		"formula": "(Отталкивание оружия + Выносливость × 4 + Лидерство × 3) × множитель отталкивания × Выносливость / 20.",
		"influences": "Выносливость, Лидерство и оружейные эффекты.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"summon_amount": {
		"name_ru": "Сила призыва",
		"name_en": "Summon Amount",
		"type": "derived",
		"description": "Потенциал количества призванных существ.",
		"formula": "Лидерство + Знание × 0,18 + Интеллект × 0,12 + Энергия × 0,10 + бонус призывов.",
		"influences": "Лидерство, Знание, Интеллект, Энергия и награды на призывы.",
		"format": "integer",
	},
	"attack_range": {
		"name_ru": "Дальность атаки",
		"name_en": "Attack Range",
		"type": "derived",
		"description": "Дальность текущей атаки/оружия.",
		"formula": "(Дальность оружия + Восприятие × 2,5 + Интеллект × вес оружия + Выносливость × 0,25 + Лидерство × 0,35) × множитель дальности.",
		"influences": "Интеллект, Восприятие, Выносливость, Лидерство, оружие и множитель дальности.",
		"format": "units",
	},
	"range_multiplier": {
		"name_ru": "Множитель дальности",
		"name_en": "Range Multiplier",
		"type": "derived",
		"description": "Множитель дальности атак. Изменяется наградами текущего забега.",
		"formula": "Множитель дальности текущего забега; без наград значение равно 100%.",
		"influences": "Награды и артефакты на дальность.",
		"format": "percent_from_one",
		"default_value": 1.0,
	},
	"regeneration": {
		"name_ru": "Регенерация",
		"name_en": "Regeneration",
		"type": "derived",
		"description": "Восстановление здоровья со временем.",
		"formula": "(0,22 + смягчённые награды) × (0,45 + Знание / 12) здоровья в секунду.",
		"influences": "Знание и эффекты лечения.",
		"format": "per_second",
		"default_value": 0.0,
	},
	"vampiric_amount": {
		"name_ru": "Вампиризм",
		"name_en": "Vampiric Amount",
		"type": "derived",
		"description": "Лечение при срабатывании вампиризма. Шанс срабатывания — отдельное условие с пределом 20%; отдельной осью прокачки он не является.",
		"formula": "55% от наград + 3,5% нанесённого урона при срабатывании; лечение ограничено секундным бюджетом.",
		"influences": "Награды, текущий урон и предметы; базовые характеристики не входят в прямую формулу.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"vampiric_chance": {
		"name_ru": "Шанс вампиризма",
		"name_en": "Vampiric Chance",
		"type": "derived",
		"description": "Шанс срабатывания вампиризма.",
		"formula": "Награды на шанс вампиризма; предел 22%.",
		"influences": "Награды и предметы; базовые характеристики не входят в прямую формулу.",
		"format": "percent",
		"default_value": 0.0,
	},
	"dot_damage": {
		"name_ru": "Периодический урон",
		"name_en": "DoT Damage",
		"type": "derived",
		"description": "Урон периодических эффектов: кровотечения, горения и отравления.",
		"formula": "(4 + Знание × 0,65 + плоская прибавка) × множитель урона.",
		"influences": "Знание, плоские награды периодического урона и общий множитель урона.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"dot_speed": {
		"name_ru": "Частота периодического урона",
		"name_en": "DoT Speed",
		"type": "derived",
		"description": "Частота тиков периодического урона.",
		"formula": "0,65 + Знание × 0,08 + Энергия × 0,015 + Ловкость × 0,010 + плоская прибавка.",
		"influences": "Знание, Энергия, Ловкость и эффекты периодического урона.",
		"format": "per_second",
		"default_value": 0.0,
	},
	"aoe_radius": {
		"name_ru": "Увеличение области атаки",
		"name_en": "Attack Area",
		"type": "derived",
		"description": "Отображаемый размер области оружия; для направленных атак участвует в ширине их коридора или сектора.",
		"formula": "(Радиус оружия + Восприятие × 3,5 + Интеллект × вес оружия + Знание × 0,35 + Лидерство × 0,30) × множитель радиуса.",
		"influences": "Интеллект, Восприятие, Знание, Лидерство, профиль оружия и награды на радиус области.",
		"format": "units",
	},
	"aura_radius": {
		"name_ru": "Радиус",
		"name_en": "Radius",
		"type": "derived",
		"description": "Радиус атак, зон, аур, усилителей и пульсовых эффектов.",
		"formula": "(Радиус оружия + вклад Лидерства, Восприятия, Энергии и Знания + плоская прибавка) × множитель радиуса.",
		"influences": "Лидерство, Восприятие, Энергия, Знание, оружие и награды на радиус.",
		"format": "units",
		"default_value": 0.0,
	},
	"buff_power": {
		"name_ru": "Сила бафа",
		"name_en": "Buff Power",
		"type": "derived",
		"description": "Сила будущих бафов, аур и командных эффектов.",
		"formula": "1 + Лидерство × 0,025 + Знание × 0,006 + Энергия × 0,004 + плоская прибавка.",
		"influences": "Лидерство, Знание, Энергия, предметы и ауры.",
		"format": "multiplier",
		"default_value": 1.0,
	},
	"knockback_power": {
		"name_ru": "Сила отталкивания",
		"name_en": "Knockback Power",
		"type": "derived",
		"description": "Сила отталкивания от баса, волн и тяжелых ударов.",
		"formula": "(Отталкивание оружия + Выносливость × 4 + Лидерство × 3) × множитель отталкивания.",
		"influences": "Выносливость, Лидерство, оружие и награды на отталкивание.",
		"format": "units",
		"default_value": 0.0,
	},
	"projectile_speed": {
		"name_ru": "Скорость снарядов",
		"name_en": "Projectile Speed",
		"type": "derived",
		"description": "Скорость снарядов и стабильность дальнего оружия.",
		"formula": "Скорость оружия + Восприятие × 18 + Ловкость × 9 + Энергия × 4 + Знание × 2 + плоская прибавка.",
		"influences": "Восприятие, Ловкость, Энергия, Знание и дальнобойное оружие.",
		"format": "units",
		"default_value": 0.0,
	},
	"ultimate_multiplier": {
		"name_ru": "Сила ультимейта",
		"name_en": "Ultimate Multiplier",
		"type": "derived",
		"description": "Множитель силы ультимативного умения класса.",
		"formula": "1,0 + Энергия × 0,02 + остальные базовые характеристики × 0,002 + награды.",
		"influences": "Энергия и малый вклад всех базовых характеристик; влияет на урон, длительность, радиус или количество целей ультимативного умения.",
		"format": "multiplier",
		"default_value": 1.0,
	},
	"pickup_radius": {
		"name_ru": "Радиус подбора",
		"name_en": "Pickup Radius",
		"type": "derived",
		"description": "Расстояние, на котором опыт и деньги притягиваются к игроку.",
		"formula": "105 + Восприятие × 7 + плоская прибавка к радиусу подбора.",
		"influences": "Восприятие и награды на радиус подбора.",
		"format": "units",
	},
}

const BASE_CHARACTER_STATS := {
	"berserk": {
		STRENGTH: 10.0,
		AGILITY: 5.0,
		INTELLIGENCE: 2.0,
		PERCEPTION: 5.0,
		ENERGY: 4.0,
		KNOWLEDGE: 4.0,
		ENDURANCE: 7.0,
		LEADERSHIP: 3.0,
	},
	"dark_mage": {
		STRENGTH: 2.0,
		AGILITY: 3.0,
		INTELLIGENCE: 10.0,
		PERCEPTION: 5.0,
		ENERGY: 7.0,
		KNOWLEDGE: 6.0,
		ENDURANCE: 2.0,
		LEADERSHIP: 5.0,
	},
	"guitarist": {
		STRENGTH: 4.0,
		AGILITY: 6.0,
		INTELLIGENCE: 4.0,
		PERCEPTION: 7.0,
		ENERGY: 6.0,
		KNOWLEDGE: 5.0,
		ENDURANCE: 4.0,
		LEADERSHIP: 7.0,
	},
}

const BASE_ENEMY_STATS := {
	"melee": {
		STRENGTH: 5.0,
		AGILITY: 5.0,
		INTELLIGENCE: 2.0,
		PERCEPTION: 2.0,
		ENERGY: 2.0,
		KNOWLEDGE: 1.0,
		ENDURANCE: 2.0,
		LEADERSHIP: 2.0,
	},
	"ranged": {
		STRENGTH: 3.0,
		AGILITY: 8.0,
		INTELLIGENCE: 1.0,
		PERCEPTION: 2.0,
		ENERGY: 2.0,
		KNOWLEDGE: 2.0,
		ENDURANCE: 2.0,
		LEADERSHIP: 1.0,
	},
	"charger": {
		STRENGTH: 3.0,
		AGILITY: 8.0,
		INTELLIGENCE: 1.0,
		PERCEPTION: 2.0,
		ENERGY: 2.0,
		KNOWLEDGE: 2.0,
		ENDURANCE: 2.0,
		LEADERSHIP: 1.0,
	},
}


static func character_stats(character_id: String) -> Dictionary:
	return BASE_CHARACTER_STATS.get(character_id, BASE_CHARACTER_STATS["berserk"]).duplicate()


static func enemy_stats(enemy_id: String) -> Dictionary:
	return BASE_ENEMY_STATS.get(enemy_id, BASE_ENEMY_STATS["melee"]).duplicate()


static func physical_damage(stats: Dictionary, default_damage: float, addition := 0.0) -> float:
	var universal_strength := (
		float(stats.get(STRENGTH, 1.0))
		+ float(stats.get(INTELLIGENCE, 0.0)) * 0.12
		+ float(stats.get(PERCEPTION, 0.0)) * 0.067
		+ float(stats.get(ENERGY, 0.0)) * 0.08
		+ float(stats.get(KNOWLEDGE, 0.0)) * 0.06
		+ float(stats.get(ENDURANCE, 0.0)) * 0.053
		+ float(stats.get(LEADERSHIP, 0.0)) * 0.067
	)
	return (default_damage + addition) * universal_strength / 10.0


static func crit_chance(stats: Dictionary, default_chance: float, addition := 0.0) -> float:
	var raw := default_chance + addition * 0.75 + float(stats.get(AGILITY, 0.0)) * 0.0075
	return clamp(raw / (1.0 + maxf(raw, 0.0) * 0.45), 0.0, 0.55)


static func crit_damage_multiplier(stats: Dictionary, default_multiplier: float, addition := 0.0) -> float:
	var agility := float(stats.get(AGILITY, 0.0))
	var flat := maxf(addition, 0.0) * 0.75 + minf(addition, 0.0)
	return clamp(1.30 + agility * 0.055 + flat, 1.0, 2.75)


static func attack_speed(stats: Dictionary, default_hits_per_second: float, addition := 0.0) -> float:
	var universal_agility := (
		float(stats.get(AGILITY, 0.0))
		+ float(stats.get(ENERGY, 0.0)) * 0.18
		+ float(stats.get(PERCEPTION, 0.0)) * 0.10
		+ float(stats.get(ENDURANCE, 0.0)) * 0.04
	)
	return max(0.1, (default_hits_per_second + addition) * 3.0 * universal_agility / 100.0)


static func dodge(stats: Dictionary, default_dodge: float, addition := 0.0) -> float:
	var raw := default_dodge * float(stats.get(AGILITY, 0.0)) / 10.0 + addition
	return clamp(raw / (1.0 + maxf(raw, 0.0) * 1.15), 0.0, 0.55)


static func health_points(stats: Dictionary, default_health: float, addition := 0.0) -> float:
	return default_health * float(stats.get(ENDURANCE, 1.0)) / 4.0 + addition


static func attack_range(default_range: float, addition := 0.0) -> float:
	return default_range + addition


static func stat_sections_for_player(player: Node) -> Dictionary:
	var stats_raw: Variant = player.get("stats")
	var parameters_raw: Variant = player.get("derived_parameters")
	var modifiers_raw: Variant = player.get("run_modifiers")
	var stats: Dictionary = stats_raw if stats_raw is Dictionary else {}
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var modifiers: Dictionary = modifiers_raw if modifiers_raw is Dictionary else {}
	var base_entries := []
	var derived_entries := []

	for stat_id in BASE_STAT_ORDER:
		base_entries.append(_entry_for_stat(str(stat_id), stats.get(stat_id, null)))

	for stat_id in DERIVED_STAT_ORDER:
		var raw_value: Variant = null
		if parameters.has(stat_id):
			raw_value = parameters[stat_id]
		elif stat_id == "range_multiplier":
			raw_value = modifiers.get("range_multiplier", STAT_DEFINITIONS[stat_id].get("default_value", null))
		else:
			raw_value = STAT_DEFINITIONS[stat_id].get("default_value", null)
		derived_entries.append(_entry_for_stat(str(stat_id), raw_value))

	return {
		"base": base_entries,
		"derived": derived_entries,
	}


static func _entry_for_stat(stat_id: String, raw_value: Variant) -> Dictionary:
	var definition: Dictionary = STAT_DEFINITIONS.get(stat_id, {})
	return {
		"id": stat_id,
		"name_ru": str(definition.get("name_ru", stat_id)),
		"name_en": str(definition.get("name_en", stat_id.capitalize())),
		"type": str(definition.get("type", "derived")),
		"description": str(definition.get("description", "Описание пока не добавлено.")),
		"formula": str(definition.get("formula", "Формула пока не подключена.")),
		"influences": str(definition.get("influences", "Связи пока не описаны.")),
		"value": raw_value,
		"value_text": format_stat_value(stat_id, raw_value),
	}


static func format_stat_value(stat_id: String, raw_value: Variant) -> String:
	if raw_value == null:
		return "N/A"

	var definition: Dictionary = STAT_DEFINITIONS.get(stat_id, {})
	var format_id := str(definition.get("format", "decimal"))
	var value := float(raw_value)
	match format_id:
		"integer":
			return str(int(round(value)))
		"plain":
			return "%.1f" % value
		"percent":
			return "%d%%" % int(round(value * 100.0))
		"percent_from_one":
			return "%d%%" % int(round(value * 100.0))
		"multiplier":
			return "%.2fx" % value
		"per_second":
			return "%.2f / sec" % value
		"units":
			return "%.0f" % value
		_:
			return "%.1f" % value
