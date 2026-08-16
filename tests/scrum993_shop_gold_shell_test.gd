extends "res://tests/runtime_smoke_test.gd"

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const FRAME_PATH := "res://assets/sprites/ui/meta40/frame_border.png"
const BACKDROP_PATH := "res://assets/backgrounds/ui/ui_backdrop_merchant_archive.png"
const TARGETS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _errors: PackedStringArray = []


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_target(viewport_size, 5000)
	await _validate_unaffordable()
	await _validate_purchased()
	await _validate_live_resize_and_stock()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	_finish("SCRUM-993 Shop gold shell test passed at 1280x720, 1920x1080, 2560x1440 and live resize.")


func _validate_target(viewport_size: Vector2i, money: int) -> void:
	var fixture := await _shop_fixture(viewport_size, money)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	await _assert_layout(main, viewport_size, "fresh %s" % str(viewport_size))
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _validate_unaffordable() -> void:
	var fixture := await _shop_fixture(Vector2i(1280, 720), 0)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var button := main.find_child("ShopItemButton0", true, false) as Button
	if button == null:
		_errors.append("unaffordable: missing ShopItemButton0.")
	else:
		var tooltip := str(button.get_meta("shop_tooltip_text", ""))
		if not tooltip.contains("Не хватает монет"):
			_errors.append("unaffordable: fixed tooltip must explain insufficient money.")
		if button.find_child("ShopItemStateOverlay", true, false) != null:
			_errors.append("unaffordable: explanation must not cover the icon/caption/price with a full-slot overlay.")
		var before := (main.get("current_shop_purchased") as Array).duplicate()
		button.emit_signal("pressed")
		await _settle()
		if (main.get("current_shop_purchased") as Array) != before or int((main.get("run_player_snapshot") as Dictionary).get("money", -1)) != 0:
			_errors.append("unaffordable: press must not spend money or mutate purchased state.")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _validate_purchased() -> void:
	var fixture := await _shop_fixture(Vector2i(1280, 720), 12000, [true, false, false, false])
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var button := main.find_child("ShopItemButton0", true, false) as Button
	if button == null or not button.disabled or button.find_child("ShopEmptyHook", true, false) == null:
		_errors.append("purchased: first deterministic product must render as a disabled empty hook.")
	elif not str(button.get_meta("shop_tooltip_text", "")).contains("Уже куплено"):
		_errors.append("purchased: product metadata must retain the purchased explanation.")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _validate_live_resize_and_stock() -> void:
	var fixture := await _shop_fixture(Vector2i(2560, 1440), 5000)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var initial_ids := _shop_ids(main)
	var initial_purchased := (main.get("current_shop_purchased") as Array).duplicate()
	viewport.size = Vector2i(1280, 720)
	await _settle()
	await _assert_layout(main, Vector2i(1280, 720), "live 2560->1280")
	if _shop_ids(main) != initial_ids or (main.get("current_shop_purchased") as Array) != initial_purchased:
		_errors.append("live resize must not rebuild Shop stock/purchased state.")
	viewport.size = Vector2i(2560, 1440)
	await _settle()
	await _assert_layout(main, Vector2i(2560, 1440), "live 1280->2560")
	if _shop_ids(main) != initial_ids:
		_errors.append("reverse live resize must keep exact Shop stock ids.")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _shop_fixture(viewport_size: Vector2i, money: int, purchased := [false, false, false, false]) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 3)
	main.set("current_node_type", "shop")
	main.set("current_route_choice", "scrum993")
	var player := PLAYER_SCENE.instantiate()
	viewport.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", money)
	main.call("_store_player_snapshot", player)
	player.queue_free()
	main.set("current_shop_items", _deterministic_shop_items())
	main.set("current_shop_purchased", (purchased as Array).duplicate())
	main.set("current_shop_node_key", "1:3:shop:scrum993")
	main.ui._show_shop_screen()
	await _settle()
	return {"viewport": viewport, "main": main}


