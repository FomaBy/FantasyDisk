extends SceneTree

# Smoke-тест sliced_rig_manifest.gd (был непокрыт). Манифест cutout-ригов:
# текстуры частей preload'ятся (существование гарантирует компиляция), НО
# строковый `source`-путь, ссылка `attack_part` на реальную часть, наличие
# torso и ПОКРЫТИЕ персонажей ригом компиляцией НЕ гарантированы — персонаж без
# рига рендерится сломанным. Это и гейтим. Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/sliced_rig_manifest_smoke_test.gd

const RigManifest := preload("res://scripts/sliced_rig_manifest.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []
	var data: Dictionary = RigManifest.DATA

	if data.size() < 10:
		errors.append("DATA подозрительно мал (%d) — гейт прошёл бы вакуумно" % data.size())

	for rig_id in data:
		var rid := str(rig_id)
		var entry: Dictionary = data[rig_id]

		# source — строковый путь (НЕ preload) -> может быть битым.
		var source := str(entry.get("source", ""))
		if source == "" or not ResourceLoader.exists(source):
			errors.append("риг '%s': source отсутствует/битый '%s'" % [rid, source])

		# Обязательные поля.
		for field in ["size", "style", "attack_part", "parts"]:
			if not entry.has(field):
				errors.append("риг '%s': нет поля '%s'" % [rid, field])
		if not (entry.get("size") is Vector2):
			errors.append("риг '%s': size не Vector2" % rid)
		if not (entry.get("socket", Vector2.ZERO) is Vector2):
			errors.append("риг '%s': socket не Vector2" % rid)

		var parts: Dictionary = entry.get("parts", {})
		if parts.is_empty():
			errors.append("риг '%s': пустой parts" % rid)
			continue
		# torso — базовая часть, обязана быть у всех.
		if not parts.has("torso"):
			errors.append("риг '%s': нет базовой части 'torso'" % rid)

		# Каждая часть: texture (Texture2D), pos/pivot (Vector2), z (число).
		for part_id in parts:
			var part: Dictionary = parts[part_id]
			var tex = part.get("texture")
			if not (tex is Texture2D):
				errors.append("риг '%s'/часть '%s': texture не Texture2D" % [rid, part_id])
			if not (part.get("pos") is Vector2):
				errors.append("риг '%s'/часть '%s': pos не Vector2" % [rid, part_id])
			if not (part.get("pivot") is Vector2):
				errors.append("риг '%s'/часть '%s': pivot не Vector2" % [rid, part_id])
			if not part.has("z"):
				errors.append("риг '%s'/часть '%s': нет z" % [rid, part_id])

		# attack_part обязан ссылаться на реальную часть рига.
		var attack_part := str(entry.get("attack_part", ""))
		if attack_part != "" and not parts.has(attack_part):
			errors.append("риг '%s': attack_part '%s' не существует среди частей" % [rid, attack_part])

	# Покрытие: каждый играбельный персонаж имеет cutout-риг (иначе сломанный рендер).
	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		if not data.has(cid):
			errors.append("персонаж '%s' без cutout-рига в манифесте" % cid)

	if not errors.is_empty():
		for e in errors:
			push_error("Sliced rig manifest smoke: %s" % e)
		push_error("Sliced rig manifest smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Sliced rig manifest smoke test passed (%d ригов, %d персонажей покрыто)." % [
		data.size(), ProgressionData.character_ids().size()])
	quit(0)
