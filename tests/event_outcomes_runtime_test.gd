extends SceneTree

# SCRUM-996: рантайм-гейт условных и скрытых исходов событий.
# Покрывает: check success/failure, hidden-карточки + reveal-шаг (outcome_text,
# скрытые карточки, EventContinueButton завершает событие), боевой исход
# (pending_event_combat + post_combat), магазин после события (shop_after,
# выход из магазина → advance), магазин после победы событийного боя
# (_combat_victory_map_continuation, выход БЕЗ повторного advance),
# damage_flat с полом 1 HP, применение money/stats/random_artifact,
# очистку current_event_definition, act-фильтр pick_event.
#
# Запуск: python3 tools/godot_gate.py --headless --path . --script res://tests/event_outcomes_runtime_test.gd

const EventData := preload("res://scripts/event_data.gd")

var _failures: Array[String] = []


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[event_outcomes_runtime] FAIL: " + message)


func _initialize() -> void:
	_test_pick_event_context()
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if main_scene == null or player_scene == null:
		_fail("Main.tscn/Player.tscn не загрузились.")
		quit(1)
		return
	await _test_outcome_resolution_and_application(main_scene, player_scene)
	await _test_hidden_reveal_flow(main_scene, player_scene)
	await _test_check_reveal_flow(main_scene, player_scene)
	await _test_shop_after_event_flow(main_scene, player_scene)
	await _test_combat_outcome_and_shop_after_victory(main_scene, player_scene)
	if _failures.is_empty():
		print("[event_outcomes_runtime] PASSED — pick_event context, check S/F, hidden+reveal, damage_flat floor, money/stats/artifact, shop_after (событие и победа), очистка current_event_definition.")
		quit(0)
	else:
		print("[event_outcomes_runtime] FAILED (%d ошибок)" % _failures.size())
		quit(1)


# --- Секция A: act-контекст pick_event (чистая логика, без сцен) ---
func _test_pick_event_context() -> void:
	if not EventData._event_allowed_in_context({"tags": {"acts": [2]}}, {"act": 2}):
		_fail("act-тег [2] должен пропускать событие при context.act=2.")
	if EventData._event_allowed_in_context({"tags": {"acts": [2]}}, {"act": 1}):
		_fail("act-тег [2] должен отсеивать событие при context.act=1.")
	if not EventData._event_allowed_in_context({"tags": {"acts": []}}, {"act": 1}):
		_fail("пустой acts-тег = событие допустимо в любом акте.")
	if not EventData._event_allowed_in_context({}, {"act": 3}):
		_fail("событие без tags допустимо в любом акте.")
	if not EventData._event_allowed_in_context({"tags": {"acts": [1]}}, {}):
		_fail("пустой context не должен фильтровать события.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 996
	# Текущий пул без тегов: выбор с context обязан работать как раньше.
	var picked := EventData.pick_event([], rng, {"act": 1})
	if not EventData.event_ids().has(str(picked.get("id", ""))):
		_fail("pick_event с context на нетегированном пуле вернул событие вне пула ('%s')." % picked.get("id", ""))
	# Совместимость: старый 2-аргументный вызов жив.
	var picked_legacy := EventData.pick_event([], rng)
	if not EventData.event_ids().has(str(picked_legacy.get("id", ""))):
		_fail("pick_event без context сломан ('%s')." % picked_legacy.get("id", ""))


# --- Хелперы полносценовых секций ---
func _spawn_main(main_scene: PackedScene) -> Node:
	var main := main_scene.instantiate()
	root.add_child(main)
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 0)
	main.set("route_nodes", [
		[
			{"type": "event", "name": "Event 1: Test", "row": 0, "branch": 0, "next_branches": [0]},
			{"type": "battle", "name": "Battle 1: Test", "row": 0, "branch": 1, "next_branches": [0]},
		],
		[
			{"type": "battle", "name": "Battle 2: Test", "row": 1, "branch": 0, "next_branches": [0]},
		],
		[
			{"type": "battle", "name": "Battle 3: Test", "row": 2, "branch": 0, "next_branches": [0]},
		],
		[
			{"type": "boss", "name": "Rift Warden", "boss_id": "rift_warden", "row": 3, "branch": 0},
		],
	])
	return main


