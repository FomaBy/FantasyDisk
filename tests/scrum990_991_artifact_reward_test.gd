extends SceneTree

# Independent focused acceptance oracle for the combined SCRUM-990/991 work.
# Production is intentionally not mocked: both real reward screens are opened,
# laid out in SubViewports and exercised through their actual Button signals.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ARTIFACT_PRESENTER := preload("res://scripts/artifact_reward_presenter.gd")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
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
const SCREEN_CONTRACTS := {
	"elite": {
		"screen": "EliteArtifactRewardScreen",
		"frame": "EliteArtifactRewardFrame",
		"content": "EliteArtifactRewardContentRoot",
		"row": "EliteArtifactRewardRow",
		"button_prefix": "EliteArtifactRewardButton",
		"redundant_panel": "EliteArtifactRewardPanel",
	},
	"boss": {
		"screen": "BossArtifactRewardScreen",
		"frame": "BossArtifactRewardFrame",
		"content": "BossArtifactRewardContentRoot",
		"row": "BossArtifactRewardRow",
		"button_prefix": "BossArtifactRewardButton",
		"redundant_panel": "BossArtifactRewardPanel",
	},
}

var _errors := PackedStringArray()


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_resolution(viewport_size, "elite")
		await _validate_resolution(viewport_size, "boss")
	await _validate_live_resize("elite")
	await _validate_live_resize("boss")
	await _validate_resolved_copy_and_badges()
	await _validate_choose_flow("elite")
	await _validate_choose_flow("boss")

	if not _errors.is_empty():
		for error in _errors:
			push_error("[SCRUM-990/991 Artifact Reward] %s" % error)
		quit(1)
		return
	print("SCRUM-990/991 artifact reward focused test passed: shared hollow shell, responsive 3-card rows, resolved effects, deterministic badges, focus and choose flows.")
	quit(0)


func _validate_resolution(viewport_size: Vector2i, kind: String) -> void:
	var fixture := await _open_fixture(viewport_size, kind)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	_assert_screen(main, viewport_size, kind, "%s %dx%d" % [kind, viewport_size.x, viewport_size.y])
	_assert_mandatory_choice_state(main, viewport, kind, "%s %dx%d" % [kind, viewport_size.x, viewport_size.y])
	await _cleanup_fixture(viewport, main)


func _validate_live_resize(kind: String) -> void:
	var fixture := await _open_fixture(Vector2i(2560, 1440), kind)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	_assert_screen(main, Vector2i(2560, 1440), kind, "%s live initial 2560x1440" % kind)
	viewport.size = Vector2i(1280, 720)
	await _settle()
	_assert_screen(main, Vector2i(1280, 720), kind, "%s live 2560x1440 -> 1280x720" % kind)
	viewport.size = Vector2i(1920, 1080)
	await _settle()
	_assert_screen(main, Vector2i(1920, 1080), kind, "%s live 1280x720 -> 1920x1080" % kind)
	await _cleanup_fixture(viewport, main)


func _validate_choose_flow(kind: String) -> void:
	var callback_count := [0]
	var fixture := await _base_fixture(Vector2i(1280, 720))
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var contract: Dictionary = SCREEN_CONTRACTS[kind]
	main.set("run_player_snapshot", {})
	_show_reward(main, kind, func() -> void:
		callback_count[0] += 1
	)
	await _settle()
	var screen := main.find_child(str(contract["screen"]), true, false) as Control
	var row := screen.find_child(str(contract["row"]), true, false) as Control if screen != null else null
	if row == null or row.get_child_count() != 3:
		_errors.append("%s choose flow: expected three selectable cards." % kind)
		await _cleanup_fixture(viewport, main)
		return
	var selected := row.get_child(1) as Button
	if selected == null or selected.disabled:
		_errors.append("%s choose flow: second card is missing or disabled." % kind)
	else:
		var selected_artifact_id := str(selected.get_meta("artifact_reward_id", ""))
		selected.pressed.emit()
		await _settle()
		if callback_count[0] != 1:
			_errors.append("%s choose flow: callback must run exactly once, got %d." % [kind, callback_count[0]])
		if main.find_child(str(contract["screen"]), true, false) != null:
			_errors.append("%s choose flow: reward screen was not cleared before returning." % kind)
		var snapshot := main.get("run_player_snapshot") as Dictionary
		var artifacts := snapshot.get("artifacts", []) as Array
		if artifacts.size() != 1:
			_errors.append("%s choose flow: exactly one artifact must be applied, got %d." % [kind, artifacts.size()])
		elif str((artifacts[0] as Dictionary).get("id", "")) != selected_artifact_id:
			_errors.append("%s choose flow: selected artifact id '%s' was not the applied id '%s'." % [kind, selected_artifact_id, str((artifacts[0] as Dictionary).get("id", ""))])
		# A stale/duplicate signal after the screen has returned must not fire.
		if callback_count[0] != 1:
			_errors.append("%s choose flow: continuation was re-entered." % kind)
	await _cleanup_fixture(viewport, main)


