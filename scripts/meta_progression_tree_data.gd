extends RefCounted

# SCRUM-828 — Мета 4.0 «Созвездия героев» (дизайн: docs/design/systems/
# meta_constellations.md). Этот модуль хранит ДАННЫЕ и сборщик графа меты:
#   • 17 персональных созвездий классов (по 22 узла: ядро-эмблема 0-cost,
#     12 звёзд-атрибутов cost 1, 4 звезды-техники cost 2, 3 взаимоисключающих
#     keystone cost 4 с числовым downside, 2 скрытые звезды на challenge-условиях);
#   • «Атлас гильдии» — общий QoL-слой ~24 узла (валюта — звёздная пыль),
#     боевой силы почти не несёт (4 наследных keystone v2 — отдельный бюджет);
#   • реестр значений звёзд-атрибутов (STAR_ATTRS), веса силы (POWER_WEIGHTS)
#     для бюджет-гейта +18–25%, RU-подписи эффектов (EFFECT_LABELS/FLAG_DESC).
#
# Публичный API meta_progression.gd (node_list/allocate_node/skill_modifiers*/
# entry_map) сохраняет формат узла {id,branch,tier,cost,kind,title,desc,effects,
# pos,adj,class_affinity?} + новые поля Меты 4.0: role, npos (нормализованная
# позиция 0..1 по силуэту приложения C), exclusive_group (keystone-группа класса),
# condition/lore (скрытые звезды). Ключи эффектов — ТОЛЬКО разведённые в player.gd
# (META_SKILL_*_MAP) или в main/ui (экономические) — иначе эффект молча теряется
# (гейт в tests/meta_skill_tree_smoke_test.gd).

# --- Реестр звёзд-атрибутов (значение минорной звезды подобрано под бюджет ---
# силы: value × POWER_WEIGHTS[key] ≈ 0.008 damage-mult-эквивалента на звезду).
const STAR_ATTRS := {
	"damage": {"key": "damage_mult", "value": 0.008, "short": "Урон", "ru": "к урону", "pct": true},
	"attack_speed": {"key": "attack_speed_mult", "value": 0.008, "short": "Скорость атаки", "ru": "к скорости атаки", "pct": true},
	"max_health": {"key": "max_health_mult", "value": 0.008, "short": "Живучесть", "ru": "к макс. здоровью", "pct": true},
	"move_speed": {"key": "move_speed_mult", "value": 0.01, "short": "Скорость", "ru": "к скорости движения", "pct": true},
	"aoe_radius": {"key": "aoe_radius_mult", "value": 0.013, "short": "Область", "ru": "к радиусу области", "pct": true},
	"pickup_radius": {"key": "pickup_radius_flat", "value": 5.0, "short": "Подбор", "ru": "к радиусу подбора", "pct": false},
	"defense": {"key": "defense_flat", "value": 0.004, "short": "Защита", "ru": "к защите", "pct": true},
	"knockback": {"key": "knockback_mult", "value": 0.02, "short": "Отталкивание", "ru": "к отталкиванию", "pct": true},
	"crit_chance": {"key": "crit_chance_flat", "value": 0.004, "short": "Шанс крита", "ru": "к шансу крита", "pct": true},
	"crit_damage": {"key": "crit_damage_flat", "value": 0.021, "short": "Урон крита", "ru": "к урону крита", "pct": true},
	"dodge": {"key": "dodge_flat", "value": 0.003, "short": "Уклонение", "ru": "к уклонению", "pct": true},
	"range": {"key": "range_mult", "value": 0.01, "short": "Дальность", "ru": "к дальности атаки", "pct": true},
	"dot_damage": {"key": "dot_damage_flat", "value": 0.21, "short": "Периодический урон", "ru": "периодического урона", "pct": false},
	"dot_speed": {"key": "dot_speed_flat", "value": 0.013, "short": "Скорость тиков", "ru": "к скорости тиков", "pct": false},
	"projectile_speed": {"key": "projectile_speed_flat", "value": 7.0, "short": "Снаряды", "ru": "к скорости снарядов", "pct": false},
	"aura_radius": {"key": "aura_radius_flat", "value": 2.0, "short": "Аура", "ru": "к радиусу ауры", "pct": false},
	"buff_power": {"key": "buff_power_flat", "value": 0.006, "short": "Поддержка", "ru": "к силе поддержки", "pct": true},
	"summon_amount": {"key": "summon_bonus", "value": 0.13, "short": "Призыв", "ru": "к силе призыва", "pct": false},
	"absorb": {"key": "absorb_flat", "value": 0.5, "short": "Поглощение", "ru": "к поглощению", "pct": false},
	"regeneration": {"key": "regeneration_flat", "value": 0.023, "short": "Регенерация", "ru": "к регенерации", "pct": false},
	"vampiric_amount": {"key": "vampiric_amount_flat", "value": 0.1, "short": "Вампиризм", "ru": "к лечению вампиризмом", "pct": false},
	"vampiric_chance": {"key": "vampiric_chance_flat", "value": 0.006, "short": "Шанс вампиризма", "ru": "к шансу вампиризма", "pct": true},
	"ultimate_power": {"key": "ultimate_flat", "value": 0.011, "short": "Ультимейт", "ru": "к силе ультимейта", "pct": true},
}

# --- Веса силы: damage-mult-эквивалент единицы значения ключа. Используются ---
# meta_progression.estimated_class_power_multiplier и бюджет-гейтом §6 дизайна
# (полный билд класса = +18..25%, спред по классам ≤1.25). Экономические ключи
# намеренно весят 0 (Атлас не несёт боевой силы).
const POWER_WEIGHTS := {
	"damage_mult": 1.0, "attack_speed_mult": 1.0, "max_health_mult": 1.0,
	"move_speed_mult": 0.8, "aoe_radius_mult": 0.6, "pickup_radius_flat": 0.0015,
	"defense_flat": 2.0, "knockback_mult": 0.4, "crit_chance_flat": 2.0,
	"crit_damage_flat": 0.375, "dodge_flat": 3.0, "range_mult": 0.8,
	"dot_damage_flat": 0.0375, "dot_speed_flat": 0.6, "projectile_speed_flat": 0.0011,
	"aura_radius_flat": 0.004, "aura_radius_mult": 0.6, "buff_power_flat": 1.25,
	"summon_bonus": 0.06, "absorb_flat": 0.015, "regeneration_flat": 0.35,
	"vampiric_amount_flat": 0.08, "vampiric_chance_flat": 1.4, "ultimate_flat": 0.75,
	"ult_charge_mult": 0.5, "elite_boss_damage_mult": 0.5,
	"low_hp_damage_bonus": 0.25, "lowhp_regen_bonus": 0.05, "healing_mult": 0.15,
	"kill_explosion_chance": 0.5, "take_hit_pulse_chance": 0.5,
	"thorn_reflect_multiplier": 0.2, "crit_speed_burst": 0.3, "dodge_rush_bonus": 0.3,
	"lowhp_guard": 0.02, "death_save": 0.03, "ult_start_charge": 0.02,
	# SCRUM-834 (Мета 4.1): условные keystone — бонус урона по типу условия. Вес =
	# средняя доля времени активности (аптайм) × вес damage_mult (1.0): «пока ранен»
	# HP<50% ≈0.30, «в стойке» неподвижность ≥0.8с ≈0.45, «в рывке» окно после
	# уклонения ≈0.25, «в гуще боя» доля врагов рядом от кэпа ≈0.50. Так крупный
	# заголовочный процент keystone держит узкий budget-вклад (§6, спред ≤1.25).
	"hurt_damage_bonus": 0.30, "stance_damage_bonus": 0.45,
	"rush_damage_bonus": 0.25, "swarm_damage_bonus": 0.50,
	# SCRUM-834a: условные keystone на тех же гейтах, но с не-урон стат-целью. Вес =
	# аптайм гейта × вес самой стат-цели. stance(≈0.45)×attack_speed_mult(1.0)=0.45;
	# rush(≈0.25)×crit_chance_flat(2.0)=0.50. Budget-нейтрально к прежним *_damage.
	"stance_attack_speed_bonus": 0.45, "rush_crit_bonus": 0.50,
	# SCRUM-835 (Мета 4.1b): semantic combat subsystem keys. Positive downside
	# values (incoming damage, charge time) use negative weights so
	# power budget and downside gates read the signed contribution.
	"enemy_hit_damage_down": 0.80,
	"gold_damage_per_50": 0.0, "gold_damage_bonus_cap": 0.20,
	"elemental_resonance_bonus": 0.47, "elemental_orb_extra_count": 0.065,
	"prism_rift_radius_mult": 0.40,
	"heal_to_holy_damage_ratio": 0.18, "ward_absorb_bonus": 0.32,
	"reactor_heat_damage_bonus": 0.37, "reactor_heat_incoming_damage": -0.45,
	"magnet_radius_mult": 0.33,
	"device_attack_speed_bonus": 0.45, "non_device_damage_mult": 0.35,
	"mine_extra_count": 0.06,
	"dot_death_spread_duration": 0.055, "direct_damage_mult": 0.45,
	"beam_duration_mult": 0.30, "explosion_radius_mult": 0.25,
	"guitar_aura_radius_mult": 0.80, "riff_streak_damage_bonus": 0.58,
	"crit_execute_threshold": 0.70, "shadow_burst_invisibility_time": 0.095,
	"charged_shot_extra_pierce": 0.048, "charge_time_mult": -0.25,
	"trap_extra_count": 0.045, "non_trap_damage_mult": 0.35,
	"drain_extra_targets": 0.105, "medkit_healing_mult": 0.15,
	"surgical_close_damage_bonus": 0.18, "ranged_damage_mult": 0.35,
	"cloud_detonation_radius_mult": 0.25, "pool_duration_mult": 0.20,
	"homunculus_power_mult": 0.30,
	"pet_damage_mult": 0.35, "pet_personal_damage_mult": 0.35,
	"briar_radius_mult": 0.36,
	"bastion_defense_bonus": 0.60, "bastion_taunt": 0.015,
	"strength_flat": 0.008, "agility_flat": 0.008, "intelligence_flat": 0.008,
	"perception_flat": 0.008, "energy_flat": 0.008, "knowledge_flat": 0.008,
	"endurance_flat": 0.008, "leadership_flat": 0.008,
	"xp_gain_mult": 0.0, "money_gain_mult": 0.0, "shop_price_mult": 0.0,
	"attr_cost_mult": 0.0, "start_gold_flat": 0.0, "attr_extra_options": 0.0,
	"guaranteed_rare_shop": 0.0, "first_levelup_rare": 0.0,
}

