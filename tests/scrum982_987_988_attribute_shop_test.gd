extends SceneTree

# Focused acceptance gate for the combined SCRUM-982/987/988 contract:
# - the paid Attribute Shop has no manual Route/Rest/Shop/Event entry;
# - pending Level Up remains reachable on Route and Rest;
# - the mandatory post-combat shop uses the shared hollow gold shell;
# - two default or three Atlas offers remain in one horizontal row at every
#   authored target and after a live resize;
# - the full influence and before/after preview are visible on every card.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const FRAME_PATH_SUFFIX := "meta40/frame_border.png"
const EPSILON := 2.0
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const EXPECTED_INNER := {
	Vector2i(1280, 720): Rect2(157, 137, 966, 446),
	Vector2i(1920, 1080): Rect2(224, 193, 1472, 694),
	Vector2i(2560, 1440): Rect2(299, 257, 1962, 926),
}

var _errors: PackedStringArray = []
var _completion_count := 0


func _initialize() -> void:
	await _validate_removed_manual_entry_and_pending_level_up()
	await _validate_pending_level_up_live_resize()
	for viewport_size in TARGETS:
		await _validate_offer_count(viewport_size, false, 2)
		await _validate_offer_count(viewport_size, true, 3)
	await _validate_legacy_offer_normalization()
	await _validate_buy_reroll_skip_semantics()
	await _validate_live_resize()
	if not _errors.is_empty():
		for error in _errors:
			push_error("[SCRUM-982/987/988 Attribute Shop] %s" % error)
		quit(1)
		return
	print("SCRUM-982/987/988 Attribute Shop focused test passed: manual entry removal, Level Up preservation, 2/3-offer gold shell, semantics and live resize.")
	quit(0)


func _validate_removed_manual_entry_and_pending_level_up() -> void:
	var fixture := await _base_fixture(Vector2i(1280, 720), 500)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	main.set("route_stage", 0)
	main.set("route_nodes", main.route._generate_route())
	main.set("pending_level_ups", 0)

	main.route._show_battle_map()
	await _settle()
	_assert_no_manual_attribute_entry(main, "Route pending=0")

	main.ui._show_rest_screen()
	await _settle()
	_assert_no_manual_attribute_entry(main, "Rest pending=0")

	main.set("current_node_type", "shop")
	main.set("current_route_choice", "scrum982_manual_entry_gate")
	main.ui._show_shop_screen()
	await _settle()
	_assert_no_manual_attribute_entry(main, "Shop pending=0")

	main.ui._show_event_screen({"name": "Тестовое событие", "event_id": "caravan_bandits"})
	await _settle()
	_assert_no_manual_attribute_entry(main, "Event pending=0")

	# Route rebuilds its HUD and must explicitly retain the independent pending
	# Level Up affordance without recreating the removed paid-stat FAB.
	main.set("pending_level_ups", 2)
	main.route._show_battle_map()
	await _settle()
	_assert_pending_level_up(main, "Route pending=2", 2)
	_assert_no_upgrade_fab(main, "Route pending=2")

	# Rest is another non-combat destination: opening it must not strand pending
	# level rewards even though manual Attribute Shop access remains forbidden.
	main.ui._show_rest_screen()
	await _settle()
	_assert_pending_level_up(main, "Rest pending=2", 2)
	_assert_no_upgrade_fab(main, "Rest pending=2")

	await _teardown(viewport, main)


func _validate_offer_count(viewport_size: Vector2i, atlas_extra: bool, expected_count: int) -> void:
	var fixture := await _attribute_shop_fixture(viewport_size, 500, atlas_extra)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var context := "%s %s offers" % [str(viewport_size), "Atlas" if atlas_extra else "default"]
	_assert_attribute_shop_layout(main, viewport_size, expected_count, context)
	await _teardown(viewport, main)


