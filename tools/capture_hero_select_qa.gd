extends SceneTree

## Captures the Hero Select screen for Hero Select visual QA.
## Run: Godot --headless --path . --script res://tools/capture_hero_select_qa.gd
## Output: build/qa/scrum281/hero_select_*.png

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum281")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-281 Hero Select QA Capture")
	dump_lines.append("")
	for viewport_size in VIEWPORT_SIZES:
		await _capture_at_size(viewport_size, qa_dir, dump_lines)
	var file := FileAccess.open("%s/hero_select_capture_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
		print("Hero Select QA capture updated.")
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
	main.call("_show_character_select")
	for _i in range(8):
		await process_frame

	var output_path := "%s/hero_select_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y]
	dump_lines.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	if DisplayServer.get_name() == "headless":
		dump_lines.append("- screenshot: skipped in headless dummy renderer; rect dump below is authoritative for layout QA.")
	else:
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png(output_path)
			dump_lines.append("- screenshot: `%s`" % output_path)
		else:
			dump_lines.append("- screenshot: unavailable")
	for node_name in [
		"HeroSelectHeader",
		"HeroSelectBackButton",
			"HeroSelectContent",
			"HeroSelectPortraitPanel",
			"HeroSelectPortraitFrame",
			"HeroSelectPortraitFrameArt",
			"HeroSelectPortraitContent",
			"HeroSelectLargePortrait",
			"HeroSelectRightRegion",
			"HeroSelectDossierPanel",
			"HeroSelectDossierFrame",
			"HeroSelectDossierFrameArt",
			"HeroSelectDossierContent",
			"HeroSelectDossier",
			"HeroSelectInfoTitle",
			"HeroSelectInfoDescription",
			"HeroSelectTraits",
			"HeroSelectWeapons",
			"AscensionSelectorRow",
			"AscensionMinusButton",
			"AscensionLevelLabel",
			"AscensionPlusButton",
			"AscensionModsLabel",
			"HeroSelectChooseButton",
			"HeroSelectRadarReserve",
			"HeroSelectRadarPanel",
			"HeroSelectRadarFrameArt",
			"HeroSelectRadarContent",
			"HeroStatRadarTitle",
			"HeroStatRadar",
			"HeroThumbnailStripFrame",
		"HeroThumbnailStripContent",
		"HeroThumbnailStrip",
		"HeroThumbnail_berserk",
		"HeroThumbnail_thief",
	]:
		var control := main.find_child(node_name, true, false) as Control
		if control != null:
			dump_lines.append("- `%s`: rect=`%s`, min=`%s`" % [node_name, str(control.get_global_rect()), str(control.custom_minimum_size)])
	viewport.queue_free()
	await process_frame
