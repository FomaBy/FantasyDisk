extends SceneTree

# Гейт экономики очков меты (SCRUM-696): метаочки даются ТОЛЬКО за первый clear
# уровня возвышения 0..5 каждым классом по формуле 1/1/2/3/4/5, без фарма
# повторных боссов. class_boss_wins при этом копится за каждую победу — это
# отдельная механика.
#
# Отдельный изолированный файл (читает meta_progression).
# Запуск: Godot --headless --path . --script res://tests/meta_points_per_ascension_test.gd

const Meta := preload("res://scripts/meta_progression.gd")


func _initialize() -> void:
	var errors: Array = []
	var state := Meta.default_state()

	# 1. Новое возвышение (бой на текущем максимуме 0) → +1 очко.
	state = Meta.record_boss_victory(state, "berserk", 0)
	if int(state.get("skill_points", -1)) != 1 or int(state.get("meta_points", -1)) != 1:
		errors.append("новое возвышение должно дать +1 skill/meta (got %d/%d)" % [int(state.get("skill_points", -1)), int(state.get("meta_points", -1))])
	if Meta.ascension_level(state, "berserk") != 1:
		errors.append("возвышение berserk должно стать 1")

	# 2. Повтор на УЖЕ пройденном уровне (run_level 0 < completed 1) → НЕ даёт очко.
	state = Meta.record_boss_victory(state, "berserk", 0)
	if int(state.get("skill_points", -1)) != 1:
		errors.append("повтор на пройденном уровне НЕ должен давать очко (got %d)" % int(state.get("skill_points", -1)))
	if Meta.ascension_level(state, "berserk") != 1:
		errors.append("повтор не должен поднимать возвышение")

	# 3. Бой на текущем максимуме (run_level 1 == completed 1) → ещё +1 очко.
	state = Meta.record_boss_victory(state, "berserk", 1)
	if int(state.get("skill_points", -1)) != 2:
		errors.append("новое возвышение (L2) должно дать ещё +1 очко (got %d)" % int(state.get("skill_points", -1)))
	if Meta.ascension_level(state, "berserk") != 2:
		errors.append("возвышение berserk должно стать 2")

	# 3b. Дальнейшая формула: ascension 2/3/4/5 дают +2/+3/+4/+5.
	var expected := {2: 4, 3: 7, 4: 11, 5: 16}
	for level in [2, 3, 4, 5]:
		state = Meta.record_boss_victory(state, "berserk", level)
		if int(state.get("skill_points", -1)) != int(expected[level]):
			errors.append("после первого clear ascension %d должно быть %d метаочков (got %d)" % [level, int(expected[level]), int(state.get("skill_points", -1))])
	var before_max_repeat := int(state.get("skill_points", 0))
	state = Meta.record_boss_victory(state, "berserk", 5)
	if int(state.get("skill_points", -1)) != before_max_repeat:
		errors.append("повтор ascension 5 не должен фармить метаочки")

	# 4. Фарм на низком уровне (5 повторов) → очки не растут.
	var before_farm := int(state.get("skill_points", 0))
	for i in range(5):
		state = Meta.record_boss_victory(state, "berserk", 0)
	if int(state.get("skill_points", -1)) != before_farm:
		errors.append("фарм повторных боссов не должен давать очки (было %d, стало %d)" % [before_farm, int(state.get("skill_points", -1))])

	# 5. Другой класс (любой) даёт своё очко за своё новое возвышение.
	var sp_before := int(state.get("skill_points", 0))
	state = Meta.record_boss_victory(state, "soldier", 0)
	if int(state.get("skill_points", -1)) != sp_before + 1:
		errors.append("новое возвышение другим классом (soldier) должно дать +1 очко")

	# 6. Legacy-like state at selectable max: first clear ascension 5 gives the +5
	# endcap reward once, then repeats do not farm it.
	var maxed := Meta.default_state()
	maxed["ascension_levels"] = {"berserk": Meta.MAX_ASCENSION_LEVEL}
	maxed = Meta.record_boss_victory(maxed, "berserk", Meta.MAX_ASCENSION_LEVEL)
	if int(maxed.get("skill_points", -1)) != 16:
		errors.append("первый clear максимального возвышения должен довести класс до 16 метаочков")
	maxed = Meta.record_boss_victory(maxed, "berserk", Meta.MAX_ASCENSION_LEVEL)
	if int(maxed.get("skill_points", -1)) != 16:
		errors.append("повтор максимального возвышения не должен давать очки")
	if Meta.ascension_level(maxed, "berserk") != Meta.MAX_ASCENSION_LEVEL:
		errors.append("возвышение не должно превышать максимум")

	# 7. class_boss_wins всё ещё копится за КАЖДУЮ победу (не привязано к очкам).
	if Meta.class_boss_wins(state, "berserk") < 7:
		errors.append("class_boss_wins должен копиться за каждую победу (got %d)" % Meta.class_boss_wins(state, "berserk"))

	# 8. Общий cap заработанных метаочков = 100.
	var cap_state := Meta.default_state()
	for class_id in Meta.CLASS_ENTRY_NODES.keys():
		for level in range(0, Meta.MAX_ASCENSION_LEVEL + 1):
			cap_state = Meta.record_boss_victory(cap_state, str(class_id), level)
	if Meta.earned_meta_points(cap_state) != Meta.META_POINTS_CAP:
		errors.append("общий cap метаочков должен быть %d (got %d)" % [Meta.META_POINTS_CAP, Meta.earned_meta_points(cap_state)])

	if not errors.is_empty():
		for e in errors:
			push_error("Meta points per ascension: %s" % e)
		push_error("Meta points per ascension: %d нарушений." % errors.size())
		quit(1)
		return
	print("Meta points per ascension passed (SCRUM-696 formula, cap, no farming, class_boss_wins independent).")
	quit(0)