func _assert_mandatory_choice_state(main: Node, viewport: SubViewport, kind: String, context: String) -> void:
	var contract: Dictionary = SCREEN_CONTRACTS[kind]
	var focus_owner := viewport.gui_get_focus_owner() as Control
	var expected_name := "%s0" % str(contract["button_prefix"])
	if focus_owner == null or str(focus_owner.name) != expected_name:
		_errors.append("%s: initial focus must be %s, got %s." % [context, expected_name, str(focus_owner.name) if focus_owner != null else "<none>"])
	var escape_action: Callable = main.get("ui_escape_action")
	if escape_action.is_valid():
		_errors.append("%s: mandatory artifact choice must not expose an Escape/cancel action." % context)


func _validate_resolved_copy_and_badges() -> void:
	var fixture := await _base_fixture(Vector2i(1920, 1080))
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var host := Control.new()
	host.custom_minimum_size = Vector2(1520, 742)
	host.size = host.custom_minimum_size
	main.add_child(host)

	var class_reward := {
		"id": "scrum991_class_damage_oracle",
		"kind": "artifact",
		"title": "Классовая линза",
		"description": "Общий бонус урона.",
		"tier": 3,
		"mods": {"damage_multiplier": 1.18},
	}
	main.set("selected_character_id", "berserk")
	var berserk_card: Button = main.ui._make_elite_artifact_card(class_reward)
	host.add_child(berserk_card)
	await _settle()
	var berserk_resolved := _resolved_text(berserk_card, "synthetic berserk")
	berserk_card.queue_free()
	await _settle()

	main.set("selected_character_id", "dark_mage")
	var mage_card: Button = main.ui._make_elite_artifact_card(class_reward)
	host.add_child(mage_card)
	await _settle()
	var mage_resolved := _resolved_text(mage_card, "synthetic dark_mage")
	if berserk_resolved == mage_resolved:
		_errors.append("resolved effect must differ for the same class-dependent reward on berserk vs dark_mage.")
	for resolved in [berserk_resolved, mage_resolved]:
		if resolved == "" or resolved == str(class_reward["description"]):
			_errors.append("class-dependent reward must expose concrete resolved copy, not the generic source description.")
		if resolved.contains("Интерпретация:"):
			_errors.append("resolved copy must not preserve the removed 'Интерпретация:' filler prefix.")
	mage_card.queue_free()
	await _settle()

	main.set("selected_character_id", "berserk")
	var damage_reward := _synthetic_reward("damage", {"damage_multiplier": 1.20})
	var survival_reward := _synthetic_reward("survival", {"defense_flat": 0.12, "max_health_flat": 15.0})
	var hybrid_reward := _synthetic_reward("hybrid", {"damage_multiplier": 1.15, "defense_flat": 0.10})
	var unsafe_reward := _synthetic_reward("unsafe", {"scripted_proc_unknown": 1.0})
	await _assert_badges(host, main, damage_reward, true, false, "damage")
	await _assert_badges(host, main, survival_reward, false, true, "survival")
	await _assert_badges(host, main, hybrid_reward, true, true, "hybrid")
	await _assert_badges(host, main, unsafe_reward, false, false, "unsafe/unknown")
	# Same input must produce exactly the same badge copy on a second render.
	var first := await _render_badge_text(host, main, hybrid_reward)
	var second := await _render_badge_text(host, main, hybrid_reward)
	if first == "" or first != second:
		_errors.append("hybrid badge classification must be deterministic; got '%s' then '%s'." % [first, second])

	# Offer-set badges are comparative, not per-card guesses: an exact positive
	# tie is ambiguous and therefore leaves both cards unbadged.
	var tied_damage := damage_reward.duplicate(true)
	tied_damage["id"] = "scrum991_damage_tie_oracle"
	var weapon_config := PROGRESSION_DATA.weapon("berserk", "sword")
	weapon_config["character_id"] = "berserk"
	var tie_presentations := ARTIFACT_PRESENTER.build_offer_presentations(
		[damage_reward, tied_damage, unsafe_reward],
		"berserk",
		PROGRESSION_DATA.base_stats("berserk"),
		{},
		weapon_config
	)
	for index in [0, 1]:
		if str((tie_presentations[index] as Dictionary).get("badge_text", "")).contains("Лучший урон"):
			_errors.append("equal positive damage offers must omit the ambiguous Best Damage badge (index %d)." % index)

	# Mixed rewards must retain source mechanics that are not represented by the
	# finite derived-parameter forecast, including penalties and class mechanics.
	_assert_source_semantics_preserved("burning_shard", "berserk", "sword", "-20% лечения")
	_assert_source_semantics_preserved("spore_capacitor", "biologist", "biologist_spore_lens", "замедляют на 25%")
	_assert_source_semantics_preserved("venom_spool", "assassin", "venom_wire", "2 тика дольше")
	_assert_source_semantics_preserved("guardian_bulwark", "berserk", "sword", "Перезаряд 18с.")
	_assert_source_semantics_preserved("counterwave_sigil", "berserk", "sword", "Перезаряд 3с.")
	await _assert_compact_long_copy_fit(host, main, "counterwave_sigil", "Перезаряд 3с.")

	var leech_heart := PROGRESSION_DATA.artifact_definition("leech_heart")
	var doctor_config := PROGRESSION_DATA.weapon("doctor", "plague_syringe")
	doctor_config["character_id"] = "doctor"
	var doctor_blocked := ARTIFACT_PRESENTER.build_single_presentation(
		leech_heart,
		"doctor",
		PROGRESSION_DATA.base_stats("doctor"),
		{},
		doctor_config
	) as Dictionary
	var doctor_copy := str(doctor_blocked.get("resolved_effect", ""))
	if not doctor_copy.contains("заблокировано клятвой Доктора") or doctor_copy.contains("возвращает 2%"):
		_errors.append("Doctor-blocked generic sustain must state that no bonus applies without promising the rejected heal; got '%s'." % doctor_copy)
	if str(doctor_blocked.get("badge_text", "")) != "":
		_errors.append("Doctor-blocked generic sustain must not receive a recommendation badge.")

	await _cleanup_fixture(viewport, main)


