extends SceneTree

# Структурный гейт целостности оружия (постоянный регресс-гейт, комплемент к
# аудиту SCRUM-277 «weapon integrity 17×3»). Ловит класс багов, о котором сообщил
# пользователь (PriestChime/scene_path/подмена пассивкой): каждое оружие во всех
# классах должно быть НАСТОЯЩИМ активным оружием с резолвящейся сценой, а не
# опечаткой id / битым scene_path / случайно подменённым пассивкой.
#
# Проверяет по ВСЕМ парам класс×оружие:
#   1. id записи == ключу словаря (нет рассинхрона id, как PriestChime/priest_chime);
#   2. scene_path непустой И ResourceLoader.exists() (сцена реально грузится);
#   3. damage_multiplier > 0 (оружие активно, не выродилось в чистый пассив);
#   4. passive_mods, если есть, — Dictionary (пассивка не заместила весь конфиг);
#   5. id глобально уникален (нет коллизий между классами).
#
# Отдельный изолированный файл (только ЧИТАЕТ ProgressionData).
# Запуск: Godot --headless --path . --script res://tests/weapon_scene_integrity_test.gd

const PD := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []
	var total := 0
	var global_ids := {}  # weapon_id -> "class/weapon" первого владельца
	var used_attack_modes := {}  # attack_mode -> true (встреченные в data режимы)

	for character_id in PD.character_ids():
		var cid := str(character_id)
		var weapon_ids: Array = PD.weapon_ids(cid)
		if weapon_ids.is_empty():
			errors.append("класс '%s' без оружия" % cid)
			continue
		for weapon_id in weapon_ids:
			var wid := str(weapon_id)
			var cfg: Dictionary = PD.weapon(cid, wid)
			if cfg.is_empty():
				errors.append("%s/%s: пустой конфиг оружия" % [cid, wid])
				continue
			total += 1

			# 1. id записи совпадает с ключом (защита от PriestChime-рассинхрона).
			var rec_id := str(cfg.get("id", ""))
			if rec_id != wid:
				errors.append("%s/%s: поле id='%s' не совпадает с ключом '%s'" % [cid, wid, rec_id, wid])

			# 2. scene_path непустой и резолвится.
			var scene_path := str(cfg.get("scene_path", ""))
			if scene_path == "":
				errors.append("%s/%s: пустой scene_path" % [cid, wid])
			elif not ResourceLoader.exists(scene_path):
				errors.append("%s/%s: scene_path не резолвится — '%s'" % [cid, wid, scene_path])

			# 3. Активное оружие: положительный множитель урона (не выродилось в пассив).
			if float(cfg.get("damage_multiplier", 0.0)) <= 0.0:
				errors.append("%s/%s: damage_multiplier <= 0 (оружие подменено пассивкой?)" % [cid, wid])

			# 4. passive_mods структурно корректны.
			if cfg.has("passive_mods") and not (cfg["passive_mods"] is Dictionary):
				errors.append("%s/%s: passive_mods не Dictionary" % [cid, wid])

			# 4b. SCRUM-710: data-driven attack_mode обязан иметь зарегистрированный
			# исполнитель в ClassWeapon.ATTACK_MODE_EXECUTORS. Иначе оружие молча
			# проваливается в DEFAULT_ATTACK_MODE ('sound_wave') и стреляет чужой
			# атакой. attack_mode используется ТОЛЬКО class_weapon (berserk/summoner
			# не читают это поле), поэтому проверка применима ко всем, кто его задаёт.
			if cfg.has("attack_mode"):
				var mode := str(cfg["attack_mode"])
				used_attack_modes[mode] = true
				if not ClassWeapon.has_attack_mode_executor(mode):
					errors.append("%s/%s: attack_mode '%s' не зарегистрирован в ATTACK_MODE_EXECUTORS (молчаливый fallback в '%s')" % [cid, wid, mode, ClassWeapon.DEFAULT_ATTACK_MODE])

			# 5. Глобальная уникальность id.
			if global_ids.has(wid):
				errors.append("дубль weapon_id '%s': %s/%s == %s" % [wid, cid, wid, global_ids[wid]])
			else:
				global_ids[wid] = "%s/%s" % [cid, wid]

	# SCRUM-710: целостность реестра исполнителей атак. Каждый зарегистрированный
	# режим обязан резолвиться в реальный метод ClassWeapon (защита от опечатки
	# в ATTACK_MODE_EXECUTORS), и сам DEFAULT_ATTACK_MODE должен быть зарегистрирован
	# (иначе fallback в _execute_attack_mode упал бы с ошибкой вызова).
	var probe := ClassWeapon.new()
	for mode in ClassWeapon.registered_attack_modes():
		var executor_name := str(ClassWeapon.ATTACK_MODE_EXECUTORS[mode])
		if not probe.has_method(executor_name):
			errors.append("ATTACK_MODE_EXECUTORS['%s'] -> '%s' — метод не существует в ClassWeapon" % [mode, executor_name])
	if not ClassWeapon.has_attack_mode_executor(ClassWeapon.DEFAULT_ATTACK_MODE):
		errors.append("DEFAULT_ATTACK_MODE '%s' не зарегистрирован — fallback _execute_attack_mode сломан" % ClassWeapon.DEFAULT_ATTACK_MODE)
	probe.free()
	# Анти-вакуум: data реально задаёт attack_mode для приличного числа оружий.
	if used_attack_modes.size() < 12:
		errors.append("data-driven attack_mode подозрительно мало (%d уникальных) — реестр-гейт прошёл бы вакуумно" % used_attack_modes.size())

	# Анти-вакуум.
	if total < 40:
		errors.append("оружий подозрительно мало (%d) — гейт прошёл бы вакуумно" % total)
	if PD.character_ids().size() < 9:
		errors.append("классов подозрительно мало (%d)" % PD.character_ids().size())

	if not errors.is_empty():
		for e in errors:
			push_error("Weapon scene integrity: %s" % e)
		push_error("Weapon scene integrity: %d нарушений (оружий %d)." % [errors.size(), total])
		quit(1)
		return
	print("Weapon scene integrity passed (%d оружий, все scene_path резолвятся, id уникальны, активны; attack_mode-реестр полон: %d уникальных режимов из %d зарегистрированных)." % [total, used_attack_modes.size(), ClassWeapon.registered_attack_modes().size()])
	quit(0)
