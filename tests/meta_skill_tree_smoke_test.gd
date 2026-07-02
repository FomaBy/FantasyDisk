extends SceneTree

# SCRUM-828: data-целостность Меты 4.0 «Созвездия героев» (17 per-class графов +
# Атлас гильдии), экономика двух валют (эмблемы/пыль), keystone-взаимоисключение,
# скрытые звезды, миграция сейва schema 4→5, бюджет силы §6 дизайн-дока
# (docs/design/systems/meta_constellations.md), применение к игроку и старый
# экран дерева (v3 UI живёт на совместимом API до T3/SCRUM-827).

const Meta := preload("res://scripts/meta_progression.gd")
const CharacterData := preload("res://scripts/progression_data_characters.gd")
const TreeData := preload("res://scripts/meta_progression_tree_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _initialize() -> void:
	_test_tree_data_integrity()
	_test_effect_keys_are_wired()
	_test_graph_connectivity()
	_test_purchase_and_currencies()
	_test_save_load_roundtrip()
	_test_migration_schema4_to_5()
	_test_budget_power_corridor()
	_test_atlas_stays_non_combat()
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


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


# --- Данные ---

func _test_tree_data_integrity() -> void:
	# 17 созвездий × 22 узла + Атлас 24 = 398; id уникальны; adj симметричны;
	# описания RU без внутренних токенов; у эффект-узлов есть числа или готовая
	# фраза флага; позиции заданы и в мире (pos), и нормированно (npos).
	if Meta.SKILL_TREE.size() != 17 * 22 + 24:
		_fail("Expected 17*22+24=398 nodes, got %d." % Meta.SKILL_TREE.size())
		return
	var ids := {}
	var class_keystones := {}
	var atlas_keystones := 0
	for node in Meta.SKILL_TREE:
		var node_data: Dictionary = node
		var node_id := str(node_data.get("id", ""))
		if node_id == "" or ids.has(node_id):
			_fail("Duplicate or empty node id '%s'." % node_id)
			return
		ids[node_id] = true
		if not (node_data.get("pos") is Vector2) or not (node_data.get("npos") is Vector2):
			_fail("Node '%s' missing pos/npos." % node_id)
			return
		if not (node_data.get("adj", []) is Array) or (node_data.get("adj", []) as Array).is_empty():
			_fail("Node '%s' missing adjacency." % node_id)
			return
		if str(node_data.get("title", "")) == "" or str(node_data.get("desc", "")) == "":
			_fail("Node '%s' missing RU title/desc." % node_id)
			return
		var desc := str(node_data["desc"])
		for token in ["_mult", "_flat", "_bonus", "_chance"]:
			if desc.contains(token):
				_fail("Node '%s' desc leaks internal token '%s'." % [node_id, token])
				return
		if str(node_data.get("kind", "")) == "keystone":
			var affinity := str(node_data.get("class_affinity", ""))
			if affinity == "":
				atlas_keystones += 1
			else:
				class_keystones[affinity] = int(class_keystones.get(affinity, 0)) + 1
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
	if atlas_keystones != 4:
		_fail("Expected 4 inherited v2 keystones in the Atlas, got %d." % atlas_keystones)
		return
	var entry_ids := {}
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		if int(class_keystones.get(cid, 0)) != 3:
			_fail("Expected exactly 3 keystones for '%s'." % cid)
			return
		if not Meta.CLASS_ENTRY_NODES.has(cid):
			_fail("Missing constellation core for '%s'." % cid)
			return
		var entry_id := str(Meta.CLASS_ENTRY_NODES[cid])
		if entry_ids.has(entry_id) or Meta.node_by_id(entry_id).is_empty():
			_fail("Constellation core '%s' duplicated or missing." % entry_id)
			return
		entry_ids[entry_id] = true
	# Наследные keystone v2 присутствуют в Атласе (§6.5 дизайна).
	var all_atlas_effects := {}
	for node in Meta.atlas_nodes():
		for key in ((node as Dictionary).get("effects", {}) as Dictionary).keys():
			all_atlas_effects[str(key)] = true
	for flag in ["death_save", "guaranteed_rare_shop", "first_levelup_rare", "ult_start_charge"]:
		if not all_atlas_effects.has(flag):
			_fail("Atlas must inherit v2 keystone flag '%s'." % flag)
			return


func _test_effect_keys_are_wired() -> void:
	# Приложение B дизайна: КАЖДЫЙ ключ эффекта графа обязан быть разведён в
	# player.gd (META_SKILL_*_MAP / флаги) или в main/ui (экономика) — иначе
	# эффект молча теряется.
	var wired := {}
	for key in PlayerScript.META_SKILL_MULT_MAP.keys():
		wired[str(key)] = true
	for key in PlayerScript.META_SKILL_FLAT_MAP.keys():
		wired[str(key)] = true
	for key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP.keys():
		wired[str(key)] = true
	# Флаги player.gd (apply_meta_skill_modifiers) и экономика main.gd/ui_screens.gd.
	for key in ["ult_start_charge", "death_save", "lowhp_guard", "guaranteed_rare_shop", "first_levelup_rare", "shop_price_mult", "attr_cost_mult", "start_gold_flat", "attr_extra_options"]:
		wired[str(key)] = true
	for node in Meta.SKILL_TREE:
		var node_data: Dictionary = node
		for key in (node_data.get("effects", {}) as Dictionary).keys():
			if not wired.has(str(key)):
				_fail("Node '%s' uses unwired effect key '%s' (Appendix B gate)." % [str(node_data["id"]), str(key)])
				return


func _test_graph_connectivity() -> void:
	# Каждое созвездие связно от своего ядра (все 22 узла достижимы);
	# Атлас связен от хаба (24 узла).
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		var members := {}
		for node in Meta.constellation_nodes(cid):
			members[str((node as Dictionary)["id"])] = true
		var reached := _bfs(str(Meta.CLASS_ENTRY_NODES[cid]), members)
		if reached != members.size():
			_fail("Constellation '%s' is not fully connected (%d of %d)." % [cid, reached, members.size()])
			return
	var atlas_members := {}
	for node in Meta.atlas_nodes():
		atlas_members[str((node as Dictionary)["id"])] = true
	if _bfs("atlas_hub", atlas_members) != atlas_members.size():
		_fail("Atlas graph is not fully connected.")
		return


func _bfs(start_id: String, members: Dictionary) -> int:
	if not members.has(start_id):
		return 0
	var visited := {start_id: true}
	var queue := [start_id]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		for neighbor in Meta.node_by_id(current).get("adj", []):
			var nid := str(neighbor)
			if members.has(nid) and not visited.has(nid):
				visited[nid] = true
				queue.append(nid)
	return visited.size()


# --- Экономика покупок ---

func _test_purchase_and_currencies() -> void:
	var state: Dictionary = Meta.default_state()
	state = Meta.record_boss_victory(state, "berserk", 0)  # 2 эмблемы берсерка, 1 пыль
	# Ядро открыто сразу, сосед ядра доступен, дальний узел заперт.
	var core_id := str(Meta.CLASS_ENTRY_NODES["berserk"])
	if Meta.node_status(state, core_id) != "purchased":
		_fail("Constellation core must be open from the start.")
		return
	if Meta.node_status(state, "berserk_m0") != "available":
		_fail("Core neighbor must be available with sigils in pocket.")
		return
	if Meta.node_status(state, "berserk_m1") != "locked":
		_fail("Distant star must stay locked without adjacency.")
		return
	# Эмблемы чужого класса не тратятся: у солдата валюты нет.
	if Meta.node_status(state, "soldier_m0") != "locked":
		_fail("Soldier stars must be locked without soldier sigils.")
		return
	# Покупка списывает эмблемы ЭТОГО класса.
	var before := Meta.class_sigils_available(state, "berserk")
	state = Meta.allocate_node(state, "berserk_m0")
	if not Meta.is_node_purchased(state, "berserk_m0"):
		_fail("Expected star purchase to register.")
		return
	if Meta.class_sigils_available(state, "berserk") != before - 1:
		_fail("Expected purchase to spend berserk sigils.")
		return
	if Meta.stardust_available(state) != Meta.stardust_earned(state):
		_fail("Constellation purchase must not spend stardust.")
		return
	# Атлас: хаб открыт, покупка QoL-узла списывает пыль.
	if Meta.node_status(state, "atlas_hub") != "purchased":
		_fail("Atlas hub must be open from the start.")
		return
	if Meta.node_status(state, "atlas_m0") != "locked":
		_fail("Atlas node must be locked without enough stardust (cost 2 > 1).")
		return
	state = Meta.record_boss_victory(state, "soldier", 0)  # +1 пыль (вторая первая победа)
	if Meta.node_status(state, "atlas_m0") != "available":
		_fail("Atlas node must unlock with 2 stardust.")
		return
	var dust_before := Meta.stardust_available(state)
	var berserk_sigils_before := Meta.class_sigils_available(state, "berserk")
	state = Meta.allocate_node(state, "atlas_m0")
	if not Meta.is_node_purchased(state, "atlas_m0") or Meta.stardust_available(state) != dust_before - 2:
		_fail("Atlas purchase must spend 2 stardust.")
		return
	if Meta.class_sigils_available(state, "berserk") != berserk_sigils_before:
		_fail("Atlas purchase must not spend class sigils.")
		return
	# Полный бесплатный респек: узлы возвращаются, валюты освобождаются.
	state = Meta.reset_skill_tree(state)
	if Meta.global_level(state) != 0 or Meta.class_sigils_available(state, "berserk") != Meta.class_sigils_earned(state, "berserk") or Meta.stardust_available(state) != Meta.stardust_earned(state):
		_fail("Free full respec must refund all currencies.")
		return


func _test_save_load_roundtrip() -> void:
	var path := "user://test_meta_constellations.cfg"
	var state: Dictionary = Meta.default_state()
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3, 4, 5]}
	state = Meta.allocate_node(state, "berserk_m0")
	state = Meta.allocate_node(state, "berserk_m1")
	state = Meta.allocate_node(state, "berserk_m2")
	state = Meta.allocate_node(state, "berserk_t0")
	state = Meta.allocate_node(state, "berserk_k0")
	state = Meta.set_active_keystone(state, "berserk", "berserk_k0")
	Meta.save_state(state, path)
	var loaded: Dictionary = Meta.load_state(path)
	if Meta.global_level(loaded) != 5:
		_fail("Expected 5 purchased stars after reload, got %d." % Meta.global_level(loaded))
		return
	if Meta.active_keystone(loaded, "berserk") != "berserk_k0":
		_fail("Active keystone must survive save/load.")
		return
	if Meta.class_sigils_earned(loaded, "berserk") != 22:
		_fail("Sigils must derive from persisted awards (22).")
		return
	if Meta.class_sigils_available(loaded, "berserk") != 22 - 9:
		_fail("Spent sigils must persist through save/load (m0+m1+m2=3, t0=2, k0=4).")
		return
	if int(loaded.get("skill_tree_schema", 0)) != Meta.TREE_SCHEMA_VERSION:
		_fail("Loaded state must carry schema 5.")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_migration_schema4_to_5() -> void:
	# Старый сейв v3 (schema 4): узлы общего графа → полный респек; первые клиры
	# (awards) объединяются с выводом из ascension_levels (возврат наград,
	# заблокированных v3-капом 100); валюты пересчитываются; ничего не теряется.
	var path := "user://test_meta_migration_v4.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "skill_tree_schema", 4)
	cfg.set_value("meta", "meta_points", 61)
	cfg.set_value("meta", "skill_points", 11)
	cfg.set_value("meta", "meta_point_awards", {"berserk": [0, 1, 2]})
	cfg.set_value("meta", "ascension_levels", {"berserk": 4, "dark_mage": 5})
	cfg.set_value("meta", "skill_nodes", ["core_origin", "strength_gate", "berserk_a0", "old_missing_node"])
	cfg.set_value("meta", "class_boss_wins", {"berserk": 6, "dark_mage": 9})
	cfg.set_value("meta", "class_challenges_done", {"berserk": ["weapon_master"]})
	cfg.set_value("meta", "class_challenge_progress", {"dark_mage": {"weapons": ["staff"], "best_ascension": 5, "no_shop_wins": 0}})
	cfg.set_value("meta", "secret_boss_defeated", true)
	cfg.set_value("meta", "achievements", ["first_blood", "slayer"])
	cfg.save(path)
	var loaded := Meta.load_state(path)
	if Meta.global_level(loaded) != 0:
		_fail("Schema 4 nodes must be fully respecced on migration.")
		return
	# Эмблемы берсерка: awards [0,1,2] ∪ derived [0..3] = [0..3] → 2+2+3+4=11 + челлендж 2 = 13.
	if Meta.class_sigils_earned(loaded, "berserk") != 13:
		_fail("Berserk sigils after migration must be 13 (awards∪levels + challenge), got %d." % Meta.class_sigils_earned(loaded, "berserk"))
		return
	# Тёмный маг: derived [0..4] = 2+2+3+4+5 = 16.
	if Meta.class_sigils_earned(loaded, "dark_mage") != 16:
		_fail("Dark mage sigils after migration must be 16, got %d." % Meta.class_sigils_earned(loaded, "dark_mage"))
		return
	# Пыль: первые победы (berserk, dark_mage) 2 + A5 тёмного мага (best_ascension 5) 1
	# + секретный босс 3 + вехи достижений (2 ачивки → пороги 1,2) 2 = 8.
	if Meta.stardust_earned(loaded) != 8:
		_fail("Stardust after migration must be 8, got %d." % Meta.stardust_earned(loaded))
		return
	if not (loaded.get("active_keystones", {}) as Dictionary).is_empty():
		_fail("Migration must not invent active keystones.")
		return
	# Прогресс-факты пережили миграцию.
	if Meta.class_boss_wins(loaded, "dark_mage") != 9 or not Meta.class_challenges_done(loaded, "berserk").has("weapon_master"):
		_fail("Wins/challenges must survive migration.")
		return
	if not Meta.secret_boss_defeated(loaded):
		_fail("Secret boss flag must survive migration.")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Совсем древний сейв (schema 2, линейное дерево) — тот же путь миграции.
	var old_path := "user://test_meta_migration_v2.cfg"
	var old_cfg := ConfigFile.new()
	old_cfg.set_value("meta", "meta_points", 999)
	old_cfg.set_value("meta", "skill_tree_schema", 2)
	old_cfg.set_value("meta", "ascension_levels", {"berserk": 3})
	old_cfg.set_value("meta", "skill_nodes", ["wealth_gold_1", "endure_capstone"])
	old_cfg.save(old_path)
	var old_loaded := Meta.load_state(old_path)
	if Meta.global_level(old_loaded) != 0:
		_fail("Linear-tree save must be respecced.")
		return
	if Meta.class_sigils_earned(old_loaded, "berserk") != 7:
		_fail("Linear-tree save must derive 2+2+3=7 sigils from ascension 3, got %d." % Meta.class_sigils_earned(old_loaded, "berserk"))
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))