func _store_rich_snapshot(main: Node, player_scene: PackedScene, money := 500) -> void:
	var player := player_scene.instantiate()
	root.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", money)
	var stats: Dictionary = player.get("stats")
	for stat_id in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
		stats[stat_id] = 12
	player.set("stats", stats)
	player.set("health", float(player.get("max_health")))
	main.combat._store_player_snapshot(player)
	player.queue_free()


func _press(button: Button) -> void:
	button.pressed.emit()


# --- Секция B: резолюция check и применение исходов (damage_flat/money/stats/artifact) ---
func _test_outcome_resolution_and_application(main_scene: PackedScene, player_scene: PackedScene) -> void:
	var main := _spawn_main(main_scene)
	await process_frame
	_store_rich_snapshot(main, player_scene)

	var check_choice := {
		"id": "t996_check", "title": "Проверка", "description": "тест",
		"check": {"stat": "strength", "difficulty": 7},
		"success": {"money": 18, "outcome_text": "Успех теста."},
		"failure": {"damage_flat": 5, "outcome_text": "Провал теста."},
	}
	# Успех: stat 12 >= 7.
	var high_player: Node = main.combat._snapshot_player_for_menu()
	var success_outcome: Dictionary = main.ui._resolve_event_choice_outcome(check_choice, high_player)
	high_player.queue_free()
	if not bool(success_outcome.get("check_passed", false)):
		_fail("check 12>=7 должен проходить.")
	if int(success_outcome.get("money", 0)) != 18 or str(success_outcome.get("outcome_text", "")) != "Успех теста.":
		_fail("success-ветка (money/outcome_text) не слилась в исход: %s" % str(success_outcome))
	# Провал: stat 0 < 7.
	var low_player: Node = main.combat._snapshot_player_for_menu()
	var low_stats: Dictionary = low_player.get("stats")
	low_stats["strength"] = 0
	low_player.set("stats", low_stats)
	var failure_outcome: Dictionary = main.ui._resolve_event_choice_outcome(check_choice, low_player)
	low_player.queue_free()
	if bool(failure_outcome.get("check_passed", true)):
		_fail("check 0<7 должен проваливаться.")
	if int(failure_outcome.get("damage_flat", 0)) != 5 or str(failure_outcome.get("outcome_text", "")) != "Провал теста.":
		_fail("failure-ветка (damage_flat/outcome_text) не слилась в исход: %s" % str(failure_outcome))

	# damage_flat: обычный урон и пол 1 HP.
	var dmg_player := player_scene.instantiate()
	root.add_child(dmg_player)
	dmg_player.configure_character("berserk", "sword")
	dmg_player.set("health", 100.0)
	if not bool(main.ui._apply_event_outcome_to_player({"damage_flat": 30}, dmg_player)):
		_fail("damage_flat-исход должен применяться (true).")
	if absf(float(dmg_player.get("health")) - 70.0) > 0.01:
		_fail("damage_flat 30 от 100 HP должен оставить 70, есть %s." % str(dmg_player.get("health")))
	dmg_player.set("health", 3.0)
	main.ui._apply_event_outcome_to_player({"damage_flat": 9999}, dmg_player)
	if absf(float(dmg_player.get("health")) - 1.0) > 0.01:
		_fail("damage_flat не летален: пол 1 HP, есть %s." % str(dmg_player.get("health")))
	dmg_player.queue_free()

	# money / stats / random_artifact.
	var reward_player := player_scene.instantiate()
	root.add_child(reward_player)
	reward_player.configure_character("berserk", "sword")
	reward_player.set("money", 10)
	var strength_before := float((reward_player.get("stats") as Dictionary).get("strength", 0.0))
	var artifacts_before := (reward_player.get("artifacts") as Array).size()
	var money_before := int(reward_player.get("money"))
	main.ui._apply_event_outcome_to_player({"money": 25, "stats": {"strength": 2}, "random_artifact": true}, reward_player)
	var money_gained := int(reward_player.get("money")) - money_before
	var artifacts_after := (reward_player.get("artifacts") as Array).size()
	if float((reward_player.get("stats") as Dictionary).get("strength", 0.0)) < strength_before + 2.0 - 0.01:
		_fail("stats.strength +2 не применился.")
	if artifacts_after > artifacts_before:
		if money_gained != 25:
			_fail("money-исход должен дать ровно +25 при выданном артефакте, есть +%d." % money_gained)
	elif money_gained <= 25:
		# Пустой пул артефактов компенсируется золотом (SCRUM-634) — money вырос бы сильнее.
		_fail("random_artifact не выдал ни артефакт, ни золотую компенсацию (money +%d, артефактов %d→%d)." % [money_gained, artifacts_before, artifacts_after])
	reward_player.queue_free()

	# Тексты hidden-карточки.
	if main.ui._event_choice_description_text({"hidden": true, "description": "секрет"}) != "Исход неизвестен…":
		_fail("hidden без unknown_hint должен показывать дефолт «Исход неизвестен…».")
	if main.ui._event_choice_description_text({"hidden": true, "unknown_hint": "Из щели тянет холодом."}) != "Из щели тянет холодом.":
		_fail("hidden с unknown_hint должен показывать hint.")
	if main.ui._event_choice_action_text({"hidden": true, "cost_money": 10}) != "Рискнуть":
		_fail("hidden action-текст должен быть «Рискнуть».")
	if main.ui._event_choice_action_text({"description": "обычный"}) != "Выбрать":
		_fail("обычный action-текст без цены должен остаться «Выбрать».")

	# Скидка событийного магазина: цены стока режутся с полом 1.
	main.set("current_shop_items", [{"cost": 100}, {"cost": 3}, {"cost": 1}])
	main.ui._apply_event_shop_discount(0.5)
	var discounted: Array = main.get("current_shop_items")
	if int(discounted[0].get("cost", -1)) != 50 or int(discounted[1].get("cost", -1)) != 2 or int(discounted[2].get("cost", -1)) != 1:
		_fail("shop_discount 0.5 должен дать цены [50, 2, 1], есть %s." % str(discounted))

	main.queue_free()
	await process_frame


