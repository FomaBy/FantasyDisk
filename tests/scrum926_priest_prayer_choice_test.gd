extends SceneTree

# SCRUM-926/SCRUM-1088 focused acceptance: the mandatory Priest pre-battle
# choice uses the exact live Level Up overlay/panel/card builders, not the old
# prayer-specific modal. Selection order, pause/input and exactly-once combat
# continuation stay unchanged.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const PRAYER_IDS := ["prayer_wrath", "prayer_mending", "prayer_aegis"]
const PRAYER_TITLES := ["Молитва кары", "Молитва исцеления", "Молитва защиты"]
const EFFECT_SUMMARIES := ["+20% ко всему урону", "+2 HP/с", "−20% вход. урона"]

var _errors := PackedStringArray()


func _initialize() -> void:
	for target in TARGETS:
		await _check_priest_resolution(target)
	await _check_non_priest_fast_path()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1088 prayer choice passed exact Level Up shell/card reuse, mandatory pause/order, 720p/1080p/2K zones, focus, exactly-once selection and non-Priest fast path.")
	quit(0)


func _check_priest_resolution(target: Vector2i) -> void:
	var fixture := await _open_priest(target, "elite")
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var player := main.get("current_player") as Node
	var screen := _prayer_screen(main)
	var context := "%dx%d" % [target.x, target.y]
	if screen == null or player == null:
		_errors.append("%s: mandatory prayer Level Up screen/player missing." % context)
		await _cleanup(viewport, main)
		return
	if not main.call("_has_pause_reason", "battle_prayer") or not paused:
		_errors.append("%s: battle_prayer pause reason/tree pause missing." % context)
	if str(player.call("active_battle_prayer_id")) != "":
		_errors.append("%s: prayer selected before player input." % context)
	if not get_nodes_in_group("elite_enemies").is_empty():
		_errors.append("%s: elite spawned before mandatory prayer selection." % context)

	# Exact reuse contract: these are the same nodes produced by the ordinary
	# Level Up picker, and the old prayer-specific art/modal is absent.
	var panel := screen.find_child("LevelUpPanel", true, false) as PanelContainer
	var header := screen.find_child("LevelUpHeroHeader", true, false) as Control
	var row := screen.find_child("LevelUpRewardsRow", true, false) as HBoxContainer
	var title := screen.find_child("LevelUpTitle", true, false) as Label
	if panel == null or header == null or row == null or title == null:
		_errors.append("%s: canonical Level Up shell nodes are incomplete." % context)
	else:
		if title.text != "Молитва перед боем":
			_errors.append("%s: prayer title was not injected into LevelUpTitle." % context)
		if not Rect2(Vector2.ZERO, Vector2(target)).grow(1.0).encloses(panel.get_global_rect()):
			_errors.append("%s: LevelUpPanel escapes viewport: %s." % [context, str(panel.get_global_rect())])
	if screen.find_child("BattlePrayerModal", true, false) != null or screen.find_child("BattlePrayerFrameArt", true, false) != null:
		_errors.append("%s: obsolete prayer-specific modal/frame still renders." % context)
	if not bool(screen.get_meta("battle_prayer_choice", false)):
		_errors.append("%s: LevelUpOverlay lacks battle_prayer_choice state marker." % context)

	var buttons: Array[Button] = []
	for index in range(PRAYER_IDS.size()):
		var button := screen.find_child("LevelUpRewardButton%d" % index, true, false) as Button
		if button == null:
			_errors.append("%s: missing canonical LevelUpRewardButton%d." % [context, index])
			continue
		buttons.append(button)
		if str(button.get_meta("prayer_id", "")) != PRAYER_IDS[index]:
			_errors.append("%s: card %d prayer id/order mismatch." % [context, index])
		if not bool(button.get_meta("level_up_text_field_card", false)):
			_errors.append("%s: card %d is not the canonical Level Up card builder output." % [context, index])
		var card_title := button.find_child("LevelUpRewardTitle", true, false) as Label
		var effect := button.find_child("LevelUpRewardEffectText", true, false) as Label
		if card_title == null or card_title.text != PRAYER_TITLES[index]:
			_errors.append("%s: card %d title mismatch." % [context, index])
		if effect == null or effect.text != EFFECT_SUMMARIES[index]:
			_errors.append("%s: card %d effect summary mismatch/ellipsis: '%s'." % [context, index, effect.text if effect != null else "<missing>"])
		elif effect.text.contains("…") or effect.text.contains("..."):
			_errors.append("%s: card %d stores an ellipsized effect summary." % [context, index])
		else:
			var effect_font := effect.get_theme_font("font")
			var effect_font_size := effect.get_theme_font_size("font_size")
			if effect_font != null and effect_font.get_string_size(effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, effect_font_size).x > effect.size.x:
				_errors.append("%s: card %d full effect summary does not fit its Level Up field." % [context, index])
		_assert_level_up_card_safe(button, context)
		var before := button.get_global_rect()
		button.grab_focus()
		await process_frame
		if button.get_global_rect() != before:
			_errors.append("%s: focus shifts Level Up card %d geometry." % [context, index])
	if buttons.size() == 3:
		for first in range(buttons.size()):
			for second in range(first + 1, buttons.size()):
				if buttons[first].get_global_rect().intersects(buttons[second].get_global_rect()):
					_errors.append("%s: Level Up prayer cards %d/%d overlap." % [context, first, second])
		buttons[0].grab_focus()
		await process_frame
		if buttons[0].get_viewport().gui_get_focus_owner() != buttons[0]:
			_errors.append("%s: first Level Up prayer card is not focusable." % context)
		if buttons[0].focus_neighbor_left != buttons[2].get_path() or buttons[2].focus_neighbor_right != buttons[0].get_path():
			_errors.append("%s: horizontal Level Up focus ring is not circular." % context)

	# SCRUM-1044 remains part of the contract: physical cancel must not open
	# PauseStatsMenu or bypass the mandatory Level Up-shell choice.
	var cancel_events: Array[InputEvent] = []
	var physical_escape := InputEventKey.new()
	physical_escape.keycode = KEY_ESCAPE
	physical_escape.physical_keycode = KEY_ESCAPE
	physical_escape.pressed = true
	cancel_events.append(physical_escape)
	var keyboard_cancel := InputEventAction.new()
	keyboard_cancel.action = &"ui_cancel"
	keyboard_cancel.pressed = true
	cancel_events.append(keyboard_cancel)
	var gamepad_cancel := InputEventJoypadButton.new()
	gamepad_cancel.button_index = JOY_BUTTON_B
	gamepad_cancel.pressed = true
	cancel_events.append(gamepad_cancel)
	for cancel_event in cancel_events:
		main.call("_input", cancel_event)
		await process_frame
		if _prayer_screen(main) == null or not paused:
			_errors.append("%s: %s closed the mandatory choice." % [context, cancel_event.get_class()])
		if main.find_child("PauseStatsMenuRoot", true, false) != null:
			_errors.append("%s: %s opened pause dossier over prayer." % [context, cancel_event.get_class()])
		if buttons.size() == 3 and buttons[0].get_viewport().gui_get_focus_owner() != buttons[0]:
			_errors.append("%s: %s stole prayer-card focus." % [context, cancel_event.get_class()])

	var verify_movement_rearm := target == TARGETS[0] and player is CharacterBody2D
	var position_before_choice := Vector2.ZERO
	if verify_movement_rearm:
		(player as CharacterBody2D).set_physics_process(false)
		position_before_choice = (player as CharacterBody2D).global_position
		# FAN-1096: Up is both UI navigation and combat movement. Holding it while
		# confirming the mandatory pre-battle choice must not leak into combat.
		Input.action_press(&"move_up")
	if buttons.size() == 3:
		buttons[1].emit_signal("pressed")
		buttons[1].emit_signal("pressed") # same-frame duplicate must be ignored
	await _settle()
	if str(player.call("active_battle_prayer_id")) != "prayer_mending":
		_errors.append("%s: exact selected id was not applied." % context)
	if _prayer_screen(main) != null:
		_errors.append("%s: prayer Level Up screen remained after valid selection." % context)
	if main.call("_has_pause_reason", "battle_prayer") or paused:
		_errors.append("%s: prayer pause remained after valid selection." % context)
	if get_nodes_in_group("elite_enemies").size() != 1:
		_errors.append("%s: combat continuation spawned %d elites, expected exactly one." % [context, get_nodes_in_group("elite_enemies").size()])
	if verify_movement_rearm:
		_assert_movement_rearms_after_choice(player as CharacterBody2D, position_before_choice, context)
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
	if _prayer_screen(main) != null:
		_errors.append("non-Priest: prayer Level Up screen leaked to Berserk.")
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


