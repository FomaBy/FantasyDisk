extends SceneTree

# SCRUM-873: награда за акт-босса = выбор 1 из 3 суперредких артефактов
# (tier >= 3, без дублей) + отхил ACT_TRANSITION_HEAL_PERCENT max HP при
# переходе в следующий акт (лечится run_player_snapshot; после финального
# акта отхила нет — advance_to_next_act возвращает false).

const ProgressionData := preload("res://scripts/progression_data.gd")

var _failed := false


func _fail(message: String) -> void:
	_failed = true
	push_error("[boss_act_reward_heal] " + message)


func _initialize() -> void:
	var ok := await _run()
	if ok and not _failed:
		print("[boss_act_reward_heal] PASSED")
		quit(0)
	else:
		quit(1)


func _run() -> bool:
	_test_choices_pool()

	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn не загрузилась")
		return false
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	_test_act_transition_heal(main)
	await _test_reward_screen_flow(main)

	main.queue_free()
	await process_frame
	return true


func _test_choices_pool() -> void:
	for character_id in ["", "berserk", "dark_mage", "guitarist", "doctor"]:
		for _attempt in range(6):
			var choices: Array = ProgressionData.boss_completion_artifact_choices(3, character_id)
			if choices.size() != 3:
				_fail("choices(%s) должен вернуть 3 варианта, got %d" % [character_id, choices.size()])
				return
			var ids := {}
			for reward in choices:
				var reward_dict: Dictionary = reward
				ids[str(reward_dict.get("id", ""))] = true
				if int(reward_dict.get("tier", 1)) < 3:
					_fail("choices(%s): не-суперредкий тир %d (%s)" % [character_id, int(reward_dict.get("tier", 1)), str(reward_dict.get("id"))])
				if str(reward_dict.get("kind", "")) != "artifact":
					_fail("choices(%s): kind != artifact (%s)" % [character_id, str(reward_dict.get("id"))])
			if ids.size() != 3:
				_fail("choices(%s): дубли в выборке %s" % [character_id, str(ids.keys())])


func _test_act_transition_heal(main: Node) -> void:
	var heal_percent := float(main.ACT_TRANSITION_HEAL_PERCENT)
	if heal_percent < 0.6 or heal_percent > 0.8:
		_fail("ACT_TRANSITION_HEAL_PERCENT %.2f вне запрошенного диапазона 60–80%%" % heal_percent)

	# Переход акт 1 -> 2: 20 + 70 = 90 HP.
	main.set("current_act", 1)
	main.set("run_player_snapshot", {"health": 20.0, "max_health": 100.0})
	if not bool(main.call("advance_to_next_act")):
		_fail("advance_to_next_act(act 1) должен вернуть true")
	var healed := float((main.get("run_player_snapshot") as Dictionary).get("health", -1.0))
	if not is_equal_approx(healed, 20.0 + 100.0 * heal_percent):
		_fail("отхил при переходе акта: ожидалось %.1f, got %.1f" % [20.0 + 100.0 * heal_percent, healed])

	# Кламп по максимуму: 60 + 70 -> 100.
	main.set("current_act", 1)
	main.set("run_player_snapshot", {"health": 60.0, "max_health": 100.0})
	main.call("advance_to_next_act")
	var clamped := float((main.get("run_player_snapshot") as Dictionary).get("health", -1.0))
	if not is_equal_approx(clamped, 100.0):
		_fail("отхил должен клампиться по max_health: ожидалось 100, got %.1f" % clamped)

	# Финальный акт: перехода нет, отхила нет.
	main.set("current_act", int(main.ACT_COUNT))
	main.set("run_player_snapshot", {"health": 20.0, "max_health": 100.0})
	if bool(main.call("advance_to_next_act")):
		_fail("advance_to_next_act(финальный акт) должен вернуть false")
	var untouched := float((main.get("run_player_snapshot") as Dictionary).get("health", -1.0))
	if not is_equal_approx(untouched, 20.0):
		_fail("после финального акта HP не должен меняться: ожидалось 20, got %.1f" % untouched)


func _test_reward_screen_flow(main: Node) -> bool:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "")
	main.set("run_player_snapshot", {})
	var done_called := [false]
	var ui = main.get("ui")
	ui._show_boss_artifact_reward(func() -> void:
		done_called[0] = true)
	await process_frame

	var screen := root.find_child("BossArtifactRewardScreen", true, false)
	if screen == null:
		_fail("BossArtifactRewardScreen не создан")
		return false
	var row := screen.find_child("BossArtifactRewardRow", true, false)
	if row == null or row.get_child_count() != 3:
		_fail("на экране должно быть 3 карточки, got %s" % (str(row.get_child_count()) if row != null else "нет ряда"))
		return false

	var first_card := row.get_child(0) as Button
	first_card.emit_signal("pressed")
	await process_frame

	if not done_called[0]:
		_fail("on_done не вызван после выбора карточки")
	var snapshot: Dictionary = main.get("run_player_snapshot")
	var artifacts: Array = snapshot.get("artifacts", [])
	if artifacts.size() != 1:
		_fail("после выбора в снапшоте должен быть ровно 1 артефакт, got %d" % artifacts.size())
	else:
		# Игрок хранит артефакт как {id, title} — сверяем id с пулом tier>=3.
		var picked_id := str((artifacts[0] as Dictionary).get("id", ""))
		var super_rare_ids := {}
		for reward in ProgressionData.boss_completion_artifact_rewards("berserk"):
			super_rare_ids[str((reward as Dictionary).get("id", ""))] = true
		if not super_rare_ids.has(picked_id):
			_fail("выбранный артефакт '%s' не из суперредкого пула (tier>=3)" % picked_id)
	if root.find_child("BossArtifactRewardScreen", true, false) != null:
		_fail("экран награды должен закрыться после выбора")
	return true
