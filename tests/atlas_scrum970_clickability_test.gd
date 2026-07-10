extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const Meta := preload("res://scripts/meta_progression.gd")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2048, 1152),
	Vector2i(2560, 1440),
]

var errors := PackedStringArray()
var report := PackedStringArray(["# SCRUM-970 Atlas pointer clickability matrix", ""])


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum970")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var report_file := FileAccess.open("%s/atlas_clickability_matrix.md" % qa_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report))
		report_file.close()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-970 Atlas pointer clickability test passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var owned_viewport := SubViewport.new()
	owned_viewport.size = viewport_size
	owned_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(owned_viewport)
	var viewport: Viewport = owned_viewport
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	var state: Dictionary = main.get("meta_state")
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3]}
	state["skill_nodes"] = []
	state["active_keystones"] = {}
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	main.ui._show_atlas_screen()
	for _frame_index in range(10):
		await process_frame

	var context := "Atlas viewport=%s" % str(viewport.get_visible_rect().size)
	report.append("## %s" % context)
	await _check_gamepad_focus_cycle(viewport, main, context)
	var canvas := main.find_child("AtlasCanvas", true, false) as Control
	if canvas == null:
		errors.append("%s: missing canvas/class node." % context)
		await _teardown(owned_viewport)
		return
	for class_id in ["soldier", "berserk"]:
		var medallion := main.find_child("AtlasMedallion_%s" % class_id, true, false) as TextureButton
		if medallion == null:
			errors.append("%s: missing %s class selector." % [context, class_id])
			continue
		var medallion_hovered := await _pointer_click(viewport, medallion)
		for _frame_index in range(12):
			await process_frame
		if str(main.ui._atlas.get("class_id", "")) != class_id:
			errors.append("%s: %s selector routed to %s but did not select the class." % [context, class_id, medallion_hovered])
	canvas = main.find_child("AtlasCanvas", true, false) as Control
	var class_node := main.find_child("AtlasNode_berserk_m0", true, false) as TextureButton
	if canvas == null or class_node == null:
		errors.append("%s: missing rebuilt berserk canvas/class node." % context)
		await _teardown(owned_viewport)
		return
	_check_hitbox_inside_canvas(canvas, class_node, "%s class node" % context)
	if class_node.tooltip_text.strip_edges() == "":
		errors.append("%s: visible class node has no tooltip." % context)
	var class_nodes_before: Array = (main.get("meta_state") as Dictionary).get("skill_nodes", []).duplicate()
	var class_currency_before := Meta.currency_available_for_node(main.get("meta_state"), "berserk_m0")
	var class_rect := class_node.get_global_rect()
	var hovered := await _pointer_click(viewport, class_node, main, "berserk_m0", context)
	for _frame_index in range(12):
		await process_frame
	if str(main.ui._atlas.get("selected", "")) != "berserk_m0":
		errors.append("%s: real pointer click at %s was routed to %s and did not select berserk_m0." % [context, str(class_node.get_global_rect().get_center()), hovered])
	if Meta.is_node_purchased(main.get("meta_state"), "berserk_m0") \
			or (main.get("meta_state") as Dictionary).get("skill_nodes", []) != class_nodes_before \
			or Meta.currency_available_for_node(main.get("meta_state"), "berserk_m0") != class_currency_before:
		errors.append("%s: class-node preview changed purchases or emblem currency before explicit Buy." % context)
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	if buy == null or buy.disabled or not buy.is_visible_in_tree():
		errors.append("%s: selected class node did not expose an enabled buy action." % context)
	else:
		var buy_hovered := await _pointer_click(viewport, buy)
		if not Meta.is_node_purchased(main.get("meta_state"), "berserk_m0"):
			errors.append("%s: real pointer buy click was routed to %s and did not allocate berserk_m0." % [context, buy_hovered])
		var class_cost := int(Meta.node_by_id("berserk_m0").get("cost", 0))
		if Meta.currency_available_for_node(main.get("meta_state"), "berserk_m0") != class_currency_before - class_cost:
			errors.append("%s: explicit class Buy did not spend exactly %d emblems." % [context, class_cost])

	# Reopen from a clean state before the Guild path so stale selection/focus
	# cannot make the pointer assertion pass accidentally.
	state = main.get("meta_state")
	state["meta_point_awards"] = {"berserk": [0]}
	state["skill_nodes"] = []
	main.set("meta_state", state)
	main.ui._show_atlas_screen()
	for _frame_index in range(10):
		await process_frame
	var guild_tab := main.find_child("AtlasTabGuild", true, false) as Button
	if guild_tab == null:
		errors.append("%s: missing Guild tab." % context)
		await _teardown(owned_viewport)
		return
	var tab_hovered := await _pointer_click(viewport, guild_tab)
	for _frame_index in range(8):
		await process_frame
	if str(main.ui._atlas.get("tab", "")) != "guild":
		errors.append("%s: real pointer Guild click was routed to %s and did not switch tabs." % [context, tab_hovered])
	var guild_node := main.find_child("AtlasNode_atlas_m0", true, false) as TextureButton
	if guild_node == null:
		errors.append("%s: missing Guild atlas_m0 node." % context)
		await _teardown(owned_viewport)
		return
	_check_hitbox_inside_canvas(main.find_child("AtlasCanvas", true, false) as Control, guild_node, "%s guild node" % context)
	var guild_nodes_before: Array = (main.get("meta_state") as Dictionary).get("skill_nodes", []).duplicate()
	var guild_currency_before := Meta.currency_available_for_node(main.get("meta_state"), "atlas_m0")
	var guild_rect := guild_node.get_global_rect()
	var guild_hovered := await _pointer_click(viewport, guild_node, main, "atlas_m0", context)
	for _frame_index in range(12):
		await process_frame
	if str(main.ui._atlas.get("selected", "")) != "atlas_m0":
		errors.append("%s: real pointer click was routed to %s and did not select atlas_m0." % [context, guild_hovered])
	if Meta.is_node_purchased(main.get("meta_state"), "atlas_m0") \
			or (main.get("meta_state") as Dictionary).get("skill_nodes", []) != guild_nodes_before \
			or Meta.currency_available_for_node(main.get("meta_state"), "atlas_m0") != guild_currency_before:
		errors.append("%s: Guild-node preview changed purchases or stardust before explicit Buy." % context)
	var guild_buy := main.find_child("AtlasBuyButton", true, false) as Button
	if guild_buy == null or guild_buy.disabled or not guild_buy.is_visible_in_tree():
		errors.append("%s: selected Guild node did not expose an enabled buy action." % context)
	else:
		var guild_buy_hovered := await _pointer_click(viewport, guild_buy)
		if not Meta.is_node_purchased(main.get("meta_state"), "atlas_m0"):
			errors.append("%s: real pointer Guild buy click was routed to %s and did not allocate atlas_m0." % [context, guild_buy_hovered])
		var guild_cost := int(Meta.node_by_id("atlas_m0").get("cost", 0))
		if Meta.currency_available_for_node(main.get("meta_state"), "atlas_m0") != guild_currency_before - guild_cost:
			errors.append("%s: explicit Guild Buy did not spend exactly %d stardust." % [context, guild_cost])

	var respec := main.find_child("AtlasRespecButton", true, false) as Button
	if respec == null or respec.disabled or respec.tooltip_text.strip_edges() == "":
		errors.append("%s: reset control is missing, disabled, or lacks its tooltip." % context)
	else:
		var respec_hovered := await _pointer_click(viewport, respec)
		var popup := main.find_child("AtlasRespecPopup", true, false) as PanelContainer
		if popup == null or not popup.is_visible_in_tree():
			errors.append("%s: reset click routed to %s but did not open confirmation." % [context, respec_hovered])
		else:
			var cancel := main.find_child("AtlasRespecCancelButton", true, false) as Button
			if cancel == null:
				errors.append("%s: reset confirmation has no cancel control." % context)
			else:
				await _pointer_click(viewport, cancel)
				if popup.visible:
					errors.append("%s: reset cancel did not close confirmation." % context)

	# Meta 4.0 intentionally renders the full graph without legacy zoom/pan
	# controls; the current equivalents are the class selector, reset and tabs.
	if main.find_child("SkillTreeZoomIn", true, false) != null or main.find_child("SkillTreeZoomOut", true, false) != null:
		errors.append("%s: obsolete zoom controls returned to the fixed Atlas canvas." % context)
	var back := main.find_child("AtlasBackButton", true, false) as Button
	if back == null:
		errors.append("%s: missing Back control." % context)
	else:
		var back_hovered := await _pointer_click(viewport, back)
		for _frame_index in range(2):
			await process_frame
		if main.find_child("MainMenuScreen", true, false) == null:
			errors.append("%s: Back click routed to %s but did not return to the main menu." % [context, back_hovered])

	report.append("- class node: `%s`; Guild node: `%s`" % [str(class_rect), str(guild_rect)])
	report.append("- pointer path: class selectors → class node → buy → Guild tab → Guild node → buy → reset/cancel → back")
	await _teardown(owned_viewport)


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/":
		push_error("SCRUM-970 test refuses the default user://; pass -- --user-data-dir=<unique scratch root> and point the platform user-data environment there.")
		return false
	if not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-970 scratch mismatch: user:// resolves to %s outside requested %s." % [actual, requested])
		return false
	report.append("Scratch user data: `%s`" % actual)
	report.append("")
	return true


