extends SceneTree

## SCRUM-1073 compact Event typography geometry evidence.
## Runs windowed: exact lower-zone/card containment assertions + PNG captures.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const VIEWPORT_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720)]
const OUTPUT_DIR := "res://docs/design/previews/scrum1073_semantic_band_migration"
const EPSILON := 1.5


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("SCRUM-1073 geometry capture requires a windowed renderer.")
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	var report := PackedStringArray([
		"# SCRUM-1073 compact Event geometry",
		"",
		"The lower content zone grows upward; its viewport margin and separation",
		"from the dialogue panel remain explicit acceptance constraints.",
		"",
	])
	for viewport_size in VIEWPORT_SIZES:
		var error := await _capture(viewport_size, absolute, report)
		if error != "":
			push_error(error)
			quit(1)
			return
	var file := FileAccess.open("%s/compact_event_geometry.md" % absolute, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write SCRUM-1073 geometry report.")
		quit(1)
		return
	file.store_string("\n".join(report))
	file.close()
	print("SCRUM-1073 compact Event geometry capture passed at 1152x648 and 1280x720.")
	quit(0)


func _capture(viewport_size: Vector2i, absolute: String, report: PackedStringArray) -> String:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", 137)
	main.combat._store_player_snapshot(player)
	player.queue_free()
	main.ui._show_event_screen({"type": "event", "name": "Событие", "event_id": "sudden_fork"})
	for _frame in range(12):
		await process_frame

	var margin := roundf(clampf(float(viewport_size.y) * 0.025, 12.0, 36.0))
	var gap := roundf(clampf(float(viewport_size.x) * 0.012, 10.0, 32.0))
	var card_width := floorf((float(viewport_size.x) - 2.0 * margin - 260.0 - 3.0 * gap) / 3.0)
	var expected_row := Rect2(margin, float(viewport_size.y) - margin - 176.0, card_width * 3.0 + gap * 2.0, 176.0)
	var row := main.find_child("EventChoiceRow", true, false) as Control
	var panel := main.find_child("MenuPanel_event", true, false) as Control
	var back := main.find_child("EventBackButton", true, false) as Control
	if row == null or panel == null or back == null:
		return "SCRUM-1073 %s: missing Event row/panel/back." % str(viewport_size)
	if not _rect_matches(row.get_global_rect(), expected_row):
		return "SCRUM-1073 %s: expected row %s, got %s." % [str(viewport_size), str(expected_row), str(row.get_global_rect())]
	if row.get_global_rect().intersects(panel.get_global_rect()) or back.get_global_rect().intersects(panel.get_global_rect()):
		return "SCRUM-1073 %s: compact lower zone overlaps dialogue panel." % str(viewport_size)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(-margin)
	if not viewport_rect.grow(EPSILON).encloses(row.get_global_rect()) or not viewport_rect.grow(EPSILON).encloses(back.get_global_rect()):
		return "SCRUM-1073 %s: lower controls enter the viewport/frame margin." % str(viewport_size)
	for node in main.find_children("EventChoiceButton*", "Button", true, false):
		var card := node as Button
		if card == null or not card.visible:
			continue
		if not row.get_global_rect().grow(EPSILON).encloses(card.get_global_rect()):
			return "SCRUM-1073 %s: %s escapes the exact lower row." % [str(viewport_size), str(card.name)]
		for suffix in ["Title", "Description", "Hint", "Action"]:
			var label := card.find_child("%s%s" % [card.name, suffix], true, false) as Control
			if label != null and not card.get_global_rect().grow(EPSILON).encloses(label.get_global_rect()):
				return "SCRUM-1073 %s: %s%s escapes card content geometry." % [str(viewport_size), str(card.name), suffix]

	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return "SCRUM-1073 %s: renderer returned an empty capture." % str(viewport_size)
	var output := "%s/compact_event_%dx%d.png" % [absolute, viewport_size.x, viewport_size.y]
	if image.save_png(output) != OK:
		return "SCRUM-1073 %s: failed to save capture." % str(viewport_size)
	report.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	report.append("")
	report.append("- Expected lower content zone: `%s`" % str(expected_row))
	report.append("- Runtime lower content zone: `%s`" % str(row.get_global_rect()))
	report.append("- Dialogue panel: `%s`" % str(panel.get_global_rect()))
	report.append("- Back action: `%s`" % str(back.get_global_rect()))
	report.append("- Verdict: PASS — exact rect, viewport margin and all text lanes contained.")
	report.append("")
	main.queue_free()
	viewport.queue_free()
	await process_frame
	return ""


func _rect_matches(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= EPSILON and actual.size.distance_to(expected.size) <= EPSILON
