extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const STRESS_CYCLES := 50

var _errors: Array[String] = []


func _initialize() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	main.selected_character_id = "berserk"
	main.selected_weapon_id = "sword"

	await _test_route_pause_settings_repro(main)
	await _test_menu_snapshot_lifecycle(main)
	var continue_snapshot: Dictionary = await _test_double_start_idempotency(main)
	await _test_stale_combat_active_route_activation(main)
	await _stress_new_continue_transitions(main, continue_snapshot)

	main.combat_active = false
	main.boss_combat_active = false
	main._clear_world()
	main._clear_hud()
	main._clear_ui()
	main.queue_free()
	await process_frame
	await physics_frame

	if not _errors.is_empty():
		for error in _errors:
			push_error("SCRUM-1071: %s" % error)
		quit(1)
		return
	print("SCRUM-1071 duplicate Player regression passed: %d start cycles, new/continue, battle/elite/boss, temp cleanup, idempotent hooks/HUD/camera." % STRESS_CYCLES)
	quit(0)


func _test_route_pause_settings_repro(main: Node) -> void:
	main._show_battle_map()
	await process_frame
	main.ui._show_pause_menu()
	await process_frame
	var pause_menu := main.pause_stats_menu as Control
	var temp_player: Node = pause_menu.get("_player") as Node if pause_menu != null else null
	if pause_menu == null or temp_player == null:
		_errors.append("Route Map -> dossier did not create the expected snapshot fixture")
		main._clear_all_game_pauses()
		return
	var temp_ref: WeakRef = weakref(temp_player)
	var settings_button := main.find_child("PauseSettingsButton", true, false) as Button
	if settings_button == null:
		_errors.append("Route Map dossier lacks Settings action")
		main._clear_all_game_pauses()
		return
	settings_button.pressed.emit()
	if temp_player.is_inside_tree() or temp_player.is_in_group("temporary_players"):
		_errors.append("Route Map -> dossier -> Settings did not synchronously detach snapshot")
	await process_frame
	await physics_frame
	if temp_ref.get_ref() != null:
		_errors.append("Route Map -> dossier -> Settings leaked snapshot after frames")
	if main.find_child("SettingsV2Root", true, false) == null:
		_errors.append("Route Map dossier Settings transition did not complete")
	var back_button := main.find_child("SettingsBackButton", true, false) as Button
	if back_button == null:
		_errors.append("Settings return action missing in lifecycle reproduction")
		main._clear_all_game_pauses()
		return
	back_button.pressed.emit()
	await process_frame
	var resume_button := main.find_child("PauseResumeButton", true, false) as Button
	if resume_button == null:
		_errors.append("Settings return did not restore pause dossier")
		main._clear_all_game_pauses()
		return
	resume_button.pressed.emit()
	await process_frame
	await physics_frame
	if main.get_tree().paused or not get_nodes_in_group("temporary_players").is_empty():
		_errors.append("Settings -> dossier -> Resume left pause or temporary Player behind")


func _test_menu_snapshot_lifecycle(main: Node) -> void:
	var temp_player := main.combat._snapshot_player_for_menu() as Node
	if temp_player == null:
		_errors.append("menu snapshot could not be created")
		return
	if temp_player.is_in_group("player"):
		_errors.append("menu snapshot remained in combat player group")
	if not temp_player.is_in_group("temporary_players"):
		_errors.append("menu snapshot lacks explicit temporary ownership group")
	if StringName(temp_player.get_meta("player_lifecycle_role", &"")) != &"menu_snapshot":
		_errors.append("menu snapshot lacks lifecycle role metadata")
	if int(temp_player.get_meta("player_lifecycle_owner", 0)) != main.get_instance_id():
		_errors.append("menu snapshot lacks Main ownership metadata")
	if temp_player.process_mode != Node.PROCESS_MODE_DISABLED:
		_errors.append("menu snapshot can still process gameplay")
	var temp_camera := temp_player.get_node_or_null("Camera2D") as Camera2D
	if temp_camera == null or temp_camera.enabled:
		_errors.append("menu snapshot Camera2D is missing or still enabled")
	var temp_ref: WeakRef = weakref(temp_player)
	main._clear_ui()
	if temp_player.is_inside_tree() or temp_player.is_in_group("temporary_players"):
		_errors.append("_clear_ui did not synchronously detach its menu snapshot")
	await process_frame
	await physics_frame
	if temp_ref.get_ref() != null:
		_errors.append("detached menu snapshot was not freed after process/physics frames")