# --- Бюджет силы (§6 дизайна) ---

func _test_budget_power_corridor() -> void:
	# Полный реалистичный билд класса (ядро + 12 атрибутных + 4 техники +
	# 1 активный keystone) даёт +18..25% взвешенной эффективной силы; коридор
	# damage_mult-эквивалента [0.10..0.40]; спред лучших билдов классов ≤1.25.
	var best_by_class := {}
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		var star_ids := []
		var keystone_ids := []
		for node in Meta.constellation_nodes(cid):
			var node_data: Dictionary = node
			match str(node_data.get("role", "")):
				"minor", "technique":
					star_ids.append(str(node_data["id"]))
				"keystone":
					keystone_ids.append(str(node_data["id"]))
		var best := 0.0
		for keystone_id in keystone_ids:
			var state: Dictionary = Meta.default_state()
			var build := star_ids.duplicate()
			build.append(keystone_id)
			state["skill_nodes"] = build
			state["active_keystones"] = {cid: keystone_id}
			if Meta.purchased_nodes(state).size() != build.size() + 17 + 1:
				_fail("Build for '%s' references unknown ids." % cid)
				return
			var power := Meta.estimated_class_power_multiplier(state, cid)
			var gain := power - 1.0
			if gain < 0.18 or gain > 0.25:
				_fail("Class '%s' keystone '%s' build power %.4f outside +18..25%% corridor." % [cid, keystone_id, power])
				return
			if gain < 0.10 or gain > 0.40:
				_fail("Class '%s' damage-mult equivalent %.4f outside [0.10..0.40]." % [cid, gain])
				return
			best = maxf(best, gain)
		best_by_class[cid] = best
	var lo := 10.0
	var hi := 0.0
	for cid in best_by_class.keys():
		lo = minf(lo, float(best_by_class[cid]))
		hi = maxf(hi, float(best_by_class[cid]))
	if hi / lo > 1.25:
		_fail("Cross-class power spread %.3f exceeds 1.25 (lo %.4f, hi %.4f)." % [hi / lo, lo, hi])
		return
	# Полное созвездие дороже заработка без челленджей (22 < 32): выбор реален.
	if Meta.constellation_total_cost("berserk") <= 22:
		_fail("Full constellation must cost more than ascension-only sigil income.")
		return