func _assert_source_semantics_preserved(artifact_id: String, character_id: String, weapon_id: String, expected_fragment: String) -> void:
	var reward := PROGRESSION_DATA.artifact_definition(artifact_id)
	var weapon_config := PROGRESSION_DATA.weapon(character_id, weapon_id)
	weapon_config["character_id"] = character_id
	var presentation := ARTIFACT_PRESENTER.build_single_presentation(
		reward,
		character_id,
		PROGRESSION_DATA.base_stats(character_id),
		{},
		weapon_config
	) as Dictionary
	var resolved := str(presentation.get("resolved_effect", ""))
	if not resolved.contains(expected_fragment):
		_errors.append("%s must preserve source mechanic/penalty '%s'; got '%s'." % [artifact_id, expected_fragment, resolved])


func _assert_compact_long_copy_fit(host: Control, main: Node, artifact_id: String, expected_fragment: String) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	var card: Button = main.ui._make_elite_artifact_card(PROGRESSION_DATA.artifact_definition(artifact_id))
	card.name = "CompactLongCopyOracle"
	host.add_child(card)
	main.ui._resize_elite_artifact_card(card, Vector2(286.0, 344.0))
	await _settle()
	var resolved := card.find_child("EliteArtifactRewardResolvedEffect", true, false) as Label
	if resolved == null or not resolved.text.contains(expected_fragment):
		_errors.append("compact %s card must retain '%s'." % [artifact_id, expected_fragment])
	_assert_card_content(card, host.get_global_rect(), "compact 1280x720 long-copy oracle")
	card.queue_free()
	await _settle()


