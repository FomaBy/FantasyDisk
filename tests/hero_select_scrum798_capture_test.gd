extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1536, 864),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const HEROES := ["berserk", "dark_mage", "guitarist", "priest"]
const QA_DIR := "res://build/qa/scrum-798"
const PREVIEW_MIN_SIZE := 320.0
const SLOT_MIN_SIZE := 180.0


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path(QA_DIR)
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump := PackedStringArray()
	dump.append("# SCRUM-798 Hero Select Runtime Evidence")
	dump.append("")
	for viewport_size in VIEWPORTS:
		for hero_id in HEROES:
			await _capture_layout(viewport_size, hero_id, dump)
	var file := FileAccess.open("%s/hero_select_scrum798_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump))
		file.close()
	print("SCRUM-798 Hero Select capture evidence written to %s." % qa_dir)
	quit(0)


func _capture_layout(viewport_size: Vector2i, hero_id: String, dump: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", hero_id)
	main.call("_show_character_select")
	await process_frame
	await process_frame

	var context := "%s %s" % [hero_id, str(viewport_size)]
	var portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	var portrait_frame := main.find_child("HS4PortraitFrame", true, false) as Control
	var dossier := main.find_child("HS4DossierFrame", true, false) as Control
	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var choose := main.find_child("HS4ChooseButton", true, false) as Control
	var carousel := main.find_child("HS4Carousel", true, false) as Control
	if portrait == null or portrait_frame == null or dossier == null or ascension == null or choose == null or carousel == null:
		_fail("Missing core Hero Select SCRUM-798 nodes at %s." % context)
		return

	var portrait_rect := portrait_frame.get_global_rect()
	var dossier_rect := dossier.get_global_rect()
	var asc_rect := ascension.get_global_rect()
	var choose_rect := choose.get_global_rect()
	var carousel_rect := carousel.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(1.0)
	for control in [portrait_frame, dossier, ascension, choose, carousel]:
		var rect := (control as Control).get_global_rect()
		if not viewport_rect.encloses(rect):
			_fail("Expected %s to stay in viewport at %s, got %s." % [(control as Control).name, context, rect])
			return
	if portrait_rect.size.x < PREVIEW_MIN_SIZE or portrait_rect.size.y < PREVIEW_MIN_SIZE:
		_fail("Expected enlarged preview at %s, got %s." % [context, portrait_rect])
		return
	var slots := _visible_slots(carousel)
	if slots.size() < 3:
		_fail("Expected at least 3 carousel slots at %s, got %d." % [context, slots.size()])
		return
	var first_slot := slots[0] as Control
	if first_slot.get_global_rect().size.x < SLOT_MIN_SIZE or first_slot.get_global_rect().size.y < SLOT_MIN_SIZE:
		_fail("Expected enlarged carousel slot at %s, got %s." % [context, first_slot.get_global_rect()])
		return
	for pair in [[portrait_rect, dossier_rect], [portrait_rect, carousel_rect], [dossier_rect, carousel_rect], [asc_rect, carousel_rect], [portrait_rect, asc_rect]]:
		if (pair[0] as Rect2).grow(-2.0).intersects((pair[1] as Rect2).grow(-2.0)):
			_fail("Unexpected Hero Select overlap at %s: %s vs %s." % [context, pair[0], pair[1]])
			return
	for stat_id in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
		var stat_button := main.find_child("HS4Stat_%s" % stat_id, true, false) as Button
		var stat_fill := main.find_child("HS4StatBarFill_%s" % stat_id, true, false) as ColorRect
		if stat_button == null or stat_fill == null or not stat_button.tooltip_text.contains(" — ") or stat_button.tooltip_text.contains("Формула:"):
			_fail("Expected concise stat line bar tooltip for %s at %s." % [stat_id, context])
			return
	for relevance in ["primary", "secondary", "optional"]:
		var label := main.find_child("HS4BuildGuidance_%s" % relevance, true, false) as Label
		if label == null or label.text.strip_edges() == "":
			_fail("Expected build guidance %s at %s." % [relevance, context])
			return

	dump.append("## %s" % context)
	dump.append("- `HS4PortraitFrame`: `%s`")
	dump[dump.size() - 1] = dump[dump.size() - 1] % str(portrait_rect)
	dump.append("- `HS4Portrait`: `%s`" % str(portrait.get_global_rect()))
	dump.append("- `HS4DossierFrame`: `%s`" % str(dossier_rect))
	dump.append("- `HS4AscensionFrame`: `%s`" % str(asc_rect))
	dump.append("- `HS4ChooseButton`: `%s`" % str(choose_rect))
	dump.append("- `HS4Carousel`: `%s`" % str(carousel_rect))
	dump.append("- `HeroThumbnailSample`: `%s`, visible slots `%d`" % [str(first_slot.get_global_rect()), slots.size()])
	for relevance in ["primary", "secondary", "optional"]:
		var label := main.find_child("HS4BuildGuidance_%s" % relevance, true, false) as Label
		dump.append("- `%s`: `%s`" % [label.name, label.text])
	dump.append("")

	var image: Image = null
	if DisplayServer.get_name() != "headless":
		image = viewport.get_texture().get_image()
	if image != null:
		image.save_png("%s/hero_select_%s_%dx%d.png" % [ProjectSettings.globalize_path(QA_DIR), hero_id, viewport_size.x, viewport_size.y])
	else:
		dump.append("- screenshot: unavailable from headless dummy renderer")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _visible_slots(carousel: Control) -> Array:
	var out := []
	if carousel == null:
		return out
	for child in carousel.get_children():
		var slot := child as Button
		if slot != null and slot.visible and slot.name.begins_with("HS4CarouselSlot_"):
			out.append(slot)
	return out


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
