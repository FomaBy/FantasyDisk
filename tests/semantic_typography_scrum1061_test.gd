extends SceneTree

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")
const INVENTORY_PATH := "res://docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json"
const VIEWPORT_HEIGHTS := [648.0, 720.0, 900.0, 1080.0, 1440.0, 2160.0]
const RUSSIAN_SAMPLES := {
	"title": "Продолжить забег?",
	"section": "Боевые параметры",
	"body": "Выбранный путь фиксируется до завершения следующего сражения.",
	"description": "Увеличивает сопротивление и сохраняет читаемость длинного описания.",
	"action": "Сбросить игровые настройки",
	"tab": "Управление",
	"field": "Множитель здоровья противников",
	"value": "Пользовательский ×1,25",
	"tooltip": "Критический шанс\nВероятность нанести усиленный урон.",
	"caption": "LB/RB — сменить вкладку",
	"hud": "Следующая волна: 00:42",
}

var _errors := PackedStringArray()


func _initialize() -> void:
	_check_tokens()
	_check_compatibility_resolvers()
	_check_russian_glyph_matrix()
	_check_inventory()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1061 semantic typography token/inventory/Russian matrix passed at 648/720/900/1080/2K/4K tiers.")
	quit(0)


func _check_tokens() -> void:
	var roles := SemanticTypography.roles()
	if roles.size() != 12:
		_errors.append("Expected 12 semantic roles, got %d." % roles.size())
	for role in roles:
		var spec := SemanticTypography.token(role)
		var min_px := int(spec.get("min", 0))
		var target_px := int(spec.get("target", 0))
		var max_px := int(spec.get("max", 0))
		if min_px <= 0 or min_px > target_px or target_px > max_px:
			_errors.append("%s has invalid min/target/max: %s." % [role, str(spec)])
		if str(spec.get("overflow", "")).is_empty():
			_errors.append("%s has no overflow policy." % role)
		var previous := -1
		for height in VIEWPORT_HEIGHTS:
			var effective := SemanticTypography.resolve(role, height)
			if effective < min_px or effective > max_px:
				_errors.append("%s @%d resolves to %d outside %d..%d." % [role, int(height), effective, min_px, max_px])
			if previous > effective:
				_errors.append("%s semantic scale is not monotonic at %d." % [role, int(height)])
			previous = effective


func _check_compatibility_resolvers() -> void:
	# Exact SCRUM-883 values: centralization must not move accepted geometry.
	for row in [
		[648.0, 16, 21],
		[720.0, 16, 22],
		[864.0, 16, 23],
		[1080.0, 16, 23],
	]:
		var actual := SemanticTypography.resolve_authored_compat(
			SemanticTypography.ROLE_ACTION, row[1], row[0]
		)
		if actual != row[2]:
			_errors.append("Authored compatibility %s expected %d, got %d." % [str(row), row[2], actual])
	if SemanticTypography.resolve_scaled_compat(SemanticTypography.ROLE_FIELD, 26.0, 0.75, 12) != 20:
		_errors.append("Settings authored 26×0.75 compatibility changed.")
	for row in [[24, 0.6, 17, 32], [24, 1.0, 17, 32], [24, 2.0, 17, 32]]:
		var local_px := SemanticTypography.resolve_transform_aware(
			SemanticTypography.ROLE_BODY, row[0], row[1], row[2], row[3]
		)
		var visual_px := float(local_px) * float(row[1])
		if visual_px + 0.61 < float(row[2]) or visual_px - 0.61 > float(row[3]):
			_errors.append("Transform-aware Codex visual px %.2f escapes %d..%d." % [visual_px, row[2], row[3]])


func _check_russian_glyph_matrix() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		_errors.append("Fallback font is unavailable for Russian glyph verification.")
		return
	for glyph in ["Ж", "Я", "й", "ё", "×"]:
		if not font.has_char(glyph.unicode_at(0)):
			_errors.append("Runtime fallback font misses required glyph '%s'." % glyph)
	for role_name in RUSSIAN_SAMPLES:
		var role := StringName(role_name)
		for height in VIEWPORT_HEIGHTS:
			var px := SemanticTypography.resolve(role, height)
			var sample := str(RUSSIAN_SAMPLES[role_name])
			var measured := font.get_multiline_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px)
			if measured.x <= 0.0 or measured.y <= 0.0:
				_errors.append("%s @%d has no measurable Russian glyphs." % [role_name, int(height)])
			if px < SemanticTypography.role_min(role):
				_errors.append("%s @%d fell below its semantic minimum." % [role_name, int(height)])
	var tooltip_text := "%s %s %s %s" % [RUSSIAN_SAMPLES["tooltip"], RUSSIAN_SAMPLES["tooltip"], RUSSIAN_SAMPLES["tooltip"], RUSSIAN_SAMPLES["tooltip"]]
	var tooltip := GlobalTooltip.make_tooltip_label(tooltip_text)
	if tooltip.get_theme_font_size("font_size") < SemanticTypography.role_min(SemanticTypography.ROLE_TOOLTIP):
		_errors.append("Live GlobalTooltip label is below the tooltip token floor.")
	if tooltip.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
		_errors.append("Live GlobalTooltip long Russian copy lost smart-wrap overflow policy.")
	var applied := Label.new()
	SemanticTypography.apply(applied, SemanticTypography.ROLE_BODY, 1080.0)
	if str(applied.get_meta("semantic_typography_role", "")) != "body" or str(applied.get_meta("semantic_typography_overflow", "")).is_empty():
		_errors.append("SemanticTypography.apply() did not publish role/overflow metadata.")
	tooltip.free()
	applied.free()


