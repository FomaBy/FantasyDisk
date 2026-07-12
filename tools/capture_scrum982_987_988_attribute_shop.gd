extends SceneTree

## Persistent renderer evidence for combined SCRUM-982/987/988. Run windowed
## through tools/godot_gate.py; the script writes three Atlas-offer captures and
## a geometry report into the committed design preview folder.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const TARGETS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	var output_dir := ProjectSettings.globalize_path("res://docs/design/previews/scrum982_987_988_attribute_shop/runtime")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := PackedStringArray(["# SCRUM-982/987/988 Attribute Shop Runtime Matrix", ""])
	for viewport_size in TARGETS:
		await _capture(viewport_size, output_dir, report)
	await _capture_teardown.release_windowed_audio(self)
	var report_file := FileAccess.open("%s/runtime_matrix.md" % output_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report))
		report_file.close()
	if _errors.is_empty():
		print("SCRUM-982/987/988 Attribute Shop runtime capture completed.")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _capture(viewport_size: Vector2i, output_dir: String, report: PackedStringArray) -> void:
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
	main.set("meta_state", {"skill_nodes": ["atlas_n2"]})
	main.set("attribute_offer", ["agility", "endurance", "leadership"])
	main.set("attribute_rerolls_left", 2)
	var player := PLAYER_SCENE.instantiate()
	viewport.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", 9999)
	main.call("_store_player_snapshot", player)
	player.queue_free()
	main.ui._show_attribute_shop(Callable())
	for _frame in range(12):
		await process_frame
	var screen := main.find_child("AttributeShopScreen", true, false) as Control
	var offers := main.find_child("AttributeOffers", true, false) as HBoxContainer
	var actions := main.find_child("AttributeShopActions", true, false) as HBoxContainer
	var first := offers.get_child(0) as Button if offers != null and offers.get_child_count() > 0 else null
	if first != null:
		first.grab_focus()
	for _frame in range(4):
		await process_frame
	report.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	report.append("- inner: `%s`" % str(screen.get_meta("gold_shell_inner_rect", Rect2()) if screen != null else Rect2()))
	report.append("- offers: `%s`, count=%d" % [str(offers.get_global_rect() if offers != null else Rect2()), offers.get_child_count() if offers != null else 0])
	report.append("- actions: `%s`" % str(actions.get_global_rect() if actions != null else Rect2()))
	if offers != null:
		for child in offers.get_children():
			var card := child as Button
			if card != null:
				report.append("- %s: `%s`, content=`%s`" % [card.name, str(card.get_global_rect()), str(card.get_meta("attribute_content_rect", Rect2()))])
	report.append("")
	if DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/atlas_three_offers_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y])
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for error in teardown_errors:
		_errors.append("%dx%d: %s" % [viewport_size.x, viewport_size.y, error])
		report.append("- lifecycle error: `%s`" % error)
