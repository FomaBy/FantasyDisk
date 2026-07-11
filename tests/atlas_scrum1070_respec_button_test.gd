extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const Meta := preload("res://scripts/meta_progression.gd")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")

const VIEWPORTS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2048, 1152),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const FAMILY := "text/standard_420x104"
const TEXTURE_PREFIX := "res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_standard_420x104_"
const EXPECTED_TEXTURE_MARGINS := Vector4(54, 21, 54, 21)
const EXPECTED_CONTENT_MARGINS := Vector4(71, 21, 71, 21)

var _errors := PackedStringArray()


func _initialize() -> void:
	for viewport_size in VIEWPORTS:
		await _check_layout(viewport_size)
	await _check_live_resize()
	await _check_reset_scopes()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1070 Atlas reset footer passed exact 420px family/fit/frame/reset gates at seven responsive tiers, live resize and both scopes.")
	quit(0)


func _check_layout(viewport_size: Vector2i) -> void:
	var owned_viewport := SubViewport.new()
	owned_viewport.size = viewport_size
	owned_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(owned_viewport)
	var main := await _spawn_main(owned_viewport, ["berserk_m0"])
	main.ui._show_atlas_screen()
	await _settle()

	var context := "viewport=%s" % str(viewport_size)
	var button := main.find_child("AtlasRespecButton", true, false) as Button
	var footer := main.find_child("AtlasFooter", true, false) as HBoxContainer
	var legend := main.find_child("AtlasLegend", true, false) as HBoxContainer
	var safe := main.find_child("AtlasSafeArea", true, false) as MarginContainer
	var frame := main.find_child("AtlasFrame", true, false) as Panel
	if button == null or footer == null or legend == null or safe == null or frame == null:
		_errors.append("%s: reset/footer/legend/safe hierarchy is incomplete." % context)
		await _teardown(owned_viewport)
		return

	var expected_height := 72.0 if viewport_size.y < 760 else (88.0 if viewport_size.y < 1000 else 104.0)
	var expected_size := Vector2(420.0, expected_height)
	if not button.custom_minimum_size.is_equal_approx(expected_size):
		_errors.append("%s: custom minimum must be %s, got %s." % [context, str(expected_size), str(button.custom_minimum_size)])
	if not button.size.is_equal_approx(expected_size):
		_errors.append("%s: visible/hit rect must be %s, got %s (combined_min=%s footer=%s flags_v=%d font=%d)." % [context, str(expected_size), str(button.size), str(button.get_combined_minimum_size()), str(footer.size), button.size_flags_vertical, button.get_theme_font_size("font_size")])
	var expected_font := 21 if viewport_size.y < 760 else 23
	if button.get_theme_font_size("font_size") != expected_font:
		_errors.append("%s: action font must be %dpx, got %dpx." % [context, expected_font, button.get_theme_font_size("font_size")])
	if str(button.get_meta(UIButtonFamily.META_FAMILY, "")) != FAMILY or not bool(button.get_meta(UIButtonFamily.META_FAMILY_EXPLICIT, false)):
		_errors.append("%s: family must be explicitly pinned to %s, got %s." % [context, FAMILY, str(button.get_meta(UIButtonFamily.META_FAMILY, ""))])
	if button.autowrap_mode != TextServer.AUTOWRAP_OFF or button.clip_text or button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		_errors.append("%s: reset label must be one-line, unclipped and untrimmed." % context)
	if button.focus_mode != Control.FOCUS_ALL or button.focus_neighbor_top.is_empty():
		_errors.append("%s: reset button lost its gamepad focus contract." % context)

	var button_rect := button.get_global_rect()
	var footer_rect := footer.get_global_rect().grow(1.0)
	var safe_rect := safe.get_global_rect().grow(1.0)
	var frame_safe_rect := _frame_content_rect(viewport_size).grow(1.5)
	var legend_rect := legend.get_global_rect()
	if absf(footer.get_global_rect().position.x - _frame_content_rect(viewport_size).position.x) > 1.5 or absf(footer.get_global_rect().end.x - _frame_content_rect(viewport_size).end.x) > 1.5:
		_errors.append("%s: footer horizontal bounds drifted from authored frame content rect: %s vs %s." % [context, str(footer.get_global_rect()), str(_frame_content_rect(viewport_size))])
	if not footer_rect.encloses(button_rect) or not safe_rect.encloses(button_rect) or not frame_safe_rect.encloses(button_rect):
		_errors.append("%s: reset rect %s escapes footer/safe zone." % [context, str(button_rect)])
	if not footer_rect.encloses(legend_rect) or not safe_rect.encloses(legend_rect) or not frame_safe_rect.encloses(legend_rect):
		_errors.append("%s: legend rect %s escapes footer/safe zone." % [context, str(legend_rect)])
	if button_rect.intersects(legend_rect):
		_errors.append("%s: reset rect overlaps legend: %s vs %s." % [context, str(button_rect), str(legend_rect)])
	_check_frame_style(frame, viewport_size, context)

	for state in UIButtonFamily.STATES:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		if style == null or style.texture == null:
			_errors.append("%s: %s state is not the accepted textured family." % [context, state])
			continue
		if style.texture.resource_path != "%s%s.png" % [TEXTURE_PREFIX, state]:
			_errors.append("%s: %s state uses %s." % [context, state, style.texture.resource_path])
		var texture_margins := Vector4(style.texture_margin_left, style.texture_margin_top, style.texture_margin_right, style.texture_margin_bottom)
		var content_margins := Vector4(
			style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP),
			style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_BOTTOM)
		)
		if texture_margins != EXPECTED_TEXTURE_MARGINS or content_margins != EXPECTED_CONTENT_MARGINS:
			_errors.append("%s: %s margins drifted: texture=%s content=%s." % [context, state, str(texture_margins), str(content_margins)])

	_check_label_fit(button, "Сброс умений", context)
	var guild_tab := main.find_child("AtlasTabGuild", true, false) as Button
	if guild_tab == null:
		_errors.append("%s: missing Guild tab." % context)
	else:
		guild_tab.pressed.emit()
		await _settle()
		if button.text != "Сброс умений Атласа":
			_errors.append("%s: Guild label mismatch: %s." % [context, button.text])
		_check_label_fit(button, "Сброс умений Атласа", context)

	await _teardown(owned_viewport)


