extends SceneTree

## Persistent runtime visual evidence for SCRUM-993. Run windowed through
## tools/godot_gate.py so SubViewport textures contain real renderer output.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const TARGETS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const STATES := ["default", "focus", "unaffordable", "purchased"]


func _initialize() -> void:
	var output_dir := ProjectSettings.globalize_path("res://docs/design/previews/scrum993_shop_gold_shell/runtime")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := PackedStringArray(["# SCRUM-993 Shop Runtime Visual Matrix", ""])
	for viewport_size in TARGETS:
		for state in STATES:
			await _capture(viewport_size, state, output_dir, report)
	var report_file := FileAccess.open("%s/runtime_matrix.md" % output_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report))
		report_file.close()
	print("SCRUM-993 runtime visual capture completed.")
	quit()


func _capture(viewport_size: Vector2i, state: String, output_dir: String, report: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 3)
	main.set("current_node_type", "shop")
	main.set("current_route_choice", "scrum993_capture_%s" % state)
	var player := PLAYER_SCENE.instantiate()
	viewport.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", 0 if state == "unaffordable" else 12000)
	main.call("_store_player_snapshot", player)
	player.queue_free()
	main.set("current_shop_items", _items())
	main.set("current_shop_purchased", [state == "purchased", false, false, false])
	main.set("current_shop_node_key", "1:3:shop:scrum993_capture_%s" % state)
	main.ui._show_shop_screen()
	for _frame in range(10):
		await process_frame
	var first := main.find_child("ShopItemButton0", true, false) as Button
	var tooltip := main.find_child("ShopTooltipPanel", true, false) as Panel
	if state == "focus" or state == "unaffordable":
		var focus_target := first
		if focus_target != null and focus_target.disabled:
			focus_target = main.find_child("ShopItemButton1", true, false) as Button
		if focus_target != null:
			focus_target.grab_focus()
	elif state == "default":
		var focus_owner := viewport.gui_get_focus_owner()
		if focus_owner != null:
			focus_owner.release_focus()
		if tooltip != null:
			tooltip.visible = false
	for _frame in range(5):
		await process_frame

	var root_node := main.find_child("ShopScreen", true, false) as Control
	var back := main.find_child("ShopLeaveButton", true, false) as Button
	report.append("## %s %dx%d" % [state, viewport_size.x, viewport_size.y])
	report.append("- safe: `%s`" % str(root_node.get_meta("gold_shell_content_rect", Rect2()) if root_node != null else Rect2()))
	report.append("- inner: `%s`" % str(root_node.get_meta("gold_shell_inner_rect", Rect2()) if root_node != null else Rect2()))
	report.append("- first product: `%s`" % str(first.get_global_rect() if first != null else Rect2()))
	report.append("- tooltip: `%s`, visible=%s" % [str(tooltip.get_global_rect() if tooltip != null else Rect2()), str(tooltip.visible if tooltip != null else false)])
	report.append("- back: `%s`" % str(back.get_global_rect() if back != null else Rect2()))
	report.append("")
	if DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/%s_%dx%d.png" % [output_dir, state, viewport_size.x, viewport_size.y])
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _items() -> Array:
	return [
		{"id": "scrum993_foreign_long", "title": "Невероятно длинное имя иномирового артефакта", "description": "Проверка полной фиксированной подсказки.", "kind": "artifact", "cost": 9999, "tier": "legendary", "classes": ["dark_mage"], "class_affinity": ["dark_mage"], "mods": {"damage_multiplier": 0.1}},
		{"id": "scrum993_speed", "title": "Сапоги странника", "description": "Скорость движения повышена.", "kind": "artifact", "cost": 125, "mods": {"move_speed_multiplier": 0.05}},
		{"id": "scrum993_guard", "title": "Страж-оберег", "description": "Защита повышена.", "kind": "artifact", "cost": 250, "mods": {"defense_flat": 0.04}},
		{"id": "scrum993_lens", "title": "Линза охотника", "description": "Шанс критического удара повышен.", "kind": "artifact", "cost": 500, "mods": {"crit_chance_flat": 0.03}},
	]