func _validate_pending_level_up_live_resize() -> void:
	var fixture := await _base_fixture(Vector2i(2560, 1440), 500)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	main.set("route_stage", 0)
	main.set("route_nodes", main.route._generate_route())
	main.set("pending_level_ups", 2)
	main.route._show_battle_map()
	await _settle()
	_assert_pending_level_up(main, "Route pending 2560x1440", 2)
	viewport.size = Vector2i(1280, 720)
	await _settle()
	_assert_pending_level_up(main, "Route pending live 2560->1280", 2)
	viewport.size = Vector2i(1920, 1080)
	await _settle()
	_assert_pending_level_up(main, "Route pending live 1280->1920", 2)
	main.ui._show_rest_screen()
	await _settle()
	_assert_pending_level_up(main, "Rest pending 1920x1080", 2)
	viewport.size = Vector2i(2560, 1440)
	await _settle()
	_assert_pending_level_up(main, "Rest pending live 1920->2560", 2)
	await _teardown(viewport, main)


func _validate_buy_reroll_skip_semantics() -> void:
	# Buying spends the exact live cost, applies +1 to the selected base stat,
	# clears the fixed offer and invokes the mandatory continuation once.
	_completion_count = 0
	var buy_fixture := await _attribute_shop_fixture(Vector2i(1280, 720), 500, false, ["strength", "agility"])
	var buy_viewport := buy_fixture["viewport"] as SubViewport
	var buy_main := buy_fixture["main"] as Node
	var buy_button := buy_main.find_child("AttributeOffer_strength", true, false) as Button
	var buy_cost := int(buy_main.ui._attribute_buy_cost())
	var buy_snapshot := (buy_main.get("run_player_snapshot") as Dictionary).duplicate(true)
	var money_before := int(buy_snapshot.get("money", -1))
	var strength_before := float((buy_snapshot.get("stats", {}) as Dictionary).get("strength", 0.0))
	if buy_button == null or buy_button.disabled:
		_errors.append("buy semantics: affordable strength offer is missing/disabled.")
	else:
		buy_button.pressed.emit()
		await _settle()
		var after_snapshot := buy_main.get("run_player_snapshot") as Dictionary
		if int(after_snapshot.get("money", -1)) != money_before - buy_cost:
			_errors.append("buy semantics: expected money %d -> %d, got %s." % [money_before, money_before - buy_cost, str(after_snapshot.get("money"))])
		if absf(float((after_snapshot.get("stats", {}) as Dictionary).get("strength", 0.0)) - (strength_before + 1.0)) > 0.001:
			_errors.append("buy semantics: strength was not increased by exactly +1.")
		if not (buy_main.get("attribute_offer") as Array).is_empty():
			_errors.append("buy semantics: purchased fixed offer must be cleared.")
		if _completion_count != 1:
			_errors.append("buy semantics: continuation must run exactly once, got %d." % _completion_count)
	await _teardown(buy_viewport, buy_main)

	# Reroll must spend its own live cost, consume one charge and replace the
	# offer. A one-card sentinel makes the replacement assertion deterministic.
	_completion_count = 0
	var reroll_fixture := await _attribute_shop_fixture(Vector2i(1280, 720), 500, false, ["strength"])
	var reroll_viewport := reroll_fixture["viewport"] as SubViewport
	var reroll_main := reroll_fixture["main"] as Node
	(reroll_main.get("rng") as RandomNumberGenerator).seed = 982987988
	var reroll_button := reroll_main.find_child("AttributeRerollButton", true, false) as Button
	var reroll_cost := int(reroll_main.ui._attribute_reroll_cost())
	var reroll_money_before := int((reroll_main.get("run_player_snapshot") as Dictionary).get("money", -1))
	var rerolls_before := int(reroll_main.get("attribute_rerolls_left"))
	var reroll_offer_before := (reroll_main.get("attribute_offer") as Array).duplicate()
	if reroll_button == null or reroll_button.disabled:
		_errors.append("reroll semantics: affordable reroll button is missing/disabled.")
	else:
		reroll_button.pressed.emit()
		await _settle()
		var rerolled_offer := reroll_main.get("attribute_offer") as Array
		if rerolled_offer.size() != 2 or rerolled_offer == reroll_offer_before:
			_errors.append("reroll semantics: default offer must be replaced by two choices, got %s." % str(rerolled_offer))
		if _unique_strings(rerolled_offer).size() != rerolled_offer.size():
			_errors.append("reroll semantics: replacement choices must be unique, got %s." % str(rerolled_offer))
		if int((reroll_main.get("run_player_snapshot") as Dictionary).get("money", -1)) != reroll_money_before - reroll_cost:
			_errors.append("reroll semantics: expected exact reroll cost %d to be spent." % reroll_cost)
		if int(reroll_main.get("attribute_rerolls_left")) != rerolls_before - 1:
			_errors.append("reroll semantics: reroll charge was not consumed exactly once.")
		if _completion_count != 0:
			_errors.append("reroll semantics: reroll must not invoke the continuation.")
	await _teardown(reroll_viewport, reroll_main)

	# Skip is a pure continuation: no gold, stat, offer or reroll mutation.
	_completion_count = 0
	var skip_fixture := await _attribute_shop_fixture(Vector2i(1280, 720), 500, false, ["energy", "knowledge"])
	var skip_viewport := skip_fixture["viewport"] as SubViewport
	var skip_main := skip_fixture["main"] as Node
	var skip_button := skip_main.find_child("AttributeSkipButton", true, false) as Button
	var state_before := (skip_main.get("run_player_snapshot") as Dictionary).duplicate(true)
	var offer_before := (skip_main.get("attribute_offer") as Array).duplicate()
	var charges_before := int(skip_main.get("attribute_rerolls_left"))
	if skip_button == null or skip_button.disabled:
		_errors.append("skip semantics: skip button is missing/disabled.")
	else:
		skip_button.pressed.emit()
		await _settle()
		if _completion_count != 1:
			_errors.append("skip semantics: continuation must run exactly once, got %d." % _completion_count)
		if (skip_main.get("run_player_snapshot") as Dictionary) != state_before \
				or (skip_main.get("attribute_offer") as Array) != offer_before \
				or int(skip_main.get("attribute_rerolls_left")) != charges_before:
			_errors.append("skip semantics: skip must not mutate money/stats/offer/reroll charges.")
	await _teardown(skip_viewport, skip_main)


