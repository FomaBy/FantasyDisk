extends SceneTree

# FAN-3973 rework: "click -> elite fight" through the real route-map path,
# WINDOWED, meant to be run with `--verbose` and wall-time stamps so the trace
# shows when the elite's SpriteFrames loaded relative to the click:
#
#   Godot --path <project> --verbose --script <abs path to this file> 2>&1 \
#     | perl -MTime::HiRes=time -pe '...stamp...'
#
# Flow: Main -> generated route (seeded) -> route_stage = first elite_battle
# row -> _show_battle_map -> wait WAIT_FRAMES (player reading the map) ->
# _activate_route_node on the elite node (the click) -> 120 combat frames.
# Prints: whether the elite pack was resident before the click, click
# duration, the longest frame in the first second of combat, whether the
# spawned elite has a live full-frame body, and RENDER_TEXTURE_MEM_USED at
# each stage (input for the FAN-3964 Windows review).

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const WAIT_FRAMES := 180  # 1.5 s at 120 Hz
const COMBAT_FRAMES := 120
const MAX_ROUTE_SEEDS := 32


func _initialize() -> void:
	await _run()


func _texture_mib() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _i in range(30):
		await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	var route: Array = []
	var elite_row := -1
	var elite_branch := -1
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
		print("probe: no elite_battle node generated")
		quit(1)
		return
	main.set("route_nodes", route)
	var elite_node: Dictionary = (route[elite_row] as Array)[elite_branch]
	var node_seed := int(elite_node.get("seed", main.fallback_node_seed(elite_node)))
	var elite_scene: PackedScene = main.node_elite_scene(node_seed)
	var elite_id := ""
	var state := elite_scene.get_state()
	for index in range(state.get_node_property_count(0)):
		if str(state.get_node_property_name(0, index)) == "elite_behavior":
			elite_id = str(state.get_node_property_value(0, index))
	var elite_frames := str(FullFrameAnimationRegistry.registry_config("elite", elite_id).get("frames", ""))
	print("probe: texture memory in menu %.0f MiB" % _texture_mib())

	main.set("route_stage", elite_row)
	main.route._show_battle_map()
	print("probe: route map shown, row %d branch %d node '%s' elite %s (%s)" % [elite_row, elite_branch, str(elite_node.get("name", "")), elite_id, elite_frames])
	var resident_at_frame := -1
	for frame_index in range(WAIT_FRAMES):
		await process_frame
		if resident_at_frame < 0 and FullFrameAnimationRegistry._prefetched_frames.has(elite_frames):
			resident_at_frame = frame_index
	print("probe: after %d map frames — elite pack resident: %s (first resident at frame %d); packs resident %d; texture memory %.0f MiB" % [WAIT_FRAMES, FullFrameAnimationRegistry._prefetched_frames.has(elite_frames), resident_at_frame, FullFrameAnimationRegistry.prefetched_frames_count(), _texture_mib()])

	print("probe: CLICK elite node")
	var click_started := Time.get_ticks_usec()
	main.route._activate_route_node(elite_row, elite_branch, elite_node)
	var click_ms := float(Time.get_ticks_usec() - click_started) / 1000.0
	print("probe: click took %.1f ms; combat_active=%s combat_type=%s" % [click_ms, main.get("combat_active"), main.get("current_combat_type")])

	var last := Time.get_ticks_usec()
	var max_delta := 0.0
	var peak_texture := _texture_mib()
	for _i in range(COMBAT_FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		max_delta = max(max_delta, float(now - last) / 1000.0)
		last = now
		peak_texture = max(peak_texture, _texture_mib())
	var elites := 0
	var elites_with_body := 0
	for enemy in get_nodes_in_group("elite_enemies"):
		elites += 1
		var body := enemy.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if body != null and body.visible and body.sprite_frames != null:
			elites_with_body += 1
	print("probe: %d combat frames — longest frame %.1f ms; elites %d with full-frame body %d; peak texture memory %.0f MiB; enemies alive %d" % [COMBAT_FRAMES, max_delta, elites, elites_with_body, peak_texture, get_nodes_in_group("enemies").size()])
	if main.has_method("_end_combat"):
		main.call("_end_combat", true)
	for _i in range(30):
		await process_frame
	print("probe: done")
	quit(0)
