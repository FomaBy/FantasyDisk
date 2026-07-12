extends SceneTree

## SCRUM-1089: five-target screenshot matrix for the full-fit Route Map + HUD 2×.
## Run (windowed): python3 tools/godot_gate.py --path . --script res://tools/capture_route_map_hud.gd
## Output: docs/design/previews/scrum1089_route_map_full_fit_hud2x/runtime/

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [
	Vector2i(1152,648), Vector2i(1280,720), Vector2i(1600,900),
	Vector2i(1920,1080), Vector2i(2560,1440),
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://docs/design/previews/scrum1089_route_map_full_fit_hud2x/runtime")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	for target in TARGETS:
		var viewport := SubViewport.new()
		viewport.size = target
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		await process_frame
		var main := MAIN_SCENE.instantiate()
		viewport.add_child(main)
		await process_frame
		main.set("selected_character_id", "berserk")
		main.set("selected_weapon_id", "sword")
		main.set("route_stage", 0)
		main.set("route_nodes", main.route._generate_route())
		main.route._show_battle_map()
		for _i in range(12):
			await process_frame
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("SCRUM-1089 capture failed for %s" % str(target))
			quit(1)
			return
		var output := "%s/route_map_full_fit_hud2x_%dx%d.png" % [qa_dir, target.x, target.y]
		if image.save_png(output) != OK:
			push_error("SCRUM-1089 could not write %s" % output)
			quit(1)
			return
		print("Saved ", output)
		viewport.queue_free()
		await process_frame
	print("SCRUM-1089 Route Map full-fit screenshot matrix complete.")
	quit(0)