func _check_gamepad_focus_cycle(viewport: Viewport, main: Node, context: String) -> void:
	var atlas_root := main.find_child("AtlasScreen", true, false) as Control
	var initial := viewport.gui_get_focus_owner()
	if atlas_root == null or initial == null or not initial.is_visible_in_tree():
		errors.append("%s: Atlas did not seed a visible initial gamepad focus." % context)
		return
	var nodes_before: Array = (main.get("meta_state") as Dictionary).get("skill_nodes", []).duplicate()
	main.ui._atlas_cycle_tab(1)
	for _frame_index in range(12):
		await process_frame
	var guild_focus := viewport.gui_get_focus_owner()
	if guild_focus == null or not guild_focus.is_visible_in_tree() or not atlas_root.is_ancestor_of(guild_focus):
		errors.append("%s: LB/RB/Tab cycle to Guild lost visible Atlas focus." % context)
	else:
		var guild_focus_name := str(guild_focus.name)
		await _push_ui_action(viewport, "ui_right")
		var guild_next := viewport.gui_get_focus_owner()
		if guild_next == null or not guild_next.is_visible_in_tree() or str(guild_next.name) == guild_focus_name:
			errors.append("%s: Guild focus cannot reach a neighbour with d-pad/right." % context)
	main.ui._atlas_cycle_tab(-1)
	for _frame_index in range(12):
		await process_frame
	var class_focus := viewport.gui_get_focus_owner()
	if class_focus == null or not class_focus.is_visible_in_tree() or not atlas_root.is_ancestor_of(class_focus):
		errors.append("%s: LB/RB/Tab cycle back to Constellation lost visible Atlas focus." % context)
	else:
		var class_focus_name := str(class_focus.name)
		await _push_ui_action(viewport, "ui_down")
		var class_next := viewport.gui_get_focus_owner()
		if class_next == null or not class_next.is_visible_in_tree() or str(class_next.name) == class_focus_name:
			errors.append("%s: Constellation focus cannot reach a neighbour with d-pad/down." % context)
	if (main.get("meta_state") as Dictionary).get("skill_nodes", []) != nodes_before:
		errors.append("%s: gamepad focus traversal changed purchases." % context)