# --- Секция C: hidden-выбор → reveal → «В путь» завершает событие ---
func _test_hidden_reveal_flow(main_scene: PackedScene, player_scene: PackedScene) -> void:
	var main := _spawn_main(main_scene)
	await process_frame
	_store_rich_snapshot(main, player_scene)
	var hidden_event := {
		"id": "t996_hidden",
		"title": "Тёмная ниша",
		"story": "В стене зияет ниша, из которой тянет холодом и звенит еле слышный шёпот монет.",
		"choices": [
			{"id": "reach_in", "title": "Сунуть руку", "hidden": true, "unknown_hint": "Из ниши тянет холодом.", "money": 30, "outcome_text": "Пальцы нащупали кошель с золотом."},
			{"id": "walk_past", "title": "Пройти мимо", "description": "Ничего не делать.", "money": 1},
		],
	}
	main.set("current_event_definition", hidden_event.duplicate(true))
	main.ui._show_event_screen({"name": "Тест скрытого исхода"})
	await process_frame
	var hidden_card := main.find_child("EventChoiceButton0", true, false) as Button
	if hidden_card == null:
		_fail("hidden: экран события не показал карточку выбора.")
		main.queue_free()
		await process_frame
		return
	var money_before := int((main.get("run_player_snapshot") as Dictionary).get("money", -1))
	_press(hidden_card)
	await process_frame
	var continue_button := main.find_child("EventContinueButton", true, false) as Button
	if continue_button == null:
		_fail("hidden: после выбора не появилась кнопка продолжения EventContinueButton.")
		main.queue_free()
		await process_frame
		return
	var story := main.find_child("EventStory", true, false) as Label
	if story == null or story.text != "Пальцы нащупали кошель с золотом.":
		_fail("hidden: reveal должен заменить story на outcome_text, есть '%s'." % (story.text if story != null else "<null>"))
	var choices_row := main.find_child("EventChoiceRow", true, false) as CanvasItem
	if choices_row == null or choices_row.visible:
		_fail("hidden: карточки выбора должны быть скрыты в reveal-состоянии.")
	var back_button := main.find_child("EventBackButton", true, false) as Button
	if back_button != null and back_button.visible:
		_fail("hidden: кнопка «Назад» должна быть скрыта в reveal-состоянии.")
	var focus_owner := main.get_viewport().gui_get_focus_owner()
	if focus_owner != continue_button:
		_fail("hidden: фокус в reveal-состоянии должен быть на EventContinueButton, есть %s." % (str(focus_owner.name) if focus_owner != null else "<null>"))
	if int(main.get("route_stage")) != 0:
		_fail("hidden: маршрут не должен двигаться до подтверждения reveal.")
	if (main.get("current_event_definition") as Dictionary).is_empty():
		_fail("hidden: current_event_definition должен жить до подтверждения (SCRUM-530: выход = повторный вход в то же событие).")
	var money_after := int((main.get("run_player_snapshot") as Dictionary).get("money", -1))
	if money_after != money_before + 30:
		_fail("hidden: исход money+30 должен примениться при выборе (до подтверждения), есть %d→%d." % [money_before, money_after])
	_press(continue_button)
	await process_frame
	if int(main.get("route_stage")) != 1:
		_fail("hidden: подтверждение reveal должно продвинуть маршрут (route_stage 1, есть %d)." % int(main.get("route_stage")))
	if not (main.get("current_event_definition") as Dictionary).is_empty():
		_fail("hidden: current_event_definition должен очиститься после подтверждения.")
	if main.find_child("RouteMapScreen", true, false) == null:
		_fail("hidden: после подтверждения reveal должен открыться экран карты.")
	main.queue_free()
	await process_frame


