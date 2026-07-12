extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const META_PROGRESSION := preload("res://scripts/meta_progression.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2048, 1152),
	Vector2i(2560, 1440),
]

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	_check_roster_titles()
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	print("SCRUM-971 Atlas selected-class label test passed.")
	quit(0)


func _check_roster_titles() -> void:
	var class_ids: Array = META_PROGRESSION.constellation_class_ids()
	if class_ids.size() != 17:
		_fail("Expected 17 Atlas classes, got %d." % class_ids.size())
		return
	for raw_class_id in class_ids:
		var class_id := str(raw_class_id)
		var title := str(PROGRESSION_DATA.character_config(class_id).get("title", "")).strip_edges()
		if title.is_empty() or title == class_id or title.contains("res://") or title.contains("TODO"):
			_fail("Class %s has no valid localized title: '%s'." % [class_id, title])
			return


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.ui._show_atlas_screen()
	for _frame_index in range(8):
		await process_frame

	var label := main.find_child("AtlasSelectedClassLabel", true, false) as Label
	var center_column := main.find_child("AtlasCenterColumn", true, false) as VBoxContainer
	var canvas := main.find_child("AtlasCanvas", true, false) as Control
	var header := main.find_child("AtlasHeader", true, false) as Control
	var class_strip := main.find_child("AtlasClassStrip", true, false) as Control
	var dossier := main.find_child("AtlasNodePanel", true, false) as Control
	var footer := main.find_child("AtlasFooter", true, false) as Control
	var layout := main.find_child("AtlasLayout", true, false) as Control
	if label == null or center_column == null or canvas == null or header == null or class_strip == null or dossier == null or footer == null or layout == null:
		_fail("Missing SCRUM-971 Atlas controls at %s." % str(viewport_size))
		return
	if label.get_parent() != center_column or canvas.get_parent() != center_column:
		_fail("Selected-class label and Atlas canvas do not share the responsive center column at %s." % str(viewport_size))
		return
	if label.mouse_filter != Control.MOUSE_FILTER_IGNORE or label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		_fail("Selected-class label is not a centered pointer-pass-through native Label at %s." % str(viewport_size))
		return
	if label.get_parent() is PanelContainer or label.get_child_count() != 0:
		_fail("Selected-class label gained a heavy frame/decorative child at %s." % str(viewport_size))
		return

	var expected_initial := str(PROGRESSION_DATA.character_config("berserk").get("title", ""))
	if label.text != expected_initial:
		_fail("Initial selected-class title is '%s', expected '%s' at %s." % [label.text, expected_initial, str(viewport_size)])
		return
	_check_layout_rects(label, center_column, canvas, header, class_strip, dossier, footer, layout, viewport_size, false)

	# The medallion handler is synchronous: player-facing text must change in the
	# same input dispatch, without reopening Atlas or waiting for a resize pass.
	for raw_class_id in META_PROGRESSION.constellation_class_ids():
		var class_id := str(raw_class_id)
		var medallion := main.find_child("AtlasMedallion_%s" % class_id, true, false) as TextureButton
		if medallion == null:
			_fail("Missing Atlas medallion for %s at %s." % [class_id, str(viewport_size)])
			return
		medallion.pressed.emit()
		var expected_title := str(PROGRESSION_DATA.character_config(class_id).get("title", ""))
		if label.text != expected_title:
			_fail("Medallion %s did not update selected-class title immediately at %s: '%s'." % [class_id, str(viewport_size), label.text])
			return

	main.ui._atlas_switch_tab("guild")
	for _frame_index in range(8):
		await process_frame
	var selected_id := str(main.ui._atlas.get("class_id", ""))
	var expected_guild_title := str(PROGRESSION_DATA.character_config(selected_id).get("title", ""))
	if label.text != expected_guild_title or not label.is_visible_in_tree():
		_fail("Guild tab lost the selected class '%s' at %s." % [expected_guild_title, str(viewport_size)])
		return
	_check_layout_rects(label, center_column, canvas, header, class_strip, dossier, footer, layout, viewport_size, true)

	if DisplayServer.get_name() != "headless":
		var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum971")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/atlas_selected_class_guild_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_fail("SCRUM-971 viewport teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])


func _check_layout_rects(
	label: Label,
	center_column: VBoxContainer,
	canvas: Control,
	header: Control,
	class_strip: Control,
	dossier: Control,
	footer: Control,
	layout: Control,
	viewport_size: Vector2i,
	on_guild: bool,
) -> void:
	var context := "%s %s" % ["Guild" if on_guild else "Constellation", str(viewport_size)]
	var label_rect := label.get_global_rect()
	if label_rect.size.x < 120.0 or label_rect.size.y < 24.0:
		_fail("%s selected-class label is not compact/readable: %s." % [context, str(label_rect)])
		return
	if not center_column.get_global_rect().grow(1.0).encloses(label_rect):
		_fail("%s selected-class label escaped its center column." % context)
		return
	if not layout.get_global_rect().grow(1.0).encloses(label_rect):
		_fail("%s selected-class label escaped the frame-safe Atlas layout." % context)
		return
	for pair in [["header", header], ["canvas", canvas], ["dossier", dossier], ["footer", footer]]:
		var control := pair[1] as Control
		if label_rect.intersects(control.get_global_rect(), true):
			_fail("%s selected-class label overlaps %s: label=%s other=%s." % [context, pair[0], str(label_rect), str(control.get_global_rect())])
			return
	if not on_guild and label_rect.intersects(class_strip.get_global_rect(), true):
		_fail("%s selected-class label overlaps the class selector." % context)
		return
	if on_guild and class_strip.visible:
		_fail("%s class selector unexpectedly remained visible." % context)


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/":
		push_error("SCRUM-971 test refuses the default user://; pass -- --user-data-dir=<unique scratch root> and isolate HOME/XDG_DATA_HOME.")
		return false
	if not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-971 scratch mismatch: user:// resolves to %s outside requested %s." % [actual, requested])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
