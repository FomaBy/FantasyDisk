extends SceneTree

# FAN-3973: drive an exported pack through start -> main menu -> hero select ->
# one normal combat (with the route map shown in between, which is where the
# full-frame prefetch runs), WINDOWED so the real renderer resolves every
# texture, and report full-frame bodies actually configured on live enemies.
# Godot's own error output (missing resources, script errors) is what the
# caller greps for in the captured stderr; this script only prints progress.
#
#   Godot --main-pack <file.pck> --script <abs path to this file>
#
# `--script` loads this file from the host filesystem while every `res://`
# path below resolves inside the pack.

const MENU_FRAMES := 120
const HERO_SELECT_FRAMES := 60
const ROUTE_MAP_FRAMES := 240
const COMBAT_FRAMES := 900


func _initialize() -> void:
	await _run()


func _run() -> void:
	print("probe: renderer=%s main_pack_resources=%s" % [RenderingServer.get_current_rendering_method(), ResourceLoader.exists("res://scenes/Main.tscn")])
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("probe: res://scenes/Main.tscn did not load from the pack")
		quit(1)
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _i in range(MENU_FRAMES):
		await process_frame
	print("probe: main menu shown, ui_layer=%s" % (main.get("ui_layer") != null))

	main.call("_show_character_select")
	for _i in range(HERO_SELECT_FRAMES):
		await process_frame
	var hero_screen := main.find_child("HeroSelectScreen", true, false)
	print("probe: hero select shown=%s" % (hero_screen != null))

	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_show_battle_map")
	for _i in range(ROUTE_MAP_FRAMES):
		await process_frame
	var registry: Variant = load("res://scripts/full_frame_animation_registry.gd")
	print("probe: route map shown; prefetched packs resident=%d" % int(registry.prefetched_frames_count()))

	main.call("_start_combat")
	var full_frame_enemies := 0
	var static_enemies := 0
	var seen_ids := {}
	for _i in range(COMBAT_FRAMES):
		await process_frame
		if _i % 60 == 0:
			for enemy in get_nodes_in_group("enemies"):
				var body := enemy.get_node_or_null("FullFrameBody") as AnimatedSprite2D
				var enemy_id := str(enemy.get("enemy_type_name"))
				if seen_ids.has(enemy_id):
					continue
				seen_ids[enemy_id] = true
				if body != null and body.visible and body.sprite_frames != null:
					full_frame_enemies += 1
				else:
					static_enemies += 1
	print("probe: combat ran %d frames; enemy kinds seen=%d with full-frame body=%d static-only=%d; combat_active=%s" % [COMBAT_FRAMES, seen_ids.size(), full_frame_enemies, static_enemies, main.get("combat_active")])
	print("probe: kinds: %s" % ", ".join(seen_ids.keys()))
	main.call("_end_combat", true) if main.has_method("_end_combat") else null
	for _i in range(30):
		await process_frame
	print("probe: done")
	quit(0)
