extends SceneTree

# Гейт прогрессии по классам (SCRUM-360). Проверяет в scripts/meta_progression.gd:
#   1. свежий state содержит пустой class_boss_wins;
#   2. record_boss_victory копит победы ПО КЛАССУ (per character);
#   3. накопительные пороги дают class_modifiers; изоляция — бонусы только своему
#      классу (другой класс не получает);
#   4. save/load round-trip class_boss_wins (персистентность, версия-совместимо);
#   5. class_next_threshold отдаёт следующий порог для UI.
#
# Отдельный изолированный файл (читает meta_progression + временный user://-путь).
# Запуск: Godot --headless --path . --script res://tests/class_progression_test.gd

const Meta := preload("res://scripts/meta_progression.gd")
const TEST_PATH := "user://test_class_progression.cfg"


func _initialize() -> void:
	var errors: Array = []
	_cleanup()

	# 1. Свежий state — пустой прогресс классов.
	var state := Meta.default_state()
	if Meta.class_boss_wins(state, "berserk") != 0:
		errors.append("свежий state: class_boss_wins должен быть 0")
	if not Meta.class_modifiers(state, "berserk").is_empty():
		errors.append("свежий state: class_modifiers должен быть пуст")

	# 2. Победы над боссом копятся ПО КЛАССУ.
	for i in range(9):
		state = Meta.record_boss_victory(state, "berserk", 0)
	if Meta.class_boss_wins(state, "berserk") != 9:
		errors.append("berserk должен иметь 9 побед, получено %d" % Meta.class_boss_wins(state, "berserk"))
	if Meta.class_boss_wins(state, "soldier") != 0:
		errors.append("soldier не играл — должно быть 0 побед")

	# 3. Накопительные бонусы достигнутых порогов (wins 1/2/4/6/9).
	var berserk_mods := Meta.class_modifiers(state, "berserk")
	if not is_equal_approx(float(berserk_mods.get("class_damage_mult", 0.0)), 0.12):
		errors.append("berserk class_damage_mult ожид. 0.12, получено %.3f" % float(berserk_mods.get("class_damage_mult", 0.0)))
	if not is_equal_approx(float(berserk_mods.get("class_max_health_mult", 0.0)), 0.06):
		errors.append("berserk class_max_health_mult ожид. 0.06, получено %.3f" % float(berserk_mods.get("class_max_health_mult", 0.0)))
	if not is_equal_approx(float(berserk_mods.get("class_attack_speed_mult", 0.0)), 0.04):
		errors.append("berserk class_attack_speed_mult ожид. 0.04")
	if Meta.class_level(state, "berserk") != 5:
		errors.append("berserk class_level ожид. 5, получено %d" % Meta.class_level(state, "berserk"))

	# 4. Изоляция: бонусы НЕ протекают на другой класс.
	if not Meta.class_modifiers(state, "soldier").is_empty():
		errors.append("class_modifiers protekает на чужой класс (soldier)")

	# Частичный порог: 3 победы новым классом → пороги 1,2 (не 4).
	for i in range(3):
		state = Meta.record_boss_victory(state, "thief", 0)
	if Meta.class_level(state, "thief") != 2:
		errors.append("thief после 3 побед ожид. 2 порога, получено %d" % Meta.class_level(state, "thief"))

	# 5. save/load round-trip.
	Meta.save_state(state, TEST_PATH)
	var loaded := Meta.load_state(TEST_PATH)
	if Meta.class_boss_wins(loaded, "berserk") != 9 or Meta.class_boss_wins(loaded, "thief") != 3:
		errors.append("class_boss_wins не пережил save/load (berserk %d, thief %d)" % [
			Meta.class_boss_wins(loaded, "berserk"), Meta.class_boss_wins(loaded, "thief")])

	# 6. class_next_threshold для UI.
	var fresh := Meta.default_state()
	var nxt := Meta.class_next_threshold(fresh, "berserk")
	if nxt.is_empty() or int(nxt.get("wins", 0)) != 1:
		errors.append("class_next_threshold для нового класса должен указывать на 1 победу")
	if not Meta.class_next_threshold(state, "berserk").is_empty():
		errors.append("полностью прокачанный класс (9 побед) не должен иметь следующего порога")

	# Анти-вакуум.
	if Meta.class_progression().size() < 3:
		errors.append("порогов прогрессии класса подозрительно мало")

	_cleanup()

	if not errors.is_empty():
		for e in errors:
			push_error("Class progression: %s" % e)
		push_error("Class progression: %d нарушений." % errors.size())
		quit(1)
		return
	print("Class progression passed (накопление per-class, изоляция бонусов, save/load, %d порогов)." % Meta.class_progression().size())
	quit(0)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_PATH):
		dir.remove(TEST_PATH)
