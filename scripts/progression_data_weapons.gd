extends RefCounted

# SCRUM-198: данные оружия классов, вынесены из progression_data.gd при
# доменном сплите. ProgressionData реэкспортит WEAPONS_BY_CLASS и
# BERSERK_WEAPONS как const (внешние ссылки ProgressionData.* сохранены).

const BERSERK_WEAPONS := {
	"sword": {
		"id": "sword",
		"title": "Двуручный меч",
		"description": "Длинный узкий сектор 100 градусов радиуса 350: точный дальний melee-замах вперед. Ширина сектора растет от секторных улучшений, радиус — от улучшений радиуса. Пассивно: +10% к урону.",
		"scene_path": "res://scenes/TwoHandedSword.tscn",
		"attack_shape": "sweep",
		"cone_degrees": 100.0,
		"attack_range": 350.0,
		"start_distance": 0.0,
		"inner_width": 150.0,
		"outer_width": 1200.0,
		"aoe_radius": 350.0,
		"sweep_degrees": 100.0,
		"geometry_stat_growth_from_delta": true,
		"range_scales_with_aoe_radius": true,
		"attack_range_intelligence_weight": 0.0,
		"aoe_radius_intelligence_weight": 0.0,
		"damage_multiplier": 1.15,
		"melee_execute_threshold": 0.28,
		"melee_execute_multiplier": 1.16,
		"melee_stagger_knockback_multiplier": 0.28,
		"passive_mods": {"damage_multiplier": 1.10},
		"fire_interval": 0.58,
		"visual_color": Color(0.62, 0.82, 1.0, 0.34),
	},
	"axe": {
		"id": "axe",
		"title": "Двуручный топор",
		"description": "Широкий сектор 180 градусов радиуса 250: половина круга по направлению к ближайшему монстру для контроля толпы вблизи. Секторные улучшения расширяют дугу, радиусные — дальность удара. Пассивно: -10% к урону.",
		"scene_path": "res://scenes/TwoHandedAxe.tscn",
		"attack_shape": "sweep",
		"cone_degrees": 180.0,
		"attack_range": 250.0,
		"start_distance": 0.0,
		"inner_width": 190.0,
		"outer_width": 560.0,
		"aoe_radius": 250.0,
		"sweep_degrees": 180.0,
		"geometry_stat_growth_from_delta": true,
		"range_scales_with_aoe_radius": true,
		"attack_range_intelligence_weight": 0.0,
		"aoe_radius_intelligence_weight": 0.0,
		"damage_multiplier": 0.85,
		"melee_close_bonus_radius": 210.0,
		"melee_close_damage_multiplier": 1.10,
		"melee_arc_followup_radius": 160.0,
		"melee_arc_followup_multiplier": 0.12,
		"passive_mods": {"damage_multiplier": 0.90},
		"fire_interval": 1.06,
		"visual_color": Color(1.0, 0.58, 0.24, 0.34),
	},
	"hammer": {
		"id": "hammer",
		"title": "Двуручный молот",
		"description": "Круговой slam радиуса 150 вокруг Берсерка: слабее по урону на старте, но радиус растет от улучшений радиуса без секторного бонуса.",
		"scene_path": "res://scenes/TwoHandedHammer.tscn",
		"attack_shape": "circle",
		"cone_degrees": 360.0,
		"attack_range": 150.0,
		"start_distance": 0.0,
		"inner_width": 180.0,
		"outer_width": 360.0,
		"aoe_radius": 150.0,
		"max_aoe_radius": 0.0,
		"sweep_degrees": 360.0,
		"circle_full_targets": 4,
		"circle_target_diminish": 0.62,
		"geometry_stat_growth_from_delta": true,
		"range_scales_with_aoe_radius": true,
		"attack_range_intelligence_weight": 0.0,
		"aoe_radius_intelligence_weight": 0.0,
		"damage_multiplier": 0.55,
		"melee_close_bonus_radius": 150.0,
		"melee_close_damage_multiplier": 1.18,
		"melee_stagger_knockback_multiplier": 0.90,
		# Молот остается слабым стартовым кругом, но его радиус теперь честно растет
		# от общего Radius; экспоненты держат late-game рост в коридоре.
		"upgrade_aoe_exponent": 1.08,
		"upgrade_damage_exponent": 1.05,
		"fire_interval": 1.25,
		"visual_color": Color(0.82, 0.72, 1.0, 0.32),
	},
}

const DARK_MAGE_WEAPONS := {
	# SCRUM-939..941: редизайн кита Тёмного мага. Класс смещён в area-давление
	# (solo_target 0.84 / aoe_target 1.30), поэтому три оружия делят AoE-ниши:
	#   dark_wand    — цепной снаряд по РАСТЯНУТЫМ группам (рикошеты + бурсты);
	#   cursed_skull — стационарный curse-прожиг ЯДРА толпы (только dot-ось);
	#   dark_book    — зеркальные парные взрывы при ОКРУЖЕНИИ (два фронта разом).
	"dark_book": {
		"id": "dark_book",
		"title": "Книга тьмы",
		# SCRUM-941: каждый каст = ПАРА взрывов, симметричных относительно мага.
		"description": "Парные страницы: взрыв по цели и зеркальный взрыв в симметричной точке с другой стороны мага.",
		"scene_path": "res://scenes/DarkBook.tscn",
		"attack_mode": "dark_mirror_blast",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.95,
		"projectile_count": 1,
		"fire_interval": 1.31,
		"attack_range": 620.0,
		"aoe_radius": 175.0,
		"projectile_speed": 520.0,
		# Зеркальный взрыв бьёт той же силой (правила урона/диминишинга общие).
		"mirror_damage_ratio": 1.0,
		"visual_color": Color(0.45, 0.15, 0.88, 0.38),
		"passive_mods": {"aoe_radius_multiplier": 1.10},
	},
	"cursed_skull": {
		"id": "cursed_skull",
		"title": "Проклятый череп",
		# SCRUM-940: ЧИСТОЕ проклятие — прямого урона нет вовсе. Череп накрывает
		# область, все проклятые быстро прогорают частыми тиками dot-оси.
		# Скейл ТОЛЬКО через curse/dot-пайплайн: dot_damage (сила тика: Знание +
		# dot_damage_flat моды + общий «Урон») и dot_speed (темп тиков).
		# Магические/чисто физические множители урон черепа НЕ повышают —
		# задокументированное правило кита (см. characters_weapons.md).
		"description": "Чистое проклятие: череп накрывает область, проклятые быстро сгорают частыми тиками. Урон растет только от силы и темпа проклятий.",
		"scene_path": "res://scenes/CursedSkull.tscn",
		"attack_mode": "skull_curse_burn",
		"damage_parameter": "magic_damage",
		"curse_only": true,
		"damage_multiplier": 1.0,
		"fire_interval": 0.9,
		"attack_range": 560.0,
		"aoe_radius": 165.0,
		# Тиков за каст на каждую проклятую цель; повторный каст ОБНОВЛЯЕТ
		# проклятие (refresh, 1 стак) — стакования и бесконечного прожига нет.
		"dot_ticks": 5,
		# Базовый темп тиков (тик/с при dot_speed=1.0): «быстрый прожиг».
		"curse_tick_rate": 7.0,
		# ДОКУМЕНТИРОВАННЫЙ curse-пайплайн (AC SCRUM-940): сила тика =
		# dot_damage * curse_tick_multiplier * (1 + Интеллект * curse_int_scale).
		# Атрибуты проклятия: Знание (dot_damage), Интеллект (глубина проклятия,
		# канон «Интеллект кормит тьму... глубже вгрызаются проклятия»),
		# dot_damage_flat моды и dot_speed (темп). Чистые magic_damage-множители
		# по-прежнему НЕ участвуют. Пара (0.58, 0.08) держит базовый тик на
		# уровне ~8.3 и даёт киту int-скейл в SCRUM-469-коридоре lvl20-оптимума;
		# формулы зеркалятся в бюджет-модели (_budget_dot_dps).
		"curse_tick_multiplier": 0.58,
		"curse_int_scale": 0.08,
		"projectile_speed": 680.0,
		"visual_color": Color(0.78, 0.16, 1.0, 0.42),
		"passive_mods": {"dot_speed_flat": 0.25},
	},
	"dark_wand": {
		"id": "dark_wand",
		"title": "Темная палочка",
		# SCRUM-939: видимый цепной/рикошет-снаряд: до 3 монстров суммарно
		# (первая цель + 2 рикошета в ближайших ещё не поражённых), на КАЖДОМ
		# попадании малый магический бурст по соседям жертвы. Повторных хитов
		# одной цели в цепи нет: если валидные цели кончились — цепь обрывается
		# раньше (документированный fallback, см. _fire_dark_chain_burst).
		"description": "Цепной снаряд: рикошетит до трех монстров, темная энергия убывает с каждым прыжком, а каждое попадание лопается малым взрывом.",
		"scene_path": "res://scenes/DarkWand.tscn",
		"attack_mode": "dark_chain_burst",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.95,
		"fire_interval": 1.35,
		"attack_range": 700.0,
		"chain_targets": 3,
		"chain_hop_range": 300.0,
		"chain_burst_ratio": 0.45,
		"pierce_damage_falloff": 0.82,
		"aoe_radius": 90.0,
		"projectile_speed": 1050.0,
		"visual_color": Color(0.28, 0.95, 1.0, 0.45),
		"passive_mods": {"range_multiplier": 1.08},
	},
}

