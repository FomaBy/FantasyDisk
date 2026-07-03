extends SceneTree

## SCRUM-847 v6: снимает все 3 вкладки настроек на 1920×1080 и 2560×1440.
## Run (windowed для PNG): Godot --path . --script res://tools/capture_settings_v6.gd
## Output: build/qa/scrum847_v6/settings_v6_<tab>_<WxH>.png + rects.md

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const TAB_SLUGS := ["screen", "sound", "controls"]

const DUMP_NODES := [
	"SettingsV2Modal", "SettingsV2MainModalFrame", "SettingsV2Title", "SettingsV6Emblem",
	"SettingsTabSwitcher", "SettingsTabButton_0", "SettingsTabButton_1", "SettingsTabButton_2",
	"SettingsContentPanel", "SettingsResolutionOption", "SettingsWindowModeOption",
	"ScreenShakeToggle", "SettingsPendingLabel",
	"VolumeSlider_master_volume", "VolumeChip_master_volume", "SettingsResetAudioButton",
	"SettingsAimModeOption", "DebugModeToggle", "SettingsResetBindingsButton",
	"SettingsGamepadDeadzoneSlider", "SettingsResetGamepadButton",
	"SettingsBottomActions", "SettingsApplyButton", "SettingsRevertButton", "SettingsBackButton",
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum847_v6")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-847 Settings v6 Capture")
	dump_lines.append("")
	for viewport_size in VIEWPORT_SIZES:
		await _capture_at_size(viewport_size, qa_dir, dump_lines)
	var file := FileAccess.open("%s/settings_v6_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	print("Settings v6 capture done.")
	quit(0)


func _capture_at_size(viewport_size: Vector2i, qa_dir: String, dump_lines: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.call("_show_settings_menu")
	for _i in range(6):
		await process_frame

	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	dump_lines.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	for tab_index in range(3):
		if tabs != null:
			tabs.current_tab = tab_index
		for _i in range(6):
			await process_frame
		var output_path := "%s/settings_v6_%s_%dx%d.png" % [qa_dir, TAB_SLUGS[tab_index], viewport_size.x, viewport_size.y]
		if DisplayServer.get_name() == "headless":
			if tab_index == 0:
				dump_lines.append("- screenshots skipped (headless); rect dump authoritative")
		else:
			var image := viewport.get_texture().get_image()
			if image != null:
				image.save_png(output_path)
				dump_lines.append("- screenshot: `%s`" % output_path)
		dump_lines.append("### tab %s" % TAB_SLUGS[tab_index])
		dump_lines.append("| node | global rect |")
		dump_lines.append("| --- | --- |")
		for node_name in DUMP_NODES:
			var node := main.find_child(node_name, true, false) as Control
			if node != null and node.is_visible_in_tree():
				dump_lines.append("| `%s` | `%s` |" % [node_name, str(node.get_global_rect())])
		dump_lines.append("")
	main.queue_free()
	viewport.queue_free()
	await process_frame
