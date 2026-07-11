extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const OUT_DIR := "res://docs/design/previews/scrum926_priest_prayer/runtime"


func _initialize() -> void:
	var absolute := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	for target in TARGETS:
		await _capture(target, absolute)
	print("SCRUM-926 runtime captures written to %s" % absolute)
	quit(0)


func _capture(target: Vector2i, absolute: String) -> void:
	paused = false
	var viewport := SubViewport.new()
	viewport.size = target
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	for _frame in range(3):
		await process_frame
	main.set("selected_character_id", "priest")
	main.set("selected_weapon_id", "priest_censer")
	main.call("_start_combat", false, "elite")
	for _frame in range(20):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("SCRUM-926 capture unavailable at %s" % str(target))
		quit(1)
		return
	image.save_png("%s/priest_prayer_choice_%dx%d.png" % [absolute, target.x, target.y])
	main.call("_clear_all_game_pauses")
	main.queue_free()
	viewport.queue_free()
	paused = false
	for _frame in range(3):
		await process_frame
