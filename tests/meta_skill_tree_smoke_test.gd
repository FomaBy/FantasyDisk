extends SceneTree

# SCRUM-150 ч.1 (file-изолированный): data-целостность древа умений, покупка с
# последовательной разблокировкой, сохранение/загрузка, балансовый потолок силы.
# Отдельный файл — runtime_smoke_test.gd занят параллельным воркером (анти-коллизия).

const Meta := preload("res://scripts/meta_progression.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _initialize() -> void:
	_test_tree_data_integrity()
	_test_branch_sequential_unlock()
	_test_purchase_and_points()
	_test_save_load_roundtrip()
	_test_full_tree_power_cap()
	await _test_player_application()
	await _test_skill_tree_screen()
	await _test_victory_shows_skill_points()
	await _test_shop_discount()
	await _test_attribute_discount()
	await _test_attribute_extra_options()
	await _test_first_levelup_rare_capstone()
	await _test_guaranteed_rare_shop_capstone()
	print("Meta skill tree smoke test passed.")
	quit(0)


func _test_guaranteed_rare_shop_capstone() -> void:
	# Capstone «Связи в гильдии»: магазин гарантированно содержит редкий (tier 3) товар.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_ascension_level", 0)
	main.set("route_stage", 3)
	if main.has_method("reset_run_ascension"):
		main.call("reset_run_ascension")
	var state: Dictionary = main.get("meta_state")
	state["skill_nodes"] = ["wealth_capstone"]
	main.set("meta_state", state)

	# Несколько прогонов: с capstone в каждом наборе должен быть tier-3.
	for _try in range(8):
		(main.get("rng") as RandomNumberGenerator).seed = 100 + _try
		var items: Array = main.ui._random_shop_items(4)
		var has_rare := false
		for item in items:
			if int((item as Dictionary).get("tier", 1)) >= 3:
				has_rare = true
				break
		if not has_rare:
			_fail("Expected guaranteed-rare-shop capstone to include a tier-3 item.")
			return
	main.queue_free()
	await process_frame


func _test_first_levelup_rare_capstone() -> void:
	# Capstone «Озарение»: первое повышение забега (level<=2) при купленном узле
	# гарантирует основную характеристику среди наград.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	var player := PLAYER_SCENE.instantiate()
	main.add_child(player)
	player.add_to_group("player")
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	player.set("level", 2)
	main.set("current_player", player)

	var state: Dictionary = main.get("meta_state")
	state["skill_nodes"] = ["lore_capstone"]
	main.set("meta_state", state)

	# С узлом + level<=2: гарантированно есть основная характеристика (rare).
	var has_stat := false
	for reward in main.ui._random_level_up_rewards(3):
		if bool((reward as Dictionary).get("rare", false)):
			has_stat = true
			break
	if not has_stat:
		_fail("Expected first-levelup-rare capstone to force a main characteristic.")
		return

	# Уже не первое повышение (level 5): capstone не форсит — гарантии нет.
	player.set("level", 5)
	var forced_count := 0
	for _try in range(20):
		var only_regular := true
		for reward in main.ui._random_level_up_rewards(3):
			if bool((reward as Dictionary).get("rare", false)):
				only_regular = false
				break
		if not only_regular:
			forced_count += 1
	# При 5% на слот форс-стат изредка выпадает, но НЕ в каждом наборе (capstone бы давал 20/20).
	if forced_count >= 20:
		_fail("Expected capstone not to force a stat past the first level-up.")
		return

	main.queue_free()
	await process_frame


func _test_attribute_extra_options() -> void:
	# Ветвь Знаний: по умолчанию 2 варианта докачки; узлы кругозора добавляют.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var base_state: Dictionary = main.get("meta_state")
	base_state["skill_nodes"] = []
	main.set("meta_state", base_state)
	if main.ui._random_attribute_pair().size() != 2:
		_fail("Expected default attribute offer to be 2 options.")
		return
	var more_state: Dictionary = main.get("meta_state")
	more_state["skill_nodes"] = ["lore_attr_1", "lore_attr_2"]
	main.set("meta_state", more_state)
	if main.ui._random_attribute_pair().size() != 4:
		_fail("Expected lore extra-option nodes to raise attribute offer to 4.")
		return
	main.queue_free()
	await process_frame


func _test_attribute_discount() -> void:
	# Ветвь Богатства: узлы удешевления снижают цену докачки атрибутов.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_ascension_level", 0)
	main.set("route_stage", 3)
	if main.has_method("reset_run_ascension"):
		main.call("reset_run_ascension")

	var base_state: Dictionary = main.get("meta_state")
	base_state["skill_nodes"] = []
	main.set("meta_state", base_state)
	var full_cost: int = main.ui._attribute_buy_cost()

	var disc_state: Dictionary = main.get("meta_state")
	disc_state["skill_nodes"] = ["wealth_attr_1", "wealth_attr_2"]
	main.set("meta_state", disc_state)
	var disc_cost: int = main.ui._attribute_buy_cost()

	if disc_cost >= full_cost or disc_cost <= 0:
		_fail("Expected attribute discount nodes to lower buy cost (%d vs %d)." % [disc_cost, full_cost])
		return
	main.queue_free()
	await process_frame


func _test_shop_discount() -> void:
	# Ветвь Богатства: купленные узлы скидки магазина снижают цены товаров.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_ascension_level", 0)
	main.set("route_stage", 2)
	if main.has_method("reset_run_ascension"):
		main.call("reset_run_ascension")

	var base_state: Dictionary = main.get("meta_state")
	base_state["skill_nodes"] = []
	main.set("meta_state", base_state)
	(main.get("rng") as RandomNumberGenerator).seed = 4242
	var full_items: Array = main.ui._random_shop_items(4)
	var full_total := 0
	for item in full_items:
		full_total += int((item as Dictionary).get("cost", 0))

	var disc_state: Dictionary = main.get("meta_state")
	disc_state["skill_nodes"] = ["wealth_shop_1", "wealth_shop_2"]
	main.set("meta_state", disc_state)
	(main.get("rng") as RandomNumberGenerator).seed = 4242
	var disc_items: Array = main.ui._random_shop_items(4)
	var disc_total := 0
	for item in disc_items:
		disc_total += int((item as Dictionary).get("cost", 0))

	if disc_total >= full_total or disc_total <= 0:
		_fail("Expected shop discount nodes to lower prices (%d vs %d)." % [disc_total, full_total])
		return
	main.queue_free()
	await process_frame


func _test_victory_shows_skill_points() -> void:
	# Инкремент 4: экран победы сообщает игроку про начисленное очко умений.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var state: Dictionary = main.get("meta_state")
	state["skill_points"] = 3
	main.set("meta_state", state)
	main.ui._show_victory_screen()
	await process_frame
	var found := false
	for label in main.find_children("*", "Label", true, false):
		if str((label as Label).text).contains("очко умений"):
			found = true
			break
	if not found:
		_fail("Expected victory screen to mention earned skill point.")
		return
	main.queue_free()
	await process_frame


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _test_tree_data_integrity() -> void:
	var total := Meta.skill_tree_total_cost()
	if total < 40 or total > 50:
		_fail("Expected skill tree budget 40-50, got %d." % total)
		return
	# 4 ветви, последовательные tier 1..N без дыр, уникальные id, описания не пусты.
	var ids := {}
	for branch in Meta.SKILL_BRANCHES:
		var nodes: Array = Meta.branch_nodes(branch)
		if nodes.is_empty():
			_fail("Expected branch '%s' to have nodes." % branch)
			return
		for i in range(nodes.size()):
			var node: Dictionary = nodes[i]
			if int(node["tier"]) != i + 1:
				_fail("Expected branch '%s' tiers to be contiguous 1..N (acyclic)." % branch)
				return
			if ids.has(str(node["id"])):
				_fail("Duplicate skill node id '%s'." % str(node["id"]))
				return
			ids[str(node["id"])] = true
			if str(node.get("desc", "")) == "" or str(node.get("title", "")) == "":
				_fail("Node '%s' missing RU title/desc." % str(node["id"]))
				return
			# Описание без сырых внутренних ID (урок SCRUM-148).
			if str(node["desc"]).contains("_mult") or str(node["desc"]).contains("_flat"):
				_fail("Node '%s' desc leaks internal token." % str(node["id"]))
				return


func _test_branch_sequential_unlock() -> void:
	var state: Dictionary = Meta.default_state()
	state["skill_points"] = 99
	var wealth: Array = Meta.branch_nodes("wealth")
	var t1: String = str(wealth[0]["id"])
	var t2: String = str(wealth[1]["id"])
	# tier 1 доступен, tier 2 — заперт, пока не куплен tier 1.
	if Meta.node_status(state, t1) != "available":
		_fail("Expected tier 1 to be available with points.")
		return
	if Meta.node_status(state, t2) != "locked":
		_fail("Expected tier 2 to be locked before tier 1.")
		return
	Meta.buy_skill_node(state, t1)
	if Meta.node_status(state, t2) != "available":
		_fail("Expected tier 2 to unlock after buying tier 1.")
		return
	# Нельзя купить заранее запертый узел (через 2 tier).
	var t3: String = str(wealth[2]["id"])
	if Meta.can_buy_node(state, t3):
		_fail("Expected tier 3 to remain unbuyable before tier 2.")
		return


func _test_purchase_and_points() -> void:
	var state: Dictionary = Meta.default_state()
	state["skill_points"] = 1
	var first: String = str(Meta.branch_nodes("might")[0]["id"])
	Meta.buy_skill_node(state, first)
	if not Meta.is_node_purchased(state, first):
		_fail("Expected node to be purchased.")
		return
	if Meta.skill_points(state) != 0:
		_fail("Expected purchase to spend the point.")
		return
	# Без очков следующий узел недоступен, даже если разблокирован по tier.
	var second: String = str(Meta.branch_nodes("might")[1]["id"])
	if Meta.can_buy_node(state, second):
		_fail("Expected no-points node to be unbuyable.")
		return
	# Победа над боссом начисляет очко умений.
	Meta.record_boss_victory(state, "berserk", 0)
	if Meta.skill_points(state) != 1:
		_fail("Expected a boss victory to grant 1 skill point.")
		return


func _test_save_load_roundtrip() -> void:
	var path := "user://test_meta_skilltree.cfg"
	var state: Dictionary = Meta.default_state()
	state["skill_points"] = 10
	# Купить первые два узла стойкости.
	var e: Array = Meta.branch_nodes("endure")
	Meta.buy_skill_node(state, str(e[0]["id"]))
	Meta.buy_skill_node(state, str(e[1]["id"]))
	Meta.save_state(state, path)
	var loaded: Dictionary = Meta.load_state(path)
	if Meta.purchased_nodes(loaded).size() != 2:
		_fail("Expected 2 purchased nodes after load.")
		return
	if Meta.skill_points(loaded) != 8:
		_fail("Expected skill_points to persist (got %d)." % Meta.skill_points(loaded))
		return
	if not Meta.is_node_purchased(loaded, str(e[0]["id"])):
		_fail("Expected purchased node to persist by id.")
		return


func _test_skill_tree_screen() -> void:
	# Инкремент 3: экран древа умений из меню — все узлы видимы, состояния и
	# покупка работают, очки тратятся, сохранение узлов.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	# Дать очки в текущем мета-состоянии.
	var state: Dictionary = main.get("meta_state")
	state["skill_points"] = 5
	state["skill_nodes"] = []
	main.set("meta_state", state)

	main.ui._show_skill_tree_screen()
	await process_frame
	if main.find_child("SkillTreeScreen", true, false) == null:
		_fail("Expected skill tree screen to open.")
		return
	var node_buttons: Array = main.find_children("SkillNode_*", "Button", true, false)
	if node_buttons.size() != Meta.SKILL_TREE.size():
		_fail("Expected %d skill node buttons, got %d." % [Meta.SKILL_TREE.size(), node_buttons.size()])
		return
	if main.find_child("SkillTreePointsLabel", true, false) == null:
		_fail("Expected a skill points counter.")
		return

	# Купить tier-1 узел ветви (доступен) — очки тратятся, узел становится куплен.
	var first_id: String = str(Meta.branch_nodes("might")[0]["id"])
	var first_btn := main.find_child("SkillNode_%s" % first_id, true, false) as Button
	if first_btn == null or first_btn.disabled:
		_fail("Expected tier-1 node '%s' to be enabled/available." % first_id)
		return
	var points_before: int = Meta.skill_points(main.get("meta_state"))
	first_btn.pressed.emit()
	await process_frame
	if not Meta.is_node_purchased(main.get("meta_state"), first_id):
		_fail("Expected clicking a node to purchase it.")
		return
	if Meta.skill_points(main.get("meta_state")) != points_before - 1:
		_fail("Expected purchase to spend a skill point on screen.")
		return

	main.queue_free()
	await process_frame


func _test_player_application() -> void:
	# Инкремент 2a: player.apply_meta_skill_modifiers складывает боевое подмножество
	# дерева в run_modifiers и заряжает ульту (capstone). Применяем полное дерево.
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	await process_frame

	var state: Dictionary = Meta.default_state()
	var all_nodes := []
	for node in Meta.SKILL_TREE:
		all_nodes.append(str(node["id"]))
	state["skill_nodes"] = all_nodes
	var mods: Dictionary = Meta.skill_modifiers(state)

	var run_mods: Dictionary = player.get("run_modifiers")
	var dmg_before := float(run_mods.get("damage_multiplier", 1.0))
	var hp_before := float(player.get("max_health"))
	player.set("ultimate_charge", 0.0)

	player.call("apply_meta_skill_modifiers", mods)
	await process_frame

	run_mods = player.get("run_modifiers")
	if float(run_mods.get("damage_multiplier", 1.0)) <= dmg_before:
		_fail("Expected meta skill damage_mult to raise damage_multiplier.")
		return
	if float(player.get("max_health")) <= hp_before:
		_fail("Expected meta skill max_health_mult to raise max HP.")
		return
	if float(run_mods.get("defense_flat", 0.0)) <= 0.0 or float(run_mods.get("regeneration_flat", 0.0)) <= 0.0:
		_fail("Expected meta skill flats (defense/regen) to apply.")
		return
	if float(run_mods.get("xp_gain_multiplier", 1.0)) <= 1.0:
		_fail("Expected meta skill xp_gain_mult to apply.")
		return
	# Capstone «Боевой раж»: ульта стартует на 50%.
	var ult_charge := float(player.get("ultimate_charge"))
	var ult_max := float(player.get("ultimate_max_charge"))
	if ult_charge < ult_max * 0.45:
		_fail("Expected ult_start_charge capstone to pre-charge the ultimate (%.1f/%.1f)." % [ult_charge, ult_max])
		return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_full_tree_power_cap() -> void:
	# Полная прокачка всех узлов -> эффективная сила не выше ~+30%.
	var state: Dictionary = Meta.default_state()
	var all_nodes := []
	for node in Meta.SKILL_TREE:
		all_nodes.append(str(node["id"]))
	state["skill_nodes"] = all_nodes
	var power := Meta.estimated_power_multiplier(state)
	if power > 1.30:
		_fail("Full skill tree exceeds +30%% power cap: %.3f." % power)
		return
	if power < 1.10:
		_fail("Full skill tree suspiciously weak (%.3f) — check effects." % power)
		return
	var mods: Dictionary = Meta.skill_modifiers(state)
	# Capstone-флаги присутствуют.
	for flag in ["guaranteed_rare_shop", "first_levelup_rare", "ult_start_charge", "death_save"]:
		if not mods.has(flag):
			_fail("Expected full tree to include capstone flag '%s'." % flag)
			return