func _assert_badges(host: Control, main: Node, reward: Dictionary, want_damage: bool, want_survival: bool, context: String) -> void:
	var text := await _render_badge_text(host, main, reward)
	var has_damage := text.contains("Лучший урон")
	var has_survival := text.contains("Лучшая выживаемость")
	if has_damage != want_damage or has_survival != want_survival:
		_errors.append("%s badges: expected damage=%s survival=%s, got '%s'." % [context, str(want_damage), str(want_survival), text])
	if not want_damage and not want_survival and text.strip_edges() != "":
		_errors.append("%s badges: unsafe/unclassified reward must omit the badge instead of guessing ('%s')." % [context, text])


func _render_badge_text(host: Control, main: Node, reward: Dictionary) -> String:
	var card: Button = main.ui._make_elite_artifact_card(reward)
	host.add_child(card)
	await _settle()
	var parts := PackedStringArray()
	for candidate in card.find_children("*Badge*", "Label", true, false):
		var label := candidate as Label
		if label != null and label.visible and label.text.strip_edges() != "":
			parts.append(label.text.strip_edges())
	var result := " · ".join(parts)
	card.queue_free()
	await _settle()
	return result


func _resolved_text(card: Button, context: String) -> String:
	if card.find_child("EliteArtifactRewardInterpretation", true, false) != null:
		_errors.append("%s: obsolete EliteArtifactRewardInterpretation must be absent." % context)
	var resolved := card.find_child("EliteArtifactRewardResolvedEffect", true, false) as Label
	if resolved == null:
		_errors.append("%s: missing concrete EliteArtifactRewardResolvedEffect." % context)
		return ""
	if not resolved.visible or not resolved.is_visible_in_tree() or not resolved.get_global_rect().has_area():
		_errors.append("%s: resolved effect must be visible and allocated." % context)
	return resolved.text.strip_edges()


func _synthetic_reward(id_suffix: String, mods: Dictionary) -> Dictionary:
	return {
		"id": "scrum991_%s_oracle" % id_suffix,
		"kind": "artifact",
		"title": "Oracle %s" % id_suffix,
		"description": "Синтетический эффект для focused acceptance.",
		"tier": 3,
		"mods": mods,
	}


func _assert_screen(main: Node, viewport_size: Vector2i, kind: String, context: String) -> void:
	var contract: Dictionary = SCREEN_CONTRACTS[kind]
	var screen := main.find_child(str(contract["screen"]), true, false) as Control
	if screen == null:
		_errors.append("%s: reward screen is missing." % context)
		return
	var expected_inner: Rect2 = EXPECTED_INNER[viewport_size]
	var frame := screen.find_child(str(contract["frame"]), true, false) as Panel
	var content := screen.find_child(str(contract["content"]), true, false) as Control
	var row := screen.find_child(str(contract["row"]), true, false) as Control
	_assert_single_hollow_frame(screen, frame, expected_inner, context)
	if not _rect_near(screen.get_meta("gold_shell_inner_rect", Rect2()) as Rect2, expected_inner):
		_errors.append("%s: screen gold_shell_inner_rect drifted from %s." % [context, str(expected_inner)])
	if content == null:
		_errors.append("%s: missing authored %s." % [context, str(contract["content"])])
	else:
		_assert_rect(content.get_global_rect(), expected_inner, "%s content root" % context)
	if row == null:
		_errors.append("%s: missing reward row." % context)
		return
	if not _encloses(expected_inner, row.get_global_rect()):
		_errors.append("%s: reward row %s escapes exact inner rect %s." % [context, str(row.get_global_rect()), str(expected_inner)])
	if row.get_child_count() != 3:
		_errors.append("%s: expected exactly 3 cards, got %d." % [context, row.get_child_count()])

	var redundant := screen.find_child(str(contract["redundant_panel"]), true, false) as Control
	if redundant != null and redundant.visible and redundant.is_visible_in_tree():
		_errors.append("%s: redundant visible %s creates a second panel/border." % [context, str(contract["redundant_panel"])])
	if screen.find_child("EliteArtifactRewardInterpretation", true, false) != null:
		_errors.append("%s: obsolete EliteArtifactRewardInterpretation is still rendered." % context)

	var cards: Array[Button] = []
	for index in range(row.get_child_count()):
		var card := row.get_child(index) as Button
		if card == null:
			_errors.append("%s: row child %d is not a Button." % [context, index])
			continue
		cards.append(card)
		if card.name != "%s%d" % [str(contract["button_prefix"]), index]:
			_errors.append("%s: unstable card name at index %d: %s." % [context, index, str(card.name)])
		_assert_card_content(card, expected_inner, context)
	_assert_single_row(cards, expected_inner, context)
	_assert_horizontal_focus(cards, context)