# --- Секция D: check-выбор → reveal со строкой проверки ---
func _test_check_reveal_flow(main_scene: PackedScene, player_scene: PackedScene) -> void:
	var main := _spawn_main(main_scene)
	await process_frame
	_store_rich_snapshot(main, player_scene)
	var check_event := {
		"id": "t996_check_ui",
		"title": "Испытание силы",
		"story": "Каменная плита ждёт того, кто рискнёт сдвинуть её с места голыми руками.",
		"choices": [
			{"id": "push_slab", "title": "Сдвинуть плиту", "description": "Проверка Силы 7.", "check": {"stat": "strength", "difficulty": 7}, "success": {"money": 12, "outcome_text": "Плита поддалась."}, "failure": {"damage_flat": 4, "outcome_text": "Плита не шелохнулась."}},
			{"id": "leave_slab", "title": "Отойти", "description": "Ничего не делать.", "money": 1},
		],
	}
	main.set("current_event_definition", check_event.duplicate(true))
	main.ui._show_event_screen({"name": "Тест проверки"})
	await process_frame
	var check_card := main.find_child("EventChoiceButton0", true, false) as Button
	if check_card == null:
		_fail("check: экран события не показал карточку выбора.")
		main.queue_free()
		await process_frame
		return
	_press(check_card)
	await process_frame
	var continue_button := main.find_child("EventContinueButton", true, false) as Button
	if continue_button == null:
		_fail("check: любой check-выбор обязан показывать reveal-шаг.")
		main.queue_free()
		await process_frame
		return
	var story := main.find_child("EventStory", true, false) as Label
	if story == null or not story.text.contains("Плита поддалась."):
		_fail("check: reveal должен показать outcome_text success-ветки, есть '%s'." % (story.text if story != null else "<null>"))
	if story != null and not (story.text.contains("Проверка") and story.text.contains("7") and story.text.contains("пройдена")):
		_fail("check: reveal должен содержать строку «Проверка <Стат> 7 — пройдена», есть '%s'." % story.text)
	_press(continue_button)
	await process_frame
	if int(main.get("route_stage")) != 1 or main.find_child("RouteMapScreen", true, false) == null:
		_fail("check: подтверждение reveal должно вернуть на карту с advance.")
	main.queue_free()
	await process_frame


