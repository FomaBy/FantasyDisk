extends RefCounted

# SCRUM-198: enemy/minion content data owned outside the progression facade.

const MINI_ELITE_KINDS := [
	{"id": "mini_scavenger_reaper", "title": "Жнец-Падальщик", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.42, "speed_mult": 1.28, "damage_mult": 1.05, "tint": [0.86, 0.96, 0.78], "desc": "Быстрый падальщик: рывками косит по дуге, добивая раненых первыми."},
	{"id": "mini_plague_bellringer", "title": "Чумной Звонарь", "scene": "poisoned", "behavior": "plague_prophet", "hp_mult": 0.60, "speed_mult": 0.72, "damage_mult": 0.85, "tint": [0.72, 0.96, 0.62], "desc": "Медлительный звонарь чумы: сеет ядовитые лужи вокруг себя."},
	{"id": "mini_bone_warden", "title": "Костяной Страж", "scene": "armored", "behavior": "iron_bastion", "hp_mult": 0.86, "speed_mult": 0.66, "damage_mult": 1.0, "tint": [0.94, 0.92, 0.84], "desc": "Костяной танк: бьёт ударной волной и держит строй, прикрывая свиту."},
	{"id": "mini_spark_wight", "title": "Искровик", "scene": "commander", "behavior": "shard_marshal", "hp_mult": 0.50, "speed_mult": 0.92, "damage_mult": 0.95, "tint": [0.72, 0.86, 1.0], "desc": "Дальнобойный дух искр: бьёт залпом веером с предупреждающим телеграфом."},
	{"id": "mini_rot_hound", "title": "Гнилая Гончая", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.40, "speed_mult": 1.32, "damage_mult": 1.0, "tint": [0.82, 0.70, 0.60], "desc": "Стайная гончая гнили: налетает рывком, оставляя кровоточащие раны."},
	{"id": "mini_shadow_devourer", "title": "Теневой Пожиратель", "scene": "stalker", "behavior": "night_stalker", "hp_mult": 0.52, "speed_mult": 1.08, "damage_mult": 1.12, "tint": [0.56, 0.50, 0.76], "desc": "Тень-пожиратель: телепортируется к жертве после короткого телеграфа."},
]