# --- RU-подписи для авто-описаний с числами (узлы обязаны читаться без токенов) ---
const EFFECT_LABELS := {
	"damage_mult": {"ru": "к урону", "pct": true},
	"attack_speed_mult": {"ru": "к скорости атаки", "pct": true},
	"max_health_mult": {"ru": "к макс. здоровью", "pct": true},
	"move_speed_mult": {"ru": "к скорости движения", "pct": true},
	"aoe_radius_mult": {"ru": "к радиусу области", "pct": true},
	"aura_radius_mult": {"ru": "к радиусу ауры", "pct": true},
	"range_mult": {"ru": "к дальности атаки", "pct": true},
	"knockback_mult": {"ru": "к отталкиванию", "pct": true},
	"ult_charge_mult": {"ru": "к скорости заряда ультимейта", "pct": true},
	"elite_boss_damage_mult": {"ru": "к урону по элиткам и боссам", "pct": true},
	"money_gain_mult": {"ru": "к добыче золота", "pct": true},
	"xp_gain_mult": {"ru": "к получаемому опыту", "pct": true},
	"shop_price_mult": {"ru": "к ценам лавки", "pct": true},
	"attr_cost_mult": {"ru": "к цене докачки атрибутов", "pct": true},
	"healing_mult": {"ru": "к получаемому лечению", "pct": true},
	"defense_flat": {"ru": "к защите", "pct": true},
	"dodge_flat": {"ru": "к уклонению", "pct": true},
	"crit_chance_flat": {"ru": "к шансу крита", "pct": true},
	"crit_damage_flat": {"ru": "к урону крита", "pct": true},
	"vampiric_chance_flat": {"ru": "к шансу вампиризма", "pct": true},
	"buff_power_flat": {"ru": "к силе поддержки", "pct": true},
	"ultimate_flat": {"ru": "к силе ультимейта", "pct": true},
	"low_hp_damage_bonus": {"ru": "к урону при низком здоровье", "pct": true},
	"kill_explosion_chance": {"ru": "шанс взрыва при убийстве", "pct": true},
	"take_hit_pulse_chance": {"ru": "шанс ответной волны при получении удара", "pct": true},
	"thorn_reflect_multiplier": {"ru": "полученного урона отражается шипами", "pct": true},
	"crit_speed_burst": {"ru": "к скорости движения после крита (короткий рывок)", "pct": true},
	"dodge_rush_bonus": {"ru": "к скорости движения после уклонения (рывок)", "pct": true},
	# SCRUM-834 (Мета 4.1): условные keystone-бонусы урона (гейт ставит player.gd).
	"hurt_damage_bonus": {"ru": "к урону, пока здоровье ниже половины", "pct": true},
	"stance_damage_bonus": {"ru": "к урону в неподвижной боевой стойке", "pct": true},
	"rush_damage_bonus": {"ru": "к урону в рывке (окно после уклонения)", "pct": true},
	"swarm_damage_bonus": {"ru": "к урону в гуще боя (на пике — врагов рядом)", "pct": true},
	# SCRUM-834a: условные keystone на существующих гейтах, не-урон стат-цель.
	"stance_attack_speed_bonus": {"ru": "к скорострельности в неподвижной боевой стойке", "pct": true},
	"rush_crit_bonus": {"ru": "к шансу крита в рывке (окно после уклонения)", "pct": true},
	# SCRUM-835: semantic keystone effects for new combat subsystems.
	"enemy_hit_damage_down": {"ru": "меньше урона от врагов, поражённых за последние 2 сек.", "pct": true},
	"gold_damage_per_50": {"ru": "к урону за каждые 50 золота", "pct": true},
	"gold_damage_bonus_cap": {"ru": "предел бонуса урона от золота", "pct": true},
	"elemental_resonance_bonus": {"ru": "к урону другой стихией по отмеченной цели", "pct": true},
	"elemental_orb_extra_count": {"ru": "дополнительных стихийных орб", "pct": false},
	"prism_rift_radius_mult": {"ru": "к радиусу призматического разлома", "pct": true},
	"heal_to_holy_damage_ratio": {"ru": "исходящего лечения превращается в святую цепь урона", "pct": true},
	"ward_absorb_bonus": {"ru": "к поглощению ward-волн", "pct": true},
	"reactor_heat_damage_bonus": {"ru": "к урону при жаре реактора выше 70%", "pct": true},
	"reactor_heat_incoming_damage": {"ru": "входящего урона при перегреве реактора", "pct": true},
	"magnet_radius_mult": {"ru": "к радиусу магнитного якоря", "pct": true},
	"device_attack_speed_bonus": {"ru": "к темпу устройств", "pct": true},
	"non_device_damage_mult": {"ru": "к личному урону вне устройств", "pct": true},
	"mine_extra_count": {"ru": "дополнительных мин", "pct": false},
	"dot_death_spread_duration": {"ru": "сек. продления DoT вокруг погибшей проклятой цели", "pct": false},
	"direct_damage_mult": {"ru": "к прямому урону", "pct": true},
	"beam_duration_mult": {"ru": "к длительности лучей", "pct": true},
	"explosion_radius_mult": {"ru": "к радиусу взрывов луча", "pct": true},
	"guitar_aura_radius_mult": {"ru": "к ширине магических аур Гитариста", "pct": true},  # SCRUM-899: магическая идентичность
	"riff_streak_damage_bonus": {"ru": "к урону при непрерывной рифф-серии", "pct": true},
	"crit_execute_threshold": {"ru": "порог добивания критом не-элитных целей", "pct": true},
	"shadow_burst_invisibility_time": {"ru": "сек. невидимости после теневого всплеска", "pct": false},
	"charged_shot_extra_pierce": {"ru": "пробития заряженным выстрелом", "pct": false},
	"charge_time_mult": {"ru": "к времени зарядки", "pct": true},
	"trap_extra_count": {"ru": "дополнительных капканов", "pct": false},
	"non_trap_damage_mult": {"ru": "к урону вне капканов", "pct": true},
	"drain_extra_targets": {"ru": "дополнительная цель drain-связи", "pct": false},
	"medkit_healing_mult": {"ru": "к лечению меднабора", "pct": true},
	"surgical_close_damage_bonus": {"ru": "к хирургическому удару в упор", "pct": true},
	"ranged_damage_mult": {"ru": "к дальнему урону", "pct": true},
	"cloud_detonation_radius_mult": {"ru": "к площади детонации облаков", "pct": true},
	"pool_duration_mult": {"ru": "к длительности луж и облаков", "pct": true},
	"homunculus_power_mult": {"ru": "к здоровью и урону гомункула", "pct": true},
	"pet_damage_mult": {"ru": "к урону питомцев", "pct": true},
	"pet_personal_damage_mult": {"ru": "к личному урону без питомцев и терний", "pct": true},
	"briar_radius_mult": {"ru": "к ширине терновых зон", "pct": true},
	"bastion_defense_bonus": {"ru": "к защите после 1 сек. стойки", "pct": true},
	"bastion_taunt": {"ru": "провокация врагов в стойке", "pct": false},
	"pickup_radius_flat": {"ru": "к радиусу подбора", "pct": false},
	"projectile_speed_flat": {"ru": "к скорости снарядов", "pct": false},
	"absorb_flat": {"ru": "к поглощению", "pct": false},
	"dot_damage_flat": {"ru": "периодического урона", "pct": false},
	"dot_speed_flat": {"ru": "к скорости тиков", "pct": false},
	"aura_radius_flat": {"ru": "к радиусу ауры", "pct": false},
	"summon_bonus": {"ru": "к силе призыва", "pct": false},
	"regeneration_flat": {"ru": "к регенерации", "pct": false},
	"vampiric_amount_flat": {"ru": "к лечению вампиризмом", "pct": false},
	"lowhp_regen_bonus": {"ru": "к регенерации при низком здоровье", "pct": false},
	"start_gold_flat": {"ru": "золота на старте забега", "pct": false},
	"strength_flat": {"ru": "к Силе", "pct": false},
	"agility_flat": {"ru": "к Ловкости", "pct": false},
	"intelligence_flat": {"ru": "к Интеллекту", "pct": false},
	"perception_flat": {"ru": "к Восприятию", "pct": false},
	"energy_flat": {"ru": "к Энергии", "pct": false},
	"knowledge_flat": {"ru": "к Знанию", "pct": false},
	"endurance_flat": {"ru": "к Стойкости", "pct": false},
	"leadership_flat": {"ru": "к Лидерству", "pct": false},
}

# Флаговые ключи описываются готовой фразой (не «+1 …»), мержатся через max().
const FLAG_DESC := {
	"death_save": "Раз за забег смертельный удар оставляет героя на ногах.",
	# SCRUM-963: канон редкости — гарантия капстоуна фактически tier 3 = «эпический».
	"guaranteed_rare_shop": "В каждой лавке гарантированно есть эпический товар.",
	"first_levelup_rare": "Первое повышение в забеге гарантированно даёт основную характеристику.",
	"ult_start_charge": "Ультимейт начинает забег заряженным наполовину.",
	"lowhp_guard": "Падение ниже 30% HP раз за порог поднимает щит-волну и даёт миг неуязвимости.",
	"attr_extra_options": "Докачка атрибутов предлагает на 1 вариант больше.",
}

# --- Базовый атрибут ядра-эмблемы (первый вкус класса без гринда, +1) ---
const CLASS_BASE_ATTRIBUTE := {
	"berserk": "strength_flat", "soldier": "perception_flat", "thief": "agility_flat",
	"elementalist": "intelligence_flat", "sniper": "perception_flat", "priest": "knowledge_flat",
	"biologist": "knowledge_flat", "robot": "endurance_flat", "engineer": "leadership_flat",
	"dark_mage": "intelligence_flat", "guitarist": "leadership_flat", "assassin": "agility_flat",
	"ranger": "perception_flat", "doctor": "knowledge_flat", "chemist": "knowledge_flat",
	"knight": "endurance_flat", "druid": "leadership_flat",
}

