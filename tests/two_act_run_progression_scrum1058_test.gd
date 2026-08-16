extends SceneTree

const RunAutosave := preload("res://scripts/run_autosave.gd")

var _failed := false


func _fail(message: String) -> void:
	_failed = true
	push_error("[SCRUM-1058 two-act progression] " + message)


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn must load")
		quit(1)
		return
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame

	_test_authoritative_two_act_contract(game)
	_test_transition_heal_and_single_advance(game)
	_test_final_act_secret_gate(game)
	_test_legacy_act_three_migration(game)
	_test_legacy_snapshot_modifier_guard(game)
	_test_production_sources_have_no_removed_act_contracts()
	await _test_secret_boss_completion_clears_autosave(game)

	game.clear_run_autosave()
	game.queue_free()
	await process_frame
	if _failed:
		quit(1)
	else:
		print("[SCRUM-1058 two-act progression] PASSED")
		quit(0)


func _test_authoritative_two_act_contract(game: Node) -> void:
	if int(game.ACT_COUNT) != 2:
		_fail("ACT_COUNT must be exactly 2")
	if int(game.ACT_SCALING_STAGE_OFFSET) != int(game.ROUTE_STEPS_TO_BOSS):
		_fail("Act scaling offset must equal the unchanged per-act route length")
	game.current_act = 1
	game.route_stage = 0
	if game.act_progress_label() != "Акт 1/2":
		_fail("Act 1 label must be dynamic 1/2")
	var act_one_route: Array = game.route._generate_route()
	if act_one_route.size() != int(game.ROUTE_STEPS_TO_BOSS) + 1:
		_fail("Act 1 route length changed")
	game.route_stage = int(game.ROUTE_STEPS_TO_BOSS)
	var act_one_final_scale := int(game.route_scaling_stage())
	game.current_act = 2
	game.route_stage = 0
	if game.act_progress_label() != "Акт 2/2":
		_fail("Act 2 label must be dynamic 2/2")
	if int(game.route_scaling_stage()) != act_one_final_scale:
		_fail("Act 2 must start at continuous Act 1 boss pressure, without a drop or jump")
	var act_two_route: Array = game.route._generate_route()
	if act_two_route.size() != act_one_route.size():
		_fail("Act 2 route must not be lengthened to compensate for removed Act 3")
	game.route_stage = int(game.ROUTE_STEPS_TO_BOSS)
	if int(game.route_scaling_stage()) != int(game.ROUTE_STEPS_TO_BOSS) * 2:
		_fail("Act 2 boss must reach the former final scaling stage")


func _test_transition_heal_and_single_advance(game: Node) -> void:
	game.clear_run_autosave()
	game.current_act = 1
	game.route_stage = int(game.ROUTE_STEPS_TO_BOSS)
	game.route_nodes = game.route._generate_route()
	game.route_selected_indices = [0, 0]
	game.run_player_snapshot = {"health": 20.0, "max_health": 100.0, "level": 7}
	if not game.advance_to_next_act():
		_fail("Act 1 boss continuation must advance to Act 2")
	var expected_health := 20.0 + 100.0 * float(game.ACT_TRANSITION_HEAL_PERCENT)
	if not is_equal_approx(float(game.run_player_snapshot.get("health", -1.0)), expected_health):
		_fail("Act transition heal must be applied exactly once")
	if int(game.current_act) != 2 or int(game.route_stage) != 0:
		_fail("Act 2 must start at route_stage 0")
	if not (game.route_selected_indices as Array).is_empty():
		_fail("Act 2 must start with fresh route selections")
	if (game.route_nodes as Array).size() != int(game.ROUTE_STEPS_TO_BOSS) + 1:
		_fail("Act 2 must generate one normal-length fresh route")
	if game.advance_to_next_act():
		_fail("Final Act 2 must not create a third route map")
	if not is_equal_approx(float(game.run_player_snapshot.get("health", -1.0)), expected_health):
		_fail("Rejected final-act advance must not apply transition heal twice")
	var persisted := RunAutosave.load_run()
	if int(persisted.get("current_act", 0)) != 2 or int(persisted.get("route_stage", -1)) != 0:
		_fail("Act transition autosave must persist the Act 2 route checkpoint")