func _push_ui_action(viewport: Viewport, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	viewport.push_input(release, true)
	for _frame_index in range(2):
		await process_frame


func _pointer_click(
	viewport: Viewport,
	control: Control,
	main: Node = null,
	expected_selection := "",
	context := ""
) -> String:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	var hovered := viewport.gui_get_hovered_control()
	var hovered_name := str(hovered.name) if hovered != null else "<none>"
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(press, true)
	await process_frame
	if expected_selection != "" and main != null:
		var selected_after_press := str(main.ui._atlas.get("selected", ""))
		if selected_after_press != expected_selection:
			errors.append("%s: pointer-down on %s did not select %s (got %s)." % [context, control.name, expected_selection, selected_after_press])
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.global_position = point
	release.pressed = false
	release.button_mask = 0
	viewport.push_input(release, true)
	for _frame_index in range(2):
		await process_frame
	return hovered_name


func _check_hitbox_inside_canvas(canvas: Control, node: TextureButton, context: String) -> void:
	if canvas == null or node == null:
		errors.append("%s: missing hitbox controls." % context)
		return
	var canvas_rect := canvas.get_global_rect().grow(1.0)
	var node_rect := node.get_global_rect()
	if not canvas_rect.encloses(node_rect):
		errors.append("%s: visible node hitbox %s leaves canvas %s." % [context, str(node_rect), str(canvas_rect)])
	if node.mouse_filter != Control.MOUSE_FILTER_STOP or node.disabled:
		errors.append("%s: node is not a live STOP pointer target." % context)
	if node.action_mode != BaseButton.ACTION_MODE_BUTTON_PRESS:
		errors.append("%s: node preview is not armed on pointer-down." % context)
	for child in node.get_children():
		var child_control := child as Control
		if child_control != null and child_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			errors.append("%s: overlay %s intercepts the node click." % [context, child_control.name])


func _teardown(owned_viewport: SubViewport) -> void:
	owned_viewport.queue_free()
	for _frame_index in range(6):
		await process_frame
