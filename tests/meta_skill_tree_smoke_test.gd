extends SceneTree

# SCRUM-1068: schema-6 constellation regression plus the frozen Guild Atlas
# runtime coverage. Class paths are weapon-scoped; Guild effects remain account-
# wide and keep their established ids/behavior.

const ProgressionData := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const CharacterData := preload("res://scripts/progression_data_characters.gd")
const TreeData := preload("res://scripts/meta_progression_tree_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")


func _initialize() -> void:
	_test_schema6_tree_data_integrity()
	_test_schema6_effect_profiles()
	_test_graph_connectivity()
	_test_schema6_purchase_and_currencies()
	_test_schema6_save_load_roundtrip()
	_test_schema5_to_6_migration()
	_test_atlas_stays_non_combat()
	await _test_guild_runtime_outcomes_1069()
	await _test_victory_shows_skill_points()
	await _test_shop_discount()
	await _test_attribute_discount()
	await _test_attribute_extra_options()
	await _test_first_levelup_rare_capstone()
	await _test_guaranteed_rare_shop_capstone()
	await _test_death_save_capstone()
	await _test_class_progression_run_start_application()
	print("Meta skill tree smoke test passed.")
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


# FAN-2476: делает мутационную порчу пары raw_dodge/dodge (или raw_defense/
# defense) видимой ИМЕННО этой сюите, а не только aggregate-ратчету в
# tests/attribute_consumability_fan1887_test.gd. Возвращает true при консистентной
# паре (иначе вызывает _fail и возвращает false).
func _assert_raw_pair(container: Dictionary, legacy_key: String, raw_key: String) -> bool:
	if not container.has(raw_key):
		_fail("FAN-2474: '%s' отсутствует рядом с '%s' — raw/legacy контракт нарушен." % [raw_key, legacy_key])
		return false
	var raw_value := float(container[raw_key])
	var expected := ProgressionData.effective_dodge(raw_value) if legacy_key == "dodge" else ProgressionData.effective_defense(raw_value)
	var actual := float(container.get(legacy_key, 0.0))
	if absf(actual - expected) > 0.001:
		_fail("FAN-2474: '%s'=%.4f != effective(%s=%.2f)=%.4f — raw/legacy разошлись." % [legacy_key, actual, raw_key, raw_value, expected])
		return false
	return true


func _test_schema6_tree_data_integrity() -> void:
	if Meta.SKILL_TREE.size() != 17 * 21 + 25:
		_fail("Expected schema-6 total 17*21+25=382 nodes, got %d." % Meta.SKILL_TREE.size())
		return
	if Meta.default_state().has("active_keystones"):
		_fail("Schema-6 default state must not serialize active_keystones.")
		return
	var ids := {}
	var atlas_count := 0
	var atlas_keystones := 0
	for raw_node in Meta.SKILL_TREE:
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		if node_id == "" or ids.has(node_id):
			_fail("Duplicate or empty node id '%s'." % node_id)
			return
		ids[node_id] = true
		if not (node.get("pos") is Vector2) or not (node.get("npos") is Vector2):
			_fail("Node '%s' is missing pos/npos." % node_id)
			return
		if not (node.get("adj", []) is Array) or (node.get("adj", []) as Array).is_empty():
			_fail("Node '%s' is missing adjacency." % node_id)
			return
		if str(node.get("title", "")) == "" or str(node.get("desc", "")) == "":
			_fail("Node '%s' is missing title/description." % node_id)
			return
		if str(node.get("class_affinity", "")) == "":
			atlas_count += 1
			if str(node.get("kind", "")) == "keystone":
				atlas_keystones += 1
		for neighbor_value in node.get("adj", []):
			var neighbor_id := str(neighbor_value)
			var neighbor := Meta.node_by_id(neighbor_id)
			if neighbor.is_empty() or not (neighbor.get("adj", []) as Array).has(node_id):
				_fail("Edge '%s' <-> '%s' is dangling or asymmetric." % [node_id, neighbor_id])
				return
	if atlas_count != 25 or atlas_keystones != 4:
		_fail("Frozen Guild Atlas must remain 25 nodes with four keystones, got %d/%d." % [atlas_count, atlas_keystones])
		return
	for class_value in CharacterData.CHARACTER_CONFIGS.keys():
		var class_id := str(class_value)
		var nodes := Meta.constellation_nodes(class_id)
		var roles := {}
		for raw_node in nodes:
			var role := str((raw_node as Dictionary).get("role", ""))
			roles[role] = int(roles.get(role, 0)) + 1
		if nodes.size() != 21 or roles != {"core": 1, "weapon_boon": 15, "weapon_final": 3, "hidden": 2}:
			_fail("Class '%s' violates schema-6 21-node anatomy: %s." % [class_id, str(roles)])
			return
		if Meta.constellation_total_cost(class_id) != 20:
			_fail("Class '%s' must have exact spend 20." % class_id)
			return


func _test_schema6_effect_profiles() -> void:
	var atlas_wired := {}
	for key in PlayerScript.META_SKILL_MULT_MAP.keys():
		atlas_wired[str(key)] = true
	for key in PlayerScript.META_SKILL_FLAT_MAP.keys():
		atlas_wired[str(key)] = true
	for key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP.keys():
		atlas_wired[str(key)] = true
	for key in ["ult_start_charge", "death_save", "lowhp_guard", "guaranteed_rare_shop", "first_levelup_rare", "shop_price_mult", "attr_cost_mult", "start_gold_flat", "attr_extra_options"]:
		atlas_wired[str(key)] = true
	for raw_node in Meta.atlas_nodes():
		var node: Dictionary = raw_node
		for key in (node.get("effects", {}) as Dictionary).keys():
			if not atlas_wired.has(str(key)):
				_fail("Guild node '%s' uses unwired effect '%s'." % [str(node.get("id", "")), str(key)])
				return
	for class_value in CharacterData.CHARACTER_CONFIGS.keys():
		var class_id := str(class_value)
		var purchased := []
		for raw_node in Meta.constellation_nodes(class_id):
			var node: Dictionary = raw_node
			var role := str(node.get("role", ""))
			if role == "core":
				continue
			var profile: Dictionary = node.get("effect_profile", {})
			if str(profile.get("effect_key", "")) == "" or str(profile.get("scope", "")) != "owning_weapon_only":
				_fail("Class node '%s' lacks an owning-weapon profile." % str(node.get("id", "")))
				return
			if role in ["weapon_boon", "weapon_final"]:
				purchased.append(str(node.get("id", "")))
		var state := Meta.default_state()
		state["skill_nodes"] = purchased
		var profiles := Meta.skill_profiles_for_class(state, class_id)
		if profiles.size() != 3:
			_fail("Class '%s' must expose exactly three typed weapon profiles." % class_id)
			return
		var finals := 0
		for weapon_value in profiles.keys():
			var weapon_id := str(weapon_value)
			var typed: Dictionary = profiles[weapon_id]
			if not bool(typed.get("valid", false)) or (typed.get("node_ids", []) as Array).size() != 6:
				_fail("Profile '%s/%s' must contain exactly its six valid path nodes." % [class_id, weapon_id])
				return
			if (typed.get("mechanics", {}) as Dictionary).size() != 1:
				_fail("Profile '%s/%s' must expose one final mechanic." % [class_id, weapon_id])
				return
			finals += 1
		if finals != 3:
			_fail("All three finals of '%s' must be co-active." % class_id)
			return