func _test_atlas_stays_non_combat() -> void:
	# §6.5: Атлас (весь!) почти не несёт боевой силы — аккаунт-множитель < 1.30
	# (наследные keystone учтены историческим балансом), и его вклад в
	# class-power формулу тоже мал.
	var state: Dictionary = Meta.default_state()
	var all_atlas := []
	for node in Meta.atlas_nodes():
		if int((node as Dictionary).get("cost", 0)) > 0:
			all_atlas.append(str((node as Dictionary)["id"]))
	state["skill_nodes"] = all_atlas
	if Meta.estimated_power_multiplier(state) >= 1.30:
		_fail("Full Atlas account power must stay < 1.30.")
		return
	if Meta.estimated_class_power_multiplier(state, "berserk") - 1.0 > 0.05:
		_fail("Full Atlas must add <= 5%% weighted class power.")
		return
	# Стоимость Атласа выше потолка пыли: «всё не купить».
	if Meta.atlas_total_cost() <= Meta.STARDUST_CAP:
		_fail("Atlas total cost must exceed the 50 stardust cap.")
		return


# --- Применение к игроку и старый экран ---

func _test_player_application() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	await process_frame

	# Полное созвездие берсерка (активен k1 «Несущий бурю») + пара узлов Атласа.
	var state: Dictionary = Meta.default_state()
	var build := ["atlas_m8", "atlas_k2"]
	for node in Meta.constellation_nodes("berserk"):
		var node_data: Dictionary = node
		if str(node_data.get("role", "")) in ["minor", "technique", "keystone"]:
			build.append(str(node_data["id"]))
	state["skill_nodes"] = build
	state["active_keystones"] = {"berserk": "berserk_k1"}
	var mods: Dictionary = Meta.skill_modifiers_for_class(state, "berserk")

	var run_mods: Dictionary = player.get("run_modifiers")
	var dmg_before := float(run_mods.get("damage_multiplier", 1.0))
	var strength_before := float((player.get("stats") as Dictionary).get("strength", 0.0))
	player.set("ultimate_charge", 0.0)

	player.call("apply_meta_skill_modifiers", mods)
	await process_frame

	run_mods = player.get("run_modifiers")
	if float(run_mods.get("damage_multiplier", 1.0)) <= dmg_before:
		_fail("Expected constellation damage stars to raise damage_multiplier.")
		return
	# Ядро-эмблема: +1 Силы берсерка в базовые статы.
	if float((player.get("stats") as Dictionary).get("strength", 0.0)) < strength_before + 0.9:
		_fail("Expected berserk core to add +1 strength.")
		return
	if float(run_mods.get("xp_gain_multiplier", 1.0)) <= 1.0:
		_fail("Expected Atlas xp node to apply.")
		return
	# Атлас-keystone «Боевой раж»: ульта стартует на 50%.
	var ult_charge := float(player.get("ultimate_charge"))
	var ult_max := float(player.get("ultimate_max_charge"))
	if ult_charge < ult_max * 0.45:
		_fail("Expected ult_start_charge keystone to pre-charge the ultimate (%.1f/%.1f)." % [ult_charge, ult_max])
		return
	# Downside активного keystone: max_health ниже, чем без него (числовой трейд-офф).
	var no_key_state: Dictionary = Meta.default_state()
	no_key_state["skill_nodes"] = build.duplicate()
	no_key_state["active_keystones"] = {}
	var no_key_mods := Meta.skill_modifiers_for_class(no_key_state, "berserk")
	if float(mods.get("max_health_mult", 0.0)) >= float(no_key_mods.get("max_health_mult", 0.0)):
		_fail("Expected «Несущий бурю» downside to reduce max_health_mult.")
		return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_skill_tree_screen() -> void:
	# Старый экран (v3 UI, SCRUM-698) живёт на новом ядре: все узлы рендерятся,
	# статусы/покупка работают, фасад очков тратится.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var state: Dictionary = main.get("meta_state")
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3]}
	state["skill_nodes"] = []
	main.set("meta_state", state)

	main.ui._show_skill_tree_screen()
	await process_frame
	if main.find_child("SkillTreeScreen", true, false) == null:
		_fail("Expected skill tree screen to open.")
		return
	var node_buttons: Array = main.find_children("SkillNode_*", "BaseButton", true, false)
	if node_buttons.size() != Meta.SKILL_TREE.size():
		_fail("Expected %d skill node buttons, got %d." % [Meta.SKILL_TREE.size(), node_buttons.size()])
		return
	if main.find_child("SkillTreePointsLabel", true, false) == null:
		_fail("Expected a skill points counter.")
		return

	# Купить звезду у ядра берсерка — фасад очков тратится, узел куплен.
	var star_id := "berserk_m0"
	var star_btn := main.find_child("SkillNode_%s" % star_id, true, false) as BaseButton
	if star_btn == null or star_btn.disabled:
		_fail("Expected core-adjacent star '%s' to be enabled/available." % star_id)
		return
	var points_before: int = Meta.skill_points(main.get("meta_state"))
	star_btn.pressed.emit()
	await process_frame
	if not Meta.is_node_purchased(main.get("meta_state"), star_id):
		_fail("Expected clicking a star to purchase it.")
		return
	if Meta.skill_points(main.get("meta_state")) != points_before - 1:
		_fail("Expected purchase to spend a point on screen.")
		return

	main.queue_free()
	await process_frame


