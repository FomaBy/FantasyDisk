extends SceneTree

# FAN-1927: полная runtime-матрица визуальной приёмки атрибутного контракта —
# 4 surface-группы × 3 viewport × 4 состояния = 48 живых состояний с PNG-
# evidence (build/qa/fan1927/) и проверками содержимого/геометрии:
#
#   surfaces:  level_up, attribute_shop, pause_codex (живые значения досье;
#              canonical-паритет Кодекса держат codex_data_smoke_test и
#              codex_scrum954_layout_test), hero_select
#   viewports: 1280×720, 1920×1080, 2560×1440
#   states:    normal / ineligible / capped / long_copy
#
# Контракты состояний — спека fan1883_attribute_clarity: ineligible-карта
# отсутствует до раскладки (ряд перецентрован), capped-ось не предлагается и
# читаема как «максимум», длинная русская копия доступна через approved
# scroll-зоны (LU.DetailDrawer / AS.DetailDrawer / dossier / tooltip), без
# ellipsis на presentation-данных; before→after/delta не удаляются compact-режимом.
#
# Запуск: Godot --headless --path . --script res://tests/attribute_ui_matrix_fan1927_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")
const AttributeContract := preload("res://scripts/attribute_contract.gd")
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")
const QACaptureTeardown := preload("res://tools/qa_capture_teardown.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const STATES := ["normal", "ineligible", "capped", "long_copy"]
const EVIDENCE_DIR := "res://build/qa/fan1927"

var _errors := PackedStringArray()
var _validated := 0
var _captured := 0
var _capture_hashes := {}
var _capture_names := {}
var _semantic_hashes := {}
var _long_copy_sentinels := {}
var _capture_teardown := QACaptureTeardown.new()


func _fail(message: String) -> void:
	_errors.append(message)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIR))
	if DisplayServer.get_name() != "headless":
		_clean_capture_evidence()
	for viewport_size in VIEWPORTS:
		for state in STATES:
			await _run_level_up(viewport_size, str(state))
			await _run_attribute_shop(viewport_size, str(state))
			await _run_pause_codex(viewport_size, str(state))
			await _run_hero_select(viewport_size, str(state))
	await _capture_teardown.release_windowed_audio(self)
	if _validated != 48:
		_fail("Validated %d runtime states instead of 48." % _validated)
	if _long_copy_sentinels.size() != 12:
		_fail("Injected %d unique long-copy sentinels instead of 12." % _long_copy_sentinels.size())
	if DisplayServer.get_name() != "headless":
		_validate_capture_inventory()
		_write_capture_manifest()
	if not _errors.is_empty():
		for error in _errors:
			push_error("[fan1927-matrix] %s" % error)
		push_error("FAN-1927 48-state UI matrix FAILED (%d/48 states, %d captures)." % [_validated, _captured])
		quit(1)
		return
	print("FAN-1927 48-state UI matrix passed: %d/48 runtime states validated, %d PNG captures in %s (4 surfaces × 3 viewports × 4 states)." % [_validated, _captured, EVIDENCE_DIR])
	quit(0)


func _clean_capture_evidence() -> void:
	var directory := DirAccess.open(EVIDENCE_DIR)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".png") or file_name == "manifest.json":
			directory.remove(file_name)


func _expected_capture_names() -> Dictionary:
	var expected := {}
	for viewport_size in VIEWPORTS:
		for state in STATES:
			for surface in ["level_up", "attribute_shop", "pause_codex", "hero_select"]:
				expected["%s_%dx%d_%s.png" % [surface, viewport_size.x, viewport_size.y, state]] = true
	return expected


func _validate_capture_inventory() -> void:
	var expected := _expected_capture_names()
	if _captured != 48 or _capture_names.size() != 48:
		_fail("Native matrix produced %d captures/%d unique names instead of 48." % [_captured, _capture_names.size()])
	for file_name in expected:
		if not _capture_names.has(file_name):
			_fail("Capture manifest is missing '%s'." % file_name)
	for file_name in _capture_names:
		if not expected.has(file_name):
			_fail("Capture manifest contains unexpected PNG '%s'." % file_name)
	var directory := DirAccess.open(EVIDENCE_DIR)
	if directory == null:
		_fail("Capture evidence directory cannot be opened.")
		return
	var disk_names := {}
	for file_name in directory.get_files():
		if file_name.ends_with(".png"):
			disk_names[file_name] = true
	if disk_names.size() != 48:
		_fail("Capture evidence directory contains %d PNGs instead of 48." % disk_names.size())
	for file_name in disk_names:
		if not expected.has(file_name):
			_fail("Capture evidence directory contains stale PNG '%s'." % file_name)