func _test_schema6_purchase_and_currencies() -> void:
	var state := Meta.record_boss_victory(Meta.default_state(), "berserk", 0, {"weapon_id": "sword"})
	if Meta.class_sigils_earned(state, "berserk") != 2:
		_fail("First clear A0 must award two schema-6 sigils.")
		return
	if Meta.node_status(state, "berserk_sword_b1") != "available" \
			or Meta.node_status(state, "berserk_sword_b2") != "locked":
		_fail("Only the core-adjacent first weapon boon may be available initially.")
		return
	if Meta.node_status(state, "soldier_soldier_rifle_b1") != "locked":
		_fail("Berserk sigils must not unlock Soldier weapon nodes.")
		return
	var dust_before := Meta.stardust_available(state)
	state = Meta.allocate_node(state, "berserk_sword_b1")
	state = Meta.allocate_node(state, "berserk_sword_b2")
	if Meta.class_sigils_spent(state, "berserk") != 2 or Meta.class_sigils_available(state, "berserk") != 0:
		_fail("Two schema-6 purchases must spend exactly two Berserk sigils.")
		return
	if Meta.stardust_available(state) != dust_before:
		_fail("Class purchases must not spend Guild stardust.")
		return
	if Meta.node_status(state, "atlas_m0") != "available":
		_fail("Frozen Guild early hook must remain available after the first win.")
		return
	state = Meta.allocate_node(state, "atlas_m0")
	if not Meta.is_node_purchased(state, "atlas_m0") or Meta.stardust_available(state) != dust_before - 1:
		_fail("Frozen Guild purchase must spend one stardust.")
		return
	state = Meta.reset_skill_tree(state)
	if Meta.class_sigils_spent(state, "berserk") != 0 or Meta.stardust_available(state) != Meta.stardust_earned(state):
		_fail("Full respec must refund both schema-6 sigils and Guild stardust.")
		return


func _test_schema6_save_load_roundtrip() -> void:
	var path := "user://test_meta_constellations_schema6.cfg"
	var state := Meta.default_state()
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3, 4, 5]}
	state["skill_nodes"] = ["berserk_sword_b1", "berserk_sword_b2", "atlas_m0"]
	state["legacy_mastery"] = {"berserk": 2}
	state["hidden_reveal_facts"] = {"berserk": ["berserk_h0"]}
	Meta.save_state(state, path)
	var loaded := Meta.load_state(path)
	if int(loaded.get("skill_tree_schema", 0)) != 6:
		_fail("Roundtrip must retain schema version 6.")
		return
	if not Meta.is_node_purchased(loaded, "berserk_sword_b1") \
			or not Meta.is_node_purchased(loaded, "berserk_sword_b2") \
			or not Meta.is_node_purchased(loaded, "atlas_m0"):
		_fail("Schema-6 class and frozen Guild purchases must survive roundtrip.")
		return
	if Meta.legacy_mastery_for_class(loaded, "berserk") != 2 \
			or not Meta.hidden_reveal_facts_for_class(loaded, "berserk").has("berserk_h0"):
		_fail("Legacy mastery and hidden reveal facts must survive roundtrip.")
		return
	if loaded.has("active_keystones"):
		_fail("Roundtrip must not revive schema-5 active_keystones.")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_schema5_to_6_migration() -> void:
	var path := "user://test_meta_migration_schema5_to_6.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "skill_tree_schema", 5)
	cfg.set_value("meta", "meta_point_awards", {"berserk": [0, 1, 2, 3, 4, 5]})
	cfg.set_value("meta", "ascension_levels", {"berserk": 5})
	cfg.set_value("meta", "skill_nodes", ["berserk_m0", "berserk_k0", "atlas_m0"])
	cfg.set_value("meta", "active_keystones", {"berserk": "berserk_k0"})
	cfg.set_value("meta", "class_challenge_progress", {"berserk": {"weapons": ["sword", "axe"], "best_ascension": 2, "no_shop_wins": 0}})
	cfg.save(path)
	var loaded := Meta.load_state(path)
	if not Meta.is_node_purchased(loaded, "atlas_m0"):
		_fail("Schema-5 migration must preserve frozen Guild purchases.")
		return
	if Meta.is_node_purchased(loaded, "berserk_m0") or Meta.class_sigils_spent(loaded, "berserk") != 0:
		_fail("Schema-5 class allocations must be fully respecced.")
		return
	if Meta.class_sigils_earned(loaded, "berserk") != 20 or Meta.legacy_mastery_for_class(loaded, "berserk") != 2:
		_fail("Schema-5 22 earned sigils must migrate to 20 spendable +2 legacy mastery.")
		return
	if loaded.has("active_keystones"):
		_fail("Migration must remove schema-5 active_keystones.")
		return
	if not Meta.hidden_star_unlocked(loaded, "berserk_h0") or not Meta.hidden_star_unlocked(loaded, "berserk_h1"):
		_fail("Migration must reconstruct hidden reveal facts without auto-purchase.")
		return
	if Meta.is_node_purchased(loaded, "berserk_h0") or Meta.is_node_purchased(loaded, "berserk_h1"):
		_fail("Revealed hidden nodes must still require purchase after migration.")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- Данные ---

func _test_tree_data_integrity() -> void:
	# 17 созвездий × 22 узла + Атлас 25 (хаб + 14 minor + 4 notable + 4 keystone
	# + 2 скрытых) = 399; id уникальны; adj симметричны; описания RU без
	# внутренних токенов; позиции заданы и в мире (pos), и нормированно (npos).
	if Meta.SKILL_TREE.size() != 17 * 22 + 25:
		_fail("Expected 17*22+25=399 nodes, got %d." % Meta.SKILL_TREE.size())
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


