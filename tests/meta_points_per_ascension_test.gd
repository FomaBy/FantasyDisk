extends SceneTree

# Гейт экономики Меты 4.0 (SCRUM-828, дизайн §4/§6.6): ЭМБЛЕМЫ КЛАССА даются
# ТОЛЬКО за первый clear возвышения 0..5 каждым классом по формуле 2/2/3/4/5/6
# (+2 за каждый выполненный челлендж класса), ЗВЁЗДНАЯ ПЫЛЬ — за аккаунт-вехи
# (первая победа классом ×17, первый A5 ×17, секретный босс 3, кодекс 8,
# достижения 5; потолок 50). Анти-фарм повторных побед сохранён 1:1 с v3.
# class_boss_wins копится за каждую победу — отдельная механика.
#
# Запуск: Godot --headless --path . --script res://tests/meta_points_per_ascension_test.gd

const Meta := preload("res://scripts/meta_progression.gd")


func _initialize() -> void:
	var errors: Array = []
	var state := Meta.default_state()

	# 0. Свежий аккаунт: валюты по нулям, фасады тоже.
	if Meta.class_sigils_earned(state, "berserk") != 0 or Meta.stardust_earned(state) != 0:
		errors.append("свежий state должен иметь 0 эмблем и 0 пыли")
	if int(state.get("meta_points", -1)) != 0 or int(state.get("skill_points", -1)) != 0:
		errors.append("фасады meta/skill_points свежего state должны быть 0")

	# 1. Первый clear A0 → +2 эмблемы берсерка и +1 пыль (первая победа классом).
	state = Meta.record_boss_victory(state, "berserk", 0)
	if Meta.class_sigils_earned(state, "berserk") != 2:
		errors.append("первый clear A0 должен дать 2 эмблемы (got %d)" % Meta.class_sigils_earned(state, "berserk"))
	if Meta.stardust_earned(state) != 1:
		errors.append("первая победа классом должна дать 1 пыль (got %d)" % Meta.stardust_earned(state))
	if Meta.ascension_level(state, "berserk") != 1:
		errors.append("возвышение berserk должно стать 1")

	# 2. Повтор на УЖЕ пройденном уровне → валюты не растут.
	state = Meta.record_boss_victory(state, "berserk", 0)
	if Meta.class_sigils_earned(state, "berserk") != 2 or Meta.stardust_earned(state) != 1:
		errors.append("повтор на пройденном уровне НЕ должен давать валюту")
	if Meta.ascension_level(state, "berserk") != 1:
		errors.append("повтор не должен поднимать возвышение")

	# 3. Лестница эмблем 2/2/3/4/5/6: накопительно 2/4/7/11/16/22.
	var expected := {1: 4, 2: 7, 3: 11, 4: 16, 5: 22}
	for level in [1, 2, 3, 4, 5]:
		state = Meta.record_boss_victory(state, "berserk", level)
		if Meta.class_sigils_earned(state, "berserk") != int(expected[level]):
			errors.append("после первого clear A%d должно быть %d эмблем (got %d)" % [level, int(expected[level]), Meta.class_sigils_earned(state, "berserk")])
	var before_max_repeat := Meta.class_sigils_earned(state, "berserk")
	state = Meta.record_boss_victory(state, "berserk", 5)
	if Meta.class_sigils_earned(state, "berserk") != before_max_repeat:
		errors.append("повтор A5 не должен фармить эмблемы")

	# 3b. Первый clear A5 добавил аккаунт-веху: пыль = 1 (первая победа) + 1 (A5).
	if Meta.stardust_earned(state) != 2:
		errors.append("первый A5-клир классом должен дать ещё 1 пыль (got %d)" % Meta.stardust_earned(state))

	# 4. Фарм на низком уровне (5 повторов) → эмблемы/пыль не растут.
	var farm_sigils := Meta.class_sigils_earned(state, "berserk")
	var farm_dust := Meta.stardust_earned(state)
	for i in range(5):
		state = Meta.record_boss_victory(state, "berserk", 0)
	if Meta.class_sigils_earned(state, "berserk") != farm_sigils or Meta.stardust_earned(state) != farm_dust:
		errors.append("фарм повторных боссов не должен давать валюту")

	# 5. Эмблемы per-class: победа солдатом даёт ЕГО эмблемы, не берсерка.
	state = Meta.record_boss_victory(state, "soldier", 0)
	if Meta.class_sigils_earned(state, "soldier") != 2:
		errors.append("первый clear A0 солдатом должен дать 2 эмблемы солдата")
	if Meta.class_sigils_earned(state, "berserk") != farm_sigils:
		errors.append("эмблемы берсерка не должны меняться от победы солдата")
	if Meta.stardust_earned(state) != farm_dust + 1:
		errors.append("первая победа вторым классом должна дать +1 пыль")

	# 6. Челленджи класса → +2 эмблемы каждый (метрика weapon_diversity 3 оружия).
	var ch_state := Meta.default_state()
	ch_state = Meta.record_boss_victory(ch_state, "thief", 0, {"weapon_id": "dagger", "used_shop": true})
	var base_sigils := Meta.class_sigils_earned(ch_state, "thief")  # 2 (A0)
	ch_state = Meta.record_boss_victory(ch_state, "thief", 0, {"weapon_id": "bow", "used_shop": true})
	ch_state = Meta.record_boss_victory(ch_state, "thief", 0, {"weapon_id": "coin", "used_shop": true})
	if not Meta.class_challenges_done(ch_state, "thief").has("weapon_master"):
		errors.append("3 разных оружия должны выполнить челлендж weapon_master")
	if Meta.class_sigils_earned(ch_state, "thief") != base_sigils + Meta.SIGILS_PER_CLASS_CHALLENGE:
		errors.append("выполненный челлендж должен дать +2 эмблемы (got %d, base %d)" % [Meta.class_sigils_earned(ch_state, "thief"), base_sigils])

	# 7. Секретный босс: +3 пыли, разово.
	var secret_state := Meta.default_state()
	var dust_before := Meta.stardust_earned(secret_state)
	secret_state = Meta.record_secret_boss_victory(secret_state)
	if Meta.stardust_earned(secret_state) != dust_before + Meta.STARDUST_SECRET_BOSS:
		errors.append("секретный босс должен дать ровно %d пыли" % Meta.STARDUST_SECRET_BOSS)
	secret_state = Meta.record_secret_boss_victory(secret_state)
	if Meta.stardust_earned(secret_state) != dust_before + Meta.STARDUST_SECRET_BOSS:
		errors.append("повтор секретного босса не должен давать пыль")

	# 8. Вехи достижений: пороги 1/2/4/6/8 → 0..5 пыли.
	var ach_state := Meta.default_state()
	ach_state["achievements"] = ["first_blood"]
	if Meta.achievement_milestones_reached(ach_state) != 1:
		errors.append("1 ачивка = 1 веха достижений")
	ach_state["achievements"] = ["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8"]
	if Meta.achievement_milestones_reached(ach_state) != Meta.STARDUST_ACHIEVEMENT_MILESTONES:
		errors.append("8 ачивок должны закрыть все 5 вех достижений")

	# 9. Вехи кодекса: полный кодекс = 8 вех; частичный — меньше.
	var codex_state := Meta.default_state()
	if Meta.codex_milestones_reached(codex_state) != 0:
		errors.append("пустой кодекс = 0 вех")
	for category in ["monsters", "bosses", "artifacts"]:
		var ids := Meta._canonical_codex_ids(category).keys()
		codex_state = Meta.record_codex_discoveries(codex_state, category, ids)
	if Meta.codex_milestones_reached(codex_state) != Meta.STARDUST_CODEX_MILESTONES:
		errors.append("полный кодекс должен закрыть все %d вех (got %d)" % [Meta.STARDUST_CODEX_MILESTONES, Meta.codex_milestones_reached(codex_state)])

	# 10. Потолок пыли ровно 50 при полном прогрессе аккаунта.
	var full := Meta.default_state()
	for class_id in Meta.CLASS_ENTRY_NODES.keys():
		for level in range(0, Meta.MAX_ASCENSION_LEVEL + 1):
			full = Meta.record_boss_victory(full, str(class_id), level)
	full = Meta.record_secret_boss_victory(full)
	for category in ["monsters", "bosses", "artifacts"]:
		full = Meta.record_codex_discoveries(full, category, Meta._canonical_codex_ids(category).keys())
	full["achievements"] = ["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8"]
	if Meta.stardust_earned(full) != Meta.STARDUST_CAP:
		errors.append("полный аккаунт должен дать ровно %d пыли (got %d)" % [Meta.STARDUST_CAP, Meta.stardust_earned(full)])
	# Эмблемы без капа общего пула: 17 классов × 22 (без челленджей).
	var sigil_total := 0
	for class_id in Meta.CLASS_ENTRY_NODES.keys():
		sigil_total += Meta.class_sigils_earned(full, str(class_id))
	if sigil_total < 17 * 22:
		errors.append("полные клиры всех классов должны дать ≥374 эмблем без v3-капа (got %d)" % sigil_total)

	# 11. class_boss_wins копится за КАЖДУЮ победу (не привязан к валютам).
	if Meta.class_boss_wins(state, "berserk") < 7:
		errors.append("class_boss_wins должен копиться за каждую победу (got %d)" % Meta.class_boss_wins(state, "berserk"))

	# 12. Legacy-like state на максимуме: первый clear A5 даёт свои +6 эмблем, повтор — нет.
	var maxed := Meta.default_state()
	maxed["ascension_levels"] = {"berserk": Meta.MAX_ASCENSION_LEVEL}
	maxed = Meta.record_boss_victory(maxed, "berserk", Meta.MAX_ASCENSION_LEVEL)
	if Meta.class_sigils_earned(maxed, "berserk") != 22:
		errors.append("legacy-макс класс после первого clear A5 должен иметь 22 эмблемы (got %d)" % Meta.class_sigils_earned(maxed, "berserk"))
	maxed = Meta.record_boss_victory(maxed, "berserk", Meta.MAX_ASCENSION_LEVEL)
	if Meta.class_sigils_earned(maxed, "berserk") != 22:
		errors.append("повтор A5 не должен фармить эмблемы legacy-класса")
	if Meta.ascension_level(maxed, "berserk") != Meta.MAX_ASCENSION_LEVEL:
		errors.append("возвышение не должно превышать максимум")

	# 13. Фасады v3 живы: заработано/доступно = сумма валют (для старого экрана).
	var facade := Meta.default_state()
	facade = Meta.record_boss_victory(facade, "berserk", 0)
	var expected_facade := Meta.class_sigils_earned(facade, "berserk") + Meta.stardust_earned(facade)
	if Meta.earned_meta_points(facade) != expected_facade or int(facade.get("meta_points", -1)) != expected_facade:
		errors.append("фасад meta_points должен равняться сумме валют (%d)" % expected_facade)

	if not errors.is_empty():
		for e in errors:
			push_error("Sigils per ascension: %s" % e)
		push_error("Sigils per ascension: %d нарушений." % errors.size())
		quit(1)
		return
	print("Sigils per ascension passed (SCRUM-828: формула 2/2/3/4/5/6, челленджи +2, пыль 50, анти-фарм, class_boss_wins independent).")
	quit(0)
