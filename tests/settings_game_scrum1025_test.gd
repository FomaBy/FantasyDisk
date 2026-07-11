extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SANDBOX := preload("res://scripts/gameplay_sandbox.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SUFFIXES := ["monster_hp", "monster_damage", "player_damage", "player_attack_speed", "monster_attack_speed"]
const KEYS := [SANDBOX.MONSTER_HP, SANDBOX.MONSTER_DAMAGE, SANDBOX.PLAYER_DAMAGE, SANDBOX.PLAYER_ATTACK_SPEED, SANDBOX.MONSTER_ATTACK_SPEED]

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	print("SCRUM-1025 Settings/Game four-tab responsive/persistence/snapshot test passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GAME_SETTINGS.SAVE_PATH))
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	if main.ui == null:
		_fail("Main UI failed to initialize at %s." % str(viewport_size))
		return
	main.ui._show_settings_menu()
	for _frame_index in range(8):
		await process_frame

	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	var switcher := main.find_child("SettingsTabSwitcher", true, false) as Control
	var panel := main.find_child("SettingsContentPanel", true, false) as Control
	var footer := main.find_child("SettingsBottomActions", true, false) as Control
	if tabs == null or switcher == null or panel == null or footer == null or tabs.get_child_count() != 4:
		_fail("Missing four-tab Settings shell at %s." % str(viewport_size))
		return
	var expected_panel_w := 960.0 if viewport_size.y <= 760 else (1158.0 if viewport_size.y <= 1080 else 1544.0)
	if absf(panel.get_global_rect().size.x - expected_panel_w) > 3.0:
		_fail("SettingsContentPanel width missed accepted SCRUM-975 geometry at %s: expected %.1f got %.1f." % [str(viewport_size), expected_panel_w, panel.get_global_rect().size.x])
		return
	for tab_index in range(4):
		var tab := main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Button
		if tab == null or tab.focus_mode != Control.FOCUS_ALL:
			_fail("Missing/focusless Settings tab %d at %s." % [tab_index, str(viewport_size)])
			return
	for expected_tab in [1, 2, 3, 0]:
		if not main.ui._cycle_settings_tab(1) or tabs.current_tab != expected_tab:
			_fail("LB/RB Settings cycle did not include Game/wrap at %s (expected %d got %d)." % [str(viewport_size), expected_tab, tabs.current_tab])
			return
	var expected_columns := 2 if viewport_size.y <= 760 else 4
	var expected_rows := 2 if viewport_size.y <= 760 else 1
	if int(switcher.get_meta("settings_tab_columns", 0)) != expected_columns or int(switcher.get_meta("settings_tab_rows", 0)) != expected_rows:
		_fail("Wrong responsive Settings tab grid metadata at %s." % str(viewport_size))
		return
	var tab_rects: Array[Rect2] = []
	for tab_index in range(4):
		var rect := (main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Button).get_global_rect()
		for previous in tab_rects:
			if rect.intersects(previous, true):
				_fail("Settings tab plates overlap at %s: %s / %s." % [str(viewport_size), str(previous), str(rect)])
				return
		tab_rects.append(rect)
	if expected_rows == 2 and (absf(tab_rects[0].position.y - tab_rects[1].position.y) > 1.0 or tab_rects[2].position.y <= tab_rects[0].position.y):
		_fail("Compact Settings tabs did not form a 2x2 grid at %s." % str(viewport_size))
		return
	if expected_rows == 1:
		for rect in tab_rects:
			if absf(rect.position.y - tab_rects[0].position.y) > 1.0:
				_fail("Wide Settings tabs did not stay in one row at %s." % str(viewport_size))
				return

	var game_tab := main.find_child("SettingsTabButton_3", true, false) as Button
	game_tab.pressed.emit()
	for _frame_index in range(5):
		await process_frame
	if tabs.current_tab != 3 or tabs.get_node_or_null("Игра") == null:
		_fail("Game tab did not select SettingsTabs page 3 at %s." % str(viewport_size))
		return

	var scroll := main.find_child("SettingsGameScroll", true, false) as ScrollContainer
	var content := main.find_child("SettingsGameContent", true, false) as Control
	var status := main.find_child("SettingsGameStatus", true, false) as Label
	var warning := main.find_child("SettingsSandboxWarning", true, false) as Label
	var reset := main.find_child("SettingsResetGameButton", true, false) as Button
	if scroll == null or content == null or status == null or warning == null or reset == null:
		_fail("Missing Settings/Game content contract at %s." % str(viewport_size))
		return
	if not scroll.follow_focus or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_fail("SettingsGameScroll must be vertical-only and follow focus at %s." % str(viewport_size))
		return
	var expected_scroll_w := 892.0 if viewport_size.y <= 760 else (1068.0 if viewport_size.y <= 1080 else 1424.0)
	if absf(scroll.get_global_rect().size.x - expected_scroll_w) > 3.0:
		_fail("SettingsGameScroll width missed accepted geometry at %s: expected %.1f got %.1f." % [str(viewport_size), expected_scroll_w, scroll.get_global_rect().size.x])
		return
	if viewport_size.y <= 760 and absf(scroll.get_v_scroll_bar().get_combined_minimum_size().x - 14.0) > 1.0:
		_fail("Compact SettingsGameScroll lost its 14px scrollbar lane.")
		return
	if not panel.get_global_rect().grow(1.0).encloses(scroll.get_global_rect()):
		_fail("Settings/Game scroll escaped panel at %s: panel=%s scroll=%s." % [str(viewport_size), str(panel.get_global_rect()), str(scroll.get_global_rect())])
		return
	if footer.visible:
		_fail("Settings/Game must hide its irrelevant Screen footer at %s." % str(viewport_size))
		return
	if status.text != "Обычный режим · 1.0×" or not reset.disabled:
		_fail("Neutral Game status/reset is wrong at %s." % str(viewport_size))
		return
	if DisplayServer.get_name() != "headless":
		await _save_capture_stable(viewport, viewport_size, "neutral_full_v2")

	for index in range(SUFFIXES.size()):
		var suffix: String = str(SUFFIXES[index])
		var key: String = str(KEYS[index])
		var slider := main.find_child("SettingsSandboxSlider_%s" % suffix, true, false) as HSlider
		var value_label := main.find_child("SettingsSandboxValue_%s" % suffix, true, false) as Label
		var row := main.find_child("SettingsSandboxRow_%s" % suffix, true, false) as Control
		var spec: Dictionary = SANDBOX.SPECS[key]
		if slider == null or value_label == null or row == null or slider.focus_mode != Control.FOCUS_ALL:
			_fail("Missing/focusless sandbox row %s at %s." % [suffix, str(viewport_size)])
			return
		if not is_equal_approx(slider.min_value, float(spec["min"])) or not is_equal_approx(slider.max_value, float(spec["max"])) or not is_equal_approx(slider.step, float(spec["step"])):
			_fail("Sandbox slider %s duplicated/wrong backend range at %s." % [suffix, str(viewport_size)])
			return
		if value_label.text != "1.0×" or not content.get_global_rect().grow(1.0).encloses(row.get_global_rect()):
			_fail("Sandbox row/value %s escaped content or lost neutral text at %s." % [suffix, str(viewport_size)])
			return

	var scrollbar_visible := scroll.get_v_scroll_bar().visible
	if viewport_size.y <= 760 and not scrollbar_visible:
		_fail("Compact Game page must scroll at %s." % str(viewport_size))
		return
	if viewport_size.y >= 1080 and scrollbar_visible:
		_fail("Wide Game page must fit without scroll at %s (content %.1f / viewport %.1f)." % [str(viewport_size), content.get_combined_minimum_size().y, scroll.size.y])
		return

	var shell_rects := {
		"header": (main.find_child("SettingsHeader", true, false) as Control).get_global_rect(),
		"back": (main.find_child("SettingsBackButton", true, false) as Control).get_global_rect(),
		"switcher": switcher.get_global_rect(),
	}
	for tab_index in range(4):
		shell_rects["tab_%d" % tab_index] = (main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Control).get_global_rect()
	if viewport_size.y <= 760:
		var scrollbar := scroll.get_v_scroll_bar()
		var scroll_rect := scroll.get_global_rect()
		var expected_runtime_h := maxf(160.0, roundf(float(viewport_size.y) * 0.6875 - 253.0))
		var expected_content_rect := Rect2(scroll_rect.position, Vector2(878.0, 520.0))
		var expected_lane_rect := Rect2(scroll_rect.position + Vector2(878.0, 0.0), Vector2(14.0, expected_runtime_h))
		var scroll_max := scrollbar.max_value - scrollbar.page
		if scroll_rect.size.distance_to(Vector2(892.0, expected_runtime_h)) > 1.0:
			_fail("Compact SettingsGameScroll must preserve 892px width and stop at the live Atlas safe edge, got %s." % str(scroll_rect))
			return
		var frame_safe_rect := (main.find_child("SettingsSafeArea", true, false) as Control).get_global_rect()
		if scroll_rect.end.y > frame_safe_rect.end.y + 1.0:
			_fail("Compact SettingsGameScroll enters the bottom Atlas ornament: scroll=%s safe=%s." % [str(scroll_rect), str(frame_safe_rect)])
			return
		if not _rect_close(content.get_global_rect(), expected_content_rect, 1.0):
			_fail("Compact SettingsGameContent must be exact %s at top-scroll, got %s." % [str(expected_content_rect), str(content.get_global_rect())])
			return
		if not _rect_close(scrollbar.get_global_rect(), expected_lane_rect, 1.0):
			_fail("Compact scrollbar lane must be exclusive %s, got %s." % [str(expected_lane_rect), str(scrollbar.get_global_rect())])
			return
		if absf(scroll_max - (520.0 - expected_runtime_h)) > 1.0:
			_fail("Compact Settings/Game max scroll must match the 520px canvas minus safe viewport, got %.1f." % scroll_max)
			return

	# Deterministic real-input path: Game tab -> five sliders -> Reset. Make
	# Reset focusable first, then drive the SubViewport with built-in ui_down.
	var traversal_hp := main.find_child("SettingsSandboxSlider_monster_hp", true, false) as HSlider
	traversal_hp.value = 1.1
	await process_frame
	game_tab.grab_focus()
	await process_frame
	var traversal_targets: Array[Control] = []
	for suffix in SUFFIXES:
		traversal_targets.append(main.find_child("SettingsSandboxSlider_%s" % suffix, true, false) as HSlider)
	traversal_targets.append(reset)
	for target in traversal_targets:
		await _press_ui_action(viewport, "ui_down")
		if viewport.gui_get_focus_owner() != target:
			_fail("Settings/Game ui_down traversal missed %s at %s; focused %s." % [target.name, str(viewport_size), str(viewport.gui_get_focus_owner())])
			return
	reset.pressed.emit()
	await process_frame

	if viewport_size.y <= 760:
		var compact_hp := main.find_child("SettingsSandboxSlider_monster_hp", true, false) as HSlider
		compact_hp.value = 1.1
		await process_frame
		reset.grab_focus()
		for _frame_index in range(5):
			await process_frame
		scroll.scroll_vertical = int(roundf(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page))
		for _frame_index in range(3):
			await process_frame
		var expected_bottom_scroll := scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page
		if absf(float(scroll.scroll_vertical) - expected_bottom_scroll) > 1.0 or not scroll.get_global_rect().grow(1.0).encloses(reset.get_global_rect()):
			_fail("Compact Game scroll did not reveal focused Reset at %s: scroll_y=%s max=%.1f viewport=%s reset=%s." % [str(viewport_size), str(scroll.scroll_vertical), expected_bottom_scroll, str(scroll.get_global_rect()), str(reset.get_global_rect())])
			return
		for bottom_suffix in SUFFIXES.slice(2):
			var bottom_row := main.find_child("SettingsSandboxRow_%s" % bottom_suffix, true, false) as Control
			if bottom_row == null or not scroll.get_global_rect().grow(1.0).encloses(bottom_row.get_global_rect()):
				_fail("Compact bottom state must fully reveal row %s inside the frame-safe viewport." % bottom_suffix)
				return
		for shell_name in shell_rects:
			var current_shell_rect: Rect2
			if str(shell_name).begins_with("tab_"):
				current_shell_rect = (main.find_child("SettingsTabButton_%s" % str(shell_name).trim_prefix("tab_"), true, false) as Control).get_global_rect()
			else:
				current_shell_rect = (main.find_child({"header": "SettingsHeader", "back": "SettingsBackButton", "switcher": "SettingsTabSwitcher"}[shell_name], true, false) as Control).get_global_rect()
			if not _rect_close(current_shell_rect, shell_rects[shell_name], 0.5):
				_fail("Compact bottom scroll moved fixed shell %s: %s -> %s." % [shell_name, str(shell_rects[shell_name]), str(current_shell_rect)])
				return
		if DisplayServer.get_name() != "headless":
			await _save_capture_stable(viewport, viewport_size, "reset_focus_frame_safe_v2")
		reset.pressed.emit()
		await process_frame

	if viewport_size == Vector2i(1920, 1080):
		var hp_slider := main.find_child("SettingsSandboxSlider_monster_hp", true, false) as HSlider
		var player_damage_slider := main.find_child("SettingsSandboxSlider_player_damage", true, false) as HSlider
		hp_slider.value = 1.7
		await process_frame
		if status.text != "Песочница активна" or reset.disabled or not warning.text.contains("прогрессия"):
			_fail("Custom Game status/warning/reset did not refresh.")
			return
		if DisplayServer.get_name() != "headless":
			await _save_capture_stable(viewport, viewport_size, "custom_full_v2")
		var persisted := GAME_SETTINGS.load_settings()
		if not is_equal_approx(float(persisted.get(SANDBOX.MONSTER_HP, -1.0)), 1.7):
			_fail("Game slider did not persist through SCRUM-976 GameSettings.")
			return
		main.begin_new_run_session()
		var active_before: Dictionary = main.run_sandbox_snapshot.duplicate(true)
		player_damage_slider.value = 1.4
		await process_frame
		if main.run_sandbox_snapshot != active_before:
			_fail("Editing Game Settings mutated the active run snapshot.")
			return
		reset.pressed.emit()
		await process_frame
		if not main.sandbox_settings_are_neutral() or main.run_sandbox_snapshot != active_before or not reset.disabled:
			_fail("Atomic Game reset changed active run or failed to restore neutral configured state.")
			return

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_fail("SCRUM-1025 viewport teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1025 test requires isolated HOME/XDG and matching --user-data-dir (actual %s, requested %s)." % [actual, requested])
		return false
	return true


func _press_ui_action(viewport: SubViewport, action: String) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	pressed.strength = 1.0
	viewport.push_input(pressed, true)
	await process_frame
	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	viewport.push_input(released, true)
	await process_frame


func _rect_close(actual: Rect2, expected: Rect2, tolerance: float) -> bool:
	return actual.position.distance_to(expected.position) <= tolerance and actual.size.distance_to(expected.size) <= tolerance


func _save_capture_stable(viewport: SubViewport, viewport_size: Vector2i, suffix: String) -> void:
	for _frame_index in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum1025")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/settings_game_%s_%dx%d.png" % [qa_dir, suffix, viewport_size.x, viewport_size.y])


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
