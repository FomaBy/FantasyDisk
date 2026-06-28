extends SceneTree

# Персистентные ачивки забега (SCRUM-617). Проверяет scripts/achievements_data.gd
# и хранение в scripts/meta_progression.gd:
#   1. свежий state — ачивок нет;
#   2. evaluate_run разблокирует ачивку при достигнутом пороге метрики и
#      начисляет meta_points;
#   3. РОВНО ОДИН РАЗ: повторный evaluate_run с тем же (или большим) результатом
#      НЕ начисляет очки и не дублирует id;
#   4. независимые метрики открывают независимые ачивки; ниже порога — не открывает;
#   5. суммарная награда == sum reward_meta_points открытых ачивок;
#   6. save/load round-trip: разблокированные ачивки и meta_points переживают
#      перезапуск; после загрузки повтор тоже не начисляет.
#
# Отдельный изолированный файл (читает achievements_data + meta_progression +
# временный user://-путь). Запуск:
#   Godot --headless --path . --script res://tests/achievements_smoke_test.gd

const Achievements := preload("res://scripts/achievements_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const TEST_PATH := "user://test_achievements.cfg"


func _initialize() -> void:
	var errors: Array = []
	_cleanup()

	# 1. Свежий state — ачивок нет.
	var state := Meta.default_state()
	if Achievements.unlocked_count(state) != 0:
		errors.append("свежий state: ачивок быть не должно, есть %d" % Achievements.unlocked_count(state))

	# 2. Достижение порога открывает ачивку + награда.
	var first := Achievements.achievement_by_id("first_blood")
	if first.is_empty():
		errors.append("ачивка first_blood не найдена в каталоге")
	else:
		var metric := str(first["metric"])  # "kills"
		var threshold := int(first["threshold"])  # 50
		var reward := int(first["reward_meta_points"])
		var points_before := int(state.get("meta_points", 0))
		var res := Achievements.evaluate_run(state, {metric: threshold})
		if not Achievements.is_unlocked(state, "first_blood"):
			errors.append("first_blood должна открыться при kills == порог")
		if not (res["newly_unlocked"] as Array).has("first_blood"):
			errors.append("newly_unlocked должен содержать first_blood")
		if int(res["awarded"]) != reward:
			errors.append("awarded ожид. %d, получено %d" % [reward, int(res["awarded"])])
		if int(state.get("meta_points", 0)) != points_before + reward:
			errors.append("meta_points не увеличились на награду (%d -> %d, ожид +%d)" % [
				points_before, int(state.get("meta_points", 0)), reward])

		# 3. РОВНО ОДИН РАЗ: повтор той же открытой ачивки не начисляет и не дублирует.
		# ВАЖНО: тот же threshold (не больше), чтобы не задеть другие пороги (напр. slayer).
		var points_after := int(state.get("meta_points", 0))
		var count_after := Achievements.unlocked_count(state)
		var res2 := Achievements.evaluate_run(state, {metric: threshold})
		if int(res2["awarded"]) != 0 or not (res2["newly_unlocked"] as Array).is_empty():
			errors.append("повторная оценка открытой ачивки не должна ничего начислять")
		if int(state.get("meta_points", 0)) != points_after:
			errors.append("повтор изменил meta_points (%d -> %d)" % [points_after, int(state.get("meta_points", 0))])
		if Achievements.unlocked_count(state) != count_after:
			errors.append("повтор продублировал ачивку (было %d, стало %d)" % [count_after, Achievements.unlocked_count(state)])

	# 4. Ниже порога — не открывает; независимые метрики независимы.
	var fresh := Meta.default_state()
	var boss := Achievements.achievement_by_id("boss_breaker")  # boss_kills >= 3
	if not boss.is_empty():
		var below := Achievements.evaluate_run(fresh, {"boss_kills": int(boss["threshold"]) - 1})
		if not (below["newly_unlocked"] as Array).is_empty():
			errors.append("boss_breaker не должна открываться ниже порога")
		if Achievements.is_unlocked(fresh, "boss_breaker"):
			errors.append("boss_breaker открыта ниже порога — ошибка")
		# kills высокие, boss_kills низкие → откроется только first_blood/slayer, не boss_breaker.
		var mixed := Achievements.evaluate_run(fresh, {"kills": 100000, "boss_kills": 0})
		if Achievements.is_unlocked(fresh, "boss_breaker"):
			errors.append("boss_breaker не должна открываться при boss_kills=0")
		if not Achievements.is_unlocked(fresh, "first_blood"):
			errors.append("first_blood должна открыться при больших kills")

	# 5. Суммарная награда == sum reward открытых (открой ВСЁ заведомо большими метриками).
	var allstate := Meta.default_state()
	var big := {"kills": 1e9, "boss_kills": 1e9, "damage_dealt": 1e9,
		"gold_collected": 1e9, "route_stage_reached": 1e9, "final_level": 1e9, "time_seconds": 1e9}
	var all_res := Achievements.evaluate_run(allstate, big)
	if Achievements.unlocked_count(allstate) != Achievements.all_achievements().size():
		errors.append("большие метрики должны открыть ВСЕ ачивки (%d из %d)" % [
			Achievements.unlocked_count(allstate), Achievements.all_achievements().size()])
	if int(all_res["awarded"]) != Achievements.total_reward_points():
		errors.append("суммарная награда %d != сумме reward_meta_points %d" % [
			int(all_res["awarded"]), Achievements.total_reward_points()])
	# Достигнутый meta_points == суммарная награда (со свежего state).
	if int(allstate.get("meta_points", 0)) != Achievements.total_reward_points():
		errors.append("meta_points после открытия всех != сумме наград")

	# 6. save/load round-trip (на состоянии с частью открытых ачивок).
	Meta.save_state(state, TEST_PATH)
	var loaded := Meta.load_state(TEST_PATH)
	if not Achievements.is_unlocked(loaded, "first_blood"):
		errors.append("first_blood не пережила save/load")
	if int(loaded.get("meta_points", 0)) != int(state.get("meta_points", 0)):
		errors.append("meta_points не пережили save/load (%d != %d)" % [
			int(loaded.get("meta_points", 0)), int(state.get("meta_points", 0))])
	# После загрузки повтор с тем же порогом не начисляет.
	var loaded_points := int(loaded.get("meta_points", 0))
	var first_metric := str(Achievements.achievement_by_id("first_blood")["metric"])
	var first_threshold := int(Achievements.achievement_by_id("first_blood")["threshold"])
	Achievements.evaluate_run(loaded, {first_metric: first_threshold})
	if int(loaded.get("meta_points", 0)) != loaded_points:
		errors.append("после save/load повтор открытой ачивки начислил очки")

	# Анти-вакуум.
	if Achievements.all_achievements().size() < 3:
		errors.append("ачивок подозрительно мало")
	if Achievements.total_reward_points() <= 0:
		errors.append("суммарная награда ачивок должна быть > 0")

	_cleanup()

	if not errors.is_empty():
		for e in errors:
			push_error("Achievements: %s" % e)
		push_error("Achievements smoke test: %d нарушений." % errors.size())
		quit(1)
		return
	print("Achievements smoke test passed (разблокировка раз, награда, save/load, %d ачивок)." % Achievements.all_achievements().size())
	quit(0)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_PATH):
		dir.remove(TEST_PATH)
