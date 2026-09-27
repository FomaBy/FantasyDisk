extends SceneTree

# FAN-3973 rework (QA d7bc8435 FAILED candidate 01d7d5106) pinned that the
# route-map hook queues the row's node elite and boss. FAN-3977 (FAN-3964 QA:
# 1-FPS seconds from mini-elite/elite/boss packs loading mid-fight) changed
# the policy: the route map warms the CORE roster — the regular enemy pool,
# EVERY mini-elite kind (any of them can roll in any regular fight) and every
# ally pack — and releases packs outside it; the node elite / boss pack is
# loaded after the click by `_finalize_combat_start`, which waits for the
# encounter roster before anything spawns (tests/full_frame_combat_residency_test.gd).
# Warming a whole row's elites and boss on top of the core roster would push
# texture memory past the 1.5 GiB acceptance line. This suite drives the REAL
# hook (`_show_battle_map` on a generated route):
#
# 1. On every row (elite_battle row, boss row, plain battle row) the core
#    roster is queued/in flight/resident: all enemies, all mini-elites, the
#    selected class's allies (and not another class's).
# 2. Showing the map on the boss row reads the node without resetting
#    `secret_boss_active` (the old code went through
#    `resolve_final_act_boss_id`, which has that side effect).
# 3. A pack outside the core roster (a boss left resident by the previous
#    fight) is released when the map is shown.
#
# Запуск: Godot --headless --path . --script res://tests/route_map_full_frame_prefetch_test.gd

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const FullFrameEncounterRoster := preload("res://scripts/full_frame_encounter_roster.gd")
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
	print("Route map full-frame prefetch test passed (every row queues the core roster: enemies, mini-elites, allies; node elite/boss are left to the gated combat start; boss row keeps secret_boss_active; stale boss pack released).")
	quit(0)


func _fail(message: String) -> void:
	_errors.append(message)


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	# Druid: the class whose ally roster is largest (beast, pack spirit, five
	# ghosts), so the class-specific ally warm-up is observable.
	main.set("selected_character_id", "druid")
	main.set("selected_weapon_id", "summon_amulet")

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

	# --- 1. elite_battle row -> the core roster is queued (elite loads at the click). ---
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
	_assert_core_roster_tracked(main, "elite_battle row")
	if _is_prefetch_tracked(elite_frames):
		_fail("row %d: the node elite pack %s must not be warmed by the route map (it is loaded by the gated combat start)." % [elite_row, elite_frames])

	# --- 2. boss row -> core roster, no secret_boss_active reset, previous boss released. ---
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
		# A boss pack left resident by the previous fight must be released.
		FullFrameAnimationRegistry._prefetched_frames[boss_frames] = load(boss_frames)
		main.set("secret_boss_active", true)
		main.set("route_stage", boss_row)
		main.route._show_battle_map()
		await process_frame
		if FullFrameAnimationRegistry.is_resident(boss_frames) or _is_prefetch_tracked(boss_frames):
			_fail("boss row: the previous boss pack %s must be released by the route map (retain_only core)." % boss_frames)
		if not bool(main.get("secret_boss_active")):
			_fail("showing the route map must not reset secret_boss_active (prefetch went through resolve_final_act_boss_id).")
		main.set("secret_boss_active", false)
		_assert_core_roster_tracked(main, "boss row")

	# --- 3. a plain battle row queues the core roster and nothing else. ---
	FullFrameAnimationRegistry.release_prefetched()
	main.set("route_stage", 0)
	main.route._show_battle_map()
	await process_frame
	_assert_core_roster_tracked(main, "row 0")
	if _is_prefetch_tracked(elite_frames):
		_fail("row 0 (battle only) must not queue the elite pack of another row.")

	FullFrameAnimationRegistry.release_prefetched()
	main.queue_free()
	await process_frame


func _assert_core_roster_tracked(main: Node, where: String) -> void:
	var core: Array = FullFrameEncounterRoster.core_paths(main.get("PROGRESSION_DATA"), str(main.get("selected_character_id")))
	if core.size() < 28:
		_fail("%s: core roster suspiciously small (%d packs)." % [where, core.size()])
	if not core.has(FullFrameAnimationRegistry.frames_path_for("ally", "druid_ghost_bear")):
		_fail("%s: the Druid's core roster must carry its ghost packs." % where)
	if core.has(FullFrameAnimationRegistry.frames_path_for("ally", "homunculus_tank")):
		_fail("%s: the Druid's core roster must not carry another class's summons." % where)
	for frames_path in core:
		if not _is_prefetch_tracked(str(frames_path)):
			_fail("%s: core pack %s is not queued/in flight/resident." % [where, frames_path])
			return
	_assert_enemy_pool_tracked(where)


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
