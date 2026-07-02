extends "res://tests/runtime_smoke_test.gd"

# Regression coverage for SCRUM-680: the main-menu title logo must sit above the
# action buttons without intersecting any of them. The pre-existing
# ui_no_overlap_matrix_test.gd did not cover title-vs-menu intersections.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGET_VIEWPORTS := [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(1080, 1920),
]


func _initialize() -> void:
	var total_checked := 0
	var dump_lines := PackedStringArray()
	dump_lines.append("# Main Menu Title No-Overlap")
	dump_lines.append("")
	for viewport_size in TARGET_VIEWPORTS:
		var checked := await _validate_main_menu_size(viewport_size, dump_lines)
		if checked < 0:
			return
		total_checked += checked

	var qa_dir := ProjectSettings.globalize_path("res://build/qa/main_menu_logo_release_fix")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_file := FileAccess.open("%s/title_no_overlap_rects.md" % qa_dir, FileAccess.WRITE)
	if dump_file != null:
		dump_file.store_string("\n".join(dump_lines))
		dump_file.close()

	print("Main menu title no-overlap test passed (%d button checks across %d viewports)." % [
		total_checked, TARGET_VIEWPORTS.size(),
	])
	quit()


func _validate_main_menu_size(viewport_size: Vector2i, dump_lines: PackedStringArray) -> int:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	main.ui._show_main_menu()
	await process_frame
	await process_frame

	var title := main.find_child("MainMenuTitleLabel", true, false) as Control
	if title == null:
		_fail("MainMenuTitleLabel node not found in main menu at %s." % [str(viewport_size)])
		main.queue_free()
		viewport.queue_free()
		return -1

	var actions := main.find_child("MainMenuActions", true, false) as Control
	if actions == null:
		_fail("MainMenuActions container not found in main menu at %s." % [str(viewport_size)])
		main.queue_free()
		viewport.queue_free()
		return -1

	var title_rect := title.get_global_rect()
	dump_lines.append("## %s" % str(viewport_size))
	dump_lines.append("- MainMenuTitleLabel: `%s`" % str(title_rect))
	var checked := 0
	for child in actions.get_children():
		if child is Control:
			var btn_rect := (child as Control).get_global_rect()
			var gap := btn_rect.position.y - (title_rect.position.y + title_rect.size.y)
			dump_lines.append("- %s: `%s`, gap=%.1f" % [str(child.name), str(btn_rect), gap])
			checked += 1
			if title_rect.intersects(btn_rect):
				_fail("%s: title logo overlaps menu button %s (%s vs %s)." % [
					str(viewport_size), str(child.name), str(title_rect), str(btn_rect)])
				main.queue_free()
				viewport.queue_free()
				return -1
			if title_rect.position.y + title_rect.size.y > btn_rect.position.y:
				_fail("%s: title logo bottom %.1f is below button %s top %.1f." % [
					str(viewport_size), title_rect.position.y + title_rect.size.y, str(child.name), btn_rect.position.y])
				main.queue_free()
				viewport.queue_free()
				return -1

	if checked == 0:
		_fail("No menu buttons found to validate title overlap at %s." % [str(viewport_size)])
		main.queue_free()
		viewport.queue_free()
		return -1

	main.queue_free()
	viewport.queue_free()
	await process_frame
	return checked