func _test_final_act_secret_gate(game: Node) -> void:
	game.current_act = int(game.ACT_COUNT)
	game.secret_boss_active = false
	game.selected_ascension_level = int(game.META_PROGRESSION.MAX_ASCENSION_LEVEL) - 1
	if game.should_start_secret_boss_after_final_act():
		_fail("Below-max Ascension must finish after the normal Act 2 boss")
	game.selected_ascension_level = int(game.META_PROGRESSION.MAX_ASCENSION_LEVEL)
	if not game.should_start_secret_boss_after_final_act():
		_fail("Max Ascension must arm the secret boss after the normal Act 2 boss")
	var normal_boss := "ashen_colossus"
	if game.resolve_final_act_boss_id(normal_boss) != normal_boss or bool(game.secret_boss_active):
		_fail("Route entry must keep the normal final boss before the secret follow-up")


func _test_legacy_act_three_migration(game: Node) -> void:
	var route: Array = game.route._generate_route()
	var legacy := {
		"current_act": 3,
		"route_stage": 5,
		"route_nodes": route,
		"route_selected_indices": [0, 1, 0, 1, 0],
		"run_player_snapshot": {"health": 73.0, "max_health": 100.0, "level": 12},
		"selected_character_id": "berserk",
	}
	var migrated: Dictionary = game.migrate_run_autosave_state(legacy)
	if int(migrated.get("current_act", 0)) != 2 or int(migrated.get("legacy_current_act", 0)) != 3:
		_fail("Legacy current_act=3 must normalize to the final Act 2 checkpoint")
	if int(migrated.get("route_stage", -1)) != 5 or migrated.get("run_player_snapshot", {}) != legacy["run_player_snapshot"]:
		_fail("Legacy migration must preserve route position and player build")
	if migrated.get("route_nodes", []) != route or migrated.get("route_selected_indices", []) != legacy["route_selected_indices"] or str(migrated.get("selected_character_id", "")) != "berserk":
		_fail("Legacy migration must keep route nodes/selections and selected character")
	game.clear_run_autosave()
	if not RunAutosave.save_run(legacy):
		_fail("Legacy checkpoint fixture must save")
		return
	if not game.load_run_autosave():
		_fail("Legacy checkpoint must load through the public autosave path")
		return
	if int(game.current_act) != 2 or int(game.route_stage) != 5:
		_fail("Loading a legacy save must never leave current_act outside 1..2")
	if float(game.run_player_snapshot.get("health", -1.0)) != 73.0:
		_fail("Loading a legacy save must preserve the player snapshot")
	var persisted := RunAutosave.load_run()
	if int(persisted.get("current_act", 0)) != 2 or int(persisted.get("run_act_count", 0)) != 2:
		_fail("Public load must persist the normalized two-act checkpoint")


func _test_legacy_snapshot_modifier_guard(game: Node) -> void:
	# FAN-2232: a present run_modifiers key passes canonical sanitization, an
	# absent optional key is never created, and a wrong-typed value fails
	# closed to an empty dictionary without crashing.
	var migrated_missing: Dictionary = game.migrate_run_autosave_state({
		"current_act": 3,
		"run_player_snapshot": {"health": 50.0, "level": 4},
	})
	if (migrated_missing.get("run_player_snapshot", {}) as Dictionary).has("run_modifiers"):
		_fail("Migration must not create the absent optional run_modifiers key")
	var migrated_present: Dictionary = game.migrate_run_autosave_state({
		"current_act": 3,
		"run_player_snapshot": {
			"health": 50.0,
			"run_modifiers": {"damage_multiplier": 1.25, "range_multiplier": 2.0},
		},
	})
	var sanitized = (migrated_present.get("run_player_snapshot", {}) as Dictionary).get("run_modifiers")
	if not (sanitized is Dictionary) or sanitized != {"damage_multiplier": 1.25}:
		_fail("Present run_modifiers must pass canonical sanitization")
	var migrated_corrupt: Dictionary = game.migrate_run_autosave_state({
		"current_act": 3,
		"run_player_snapshot": {"health": 50.0, "run_modifiers": "corrupt"},
	})
	var corrupt_value = (migrated_corrupt.get("run_player_snapshot", {}) as Dictionary).get("run_modifiers")
	if not (corrupt_value is Dictionary) or not (corrupt_value as Dictionary).is_empty():
		_fail("Wrong-typed run_modifiers must fail closed to an empty dictionary")