func _write_capture_manifest() -> void:
	var records: Array = []
	var capture_keys: Array = _capture_hashes.keys()
	capture_keys.sort()
	for key in capture_keys:
		records.append({"state": key, "sha256": _capture_hashes[key]})
	var semantic_records: Array = []
	var semantic_keys: Array = _semantic_hashes.keys()
	semantic_keys.sort()
	for key in semantic_keys:
		semantic_records.append({"state": key, "sha256": _semantic_hashes[key]})
	var sentinel_values: Array = _long_copy_sentinels.keys()
	sentinel_values.sort()
	var manifest_path := ProjectSettings.globalize_path("%s/manifest.json" % EVIDENCE_DIR)
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest == null:
		_fail("Could not write capture manifest '%s'." % manifest_path)
		return
	manifest.store_string(JSON.stringify({
		"captures": records,
		"semantic_states": semantic_records,
		"long_copy_sentinels": sentinel_values,
	}, "\t"))


func _long_copy_fixture(surface: String, viewport_size: Vector2i) -> Dictionary:
	var sentinel := "FAN1945_%s_%dx%d_LONG_COPY_END" % [surface.to_upper(), viewport_size.x, viewport_size.y]
	if _long_copy_sentinels.has(sentinel):
		_fail("%s %s: duplicate long-copy sentinel." % [surface, viewport_size])
	_long_copy_sentinels[sentinel] = true
	var paragraph := "Длинное русское описание сохраняет все числа, условия и объяснения без сокращения. "
	return {
		"sentinel": sentinel,
		"text": "%s\n%s" % [paragraph.repeat(48), sentinel],
	}


func _new_fixture(viewport_size: Vector2i) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	for _index in range(3):
		await process_frame
	return {"viewport": viewport, "main": main}


func _teardown(fixture: Dictionary) -> void:
	var viewport := fixture.get("viewport") as SubViewport
	for error in await _capture_teardown.release_viewport(self, viewport):
		_fail(str(error))


func _settle(frames := 4) -> void:
	for _index in range(frames):
		await process_frame


func _assert_scroll_reaches_sentinel(scroll: ScrollContainer, label: Label, sentinel: String, context: String) -> void:
	if scroll == null or label == null:
		_fail("%s: long-copy scroll/label is missing." % context)
		return
	await _settle(3)
	var scrollbar := scroll.get_v_scroll_bar()
	var max_scroll := maxf(0.0, scrollbar.max_value - scrollbar.page)
	if max_scroll <= 1.0:
		_fail("%s: long copy has no positive scroll range (max %.1f, page %.1f)." % [context, scrollbar.max_value, scrollbar.page])
		return
	scroll.scroll_vertical = int(ceilf(max_scroll))
	await _settle(2)
	var settled_max := maxf(0.0, scrollbar.max_value - scrollbar.page)
	if absf(float(scroll.scroll_vertical) - settled_max) > 2.0:
		_fail("%s: scroll stopped at %d instead of the end %.1f." % [context, scroll.scroll_vertical, settled_max])
	if not label.text.ends_with(sentinel):
		_fail("%s: final sentinel is absent from the rendered disclosure." % context)
		return
	var scroll_rect := scroll.get_global_rect()
	var tail_y := label.get_global_rect().end.y
	if tail_y < scroll_rect.position.y - 2.0 or tail_y > scroll_rect.end.y + 2.0:
		_fail("%s: final sentinel tail at %.1f is outside scroll viewport %s after scrolling." % [context, tail_y, scroll_rect])


