extends SceneTree

## SCRUM-879: снимает 4 унифицированных экрана (выбор героя / настройки /
## кодекс / релиз-ноты) на 1920×1080 и 2560×1440.
## Run (windowed для PNG): Godot --path . --script res://tools/capture_atlas_style_screens.gd
## Output: build/qa/scrum879/atlas_style_<screen>_<WxH>.png + rects.md

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const SCREENS := [
	{
		"slug": "hero_select",
		"nodes": ["HeroSelectScreen", "HS4TitleChip", "HS4PortraitFrame", "HS4DossierFrame",
			"HS4AscensionFrame", "HS4Carousel", "HS4ChooseButton", "HS4BackButton",
			"HeroSelectFrame", "UnifiedBackground_hero_select"],
	},
	{
		"slug": "settings",
		"nodes": ["SettingsSafeArea", "SettingsFrame", "SettingsHeader",
			"SettingsTitleChip", "SettingsTabSwitcher",
			"SettingsTabButton_0", "SettingsContentPanel", "SettingsBottomActions",
			"SettingsApplyButton", "SettingsRevertButton", "SettingsBackButton",
			"UnifiedBackground_settings"],
	},
	{
		"slug": "codex",
		"nodes": ["CodexScreen", "CodexTitleChip", "CodexNavPanel", "CodexContent",
			"CodexDetailPanel", "CodexBackButton", "CodexTab_characters",
			"CodexFrame", "UnifiedBackground_codex"],
	},
	{
		"slug": "patch_notes",
		"nodes": ["PatchNotesScreen", "PatchNotesTitleChip", "PatchNotesPanel",
			"PatchNotesBackButton", "PatchNotesFrame", "UnifiedBackground_patch_notes"],
	},
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum879")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-879 Atlas-style screens capture")
	dump_lines.append("")
	for viewport_size in VIEWPORT_SIZES:
		await _capture_at_size(viewport_size, qa_dir, dump_lines)
	var file := FileAccess.open("%s/atlas_style_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	print("Atlas-style screens capture done.")
	quit(0)


func _show_screen(main: Node, slug: String) -> void:
	match slug:
		"hero_select":
			main.call("_show_character_select")
		"settings":
			main.call("_show_settings_menu")
		"codex":
			main.get("ui").call("_show_codex_screen")
		"patch_notes":
			main.get("ui").call("_show_patch_notes_screen")


func _capture_at_size(viewport_size: Vector2i, qa_dir: String, dump_lines: PackedStringArray) -> void:
	dump_lines.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	for screen in SCREENS:
		var slug := str(screen["slug"])
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		await process_frame
		var main := MAIN_SCENE.instantiate()
		viewport.add_child(main)
		await process_frame
		_show_screen(main, slug)
		for _i in range(8):
			await process_frame
		var output_path := "%s/atlas_style_%s_%dx%d.png" % [qa_dir, slug, viewport_size.x, viewport_size.y]
		if DisplayServer.get_name() == "headless":
			if slug == "hero_select":
				dump_lines.append("- screenshots skipped (headless); rect dump authoritative")
		else:
			var image := viewport.get_texture().get_image()
			if image != null:
				image.save_png(output_path)
				dump_lines.append("- screenshot: `%s`" % output_path)
		dump_lines.append("### %s" % slug)
		dump_lines.append("| node | global rect |")
		dump_lines.append("| --- | --- |")
		for node_name in screen["nodes"]:
			var node := main.find_child(str(node_name), true, false) as Control
			if node != null and node.is_visible_in_tree():
				dump_lines.append("| `%s` | `%s` |" % [node_name, str(node.get_global_rect())])
		dump_lines.append("")
		main.queue_free()
		viewport.queue_free()
		await process_frame
