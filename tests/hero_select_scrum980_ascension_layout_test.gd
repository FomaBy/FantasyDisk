extends SceneTree

# SCRUM-1063 supersedes SCRUM-980/1026's visible modifier-scroll lane. Keep this
# historical focused path as a regression oracle for the new tooltip-only,
# centered wide-control contract across every selectable level.
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORTS:
		await _check_viewport(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1063 tooltip-only Ascension layout regression passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	var unlocked := {}
	for character_id in PROGRESSION_DATA.character_ids():
		unlocked[str(character_id)] = 4
	var state: Dictionary = main.get("meta_state")
	state["ascension_levels"] = unlocked
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	for _frame_index in range(7):
		await process_frame

	var context := "Hero Select %s" % str(viewport_size)
	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var row := main.find_child("HS4AscensionActionRow", true, false) as Control
	var minus := main.find_child("AscensionMinusButton", true, false) as Button
	var value := main.find_child("HS4AscensionValue", true, false) as Label
	var plus := main.find_child("AscensionPlusButton", true, false) as Button
	var description := main.find_child("AscensionModsLabel", true, false) as Label
	var description_scroll := main.find_child("HS4AscensionDescriptionScroll", true, false) as ScrollContainer
	var carousel := main.find_child("HS4CarouselFrame", true, false) as Control
	var dossier := main.find_child("HS4DossierFrame", true, false) as Control
	var choose := main.find_child("HS4ChooseButton", true, false) as Control
	if ascension == null or row == null or minus == null or value == null or plus == null \
			or description == null or description_scroll == null or carousel == null \
			or dossier == null or choose == null:
		errors.append("%s: missing Ascension/major controls." % context)
		await _teardown(viewport)
		return

	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(1.0)
	var asc_rect := ascension.get_global_rect()
	if not viewport_rect.encloses(asc_rect) or not asc_rect.grow(1.0).encloses(row.get_global_rect()):
		errors.append("%s: Ascension frame/row escapes viewport or parent." % context)
	for peer in [carousel, dossier, choose]:
		if asc_rect.grow(-1.0).intersects((peer as Control).get_global_rect().grow(-1.0)):
			errors.append("%s: Ascension overlaps %s." % [context, (peer as Control).name])
	if description.visible or description_scroll.visible or description_scroll.focus_mode != Control.FOCUS_NONE:
		errors.append("%s: superseded visible modifier/scroll lane remains active." % context)
	if minus.get_global_rect().size.distance_to(plus.get_global_rect().size) > 0.5:
		errors.append("%s: Ascension controls are not the same size." % context)
	var midpoint := (minus.get_global_rect().get_center().x + plus.get_global_rect().get_center().x) * 0.5
	if absf(value.get_global_rect().get_center().x - midpoint) > 1.0:
		errors.append("%s: Ascension value is not centered between controls." % context)

	var max_level := int(main.call("ascension_selectable_max", "berserk"))
	for level in range(max_level, -1, -1):
		await _assert_level(main, ascension, minus, value, plus, level, max_level, context)
		if level > 0:
			minus.pressed.emit()
			await process_frame
	for level in range(1, max_level + 1):
		plus.pressed.emit()
		await process_frame
		await _assert_level(main, ascension, minus, value, plus, level, max_level, context)

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for teardown_error in teardown_errors:
		errors.append("%s teardown: %s" % [context, teardown_error])


func _assert_level(
	main: Node,
	ascension: Control,
	minus: Button,
	value: Label,
	plus: Button,
	level: int,
	max_level: int,
	context: String
) -> void:
	await process_frame
	if int(main.get("selected_ascension_level")) != level:
		errors.append("%s level %d: selected %s." % [context, level, str(main.get("selected_ascension_level"))])
	if value.text != "Возвышение %d" % level or value.text.contains("/"):
		errors.append("%s level %d: invalid visible copy `%s`." % [context, level, value.text])
	var tooltip := ascension.tooltip_text
	if tooltip.strip_edges() == "" or value.tooltip_text != tooltip or minus.tooltip_text != tooltip or plus.tooltip_text != tooltip:
		errors.append("%s level %d: cumulative tooltip is not unified." % [context, level])
	if minus.disabled != (level <= 0) or plus.disabled != (level >= max_level):
		errors.append("%s level %d: disabled states are incorrect." % [context, level])


func _teardown(viewport: SubViewport) -> void:
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for teardown_error in teardown_errors:
		errors.append("teardown: %s" % teardown_error)


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--user-data-dir="):
			requested = value.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1063 Ascension regression requires isolated user-data.")
		return false
	return true