# SCRUM-899: Гитарист = магический кастер с барбар-формами атак и деплой-геймплеем.
# Электрогитара — УЗКАЯ передняя полоса riff_strip (частые низко-средние маг. хиты,
# позиционирование важно; НЕ широкая generic-волна). Бас — большое кольцо частых
# слабых пульсов под кайт (ранняя слабость — урон, не радиус). Усилитель — ядро
# саммонер-петли: наземные маг. AoE-турели. Канон саммонер-скейлинга ампа:
#   • число ампов: 1 + floor(Лидерство/4), кап max_summons_cap (+amp_cap_bonus);
#   • uptime: Лидерство продлевает жизнь ампа (amp_leadership_lifetime_*);
#   • сила: summon_amount учащает пульс (amp_summon_haste, формула канона
#     summoner_weapon: min(summon_amount*0.014 + leadership*0.006, 0.30));
#   • каденция установки: attack_speed через generic fire_interval-скейл;
#   • урон пульса — ТОЛЬКО magic_damage (никакой «лидерской» оси урона).
# Trait «Разогрев» (SCRUM-1006) — CLASS_TRAITS.guitarist в progression_data_characters.gd.
const GUITARIST_WEAPONS := {
	"electric_guitar": {
		"id": "electric_guitar",
		"title": "Электрогитара",
		"description": "Узкий магический рифф вперед: частые удары в короткой полосе, важно вести корпус на цель.",
		"scene_path": "res://scenes/ElectricGuitar.tscn",
		"attack_mode": "riff_strip",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.66,
		"fire_interval": 0.55,
		"attack_range": 520.0,
		"aoe_radius": 110.0,
		"wave_width": 118.0,
		"knockback": 70.0,
		"visual_color": Color(0.18, 0.95, 0.85, 0.36),
		"passive_mods": {"attack_speed_multiplier": 1.15},
	},
	"bass_guitar": {
		"id": "bass_guitar",
		"title": "Бас-гитара",
		"description": "Большое кольцо баса с первого уровня: частые слабые магические тики и жесткое отталкивание — веди толпу сквозь ауру.",
		"scene_path": "res://scenes/BassGuitar.tscn",
		"attack_mode": "pulse",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.26,
		"fire_interval": 0.78,
		"attack_range": 330.0,
		"aoe_radius": 330.0,
		"knockback": 180.0,
		"visual_color": Color(1.0, 0.78, 0.18, 0.34),
		"passive_mods": {"attack_speed_multiplier": 1.10},
	},
	"sound_amp": {
		"id": "sound_amp",
		"title": "Звуковой усилитель",
		"description": "Деплой: усилитель гремит на месте ~7с магическими пульсами; Лидерство добавляет ампы и продлевает им жизнь.",
		"scene_path": "res://scenes/SoundAmp.tscn",
		"attack_mode": "amp",
		"damage_parameter": "magic_damage",
		"damage_multiplier": 0.85,
		"fire_interval": 2.40,
		"attack_range": 520.0,
		"aoe_radius": 235.0,
		"knockback": 130.0,
		"amp_lifetime": 7.0,
		"amp_pulse_interval": 1.0,
		"max_summons": 1,
		"max_summons_cap": 3,
		"amp_leadership_lifetime_per_point": 0.12,
		"amp_leadership_lifetime_cap": 3.0,
		"amp_summon_haste": true,
		"deploy_role": "stage_pulse",
		"deploy_texture_path": "res://assets/sprites/allies/deploy_sound_amp_field.png",
		"visual_color": Color(1.0, 0.35, 0.72, 0.35),
		"passive_mods": {"pickup_radius_flat": 30.0},
	},
}

