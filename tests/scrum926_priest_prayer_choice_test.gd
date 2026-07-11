extends SceneTree

# SCRUM-926 focused acceptance: mandatory pre-battle selection, unchanged
# PixelLab frame content zones, deterministic focus, no cancel escape and an
# exactly-once continuation into the combat-start hooks/objective spawn.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const PRAYER_IDS := ["prayer_wrath", "prayer_mending", "prayer_aegis"]
const FRAME_SIZE := Vector2(688.0, 384.0)
const CARD_RECTS := [
	Rect2(65.0, 154.0, 160.0, 172.0),
	Rect2(265.0, 154.0, 160.0, 172.0),
	Rect2(465.0, 154.0, 160.0, 172.0),
]

var _errors := PackedStringArray()


func _initialize() -> void:
	for target in TARGETS:
		await _check_priest_resolution(target)
	await _check_live_resize()
	await _check_non_priest_fast_path()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-926 prayer choice passed mandatory pause/order, 720p/1080p/2K zones, focus, resize, exactly-once selection and non-Priest fast path.")
	quit(0)


func _check_priest_resolution(target: Vector2i) -> void:
	var fixture := await _open_priest(target, "elite")
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var player := main.get("current_player") as Node
	var screen := main.find_child("BattlePrayerChoiceScreen", true, false) as Control
	var context := "%dx%d" % [target.x, target.y]
	if screen == null or player == null:
		_errors.append("%s: mandatory prayer screen/player missing." % context)
		await _cleanup(viewport, main)
		return
	if not main.call("_has_pause_reason", "battle_prayer") or not paused:
		_errors.append("%s: battle_prayer pause reason/tree pause missing." % context)
	if str(player.call("active_battle_prayer_id")) != "":
		_errors.append("%s: prayer selected before player input." % context)
	if not get_nodes_in_group("elite_enemies").is_empty():
		_errors.append("%s: elite spawned before mandatory prayer selection." % context)

	var modal := screen.find_child("BattlePrayerModal", true, false) as Control
	var art := screen.find_child("BattlePrayerFrameArt", true, false) as TextureRect
	if modal == null or art == null or art.texture == null:
		_errors.append("%s: PixelLab modal art is incomplete." % context)
	else:
		var expected_scale := minf(float(target.x) * 0.82 / FRAME_SIZE.x, float(target.y) * 0.80 / FRAME_SIZE.y)
		expected_scale = clampf(expected_scale, 0.82, 3.0)
		if not modal.scale.is_equal_approx(Vector2.ONE * expected_scale):
			_errors.append("%s: modal scale %s != %.4f." % [context, str(modal.scale), expected_scale])
		if not Rect2(Vector2.ZERO, Vector2(target)).grow(1.0).encloses(modal.get_global_rect()):
			_errors.append("%s: modal escapes viewport: %s." % [context, str(modal.get_global_rect())])
		if art.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_errors.append("%s: decorative art must ignore input." % context)

	var buttons: Array[Button] = []
	for index in range(PRAYER_IDS.size()):
		var button := screen.find_child("BattlePrayerCard_%s" % PRAYER_IDS[index], true, false) as Button
		if button == null:
			_errors.append("%s: missing card %s." % [context, PRAYER_IDS[index]])
			continue
		buttons.append(button)
		if button.get_meta("content_zone_rect", Rect2()) != CARD_RECTS[index]:
			_errors.append("%s: %s does not use its authored empty card interior." % [context, button.name])
		_assert_descendants_inside(button, context)
		var before := button.get_global_rect()
		button.grab_focus()
		await process_frame
		if button.get_global_rect() != before:
			_errors.append("%s: focus shifts %s geometry." % [context, button.name])
	if buttons.size() == 3:
		buttons[0].grab_focus()
		await process_frame
		if buttons[0].get_viewport().gui_get_focus_owner() != buttons[0]:
			_errors.append("%s: first prayer card is not initial/focusable target." % context)
		if buttons[0].focus_neighbor_left != buttons[2].get_path() or buttons[2].focus_neighbor_right != buttons[0].get_path():
			_errors.append("%s: horizontal focus ring is not circular." % context)
		for button in buttons:
			if button.focus_neighbor_top != button.get_path() or button.focus_neighbor_bottom != button.get_path():
				_errors.append("%s: vertical focus must remain on %s." % [context, button.name])

	# Escape/B is intentionally consumed by a no-op while the mandatory choice is open.
	var escape_action: Callable = main.get("ui_escape_action")
	if escape_action.is_valid():
		escape_action.call()
	await process_frame
	if main.find_child("BattlePrayerChoiceScreen", true, false) == null or not paused:
		_errors.append("%s: cancel input closed the mandatory choice." % context)

	if buttons.size() == 3:
		buttons[1].emit_signal("pressed")
		buttons[1].emit_signal("pressed") # same-frame duplicate must be ignored
	await _settle()
	if str(player.call("active_battle_prayer_id")) != "prayer_mending":
		_errors.append("%s: exact selected id was not applied." % context)
	if main.find_child("BattlePrayerChoiceScreen", true, false) != null:
		_errors.append("%s: prayer screen remained after valid selection." % context)
	if main.call("_has_pause_reason", "battle_prayer") or paused:
		_errors.append("%s: prayer pause remained after valid selection." % context)
	if get_nodes_in_group("elite_enemies").size() != 1:
		_errors.append("%s: combat continuation spawned %d elites, expected exactly one." % [context, get_nodes_in_group("elite_enemies").size()])
	await _cleanup(viewport, main)


func _check_live_resize() -> void:
	var fixture := await _open_priest(Vector2i(2560, 1440), "battle")
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var modal := main.find_child("BattlePrayerModal", true, false) as Control
	viewport.size = Vector2i(1280, 720)
	await _settle()
	if modal == null or not Rect2(Vector2.ZERO, Vector2(1280, 720)).grow(1.0).encloses(modal.get_global_rect()):
		_errors.append("live resize: modal does not reflow inside 1280x720.")
	elif not modal.scale.is_equal_approx(Vector2.ONE * 1.5):
		_errors.append("live resize: modal scale %s != 1.5." % str(modal.scale))
	await _cleanup(viewport, main)


func _check_non_priest_fast_path() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_start_combat", false, "battle")
	await _settle()
	if main.find_child("BattlePrayerChoiceScreen", true, false) != null:
		_errors.append("non-Priest: prayer screen leaked to Berserk.")
	if main.call("_has_pause_reason", "battle_prayer") or paused:
		_errors.append("non-Priest: battle start was paused by prayer flow.")
	await _cleanup(viewport, main)


func _open_priest(target: Vector2i, combat_type: String) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = target
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", "priest")
	main.set("selected_weapon_id", "priest_censer")
	main.set("route_stage", 3)
	main.call("_start_combat", false, combat_type)
	await _settle()
	return {"viewport": viewport, "main": main}


func _assert_descendants_inside(button: Button, context: String) -> void:
	var zone := button.get_global_rect().grow(0.5)
	for child in button.find_children("*", "Control", true, false):
		var control := child as Control
		if control == null or not control.visible:
			continue
		if not zone.encloses(control.get_global_rect()):
			_errors.append("%s: %s escapes empty interior of %s." % [context, control.name, button.name])


func _settle() -> void:
	for _frame in range(4):
		await process_frame


func _cleanup(viewport: SubViewport, main: Node) -> void:
	paused = false
	if main != null and is_instance_valid(main):
		main.call("_clear_all_game_pauses")
		main.queue_free()
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
	await _settle()