func _assert_single_hollow_frame(screen: Control, frame: Panel, expected_inner: Rect2, context: String) -> void:
	if frame == null:
		_errors.append("%s: missing final gold-shell frame." % context)
		return
	if frame.get_parent() != screen or screen.get_child(screen.get_child_count() - 1) != frame:
		_errors.append("%s: decorative frame must be the final direct child above all content." % context)
	if frame.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_errors.append("%s: decorative frame must ignore mouse input." % context)
	if not _rect_near(frame.get_global_rect(), Rect2(Vector2.ZERO, screen.size)):
		_errors.append("%s: decorative frame must cover the full screen exactly." % context)
	var style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null or style.texture == null:
		_errors.append("%s: frame must use frame_border StyleBoxTexture." % context)
	else:
		if style.draw_center:
			_errors.append("%s: shared frame_border shell must stay hollow (draw_center=false)." % context)
		if not style.texture.resource_path.ends_with(FRAME_PATH_SUFFIX):
			_errors.append("%s: unexpected frame texture %s." % [context, style.texture.resource_path])
	if not _rect_near(frame.get_meta("gold_shell_inner_rect", Rect2()) as Rect2, expected_inner):
		_errors.append("%s: frame gold_shell_inner_rect drifted from %s." % [context, str(expected_inner)])

	var frame_border_count := 0
	for candidate in screen.find_children("*", "Panel", true, false):
		var panel := candidate as Panel
		var candidate_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
		if candidate_style != null and candidate_style.texture != null \
				and candidate_style.texture.resource_path.ends_with(FRAME_PATH_SUFFIX):
			frame_border_count += 1
	if frame_border_count != 1:
		_errors.append("%s: expected one shared hollow frame_border shell, got %d." % [context, frame_border_count])


func _assert_card_content(card: Button, screen_inner: Rect2, context: String) -> void:
	var card_rect := card.get_global_rect()
	if not _encloses(screen_inner, card_rect):
		_errors.append("%s: %s escapes the screen inner rect." % [context, str(card.name)])
	var content := card.find_child("EliteArtifactRewardContent", true, false) as Control
	if content == null:
		_errors.append("%s: %s lacks EliteArtifactRewardContent." % [context, str(card.name)])
		return
	var normal := card.get_theme_stylebox("normal")
	if normal == null:
		_errors.append("%s: %s lacks a normal card style/content margins." % [context, str(card.name)])
		return
	var content_rect := Rect2(
		card_rect.position + Vector2(normal.content_margin_left, normal.content_margin_top),
		Vector2(
			card_rect.size.x - normal.content_margin_left - normal.content_margin_right,
			card_rect.size.y - normal.content_margin_top - normal.content_margin_bottom
		)
	)
	if not content_rect.has_area() or not _encloses(card_rect, content_rect):
		_errors.append("%s: %s has invalid card content margins %s." % [context, str(card.name), str(content_rect)])
		return
	if not _rect_near(content.get_global_rect(), content_rect):
		_errors.append("%s: %s content root %s does not match style margins %s." % [context, str(card.name), str(content.get_global_rect()), str(content_rect)])

	var icon: Control = null
	for candidate in content.find_children("*", "TextureRect", true, false):
		icon = candidate as Control
		break
	var title: Label = null
	var tier := content.find_child("EliteArtifactRewardTier", true, false) as Label
	var resolved := content.find_child("EliteArtifactRewardResolvedEffect", true, false) as Label
	var action: Label = null
	var badge_labels: Array[Label] = []
	for candidate in content.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label == null:
			continue
		if label.name.contains("Badge"):
			badge_labels.append(label)
		elif label.text.strip_edges() in ["Выбрать", "Получить"]:
			action = label
		elif label != tier and label != resolved and title == null:
			title = label
	var required: Array[Control] = []
	for node in [icon, title, tier, resolved, action]:
		if node != null:
			required.append(node)
	required.append_array(badge_labels)
	if icon == null or title == null or tier == null or resolved == null or action == null:
		_errors.append("%s: %s must expose icon/title/tier/resolved effect/action inside card margins." % [context, str(card.name)])
	if badge_labels.is_empty():
		_errors.append("%s: %s must allocate a deterministic badge zone/label for real rewards." % [context, str(card.name)])
	for control in required:
		if not control.visible or not control.is_visible_in_tree() or not control.get_global_rect().has_area():
			_errors.append("%s: %s/%s is not visibly allocated." % [context, str(card.name), str(control.name)])
		elif not _encloses(content_rect, control.get_global_rect()):
			_errors.append("%s: %s/%s escapes card content margins %s." % [context, str(card.name), str(control.name), str(content_rect)])
	if resolved != null and resolved.get_line_count() > 0 and resolved.get_visible_line_count() < resolved.get_line_count():
		_errors.append("%s: %s resolved effect clips wrapped lines (%d/%d)." % [context, str(card.name), resolved.get_visible_line_count(), resolved.get_line_count()])