func _test_double_start_idempotency(main: Node) -> Dictionary:
	# Simulate the observed Route Map -> dossier -> Settings leak immediately
	# before two confirmations converge on combat start.
	for leak_index in range(3):
		var leaked := main.combat._snapshot_player_for_menu() as Node
		if leaked != null:
			leaked.set_meta("pause_dossier_temp_player", true)
	# Also cover a pre-SCRUM-1071/unmarked orphan: ancestry + player group must
	# still make world cleanup authoritative even without current_player metadata.
	var legacy_orphan := main.player_scene.instantiate() as Node
	main.add_child(legacy_orphan)
	var legacy_ref: WeakRef = weakref(legacy_orphan)
	var generation_before := int(main.combat.get("_combat_start_generation"))
	main._start_combat(false, "battle")
	var first_player := main.current_player as Node
	var first_id := first_player.get_instance_id() if first_player != null else 0
	main._start_combat(false, "battle")
	main._start_combat(false, "battle")
	if main.current_player == null or main.current_player.get_instance_id() != first_id:
		_errors.append("rapid double/triple start replaced the accepted combat Player")
	if int(main.combat.get("_combat_start_generation")) != generation_before + 1:
		_errors.append("rapid start created more than one combat generation")
	_assert_combat_uniqueness(main, "double start immediate")
	await process_frame
	await physics_frame
	if legacy_ref.get_ref() != null:
		_errors.append("legacy unmarked Player orphan survived combat cleanup")
	_assert_combat_uniqueness(main, "double start after frames")
	if first_player == null:
		return {}
	main.combat._store_player_snapshot(first_player)
	return main.run_player_snapshot.duplicate(true)


func _test_stale_combat_active_route_activation(main: Node) -> void:
	# Exact independent-QA regression: a live battle is torn down by the real
	# route-map boundary, whose historical contract leaves combat_active stale.
	# Gamepad A and mouse share RouteNode.pressed, so emitting pressed exercises
	# the production route activation without depending on a physical controller.
	var generation_before := int(main.combat.get("_combat_start_generation"))
	main.route_stage = 0
	main.route_selected_indices = []
	main.route._show_battle_map()
	if not main.combat_active:
		_errors.append("stale-boundary fixture unexpectedly normalized combat_active before route activation")
	if main.current_player != null or main.hud_layer != null:
		_errors.append("route-map boundary did not clear the previous Player/HUD fixture")
	await process_frame
	await physics_frame
	var focus := main.get_viewport().gui_get_focus_owner() as Button
	if focus == null or not str(focus.name).begins_with("RouteNode_") or focus.disabled:
		_errors.append("route-map stale-boundary fixture lacks an available focused RouteNode")
		return
	var map_screen := main.ui_layer.get_node_or_null("RouteMapScreen") as Node
	focus.pressed.emit()
	await process_frame
	await physics_frame
	if map_screen != null and is_instance_valid(map_screen) and map_screen.get_parent() != null:
		_errors.append("stale combat_active blocked RouteNode gamepad-A/pressed activation")
	if int(main.combat.get("_combat_start_generation")) != generation_before + 1:
		_errors.append("stale route boundary did not create exactly one replacement combat generation")
	_assert_combat_uniqueness(main, "stale route-map A activation")


