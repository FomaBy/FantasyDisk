extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PD := preload("res://scripts/progression_data.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const RELEVANCE_ORDER := ["primary", "secondary", "weak"]
const RELEVANCE_TITLES := {
	"primary": "Основные атрибуты",
	"secondary": "Второстепенные атрибуты",
	"weak": "Слабые атрибуты",
}

var _errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	_check_all_character_data()
	for viewport_size in VIEWPORTS:
		await _check_ui_matrix(viewport_size)
	await _check_live_resize()
	await _capture_teardown.release_windowed_audio(self)
	if not _errors.is_empty():
		for message in _errors:
			push_error("[SCRUM-1064] %s" % message)
		quit(1)
		return
	print("SCRUM-1064 structured Hero Select dossier passed: 17 heroes, schema/relevance/weapons/traits, 1152/720/1080/2K + live resize.")
	quit(0)


func _check_all_character_data() -> void:
	var roster: Array = PD.character_ids()
	if roster.size() != 17:
		_errors.append("Expected 17 canonical heroes, got %d." % roster.size())
		return
	var registry_ids := PackedStringArray()
	for entry_value in PD.ATTRIBUTE_REGISTRY:
		registry_ids.append(str((entry_value as Dictionary).get("id", "")))
	var stat_order: Array = PD.STAT_NAMES.keys()
	for cid_value in roster:
		var cid := str(cid_value)
		var dossier: Dictionary = PD.hero_select_dossier(cid)
		if dossier.has("description") or dossier.has("strengths") or dossier.has("weaknesses"):
			_errors.append("%s dossier leaks obsolete prose fields." % cid)
		var config: Dictionary = PD.character_config(cid)
		if str(dossier.get("id", "")) != cid or str(dossier.get("name", "")) != str(config.get("title", "")):
			_errors.append("%s dossier id/name drift." % cid)
		var expected_trait: Dictionary = PD.class_trait(cid)
		var dossier_trait: Dictionary = dossier.get("trait", {}) as Dictionary
		if not expected_trait.is_empty() and dossier_trait != expected_trait:
			_errors.append("%s dossier trait is not the canonical CLASS_TRAITS record." % cid)
		var weapon_ids: Array = PD.weapon_ids(cid)
		var dossier_weapons: Array = dossier.get("weapons", []) as Array
		if weapon_ids.size() != 3 or dossier_weapons.size() != weapon_ids.size():
			_errors.append("%s must expose exactly its 3 selectable weapons." % cid)
		else:
			for i in range(weapon_ids.size()):
				var wid := str(weapon_ids[i])
				var expected_weapon: Dictionary = PD.weapon(cid, wid)
				var actual_weapon := dossier_weapons[i] as Dictionary
				if str(actual_weapon.get("id", "")) != wid or str(actual_weapon.get("name", "")) != str(expected_weapon.get("title", "")):
					_errors.append("%s weapon projection drift at index %d." % [cid, i])
		var leading: Array = dossier.get("leading_base_stats", []) as Array
		if leading.size() != 3:
			_errors.append("%s leading BASE_STATS count != 3." % cid)
		else:
			var previous_value := INF
			var previous_index := -1
			for row_value in leading:
				var row := row_value as Dictionary
				var sid := str(row.get("id", ""))
				var value := float(row.get("value", -INF))
				if not is_equal_approx(value, float(PD.BASE_STATS[cid].get(sid, INF))):
					_errors.append("%s leading stat %s does not match BASE_STATS." % [cid, sid])
				var canonical_index := stat_order.find(sid)
				if value > previous_value or (is_equal_approx(value, previous_value) and canonical_index <= previous_index):
					_errors.append("%s leading stats violate value-desc/canonical-tie order." % cid)
				previous_value = value
				previous_index = canonical_index
		var groups: Dictionary = dossier.get("attribute_relevance", {}) as Dictionary
		var seen := {}
		for category in RELEVANCE_ORDER:
			for entry_value in groups.get(category, []) as Array:
				var entry := entry_value as Dictionary
				var attr_id := str(entry.get("id", ""))
				if seen.has(attr_id):
					_errors.append("%s relevance categories overlap on %s." % [cid, attr_id])
				seen[attr_id] = category
				var matrix_category := PD.attribute_relevance(attr_id, cid)
				var expected_category := "weak" if matrix_category == "optional" else matrix_category
				if category != expected_category:
					_errors.append("%s relevance category drift for %s." % [cid, attr_id])
		if seen.size() != registry_ids.size():
			_errors.append("%s relevance union covers %d/%d registry entries." % [cid, seen.size(), registry_ids.size()])
		for attr_id in registry_ids:
			if not seen.has(attr_id):
				_errors.append("%s relevance misses registry attribute %s." % [cid, attr_id])

	# Subject-matter regression anchors from the 17-kit audit. These are
	# mechanics, not balance-number changes.
	_expect_relevance("doctor", ["regeneration", "vampiric_amount", "vampiric_chance"], "optional")
	_expect_relevance("assassin", ["crit_chance", "crit_damage"], "primary")
	_expect_relevance("chemist", ["dot_damage", "dot_speed"], "primary")
	_expect_relevance("druid", ["buff_power", "aura_radius", "summon_amount"], "primary")
	_expect_relevance("robot", ["defense"], "secondary")


func _expect_relevance(cid: String, attr_ids: Array, expected: String) -> void:
	for attr_id_value in attr_ids:
		var attr_id := str(attr_id_value)
		var actual := PD.attribute_relevance(attr_id, cid)
		if actual != expected:
			_errors.append("Audit anchor %s/%s expected %s, got %s." % [cid, attr_id, expected, actual])


func _check_ui_matrix(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	for cid_value in PD.character_ids():
		var cid := str(cid_value)
		main.set("selected_character_id", cid)
		main.call("_show_character_select")
		await process_frame
		await process_frame
		_check_hero_ui(main, cid, viewport_size)
	if DisplayServer.get_name() != "headless":
		var preview_dir := ProjectSettings.globalize_path("res://docs/design/previews/scrum1064_hero_dossier")
		DirAccess.make_dir_recursive_absolute(preview_dir)
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			_errors.append("Metal capture returned no image at %s." % str(viewport_size))
		else:
			image.save_png("%s/runtime_%dx%d.png" % [preview_dir, viewport_size.x, viewport_size.y])
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_errors.append("Viewport teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])


func _check_hero_ui(main: Node, cid: String, viewport_size: Vector2i) -> void:
	var dossier: Dictionary = PD.hero_select_dossier(cid)
	var content := main.find_child("HS4DossierContent", true, false) as VBoxContainer
	var scroll := main.find_child("HS4DossierScroll", true, false) as ScrollContainer
	var frame := main.find_child("HS4DossierFrame", true, false) as Control
	var stats := main.find_child("HS4StatsColumn", true, false) as Control
	var trait_label := main.find_child("HS4TraitHeading", true, false) as Label
	var name_label := main.find_child("HS4NameLabel", true, false) as Label
	var weapon_label := main.find_child("HS4Weapon", true, false) as Label
	var leading_label := main.find_child("HS4LeadingBaseStats", true, false) as Label
	var primary := main.find_child("HS4BuildGuidance_primary", true, false) as Label
	var secondary := main.find_child("HS4BuildGuidance_secondary", true, false) as Label
	var weak := main.find_child("HS4BuildGuidance_weak", true, false) as Label
	if content == null or scroll == null or frame == null or stats == null or trait_label == null or name_label == null or weapon_label == null or leading_label == null or primary == null or secondary == null or weak == null:
		_errors.append("%s missing structured dossier nodes at %s." % [cid, str(viewport_size)])
		return
	if main.find_child("HS4Description", true, false) != null or main.find_child("HS4Strengths", true, false) != null or main.find_child("HS4Weaknesses", true, false) != null or main.find_child("HS4MainAttributes", true, false) != null:
		_errors.append("%s still exposes obsolete prose/priority nodes at %s." % [cid, str(viewport_size)])
	var trait_record: Dictionary = dossier.get("trait", {}) as Dictionary
	var expected_trait := "Особенность: %s — %s" % [
		str(trait_record.get("title", "")),
		str(trait_record.get("short_description", trait_record.get("description", ""))),
	]
	if trait_label.text != expected_trait or not trait_label.visible:
		_errors.append("%s trait copy/order drift at %s." % [cid, str(viewport_size)])
	if name_label.text != str(dossier.get("name", "")):
		_errors.append("%s name drift at %s." % [cid, str(viewport_size)])
	var expected_weapons := "Оружие: %s" % _join_names(dossier.get("weapons", []) as Array)
	if weapon_label.text != expected_weapons:
		_errors.append("%s canonical weapon names drift at %s." % [cid, str(viewport_size)])
	var expected_stats := PackedStringArray()
	for row_value in dossier.get("leading_base_stats", []) as Array:
		var row := row_value as Dictionary
		expected_stats.append("%s — %d" % [str(row.get("name", "")), int(round(float(row.get("value", 0.0))))])
	if leading_label.text != "Основные характеристики: %s." % "; ".join(expected_stats):
		_errors.append("%s leading stat copy drift at %s." % [cid, str(viewport_size)])
	var groups: Dictionary = dossier.get("attribute_relevance", {}) as Dictionary
	for category in RELEVANCE_ORDER:
		var label := main.find_child("HS4BuildGuidance_%s" % category, true, false) as Label
		var expected := "%s: %s" % [RELEVANCE_TITLES[category], _join_names(groups.get(category, []) as Array)]
		if label.text != expected or label.text.contains("+") or label.text.contains("Дополнительные атрибуты"):
			_errors.append("%s complete %s list drift/truncation at %s." % [cid, category, str(viewport_size)])
	var ordered := [trait_label, name_label, weapon_label, leading_label, primary, secondary, weak]
	for i in range(ordered.size() - 1):
		if (ordered[i] as Control).get_index() >= (ordered[i + 1] as Control).get_index():
			_errors.append("%s dossier block order failed at %s." % [cid, str(viewport_size)])
			break
	for label_value in ordered:
		var label := label_value as Label
		if label.get_parent() != content or label.max_lines_visible >= 0 or label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS:
			_errors.append("%s %s is outside scroll content or truncatable at %s." % [cid, label.name, str(viewport_size)])
	var frame_rect := frame.get_global_rect().grow(1.0)
	if not frame_rect.encloses(scroll.get_global_rect()) or not frame_rect.encloses(stats.get_global_rect()):
		_errors.append("%s dossier lanes leave frame-safe interior at %s." % [cid, str(viewport_size)])
	if scroll.get_global_rect().end.x > stats.get_global_rect().position.x - 2.0:
		_errors.append("%s dossier scrollbar/text lane overlaps fixed stats at %s." % [cid, str(viewport_size)])
	if scroll.focus_mode != Control.FOCUS_ALL or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_errors.append("%s dossier scroll input contract drift at %s." % [cid, str(viewport_size)])
	var bar := scroll.get_v_scroll_bar()
	var max_scroll := maxi(0, int(ceil(bar.max_value - bar.page)))
	var required_scroll := maxi(0, int(ceil(weak.get_global_rect().end.y - scroll.get_global_rect().end.y)))
	if max_scroll < required_scroll:
		_errors.append("%s weak list is not scroll-reachable at %s." % [cid, str(viewport_size)])


func _check_live_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "druid")
	main.call("_show_character_select")
	await process_frame
	await process_frame
	var old_root := main.find_child("HeroSelectScreen", true, false) as Control
	viewport.size = Vector2i(1920, 1080)
	for _i in range(6):
		await process_frame
	var new_root := main.find_child("HeroSelectScreen", true, false) as Control
	var frame := main.find_child("HS4DossierFrame", true, false) as Control
	var weak := main.find_child("HS4BuildGuidance_weak", true, false) as Label
	if new_root == null or new_root == old_root or frame == null or weak == null:
		_errors.append("Hero Select did not rebuild its structured dossier on live resize.")
	else:
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(1.0)
		if not viewport_rect.encloses(frame.get_global_rect()) or weak.text.strip_edges().is_empty():
			_errors.append("Live-resized dossier left viewport or lost data.")
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_errors.append("Live resize viewport teardown failed: %s" % "; ".join(teardown_errors))


func _join_names(entries: Array) -> String:
	var names := PackedStringArray()
	for entry_value in entries:
		var entry := entry_value as Dictionary
		names.append(str(entry.get("name", entry.get("id", ""))))
	return ", ".join(names) if not names.is_empty() else "Нет."
