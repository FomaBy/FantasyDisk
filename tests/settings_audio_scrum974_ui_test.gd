extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	print("SCRUM-974 Settings Sound responsive UI/reset test passed.")
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
	main.ui._show_settings_menu()
	for _frame_index in range(8):
		await process_frame
	var sound_tab := main.find_child("SettingsTabButton_1", true, false) as Button
	if sound_tab == null:
		_fail("Missing Sound tab at %s." % str(viewport_size))
		return
	sound_tab.pressed.emit()
	for _frame_index in range(5):
		await process_frame

	var panel := main.find_child("SettingsContentPanel", true, false) as Control
	var scroll := main.find_child("AudioScroll", true, false) as ScrollContainer
	var content := main.find_child("SettingsAudioContent", true, false) as VBoxContainer
	var reset := main.find_child("SettingsResetAudioButton", true, false) as Button
	var footer := main.find_child("SettingsBottomActions", true, false) as Control
	if panel == null or scroll == null or content == null or reset == null or footer == null:
		_fail("Missing SCRUM-974 Sound layout controls at %s." % str(viewport_size))
		return
	if not scroll.follow_focus or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_fail("AudioScroll must be vertical-only and follow focus at %s." % str(viewport_size))
		return
	if not panel.get_global_rect().grow(1.0).encloses(scroll.get_global_rect()):
		_fail("AudioScroll escaped SettingsContentPanel at %s." % str(viewport_size))
		return
	if scroll.get_global_rect().intersects(footer.get_global_rect(), true):
		_fail("AudioScroll overlaps Settings footer at %s." % str(viewport_size))
		return

	for volume_key in ["master_volume", "music_volume", "sfx_volume", "ui_volume"]:
		var row := main.find_child("VolumeRow_%s" % volume_key, true, false) as Control
		var slider := main.find_child("VolumeSlider_%s" % volume_key, true, false) as HSlider
		if row == null or slider == null or slider.focus_mode != Control.FOCUS_ALL:
			_fail("Missing/focusless volume row %s at %s." % [volume_key, str(viewport_size)])
			return
		if not content.get_global_rect().grow(1.0).encloses(row.get_global_rect()):
			_fail("Volume row %s escaped Audio content at %s." % [volume_key, str(viewport_size)])
			return

	var mute_row := main.find_child("AudioOptionRow_mute_when_unfocused", true, false) as Control
	var low_hp_row := main.find_child("AudioOptionRow_low_hp_warning_enabled", true, false) as Control
	var mute_toggle := main.find_child("AudioToggle_mute_when_unfocused", true, false) as CheckBox
	var low_hp_toggle := main.find_child("AudioToggle_low_hp_warning_enabled", true, false) as CheckBox
	if mute_row == null or low_hp_row == null or mute_toggle == null or low_hp_toggle == null:
		_fail("Missing the two real audio option rows at %s." % str(viewport_size))
		return
	if mute_row.get_global_rect().intersects(low_hp_row.get_global_rect(), true) or mute_row.get_global_rect().position.y >= low_hp_row.get_global_rect().position.y:
		_fail("Audio option rows are not a clean vertical stack at %s." % str(viewport_size))
		return
	if mute_toggle.focus_mode != Control.FOCUS_ALL or low_hp_toggle.focus_mode != Control.FOCUS_ALL:
		_fail("Audio option toggles are not gamepad-focusable at %s." % str(viewport_size))
		return
	if DisplayServer.get_name() != "headless":
		_save_capture(viewport, viewport_size, "top")

	var scrollbar_visible := scroll.get_v_scroll_bar().visible
	if viewport_size.y <= 720 and not scrollbar_visible:
		_fail("Compact Sound page must expose AudioScroll at %s." % str(viewport_size))
		return
	if viewport_size.y >= 1080 and scrollbar_visible:
		_fail("Sound page is cluttered/scrolling at %s although wide layout must fit (content_min=%.1f, scroll_h=%.1f, reset=%s)." % [str(viewport_size), content.get_combined_minimum_size().y, scroll.size.y, str(reset.get_global_rect())])
		return
	if viewport_size.y <= 720:
		reset.grab_focus()
		for _frame_index in range(5):
			await process_frame
		if scroll.scroll_vertical <= 0 or not scroll.get_global_rect().intersection(reset.get_global_rect()).has_area():
			_fail("AudioScroll did not reveal focused Reset at %s." % str(viewport_size))
			return
		if DisplayServer.get_name() != "headless":
			_save_capture(viewport, viewport_size, "reset_focus")

	if viewport_size == Vector2i(1920, 1080):
		var ui_slider := main.find_child("VolumeSlider_ui_volume", true, false) as HSlider
		ui_slider.value = 36.0
		mute_toggle.toggled.emit(true)
		low_hp_toggle.toggled.emit(false)
		await process_frame
		var persisted := GAME_SETTINGS.load_settings()
		if absf(float(persisted.get("ui_volume", -1.0)) - 0.36) > 0.021 \
				or not bool(persisted.get("mute_when_unfocused", false)) \
				or bool(persisted.get("low_hp_warning_enabled", true)):
			_fail("New Sound controls did not apply/persist live.")
			return
		reset.pressed.emit()
		await process_frame
		persisted = GAME_SETTINGS.load_settings()
		for volume_key in ["master_volume", "music_volume", "sfx_volume", "ui_volume"]:
			if not is_equal_approx(float(persisted.get(volume_key, -1.0)), float(GAME_SETTINGS.DEFAULTS[volume_key])):
				_fail("Reset did not restore %s." % volume_key)
				return
		if bool(persisted.get("mute_when_unfocused", true)) or not bool(persisted.get("low_hp_warning_enabled", false)):
			_fail("Reset did not restore new audio toggle defaults.")
			return

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_fail("SCRUM-974 viewport teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])


func _save_capture(viewport: SubViewport, viewport_size: Vector2i, suffix: String) -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum974")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/settings_sound_%s_%dx%d.png" % [qa_dir, suffix, viewport_size.x, viewport_size.y])


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-974 UI test requires isolated HOME/XDG and matching --user-data-dir (actual %s, requested %s)." % [actual, requested])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
