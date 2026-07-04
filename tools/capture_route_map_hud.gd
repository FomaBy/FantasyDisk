extends SceneTree

## SCRUM-876: скрин карты маршрута с единым боевым ресурс-кластером.
## Run (windowed): Godot --path . --script res://tools/capture_route_map_hud.gd
## Output: build/qa/scrum876/route_map_hud_1920x1080.png

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum876")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
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
	for _i in range(20):
		await process_frame

	if DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png("%s/route_map_hud_1920x1080.png" % qa_dir)
	var hud := main.find_child("RunResourceHud", true, false) as PanelContainer
	print("RunResourceHud rect: ", hud.get_global_rect() if hud != null else "MISSING")
	print("Route map HUD capture done.")
	quit(0)
