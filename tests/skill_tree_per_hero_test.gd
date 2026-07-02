extends SceneTree

# SCRUM-828: per-hero контракт созвездий Меты 4.0 (дизайн §3/§5/§6).
# У КАЖДОГО из 17 классов: ровно 22 узла (ядро 0-cost с +1 базовым атрибутом,
# 12 звёзд-атрибутов cost 1 СТРОГО из primary/secondary ATTRIBUTE_RELEVANCE,
# 4 звезды-техники cost 2, 3 взаимоисключающих keystone cost 4 с числовым
# downside ≥25% ценности апсайда, 2 скрытые звезды на challenge-условиях);
# keystone-взаимоисключение (активен ≤1, переключение купленных бесплатно);
# class_affinity фильтруется (эффект спит у чужих классов).

const Meta := preload("res://scripts/meta_progression.gd")
const CharacterData := preload("res://scripts/progression_data_characters.gd")
const TreeData := preload("res://scripts/meta_progression_tree_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")


func _initialize() -> void:
	_test_constellation_anatomy()
	_test_minor_stars_follow_relevance_matrix()
	_test_keystones_have_downside_and_unique_signatures()
	_test_keystone_mutual_exclusion()
	_test_hidden_stars_unlock_by_condition()
	_test_class_affinity_effects_are_filtered()
	await _test_attribute_nodes_create_different_profiles()
	print("Skill tree per-hero test passed.")
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _has_digit(text: String) -> bool:
	for ch in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


# §3: анатомия созвездия — 22 узла фиксированных ролей и цен на каждый класс.
func _test_constellation_anatomy() -> void:
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		var nodes := Meta.constellation_nodes(cid)
		if nodes.size() != 22:
			_fail("Созвездие '%s' должно иметь 22 узла, получено %d." % [cid, nodes.size()])
			return
		var by_role := {}
		for node in nodes:
			var node_data: Dictionary = node
			var role := str(node_data.get("role", ""))
			by_role[role] = int(by_role.get(role, 0)) + 1
			var cost := int(node_data.get("cost", -1))
			var expected_cost := int(TreeData.ROLE_COSTS.get(role, -1))
			if cost != expected_cost:
				_fail("Узел '%s' роли '%s' должен стоить %d, стоит %d." % [str(node_data["id"]), role, expected_cost, cost])
				return
			if str(node_data.get("title", "")) == "" or str(node_data.get("desc", "")) == "":
				_fail("Узел '%s' без RU заголовка/описания." % str(node_data["id"]))
				return
			if not (node_data.get("npos") is Vector2):
				_fail("Узел '%s' без нормированной позиции npos (приложение C)." % str(node_data["id"]))
				return
			var npos: Vector2 = node_data["npos"]
			if npos.x < 0.0 or npos.x > 1.0 or npos.y < 0.0 or npos.y > 1.0:
				_fail("npos узла '%s' вне [0..1]: %s." % [str(node_data["id"]), str(npos)])
				return
		if int(by_role.get("core", 0)) != 1 or int(by_role.get("minor", 0)) != 12 \
				or int(by_role.get("technique", 0)) != 4 or int(by_role.get("keystone", 0)) != 3 \
				or int(by_role.get("hidden", 0)) != 2:
			_fail("Созвездие '%s': роли должны быть 1/12/4/3/2 (core/minor/technique/keystone/hidden), получено %s." % [cid, str(by_role)])
			return
		# Ядро: 0-cost, «первый вкус» — +1 базового атрибута, статус purchased сразу.
		var core := Meta.node_by_id(str(Meta.CLASS_ENTRY_NODES[cid]))
		if core.is_empty() or str(core.get("role", "")) != "core":
			_fail("CLASS_ENTRY_NODES['%s'] должен указывать на ядро созвездия." % cid)
			return
		var core_effects: Dictionary = core.get("effects", {})
		var base_attr := str(TreeData.CLASS_BASE_ATTRIBUTE.get(cid, ""))
		if not is_equal_approx(float(core_effects.get(base_attr, 0.0)), 1.0):
			_fail("Ядро '%s' должно давать +1 базового атрибута '%s'." % [cid, base_attr])
			return
		if Meta.node_status(Meta.default_state(), str(core["id"])) != "purchased":
			_fail("Ядро '%s' должно быть открыто сразу (0-cost)." % cid)
			return
		# Полная стоимость созвездия: 12×1 + 4×2 + 3×4 = 32 (28–32 по §3).
		if Meta.constellation_total_cost(cid) != 32:
			_fail("Полная стоимость созвездия '%s' должна быть 32 эмблемы, получено %d." % [cid, Meta.constellation_total_cost(cid)])
			return


