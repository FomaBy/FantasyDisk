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
const QACaptureTeardown := preload("res://tools/qa_capture_teardown.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const STATES := ["normal", "ineligible", "capped", "long_copy"]
const EVIDENCE_DIR := "res://build/qa/fan1927"
# Test-owned fail-closed oracle. Reward IDs, eligibility profiles and every
# expected before/after/delta line are literals: this fixture deliberately does
# not call the production AttributeContract that renders the cards.
const LEVEL_UP_ORACLE := {
	"normal": {
		"character": "berserk",
		"weapon": "sword",
		"mods": {},
		"rewards": [
			{"id": "crit_chance_up", "attr": "crit_chance", "mods": {"crit_chance_flat": 0.07}, "rows": ["Шанс крита: 7% -> 12% · реально: +5%", "сейчас 7% · максимум 55%"]},
			{"id": "vampiric_up", "attr": "vampiric", "mods": {"vampiric_amount_flat": 0.8, "vampiric_chance_flat": 0.05, "vampiric_heal_per_second_cap": 0.8}, "rows": ["Вампиризм: 0.00 -> 0.38 · реально: +0.38", "шанс срабатывания: сейчас 0% · максимум 20%", "Шанс срабатывания: 0% -> 5% (+5 пп)"]},
			{"id": "regeneration_up", "attr": "regeneration", "mods": {"regeneration_flat": 1.3}, "rows": ["Регенерация: 0.13 -> 0.48 · реально: +0.36"]},
		],
	},
	"ineligible": {
		"character": "dark_mage",
		"weapon": "cursed_skull",
		"mods": {},
		"rewards": [
			{"id": "damage_up", "attr": "damage", "mods": {"damage_multiplier": 1.15}, "rows": ["Увеличение урона: 8 -> 9 · реально: +1", "DoT/тик: 7.9 -> 9.1 (+15%)"]},
			{"id": "max_hp_up", "attr": "max_health", "mods": {"max_health_flat": 18.0}, "rows": ["Максимальное здоровье: 38 -> 56 · реально: +18"]},
			{"id": "regeneration_up", "attr": "regeneration", "mods": {"regeneration_flat": 1.3}, "rows": ["Регенерация: 0.15 -> 0.58 · реально: +0.43"]},
		],
	},
	"capped": {
		"character": "sniper",
		"weapon": "sniper_deadeye_rifle",
		"mods": {"crit_chance_flat": 5.0},
		"rewards": [
			{"id": "damage_up", "attr": "damage", "mods": {"damage_multiplier": 1.15}, "rows": ["Физический урон: 14 -> 16 · реально: +2", "DoT/тик: 6.0 -> 6.8 (+15%)"]},
			{"id": "max_hp_up", "attr": "max_health", "mods": {"max_health_flat": 18.0}, "rows": ["Максимальное здоровье: 88 -> 106 · реально: +18"]},
			{"id": "regeneration_up", "attr": "regeneration", "mods": {"regeneration_flat": 1.3}, "rows": ["Регенерация: 0.11 -> 0.43 · реально: +0.32"]},
		],
	},
}

const FORBIDDEN_LEVEL_UP_SELECTION := [
	{
		"name": "capped",
		"character": "sniper",
		"weapon": "sniper_deadeye_rifle",
		"mods": {"crit_chance_flat": 5.0},
		"candidate": {"id": "crit_chance_up", "attr": "crit_chance", "mods": {"crit_chance_flat": 0.07}},
	},
	{
		"name": "ineligible",
		"character": "dark_mage",
		"weapon": "cursed_skull",
		"mods": {},
		"candidate": {"id": "summon_amount_up", "attr": "summon_amount", "mods": {"summon_bonus": 2.0}},
	},
	{
		"name": "no_op",
		"character": "dark_mage",
		"weapon": "cursed_skull",
		"mods": {},
		"candidate": {"id": "damage_flat_up", "attr": "damage_flat", "mods": {"damage_flat": 4.0}},
	},
	{
		"name": "before_equals_after",
		"character": "assassin",
		"weapon": "shadow_daggers",
		"mods": {},
		"candidate": {"id": "attack_speed_up", "attr": "attack_speed", "mods": {"attack_speed_multiplier": 1.12}},
	},
	{
		"name": "zero_effective_delta",
		"character": "assassin",
		"weapon": "shadow_daggers",
		"mods": {},
		"candidate": {"id": "attack_speed_up", "attr": "attack_speed", "mods": {"attack_speed_multiplier": 1.12}},
	},
]

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
	await _run_forbidden_level_up_selection()
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
	var sentinel := "FAN1945_%s_%dx%d_LONG_COPY_END." % [surface.to_upper(), viewport_size.x, viewport_size.y]
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
	if not label.text.ends_with(sentinel):
		_fail("%s: unique sentinel is absent from the preconstructed disclosure." % context)
		return
	scroll.scroll_vertical = int(ceilf(max_scroll))
	await _settle(2)
	var settled_max := maxf(0.0, scrollbar.max_value - scrollbar.page)
	if absf(float(scroll.scroll_vertical) - settled_max) > 2.0:
		_fail("%s: scroll stopped at %d instead of the end %.1f." % [context, scroll.scroll_vertical, settled_max])
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


func _reward_for_id(reward_id: String) -> Dictionary:
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		if str(reward.get("id", "")) == reward_id:
			return reward.duplicate(true)
	return {}


func _offer_attrs(offer: Array) -> Array:
	var attrs: Array = []
	for reward in offer:
		attrs.append(str((reward as Dictionary).get("attr", "")))
	return attrs


func _level_up_oracle_for_state(state: String) -> Dictionary:
	return LEVEL_UP_ORACLE["normal" if state == "long_copy" else state]


func _oracle_level_up_offer(state: String, first_description := "") -> Array:
	var oracle := _level_up_oracle_for_state(state)
	var offer: Array = []
	for index in range((oracle["rewards"] as Array).size()):
		var expected_value = (oracle["rewards"] as Array)[index]
		var expected := expected_value as Dictionary
		var reward := _reward_for_id(str(expected["id"]))
		if reward.is_empty():
			_fail("level_up %s: oracle reward '%s' is missing from the registry." % [state, expected["id"]])
			continue
		if str(reward.get("attr", "")) != str(expected["attr"]) or reward.get("mods", {}) != expected["mods"]:
			_fail("level_up %s: oracle reward '%s' contract drifted (attr/mods)." % [state, expected["id"]])
		if index == 0 and first_description != "":
			reward["description"] = first_description
		offer.append(reward)
	return offer


func _no_trim(label: Label, context: String) -> void:
	if label == null:
		_fail("%s: label missing." % context)
		return
	if label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		_fail("%s: presentation label must use OVERRUN_NO_TRIMMING." % context)


func _run_forbidden_level_up_selection() -> void:
	for scenario_value in FORBIDDEN_LEVEL_UP_SELECTION:
		var scenario := scenario_value as Dictionary
		var fixture := await _new_fixture(Vector2i(1280, 720))
		var main: Node = fixture["main"]
		var character_id := str(scenario["character"])
		var candidate := (scenario["candidate"] as Dictionary).duplicate(true)
		main.set("selected_character_id", character_id)
		main.set("selected_weapon_id", str(scenario["weapon"]))
		main.set("run_player_snapshot", {
			"stats": ProgressionData.base_stats(character_id),
			"run_modifiers": (scenario["mods"] as Dictionary).duplicate(true),
		})
		main.set("pending_level_ups", 1)
		main.set("level_up_offer", [candidate])
		main.ui._show_level_up_screen(false)
		await _settle()
		var selected: Array = main.get("level_up_offer")
		var candidate_id := str(candidate["id"])
		if selected.any(func(reward: Dictionary) -> bool: return str(reward.get("id", "")) == candidate_id):
			_fail("level_up %s: forbidden candidate '%s' reached the production selection path." % [scenario["name"], candidate_id])
		if selected.size() != 3:
			_fail("level_up %s: rejected candidate did not regenerate a complete three-card offer." % scenario["name"])
		await _teardown(fixture)


func _mount_tooltip(root_control: Control, anchor: Control, context: String) -> Dictionary:
	if root_control == null or anchor == null:
		_fail("%s: tooltip root/anchor is missing." % context)
		return {}
	var content := anchor.call("_make_custom_tooltip", anchor.tooltip_text) as Control
	if content == null:
		_fail("%s: installed production tooltip did not build content." % context)
		return {}
	var mounted := PanelContainer.new()
	mounted.name = "FAN1927MountedTooltip"
	mounted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mounted.clip_contents = true
	var viewport_size := root_control.get_viewport_rect().size
	mounted.position = Vector2(
		maxf(12.0, viewport_size.x - minf(560.0, viewport_size.x * 0.46) - 20.0),
		maxf(12.0, viewport_size.y - minf(310.0, viewport_size.y * 0.42) - 20.0)
	)
	mounted.size = Vector2(minf(560.0, viewport_size.x * 0.46), minf(310.0, viewport_size.y * 0.42))
	mounted.custom_minimum_size = mounted.size
	root_control.add_child(mounted)
	mounted.add_child(content)
	await _settle(3)
	return {
		"panel": mounted,
		"scroll": mounted.find_child("GlobalTooltipBodyScroll", true, false) as ScrollContainer,
		"label": mounted.find_child("GlobalTooltipBodyLabel", true, false) as Label,
	}


func _install_translation(message: String) -> Translation:
	var translation := Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message("hero_select_capability_format", "%%s\n%s" % message)
	TranslationServer.add_translation(translation)
	return translation


func _content_safe_rect(control: Control, style_name: String) -> Rect2:
	var style := control.get_theme_stylebox(style_name)
	var rect := control.get_global_rect()
	return Rect2(
		rect.position + Vector2(style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP)),
		rect.size - Vector2(
			style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT),
			style.get_content_margin(SIDE_TOP) + style.get_content_margin(SIDE_BOTTOM)
		)
	).grow(1.0)


