extends SceneTree

# Smoke-тест ультимейтов классов (был непокрыт). У каждого играбельного класса
# есть ульта (ULTIMATE_CONFIGS); сломанная/неполная конфигурация = класс без
# работающего ультимейта, и это ничем не ловится (напр. damage_charge_rate=0 ->
# ульта не заряжается от нанесённого урона). Также сверяем покрытие
# CLASS_DAMAGE_PARAMETER. Отдельный изолированный файл (только ЧИТАЕТ
# progression_data.gd).
#
# Запуск: Godot --headless --path . --script res://tests/character_ultimate_config_test.gd

const PD := preload("res://scripts/progression_data.gd")

const VALID_DAMAGE_PARAMS := ["damage", "magic_damage", "sound_wave_damage"]


func _initialize() -> void:
	var errors: Array = []
	var ids := PD.character_ids()

	if PD.ULTIMATE_CONFIGS.size() < 9:
		errors.append("ULTIMATE_CONFIGS подозрительно мал (%d)" % PD.ULTIMATE_CONFIGS.size())

	# Каждый играбельный класс имеет ульту, и она структурно валидна.
	for character_id in ids:
		var cid := str(character_id)
		if not PD.ULTIMATE_CONFIGS.has(cid):
			errors.append("класс '%s' без записи в ULTIMATE_CONFIGS" % cid)
			continue
		var ult: Dictionary = PD.ultimate_config(cid)
		if ult.is_empty():
			errors.append("ultimate_config('%s') пуст" % cid)
			continue

		# Player-facing текст.
		if not _text_ok(str(ult.get("title", "")), cid):
			errors.append("ульта '%s': негодный title" % cid)
		if not _text_ok(str(ult.get("description", "")), cid):
			errors.append("ульта '%s': негодное описание" % cid)

		# Числовые поля.
		if float(ult.get("duration", -1.0)) < 0.0:
			errors.append("ульта '%s': duration < 0" % cid)
		if float(ult.get("radius", 0.0)) <= 0.0:
			errors.append("ульта '%s': radius <= 0" % cid)
		if float(ult.get("damage", 0.0)) <= 0.0:
			errors.append("ульта '%s': damage <= 0" % cid)
		# damage_charge_rate=0 -> ульта не заряжается от нанесённого урона.
		if float(ult.get("damage_charge_rate", 0.0)) <= 0.0:
			errors.append("ульта '%s': damage_charge_rate <= 0 — не заряжается уроном" % cid)
		if float(ult.get("taken_charge_rate", -1.0)) < 0.0:
			errors.append("ульта '%s': taken_charge_rate < 0" % cid)
		var boss_cap := float(ult.get("boss_cap", -1.0))
		if boss_cap <= 0.0 or boss_cap > 1.0:
			errors.append("ульта '%s': boss_cap вне (0,1] (%.3f)" % [cid, boss_cap])

		# Опциональные поля — если есть, должны быть осмысленны.
		if ult.has("target_count") and int(ult["target_count"]) <= 0:
			errors.append("ульта '%s': target_count <= 0" % cid)
		if ult.has("heal_ratio"):
			var hr := float(ult["heal_ratio"])
			if hr < 0.0 or hr > 1.0:
				errors.append("ульта '%s': heal_ratio вне [0,1] (%.3f)" % [cid, hr])

	# Фоллбэк для неизвестного класса -> непустой (берсерк).
	if PD.ultimate_config("__unknown_class__").is_empty():
		errors.append("ultimate_config неизвестного класса не дал фоллбэк")

	# CLASS_DAMAGE_PARAMETER покрывает всех персонажей валидным параметром.
	for character_id in ids:
		var cid := str(character_id)
		if not PD.CLASS_DAMAGE_PARAMETER.has(cid):
			errors.append("CLASS_DAMAGE_PARAMETER без записи для '%s'" % cid)
		elif not VALID_DAMAGE_PARAMS.has(str(PD.CLASS_DAMAGE_PARAMETER[cid])):
			errors.append("CLASS_DAMAGE_PARAMETER['%s'] = '%s' вне %s" % [cid, PD.CLASS_DAMAGE_PARAMETER[cid], str(VALID_DAMAGE_PARAMS)])

	if not errors.is_empty():
		for e in errors:
			push_error("Character ultimate config: %s" % e)
		push_error("Character ultimate config test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Character ultimate config test passed (%d ультимейтов, %d персонажей покрыто)." % [
		PD.ULTIMATE_CONFIGS.size(), ids.size()])
	quit(0)


func _text_ok(text: String, id: String) -> bool:
	if text.strip_edges() == "" or text == id:
		return false
	var low := text.to_lower()
	return not (low == "null" or low.begins_with("res://"))