func _test_victory_shows_skill_points() -> void:
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


func _test_shop_discount() -> void:
	# Атлас, ветвь «Лавка»: узлы скидки снижают цены товаров.
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
	disc_state["skill_nodes"] = ["atlas_m4", "atlas_m5"]
	main.set("meta_state", disc_state)
	(main.get("rng") as RandomNumberGenerator).seed = 4242
	var disc_items: Array = main.ui._random_shop_items(4)
	var disc_total := 0
	for item in disc_items:
		disc_total += int((item as Dictionary).get("cost", 0))

	if disc_total >= full_total or disc_total <= 0:
		_fail("Expected Atlas shop nodes to lower prices (%d vs %d)." % [disc_total, full_total])
		return
	main.queue_free()
	await process_frame


func _test_attribute_discount() -> void:
	# Атлас: узлы удешевления докачки атрибутов.
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
	disc_state["skill_nodes"] = ["atlas_m6", "atlas_m7"]
	main.set("meta_state", disc_state)
	var disc_cost: int = main.ui._attribute_buy_cost()

	if disc_cost >= full_cost or disc_cost <= 0:
		_fail("Expected Atlas attribute nodes to lower buy cost (%d vs %d)." % [disc_cost, full_cost])
		return
	main.queue_free()
	await process_frame