# Порядок классов = порядок на кольце старого экрана и в ленте Атласа героев.
const CLASS_ORDER := ["berserk", "soldier", "thief", "elementalist", "sniper", "priest", "biologist", "robot", "engineer", "dark_mage", "guitarist", "assassin", "ranger", "doctor", "chemist", "knight", "druid"]

# Раскладка минорных звёзд по лучам силуэта: 4 луча × 3 звезды из 6 профильных
# атрибутов класса (A..F, primary-first). Зеркальная схема читается как узор.
const RAY_ATTR_PATTERN := [[0, 1, 0], [2, 3, 2], [1, 4, 5], [3, 5, 4]]

# Условия скрытых звёзд созвездий строятся на инфраструктуре челленджей класса
# (class_challenge_progress): metric ∈ {weapon_diversity, best_ascension,
# no_shop_wins}; Атлас использует аккаунт-метрики {codex_milestones, secret_boss,
# achievement_milestones}. Текст условия генерится в _condition_text().

const CONSTELLATION_SPECS := {
	"berserk": {
		"core_title": "Сердце ярости",
		"attrs": ["damage", "knockback", "vampiric_amount", "max_health", "crit_damage", "move_speed"],
		"techniques": [
			{"title": "Широкий замах", "effects": {"damage_mult": 0.008, "knockback_mult": 0.02}},
			{"title": "Кровавый отбор", "effects": {"vampiric_amount_flat": 0.1, "vampiric_chance_flat": 0.006}},
			{"title": "Ярость толпы", "effects": {"take_hit_pulse_chance": 0.016, "max_health_mult": 0.008}},
			{"title": "Второе дыхание", "effects": {"lowhp_regen_bonus": 0.16, "regeneration_flat": 0.023}},
		],
		"keystones": [
			{"title": "Кровавый танец", "effects": {"hurt_damage_bonus": 0.32, "healing_mult": -0.3}},
			{"title": "Несущий бурю", "effects": {"swarm_damage_bonus": 0.18, "max_health_mult": -0.04}},
			{"title": "Последний рубеж", "effects": {"low_hp_damage_bonus": 0.29, "lowhp_regen_bonus": 0.4, "defense_flat": -0.022}},
		],
		"hidden": [
			{"title": "Клич предков", "effects": {"take_hit_pulse_chance": 0.04}, "lore": "Гнев рода живёт в каждом ударе, что ты принимаешь.", "metric": "weapon_diversity", "threshold": 2},
			{"title": "Неукротимый", "effects": {"lowhp_guard": 1.0}, "lore": "Того, кто вставал с колен на вершине, не сломить у подножия.", "metric": "best_ascension", "threshold": 2},
		],
	},
	"soldier": {
		"core_title": "Устав штурмовика",
		"attrs": ["damage", "attack_speed", "projectile_speed", "range", "crit_chance", "buff_power"],
		"techniques": [
			{"title": "Огневой рубеж", "effects": {"damage_mult": 0.008, "attack_speed_mult": 0.008}},
			{"title": "Пристрелка", "effects": {"range_mult": 0.01, "projectile_speed_flat": 7.0}},
			{"title": "Бронебойный расчёт", "effects": {"elite_boss_damage_mult": 0.016, "crit_chance_flat": 0.004}},
			{"title": "Полевая смекалка", "effects": {"buff_power_flat": 0.006, "max_health_mult": 0.008}},
		],
		"keystones": [
			{"title": "Подавление", "effects": {"enemy_hit_damage_down": 0.15, "move_speed_mult": -0.10}},
			{"title": "Шквал", "effects": {"stance_attack_speed_bonus": 0.191, "damage_mult": -0.04}},
			{"title": "Гранатный подсумок", "effects": {"aoe_radius_mult": 0.07, "kill_explosion_chance": 0.09, "range_mult": -0.06}},
		],
		"hidden": [
			{"title": "Окопная выучка", "effects": {"take_hit_pulse_chance": 0.04}, "lore": "Тот, кто держал рубеж всем арсеналом, бьёт в ответ без команды.", "metric": "weapon_diversity", "threshold": 3},
			{"title": "Ветеран высот", "effects": {"elite_boss_damage_mult": 0.04}, "lore": "Возвышения — та же высота: бери её штурмом.", "metric": "class_wins", "threshold": 8},
		],
	},
	"thief": {
		"core_title": "Первый куш",
		"attrs": ["move_speed", "crit_chance", "dodge", "damage", "pickup_radius", "crit_damage"],
		"techniques": [
			{"title": "Лёгкие пальцы", "effects": {"crit_chance_flat": 0.004, "move_speed_mult": 0.01}},
			{"title": "Дым и тень", "effects": {"dodge_flat": 0.003, "damage_mult": 0.008}},
			{"title": "Карманы без дна", "effects": {"pickup_radius_flat": 5.0, "crit_damage_flat": 0.021}},
			{"title": "Скользкий трюк", "effects": {"dodge_rush_bonus": 0.027, "move_speed_mult": 0.01}},
		],
		"keystones": [
			{"title": "Из тени", "effects": {"rush_crit_bonus": 0.172, "max_health_mult": -0.04}},
			{"title": "Джекпот", "effects": {"gold_damage_per_50": 0.01, "gold_damage_bonus_cap": 0.25, "shop_price_mult": 0.20}},
			{"title": "Азарт канатоходца", "effects": {"crit_damage_flat": 0.17, "dodge_rush_bonus": 0.09, "defense_flat": -0.022}},
		],
		"hidden": [
			{"title": "Отмычка судьбы", "effects": {"dodge_rush_bonus": 0.07}, "lore": "Каждый замок в городе знает эти руки.", "metric": "no_shop_wins", "threshold": 1},
			{"title": "Крыши столицы", "effects": {"crit_speed_burst": 0.07}, "lore": "Кто бегал по черепице над стражей, того не догнать и на земле.", "metric": "weapon_diversity", "threshold": 3},
		],
	},
	"elementalist": {
		"core_title": "Триада стихий",
		"attrs": ["aoe_radius", "ultimate_power", "damage", "range", "dot_damage", "move_speed"],
		"techniques": [
			{"title": "Разогретая формула", "effects": {"aoe_radius_mult": 0.013, "damage_mult": 0.008}},
			{"title": "Стихийный контур", "effects": {"ultimate_flat": 0.011, "dot_damage_flat": 0.21}},
			{"title": "Дальняя дуга", "effects": {"range_mult": 0.01, "move_speed_mult": 0.01}},
			{"title": "Пепел и искры", "effects": {"kill_explosion_chance": 0.016, "aoe_radius_mult": 0.013}},
		],
		"keystones": [
			{"title": "Резонанс", "effects": {"elemental_resonance_bonus": 0.35, "damage_mult": -0.12}},
			{"title": "Монолит", "effects": {"elemental_orb_extra_count": 2.0, "prism_rift_radius_mult": -0.20}},
			{"title": "Огонь по площади", "effects": {"kill_explosion_chance": 0.11, "dot_damage_flat": 1.0, "move_speed_mult": -0.06}},
		],
		"hidden": [
			{"title": "Резонанс стихий", "effects": {"kill_explosion_chance": 0.04}, "lore": "Три стихии спорят, чья вспышка ярче — выигрывает Диск.", "metric": "weapon_diversity", "threshold": 3},
			{"title": "Око бури", "effects": {"lowhp_guard": 1.0}, "lore": "В сердце шторма всегда тихо — стой там.", "metric": "best_ascension", "threshold": 3},
		],
	},
	"sniper": {
		"core_title": "Холодный расчёт",
		"attrs": ["crit_chance", "crit_damage", "range", "damage", "projectile_speed", "dodge"],
		"techniques": [
			{"title": "Спокойный выдох", "effects": {"crit_chance_flat": 0.004, "crit_damage_flat": 0.021}},
			{"title": "Дальний рубеж", "effects": {"range_mult": 0.01, "damage_mult": 0.008}},
			{"title": "Скоростная пуля", "effects": {"projectile_speed_flat": 7.0, "crit_chance_flat": 0.004}},
			{"title": "Отход с позиции", "effects": {"dodge_flat": 0.003, "move_speed_mult": 0.01}},
		],
		"keystones": [
			{"title": "Один выстрел", "effects": {"stance_damage_bonus": 0.2, "attack_speed_mult": -0.04}},
			{"title": "Свинцовый ветер", "effects": {"rush_damage_bonus": 0.345, "crit_damage_flat": -0.12}},
			{"title": "Гнездо ястреба", "effects": {"range_mult": 0.06, "crit_chance_flat": 0.02, "move_speed_mult": -0.06}},
		],
		"hidden": [
			{"title": "Метка охотника", "effects": {"crit_speed_burst": 0.07}, "lore": "Секунда после идеального выстрела принадлежит только тебе.", "metric": "best_ascension", "threshold": 3},
			{"title": "Выше облаков", "effects": {"elite_boss_damage_mult": 0.04}, "lore": "С вершины возвышения любая цель как на ладони.", "metric": "no_shop_wins", "threshold": 2},
		],
	},
	"priest": {
		"core_title": "Обет заступника",
		"attrs": ["defense", "aura_radius", "buff_power", "max_health", "regeneration", "summon_amount"],
		"techniques": [
			{"title": "Мягкий хор", "effects": {"aura_radius_flat": 2.0, "buff_power_flat": 0.006}},
			{"title": "Освящённый оплот", "effects": {"defense_flat": 0.004, "regeneration_flat": 0.023}},
			{"title": "Глас утешения", "effects": {"max_health_mult": 0.008, "buff_power_flat": 0.006}},
			{"title": "Свет на пределе", "effects": {"lowhp_regen_bonus": 0.16, "aura_radius_flat": 2.0}},
		],
		"keystones": [
			{"title": "Мученик", "effects": {"heal_to_holy_damage_ratio": 0.50, "healing_mult": -0.30}},
			{"title": "Заступник", "effects": {"ward_absorb_bonus": 0.40, "ult_charge_mult": -0.17}},
			{"title": "Глас гнева", "effects": {"damage_mult": 0.05, "buff_power_flat": 0.029, "defense_flat": -0.022}},
		],
		"hidden": [
			{"title": "Чудо у алтаря", "effects": {"lowhp_guard": 1.0}, "lore": "Вера, проверенная разными реликвиями, отвечает в самый тёмный час.", "metric": "class_wins", "threshold": 8},
			{"title": "Печать вершин", "effects": {"buff_power_flat": 0.016}, "lore": "Молитва, вознесённая на вершине, звучит громче.", "metric": "best_ascension", "threshold": 4},
		],
	},
	"biologist": {
		"core_title": "Живая гипотеза",
		"attrs": ["dot_damage", "dot_speed", "summon_amount", "vampiric_amount", "regeneration", "dodge"],
		"techniques": [
			{"title": "Споровый посев", "effects": {"dot_damage_flat": 0.21, "dot_speed_flat": 0.013}},
			{"title": "Симбиоз", "effects": {"summon_bonus": 0.13, "vampiric_amount_flat": 0.1}},
			{"title": "Культура штамма", "effects": {"regeneration_flat": 0.023, "dot_damage_flat": 0.21}},
			{"title": "Защитная реакция", "effects": {"dodge_flat": 0.003, "thorn_reflect_multiplier": 0.04}},
		],
		"keystones": [
			{"title": "Пандемия", "effects": {"swarm_damage_bonus": 0.177, "damage_mult": -0.04}},
			{"title": "Симбионт", "effects": {"stance_damage_bonus": 0.204, "dot_speed_flat": -0.07}},
			{"title": "Регенеративный цикл", "effects": {"regeneration_flat": 0.15, "max_health_mult": 0.04, "move_speed_mult": -0.06}},
		],
		"hidden": [
			{"title": "Мутация", "effects": {"kill_explosion_chance": 0.04}, "lore": "Каждый погибший образец — питательная среда для нового.", "metric": "weapon_diversity", "threshold": 3},
			{"title": "Апекс-штамм", "effects": {"thorn_reflect_multiplier": 0.1}, "lore": "Выживает не сильнейший, а тот, кто больнее огрызается.", "metric": "class_wins", "threshold": 12},
		],
	},
	"robot": {
		"core_title": "Ядро реактора",
		"attrs": ["max_health", "absorb", "pickup_radius", "regeneration", "ultimate_power", "crit_chance"],
		"techniques": [
			{"title": "Тёплый реактор", "effects": {"ultimate_flat": 0.011, "absorb_flat": 0.5}},
			{"title": "Бронеплиты", "effects": {"max_health_mult": 0.008, "regeneration_flat": 0.023}},
			{"title": "Магнитный захват", "effects": {"pickup_radius_flat": 5.0, "absorb_flat": 0.5}},
			{"title": "Контур перегрузки", "effects": {"ult_charge_mult": 0.016, "crit_chance_flat": 0.004}},
		],
		"keystones": [
			{"title": "Перегрев", "effects": {"reactor_heat_damage_bonus": 0.30, "reactor_heat_incoming_damage": 0.15}},
			{"title": "Сверхпроводник", "effects": {"magnet_radius_mult": 0.50, "max_health_mult": -0.12}},
			{"title": "Протокол мести", "effects": {"take_hit_pulse_chance": 0.11, "thorn_reflect_multiplier": 0.18, "attack_speed_mult": -0.04}},
		],
		"hidden": [
			{"title": "Самопочинка", "effects": {"lowhp_regen_bonus": 0.4}, "lore": "Инженеры оставили в прошивке подарок на чёрный день.", "metric": "best_ascension", "threshold": 4},
			{"title": "Аварийный конденсатор", "effects": {"lowhp_guard": 1.0}, "lore": "Последний ватт всегда припасён на вершину.", "metric": "weapon_diversity", "threshold": 2},
		],
	},
	"engineer": {
		"core_title": "Чертёж мастерской",
		"attrs": ["summon_amount", "buff_power", "pickup_radius", "defense", "aura_radius", "projectile_speed"],
		"techniques": [
			{"title": "Сборочный приказ", "effects": {"summon_bonus": 0.13, "buff_power_flat": 0.006}},
			{"title": "Ремонтная сеть", "effects": {"defense_flat": 0.004, "aura_radius_flat": 2.0}},
			{"title": "Полевой конвейер", "effects": {"pickup_radius_flat": 5.0, "projectile_speed_flat": 7.0}},
			{"title": "Шрапнельный заряд", "effects": {"kill_explosion_chance": 0.016, "summon_bonus": 0.13}},
		],
		"keystones": [
			{"title": "Автоматизация", "effects": {"device_attack_speed_bonus": 0.25, "non_device_damage_mult": -0.15}},
			{"title": "Минёр", "effects": {"mine_extra_count": 2.0, "device_attack_speed_bonus": -0.12}},
			{"title": "Перегретые стволы", "effects": {"projectile_speed_flat": 33.0, "attack_speed_mult": 0.05, "defense_flat": -0.022}},
		],
		"hidden": [
			{"title": "Запасная схема", "effects": {"take_hit_pulse_chance": 0.04}, "lore": "Хорошая турель собирается из того, что било по тебе.", "metric": "class_wins", "threshold": 12},
			{"title": "Патент вершины", "effects": {"buff_power_flat": 0.016}, "lore": "Лучшие чертежи рождаются в разреженном воздухе.", "metric": "no_shop_wins", "threshold": 1},
		],
	},
	"dark_mage": {
		"core_title": "Серп заката",
		"attrs": ["dot_damage", "damage", "aoe_radius", "dot_speed", "crit_damage", "summon_amount"],
		"techniques": [
			{"title": "Тонкая завеса", "effects": {"damage_mult": 0.008, "dot_damage_flat": 0.21}},
			{"title": "Распад", "effects": {"aoe_radius_mult": 0.013, "dot_speed_flat": 0.013}},
			{"title": "Жатва теней", "effects": {"crit_damage_flat": 0.021, "dot_damage_flat": 0.21}},
			{"title": "Тёмный пакт", "effects": {"low_hp_damage_bonus": 0.03, "summon_bonus": 0.13}},
		],
		"keystones": [
			{"title": "Пожинатель", "effects": {"dot_death_spread_duration": 2.0, "direct_damage_mult": -0.15}},
			{"title": "Ненасытный луч", "effects": {"beam_duration_mult": 0.30, "explosion_radius_mult": -0.20}},
			{"title": "Договор пустоты", "effects": {"summon_bonus": 0.9, "low_hp_damage_bonus": 0.14, "healing_mult": -0.3}},
		],
		"hidden": [
			{"title": "Шёпот гримуара", "effects": {"kill_explosion_chance": 0.04}, "lore": "Каждая душа дочитывает за тебя одну строку заклятия.", "metric": "best_ascension", "threshold": 5},
			{"title": "Полночь без дна", "effects": {"low_hp_damage_bonus": 0.08}, "lore": "На краю гибели луна светит ярче всего.", "metric": "weapon_diversity", "threshold": 3},
		],
	},
	"guitarist": {
		"core_title": "Первый аккорд",
		"attrs": ["attack_speed", "knockback", "ultimate_power", "buff_power", "aura_radius", "dodge"],
		"techniques": [
			{"title": "Резонанс зала", "effects": {"buff_power_flat": 0.006, "aura_radius_flat": 2.0}},
			{"title": "Ритм-секция", "effects": {"attack_speed_mult": 0.008, "knockback_mult": 0.02}},
			{"title": "Соло на бис", "effects": {"ultimate_flat": 0.011, "ult_charge_mult": 0.016}},
			{"title": "Сценический кураж", "effects": {"dodge_flat": 0.003, "move_speed_mult": 0.01}},
		],
		"keystones": [
			{"title": "Хедлайнер", "effects": {"guitar_aura_radius_mult": 0.30, "knockback_mult": -0.50}},
			{"title": "Рифф", "effects": {"riff_streak_damage_bonus": 0.25, "attack_speed_mult": -0.10}},
			{"title": "Фронтмен", "effects": {"ultimate_flat": 0.07, "ult_charge_mult": 0.07, "max_health_mult": -0.04}},
		],
		"hidden": [
			{"title": "Бродячий сет-лист", "effects": {"crit_speed_burst": 0.07}, "lore": "Публика помнит того, кто сыграл на всём, что звучит.", "metric": "weapon_diversity", "threshold": 2},
			{"title": "Хедлайнер вершины", "effects": {"take_hit_pulse_chance": 0.04}, "lore": "Чем выше сцена, тем громче отдача.", "metric": "class_wins", "threshold": 15},
		],
	},
	"assassin": {
		"core_title": "Клинок-полумесяц",
		"attrs": ["crit_damage", "dodge", "vampiric_chance", "move_speed", "crit_chance", "attack_speed"],
		"techniques": [
			{"title": "Тихий выпад", "effects": {"crit_damage_flat": 0.021, "crit_chance_flat": 0.004}},
			{"title": "Скользящая тень", "effects": {"dodge_flat": 0.003, "move_speed_mult": 0.01}},
			{"title": "Кровь на лезвии", "effects": {"vampiric_chance_flat": 0.006, "crit_damage_flat": 0.021}},
			{"title": "Танец клинков", "effects": {"attack_speed_mult": 0.008, "dodge_rush_bonus": 0.027}},
		],
		"keystones": [
			{"title": "Экзекутор", "effects": {"crit_execute_threshold": 0.35, "crit_chance_flat": -0.10}},
			{"title": "Теневой шаг", "effects": {"shadow_burst_invisibility_time": 2.0, "max_health_mult": -0.15}},
			{"title": "Призрачный шаг", "effects": {"dodge_flat": 0.018, "dodge_rush_bonus": 0.12, "damage_mult": -0.04}},
		],
		"hidden": [
			{"title": "Контракт гильдии", "effects": {"crit_speed_burst": 0.07}, "lore": "Мастеру всё равно, чем убивать, — важно, что после этого тихо.", "metric": "no_shop_wins", "threshold": 2},
			{"title": "Тень на вершине", "effects": {"dodge_rush_bonus": 0.07}, "lore": "Выше всех забирается тот, кого никто не видел в пути.", "metric": "best_ascension", "threshold": 5},
		],
	},
	"ranger": {
		"core_title": "След стрелы",
		"attrs": ["range", "move_speed", "projectile_speed", "damage", "crit_chance", "dodge"],
		"techniques": [
			{"title": "Натянутая тетива", "effects": {"range_mult": 0.01, "damage_mult": 0.008}},
			{"title": "Ветер охоты", "effects": {"move_speed_mult": 0.01, "projectile_speed_flat": 7.0}},
			{"title": "Меткий глаз", "effects": {"crit_chance_flat": 0.004, "range_mult": 0.01}},
			{"title": "Уход в кусты", "effects": {"dodge_flat": 0.003, "move_speed_mult": 0.01}},
		],
		"keystones": [
			{"title": "Штурмовая стойка", "effects": {"charged_shot_extra_pierce": 2.0, "charge_time_mult": 0.20}},
			{"title": "Капканщик", "effects": {"trap_extra_count": 2.0, "non_trap_damage_mult": -0.12}},
			{"title": "Хозяин тропы", "effects": {"move_speed_mult": 0.06, "crit_chance_flat": 0.022, "max_health_mult": -0.04}},
		],
		"hidden": [
			{"title": "Следопыт арсенала", "effects": {"crit_speed_burst": 0.07}, "lore": "Хороший охотник читает след любым оружием.", "metric": "weapon_diversity", "threshold": 3},
			{"title": "Гнездо на скале", "effects": {"dodge_rush_bonus": 0.07}, "lore": "На высоте промахиваются только те, кто смотрит вниз.", "metric": "class_wins", "threshold": 5},
		],
	},
	"doctor": {
		"core_title": "Клятва полевого врача",
		# SCRUM-1064: Plague Oath blocks every generic regen/vampirism modifier.
		# Keep the constellation on live weapon/utility axes so no purchased star
		# is silently discarded by Player.apply_meta_skill_modifiers().
		"attrs": ["dot_damage", "dot_speed", "max_health", "buff_power", "attack_speed", "ultimate_power"],
		"techniques": [
			{"title": "Чумная смесь", "effects": {"dot_damage_flat": 0.21, "dot_speed_flat": 0.013}},
			{"title": "Полевой резерв", "effects": {"max_health_mult": 0.008, "buff_power_flat": 0.006}},
			{"title": "Стимулятор", "effects": {"attack_speed_mult": 0.008, "buff_power_flat": 0.006}},
			{"title": "Реанимация", "effects": {"ultimate_flat": 0.011, "max_health_mult": 0.008}},
		],
		"keystones": [
			{"title": "Вампирический контур", "effects": {"drain_extra_targets": 1.0, "medkit_healing_mult": -0.40}},
			{"title": "Хирург", "effects": {"surgical_close_damage_bonus": 0.60, "ranged_damage_mult": -0.20}},
			{"title": "Доза адреналина", "effects": {"attack_speed_mult": 0.05, "buff_power_flat": 0.029, "healing_mult": -0.3}},
		],
		"hidden": [
			{"title": "Протокол спасения", "effects": {"lowhp_guard": 1.0}, "lore": "Врач, освоивший весь инструментарий, не даст умереть и себе.", "metric": "class_wins", "threshold": 8},
			{"title": "Горный госпиталь", "effects": {"ult_start_charge": 0.5}, "lore": "Чем выше поднимаешься, тем важнее заранее подготовить переливание.", "metric": "no_shop_wins", "threshold": 2},
		],
	},
	"chemist": {
		"core_title": "Реторта истины",
		"attrs": ["aoe_radius", "dot_speed", "dot_damage", "damage", "range", "move_speed"],
		"techniques": [
			{"title": "Едкий ускоритель", "effects": {"dot_speed_flat": 0.013, "dot_damage_flat": 0.21}},
			{"title": "Цепная реакция", "effects": {"aoe_radius_mult": 0.013, "damage_mult": 0.008}},
			{"title": "Летучая фракция", "effects": {"move_speed_mult": 0.01, "range_mult": 0.01}},
			{"title": "Нестабильная смесь", "effects": {"kill_explosion_chance": 0.016, "dot_damage_flat": 0.21}},
		],
		"keystones": [
			{"title": "Катализатор", "effects": {"cloud_detonation_radius_mult": 0.40, "pool_duration_mult": -0.30}},
			{"title": "Гомункул-прайм", "effects": {"homunculus_power_mult": 0.50, "max_health_mult": -0.10}},
			{"title": "Пары эфира", "effects": {"move_speed_mult": 0.06, "dodge_flat": 0.015, "max_health_mult": -0.04}},
		],
		"hidden": [
			{"title": "Побочный продукт", "effects": {"kill_explosion_chance": 0.04}, "lore": "Настоящая наука начинается со слов «а что, если смешать всё».", "metric": "no_shop_wins", "threshold": 1},
			{"title": "Формула высот", "effects": {"dot_damage_flat": 0.5}, "lore": "Разреженный воздух — лучший катализатор.", "metric": "best_ascension", "threshold": 3},
		],
	},
	"knight": {
		"core_title": "Клятва щита",
		"attrs": ["max_health", "defense", "absorb", "aura_radius", "buff_power", "damage"],
		"techniques": [
			{"title": "Щитовая выучка", "effects": {"defense_flat": 0.004, "absorb_flat": 0.5}},
			{"title": "Несокрушимый оплот", "effects": {"max_health_mult": 0.008, "buff_power_flat": 0.006}},
			{"title": "Ответный удар", "effects": {"thorn_reflect_multiplier": 0.04, "damage_mult": 0.008}},
			{"title": "Знамя рыцаря", "effects": {"aura_radius_flat": 2.0, "buff_power_flat": 0.006}},
		],
		"keystones": [
			{"title": "Бастион", "effects": {"bastion_defense_bonus": 0.25, "bastion_taunt": 1.0, "move_speed_mult": -0.15}},
			{"title": "Марш легиона", "effects": {"rush_damage_bonus": 0.328, "defense_flat": -0.022}},
			{"title": "Шипастый панцирь", "effects": {"thorn_reflect_multiplier": 0.27, "take_hit_pulse_chance": 0.07, "attack_speed_mult": -0.04}},
		],
		"hidden": [
			{"title": "Обет турнира", "effects": {"take_hit_pulse_chance": 0.04}, "lore": "Рыцарь, сменивший копьё на меч и молот, страшен в любом строю.", "metric": "best_ascension", "threshold": 4},
			{"title": "Страж перевала", "effects": {"lowhp_guard": 1.0}, "lore": "Тот, кто держал перевал, знает цену последнему рубежу.", "metric": "class_wins", "threshold": 10},
		],
	},
	"druid": {
		"core_title": "Корень мира",
		"attrs": ["aura_radius", "summon_amount", "regeneration", "buff_power", "dot_damage", "crit_chance"],
		"techniques": [
			{"title": "Голос чащи", "effects": {"aura_radius_flat": 2.0, "summon_bonus": 0.13}},
			{"title": "Корни жизни", "effects": {"regeneration_flat": 0.023, "buff_power_flat": 0.006}},
			{"title": "Терновый покров", "effects": {"thorn_reflect_multiplier": 0.04, "dot_damage_flat": 0.21}},
			{"title": "Зов стаи", "effects": {"summon_bonus": 0.13, "crit_chance_flat": 0.004}},
		],
		"keystones": [
			{"title": "Вожак стаи", "effects": {"pet_damage_mult": 0.25, "pet_personal_damage_mult": -0.15}},
			{"title": "Терновый круг", "effects": {"briar_radius_mult": 0.35, "move_speed_mult": -0.10}},
			{"title": "Гнев леса", "effects": {"dot_damage_flat": 1.4, "thorn_reflect_multiplier": 0.18, "regeneration_flat": -0.13}},
		],
		"hidden": [
			{"title": "Перекличка леса", "effects": {"thorn_reflect_multiplier": 0.1}, "lore": "Лес отвечает тем голосом, каким к нему обращаются.", "metric": "class_wins", "threshold": 10},
			{"title": "Древо на скале", "effects": {"lowhp_regen_bonus": 0.4}, "lore": "Корни, проросшие сквозь камень вершины, не вырвать ничем.", "metric": "weapon_diversity", "threshold": 3},
		],
	},
}