# --- Секция E: shop_after после события — магазин, выход → advance ---
func _test_shop_after_event_flow(main_scene: PackedScene, player_scene: PackedScene) -> void:
	var main := _spawn_main(main_scene)
	await process_frame
	_store_rich_snapshot(main, player_scene)
	var shop_event := {
		"id": "t996_shop",
		"title": "Караван-спасатель",
		"story": "Спасённый караванщик раскладывает товар прямо на тракте и зовёт выбрать награду.",
		"choices": [
			{"id": "trade", "title": "Поторговать", "description": "Караванщик открывает лавку.", "outcome_text": "Караванщик раскладывает товар.", "shop_after": true, "shop_discount": 0.25},
			{"id": "decline", "title": "Отказаться", "description": "Уйти.", "money": 1},
		],
	}
	main.set("current_event_definition", shop_event.duplicate(true))
	main.ui._show_event_screen({"name": "Тест магазина"})
	await process_frame
	var trade_card := main.find_child("EventChoiceButton0", true, false) as Button
	if trade_card == null:
		_fail("shop_after: экран события не показал карточку выбора.")
		main.queue_free()
		await process_frame
		return
	_press(trade_card)
	await process_frame
	var continue_button := main.find_child("EventContinueButton", true, false) as Button
	if continue_button == null:
		_fail("shop_after: outcome_text должен дать reveal-шаг перед магазином.")
		main.queue_free()
		await process_frame
		return
	_press(continue_button)
	await process_frame
	if main.find_child("ShopScreen", true, false) == null:
		_fail("shop_after: подтверждение reveal должно открыть магазин.")
		main.queue_free()
		await process_frame
		return
	if int(main.get("route_stage")) != 0:
		_fail("shop_after: маршрут не должен двигаться до выхода из магазина.")
	if not (main.get("current_event_definition") as Dictionary).is_empty():
		_fail("shop_after: current_event_definition должен очиститься при уходе в магазин.")
	if not (main.get("event_shop_exit_action") as Callable).is_valid():
		_fail("shop_after: событийный магазин должен нести отложенный exit_action.")
	if (main.get("current_shop_items") as Array).is_empty():
		_fail("shop_after: событийный магазин должен получить сток товаров.")
	var leave_button := main.find_child("ShopLeaveButton", true, false) as Button
	if leave_button == null:
		_fail("shop_after: у событийного магазина нет кнопки выхода.")
		main.queue_free()
		await process_frame
		return
	_press(leave_button)
	await process_frame
	if int(main.get("route_stage")) != 1:
		_fail("shop_after: выход из событийного магазина должен продвинуть маршрут (route_stage 1, есть %d)." % int(main.get("route_stage")))
	if main.find_child("RouteMapScreen", true, false) == null:
		_fail("shop_after: выход из событийного магазина должен вернуть на карту.")
	if (main.get("event_shop_exit_action") as Callable).is_valid():
		_fail("shop_after: exit_action должен потребляться одним выходом.")
	main.queue_free()
	await process_frame


