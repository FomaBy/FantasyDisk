extends RefCounted

# SCRUM-198: ascension difficulty and per-class ascension reward data. ProgressionData remains the facade.

# SCRUM-516: лестница возвышений сжата с 10 до 5 ступеней, монстерский пресс
# заметно усилен. Прежние 10 «тонких» шагов свёрнуты в 5 «толстых», каждый из
# которых — ощутимый скачок угрозы. Все прежние рычаги сложности сохранены
# (enemy_hp/damage, price, spawn, elite, reward, healing, round_duration, boss*,
# player_max_hp, first_wave, mini_elite), но эскалация монстров круче: кумулятив
# enemy_hp_mult на новом L5 = 1.80 (было 1.32 на L10), enemy_damage_mult = 1.66
# (было 1.28). Кривая остаётся монотонной (гейт ascension_curve_balance_test):
# обычные монстры держат пресс на верхах, mini_elite-«горб» вводится на L3 (пик)
# и спадает к L5 (≤ половины пика). Капстоун-усложнения (boss_extra_phase,
# player_max_hp_mult, first_wave_boost) — на верхних ступенях L4–L5.
const ASCENSION_MODIFIERS := [
	{"id": "asc_hardened_foes", "level": 1, "title": "Закалённые враги", "description": "Монстры: +25% HP и +18% урона. Все цены (магазин, докачка, reroll): +25%.",
		"mods": {"enemy_hp_mult": 1.25, "enemy_damage_mult": 1.18, "price_mult": 1.25}},
	{"id": "asc_swift_horde", "level": 2, "title": "Быстрая орда", "description": "Волны спавнятся чаще и плотнее (+30%); монстры ещё крепче (+15% HP, +10% урона).",
		"mods": {"enemy_hp_mult": 1.15, "enemy_damage_mult": 1.10, "spawn_count_mult": 1.30, "spawn_cooldown_mult": 0.78}},
	{"id": "asc_fierce_elites", "level": 3, "title": "Свирепые элитки", "description": "Элитки: +25% HP, боевая фаза сразу. В волнах появляются мини-элитки со свитой. Монстры +12% HP. Золото и опыт: -20%.",
		"mods": {"enemy_hp_mult": 1.12, "elite_hp_mult": 1.25, "elite_instant_phase": 1.0, "mini_elite_chance": 0.16, "reward_mult": 0.80}},
	{"id": "asc_long_watch", "level": 4, "title": "Истончённая вахта", "description": "Таймер боя +25%; всё лечение -32%; монстры +12% HP и +12% урона; мини-элиток меньше.",
		"mods": {"enemy_hp_mult": 1.12, "enemy_damage_mult": 1.12, "healing_mult": 0.68, "round_duration_mult": 1.25, "mini_elite_chance": -0.05}},
	{"id": "asc_edge_of_madness", "level": 5, "title": "Грань безумия", "description": "Босс: +1 опасная фаза, +30% HP, телеграфы короче. Игрок: -20% макс. HP; стартовая волна усилена; монстры +14% урона; мини-элиток заметно меньше.",
		"mods": {"enemy_damage_mult": 1.14, "boss_hp_mult": 1.30, "boss_extra_phase": 1.0, "boss_telegraph_mult": 0.72, "player_max_hp_mult": 0.80, "first_wave_boost": 1.0, "mini_elite_chance": -0.08}},
]

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
	],
	"soldier": [
		{"id": "soldier_asc_1", "title": "Строевая Выучка", "mods": {"damage_multiplier": 1.05}},
		{"id": "soldier_asc_2", "title": "Плотный Мундир", "mods": {"max_health_flat": 8.0}},
		{"id": "soldier_asc_3", "title": "Быстрая Перезарядка", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "soldier_asc_4", "title": "Окопная Привычка", "mods": {"defense_flat": 0.02}},
		{"id": "soldier_asc_5", "title": "Пороховая Дисциплина", "mods": {"damage_multiplier": 1.07}},
	],
	"thief": [
		{"id": "thief_asc_1", "title": "Легкие Пальцы", "mods": {"damage_multiplier": 1.05}},
		{"id": "thief_asc_2", "title": "Запасной Кинжал", "mods": {"max_health_flat": 7.0}},
		{"id": "thief_asc_3", "title": "Быстрая Рука", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "thief_asc_4", "title": "Уход в Тень", "mods": {"dodge_flat": 0.02}},
		{"id": "thief_asc_5", "title": "Сорванный Кошель", "mods": {"money_gain_multiplier": 1.06}},
	],
	"elementalist": [
		{"id": "elementalist_asc_1", "title": "Искра Первостихии", "mods": {"damage_multiplier": 1.05}},
		{"id": "elementalist_asc_2", "title": "Кожух Пепла", "mods": {"max_health_flat": 6.0}},
		{"id": "elementalist_asc_3", "title": "Быстрый Поток", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "elementalist_asc_4", "title": "Широкая Мандала", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "elementalist_asc_5", "title": "Раскаленное Ядро", "mods": {"damage_multiplier": 1.07}},
	],
	"sniper": [
		{"id": "sniper_asc_1", "title": "Холодная Мушка", "mods": {"damage_multiplier": 1.05}},
		{"id": "sniper_asc_2", "title": "Запасной Плащ", "mods": {"max_health_flat": 8.0}},
		{"id": "sniper_asc_3", "title": "Сухой Спуск", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "sniper_asc_4", "title": "Широкий Глаз", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "sniper_asc_5", "title": "Бронебойный Заряд", "mods": {"damage_multiplier": 1.07}},
	],
	"priest": [
		{"id": "priest_asc_1", "title": "Тихая Литания", "mods": {"damage_multiplier": 1.04}},
		{"id": "priest_asc_2", "title": "Теплый Плащ", "mods": {"max_health_flat": 8.0}},
		{"id": "priest_asc_3", "title": "Быстрая Молитва", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "priest_asc_4", "title": "Широкий Круг", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "priest_asc_5", "title": "Священная Формула", "mods": {"damage_multiplier": 1.06}},
	],
	"biologist": [
		{"id": "biologist_asc_1", "title": "Чистая Культура", "mods": {"damage_multiplier": 1.04}},
		{"id": "biologist_asc_2", "title": "Плотная Мембрана", "mods": {"max_health_flat": 7.0}},
		{"id": "biologist_asc_3", "title": "Быстрый Анализ", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "biologist_asc_4", "title": "Широкий Посев", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "biologist_asc_5", "title": "Сильный Реагент", "mods": {"damage_multiplier": 1.07}},
	],
	"robot": [
		{"id": "robot_asc_1", "title": "Смазанные Шестерни", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "robot_asc_2", "title": "Толстый Корпус", "mods": {"max_health_flat": 10.0}},
		{"id": "robot_asc_3", "title": "Магнитная Обмотка", "mods": {"aoe_radius_multiplier": 1.04}},
		{"id": "robot_asc_4", "title": "Усиленный Сервопривод", "mods": {"damage_multiplier": 1.05}},
		{"id": "robot_asc_5", "title": "Пластинчатая Броня", "mods": {"defense_flat": 0.025}},
	],
	"engineer": [
		{"id": "engineer_asc_1", "title": "Быстрая Сборка", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "engineer_asc_2", "title": "Запасные Пластины", "mods": {"max_health_flat": 8.0}},
		{"id": "engineer_asc_3", "title": "Дополнительный Модуль", "mods": {"summon_bonus": 1.0}},
		{"id": "engineer_asc_4", "title": "Широкая Разметка", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "engineer_asc_5", "title": "Усиленный Привод", "mods": {"damage_multiplier": 1.06}},
	],
	"dark_mage": [
		{"id": "dark_mage_asc_1", "title": "Темный фокус", "mods": {"damage_multiplier": 1.05}},
		{"id": "dark_mage_asc_2", "title": "Пелена пустоты", "mods": {"max_health_flat": 6.0}},
		{"id": "dark_mage_asc_3", "title": "Расширение разлома", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "dark_mage_asc_4", "title": "Скороговорка заклятий", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "dark_mage_asc_5", "title": "Глубинная магия", "mods": {"damage_multiplier": 1.07}},
	],
	"guitarist": [
		{"id": "guitarist_asc_1", "title": "Чистый звук", "mods": {"damage_multiplier": 1.05}},
		{"id": "guitarist_asc_2", "title": "Сценическая выдержка", "mods": {"max_health_flat": 7.0}},
		{"id": "guitarist_asc_3", "title": "Широкий резонанс", "mods": {"aoe_radius_multiplier": 1.05}},
		{"id": "guitarist_asc_4", "title": "Быстрый перебор", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "guitarist_asc_5", "title": "Мощный рифф", "mods": {"damage_multiplier": 1.07}},
	],
	"assassin": [
		{"id": "assassin_asc_1", "title": "Первая Кровь", "mods": {"damage_multiplier": 1.05}},
		{"id": "assassin_asc_2", "title": "Тихий Шаг", "mods": {"max_health_flat": 8.0}},
		{"id": "assassin_asc_3", "title": "Острие Ночи", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "assassin_asc_4", "title": "Холодный Расчет", "mods": {"defense_flat": 0.02}},
		{"id": "assassin_asc_5", "title": "Двойной Росчерк", "mods": {"damage_multiplier": 1.07}},
	],
	"ranger": [
		{"id": "ranger_asc_1", "title": "Верный Прицел", "mods": {"damage_multiplier": 1.05}},
		{"id": "ranger_asc_2", "title": "Длинный Выдох", "mods": {"max_health_flat": 8.0}},
		{"id": "ranger_asc_3", "title": "Лунная Тетива", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "ranger_asc_4", "title": "Зоркость", "mods": {"defense_flat": 0.02}},
		{"id": "ranger_asc_5", "title": "Тяжелый Болт", "mods": {"damage_multiplier": 1.07}},
	],
	"doctor": [
		{"id": "doctor_asc_1", "title": "Полевые Швы", "mods": {"damage_multiplier": 1.05}},
		{"id": "doctor_asc_2", "title": "Крепкий Настой", "mods": {"max_health_flat": 8.0}},
		{"id": "doctor_asc_3", "title": "Чистые Руки", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "doctor_asc_4", "title": "Горький Тоник", "mods": {"defense_flat": 0.02}},
		{"id": "doctor_asc_5", "title": "Вторая Доза", "mods": {"damage_multiplier": 1.07}},
	],
	"chemist": [
		{"id": "chemist_asc_1", "title": "Едкая Смесь", "mods": {"damage_multiplier": 1.05}},
		{"id": "chemist_asc_2", "title": "Колба Праха", "mods": {"max_health_flat": 8.0}},
		{"id": "chemist_asc_3", "title": "Летучий Реагент", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "chemist_asc_4", "title": "Кислотный След", "mods": {"defense_flat": 0.02}},
		{"id": "chemist_asc_5", "title": "Нестабильный Состав", "mods": {"damage_multiplier": 1.07}},
	],
	"knight": [
		{"id": "knight_asc_1", "title": "Крепкий Щит", "mods": {"damage_multiplier": 1.05}},
		{"id": "knight_asc_2", "title": "Тяжелый Шаг", "mods": {"max_health_flat": 8.0}},
		{"id": "knight_asc_3", "title": "Несгибаемость", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "knight_asc_4", "title": "Клятва Стали", "mods": {"defense_flat": 0.02}},
		{"id": "knight_asc_5", "title": "Башня", "mods": {"damage_multiplier": 1.07}},
	],
	"druid": [
		{"id": "druid_asc_1", "title": "Зов Чащи", "mods": {"damage_multiplier": 1.05}},
		{"id": "druid_asc_2", "title": "Первый Зверь", "mods": {"max_health_flat": 8.0}},
		{"id": "druid_asc_3", "title": "Дикий Союз", "mods": {"attack_speed_multiplier": 1.04}},
		{"id": "druid_asc_4", "title": "Корни Силы", "mods": {"defense_flat": 0.02}},
		{"id": "druid_asc_5", "title": "Стая", "mods": {"damage_multiplier": 1.07}},
	],
}