func _assert_layout(main: Node, viewport_size: Vector2i, context: String) -> void:
	var expected := _expected(viewport_size)
	var root_node := main.find_child("ShopScreen", true, false) as Control
	var frame := main.find_child("ShopGoldFrame", true, false) as Panel
	if root_node == null or frame == null:
		_errors.append("%s: missing ShopScreen/ShopGoldFrame." % context)
		return
	if frame.get_parent().get_child(frame.get_parent().get_child_count() - 1) != frame or frame.z_index != 100 or frame.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_errors.append("%s: ShopGoldFrame must be final, z=100 and mouse-ignore." % context)
	var frame_style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if frame_style == null or frame_style.texture == null or frame_style.texture.resource_path != FRAME_PATH or frame_style.draw_center:
		_errors.append("%s: ShopGoldFrame must use the hollow production gold shell." % context)
	_assert_rect(root_node.get_meta("gold_shell_content_rect", Rect2()), expected["safe"], "%s safe" % context)
	_assert_rect(root_node.get_meta("gold_shell_inner_rect", Rect2()), expected["inner"], "%s inner" % context)
	if main.find_child("UpgradeFabButton", true, false) != null:
		_errors.append("%s: Shop must not expose manual Attribute Shop UpgradeFabButton." % context)

	var clip := main.find_child("ShopBackgroundClip", true, false) as Control
	var backdrop := main.find_child("ShopGoldBackdrop", true, false) as TextureRect
	if clip == null or backdrop == null or backdrop.texture == null:
		_errors.append("%s: missing contained merchant backdrop." % context)
	else:
		_assert_rect(clip.get_global_rect(), expected["safe"], "%s backdrop clip" % context)
		_assert_rect(backdrop.get_meta("scrum993_visible_image_rect", Rect2()), expected["visible_backdrop"], "%s visible backdrop" % context, 1.5)
		if not clip.clip_contents or backdrop.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED or backdrop.texture.resource_path != BACKDROP_PATH:
			_errors.append("%s: merchant backdrop must be clipped/contained without crop." % context)

	_assert_named_rect(main, "ShopHeader", expected["header"], context)
	_assert_named_rect(main, "ShopTitleLabel", expected["title"], context)
	_assert_named_rect(main, "ShopSubtitleLabel", expected["subtitle"], context)
	_assert_named_rect(main, "ShopLeaveButton", expected["back"], context)
	var subtitle := main.find_child("ShopSubtitleLabel", true, false) as Label
	if subtitle == null or subtitle.text != "Выбери предмет — описание появится ниже.":
		_errors.append("%s: Shop subtitle must use the compact non-clipped responsive copy." % context)
	elif _label_text_width(subtitle) > subtitle.size.x + 1.0:
		_errors.append("%s: Shop subtitle text width %.1f exceeds authored %.1fpx zone." % [context, _label_text_width(subtitle), subtitle.size.x])
	var item_rects: Array = expected["slots"]
	var sibling_rects: Array[Rect2] = []
	var item_buttons: Array[Button] = []
	for index in range(4):
		var button := main.find_child("ShopItemButton%d" % index, true, false) as Button
		if button == null:
			_errors.append("%s: missing ShopItemButton%d." % [context, index])
			continue
		_assert_rect(button.get_global_rect(), item_rects[index], "%s ShopItemButton%d" % [context, index])
		sibling_rects.append(button.get_global_rect())
		item_buttons.append(button)
		if button.tooltip_text != "" or str(button.get_meta("shop_tooltip_text", "")).strip_edges() == "":
			_errors.append("%s: ShopItemButton%d must use only the fixed tooltip band." % [context, index])
		for child_node in button.find_children("*", "Control", true, false):
			var child := child_node as Control
			var child_visual_rect := _visual_global_rect(child) if child != null else Rect2()
			if child != null and child.visible and child.is_visible_in_tree() and child_visual_rect.has_area() and not button.get_global_rect().grow(1.0).encloses(child_visual_rect):
				_errors.append("%s: %s visual rect %s escapes ShopItemButton%d %s." % [context, str(child.name), str(child_visual_rect), index, str(button.get_global_rect())])
	_assert_pairwise_disjoint(sibling_rects, "%s item slots" % context)
	if not item_buttons.is_empty():
		var caption := item_buttons[0].find_child("ShopItemCaption", true, false) as Label
		var price := item_buttons[0].find_child("ShopItemPrice", true, false) as Label
		if caption == null or caption.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS or caption.max_lines_visible != 1:
			_errors.append("%s: worst-case long caption must be a one-line ellipsis label." % context)
		if price == null or price.text != "9999":
			_errors.append("%s: deterministic first product must exercise a four-digit price." % context)
		if item_buttons[0].find_child("ShopAffinityNote", true, false) == null:
			_errors.append("%s: deterministic first product must exercise foreign-affinity marker." % context)

	var tooltip := main.find_child("ShopTooltipPanel", true, false) as Panel
	var first := main.find_child("ShopItemButton0", true, false) as Button
	if tooltip == null or first == null:
		_errors.append("%s: missing fixed tooltip/first product." % context)
	else:
		first.grab_focus()
		await _settle()
		if not tooltip.visible:
			_errors.append("%s: focused product must reveal fixed tooltip." % context)
		_assert_rect(tooltip.get_global_rect(), expected["tooltip"], "%s tooltip" % context)
		_assert_named_rect(main, "ShopTooltipText", expected["tooltip_content"], context)
		var tooltip_label := main.find_child("ShopTooltipText", true, false) as Label
		if tooltip_label == null or not tooltip_label.text.contains("Цена: 9999g") or not tooltip_label.text.contains("Класс:") or not tooltip_label.text.contains("Не хватает монет"):
			_errors.append("%s: fixed tooltip must expose full title/effect/price/class/state content." % context)
		elif tooltip_label.get_visible_line_count() < tooltip_label.get_line_count():
			_errors.append("%s: fixed tooltip clips %d of %d wrapped lines." % [context, tooltip_label.get_line_count() - tooltip_label.get_visible_line_count(), tooltip_label.get_line_count()])
		var tooltip_style := tooltip.get_theme_stylebox("panel") as StyleBoxTexture
		if tooltip_style == null:
			_errors.append("%s: fixed tooltip must retain the authored texture frame." % context)
		else:
			if tooltip_style.content_margin_left + 0.1 < tooltip_style.texture_margin_left + 4.0 or tooltip_style.content_margin_top + 0.1 < tooltip_style.texture_margin_top + 4.0:
				_errors.append("%s: tooltip content margins must clear texture rails plus reserve." % context)
		var back_for_hide := main.find_child("ShopLeaveButton", true, false) as Button
		if back_for_hide != null:
			back_for_hide.grab_focus()
			await _settle()
			if tooltip.visible:
				_errors.append("%s: fixed tooltip must hide after product focus leaves." % context)
			first.grab_focus()
			await _settle()

	var hud := main.find_child("RunResourceHud", true, false) as Control
	if hud == null or not (expected["hud"] as Rect2).grow(1.0).encloses(hud.get_global_rect()):
		_errors.append("%s: RunResourceHud must fit the authored header zone, got %s." % [context, str(hud.get_global_rect() if hud != null else Rect2())])
	if hud != null and hud.get_global_rect().intersects(expected["title"] as Rect2):
		_errors.append("%s: RunResourceHud overlaps Shop title." % context)

	var back := main.find_child("ShopLeaveButton", true, false) as Button
	if first != null and back != null:
		for index in range(item_buttons.size()):
			var item := item_buttons[index]
			var previous := item_buttons[(index - 1 + item_buttons.size()) % item_buttons.size()]
			var next := item_buttons[(index + 1) % item_buttons.size()]
			if item.get_node_or_null(item.focus_neighbor_left) != previous or item.get_node_or_null(item.focus_neighbor_right) != next or item.get_node_or_null(item.focus_neighbor_bottom) != back or item.get_node_or_null(item.focus_neighbor_top) != back:
				_errors.append("%s: ShopItemButton%d focus ring/cross links are incomplete." % [context, index])
		if back.get_node_or_null(back.focus_neighbor_top) != first or back.get_node_or_null(back.focus_neighbor_bottom) != first or back.get_node_or_null(back.focus_neighbor_left) != back or back.get_node_or_null(back.focus_neighbor_right) != back:
			_errors.append("%s: Back focus return/self links are incomplete." % context)
	if not main.find_children("*", "ScrollContainer", true, false).is_empty():
		_errors.append("%s: Shop gold shell must not need a scrollbar." % context)