func _assert_single_row(cards: Array[Button], inner: Rect2, context: String) -> void:
	if cards.size() != 3:
		return
	var baseline_y := cards[0].get_global_rect().position.y
	var last_x := -INF
	for index in range(cards.size()):
		var rect := cards[index].get_global_rect()
		if absf(rect.position.y - baseline_y) > EPSILON:
			_errors.append("%s: card %d leaves the single horizontal row." % [context, index])
		if rect.position.x <= last_x:
			_errors.append("%s: cards are not ordered left-to-right." % context)
		last_x = rect.position.x
		if not _encloses(inner, rect):
			_errors.append("%s: card %d escapes the frame safe zone." % [context, index])
	for first in range(cards.size()):
		for second in range(first + 1, cards.size()):
			if cards[first].get_global_rect().intersects(cards[second].get_global_rect()):
				_errors.append("%s: cards %d and %d overlap." % [context, first, second])


func _assert_horizontal_focus(cards: Array[Button], context: String) -> void:
	if cards.size() != 3:
		return
	for index in range(cards.size()):
		var left := cards[(index - 1 + cards.size()) % cards.size()]
		var right := cards[(index + 1) % cards.size()]
		if cards[index].focus_mode != Control.FOCUS_ALL:
			_errors.append("%s: %s is not gamepad-focusable." % [context, str(cards[index].name)])
		if cards[index].focus_neighbor_left != left.get_path() or cards[index].focus_neighbor_right != right.get_path():
			_errors.append("%s: %s must use circular Left/Right gamepad focus." % [context, str(cards[index].name)])


func _open_fixture(viewport_size: Vector2i, kind: String) -> Dictionary:
	var fixture := await _base_fixture(viewport_size)
	var main := fixture["main"] as Node
	_show_reward(main, kind, Callable())
	await _settle()
	return fixture


func _base_fixture(viewport_size: Vector2i) -> Dictionary:
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
	main.set("route_stage", 6)
	main.set("run_player_snapshot", {})
	return {"viewport": viewport, "main": main}


func _show_reward(main: Node, kind: String, callback: Callable) -> void:
	if kind == "boss":
		main.ui._show_boss_artifact_reward(callback)
	else:
		main.ui._show_elite_artifact_reward(callback)


func _rect_near(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= EPSILON and actual.size.distance_to(expected.size) <= EPSILON


func _assert_rect(actual: Rect2, expected: Rect2, context: String) -> void:
	if not _rect_near(actual, expected):
		_errors.append("%s: expected %s, got %s." % [context, str(expected), str(actual)])


func _encloses(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(EPSILON).encloses(inner)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _cleanup_fixture(viewport: SubViewport, main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
	await process_frame
	await process_frame