# §6.3: звезды-атрибуты класса ⊆ его primary/secondary из ATTRIBUTE_RELEVANCE.
func _test_minor_stars_follow_relevance_matrix() -> void:
	var relevant := {}
	var primaries := {}
	for attr in CharacterData.ATTRIBUTE_RELEVANCE.keys():
		var rel: Dictionary = CharacterData.ATTRIBUTE_RELEVANCE[attr]
		for c in rel.get("primary", []):
			var cid := str(c)
			if not relevant.has(cid):
				relevant[cid] = {}
			(relevant[cid] as Dictionary)[str(attr)] = true
			if not primaries.has(cid):
				primaries[cid] = []
			(primaries[cid] as Array).append(str(attr))
		for c in rel.get("secondary", []):
			var cid := str(c)
			if not relevant.has(cid):
				relevant[cid] = {}
			(relevant[cid] as Dictionary)[str(attr)] = true
	var key_to_attr := {}
	for a in TreeData.STAR_ATTRS.keys():
		key_to_attr[str((TreeData.STAR_ATTRS[a] as Dictionary)["key"])] = str(a)
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		var keys_present := {}
		for node in Meta.constellation_nodes(cid):
			var node_data: Dictionary = node
			var role := str(node_data.get("role", ""))
			var effects: Dictionary = node_data.get("effects", {})
			for k in effects.keys():
				keys_present[str(k)] = true
			# Правило матрицы — для звёзд-атрибутов (жёсткий гейт §3).
			if role != "minor":
				continue
			for k in effects.keys():
				var ek := str(k)
				if not key_to_attr.has(ek):
					_fail("Звезда-атрибут '%s' класса '%s' с не-атрибутным ключом '%s'." % [str(node_data["id"]), cid, ek])
					return
				var attr_id := str(key_to_attr[ek])
				if not (relevant.get(cid, {}) as Dictionary).has(attr_id):
					_fail("Класс '%s': звезда '%s' даёт нерелевантный (optional) атрибут '%s'." % [cid, str(node_data["id"]), attr_id])
					return
			if not _has_digit(str(node_data.get("desc", ""))):
				_fail("Описание звезды '%s' без числа: %s" % [str(node_data["id"]), str(node_data.get("desc", ""))])
				return
		# Каждый primary-атрибут с разведённым ключом представлен в созвездии
		# (magic_focus не имеет собственного ключа — представлен через damage).
		for attr in primaries.get(cid, []):
			var a := str(attr)
			if not TreeData.STAR_ATTRS.has(a):
				continue
			var eff_key := str((TreeData.STAR_ATTRS[a] as Dictionary)["key"])
			if not keys_present.has(eff_key):
				_fail("Класс '%s': primary-атрибут '%s' (%s) не представлен в созвездии." % [cid, a, eff_key])
				return


