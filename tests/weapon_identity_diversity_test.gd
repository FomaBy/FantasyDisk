extends SceneTree

# Гейт уникальности оружия (тема патча 0.1.5 «уникальный геймплей на каждом
# оружии»). Две пушки не должны схлопнуться в МЕХАНИЧЕСКИ идентичный конфиг
# (одинаковая геймплейная сигнатура) — ни внутри класса, ни глобально. Ловит
# случайные копипаст-дубли при массовом ребалансе 51 оружия. Сигнатура — сырой
# WEAPONS_BY_CLASS-конфиг без меток id/title/description и косметики visual_color.
# Отдельный изолированный файл (только ЧИТАЕТ ProgressionData).
#
# Запуск: Godot --headless --path . --script res://tests/weapon_identity_diversity_test.gd

const PD := preload("res://scripts/progression_data.gd")

# Поля-метки и косметика, не влияющие на механику.
const IGNORED_KEYS := ["id", "title", "description", "visual_color"]


func _signature(config: Dictionary) -> String:
	var clean := {}
	for key in config:
		if str(key) in IGNORED_KEYS:
			continue
		clean[str(key)] = config[key]
	# Сортируем ключи для стабильной сериализации.
	var sorted_keys := clean.keys()
	sorted_keys.sort()
	var ordered := {}
	for k in sorted_keys:
		ordered[k] = clean[k]
	return JSON.stringify(ordered)


func _initialize() -> void:
	var errors: Array = []
	var total := 0
	var global_sigs := {}  # signature -> "class/weapon" первого владельца

	for character_id in PD.character_ids():
		var cid := str(character_id)
		var class_weapons: Dictionary = PD.WEAPONS_BY_CLASS.get(cid, {})
		var weapon_ids: Array = PD.weapon_ids(cid)
		if weapon_ids.is_empty():
			errors.append("класс '%s' без оружия" % cid)
			continue
		var seen_in_class := {}  # signature -> wid
		for weapon_id in weapon_ids:
			var wid := str(weapon_id)
			var raw: Dictionary = class_weapons.get(wid, {})
			if raw.is_empty():
				errors.append("%s/%s: пустой конфиг" % [cid, wid])
				continue
			total += 1
			# Базовая валидность.
			if str(raw.get("scene_path", "")) == "":
				errors.append("%s/%s: пустой scene_path" % [cid, wid])
			if float(raw.get("damage_multiplier", 0.0)) <= 0.0:
				errors.append("%s/%s: damage_multiplier <= 0" % [cid, wid])

			var sig := _signature(raw)
			# Внутри класса — строго уникально.
			if seen_in_class.has(sig):
				errors.append("%s: оружие '%s' механически идентично '%s' (дубль внутри класса)" % [cid, wid, seen_in_class[sig]])
			else:
				seen_in_class[sig] = wid
			# Глобально — нет полных дублей.
			if global_sigs.has(sig):
				errors.append("полный дубль геймплея: %s/%s == %s" % [cid, wid, global_sigs[sig]])
			else:
				global_sigs[sig] = "%s/%s" % [cid, wid]

	# Анти-вакуум.
	if total < 40:
		errors.append("оружий подозрительно мало (%d) — гейт прошёл бы вакуумно" % total)
	if PD.character_ids().size() < 9:
		errors.append("классов подозрительно мало (%d)" % PD.character_ids().size())

	if not errors.is_empty():
		for e in errors:
			push_error("Weapon identity diversity: %s" % e)
		push_error("Weapon identity diversity: %d нарушений (оружий %d)." % [errors.size(), total])
		quit(1)
		return
	print("Weapon identity diversity passed (%d оружий, %d уникальных сигнатур, дублей нет)." % [total, global_sigs.size()])
	quit(0)