func _stress_new_continue_transitions(main: Node, continue_snapshot: Dictionary) -> void:
	for cycle in range(STRESS_CYCLES):
		main.combat_active = false
		main.boss_combat_active = false
		main._clear_world()
		main._clear_hud()
		main._clear_ui()
		await process_frame
		await physics_frame

		var is_continue := cycle >= STRESS_CYCLES / 2
		main.run_player_snapshot = continue_snapshot.duplicate(true) if is_continue else {}
		# Every fifth transition leaves two dossier snapshots unresolved. Combat
		# start must retire them centrally, including the Settings teardown path.
		if cycle % 5 == 0:
			for leak_index in range(2):
				var leaked := main.combat._snapshot_player_for_menu() as Node
				if leaked != null:
					leaked.set_meta("pause_dossier_temp_player", true)

		var combat_type := "battle"
		var is_boss := false
		match cycle % 10:
			7:
				combat_type = "elite"
			8:
				combat_type = "boss"
				is_boss = true
			_:
				pass
		var generation_before := int(main.combat.get("_combat_start_generation"))
		main._start_combat(is_boss, combat_type)
		var accepted_player := main.current_player as Node
		var accepted_id := accepted_player.get_instance_id() if accepted_player != null else 0
		# Models rapid mouse/key/gamepad confirmation delivery to the same lifecycle
		# entry point without relying on layout-owned controls.
		main._start_combat(is_boss, combat_type)
		main._start_combat(is_boss, combat_type)
		if accepted_player == null or main.current_player == null or main.current_player.get_instance_id() != accepted_id:
			_errors.append("cycle %d (%s): repeated trigger replaced Player" % [cycle, "continue" if is_continue else "new"])
		if int(main.combat.get("_combat_start_generation")) != generation_before + 1:
			_errors.append("cycle %d: expected exactly one combat generation" % cycle)
		_assert_combat_uniqueness(main, "cycle %d immediate" % cycle)
		await process_frame
		await physics_frame
		_assert_combat_uniqueness(main, "cycle %d after frames" % cycle)


func _assert_combat_uniqueness(main: Node, context: String) -> void:
	var players: Array[Node] = []
	for candidate in get_nodes_in_group("player"):
		if candidate is Node and is_instance_valid(candidate):
			players.append(candidate as Node)
	if players.size() != 1:
		_errors.append("%s: expected one player-group node, got %d" % [context, players.size()])
		return
	var player := players[0]
	if player != main.current_player:
		_errors.append("%s: player-group node is not current_player" % context)
	if StringName(player.get_meta("player_lifecycle_role", &"")) != &"combat":
		_errors.append("%s: current Player lacks combat lifecycle role" % context)
	if int(player.get_meta("player_lifecycle_owner", 0)) != main.get_instance_id():
		_errors.append("%s: current Player lacks Main lifecycle owner" % context)
	if not get_nodes_in_group("temporary_players").is_empty():
		_errors.append("%s: temporary Player survived combat transition" % context)

	var enabled_cameras := 0
	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	for candidate in players:
		for camera_node in candidate.find_children("*", "Camera2D", true, false):
			var camera := camera_node as Camera2D
			if camera != null and camera.enabled:
				enabled_cameras += 1
	if player_camera == null or not player_camera.enabled or enabled_cameras != 1:
		_errors.append("%s: expected exactly one enabled Player Camera2D" % context)
	if player.is_inside_tree() and player.get_viewport().get_camera_2d() != player_camera:
		_errors.append("%s: viewport current camera is not current_player Camera2D" % context)

	for signal_name in [&"died", &"leveled_up", &"damaged"]:
		var connections := player.get_signal_connection_list(signal_name)
		if connections.size() != 1:
			_errors.append("%s: signal %s has %d handlers, expected one" % [context, signal_name, connections.size()])
	var hud_roots := main.find_children("CombatHudRoot", "Control", true, false)
	if hud_roots.size() != 1:
		_errors.append("%s: expected one CombatHudRoot, got %d" % [context, hud_roots.size()])
	var weapons := get_nodes_in_group("player_weapons")
	if weapons.size() != 1:
		_errors.append("%s: expected one equipped player weapon, got %d" % [context, weapons.size()])