func _check_inventory() -> void:
	if not FileAccess.file_exists(INVENTORY_PATH):
		_errors.append("Typography inventory JSON is missing.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_PATH))
	if not parsed is Dictionary:
		_errors.append("Typography inventory JSON is invalid.")
		return
	var inventory := parsed as Dictionary
	if int(inventory.get("schema", 0)) != 2:
		_errors.append("Typography inventory must use full-expression schema 2.")
	var entries := inventory.get("entries", []) as Array
	if entries.size() < 150:
		_errors.append("Typography inventory is implausibly small: %d entries." % entries.size())
	var fingerprints := {}
	var indexed := {}
	var routed_to_atlas := 0
	var routed_to_legacy_migration := 0
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		var fingerprint := str(entry.get("fingerprint", ""))
		if fingerprint.length() != 16 or fingerprints.has(fingerprint):
			_errors.append("Inventory fingerprint is missing/duplicated: %s." % fingerprint)
		fingerprints[fingerprint] = true
		indexed["%s::%s" % [entry.get("path", ""), entry.get("function", "")]] = indexed.get("%s::%s" % [entry.get("path", ""), entry.get("function", "")], []) + [entry]
		if str(entry.get("mapping_source", "")) != "reviewed_manifest":
			_errors.append("%s is not backed by the explicit reviewed manifest." % fingerprint)
		var role := StringName(str(entry.get("role", "")))
		if not SemanticTypography.TOKENS.has(role):
			_errors.append("%s maps to unknown role %s." % [fingerprint, role])
		var status := str(entry.get("status", ""))
		if status != "mapped" and status != "allowlist":
			_errors.append("%s has invalid status %s." % [fingerprint, status])
		var mapping_mode := str(entry.get("mapping_mode", ""))
		if mapping_mode != "semantic_native" and mapping_mode != "legacy_compat":
			_errors.append("%s has invalid mapping_mode %s." % [fingerprint, mapping_mode])
		if mapping_mode == "legacy_compat":
			if str(entry.get("range_contract", "")).is_empty():
				_errors.append("Legacy mapping %s has no reviewed range contract." % fingerprint)
			if not entry.has("effective_min") or not entry.has("effective_max") or float(entry.get("effective_min", 1.0)) > float(entry.get("effective_max", 0.0)):
				_errors.append("Legacy mapping %s has no valid effective bounds." % fingerprint)
		if status == "allowlist":
			for required in ["owner", "reason", "next_issue"]:
				if str(entry.get(required, "")).is_empty():
					_errors.append("Allowlist %s misses %s." % [fingerprint, required])
			var next_issue := str(entry.get("next_issue", ""))
			if next_issue != "SCRUM-1068" and next_issue != "SCRUM-1073":
				_errors.append("Allowlist %s routes to unexpected issue %s." % [fingerprint, next_issue])
			var is_atlas_canvas := str(entry.get("path", "")) == "scripts/ui_screens.gd" and str(entry.get("function", "")) in ["_show_atlas_screen", "_atlas_build_canvas"]
			if next_issue == "SCRUM-1068":
				routed_to_atlas += 1
				if not is_atlas_canvas:
					_errors.append("Allowlist %s overloads Atlas-only SCRUM-1068." % fingerprint)
			elif next_issue == "SCRUM-1073":
				routed_to_legacy_migration += 1
				if is_atlas_canvas:
					_errors.append("Atlas allowlist %s escaped SCRUM-1068." % fingerprint)
			if not entry.has("effective_min") or not entry.has("effective_max"):
				_errors.append("Allowlist %s misses reviewed effective bounds." % fingerprint)
	var counts := inventory.get("counts", {}) as Dictionary
	if routed_to_atlas != int(counts.get("routed_scrum_1068", -1)) or routed_to_legacy_migration != int(counts.get("routed_scrum_1073", -1)):
		_errors.append("Allowlist routing counters disagree with entries: SCRUM-1068=%d SCRUM-1073=%d counts=%s." % [routed_to_atlas, routed_to_legacy_migration, str(counts)])
	if routed_to_atlas + routed_to_legacy_migration != int(counts.get("allowlist", -1)):
		_errors.append("Every allowlist site must route to exactly one truthful follow-up.")
	if int(counts.get("unreviewed", -1)) != 0 or int(counts.get("draw_string", 0)) < 2 or int(counts.get("semantic_binding", 0)) < 16 or not counts.has("resource_override"):
		_errors.append("Inventory completeness counts do not guard unreviewed/draw_string/resource sites: %s." % str(counts))
	_assert_inventory_site(indexed, "scripts/ui/hero_stat_radar.gd", "_draw", "caption", "ROLE_CAPTION", "draw_string")
	_assert_inventory_site(indexed, "scripts/threat_indicators.gd", "_draw_marker", "hud", "ROLE_HUD", "draw_string")
	_assert_inventory_site(indexed, "scripts/enemy.gd", "_show_combat_feedback", "hud", "30 if critical else 22", "theme_override")
	_assert_inventory_site(indexed, "scripts/ui_screens.gd", "_make_settings_game_tab", "title", "title.add_theme", "theme_override")
	_assert_inventory_site(indexed, "scripts/ui_screens.gd", "_make_settings_game_tab", "description", "description.add_theme", "theme_override")
	_assert_inventory_site(indexed, "scripts/ui_screens.gd", "_make_settings_game_tab", "value", "value_label.add_theme", "theme_override")
	_assert_inventory_site(indexed, "scripts/pause_stats_menu.gd", "_build_body", "section", "stats_title.add_theme", "theme_override")
	_assert_inventory_site(indexed, "scripts/ui_screens.gd", "_show_continue_run_dialog", "title", "title_label.add_theme", "theme_override")
	_assert_inventory_site(indexed, "scripts/ui_screens.gd", "_show_codex_screen", "title", "_codex_bind_stage_font(title_label", "semantic_binding")
	_assert_inventory_site(indexed, "scripts/ui_screens.gd", "_make_battle_prayer_card", "action", "ROLE_ACTION", "semantic_binding")
	_assert_inventory_range(indexed, "scripts/ui_screens.gd", "_make_settings_game_tab", "title.add_theme", "legacy_compat", 15, 21, "allowlist")
	_assert_inventory_range(indexed, "scripts/pause_stats_menu.gd", "_build_header", "_title_label.add_theme", "legacy_compat", 22, 26, "allowlist")
	_assert_inventory_range(indexed, "scripts/ui_screens.gd", "_hs4_apply_wide_control_style", "button.add_theme", "legacy_compat", 20, 38, "allowlist")
	_assert_inventory_range(indexed, "scripts/ui_screens.gd", "_layout_attribute_offer_card", "title.add_theme", "legacy_compat", 11, 22, "allowlist")
	_assert_inventory_range(indexed, "scripts/ui_screens.gd", "_make_battle_prayer_card", "ROLE_ACTION", "legacy_compat", 11, 11, "allowlist")
	_assert_inventory_range(indexed, "scripts/ui_screens.gd", "_show_continue_run_dialog", "subtitle_label.add_theme", "legacy_compat", 21, 23, "allowlist")
	_assert_inventory_range(indexed, "scripts/ui_icon_registry.gd", "<class>", "display_size.x >= 55.0", "legacy_compat", 16, 18, "mapped")
	var output := []
	var exit_code := OS.execute("python3", PackedStringArray(["tools/typography_inventory.py", "--check"]), output, true)
	if exit_code != 0:
		_errors.append("Inventory regeneration check failed: %s." % "\n".join(output))
	var matrix_source := FileAccess.get_file_as_string("res://tests/ui_no_overlap_matrix_test.gd")
	for resolution in ["1152, 648", "1280, 720", "1600, 900", "1920, 1080", "2560, 1440", "3840, 2160"]:
		if not matrix_source.contains("Vector2i(%s)" % resolution):
			_errors.append("UI no-overlap matrix lost required semantic tier %s." % resolution)


func _assert_inventory_site(indexed: Dictionary, path: String, function: String, role: String, source_fragment: String, kind: String) -> void:
	var key := "%s::%s" % [path, function]
	for raw_entry in indexed.get(key, []):
		var entry := raw_entry as Dictionary
		if str(entry.get("role", "")) == role and str(entry.get("kind", "")) == kind and str(entry.get("source", "")).contains(source_fragment):
			return
	_errors.append("Inventory misses reviewed %s %s::%s role=%s fragment=%s." % [kind, path, function, role, source_fragment])


func _assert_inventory_range(indexed: Dictionary, path: String, function: String, source_fragment: String, mode: String, min_px: int, max_px: int, status: String) -> void:
	var key := "%s::%s" % [path, function]
	for raw_entry in indexed.get(key, []):
		var entry := raw_entry as Dictionary
		if str(entry.get("source", "")).contains(source_fragment):
			if str(entry.get("mapping_mode", "")) != mode or str(entry.get("status", "")) != status or int(entry.get("effective_min", -1)) != min_px or int(entry.get("effective_max", -1)) != max_px:
				_errors.append("Inventory range %s::%s %s is not %s/%s %d..%d." % [path, function, source_fragment, status, mode, min_px, max_px])
			return
	_errors.append("Inventory range site missing: %s::%s %s." % [path, function, source_fragment])