const CONSTELLATION_LAYOUT := {
	"berserk": [Vector2(0.500, 0.560), Vector2(0.425, 0.456), Vector2(0.353, 0.374), Vector2(0.270, 0.304), Vector2(0.180, 0.240), Vector2(0.575, 0.456), Vector2(0.647, 0.374), Vector2(0.730, 0.304), Vector2(0.820, 0.240), Vector2(0.500, 0.431), Vector2(0.500, 0.321), Vector2(0.500, 0.210), Vector2(0.500, 0.102), Vector2(0.500, 0.661), Vector2(0.500, 0.747), Vector2(0.500, 0.834), Vector2(0.500, 0.920), Vector2(0.081, 0.141), Vector2(0.919, 0.141), Vector2(0.500, 0.050), Vector2(0.726, 0.437), Vector2(0.400, 0.747)],
	"soldier": [Vector2(0.500, 0.400), Vector2(0.417, 0.523), Vector2(0.336, 0.619), Vector2(0.242, 0.704), Vector2(0.140, 0.780), Vector2(0.583, 0.523), Vector2(0.664, 0.619), Vector2(0.758, 0.704), Vector2(0.860, 0.780), Vector2(0.500, 0.310), Vector2(0.500, 0.234), Vector2(0.500, 0.157), Vector2(0.500, 0.102), Vector2(0.500, 0.546), Vector2(0.500, 0.670), Vector2(0.500, 0.795), Vector2(0.500, 0.920), Vector2(0.050, 0.882), Vector2(0.950, 0.882), Vector2(0.500, 0.050), Vector2(0.584, 0.679), Vector2(0.400, 0.670)],
	"thief": [Vector2(0.440, 0.580), Vector2(0.440, 0.440), Vector2(0.440, 0.320), Vector2(0.440, 0.200), Vector2(0.440, 0.102), Vector2(0.355, 0.633), Vector2(0.286, 0.683), Vector2(0.221, 0.740), Vector2(0.160, 0.800), Vector2(0.525, 0.633), Vector2(0.594, 0.683), Vector2(0.659, 0.740), Vector2(0.720, 0.800), Vector2(0.572, 0.530), Vector2(0.681, 0.477), Vector2(0.783, 0.413), Vector2(0.880, 0.340), Vector2(0.440, 0.050), Vector2(0.050, 0.886), Vector2(0.830, 0.886), Vector2(0.230, 0.600), Vector2(0.720, 0.569)],
	"elementalist": [Vector2(0.500, 0.560), Vector2(0.522, 0.426), Vector2(0.529, 0.310), Vector2(0.520, 0.195), Vector2(0.500, 0.102), Vector2(0.408, 0.641), Vector2(0.325, 0.703), Vector2(0.235, 0.755), Vector2(0.140, 0.800), Vector2(0.592, 0.641), Vector2(0.675, 0.703), Vector2(0.765, 0.755), Vector2(0.860, 0.800), Vector2(0.500, 0.661), Vector2(0.500, 0.747), Vector2(0.500, 0.834), Vector2(0.500, 0.920), Vector2(0.500, 0.050), Vector2(0.050, 0.878), Vector2(0.950, 0.878), Vector2(0.262, 0.625), Vector2(0.400, 0.747)],
	"sniper": [Vector2(0.500, 0.500), Vector2(0.515, 0.388), Vector2(0.520, 0.292), Vector2(0.514, 0.196), Vector2(0.500, 0.102), Vector2(0.612, 0.515), Vector2(0.708, 0.520), Vector2(0.804, 0.514), Vector2(0.898, 0.500), Vector2(0.485, 0.612), Vector2(0.480, 0.708), Vector2(0.486, 0.804), Vector2(0.500, 0.898), Vector2(0.388, 0.485), Vector2(0.292, 0.480), Vector2(0.196, 0.486), Vector2(0.100, 0.500), Vector2(0.500, 0.050), Vector2(0.950, 0.500), Vector2(0.500, 0.950), Vector2(0.698, 0.620), Vector2(0.302, 0.380)],
	"priest": [Vector2(0.500, 0.520), Vector2(0.517, 0.397), Vector2(0.522, 0.291), Vector2(0.515, 0.186), Vector2(0.500, 0.102), Vector2(0.595, 0.573), Vector2(0.680, 0.611), Vector2(0.769, 0.639), Vector2(0.860, 0.660), Vector2(0.394, 0.545), Vector2(0.306, 0.575), Vector2(0.222, 0.614), Vector2(0.140, 0.660), Vector2(0.500, 0.638), Vector2(0.500, 0.738), Vector2(0.500, 0.839), Vector2(0.500, 0.940), Vector2(0.500, 0.050), Vector2(0.950, 0.711), Vector2(0.050, 0.711), Vector2(0.635, 0.700), Vector2(0.400, 0.738)],
	"biologist": [Vector2(0.500, 0.520), Vector2(0.455, 0.390), Vector2(0.401, 0.289), Vector2(0.327, 0.200), Vector2(0.240, 0.120), Vector2(0.545, 0.390), Vector2(0.599, 0.289), Vector2(0.673, 0.200), Vector2(0.760, 0.120), Vector2(0.454, 0.644), Vector2(0.399, 0.741), Vector2(0.326, 0.825), Vector2(0.240, 0.900), Vector2(0.546, 0.644), Vector2(0.601, 0.741), Vector2(0.674, 0.825), Vector2(0.760, 0.900), Vector2(0.164, 0.050), Vector2(0.836, 0.050), Vector2(0.161, 0.950), Vector2(0.691, 0.328), Vector2(0.510, 0.783)],
	"robot": [Vector2(0.500, 0.500), Vector2(0.500, 0.382), Vector2(0.500, 0.282), Vector2(0.500, 0.181), Vector2(0.500, 0.102), Vector2(0.389, 0.545), Vector2(0.300, 0.593), Vector2(0.217, 0.652), Vector2(0.140, 0.720), Vector2(0.611, 0.545), Vector2(0.700, 0.593), Vector2(0.783, 0.652), Vector2(0.860, 0.720), Vector2(0.500, 0.618), Vector2(0.500, 0.718), Vector2(0.500, 0.819), Vector2(0.500, 0.920), Vector2(0.500, 0.050), Vector2(0.050, 0.793), Vector2(0.950, 0.793), Vector2(0.258, 0.502), Vector2(0.400, 0.718)],
	"engineer": [Vector2(0.500, 0.500), Vector2(0.430, 0.402), Vector2(0.362, 0.326), Vector2(0.284, 0.260), Vector2(0.200, 0.200), Vector2(0.570, 0.402), Vector2(0.638, 0.326), Vector2(0.716, 0.260), Vector2(0.800, 0.200), Vector2(0.430, 0.598), Vector2(0.362, 0.674), Vector2(0.284, 0.740), Vector2(0.200, 0.800), Vector2(0.570, 0.598), Vector2(0.638, 0.674), Vector2(0.716, 0.740), Vector2(0.800, 0.800), Vector2(0.101, 0.101), Vector2(0.899, 0.101), Vector2(0.101, 0.899), Vector2(0.716, 0.388), Vector2(0.560, 0.736)],
	"dark_mage": [Vector2(0.560, 0.500), Vector2(0.467, 0.408), Vector2(0.398, 0.321), Vector2(0.344, 0.224), Vector2(0.300, 0.120), Vector2(0.437, 0.531), Vector2(0.331, 0.540), Vector2(0.226, 0.527), Vector2(0.120, 0.500), Vector2(0.508, 0.620), Vector2(0.451, 0.716), Vector2(0.381, 0.801), Vector2(0.300, 0.880), Vector2(0.650, 0.510), Vector2(0.726, 0.513), Vector2(0.803, 0.509), Vector2(0.880, 0.500), Vector2(0.221, 0.050), Vector2(0.050, 0.500), Vector2(0.221, 0.950), Vector2(0.314, 0.441), Vector2(0.719, 0.612)],
	"guitarist": [Vector2(0.360, 0.660), Vector2(0.365, 0.501), Vector2(0.357, 0.366), Vector2(0.334, 0.232), Vector2(0.300, 0.100), Vector2(0.457, 0.536), Vector2(0.530, 0.424), Vector2(0.589, 0.305), Vector2(0.640, 0.180), Vector2(0.315, 0.733), Vector2(0.277, 0.795), Vector2(0.238, 0.858), Vector2(0.200, 0.920), Vector2(0.459, 0.632), Vector2(0.545, 0.614), Vector2(0.632, 0.605), Vector2(0.720, 0.600), Vector2(0.285, 0.050), Vector2(0.711, 0.059), Vector2(0.127, 0.950), Vector2(0.611, 0.483), Vector2(0.569, 0.712)],
	"assassin": [Vector2(0.420, 0.560), Vector2(0.348, 0.440), Vector2(0.299, 0.332), Vector2(0.264, 0.218), Vector2(0.240, 0.100), Vector2(0.490, 0.420), Vector2(0.567, 0.316), Vector2(0.666, 0.231), Vector2(0.780, 0.160), Vector2(0.547, 0.550), Vector2(0.654, 0.556), Vector2(0.758, 0.582), Vector2(0.860, 0.620), Vector2(0.373, 0.656), Vector2(0.340, 0.741), Vector2(0.316, 0.829), Vector2(0.300, 0.920), Vector2(0.189, 0.050), Vector2(0.874, 0.056), Vector2(0.950, 0.639), Vector2(0.653, 0.368), Vector2(0.248, 0.701)],
	"ranger": [Vector2(0.460, 0.520), Vector2(0.460, 0.391), Vector2(0.460, 0.281), Vector2(0.460, 0.170), Vector2(0.460, 0.102), Vector2(0.349, 0.550), Vector2(0.263, 0.590), Vector2(0.188, 0.649), Vector2(0.120, 0.720), Vector2(0.540, 0.602), Vector2(0.617, 0.658), Vector2(0.705, 0.695), Vector2(0.800, 0.720), Vector2(0.572, 0.419), Vector2(0.668, 0.333), Vector2(0.764, 0.246), Vector2(0.860, 0.160), Vector2(0.460, 0.050), Vector2(0.050, 0.791), Vector2(0.921, 0.791), Vector2(0.230, 0.496), Vector2(0.735, 0.407)],
	"doctor": [Vector2(0.500, 0.500), Vector2(0.500, 0.382), Vector2(0.500, 0.282), Vector2(0.500, 0.181), Vector2(0.500, 0.102), Vector2(0.606, 0.500), Vector2(0.698, 0.500), Vector2(0.789, 0.500), Vector2(0.880, 0.500), Vector2(0.500, 0.618), Vector2(0.500, 0.718), Vector2(0.500, 0.819), Vector2(0.500, 0.898), Vector2(0.394, 0.500), Vector2(0.302, 0.500), Vector2(0.211, 0.500), Vector2(0.120, 0.500), Vector2(0.500, 0.050), Vector2(0.950, 0.500), Vector2(0.500, 0.950), Vector2(0.698, 0.600), Vector2(0.302, 0.400)],
	"chemist": [Vector2(0.500, 0.360), Vector2(0.455, 0.287), Vector2(0.417, 0.225), Vector2(0.378, 0.162), Vector2(0.340, 0.100), Vector2(0.545, 0.287), Vector2(0.583, 0.225), Vector2(0.622, 0.162), Vector2(0.660, 0.100), Vector2(0.443, 0.516), Vector2(0.379, 0.641), Vector2(0.296, 0.754), Vector2(0.200, 0.860), Vector2(0.557, 0.516), Vector2(0.621, 0.641), Vector2(0.704, 0.754), Vector2(0.800, 0.860), Vector2(0.267, 0.050), Vector2(0.733, 0.050), Vector2(0.128, 0.950), Vector2(0.668, 0.277), Vector2(0.529, 0.681)],
	"knight": [Vector2(0.500, 0.440), Vector2(0.396, 0.391), Vector2(0.312, 0.343), Vector2(0.234, 0.284), Vector2(0.160, 0.220), Vector2(0.604, 0.391), Vector2(0.688, 0.343), Vector2(0.766, 0.284), Vector2(0.840, 0.220), Vector2(0.500, 0.580), Vector2(0.500, 0.700), Vector2(0.500, 0.820), Vector2(0.500, 0.898), Vector2(0.500, 0.345), Vector2(0.500, 0.263), Vector2(0.500, 0.182), Vector2(0.500, 0.100), Vector2(0.050, 0.144), Vector2(0.950, 0.144), Vector2(0.500, 0.950), Vector2(0.734, 0.431), Vector2(0.600, 0.263)],
	"druid": [Vector2(0.500, 0.620), Vector2(0.432, 0.491), Vector2(0.365, 0.387), Vector2(0.286, 0.291), Vector2(0.200, 0.200), Vector2(0.500, 0.469), Vector2(0.500, 0.339), Vector2(0.500, 0.210), Vector2(0.500, 0.102), Vector2(0.568, 0.491), Vector2(0.635, 0.387), Vector2(0.714, 0.291), Vector2(0.800, 0.200), Vector2(0.500, 0.710), Vector2(0.500, 0.786), Vector2(0.500, 0.863), Vector2(0.500, 0.940), Vector2(0.119, 0.086), Vector2(0.500, 0.050), Vector2(0.881, 0.086), Vector2(0.600, 0.339), Vector2(0.400, 0.786)],
}

