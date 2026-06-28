extends RefCounted

# SCRUM-198: контент-данные наград (характеристики/артефакты/level-up),
# вынесены из progression_data.gd при доменном сплите. ProgressionData
# реэкспортит их как const (внешние ссылки ProgressionData.* сохранены).

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
	# SCRUM-500: триггерные (активируемые событием) артефакты — новый под-класс предметов.
	# Маркер `active:true` + поле `trigger` (семантика события). Эффект — суммируемый флаг в
	# mods (НЕ *_multiplier), раскладывается _apply_reward_mods как обычно. Пометка «⚡ Активный»
	# вшита в description (data-driven, без правок карточки). Значения консервативны и ситуативны:
	# лечение/щит/мув-бафф/ситуативный бурст — НЕ постоянный +damage, чтобы не смещать DPS/TTD-гейты.
	{"id": "guardian_bulwark", "title": "Рубеж Стража", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_low_hp", "description": "⚡ Активный — при низком HP: впервые упав ниже 30% HP, делаешь нокбэк-волну и получаешь 1.5с неуязвимости. Перезаряд 18с.", "mods": {"lowhp_guard": 1.0}},
	{"id": "chain_spark", "title": "Цепная Искра", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_kill", "description": "⚡ Активный — при убийстве: 14% шанс взрыва по области у трупа (70% урона).", "mods": {"kill_explosion_chance": 0.14}},
	{"id": "crit_impulse", "title": "Импульс Крита", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_crit", "description": "⚡ Активный — при крите: +35% скорости движения на 1.8с (короткий рывок).", "mods": {"crit_speed_burst": 0.35}},
	{"id": "breather_totem", "title": "Передышка", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_room_clear", "description": "⚡ Активный — при зачистке боя: лечит 8% максимального здоровья.", "mods": {"room_clear_heal_percent": 0.08}},
	{"id": "counterwave_sigil", "title": "Контр-волна", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_take_hit", "description": "⚡ Активный — получив удар: 22% шанс выпустить отталкивающую волну, бьющую врагов рядом (90% полученного урона). Перезаряд 3с.", "mods": {"take_hit_pulse_chance": 0.22}},
	{"id": "soul_harvest", "title": "Сбор Душ", "tier": 3, "cost": 95, "class_affinity": [], "active": true, "trigger": "on_kill", "description": "⚡ Активный — при убийстве: каждое 6-е убийство лечит 3% максимального здоровья (стак сбрасывается между боями).", "mods": {"kill_streak_heal_every": 6.0}},
	{"id": "second_wind", "title": "Второе Дыхание", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_low_hp", "description": "⚡ Активный — при низком HP: пока здоровье ниже 30%, реген восстановления усилен (+5 к регенерации).", "mods": {"lowhp_regen_bonus": 5.0}},
	# SCRUM-619/623: «ключ» к секретному бою конца Акта 3 (Meta.SECRET_ENCOUNTER_ARTIFACT_KEY).
	# Редкий (tier 3), скромный стат-бонус — ценность в разблокировке скрытого контента, не в силе.
	{"id": "rift_key", "title": "Ключ Разлома", "tier": 3, "cost": 95, "class_affinity": [], "description": "+4 Восприятие, +4 Знание. Открывает тайную тропу в конце Акта 3.", "stats": {"perception": 4.0, "knowledge": 4.0}},
]

# SCRUM-618: стартовые модификаторы забега («бооны»). Перед стартом игрок выбирает
# один из 3 случайных боонов — забег начинается чуть иначе, ломая однообразие
# первых волн. Взаимоисключающие; каждый — МЕЛКИЙ набор mods. Ключи mods совпадают
# со словарём дерева умений (player.apply_meta_skill_modifiers): множители
# (*_mult — доли, эффект 1.0+значение) и плоские (*_flat). Боевая «эффективная
# сила» каждого боона держится в пределах +10% (тест start_boons_test); много
# утилити-боонов (золото/опыт/подбор/скорость) с ~нулевым боевым весом.
const START_BOONS := [
	{"id": "glass_edge", "title": "Хрупкое Лезвие",
	 "description": "+8% урона, но −5% максимального HP. Бей сильнее, живи осторожнее.",
	 "mods": {"damage_mult": 0.08, "max_health_mult": -0.05}},
	{"id": "zealot", "title": "Фанатик",
	 "description": "+7% скорости атаки. Чаще бьёшь — плотнее напор.",
	 "mods": {"attack_speed_mult": 0.07}},
	{"id": "veteran", "title": "Ветеран",
	 "description": "+15% опыта за бои. Качаешься быстрее с первых волн.",
	 "mods": {"xp_gain_mult": 0.15}},
	{"id": "scavenger", "title": "Старьёвщик",
	 "description": "+20% золота с врагов. Больше монет — раньше покупки в лавке.",
	 "mods": {"money_gain_mult": 0.20}},
	{"id": "ironhide", "title": "Железная Шкура",
	 "description": "+5% снижения урона. Сглаживает ранние спайки.",
	 "mods": {"defense_flat": 0.05}},
	{"id": "swiftfoot", "title": "Быстрая Поступь",
	 "description": "+3% уклонения и +6 восстановления здоровья отдыхом. Манёвреннее в начале.",
	 "mods": {"dodge_flat": 0.03, "regeneration_flat": 0.6}},
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
