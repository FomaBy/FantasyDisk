extends "res://tests/runtime_smoke_test.gd"

# Regression coverage for SCRUM-680: the main-menu title logo must sit above the
# action buttons without intersecting any of them. The pre-existing
# ui_no_overlap_matrix_test.gd did not cover title-vs-menu intersections.


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for title-overlap test.")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var title := main.find_child("MainMenuTitleLabel", true, false) as Control
	if title == null:
		_fail("MainMenuTitleLabel node not found in main menu.")
		main.queue_free()
		return

	var actions := main.find_child("MainMenuActions", true, false) as Control
	if actions == null:
		_fail("MainMenuActions container not found in main menu.")
		main.queue_free()
		return

	var title_rect := title.get_global_rect()
	var checked := 0
	for child in actions.get_children():
		if child is Control:
			var btn_rect := (child as Control).get_global_rect()
			checked += 1
			if title_rect.intersects(btn_rect):
				_fail("Title logo %s overlaps menu button %s (%s vs %s)." % [
					str(title_rect), str(child.name), str(title_rect), str(btn_rect)])
				main.queue_free()
				return
			if title_rect.position.y + title_rect.size.y > btn_rect.position.y:
				_fail("Title logo bottom %.1f is below button %s top %.1f." % [
					title_rect.position.y + title_rect.size.y, str(child.name), btn_rect.position.y])
				main.queue_free()
				return

	if checked == 0:
		_fail("No menu buttons found to validate title overlap.")
		main.queue_free()
		return

	main.queue_free()
	await process_frame
	print("Main menu title no-overlap test passed (%d buttons clear of logo)." % checked)
	quit()