func _level_up_geometry_errors(
		row_rect: Rect2,
		viewport_rect: Rect2,
		panel_safe: Rect2,
		card_safe: Rect2,
		drawer_rect: Rect2
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not viewport_rect.encloses(row_rect):
		errors.append("row leaves viewport")
	if not panel_safe.encloses(row_rect):
		errors.append("row leaves LevelUpPanel safe area")
	if not card_safe.encloses(row_rect):
		errors.append("row leaves reward-card safe area")
	if drawer_rect.has_area() and drawer_rect.intersects(row_rect):
		errors.append("LU.DetailDrawer intersects mandatory effect row")
	return errors


# ---------------------------------------------------------------- Level Up ---

func _run_level_up(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "level_up %s %s" % [viewport_size, state]
	var oracle := _level_up_oracle_for_state(state)
	var character_id := str(oracle["character"])
	var weapon_id := str(oracle["weapon"])
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("level_up", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", weapon_id)
	main.set("run_player_snapshot", {
		"stats": ProgressionData.base_stats(character_id),
		"run_modifiers": (oracle["mods"] as Dictionary).duplicate(true),
	})
	main.set("pending_level_ups", 1)
	main.set("level_up_offer", _oracle_level_up_offer(state, long_fixture_text))
	main.ui._show_level_up_screen(false)
	await _settle()

	var offer: Array = main.get("level_up_offer")
	if offer.size() != 3:
		_fail("%s: offer has %d cards, expected 3." % [context, offer.size()])
	var actual_ids: Array = offer.map(func(reward: Dictionary) -> String: return str(reward.get("id", "")))
	var expected_ids: Array = (oracle["rewards"] as Array).map(func(reward: Dictionary) -> String: return str(reward["id"]))
	if actual_ids != expected_ids:
		_fail("%s: fail-closed oracle expected rewards %s, got %s." % [context, expected_ids, actual_ids])

	var drawer := main.find_child("LevelUpDetailDrawer", true, false) as PanelContainer
	var drawer_scroll := main.find_child("LevelUpDetailScroll", true, false) as ScrollContainer
	var drawer_label := main.find_child("LevelUpDetailLabel", true, false) as Label
	if drawer == null or drawer_scroll == null or drawer_label == null:
		_fail("%s: LU.DetailDrawer (panel/scroll/label) is missing." % context)
	else:
		_no_trim(drawer_label, "%s drawer" % context)
		if not drawer.visible and bool(drawer.get_meta("lu_drawer_overlay", false)):
			var first_card := main.find_child("LevelUpRewardButton0", true, false) as Button
			if first_card != null:
				first_card.grab_focus()
				await _settle(2)
		if not drawer.visible:
			_fail("%s: LU.DetailDrawer is hidden at an approved viewport." % context)
		elif str(drawer_label.text).strip_edges() == "":
			_fail("%s: LU.DetailDrawer has no focused-card copy." % context)

	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var level_panel := main.find_child("LevelUpPanel", true, false) as Control
	var panel_safe := _content_safe_rect(level_panel, "panel") if level_panel != null else Rect2()
	var drawer_rect := drawer.get_global_rect() if drawer != null and drawer.visible else Rect2()
	var overlap_probe_run := false
	# Enumerate every mandatory row, including LevelUpRewardEffectText2/3.
	for card_index in range(3):
		var card := main.find_child("LevelUpRewardButton%d" % card_index, true, false) as Button
		if card == null:
			_fail("%s: card %d missing." % [context, card_index])
			continue
		var title := card.find_child("LevelUpRewardTitle", true, false) as Label
		if title == null or title.text.strip_edges() == "" or not title.is_visible_in_tree() \
				or not title.get_global_rect().has_area() or title.get_visible_line_count() < 1:
			_fail("%s: card %d mandatory title is not visibly rendered (rect %s, font %d, lines %d/%d)." % [
				context,
				card_index,
				str(title.get_global_rect()) if title != null else "<missing>",
				title.get_theme_font_size("font_size") if title != null else 0,
				title.get_visible_line_count() if title != null else 0,
				title.get_line_count() if title != null else 0,
			])
		var expected_rows: Array = oracle["rewards"][card_index]["rows"]
		var rows := card.find_children("LevelUpRewardEffectText*", "Label", true, false)
		if rows.size() != expected_rows.size():
			_fail("%s: card %d rendered %d/%d mandatory effect rows." % [context, card_index, rows.size(), expected_rows.size()])
		var card_safe := _content_safe_rect(card, "normal")
		var effect_panel := card.find_child("LevelUpRewardEffectPreview", true, false) as PanelContainer
		if effect_panel == null or (drawer_rect.has_area() and drawer_rect.intersects(effect_panel.get_global_rect())):
			_fail("%s: card %d effect block %s is missing or intersects LU.DetailDrawer %s." % [
				context,
				card_index,
				str(effect_panel.get_global_rect()) if effect_panel != null else "<missing>",
				str(drawer_rect),
			])
		for row_index in range(rows.size()):
			var row := rows[row_index] as Label
			if row_index >= expected_rows.size():
				_fail("%s: card %d has unexpected effect row '%s'." % [context, card_index, row.text])
				continue
			if row.text != str(expected_rows[row_index]):
				_fail("%s: card %d row %d oracle mismatch: expected '%s', got '%s'." % [context, card_index, row_index, expected_rows[row_index], row.text])
			if not row.is_visible_in_tree() or not row.get_global_rect().has_area():
				_fail("%s: card %d row %d is not visibly rendered." % [context, card_index, row_index])
			_no_trim(row, "%s card %d row %d" % [context, card_index, row_index])
			if row.clip_text or row.max_lines_visible != -1:
				_fail("%s: card %d row %d uses clipping/line truncation." % [context, card_index, row_index])
			var row_font := row.get_theme_font("font")
			if row_font == null:
				row_font = ThemeDB.fallback_font
			var required_height := row_font.get_multiline_string_size(
				row.text, HORIZONTAL_ALIGNMENT_CENTER, row.size.x, row.get_theme_font_size("font_size")).y
			if required_height > row.size.y + 2.0 or row.get_visible_line_count() < row.get_line_count():
				_fail("%s: card %d row %d is not fully visible (needs %.1fpx, has %.1fpx)." % [context, card_index, row_index, required_height, row.size.y])
			for geometry_error in _level_up_geometry_errors(
					row.get_global_rect(), viewport_rect, panel_safe, card_safe, drawer_rect):
				_fail("%s: card %d row %d %s." % [context, card_index, row_index, geometry_error])
			if not overlap_probe_run:
				overlap_probe_run = true
				if _level_up_geometry_errors(
						row.get_global_rect(), viewport_rect, panel_safe, card_safe, row.get_global_rect()).is_empty():
					_fail("%s: known-overlap negative probe did not reject a drawer covering an effect row." % context)
	if state == "long_copy" and drawer_label != null:
		var first_description := str((offer[0] as Dictionary).get("description", ""))
		if not drawer_label.text.contains(first_description):
			_fail("%s: drawer lacks the full preconstructed long description." % context)
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
		"long_copy":
			main.set("attribute_offer", [{"id": "strength", "interpretation": long_fixture_text}, "agility"])
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
		if viewport_size.y >= 1000:
			semantic_text = drawer_label.text
			await _assert_scroll_reaches_sentinel(drawer_scroll, drawer_label, sentinel, context)
		else:
			var tooltip_root := main.find_child("AttributeShopScreen", true, false) as Control
			var mounted_tooltip := await _mount_tooltip(tooltip_root, first_offer, context)
			var body_scroll := mounted_tooltip.get("scroll") as ScrollContainer
			var body_label := mounted_tooltip.get("label") as Label
			semantic_text = body_label.text if body_label != null else ""
			_no_trim(body_label, "%s tooltip" % context)
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
	if state == "long_copy":
		var player: Node = main.get("current_player")
		if player != null and is_instance_valid(player):
			player.set("artifacts", [{"id": "", "title": "QA", "description": long_fixture_text, "tier": 1}])
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
	var artifact_chip: Control = null
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
			artifact_chip = pause.find_child("RunEquipmentChip_*", true, false) as Control
	if state == "long_copy":
		if artifact_chip == null:
			_fail("%s: production equipment chip is missing." % context)
		else:
			var mounted_tooltip := await _mount_tooltip(pause, artifact_chip, context)
			var tooltip_scroll := mounted_tooltip.get("scroll") as ScrollContainer
			var tooltip_label := mounted_tooltip.get("label") as Label
			semantic_text = tooltip_label.text if tooltip_label != null else ""
			_no_trim(tooltip_label, "%s tooltip" % context)
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
	var content_translation: Translation = null
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("hero_select", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		content_translation = _install_translation(str(long_fixture["text"]))
	match state:
		"ineligible":
			character_id = "chemist"
		"capped":
			character_id = "assassin"
	main.set("selected_character_id", character_id)
	main.ui._show_character_select()
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
		if content_translation != null:
			TranslationServer.remove_translation(content_translation)
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
			if dossier_scroll != null and capability_label.text.contains(sentinel):
				semantic_text = capability_label.text
				await _assert_scroll_reaches_sentinel(dossier_scroll, capability_label, sentinel, context)
			else:
				_fail("%s: production capability line lacks the preconstructed long-copy sentinel." % context)
	await _capture(fixture, "hero_select", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)
	if content_translation != null:
		TranslationServer.remove_translation(content_translation)
