extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")

var errors := PackedStringArray()
var created_paths := PackedStringArray()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(1)
		return
	_test_topology()
	_test_schema5_migrations()
	_test_schema6_purchase_and_reset()
	_test_weapon_diversity_is_class_scoped()
	_test_native_schema6_fail_closed_normalization()
	for path in created_paths:
		DirAccess.remove_absolute(path)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 schema-6 topology/migration passed old-earned 20/22/24/28, idempotence, reveal/purchase and Guild preservation.")
	quit(0)


func _test_topology() -> void:
	_check(Meta.TREE_SCHEMA_VERSION == 6, "tree schema must be 6")
	_check(Meta.node_list().size() == 382, "runtime graph must contain 357 class + 25 Guild nodes")
	_check(Meta.atlas_nodes().size() == 25, "Guild Atlas must retain 25 nodes")
	for class_id in Meta.constellation_class_ids():
		var nodes := Meta.constellation_nodes(str(class_id))
		var branch_nodes := nodes.filter(func(node): return str(node.get("role", "")) == "weapon_boon")
		var finals := nodes.filter(func(node): return str(node.get("role", "")) == "weapon_final")
		var hidden := nodes.filter(func(node): return str(node.get("role", "")) == "hidden")
		_check(nodes.size() == 21, "%s must have 21 nodes" % class_id)
		_check(branch_nodes.size() == 15, "%s must have 15 ordinary weapon boons" % class_id)
		_check(finals.size() == 3, "%s must have three simultaneous finals" % class_id)
		_check(hidden.size() == 2, "%s must have two hidden side nodes" % class_id)
		_check(Meta.constellation_total_cost(str(class_id)) == 20, "%s must cost exactly 20" % class_id)
		for node in nodes:
			var role := str(node.get("role", ""))
			if role in ["weapon_boon", "weapon_final", "hidden"]:
				_check(int(node.get("cost", 0)) == 1, "%s/%s must cost 1" % [class_id, node.get("id")])
				_check(str((node.get("effect_profile", {}) as Dictionary).get("scope", "")) == "owning_weapon_only", "%s/%s lost weapon scope" % [class_id, node.get("id")])
	var berserk_core := Meta.node_by_id("berserk_core")
	_check((berserk_core.get("adj", []) as Array).size() == 3, "core must connect to exactly three weapon rays")
	_check((Meta.node_by_id("berserk_sword_b3").get("adj", []) as Array).has("berserk_h0"), "hidden h0 must spur from owning b3")
	_check((Meta.node_by_id("berserk_h0").get("adj", []) as Array).has("berserk_sword_b3"), "hidden h0 edge must be symmetric")