# §3/§6.4: у каждого keystone числовой downside (≥25% ценности апсайда в весах
# силы) и уникальная сигнатура эффектов между всеми 51 keystone.
func _test_keystones_have_downside_and_unique_signatures() -> void:
	var signatures := {}
	var per_class := {}
	for node in Meta.node_list():
		var node_data: Dictionary = node
		if str(node_data.get("role", "")) != "keystone" or str(node_data.get("class_affinity", "")) == "":
			continue
		var cid := str(node_data["class_affinity"])
		per_class[cid] = int(per_class.get(cid, 0)) + 1
		var effects: Dictionary = node_data.get("effects", {})
		if effects.is_empty():
			_fail("Keystone '%s' без эффектов." % str(node_data["id"]))
			return
		if str(node_data.get("exclusive_group", "")) != "%s_keystones" % cid:
			_fail("Keystone '%s' вне exclusive-группы своего класса." % str(node_data["id"]))
			return
		var up_power := 0.0
		var down_power := 0.0
		var has_negative := false
		for k in effects.keys():
			var v := float(effects[k])
			var w := float(TreeData.POWER_WEIGHTS.get(str(k), 0.0))
			if str(k) == "shop_price_mult" and v > 0.0:
				w = -0.25
			var contribution := v * w
			if contribution < 0.0:
				has_negative = true
				down_power += absf(contribution)
			else:
				up_power += contribution
		if not has_negative:
			_fail("Keystone '%s' без числового downside." % str(node_data["id"]))
			return
		if down_power < 0.25 * up_power - 0.0001:
			_fail("Keystone '%s': downside %.4f < 25%% апсайда %.4f." % [str(node_data["id"]), down_power, up_power])
			return
		var keys: Array = effects.keys()
		keys.sort()
		var sig := ""
		for k in keys:
			sig += "%s=%.4f;" % [str(k), float(effects[k])]
		if signatures.has(sig):
			_fail("Keystone '%s' повторяет сигнатуру '%s'." % [str(node_data["id"]), str(signatures[sig])])
			return
		signatures[sig] = str(node_data["id"])
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		if int(per_class.get(str(class_id), 0)) != 3:
			_fail("Класс '%s' должен иметь ровно 3 keystone, получено %d." % [str(class_id), int(per_class.get(str(class_id), 0))])
			return


# §3: взаимоисключение keystone — активен ≤1; переключение купленных бесплатно;
# первый купленный активируется сам; неактивный купленный «спит».
func _test_keystone_mutual_exclusion() -> void:
	var state: Dictionary = Meta.default_state()
	# Эмблемы на полный путь: все клиры + челленджи не нужны — задаём покупки напрямую.
	state["skill_nodes"] = [
		"berserk_m0", "berserk_m1", "berserk_m2", "berserk_t0",
		"berserk_m3", "berserk_m4", "berserk_m5", "berserk_t1",
	]
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3, 4, 5]}
	# Покупка первого keystone через публичный API: авто-активация.
	state = Meta.allocate_node(state, "berserk_k0")
	if not Meta.is_node_purchased(state, "berserk_k0"):
		_fail("Первый keystone должен покупаться при доступных эмблемах.")
		return
	if Meta.active_keystone(state, "berserk") != "berserk_k0":
		_fail("Первый купленный keystone должен активироваться автоматически.")
		return
	# Покупка второго keystone: куплен, но активен по-прежнему ≤1.
	state = Meta.allocate_node(state, "berserk_k1")
	if not Meta.is_node_purchased(state, "berserk_k1"):
		_fail("Второй keystone должен быть покупаемым (владение не исключается).")
		return
	if Meta.active_keystone(state, "berserk") != "berserk_k0":
		_fail("Покупка второго keystone не должна менять активный.")
		return
	var mods_k0 := Meta.skill_modifiers_for_class(state, "berserk")
	# Ключи, уникальные для неактивного k1 (нет ни у k0, ни у остального билда),
	# обязаны ОТСУТСТВОВАТЬ в модах: купленный, но не активный keystone спит.
	var k1_effects: Dictionary = Meta.node_by_id("berserk_k1").get("effects", {})
	for k in k1_effects.keys():
		var found_elsewhere := (Meta.node_by_id("berserk_k0").get("effects", {}) as Dictionary).has(k) \
			or (Meta.node_by_id("berserk_core").get("effects", {}) as Dictionary).has(k)
		for nid in state["skill_nodes"]:
			var node := Meta.node_by_id(str(nid))
			if str(node.get("role", "")) != "keystone" and (node.get("effects", {}) as Dictionary).has(k):
				found_elsewhere = true
		if not found_elsewhere and mods_k0.has(k):
			_fail("Эффект '%s' неактивного keystone просочился в моды класса." % str(k))
			return
	# Бесплатное переключение: активен k1, k0 уснул; количество покупок не меняется.
	var purchases_before: int = Meta.global_level(state)
	var sigils_before: int = Meta.class_sigils_available(state, "berserk")
	state = Meta.set_active_keystone(state, "berserk", "berserk_k1")
	if Meta.active_keystone(state, "berserk") != "berserk_k1":
		_fail("Переключение купленного keystone должно работать.")
		return
	if Meta.global_level(state) != purchases_before or Meta.class_sigils_available(state, "berserk") != sigils_before:
		_fail("Переключение keystone должно быть бесплатным.")
		return
	var mods_k1 := Meta.skill_modifiers_for_class(state, "berserk")
	if mods_k0.hash() == mods_k1.hash():
		_fail("Смена активного keystone должна менять моды класса.")
		return
	# Некупленный keystone нельзя активировать.
	state = Meta.set_active_keystone(state, "berserk", "berserk_k2")
	if Meta.active_keystone(state, "berserk") != "berserk_k1":
		_fail("Некупленный keystone не должен активироваться.")
		return


