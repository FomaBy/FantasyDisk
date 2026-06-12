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
	"sound_wave_damage",
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

const STAT_DEFINITIONS := {
	STRENGTH: {
		"name_ru": "Сила",
		"name_en": "Strength",
		"type": "base",
		"description": "Влияет на физический урон и силовые melee-параметры.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Damage, силовые melee-эффекты.",
		"format": "plain",
	},
	AGILITY: {
		"name_ru": "Ловкость",
		"name_en": "Agility",
		"type": "base",
		"description": "Влияет на скорость атаки, скорость движения, шанс крита и уворот.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Attack Speed, Move Speed, Crit Chance, Crit Damage, Dodge.",
		"format": "plain",
	},
	INTELLIGENCE: {
		"name_ru": "Интеллект",
		"name_en": "Intelligence",
		"type": "base",
		"description": "Влияет на магический урон и зачарования оружия у немагических классов.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Magic Damage, магические splash/enchant интерпретации.",
		"format": "plain",
	},
	PERCEPTION: {
		"name_ru": "Восприятие",
		"name_en": "Perception",
		"type": "base",
		"description": "Влияет на дальность, радиус AoE, скорость снарядов и радиус подбора.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Attack Range, AoE Radius, Pickup Radius, Projectile Speed.",
		"format": "plain",
	},
	ENERGY: {
		"name_ru": "Энергия",
		"name_en": "Energy",
		"type": "base",
		"description": "Ускоряет уникальную механику класса и питает магические/звуковые параметры.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Magic Damage, Sound Wave Damage, class unique cooldown/charge timing.",
		"format": "plain",
	},
	KNOWLEDGE: {
		"name_ru": "Знание",
		"name_en": "Knowledge",
		"type": "base",
		"description": "Влияет на лечение, DoT, скорость тиков и регенерацию.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Regeneration, DoT Damage, DoT Speed.",
		"format": "plain",
	},
	ENDURANCE: {
		"name_ru": "Выносливость",
		"name_en": "Endurance",
		"type": "base",
		"description": "Влияет на HP, защиту и отталкивание.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "HealthPoint, Defense, Knockback Distance.",
		"format": "plain",
	},
	LEADERSHIP: {
		"name_ru": "Лидерство",
		"name_en": "Leadership",
		"type": "base",
		"description": "Влияет на количество и силу призывов, ауры и бафы.",
		"formula": "Базовая характеристика персонажа + награды характеристик.",
		"influences": "Summon Amount, Aura Radius, Buff Power, echo/familiar class interpretations.",
		"format": "plain",
	},
	"damage": {
		"name_ru": "Урон",
		"name_en": "Damage",
		"type": "derived",
		"description": "Текущий урон оружия до крита.",
		"formula": "(15 * Strength / 10) * weapon damage multiplier * run damage multiplier + flat damage.",
		"influences": "Strength, оружие, артефакты и награды на Damage.",
		"format": "decimal",
	},
	"magic_damage": {
		"name_ru": "Магический урон",
		"name_en": "Magic Damage",
		"type": "derived",
		"description": "Базовый урон темной магии до крита и эффектов оружия.",
		"formula": "(14 * Intelligence / 10 + Energy * 0.65) * weapon multiplier * run damage multiplier.",
		"influences": "Intelligence, Energy, оружие мага, артефакты и награды на Damage.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"sound_wave_damage": {
		"name_ru": "Урон звуком",
		"name_en": "Sound Wave Damage",
		"type": "derived",
		"description": "Базовый урон звуковых атак Гитариста.",
		"formula": "(12 * (Perception + Energy) / 12 + Leadership * 0.45) * weapon multiplier * run damage multiplier.",
		"influences": "Perception, Energy, Leadership, оружие Гитариста и награды на Damage.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"crit_chance": {
		"name_ru": "Шанс крита",
		"name_en": "Crit Chance",
		"type": "derived",
		"description": "Вероятность нанести критический удар.",
		"formula": "clamp(5% + Agility / 100 + flat crit chance, 0%, 80%).",
		"influences": "Agility и награды на Crit Chance.",
		"format": "percent",
	},
	"crit_damage_multiplier": {
		"name_ru": "Сила крита",
		"name_en": "Crit Damage Multiplier",
		"type": "derived",
		"description": "Множитель урона при критическом ударе.",
		"formula": "1 + 2 * Agility / 20 + flat crit damage.",
		"influences": "Agility и награды на Crit Damage.",
		"format": "multiplier",
	},
	"attack_speed": {
		"name_ru": "Скорость атаки",
		"name_en": "Attack Speed",
		"type": "derived",
		"description": "Количество атак в секунду. Cooldown оружия пересчитывается от этого значения.",
		"formula": "max(0.1, (9 * 3 * Agility / 100) * attack speed multiplier).",
		"influences": "Agility и награды на Attack Speed.",
		"format": "per_second",
	},
	"dodge": {
		"name_ru": "Уворот",
		"name_en": "Dodge",
		"type": "derived",
		"description": "Шанс избежать входящего урона. Сейчас зарезервирован для защитной системы.",
		"formula": "clamp(2% + Agility * 1.2% + flat dodge, 0%, 80%).",
		"influences": "Agility и награды на Dodge.",
		"format": "percent",
	},
	"move_speed": {
		"name_ru": "Скорость движения",
		"name_en": "Move Speed",
		"type": "derived",
		"description": "Скорость перемещения персонажа.",
		"formula": "(245 + Agility * 5.5) * move speed multiplier.",
		"influences": "Agility и награды на Move Speed.",
		"format": "units",
	},
	"defense": {
		"name_ru": "Защита",
		"name_en": "Defense",
		"type": "derived",
		"description": "Снижает входящий урон.",
		"formula": "clamp(4% + Endurance * 1.8% + flat defense, 0%, 75%).",
		"influences": "Endurance и награды на Defense.",
		"format": "percent",
	},
	"absorb": {
		"name_ru": "Поглощение",
		"name_en": "Absorb",
		"type": "derived",
		"description": "Плоское поглощение перед основным уроном.",
		"formula": "Endurance * 0.25 + награды. Плоско срезает входящий удар до защиты (минимум 20% урона проходит).",
		"influences": "Endurance, предметы и защитные эффекты.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"health_point": {
		"name_ru": "Макс HP",
		"name_en": "HealthPoint",
		"type": "derived",
		"description": "Максимальное здоровье персонажа.",
		"formula": "(50 * Endurance / 4 + flat max HP) * max health multiplier.",
		"influences": "Endurance и награды на Max HP.",
		"format": "integer",
	},
	"knockback_distance": {
		"name_ru": "Отталкивание",
		"name_en": "Knockback Distance",
		"type": "derived",
		"description": "Дистанция отталкивания врагов. Пока не подключено.",
		"formula": "Knockback Power * Endurance / 20 — отображаемая дальность отталкивания; в бою действует Knockback Power.",
		"influences": "Endurance и будущие оружейные эффекты.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"summon_amount": {
		"name_ru": "Количество призывов",
		"name_en": "Summon Amount",
		"type": "derived",
		"description": "Потенциал количества призванных существ.",
		"formula": "Leadership + summon bonus.",
		"influences": "Leadership и награды на призывы.",
		"format": "integer",
	},
	"attack_range": {
		"name_ru": "Дальность атаки",
		"name_en": "Attack Range",
		"type": "derived",
		"description": "Дальность текущей атаки/оружия.",
		"formula": "(weapon attack range + Perception * 2.5) * range multiplier.",
		"influences": "Perception, оружие и Range Multiplier.",
		"format": "units",
	},
	"range_multiplier": {
		"name_ru": "Множитель дальности",
		"name_en": "Range Multiplier",
		"type": "derived",
		"description": "Множитель дальности атак. Сейчас хранится как run modifier.",
		"formula": "run range multiplier. Если наград нет, значение 100%.",
		"influences": "Награды и артефакты на дальность.",
		"format": "percent_from_one",
		"default_value": 1.0,
	},
	"regeneration": {
		"name_ru": "Регенерация",
		"name_en": "Regeneration",
		"type": "derived",
		"description": "Восстановление здоровья со временем. Пока не подключено.",
		"formula": "(0.3 + награды) * Knowledge / 5 — HP в секунду, лечит постоянно.",
		"influences": "Knowledge, Energy и будущие healing-эффекты.",
		"format": "per_second",
		"default_value": 0.0,
	},
	"vampiric_amount": {
		"name_ru": "Вампиризм",
		"name_en": "Vampiric Amount",
		"type": "derived",
		"description": "Количество лечения от вампирического эффекта. Пока не подключено.",
		"formula": "Награды + половина нанесенного урона; лечит при ударе с шансом Vampiric Chance.",
		"influences": "Energy, текущий урон и будущие предметы.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"vampiric_chance": {
		"name_ru": "Шанс вампиризма",
		"name_en": "Vampiric Chance",
		"type": "derived",
		"description": "Шанс срабатывания вампиризма. Пока не подключено.",
		"formula": "Endurance * 0.25 + награды. Плоско срезает входящий удар до защиты (минимум 20% урона проходит).",
		"influences": "Energy, Knowledge и будущие предметы.",
		"format": "percent",
		"default_value": 0.0,
	},
	"dot_damage": {
		"name_ru": "DoT урон",
		"name_en": "DoT Damage",
		"type": "derived",
		"description": "Урон периодических эффектов. Пока не подключено.",
		"formula": "(Default + Addition) * Knowledge / 10. Формула пока не подключена к бою.",
		"influences": "Knowledge и будущие яды/горение.",
		"format": "decimal",
		"default_value": 0.0,
	},
	"dot_speed": {
		"name_ru": "Скорость DoT",
		"name_en": "DoT Speed",
		"type": "derived",
		"description": "Частота тиков периодического урона. Пока не подключено.",
		"formula": "(Default + Addition) * 3 * Knowledge / 100. Формула пока не подключена к бою.",
		"influences": "Knowledge и будущие DoT-эффекты.",
		"format": "per_second",
		"default_value": 0.0,
	},
	"aoe_radius": {
		"name_ru": "Радиус AoE",
		"name_en": "AoE Radius",
		"type": "derived",
		"description": "Радиус или ширина area-атак.",
		"formula": "(weapon AoE radius + Perception * 3.5) * AoE radius multiplier.",
		"influences": "Perception, оружие и награды на AoE.",
		"format": "units",
	},
	"aura_radius": {
		"name_ru": "Радиус ауры",
		"name_en": "Aura Radius",
		"type": "derived",
		"description": "Радиус аур, усилителей и пульсовых эффектов.",
		"formula": "(weapon AoE radius + Leadership * 5) * AoE radius multiplier.",
		"influences": "Leadership, Perception, оружие и AoE-награды.",
		"format": "units",
		"default_value": 0.0,
	},
	"buff_power": {
		"name_ru": "Сила бафа",
		"name_en": "Buff Power",
		"type": "derived",
		"description": "Сила будущих бафов, аур и командных эффектов.",
		"formula": "1 + Leadership * 0.025.",
		"influences": "Leadership и будущие предметы/ауры.",
		"format": "multiplier",
		"default_value": 1.0,
	},
	"knockback_power": {
		"name_ru": "Сила отталкивания",
		"name_en": "Knockback Power",
		"type": "derived",
		"description": "Сила отталкивания от баса, волн и тяжелых ударов.",
		"formula": "(weapon knockback + Endurance * 4 + Leadership * 3) * knockback multiplier.",
		"influences": "Endurance, Leadership, оружие и награды на Knockback.",
		"format": "units",
		"default_value": 0.0,
	},
	"projectile_speed": {
		"name_ru": "Скорость снарядов",
		"name_en": "Projectile Speed",
		"type": "derived",
		"description": "Скорость снарядов. Для Берсерка обычно не используется.",
		"formula": "Default * Perception + Addition. Формула пока не подключена к текущему оружию.",
		"influences": "Perception и ranged-оружие.",
		"format": "units",
		"default_value": 0.0,
	},
	"ultimate_multiplier": {
		"name_ru": "Сила ульты",
		"name_en": "Ultimate Multiplier",
		"type": "derived",
		"description": "Множитель силы ultimate-умения. Пока не подключено.",
		"formula": "1.0 + Energy * 0.02 + награды. Зарезервировано: ультимейтов в игре пока нет.",
		"influences": "Будущие ultimate-награды и предметы.",
		"format": "multiplier",
		"default_value": 1.0,
	},
	"pickup_radius": {
		"name_ru": "Радиус подбора",
		"name_en": "Pickup Radius",
		"type": "derived",
		"description": "Расстояние, на котором XP и деньги притягиваются к игроку.",
		"formula": "105 + Perception * 7 + flat pickup radius.",
		"influences": "Perception и награды на Pickup Radius.",
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
	return (default_damage + addition) * float(stats.get(STRENGTH, 1.0)) / 10.0


static func crit_chance(stats: Dictionary, default_chance: float, addition := 0.0) -> float:
	return clamp(default_chance + addition + float(stats.get(AGILITY, 0.0)) / 100.0, 0.0, 1.0)


static func crit_damage_multiplier(stats: Dictionary, default_multiplier: float, addition := 0.0) -> float:
	return 1.0 + (default_multiplier + addition) * float(stats.get(AGILITY, 0.0)) / 20.0


static func attack_speed(stats: Dictionary, default_hits_per_second: float, addition := 0.0) -> float:
	return max(0.1, (default_hits_per_second + addition) * 3.0 * float(stats.get(AGILITY, 0.0)) / 100.0)


static func dodge(stats: Dictionary, default_dodge: float, addition := 0.0) -> float:
	return clamp(default_dodge * float(stats.get(AGILITY, 0.0)) / 10.0 + addition, 0.0, 0.8)


static func move_speed(default_speed: float, stats: Dictionary, addition := 0.0) -> float:
	return default_speed + addition + float(stats.get(AGILITY, 0.0))


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
