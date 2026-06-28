extends RefCounted

# SCRUM-198: enemy/minion content data owned outside the progression facade.

const ENEMY_SIZE_PROFILES := {
	"ordinary": {"scale": 1.0, "label": "Обычный враг"},
	"mini_elite": {"scale": 1.05, "label": "Мини-элитка Возвышения"},
	"elite": {"scale": 1.68, "label": "Карточная элитка"},
	"boss": {"scale": 1.90, "label": "Босс"},
}

const MINI_ELITE_KINDS := [
	{"id": "mini_scavenger_reaper", "title": "Жнец-Падальщик", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.42, "speed_mult": 1.28, "damage_mult": 1.05, "tint": [0.86, 0.96, 0.78], "desc": "Быстрый падальщик: рывками косит по дуге, добивая раненых первыми."},
	{"id": "mini_plague_bellringer", "title": "Чумной Звонарь", "scene": "poisoned", "behavior": "plague_prophet", "hp_mult": 0.60, "speed_mult": 0.72, "damage_mult": 0.85, "tint": [0.72, 0.96, 0.62], "desc": "Медлительный звонарь чумы: сеет ядовитые лужи вокруг себя."},
	{"id": "mini_bone_warden", "title": "Костяной Страж", "scene": "armored", "behavior": "iron_bastion", "hp_mult": 0.86, "speed_mult": 0.66, "damage_mult": 1.0, "tint": [0.94, 0.92, 0.84], "desc": "Костяной танк: бьёт ударной волной и держит строй, прикрывая свиту."},
	{"id": "mini_spark_wight", "title": "Искровик", "scene": "commander", "behavior": "shard_marshal", "hp_mult": 0.50, "speed_mult": 0.92, "damage_mult": 0.95, "tint": [0.72, 0.86, 1.0], "desc": "Дальнобойный дух искр: бьёт залпом веером с предупреждающим телеграфом."},
	{"id": "mini_rot_hound", "title": "Гнилая Гончая", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.40, "speed_mult": 1.32, "damage_mult": 1.0, "tint": [0.82, 0.70, 0.60], "desc": "Стайная гончая гнили: налетает рывком, оставляя кровоточащие раны."},
	{"id": "mini_shadow_devourer", "title": "Теневой Пожиратель", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.52, "speed_mult": 1.08, "damage_mult": 1.12, "tint": [0.56, 0.50, 0.76], "desc": "Тень-пожиратель: телепортируется к жертве после короткого телеграфа."},
	# SCRUM-607: +4 новых вида с перевешенными статами (танк-таран / рой-снайпер /
	# чумной-берсерк / фантом). Только tint существующих rig, без нового арта.
	{"id": "mini_siege_rammer", "title": "Осадный Таран", "scene": "armored", "behavior": "iron_bastion", "hp_mult": 1.18, "speed_mult": 0.78, "damage_mult": 1.35, "tint": [0.96, 0.74, 0.42], "desc": "Бронированный таран: толстый панцирь и тяжёлая ударная волна, но медлителен."},
	{"id": "mini_swarm_sniper", "title": "Роевой Снайпер", "scene": "commander", "behavior": "shard_marshal", "hp_mult": 0.38, "speed_mult": 1.04, "damage_mult": 1.22, "tint": [0.52, 0.94, 0.90], "desc": "Хрупкий дальнобой роя: бьёт точным залпом издали, но падает от пары ударов."},
	{"id": "mini_plague_berserker", "title": "Чумной Берсерк", "scene": "poisoned", "behavior": "plague_prophet", "hp_mult": 0.64, "speed_mult": 1.14, "damage_mult": 1.18, "tint": [0.60, 0.82, 0.34], "desc": "Бешеный носитель чумы: напористо лезет вплотную и заливает ядом по площади."},
	{"id": "mini_void_phantom", "title": "Фантом Бездны", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.34, "speed_mult": 1.42, "damage_mult": 1.28, "tint": [0.46, 0.40, 0.86], "desc": "Стремительный фантом: молниеносные блинк-удары, но тает под фокусом."},
]

