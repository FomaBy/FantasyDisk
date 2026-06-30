extends SceneTree

# SCRUM-696: data-целостность PoE-like графа умений, экономика метаочков,
# миграция старого линейного дерева, сохранение/загрузка, балансовый потолок силы.
# Отдельный файл — runtime_smoke_test.gd занят параллельным воркером (анти-коллизия).

const Meta := preload("res://scripts/meta_progression.gd")
const CharacterData := preload("res://scripts/progression_data_characters.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _initialize() -> void:
	_test_tree_data_integrity()
	_test_branch_sequential_unlock()
	_test_purchase_and_points()
	_test_save_load_roundtrip()
	_test_meta_point_formula_and_cap()
	_test_save_migration_from_linear_tree()
	_test_full_tree_power_cap()
	await _test_player_application()
	await _test_skill_tree_screen()
	await _test_victory_shows_skill_points()
	await _test_shop_discount()
	await _test_attribute_discount()
	await _test_attribute_extra_options()
	await _test_first_levelup_rare_capstone()
	await _test_guaranteed_rare_shop_capstone()
	await _test_death_save_capstone()
	await _test_run_start_application()
	await _test_class_progression_run_start_application()
	print("Meta skill tree smoke test passed.")
	quit(0)


func _test_run_start_application() -> void:
	# Финал SCRUM-150: apply_ascension_bonuses на старте забега применяет боевые
	# модификаторы дерева к игроку + начисляет старт-золото.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_ascension_level", 0)
	main.set("route_stage", 0)
	var state: Dictionary = main.get("meta_state")
	state["skill_nodes"] = ["wealth_start_1", "wealth_start_2", "might_dmg_1"]
	main.set("meta_state", state)

	var player := PLAYER_SCENE.instantiate()
	main.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	player.set("money", 0)
	var dmg_before := float((player.get("run_modifiers") as Dictionary).get("damage_multiplier", 1.0))

	main.call("apply_ascension_bonuses", player)
	await process_frame

	# Старт-золото v2: два малых узла по +15.
	if int(player.get("money")) < 30:
		_fail("Expected start-gold nodes to grant +30 gold at run start (got %d)." % int(player.get("money")))
		return
	# Боевой модификатор урона применён.
	if float((player.get("run_modifiers") as Dictionary).get("damage_multiplier", 1.0)) <= dmg_before:
		_fail("Expected meta skill damage to apply at run start.")
		return

	main.queue_free()
	await process_frame


func _test_class_progression_run_start_application() -> void:
	# SCRUM-360: классовые бонусы применяются только к выбранному классу и через
	# тот же run-start wiring, что и аккаунтное древо.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	var state: Dictionary = Meta.default_state()
	for _i in range(9):
		state = Meta.record_boss_victory(state, "berserk", 0)
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	main.set("selected_ascension_level", 0)

	var berserk_player := PLAYER_SCENE.instantiate()
	main.add_child(berserk_player)
	berserk_player.configure_character("berserk", "sword")
	var berserk_damage_before := float((berserk_player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	var berserk_health_before := float(berserk_player.get("max_health"))
	main.call("apply_ascension_bonuses", berserk_player)
	await process_frame
	var berserk_damage_after := float((berserk_player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	var berserk_health_after := float(berserk_player.get("max_health"))
	if berserk_damage_after <= berserk_damage_before or berserk_health_after <= berserk_health_before:
		_fail("Expected selected class progression to increase Berserk damage and HP at run start.")
		return

	var soldier_player := PLAYER_SCENE.instantiate()
	main.add_child(soldier_player)
	soldier_player.configure_character("soldier", "soldier_rifle")
	main.set("selected_character_id", "soldier")
	var soldier_damage_before := float((soldier_player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	main.call("apply_ascension_bonuses", soldier_player)
	await process_frame
	var soldier_damage_after := float((soldier_player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	if not is_equal_approx(soldier_damage_after, soldier_damage_before):
		_fail("Expected Berserk class progression not to leak onto Soldier.")
		return

	main.queue_free()
	await process_frame


func _test_death_save_capstone() -> void:
	# Capstone «Вторая жизнь»: первый смертельный удар оставляет 1 HP (раз за забег).
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	# Применяем дерево с death_save -> флаг в run_modifiers.
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = ["endure_capstone"]
	player.call("apply_meta_skill_modifiers", Meta.skill_modifiers(state))
	# Гарантируем смертельный удар: убираем уклонение/защиту/поглощение.
	var derived: Dictionary = player.get("derived_parameters")
	derived["dodge"] = 0.0
	derived["defense"] = 0.0
	derived["absorb"] = 0.0
	player.set("health", 5.0)
	player.set("_damage_invulnerability_left", 0.0)

	player.call("take_damage", 1000.0)
	await process_frame
	# death_save ставит 1 HP; за кадр реген может чуть добавить — проверяем «выжил на низком HP».
	if not is_instance_valid(player) or float(player.get("health")) < 0.9 or float(player.get("health")) > 3.0:
		_fail("Expected death-save capstone to leave the player alive at low HP.")
		return
	var rm: Dictionary = player.get("run_modifiers")
	if float(rm.get("death_save_used", 0.0)) <= 0.0:
		_fail("Expected death-save to be marked used after triggering.")
		return

	# Второй смертельный удар (сброс неуязвимости) — спасения больше нет.
	player.set("_damage_invulnerability_left", 0.0)
	player.call("take_damage", 1000.0)
	await process_frame
	if is_instance_valid(player):
		_fail("Expected death-save to be once-per-run (second lethal hit kills).")
		return

	holder.queue_free()
	current_scene = null
	await process_frame


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
	state["meta_point_awards"] = {"berserk": [0, 1, 2]}
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
	if total < 90 or total > Meta.META_POINTS_CAP:
		_fail("Expected skill tree budget near cap 100, got %d." % total)
		return
	if Meta.SKILL_TREE.size() < 60 or Meta.SKILL_TREE.size() > 90:
		_fail("Expected compact PoE-like graph to have 60-90 nodes, got %d." % Meta.SKILL_TREE.size())
		return
	var ids := {}
	var keystones := 0
	for node in Meta.SKILL_TREE:
		var node_data: Dictionary = node
		var node_id := str(node_data.get("id", ""))
		if node_id == "" or ids.has(node_id):
			_fail("Duplicate or empty skill node id '%s'." % node_id)
			return
		ids[node_id] = true
		if not node_data.has("pos") or not (node_data.get("pos") is Vector2):
			_fail("Node '%s' missing Vector2 pos." % node_id)
			return
		if not (node_data.get("adj", []) is Array):
			_fail("Node '%s' missing adjacency list." % node_id)
			return
		if str(node_data.get("kind", "")) == "keystone":
			keystones += 1
		if str(node_data.get("desc", "")) == "" or str(node_data.get("title", "")) == "":
			_fail("Node '%s' missing RU title/desc." % node_id)
			return
		if str(node_data["desc"]).contains("_mult") or str(node_data["desc"]).contains("_flat"):
			_fail("Node '%s' desc leaks internal token." % node_id)
			return
	for node in Meta.SKILL_TREE:
		var node_data: Dictionary = node
		var from_id := str(node_data["id"])
		for neighbor_id in node_data.get("adj", []):
			var neighbor := Meta.node_by_id(str(neighbor_id))
			if neighbor.is_empty():
				_fail("Node '%s' has dangling neighbor '%s'." % [from_id, str(neighbor_id)])
				return
			if not (neighbor.get("adj", []) as Array).has(from_id):
				_fail("Edge '%s' -> '%s' is not symmetric." % [from_id, str(neighbor_id)])
				return
	if keystones < 3 or keystones > 6:
		_fail("Expected 3-6 keystones, got %d." % keystones)
		return
	var entry_ids := {}
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		if not Meta.CLASS_ENTRY_NODES.has(cid):
			_fail("Missing class entry node for '%s'." % cid)
			return
		var entry_id := str(Meta.CLASS_ENTRY_NODES[cid])
		if entry_ids.has(entry_id):
			_fail("Duplicate class entry node '%s'." % entry_id)
			return
		entry_ids[entry_id] = true
		if Meta.node_by_id(entry_id).is_empty():
			_fail("Class entry node '%s' is not in SKILL_TREE." % entry_id)
			return


func _test_branch_sequential_unlock() -> void:
	var state: Dictionary = Meta.default_state()
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3]}
	var entry_id := str(Meta.CLASS_ENTRY_NODES["berserk"])
	if Meta.node_status(state, entry_id) != "available":
		_fail("Expected a class entry node to be available as graph root.")
		return
	var entry := Meta.node_by_id(entry_id)
	var neighbor_id := str((entry.get("adj", []) as Array)[0])
	var far_id := "core_keystone"
	if Meta.node_status(state, neighbor_id) != "locked":
		_fail("Expected entry neighbor to stay locked until entry is allocated.")
		return
	if Meta.node_status(state, far_id) != "locked":
		_fail("Expected distant graph node to be locked before connecting path.")
		return
	Meta.allocate_node(state, entry_id)
	if Meta.node_status(state, neighbor_id) != "available":
		_fail("Expected neighbor to unlock after allocating adjacent entry.")
		return
	if Meta.node_status(state, far_id) != "locked":
		_fail("Expected distant node to remain locked without adjacency.")
		return


func _test_purchase_and_points() -> void:
	var state: Dictionary = Meta.default_state()
	state["meta_point_awards"] = {"berserk": [0]}
	var first: String = str(Meta.CLASS_ENTRY_NODES["berserk"])
	var before := Meta.available_meta_points(state)
	Meta.allocate_node(state, first)
	if not Meta.is_node_purchased(state, first):
		_fail("Expected entry node to be allocated.")
		return
	if Meta.available_meta_points(state) != before - int(Meta.node_by_id(first)["cost"]):
		_fail("Expected allocation to spend available meta points.")
		return
	var second: String = str((Meta.node_by_id(first).get("adj", []) as Array)[0])
	if Meta.can_buy_node(state, second):
		_fail("Expected no-points neighbor to be unbuyable.")
		return
	Meta.record_boss_victory(state, "berserk", 1)
	if Meta.available_meta_points(state) != 1:
		_fail("Expected first clear of ascension 1 to grant one more available meta point.")
		return


func _test_save_load_roundtrip() -> void:
	var path := "user://test_meta_skilltree.cfg"
	var state: Dictionary = Meta.default_state()
	state["meta_point_awards"] = {"berserk": [0, 1, 2]}
	var entry_id := str(Meta.CLASS_ENTRY_NODES["berserk"])
	Meta.allocate_node(state, entry_id)
	var next_id := str((Meta.node_by_id(entry_id).get("adj", []) as Array)[0])
	Meta.allocate_node(state, next_id)
	Meta.save_state(state, path)
	var loaded: Dictionary = Meta.load_state(path)
	if Meta.purchased_nodes(loaded).size() != 2:
		_fail("Expected 2 allocated nodes after load.")
		return
	if Meta.earned_meta_points(loaded) != 4:
		_fail("Expected earned meta points to persist from ascension awards.")
		return
	if Meta.available_meta_points(loaded) != 2:
		_fail("Expected available meta points to persist through derived economy.")
		return
	if not Meta.is_node_purchased(loaded, entry_id):
		_fail("Expected allocated node to persist by id.")
		return


func _test_meta_point_formula_and_cap() -> void:
	var state: Dictionary = Meta.default_state()
	var expected := [1, 2, 4, 7, 11, 16]
	for level in range(0, Meta.MAX_ASCENSION_LEVEL + 1):
		state = Meta.record_boss_victory(state, "berserk", level)
		if Meta.earned_meta_points(state) != int(expected[level]):
			_fail("Expected earned meta points after ascension %d to be %d, got %d." % [level, int(expected[level]), Meta.earned_meta_points(state)])
			return
		var repeat_before := Meta.earned_meta_points(state)
		state = Meta.record_boss_victory(state, "berserk", level)
		if Meta.earned_meta_points(state) != repeat_before:
			_fail("Expected repeat clear at ascension %d not to farm meta points." % level)
			return
	var cap_state: Dictionary = Meta.default_state()
	for class_id in Meta.CLASS_ENTRY_NODES.keys():
		for level in range(0, Meta.MAX_ASCENSION_LEVEL + 1):
			cap_state = Meta.record_boss_victory(cap_state, str(class_id), level)
	if Meta.earned_meta_points(cap_state) != Meta.META_POINTS_CAP:
		_fail("Expected earned meta points to clamp at cap %d, got %d." % [Meta.META_POINTS_CAP, Meta.earned_meta_points(cap_state)])
		return


func _test_save_migration_from_linear_tree() -> void:
	var path := "user://test_meta_skilltree_migration.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "meta_points", 999)
	cfg.set_value("meta", "skill_points", 999)
	cfg.set_value("meta", "ascension_levels", {"berserk": 3, "dark_mage": 5})
	cfg.set_value("meta", "skill_nodes", ["wealth_gold_1", "endure_capstone", "old_missing_node"])
	cfg.save(path)
	var loaded := Meta.load_state(path)
	if not Meta.purchased_nodes(loaded).is_empty():
		_fail("Expected old linear skill nodes to be respecced during schema migration.")
		return
	if Meta.earned_meta_points(loaded) != 15:
		_fail("Expected migrated meta points from ascension levels to be 15, got %d." % Meta.earned_meta_points(loaded))
		return
	if Meta.available_meta_points(loaded) != 15:
		_fail("Expected migrated available meta points to match earned points after reset.")
		return


func _removed_old_linear_tests_marker() -> void:
	pass


func _test_skill_tree_screen() -> void:
	# Инкремент 3: экран древа умений из меню — все узлы видимы, состояния и
	# покупка работают, очки тратятся, сохранение узлов.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	# Дать очки в текущем мета-состоянии.
	var state: Dictionary = main.get("meta_state")
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3]}
	state["skill_nodes"] = []
	main.set("meta_state", state)

	main.ui._show_skill_tree_screen()
	await process_frame
	if main.find_child("SkillTreeScreen", true, false) == null:
		_fail("Expected skill tree screen to open.")
		return
	# SCRUM-698: графовые узлы рендерятся как TextureButton (BaseButton) с арт-ассетами.
	var node_buttons: Array = main.find_children("SkillNode_*", "BaseButton", true, false)
	if node_buttons.size() != Meta.SKILL_TREE.size():
		_fail("Expected %d skill node buttons, got %d." % [Meta.SKILL_TREE.size(), node_buttons.size()])
		return
	if main.find_child("SkillTreePointsLabel", true, false) == null:
		_fail("Expected a skill points counter.")
		return

	# Купить узел-точку входа класса (всегда доступен) — очки тратятся, узел куплен.
	var first_id: String = str(Meta.branch_nodes("might")[0]["id"])
	var first_btn := main.find_child("SkillNode_%s" % first_id, true, false) as BaseButton
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
