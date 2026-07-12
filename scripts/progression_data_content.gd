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
	# --- SCRUM-960: универсальные СЕМЬИ с роллом редкости (32) ------------------
	# Контракт: docs/design/systems/artifact_system_matrix.md §1-2. Семья помечена
	# rarity_scaling:true и несёт tiers{1,2,3}; тир роллится ПРИ ВЫДАЧЕ (сэмплеры →
	# ProgressionData.materialize_family_offer), сама семья входит в пул с весом 1.0.
	# Корень записи = т1-база (tier/cost/description/stats|mods зеркалят tiers[1])
	# для legacy-читателей (artifact_definition, кодекс, балансовые тулзы).
	# Правило скейла §1.2: базовый стат +2/+4/+7; процентный атрибут ×1.10/×1.18/×1.30;
	# долевой флет +0.10/+0.18/+0.30; плоский флет ≈0.75×/1.25×/2.0× level-up карточки.
	#
	# 8 семей базовых статов (+2/+4/+7):
	{"id": "warrior_charm", "title": "Оберег воина", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Сила.", "stats": {"strength": 2.0},
	 "tiers": {
		1: {"description": "+2 Сила.", "stats": {"strength": 2.0}},
		2: {"description": "+4 Сила.", "stats": {"strength": 4.0}},
		3: {"description": "+7 Сила.", "stats": {"strength": 7.0}},
	}},
	{"id": "fox_boots", "title": "Лисьи сапоги", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Ловкость.", "stats": {"agility": 2.0},
	 "tiers": {
		1: {"description": "+2 Ловкость.", "stats": {"agility": 2.0}},
		2: {"description": "+4 Ловкость.", "stats": {"agility": 4.0}},
		3: {"description": "+7 Ловкость.", "stats": {"agility": 7.0}},
	}},
	{"id": "glass_orb", "title": "Стеклянная сфера", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Интеллект.", "stats": {"intelligence": 2.0},
	 "tiers": {
		1: {"description": "+2 Интеллект.", "stats": {"intelligence": 2.0}},
		2: {"description": "+4 Интеллект.", "stats": {"intelligence": 4.0}},
		3: {"description": "+7 Интеллект.", "stats": {"intelligence": 7.0}},
	}},
	{"id": "hawk_lens", "title": "Линза охоты", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Восприятие.", "stats": {"perception": 2.0},
	 "tiers": {
		1: {"description": "+2 Восприятие.", "stats": {"perception": 2.0}},
		2: {"description": "+4 Восприятие.", "stats": {"perception": 4.0}},
		3: {"description": "+7 Восприятие.", "stats": {"perception": 7.0}},
	}},
	{"id": "ember_core", "title": "Тлеющее ядро", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Энергия.", "stats": {"energy": 2.0},
	 "tiers": {
		1: {"description": "+2 Энергия.", "stats": {"energy": 2.0}},
		2: {"description": "+4 Энергия.", "stats": {"energy": 4.0}},
		3: {"description": "+7 Энергия.", "stats": {"energy": 7.0}},
	}},
	{"id": "old_codex", "title": "Ветхий кодекс", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Знание.", "stats": {"knowledge": 2.0},
	 "tiers": {
		1: {"description": "+2 Знание.", "stats": {"knowledge": 2.0}},
		2: {"description": "+4 Знание.", "stats": {"knowledge": 4.0}},
		3: {"description": "+7 Знание.", "stats": {"knowledge": 7.0}},
	}},
	{"id": "stone_heart", "title": "Каменное сердце", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Выносливость.", "stats": {"endurance": 2.0},
	 "tiers": {
		1: {"description": "+2 Выносливость.", "stats": {"endurance": 2.0}},
		2: {"description": "+4 Выносливость.", "stats": {"endurance": 4.0}},
		3: {"description": "+7 Выносливость.", "stats": {"endurance": 7.0}},
	}},
	{"id": "banner_seed", "title": "Семя знамени", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 Лидерство.", "stats": {"leadership": 2.0},
	 "tiers": {
		1: {"description": "+2 Лидерство.", "stats": {"leadership": 2.0}},
		2: {"description": "+4 Лидерство.", "stats": {"leadership": 4.0}},
		3: {"description": "+7 Лидерство.", "stats": {"leadership": 7.0}},
	}},
	# 24 семьи производных атрибутов (ключ эффекта = ключ level-up карточки, §2.2):
	{"id": "splinter_gloves", "title": "Перчатки осколков", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% урона.", "mods": {"damage_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% урона.", "mods": {"damage_multiplier": 1.10}},
		2: {"description": "+18% урона.", "mods": {"damage_multiplier": 1.18}},
		3: {"description": "+30% урона.", "mods": {"damage_multiplier": 1.30}},
	}},
	{"id": "quickstring", "title": "Быстрая струна", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% скорости атаки.", "mods": {"attack_speed_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% скорости атаки.", "mods": {"attack_speed_multiplier": 1.10}},
		2: {"description": "+18% скорости атаки.", "mods": {"attack_speed_multiplier": 1.18}},
		3: {"description": "+30% скорости атаки.", "mods": {"attack_speed_multiplier": 1.30}},
	}},
	{"id": "sturdy_amulet", "title": "Крепкий амулет", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+15 max HP.", "mods": {"max_health_flat": 15.0},
	 "tiers": {
		1: {"description": "+15 max HP.", "mods": {"max_health_flat": 15.0}},
		2: {"description": "+25 max HP.", "mods": {"max_health_flat": 25.0}},
		3: {"description": "+40 max HP.", "mods": {"max_health_flat": 40.0}},
	}},
	{"id": "fast_boots", "title": "Легкие сапоги", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% скорости движения.", "mods": {"move_speed_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% скорости движения.", "mods": {"move_speed_multiplier": 1.10}},
		2: {"description": "+18% скорости движения.", "mods": {"move_speed_multiplier": 1.18}},
		3: {"description": "+30% скорости движения.", "mods": {"move_speed_multiplier": 1.30}},
	}},
	{"id": "battle_fan", "title": "Боевой веер", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% ширины сектора.", "mods": {"sector_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% ширины сектора.", "mods": {"sector_multiplier": 1.10}},
		2: {"description": "+18% ширины сектора.", "mods": {"sector_multiplier": 1.18}},
		3: {"description": "+30% ширины сектора.", "mods": {"sector_multiplier": 1.30}},
	}},
	{"id": "magnetic_buckle", "title": "Магнитный талисман", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+35 радиуса подбора.", "mods": {"pickup_radius_flat": 35.0},
	 "tiers": {
		1: {"description": "+35 радиуса подбора.", "mods": {"pickup_radius_flat": 35.0}},
		2: {"description": "+55 радиуса подбора.", "mods": {"pickup_radius_flat": 55.0}},
		3: {"description": "+90 радиуса подбора.", "mods": {"pickup_radius_flat": 90.0}},
	}},
	{"id": "iron_scale", "title": "Железная чешуя", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% защиты.", "mods": {"defense_flat": 0.10},
	 "tiers": {
		1: {"description": "+10% защиты.", "mods": {"defense_flat": 0.10}},
		2: {"description": "+18% защиты.", "mods": {"defense_flat": 0.18}},
		3: {"description": "+30% защиты.", "mods": {"defense_flat": 0.30}},
	}},
	{"id": "arcane_prism", "title": "Чародейская призма", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% магического урона.", "mods": {"magic_damage_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% магического урона.", "mods": {"magic_damage_multiplier": 1.10}},
		2: {"description": "+18% магического урона.", "mods": {"magic_damage_multiplier": 1.18}},
		3: {"description": "+30% магического урона.", "mods": {"magic_damage_multiplier": 1.30}},
	}},
	{"id": "ram_horn", "title": "Рог тарана", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% отталкивания.", "mods": {"knockback_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% отталкивания.", "mods": {"knockback_multiplier": 1.10}},
		2: {"description": "+18% отталкивания.", "mods": {"knockback_multiplier": 1.18}},
		3: {"description": "+30% отталкивания.", "mods": {"knockback_multiplier": 1.30}},
	}},
	{"id": "sharp_talisman", "title": "Острый талисман", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% шанса крита.", "mods": {"crit_chance_flat": 0.10},
	 "tiers": {
		1: {"description": "+10% шанса крита.", "mods": {"crit_chance_flat": 0.10}},
		2: {"description": "+18% шанса крита.", "mods": {"crit_chance_flat": 0.18}},
		3: {"description": "+30% шанса крита.", "mods": {"crit_chance_flat": 0.30}},
	}},
	{"id": "executioner_edge", "title": "Грань палача", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% урона крита.", "mods": {"crit_damage_flat": 0.10},
	 "tiers": {
		1: {"description": "+10% урона крита.", "mods": {"crit_damage_flat": 0.10}},
		2: {"description": "+18% урона крита.", "mods": {"crit_damage_flat": 0.18}},
		3: {"description": "+30% урона крита.", "mods": {"crit_damage_flat": 0.30}},
	}},
	{"id": "ghost_ribbon", "title": "Лента призрака", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% уклонения.", "mods": {"dodge_flat": 0.10},
	 "tiers": {
		1: {"description": "+10% уклонения.", "mods": {"dodge_flat": 0.10}},
		2: {"description": "+18% уклонения.", "mods": {"dodge_flat": 0.18}},
		3: {"description": "+30% уклонения.", "mods": {"dodge_flat": 0.30}},
	}},
	{"id": "wide_sigil", "title": "Дальняя печать", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% дальности атаки.", "mods": {"range_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% дальности атаки.", "mods": {"range_multiplier": 1.10}},
		2: {"description": "+18% дальности атаки.", "mods": {"range_multiplier": 1.18}},
		3: {"description": "+30% дальности атаки.", "mods": {"range_multiplier": 1.30}},
	}},
	{"id": "venom_vial", "title": "Флакон отравы", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+2 периодического урона за тик.", "mods": {"dot_damage_flat": 2.0},
	 "tiers": {
		1: {"description": "+2 периодического урона за тик.", "mods": {"dot_damage_flat": 2.0}},
		2: {"description": "+4 периодического урона за тик.", "mods": {"dot_damage_flat": 4.0}},
		3: {"description": "+6 периодического урона за тик.", "mods": {"dot_damage_flat": 6.0}},
	}},
	{"id": "plague_metronome", "title": "Чумной метроном", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+0.2 тика периодического урона в секунду.", "mods": {"dot_speed_flat": 0.2},
	 "tiers": {
		1: {"description": "+0.2 тика периодического урона в секунду.", "mods": {"dot_speed_flat": 0.2}},
		2: {"description": "+0.3 тика периодического урона в секунду.", "mods": {"dot_speed_flat": 0.3}},
		3: {"description": "+0.5 тика периодического урона в секунду.", "mods": {"dot_speed_flat": 0.5}},
	}},
	{"id": "falcon_feather", "title": "Перо сокола", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+70 к скорости снарядов.", "mods": {"projectile_speed_flat": 70.0},
	 "tiers": {
		1: {"description": "+70 к скорости снарядов.", "mods": {"projectile_speed_flat": 70.0}},
		2: {"description": "+110 к скорости снарядов.", "mods": {"projectile_speed_flat": 110.0}},
		3: {"description": "+180 к скорости снарядов.", "mods": {"projectile_speed_flat": 180.0}},
	}},
	{"id": "wide_halo", "title": "Широкий нимб", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% радиуса атак и зон.", "mods": {"aoe_radius_multiplier": 1.10},
	 "tiers": {
		1: {"description": "+10% радиуса атак и зон.", "mods": {"aoe_radius_multiplier": 1.10}},
		2: {"description": "+18% радиуса атак и зон.", "mods": {"aoe_radius_multiplier": 1.18}},
		3: {"description": "+30% радиуса атак и зон.", "mods": {"aoe_radius_multiplier": 1.30}},
	}},
	{"id": "war_banner", "title": "Боевое знамя", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% силы поддержки.", "mods": {"buff_power_flat": 0.10},
	 "tiers": {
		1: {"description": "+10% силы поддержки.", "mods": {"buff_power_flat": 0.10}},
		2: {"description": "+18% силы поддержки.", "mods": {"buff_power_flat": 0.18}},
		3: {"description": "+30% силы поддержки.", "mods": {"buff_power_flat": 0.30}},
	}},
	{"id": "summoners_bell", "title": "Колокольчик призывателя", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+1.5 к силе призывов.", "mods": {"summon_bonus": 1.5},
	 "tiers": {
		1: {"description": "+1.5 к силе призывов.", "mods": {"summon_bonus": 1.5}},
		2: {"description": "+2.5 к силе призывов.", "mods": {"summon_bonus": 2.5}},
		3: {"description": "+4 к силе призывов.", "mods": {"summon_bonus": 4.0}},
	}},
	{"id": "aegis_shard", "title": "Осколок эгиды", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+3 к поглощению урона.", "mods": {"absorb_flat": 3.0},
	 "tiers": {
		1: {"description": "+3 к поглощению урона.", "mods": {"absorb_flat": 3.0}},
		2: {"description": "+5 к поглощению урона.", "mods": {"absorb_flat": 5.0}},
		3: {"description": "+8 к поглощению урона.", "mods": {"absorb_flat": 8.0}},
	}},
	{"id": "troll_blood", "title": "Кровь тролля", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+1 к регенерации в секунду.", "mods": {"regeneration_flat": 1.0},
	 "tiers": {
		1: {"description": "+1 к регенерации в секунду.", "mods": {"regeneration_flat": 1.0}},
		2: {"description": "+1.6 к регенерации в секунду.", "mods": {"regeneration_flat": 1.6}},
		3: {"description": "+2.6 к регенерации в секунду.", "mods": {"regeneration_flat": 2.6}},
	}},
	{"id": "leech_fang", "title": "Клык Пиявки", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+0.75 к лечению от вампиризма и к пределу лечения в секунду.", "mods": {"vampiric_amount_flat": 0.75, "vampiric_heal_per_second_cap": 0.75},
	 "tiers": {
		1: {"description": "+0.75 к лечению от вампиризма и к пределу лечения в секунду.", "mods": {"vampiric_amount_flat": 0.75, "vampiric_heal_per_second_cap": 0.75}},
		2: {"description": "+1.25 к лечению от вампиризма и к пределу лечения в секунду.", "mods": {"vampiric_amount_flat": 1.25, "vampiric_heal_per_second_cap": 1.25}},
		3: {"description": "+2 к лечению от вампиризма и к пределу лечения в секунду.", "mods": {"vampiric_amount_flat": 2.0, "vampiric_heal_per_second_cap": 2.0}},
	}},
	{"id": "thirsty_ruby", "title": "Жаждущий рубин", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% шанса вампиризма.", "mods": {"vampiric_chance_flat": 0.10},
	 "tiers": {
		1: {"description": "+10% шанса вампиризма.", "mods": {"vampiric_chance_flat": 0.10}},
		2: {"description": "+18% шанса вампиризма.", "mods": {"vampiric_chance_flat": 0.18}},
		3: {"description": "+30% шанса вампиризма.", "mods": {"vampiric_chance_flat": 0.30}},
	}},
	{"id": "overcharge_rune", "title": "Руна перегрузки", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
	 "description": "+10% силы ультимейта.", "mods": {"ultimate_flat": 0.10},
	 "tiers": {
		1: {"description": "+10% силы ультимейта.", "mods": {"ultimate_flat": 0.10}},
		2: {"description": "+18% силы ультимейта.", "mods": {"ultimate_flat": 0.18}},
		3: {"description": "+30% силы ультимейта.", "mods": {"ultimate_flat": 0.30}},
	}},
	# --- Сохранённые универсалы (37, artifact_system_matrix §3 — значения без
	# изменений; SCRUM-963: последние англ. title переведены, id стабильны) ---
	{"id": "red_whetstone", "title": "Точильный камень", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Сила, +3 Ловкость.", "stats": {"strength": 3.0, "agility": 3.0}},
	{"id": "star_compass", "title": "Звёздный компас", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Восприятие, +3 Знание.", "stats": {"perception": 3.0, "knowledge": 3.0}},
	{"id": "living_root", "title": "Живой корень", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Выносливость, +3 Энергия.", "stats": {"endurance": 3.0, "energy": 3.0}},
	{"id": "captains_coin", "title": "Монета капитана", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Лидерство, +3 Сила.", "stats": {"leadership": 3.0, "strength": 3.0}},
	{"id": "heavy_totem", "title": "Тяжёлый тотем", "tier": 2, "cost": 55, "class_affinity": [], "description": "+62% максимального HP, -5% скорости движения.", "mods": {"max_health_multiplier": 1.62, "move_speed_multiplier": 0.95}},
	{"id": "silver_coin", "title": "Серебряная монета", "tier": 1, "cost": 30, "class_affinity": [], "description": "+62% золота.", "mods": {"money_gain_multiplier": 1.62}},
	{"id": "survival_manual", "title": "Учебник выживания", "tier": 1, "cost": 30, "class_affinity": [], "description": "+55% опыта.", "mods": {"xp_gain_multiplier": 1.55}},
	{"id": "cracked_shield", "title": "Треснувший щит", "tier": 2, "cost": 55, "class_affinity": [], "description": "+30% защиты, -6% скорости движения.", "mods": {"defense_flat": 0.3, "move_speed_multiplier": 0.94}},
	{"id": "cursed_crown", "title": "Проклятая корона", "tier": 2, "cost": 55, "class_affinity": [], "description": "+75% урона, -18% максимального HP.", "mods": {"damage_multiplier": 1.75, "max_health_multiplier": 0.82}},
	{"id": "fragile_heart", "title": "Хрупкое сердце", "tier": 2, "cost": 55, "class_affinity": [], "description": "+62% скорости атаки, -10% защиты.", "mods": {"attack_speed_multiplier": 1.62, "defense_flat": -0.1}},
	{"id": "greedy_purse", "title": "Жадный кошелек", "tier": 2, "cost": 55, "class_affinity": [], "description": "+112% золота, враги: +37% HP.", "mods": {"money_gain_multiplier": 2.12, "enemy_health_multiplier": 1.37}},
	{"id": "burning_shard", "title": "Горящий осколок", "tier": 2, "cost": 55, "class_affinity": [], "description": "+50% радиуса атак и зон, -20% лечения.", "mods": {"aoe_radius_multiplier": 1.5, "healing_multiplier": 0.8}},
	{"id": "golden_route_mark", "title": "Золотая метка пути", "tier": 2, "cost": 55, "class_affinity": [], "description": "+37% опыта, +37% золота.", "mods": {"xp_gain_multiplier": 1.37, "money_gain_multiplier": 1.37}},
	{"id": "glass_edge", "title": "Стеклянная кромка", "tier": 2, "cost": 55, "class_affinity": [], "description": "+50% урона крита, -8 max HP.", "mods": {"crit_damage_flat": 0.5, "max_health_flat": -8.0}},
	{"id": "sacrifice_seal", "title": "Печать жертвы", "tier": 2, "cost": 55, "class_affinity": [], "description": "+30% шанса крита, -22% максимального HP.", "mods": {"crit_chance_flat": 0.30, "max_health_multiplier": 0.78}},
	{"id": "hungry_amulet", "title": "Голодный амулет", "tier": 2, "cost": 55, "class_affinity": [], "description": "+85% золота, -35% лечения.", "mods": {"money_gain_multiplier": 1.85, "healing_multiplier": 0.65}},
	{"id": "berserk_totem", "title": "Тотем берсерка", "tier": 2, "cost": 55, "class_affinity": [], "description": "+60% урона, -20% скорости движения.", "mods": {"damage_multiplier": 1.60, "move_speed_multiplier": 0.80}},
	{"id": "focus_lens", "title": "Линза фокуса", "tier": 2, "cost": 55, "class_affinity": [], "description": "+70% дальности атаки, -25% радиуса атак и зон.", "mods": {"range_multiplier": 1.70, "aoe_radius_multiplier": 0.75}},
	{"id": "stone_hide", "title": "Каменная шкура", "tier": 2, "cost": 55, "class_affinity": [], "description": "+40% защиты, -25% скорости атаки.", "mods": {"defense_flat": 0.40, "attack_speed_multiplier": 0.75}},
	{"id": "echo_core", "title": "Эхо Разлома", "tier": 3, "cost": 95, "class_affinity": [], "description": "Каждый 5-й удар по врагу вызывает взрыв эха: 80% урона по области вокруг цели.", "mods": {"echo_blast_every": 5.0}},
	{"id": "blood_pact", "title": "Кровавый Рубеж", "tier": 3, "cost": 95, "class_affinity": [], "description": "Пока здоровье ниже 30% — +50% урона. Риск, достойный награды.", "mods": {"low_hp_damage_bonus": 0.5}},
	{"id": "leech_heart", "title": "Сердце Пиявки", "tier": 3, "cost": 95, "class_affinity": [], "description": "Каждое убийство возвращает 2% максимального здоровья.", "mods": {"kill_heal_percent": 0.02}},
	{"id": "thorn_pact", "title": "Договор Шипов", "tier": 3, "cost": 95, "class_affinity": [], "description": "Получив урон, выплескиваешь 200% этого урона на всех врагов рядом.", "mods": {"thorn_reflect_multiplier": 2.0}},
	{"id": "phantom_step", "title": "Призрачный Шаг", "tier": 3, "cost": 95, "class_affinity": [], "description": "Успешный уворот дает +40% скорости движения на 2 секунды.", "mods": {"dodge_rush_bonus": 0.4}},
	# SCRUM-500: триггерные (активируемые событием) артефакты — новый под-класс предметов.
	# Маркер `active:true` + поле `trigger` (семантика события). Эффект — суммируемый флаг в
	# mods (НЕ *_multiplier), раскладывается _apply_reward_mods как обычно. Пометка «⚡ Активный»
	# вшита в description (data-driven, без правок карточки). Значения консервативны и ситуативны:
	# лечение/щит/мув-бафф/ситуативный бурст — НЕ постоянный +damage, чтобы не смещать DPS/TTD-гейты.
	{"id": "field_kit", "title": "Полевой бинт", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_room_clear", "description": "⚡ Активный — при зачистке боя: лечит 5% максимального здоровья.", "mods": {"room_clear_heal_percent": 0.05}},
	{"id": "vital_siphon", "title": "Живой сифон", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_kill", "description": "⚡ Активный — при убийстве: возвращает 1% максимального здоровья.", "mods": {"kill_heal_percent": 0.01}},
	{"id": "powder_charge", "title": "Пороховой заряд", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_kill", "description": "⚡ Активный — при убийстве: 10% шанс взрыва по области у трупа (70% урона).", "mods": {"kill_explosion_chance": 0.10}},
	{"id": "bulwark_echo", "title": "Эхо бастиона", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_take_hit", "description": "⚡ Активный — получив удар: 16% шанс выпустить отталкивающую волну рядом. Перезаряд 3с.", "mods": {"take_hit_pulse_chance": 0.16}},
	{"id": "duelist_spur", "title": "Шпора дуэлянта", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_crit", "description": "⚡ Активный — при крите: +22% скорости движения на 1.8с.", "mods": {"crit_speed_burst": 0.22}},
	{"id": "guardian_bulwark", "title": "Рубеж Стража", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_low_hp", "description": "⚡ Активный — при низком HP: впервые упав ниже 30% HP, делаешь нокбэк-волну и получаешь 1.5с неуязвимости. Перезаряд 18с.", "mods": {"lowhp_guard": 1.0}},
	{"id": "chain_spark", "title": "Цепная Искра", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_kill", "description": "⚡ Активный — при убийстве: 14% шанс взрыва по области у трупа (70% урона).", "mods": {"kill_explosion_chance": 0.14}},
	{"id": "crit_impulse", "title": "Импульс Крита", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_crit", "description": "⚡ Активный — при крите: +35% скорости движения на 1.8с (короткий рывок).", "mods": {"crit_speed_burst": 0.35}},
	{"id": "breather_totem", "title": "Передышка", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_room_clear", "description": "⚡ Активный — при зачистке боя: лечит 8% максимального здоровья.", "mods": {"room_clear_heal_percent": 0.08}},
	{"id": "counterwave_sigil", "title": "Контр-волна", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_take_hit", "description": "⚡ Активный — получив удар: 22% шанс выпустить отталкивающую волну, бьющую врагов рядом (90% полученного урона). Перезаряд 3с.", "mods": {"take_hit_pulse_chance": 0.22}},
	{"id": "soul_harvest", "title": "Сбор Душ", "tier": 3, "cost": 95, "class_affinity": [], "active": true, "trigger": "on_kill", "description": "⚡ Активный — при убийстве: каждое 6-е убийство лечит 3% максимального здоровья (стак сбрасывается между боями).", "mods": {"kill_streak_heal_every": 6.0}},
	{"id": "second_wind", "title": "Второе Дыхание", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_low_hp", "description": "⚡ Активный — при низком HP: пока здоровье ниже 30%, реген восстановления усилен (+5 к регенерации).", "mods": {"lowhp_regen_bonus": 5.0}},
	# Исторический SCRUM-619/623 key-artifact. Секретный бой теперь гейтится
	# максимальным Возвышением; предмет остаётся самостоятельной stat-реликвией.
	{"id": "rift_key", "title": "Ключ Разлома", "tier": 3, "cost": 95, "class_affinity": [], "description": "+4 Восприятие, +4 Знание. Реликвия тайной тропы финального разлома.", "stats": {"perception": 4.0, "knowledge": 4.0}},
	# --- SCRUM-961: классовые артефакты (85 = 17 × 5, artifact_system_matrix §4) ---
	# Все: class_affinity=[class_id], requires_ascension: 5 (гейт §1.4 в сэмплерах),
	# cost = COST_BY_TIER[tier], БЕЗ affinity_mods. Хуки NEW-ключей — player.gd /
	# class_weapon.gd / berserk_weapon.gd / summoner_weapon.gd / sentry_turret.gd /
	# combat_director.gd (место каждого ключа — в строке §4 матрицы).
	# Assassin — Критический танец:
	{"id": "perfect_edge", "title": "Идеальная грань", "tier": 2, "cost": 55, "class_affinity": ["assassin"], "requires_ascension": 5, "description": "+15% шанса крита, +25% урона крита.", "mods": {"crit_chance_flat": 0.15, "crit_damage_flat": 0.25}},
	{"id": "shadow_twin", "title": "Теневой двойник", "tier": 3, "cost": 95, "class_affinity": ["assassin"], "requires_ascension": 5, "active": true, "trigger": "on_crit", "description": "⚡ Активный — при крите: теневой двойник повторяет росчерк у цели (45% урона по области).", "mods": {"crit_shadow_echo_damage": 0.45}},
	{"id": "venom_spool", "title": "Ядовитая катушка", "tier": 2, "cost": 55, "class_affinity": ["assassin"], "requires_ascension": 5, "description": "Яд Ядовитой струны тикает на 2 тика дольше; +5% уклонения.", "mods": {"venom_dot_extra_ticks": 2.0, "dodge_flat": 0.05}},
	{"id": "evasion_shroud", "title": "Покров уклонения", "tier": 2, "cost": 55, "class_affinity": ["assassin"], "requires_ascension": 5, "description": "+8% уклонения; успешный уворот разгоняет (+25% скорости на 2с).", "mods": {"dodge_flat": 0.08, "dodge_rush_bonus": 0.25}},
	{"id": "return_arc_rune", "title": "Руна обратной дуги", "tier": 3, "cost": 95, "class_affinity": ["assassin"], "requires_ascension": 5, "description": "Чакрамы возвращаются по широкой дуге (+35%), обратный проход бьёт больнее (+30%).", "mods": {"boomerang_return_width_mult": 0.35, "boomerang_return_damage_mult": 0.30}},
	# Berserk — Телесный напор:
	{"id": "crimson_grip", "title": "Багровая рукоять", "tier": 3, "cost": 95, "class_affinity": ["berserk"], "requires_ascension": 5, "description": "Удары в ближнем бою копят ярость: до 5 стаков по +2% урона и +1.5% темпа (окно 4с).", "mods": {"rage_hit_stacks": 1.0}},
	{"id": "spectral_axe", "title": "Призрачный топор", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "requires_ascension": 5, "description": "Взмахи топора рождают призрачный повтор по той же дуге (+25% followup-урона).", "mods": {"spectral_followup_bonus": 0.25}},
	{"id": "hammer_weight", "title": "Вес молота", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "requires_ascension": 5, "description": "Удар молота шире (+12%) и полновесно накрывает до 6 целей.", "mods": {"hammer_slam_focus": 1.0}},
	{"id": "blood_roar", "title": "Кровавый рык", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "requires_ascension": 5, "active": true, "trigger": "on_take_hit", "description": "⚡ Активный — получив удар: 30% шанс волны отталкивания и урона. Перезаряд 3с.", "mods": {"take_hit_pulse_chance": 0.30}},
	{"id": "last_onslaught", "title": "Последний натиск", "tier": 3, "cost": 95, "class_affinity": ["berserk"], "requires_ascension": 5, "active": true, "trigger": "on_low_hp", "description": "⚡ Активный — ниже 30% HP: +35% урона и одноразовый щит-волна за порог. Перезаряд 18с.", "mods": {"low_hp_damage_bonus": 0.35, "lowhp_guard": 1.0}},
	# Biologist — Биореакция:
	{"id": "spore_capacitor", "title": "Споровый конденсатор", "tier": 2, "cost": 55, "class_affinity": ["biologist"], "requires_ascension": 5, "description": "Кольца Споровой линзы замедляют на 25% сильнее (сверх базовых 5–20%); +10% магического урона.", "mods": {"spore_slow_power": 0.25, "magic_damage_multiplier": 1.10}},
	{"id": "sample_chain", "title": "Цепь образцов", "tier": 3, "cost": 95, "class_affinity": ["biologist"], "requires_ascension": 5, "description": "Луч Инъектора бьёт на 30% сильнее, бурст анализа шире (+25% радиуса).", "mods": {"sample_beam_full_damage": 1.0}},
	{"id": "symbiote_sheath", "title": "Симбиотическая оболочка", "tier": 2, "cost": 55, "class_affinity": ["biologist"], "requires_ascension": 5, "description": "Стартовый удар семени на 35% сильнее, заражение семени тикает на 2 тика дольше.", "mods": {"symbiote_impact_bonus": 0.35, "symbiote_dot_extra_ticks": 2.0}},
	{"id": "inhibitor_colony", "title": "Колония торможения", "tier": 2, "cost": 55, "class_affinity": ["biologist"], "requires_ascension": 5, "description": "Биоурон вешает стакающееся замедление: 8% за стак, до 3 стаков.", "mods": {"bio_contact_slow": 0.08}},
	{"id": "split_analysis", "title": "Расщепленный анализ", "tier": 3, "cost": 95, "class_affinity": ["biologist"], "requires_ascension": 5, "description": "Первый задетый враг делится спорами: 40% урона двум соседям.", "mods": {"analysis_split_ratio": 0.4}},
	# Thief — Воровская хватка (SCRUM-897: кинжал/дым переописаны под новый кит;
	# лишние прыжки монеты капятся COIN_CHAIN_HARD_CAP=8 в class_weapon.gd):
	{"id": "lucky_coin", "title": "Счастливая монета", "tier": 2, "cost": 55, "class_affinity": ["thief"], "requires_ascension": 5, "description": "Монета скачет на 2 прыжка дольше (максимум 8) и крадёт +1 золото с каждой обворованной цели.", "mods": {"coin_extra_bounces": 2.0, "coin_steal_bonus": 1.0}},
	{"id": "magnetic_purse", "title": "Магнитный кошель", "tier": 2, "cost": 55, "class_affinity": ["thief"], "requires_ascension": 5, "description": "+90 радиуса подбора, +10% золота.", "mods": {"pickup_radius_flat": 90.0, "money_gain_multiplier": 1.10}},
	{"id": "paralyzing_blade", "title": "Парализующее лезвие", "tier": 3, "cost": 95, "class_affinity": ["thief"], "requires_ascension": 5, "description": "Паралич-яд Отравленного Кинжала держит на 0.7с дольше.", "mods": {"backstab_root_duration": 0.7}},
	{"id": "smoke_cache", "title": "Дымный тайник", "tier": 2, "cost": 55, "class_affinity": ["thief"], "requires_ascension": 5, "description": "Дымовое облако на 40% дольше и внутри даёт ещё +12% уклонения.", "mods": {"smoke_duration_mult": 0.40, "smoke_dodge_bonus": 0.12}},
	{"id": "stolen_crest", "title": "Украденный герб", "tier": 3, "cost": 95, "class_affinity": ["thief"], "requires_ascension": 5, "description": "До конца забега в пул наград попадают 2 случайных артефакта чужих классов.", "mods": {"cross_class_artifact_slots": 2.0}},
	# Guitarist — Сценический контроль:
	{"id": "overdrive_pick", "title": "Медиатор овердрайва", "tier": 3, "cost": 95, "class_affinity": ["guitarist"], "requires_ascension": 5, "description": "Пока рифф-серия активна: +10% урона и +12% скорости атаки.", "mods": {"riff_streak_damage_bonus": 0.10, "riff_streak_attack_speed_bonus": 0.12}},
	{"id": "bass_resonator", "title": "Басовый резонатор", "tier": 2, "cost": 55, "class_affinity": ["guitarist"], "requires_ascension": 5, "description": "Бас-аура шире (+30%); +8% скорости атаки.", "mods": {"guitar_aura_radius_mult": 0.30, "attack_speed_multiplier": 1.08}},
	{"id": "stage_amplifier", "title": "Сценический усилитель", "tier": 2, "cost": 55, "class_affinity": ["guitarist"], "requires_ascension": 5, "description": "Усилители живут на 2.5с дольше, предел деплоя выше (до 4).", "mods": {"amp_lifetime_bonus": 2.5, "amp_cap_bonus": 1.0}},
	{"id": "feedback_loop", "title": "Петля фидбэка", "tier": 3, "cost": 95, "class_affinity": ["guitarist"], "requires_ascension": 5, "description": "Пульсы усилителей стакают резонанс: +5% входящего урона за стак, до 3.", "mods": {"amp_resonance_vuln": 0.05}},
	{"id": "rhythm_counter", "title": "Счетчик ритма", "tier": 2, "cost": 55, "class_affinity": ["guitarist"], "requires_ascension": 5, "description": "Каждый 4-й гитарный каст срабатывает дважды (повтор на 55% урона).", "mods": {"rhythm_echo_every": 4.0}},
	# Doctor — Клинический drain:
	{"id": "surgical_oath", "title": "Хирургическая клятва", "tier": 2, "cost": 55, "class_affinity": ["doctor"], "requires_ascension": 5, "description": "+20% лечения от оружия, +2 к пределу drain-лечения в секунду.", "mods": {"healing_multiplier": 1.20, "drain_heal_per_second_cap": 2.0}},
	{"id": "bonesaw_teeth", "title": "Зубья костяной пилы", "tier": 2, "cost": 55, "class_affinity": ["doctor"], "requires_ascension": 5, "description": "Костяная пила режет на 30% шире и возвращает +8% урона здоровьем.", "mods": {"saw_arc_width_mult": 0.30, "saw_heal_ratio_bonus": 0.08}},
	{"id": "plague_carrier", "title": "Чумной носитель", "tier": 3, "cost": 95, "class_affinity": ["doctor"], "requires_ascension": 5, "description": "Смерть заражённого передаёт чуму соседям (2.2с); +0.25 тика в секунду.", "mods": {"dot_death_spread_duration": 2.2, "dot_speed_flat": 0.25}},
	{"id": "restorative_vapor", "title": "Восстановительный пар", "tier": 3, "cost": 95, "class_affinity": ["doctor"], "requires_ascension": 5, "description": "Зелье оставляет паровую зону: жжёт врагов и подлечивает Доктора.", "mods": {"restore_vapor_power": 1.0}},
	{"id": "triage_protocol", "title": "Протокол триажа", "tier": 2, "cost": 55, "class_affinity": ["doctor"], "requires_ascension": 5, "active": true, "trigger": "on_low_hp", "description": "⚡ Активный — ниже 30% HP: следующий лечащий импульс оружия усилен ×2.5. Перезаряд 12с.", "mods": {"triage_heal_burst": 1.5}},
	# Druid — Командование стаей:
	{"id": "spirit_pack_banner", "title": "Знамя духовной стаи", "tier": 2, "cost": 55, "class_affinity": ["druid"], "requires_ascension": 5, "description": "+20% силы поддержки; духи бьют на 15% сильнее.", "mods": {"buff_power_flat": 0.20, "pet_damage_mult": 0.15}},
	{"id": "wolf_call", "title": "Зов волков", "tier": 3, "cost": 95, "class_affinity": ["druid"], "requires_ascension": 5, "description": "+2 к силе призывов; стая склоняется к волкам, ближние духи рвут на 20% сильнее.", "mods": {"summon_bonus": 2.0, "pack_wolf_bias": 1.0}},
	{"id": "blue_totem", "title": "Голубой тотем", "tier": 2, "cost": 55, "class_affinity": ["druid"], "requires_ascension": 5, "description": "Вороний тотем пульсирует злее (+25%) и чаще; +10% магического урона.", "mods": {"raven_pulse_bonus": 0.25, "magic_damage_multiplier": 1.10}},
	{"id": "briar_seal", "title": "Печать терновника", "tier": 2, "cost": 55, "class_affinity": ["druid"], "requires_ascension": 5, "description": "Терновые зоны замедляют на 20%; +0.25 тика периодического урона в секунду.", "mods": {"briar_slow_power": 0.20, "dot_speed_flat": 0.25}},
	{"id": "pack_alpha", "title": "Альфа стаи", "tier": 3, "cost": 95, "class_affinity": ["druid"], "requires_ascension": 5, "description": "+40 радиуса аур, +15% силы поддержки, +1.5 к силе призывов.", "mods": {"aura_radius_flat": 40.0, "buff_power_flat": 0.15, "summon_bonus": 1.5}},
	# Engineer — Мастерская приказов:
	{"id": "turret_magazine", "title": "Магазин турели", "tier": 2, "cost": 55, "class_affinity": ["engineer"], "requires_ascension": 5, "description": "+6 выстрелов к боезапасу каждой турели (базовые 15).", "mods": {"sentry_magazine_bonus": 6.0}},
	{"id": "drone_gyroscope", "title": "Гироскоп дрона", "tier": 2, "cost": 55, "class_affinity": ["engineer"], "requires_ascension": 5, "description": "+20% скорости орбиты дронов; устройства работают на 12% чаще.", "mods": {"drone_orbit_speed_bonus": 0.20, "device_attack_speed_bonus": 0.12}},
	{"id": "mine_satchel", "title": "Минная сумка", "tier": 3, "cost": 95, "class_affinity": ["engineer"], "requires_ascension": 5, "description": "+2 к пределу живых мин (базовые 6).", "mods": {"mine_cap_bonus": 2.0}},
	{"id": "field_blueprint", "title": "Полевой чертеж", "tier": 3, "cost": 95, "class_affinity": ["engineer"], "requires_ascension": 5, "description": "Каждые 6 Лидерства: +1 к пределу турелей и мин, +2 выстрела турели.", "mods": {"blueprint_leadership_scaling": 1.0}},
	{"id": "salvage_core", "title": "Ядро утилизации", "tier": 2, "cost": 55, "class_affinity": ["engineer"], "requires_ascension": 5, "description": "Отжившие и подорванные устройства возвращают 35% перезарядки.", "mods": {"salvage_refund_ratio": 0.35}},
	# Ranger — Сторожевой лук (SCRUM-909..913: кит редизайнут — сплит-болт,
	# пирсинг-конус, перманентный капкан с параличом; артефакты дополняют базу):
	{"id": "impact_string", "title": "Ударная тетива", "tier": 2, "cost": 55, "class_affinity": ["ranger"], "requires_ascension": 5, "description": "+35% отталкивания: попадания лука отбрасывают врагов от Рейнджера ещё дальше.", "mods": {"knockback_multiplier": 1.35}},
	{"id": "moon_splitter", "title": "Лунный расщепитель", "tier": 3, "cost": 95, "class_affinity": ["ranger"], "requires_ascension": 5, "description": "Болт Лунного арбалета расщепляется в +2 дополнительные цели (всего 6) с тем же уроном.", "mods": {"moon_split_targets": 2.0}},
	{"id": "storm_piercer", "title": "Грозовой пробойник", "tier": 2, "cost": 55, "class_affinity": ["ranger"], "requires_ascension": 5, "description": "+2 пробития заряженным выстрелам, +15% дальности.", "mods": {"charged_shot_extra_pierce": 2.0, "range_multiplier": 1.15}},
	{"id": "root_snare", "title": "Корневой капкан", "tier": 3, "cost": 95, "class_affinity": ["ranger"], "requires_ascension": 5, "description": "+2 к пределу живых капканов (всего 8), паралич захлопнутых дольше на 0.6с.", "mods": {"trap_cap_bonus": 2.0, "trap_paralysis_bonus": 0.6}},
	{"id": "hunters_mark", "title": "Метка охотника", "tier": 2, "cost": 55, "class_affinity": ["ranger"], "requires_ascension": 5, "description": "Отброшенные и обездвиженные враги получают +25% урона.", "mods": {"hunter_mark_bonus": 0.25}},
	# Robot — Бронеконтур:
	{"id": "armor_protocol", "title": "Бронепротокол", "tier": 2, "cost": 55, "class_affinity": ["robot"], "requires_ascension": 5, "description": "+5 поглощения урона, +8% защиты.", "mods": {"absorb_flat": 5.0, "defense_flat": 0.08}},
	{"id": "anchor_core", "title": "Ядро якоря", "tier": 2, "cost": 55, "class_affinity": ["robot"], "requires_ascension": 5, "description": "Магнитный якорь шире (+25%) и стягивает рядовых врагов на 35% сильнее.", "mods": {"magnet_radius_mult": 0.25, "anchor_pull_power": 0.35}},
	{"id": "press_calibrator", "title": "Калибратор пресса", "tier": 2, "cost": 55, "class_affinity": ["robot"], "requires_ascension": 5, "description": "Коридор Пресса на 30% шире и прижимает врагов к осевой линии.", "mods": {"press_corridor_bonus": 1.0}},
	{"id": "reactor_chronometer", "title": "Реакторный хронометр", "tier": 3, "cost": 95, "class_affinity": ["robot"], "requires_ascension": 5, "description": "Выбросы реактора идут плавной ротацией без мёртвых секторов; +10% скорости атаки.", "mods": {"reactor_smooth_rotation": 1.0, "attack_speed_multiplier": 1.10}},
	{"id": "repair_subroutine", "title": "Ремонтная подпрограмма", "tier": 3, "cost": 95, "class_affinity": ["robot"], "requires_ascension": 5, "active": true, "trigger": "on_take_hit", "description": "⚡ Активный — поглощённый бронёй урон копит заряд: при 8% max HP — +3 поглощения на 5с.", "mods": {"repair_charge_ratio": 0.5}},
	# Knight — Возмездие (SCRUM-920..923):
	{"id": "rebound_plate", "title": "Отбойная пластина", "tier": 2, "cost": 55, "class_affinity": ["knight"], "requires_ascension": 5, "description": "+40% отталкивания ударов по рядовым врагам.", "mods": {"knockback_multiplier": 1.40}},
	# SCRUM-921: база копья теперь сама колет трижды (лево-центр-право) — артефакт
	# переосмыслен в «Веер уколов»: два ДОПОЛНИТЕЛЬНЫХ крайних укола ±32° (55%).
	{"id": "triple_thrust", "title": "Веер уколов", "tier": 3, "cost": 95, "class_affinity": ["knight"], "requires_ascension": 5, "description": "Веер копья шире: два дополнительных крайних укола (55%) под ±32°.", "mods": {"spear_triple_thrust": 1.0}},
	{"id": "tower_slam", "title": "Башенный удар", "tier": 2, "cost": 55, "class_affinity": ["knight"], "requires_ascension": 5, "description": "Конус Башенного щита на 20% шире; +20% отталкивания.", "mods": {"sector_multiplier": 1.20, "knockback_multiplier": 1.20}},
	{"id": "holy_chain", "title": "Святая цепь", "tier": 3, "cost": 95, "class_affinity": ["knight"], "requires_ascension": 5, "description": "Спираль Кистеня раскручивается: +12% радиуса за каст подряд, до +36%.", "mods": {"flail_spiral_growth": 1.0}},
	{"id": "vanguard_oath", "title": "Авангардная клятва", "tier": 2, "cost": 55, "class_affinity": ["knight"], "requires_ascension": 5, "description": "+5% защиты; в стойке (неподвижность) — ещё +10%.", "mods": {"bastion_defense_bonus": 0.10, "defense_flat": 0.05}},
	# Priest — Священная формула:
	{"id": "prayer_beads", "title": "Четки молитвы", "tier": 2, "cost": 55, "class_affinity": ["priest"], "requires_ascension": 5, "active": true, "trigger": "on_battle_start", "description": "⚡ Активный — первые 6с боя: +30% магического урона и исходящего лечения.", "mods": {"prayer_opening_power": 0.30}},
	{"id": "reliquary_salvo", "title": "Реликварный залп", "tier": 3, "cost": 95, "class_affinity": ["priest"], "requires_ascension": 5, "description": "Реликварий ускоряет литанию: бурсты чаще (−25% интервала), каждая вспышка сильнее (+20%).", "mods": {"reliquary_barrage_mode": 1.0}},
	{"id": "censer_vow", "title": "Обет кадила", "tier": 2, "cost": 55, "class_affinity": ["priest"], "requires_ascension": 5, "description": "Кадило пульсирует реже, но шире (+45% радиуса) и больнее (+35%).", "mods": {"censer_vow_mode": 1.0}},
	{"id": "twin_bell", "title": "Двойной колокол", "tier": 3, "cost": 95, "class_affinity": ["priest"], "requires_ascension": 5, "description": "Эхо-звон: оба взрыва колокола повторяются через мгновение (45% урона), эхо тоже не бьет одного врага дважды.", "mods": {"chime_twin_toll": 1.0}},
	{"id": "martyr_shroud", "title": "Покров мученика", "tier": 2, "cost": 55, "class_affinity": ["priest"], "requires_ascension": 5, "active": true, "trigger": "on_low_hp", "description": "⚡ Активный — ниже 30% HP: +12% защиты и +3 к регенерации.", "mods": {"lowhp_defense_bonus": 0.12, "lowhp_regen_bonus": 3.0}},
	# Sniper — Точная ликвидация:
	{"id": "longshot_scope", "title": "Дальнобойный прицел", "tier": 3, "cost": 95, "class_affinity": ["sniper"], "requires_ascension": 5, "description": "Чем дальше цель, тем больнее выстрел: +3% урона за 100px, кап +30%.", "mods": {"longshot_scaling": 1.0}},
	{"id": "deadeye_round", "title": "Патрон мертвого глаза", "tier": 3, "cost": 95, "class_affinity": ["sniper"], "requires_ascension": 5, "description": "Винтовка предпочитает дальнюю цель; в конце линии терминальный взрыв (45%).", "mods": {"deadeye_terminal_blast": 0.45}},
	{"id": "spotter_mark", "title": "Метка наводчика", "tier": 2, "cost": 55, "class_affinity": ["sniper"], "requires_ascension": 5, "description": "Зона наводчика ложится на 35% быстрее и бьёт дополнительным ударом.", "mods": {"spotter_fast_mark": 1.0}},
	{"id": "shatter_drum", "title": "Барабан осколков", "tier": 2, "cost": 55, "class_affinity": ["sniper"], "requires_ascension": 5, "description": "+2 осколка Осколочным патронам по ближайшим траекториям.", "mods": {"shatter_extra_splits": 2.0}},
	{"id": "clean_line", "title": "Чистая линия", "tier": 2, "cost": 55, "class_affinity": ["sniper"], "requires_ascension": 5, "description": "+120 к скорости снарядов, +12% дальности атаки.", "mods": {"projectile_speed_flat": 120.0, "range_multiplier": 1.12}},
	# Soldier — Двойное действие (описания под редизайн SCRUM-936/937/938):
	{"id": "second_volley", "title": "Второй залп", "tier": 3, "cost": 95, "class_affinity": ["soldier"], "requires_ascension": 5, "description": "12% шанс повторить попадание аркебузы ослабленным залпом (50% урона).", "mods": {"duplicate_hit_chance": 0.12}},
	{"id": "arquebus_shrapnel", "title": "Шрапнель аркебузы", "tier": 2, "cost": 55, "class_affinity": ["soldier"], "requires_ascension": 5, "description": "Осколочная зона взрывной пули шире (+25%), соседям основной цели прилетает больше.", "mods": {"arquebus_shrapnel_bonus": 1.0}},
	{"id": "long_fuse", "title": "Длинный фитиль", "tier": 2, "cost": 55, "class_affinity": ["soldier"], "requires_ascension": 5, "description": "Фитиль горит на 0.35с дольше: взрыв +50% урона и +10% радиуса.", "mods": {"long_fuse_bonus": 0.5}},
	{"id": "bayonet_trigger", "title": "Спуск штыка", "tier": 2, "cost": 55, "class_affinity": ["soldier"], "requires_ascension": 5, "description": "+35% к шансу авто-выстрела штыка по цели за конусом (70% урона).", "mods": {"bayonet_shot_chance": 0.35}},
	{"id": "battle_doctrine", "title": "Боевой устав", "tier": 3, "cost": 95, "class_affinity": ["soldier"], "requires_ascension": 5, "description": "Дубли по уставу: работают на пулях, гранатах и штыке; +6% к шансу дубля.", "mods": {"duplicate_hit_universal": 1.0, "duplicate_hit_chance": 0.06}},
	# Dark Mage — Темная формула (SCRUM-939/941: chain_wand и mirror_page
	# репозиционированы — цепь и зеркало теперь БАЗА оружий нового кита):
	{"id": "chain_wand", "title": "Цепная палочка", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "requires_ascension": 5, "description": "Цепь палочки прыгает на одну цель дальше, а бурсты попаданий бьют на 15% сильнее.", "mods": {"wand_extra_chain": 1.0, "wand_burst_bonus": 0.15}},
	{"id": "curse_font", "title": "Купель проклятий", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "requires_ascension": 5, "description": "+3 урона проклятия за тик, +0.35 тика в секунду.", "mods": {"dot_damage_flat": 3.0, "dot_speed_flat": 0.35}},
	{"id": "mirror_page", "title": "Зеркальная страница", "tier": 3, "cost": 95, "class_affinity": ["dark_mage"], "requires_ascension": 5, "description": "Оба взрыва Книги тьмы отдаются эхом (45% урона) через мгновение.", "mods": {"book_mirror_echo": 0.45}},
	{"id": "void_hunger", "title": "Голод пустоты", "tier": 3, "cost": 95, "class_affinity": ["dark_mage"], "requires_ascension": 5, "description": "Проклятые смерти голодны: DoT перекидывается на соседей погибшего (2.5с).", "mods": {"dot_death_spread_duration": 2.5}},
	{"id": "black_bargain", "title": "Черная сделка", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "requires_ascension": 5, "description": "+4 урона DoT за тик, +0.25 тика в секунду; −15% максимального HP.", "mods": {"dot_damage_flat": 4.0, "dot_speed_flat": 0.25, "max_health_multiplier": 0.85}},
	# Chemist — Алхимическая цепь:
	{"id": "volatile_dust", "title": "Летучая пыль", "tier": 2, "cost": 55, "class_affinity": ["chemist"], "requires_ascension": 5, "description": "Пыль ещё летучее: касты на 22% быстрее, прямой взрыв +25%.", "mods": {"volatile_powder_mode": 1.0}},
	{"id": "acid_catalyst", "title": "Кислотный катализатор", "tier": 3, "cost": 95, "class_affinity": ["chemist"], "requires_ascension": 5, "description": "Кислота цепляется глубже: кап вечных кислотных зарядов на цель +3 (до 8 луж).", "mods": {"acid_charge_stacks": 1.0}},
	{"id": "clear_acid", "title": "Прозрачная кислота", "tier": 1, "cost": 30, "class_affinity": ["chemist"], "requires_ascension": 5, "description": "Лужи кислоты прозрачны и читаемы, с яркой кромкой; держатся на 25% дольше.", "mods": {"pool_duration_mult": 0.25}},
	{"id": "tank_homunculus", "title": "Гомункул-танк", "tier": 3, "cost": 95, "class_affinity": ["chemist"], "requires_ascension": 5, "description": "Гомункул-здоровяк: +60% HP танка; +25% силы гомункулов.", "mods": {"homunculus_taunt": 1.0, "homunculus_power_mult": 0.25}},
	{"id": "reactor_homunculus", "title": "Гомункул-реактор", "tier": 3, "cost": 95, "class_affinity": ["chemist"], "requires_ascension": 5, "description": "Второй гомункул — неуязвимый реактор: не бьёт, но волнами копит DoT (до 3 стаков).", "mods": {"homunculus_reactor": 1.0}},
	# Elementalist — Стихийная формула (SCRUM-948..950: эффекты поверх нового кита —
	# квадрат/полнокартный X/тяжёлый метеор в базе; ключи mods сохранены):
	{"id": "fourth_ring", "title": "Четвертое кольцо", "tier": 3, "cost": 95, "class_affinity": ["elementalist"], "requires_ascension": 5, "description": "Земляное ядро укрепляет квадрат: физический канал на 60% сильнее и +1 тик поля.", "mods": {"elemental_orb_extra_count": 1.0, "earth_orb_mode": 1.0}},
	{"id": "prismatic_cross", "title": "Призматический крест", "tier": 3, "cost": 95, "class_affinity": ["elementalist"], "requires_ascension": 5, "description": "К диагоналям X добавляется крест «+» на 60% силы луча; +20% радиуса центра.", "mods": {"prism_cross_pierce": 1.0, "prism_rift_radius_mult": 0.20}},
	{"id": "meteor_heart", "title": "Сердце метеора", "tier": 2, "cost": 55, "class_affinity": ["elementalist"], "requires_ascension": 5, "description": "Метеор реже (+45% интервала), но центральный удар +55% и зона догорает на 2 тика дольше.", "mods": {"meteor_heart_mode": 1.0}},
	{"id": "mana_overflow", "title": "Переполнение магии", "tier": 2, "cost": 55, "class_affinity": ["elementalist"], "requires_ascension": 5, "description": "+18% магического урона, +12% заряда ультимейта.", "mods": {"magic_damage_multiplier": 1.18, "ult_charge_multiplier": 1.12}},
	{"id": "elemental_recoil", "title": "Стихийный отдачник", "tier": 2, "cost": 55, "class_affinity": ["elementalist"], "requires_ascension": 5, "description": "Стихийные области отталкивают монстров прочь от заклинателя; +15% отталкивания.", "mods": {"elemental_repulse_power": 90.0, "knockback_multiplier": 1.15}},
]

# SCRUM-618: стартовые модификаторы забега («бооны»). Перед стартом игрок выбирает
# один из 3 случайных боонов — забег начинается чуть иначе, ломая однообразие
# первых волн. Взаимоисключающие; каждый — МЕЛКИЙ набор mods. Ключи mods совпадают
# со словарём дерева умений (player.apply_meta_skill_modifiers): множители
# (*_mult — доли, эффект 1.0+значение) и плоские (*_flat). Боевая «эффективная
# сила» каждого боона держится в пределах +10% (тест start_boons_test); много
# утилити-боонов (золото/опыт/подбор/скорость) с ~нулевым боевым весом.
const START_BOONS := [
	{"id": "boon_glass_edge", "title": "Хрупкое Лезвие",
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

# SCRUM-695: каждая награда несёт каноничный "attr" (см. CharacterData.ATTRIBUTE_REGISTRY).
# Релевантность для класса берётся из ATTRIBUTE_RELEVANCE по этому attr, а не косвенно
# через 8 базовых характеристик. Описания — человекочитаемые единицы (никаких «+0.18
# силы поддержки» / «flat absorption»); численное before→after показывает карточка через
# _level_up_reward_preview в ui_screens.gd.
# FAN-1034: 24 → 19 карт. Удалены мёртвые оси (скорость снарядов — только косметика
# задержки импакта; отталкивание — боссы/элитки иммунны; ширина сектора — no-op для
# 46/51 оружий), слиты пары вампиризма и dot damage+speed, а class_affinity гейтит
# профильные карты (magic_focus/buff_power) от классов, где ось мертва. Механики
# (projectile_speed, knockback, sector, dot_speed, vampiric_*) в derived-слое живут —
# их продолжают кормить статы, артефакты и мета-древо.
const LEVEL_UP_REWARDS := [
	{"id": "damage_up", "attr": "damage", "title": "+Урон", "description": "+15% к урону.", "kind": "upgrade", "mods": {"damage_multiplier": 1.15}},
	{"id": "attack_speed_up", "attr": "attack_speed", "title": "+Скорость атаки", "description": "+12% к скорости атаки.", "kind": "upgrade", "mods": {"attack_speed_multiplier": 1.12}},
	{"id": "max_hp_up", "attr": "max_health", "title": "+Макс. здоровье", "description": "+18 к максимальному здоровью.", "kind": "upgrade", "mods": {"max_health_flat": 18.0}},
	{"id": "move_speed_up", "attr": "move_speed", "title": "+Скорость движения", "description": "+10% к скорости движения.", "kind": "upgrade", "mods": {"move_speed_multiplier": 1.10}},
	{"id": "aoe_radius_up", "attr": "aoe_radius", "title": "+Область поражения", "description": "+15% к радиусу атак, взрывов, аур и зон.", "kind": "upgrade", "mods": {"aoe_radius_multiplier": 1.15}},
	{"id": "pickup_radius_up", "attr": "pickup_radius", "title": "+Радиус подбора", "description": "+45 к радиусу подбора опыта и золота.", "kind": "upgrade", "mods": {"pickup_radius_flat": 45.0}},
	{"id": "defense_up", "attr": "defense", "title": "+Защита", "description": "+10% к снижению входящего урона.", "kind": "upgrade", "mods": {"defense_flat": 0.10}},
	{"id": "magic_focus_up", "attr": "magic_focus", "title": "+Маг. урон", "description": "+14% только к магическому урону.", "kind": "upgrade", "mods": {"magic_damage_multiplier": 1.14},
		"class_affinity": ["elementalist", "priest", "biologist", "dark_mage", "guitarist", "doctor", "chemist", "druid"]},
	{"id": "crit_chance_up", "attr": "crit_chance", "title": "+Шанс крита", "description": "+7% к шансу критического удара.", "kind": "upgrade", "mods": {"crit_chance_flat": 0.07}},
	{"id": "crit_damage_up", "attr": "crit_damage", "title": "+Урон крита", "description": "+35% к множителю критического урона.", "kind": "upgrade", "mods": {"crit_damage_flat": 0.35}},
	{"id": "dodge_up", "attr": "dodge", "title": "+Уклонение", "description": "+8% к шансу уклонения.", "kind": "upgrade", "mods": {"dodge_flat": 0.08}},
	{"id": "range_up", "attr": "range", "title": "+Дальность атаки", "description": "+12% к дальности атаки.", "kind": "upgrade", "mods": {"range_multiplier": 1.12}},
	{"id": "dot_damage_up", "attr": "dot_damage", "title": "+Периодический урон", "description": "+3 урона тикам яда/горения/кровотечения и +0.15 к их темпу. Классы без эффекта получают малое кровотечение.", "kind": "upgrade", "mods": {"dot_damage_flat": 3.0, "dot_speed_flat": 0.15}},
	{"id": "buff_power_up", "attr": "buff_power", "title": "+Сила поддержки", "description": "+18% к силе аур, кличей и усилений поддержки.", "kind": "upgrade", "mods": {"buff_power_flat": 0.18},
		"class_affinity": ["priest", "druid", "guitarist", "engineer", "assassin", "dark_mage", "elementalist"]},
	{"id": "summon_amount_up", "attr": "summon_amount", "title": "+Сила призыва", "description": "+2 к силе призывов. Непризывные классы получают эхо-оружие или спутника.", "kind": "upgrade", "mods": {"summon_bonus": 2.0}},
	{"id": "absorb_up", "attr": "absorb", "title": "+Поглощение", "description": "+4 к поглощению урона: каждый входящий удар слабее на 4.", "kind": "upgrade", "mods": {"absorb_flat": 4.0}},
	{"id": "regeneration_up", "attr": "regeneration", "title": "+Регенерация", "description": "+1.3 здоровья в секунду к восстановлению.", "kind": "upgrade", "mods": {"regeneration_flat": 1.3}},
	{"id": "vampiric_up", "attr": "vampiric", "title": "+Вампиризм", "description": "+5% к шансу вылечиться при ударе, +0.8 к лечению и его пределу в секунду.", "kind": "upgrade", "mods": {"vampiric_amount_flat": 0.8, "vampiric_chance_flat": 0.05, "vampiric_heal_per_second_cap": 0.8}},
	{"id": "ultimate_power_up", "attr": "ultimate_power", "title": "+Сила ультимейта", "description": "+12% к силе эффектов классового ультимейта.", "kind": "upgrade", "mods": {"ultimate_flat": 0.12}},
]