const ENEMY_MECHANIC_CATALOG := {
	"aura_buff": {"title": "Аура усиления", "telegraph": false, "desc": "Усиливает свиту или себя в читаемом радиусе."},
	"summon_retinue": {"title": "Призыв свиты", "telegraph": false, "desc": "Поднимает адъютантов/рой с лимитом активных существ."},
	"blink_reposition": {"title": "Телепорт/блинк", "telegraph": true, "desc": "Сначала показывает точку выхода, затем меняет позицию."},
	"hazard_pool": {"title": "Опасная лужа", "telegraph": true, "desc": "Отложенная зона с уроном или контролем после предупреждения."},
	"poison_dot": {"title": "Яд/DoT", "telegraph": true, "desc": "Оставляет тикающий урон в зоне или от попадания."},
	"shield_block": {"title": "Блок/щит", "telegraph": false, "desc": "Временно режет входящий урон и меняет tint."},
	"charge_telegraph": {"title": "Рывок с предупреждением", "telegraph": true, "desc": "Опасная прямая атака с окном на уклонение."},
	"reflect_thorns": {"title": "Шипованный панцирь", "telegraph": false, "desc": "Возвращает часть угрозы, если бить активную защиту вблизи."},
	"slow_zone": {"title": "Замедляющая зона", "telegraph": true, "desc": "Зона контроля, снижающая темп героя."},
	"vampirism": {"title": "Вампиризм", "telegraph": true, "desc": "Опасный укус/удар лечит владельца при попадании."},
	"rift_wave": {"title": "Волна разлома", "telegraph": true, "desc": "Серия зон с гарантированным безопасным проходом."},
	"mirror_double": {"title": "Зеркальный двойник", "telegraph": true, "desc": "Вторая теневая точка атаки во второй фазе."},
	"gravity_pull": {"title": "Гравитационная воронка", "telegraph": true, "desc": "Притягивает героя к центру после предупреждения."},
	"weakpoint_shell": {"title": "Хрупкий панцирь", "telegraph": false, "desc": "Сильная защита с короткими окнами уязвимости."},
	"healing_inversion": {"title": "Проклятие лечения", "telegraph": true, "desc": "Тематический debuff-hook для будущего расширения лечения."},
	"split_spawn": {"title": "Раскол/выводок", "telegraph": false, "desc": "Создает дополнительную угрозу при фазе или низком HP."},
}

const ELITE_ATTACK_CONFIGS := {
	"iron_bastion": {
		"attack_id": "slam_wave",
		"cooldown": 6.0, "windup": 0.6, "strike": 0.25, "recover": 0.5,
		"trigger_range": 340.0, "radius": 260.0,
		"damage_factor": 2.0, "knockback": 150.0,
	},
	"night_stalker": {
		"attack_id": "shadow_strike",
		"cooldown": 7.0, "windup": 0.5, "strike": 0.18, "recover": 0.45,
		"trigger_range": 540.0, "radius": 92.0,
		"damage_factor": 2.4, "behind_offset": 74.0,
	},
	"plague_prophet": {
		"attack_id": "poison_volley",
		"cooldown": 8.0, "windup": 0.45, "strike": 0.35, "recover": 0.5,
		"trigger_range": 560.0, "radius": 56.0,
		"damage_factor": 0.8, "lob_count": 3, "lob_spread": 130.0,
		"puddle_duration": 3.0, "tick_interval": 0.6, "lob_travel_time": 0.4,
	},
	"shard_marshal": {
		"attack_id": "shard_fan",
		"cooldown": 6.0, "windup": 0.5, "strike": 0.2, "recover": 0.4,
		"trigger_range": 620.0, "radius": 0.0,
		"damage_factor": 1.0, "shard_count": 5, "spread_degrees": 60.0,
		"shard_speed": 430.0,
	},
}

const UNIQUE_ENCOUNTER_PATTERNS := {
	"iron_bastion": {
		"title": "Железная цитадель", "kind": "elite",
		"attack_id": "slam_wave",
		"mechanics": ["shield_block", "reflect_thorns", "charge_telegraph"],
		"summary": "щит, отражающий панцирь и читаемая ударная волна",
	},
	"night_stalker": {
		"title": "Охота из тени", "kind": "elite",
		"attack_id": "shadow_strike",
		"mechanics": ["blink_reposition", "mirror_double", "charge_telegraph"],
		"summary": "метка выхода, телепорт и двойной теневой заход во второй фазе",
	},
	"plague_prophet": {
		"title": "Проповедь гнили", "kind": "elite",
		"attack_id": "poison_volley",
		"mechanics": ["hazard_pool", "poison_dot", "healing_inversion"],
		"summary": "ядовитые лобы, тикающие лужи и проклятая чумная тема",
	},
	"shard_marshal": {
		"title": "Командир осколков", "kind": "elite",
		"attack_id": "shard_fan",
		"mechanics": ["aura_buff", "gravity_pull", "rift_wave"],
		"summary": "аура свиты, веер осколков и фазовое кольцо залпов",
	},
	"rift_warden": {
		"title": "Страж разлома", "kind": "boss",
		"mechanics": ["rift_wave", "summon_retinue", "shield_block", "gravity_pull"],
		"summary": "зоны разлома, свита, щит и гравитационные воронки",
	},
	"disk_devourer": {
		"title": "Пожиратель диска", "kind": "boss",
		"mechanics": ["charge_telegraph", "hazard_pool", "vampirism", "rift_wave"],
		"summary": "рывок, slam, радиальный взрыв и вампирский укус вблизи",
	},
	"bone_archon": {
		"title": "Костяной архонт", "kind": "boss",
		"mechanics": ["summon_retinue", "rift_wave", "split_spawn", "hazard_pool"],
		"summary": "легион, веер черепов и костяная стена с проходом",
	},
	"brood_mother": {
		"title": "Матерь роя", "kind": "boss",
		"mechanics": ["summon_retinue", "slow_zone", "charge_telegraph", "split_spawn"],
		"summary": "выводок, паутины, финальный бросок и давление числом",
	},
	"ashen_colossus": {
		"title": "Пепельный колосс", "kind": "boss",
		"mechanics": ["hazard_pool", "reflect_thorns", "weakpoint_shell", "rift_wave"],
		"summary": "slam-волны, тлеющие зоны, раскаленный панцирь и энрейдж",
	},
}