# --- «Атлас гильдии»: общий QoL-слой (валюта — звёздная пыль) ---
# 25 узлов: хаб 0-cost + 14 минорных (13×cost 2 + 1×cost 1 — ранний крючок §4) +
# 4 notable (cost 3) + 4 наследных keystone v2 (cost 5: death_save/
# guaranteed_rare_shop/first_levelup_rare/ult_start_charge — их боевой вклад
# заперт тестом аккаунт-множителя <1.30) + 2 скрытых узла (кодекс-вехи и
# секретный босс «зажигают» их без покупки). Полная стоимость 59 пыли при
# потолке заработка 50 — «всё не купить». SCRUM-828: узел atlas_m0 стоит 1 пыль,
# чтобы ПЕРВАЯ победа (1 пыль, §4) сразу открывала первый QoL-узел Атласа.
const ATLAS_NODES := [
	{"id": "atlas_hub", "role": "core", "cost": 0, "title": "Зал гильдии", "desc": "Сердце Атласа гильдии. Открыт всем героям.", "effects": {}, "npos": Vector2(0.5, 0.5), "adj": ["atlas_m0", "atlas_m2", "atlas_m4", "atlas_m6", "atlas_m8", "atlas_m10", "atlas_m11", "atlas_m13"]},
	# Ветвь «Казна» (северо-запад): золото и стартовый капитал.
	# atlas_m0 — «ранний крючок» §4: cost 1, покупается сразу после первой победы.
	{"id": "atlas_m0", "role": "minor", "cost": 1, "title": "Договор с торговцами", "effects": {"money_gain_mult": 0.02}, "npos": Vector2(0.38, 0.38), "adj": ["atlas_hub", "atlas_m1"]},
	{"id": "atlas_m1", "role": "minor", "cost": 2, "title": "Караванные связи", "effects": {"money_gain_mult": 0.02}, "npos": Vector2(0.28, 0.28), "adj": ["atlas_m0", "atlas_n0"]},
	{"id": "atlas_m2", "role": "minor", "cost": 2, "title": "Подъёмные новичка", "effects": {"start_gold_flat": 10.0}, "npos": Vector2(0.46, 0.30), "adj": ["atlas_hub", "atlas_m3"]},
	{"id": "atlas_m3", "role": "minor", "cost": 2, "title": "Гильдейский аванс", "effects": {"start_gold_flat": 10.0}, "npos": Vector2(0.40, 0.19), "adj": ["atlas_m2", "atlas_n0"]},
	{"id": "atlas_n0", "role": "notable", "cost": 3, "title": "Золотая жила", "effects": {"money_gain_mult": 0.03, "start_gold_flat": 5.0}, "npos": Vector2(0.26, 0.14), "adj": ["atlas_m1", "atlas_m3", "atlas_k0"]},
	{"id": "atlas_k0", "role": "keystone", "cost": 5, "title": "Связи в гильдии", "effects": {"guaranteed_rare_shop": 1.0, "start_gold_flat": 15.0}, "npos": Vector2(0.12, 0.08), "adj": ["atlas_n0"]},
	# Ветвь «Лавка» (северо-восток): скидки лавки и докачки.
	{"id": "atlas_m4", "role": "minor", "cost": 2, "title": "Скидка по знакомству", "effects": {"shop_price_mult": -0.02}, "npos": Vector2(0.62, 0.38), "adj": ["atlas_hub", "atlas_m5"]},
	{"id": "atlas_m5", "role": "minor", "cost": 2, "title": "Оптовые цены", "effects": {"shop_price_mult": -0.02}, "npos": Vector2(0.72, 0.28), "adj": ["atlas_m4", "atlas_n1"]},
	{"id": "atlas_m6", "role": "minor", "cost": 2, "title": "Тренировочный зал", "effects": {"attr_cost_mult": -0.02}, "npos": Vector2(0.54, 0.30), "adj": ["atlas_hub", "atlas_m7"]},
	{"id": "atlas_m7", "role": "minor", "cost": 2, "title": "Наставники гильдии", "effects": {"attr_cost_mult": -0.02}, "npos": Vector2(0.60, 0.19), "adj": ["atlas_m6", "atlas_n1"]},
	{"id": "atlas_n1", "role": "notable", "cost": 3, "title": "Штатный интендант", "effects": {"shop_price_mult": -0.02, "attr_cost_mult": -0.02}, "npos": Vector2(0.74, 0.14), "adj": ["atlas_m5", "atlas_m7", "atlas_k1"]},
	{"id": "atlas_k1", "role": "keystone", "cost": 5, "title": "Озарение", "effects": {"first_levelup_rare": 1.0}, "npos": Vector2(0.88, 0.08), "adj": ["atlas_n1"]},
	# Ветвь «Знание» (юго-запад): опыт, кругозор, ульта-раж.
	{"id": "atlas_m8", "role": "minor", "cost": 2, "title": "Хроники походов", "effects": {"xp_gain_mult": 0.02}, "npos": Vector2(0.38, 0.62), "adj": ["atlas_hub", "atlas_m9"]},
	{"id": "atlas_m9", "role": "minor", "cost": 2, "title": "Разбор полётов", "effects": {"xp_gain_mult": 0.02}, "npos": Vector2(0.28, 0.72), "adj": ["atlas_m8", "atlas_n2", "atlas_h0"]},
	{"id": "atlas_m10", "role": "minor", "cost": 2, "title": "Полевые заметки", "effects": {"xp_gain_mult": 0.02}, "npos": Vector2(0.46, 0.70), "adj": ["atlas_hub", "atlas_n2"]},
	{"id": "atlas_n2", "role": "notable", "cost": 3, "title": "Кругозор", "effects": {"attr_extra_options": 1.0}, "npos": Vector2(0.34, 0.84), "adj": ["atlas_m9", "atlas_m10", "atlas_k2"]},
	{"id": "atlas_k2", "role": "keystone", "cost": 5, "title": "Боевой раж", "effects": {"ult_start_charge": 0.5}, "npos": Vector2(0.18, 0.92), "adj": ["atlas_n2"]},
	{"id": "atlas_h0", "role": "hidden", "cost": 0, "title": "Архив гильдии", "effects": {"money_gain_mult": 0.03}, "npos": Vector2(0.16, 0.62), "adj": ["atlas_m9"], "metric": "codex_milestones", "threshold": 4, "lore": "Полки архива пополняются трофеями всех походов гильдии."},
	# Ветвь «Дорога» (юго-восток): подбор, аптека, вторая жизнь.
	{"id": "atlas_m11", "role": "minor", "cost": 2, "title": "Цепкие руки", "effects": {"pickup_radius_flat": 10.0}, "npos": Vector2(0.62, 0.62), "adj": ["atlas_hub", "atlas_m12"]},
	{"id": "atlas_m12", "role": "minor", "cost": 2, "title": "Длинный шаг", "effects": {"pickup_radius_flat": 10.0}, "npos": Vector2(0.72, 0.72), "adj": ["atlas_m11", "atlas_n3", "atlas_h1"]},
	{"id": "atlas_m13", "role": "minor", "cost": 2, "title": "Походная аптека", "effects": {"healing_mult": 0.04}, "npos": Vector2(0.54, 0.70), "adj": ["atlas_hub", "atlas_n3"]},
	{"id": "atlas_n3", "role": "notable", "cost": 3, "title": "Страховой взнос", "effects": {"pickup_radius_flat": 8.0, "healing_mult": 0.03}, "npos": Vector2(0.66, 0.84), "adj": ["atlas_m12", "atlas_m13", "atlas_k3"]},
	{"id": "atlas_k3", "role": "keystone", "cost": 5, "title": "Вторая жизнь", "effects": {"death_save": 1.0}, "npos": Vector2(0.82, 0.92), "adj": ["atlas_n3"]},
	{"id": "atlas_h1", "role": "hidden", "cost": 0, "title": "Трофей разлома", "effects": {"start_gold_flat": 25.0}, "npos": Vector2(0.84, 0.62), "adj": ["atlas_m12"], "metric": "secret_boss", "threshold": 1, "lore": "Осколок сущности секретного босса оплачивает любые долги гильдии."},
]

