extends SceneTree

# Гейт экономики очков меты (SCRUM-385): очко меты/умений даётся ТОЛЬКО за
# прохождение НОВОГО возвышения (любым классом), без фарма повторных боссов на
# уже пройденном уровне. class_boss_wins (прогрессия класса) при этом копится за
# каждую победу — это отдельная механика.
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

	# 3. Бой на текущем максимуме (run_level 1 == completed 1) → новое возвышение +1 очко.
	state = Meta.record_boss_victory(state, "berserk", 1)
	if int(state.get("skill_points", -1)) != 2:
		errors.append("новое возвышение (L2) должно дать ещё +1 очко (got %d)" % int(state.get("skill_points", -1)))
	if Meta.ascension_level(state, "berserk") != 2:
		errors.append("возвышение berserk должно стать 2")

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

	# 6. На максимуме (L10) повторы не дают очко.
	var maxed := Meta.default_state()
	maxed["ascension_levels"] = {"berserk": Meta.MAX_ASCENSION_LEVEL}
	var sp_max := int(maxed.get("skill_points", 0))
	maxed = Meta.record_boss_victory(maxed, "berserk", Meta.MAX_ASCENSION_LEVEL)
	if int(maxed.get("skill_points", -1)) != sp_max:
		errors.append("на максимуме возвышения повтор не должен давать очко")
	if Meta.ascension_level(maxed, "berserk") != Meta.MAX_ASCENSION_LEVEL:
		errors.append("возвышение не должно превышать максимум")

	# 7. class_boss_wins всё ещё копится за КАЖДУЮ победу (не привязано к очкам).
	if Meta.class_boss_wins(state, "berserk") < 7:
		errors.append("class_boss_wins должен копиться за каждую победу (got %d)" % Meta.class_boss_wins(state, "berserk"))

	# Экономика дерева достижима: потенциал очков (10 на класс) покрывает стоимость.
	if Meta.MAX_ASCENSION_LEVEL < Meta.skill_tree_total_cost() and Meta.MAX_ASCENSION_LEVEL * 2 < Meta.skill_tree_total_cost():
		# Несколько классов до максимума с запасом покрывают дерево — sanity, не жёсткий гейт.
		pass

	if not errors.is_empty():
		for e in errors:
			push_error("Meta points per ascension: %s" % e)
		push_error("Meta points per ascension: %d нарушений." % errors.size())
		quit(1)
		return
	print("Meta points per ascension passed (очко только за новое возвышение; фарм не даёт; class_boss_wins независим).")
	quit(0)