func _validate_legacy_offer_normalization() -> void:
	var fixture := await _attribute_shop_fixture(
		Vector2i(1280, 720), 500, true,
		["strength", "strength", "removed_stat", "agility", "endurance", "leadership"]
	)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var normalized := main.get("attribute_offer") as Array
	if normalized.size() != 3 or _unique_strings(normalized).size() != 3:
		_errors.append("legacy normalization: expected exactly 3 unique Atlas offers, got %s." % str(normalized))
	for stat_id in normalized:
		if stat_id not in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
			_errors.append("legacy normalization: non-canonical stat survived: %s." % str(stat_id))
	_assert_attribute_shop_layout(main, Vector2i(1280, 720), 3, "legacy 4+/duplicate offer normalization")
	await _teardown(viewport, main)


func _validate_live_resize() -> void:
	var fixture := await _attribute_shop_fixture(Vector2i(2560, 1440), 500, true)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var original_offer := (main.get("attribute_offer") as Array).duplicate()
	_assert_attribute_shop_layout(main, Vector2i(2560, 1440), 3, "live initial 2560x1440")

	viewport.size = Vector2i(1280, 720)
	await _settle()
	_assert_attribute_shop_layout(main, Vector2i(1280, 720), 3, "live 2560x1440 -> 1280x720")
	if (main.get("attribute_offer") as Array) != original_offer:
		_errors.append("live resize: shrinking must preserve the exact Atlas offer.")

	viewport.size = Vector2i(1920, 1080)
	await _settle()
	_assert_attribute_shop_layout(main, Vector2i(1920, 1080), 3, "live 1280x720 -> 1920x1080")
	if (main.get("attribute_offer") as Array) != original_offer:
		_errors.append("live resize: growing must preserve the exact Atlas offer.")
	await _teardown(viewport, main)


