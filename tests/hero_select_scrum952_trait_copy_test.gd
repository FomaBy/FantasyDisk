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
		var config: Dictionary = PROGRESSION_DATA.character_config(cid)
		var trait_config: Dictionary = PROGRESSION_DATA.class_trait(cid)
		for key in ["id", "title", "description", "short_description"]:
			var value := str(trait_config.get(key, "")).strip_edges()
			if value.is_empty() or value.contains("TODO") or value.contains("res://"):
				_fail("Trait %s has invalid player-facing %s: '%s'." % [cid, key, value])
				return
		for key in ["strengths", "weaknesses"]:
			if str(config.get(key, "")).strip_edges().is_empty():
				_fail("Character %s has empty %s." % [cid, key])
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
		var trait_config: Dictionary = PROGRESSION_DATA.class_trait(cid)
		var config: Dictionary = PROGRESSION_DATA.character_config(cid)
		var heading := main.find_child("HS4TraitHeading", true, false) as Label
		var strengths := main.find_child("HS4Strengths", true, false) as Label
		var weaknesses := main.find_child("HS4Weaknesses", true, false) as Label
		var playstyle := main.find_child("HS4Description", true, false) as Label
		var scroll := main.find_child("HS4DossierScroll", true, false) as ScrollContainer
		var content := main.find_child("HS4DossierContent", true, false) as Control
		var frame := main.find_child("HS4DossierFrame", true, false) as Control
		if heading == null or strengths == null or weaknesses == null or playstyle == null or scroll == null or content == null or frame == null:
			_fail("Missing SCRUM-952 dossier nodes for %s at %s." % [cid, str(viewport_size)])
			return
		var expected_description := str(trait_config.get("short_description", trait_config.get("description", "")))
		var expected_heading := "Особенность — %s: %s" % [str(trait_config.get("title", "")), expected_description]
		if heading.text != expected_heading:
			_fail("Trait copy drift for %s at %s." % [cid, str(viewport_size)])
			return
		if strengths.text != "Плюсы: %s" % str(config.get("strengths", "")):
			_fail("Plus copy drift for %s at %s." % [cid, str(viewport_size)])
			return
		if weaknesses.text != "Минусы: %s" % str(config.get("weaknesses", "")):
			_fail("Minus copy drift for %s at %s." % [cid, str(viewport_size)])
			return
		if not heading.tooltip_text.contains(expected_description) or strengths.tooltip_text != strengths.text or weaknesses.tooltip_text != weaknesses.text:
			_fail("Full tooltip copy missing for %s at %s." % [cid, str(viewport_size)])
			return
		if not (heading.get_index() < strengths.get_index() and strengths.get_index() < weaknesses.get_index() and weaknesses.get_index() < playstyle.get_index()):
			_fail("Expected trait -> plus -> minus hierarchy for %s." % cid)
			return
		for label in [heading, strengths, weaknesses]:
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
			if viewport_size.y >= 1000 and not scroll_rect.grow(1.0).encloses(copy_rect):
				_fail("%s is not fully visible without scrolling at %s for %s: copy=%s scroll=%s." % [copy_label.name, str(viewport_size), cid, str(copy_rect), str(scroll_rect)])
				return
		if not frame.get_global_rect().grow(1.0).encloses(scroll.get_global_rect()):
			_fail("Dossier scroll left the frame-safe content area at %s." % str(viewport_size))
			return
		if scroll.focus_mode != Control.FOCUS_ALL:
			_fail("Compact dossier scroll is not keyboard/gamepad focusable at %s." % str(viewport_size))
			return
		var bar := scroll.get_v_scroll_bar()
		var max_scroll := maxi(0, int(ceil(bar.max_value - bar.page)))
		var required_scroll := maxi(0, int(ceil(weaknesses.get_global_rect().end.y - scroll.get_global_rect().end.y)))
		if max_scroll < required_scroll:
			_fail("Minus section is not scroll-reachable for %s at %s." % [cid, str(viewport_size)])
			return
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
