extends SceneTree

# Стартовые бооны забега (SCRUM-618). Проверяет данные/фасад в
# scripts/progression_data_content.gd + scripts/progression_data.gd и
# персистентность выбора через scripts/run_autosave.gd:
#   1. каталог: 6-8 боонов, id уникальны/непусты, mods непусты и из разрешённого
#      словаря ключей (совпадает с player.apply_meta_skill_modifiers);
#   2. БАЛАНС: «эффективная боевая сила» каждого боона <= +10% (мелкие mods);
#   3. ТОЖДЕСТВЕННОСТЬ: start_boon_mods("") == {} и для неизвестного id == {}
#      (нет боона = нейтральный старт);
#   4. персистентность: selected_start_boon_id переживает RunAutosave save/load.
#
# Отдельный изолированный файл. Запуск:
#   Godot --headless --path . --script res://tests/start_boons_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")
const RunAutosave := preload("res://scripts/run_autosave.gd")
const TEST_PATH := "user://test_start_boons_autosave.cfg"

# Допустимые ключи mods боонов — те же, что понимает player.apply_meta_skill_modifiers
# (META_SKILL_MULT_MAP + META_SKILL_FLAT_MAP). Чужой ключ = молча проигнорирован → баг.
const ALLOWED_MULT_KEYS := ["damage_mult", "attack_speed_mult", "max_health_mult",
	"xp_gain_mult", "money_gain_mult", "ult_charge_mult", "elite_boss_damage_mult"]
const ALLOWED_FLAT_KEYS := ["defense_flat", "dodge_flat", "regeneration_flat"]

const POWER_CAP := 1.10  # эффективная боевая сила боона не выше +10%


# Грубая оценка боевой «эффективной силы» боона: урон × скорость атаки × HP ×
# митигейт. Утилити-ключи (xp/money/ult_charge) в боевую силу не входят.
func _boon_power(mods: Dictionary) -> float:
	var dmg := 1.0 + float(mods.get("damage_mult", 0.0)) + 0.5 * float(mods.get("elite_boss_damage_mult", 0.0))
	var atk := 1.0 + float(mods.get("attack_speed_mult", 0.0))
	var hp := 1.0 + float(mods.get("max_health_mult", 0.0))
	var mitigation := 1.0 + float(mods.get("defense_flat", 0.0)) + float(mods.get("dodge_flat", 0.0)) + 0.02 * float(mods.get("regeneration_flat", 0.0))
	return dmg * atk * hp * mitigation


func _initialize() -> void:
	var errors: Array = []
	_cleanup()

	var boons := ProgressionData.start_boons()

	# 1. Каталог: количество, уникальность id, непустые mods, валидные ключи.
	if boons.size() < 6 or boons.size() > 8:
		errors.append("боонов должно быть 6-8, есть %d" % boons.size())
	var seen := {}
	for boon in boons:
		var bd: Dictionary = boon
		var bid := str(bd.get("id", ""))
		if bid == "":
			errors.append("боон с пустым id")
			continue
		if seen.has(bid):
			errors.append("дублирующийся id боона '%s'" % bid)
		seen[bid] = true
		var mods: Dictionary = bd.get("mods", {})
		if mods.is_empty():
			errors.append("боон '%s' без mods" % bid)
		for key in mods.keys():
			if not (ALLOWED_MULT_KEYS.has(str(key)) or ALLOWED_FLAT_KEYS.has(str(key))):
				errors.append("боон '%s': неизвестный ключ mods '%s' (player его проигнорирует)" % [bid, str(key)])
		if str(bd.get("title", "")) == "":
			errors.append("боон '%s' без title" % bid)
		if str(bd.get("description", "")) == "":
			errors.append("боон '%s' без description" % bid)

	# 2. Баланс: боевая сила каждого боона <= +10%.
	for boon in boons:
		var bd: Dictionary = boon
		var power := _boon_power(bd.get("mods", {}))
		if power > POWER_CAP + 0.0001:
			errors.append("боон '%s': боевая сила %.3f > порога %.2f" % [str(bd.get("id", "")), power, POWER_CAP])

	# 3. Тождественность: "" и неизвестный id → пустые mods.
	if not ProgressionData.start_boon_mods("").is_empty():
		errors.append("start_boon_mods('') должен быть пуст (нет боона = нейтральный старт)")
	if not ProgressionData.start_boon_mods("definitely_not_a_boon").is_empty():
		errors.append("start_boon_mods(неизвестный) должен быть пуст")
	# Известный боон → непустые mods, равные каталогу.
	if not boons.is_empty():
		var sample_id := str((boons[0] as Dictionary).get("id", ""))
		var sample_mods := ProgressionData.start_boon_mods(sample_id)
		if sample_mods.is_empty():
			errors.append("start_boon_mods('%s') не должен быть пуст" % sample_id)
		# Возвращается КОПИЯ (мутация не портит каталог).
		sample_mods["damage_mult"] = 999.0
		if float(ProgressionData.start_boon_mods(sample_id).get("damage_mult", 0.0)) == 999.0:
			errors.append("start_boon_mods вернул ссылку на каталог (мутация просочилась)")

	# 4. Персистентность: selected_start_boon_id переживает RunAutosave save/load.
	var boon_to_save := str((boons[0] as Dictionary).get("id", "")) if not boons.is_empty() else "glass_edge"
	var ok := RunAutosave.save_run({
		"selected_character_id": "berserk",
		"selected_weapon_id": "sword",
		"selected_start_boon_id": boon_to_save,
		"route_stage": 0,
	}, TEST_PATH)
	if not ok:
		errors.append("RunAutosave.save_run не сохранил фикстуру с бооном")
	else:
		var loaded := RunAutosave.load_run(TEST_PATH)
		if str(loaded.get("selected_start_boon_id", "")) != boon_to_save:
			errors.append("selected_start_boon_id не пережил save/load ('%s' != '%s')" % [
				str(loaded.get("selected_start_boon_id", "")), boon_to_save])

	_cleanup()

	if not errors.is_empty():
		for e in errors:
			push_error("Start boons: %s" % e)
		push_error("Start boons test: %d нарушений." % errors.size())
		quit(1)
		return
	print("Start boons test passed (%d боонов, сила <=+10%%, тождественность, autosave round-trip)." % boons.size())
	quit(0)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_PATH):
		dir.remove(TEST_PATH)
