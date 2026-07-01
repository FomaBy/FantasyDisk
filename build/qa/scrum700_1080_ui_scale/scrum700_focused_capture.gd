extends "res://tests/design_review_screenshot_capture_test.gd"

const SCRUM700_VIEWPORT_SIZE := Vector2i(1920, 1080)
const SCRUM700_OUT_DIR := "res://build/qa/scrum700_1080_ui_scale"
const SCRUM700_SCREEN_IDS := [
	"main_menu",
	"settings_display",
	"hero_select",
	"weapon_select",
	"codex",
	"level_up",
	"shop",
	"event",
	"pause_stats",
	"victory",
	"death",
	"combat_hud",
]


func _initialize() -> void:
	var absolute_out := ProjectSettings.globalize_path(SCRUM700_OUT_DIR)
	var screenshot_dir := "%s/screenshots" % absolute_out
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	var manifest := PackedStringArray()
	var rects := PackedStringArray()
	var verdicts := PackedStringArray()
	manifest.append("# SCRUM-700 1080p Focused UI Capture Manifest")
	manifest.append("")
	rects.append("# SCRUM-700 1080p Priority Rect Dump")
	rects.append("")
	verdicts.append("# SCRUM-700 1080p Preliminary Verdicts")
	verdicts.append("")
	for screen_id in SCRUM700_SCREEN_IDS:
		var path := await _capture_screen_scrum700(SCRUM700_VIEWPORT_SIZE, screen_id, screenshot_dir, rects, verdicts)
		manifest.append("- `%s` `%s`: `%s`" % [screen_id, str(SCRUM700_VIEWPORT_SIZE), path])
	var manifest_file := FileAccess.open("%s/manifest.md" % absolute_out, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string("\n".join(manifest))
		manifest_file.close()
	var rect_file := FileAccess.open("%s/priority_rects_1920x1080.md" % absolute_out, FileAccess.WRITE)
	if rect_file != null:
		rect_file.store_string("\n".join(rects))
		rect_file.close()
	var verdict_file := FileAccess.open("%s/preliminary_verdicts.md" % absolute_out, FileAccess.WRITE)
	if verdict_file != null:
		verdict_file.store_string("\n".join(verdicts))
		verdict_file.close()
	if not _missing_captures.is_empty():
		for missing in _missing_captures:
			push_error(missing)
		quit(1)
		return
	print("SCRUM-700 focused screenshots written to %s" % absolute_out)
	quit(0)


func _capture_screen_scrum700(
	viewport_size: Vector2i,
	screen_id: String,
	screenshot_dir: String,
	rects: PackedStringArray,
	verdicts: PackedStringArray
) -> String:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	await _open_screen_scrum700(main, screen_id)
	for _i in range(45):
		await process_frame
	_append_priority_rects(main, screen_id, viewport_size, rects, verdicts)
	var image := viewport.get_texture().get_image()
	var path := "%s/%s_%dx%d.png" % [screenshot_dir, screen_id, viewport_size.x, viewport_size.y]
	if image == null:
		_missing_captures.append("%s %s: viewport image unavailable" % [screen_id, str(viewport_size)])
		viewport.queue_free()
		await process_frame
		return ""
	image.save_png(path)
	viewport.queue_free()
	await process_frame
	return path


func _open_screen_scrum700(main: Node, screen_id: String) -> void:
	if screen_id == "combat_hud":
		_prepare_run_state(main)
		main.set("selected_ascension_level", 1)
		main.set("pending_level_ups", 1)
		main.call("_start_combat")
		await process_frame
		main.ui._update_level_up_button()
		return
	await _open_screen(main, screen_id)


func _append_priority_rects(
	main: Node,
	screen_id: String,
	viewport_size: Vector2i,
	rects: PackedStringArray,
	verdicts: PackedStringArray
) -> void:
	match screen_id:
		"main_menu":
			_append_main_menu_rects(main, viewport_size, rects, verdicts)
		"combat_hud":
			_append_combat_hud_rects(main, viewport_size, rects, verdicts)


func _append_main_menu_rects(main: Node, viewport_size: Vector2i, rects: PackedStringArray, verdicts: PackedStringArray) -> void:
	rects.append("## main_menu %s" % str(viewport_size))
	var title := main.find_child("MainMenuTitleLabel", true, false) as Control
	var actions := main.find_child("MainMenuActions", true, false) as Control
	_append_named_rect(rects, "MainMenuTitleLabel", title)
	_append_named_rect(rects, "MainMenuActions", actions)
	var overlap_count := 0
	var min_gap := 1.0e20
	if actions != null and title != null:
		var title_rect := title.get_global_rect()
		for child in actions.get_children():
			var control := child as Control
			if control == null or not control.visible:
				continue
			var child_rect := control.get_global_rect()
			rects.append("- `%s`: `%s`" % [control.name, str(child_rect)])
			if title_rect.intersects(child_rect):
				overlap_count += 1
			min_gap = minf(min_gap, child_rect.position.y - (title_rect.position.y + title_rect.size.y))
	if title == null or actions == null:
		verdicts.append("- `main_menu 1920x1080`: BLOCKER - title or action container missing.")
	elif overlap_count > 0:
		verdicts.append("- `main_menu 1920x1080`: FAIL - logo/title overlaps %d menu control(s); nearest vertical gap %.1f px." % [overlap_count, min_gap])
	elif min_gap < 32.0:
		verdicts.append("- `main_menu 1920x1080`: WARN - logo/title is close to menu controls; nearest vertical gap %.1f px." % min_gap)
	else:
		verdicts.append("- `main_menu 1920x1080`: PASS - logo/title clear of menu controls; nearest vertical gap %.1f px." % min_gap)
	rects.append("")


func _append_combat_hud_rects(main: Node, viewport_size: Vector2i, rects: PackedStringArray, verdicts: PackedStringArray) -> void:
	rects.append("## combat_hud %s" % str(viewport_size))
	var hud_names := [
		"RunResourceHud",
		"HudHPCard",
		"HudXPCard",
		"HudMoneyCard",
		"HudULTCard",
		"CombatTimerPanel",
		"CombatTimerLabel",
		"AscensionHudBadge",
		"AscensionHudLabel",
		"LevelUpPlusButton",
		"LevelUpPlusBadgePanel",
		"LevelUpPlusBadge",
	]
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var visible_area := 0.0
	var top_hud_max_bottom := 0.0
	var missing := PackedStringArray()
	var old_hud_found := PackedStringArray()
	for old_name in ["CharacterStatsHud", "ArtifactHudRow"]:
		if main.find_child(old_name, true, false) != null:
			old_hud_found.append(old_name)
	for hud_name in hud_names:
		var control := main.find_child(hud_name, true, false) as Control
		_append_named_rect(rects, hud_name, control)
		if control == null or not control.visible or not control.get_global_rect().has_area():
			missing.append(hud_name)
			continue
		var rect := control.get_global_rect()
		if ["RunResourceHud", "CombatTimerPanel", "AscensionHudBadge", "LevelUpPlusButton"].has(hud_name):
			visible_area += rect.size.x * rect.size.y
		if ["RunResourceHud", "CombatTimerPanel", "AscensionHudBadge"].has(hud_name):
			top_hud_max_bottom = maxf(top_hud_max_bottom, rect.position.y + rect.size.y)
		if not viewport_rect.grow(1.0).encloses(rect):
			verdicts.append("- `combat_hud 1920x1080`: FAIL - `%s` escapes viewport: `%s`." % [hud_name, str(rect)])
	var occupancy_pct := visible_area * 100.0 / maxf(1.0, viewport_rect.size.x * viewport_rect.size.y)
	var top_band_pct := top_hud_max_bottom * 100.0 / maxf(1.0, viewport_rect.size.y)
	rects.append("- panel_area_pct_resource_timer_asc_plus: `%.2f%%`" % occupancy_pct)
	rects.append("- top_hud_band_bottom_pct: `%.2f%%`" % top_band_pct)
	if not old_hud_found.is_empty():
		verdicts.append("- `combat_hud 1920x1080`: FAIL - legacy HUD nodes present: `%s`." % ", ".join(old_hud_found))
	elif missing.size() > 0:
		verdicts.append("- `combat_hud 1920x1080`: BLOCKER - expected HUD controls missing or invisible: `%s`." % ", ".join(missing))
	elif occupancy_pct > 22.0:
		verdicts.append("- `combat_hud 1920x1080`: FAIL - priority HUD panel area is %.2f%% of viewport." % occupancy_pct)
	elif occupancy_pct > 16.0 or top_band_pct > 30.0:
		verdicts.append("- `combat_hud 1920x1080`: WARN - priority HUD panel area %.2f%%, top HUD band reaches %.2f%% of viewport height." % [occupancy_pct, top_band_pct])
	else:
		verdicts.append("- `combat_hud 1920x1080`: PASS - priority HUD panel area %.2f%%, top HUD band reaches %.2f%% of viewport height." % [occupancy_pct, top_band_pct])
	rects.append("")


func _append_named_rect(lines: PackedStringArray, node_name: String, control: Control) -> void:
	if control == null:
		lines.append("- `%s`: MISSING" % node_name)
		return
	lines.append("- `%s`: `%s` visible=`%s`" % [node_name, str(control.get_global_rect()), str(control.visible)])