func _test_schema5_migrations() -> void:
	var cases := [
		{"name": "old20", "awards": [0, 1, 2, 3, 4], "done": ["weapon_master", "peak_climber"], "legacy": 0, "new_earned": 15},
		{"name": "old22", "awards": [0, 1, 2, 3, 4, 5], "done": [], "legacy": 2, "new_earned": 20},
		{"name": "old24", "awards": [0, 1, 2, 3, 4, 5], "done": ["weapon_master"], "legacy": 4, "new_earned": 20},
		{"name": "old28", "awards": [0, 1, 2, 3, 4, 5], "done": ["weapon_master", "peak_climber", "lone_wolf"], "legacy": 8, "new_earned": 20},
	]
	for migration_case in cases:
		var path := "user://scrum1068_%s.cfg" % migration_case["name"]
		created_paths.append(ProjectSettings.globalize_path(path))
		_write_schema5_fixture(path, migration_case["awards"], migration_case["done"])
		var state := Meta.load_state(path)
		var context := str(migration_case["name"])
		_check(int(state.get("skill_tree_schema", 0)) == 6, "%s: schema did not migrate" % context)
		_check(bool(state.get("constellation_schema6_migrated", false)), "%s: migration marker missing" % context)
		_check(int((state.get("legacy_mastery", {}) as Dictionary).get("berserk", 0)) == int(migration_case["legacy"]), "%s: legacy mastery mismatch" % context)
		_check(Meta.class_sigils_earned(state, "berserk") == int(migration_case["new_earned"]), "%s: new earned sigils mismatch" % context)
		_check((state.get("skill_nodes", []) as Array) == ["atlas_m0", "atlas_m1"], "%s: class allocations were not refunded or Guild purchases drifted" % context)
		_check(not state.has("active_keystones"), "%s: active_keystones survived schema 6" % context)
		var reveals = (state.get("hidden_reveal_facts", {}) as Dictionary).get("berserk", [])
		_check((reveals as Array).has("berserk_h0") and (reveals as Array).has("berserk_h1"), "%s: schema5 reveal facts were not reconstructed" % context)
		_check(int((state.get("class_boss_wins", {}) as Dictionary).get("berserk", 0)) == 9, "%s: class wins were not preserved" % context)
		Meta.save_state(state, path)
		var reloaded := Meta.load_state(path)
		_check(reloaded.get("legacy_mastery") == state.get("legacy_mastery"), "%s: repeated load changed legacy mastery" % context)
		_check(reloaded.get("hidden_reveal_facts") == state.get("hidden_reveal_facts"), "%s: repeated load changed reveal ledger" % context)
		_check(reloaded.get("skill_nodes") == state.get("skill_nodes"), "%s: repeated load changed purchases" % context)
		var config := ConfigFile.new()
		config.load(path)
		_check(not config.has_section_key("meta", "active_keystones"), "%s: save serialized removed active_keystones" % context)


func _test_schema6_purchase_and_reset() -> void:
	var path := "user://scrum1068_native.cfg"
	created_paths.append(ProjectSettings.globalize_path(path))
	var state := Meta.default_state()
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3, 4, 5]}
	state["class_challenge_progress"] = {"berserk": {"weapons": ["sword", "axe", "hammer"], "best_ascension": 5, "no_shop_wins": 1}}
	state["class_challenges_done"] = {"berserk": ["weapon_master", "peak_climber", "lone_wolf"]}
	state["legacy_mastery"] = {"berserk": 8}
	Meta.save_state(state, path)
	state = Meta.load_state(path)
	_check(Meta.class_sigils_earned(state, "berserk") == 20, "native schema6 class must earn exactly 20 sigils")
	_check(Meta.node_status(state, "berserk_h0") == "locked", "revealed hidden must still require owning b3")
	var class_entry := Schema6.class_entry("berserk")
	for branch in class_entry.get("weapon_branches", []):
		for node in (branch as Dictionary).get("nodes", []):
			state = Meta.allocate_node(state, str((node as Dictionary).get("node_id", "")))
	_check(Meta.node_status(state, "berserk_h0") == "available", "revealed hidden must become available after owning b3")
	state = Meta.allocate_node(state, "berserk_h0")
	state = Meta.allocate_node(state, "berserk_h1")
	_check(Meta.class_sigils_spent(state, "berserk") == 20, "full constellation must spend 20")
	_check(Meta.class_sigils_available(state, "berserk") == 0, "full constellation must leave zero sigils")
	for final_id in ["berserk_sword_final", "berserk_axe_final", "berserk_hammer_final"]:
		_check(Meta.is_node_purchased(state, final_id), "all three finals must remain purchased: %s" % final_id)
	_check(Meta.active_keystone(state, "berserk") == "", "schema6 must have no active keystone toggle")
	var purchases := (state.get("skill_nodes", []) as Array).duplicate()
	purchases.append("atlas_m0")
	state["skill_nodes"] = purchases
	var reveal_before = (state.get("hidden_reveal_facts", {}) as Dictionary).duplicate(true)
	var legacy_before = (state.get("legacy_mastery", {}) as Dictionary).duplicate(true)
	state = Meta.reset_constellation(state, "berserk")
	_check((state.get("skill_nodes", []) as Array) == ["atlas_m0"], "class reset must preserve Guild purchases only")
	_check(state.get("hidden_reveal_facts") == reveal_before, "class reset must preserve reveal ledger")
	_check(state.get("legacy_mastery") == legacy_before, "class reset must preserve legacy mastery")
	state["skill_nodes"] = ["atlas_m0", "berserk_sword_b1"]
	state = Meta.reset_constellation(state, "")
	_check((state.get("skill_nodes", []) as Array) == ["berserk_sword_b1"], "Guild reset must preserve class purchases")
	_check(state.get("hidden_reveal_facts") == reveal_before, "Guild reset must preserve reveal ledger")
	_check(state.get("legacy_mastery") == legacy_before, "Guild reset must preserve legacy mastery")