# §5: скрытые звезды открываются ПОДВИГОМ (метрики челленджей), не покупкой.
func _test_hidden_stars_unlock_by_condition() -> void:
	var state: Dictionary = Meta.default_state()
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		for node in Meta.constellation_nodes(cid):
			var node_data: Dictionary = node
			if str(node_data.get("role", "")) != "hidden":
				continue
			var nid := str(node_data["id"])
			var condition: Dictionary = node_data.get("condition", {})
			if str(condition.get("metric", "")) == "" or int(condition.get("threshold", 0)) <= 0:
				_fail("Скрытая звезда '%s' без условия." % nid)
				return
			if str(condition.get("text", "")) == "" or str(node_data.get("lore", "")) == "":
				_fail("Скрытая звезда '%s' без RU-текста условия/лора." % nid)
				return
			if Meta.node_status(state, nid) != "hidden":
				_fail("Скрытая звезда '%s' до подвига должна быть в тумане ('hidden')." % nid)
				return
			if Meta.hidden_star_unlocked(state, nid):
				_fail("Скрытая звезда '%s' не должна быть открыта на свежем аккаунте." % nid)
				return
	# Подвиги берсерка: 2 оружия (h0) и победа на возвышении 2 (h1).
	state = Meta.record_boss_victory(state, "berserk", 0, {"weapon_id": "sword"})
	state = Meta.record_boss_victory(state, "berserk", 1, {"weapon_id": "axe"})
	state = Meta.record_boss_victory(state, "berserk", 2, {"weapon_id": "axe"})
	for hid in ["berserk_h0", "berserk_h1"]:
		if not Meta.hidden_star_unlocked(state, hid):
			_fail("Подвиг должен открыть скрытую звезду '%s'." % hid)
			return
		if Meta.node_status(state, hid) != "purchased":
			_fail("Открытая скрытая звезда '%s' должна светиться как купленная." % hid)
			return
	var mods := Meta.skill_modifiers_for_class(state, "berserk")
	var h0_effects: Dictionary = Meta.node_by_id("berserk_h0").get("effects", {})
	for k in h0_effects.keys():
		if float(mods.get(k, 0.0)) <= 0.0:
			_fail("Эффект открытой скрытой звезды должен попасть в моды класса ('%s')." % str(k))
			return
	# Прогресс условия для панели узла (API 827).
	var progress := Meta.hidden_star_progress(state, "berserk_h0")
	if not bool(progress.get("unlocked", false)) or int(progress.get("required", 0)) <= 0:
		_fail("hidden_star_progress должен отражать открытие и порог.")
		return
	# Чужому классу подвиг берсерка звёзд не открывает.
	if Meta.hidden_star_unlocked(state, "soldier_h0"):
		_fail("Подвиг берсерка не должен открывать скрытые звезды солдата.")
		return