func _test_attribute_extra_options() -> void:
	# Атлас «Кругозор»: +1 вариант докачки атрибутов.
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
	more_state["skill_nodes"] = ["atlas_n2"]
	main.set("meta_state", more_state)
	if main.ui._random_attribute_pair().size() != 3:
		_fail("Expected Atlas «Кругозор» to raise attribute offer to 3.")
		return
	main.queue_free()
	await process_frame


func _test_first_levelup_rare_capstone() -> void:
	# Атлас-keystone «Озарение»: первое повышение гарантирует основную характеристику.
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
	state["skill_nodes"] = ["atlas_k1"]
	main.set("meta_state", state)

	var has_stat := false
	for reward in main.ui._random_level_up_rewards(3):
		if bool((reward as Dictionary).get("rare", false)):
			has_stat = true
			break
	if not has_stat:
		_fail("Expected first-levelup-rare keystone to force a main characteristic.")
		return

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
	if forced_count >= 20:
		_fail("Expected keystone not to force a stat past the first level-up.")
		return

	main.queue_free()
	await process_frame


func _test_guaranteed_rare_shop_capstone() -> void:
	# Атлас-keystone «Связи в гильдии»: в лавке гарантированно есть tier-3 товар.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_ascension_level", 0)
	main.set("route_stage", 3)
	if main.has_method("reset_run_ascension"):
		main.call("reset_run_ascension")
	var state: Dictionary = main.get("meta_state")
	state["skill_nodes"] = ["atlas_k0"]
	main.set("meta_state", state)

	for _try in range(8):
		(main.get("rng") as RandomNumberGenerator).seed = 100 + _try
		var items: Array = main.ui._random_shop_items(4)
		var has_rare := false
		for item in items:
			if int((item as Dictionary).get("tier", 1)) >= 3:
				has_rare = true
				break
		if not has_rare:
			_fail("Expected guaranteed-rare-shop keystone to include a tier-3 item.")
			return
	main.queue_free()
	await process_frame