# SCRUM-894: кит Ассасина — хрупкий crit-скейлер (trait «Хладнокровие»: кап крита
# 100%, см. CLASS_TRAITS). Shadow Momentum (kill_growth_*) удалён как нечитаемый —
# его заменил «Рывок темпа» Теневых кинжалов (flurry_tempo_*). Контракты кита —
# tests/assassin_kit_test.gd + tests/kill_scaling_identity_test.gd.
const ASSASSIN_WEAPONS := {
	"chakrams": {
		"id": "chakrams", "title": "Чакрамы",
		"description": "Возвращающиеся клинки: режут коридор до цели, а назад летят левой дугой. Правильная позиция — и враг получает оба прохода.",
		"scene_path": "res://scenes/Chakrams.tscn",
		"attack_mode": "boomerang", "damage_parameter": "damage",
		"damage_multiplier": 0.45, "fire_interval": 0.62,
		"attack_range": 460.0, "aoe_radius": 60.0, "beam_width": 56.0,
		"projectile_speed": 760.0,
		# Возврат — квадратичная дуга через ЛЕВУЮ сторону от направления броска;
		# смещение середины дуги. Гейт: максимум 1 outbound + 1 return хит на цель
		# за каст (см. ClassWeapon._fire_boomerang).
		"return_arc_offset": 170.0,
		"crit_shadow_burst_radius": 115.0,
		"visual_color": Color(0.72, 0.30, 1.0, 0.40),
		"passive_mods": {"crit_chance_flat": 0.06},
	},
	"shadow_daggers": {
		"id": "shadow_daggers", "title": "Теневые кинжалы",
		"description": "Веер коротких выпадов: сектор перед собой плюс всё вплотную вокруг героя. После серии по врагам — рывок темпа: короткий бонус скорости и уворота.",
		"scene_path": "res://scenes/ShadowDaggers.tscn",
		"attack_mode": "stab_flurry", "damage_parameter": "damage",
		"damage_multiplier": 0.54, "fire_interval": 0.38,
		"attack_range": 230.0, "aoe_radius": 82.0, "wave_width": 190.0,
		"projectile_count": 3, "knockback": 35.0,
		# SCRUM-894: мёртвой зоны в упор нет — враги в радиусе point_blank_radius
		# вокруг героя попадают в кандидаты серии независимо от направления.
		"point_blank_radius": 95.0,
		"melee_close_bonus_radius": 135.0, "melee_close_damage_multiplier": 1.18,
		"melee_execute_threshold": 0.35, "melee_execute_multiplier": 1.24,
		# SCRUM-894 «Рывок темпа» (замена Shadow Momentum): после серии, задевшей
		# хотя бы одного врага, — flurry_tempo_duration секунд +speed/+dodge.
		# Не стакается (только refresh), внутренний кулдаун flurry_tempo_cooldown
		# исключает перманентный аптайм (Player.trigger_flurry_tempo).
		"flurry_tempo_duration": 1.6,
		"flurry_tempo_cooldown": 4.0,
		"flurry_tempo_speed_bonus": 0.14,
		"flurry_tempo_dodge_bonus": 0.10,
		"crit_shadow_burst_radius": 78.0,
		"visual_color": Color(0.55, 0.18, 0.88, 0.42),
		"passive_mods": {"crit_chance_flat": 0.10, "attack_speed_multiplier": 1.08},
	},
	"venom_wire": {
		"id": "venom_wire", "title": "Ядовитая струна",
		"description": "Ядовитая гаррота от самой руки: пробивает ряд врагов по линии и душит тех, кто вцепился вплотную. Крит-удар делает яд злее.",
		"scene_path": "res://scenes/VenomWire.tscn",
		"attack_mode": "dot_beam", "damage_parameter": "damage",
		"damage_multiplier": 0.68, "fire_interval": 0.78,
		"attack_range": 420.0, "aoe_radius": 75.0, "beam_width": 32.0,
		"pierce_count": 4, "dot_ticks": 4,
		# SCRUM-894: линия начинается у героя, и враги в close_contact_radius
		# вокруг него ловят струну с любой стороны (пирс-лимит общий — без
		# бесплатных лишних хитов). dot_crit_snapshot_ratio — крит прямого удара
		# усиливает тики яда долей крит-множителя (снапшот на момент каста).
		"close_contact_radius": 80.0,
		"dot_crit_snapshot_ratio": 0.6,
		"crit_shadow_burst_radius": 92.0,
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

# SCRUM-900: редизайн кита «чумного доктора» — сустейн ТОЛЬКО от оружия (trait
# plague_oath, см. CLASS_TRAITS). Иерархия лечения: bone_saw (0.30, ближний
# позиционный риск) > restore_potion (0.20, безопасный AoE) > plague_syringe
# (0.14, пассивное давление чумы). Всё лечение идёт от ФАКТИЧЕСКИ нанесённого
# урона через apply_drain_heal (per-second бюджет SCRUM-517 — бессмертие
# недостижимо даже при полном заражении карты).
const DOCTOR_WEAPONS := {
	"restore_potion": {
		"id": "restore_potion", "title": "Зелье восстановления",
		"description": "Бросок зелья: магический взрыв по области; Доктор лечится на долю фактически нанесенного урона.",
		"scene_path": "res://scenes/RestorePotion.tscn",
		"attack_mode": "aoe_projectile", "damage_parameter": "magic_damage",
		"damage_multiplier": 2.7, "fire_interval": 1.15,
		"attack_range": 520.0, "aoe_radius": 150.0,
		"projectile_speed": 620.0,
		"heal_percent_of_damage": 0.16,
		"visual_color": Color(0.35, 0.95, 0.55, 0.42),
		"passive_mods": {"max_health_multiplier": 1.10},
	},
	"plague_syringe": {
		"id": "plague_syringe", "title": "Чумной шприц",
		"description": "Чумной дротик: долгая зараза (24с) с медленно растущими тиками, перескакивающая на соседей; часть чумного урона лечит Доктора.",
		"scene_path": "res://scenes/PlagueSyringe.tscn",
		"attack_mode": "plague_dart", "damage_parameter": "magic_damage",
		"damage_multiplier": 2.4, "fire_interval": 1.35,
		"attack_range": 590.0, "aoe_radius": 90.0,
		"projectile_speed": 760.0,
		# Чума (профиль — ProgressionData.plague_tick_profile, единый для
		# рантайма и бюджета): длительность в целевом коридоре 20-30с тикета.
		"plague_duration": 24.0, "plague_tick_interval": 2.0,
		"plague_tick_ratio": 0.22, "plague_dot_coupling": 0.6,
		"plague_ramp_ticks": 5,
		"plague_spread_chance": 0.22, "plague_spread_radius": 200.0,
		"plague_max_infected": 10,
		"heal_percent_of_damage": 0.12,
		"visual_color": Color(0.36, 0.95, 0.42, 0.46),
		"passive_mods": {"max_health_multiplier": 1.04},
	},
	"bone_saw": {
		"id": "bone_saw", "title": "Костяная пила",
		"description": "Широкий сектор 135° перед Доктором: пила рвет несколько целей и возвращает больше всего здоровья — пока враги перед зубьями, а не за спиной.",
		"scene_path": "res://scenes/BoneSaw.tscn",
		"attack_mode": "saw_sector", "damage_parameter": "damage",
		"damage_multiplier": 4.6, "fire_interval": 0.62,
		"attack_range": 215.0, "aoe_radius": 215.0,
		"cone_degrees": 135.0,
		"sector_full_targets": 4, "sector_target_diminish": 0.72,
		"heal_percent_of_damage": 0.34,
		"melee_close_bonus_radius": 110.0, "melee_close_damage_multiplier": 1.12,
		"visual_color": Color(0.88, 0.22, 0.18, 0.42),
		"passive_mods": {"defense_flat": 0.02},
	},
}

const CHEMIST_WEAPONS := {
	# SCRUM-943: быстрый ПРЯМОЙ физический close-mid AoE — комфортная «рабочая
	# лошадка» кита. Базовой лужи/DoT нет (leaves_pool убран) — периодическую ось
	# кита держат кислотная колба и волны гомункула; trait «Катализатор» (SCRUM-942)
	# этот прямой взрыв НЕ усиливает. Скейл от физического урона (damage_parameter
	# "damage") — вложения в физику ощутимо разгоняют именно пыль.
	"blast_powder": {
		"id": "blast_powder", "title": "Взрывная пыль",
		"description": "Быстрая пара прямых взрывов по ближайшим целям на ближне-средней дистанции. Скейлится от физического урона; без облаков и DoT.",
		"scene_path": "res://scenes/BlastPowder.tscn",
		"attack_mode": "aoe_projectile", "damage_parameter": "damage",
		# projectile_count 2 — двойной бросок по двум ближайшим целям: живое
		# crowd-покрытие прямого AoE (по одиночной цели летит один снаряд);
		# ручной множитель держит авто-тюнер вне сатурации клампа 2.80.
		"damage_multiplier": 2.60, "fire_interval": 0.62, "projectile_count": 2,
		"attack_range": 430.0, "aoe_radius": 150.0, "projectile_speed": 640.0,
		"visual_color": Color(0.95, 0.72, 0.22, 0.44),
		"passive_mods": {"aoe_radius_multiplier": 1.10},
	},
	# SCRUM-944: зонный контроль пола — долгоживущие ПОЛУПРОЗРАЧНЫЕ лужи. Монстр,
	# зашедший в лужу, получает один ВЕЧНЫЙ кислотный заряд ОТ ЭТОЙ лужи (статус
	# "acid_charge_p<pool_id>", тикает до смерти носителя); разные лужи стакаются
	# (кап pool_charge_cap, артефакт «Кислотный катализатор» поднимает кап на +3).
	# Trait «Катализатор» множит и тики лужи, и заряды (+50%).
	"acid_flask": {
		"id": "acid_flask", "title": "Кислотная колба",
		"description": "Долгая полупрозрачная кислотная лужа: пока враг в луже — тики, а каждый контакт с новой лужей вешает вечный кислотный заряд (до 5).",
		"scene_path": "res://scenes/AcidFlask.tscn",
		"attack_mode": "aoe_projectile", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.24, "fire_interval": 1.25,
		"attack_range": 600.0, "aoe_radius": 210.0, "projectile_speed": 520.0,
		"leaves_pool": true, "pool_element": "poison", "pool_duration": 7.0, "pool_tick_interval": 0.75,
		"pool_tick_damage_multiplier": 0.90,
		"pool_direct_damage_multiplier": 0.38,
		"pool_translucent": true,
		"pool_contact_charges": true, "pool_charge_tick_multiplier": 0.30,
		"pool_charge_tick_interval": 0.9, "pool_charge_cap": 5,
		"visual_color": Color(0.22, 0.95, 0.26, 0.44),
		"passive_mods": {"aoe_radius_multiplier": 1.08},
	},
	# SCRUM-946: ПОСТОЯННАЯ пара гомункулов (без таймера жизни):
	# - танк: 4x max HP Химика, таунт-пульсы (враги грызут его, а не игрока),
	#   смертен; после смерти переспавнивается через fire_interval (4с);
	# - кастер: неуязвим (Node2D-эффект вне групп allies/боевого лимита), ходит
	#   рядом с танком (fallback — плечо Химика), каждые summon_wave_interval
	#   вешает волной вечный DoT-заряд (кап summon_wave_stack_cap, trait ×1.5).
	# max_summons=2 — бюджетное покрытие пары (боевой лимит рантайма пара не
	# использует: популяцию ведёт _update_homunculus_pair).
	"homunculus_vial": {
		"id": "homunculus_vial", "title": "Склянка гомункула",
		"description": "Постоянная пара гомункулов: живучий танк-провокатор (4x HP Химика) и неуязвимый кастер, копящий волнами вечный периодический урон.",
		"scene_path": "res://scenes/HomunculusVial.tscn",
		"damage_parameter": "magic_damage",
		"summon_damage_multiplier": 2.40,  # SCRUM-546: подъём с пола DPS-полосы (был 0.52)
		"damage_multiplier": 0.90, "fire_interval": 4.0,  # fire_interval = респавн-пауза танка
		"upgrade_damage_exponent": 1.40,  # SCRUM-505: lvl20 summon-profile lift; empty run_modifiers stay 1.0
		"attack_range": 420.0, "aoe_radius": 70.0,
		"summon_aoe_radius": 84.0, "summon_aoe_damage_multiplier": 0.86,  # SCRUM-505: splash танка; рост покрытия — от (level-1) в _summon_profile
		"summon_leash_radius": 540.0,
		"max_summons": 2,  # бюджет-покрытие пары танк+кастер (см. коммент выше)
		"summon_role": "tank_control",
		"summon_role_damage_multiplier": 1.25,  # SCRUM-546 (был 0.95)
		"summon_health_multiplier": 4.0,  # SCRUM-946: танк = 4x max HP Химика
		"summon_attack_interval": 0.38,
		"summon_speed_multiplier": 0.88,
		"summon_control_knockback": 95.0,
		"summon_pair_mode": true,
		"pair_tank_visual_id": "homunculus_tank",
		"summon_wave_interval": 1.7,
		"summon_wave_radius": 150.0,
		"summon_wave_dot_multiplier": 0.35,
		"summon_wave_dot_interval": 1.0,
		"summon_wave_stack_cap": 4,
		"ally_visual_id": "homunculus_tank",
		"visual_color": Color(0.54, 0.96, 0.48, 0.42),
		"passive_mods": {"max_health_flat": 6.0},
	},
}

const KNIGHT_WEAPONS := {
	"long_spear": {
		"id": "long_spear", "title": "Копье",
		"description": "Длинный точечный выпад: узкая полоса 90 x 540, медленно и тяжело. Пассив: +5% защиты и легкий single-target block/counter.",
		"scene_path": "res://scenes/LongSpear.tscn",
		"attack_shape": "strip", "cone_degrees": 24.0,
		"attack_range": 540.0, "start_distance": 0.0,
		"inner_width": 90.0, "outer_width": 90.0, "aoe_radius": 540.0,
		"sweep_degrees": 24.0, "damage_multiplier": 3.0, "fire_interval": 1.0,
		"melee_execute_threshold": 0.36, "melee_execute_multiplier": 1.20,
		"melee_stagger_knockback_multiplier": 0.35,
		"visual_color": Color(0.80, 0.86, 0.95, 0.36),
		"passive_mods": {"defense_flat": 0.05, "block_reduction": 0.38, "counter_damage_multiplier": 0.32, "counter_incoming_multiplier": 2.4, "counter_cap_multiplier": 0.60, "counter_radius": 145.0, "counter_arc_degrees": 60.0, "counter_target_cap": 2, "counter_full_targets": 1, "counter_target_diminish": 1.10, "counter_cooldown": 2.8, "counter_knockback": 120.0, "counter_stagger_duration": 0.55},
	},
	"tower_shield": {
		"id": "tower_shield", "title": "Башенный щит",
		"description": "Короткий фронтальный bash: меньше урона, сильная защита и мощная block/counter ответка по контактной стае.",
		"scene_path": "res://scenes/TowerShield.tscn",
		"attack_shape": "sweep", "cone_degrees": 95.0,
		"attack_range": 215.0, "start_distance": 0.0,
		"inner_width": 150.0, "outer_width": 290.0, "aoe_radius": 215.0,
		"sweep_degrees": 95.0, "damage_multiplier": 0.72, "fire_interval": 0.82,
		"melee_close_bonus_radius": 185.0, "melee_close_damage_multiplier": 1.08,
		"melee_stagger_knockback_multiplier": 1.15,
		"visual_color": Color(0.74, 0.78, 0.92, 0.36),
		"passive_mods": {"defense_flat": 0.08, "max_health_multiplier": 1.08, "block_reduction": 0.62, "counter_damage_multiplier": 0.55, "counter_incoming_multiplier": 5.0, "counter_cap_multiplier": 1.45, "counter_radius": 195.0, "counter_arc_degrees": 135.0, "counter_target_cap": 4, "counter_full_targets": 3, "counter_target_diminish": 0.55, "counter_cooldown": 1.7, "counter_knockback": 230.0, "counter_stagger_duration": 0.85},
	},
	"holy_flail": {
		"id": "holy_flail", "title": "Освященный кистень",
		"description": "Тяжелый круговой замах средней дальности: медленнее щита, зато держит holy-control круг и мягкую круговую ответку.",
		"scene_path": "res://scenes/HolyFlail.tscn",
		"attack_shape": "circle", "cone_degrees": 360.0,
		"attack_range": 235.0, "start_distance": 0.0,
		"inner_width": 180.0, "outer_width": 360.0, "aoe_radius": 235.0,
		"sweep_degrees": 360.0, "damage_multiplier": 0.86, "fire_interval": 1.18,
		"melee_arc_followup_radius": 175.0, "melee_arc_followup_multiplier": 0.16,
		"melee_stagger_knockback_multiplier": 0.45,
		"visual_color": Color(1.0, 0.84, 0.32, 0.34),
		"passive_mods": {"knockback_multiplier": 1.20, "block_reduction": 0.30, "counter_damage_multiplier": 0.48, "counter_incoming_multiplier": 3.2, "counter_cap_multiplier": 1.15, "counter_radius": 215.0, "counter_arc_degrees": 360.0, "counter_target_cap": 6, "counter_full_targets": 4, "counter_target_diminish": 0.45, "counter_cooldown": 2.8, "counter_knockback": 165.0, "counter_stagger_duration": 0.65},
	},
}

# SCRUM-902/903: редизайн кита Друида. Амулет — случайный ростер призраков
# (3 melee physical + 2 magic ranged, арт SCRUM-901/1015/1016) с классовой
# «Аурой дикой силы» (CLASS_TRAITS.druid); Посох терний — полупрозрачная зона
# шипов (слоу + повторные ФИЗИЧЕСКИЕ хиты с капом на врага/зону, не DoT-ось);
# Вороний тотем — деплой-тотемы, пускающие самонаводящихся воронов с AoE-взрывом.
const DRUID_WEAPONS := {
	"summon_amulet": {
		"id": "summon_amulet", "title": "Амулет призыва",
		"description": "Зовет призрачный ростер: ближние духи рвут физически по площади, дальние бьют магическими снарядами; состав случаен, стая растет от Лидерства.",
		"scene_path": "res://scenes/SummonAmulet.tscn",
		"damage_parameter": "magic_damage",
		"summon_damage_multiplier": 1.85,  # SCRUM-546: подъём с пола DPS-полосы (был 0.58)
		"damage_multiplier": 1.0, "fire_interval": 3.0,
		"upgrade_damage_exponent": 1.22,  # SCRUM-505: lvl20 summon-profile lift; empty run_modifiers stay 1.0
		"attack_range": 420.0, "aoe_radius": 60.0,
		# SCRUM-505: мобильная стая мертва на 20t-оси. per-summon урон зажат budget-флором
		# (budget_damage_multiplier=0.28), поэтому 20t тянем ПОКРЫТИЕМ роя. Чтобы НЕ
		# раздуть lvl1 (стартовый баланс уже ок), основной прирост покрытия splash
		# масштабируется от (level-1) в _summon_profile (=0 на lvl1, растёт к lvl20) —
		# здесь только lvl1-нейтральный flat-base. См. summoner_weapon._summon_profile.
		"summon_aoe_radius": 78.0, "summon_aoe_damage_multiplier": 0.82,  # SCRUM-505 lvl1-нейтральный base (было 72/0.80); рост покрытия splash — от (level-1) в _summon_profile
		"summon_leash_radius": 560.0,
		# SCRUM-902: baseline-стая ≥5 активных призывов БЕЗ прокачки: base 5 +
		# floor(leadership/4) (player._apply_weapon_scaling) = 7 у стартового
		# Друида (Лидерство 9); дальше слоты растут от Лидерства/summon_bonus.
		"max_summons": 5,
		"command_mode": "attack_target",
		"summon_role": "pack_damage",
		"summon_role_damage_multiplier": 1.45,  # SCRUM-546 (был 1.06)
		"summon_health_multiplier": 0.30,
		"summon_attack_interval": 0.34,  # SCRUM-546 (lvl1-нейтрально); темп растёт от haste
		"summon_speed_multiplier": 1.15,
		"summon_lifetime_multiplier": 1.12,
		"summon_control_knockback": 34.0,
		# SCRUM-902: канонический ростер призраков (арт SCRUM-901/1015/1016).
		# Каждый призыв — СЛУЧАЙНАЯ запись ростера: melee-звери бьют ФИЗИЧЕСКИ по
		# площади (family=physical ← стат damage/Сила), дальние — МАГИЧЕСКИМ
		# снарядом (family=magic ← стат magic_damage/Интеллект). Зеркало бюджета —
		# ProgressionData._budget_summon_dps (композиционно-взвешенная семья).
		"summon_roster": [
			{"visual_id": "druid_ghost_wolf", "family": "physical", "attack_kind": "melee"},
			{"visual_id": "druid_ghost_bear", "family": "physical", "attack_kind": "melee"},
			{"visual_id": "druid_ghost_panther", "family": "physical", "attack_kind": "melee"},
			{"visual_id": "druid_ghost_stag", "family": "magic", "attack_kind": "ranged"},
			{"visual_id": "druid_ghost_lion", "family": "magic", "attack_kind": "ranged"},
		],
		# SCRUM-902: параметры снаряда дальних духов (см. ally_minion.gd).
		"summon_ranged_range": 240.0,
		"summon_ranged_projectile_speed": 620.0,
		"visual_color": Color(0.45, 0.80, 0.35, 0.42),
		"passive_mods": {"buff_power_note": 0.0},
	},
	"briar_staff": {
		"id": "briar_staff", "title": "Посох терний",
		"description": "Бросок семени-терновника: полупрозрачная зона шипов замедляет и наносит повторные физические удары идущим сквозь нее.",
		"scene_path": "res://scenes/BriarStaff.tscn",
		# SCRUM-903: шипы — ФИЗИЧЕСКИЕ повторные хиты (damage ← Сила), не DoT-ось.
		"attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"damage_multiplier": 0.70, "fire_interval": 1.20,
		"attack_range": 560.0, "aoe_radius": 190.0, "projectile_speed": 500.0,
		"leaves_pool": true, "pool_duration": 3.6, "pool_tick_interval": 0.55,
		"pool_element": "briar",
		# SCRUM-903: контракт терновой зоны (зеркало бюджета — _budget_pool_dps,
		# briar-ветка; рантайм — class_weapon._briar_zone_tick):
		#   briar_zone         — зона работает повторными физ-хитами вместо
		#                        generic dot-тиков (dot_damage НЕ участвует);
		#   briar_hit_multiplier — урон одного хита = физ. damage × множитель;
		#   briar_hit_cap      — КАП хитов на ОДНОГО врага с ОДНОЙ зоны (время
		#                        внутри/проход сквозь зону дают до cap читаемых
		#                        ударов раз в pool_tick_interval; повторный вход
		#                        в ту же зону хиты не сбрасывает — анти-runaway,
		#                        общий потолок зон MAX_ACTIVE_DAMAGE_POOLS=6);
		#   briar_slow_multiplier — слоу внутри зоны (спадает при выходе).
		"briar_zone": true,
		"briar_hit_multiplier": 0.34,
		"briar_hit_cap": 5,
		"briar_slow_multiplier": 0.62,
		# SCRUM-903: зона полупрозрачна — поле боя читается сквозь шипы.
		"pool_translucent": true,
		"visual_color": Color(0.32, 0.78, 0.28, 0.44),
		"passive_mods": {"aoe_radius_multiplier": 1.08},
	},
	"raven_totem": {
		"id": "raven_totem", "title": "Вороний тотем",
		"description": "Ставит наземные тотемы: каждый пускает самонаводящихся воронов, взрывающихся по области; лимит и сила растут от Лидерства.",
		"scene_path": "res://scenes/RavenTotem.tscn",
		"attack_mode": "amp", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.66, "fire_interval": 2.35,
		"attack_range": 470.0, "aoe_radius": 255.0, "knockback": 70.0,
		# SCRUM-903: деплой-тотем живёт ~8с (AC 6-10с) и раз в amp_pulse_interval
		# выпускает самонаводящегося ворона; baseline-лимит = base 2 +
		# floor(Лидерство 9 / 4) = 4 активных тотема (кап 6 — рост от Лидерства).
		"amp_lifetime": 8.0, "amp_pulse_interval": 1.10, "max_summons": 2,
		"max_summons_cap": 6,
		# SCRUM-903: контракт воронов (рантайм — class_weapon._launch_totem_raven;
		# зеркало бюджета — _budget_hit_model, amp+raven_homing ветка):
		#   raven_homing            — пульс тотема = самонаводящийся ворон-снаряд
		#                             (кривая Безье с живым доведением до цели),
		#                             взрыв по области в точке попадания;
		#   raven_damage_multiplier — урон взрыва = _rolled_damage × множитель;
		#   raven_explosion_radius  — радиус взрыва (полный урон первым
		#                             RAVEN_EXPLOSION_FULL_TARGETS целям, дальше
		#                             диминиш — анти-стакинг толпы).
		"raven_homing": true,
		"raven_damage_multiplier": 0.85,
		"raven_explosion_radius": 120.0,
		"deploy_role": "support_totem",
		"summon_role": "support_totem",
		"summon_role_damage_multiplier": 1.08,
		"summon_support_heal_percent": 0.004,
		"summon_control_knockback": 72.0,
		"deploy_texture_path": "res://assets/sprites/allies/deploy_raven_totem_field.png",
		"visual_color": Color(0.20, 0.72, 0.42, 0.40),
		"passive_mods": {"pickup_radius_flat": 20.0},
	},
}

# SCRUM-936/937/938: редизайн кита Солдата (быстрая взрывная пуля / медленный
# фитильный нюк / ближний штыковой конус). Все три действия дублируются trait'ом
# «Двойное действие» (SCRUM-935, CLASS_TRAITS.soldier) — компенсация ×1.5 бюджета
# зашита в estimate_weapon_budget_for_stats, урон авто-тюнится budget_tuning_for.
const SOLDIER_WEAPONS := {
	"soldier_rifle": {
		"id": "soldier_rifle", "title": "Аркебуза строя",
		"description": "Быстрая взрывная пуля: выстрел летит далеко в цель и взрывается малой зоной осколков, задевая соседей.",
		"scene_path": "res://scenes/SoldierRifle.tscn",
		"attack_mode": "arquebus_shot", "damage_parameter": "damage",
		"damage_multiplier": 0.60, "fire_interval": 0.62,
		"attack_range": 640.0, "aoe_radius": 95.0,
		"projectile_speed": 1150.0, "beam_width": 26.0,
		"damage_falloff": 0.45, "knockback": 42.0,
		"visual_color": Color(0.84, 0.78, 0.58, 0.42),
		"passive_mods": {"range_multiplier": 1.06},
	},
	"soldier_grenade": {
		"id": "soldier_grenade", "title": "Граната с фитилем",
		"description": "Тяжелая граната летит медленно, ложится и горит на видимом фитиле, затем мощный взрыв накрывает зону с падением урона к краю.",
		"scene_path": "res://scenes/SoldierGrenade.tscn",
		"attack_mode": "grenade_fuse", "damage_parameter": "damage",
		"damage_multiplier": 2.35, "fire_interval": 3.10,
		"attack_range": 520.0, "aoe_radius": 190.0,
		"projectile_speed": 230.0, "grenade_delay": 0.85,
		"damage_falloff": 0.50, "knockback": 90.0,
		"visual_color": Color(0.96, 0.55, 0.22, 0.46),
		"passive_mods": {"aoe_radius_multiplier": 1.08},
	},
	"soldier_bayonet": {
		"id": "soldier_bayonet", "title": "Штык-стойка",
		"description": "Штыковой выпад конусом перед собой: каждый враг в секторе получает укол и отброс, а винтовка иногда добивает выстрелом цель за конусом.",
		"scene_path": "res://scenes/SoldierBayonet.tscn",
		"attack_mode": "bayonet_cone", "damage_parameter": "damage",
		"damage_multiplier": 0.92, "fire_interval": 0.82,
		"attack_range": 205.0, "aoe_radius": 205.0,
		"cone_degrees": 105.0, "knockback": 96.0,
		"bayonet_auto_shot_chance": 0.25,
		"bayonet_shot_range": 560.0,
		"bayonet_shot_damage_multiplier": 0.7,
		"melee_close_bonus_radius": 150.0, "melee_close_damage_multiplier": 1.12,
		"melee_stagger_knockback_multiplier": 1.25,
		"visual_color": Color(0.58, 0.86, 1.0, 0.40),
		"passive_mods": {"defense_flat": 0.03},
	},
}

const THIEF_WEAPONS := {
	# SCRUM-897: редизайн кита Вора поверх trait «Воровская хватка»
	# (CLASS_TRAITS.thief в progression_data_characters.gd — магнит подбора).
	# Ниши кита: экономический рикошет по толпе / контроль-кинжал с backstab-окном
	# / защитная дым-зона с разовым AoE-взрывом. Константы механик — COIN_*/
	# POISON_*/BACKSTAB_* в class_weapon.gd.
	"thief_coin_pouch": {
		# SCRUM-897 «Кошель Рикошета»: цепь из projectile_count прыжков (базово 6,
		# прогрессия капится COIN_CHAIN_HARD_CAP=8 — не бесконечна и не лучший
		# полнокартный клир). damage_falloff = ДОЛЯ УРОНА ПОСЛЕДНЕГО прыжка:
		# урон убывает монотонно tail^(i/(n-1)) до ровно 50% к финальному звену.
		# Золото начисляется МГНОВЕННО (gain_money) с первых steal_hits целей
		# цепи — без спавна и сбора пикапа.
		"id": "thief_coin_pouch", "title": "Кошель Рикошета",
		"description": "Монета скачет цепью до 6 целей: урон плавно убывает до половины к последнему прыжку, а золото с первых трех попаданий сразу падает в кошель.",
		"scene_path": "res://scenes/ThiefCoinPouch.tscn",
		"attack_mode": "coin_ricochet", "damage_parameter": "damage",
		"damage_multiplier": 0.82, "fire_interval": 0.88,
		"attack_range": 520.0, "aoe_radius": 120.0,
		"beam_width": 34.0, "projectile_count": 6,
		"damage_falloff": 0.5, "steal_money": 1, "steal_hits": 3,
		"visual_color": Color(1.0, 0.78, 0.28, 0.44),
		"passive_mods": {"money_gain_multiplier": 1.08},
	},
	"thief_shadow_cloak": {
		# SCRUM-897 «Отравленный Кинжал» (ex-«Плащ Захода»): кинжал из тени бьёт
		# за ближайшей целью БЕЗ движения/телепорта героя. Встроенный контроль:
		# паралич-яд poison_paralysis_duration (кламп POISON_PARALYSIS_CAP, у
		# боссов/элит срез POISON_PARALYSIS_BOSS_FACTOR). Позиционный пейофф:
		# удар в спину (цель смотрит прочь от фантома) ×BACKSTAB_POSITIONAL_MULTIPLIER.
		"id": "thief_shadow_cloak", "title": "Отравленный Кинжал",
		"description": "Кинжал бьет из тени за ближайшей целью, не смещая героя: паралич-яд сковывает задетых, а удар в спину наносит повышенный урон.",
		"scene_path": "res://scenes/ThiefShadowCloak.tscn",
		"attack_mode": "shadow_backstab", "damage_parameter": "damage",
		"damage_multiplier": 0.96, "fire_interval": 1.08,
		"attack_range": 360.0, "aoe_radius": 140.0,
		"knockback": 62.0, "poison_paralysis_duration": 0.85,
		"visual_color": Color(0.74, 0.30, 1.0, 0.42),
		"passive_mods": {"dodge_flat": 0.04, "crit_chance_flat": 0.04},
	},
	"thief_smoke_bomb": {
		# SCRUM-897 «Дымовая Бомба»: брошенный снаряд летит grenade_delay, на
		# детонации — ОДНО AoE-событие урона (скейлится уроном/AoE/темпом билда),
		# затем НЕдамажащее облако smoke_duration. Уклонение (+dodge_bonus)
		# действует ТОЛЬКО пока герой внутри облака; суммарный шанс в дыму капится
		# SMOKE_CLOUD_DODGE_CAP=0.90 (progression_data_balance.gd).
		"id": "thief_smoke_bomb", "title": "Дымовая Бомба",
		"description": "Бросок шашки: после задержки взрыв бьет по области, а осевшее облако укрывает Вора — внутри дыма уклонение резко растет.",
		"scene_path": "res://scenes/ThiefSmokeBomb.tscn",
		"attack_mode": "smoke_bomb", "damage_parameter": "damage",
		# damage_multiplier 1.02→1.34 (SCRUM-897): бюджетный тюнер дыма сидел в
		# клэмп-сатурации 2.80 (кит не дотягивал до классового таргета) — поднятая
		# база выводит budget_damage_multiplier в рабочий коридор (~2.2).
		"damage_multiplier": 1.34, "fire_interval": 1.34,
		"attack_range": 430.0, "aoe_radius": 170.0,
		"grenade_delay": 0.50, "smoke_duration": 2.60,
		"dodge_bonus": 0.35, "knockback": 54.0,
		"visual_color": Color(0.45, 0.48, 0.58, 0.42),
		"passive_mods": {"move_speed_multiplier": 1.04},
	},
}

const ELEMENTALIST_WEAPONS := {
	# SCRUM-948..950: редизайн кита Элементалиста поверх trait SCRUM-947
	# («Проводник стихий», см. CLASS_TRAITS.elementalist в progression_data_characters.gd).
	# Ниши кита: постоянный квадрат-ореол / редкий полнокартный X / сверхредкий
	# нюк с догорающей зоной. Метеор — максимальный fire_interval среди ВСЕХ
	# оружий игрока (4.50 > 4.0 у homunculus_vial).
	"elementalist_orb_ring": {
		# SCRUM-948: «Кольцо Четырёх Стихий» (бывш. «Кольцо Трех Стихий») —
		# квадратная AoE в точке каста, три канала урона сразу (физика+магия+
		# периодика, потому тяжело масштабируется оптимально) + отброс от центра
		# на каждом тике. Геометрия/доли — константы SQUARE_* в class_weapon.gd.
		"id": "elementalist_orb_ring", "title": "Кольцо Четырёх Стихий",
		"description": "Квадрат четырёх стихий вспыхивает в точке каста: тики бьют физикой, магией и ожогом и отбрасывают врагов прочь от центра.",
		"scene_path": "res://scenes/ElementalistOrbRing.tscn",
		"attack_mode": "elemental_orbit", "damage_parameter": "magic_damage",
		"damage_multiplier": 1.35, "fire_interval": 1.52,
		"attack_range": 360.0, "aoe_radius": 230.0,
		"projectile_count": 4, "orbit_duration": 1.35, "storm_ticks": 4,
		"dot_ticks": 2, "knockback": 46.0,
		"visual_color": Color(0.40, 0.82, 1.0, 0.42),
		"passive_mods": {"aoe_radius_multiplier": 1.06},
	},
	"elementalist_prism_focus": {
		# SCRUM-949: полнокартный X-разлом — две диагональные линии через точку
		# фокуса до границ арены (практический предел PRISM_FULL_MAP_REACH в
		# class_weapon.gd покрывает диагональ арены 4096×2304 из любой точки)
		# + малый AoE в центре пересечения. Урон детерминирован: линия — не более
		# одного попадания на врага за каст, центр — один бонус-хит.
		"id": "elementalist_prism_focus", "title": "Призматический Фокус",
		"description": "X-разлом во всю карту: две диагональные линии стихий пронзают арену через точку фокуса, а их пересечение взрывается малым AoE.",
		"scene_path": "res://scenes/ElementalistPrismFocus.tscn",
		"attack_mode": "prism_rift", "damage_parameter": "magic_damage",
		"damage_multiplier": 1.90, "fire_interval": 2.30,
		"attack_range": 560.0, "aoe_radius": 150.0,
		"beam_width": 58.0, "grenade_delay": 0.42,
		"visual_color": Color(0.76, 0.42, 1.0, 0.44),
		"passive_mods": {"range_multiplier": 1.05},
	},
	"elementalist_meteor_core": {
		# SCRUM-950: самое медленное оружие игрока — максимальный fire_interval,
		# долгий телеграф + падение (grenade_delay = ПОЛНАЯ задержка до удара,
		# внутри делится на телеграф/полёт: METEOR_TELEGRAPH_RATIO), огромный
		# магический взрыв и догорающая DoT-зона (dot_ticks тиков каждые
		# pool_tick_interval по dot-оси владельца).
		"id": "elementalist_meteor_core", "title": "Ядро Метеора",
		"description": "Высшая ставка мага: долгий телеграф, тяжёлое падение метеора, огромный взрыв и догорающая зона ожога. Самое медленное оружие в игре.",
		"scene_path": "res://scenes/ElementalistMeteorCore.tscn",
		"attack_mode": "meteor_shards", "damage_parameter": "magic_damage",
		"damage_multiplier": 2.90, "fire_interval": 4.50,
		"attack_range": 610.0, "aoe_radius": 240.0,
		"beam_width": 72.0, "grenade_delay": 1.30,
		"dot_ticks": 5, "pool_tick_interval": 0.62,
		"visual_color": Color(1.0, 0.48, 0.16, 0.46),
		"passive_mods": {"damage_multiplier": 1.04},
	},
}

const SNIPER_WEAPONS := {
	"sniper_deadeye_rifle": {
		"id": "sniper_deadeye_rifle", "title": "Винтовка Мертвого Глаза",
		"description": "Lockshot: короткая фиксация линии, затем тяжелый точный выстрел с узким overpenetration.",
		"scene_path": "res://scenes/SniperDeadeyeRifle.tscn",
		"attack_mode": "sniper_lockshot", "damage_parameter": "damage",
		"damage_multiplier": 1.22, "fire_interval": 1.42,
		"attack_range": 940.0, "aoe_radius": 220.0,
		"beam_width": 34.0, "grenade_delay": 0.20,
		"damage_falloff": 0.38,
		"visual_color": Color(0.92, 0.96, 1.0, 0.46),
		"passive_mods": {"crit_chance_flat": 0.04},
	},
	"sniper_spotter_scope": {
		"id": "sniper_spotter_scope", "title": "Прицел Наводчика",
		"description": "Kill-zone: отмечает область вокруг цели и вызывает серию прицельных ударов по врагам внутри.",
		"scene_path": "res://scenes/SniperSpotterScope.tscn",
		"attack_mode": "sniper_kill_zone", "damage_parameter": "damage",
		"damage_multiplier": 0.82, "fire_interval": 1.34,
		"attack_range": 760.0, "aoe_radius": 210.0,
		"beam_width": 30.0, "projectile_count": 4,
		"grenade_delay": 0.22, "damage_falloff": 0.74,
		"visual_color": Color(1.0, 0.62, 0.18, 0.42),
		"passive_mods": {"range_multiplier": 1.04},
	},
	"sniper_shatter_rounds": {
		"id": "sniper_shatter_rounds", "title": "Осколочные Патроны",
		"description": "Split-round: основной выстрел по ближайшей цели, затем осколки расходятся веером по траекториям и могут пробить вторую цель.",
		"scene_path": "res://scenes/SniperShatterRounds.tscn",
		"attack_mode": "sniper_split_round", "damage_parameter": "damage",
		"damage_multiplier": 0.98, "fire_interval": 1.08,
		"attack_range": 820.0, "aoe_radius": 260.0,
		"beam_width": 38.0, "split_count": 3,
		"pierce_count": 2,
		"damage_falloff": 0.55,
		"visual_color": Color(0.50, 0.88, 1.0, 0.42),
		"passive_mods": {"crit_damage_multiplier": 1.08},
	},
}

const PRIEST_WEAPONS := {
	"priest_reliquary": {
		"id": "priest_reliquary", "title": "Светлый Реликварий",
		"description": "Sanctify: отмечает ближайшую цель святым знаком, затем знак взрывается и лечит Священника от нанесенного урона.",
		"scene_path": "res://scenes/PriestReliquary.tscn",
		"attack_mode": "priest_sanctify", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.96, "fire_interval": 1.22,
		"attack_range": 560.0, "aoe_radius": 190.0,
		"beam_width": 46.0, "grenade_delay": 0.24,
		"damage_falloff": 0.62, "heal_percent_of_damage": 0.08,
		"visual_color": Color(1.0, 0.92, 0.48, 0.42),
		"passive_mods": {"regeneration_flat": 0.18},
	},
	"priest_censer": {
		"id": "priest_censer", "title": "Кадило Обета",
		"description": "Ward pulses: вокруг Священника проходят несколько защитных волн, которые жгут врагов и дают малое лечение.",
		"scene_path": "res://scenes/PriestCenser.tscn",
		"attack_mode": "priest_ward", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.58, "fire_interval": 1.08,
		"attack_range": 260.0, "aoe_radius": 215.0,
		"storm_ticks": 3, "burst_interval": 0.13,
		"heal_percent_on_attack": 0.012,
		"visual_color": Color(0.96, 1.0, 0.70, 0.36),
		"passive_mods": {"defense_flat": 0.02},
	},
	"priest_chime": {
		"id": "priest_chime", "title": "Колокол Молитвы",
		"description": "Prayer chain: молитвенная нить перескакивает между врагами, каждый скачок возвращает часть силы Священнику.",
		"scene_path": "res://scenes/PriestChime.tscn",
		"attack_mode": "priest_prayer_chain", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.76, "fire_interval": 1.16,
		"attack_range": 620.0, "aoe_radius": 300.0,
		"projectile_count": 4, "beam_width": 34.0,
		"damage_falloff": 0.78, "heal_percent_of_damage": 0.06,
		"visual_color": Color(0.72, 0.92, 1.0, 0.40),
		"passive_mods": {"aura_radius_multiplier": 1.05},
	},
}

# SCRUM-896: редизайн кита Биолога — хрупкий био-реактивный класс с гибридным
# скейлом (физ/маг/DoT) и тремя РАЗНЫМИ нишами:
#   линза — ЛОКАЛЬНЫЙ AoE у персонажа (range резко срезан) + замедление всех
#     задетых 5%→20% от нормированной прогрессии (spore_slow_base/max);
#   инъектор — самый длинный пирсинг-луч: урон по всей длине (маг.ролл +
#     INJECTOR_PHYSICAL_SHARE канала damage — ось Силы) и малый бурст анализа
#     на конце (tip_burst_ratio, aoe_radius много меньше Линзы);
#   семя — дальняя темпоральная зона: прорастание через grenade_delay,
#     стартовый маг.хит (seed_impact_ratio), главный пейофф — биоинфекция
#     (dot_ticks × curse_tick_multiplier; generic-ключи периодики).
# Периодика всех трёх — status bio_infection с source_id владельца (топливо
# trait'а «Разбор образцов» SCRUM-1005). Оси скейла по оружиям задокументированы
# в docs/design/systems/characters_weapons.md; зеркала бюджета — bio-ветки
# _budget_hit_model/_budget_dot_dps.
const BIOLOGIST_WEAPONS := {
	"biologist_spore_lens": {
		"id": "biologist_spore_lens", "title": "Споровая Линза",
		"description": "Spore bloom: три расширяющихся споровых кольца у самого Биолога — ранят, заражают и замедляют задетых (замедление растёт с прогрессией).",
		"scene_path": "res://scenes/BiologistSporeLens.tscn",
		"attack_mode": "bio_spore_bloom", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.66, "fire_interval": 1.18,
		"attack_range": 235.0, "aoe_radius": 210.0,
		"storm_ticks": 3, "burst_interval": 0.16,
		"damage_falloff": 0.70, "dot_ticks": 2,
		"curse_tick_rate": 2.0, "curse_tick_multiplier": 1.0,
		"spore_slow_base": 0.05, "spore_slow_max": 0.20,
		"visual_color": Color(0.46, 1.0, 0.42, 0.40),
		"passive_mods": {"dot_damage_flat": 1.0},
	},
	"biologist_sample_injector": {
		"id": "biologist_sample_injector", "title": "Инъектор Образцов",
		"description": "Sample beam: пирсинг-луч ранит всех на своей длине (магия + доля физики), на конце — малый бурст анализа; ближайший враг получает пробу-инфекцию.",
		"scene_path": "res://scenes/BiologistSampleInjector.tscn",
		"attack_mode": "bio_sample_dart", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.85, "fire_interval": 1.05,
		"attack_range": 640.0, "aoe_radius": 96.0,
		"beam_width": 46.0, "damage_falloff": 0.64,
		"dot_ticks": 1, "curse_tick_rate": 1.2, "curse_tick_multiplier": 0.6,
		"tip_burst_ratio": 0.55,
		"visual_color": Color(0.70, 1.0, 0.28, 0.42),
		"passive_mods": {"crit_chance_flat": 0.025},
	},
	"biologist_symbiote_seed": {
		"id": "biologist_symbiote_seed", "title": "Семя Симбионта",
		"description": "Symbiote seed: дальнее семя прорастает с задержкой — стартовый магический удар и долгие пульсы заражения; главный урон приходит со временем.",
		"scene_path": "res://scenes/BiologistSymbioteSeed.tscn",
		"attack_mode": "bio_symbiote_web", "damage_parameter": "magic_damage",
		"damage_multiplier": 0.60, "fire_interval": 1.24,
		"attack_range": 700.0, "aoe_radius": 150.0,
		"grenade_delay": 0.55, "damage_falloff": 0.58,
		"dot_ticks": 6, "curse_tick_rate": 1.0, "curse_tick_multiplier": 1.6,
		"seed_impact_ratio": 0.85,
		"visual_color": Color(0.36, 0.92, 0.58, 0.42),
		"passive_mods": {"aura_radius_multiplier": 1.04},
	},
}

const ROBOT_WEAPONS := {
	# SCRUM-915/916/918: редизайн кита Робота (trait «Бронекорпус» — SCRUM-914,
	# см. CLASS_TRAITS.robot). Механики — ClassWeapon._fire_robot_*; зеркала
	# бюджета — ProgressionData._budget_hit_model.
	"robot_magnetic_anchor": {
		"id": "robot_magnetic_anchor", "title": "Магнитный Якорь",
		# SCRUM-915: редкий тяжёлый AoE-пулл. knockback = базовая мощь пулла
		# (конвергенция 0.85 пути к центру за каст, элитки/боссы не смещаются);
		# медленный базовый темп (fire_interval 2.05) разгоняется скоростью
		# атаки, aoe_radius растёт AoE-прогрессией — группировка «точка за точкой».
		# Легаси melee-identity ключи (arc followup / stagger) сняты редизайном:
		# стаггер расталкивал врагов ОТ игрока против собственного пулла и
		# смещал элиток/боссов вопреки AC SCRUM-915.
		"description": "Magnetic anchor: тяжелый якорь бьет по большой площади и стягивает рядовых врагов в центр зоны; элитки и боссы не смещаются, но урон получают полностью.",
		"scene_path": "res://scenes/RobotMagneticAnchor.tscn",
		"attack_mode": "robot_magnetic_anchor", "damage_parameter": "damage",
		"damage_multiplier": 1.55, "fire_interval": 2.05,
		"attack_range": 520.0, "aoe_radius": 250.0,
		"grenade_delay": 0.34, "knockback": 170.0,
		"damage_falloff": 0.72, "beam_width": 44.0,
		"visual_color": Color(0.42, 0.82, 1.0, 0.42),
		"passive_mods": {"absorb_flat": 2.0},
	},
	"robot_hydraulic_press": {
		"id": "robot_hydraulic_press", "title": "Гидравлический Пресс",
		# SCRUM-916: широкий коридор компрессии. Урон по ВСЕЙ ширине
		# suppression_width (300; ×1.30 с «Калибратором пресса»), рядовых
		# прижимает к осевой линии (конвергенция 0.80), элитки/боссы — резист
		# смещения x0.25 при полном уроне; beam_width = центральная «губка»/ось
		# для VFX. knockback = сила компрессии. Легаси melee-identity ключи
		# (close bonus / stagger) сняты редизайном: стаггер выталкивал врагов
		# вбок ОТ оси против собственной компрессии.
		"description": "Compression line: широкий коридор перед роботом давит врагов и сжимает их к осевой линии, выстраивая толпу в ровный ряд; элитки и боссы почти не смещаются.",
		"scene_path": "res://scenes/RobotHydraulicPress.tscn",
		"attack_mode": "robot_compression_line", "damage_parameter": "damage",
		"damage_multiplier": 1.05, "fire_interval": 1.35,
		"attack_range": 430.0, "aoe_radius": 180.0,
		"beam_width": 120.0, "suppression_width": 300.0,
		"grenade_delay": 0.20, "knockback": 130.0,
		"damage_falloff": 0.55,
		"visual_color": Color(0.94, 0.72, 0.36, 0.42),
		"passive_mods": {"defense_flat": 0.018},
	},
	"robot_reactor_core": {
		"id": "robot_reactor_core", "title": "Реакторное Ядро",
		# SCRUM-918: вращающийся 4-направленный веер. Ровно 4 вентиля 90°,
		# паттерн +6° по часовой после каждой атаки, БЕЗ самонаведения; урон
		# вентиля = ролл × 0.42 (REACTOR_VENT_DAMAGE_RATIO), extra_projectile
		# расширяет лопасти. projectile_count фиксирует 4 направления для
		# бюджет-модели/доков.
		"description": "Reactor vent: четыре фиксированных выброса крестом вокруг корпуса; после каждой атаки крест доворачивается на 6 градусов по часовой — веер обходит весь круг.",
		"scene_path": "res://scenes/RobotReactorCore.tscn",
		"attack_mode": "robot_reactor_vent", "damage_parameter": "damage",
		"damage_multiplier": 0.70, "fire_interval": 0.92,
		"attack_range": 300.0, "aoe_radius": 155.0,
		"beam_width": 96.0, "projectile_count": 4,
		"knockback": 135.0, "damage_falloff": 0.70,
		"visual_color": Color(0.36, 1.0, 0.86, 0.40),
		"passive_mods": {"regeneration_flat": 0.16},
	},
}

const ENGINEER_WEAPONS := {
	"engineer_sentry_wrench": {
		"id": "engineer_sentry_wrench", "title": "Ключ Часового",
		"description": "Sentry turret: разворачивает стационарную турель (лимит 2, новая заменяет старейшую); турели сами обстреливают ближайших врагов снарядами.",
		"scene_path": "res://scenes/EngineerSentryWrench.tscn",
		"attack_mode": "engineer_sentry_link", "damage_parameter": "damage",
		# SCRUM-888: переосмысление — РАЗВОРАЧИВАЕМЫЕ ПЕРСИСТЕНТНЫЕ ТУРЕЛИ.
		# damage_multiplier — урон одного снаряда турели; сустейн (2 турели ×
		# выстрел каждые amp_pulse_interval) моделируется summon-компонентом
		# бюджета: summon_attack_interval/summon_damage_multiplier зеркалят
		# реальный цикл scripts/sentry_turret.gd 1:1 (_budget_summon_dps).
		"damage_multiplier": 0.71, "fire_interval": 2.70,
		"upgrade_damage_exponent": 2.45,  # SCRUM-505: sentry scales from lvl20 DPS upgrades, not lvl1 flat damage
		"attack_range": 560.0, "aoe_radius": 170.0,
		# Залп = projectile_count + extra_projectile снарядов по РАЗНЫМ ближайшим
		# целям (damage_falloff^i на доп. снаряды). Одна цель в радиусе получает
		# ТОЛЬКО первый снаряд — соло не перегревается, толпа получает покрытие
		# (crowd-ось инженера aoe_target 1.12; residual-пара тюнера = старой).
		"projectile_count": 2,
		"amp_pulse_interval": 0.55,  # базовый темп турели; ÷ (1 + min(summon_amount*0.014 + leadership*0.006, 0.30))
		"max_summons": 2, "max_summons_cap": 2,  # SCRUM-888: жёсткий лимит 2 турели, старейшая заменяется с мини-VFX
		"damage_falloff": 0.55,  # спад на доп. снаряды залпа (2-й и далее)
		"summon_attack_interval": 0.55, "summon_damage_multiplier": 1.0,  # бюджет-зеркало цикла турели (не геймплей)
		"deploy_role": "turret_dps",
		"summon_role": "engineer_sentry",
		"summon_role_damage_multiplier": 1.45,  # SCRUM-546 (был 1.10)
		"sentry_splash_radius": 82.0,
		"sentry_splash_damage_multiplier": 0.24,
		"sentry_splash_target_cap": 2,
		"visual_color": Color(0.88, 0.70, 0.32, 0.42),
		"passive_mods": {"summon_bonus": 1.0},
	},
	"engineer_repair_drone": {
		"id": "engineer_repair_drone", "title": "Ремонтный Дрон",
		"description": "Repair drone: дрон связывает несколько целей дугой и возвращает часть нанесенного урона в ремонт корпуса.",
		"scene_path": "res://scenes/EngineerRepairDrone.tscn",
		"attack_mode": "engineer_repair_drone", "damage_parameter": "damage",
		"damage_multiplier": 0.82, "fire_interval": 1.08,
		"attack_range": 540.0, "aoe_radius": 260.0,
		"beam_width": 30.0, "projectile_count": 4,
		"damage_falloff": 0.68, "heal_percent_of_damage": 0.045,
		"deploy_role": "repair_chain",
		"summon_role": "support_drone",
		"summon_role_damage_multiplier": 0.92,
		"summon_support_heal_percent": 0.006,
		"visual_color": Color(0.48, 0.90, 1.0, 0.40),
		"passive_mods": {"regeneration_flat": 0.14},
	},
	"engineer_pressure_mines": {
		"id": "engineer_pressure_mines", "title": "Минная Сетка",
		"description": "Pressure mine grid: раскладывает три малые мины веером; каждая срабатывает отдельно при касании врагом.",
		"scene_path": "res://scenes/EngineerPressureMines.tscn",
		"attack_mode": "engineer_pressure_mines", "damage_parameter": "damage",
		"damage_multiplier": 0.96, "fire_interval": 1.46,
		"attack_range": 390.0, "aoe_radius": 125.0,
		"projectile_count": 3, "pool_duration": 3.0, "pool_tick_interval": 0.16,
		"damage_falloff": 0.62, "knockback": 82.0,
		"deploy_role": "mine_grid",
		"visual_color": Color(1.0, 0.54, 0.24, 0.42),
		"passive_mods": {"aoe_radius_multiplier": 1.05},
	},
}

const WEAPONS_BY_CLASS := {
	"berserk": BERSERK_WEAPONS,
	"soldier": SOLDIER_WEAPONS,
	"thief": THIEF_WEAPONS,
	"elementalist": ELEMENTALIST_WEAPONS,
	"sniper": SNIPER_WEAPONS,
	"priest": PRIEST_WEAPONS,
	"biologist": BIOLOGIST_WEAPONS,
	"robot": ROBOT_WEAPONS,
	"engineer": ENGINEER_WEAPONS,
	"dark_mage": DARK_MAGE_WEAPONS,
	"guitarist": GUITARIST_WEAPONS,
	"assassin": ASSASSIN_WEAPONS,
	"ranger": RANGER_WEAPONS,
	"doctor": DOCTOR_WEAPONS,
	"chemist": CHEMIST_WEAPONS,
	"knight": KNIGHT_WEAPONS,
	"druid": DRUID_WEAPONS,
}
