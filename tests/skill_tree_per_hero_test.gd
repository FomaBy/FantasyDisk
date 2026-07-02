extends SceneTree

# SCRUM-696/726/807: per-hero контракт классовых ветвей Skill Tree 3.0.
# У КАЖДОГО из 17 классов: ≥8 классовых (class_affinity) нодов, ≥2 notable,
# ровно 1 уникальный keystone; профильные атрибуты ветви следуют матрице
# релевантности (ATTRIBUTE_RELEVANCE primary); описания эффект-нодов содержат
# числа; class_affinity фильтруется (эффект спит у чужих классов).

const Meta := preload("res://scripts/meta_progression.gd")
const CharacterData := preload("res://scripts/progression_data_characters.gd")
const TreeData := preload("res://scripts/meta_progression_tree_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")


func _initialize() -> void:
	_test_class_affinity_keystones_are_unique()
	_test_class_branch_contract()
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


func _test_class_affinity_keystones_are_unique() -> void:
	var seen := {}
	var signatures := {}
	for node in Meta.node_list():
		var node_data: Dictionary = node
		if str(node_data.get("kind", "")) == "keystone" and str(node_data.get("class_affinity", "")) != "":
			var class_id := str(node_data["class_affinity"])
			seen[class_id] = int(seen.get(class_id, 0)) + 1
			var effects: Dictionary = node_data.get("effects", {})
			if effects.is_empty():
				_fail("Class keystone '%s' has no effects." % str(node_data.get("id", "")))
				return
			# Сигнатура эффектов keystone должна быть уникальной между классами.
			var keys: Array = effects.keys()
			keys.sort()
			var sig := ""
			for k in keys:
				sig += "%s=%.4f;" % [str(k), float(effects[k])]
			if signatures.has(sig):
				_fail("Keystone '%s' shares effect signature with '%s'." % [str(node_data["id"]), str(signatures[sig])])
				return
			signatures[sig] = str(node_data["id"])
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		if int(seen.get(cid, 0)) != 1:
			_fail("Expected exactly one class keystone for '%s', got %d." % [cid, int(seen.get(cid, 0))])
			return


func _test_class_branch_contract() -> void:
	# Инвертируем матрицу релевантности → primary-атрибуты каждого класса.
	var primaries := {}
	# relevant[class] = множество атрибутов класса (primary ∪ secondary). Всё вне
	# него — optional («профильно мимо»). SCRUM-807: атрибутные ноды ветви обязаны
	# следовать этой матрице; optional-атрибуты в ветви запрещены.
	var relevant := {}
	for attr in CharacterData.ATTRIBUTE_RELEVANCE.keys():
		var rel: Dictionary = CharacterData.ATTRIBUTE_RELEVANCE[attr]
		for c in rel.get("primary", []):
			var cid := str(c)
			if not primaries.has(cid):
				primaries[cid] = []
			(primaries[cid] as Array).append(str(attr))
			if not relevant.has(cid):
				relevant[cid] = {}
			(relevant[cid] as Dictionary)[str(attr)] = true
		for c in rel.get("secondary", []):
			var cid := str(c)
			if not relevant.has(cid):
				relevant[cid] = {}
			(relevant[cid] as Dictionary)[str(attr)] = true
	# Обратный маппинг ключ-эффекта → attr-id (только атрибутные ключи ATTR_EFFECT).
	var key_to_attr := {}
	for a in TreeData.ATTR_EFFECT.keys():
		key_to_attr[str((TreeData.ATTR_EFFECT[a] as Dictionary)["key"])] = str(a)
	# Собираем классовые ноды по классу.
	var affinity_count := {}
	var notable_count := {}
	var keystone_count := {}
	var branch_keys := {}
	for node in Meta.node_list():
		var node_data: Dictionary = node
		var aff := str(node_data.get("class_affinity", ""))
		if aff == "":
			continue
		affinity_count[aff] = int(affinity_count.get(aff, 0)) + 1
		var kind := str(node_data.get("kind", ""))
		if kind == "notable":
			notable_count[aff] = int(notable_count.get(aff, 0)) + 1
		elif kind == "keystone":
			keystone_count[aff] = int(keystone_count.get(aff, 0)) + 1
		if not branch_keys.has(aff):
			branch_keys[aff] = {}
		var effects: Dictionary = node_data.get("effects", {})
		for k in effects.keys():
			(branch_keys[aff] as Dictionary)[str(k)] = true
		# Запрет чужих optional/non-relevant атрибутов на АТРИБУТНЫХ узлах ветви
		# (minor/notable). Keystone — build-defining узел, не атрибутный: его
		# уникальная механика может использовать любые ключи (правило не применяется).
		if kind == "minor" or kind == "notable":
			for k in effects.keys():
				var ek := str(k)
				if not key_to_attr.has(ek):
					continue
				var attr_id := str(key_to_attr[ek])
				if not (relevant.get(aff, {}) as Dictionary).has(attr_id):
					_fail("Class '%s' %s node '%s' grants non-relevant (optional) attr '%s' (%s)." % [aff, kind, str(node_data.get("id", "")), attr_id, ek])
					return
		# Описания эффект-нодов обязаны содержать число (мандат «ясно и понятно»).
		if not effects.is_empty() and not _has_digit(str(node_data.get("desc", ""))):
			_fail("Class node '%s' desc has no number: %s" % [str(node_data.get("id", "")), str(node_data.get("desc", ""))])
			return
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		if int(affinity_count.get(cid, 0)) < 8:
			_fail("Class '%s' has %d affinity nodes (<8)." % [cid, int(affinity_count.get(cid, 0))])
			return
		if int(notable_count.get(cid, 0)) < 2:
			_fail("Class '%s' has %d notable nodes (<2)." % [cid, int(notable_count.get(cid, 0))])
			return
		if int(keystone_count.get(cid, 0)) != 1:
			_fail("Class '%s' must have exactly 1 keystone, got %d." % [cid, int(keystone_count.get(cid, 0))])
			return
		# Каждый primary-атрибут с разведённым ключом представлен в ветви.
		# (magic_focus не имеет собственного ключа — представлен через damage, см. дизайн.)
		var keys_present: Dictionary = branch_keys.get(cid, {})
		for attr in primaries.get(cid, []):
			var a := str(attr)
			if not TreeData.ATTR_EFFECT.has(a):
				continue
			var eff_key := str((TreeData.ATTR_EFFECT[a] as Dictionary)["key"])
			if not keys_present.has(eff_key):
				_fail("Class '%s' primary attr '%s' (%s) not represented in its branch." % [cid, a, eff_key])
				return