func _check_live_resize() -> void:
	var owned_viewport := SubViewport.new()
	owned_viewport.size = Vector2i(1152, 648)
	owned_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(owned_viewport)
	var main := await _spawn_main(owned_viewport, ["berserk_m0"])
	main.ui._show_atlas_screen()
	await _settle()
	var button := main.find_child("AtlasRespecButton", true, false) as Button
	var original_instance_id := button.get_instance_id() if button != null else 0
	for viewport_size in [Vector2i(1600, 900), Vector2i(3840, 2160), Vector2i(1280, 720)]:
		owned_viewport.size = viewport_size
		await _settle()
		button = main.find_child("AtlasRespecButton", true, false) as Button
		var footer := main.find_child("AtlasFooter", true, false) as HBoxContainer
		var legend := main.find_child("AtlasLegend", true, false) as HBoxContainer
		var safe := main.find_child("AtlasSafeArea", true, false) as MarginContainer
		var frame := main.find_child("AtlasFrame", true, false) as Panel
		var context := "live_resize=%s" % str(viewport_size)
		if button == null or footer == null or legend == null or safe == null or frame == null:
			_errors.append("%s: responsive footer hierarchy disappeared." % context)
			continue
		if button.get_instance_id() != original_instance_id:
			_errors.append("%s: Atlas was rebuilt instead of reflowing the same button instance." % context)
		var expected_height := 72.0 if viewport_size.y < 760 else (88.0 if viewport_size.y < 1000 else 104.0)
		if not button.size.is_equal_approx(Vector2(420.0, expected_height)):
			_errors.append("%s: exact live size drifted to %s." % [context, str(button.size)])
		var expected_font := 21 if viewport_size.y < 760 else 23
		if button.get_theme_font_size("font_size") != expected_font:
			_errors.append("%s: live action font expected %dpx, got %dpx." % [context, expected_font, button.get_theme_font_size("font_size")])
		if str(button.get_meta(UIButtonFamily.META_FAMILY, "")) != FAMILY:
			_errors.append("%s: live resize lost %s family." % [context, FAMILY])
		var button_rect := button.get_global_rect()
		var legend_rect := legend.get_global_rect()
		var frame_safe_rect := _frame_content_rect(viewport_size).grow(1.5)
		if absf(footer.get_global_rect().position.x - _frame_content_rect(viewport_size).position.x) > 1.5 or absf(footer.get_global_rect().end.x - _frame_content_rect(viewport_size).end.x) > 1.5:
			_errors.append("%s: live footer bounds do not match responsive frame content rect: %s vs %s." % [context, str(footer.get_global_rect()), str(_frame_content_rect(viewport_size))])
		if button_rect.intersects(legend_rect) or not footer.get_global_rect().grow(1.0).encloses(button_rect) or not frame_safe_rect.encloses(button_rect) or not frame_safe_rect.encloses(legend_rect):
			_errors.append("%s: button/legend/footer safe reflow failed: %s vs %s." % [context, str(button_rect), str(legend_rect)])
		_check_frame_style(frame, viewport_size, context)
	await _teardown(owned_viewport)


func _frame_content_rect(viewport_size: Vector2i) -> Rect2:
	var horizontal_margin := 160.0 * float(viewport_size.x) / 1536.0
	var vertical_margin := 160.0 * float(viewport_size.y) / 1024.0 * 0.86
	return Rect2(
		Vector2(horizontal_margin, vertical_margin),
		Vector2(float(viewport_size.x) - horizontal_margin * 2.0, float(viewport_size.y) - vertical_margin * 2.0)
	)