func _assert_attribute_shop_layout(main: Node, viewport_size: Vector2i, expected_count: int, context: String) -> void:
	var screen := main.find_child("AttributeShopScreen", true, false) as Control
	var frame := main.find_child("AttributeShopFrame", true, false) as Panel
	var title := main.find_child("AttributeShopTitle", true, false) as Label
	var money := main.find_child("AttributeShopMoney", true, false) as Label
	var offers := main.find_child("AttributeOffers", true, false) as HBoxContainer
	var actions := main.find_child("AttributeShopActions", true, false) as HBoxContainer
	if screen == null or frame == null or title == null or money == null or offers == null or actions == null:
		_errors.append("%s: incomplete Attribute Shop gold-shell node inventory." % context)
		return

	var expected_inner: Rect2 = EXPECTED_INNER.get(viewport_size, Rect2())
	var inner: Rect2 = screen.get_meta("gold_shell_inner_rect", Rect2()) as Rect2
	if not _rect_near(inner, expected_inner):
		_errors.append("%s: exact gold_shell_inner_rect drifted: %s vs %s." % [context, str(inner), str(expected_inner)])
	for control in [title, money, offers, actions]:
		if not _encloses(inner, (control as Control).get_global_rect()):
			_errors.append("%s: %s %s escapes exact inner rect %s." % [context, str((control as Control).name), str((control as Control).get_global_rect()), str(inner)])

	if screen.find_child("AttributeShopPanel", true, false) != null:
		_errors.append("%s: redundant AttributeShopPanel must remain removed." % context)
	# FAN-1927 (спека fan1883_attribute_clarity, AS.DetailDrawer): единственный
	# разрешённый ScrollContainer — approved drawer длинной копии. На 1080p+ он
	# виден между рядом и действиями; на compact-вьюпортах скрыт (длинная копия —
	# скроллируемый tooltip), и другие ScrollContainer'ы по-прежнему запрещены.
	var drawer := screen.find_child("AttributeShopDetailDrawer", true, false) as PanelContainer
	var drawer_scroll := screen.find_child("AttributeShopDetailScroll", true, false) as ScrollContainer
	var drawer_label := screen.find_child("AttributeShopDetailLabel", true, false) as Label
	if drawer == null or drawer_scroll == null or drawer_label == null:
		_errors.append("%s: approved AS.DetailDrawer (panel/scroll/label) is missing." % context)
	else:
		if drawer_label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			_errors.append("%s: AS.DetailDrawer label must not use ellipsis trimming." % context)
		var drawer_expected_visible: bool = viewport_size.y >= 1000.0
		if drawer.visible != drawer_expected_visible:
			_errors.append("%s: AS.DetailDrawer visible=%s, expected %s." % [context, drawer.visible, drawer_expected_visible])
		if drawer.visible:
			if not _encloses(inner, drawer.get_global_rect()):
				_errors.append("%s: AS.DetailDrawer %s escapes inner rect %s." % [context, str(drawer.get_global_rect()), str(inner)])
			if drawer.get_global_rect().position.y < offers.get_global_rect().end.y - 1.0:
				_errors.append("%s: AS.DetailDrawer overlaps the offer row." % context)
			if drawer.get_global_rect().end.y > actions.get_global_rect().position.y + 1.0:
				_errors.append("%s: AS.DetailDrawer overlaps the actions band." % context)
			if str(drawer_label.text).strip_edges() == "":
				_errors.append("%s: AS.DetailDrawer has no focused-card copy." % context)
	for scroll_node in screen.find_children("*", "ScrollContainer", true, false):
		if (scroll_node as Node).name != "AttributeShopDetailScroll":
			_errors.append("%s: unexpected ScrollContainer '%s' outside the approved drawer." % [context, (scroll_node as Node).name])

	if frame.get_parent() != screen or screen.get_child(screen.get_child_count() - 1) != frame:
		_errors.append("%s: AttributeShopFrame must be the final direct child above all content." % context)
	if frame.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_errors.append("%s: AttributeShopFrame must ignore mouse input." % context)
	var frame_style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if frame_style == null or frame_style.texture == null:
		_errors.append("%s: AttributeShopFrame must use the production StyleBoxTexture." % context)
	else:
		if frame_style.draw_center:
			_errors.append("%s: AttributeShopFrame must stay hollow (draw_center=false)." % context)
		if not frame_style.texture.resource_path.ends_with(FRAME_PATH_SUFFIX):
			_errors.append("%s: unexpected AttributeShopFrame texture %s." % [context, frame_style.texture.resource_path])

	if offers.get_child_count() != expected_count:
		_errors.append("%s: expected %d offer cards, got %d." % [context, expected_count, offers.get_child_count()])
	var card_rects: Array[Rect2] = []
	var first_y := NAN
	for offer_node in offers.get_children():
		var offer := offer_node as Button
		if offer == null:
			_errors.append("%s: AttributeOffers contains a non-Button child." % context)
			continue
		var offer_rect := offer.get_global_rect()
		card_rects.append(offer_rect)
		if is_nan(first_y):
			first_y = offer_rect.position.y
		elif absf(offer_rect.position.y - first_y) > EPSILON:
			_errors.append("%s: %s leaves the single horizontal offer row." % [context, str(offer.name)])
		if not _encloses(inner, offer_rect) or not _encloses(offers.get_global_rect(), offer_rect):
			_errors.append("%s: %s escapes its row or the frame inner zone." % [context, str(offer.name)])
		_assert_visible_effect_label(offer, "Influence", "Влияет на:", context)
		_assert_visible_effect_label(offer, "Preview", "", context)
		var interpretation := offer.find_child("%sInterpretation" % offer.name, false, false) as Label
		if interpretation == null or interpretation.text.strip_edges() == "" or not offer.tooltip_text.contains(interpretation.text):
			_errors.append("%s: %s tooltip must preserve the unabridged class interpretation." % [context, offer.name])
		var influence := offer.find_child("%sInfluence" % offer.name, false, false) as Label
		var preview := offer.find_child("%sPreview" % offer.name, false, false) as Label
		var full_influence := str(influence.get_meta("full_text", "")) if influence != null else ""
		var full_preview := str(preview.get_meta("full_text", "")) if preview != null else ""
		if full_influence == "" or not offer.tooltip_text.contains(full_influence):
			_errors.append("%s: %s tooltip must preserve the full influence list behind the compact lane." % [context, offer.name])
		for preview_line in full_preview.split("\n", false):
			if str(preview_line) != "" and not offer.tooltip_text.contains(str(preview_line)):
				_errors.append("%s: %s tooltip lost full preview line '%s'." % [context, offer.name, preview_line])
	for first_index in range(card_rects.size()):
		for second_index in range(first_index + 1, card_rects.size()):
			if card_rects[first_index].intersects(card_rects[second_index]):
				_errors.append("%s: offer cards %d and %d overlap." % [context, first_index, second_index])

	if actions.get_child_count() != 2:
		_errors.append("%s: AttributeShopActions must contain exactly reroll + skip." % context)
	for action_node in actions.get_children():
		var action := action_node as Button
		if action == null or not _encloses(inner, action.get_global_rect()):
			_errors.append("%s: action %s escapes exact inner rect." % [context, str(action_node.name)])
	if actions.get_child_count() == 2:
		var left_action := actions.get_child(0) as Button
		var right_action := actions.get_child(1) as Button
		if left_action != null and right_action != null:
			if left_action.focus_neighbor_right != right_action.get_path() or right_action.focus_neighbor_left != left_action.get_path():
				_errors.append("%s: horizontal Reroll/Skip pair must traverse with Left/Right." % context)