func _test_class_affinity_effects_are_filtered() -> void:
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = ["berserk_a0", "berserk_n0", "berserk_key"]
	var account_mods := Meta.skill_modifiers(state)
	if not account_mods.is_empty():
		_fail("Expected account skill_modifiers() to skip class-affinity nodes.")
		return
	var berserk_mods := Meta.skill_modifiers_for_class(state, "berserk")
	if float(berserk_mods.get("damage_mult", 0.0)) <= 0.0 or float(berserk_mods.get("low_hp_damage_bonus", 0.0)) <= 0.0:
		_fail("Expected Berserk signature effects for selected Berserk.")
		return
	var soldier_mods := Meta.skill_modifiers_for_class(state, "soldier")
	if soldier_mods.has("damage_mult") or soldier_mods.has("low_hp_damage_bonus"):
		_fail("Expected Berserk signature effects not to leak to Soldier.")
		return


func _test_attribute_nodes_create_different_profiles() -> void:
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = [
		"strength_flow_1", "strength_flow_2", "strength_notable",
		"intelligence_flow_1", "intelligence_flow_2", "intelligence_notable",
		"leadership_flow_1", "leadership_flow_2", "leadership_notable",
	]
	var mods := Meta.skill_modifiers(state)
	for required in ["strength_flat", "intelligence_flat", "leadership_flat"]:
		if float(mods.get(required, 0.0)) <= 0.0:
			_fail("Expected attribute modifier '%s' from purchased petals." % required)
			return

	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var berserk := PLAYER_SCENE.instantiate()
	holder.add_child(berserk)
	berserk.configure_character("berserk", "sword")
	var berserk_before: Dictionary = (berserk.get("derived_parameters") as Dictionary).duplicate(true)
	berserk.apply_meta_skill_modifiers(mods)
	await process_frame
	var berserk_after: Dictionary = berserk.get("derived_parameters")

	var engineer := PLAYER_SCENE.instantiate()
	holder.add_child(engineer)
	engineer.configure_character("engineer", "engineer_sentry_wrench")
	var engineer_before: Dictionary = (engineer.get("derived_parameters") as Dictionary).duplicate(true)
	engineer.apply_meta_skill_modifiers(mods)
	await process_frame
	var engineer_after: Dictionary = engineer.get("derived_parameters")

	var berserk_damage_gain := float(berserk_after.get("damage", 0.0)) - float(berserk_before.get("damage", 0.0))
	var berserk_summon_gain := float(berserk_after.get("summon_amount", 0.0)) - float(berserk_before.get("summon_amount", 0.0))
	var engineer_damage_gain := float(engineer_after.get("damage", 0.0)) - float(engineer_before.get("damage", 0.0))
	var engineer_summon_gain := float(engineer_after.get("summon_amount", 0.0)) - float(engineer_before.get("summon_amount", 0.0))

	if berserk_damage_gain <= 0.0 or engineer_summon_gain <= 0.0:
		_fail("Expected attribute petals to change derived combat parameters.")
		return
	if is_equal_approx(berserk_damage_gain, engineer_damage_gain) and is_equal_approx(berserk_summon_gain, engineer_summon_gain):
		_fail("Expected same attribute petals to produce different per-hero derived profiles.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
