extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const CODEX_DATA := preload("res://scripts/codex_data.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	_check_shared_data()
	for viewport_size in VIEWPORTS:
		await _check_ui_matrix(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	print("SCRUM-952 Hero Select trait-copy test passed.")
	quit(0)


func _check_shared_data() -> void:
	var ids: Array = PROGRESSION_DATA.character_ids()
	if ids.size() != 17:
		_fail("Expected 17 playable characters, got %d." % ids.size())
		return
	if PROGRESSION_DATA.CLASS_TRAITS.size() != ids.size():
		_fail("CLASS_TRAITS keyset does not cover the playable roster.")
		return
	var codex_by_id := {}
	for entry in CODEX_DATA.characters():
		codex_by_id[str((entry as Dictionary).get("id", ""))] = entry
	for raw_id in ids:
		var cid := str(raw_id)
		var trait_config: Dictionary = PROGRESSION_DATA.class_trait(cid)
		for key in ["id", "title", "description", "short_description"]:
			var value := str(trait_config.get(key, "")).strip_edges()
			if value.is_empty() or value.contains("TODO") or value.contains("res://"):
				_fail("Trait %s has invalid player-facing %s: '%s'." % [cid, key, value])
				return
		var mutated := PROGRESSION_DATA.class_trait(cid)
		mutated["title"] = "mutated"
		if str(PROGRESSION_DATA.class_trait(cid).get("title", "")) == "mutated":
			_fail("class_trait(%s) did not return an isolated copy." % cid)
			return
		var codex_entry: Dictionary = codex_by_id.get(cid, {})
		var projected: Dictionary = codex_entry.get("trait", {})
		if str(projected.get("id", "")) != str(trait_config.get("id", "")):
			_fail("Codex trait id drift for %s." % cid)
			return
		if str(projected.get("title", "")) != str(trait_config.get("title", "")):
			_fail("Codex trait title drift for %s." % cid)
			return
		if str(projected.get("description", "")) != str(trait_config.get("short_description", "")):
			_fail("Codex short trait copy drift for %s." % cid)
			return
		if str(projected.get("details", "")) != str(trait_config.get("description", "")):
			_fail("Codex detailed trait copy drift for %s." % cid)
			return


func _check_ui_matrix(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame

	for raw_id in PROGRESSION_DATA.character_ids():
		var cid := str(raw_id)
		main.set("selected_character_id", cid)
		main.call("_show_character_select")
		await process_frame
		await process_frame
		var dossier: Dictionary = PROGRESSION_DATA.hero_select_dossier(cid)
		var trait_config: Dictionary = dossier.get("trait", {}) as Dictionary
		var heading := main.find_child("HS4TraitHeading", true, false) as Label
		var name_label := main.find_child("HS4NameLabel", true, false) as Label
		var weapon_label := main.find_child("HS4Weapon", true, false) as Label
		var leading_stats := main.find_child("HS4LeadingBaseStats", true, false) as Label
		var primary := main.find_child("HS4BuildGuidance_primary", true, false) as Label
		var secondary := main.find_child("HS4BuildGuidance_secondary", true, false) as Label
		var scroll := main.find_child("HS4DossierScroll", true, false) as ScrollContainer
		var content := main.find_child("HS4DossierContent", true, false) as Control
		var frame := main.find_child("HS4DossierFrame", true, false) as Control
		if heading == null or name_label == null or weapon_label == null or leading_stats == null or primary == null or secondary == null or scroll == null or content == null or frame == null:
			_fail("Missing SCRUM-952 dossier nodes for %s at %s." % [cid, str(viewport_size)])
			return
		if main.find_child("HS4BuildGuidance_weak", true, false) != null:
			_fail("Expected the removed weak-attributes rail to be absent for %s at %s." % [cid, str(viewport_size)])
			return
		var expected_description := str(trait_config.get("short_description", trait_config.get("description", "")))
		var expected_heading := "Особенность: %s — %s" % [str(trait_config.get("title", "")), expected_description]
		if heading.text != expected_heading:
			_fail("Trait copy drift for %s at %s." % [cid, str(viewport_size)])
			return
		if name_label.text != str(dossier.get("name", "")):
			_fail("Hero name drift for %s at %s." % [cid, str(viewport_size)])
			return
		if main.find_child("HS4Strengths", true, false) != null or main.find_child("HS4Weaknesses", true, false) != null or main.find_child("HS4Description", true, false) != null:
			_fail("Obsolete prose dossier nodes are still visible/present for %s." % cid)
			return
		if heading.tooltip_text != heading.text:
			_fail("Exact trait tooltip copy missing for %s at %s." % [cid, str(viewport_size)])
			return
		if not (heading.get_index() < name_label.get_index() and name_label.get_index() < weapon_label.get_index() and weapon_label.get_index() < leading_stats.get_index() and leading_stats.get_index() < primary.get_index() and primary.get_index() < secondary.get_index()):
			_fail("Expected trait -> name -> weapons -> stats -> relevance hierarchy for %s." % cid)
			return
		for label in [heading, name_label, weapon_label, leading_stats, primary, secondary]:
			var copy_label := label as Label
			if copy_label.max_lines_visible >= 0 or copy_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS:
				_fail("Canonical copy is truncatable in %s for %s." % [copy_label.name, cid])
				return
			if copy_label.get_parent() != content:
				_fail("%s escaped HS4DossierContent for %s." % [copy_label.name, cid])
				return
			var copy_rect := copy_label.get_global_rect()
			var scroll_rect := scroll.get_global_rect()
			if copy_rect.position.x < scroll_rect.position.x - 1.0 or copy_rect.end.x > scroll_rect.end.x + 1.0:
				_fail("%s crosses the dossier text lane at %s for %s." % [copy_label.name, str(viewport_size), cid])
				return
			# SCRUM-1064 intentionally keeps complete relevance lists in the same
			# scroll canvas at every tier; vertical overflow is accepted only when
			# the final secondary section remains reachable below.
		if not frame.get_global_rect().grow(1.0).encloses(scroll.get_global_rect()):
			_fail("Dossier scroll left the frame-safe content area at %s." % str(viewport_size))
			return
		if scroll.focus_mode != Control.FOCUS_ALL:
			_fail("Compact dossier scroll is not keyboard/gamepad focusable at %s." % str(viewport_size))
			return
		var bar := scroll.get_v_scroll_bar()
		var max_scroll := maxi(0, int(ceil(bar.max_value - bar.page)))
		var required_scroll := maxi(0, int(ceil(secondary.get_global_rect().end.y - scroll.get_global_rect().end.y)))
		if max_scroll < required_scroll:
			_fail("Secondary section is not scroll-reachable for %s at %s." % [cid, str(viewport_size)])
			return
		if viewport_size == Vector2i(1280, 720) and cid == "druid":
			await _check_compact_dossier_input(viewport, main, scroll, max_scroll)
		scroll.scroll_vertical = max_scroll
		await process_frame

	if DisplayServer.get_name() != "headless":
		var final_scroll := main.find_child("HS4DossierScroll", true, false) as ScrollContainer
		if final_scroll != null:
			final_scroll.scroll_vertical = 0
			await process_frame
		var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum952")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png("%s/hero_select_trait_copy_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_fail("SCRUM-952 viewport teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])


func _check_compact_dossier_input(viewport: SubViewport, main: Node, scroll: ScrollContainer, max_scroll: int) -> void:
	if max_scroll <= 0:
		_fail("SCRUM-1046 oracle requires overflowing Druid copy at 1280x720.")
		return
	var choose := main.find_child("HS4ChooseButton", true, false) as Button
	var back := main.find_child("HS4BackButton", true, false) as Button
	var next_hero := main.find_child("HS4CarouselNextButton", true, false) as Button
	if choose == null or back == null or next_hero == null:
		_fail("SCRUM-1046 missing Hero Select boundary/reset controls.")
		return

	# Physical keyboard Down scrolls first and consumes focus navigation.
	scroll.scroll_vertical = 0
	scroll.grab_focus()
	await process_frame
	await _push_key(viewport, KEY_DOWN)
	if scroll.scroll_vertical <= 0 or viewport.gui_get_focus_owner() != scroll:
		_fail("SCRUM-1046 keyboard Down did not scroll first while retaining dossier focus.")
		return

	# Physical D-pad follows the same semantic ui_down binding.
	scroll.scroll_vertical = 0
	scroll.grab_focus()
	await process_frame
	await _push_dpad(viewport, JOY_BUTTON_DPAD_DOWN)
	if scroll.scroll_vertical <= 0 or viewport.gui_get_focus_owner() != scroll:
		_fail("SCRUM-1046 D-pad Down did not scroll first while retaining dossier focus.")
		return

	# Page actions must be handled locally as well, not left to an unreliable
	# default ScrollContainer route.
	scroll.scroll_vertical = 0
	scroll.grab_focus()
	await process_frame
	await _push_key(viewport, KEY_PAGEDOWN)
	if scroll.scroll_vertical <= 0 or viewport.gui_get_focus_owner() != scroll:
		_fail("SCRUM-1046 PageDown did not scroll the compact dossier.")
		return
	scroll.scroll_vertical = max_scroll
	await process_frame
	await _push_key(viewport, KEY_PAGEUP)
	if scroll.scroll_vertical >= max_scroll or viewport.gui_get_focus_owner() != scroll:
		_fail("SCRUM-1046 PageUp did not scroll upward while retaining dossier focus.")
		return

	# At the bottom/top only, the same action transfers focus to the explicit
	# neighbour declared by the Hero Select focus graph.
	scroll.scroll_vertical = max_scroll
	scroll.grab_focus()
	await process_frame
	await _push_dpad(viewport, JOY_BUTTON_DPAD_DOWN)
	if viewport.gui_get_focus_owner() != choose:
		_fail("SCRUM-1046 bottom boundary did not hand D-pad focus to Choose.")
		return
	scroll.scroll_vertical = 0
	scroll.grab_focus()
	await process_frame
	await _push_key(viewport, KEY_UP)
	if viewport.gui_get_focus_owner() != back:
		_fail("SCRUM-1046 top boundary did not hand keyboard focus to Back.")
		return

	# Existing hero-change reset remains synchronous/deferred-safe.
	scroll.scroll_vertical = max_scroll
	var previous_class_id := str(main.get("selected_character_id"))
	next_hero.pressed.emit()
	await process_frame
	await process_frame
	if str(main.get("selected_character_id")) == previous_class_id or scroll.scroll_vertical != 0:
		_fail("SCRUM-1046 hero change did not reset dossier scroll to zero.")


func _push_key(viewport: SubViewport, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _push_dpad(viewport: SubViewport, button_index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = button_index
	press.pressed = true
	press.pressure = 1.0
	viewport.push_input(press)
	await process_frame
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = button_index
	release.pressed = false
	release.pressure = 0.0
	viewport.push_input(release)
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
