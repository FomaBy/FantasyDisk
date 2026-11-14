extends "res://tests/runtime_smoke_test.gd"

# FAN-4010: shop focus survives a purchase; Settings Back/Update are reachable
# with direction input on every tab.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

var _errors: PackedStringArray = []


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	await _test_shop_focus(main, viewport)
	await _test_settings_reachability(main)
	main.queue_free()
	viewport.queue_free()
	await process_frame
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	_finish("FAN-4010 shop focus and settings direction navigation test passed.")


func _settle() -> void:
	for _frame in range(7):
		await process_frame


func _shop_items() -> Array:
	var items: Array = []
	for index in range(4):
		items.append({"id": "fan4010_%d" % index, "title": "Item %d" % index, "description": "d", "kind": "artifact", "cost": 100, "mods": {"move_speed_multiplier": 0.05}})
	return items


func _focus_name(viewport: Viewport) -> String:
	var owner := viewport.gui_get_focus_owner()
	return str(owner.name) if owner != null else ""


func _press_accept(viewport: Viewport) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		viewport.push_input(event)
	await _settle()


func _test_shop_focus(main: Node, viewport: Viewport) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 3)
	main.set("current_node_type", "shop")
	main.set("current_route_choice", "fan4010")
	var player := PLAYER_SCENE.instantiate()
	viewport.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", 5000)
	main.call("_store_player_snapshot", player)
	player.queue_free()
	main.set("current_shop_items", _shop_items())
	main.set("current_shop_purchased", [false, false, false, false])
	main.set("current_shop_node_key", "1:3:shop:fan4010")
	main.ui._show_shop_screen()
	await _settle()
	if _focus_name(viewport) != "ShopItemButton0":
		_errors.append("shop: initial focus must be the first item, got %s." % _focus_name(viewport))
	(main.find_child("ShopItemButton2", true, false) as Button).grab_focus()
	await process_frame
	await _press_accept(viewport)
	var purchased: Array = main.get("current_shop_purchased")
	if purchased != [false, false, true, false]:
		_errors.append("shop: Enter on item 2 must buy only item 2, got %s." % str(purchased))
	if _focus_name(viewport) != "ShopItemButton1":
		_errors.append("shop: after buying item 2 focus must move to nearest remaining item 1 (lower index wins ties), got %s." % _focus_name(viewport))
	await _press_accept(viewport)
	purchased = main.get("current_shop_purchased")
	if purchased[0]:
		_errors.append("shop: a second accept must not buy the first item.")
	# Buy everything left: focus ends on the leave button.
	main.set("current_shop_purchased", [true, true, true, false])
	main.ui._show_shop_screen()
	await _settle()
	(main.find_child("ShopItemButton3", true, false) as Button).grab_focus()
	await process_frame
	await _press_accept(viewport)
	if _focus_name(viewport) != "ShopLeaveButton":
		_errors.append("shop: with no items left focus must go to ShopLeaveButton, got %s." % _focus_name(viewport))


func _reachable_names(start: Control) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var current: Control = queue.pop_front()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var next := current.find_valid_focus_neighbor(side)
			if next != null and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _test_settings_reachability(main: Node) -> void:
	main.ui._show_settings_menu()
	await _settle()
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	if tabs == null:
		_errors.append("settings: SettingsTabs missing.")
		return
	for tab_index in range(4):
		(main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Button).emit_signal("pressed")
		await _settle()
		var start := main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Control
		var seen := _reachable_names(start)
		var names := {}
		for control in seen:
			names[str((control as Control).name)] = true
		if not names.has("SettingsBackButton"):
			_errors.append("settings tab %d: SettingsBackButton unreachable by direction input." % tab_index)
		if tab_index != 3 and not names.has("SettingsUpdateButton"):
			_errors.append("settings tab %d: SettingsUpdateButton unreachable by direction input." % tab_index)
		# Every visible enabled button on this tab must be reachable.
		for node in main.find_children("*", "BaseButton", true, false):
			var button := node as BaseButton
			if button.is_visible_in_tree() and not button.disabled and button.focus_mode == Control.FOCUS_ALL and not names.has(str(button.name)):
				var tab_control := tabs.get_current_tab_control()
				if tab_control != null and tab_control.is_ancestor_of(button):
					_errors.append("settings tab %d: %s unreachable." % [tab_index, button.name])