func _expected(viewport_size: Vector2i) -> Dictionary:
	match viewport_size:
		Vector2i(1280, 720):
			return {"safe": Rect2(133,113,1014,494), "inner": Rect2(157,137,966,446), "visible_backdrop": Rect2(201,113,878,494), "header": Rect2(157,137,966,70), "hud": Rect2(181,147,480,50), "title": Rect2(675,137,330,34), "subtitle": Rect2(675,173,330,24), "slots": [Rect2(340,219,132,140),Rect2(496,219,132,140),Rect2(652,219,132,140),Rect2(808,219,132,140)], "tooltip": Rect2(290,361,700,148), "tooltip_content": Rect2(315,378,650,114), "back": Rect2(500,511,280,64)}
		Vector2i(1920, 1080):
			return {"safe": Rect2(200,169,1520,742), "inner": Rect2(224,193,1472,694), "visible_backdrop": Rect2(300,169,1320,742), "header": Rect2(224,193,1472,100), "hud": Rect2(248,209,720,72), "title": Rect2(996,193,560,52), "subtitle": Rect2(996,251,560,32), "slots": [Rect2(572,325,164,164),Rect2(776,325,164,164),Rect2(980,325,164,164),Rect2(1184,325,164,164)], "tooltip": Rect2(690,513,540,200), "tooltip_content": Rect2(721,537,478,152), "back": Rect2(780,795,360,72)}
		_:
			return {"safe": Rect2(267,225,2026,990), "inner": Rect2(299,257,1962,926), "visible_backdrop": Rect2(400,225,1760,990), "header": Rect2(299,257,1962,120), "hud": Rect2(323,273,930,88), "title": Rect2(1281,257,700,64), "subtitle": Rect2(1281,327,700,40), "slots": [Rect2(810,421,196,196),Rect2(1058,421,196,196),Rect2(1306,421,196,196),Rect2(1554,421,196,196)], "tooltip": Rect2(980,649,600,240), "tooltip_content": Rect2(1016,677,528,184), "back": Rect2(1100,1059,360,88)}