# --- Геометрия старого экрана (SCRUM-698 canvas): созвездия на кольце, Атлас в центре ---
const RING_RADIUS := 760.0
const CONSTELLATION_SCALE := 470.0
const ATLAS_SCALE := 620.0

# Стоимости по ролям (созвездие: §3 дизайна; Атлас: §2).
const ROLE_COSTS := {"core": 0, "minor": 1, "technique": 2, "keystone": 4, "hidden": 0}
# kind для старого экрана (арт/размер узла): core→entry, technique→notable.
const ROLE_KINDS := {"core": "entry", "minor": "minor", "notable": "notable", "technique": "notable", "keystone": "keystone", "hidden": "hidden"}


static func _fmt(x: float) -> String:
	if is_equal_approx(x, roundf(x)):
		return str(int(roundf(x)))
	if is_equal_approx(x, snappedf(x, 0.1)):
		return "%.1f" % snappedf(x, 0.1)
	if is_equal_approx(x, snappedf(x, 0.01)):
		return "%.2f" % snappedf(x, 0.01)
	return "%.3f" % x


# Один эффект → человекочитаемый фрагмент с числом («+0.8% к урону»).
static func _effect_fragment(key: String, value: float) -> String:
	var label: Dictionary = EFFECT_LABELS.get(key, {})
	var ru := str(label.get("ru", key))
	var pct := bool(label.get("pct", false))
	var num: float = value * 100.0 if pct else value
	var sign := "+" if value >= 0.0 else ""
	var unit := "%" if pct else ""
	return "%s%s%s %s" % [sign, _fmt(num), unit, ru]