func _assert_visible_effect_label(offer: Button, suffix: String, required_text: String, context: String) -> void:
	var label: Label = null
	for child_node in offer.find_children("*%s" % suffix, "Label", true, false):
		label = child_node as Label
		break
	if label == null:
		_errors.append("%s: %s is missing visible %s label." % [context, str(offer.name), suffix])
		return
	if not label.visible or not label.is_visible_in_tree() or not label.get_global_rect().has_area() or label.text.strip_edges() == "":
		_errors.append("%s: %s %s label must be visible, non-empty and have area." % [context, str(offer.name), suffix])
	if required_text != "" and not label.text.contains(required_text):
		_errors.append("%s: %s %s label must contain '%s'." % [context, str(offer.name), suffix, required_text])
	if not _encloses(offer.get_global_rect(), label.get_global_rect()):
		_errors.append("%s: %s %s label escapes its card." % [context, str(offer.name), suffix])
	if offer.custom_minimum_size.y >= 230.0 and label.get_theme_font_size("font_size") < 11:
		_errors.append("%s: %s %s body font is below approved 11px minimum." % [context, str(offer.name), suffix])
	if label.get_line_count() > 0 and label.get_visible_line_count() < label.get_line_count():
		_errors.append("%s: %s %s clips wrapped lines (%d/%d visible)." % [context, str(offer.name), suffix, label.get_visible_line_count(), label.get_line_count()])


