extends RefCounted

# SCRUM-198: shop-only item data. Artifact/reward data stays in progression_data_content.gd.

const SHOP_ITEMS := [
	{"id": "shop_damage", "title": "Точильный камень", "description": "+10% к урону.", "cost": 42, "mods": {"damage_multiplier": 1.10}},
	{"id": "shop_heal", "title": "Полевой бинт", "description": "Восстановить 35% максимального здоровья.", "cost": 28, "heal_percent": 0.35},
	{"id": "shop_pickup", "title": "Магнитный талисман", "description": "+35 к радиусу подбора.", "cost": 35, "mods": {"pickup_radius_flat": 35.0}},
	{"id": "shop_speed", "title": "Легкие сапоги", "description": "+8% к скорости движения.", "cost": 35, "mods": {"move_speed_multiplier": 1.08}},
	{"id": "shop_weapon_cooldown", "title": "Масло темпа", "description": "+10% к скорости атаки.", "cost": 46, "mods": {"attack_speed_multiplier": 1.10}},
	{"id": "shop_range", "title": "Линза охоты", "description": "+12% к области атаки.", "cost": 42, "mods": {"aoe_radius_multiplier": 1.12}},
	{"id": "shop_artifact", "title": "Пыльный артефакт", "description": "+1 случайная характеристика через Восприятие.", "cost": 52, "stats": {"perception": 1.0}},
]
