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

	# --- SCRUM-620: челленджи класса за разнообразие забега ---
	# Бэк-совместимость: thief выше набрал 3 победы БЕЗ weapon_id (run_context пуст) —
	# weapon_diversity НЕ должен сработать (пустой набор оружий).
	if Meta.class_challenges_done(state, "thief").has("weapon_master"):
		errors.append("620: weapon_master не должен срабатывать без weapon_id (legacy-вызовы)")

	var ch := Meta.default_state()
	# 1. Diversity: победы 3 РАЗНЫМИ оружиями → weapon_master done.
	ch = Meta.record_boss_victory(ch, "ranger", 0, {"weapon_id": "moon_crossbow", "used_shop": true})
	ch = Meta.record_boss_victory(ch, "ranger", 0, {"weapon_id": "moon_crossbow", "used_shop": true})  # дубль оружия — не считается новым
	if Meta.class_challenges_done(ch, "ranger").has("weapon_master"):
		errors.append("620: weapon_master не должен срабатывать на 1 уникальном оружии (2 победы одним moon_crossbow)")
	ch = Meta.record_boss_victory(ch, "ranger", 0, {"weapon_id": "storm_longbow", "used_shop": true})
	ch = Meta.record_boss_victory(ch, "ranger", 0, {"weapon_id": "hunter_trap", "used_shop": true})
	if not Meta.class_challenges_done(ch, "ranger").has("weapon_master"):
		errors.append("620: 3 разных оружия должны выполнить weapon_master")
	# Прогресс-метрики: ровно 3 уникальных оружия.
	if Meta.class_challenge_progress_for(ch, "ranger")["weapons"].size() != 3:
		errors.append("620: weapons прогресс должен содержать 3 уникальных, получено %d" % Meta.class_challenge_progress_for(ch, "ranger")["weapons"].size())

	# 2. Дедуп: повторное выполнение НЕ дублирует id в done.
	var done_before := Meta.class_challenges_done(ch, "ranger").size()
	ch = Meta.record_boss_victory(ch, "ranger", 0, {"weapon_id": "moon_crossbow", "used_shop": true})
	if Meta.class_challenges_done(ch, "ranger").size() != done_before:
		errors.append("620: повторная победа дублирует выполненный челлендж (было %d, стало %d)" % [done_before, Meta.class_challenges_done(ch, "ranger").size()])

	# 3. Изоляция: бонусы челленджей не протекают на другой класс.
	if not Meta.class_challenge_modifiers(ch, "berserk").is_empty():
		errors.append("620: class_challenge_modifiers протекает на чужой класс")

	# 4. Schema 6 хранит выполненные челленджи только для discovery/reveal:
	# они не должны добавлять скрытый боевой бонус.
	var ranger_ch_mods := Meta.class_challenge_modifiers(ch, "ranger")
	if not ranger_ch_mods.is_empty():
		errors.append("620: Schema 6 не должен возвращать боевые модификаторы за weapon_master: %s" % str(ranger_ch_mods))

	# 5. high_asc_win по run_level; no_shop_win по used_shop=false.
	var ch2 := Meta.default_state()
	ch2 = Meta.record_boss_victory(ch2, "doctor", 3, {"weapon_id": "restore_potion", "used_shop": false})
	if not Meta.class_challenges_done(ch2, "doctor").has("peak_climber"):
		errors.append("620: победа на возвышении 3 должна выполнить peak_climber")
	if not Meta.class_challenges_done(ch2, "doctor").has("lone_wolf"):
		errors.append("620: победа без магазина должна выполнить lone_wolf")
	# used_shop=true НЕ должен засчитывать lone_wolf новому классу.
	var ch3 := Meta.default_state()
	ch3 = Meta.record_boss_victory(ch3, "knight", 0, {"weapon_id": "long_spear", "used_shop": true})
	if Meta.class_challenges_done(ch3, "knight").has("lone_wolf"):
		errors.append("620: с покупкой в магазине lone_wolf не должен выполняться")
	if Meta.class_challenges_done(ch3, "knight").has("peak_climber"):
		errors.append("620: возвышение 0 не должно выполнять peak_climber")

	# 6. Анти-крип: суммарный вклад челленджей на ключ не превышает потолок +5%.
	for key in ranger_ch_mods.keys():
		if float(ranger_ch_mods[key]) > Meta.CLASS_CHALLENGE_MAX_BONUS + 0.0001:
			errors.append("620: вклад челленджа '%s' %.3f превышает потолок %.3f" % [str(key), float(ranger_ch_mods[key]), Meta.CLASS_CHALLENGE_MAX_BONUS])

	# 7. save/load round-trip челленджей (метрики + выполненные).
	Meta.save_state(ch, TEST_PATH)
	var loaded_ch := Meta.load_state(TEST_PATH)
	if not Meta.class_challenges_done(loaded_ch, "ranger").has("weapon_master"):
		errors.append("620: weapon_master не пережил save/load")
	if Meta.class_challenge_progress_for(loaded_ch, "ranger")["weapons"].size() != 3:
		errors.append("620: weapons-прогресс не пережил save/load")

	# Анти-вакуум: челленджей >= 3, и свежий state пуст по челленджам.
	if Meta.CLASS_CHALLENGES.size() < 3:
		errors.append("620: челленджей класса подозрительно мало")
	if not Meta.class_challenges_done(Meta.default_state(), "ranger").is_empty():
		errors.append("620: свежий state должен иметь пустые челленджи")

	_cleanup()

	if not errors.is_empty():
		for e in errors:
			push_error("Class progression: %s" % e)
		push_error("Class progression: %d нарушений." % errors.size())
		quit(1)
		return
	print("Class progression passed (per-class накопление, изоляция, save/load, %d порогов, %d челленджей SCRUM-620)." % [Meta.class_progression().size(), Meta.CLASS_CHALLENGES.size()])
	quit(0)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_PATH):
		dir.remove(TEST_PATH)
