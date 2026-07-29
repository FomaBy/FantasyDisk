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
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const STATES := ["normal", "ineligible", "capped", "long_copy"]
const EVIDENCE_DIR := "res://build/qa/fan1927"

var _errors := PackedStringArray()
var _validated := 0
var _captured := 0


func _fail(message: String) -> void:
	_errors.append(message)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIR))
	for viewport_size in VIEWPORTS:
		for state in STATES:
			await _run_level_up(viewport_size, str(state))
			await _run_attribute_shop(viewport_size, str(state))
			await _run_pause_codex(viewport_size, str(state))
			await _run_hero_select(viewport_size, str(state))
	if _validated != 48:
		_fail("Validated %d runtime states instead of 48." % _validated)
	if not _errors.is_empty():
		for error in _errors:
			push_error("[fan1927-matrix] %s" % error)
		push_error("FAN-1927 48-state UI matrix FAILED (%d/48 states, %d captures)." % [_validated, _captured])
		quit(1)
		return
	print("FAN-1927 48-state UI matrix passed: %d/48 runtime states validated, %d PNG captures in %s (4 surfaces × 3 viewports × 4 states)." % [_validated, _captured, EVIDENCE_DIR])
	quit(0)


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
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
	await process_frame


func _settle(frames := 4) -> void:
	for _index in range(frames):
		await process_frame


func _capture(fixture: Dictionary, surface: String, viewport_size: Vector2i, state: String) -> void:
	_validated += 1
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
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s %s %s: Metal capture returned no image." % [surface, viewport_size, state])
		return
	image.save_png(ProjectSettings.globalize_path("%s/%s_%dx%d_%s.png" % [EVIDENCE_DIR, surface, viewport_size.x, viewport_size.y, state]))
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
	if state == "long_copy":
		# Три реальные карты с самой длинной русской копией.
		var by_length: Array = []
		for reward in ProgressionData.LEVEL_UP_REWARDS:
			by_length.append(reward.duplicate(true))
		by_length.sort_custom(func(a, b): return str((a as Dictionary).get("description", "")).length() > str((b as Dictionary).get("description", "")).length())
		main.set("level_up_offer", by_length.slice(0, 3))
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
			await _settle(2)
			if drawer_label.size.y > drawer_scroll.size.y + 1.0 and drawer_scroll.get_v_scroll_bar().max_value <= drawer_scroll.size.y:
				_fail("%s: long copy overflows the drawer without a working scroll range." % context)
	await _capture(fixture, "level_up", viewport_size, state)
	await _teardown(fixture)


# ---------------------------------------------------------- Attribute Shop ---

func _run_attribute_shop(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "attribute_shop %s %s" % [viewport_size, state]
	var character_id := "berserk"
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
	var drawer_label := main.find_child("AttributeShopDetailLabel", true, false) as Label
	if drawer == null or drawer_label == null:
		_fail("%s: AS.DetailDrawer missing." % context)
	elif viewport_size.y >= 1000:
		if not drawer.visible or str(drawer_label.text).strip_edges() == "":
			_fail("%s: AS.DetailDrawer hidden/empty at %s." % [context, viewport_size])
		else:
			_no_trim(drawer_label, "%s drawer" % context)
	else:
		var long_body := "Тестовая длинная русская копия. " .repeat(60)
		var tooltip_content := GlobalTooltip.make_tooltip_content("Заголовок\n%s" % long_body, offers_box)
		if tooltip_content.find_child("GlobalTooltipBodyScroll", true, false) == null:
			_fail("%s: compact long copy has no scrollable tooltip body." % context)
		tooltip_content.free()
	await _capture(fixture, "attribute_shop", viewport_size, state)
	await _teardown(fixture)


# ------------------------------------------------------------- Pause/Codex ---

func _run_pause_codex(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "pause_codex %s %s" % [viewport_size, state]
	var character_id := "berserk"
	var weapon_id := "sword"
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
			# Длинная копия оси доступна через bounded tooltip досье (scroll-путь
			# закреплён scrum983_escape_dossier_test); проверяем полноту данных.
			var chip := pause.find_child("DerivedStatChip_damage_flat", true, false) as Control
			if chip == null or str(chip.get_meta("dossier_tooltip_text", "")).strip_edges() == "":
				_fail("%s: axis chip lacks the complete bounded tooltip copy." % context)
	await _capture(fixture, "pause_codex", viewport_size, state)
	await _teardown(fixture)


# ------------------------------------------------------------- Hero Select ---

func _run_hero_select(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "hero_select %s %s" % [viewport_size, state]
	var character_id := "guitarist"
	match state:
		"ineligible":
			character_id = "chemist"
		"capped":
			character_id = "assassin"
		"long_copy":
			character_id = "druid"
	main.set("selected_character_id", character_id)
	main.call("_show_character_select")
	await _settle(6)

	var cap_label := main.find_child("HS4BuildGuidance_cap_potential", true, false) as Label
	var capability_label := main.find_child("HS4BuildGuidance_capability", true, false) as Label
	var dossier_scroll := main.find_child("HS4DossierScroll", true, false) as ScrollContainer
	if dossier_scroll == null:
		_fail("%s: HS4DossierScroll missing." % context)
	if cap_label == null or capability_label == null:
		_fail("%s: HS.CapPotential/HS.CapabilityLine labels missing." % context)
		await _capture(fixture, "hero_select", viewport_size, state)
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
				await _settle(2)
				if content.size.y > dossier_scroll.size.y + 1.0 and dossier_scroll.get_v_scroll_bar().max_value <= 0.0:
					_fail("%s: dossier long copy overflows without a scroll range." % context)
	await _capture(fixture, "hero_select", viewport_size, state)
	await _teardown(fixture)
