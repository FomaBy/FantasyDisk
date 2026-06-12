extends SceneTree

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	viewport.add_child(main)
	await process_frame
	main.call("_show_settings_menu")
	await process_frame
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	if tabs != null:
		tabs.current_tab = 1
	await process_frame
	await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	var image := viewport.get_texture().get_image()
	if image == null:
		var report := FileAccess.open(ProjectSettings.globalize_path("res://build/qa/settings_volume_slider_ux_tree.txt"), FileAccess.WRITE)
		report.store_line("Headless SubViewport screenshot texture was unavailable.")
		for slider_id in ["master_volume", "music_volume", "sfx_volume"]:
			var slider := main.find_child("VolumeSlider_%s" % slider_id, true, false) as HSlider
			if slider == null:
				report.store_line("%s: missing" % slider_id)
				continue
			var track := slider.get_theme_stylebox("slider")
			var fill := slider.get_theme_stylebox("grabber_area")
			report.store_line("%s: visible=%s value=%.1f min_size=%s step=%.1f focus=%s track=%s fill=%s" % [
				slider_id,
				str(slider.visible),
				slider.value,
				str(slider.custom_minimum_size),
				slider.step,
				str(slider.focus_mode),
				track.get_class(),
				fill.get_class(),
			])
		report.close()
		quit(2)
		return
	image.save_png(ProjectSettings.globalize_path("res://build/qa/settings_volume_slider_ux.png"))
	quit(0)