func _test_weapon_diversity_is_class_scoped() -> void:
	var state := Meta.default_state()
	for foreign_weapon in ["soldier_rifle", "dark_book", "thief_coin_pouch"]:
		state = Meta.record_boss_victory(state, "berserk", 0, {"weapon_id": foreign_weapon, "used_shop": true})
	_check((Meta.class_challenge_progress_for(state, "berserk").get("weapons", []) as Array).is_empty(), "foreign weapon IDs polluted Berserk diversity")
	_check(not Meta.hidden_star_unlocked(state, "berserk_h0"), "foreign weapon IDs revealed Berserk hidden node")
	state = Meta.record_boss_victory(state, "berserk", 0, {"weapon_id": "sword", "used_shop": true})
	state = Meta.record_boss_victory(state, "berserk", 0, {"weapon_id": "axe", "used_shop": true})
	_check((Meta.class_challenge_progress_for(state, "berserk").get("weapons", []) as Array) == ["sword", "axe"], "canonical Berserk weapon diversity was not recorded exactly")
	_check(Meta.hidden_star_unlocked(state, "berserk_h0"), "two canonical Berserk weapons must reveal h0")


func _test_native_schema6_fail_closed_normalization() -> void:
	var path := "user://scrum1068_native_corrupt.cfg"
	created_paths.append(ProjectSettings.globalize_path(path))
	var config := ConfigFile.new()
	config.set_value("meta", "skill_tree_schema", 6)
	config.set_value("meta", "meta_point_awards", {"berserk": [0, 1, 2, 3, 4, 5]})
	config.set_value("meta", "skill_nodes", [
		"berserk_sword_b1",
		"berserk_sword_b3",
		"berserk_sword_final",
		"berserk_h0",
		"atlas_k0",
	])
	config.set_value("meta", "class_challenge_progress", {"berserk": {"weapons": ["sword", "axe"], "best_ascension": 0, "no_shop_wins": 0}})
	config.set_value("meta", "hidden_reveal_facts", {"berserk": ["berserk_h0"]})
	config.set_value("meta", "legacy_mastery", {})
	config.save(path)
	var state := Meta.load_state(path)
	_check((state.get("skill_nodes", []) as Array) == ["berserk_sword_b1"], "native schema6 must reject disconnected final/b3/hidden and disconnected zero-budget Guild purchase")


func _write_schema5_fixture(path: String, awards: Array, done: Array) -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "skill_tree_schema", 5)
	config.set_value("meta", "meta_point_awards", {"berserk": awards})
	config.set_value("meta", "ascension_levels", {"berserk": 5})
	config.set_value("meta", "skill_nodes", ["atlas_m0", "atlas_m1", "berserk_m0", "berserk_k0", "unknown_node"])
	config.set_value("meta", "active_keystones", {"berserk": "berserk_k0"})
	config.set_value("meta", "class_boss_wins", {"berserk": 9})
	config.set_value("meta", "class_challenge_progress", {"berserk": {"weapons": ["sword", "axe", "hammer"], "best_ascension": 5, "no_shop_wins": 1}})
	config.set_value("meta", "class_challenges_done", {"berserk": done})
	config.set_value("meta", "secret_boss_defeated", true)
	config.set_value("meta", "achievements", ["first_win"])
	config.set_value("meta", "discovered_monsters", [])
	config.set_value("meta", "discovered_bosses", [])
	config.set_value("meta", "discovered_artifacts", [])
	config.save(path)


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1068 migration test requires one explicit scratch user-data root.")
		return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