func _test_semantic_keystone_behavioral_gate_contract() -> void:
	# SCRUM-837: the data smoke must not be the only guard for Meta 4.1 keystones.
	# This contract keeps the dedicated mini-arena behavioral smoke registered and
	# makes generic four-key flattening visible even before QA runs the heavy gate.
	if not ResourceLoader.exists("res://tests/meta_keystone_behavioral_smoke_test.gd"):
		_fail("SCRUM-837 behavioral keystone smoke is missing.")
		return
	var semantic_keys := [
		"enemy_hit_damage_down",
		"gold_damage_per_50",
		"elemental_resonance_bonus",
		"reactor_heat_damage_bonus",
		"device_attack_speed_bonus",
		"dot_death_spread_duration",
		"shadow_burst_invisibility_time",
		"charged_shot_extra_pierce",
		"drain_extra_targets",
		"cloud_detonation_radius_mult",
		"pet_damage_mult",
		"bastion_defense_bonus",
	]
	for key in semantic_keys:
		if not PlayerScript.META_SKILL_FLAT_MAP.has(str(key)):
			_fail("Semantic keystone key '%s' is not wired in player.gd; SCRUM-835/837 cannot be accepted." % str(key))
			return
	var required_by_class := {
		"soldier": ["enemy_hit_damage_down"],
		"thief": ["gold_damage_per_50"],
		"elementalist": ["elemental_resonance_bonus"],
		"robot": ["reactor_heat_damage_bonus"],
		"engineer": ["device_attack_speed_bonus"],
		"dark_mage": ["dot_death_spread_duration"],
		"assassin": ["shadow_burst_invisibility_time"],
		"ranger": ["charged_shot_extra_pierce"],
		"doctor": ["drain_extra_targets"],
		"chemist": ["cloud_detonation_radius_mult"],
		"druid": ["pet_damage_mult"],
		"knight": ["bastion_defense_bonus"],
	}
	for class_id in required_by_class.keys():
		var key_union := {}
		for suffix in ["k0", "k1"]:
			var node := Meta.node_by_id("%s_%s" % [str(class_id), suffix])
			if node.is_empty():
				_fail("Missing semantic keystone node '%s_%s'." % [str(class_id), suffix])
				return
			for key in (node.get("effects", {}) as Dictionary).keys():
				key_union[str(key)] = true
		for required_key in required_by_class[class_id]:
			if not key_union.has(str(required_key)):
				_fail("Class '%s' k0/k1 lack semantic key '%s'; still flattened to generic conditional effects." % [str(class_id), str(required_key)])
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
	# Атлас: хаб открыт. SCRUM-828 «ранний крючок» §4 — первый QoL-узел
	# (atlas_m0, cost 1) доступен СРАЗУ после первой победы (1 пыль).
	if Meta.node_status(state, "atlas_hub") != "purchased":
		_fail("Atlas hub must be open from the start.")
		return
	if Meta.node_status(state, "atlas_m0") != "available":
		_fail("Atlas early-hook node (cost 1) must unlock after the first win (1 stardust).")
		return
	# Узлы за 2 пыли (atlas_m2) ещё заперты с одной пылью.
	if Meta.node_status(state, "atlas_m2") != "locked":
		_fail("Atlas cost-2 node must stay locked with only 1 stardust.")
		return
	state = Meta.record_boss_victory(state, "soldier", 0)  # +1 пыль (вторая первая победа)
	if Meta.node_status(state, "atlas_m2") != "available":
		_fail("Atlas cost-2 node must unlock with 2 stardust.")
		return
	var dust_before := Meta.stardust_available(state)
	var berserk_sigils_before := Meta.class_sigils_available(state, "berserk")
	state = Meta.allocate_node(state, "atlas_m0")
	if not Meta.is_node_purchased(state, "atlas_m0") or Meta.stardust_available(state) != dust_before - 1:
		_fail("Atlas early-hook purchase (cost 1) must spend 1 stardust.")
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
	# SCRUM-1069: schema-5 Guild purchases keep their canonical IDs and receive
	# the tuned value in place; no migration/respec is allowed.
	(state["skill_nodes"] as Array).append("atlas_m0")
	Meta.save_state(state, path)
	var loaded: Dictionary = Meta.load_state(path)
	if Meta.global_level(loaded) != 6:
		_fail("Expected 6 purchased nodes including preserved Guild node after reload, got %d." % Meta.global_level(loaded))
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
	if not Meta.is_node_purchased(loaded, "atlas_m0") \
			or not is_equal_approx(float(Meta.skill_modifiers(loaded).get("money_gain_mult", 0.0)), 0.05):
		_fail("Schema-5 Guild purchase must survive and resolve to tuned +5%% gold.")
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
	# SCRUM-1069: усиленный Atlas остаётся support/economy-слоем. Full Atlas is
	# a stricter upper bound than any legal 50-dust build.
	var state: Dictionary = Meta.default_state()
	var all_atlas := []
	for node in Meta.atlas_nodes():
		if int((node as Dictionary).get("cost", 0)) > 0:
			all_atlas.append(str((node as Dictionary)["id"]))
	state["skill_nodes"] = all_atlas
	if Meta.estimated_power_multiplier(state) >= Meta.GUILD_ATLAS_ACCOUNT_POWER_CAP:
		_fail("Full Atlas account power must stay < %.2f." % Meta.GUILD_ATLAS_ACCOUNT_POWER_CAP)
		return
	# Взвешенный вклад Атласа в class-power ≤18% (дельта от базлайна с одним
	# ядром класса), using source-aware Guild weights.
	var baseline := Meta.estimated_class_power_multiplier(Meta.default_state(), "berserk")
	if Meta.estimated_class_power_multiplier(state, "berserk") - baseline > Meta.GUILD_ATLAS_CLASS_POWER_DELTA_CAP + 0.0001:
		_fail("Full Atlas must add <= %.0f%% weighted class power over baseline." % (Meta.GUILD_ATLAS_CLASS_POWER_DELTA_CAP * 100.0))
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
	var build := ["atlas_m0", "atlas_m8", "atlas_k2"]
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
	# SCRUM-1069: Атлас-keystone «Боевой раж» полностью заряжает ульту.
	var ult_charge := float(player.get("ultimate_charge"))
	var ult_max := float(player.get("ultimate_max_charge"))
	if ult_charge < ult_max * 0.99:
		_fail("Expected ult_start_charge keystone to pre-charge the ultimate (%.1f/%.1f)." % [ult_charge, ult_max])
		return
	# Doctor hidden «Горный госпиталь» still grants 50%; Guild k2 must win the
	# max-merge and remain a real 100% upgrade instead of a duplicate no-op.
	var doctor_state := Meta.default_state()
	doctor_state["skill_nodes"] = ["atlas_k2"]
	doctor_state["class_challenge_progress"] = {"doctor": {"no_shop_wins": 2}}
	var doctor_mods := Meta.skill_modifiers_for_class(doctor_state, "doctor")
	if not is_equal_approx(float(doctor_mods.get("ult_start_charge", 0.0)), 1.0):
		_fail("Guild k2 must override Doctor hidden 50%% charge with exact 100%%.")
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