func _assert_no_manual_attribute_entry(main: Node, context: String) -> void:
	_assert_no_upgrade_fab(main, context)
	if main.find_child("AttributeShopScreen", true, false) != null:
		_errors.append("%s: destination must not auto-open Attribute Shop." % context)


func _assert_no_upgrade_fab(main: Node, context: String) -> void:
	if main.find_child("UpgradeFabButton", true, false) != null:
		_errors.append("%s: removed manual Attribute Shop UpgradeFabButton is present." % context)


func _assert_pending_level_up(main: Node, context: String, expected_count: int) -> void:
	var button := main.find_child("LevelUpPlusButton", true, false) as Button
	var badge := main.find_child("LevelUpPlusBadge", true, false) as Label
	if button == null or not button.visible or not button.is_visible_in_tree():
		_errors.append("%s: pending LevelUpPlusButton is missing/not visible." % context)
	if badge == null or badge.text != str(expected_count):
		_errors.append("%s: expected LevelUpPlusBadge '%d', got '%s'." % [context, expected_count, badge.text if badge != null else "<missing>"])
	var screen := main.find_child("RouteMapScreen", true, false) as Control
	if screen == null:
		screen = main.find_child("MenuScreen_campfire", true, false) as Control
	if button != null and screen != null:
		var inner: Rect2 = screen.get_meta("gold_shell_inner_rect", Rect2()) as Rect2
		for candidate in [button] + button.find_children("*", "Control", true, false):
			var control := candidate as Control
			if control != null and control.visible and control.is_visible_in_tree() and control.get_global_rect().has_area() and not _encloses(inner, control.get_global_rect()):
				_errors.append("%s: %s %s overlaps the gold ornament outside %s." % [context, control.name, str(control.get_global_rect()), str(inner)])


func _attribute_shop_fixture(viewport_size: Vector2i, money: int, atlas_extra: bool, fixed_offer: Array = []) -> Dictionary:
	var fixture := await _base_fixture(viewport_size, money)
	var main := fixture["main"] as Node
	var state := (main.get("meta_state") as Dictionary).duplicate(true)
	state["skill_nodes"] = ["atlas_n2"] if atlas_extra else []
	main.set("meta_state", state)
	main.set("attribute_offer", fixed_offer.duplicate())
	main.set("attribute_rerolls_left", 2)
	main.ui._show_attribute_shop(Callable(self, "_on_attribute_completed"))
	await _settle()
	return fixture


func _base_fixture(viewport_size: Vector2i, money: int) -> Dictionary:
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
	main.set("route_stage", 0)
	var player := PLAYER_SCENE.instantiate()
	viewport.add_child(player)
	await process_frame
	player.configure_character("berserk", "sword")
	player.set("money", money)
	main.call("_store_player_snapshot", player)
	player.queue_free()
	await _settle()
	return {"viewport": viewport, "main": main}


func _on_attribute_completed() -> void:
	_completion_count += 1


func _unique_strings(values: Array) -> Dictionary:
	var unique := {}
	for value in values:
		unique[str(value)] = true
	return unique


func _rect_near(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= EPSILON and actual.size.distance_to(expected.size) <= EPSILON


func _encloses(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(EPSILON).encloses(inner)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _teardown(viewport: SubViewport, main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
	await process_frame
	await process_frame
