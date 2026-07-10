extends "res://tests/runtime_smoke_test.gd"

# Focused acceptance gate for SCRUM-981. It validates the shared production
# 9-slice, exact Main Menu content zones and the approved non-combat inventory
# at every required resolution. Level Up remains an explicit frameless screen.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FRAME_PATH := "res://assets/sprites/ui/meta40/frame_border.png"
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _errors: PackedStringArray = []


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_resolution(viewport_size)
	await _validate_live_resize()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-981 gold menu shell test passed at 1280x720, 1920x1080 and 2560x1440.")
	quit()


func _validate_resolution(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	var expected_safe := _safe_rect(Vector2(viewport_size))

	main.ui._show_main_menu()
	await _settle()
	_assert_frame(main, "MainMenuFrame", expected_safe, viewport_size)
	_assert_main_menu(main, expected_safe, viewport_size)

	main.set("selected_character_id", "berserk")
	main.ui._show_rest_screen()
	await _settle()
	_assert_shell_screen(main, "RestFrame", "MenuPanel_campfire", expected_safe, viewport_size, true)

	main.set("selected_character_id", "berserk")
	main.ui._show_upgrade_screen()
	await _settle()
	_assert_shell_screen(main, "UpgradeFrame", "MenuPanel_upgrade", expected_safe, viewport_size, true)

	main.set("selected_character_id", "berserk")
	main.ui._show_reward_screen()
	await _settle()
	_assert_shell_screen(main, "BattleRewardFrame", "MenuPanel_artifact_reward", expected_safe, viewport_size, true)

	main.set("selected_character_id", "berserk")
	main.set("run_metrics", _sample_metrics("Победа"))
	main.ui._show_victory_screen()
	await _settle()
	_assert_shell_screen(main, "VictoryFrame", "PauseEndModalPanel_victory", expected_safe, viewport_size, false)

	main.set("run_metrics", _sample_metrics("Поражение"))
	main.ui._show_death_screen("Тестовое поражение")
	await _settle()
	_assert_shell_screen(main, "DefeatFrame", "PauseEndModalPanel_death", expected_safe, viewport_size, false)

	# SCRUM-985 owns the deliberately frameless Level Up screen.
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("pending_level_ups", 1)
	main.set("level_up_offer", [
		{"id": "scrum981_a", "title": "+Урон", "description": "+10% к урону.", "kind": "upgrade", "mods": {"damage_multiplier": 1.1}},
		{"id": "scrum981_b", "title": "+Защита", "description": "+5% к защите.", "kind": "upgrade", "mods": {"defense_flat": 0.05}},
		{"id": "scrum981_c", "title": "+Радиус", "description": "+10% к области.", "kind": "upgrade", "mods": {"aoe_radius_multiplier": 1.1}},
	])
	main.ui._show_level_up_screen(false)
	await _settle()
	if main.find_child("LevelUpFrame", true, false) != null:
		_errors.append("%s: Level Up must remain without the shared outer frame." % str(viewport_size))

	main.queue_free()
	viewport.queue_free()
	await process_frame


func _assert_main_menu(main: Node, safe_rect: Rect2, viewport_size: Vector2i) -> void:
	var title := main.find_child("MainMenuTitleLabel", true, false) as Control
	var actions := main.find_child("MainMenuActions", true, false) as GridContainer
	var version := main.find_child("MainMenuVersionLabel", true, false) as Control
	var credits := main.find_child("MainMenuCreditsButton", true, false) as Button
	if title == null or actions == null or version == null or credits == null:
		_errors.append("%s: Main Menu gold-shell nodes are incomplete." % str(viewport_size))
		return
	var inner_rect := _inner_rect(Vector2(viewport_size))
	_assert_inside(title.get_global_rect(), inner_rect, "%s MainMenuTitleLabel" % str(viewport_size))
	_assert_inside(actions.get_global_rect(), safe_rect, "%s MainMenuActions" % str(viewport_size))
	_assert_inside(version.get_global_rect(), safe_rect, "%s MainMenuVersionLabel" % str(viewport_size))
	_assert_inside(credits.get_global_rect(), inner_rect, "%s MainMenuCreditsButton authored inner" % str(viewport_size))
	if actions.columns != 2 or actions.get_child_count() != 6:
		_errors.append("%s: MainMenuActions must be an exact 2x3 six-button grid." % str(viewport_size))
	for child in actions.get_children():
		if child is Button:
			_assert_inside((child as Button).get_global_rect(), safe_rect, "%s %s" % [str(viewport_size), str(child.name)])

	var expected := _main_expected(viewport_size)
	_assert_rect_near(title.get_global_rect(), expected["logo"], "%s Main Menu logo" % str(viewport_size))
	_assert_rect_near(actions.get_global_rect(), expected["grid"], "%s Main Menu grid" % str(viewport_size))
	_assert_rect_near(version.get_global_rect(), expected["version"], "%s Main Menu version" % str(viewport_size))
	_assert_rect_near(credits.get_global_rect(), expected["credits"], "%s Main Menu credits" % str(viewport_size))
	for peer in [title, actions, version]:
		if credits.get_global_rect().intersects((peer as Control).get_global_rect()):
			_errors.append("%s: MainMenuCreditsButton overlaps %s." % [str(viewport_size), str((peer as Control).name)])
	var first := actions.get_child(0) as Button
	if first != null and absf(first.size.y - float(expected["button_height"])) > 1.0:
		_errors.append("%s: Main Menu button height %.1f != %.1f." % [str(viewport_size), first.size.y, float(expected["button_height"])])


func _assert_shell_screen(main: Node, frame_name: String, panel_name: String, safe_rect: Rect2, viewport_size: Vector2i, expect_hud: bool) -> void:
	_assert_frame(main, frame_name, safe_rect, viewport_size)
	var inner_rect := _inner_rect(Vector2(viewport_size))
	var panel := main.find_child(panel_name, true, false) as Control
	if panel == null:
		_errors.append("%s: missing %s." % [str(viewport_size), panel_name])
	else:
		_assert_inside(panel.get_global_rect(), safe_rect, "%s %s" % [str(viewport_size), panel_name])
	for node in main.ui_layer.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.visible and button.is_visible_in_tree():
			_assert_inside(button.get_global_rect(), safe_rect, "%s %s" % [str(viewport_size), str(button.name)])
	if expect_hud:
		var resource_hud := main.find_child("RunResourceHud", true, false) as Control
		if resource_hud == null:
			_errors.append("%s %s: missing menu resource HUD." % [str(viewport_size), panel_name])
		else:
			_assert_inside(resource_hud.get_global_rect(), inner_rect, "%s %s RunResourceHud authored inner" % [str(viewport_size), panel_name])
			for node in resource_hud.find_children("*", "Control", true, false):
				var control := node as Control
				if control != null and control.visible and control.is_visible_in_tree() and control.get_global_rect().has_area():
					_assert_inside(control.get_global_rect(), inner_rect, "%s %s %s authored inner" % [str(viewport_size), panel_name, str(control.name)])
			if panel != null and resource_hud.get_global_rect().intersects(panel.get_global_rect()):
				_errors.append("%s %s: menu HUD %s overlaps content panel %s." % [str(viewport_size), panel_name, str(resource_hud.get_global_rect()), str(panel.get_global_rect())])
		var fab := main.find_child("UpgradeFabButton", true, false) as Button
		if fab != null and fab.visible and fab.is_visible_in_tree():
			_assert_inside(fab.get_global_rect(), inner_rect, "%s %s UpgradeFabButton authored inner" % [str(viewport_size), panel_name])
			if fab.get_global_rect().size.distance_to(Vector2(72.0, 72.0)) > 1.1:
				_errors.append("%s %s: generic FAB visible rect %s must fit the exact 72x72 socket." % [str(viewport_size), panel_name, str(fab.get_global_rect())])
	if panel_name.begins_with("PauseEndModalPanel_"):
		_assert_result_summary_visible(main, panel_name, "%s %s" % [str(viewport_size), panel_name])
	elif panel_name == "MenuPanel_artifact_reward":
		_assert_battle_reward_content(main, "%s %s" % [str(viewport_size), panel_name])
	_assert_visible_shell_content(main, safe_rect, "%s %s" % [str(viewport_size), panel_name])


func _assert_result_summary_visible(main: Node, panel_name: String, context: String) -> void:
	var screen_id := "victory" if panel_name.ends_with("victory") else "death"
	var summary := main.find_child("RunSummaryColumn_%s" % screen_id, true, false) as Control
	if summary == null:
		_errors.append("%s: missing result summary column." % context)
		return
	var summary_rect := summary.get_global_rect().grow(1.0)
	for node in summary.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.visible or not control.is_visible_in_tree() or not control.get_global_rect().has_area():
			continue
		if not summary_rect.encloses(control.get_global_rect()):
			_errors.append("%s: %s is clipped by result summary column %s." % [context, str(control.name), str(summary_rect)])


func _assert_battle_reward_content(main: Node, context: String) -> void:
	for node in main.find_children("BattleRewardButton*", "Button", true, false):
		var button := node as Button
		var content := button.find_child("BattleRewardCardContent", true, false) as Control if button != null else null
		if button == null or content == null:
			_errors.append("%s: missing Battle Reward card content." % context)
			continue
		if content.get_combined_minimum_size().y > content.size.y + 1.0:
			_errors.append("%s %s: content minimum %.1f exceeds visible height %.1f." % [context, str(button.name), content.get_combined_minimum_size().y, content.size.y])
		var content_rect := content.get_global_rect().grow(1.0)
		for child_node in content.find_children("*", "Control", true, false):
			var child := child_node as Control
			if child == null or not child.visible or not child.is_visible_in_tree() or not child.get_global_rect().has_area():
				continue
			if not content_rect.encloses(child.get_global_rect()):
				_errors.append("%s %s: %s is clipped by card content rect %s." % [context, str(button.name), str(child.name), str(content_rect)])


func _assert_visible_shell_content(main: Node, safe_rect: Rect2, context: String) -> void:
	for layer_value in [main.get("ui_layer"), main.get("hud_layer")]:
		var layer := layer_value as CanvasLayer
		if layer == null or not is_instance_valid(layer):
			continue
		for node in layer.find_children("*", "Control", true, false):
			var control := node as Control
			if control == null or not control.visible or not control.is_visible_in_tree():
				continue
			if not (control is Button or control is Label or control is TextureRect or control is ScrollContainer):
				continue
			var node_name := str(control.name)
			if control.has_meta("gold_shell_asset") or node_name.contains("Background") or node_name.contains("Backdrop") or node_name.contains("Shade"):
				continue
			var visible_rect := _clipped_visible_rect(control)
			if visible_rect.has_area():
				_assert_inside(visible_rect, safe_rect, "%s %s" % [context, node_name])


func _clipped_visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		var ancestor_control := ancestor as Control
		if ancestor_control != null and (ancestor_control.clip_contents or ancestor_control is ScrollContainer):
			rect = rect.intersection(ancestor_control.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


func _validate_live_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2560, 1440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	var compact_size := Vector2i(1280, 720)
	var compact_safe := _safe_rect(Vector2(compact_size))

	main.ui._show_main_menu()
	await _settle()
	viewport.size = compact_size
	await _settle()
	_assert_frame(main, "MainMenuFrame", compact_safe, compact_size)
	_assert_main_menu(main, compact_safe, compact_size)

	viewport.size = Vector2i(2560, 1440)
	await _settle()
	main.set("selected_character_id", "berserk")
	main.ui._show_rest_screen()
	await _settle()
	var fresh_large_hud := _hud_geometry(main)
	_assert_hud_siblings_disjoint(main, "fresh 2560x1440 Rest")
	viewport.size = compact_size
	await _settle()
	_assert_shell_screen(main, "RestFrame", "MenuPanel_campfire", compact_safe, compact_size, true)
	var live_compact_hud := _hud_geometry(main)
	_assert_hud_siblings_disjoint(main, "live 2560->1280 Rest")
	var fresh_compact_hud: Dictionary = await _fresh_rest_hud_geometry(compact_size)
	_assert_hud_geometry_equal(live_compact_hud, fresh_compact_hud, "live 2560->1280 vs fresh 1280 Rest")
	viewport.size = Vector2i(2560, 1440)
	await _settle()
	_assert_shell_screen(main, "RestFrame", "MenuPanel_campfire", _safe_rect(Vector2(2560, 1440)), Vector2i(2560, 1440), true)
	_assert_hud_siblings_disjoint(main, "live 1280->2560 Rest")
	_assert_hud_geometry_equal(_hud_geometry(main), fresh_large_hud, "live 2560->1280->2560 Rest idempotency")

	viewport.size = Vector2i(2560, 1440)
	await _settle()
	main.ui._show_upgrade_screen()
	await _settle()
	viewport.size = compact_size
	await _settle()
	_assert_shell_screen(main, "UpgradeFrame", "MenuPanel_upgrade", compact_safe, compact_size, true)

	viewport.size = Vector2i(2560, 1440)
	await _settle()
	main.ui._show_reward_screen()
	await _settle()
	viewport.size = compact_size
	await _settle()
	_assert_shell_screen(main, "BattleRewardFrame", "MenuPanel_artifact_reward", compact_safe, compact_size, true)

	viewport.size = Vector2i(2560, 1440)
	await _settle()
	main.set("run_metrics", _sample_metrics("Победа resize"))
	main.ui._show_victory_screen()
	await _settle()
	viewport.size = compact_size
	await _settle()
	_assert_shell_screen(main, "VictoryFrame", "PauseEndModalPanel_victory", compact_safe, compact_size, false)

	viewport.size = Vector2i(2560, 1440)
	await _settle()
	main.set("run_metrics", _sample_metrics("Поражение resize"))
	main.ui._show_death_screen("Тест resize")
	await _settle()
	viewport.size = compact_size
	await _settle()
	_assert_shell_screen(main, "DefeatFrame", "PauseEndModalPanel_death", compact_safe, compact_size, false)

	viewport.size = Vector2i(2560, 1440)
	await _settle()
	main.set("route_stage", 0)
	main.set("route_nodes", main.route._generate_route())
	main.route._show_battle_map()
	await _settle()
	viewport.size = compact_size
	await _settle()
	_assert_frame(main, "RouteMapFrame", compact_safe, compact_size)
	for node_name in ["RouteMapHeader", "RouteMapTitleProgress", "RunResourceHud", "RouteMapScroll", "UpgradeFabButton"]:
		var control := main.find_child(node_name, true, false) as Control
		if control == null:
			_errors.append("live-resize Route Map: missing %s." % node_name)
		else:
			_assert_inside(control.get_global_rect(), compact_safe, "live-resize Route Map %s" % node_name)

	main.queue_free()
	viewport.queue_free()
	await process_frame


func _assert_frame(main: Node, frame_name: String, safe_rect: Rect2, viewport_size: Vector2i) -> void:
	var frame := main.find_child(frame_name, true, false) as Panel
	if frame == null:
		_errors.append("%s: missing %s." % [str(viewport_size), frame_name])
		return
	var frame_parent := frame.get_parent()
	if frame_parent == null or frame_parent.get_child(frame_parent.get_child_count() - 1) != frame:
		_errors.append("%s %s: gold shell must remain the final visual child." % [str(viewport_size), frame_name])
	var style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null or style.texture == null or style.texture.resource_path != FRAME_PATH:
		_errors.append("%s %s: expected production meta40/frame_border.png StyleBoxTexture." % [str(viewport_size), frame_name])
		return
	if style.draw_center:
		_errors.append("%s %s: outer shell must remain hollow (draw_center=false)." % [str(viewport_size), frame_name])
	var recorded: Rect2 = frame.get_meta("gold_shell_content_rect", Rect2()) as Rect2
	_assert_rect_near(recorded, safe_rect, "%s %s safe rect" % [str(viewport_size), frame_name])
	var recorded_inner: Rect2 = frame.get_meta("gold_shell_inner_rect", Rect2()) as Rect2
	_assert_rect_near(recorded_inner, _inner_rect(Vector2(viewport_size)), "%s %s authored inner rect" % [str(viewport_size), frame_name])


func _safe_rect(viewport_size: Vector2) -> Rect2:
	var margins := Vector4(
		roundf(160.0 * viewport_size.x / 1536.0),
		roundf(160.0 * viewport_size.y / 1024.0),
		roundf(160.0 * viewport_size.x / 1536.0),
		roundf(160.0 * viewport_size.y / 1024.0)
	)
	return Rect2(Vector2(margins.x, margins.y), viewport_size - Vector2(margins.x + margins.z, margins.y + margins.w))


func _inner_rect(viewport_size: Vector2) -> Rect2:
	var reserve := 32.0 if viewport_size.y >= 1200.0 else 24.0
	return _safe_rect(viewport_size).grow(-reserve)


func _main_expected(viewport_size: Vector2i) -> Dictionary:
	match viewport_size:
		Vector2i(1280, 720):
			return {"logo": Rect2(157, 137, 460, 110), "grid": Rect2(157, 263, 776, 244), "version": Rect2(995, 543, 112, 24), "credits": Rect2(871, 149, 240, 36), "button_height": 72.0}
		Vector2i(1920, 1080):
			return {"logo": Rect2(224, 193, 620, 170), "grid": Rect2(224, 387, 780, 348), "version": Rect2(1546, 839, 126, 24), "credits": Rect2(1444, 205, 240, 36), "button_height": 104.0}
		_:
			return {"logo": Rect2(299, 257, 720, 220), "grid": Rect2(299, 509, 780, 348), "version": Rect2(2105, 1127, 124, 24), "credits": Rect2(2009, 269, 240, 36), "button_height": 104.0}


func _fresh_rest_hud_geometry(viewport_size: Vector2i) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", "berserk")
	main.ui._show_rest_screen()
	await _settle()
	_assert_hud_siblings_disjoint(main, "fresh %s Rest" % str(viewport_size))
	var result := _hud_geometry(main)
	main.queue_free()
	viewport.queue_free()
	await process_frame
	return result


func _hud_geometry(main: Node) -> Dictionary:
	var result := {}
	for node_name in ["HudHPTrack", "HudHPBar", "HudXPTrack", "HudXPBar", "HudULTTrack", "HudULTBar"]:
		var control := main.find_child(node_name, true, false) as Control
		if control == null:
			_errors.append("HUD geometry: missing %s." % node_name)
			continue
		result[node_name] = control.get_global_rect()
	return result


func _assert_hud_siblings_disjoint(main: Node, context: String) -> void:
	for suffix in ["Track", "Bar"]:
		var names := ["HudHP%s" % suffix, "HudXP%s" % suffix, "HudULT%s" % suffix]
		for i in range(names.size()):
			for j in range(i + 1, names.size()):
				var first := main.find_child(names[i], true, false) as Control
				var second := main.find_child(names[j], true, false) as Control
				if first != null and second != null and first.get_global_rect().intersects(second.get_global_rect()):
					_errors.append("%s: %s %s overlaps %s %s." % [context, names[i], str(first.get_global_rect()), names[j], str(second.get_global_rect())])


func _assert_hud_geometry_equal(actual: Dictionary, expected: Dictionary, context: String) -> void:
	for node_name in expected.keys():
		if not actual.has(node_name):
			_errors.append("%s: missing actual %s rect." % [context, str(node_name)])
			continue
		_assert_rect_near(actual[node_name] as Rect2, expected[node_name] as Rect2, "%s %s" % [context, str(node_name)])


func _assert_inside(rect: Rect2, safe_rect: Rect2, label: String) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("%s has an empty rect %s." % [label, str(rect)])
	elif not safe_rect.grow(1.0).encloses(rect):
		_errors.append("%s rect %s escapes gold-shell safe rect %s." % [label, str(rect), str(safe_rect)])


func _assert_rect_near(actual: Rect2, expected: Rect2, label: String) -> void:
	if actual.position.distance_to(expected.position) > 1.1 or actual.size.distance_to(expected.size) > 1.1:
		_errors.append("%s rect %s != expected %s." % [label, str(actual), str(expected)])


func _sample_metrics(outcome: String) -> Dictionary:
	return {
		"kills": 12,
		"boss_kills": 1,
		"damage_dealt": 4200.0,
		"damage_taken": 700.0,
		"gold_collected": 300,
		"time_seconds": 120.0,
		"route_stage_reached": 4,
		"final_level": 6,
		"artifacts": [],
		"outcome_reason": outcome,
	}


func _settle() -> void:
	for _frame in range(6):
		await process_frame