func _test_death_save_capstone() -> void:
	# Атлас-keystone «Вторая жизнь»: первый смертельный удар оставляет 1 HP.
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = ["atlas_k3"]
	player.call("apply_meta_skill_modifiers", Meta.skill_modifiers(state))
	var derived: Dictionary = player.get("derived_parameters")
	derived["dodge"] = 0.0
	derived["defense"] = 0.0
	derived["absorb"] = 0.0
	player.set("health", 5.0)
	player.set("_damage_invulnerability_left", 0.0)

	player.call("take_damage", 1000.0)
	await process_frame
	if not is_instance_valid(player) or float(player.get("health")) < 0.9 or float(player.get("health")) > 3.0:
		_fail("Expected death-save keystone to leave the player alive at low HP.")
		return
	var rm: Dictionary = player.get("run_modifiers")
	if float(rm.get("death_save_used", 0.0)) <= 0.0:
		_fail("Expected death-save to be marked used after triggering.")
		return

	player.set("_damage_invulnerability_left", 0.0)
	player.call("take_damage", 1000.0)
	await process_frame
	if is_instance_valid(player):
		_fail("Expected death-save to be once-per-run (second lethal hit kills).")
		return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_run_start_application() -> void:
	# apply_ascension_bonuses на старте забега применяет моды класса (созвездие +
	# Атлас) к игроку и начисляет старт-золото Атласа.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_ascension_level", 0)
	main.set("route_stage", 0)
	var state: Dictionary = main.get("meta_state")
	state["skill_nodes"] = ["atlas_k0", "berserk_m0", "berserk_m2"]
	main.set("meta_state", state)

	var player := PLAYER_SCENE.instantiate()
	main.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	player.set("money", 0)
	var dmg_before := float((player.get("run_modifiers") as Dictionary).get("damage_multiplier", 1.0))

	main.call("apply_ascension_bonuses", player)
	await process_frame

	if int(player.get("money")) < 15:
		_fail("Expected Atlas guild keystone to grant +15 gold at run start (got %d)." % int(player.get("money")))
		return
	if float((player.get("run_modifiers") as Dictionary).get("damage_multiplier", 1.0)) <= dmg_before:
		_fail("Expected constellation damage to apply at run start.")
		return

	main.queue_free()
	await process_frame


func _test_class_progression_run_start_application() -> void:
	# SCRUM-360: классовые бонусы применяются только выбранному классу.
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