# Все эффекты узла → строка описания с числами; флаговые ключи — готовой фразой.
static func effects_desc(effects: Dictionary) -> String:
	var parts: Array = []
	for key in effects.keys():
		if FLAG_DESC.has(str(key)):
			parts.append(str(FLAG_DESC[str(key)]).trim_suffix("."))
		else:
			parts.append(_effect_fragment(str(key), float(effects[key])))
	return ", ".join(parts)


# RU-текст условия скрытой звезды (для панели узла и тумана «?»).
static func condition_text(metric: String, threshold: int) -> String:
	match metric:
		"weapon_diversity":
			return "Победи финального босса %d разными оружиями этого класса." % threshold
		"best_ascension":
			return "Победи на возвышении %d или выше этим классом." % threshold
		"no_shop_wins":
			return "Победи без покупок в магазине этим классом."
		"class_wins":
			return "Одержи %d финальных побед этим классом." % threshold
		"codex_milestones":
			return "Достигни %d вех кодекса (открывай монстров, боссов и артефакты)." % threshold
		"secret_boss":
			return "Одолей секретного босса возвышений."
		"achievement_milestones":
			return "Достигни %d вех достижений." % threshold
	return "Условие скрыто."


static func _add(nodes: Array, index: Dictionary, node: Dictionary) -> void:
	node["adj"] = []
	nodes.append(node)
	index[str(node["id"])] = node


