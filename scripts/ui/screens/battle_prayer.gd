extends "res://scripts/ui/screens/feedback.gd"

# FAN-3824: модуль распределённого UI-класса — выбор боевой молитвы.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# SCRUM-1088: the mandatory Priest battle-start choice deliberately reuses the
# live Level Up shell/card builders. There is no prayer-specific frame, card
# geometry or visual family: only the title, three data dictionaries and the
# selection callback differ from an ordinary Level Up choice.
func show_battle_prayer_choice(player: Node, on_selected: Callable) -> bool:
	if player == null or not is_instance_valid(player) or not player.has_method("battle_prayer_choices"):
		return false
	var choices: Array = player.call("battle_prayer_choices")
	if choices.is_empty() or str(player.call("active_battle_prayer_id")) != "":
		return false
	if _is_battle_prayer_choice_open():
		return true

	var layout := _level_up_layout_metrics()
	var display_choices: Array = []
	for choice_raw in choices.slice(0, 3):
		var choice := (choice_raw as Dictionary).duplicate(true)
		var prayer_id := str(choice.get("id", ""))
		choice["icon_id"] = str(BATTLE_PRAYER_ICON_IDS.get(prayer_id, "artifact"))
		# Display-only compact copy for the fixed one-line Level Up effect field.
		# Canonical prayer descriptions/effects remain unchanged in progression data.
		choice["effect_summary"] = str(BATTLE_PRAYER_EFFECT_SUMMARIES.get(prayer_id, choice.get("description", "")))
		choice["description"] = "Действует до конца текущего боя."
		display_choices.append(choice)
	var advice := {"forecasts": [], "badges": []}
	layout["card_plan"] = _level_up_card_plan(display_choices, advice, layout)
	var box := _create_level_up_menu_box(
		"Молитва перед боем",
		"Выбери 1 из 3 усилений. Один выбор на текущий бой.",
		layout
	)
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	game.ui_layer.name = "BattlePrayerChoiceLayer"
	var root := game.ui_layer.get_node_or_null("LevelUpOverlay") as Control
	if root == null:
		return false
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_meta("selection_locked", false)
	root.set_meta("battle_prayer_choice", true)
	root.set_meta("source_content_layout", "res://docs/design/mockups/scrum1088_priest_prayer_attribute_picker/layout.json")

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "LevelUpRewardsRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.position = layout.get("rewards_row_position", Vector2.ZERO)
	rewards_row.size = layout.get("rewards_row_size", Vector2(760.0, 320.0))
	rewards_row.custom_minimum_size = rewards_row.size
	rewards_row.add_theme_constant_override("separation", int(layout.get("card_gap", 0)))
	box.add_child(rewards_row)

	var buttons: Array[Button] = []
	for index in range(display_choices.size()):
		var choice: Dictionary = display_choices[index]
		var button := _make_level_up_reward_button(choice, layout, advice, index)
		button.name = "LevelUpRewardButton%d" % index
		button.set_meta("prayer_id", str(choice.get("id", "")))
		button.pressed.connect(Callable(self, "_select_battle_prayer").bind(root, player, str(choice.get("id", "")), on_selected))
		rewards_row.add_child(button)
		buttons.append(button)

	_wire_run_ui_focus(buttons, true, [], buttons[0] if not buttons.is_empty() else null)
	game.ui_escape_action = Callable(self, "_consume_battle_prayer_cancel")
	game.push_pause("battle_prayer")

	var panel := box.get_parent() as PanelContainer
	var title_label := box.find_child("LevelUpTitle", true, false) as Label
	var sparkle_root := game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpParticles") as Control
	_start_level_up_intro(panel, title_label, buttons, sparkle_root)
	return true




func _select_battle_prayer(root: Control, player: Node, prayer_id: String, on_selected: Callable) -> void:
	if root == null or not is_instance_valid(root) or bool(root.get_meta("selection_locked", false)):
		return
	if player == null or not is_instance_valid(player) or not player.has_method("select_battle_prayer"):
		return
	if not bool(player.call("select_battle_prayer", prayer_id)):
		return
	root.set_meta("selection_locked", true)
	_close_battle_prayer_choice()
	if on_selected.is_valid():
		on_selected.call()




func _close_battle_prayer_choice() -> void:
	game.ui_escape_action = Callable()
	if game.ui_layer != null and is_instance_valid(game.ui_layer):
		game.ui_layer.queue_free()
	game.ui_layer = null
	game.pop_pause("battle_prayer")




func _consume_battle_prayer_cancel() -> void:
	# The choice is mandatory: Escape/B intentionally has no closing action.
	pass




func _is_battle_prayer_choice_open() -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	var root := game.ui_layer.get_node_or_null("LevelUpOverlay") as Control
	return root != null and bool(root.get_meta("battle_prayer_choice", false))