func _image_has_variance(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	var step_x := maxi(1, image.get_width() / 16)
	var step_y := maxi(1, image.get_height() / 16)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			if not image.get_pixel(x, y).is_equal_approx(first):
				return true
	return false


func _read_capture_image(viewport: SubViewport) -> Image:
	var image: Image = null
	for _attempt in range(4):
		RenderingServer.force_draw(false)
		await _settle(2)
		image = viewport.get_texture().get_image()
		if image != null and not image.is_empty() and _image_has_variance(image):
			return image
	return image


func _capture(fixture: Dictionary, surface: String, viewport_size: Vector2i, state: String, semantic_text: String, sentinel := "") -> void:
	_validated += 1
	var pair_key := "%s_%dx%d" % [surface, viewport_size.x, viewport_size.y]
	if state == "normal" or state == "long_copy":
		var semantic_key := "%s_%s" % [pair_key, state]
		_semantic_hashes[semantic_key] = semantic_text.sha256_text()
		if state == "long_copy":
			if sentinel == "" or not semantic_text.contains(sentinel):
				_fail("%s: long-copy semantic state lacks its unique sentinel." % pair_key)
			var normal_semantic_key := "%s_normal" % pair_key
			if not _semantic_hashes.has(normal_semantic_key):
				_fail("%s: normal semantic state was not recorded before long-copy." % pair_key)
			elif _semantic_hashes[normal_semantic_key] == _semantic_hashes[semantic_key]:
				_fail("%s: normal/long-copy semantic hashes are identical." % pair_key)
	# Канон repo (hero_select_scrum1064): headless-гейт проверяет контент/
	# геометрию всех состояний; PNG-evidence рендерится при живом DisplayServer
	# (Metal): Godot --path . --script res://tests/attribute_ui_matrix_fan1927_test.gd
	if DisplayServer.get_name() == "headless":
		return
	var viewport := fixture.get("viewport") as SubViewport
	if viewport == null:
		return
	# Даём intro-твинам поверхности завершиться перед снимком.
	await _settle(40)
	var image := await _read_capture_image(viewport)
	if image == null or image.is_empty():
		_fail("%s %s %s: Metal capture returned no image." % [surface, viewport_size, state])
		return
	if image.get_size() != viewport_size:
		_fail("%s %s %s: capture size %s does not match viewport." % [surface, viewport_size, state, image.get_size()])
	if not _image_has_variance(image):
		_fail("%s %s %s: capture is a uniform frame, not reviewable UI evidence." % [surface, viewport_size, state])
	var file_name := "%s_%dx%d_%s.png" % [surface, viewport_size.x, viewport_size.y, state]
	var absolute_path := ProjectSettings.globalize_path("%s/%s" % [EVIDENCE_DIR, file_name])
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("%s: save_png failed with %s." % [file_name, error_string(save_error)])
		return
	if _capture_names.has(file_name):
		_fail("Duplicate capture name '%s'." % file_name)
	_capture_names[file_name] = true
	var capture_key := "%s_%s" % [pair_key, state]
	_capture_hashes[capture_key] = FileAccess.get_sha256(absolute_path)
	if state == "long_copy":
		var normal_capture_key := "%s_normal" % pair_key
		if not _capture_hashes.has(normal_capture_key):
			_fail("%s: normal capture hash was not recorded before long-copy." % pair_key)
		elif _capture_hashes[normal_capture_key] == _capture_hashes[capture_key]:
			_fail("%s: normal/long-copy PNG hashes are identical." % pair_key)
	_captured += 1


func _reward_for_attr(attr_id: String) -> Dictionary:
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		if str(reward.get("attr", "")) == attr_id:
			return reward.duplicate(true)
	return {}


func _offer_attrs(offer: Array) -> Array:
	var attrs: Array = []
	for reward in offer:
		attrs.append(str((reward as Dictionary).get("attr", "")))
	return attrs


func _contextual_level_up_offer(character_id: String, weapon_id: String, fixture_text := "") -> Array:
	var stats: Dictionary = ProgressionData.base_stats(character_id)
	var weapon: Dictionary = ProgressionData.weapon(character_id, weapon_id)
	var pool: Array = AttributeContract.eligible_level_up_rewards(character_id, stats, {}, weapon)
	pool.sort_custom(func(a, b):
		var a_description := str((a as Dictionary).get("description", ""))
		var b_description := str((b as Dictionary).get("description", ""))
		if a_description.length() == b_description.length():
			return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", ""))
		return a_description.length() > b_description.length()
	)
	if pool.size() < 3:
		_fail("%s/%s: contextual eligible pool has %d rewards, expected at least 3." % [character_id, weapon_id, pool.size()])
		return []
	var offer: Array = []
	for index in range(3):
		var reward := (pool[index] as Dictionary).duplicate(true)
		var presentation: Dictionary = AttributeContract.attribute_presentation(reward, character_id, stats, {}, weapon)
		if str(presentation.get("availability", "")) != "eligible":
			_fail("%s/%s: fixture reward '%s' is not eligible." % [character_id, weapon_id, reward.get("id", "")])
		if is_zero_approx(float(presentation.get("delta_effective", 0.0))) \
				or is_equal_approx(float(presentation.get("before", 0.0)), float(presentation.get("after", 0.0))):
			_fail("%s/%s: fixture reward '%s' is a no-op." % [character_id, weapon_id, reward.get("id", "")])
		if index == 0 and fixture_text != "":
			reward["description"] = "%s\n%s" % [str(reward.get("description", "")).strip_edges(), fixture_text]
		offer.append(reward)
	return offer


func _no_trim(label: Label, context: String) -> void:
	if label == null:
		_fail("%s: label missing." % context)
		return
	if label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS:
		_fail("%s: presentation label uses forbidden ellipsis trimming." % context)


# ---------------------------------------------------------------- Level Up ---

func _run_level_up(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "level_up %s %s" % [viewport_size, state]
	var character_id := "berserk"
	var weapon_id := "sword"
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("level_up", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	match state:
		"ineligible":
			character_id = "dark_mage"
			weapon_id = "cursed_skull"
		"capped":
			character_id = "sniper"
			weapon_id = "sniper_deadeye_rifle"
			main.set("run_player_snapshot", {
				"stats": ProgressionData.base_stats("sniper"),
				"run_modifiers": {"crit_chance_flat": 5.0},
			})
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", weapon_id)
	main.set("pending_level_ups", 1)
	if state == "normal" or state == "long_copy":
		main.set("level_up_offer", _contextual_level_up_offer(character_id, weapon_id, long_fixture_text))
	else:
		main.set("level_up_offer", [])
	main.ui._show_level_up_screen(false)
	await _settle()

	var offer: Array = main.get("level_up_offer")
	if offer.size() != 3:
		_fail("%s: offer has %d cards, expected 3." % [context, offer.size()])
	var attrs := _offer_attrs(offer)
	match state:
		"ineligible":
			for forbidden in ["damage_flat", "crit_chance", "crit_damage"]:
				if attrs.has(forbidden):
					_fail("%s: cursed_skull offer contains dead axis '%s'." % [context, forbidden])
		"capped":
			if attrs.has("crit_chance"):
				_fail("%s: crit-capped sniper offer still contains crit_chance." % context)
	# Каждая карточка держит фактическую строку before→after (row 0).
	for card_index in range(3):
		var effect := main.find_child("LevelUpRewardButton%d" % card_index, true, false)
		if effect == null:
			_fail("%s: card %d missing." % [context, card_index])
			continue
		var row := (effect as Control).find_child("LevelUpRewardEffectText", true, false) as Label
		if row == null or not row.text.contains("->"):
			_fail("%s: card %d lacks the before->after row." % [context, card_index])
			continue
		_no_trim(row, "%s card %d mandatory values" % [context, card_index])
		if row.clip_text or row.max_lines_visible != -1:
			_fail("%s: card %d mandatory values still use clipping/line truncation." % [context, card_index])
		var reward: Dictionary = offer[card_index] if card_index < offer.size() else {}
		if str(reward.get("attr", "")) != "" and not row.text.contains("реально:"):
			_fail("%s: card %d lacks the complete effective delta." % [context, card_index])
		var row_font := row.get_theme_font("font")
		if row_font == null:
			row_font = ThemeDB.fallback_font
		var required_height := row_font.get_multiline_string_size(
			row.text, HORIZONTAL_ALIGNMENT_CENTER, row.size.x, row.get_theme_font_size("font_size")).y
		if required_height > row.size.y + 2.0:
			_fail("%s: card %d mandatory values need %.1fpx but have %.1fpx." % [context, card_index, required_height, row.size.y])
		if row.get_visible_line_count() < row.get_line_count():
			_fail("%s: card %d mandatory values are not fully visible." % [context, card_index])
	# LU.DetailDrawer: scroll-зона полной копии без ellipsis.
	var drawer := main.find_child("LevelUpDetailDrawer", true, false) as PanelContainer
	var drawer_scroll := main.find_child("LevelUpDetailScroll", true, false) as ScrollContainer
	var drawer_label := main.find_child("LevelUpDetailLabel", true, false) as Label
	if drawer == null or drawer_scroll == null or drawer_label == null:
		_fail("%s: LU.DetailDrawer (panel/scroll/label) is missing." % context)
	else:
		_no_trim(drawer_label, "%s drawer" % context)
		if not drawer.visible and bool(drawer.get_meta("lu_drawer_overlay", false)):
			# Compact focus drawer (спека: «focus drawer — scroll») — появляется
			# при фокусе карточки.
			var first_card := main.find_child("LevelUpRewardButton0", true, false) as Button
			if first_card != null:
				first_card.grab_focus()
				await _settle(2)
		if not drawer.visible:
			_fail("%s: LU.DetailDrawer is hidden at an approved viewport." % context)
		elif str(drawer_label.text).strip_edges() == "":
			_fail("%s: LU.DetailDrawer has no focused-card copy." % context)
		elif state == "long_copy":
			var first_description := str((offer[0] as Dictionary).get("description", ""))
			if not drawer_label.text.contains(first_description):
				_fail("%s: drawer lacks the full long description of the focused card." % context)
			if not drawer_label.text.ends_with(sentinel):
				drawer_label.text += "\n%s" % sentinel
			await _assert_scroll_reaches_sentinel(drawer_scroll, drawer_label, sentinel, context)
	var semantic_text := drawer_label.text if drawer_label != null else "\n".join(_offer_attrs(offer))
	await _capture(fixture, "level_up", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)


# ---------------------------------------------------------- Attribute Shop ---

func _run_attribute_shop(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "attribute_shop %s %s" % [viewport_size, state]
	var character_id := "berserk"
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("attribute_shop", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	match state:
		"capped":
			character_id = "sniper"
			main.set("run_player_snapshot", {
				"stats": ProgressionData.base_stats("sniper"),
				"run_modifiers": {"crit_chance_flat": 5.0},
			})
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", str(ProgressionData.weapon_ids(character_id)[0]))
	match state:
		"ineligible":
			# Leadership незаслуженно сохранён старым сейвом — normalize обязан
			# убрать его до построения AttributeOffers.
			main.set("attribute_offer", ["strength", "leadership"])
		"capped":
			main.set("attribute_offer", ["agility", "strength"])
		_:
			main.set("attribute_offer", ["strength", "agility"])
	main.ui._show_attribute_shop(Callable())
	await _settle(6)

	var offers_box := main.find_child("AttributeOffers", true, false) as Container
	if offers_box == null:
		_fail("%s: AttributeOffers missing." % context)
		await _teardown(fixture)
		return
	if state == "ineligible":
		if main.find_child("AttributeOffer_leadership", true, false) != null:
			_fail("%s: ineligible leadership card is rendered." % context)
		if offers_box.get_child_count() < 2:
			_fail("%s: row not refilled/recentered after filtering (got %d cards)." % [context, offers_box.get_child_count()])
	# Compact-режим НЕ удаляет before→after: у каждой карточки в Preview есть "->".
	for offer_node in offers_box.get_children():
		var preview := (offer_node as Control).find_child("%sPreview" % (offer_node as Control).name, false, false) as Label
		if preview == null or not preview.text.contains("->"):
			_fail("%s: %s preview lost before->after values (text '%s')." % [context, (offer_node as Control).name, preview.text if preview != null else "<none>"])
	if state == "capped":
		var agility_preview := main.find_child("AttributeOffer_agilityPreview", true, false) as Label
		if agility_preview != null:
			var full_preview := str(agility_preview.get_meta("full_text", agility_preview.text))
			if full_preview.contains("Шанс крита"):
				_fail("%s: crit-capped context still promises 'Шанс крита' growth in the +1 preview." % context)
	# AS.DetailDrawer на 1080p+; на compact длинная копия — скроллируемый tooltip.
	var drawer := main.find_child("AttributeShopDetailDrawer", true, false) as PanelContainer
	var drawer_scroll := main.find_child("AttributeShopDetailScroll", true, false) as ScrollContainer
	var drawer_label := main.find_child("AttributeShopDetailLabel", true, false) as Label
	var semantic_text := drawer_label.text if drawer_label != null else ""
	if drawer == null or drawer_label == null:
		_fail("%s: AS.DetailDrawer missing." % context)
	elif viewport_size.y >= 1000:
		if not drawer.visible or str(drawer_label.text).strip_edges() == "":
			_fail("%s: AS.DetailDrawer hidden/empty at %s." % [context, viewport_size])
		else:
			_no_trim(drawer_label, "%s drawer" % context)
	if state == "long_copy" and offers_box.get_child_count() > 0:
		var first_offer := offers_box.get_child(0) as Button
		first_offer.tooltip_text = "%s\n%s" % [first_offer.tooltip_text, long_fixture_text]
		if viewport_size.y >= 1000:
			drawer_label.text = first_offer.tooltip_text
			semantic_text = drawer_label.text
			await _assert_scroll_reaches_sentinel(drawer_scroll, drawer_label, sentinel, context)
		else:
			var tooltip_content := first_offer.call("_make_custom_tooltip", first_offer.tooltip_text) as Control
			if tooltip_content == null:
				_fail("%s: compact installed tooltip did not build content." % context)
			else:
				var tooltip_panel := PanelContainer.new()
				tooltip_panel.name = "AttributeShopLongCopyTooltip"
				tooltip_panel.add_theme_stylebox_override("panel", GlobalTooltip.make_atlas_chip_panel_style())
				tooltip_panel.position = Vector2(roundf((viewport_size.x - 680.0) * 0.5), 170.0)
				tooltip_panel.custom_minimum_size = Vector2(680.0, 360.0)
				tooltip_panel.size = tooltip_panel.custom_minimum_size
				tooltip_panel.add_child(tooltip_content)
				var screen := main.find_child("AttributeShopScreen", true, false) as Control
				if screen == null:
					_fail("%s: AttributeShopScreen missing for compact tooltip fixture." % context)
					tooltip_panel.free()
				else:
					screen.add_child(tooltip_panel)
					await _settle(3)
					var body_scroll := tooltip_content.find_child("GlobalTooltipBodyScroll", true, false) as ScrollContainer
					var body_label := tooltip_content.find_child("GlobalTooltipBodyLabel", true, false) as Label
					semantic_text = body_label.text if body_label != null else ""
					await _assert_scroll_reaches_sentinel(body_scroll, body_label, sentinel, context)
	await _capture(fixture, "attribute_shop", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)


# ------------------------------------------------------------- Pause/Codex ---

func _run_pause_codex(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "pause_codex %s %s" % [viewport_size, state]
	var character_id := "berserk"
	var weapon_id := "sword"
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("pause_codex", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	match state:
		"ineligible":
			character_id = "druid"
			weapon_id = "summon_amulet"
		"capped":
			character_id = "sniper"
			weapon_id = "sniper_deadeye_rifle"
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", weapon_id)
	main.set("route_stage", 2)
	main.call("_start_combat")
	await _settle(4)
	if state == "capped":
		var player: Node = main.get("current_player")
		if player != null and is_instance_valid(player):
			var mods: Dictionary = player.get("run_modifiers")
			mods["crit_chance_flat"] = float(mods.get("crit_chance_flat", 0.0)) + 5.0
			player._apply_stat_scaling()
	main.ui._show_pause_menu(true)
	await _settle(6)

	var pause := main.find_child("PauseStatsMenu", true, false) as Control
	if pause == null:
		pause = main.get("pause_stats_menu") as Control
	if pause == null:
		_fail("%s: pause dossier did not open." % context)
		await _teardown(fixture)
		return
	var semantic_chip := pause.find_child("DerivedStatChip_damage_flat", true, false) as Control
	var semantic_text := str(semantic_chip.get_meta("dossier_tooltip_text", "")) if semantic_chip != null else ""
	match state:
		"normal":
			for axis_id in ["damage_flat", "damage", "attack_speed", "crit_chance", "vampiric", "ultimate_power"]:
				var chip_value := pause.find_child("DerivedStatValue_%s" % axis_id, true, false) as Label
				if chip_value == null or chip_value.text.strip_edges() == "":
					_fail("%s: canonical axis chip '%s' missing/empty." % [context, axis_id])
		"ineligible":
			# SummonerWeapon: generic attack_speed мёртв, «Сила призыва» —
			# фактический integer-парк.
			if pause.find_child("DerivedStatChip_attack_speed", true, false) != null:
				_fail("%s: dead attack_speed axis rendered for summon_amulet." % context)
			var summon_value := pause.find_child("DerivedStatValue_summon_amount", true, false) as Label
			if summon_value == null or not summon_value.text.strip_edges().is_valid_int():
				_fail("%s: summon chip must show the integer runtime pack." % context)
		"capped":
			var crit_value := pause.find_child("DerivedStatValue_crit_chance", true, false) as Label
			if crit_value == null or not crit_value.text.contains("макс"):
				_fail("%s: capped crit chip lacks the readable 'макс.' state (text '%s')." % [context, crit_value.text if crit_value != null else "<none>"])
		"long_copy":
			if semantic_chip == null or semantic_text.strip_edges() == "":
				_fail("%s: axis chip lacks the complete bounded tooltip copy." % context)
			else:
				semantic_chip.set_meta("dossier_tooltip_text", "%s\n%s" % [semantic_text, long_fixture_text])
				semantic_chip.grab_focus()
				await _settle(4)
				var tooltip := pause.find_child("DossierFocusTooltip", true, false) as PanelContainer
				var tooltip_scroll := pause.find_child("DossierFocusTooltipScroll", true, false) as ScrollContainer
				var tooltip_label := pause.find_child("DossierFocusTooltipLabel", true, false) as Label
				if tooltip == null or not tooltip.visible:
					_fail("%s: focused dossier tooltip did not render." % context)
				semantic_text = tooltip_label.text if tooltip_label != null else ""
				await _assert_scroll_reaches_sentinel(tooltip_scroll, tooltip_label, sentinel, context)
	await _capture(fixture, "pause_codex", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)


# ------------------------------------------------------------- Hero Select ---

func _run_hero_select(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "hero_select %s %s" % [viewport_size, state]
	var character_id := "guitarist"
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("hero_select", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	match state:
		"ineligible":
			character_id = "chemist"
		"capped":
			character_id = "assassin"
	main.set("selected_character_id", character_id)
	main.call("_show_character_select")
	await _settle(6)

	var cap_label := main.find_child("HS4BuildGuidance_cap_potential", true, false) as Label
	var capability_label := main.find_child("HS4BuildGuidance_capability", true, false) as Label
	var dossier_scroll := main.find_child("HS4DossierScroll", true, false) as ScrollContainer
	var trait_label := main.find_child("HS4TraitHeading", true, false) as Label
	var semantic_text := trait_label.text if trait_label != null else ""
	if dossier_scroll == null:
		_fail("%s: HS4DossierScroll missing." % context)
	if cap_label == null or capability_label == null:
		_fail("%s: HS.CapPotential/HS.CapabilityLine labels missing." % context)
		await _capture(fixture, "hero_select", viewport_size, state, semantic_text, sentinel)
		await _teardown(fixture)
		return
	_no_trim(cap_label, "%s cap potential" % context)
	_no_trim(capability_label, "%s capability" % context)
	match state:
		"normal":
			# Гитарист: вампиризм-потенциал и реальный summon-потребитель.
			if not cap_label.visible or not cap_label.text.contains("Вампиризм"):
				_fail("%s: guitarist cap potential lacks vampiric proc data (text '%s')." % [context, cap_label.text])
			var amp_title := str(ProgressionData.weapon("guitarist", "sound_amp").get("title", "sound_amp"))
			if not capability_label.visible or not capability_label.text.contains(amp_title):
				_fail("%s: capability line must name the real summon consumer '%s' (text '%s')." % [context, amp_title, capability_label.text])
		"ineligible":
			# Химик: ни одно оружие не потребляет summon_bonus — линия скрыта.
			if capability_label.visible:
				_fail("%s: chemist has no real summon consumer but capability line is visible ('%s')." % [context, capability_label.text])
		"capped":
			if not cap_label.visible or not cap_label.text.contains("максимум 100%"):
				_fail("%s: assassin cap potential must state 'максимум 100%%' (text '%s')." % [context, cap_label.text])
			if cap_label.text.containsn("повы") or cap_label.text.containsn("купить"):
				_fail("%s: cap potential must not carry a CTA." % context)
		"long_copy":
			var content := main.find_child("HS4DossierContent", true, false) as Control
			if content != null and dossier_scroll != null:
				var fixture_label := Label.new()
				fixture_label.name = "HS4LongCopyFixture"
				fixture_label.text = long_fixture_text
				fixture_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				fixture_label.max_lines_visible = -1
				fixture_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
				fixture_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				content.add_child(fixture_label)
				semantic_text = fixture_label.text
				await _assert_scroll_reaches_sentinel(dossier_scroll, fixture_label, sentinel, context)
			else:
				_fail("%s: dossier long-copy content zone is missing." % context)
	await _capture(fixture, "hero_select", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)
