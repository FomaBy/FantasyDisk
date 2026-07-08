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
	{"id": "hawk_lens", "title": "Линза ястреба", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
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
	{"id": "fast_boots", "title": "Быстрые сапоги", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
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
	{"id": "magnetic_buckle", "title": "Магнитная пряжка", "rarity_scaling": true, "tier": 1, "cost": 30, "class_affinity": [],
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
	# --- Сохранённые универсалы (37, artifact_system_matrix §3 — без изменений) ---
	# --- + легаси классовые (16 записей blood_sigil..split_core — удаляет SCRUM-961) ---
	{"id": "red_whetstone", "title": "Red Whetstone", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Сила, +3 Ловкость.", "stats": {"strength": 3.0, "agility": 3.0}},
	{"id": "star_compass", "title": "Star Compass", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Восприятие, +3 Знание.", "stats": {"perception": 3.0, "knowledge": 3.0}},
	{"id": "living_root", "title": "Living Root", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Выносливость, +3 Энергия.", "stats": {"endurance": 3.0, "energy": 3.0}},
	{"id": "captains_coin", "title": "Captain's Coin", "tier": 1, "cost": 30, "class_affinity": [], "description": "+3 Лидерство, +3 Сила.", "stats": {"leadership": 3.0, "strength": 3.0}},
	{"id": "heavy_totem", "title": "Heavy Totem", "tier": 2, "cost": 55, "class_affinity": [], "description": "+62% максимального HP, -5% скорости движения.", "mods": {"max_health_multiplier": 1.62, "move_speed_multiplier": 0.95}},
	{"id": "blood_sigil", "title": "Кровавая печать", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "description": "+20 max HP. Берсерк: +45% урона.", "mods": {"max_health_flat": 20.0}, "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "void_ink", "title": "Чернила пустоты", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "description": "+50% радиуса атак и зон. Темный маг: +50% урона.", "mods": {"aoe_radius_multiplier": 1.5}, "affinity_mods": {"damage_multiplier": 1.5}},
	{"id": "echo_pick", "title": "Медиатор эха", "tier": 2, "cost": 55, "class_affinity": ["guitarist"], "description": "+40% отталкивания. Гитарист: +45% скорости атаки.", "mods": {"knockback_multiplier": 1.4}, "affinity_mods": {"attack_speed_multiplier": 1.45}},
	{"id": "silver_coin", "title": "Серебряная монета", "tier": 1, "cost": 30, "class_affinity": [], "description": "+62% золота.", "mods": {"money_gain_multiplier": 1.62}},
	{"id": "survival_manual", "title": "Учебник выживания", "tier": 1, "cost": 30, "class_affinity": [], "description": "+55% опыта.", "mods": {"xp_gain_multiplier": 1.55}},
	{"id": "cracked_shield", "title": "Треснувший щит", "tier": 2, "cost": 55, "class_affinity": [], "description": "+30% защиты, -6% скорости движения.", "mods": {"defense_flat": 0.3, "move_speed_multiplier": 0.94}},
	{"id": "jagged_blade", "title": "Зазубренное лезвие", "tier": 1, "cost": 30, "class_affinity": ["berserk"], "description": "Берсерк: +45% урона.", "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "heavy_grip", "title": "Тяжелая рукоять", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "description": "-8% скорости атаки. Берсерк: +60% отталкивания.", "mods": {"attack_speed_multiplier": 0.92}, "affinity_mods": {"knockback_multiplier": 1.6}},
	{"id": "war_belt", "title": "Боевой ремень", "tier": 1, "cost": 30, "class_affinity": ["berserk"], "description": "Берсерк: +55% радиуса атак.", "affinity_mods": {"aoe_radius_multiplier": 1.55}},
	{"id": "warriors_rage", "title": "Ярость воина", "tier": 2, "cost": 55, "class_affinity": ["berserk"], "description": "-10% максимального HP. Берсерк: +50% урона.", "mods": {"max_health_multiplier": 0.9}, "affinity_mods": {"damage_multiplier": 1.5}},
	{"id": "dark_crystal", "title": "Темный кристалл", "tier": 1, "cost": 30, "class_affinity": ["dark_mage"], "description": "Темный маг: +45% урона.", "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "ash_page", "title": "Пепельная страница", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "description": "+25% урона. Темный маг: +45% радиуса атак и зон.", "mods": {"damage_multiplier": 1.25}, "affinity_mods": {"aoe_radius_multiplier": 1.45}},
	{"id": "skull_resonator", "title": "Черепной резонатор", "tier": 1, "cost": 30, "class_affinity": ["dark_mage"], "description": "Темный маг: +50% дальности атаки.", "affinity_mods": {"range_multiplier": 1.5}},
	{"id": "ink_candle", "title": "Чернильная свеча", "tier": 2, "cost": 55, "class_affinity": ["dark_mage"], "description": "-6% скорости движения. Темный маг: +55% урона.", "mods": {"move_speed_multiplier": 0.94}, "affinity_mods": {"damage_multiplier": 1.55}},
	{"id": "copper_string", "title": "Медная струна", "tier": 1, "cost": 30, "class_affinity": ["guitarist"], "description": "Гитарист: +45% урона.", "affinity_mods": {"damage_multiplier": 1.45}},
	{"id": "broken_pick", "title": "Сломанный медиатор", "tier": 1, "cost": 30, "class_affinity": ["guitarist"], "description": "Гитарист: +30% шанса крита.", "affinity_mods": {"crit_chance_flat": 0.3}},
	{"id": "loud_amp", "title": "Громкий усилитель", "tier": 1, "cost": 30, "class_affinity": ["guitarist"], "description": "Гитарист: +50% радиуса атак и зон.", "affinity_mods": {"aoe_radius_multiplier": 1.5}},
	{"id": "bass_cable", "title": "Басовый кабель", "tier": 2, "cost": 55, "class_affinity": ["guitarist"], "description": "+25% радиуса атак и зон. Гитарист: +45% отталкивания.", "mods": {"aoe_radius_multiplier": 1.25}, "affinity_mods": {"knockback_multiplier": 1.45}},
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
	{"id": "split_core", "title": "Ядро Расщепления", "tier": 3, "cost": 95, "class_affinity": ["dark_mage", "guitarist"], "description": "Темный маг/Гитарист: +1 снаряд и луч всем атакам.", "affinity_mods": {"extra_projectile": 1.0}},
	{"id": "blood_pact", "title": "Кровавый Рубеж", "tier": 3, "cost": 95, "class_affinity": [], "description": "Пока здоровье ниже 30% — +50% урона. Риск, достойный награды.", "mods": {"low_hp_damage_bonus": 0.5}},
	{"id": "leech_heart", "title": "Сердце Пиявки", "tier": 3, "cost": 95, "class_affinity": [], "description": "Каждое убийство возвращает 2% максимального здоровья.", "mods": {"kill_heal_percent": 0.02}},
	{"id": "thorn_pact", "title": "Договор Шипов", "tier": 3, "cost": 95, "class_affinity": [], "description": "Получив урон, выплескиваешь 200% этого урона на всех врагов рядом.", "mods": {"thorn_reflect_multiplier": 2.0}},
	{"id": "phantom_step", "title": "Призрачный Шаг", "tier": 3, "cost": 95, "class_affinity": [], "description": "Успешный уворот дает +40% скорости движения на 2 секунды.", "mods": {"dodge_rush_bonus": 0.4}},
	# SCRUM-500: триггерные (активируемые событием) артефакты — новый под-класс предметов.
	# Маркер `active:true` + поле `trigger` (семантика события). Эффект — суммируемый флаг в
	# mods (НЕ *_multiplier), раскладывается _apply_reward_mods как обычно. Пометка «⚡ Активный»
	# вшита в description (data-driven, без правок карточки). Значения консервативны и ситуативны:
	# лечение/щит/мув-бафф/ситуативный бурст — НЕ постоянный +damage, чтобы не смещать DPS/TTD-гейты.
	{"id": "field_kit", "title": "Полевой набор", "tier": 2, "cost": 55, "class_affinity": [], "active": true, "trigger": "on_room_clear", "description": "⚡ Активный — при зачистке боя: лечит 5% максимального здоровья.", "mods": {"room_clear_heal_percent": 0.05}},
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
const LEVEL_UP_REWARDS := [
	{"id": "damage_up", "attr": "damage", "title": "+Урон", "description": "+15% к урону.", "kind": "upgrade", "mods": {"damage_multiplier": 1.15}},
	{"id": "attack_speed_up", "attr": "attack_speed", "title": "+Скорость атаки", "description": "+12% к скорости атаки.", "kind": "upgrade", "mods": {"attack_speed_multiplier": 1.12}},
	{"id": "max_hp_up", "attr": "max_health", "title": "+Макс. здоровье", "description": "+18 к максимальному здоровью.", "kind": "upgrade", "mods": {"max_health_flat": 18.0}},
	{"id": "move_speed_up", "attr": "move_speed", "title": "+Скорость движения", "description": "+10% к скорости движения.", "kind": "upgrade", "mods": {"move_speed_multiplier": 1.10}},
	{"id": "aoe_radius_up", "attr": "aoe_radius", "title": "+Ширина сектора", "description": "+15% к ширине сектора.", "kind": "upgrade", "mods": {"sector_multiplier": 1.15}},
	{"id": "pickup_radius_up", "attr": "pickup_radius", "title": "+Радиус подбора", "description": "+45 к радиусу подбора опыта и золота.", "kind": "upgrade", "mods": {"pickup_radius_flat": 45.0}},
	{"id": "defense_up", "attr": "defense", "title": "+Защита", "description": "+10% к снижению входящего урона.", "kind": "upgrade", "mods": {"defense_flat": 0.10}},
	{"id": "magic_focus_up", "attr": "magic_focus", "title": "+Маг. урон", "description": "+14% только к магическому урону.", "kind": "upgrade", "mods": {"magic_damage_multiplier": 1.14}},
	{"id": "knockback_up", "attr": "knockback", "title": "+Отталкивание", "description": "+18% к силе отталкивания.", "kind": "upgrade", "mods": {"knockback_multiplier": 1.18}},
	{"id": "crit_chance_up", "attr": "crit_chance", "title": "+Шанс крита", "description": "+7% к шансу критического удара.", "kind": "upgrade", "mods": {"crit_chance_flat": 0.07}},
	{"id": "crit_damage_up", "attr": "crit_damage", "title": "+Урон крита", "description": "+35% к множителю критического урона.", "kind": "upgrade", "mods": {"crit_damage_flat": 0.35}},
	{"id": "dodge_up", "attr": "dodge", "title": "+Уклонение", "description": "+8% к шансу уклонения.", "kind": "upgrade", "mods": {"dodge_flat": 0.08}},
	{"id": "range_up", "attr": "range", "title": "+Дальность атаки", "description": "+12% к дальности атаки.", "kind": "upgrade", "mods": {"range_multiplier": 1.12}},
	{"id": "dot_damage_up", "attr": "dot_damage", "title": "+Периодический урон", "description": "+3 урона в каждом тике яда/горения/кровотечения. Классы без эффекта получают малое кровотечение.", "kind": "upgrade", "mods": {"dot_damage_flat": 3.0}},
	{"id": "dot_speed_up", "attr": "dot_speed", "title": "+Скорость тиков", "description": "+0.25 тика периодического урона в секунду.", "kind": "upgrade", "mods": {"dot_speed_flat": 0.25}},
	{"id": "projectile_speed_up", "attr": "projectile_speed", "title": "+Скорость снарядов", "description": "+90 к скорости полёта снарядов.", "kind": "upgrade", "mods": {"projectile_speed_flat": 90.0}},
	{"id": "aura_radius_up", "attr": "aura_radius", "title": "+Радиус", "description": "+15% к радиусу атак и зон.", "kind": "upgrade", "mods": {"aoe_radius_multiplier": 1.15}},
	{"id": "buff_power_up", "attr": "buff_power", "title": "+Сила поддержки", "description": "+18% к силе аур, кличей и усилений поддержки.", "kind": "upgrade", "mods": {"buff_power_flat": 0.18}},
	{"id": "summon_amount_up", "attr": "summon_amount", "title": "+Сила призыва", "description": "+2 к силе призывов. Непризывные классы получают эхо-оружие или спутника.", "kind": "upgrade", "mods": {"summon_bonus": 2.0}},
	{"id": "absorb_up", "attr": "absorb", "title": "+Поглощение", "description": "+4 к поглощению урона: каждый входящий удар слабее на 4.", "kind": "upgrade", "mods": {"absorb_flat": 4.0}},
	{"id": "regeneration_up", "attr": "regeneration", "title": "+Регенерация", "description": "+1.3 здоровья в секунду к восстановлению.", "kind": "upgrade", "mods": {"regeneration_flat": 1.3}},
	{"id": "vampiric_amount_up", "attr": "vampiric_amount", "title": "+Вампиризм (лечение)", "description": "+1 к лечению от вампиризма и +1 к пределу лечения в секунду.", "kind": "upgrade", "mods": {"vampiric_amount_flat": 1.0, "vampiric_heal_per_second_cap": 1.0}},
	{"id": "vampiric_chance_up", "attr": "vampiric_chance", "title": "+Вампиризм (шанс)", "description": "+5% к шансу вылечиться при ударе.", "kind": "upgrade", "mods": {"vampiric_chance_flat": 0.05}},
	{"id": "ultimate_power_up", "attr": "ultimate_power", "title": "+Сила ультимейта", "description": "+12% к силе эффектов классового ультимейта.", "kind": "upgrade", "mods": {"ultimate_flat": 0.12}},
]
