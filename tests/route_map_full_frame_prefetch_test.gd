extends SceneTree

# FAN-3973 rework (QA d7bc8435 FAILED candidate 01d7d5106): the route-map
# prefetch hook matched node type "elite" while generated routes carry
# "elite_battle", so no elite pack was ever prefetched and the elite still
# loaded synchronously inside the node click. This suite drives the REAL hook
# (`_show_battle_map` on a generated route, not `queue_prefetch` directly):
#
# 1. On a row that contains an `elite_battle` node, the pack of the elite that
#    `node_elite_scene(seed)` resolves for that node is queued/in flight/
#    resident after the map is shown.
# 2. On the boss row, the node's `boss_id` pack is queued — read from the node
#    itself, without resetting `secret_boss_active` (the old code went through
#    `resolve_final_act_boss_id`, which has that side effect).
# 3. On every row the regular enemy pool is queued.
#
# Запуск: Godot --headless --path . --script res://tests/route_map_full_frame_prefetch_test.gd

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const MAX_ROUTE_SEEDS := 32

var _errors: Array = []


func _initialize() -> void:
	await _run()
	if not _errors.is_empty():
		for error in _errors:
			push_error("Route map full-frame prefetch: %s" % error)
		push_error("Route map full-frame prefetch test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Route map full-frame prefetch test passed (elite_battle row queues the node elite, boss row queues the node boss without run-state side effects, enemy pool on every row).")
	quit(0)


func _fail(message: String) -> void:
	_errors.append(message)


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")

	# Route generation is rng-driven; pick the first seed whose route has an
	# elite_battle node so the elite check never passes vacuously.
	var elite_row := -1
	var elite_branch := -1
	var route: Array = []
	for seed_index in range(MAX_ROUTE_SEEDS):
		main.rng.seed = 3973 + seed_index
		route = main.route._generate_route()
		for step_index in range(route.size()):
			for branch_index in range((route[step_index] as Array).size()):
				if str(((route[step_index] as Array)[branch_index] as Dictionary).get("type", "")) == "elite_battle":
					elite_row = step_index
					elite_branch = branch_index
					break
			if elite_row >= 0:
				break
		if elite_row >= 0:
			break
	if elite_row < 0:
		_fail("no generated route with an elite_battle node in %d seeds — cannot exercise the elite branch." % MAX_ROUTE_SEEDS)
		main.queue_free()
		return
	main.set("route_nodes", route)

	# --- 1. elite_battle row -> that node's elite pack is queued. ---
	var elite_node: Dictionary = (route[elite_row] as Array)[elite_branch]
	var node_seed := int(elite_node.get("seed", main.fallback_node_seed(elite_node)))
	var elite_id := _scene_root_string_property(main.node_elite_scene(node_seed), "elite_behavior")
	var elite_frames := str(FullFrameAnimationRegistry.registry_config("elite", elite_id).get("frames", ""))
	if elite_id == "" or elite_frames == "":
		_fail("node_elite_scene(%d) must resolve to a registered elite (got id '%s')." % [node_seed, elite_id])
	FullFrameAnimationRegistry.release_prefetched()
	main.set("route_stage", elite_row)
	main.route._show_battle_map()
	await process_frame
	if not _is_prefetch_tracked(elite_frames):
		_fail("row %d has elite_battle node '%s' (elite %s) but its pack %s was not queued by _show_battle_map." % [elite_row, str(elite_node.get("name", "")), elite_id, elite_frames])
	_assert_enemy_pool_tracked("elite_battle row")
	# The hook is read-only for run state: a rogue `elite` alias node in the
	# same row would be handled the same way (covered by _open_route_node).

	# --- 2. boss row -> the node's boss pack, no secret_boss_active reset. ---
	var boss_row := route.size() - 1
	var boss_node: Dictionary = (route[boss_row] as Array)[0]
	if str(boss_node.get("type", "")) != "boss":
		_fail("expected the last generated row to be the boss row, got '%s'." % str(boss_node.get("type", "")))
	else:
		var boss_id := str(boss_node.get("boss_id", ""))
		var boss_frames := str(FullFrameAnimationRegistry.registry_config("boss", boss_id).get("frames", ""))
		if boss_frames == "":
			_fail("boss node id '%s' is not a registered boss pack." % boss_id)
		FullFrameAnimationRegistry.release_prefetched()
		main.set("secret_boss_active", true)
		main.set("route_stage", boss_row)
		main.route._show_battle_map()
		await process_frame
		if not _is_prefetch_tracked(boss_frames):
			_fail("boss row did not queue the node boss pack %s." % boss_frames)
		if not bool(main.get("secret_boss_active")):
			_fail("showing the route map must not reset secret_boss_active (prefetch went through resolve_final_act_boss_id).")
		main.set("secret_boss_active", false)
		_assert_enemy_pool_tracked("boss row")

	# --- 3. a plain battle row still queues the enemy pool and nothing else. ---
	FullFrameAnimationRegistry.release_prefetched()
	main.set("route_stage", 0)
	main.route._show_battle_map()
	await process_frame
	_assert_enemy_pool_tracked("row 0")
	if _is_prefetch_tracked(elite_frames):
		_fail("row 0 (battle only) must not queue the elite pack of another row.")

	FullFrameAnimationRegistry.release_prefetched()
	main.queue_free()
	await process_frame


func _assert_enemy_pool_tracked(where: String) -> void:
	var enemy_table: Dictionary = FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES.get("enemy", {})
	for enemy_id in enemy_table.keys():
		var frames_path := str((enemy_table[enemy_id] as Dictionary).get("frames", ""))
		if not _is_prefetch_tracked(frames_path):
			_fail("%s: enemy pack %s is not queued/resident." % [where, frames_path])
			return


func _is_prefetch_tracked(frames_path: String) -> bool:
	return FullFrameAnimationRegistry._prefetch_queue.has(frames_path) \
		or FullFrameAnimationRegistry._prefetch_in_flight.has(frames_path) \
		or FullFrameAnimationRegistry._prefetched_frames.has(frames_path)


func _scene_root_string_property(scene: PackedScene, property_name: String) -> String:
	if scene == null:
		return ""
	var state := scene.get_state()
	for index in range(state.get_node_property_count(0)):
		if str(state.get_node_property_name(0, index)) == property_name:
			return str(state.get_node_property_value(0, index))
	return ""