func _test_class_affinity_effects_are_filtered() -> void:
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = ["berserk_m0", "berserk_t0", "berserk_k0"]
	state["active_keystones"] = {"berserk": "berserk_k0"}
	var account_mods := Meta.skill_modifiers(state)
	if not account_mods.is_empty():
		_fail("skill_modifiers() аккаунта не должен включать узлы созвездий.")
		return
	var berserk_mods := Meta.skill_modifiers_for_class(state, "berserk")
	if float(berserk_mods.get("damage_mult", 0.0)) <= 0.0:
		_fail("Моды берсерка должны включать его купленные звезды.")
		return
	# SCRUM-834: k0 «Кровавый танец» теперь условный (бонус урона, пока HP<50%).
	if float(berserk_mods.get("hurt_damage_bonus", 0.0)) <= 0.0:
		_fail("Моды берсерка должны включать активный keystone «Кровавый танец».")
		return
	var soldier_mods := Meta.skill_modifiers_for_class(state, "soldier")
	if soldier_mods.has("damage_mult") or soldier_mods.has("hurt_damage_bonus"):
		_fail("Звезды берсерка не должны протекать солдату.")
		return
	# Ядро чужого созвездия тоже спит: у солдата только его собственное ядро.
	if not is_equal_approx(float(soldier_mods.get("perception_flat", 0.0)), 1.0):
		_fail("Ядро солдата должно давать +1 Восприятия его модам.")
		return
	if soldier_mods.has("strength_flat"):
		_fail("Ядро берсерка (+1 Силы) не должно протекать солдату.")
		return


func _test_attribute_nodes_create_different_profiles() -> void:
	# Одинаковая «инвестиция» в свои созвездия даёт РАЗНЫЕ derived-профили героев.
	var berserk_state: Dictionary = Meta.default_state()
	berserk_state["skill_nodes"] = ["berserk_m0", "berserk_m1", "berserk_m2"]
	var berserk_mods := Meta.skill_modifiers_for_class(berserk_state, "berserk")
	var engineer_state: Dictionary = Meta.default_state()
	engineer_state["skill_nodes"] = ["engineer_m0", "engineer_m1", "engineer_m2"]
	var engineer_mods := Meta.skill_modifiers_for_class(engineer_state, "engineer")

	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var berserk := PLAYER_SCENE.instantiate()
	holder.add_child(berserk)
	berserk.configure_character("berserk", "sword")
	var berserk_before: Dictionary = (berserk.get("derived_parameters") as Dictionary).duplicate(true)
	berserk.apply_meta_skill_modifiers(berserk_mods)
	await process_frame
	var berserk_after: Dictionary = berserk.get("derived_parameters")

	var engineer := PLAYER_SCENE.instantiate()
	holder.add_child(engineer)
	engineer.configure_character("engineer", "engineer_sentry_wrench")
	var engineer_before: Dictionary = (engineer.get("derived_parameters") as Dictionary).duplicate(true)
	engineer.apply_meta_skill_modifiers(engineer_mods)
	await process_frame
	var engineer_after: Dictionary = engineer.get("derived_parameters")

	var berserk_damage_gain := float(berserk_after.get("damage", 0.0)) - float(berserk_before.get("damage", 0.0))
	var engineer_summon_gain := float(engineer_after.get("summon_amount", 0.0)) - float(engineer_before.get("summon_amount", 0.0))
	var engineer_damage_gain := float(engineer_after.get("damage", 0.0)) - float(engineer_before.get("damage", 0.0))
	if berserk_damage_gain <= 0.0:
		_fail("Звезды урона берсерка должны поднять его derived damage.")
		return
	if engineer_summon_gain <= 0.0:
		_fail("Звезды призыва инженера должны поднять его derived summon_amount.")
		return
	if is_equal_approx(berserk_damage_gain, engineer_damage_gain):
		_fail("Созвездия должны давать разные per-hero профили derived-параметров.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