# --- Секция F: боевой исход + магазин после победы событийного боя ---
func _test_combat_outcome_and_shop_after_victory(main_scene: PackedScene, player_scene: PackedScene) -> void:
	# F1: боевой исход выставляет pending_event_combat с post_combat (включая shop_after).
	var main := _spawn_main(main_scene)
	await process_frame
	_store_rich_snapshot(main, player_scene)
	var combat_choice := {
		"id": "t996_fight", "title": "Принять бой", "description": "тест",
		"combat": {"type": "battle", "enemy_health_multiplier": 1.05, "money_multiplier": 1.2},
		"post_combat": {"stats": {"strength": 1}, "shop_after": true},
	}
	var resolution: Dictionary = main.ui._apply_event_choice_resolved(combat_choice)
	await process_frame
	if not bool(resolution.get("starts_combat", false)) or not bool(main.get("combat_active")):
		_fail("боевой исход должен стартовать бой (starts_combat + combat_active).")
	var pending: Dictionary = main.get("pending_event_combat")
	if absf(float(pending.get("enemy_health_multiplier", 0.0)) - 1.05) > 0.001:
		_fail("pending_event_combat должен нести множители боя, есть %s." % str(pending))
	var pending_post: Dictionary = pending.get("post_combat", {})
	if not bool(pending_post.get("shop_after", false)) or int((pending_post.get("stats", {}) as Dictionary).get("strength", 0)) != 1:
		_fail("pending_event_combat.post_combat должен нести награды и shop_after, есть %s." % str(pending_post))
	if not (main.get("current_event_definition") as Dictionary).is_empty():
		_fail("старт событийного боя должен очищать current_event_definition (как раньше).")
	main.combat._end_combat(true)
	await process_frame
	if bool(main.get("combat_active")) or not (main.get("pending_event_combat") as Dictionary).is_empty():
		_fail("победа должна закрывать бой и чистить pending_event_combat.")
	main.queue_free()
	await process_frame

	# F2: продолжение победного флоу с post_combat.shop_after — магазин, выход БЕЗ повторного advance.
	var shop_main := _spawn_main(main_scene)
	await process_frame
	_store_rich_snapshot(shop_main, player_scene)
	shop_main.set("route_stage", 1)  # как после инкремента в _end_combat
	var continuation: Callable = shop_main.combat._combat_victory_map_continuation({"post_combat": {"shop_after": true, "shop_discount": 0.25}})
	continuation.call()
	await process_frame
	if shop_main.find_child("ShopScreen", true, false) == null:
		_fail("post_combat.shop_after: продолжение победы должно открыть магазин.")
		shop_main.queue_free()
		await process_frame
		return
	var leave_button := shop_main.find_child("ShopLeaveButton", true, false) as Button
	if leave_button == null:
		_fail("post_combat.shop_after: у пост-боевого магазина нет кнопки выхода.")
		shop_main.queue_free()
		await process_frame
		return
	_press(leave_button)
	await process_frame
	if int(shop_main.get("route_stage")) != 1:
		_fail("post_combat.shop_after: выход из магазина НЕ должен повторно двигать маршрут (advance уже сделан боем), есть stage %d." % int(shop_main.get("route_stage")))
	if shop_main.find_child("RouteMapScreen", true, false) == null:
		_fail("post_combat.shop_after: выход из магазина должен вернуть на карту.")
	if (shop_main.get("event_shop_exit_action") as Callable).is_valid():
		_fail("post_combat.shop_after: exit_action должен потребляться одним выходом.")
	shop_main.queue_free()
	await process_frame

	# F3: без shop_after продолжение победы ведёт сразу на карту.
	var plain_main := _spawn_main(main_scene)
	await process_frame
	_store_rich_snapshot(plain_main, player_scene)
	plain_main.set("route_stage", 1)
	var plain_continuation: Callable = plain_main.combat._combat_victory_map_continuation({})
	plain_continuation.call()
	await process_frame
	if plain_main.find_child("RouteMapScreen", true, false) == null or plain_main.find_child("ShopScreen", true, false) != null:
		_fail("продолжение победы без shop_after должно вести сразу на карту.")
	if int(plain_main.get("route_stage")) != 1:
		_fail("продолжение победы без shop_after не должно менять route_stage.")
	plain_main.queue_free()
	await process_frame