func _test_secret_boss_completion_clears_autosave(game: Node) -> void:
	game.clear_run_autosave()
	game.current_act = int(game.ACT_COUNT)
	game.route_stage = int(game.ROUTE_STEPS_TO_BOSS)
	game.route_nodes = game.route._generate_route()
	game.route_selected_indices = []
	game.selected_character_id = "berserk"
	game.selected_weapon_id = "sword"
	game.selected_ascension_level = int(game.META_PROGRESSION.MAX_ASCENSION_LEVEL)
	game.current_boss_id = "ashen_colossus"
	game.current_combat_type = "boss"
	game.secret_boss_active = false
	if not game.save_run_autosave("scrum1058_secret_flow"):
		_fail("Final-act checkpoint must save before the secret flow")
		return
	game._start_combat(true)
	await process_frame
	await process_frame
	# _start_combat clamps the selected level to account unlocks. This focused
	# flow intentionally exercises the max-Ascension branch without mutating the
	# persistent profile, so restore the branch input after combat setup.
	game.selected_ascension_level = int(game.META_PROGRESSION.MAX_ASCENSION_LEVEL)
	var normal_boss := get_first_node_in_group("bosses")
	if normal_boss == null:
		_fail("Normal final Act 2 boss must spawn")
		return
	normal_boss.set("dodge_chance", 0.0)
	normal_boss.set("shield_active", false)
	normal_boss.take_damage(9999999.0)
	for _attempt in range(180):
		await process_frame
		if game.combat.is_boss_victory_pending():
			break
	if not game.combat.is_boss_victory_pending():
		_fail("Normal final boss death must enter the victory-delay window")
		return
	await create_timer(2.1, false, false, true).timeout
	var reward_row: Node = null
	for _attempt in range(180):
		await process_frame
		reward_row = game.find_child("BossArtifactRewardRow", true, false)
		if reward_row != null:
			break
	if reward_row == null or reward_row.get_child_count() != 3:
		_fail("Max-Ascension Act 2 boss must show one reward before the secret follow-up")
		return
	(reward_row.get_child(0) as Button).emit_signal("pressed")
	var secret_boss: Node = null
	for _attempt in range(240):
		await process_frame
		if bool(game.secret_boss_active) and bool(game.combat_active):
			secret_boss = get_first_node_in_group("bosses")
			if secret_boss != null:
				break
	if secret_boss == null or not bool(game.secret_boss_active):
		_fail("Reward continuation must start the secret boss after final Act 2")
		return
	secret_boss.set("dodge_chance", 0.0)
	secret_boss.set("shield_active", false)
	secret_boss.take_damage(9999999.0)
	for _attempt in range(180):
		await process_frame
		if game.combat.is_boss_victory_pending():
			break
	if not game.combat.is_boss_victory_pending():
		_fail("Secret boss death must enter the victory-delay window")
		return
	await create_timer(2.1, false, false, true).timeout
	for _attempt in range(240):
		await process_frame
		if not RunAutosave.has_run():
			break
	if RunAutosave.has_run():
		_fail("Secret boss victory must finish the run and clear autosave")


func _test_production_sources_have_no_removed_act_contracts() -> void:
	for path in [
		"res://scripts/main.gd",
		"res://scripts/combat_director.gd",
		"res://scripts/route_map_screen.gd",
		"res://scripts/audio_manager.gd",
		"res://scripts/meta_progression.gd",
		"res://scripts/progression_data_content.gd",
		"res://scripts/progression_data_enemies.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for removed in ["after_act3", "resolve_act3", "act3", "Act 3", "Act-3", "Акт 3", "Акта 3", "ACT_COUNT := 3"]:
			if source.contains(removed):
				_fail("%s still contains removed three-act contract '%s'" % [path, removed])