static func _connect(index: Dictionary, a: String, b: String) -> void:
	if not index.has(a) or not index.has(b) or a == b:
		return
	var adj_a: Array = index[a]["adj"]
	var adj_b: Array = index[b]["adj"]
	if not adj_a.has(b):
		adj_a.append(b)
	if not adj_b.has(a):
		adj_b.append(a)


# Мировая позиция узла созвездия для старого экрана: кольцо 17 классов.
static func _world_pos(class_index: int, npos: Vector2) -> Vector2:
	var angle := TAU * float(class_index) / float(CLASS_ORDER.size()) - PI * 0.5
	var center := Vector2(cos(angle), sin(angle)) * RING_RADIUS
	return center + (npos - Vector2(0.5, 0.5)) * CONSTELLATION_SCALE


# Единственная точка сборки графа Меты 4.0. entry_nodes =
# meta_progression.CLASS_ENTRY_NODES (id ядра-эмблемы по классу) — параметром,
# чтобы не плодить круговых preload.
static func build_tree(entry_nodes: Dictionary) -> Array:
	var nodes := []
	var index := {}

	# --- Атлас гильдии (центр мира; account-слой, class_affinity = "") ---
	for spec in ATLAS_NODES:
		var s: Dictionary = spec
		var role := str(s["role"])
		var effects: Dictionary = (s.get("effects", {}) as Dictionary).duplicate(true)
		var desc := str(s.get("desc", ""))
		if desc == "":
			desc = "%s." % effects_desc(effects) if not effects.is_empty() else "Узел Атласа гильдии."
		var node := {
			"id": str(s["id"]), "branch": "atlas", "tier": 1, "cost": int(s["cost"]),
			"kind": str(ROLE_KINDS[role]), "role": role, "title": str(s["title"]),
			"desc": desc, "effects": effects,
			"npos": s["npos"], "pos": ((s["npos"] as Vector2) - Vector2(0.5, 0.5)) * ATLAS_SCALE,
		}
		if role == "hidden":
			node["condition"] = {"metric": str(s["metric"]), "threshold": int(s["threshold"]), "text": condition_text(str(s["metric"]), int(s["threshold"]))}
			node["lore"] = str(s.get("lore", ""))
			node["desc"] = "%s Открывается подвигом: %s" % [node["desc"], str(node["condition"]["text"])]
		_add(nodes, index, node)
	for spec in ATLAS_NODES:
		for neighbor in (spec as Dictionary).get("adj", []):
			_connect(index, str((spec as Dictionary)["id"]), str(neighbor))

	# --- 17 созвездий классов ---
	for class_index in range(CLASS_ORDER.size()):
		var class_id: String = CLASS_ORDER[class_index]
		_build_constellation(nodes, index, entry_nodes, class_id, class_index)

	for node in nodes:
		(node["adj"] as Array).sort()
	return nodes


# Созвездие класса: 22 узла по силуэту приложения C (CONSTELLATION_LAYOUT:
# [ядро, 4 луча × (m0,m1,m2,техника), 3 keystone, 2 скрытых]).
static func _build_constellation(nodes: Array, index: Dictionary, entry_nodes: Dictionary, class_id: String, class_index: int) -> void:
	var spec: Dictionary = CONSTELLATION_SPECS.get(class_id, {})
	var layout: Array = CONSTELLATION_LAYOUT.get(class_id, [])
	if spec.is_empty() or layout.size() != 22:
		return
	var attrs: Array = spec["attrs"]
	var core_id := str(entry_nodes.get(class_id, "%s_core" % class_id))
	var base_attr_key := str(CLASS_BASE_ATTRIBUTE.get(class_id, "strength_flat"))
	var core_effects := {base_attr_key: 1.0}
	_add(nodes, index, {
		"id": core_id, "branch": class_id, "tier": 10, "cost": 0, "kind": "entry",
		"role": "core", "title": str(spec.get("core_title", "Эмблема класса")),
		"desc": "Ядро созвездия: герб героя. Открыто сразу и даёт %s." % effects_desc(core_effects),
		"effects": core_effects, "npos": layout[0],
		"pos": _world_pos(class_index, layout[0]), "class_affinity": class_id,
	})

	# 4 луча × 3 минорные звезды + звезда-техника на конце луча.
	var attr_seen := {}
	for ray in range(4):
		var prev_id := core_id
		for step in range(3):
			var li: int = 1 + ray * 4 + step
			var attr_id := str(attrs[RAY_ATTR_PATTERN[ray][step]])
			var star: Dictionary = STAR_ATTRS[attr_id]
			attr_seen[attr_id] = int(attr_seen.get(attr_id, 0)) + 1
			# SCRUM-834 (Мета 4.1): два номинала минорных звёзд. Каждый профильный
			# атрибут представлен дважды (I и II) — I=«+1» (×2/3), II=«+2» (×4/3).
			# Сумма пары = 2×base → базовый бюджет созвездия сохраняется точно (§6).
			var denom_factor := (2.0 / 3.0) if int(attr_seen[attr_id]) == 1 else (4.0 / 3.0)
			var value := float(star["value"]) * denom_factor
			var effects := {str(star["key"]): value}
			var minor_id := "%s_m%d" % [class_id, ray * 3 + step]
			_add(nodes, index, {
				"id": minor_id, "branch": class_id, "tier": 11, "cost": int(ROLE_COSTS["minor"]),
				"kind": "minor", "role": "minor",
				"title": "%s %s" % [str(star["short"]), "I" if int(attr_seen[attr_id]) == 1 else "II"],
				"desc": "Звезда-атрибут: %s." % effects_desc(effects),
				"effects": effects, "npos": layout[li],
				"pos": _world_pos(class_index, layout[li]), "class_affinity": class_id,
			})
			_connect(index, prev_id, minor_id)
			prev_id = minor_id
		var t_li: int = 1 + ray * 4 + 3
		var tech: Dictionary = (spec["techniques"] as Array)[ray]
		var tech_effects: Dictionary = (tech["effects"] as Dictionary).duplicate(true)
		var tech_id := "%s_t%d" % [class_id, ray]
		_add(nodes, index, {
			"id": tech_id, "branch": class_id, "tier": 12, "cost": int(ROLE_COSTS["technique"]),
			"kind": "notable", "role": "technique", "title": str(tech["title"]),
			"desc": "Звезда-техника: %s." % effects_desc(tech_effects),
			"effects": tech_effects, "npos": layout[t_li],
			"pos": _world_pos(class_index, layout[t_li]), "class_affinity": class_id,
		})
		_connect(index, prev_id, tech_id)

	# 3 взаимоисключающих keystone (общая exclusive-группа класса) на концах лучей 0..2.
	for ki in range(3):
		var k_li: int = 17 + ki
		var keystone: Dictionary = (spec["keystones"] as Array)[ki]
		var k_effects: Dictionary = (keystone["effects"] as Dictionary).duplicate(true)
		var k_id := "%s_k%d" % [class_id, ki]
		_add(nodes, index, {
			"id": k_id, "branch": class_id, "tier": 16, "cost": int(ROLE_COSTS["keystone"]),
			"kind": "keystone", "role": "keystone", "title": str(keystone["title"]),
			"desc": "Ключевая звезда «%s»: %s. Активна лишь одна ключевая звезда созвездия; переключение купленных — бесплатно." % [str(keystone["title"]), effects_desc(k_effects)],
			"effects": k_effects, "npos": layout[k_li],
			"pos": _world_pos(class_index, layout[k_li]), "class_affinity": class_id,
			"exclusive_group": "%s_keystones" % class_id,
		})
		_connect(index, "%s_t%d" % [class_id, ki], k_id)

	# 2 скрытые звезды (лучи 1 и 3, середина) — открываются подвигом, не покупкой.
	for hi in range(2):
		var h_li: int = 20 + hi
		var hidden: Dictionary = (spec["hidden"] as Array)[hi]
		var h_effects: Dictionary = (hidden["effects"] as Dictionary).duplicate(true)
		var h_id := "%s_h%d" % [class_id, hi]
		var cond_text := condition_text(str(hidden["metric"]), int(hidden["threshold"]))
		_add(nodes, index, {
			"id": h_id, "branch": class_id, "tier": 14, "cost": 0,
			"kind": "hidden", "role": "hidden", "title": str(hidden["title"]),
			"desc": "Скрытая звезда: %s. Открывается подвигом: %s" % [effects_desc(h_effects), cond_text],
			"effects": h_effects, "npos": layout[h_li],
			"pos": _world_pos(class_index, layout[h_li]), "class_affinity": class_id,
			"condition": {"metric": str(hidden["metric"]), "threshold": int(hidden["threshold"]), "text": cond_text},
			"lore": str(hidden.get("lore", "")),
		})
		_connect(index, "%s_m%d" % [class_id, (1 if hi == 0 else 3) * 3 + 1], h_id)