func _test_guild_runtime_outcomes_1069() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	var base_pickup := float(player.get("pickup_radius"))
	var state := Meta.default_state()
	state["skill_nodes"] = ["atlas_m0", "atlas_m8", "atlas_m11", "atlas_m13"]
	player.call("apply_meta_skill_modifiers", Meta.skill_modifiers(state))
	player.set("money", 0)
	player.set("xp", 0)
	player.set("xp_to_next", 9999)
	player.call("gain_money", 20)
	player.call("gain_xp", 20)
	if int(player.get("money")) != 21 or int(player.get("xp")) != 21:
		_fail("Guild 5%% minor must change a 20-unit pickup after rounding (money=%d xp=%d)." % [player.get("money"), player.get("xp")])
		return
	if absf(float(player.get("pickup_radius")) - (base_pickup + 30.0)) > 0.1:
		_fail("Guild pickup minor must add exact +30 at runtime.")
		return
	var max_hp := float(player.get("max_health"))
	player.set("health", max_hp * 0.50)
	player.call("heal_percent", 0.10)
	if absf(float(player.get("health")) - max_hp * 0.608) > 0.15:
		_fail("Guild healing minor must turn 10%% max-HP heal into exact 10.8%%.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame


# SCRUM-834 (Мета 4.1): каждый из 4 типов условных keystone поднимает урон ЛИШЬ
# при выполнении условия; гейты ставит player (HP-порог, стойка, окно-после-
# уклонения, счёт-в-радиусе). Минимум 1 поведенческий сценарий на тип условия.
func _make_conditional_player(holder: Node2D, mods: Dictionary, class_id: String = "berserk", weapon_id: String = "sword", manual_fixture := false) -> Node:
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character(class_id, weapon_id)
	if manual_fixture:
		_quiesce_manual_combat_fixture(player)
	await process_frame
	player.call("apply_meta_skill_modifiers", mods)
	if manual_fixture:
		_quiesce_manual_combat_fixture(player)
	await process_frame
	return player


func _mods_for_active_keystone(class_id: String, node_id: String) -> Dictionary:
	var node := Meta.node_by_id(node_id)
	if node.is_empty():
		_fail("Real-node smoke expected existing keystone '%s'." % node_id)
		return {}
	if str(node.get("role", "")) != "keystone" or str(node.get("class_affinity", "")) != class_id:
		_fail("Real-node smoke expected '%s' to be a '%s' keystone." % [node_id, class_id])
		return {}
	var inactive_state: Dictionary = Meta.default_state()
	inactive_state["skill_nodes"] = [node_id]
	var inactive_mods := Meta.skill_modifiers_for_class(inactive_state, class_id)
	for key in (node.get("effects", {}) as Dictionary).keys():
		if inactive_mods.has(str(key)):
			_fail("Keystone '%s' effect '%s' must sleep until the node is active." % [node_id, str(key)])
			return {}
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = [node_id]
	state = Meta.set_active_keystone(state, class_id, node_id)
	if Meta.active_keystone(state, class_id) != node_id:
		_fail("Real-node smoke could not activate keystone '%s' for '%s'." % [node_id, class_id])
		return {}
	return Meta.skill_modifiers_for_class(state, class_id)


func _dmg(player: Node) -> float:
	return float((player.get("derived_parameters") as Dictionary).get("damage", 0.0))


# SCRUM-834a: не-урон стат-цели условных keystone (скорострельность/крит-шанс).
func _atk_speed(player: Node) -> float:
	return float((player.get("derived_parameters") as Dictionary).get("attack_speed", 0.0))


func _crit(player: Node) -> float:
	return float((player.get("derived_parameters") as Dictionary).get("crit_chance", 0.0))


func _test_conditional_keystones() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	# 1) HP-порог «пока ранен» (HP < 50%).
	var ph := await _make_conditional_player(holder, {"hurt_damage_bonus": 0.3})
	var base_h := _dmg(ph)
	ph.set("health", float(ph.get("max_health")) * 0.4)
	ph.call("_update_conditional_keystones", 0.1)
	if _dmg(ph) <= base_h:
		_fail("Условный keystone «пока ранен» должен поднимать урон при HP<50%.")
		return
	ph.set("health", float(ph.get("max_health")))
	ph.call("_update_conditional_keystones", 0.1)
	if absf(_dmg(ph) - base_h) > 0.01:
		_fail("Бонус «пока ранен» обязан исчезать при HP≥50%.")
		return
	ph.queue_free()

	# 2) Стойка: неподвижность ≥ порога.
	var ps := await _make_conditional_player(holder, {"stance_damage_bonus": 0.2})
	var base_s := _dmg(ps)
	ps.set("velocity", Vector2.ZERO)
	ps.call("_update_conditional_keystones", 1.0)  # > STANCE_ACTIVATION_TIME
	if _dmg(ps) <= base_s:
		_fail("Условный keystone «в стойке» должен поднимать урон при неподвижности.")
		return
	ps.set("velocity", Vector2(320.0, 0.0))
	ps.call("_update_conditional_keystones", 0.1)
	if absf(_dmg(ps) - base_s) > 0.01:
		_fail("Бонус «в стойке» обязан исчезать в движении.")
		return
	ps.queue_free()

	# 3) Окно после уклонения: «в рывке».
	var pr := await _make_conditional_player(holder, {"rush_damage_bonus": 0.34})
	var base_r := _dmg(pr)
	pr.call("_trigger_rush_window")
	if _dmg(pr) <= base_r:
		_fail("Условный keystone «в рывке» должен поднимать урон после уклонения.")
		return
	pr.queue_free()

	# 4) Счёт-в-радиусе: «в гуще боя».
	var pw := await _make_conditional_player(holder, {"swarm_damage_bonus": 0.18})
	var base_w := _dmg(pw)
	for _i in range(int(PlayerScript.SWARM_CAP)):
		var foe := Node2D.new()
		holder.add_child(foe)
		foe.global_position = pw.get("global_position")
		foe.add_to_group("enemies")
	pw.call("_update_conditional_keystones", PlayerScript.SWARM_SCAN_INTERVAL + 0.1)
	if _dmg(pw) <= base_w:
		_fail("Условный keystone «в гуще боя» должен поднимать урон при врагах рядом.")
		return
	pw.queue_free()

	# 5) SCRUM-834a: real PM node soldier_k1 «Шквал» → active meta keystone →
	# player/progression runtime. Не-урон стат-цель: на том же гейте
	# stance_active меняется attack_speed, а не synthetic dictionary.
	var soldier_mods := _mods_for_active_keystone("soldier", "soldier_k1")
	if float(soldier_mods.get("stance_attack_speed_bonus", 0.0)) < 0.18:
		_fail("soldier_k1 must provide stance_attack_speed_bonus through Meta.skill_modifiers_for_class.")
		return
	var pas := await _make_conditional_player(holder, soldier_mods, "soldier", "soldier_rifle")
	var base_as := _atk_speed(pas)
	pas.set("velocity", Vector2.ZERO)
	pas.call("_update_conditional_keystones", 1.0)  # > STANCE_ACTIVATION_TIME
	if _atk_speed(pas) <= base_as:
		_fail("Условный keystone «Шквал» (стойка→скорострельность) должен поднимать attack_speed в стойке.")
		return
	pas.set("velocity", Vector2(320.0, 0.0))
	pas.call("_update_conditional_keystones", 0.1)
	if absf(_atk_speed(pas) - base_as) > 0.01:
		_fail("Бонус скорострельности «Шквал» обязан исчезать в движении.")
		return
	pas.queue_free()

	# 6) SCRUM-834a: real PM node thief_k0 «Из тени» → active meta keystone →
	# player/progression runtime. Не-урон стат-цель на существующем окне
	# rush_window_active, без synthetic modifier dictionary.
	var thief_mods := _mods_for_active_keystone("thief", "thief_k0")
	if float(thief_mods.get("rush_crit_bonus", 0.0)) < 0.16:
		_fail("thief_k0 must provide rush_crit_bonus through Meta.skill_modifiers_for_class.")
		return
	var prc := await _make_conditional_player(holder, thief_mods, "thief", "thief_smoke_bomb")
	var base_crit := _crit(prc)
	prc.call("_trigger_rush_window")
	if _crit(prc) <= base_crit:
		_fail("Условный keystone «Из тени» (рывок→крит) должен поднимать crit_chance после уклонения.")
		return
	prc.queue_free()

	current_scene = null
	holder.queue_free()
	await process_frame


func _test_semantic_combat_keystones_835() -> void:
	_test_semantic_keystone_data_835()
	await _test_semantic_keystone_runtime_835()


func _test_semantic_keystone_data_835() -> void:
	var expected := {
		"soldier_k0": {"title": "Подавление", "effects": {"enemy_hit_damage_down": 0.15, "move_speed_mult": -0.10}},
		"thief_k1": {"title": "Джекпот", "effects": {"gold_damage_per_50": 0.01, "gold_damage_bonus_cap": 0.25, "shop_price_mult": 0.20}},
		"elementalist_k0": {"title": "Резонанс", "effects": {"elemental_resonance_bonus": 0.35, "damage_mult": -0.12}},
		"elementalist_k1": {"title": "Монолит", "effects": {"elemental_orb_extra_count": 2.0, "prism_rift_radius_mult": -0.20}},
		"priest_k0": {"title": "Мученик", "effects": {"heal_to_holy_damage_ratio": 0.50, "healing_mult": -0.30}},
		"priest_k1": {"title": "Заступник", "effects": {"ward_absorb_bonus": 0.40, "ult_charge_mult": -0.17}},
		"robot_k0": {"title": "Перегрев", "effects": {"reactor_heat_damage_bonus": 0.30, "reactor_heat_incoming_damage": 0.15}},
		"robot_k1": {"title": "Сверхпроводник", "effects": {"magnet_radius_mult": 0.50, "max_health_mult": -0.12}},
		"engineer_k0": {"title": "Автоматизация", "effects": {"device_attack_speed_bonus": 0.25, "non_device_damage_mult": -0.15}},
		"engineer_k1": {"title": "Минёр", "effects": {"mine_extra_count": 2.0, "device_attack_speed_bonus": -0.12}},
		"dark_mage_k0": {"title": "Пожинатель", "effects": {"dot_death_spread_duration": 2.0, "direct_damage_mult": -0.15}},
		"dark_mage_k1": {"title": "Ненасытный луч", "effects": {"beam_duration_mult": 0.30, "explosion_radius_mult": -0.20}},
		"guitarist_k0": {"title": "Хедлайнер", "effects": {"guitar_aura_radius_mult": 0.30, "knockback_mult": -0.50}},
		"guitarist_k1": {"title": "Рифф", "effects": {"riff_streak_damage_bonus": 0.25, "attack_speed_mult": -0.10}},
		"assassin_k0": {"title": "Экзекутор", "effects": {"crit_execute_threshold": 0.35, "crit_chance_flat": -0.10}},
		"assassin_k1": {"title": "Теневой шаг", "effects": {"shadow_burst_invisibility_time": 2.0, "max_health_mult": -0.15}},
		"ranger_k0": {"title": "Штурмовая стойка", "effects": {"charged_shot_extra_pierce": 2.0, "charge_time_mult": 0.20}},
		"ranger_k1": {"title": "Капканщик", "effects": {"trap_extra_count": 2.0, "non_trap_damage_mult": -0.12}},
		"doctor_k0": {"title": "Вампирический контур", "effects": {"drain_extra_targets": 1.0, "medkit_healing_mult": -0.40}},
		"doctor_k1": {"title": "Хирург", "effects": {"surgical_close_damage_bonus": 0.60, "ranged_damage_mult": -0.20}},
		"chemist_k0": {"title": "Катализатор", "effects": {"cloud_detonation_radius_mult": 0.40, "pool_duration_mult": -0.30}},
		"chemist_k1": {"title": "Гомункул-прайм", "effects": {"homunculus_power_mult": 0.50, "max_health_mult": -0.10}},
		"knight_k0": {"title": "Бастион", "effects": {"bastion_defense_bonus": 0.25, "bastion_taunt": 1.0, "move_speed_mult": -0.15}},
		"druid_k0": {"title": "Вожак стаи", "effects": {"pet_damage_mult": 0.25, "pet_personal_damage_mult": -0.15}},
		"druid_k1": {"title": "Терновый круг", "effects": {"briar_radius_mult": 0.35, "move_speed_mult": -0.10}},
	}
	var generic_placeholders := ["hurt_damage_bonus", "stance_damage_bonus", "rush_damage_bonus", "swarm_damage_bonus"]
	for node_id in expected.keys():
		var node := Meta.node_by_id(str(node_id))
		if node.is_empty():
			_fail("SCRUM-835 expected keystone '%s' is missing." % str(node_id))
			return
		var expected_node: Dictionary = expected[node_id]
		if str(node.get("title", "")) != str(expected_node.get("title", "")):
			_fail("SCRUM-835 keystone '%s' title mismatch: %s." % [str(node_id), str(node.get("title", ""))])
			return
		var effects: Dictionary = node.get("effects", {})
		for key in (expected_node.get("effects", {}) as Dictionary).keys():
			if not effects.has(key) or not is_equal_approx(float(effects[key]), float((expected_node["effects"] as Dictionary)[key])):
				_fail("SCRUM-835 keystone '%s' missing/changed effect '%s'." % [str(node_id), str(key)])
				return
		for generic_key in generic_placeholders:
			if effects.has(generic_key):
				_fail("SCRUM-835 keystone '%s' must use semantic subsystem keys, not generic '%s'." % [str(node_id), str(generic_key)])
				return


func _spawn_test_enemy(holder: Node2D, position: Vector2, max_hp := 100.0, manual_fixture := false) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	holder.add_child(enemy)
	enemy.global_position = position
	enemy.add_to_group("enemies")
	if manual_fixture:
		_quiesce_manual_combat_fixture(enemy)
	await process_frame
	enemy.set("max_health", max_hp)
	enemy.set("health", max_hp)
	return enemy


func _quiesce_manual_combat_fixture(actor: Node) -> void:
	# SCRUM-1028: semantic mini-arenas ниже вызывают runtime API напрямую. Пока
	# coroutine ждёт process_frame, живое оружие/AI не должно успеть выбрать цель,
	# потратить cooldown, убить fixture или сдвинуть его. Отключаем только
	# callbacks (и у уже созданных детей), сохраняя CharacterBody2D в physics
	# space для явных call("_physics_process")/move_and_slide() oracle ниже.
	actor.set_process(false)
	actor.set_physics_process(false)
	for child in actor.get_children():
		_quiesce_manual_combat_fixture(child)


func _test_semantic_keystone_runtime_835() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var gold_player := await _make_conditional_player(holder, {"gold_damage_per_50": 0.01, "gold_damage_bonus_cap": 0.25})
	gold_player.set("money", 49)
	if not is_equal_approx(float(gold_player.call("meta_damage_multiplier", {}, null)), 1.0):
		_fail("SCRUM-835 Джекпот must floor gold bonus to full 50-gold steps.")
		return
	gold_player.set("money", 2500)
	if absf(float(gold_player.call("meta_damage_multiplier", {}, null)) - 1.25) > 0.001:
		_fail("SCRUM-835 Джекпот must cap gold damage bonus at +25%.")
		return
	gold_player.queue_free()

	var soldier := await _make_conditional_player(holder, {"enemy_hit_damage_down": 0.15})
	var suppressed := await _spawn_test_enemy(holder, soldier.global_position + Vector2(32.0, 0.0))
	soldier.call("_apply_meta_keystone_hit_effects", suppressed, 5.0, {})
	if StatusEffects.damage_multiplier(suppressed) > 0.86:
		_fail("SCRUM-835 Подавление must reduce outgoing damage of recently hit enemies.")
		return
	StatusEffects.tick(suppressed, 2.10)
	if StatusEffects.damage_multiplier(suppressed) < 0.99:
		_fail("SCRUM-835 Подавление must expire after its 2s window.")
		return
	soldier.queue_free()
	suppressed.queue_free()

	var elementalist := await _make_conditional_player(holder, {"elemental_resonance_bonus": 0.35})
	var resonant := await _spawn_test_enemy(holder, elementalist.global_position + Vector2(48.0, 0.0))
	resonant.set_meta("meta_elemental_mark_element", "fire")
	resonant.set_meta("meta_elemental_mark_owner", elementalist.get_instance_id())
	var same_element := float(elementalist.call("meta_damage_multiplier", {"element": "fire"}, resonant))
	var other_element := float(elementalist.call("meta_damage_multiplier", {"element": "storm"}, resonant))
	if other_element <= same_element * 1.34:
		_fail("SCRUM-835 Резонанс must boost a different element against marked targets.")
		return
	elementalist.queue_free()
	resonant.queue_free()

	var robot := await _make_conditional_player(holder, {"reactor_heat_damage_bonus": 0.30, "reactor_heat_incoming_damage": 0.15})
	var cold := float(robot.call("meta_damage_multiplier", {"attack_mode": "robot_reactor_core"}, null))
	for _i in range(5):
		robot.call("_apply_meta_keystone_hit_effects", null, 10.0, {"attack_mode": "robot_reactor_core"})
	robot.call("_update_meta_keystone_runtime", 0.0)
	var hot := float(robot.call("meta_damage_multiplier", {"attack_mode": "robot_reactor_core"}, null))
	if hot <= cold * 1.29:
		_fail("SCRUM-835 Перегрев must grant damage after reactor heat exceeds 70%.")
		return
	robot.queue_free()

	var assassin := await _make_conditional_player(holder, {"crit_execute_threshold": 0.35})
	var victim := await _spawn_test_enemy(holder, assassin.global_position + Vector2(40.0, 0.0), 100.0)
	victim.set("health", 34.0)
	assassin.call("_apply_meta_keystone_hit_effects", victim, 10.0, {"critical": true, "damage_type": "physical"})
	if float(victim.get("health")) > 0.0:
		_fail("SCRUM-835 Экзекутор must execute non-elite targets under 35% HP on crit.")
		return
	var elite := await _spawn_test_enemy(holder, assassin.global_position + Vector2(60.0, 0.0), 100.0)
	elite.add_to_group("elite_enemies")
	elite.set("health", 34.0)
	assassin.call("_apply_meta_keystone_hit_effects", elite, 10.0, {"critical": true, "damage_type": "physical"})
	if float(elite.get("health")) <= 0.0:
		_fail("SCRUM-835 Экзекутор must not execute elite targets.")
		return
	assassin.queue_free()
	victim.queue_free()
	elite.queue_free()

	var helper := await _make_conditional_player(holder, {
		"elemental_orb_extra_count": 2.0,
		"mine_extra_count": 2.0,
		"trap_extra_count": 2.0,
		"drain_extra_targets": 1.0,
		"charged_shot_extra_pierce": 2.0,
		"magnet_radius_mult": 0.50,
		"prism_rift_radius_mult": -0.20,
		"cloud_detonation_radius_mult": 0.40,
		"briar_radius_mult": 0.35,
		"beam_duration_mult": 0.30,
		"pool_duration_mult": -0.30,
		"device_attack_speed_bonus": 0.25,
		"charge_time_mult": 0.20,
	})
	if int(helper.call("meta_extra_projectiles", {"attack_mode": "elemental_orbit"})) != 2:
		_fail("SCRUM-835 Монолит must add two elemental orbit orbs.")
		return
	if int(helper.call("meta_extra_projectiles", {"attack_mode": "engineer_pressure_mines"})) != 2:
		_fail("SCRUM-835 Минёр must add two pressure mines.")
		return
	if int(helper.call("meta_extra_projectiles", {"attack_mode": "trap"})) != 2 or not bool(helper.call("meta_trap_instant_arm", {"attack_mode": "trap"})):
		_fail("SCRUM-835 Капканщик must add two traps and arm them instantly.")
		return
	if int(helper.call("meta_extra_projectiles", {"attack_mode": "drain_link"})) != 1:
		_fail("SCRUM-835 Вампирический контур must add one drain-link target.")
		return
	if int(helper.call("meta_extra_pierce", {"is_charged": true})) != 2:
		_fail("SCRUM-835 Штурмовая стойка must add charged-shot pierce.")
		return
	if float(helper.call("meta_radius_multiplier", {"attack_mode": "robot_magnetic_anchor"})) < 1.49:
		_fail("SCRUM-835 Сверхпроводник must expand magnet radius.")
		return
	if float(helper.call("meta_radius_multiplier", {"attack_mode": "prism_rift"})) > 0.81:
		_fail("SCRUM-835 Монолит must shrink prism/rift zones.")
		return
	if float(helper.call("meta_radius_multiplier", {"is_cloud": true})) < 1.39:
		_fail("SCRUM-835 Катализатор must expand cloud detonation radius.")
		return
	if float(helper.call("meta_radius_multiplier", {"is_briar": true})) < 1.34:
		_fail("SCRUM-835 Терновый круг must expand briar zones.")
		return
	if float(helper.call("meta_duration_multiplier", {"attack_mode": "beam"})) < 1.29:
		_fail("SCRUM-835 Ненасытный луч must extend beam duration.")
		return
	if float(helper.call("meta_duration_multiplier", {"is_cloud": true})) > 0.71:
		_fail("SCRUM-835 Катализатор downside must shorten pool/cloud duration.")
		return
	if float(helper.call("meta_interval_multiplier", {"is_device": true})) >= 0.81:
		_fail("SCRUM-835 Автоматизация must make devices shoot faster.")
		return
	if float(helper.call("meta_charge_time_multiplier", {"is_charged": true})) < 1.19:
		_fail("SCRUM-835 Штурмовая стойка downside must slow charge time.")
		return
	helper.queue_free()

	var priest := await _make_conditional_player(holder, {"heal_to_holy_damage_ratio": 0.50}, "priest", "priest_reliquary")
	var holy_target := await _spawn_test_enemy(holder, priest.global_position + Vector2(96.0, 0.0), 100.0)
	priest.set("health", float(priest.get("max_health")) * 0.50)
	var holy_before := float(holy_target.get("health"))
	priest.call("heal_percent", 0.20)
	if float(holy_target.get("health")) >= holy_before:
		_fail("SCRUM-835 Мученик must convert real healing into holy chain damage.")
		return
	priest.queue_free()
	holy_target.queue_free()

	var warded := await _make_conditional_player(holder, {"ward_absorb_bonus": 0.40})
	var absorb_before := float((warded.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0))
	warded.call("meta_apply_priest_ward", 0.25)
	var absorb_after := float((warded.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0))
	if absorb_after <= absorb_before:
		_fail("SCRUM-835 Заступник must add ward absorb.")
		return
	warded.queue_free()

	var reaper := await _make_conditional_player(holder, {"dot_death_spread_duration": 2.0}, "dark_mage", "cursed_skull")
	var dot_source := await _spawn_test_enemy(holder, reaper.global_position + Vector2(64.0, 0.0), 100.0)
	var dot_neighbor := await _spawn_test_enemy(holder, dot_source.global_position + Vector2(42.0, 0.0), 100.0)
	StatusEffects.apply_status(dot_source, "semantic_test_dot", {
		"duration": 1.0,
		"dot_damage": 2.0,
		"dot_interval": 0.5,
	})
	reaper.call("on_enemy_killed", dot_source)
	if not StatusEffects.has_status(dot_neighbor, "semantic_test_dot"):
		_fail("SCRUM-835 Пожинатель must spread real DoT statuses on enemy death.")
		return
	var spread_snapshot := StatusEffects.snapshot(dot_neighbor)
	if float((spread_snapshot.get("semantic_test_dot", {}) as Dictionary).get("remaining", 0.0)) < 1.9:
		_fail("SCRUM-835 Пожинатель must extend spread DoT to the configured duration.")
		return
	reaper.queue_free()
	dot_source.queue_free()
	dot_neighbor.queue_free()

	var shadow := await _make_conditional_player(holder, {"shadow_burst_invisibility_time": 2.0}, "assassin", "shadow_daggers", true)
	var shadow_params := shadow.get("derived_parameters") as Dictionary
	shadow_params["dodge"] = 0.0
	shadow_params["raw_dodge"] = 0.0
	if not _assert_raw_pair(shadow_params, "dodge", "raw_dodge"):
		return
	var shadow_target := await _spawn_test_enemy(holder, shadow.global_position + Vector2(160.0, 0.0), 100.0, true)
	shadow.set("health", shadow.get("max_health"))
	if float(shadow.get("_assassin_crit_shadow_cooldown_left")) > 0.0:
		_fail("SCRUM-1028 shadow mini-arena must begin before any automatic weapon consumes the cooldown.")
		return
	shadow.call("trigger_assassin_crit_shadow", shadow_target, 80.0)
	if float(shadow.get("_shadow_invisible_left")) < 1.99:
		_fail("SCRUM-835 Теневой шаг must open its configured two-second invisibility window immediately.")
		return
	var shadow_before := float(shadow.get("health"))
	if bool(shadow.call("take_damage", 10.0, "semantic_835_shadow_invisible")) or float(shadow.get("health")) < shadow_before:
		_fail("SCRUM-835 Теневой шаг must make the assassin ignore damage during shadow invisibility.")
		return
	shadow.queue_free()
	shadow_target.queue_free()

	var plain_chemist := await _make_conditional_player(holder, {}, "chemist", "homunculus_vial")
	var prime_chemist := await _make_conditional_player(holder, {"homunculus_power_mult": 0.50}, "chemist", "homunculus_vial")
	var plain_homunculus_weapon := plain_chemist.get("equipped_weapon") as Node
	var prime_homunculus_weapon := prime_chemist.get("equipped_weapon") as Node
	var plain_homunculus_profile: Dictionary = plain_homunculus_weapon.call("_summon_profile", plain_chemist)
	var prime_homunculus_profile: Dictionary = prime_homunculus_weapon.call("_summon_profile", prime_chemist)
	if float(prime_homunculus_profile.get("damage", 0.0)) <= float(plain_homunculus_profile.get("damage", 0.0)) * 1.49 \
			or float(prime_homunculus_profile.get("max_health", 0.0)) <= float(plain_homunculus_profile.get("max_health", 0.0)) * 1.49:
		_fail("SCRUM-835 Гомункул-прайм must boost real homunculus summon damage and health profiles.")
		return
	plain_chemist.queue_free()
	prime_chemist.queue_free()

	var plain_druid := await _make_conditional_player(holder, {}, "druid", "summon_amulet")
	var pack_druid := await _make_conditional_player(holder, {"pet_damage_mult": 0.25}, "druid", "summon_amulet")
	var plain_pet_weapon := plain_druid.get("equipped_weapon") as Node
	var pack_pet_weapon := pack_druid.get("equipped_weapon") as Node
	var plain_pet_profile: Dictionary = plain_pet_weapon.call("_summon_profile", plain_druid)
	var pack_pet_profile: Dictionary = pack_pet_weapon.call("_summon_profile", pack_druid)
	if float(pack_pet_profile.get("damage", 0.0)) <= float(plain_pet_profile.get("damage", 0.0)) * 1.24:
		_fail("SCRUM-835 Вожак стаи must boost real pet summon damage profiles.")
		return
	plain_druid.queue_free()
	pack_druid.queue_free()

	await process_frame
	var plain := await _make_conditional_player(holder, {}, "berserk", "sword", true)
	var bastion := await _make_conditional_player(holder, {"bastion_defense_bonus": 0.25, "bastion_taunt": 1.0}, "berserk", "sword", true)
	var plain_params := plain.get("derived_parameters") as Dictionary
	plain_params["dodge"] = 0.0
	plain_params["raw_dodge"] = 0.0
	if not _assert_raw_pair(plain_params, "dodge", "raw_dodge"):
		return
	plain.set("health", plain.get("max_health"))
	bastion.set("health", bastion.get("max_health"))
	bastion.set("velocity", Vector2.ZERO)
	bastion.call("_update_conditional_keystones", 1.0)
	if not bool(bastion.get("_stance_active")):
		_fail("SCRUM-1028 Bastion mini-arena must deterministically enter stance before damage comparison.")
		return
	# Stance activation recalculates and replaces derived_parameters; remove the
	# intentional runtime dodge only after that recalculation.
	var bastion_params := bastion.get("derived_parameters") as Dictionary
	bastion_params["dodge"] = 0.0
	bastion_params["raw_dodge"] = 0.0
	if not _assert_raw_pair(bastion_params, "dodge", "raw_dodge"):
		return
	if float(plain.call("_current_dodge_chance")) > 0.0 or float(bastion.call("_current_dodge_chance")) > 0.0:
		_fail("SCRUM-1028 Bastion defense comparison must neutralize random dodge on both fixtures.")
		return
	var plain_before := float(plain.get("health"))
	var bastion_before := float(bastion.get("health"))
	plain.call("take_damage", 10.0, "semantic_835_plain")
	bastion.call("take_damage", 10.0, "semantic_835_bastion")
	if bastion_before - float(bastion.get("health")) >= plain_before - float(plain.get("health")):
		_fail("SCRUM-835 Бастион must reduce incoming damage while stance is active.")
		return
	plain.global_position = Vector2(40.0, 0.0)
	bastion.global_position = Vector2(240.0, 0.0)
	var taunted_enemy := await _spawn_test_enemy(holder, Vector2(160.0, 0.0), 100.0, true)
	taunted_enemy.set("move_speed", 120.0)
	taunted_enemy.set("contact_range", 12.0)
	bastion.call("_update_conditional_keystones", 0.10)
	taunted_enemy.call("_physics_process", 0.05)
	if (taunted_enemy.get("velocity") as Vector2).x <= 0.0:
		_fail("SCRUM-835 Бастион taunt must make enemy AI target the taunt owner, not the default player.")
		return
	StatusEffects.tick(taunted_enemy, 0.60)
	taunted_enemy.call("_physics_process", 0.05)
	if (taunted_enemy.get("velocity") as Vector2).x >= 0.0:
		_fail("SCRUM-835 Бастион taunt must expire and let enemy AI fall back to the default player target.")
		return
	taunted_enemy.queue_free()
	plain.queue_free()
	bastion.queue_free()

	current_scene = null
	holder.queue_free()
	await process_frame


func _test_skill_tree_screen() -> void:
	# SCRUM-827: экран прокачки = «Атлас героев». Созвездие выбранного класса
	# рендерится целиком (22 узла), выбор узла + «Вложить эмблему» покупают
	# звезду, фасад очков тратится.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var state: Dictionary = main.get("meta_state")
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3]}
	state["skill_nodes"] = []
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")

	main.ui._show_atlas_screen()
	await process_frame
	if main.find_child("AtlasScreen", true, false) == null:
		_fail("Expected atlas screen to open.")
		return
	var node_buttons: Array = main.find_children("AtlasNode_*", "BaseButton", true, false)
	if node_buttons.size() != 22:
		_fail("Expected 22 constellation node buttons, got %d." % node_buttons.size())
		return
	if main.find_child("AtlasEmblemsLabel", true, false) == null:
		_fail("Expected a class sigil counter in the atlas header.")
		return

	# Купить звезду у ядра берсерка — фасад очков тратится, узел куплен.
	var star_id := "berserk_m0"
	var star_btn := main.find_child("AtlasNode_%s" % star_id, true, false) as BaseButton
	if star_btn == null:
		_fail("Expected core-adjacent star '%s' on the canvas." % star_id)
		return
	var points_before: int = Meta.skill_points(main.get("meta_state"))
	star_btn.pressed.emit()
	await process_frame
	var buy_button := main.find_child("AtlasBuyButton", true, false) as BaseButton
	if buy_button == null or not buy_button.visible or buy_button.disabled:
		_fail("Expected an enabled buy button for available star '%s'." % star_id)
		return
	buy_button.pressed.emit()
	await process_frame
	if not Meta.is_node_purchased(main.get("meta_state"), star_id):
		_fail("Expected the buy button to purchase the selected star.")
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
	# Атлас, ветвь «Лавка»: узлы скидки снижают цены ТОЙ ЖЕ корзины.
	# SCRUM-1027: shop_items() материализует rarity-family tier через глобальный
	# RNG, а _weighted_sample() использует main.rng. Оба источника обязаны иметь
	# один seed для base/discount пары; иначе тест сравнивает разные tier/cost.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_ascension_level", 0)
	main.set("route_stage", 2)
	if main.has_method("reset_run_ascension"):
		main.call("reset_run_ascension")

	var base_state: Dictionary = main.get("meta_state")
	base_state["skill_nodes"] = []
	base_state["active_keystones"] = {}
	main.set("meta_state", base_state)
	var discount_state: Dictionary = base_state.duplicate(true)
	discount_state["skill_nodes"] = ["atlas_m4", "atlas_m5", "atlas_n1"]
	var global_mods: Dictionary = Meta.skill_modifiers(discount_state)
	var class_mods: Dictionary = Meta.skill_modifiers_for_class(discount_state, "berserk")
	var global_shop_mult := float(global_mods.get("shop_price_mult", 0.0))
	var class_shop_delta := float(class_mods.get("shop_price_mult", 0.0)) - global_shop_mult
	var expected_price_mult := maxf(1.0 + global_shop_mult, 0.1) * maxf(1.0 + class_shop_delta, 0.1)
	if not is_equal_approx(global_shop_mult, -0.20) or not is_equal_approx(expected_price_mult, 0.80):
		_fail("Expected full Shop branch multiplier 0.80, got global %.3f / final %.3f." % [global_shop_mult, expected_price_mult])
		return

	for sample_seed in [17, 4242, 9001, 31337]:
		main.set("meta_state", base_state)
		(main.get("rng") as RandomNumberGenerator).seed = sample_seed
		seed(sample_seed)
		var full_items: Array = main.ui._random_shop_items(4)

		main.set("meta_state", discount_state)
		(main.get("rng") as RandomNumberGenerator).seed = sample_seed
		seed(sample_seed)
		var discounted_items: Array = main.ui._random_shop_items(4)
		if discounted_items.size() != full_items.size() or full_items.is_empty():
			_fail("Shop discount seed %d changed basket size (%d vs %d)." % [sample_seed, discounted_items.size(), full_items.size()])
			return
		for index in range(full_items.size()):
			var base_item := full_items[index] as Dictionary
			var discounted_item := discounted_items[index] as Dictionary
			var base_signature := "%s|%s|%d" % [
				str(base_item.get("id", "")),
				str(base_item.get("kind", "")),
				int(base_item.get("tier", 1)),
			]
			var discounted_signature := "%s|%s|%d" % [
				str(discounted_item.get("id", "")),
				str(discounted_item.get("kind", "")),
				int(discounted_item.get("tier", 1)),
			]
			if discounted_signature != base_signature:
				_fail("Shop discount seed %d changed item %d (%s -> %s); both RNG sources must be paired." % [
					sample_seed, index, base_signature, discounted_signature])
				return
			var base_cost := int(base_item.get("cost", 0))
			var expected_cost := maxi(1, int(round(float(base_cost) * expected_price_mult)))
			var discounted_cost := int(discounted_item.get("cost", 0))
			if discounted_cost != expected_cost or discounted_cost <= 0:
				_fail("Shop discount seed %d item %s expected %d from %d, got %d." % [
					sample_seed, base_signature, expected_cost, base_cost, discounted_cost])
				return
	# Не оставляем process-global RNG на последней SCRUM-1027
	# последовательности: следующие независимые smoke-сценарии снова работают в
	# обычном runtime-режиме. Failure paths завершают процесс через _fail().
	randomize()
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
	disc_state["skill_nodes"] = ["atlas_m6", "atlas_m7", "atlas_n1"]
	main.set("meta_state", disc_state)
	var disc_cost: int = main.ui._attribute_buy_cost()

	var expected_disc_cost := maxi(1, int(round(float(full_cost) * 0.80)))
	if disc_cost != expected_disc_cost or disc_cost <= 0:
		_fail("Expected full Guild attribute branch to price %.0f%% (%d), got %d from %d." % [80.0, expected_disc_cost, disc_cost, full_cost])
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
	# SCRUM-1069: «Вторая жизнь» восстанавливает 30% max HP один раз за забег.
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
	derived["raw_dodge"] = 0.0
	derived["defense"] = 0.0
	derived["raw_defense"] = 0.0
	if not _assert_raw_pair(derived, "dodge", "raw_dodge") or not _assert_raw_pair(derived, "defense", "raw_defense"):
		return
	derived["absorb"] = 0.0
	player.set("health", 5.0)
	player.set("_damage_invulnerability_left", 0.0)

	player.call("take_damage", 1000.0)
	await process_frame
	var expected_health := float(player.get("max_health")) * 0.30
	if not is_instance_valid(player) or absf(float(player.get("health")) - expected_health) > 0.1:
		_fail("Expected death-save to restore 30%% max HP (expected %.2f, got %.2f)." % [expected_health, float(player.get("health"))])
		return
	var rm: Dictionary = player.get("run_modifiers")
	if float(rm.get("death_save_used", 0.0)) <= 0.0:
		_fail("Expected death-save to be marked used after triggering.")
		return
	if float(player.get("_damage_invulnerability_left")) < 1.8:
		_fail("Expected death-save to preserve the 2s invulnerability window.")
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
	state["skill_nodes"] = ["atlas_m0", "atlas_m1", "atlas_m2", "atlas_m3", "atlas_n0", "atlas_k0", "berserk_m0", "berserk_m2"]
	main.set("meta_state", state)

	var player := PLAYER_SCENE.instantiate()
	main.add_child(player)
	if player.has_method("configure_character"):
		player.configure_character("berserk", "sword")
	player.set("money", 0)
	var dmg_before := float((player.get("run_modifiers") as Dictionary).get("damage_multiplier", 1.0))

	main.call("apply_ascension_bonuses", player)
	await process_frame

	if int(player.get("money")) != 100:
		_fail("Expected full Treasury branch to grant exact +100 start gold (got %d)." % int(player.get("money")))
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