func _check_frame_style(frame: Panel, viewport_size: Vector2i, context: String) -> void:
	var style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null:
		_errors.append("%s: Atlas frame lost its 9-slice style." % context)
		return
	var actual := Vector4(style.texture_margin_left, style.texture_margin_top, style.texture_margin_right, style.texture_margin_bottom)
	var expected := Vector4(
		roundf(160.0 * float(viewport_size.x) / 1536.0),
		roundf(160.0 * float(viewport_size.y) / 1024.0),
		roundf(160.0 * float(viewport_size.x) / 1536.0),
		roundf(160.0 * float(viewport_size.y) / 1024.0)
	)
	if not actual.is_equal_approx(expected):
		_errors.append("%s: Atlas frame margins are stale: %s vs %s." % [context, str(actual), str(expected)])


func _check_label_fit(button: Button, expected_text: String, context: String) -> void:
	button.text = expected_text
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	var measured := font.get_string_size(expected_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var content_width := button.size.x - EXPECTED_CONTENT_MARGINS.x - EXPECTED_CONTENT_MARGINS.z
	if measured + 4.0 > content_width:
		_errors.append("%s: '%s' width %.1f + reserve exceeds %.1f content px at font %d." % [context, expected_text, measured, content_width, font_size])


func _check_reset_scopes() -> void:
	var owned_viewport := SubViewport.new()
	owned_viewport.size = Vector2i(1920, 1080)
	owned_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(owned_viewport)
	var main := await _spawn_main(owned_viewport, ["berserk_m0", "atlas_m0"])
	main.ui._show_atlas_screen()
	await _settle()
	var button := main.find_child("AtlasRespecButton", true, false) as Button
	var popup := main.find_child("AtlasRespecPopup", true, false) as PanelContainer
	var cancel := main.find_child("AtlasRespecCancelButton", true, false) as Button
	var confirm := main.find_child("AtlasRespecConfirmButton", true, false) as Button
	if button == null or popup == null or cancel == null or confirm == null:
		_errors.append("reset scopes: confirmation hierarchy is incomplete.")
		await _teardown(owned_viewport)
		return

	button.pressed.emit()
	await process_frame
	if not popup.visible:
		_errors.append("reset scopes: constellation press did not open confirmation.")
	cancel.pressed.emit()
	await process_frame
	if popup.visible or not Meta.is_node_purchased(main.meta_state, "berserk_m0") or not Meta.is_node_purchased(main.meta_state, "atlas_m0"):
		_errors.append("reset scopes: Cancel changed purchases or left popup open.")
	button.pressed.emit()
	confirm.pressed.emit()
	await _settle()
	if Meta.is_node_purchased(main.meta_state, "berserk_m0") or not Meta.is_node_purchased(main.meta_state, "atlas_m0"):
		_errors.append("reset scopes: constellation reset did not refund only the selected class.")
	if Meta.class_sigils_available(main.meta_state, "berserk") != Meta.class_sigils_earned(main.meta_state, "berserk"):
		_errors.append("reset scopes: constellation emblems were not fully refunded.")

	var state: Dictionary = main.meta_state
	state["skill_nodes"] = ["berserk_m0", "atlas_m0"]
	main.meta_state = state
	main.ui._show_atlas_screen()
	await _settle()
	var guild_tab := main.find_child("AtlasTabGuild", true, false) as Button
	button = main.find_child("AtlasRespecButton", true, false) as Button
	guild_tab.pressed.emit()
	await _settle()
	popup = main.find_child("AtlasRespecPopup", true, false) as PanelContainer
	confirm = main.find_child("AtlasRespecConfirmButton", true, false) as Button
	button.pressed.emit()
	confirm.pressed.emit()
	await _settle()
	if not Meta.is_node_purchased(main.meta_state, "berserk_m0") or Meta.is_node_purchased(main.meta_state, "atlas_m0"):
		_errors.append("reset scopes: Guild reset did not refund only Atlas purchases.")
	if Meta.stardust_available(main.meta_state) != Meta.stardust_earned(main.meta_state):
		_errors.append("reset scopes: Guild stardust was not fully refunded.")

	await _teardown(owned_viewport)


func _spawn_main(viewport: SubViewport, purchases: Array) -> Node:
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	var state: Dictionary = main.meta_state
	state["skill_nodes"] = purchases.duplicate()
	state["active_keystones"] = {}
	state["meta_point_awards"] = {"berserk": [0]}
	state["ascension_levels"] = {}
	state["class_boss_wins"] = {}
	state["class_challenge_progress"] = {}
	state["class_challenges_done"] = {}
	state["secret_boss_defeated"] = false
	state["achievements"] = []
	state["discovered_monsters"] = []
	state["discovered_bosses"] = []
	state["discovered_artifacts"] = []
	main.meta_state = state
	main.selected_character_id = "berserk"
	return main


func _settle() -> void:
	for _frame in range(8):
		await process_frame


func _teardown(viewport: SubViewport) -> void:
	viewport.queue_free()
	await process_frame
