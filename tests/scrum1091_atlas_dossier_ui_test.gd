extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const PREFINAL_PATH := [
	"berserk_sword_b1", "berserk_sword_b2", "berserk_sword_b3",
	"berserk_sword_b4", "berserk_sword_b5",
]

var errors := PackedStringArray()
var teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORTS:
		await _check_viewport(viewport_size)
	await _check_same_instance_resize()
	await teardown.release_windowed_audio(self)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1091 Atlas dossier UI passed scroll/pinned controls/final hierarchy/no-toggle/safe-zone at 720p/1080p/2K and same-instance resize.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := await _spawn_main(viewport)
	await _open_final(main)
	_check_contract(main, viewport_size, "viewport=%s" % str(viewport_size))
	var teardown_errors := await teardown.release_viewport(self, viewport)
	for error in teardown_errors:
		errors.append("viewport=%s teardown: %s" % [str(viewport_size), error])


func _check_same_instance_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := await _spawn_main(viewport)
	await _open_final(main)
	var scroll := main.find_child("AtlasNodeScroll", true, false) as ScrollContainer
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	var scroll_id := scroll.get_instance_id() if scroll != null else 0
	var buy_id := buy.get_instance_id() if buy != null else 0
	for viewport_size in [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 720)]:
		viewport.size = viewport_size
		await _settle()
		scroll = main.find_child("AtlasNodeScroll", true, false) as ScrollContainer
		buy = main.find_child("AtlasBuyButton", true, false) as Button
		if scroll == null or buy == null or scroll.get_instance_id() != scroll_id or buy.get_instance_id() != buy_id:
			errors.append("live resize %s rebuilt or lost dossier controls" % str(viewport_size))
			continue
		_check_contract(main, viewport_size, "live_resize=%s" % str(viewport_size))
	var teardown_errors := await teardown.release_viewport(self, viewport)
	for error in teardown_errors:
		errors.append("live resize teardown: %s" % error)


func _spawn_main(viewport: SubViewport) -> Node:
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	var state: Dictionary = main.get("meta_state")
	state["skill_nodes"] = PREFINAL_PATH.duplicate()
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3, 4, 5]}
	state["ascension_levels"] = {"berserk": 5}
	state["class_boss_wins"] = {"berserk": 1}
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	return main


func _open_final(main: Node) -> void:
	main.ui._show_atlas_screen()
	await _settle()
	var final_button := main.find_child("AtlasNode_berserk_sword_final", true, false) as TextureButton
	if final_button == null:
		errors.append("Atlas does not expose berserk_sword_final")
		return
	final_button.pressed.emit()
	await _settle()


func _check_contract(main: Node, viewport_size: Vector2i, context: String) -> void:
	var panel := main.find_child("AtlasNodePanel", true, false) as PanelContainer
	var panel_box := main.find_child("AtlasNodePanelBox", true, false) as VBoxContainer
	var scroll := main.find_child("AtlasNodeScroll", true, false) as ScrollContainer
	var info_box := main.find_child("AtlasNodeInfoBox", true, false) as VBoxContainer
	var callout := main.find_child("AtlasNodeFinalCallout", true, false) as Label
	var desc := main.find_child("AtlasNodeDesc", true, false) as Label
	var price_row := main.find_child("AtlasNodePriceRow", true, false) as HBoxContainer
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	var toggle := main.find_child("AtlasKeystoneToggle", true, false) as Button
	if panel == null or panel_box == null or scroll == null or info_box == null or callout == null or desc == null or price_row == null or buy == null or toggle == null:
		errors.append("%s: incomplete dossier hierarchy" % context)
		return
	if callout.text != "УНИКАЛЬНЫЙ ФИНАЛ" or not callout.is_visible_in_tree():
		errors.append("%s: exact final callout is absent" % context)
	if not desc.text.contains("Оружие: «Двуручный меч»") or not desc.text.contains("Триггер и механика:") or not desc.text.contains("Против босса:") or not desc.text.contains("не менее +20%"):
		errors.append("%s: final copy lost weapon/trigger/boss/floor details" % context)
	if toggle.visible or toggle.is_visible_in_tree():
		errors.append("%s: weapon final exposes a legacy activation toggle" % context)
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or scroll.focus_mode != Control.FOCUS_ALL:
		errors.append("%s: dossier scroll/input contract drifted" % context)
	if not scroll.is_ancestor_of(info_box) or not info_box.is_ancestor_of(desc) or not info_box.is_ancestor_of(callout):
		errors.append("%s: long final copy escaped AtlasNodeScroll" % context)
	if scroll.is_ancestor_of(price_row) or scroll.is_ancestor_of(buy) or price_row.get_parent() != panel_box or buy.get_parent() != panel_box:
		errors.append("%s: price/Buy are not pinned outside the scroll viewport" % context)
	var panel_rect := panel.get_global_rect().grow(1.0)
	for control in [scroll, price_row, buy]:
		if control.is_visible_in_tree() and not panel_rect.encloses((control as Control).get_global_rect()):
			errors.append("%s: %s escapes dossier panel safe zone" % [context, control.name])
	if scroll.get_global_rect().intersects(price_row.get_global_rect(), true) or scroll.get_global_rect().intersects(buy.get_global_rect(), true) or price_row.get_global_rect().intersects(buy.get_global_rect(), true):
		errors.append("%s: scroll, price and Buy overlap" % context)
	var style := panel.get_theme_stylebox("panel")
	if style == null or style.get_content_margin(SIDE_LEFT) < 30.0 or style.get_content_margin(SIDE_RIGHT) < 30.0 or style.get_content_margin(SIDE_TOP) < 30.0 or style.get_content_margin(SIDE_BOTTOM) < 30.0:
		errors.append("%s: dossier content margins are below the accepted 30px ornament reserve" % context)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(1.0)
	if not viewport_rect.encloses(panel.get_global_rect()) or not viewport_rect.encloses(buy.get_global_rect()):
		errors.append("%s: dossier/action escapes viewport" % context)
	# Long final copy must actually exercise the scroll lane on 720p; larger tiers
	# may fit, but page/max values must still be coherent and reset to the top.
	var bar := scroll.get_v_scroll_bar()
	if bar.page <= 0.0 or bar.max_value < bar.page or scroll.scroll_vertical != 0:
		errors.append("%s: scroll page/max/top state is incoherent" % context)
	if viewport_size == Vector2i(1280, 720) and bar.max_value <= bar.page:
		errors.append("%s: long final copy did not activate the designed 720p scroll lane" % context)


func _settle() -> void:
	for _index in range(10):
		await process_frame


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1091 UI test requires an isolated --user-data-dir scratch root")
		return false
	return true