func _prayer_screen(main: Node) -> Control:
	var screen := main.find_child("LevelUpOverlay", true, false) as Control
	return screen if screen != null and bool(screen.get_meta("battle_prayer_choice", false)) else null


func _assert_level_up_card_safe(button: Button, context: String) -> void:
	var margins: Vector4 = button.get_meta("level_up_card_content_margins", Vector4.ZERO)
	if margins.x <= 0.0 or margins.y <= 0.0 or margins.z <= 0.0 or margins.w <= 0.0:
		_errors.append("%s: %s has no Level Up content margins." % [context, button.name])
		return
	var safe := Rect2(
		button.get_global_rect().position + Vector2(margins.x, margins.y),
		button.size - Vector2(margins.x + margins.z, margins.y + margins.w)
	).grow(0.75)
	var content := button.find_child("LevelUpRewardContent", true, false) as Control
	if content == null or not safe.encloses(content.get_global_rect()):
		_errors.append("%s: %s content escapes its Level Up safe zone." % [context, button.name])


func _assert_movement_rearms_after_choice(player: CharacterBody2D, start_position: Vector2, context: String) -> void:
	player.call("_physics_process", 1.0 / 60.0)
	if not player.global_position.is_equal_approx(start_position) or not player.velocity.is_zero_approx():
		_errors.append("%s: held UI Up leaked into combat movement: position=%s velocity=%s." % [context, str(player.global_position), str(player.velocity)])

	Input.action_release(&"move_up")
	player.call("_physics_process", 1.0 / 60.0)
	var neutral_position := player.global_position
	Input.action_press(&"move_up")
	player.call("_physics_process", 1.0 / 60.0)
	if player.global_position.y >= neutral_position.y or player.velocity.y >= 0.0:
		_errors.append("%s: movement did not re-arm after Up returned to neutral." % context)

	Input.action_release(&"move_up")
	player.call("_physics_process", 1.0 / 60.0)
	if not player.velocity.is_zero_approx():
		_errors.append("%s: movement did not stop after the fresh Up press was released: %s." % [context, str(player.velocity)])
	player.set_physics_process(true)


func _settle() -> void:
	for _frame in range(6):
		await process_frame


func _cleanup(viewport: SubViewport, main: Node) -> void:
	Input.action_release(&"move_up")
	paused = false
	if main != null and is_instance_valid(main):
		main.call("_clear_all_game_pauses")
		main.queue_free()
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
	await _settle()