func _shop_ids(main: Node) -> Array[String]:
	var ids: Array[String] = []
	for item in main.get("current_shop_items") as Array:
		ids.append(str((item as Dictionary).get("id", "")))
	return ids


func _deterministic_shop_items() -> Array:
	return [
		{"id": "scrum993_foreign_long", "title": "Невероятно длинное имя иномирового артефакта", "description": "Проверка полной фиксированной подсказки.", "kind": "artifact", "cost": 9999, "tier": "legendary", "classes": ["dark_mage"], "class_affinity": ["dark_mage"], "mods": {"damage_multiplier": 0.1}},
		{"id": "scrum993_speed", "title": "Сапоги странника", "description": "Скорость движения повышена.", "kind": "artifact", "cost": 125, "mods": {"move_speed_multiplier": 0.05}},
		{"id": "scrum993_guard", "title": "Страж-оберег", "description": "Защита повышена.", "kind": "artifact", "cost": 250, "mods": {"defense_flat": 0.04}},
		{"id": "scrum993_lens", "title": "Линза охотника", "description": "Шанс критического удара повышен.", "kind": "artifact", "cost": 500, "mods": {"crit_chance_flat": 0.03}},
	]


func _visual_global_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var transform := control.get_global_transform()
	var corners := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum = minimum.min(corner as Vector2)
		maximum = maximum.max(corner as Vector2)
	return Rect2(minimum, maximum - minimum)


func _label_text_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x if font != null else INF


func _assert_named_rect(main: Node, node_name: String, expected: Rect2, context: String) -> void:
	var control := main.find_child(node_name, true, false) as Control
	if control == null:
		_errors.append("%s: missing %s." % [context, node_name])
		return
	_assert_rect(control.get_global_rect(), expected, "%s %s" % [context, node_name])


func _assert_rect(actual: Rect2, expected: Rect2, label: String, tolerance := 1.1) -> void:
	if actual.position.distance_to(expected.position) > tolerance or actual.size.distance_to(expected.size) > tolerance:
		_errors.append("%s rect %s != %s." % [label, str(actual), str(expected)])


func _assert_pairwise_disjoint(rects: Array[Rect2], label: String) -> void:
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				_errors.append("%s: %s intersects %s." % [label, str(rects[i]), str(rects[j])])


func _settle() -> void:
	for _frame in range(7):
		await process_frame
