extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const Meta := preload("res://scripts/meta_progression.gd")
const TEST_PATH := "user://test_codex_unread_victory.cfg"
const BADGE_PATH := "res://assets/sprites/ui/icons/codex/ui_badge_codex_unread.png"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var errors := PackedStringArray()


func _initialize() -> void:
	_cleanup()
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	_cleanup()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("FAN-1077 Codex unread/victory test passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var context := "FAN-1077 %dx%d" % [viewport_size.x, viewport_size.y]
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.meta_save_path = TEST_PATH
	main.meta_state = Meta.default_state()
	main.reset_run_metrics()
	if not main.record_future_codex_unlock("characters", "druid", "Друид"):
		errors.append("%s: future character unlock API rejected canonical content." % context)
	if not main.record_future_codex_unlock("weapons", "summon_amulet", "Амулет призыва", "druid"):
		errors.append("%s: future weapon unlock API rejected canonical content." % context)
	if main.record_future_codex_unlock("weapons", "summon_amulet", "Амулет призыва", "druid"):
		errors.append("%s: future weapon unlock API accepted a duplicate." % context)
	main.record_codex_artifact_discovery({"kind": "artifact", "id": "rift_key", "title": "Ключ Разлома"})

	main.ui._show_main_menu()
	await _frames(3)
	var menu_badge := main.find_child("MainMenuCodexUnreadBadge", true, false) as TextureRect
	_expect_badge(menu_badge, "%s main-menu" % context)
	var codex_button := main.find_child("MainMenuCodexButton", true, false) as Button
	if menu_badge != null and codex_button != null:
		_expect_inside(menu_badge.get_global_rect(), codex_button.get_global_rect(), "%s main-menu badge" % context)
	_save_screenshot(viewport, "main_menu", viewport_size)

	main.ui._show_codex_screen()
	await _frames(4)
	var character_list := main.find_child("CodexSectionList_characters", true, false) as VBoxContainer
	var first_character := character_list.get_child(0) as Button if character_list != null and character_list.get_child_count() > 0 else null
	if first_character == null or str(first_character.get_meta("codex_entry_id", "")) != "druid":
		errors.append("%s: unread character/weapon owner did not sort first." % context)
	else:
		_expect_badge(first_character.get_node_or_null("CodexUnreadBadge") as TextureRect, "%s character row" % context)
	var character_tab_badge := main.find_child("CodexTabUnreadBadge_characters", true, false) as TextureRect
	_expect_badge(character_tab_badge, "%s character tab" % context)

	var artifact_tab := main.find_child("CodexTab_artifacts", true, false) as Button
	if artifact_tab != null:
		artifact_tab.pressed.emit()
	await _frames(3)
	var artifact_list := main.find_child("CodexSectionList_artifacts", true, false) as VBoxContainer
	var first_artifact := artifact_list.get_child(0) as Button if artifact_list != null and artifact_list.get_child_count() > 0 else null
	if first_artifact == null or str(first_artifact.get_meta("codex_entry_id", "")) != "rift_key":
		errors.append("%s: unread artifact did not sort first." % context)
	else:
		var entry_badge := first_artifact.get_node_or_null("CodexUnreadBadge") as TextureRect
		_expect_badge(entry_badge, "%s artifact row" % context)
		if entry_badge != null:
			_expect_inside(entry_badge.get_global_rect(), first_artifact.get_global_rect(), "%s entry badge" % context)
		_save_screenshot(viewport, "codex_unread", viewport_size)
		first_artifact.pressed.emit()
		await _frames(2)
		if Meta.is_codex_unread(main.meta_state, "artifacts", "rift_key"):
			errors.append("%s: explicit artifact open did not clear unread state." % context)
		var persisted := Meta.load_state(TEST_PATH)
		if Meta.is_codex_unread(persisted, "artifacts", "rift_key"):
			errors.append("%s: cleared artifact unread state was not persisted." % context)
		if entry_badge != null and entry_badge.visible:
			errors.append("%s: read artifact badge remained visible." % context)
	var artifact_tab_badge := main.find_child("CodexTabUnreadBadge_artifacts", true, false) as TextureRect
	if artifact_tab_badge != null and artifact_tab_badge.visible:
		errors.append("%s: artifact tab badge remained after its last unread entry was opened." % context)

	var run_unlocks: Array = main.run_metrics.get("new_unlocks", []) as Array
	if run_unlocks.size() != 3:
		errors.append("%s: run-local unlock journal dedupe/order API produced %d rows." % [context, run_unlocks.size()])
	main.ui._show_victory_screen()
	await _frames(4)
	var unlock_panel := main.find_child("VictoryUnlockPanel", true, false) as PanelContainer
	var unlock_scroll := main.find_child("VictoryUnlockScroll", true, false) as ScrollContainer
	var unlock_list := main.find_child("VictoryUnlockList", true, false) as VBoxContainer
	var summary := main.find_child("RunSummaryColumn_victory", true, false) as VBoxContainer
	if unlock_panel == null or unlock_scroll == null or unlock_list == null:
		errors.append("%s: victory unlock journal is incomplete." % context)
	else:
		if unlock_list.get_child_count() != 3:
			errors.append("%s: victory journal has %d rows, expected 3." % [context, unlock_list.get_child_count()])
		if summary != null:
			_expect_inside(unlock_panel.get_global_rect(), summary.get_global_rect(), "%s victory unlock panel" % context)
		var labels := PackedStringArray()
		for child in unlock_list.get_children():
			var label := child.find_child("VictoryUnlockLabel_*", true, false) as Label
			if label != null:
				labels.append(label.text)
		for expected_title in ["Ключ Разлома", "Друид", "Амулет призыва"]:
			if not _contains_text(labels, expected_title):
				errors.append("%s: victory journal omitted %s." % [context, expected_title])
	if main.find_child("RunSummaryStat_time", true, false) == null or main.find_child("RunSummaryStat_kills", true, false) == null:
		errors.append("%s: compact victory journal displaced required run stats." % context)

	_save_screenshot(viewport, "victory", viewport_size)
	viewport.queue_free()
	await process_frame


func _expect_badge(badge: TextureRect, context: String) -> void:
	if badge == null or not badge.visible:
		errors.append("%s: unread badge is missing or hidden." % context)
		return
	if badge.texture == null or badge.texture.resource_path != BADGE_PATH:
		errors.append("%s: unread badge does not use the PixelLab runtime asset." % context)


func _expect_inside(inner: Rect2, outer: Rect2, context: String) -> void:
	if not outer.grow(1.0).encloses(inner):
		errors.append("%s escapes its safe-zone: %s outside %s." % [context, str(inner), str(outer)])


func _contains_text(values: PackedStringArray, expected: String) -> bool:
	for value in values:
		if value.contains(expected):
			return true
	return false


func _save_screenshot(viewport: SubViewport, screen_id: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := viewport.get_texture().get_image()
	if image == null:
		return
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/fan1077")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	image.save_png("%s/%s_%dx%d.png" % [qa_dir, screen_id, viewport_size.x, viewport_size.y])


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
