extends RefCounted

# Focused view/data presenter for FAN-1077 Codex unread badges and the victory
# unlock journal. The owning UIScreens module supplies its shared theme helpers.

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")
const BADGE_PATH := "res://assets/sprites/ui/icons/codex/ui_badge_codex_unread.png"

var game


func _init(game_ref) -> void:
	game = game_ref


func add_unread_badge(parent: Control, badge_name: String, badge_size: float, right_inset: float, top_inset := -1.0) -> TextureRect:
	var badge := TextureRect.new()
	badge.name = badge_name
	badge.texture = game._cached_texture(BADGE_PATH)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchor(SIDE_LEFT, 1.0)
	badge.set_anchor(SIDE_RIGHT, 1.0)
	if top_inset >= 0.0:
		badge.set_anchor(SIDE_TOP, 0.0)
		badge.set_anchor(SIDE_BOTTOM, 0.0)
		badge.offset_top = top_inset
		badge.offset_bottom = top_inset + badge_size
	else:
		badge.set_anchor(SIDE_TOP, 0.5)
		badge.set_anchor(SIDE_BOTTOM, 0.5)
		badge.offset_top = badge_size * -0.5
		badge.offset_bottom = badge_size * 0.5
	badge.offset_left = -right_inset - badge_size
	badge.offset_right = -right_inset
	badge.z_index = 20
	parent.add_child(badge)
	return badge


func section_has_unread(section_id: String) -> bool:
	match section_id:
		"characters":
			return game.META_PROGRESSION.has_codex_unread(game.meta_state, ["characters", "weapons"])
		"monsters":
			return game.META_PROGRESSION.has_codex_unread(game.meta_state, ["monsters", "bosses"])
		"artifacts":
			return game.META_PROGRESSION.has_codex_unread(game.meta_state, ["artifacts"])
	return false


func refresh_tab_badges(content: PanelContainer) -> void:
	if content == null or not is_instance_valid(content):
		return
	var tabs := content.get_meta("codex_tabs", null) as Control
	if tabs == null:
		return
	for section_id in ["characters", "monsters", "artifacts"]:
		var badge := tabs.get_node_or_null("CodexTab_%s/CodexTabUnreadBadge_%s" % [section_id, section_id]) as TextureRect
		if badge != null:
			badge.visible = section_has_unread(section_id)


func unread_first(entries: Array, unread_resolver: Callable) -> Array:
	var unread := []
	var read := []
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		(unread if not (unread_resolver.call(entry) as Array).is_empty() else read).append(entry)
	unread.append_array(read)
	return unread


func character_unread_refs(character: Dictionary) -> Array:
	var refs := []
	var character_id := str(character.get("id", ""))
	if game.META_PROGRESSION.is_codex_unread(game.meta_state, "characters", character_id):
		refs.append({"category": "characters", "id": character_id})
	for raw_weapon in character.get("weapons", []):
		var weapon := raw_weapon as Dictionary
		var weapon_id: String = game.META_PROGRESSION.codex_weapon_id(character_id, str(weapon.get("id", "")))
		if game.META_PROGRESSION.is_codex_unread(game.meta_state, "weapons", weapon_id):
			refs.append({"category": "weapons", "id": weapon_id})
	return refs


func monster_unread_refs(monster: Dictionary) -> Array:
	var category := "bosses" if str(monster.get("kind", "")) == "boss" else "monsters"
	var monster_id := str(monster.get("id", ""))
	return [{"category": category, "id": monster_id}] if game.META_PROGRESSION.is_codex_unread(game.meta_state, category, monster_id) else []


func artifact_unread_refs(artifact: Dictionary) -> Array:
	var artifact_id := str(artifact.get("id", ""))
	return [{"category": "artifacts", "id": artifact_id}] if game.META_PROGRESSION.is_codex_unread(game.meta_state, "artifacts", artifact_id) else []


func add_victory_unlocks(box: VBoxContainer, ui) -> void:
	var unlocks: Array = game.run_metrics.get("new_unlocks", []) as Array
	if unlocks.is_empty():
		return
	var ultra_compact: bool = game.get_viewport().get_visible_rect().size.y < 800.0
	var panel := PanelContainer.new()
	panel.name = "VictoryUnlockPanel"
	panel.custom_minimum_size.y = 86.0 if ultra_compact else 104.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", ui._atlas_chip_style(0.94, 8.0))
	box.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "VictoryUnlockColumn"
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var title := Label.new()
	title.name = "VictoryUnlockTitle"
	title.text = "НОВОЕ ОТКРЫТО"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_DESCRIPTION,
		ui._readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 10 if ultra_compact else 12, 10, 16),
		SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
	))
	title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.40, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "VictoryUnlockScroll"
	scroll.custom_minimum_size.y = 56.0 if ultra_compact else 68.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "VictoryUnlockList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var category_titles := {"artifacts": "Артефакт", "characters": "Герой", "weapons": "Оружие"}
	for unlock_index in range(unlocks.size()):
		var unlock := unlocks[unlock_index] as Dictionary
		var row := HBoxContainer.new()
		row.name = "VictoryUnlockRow_%d" % unlock_index
		row.set_meta("unlock_category", str(unlock.get("category", "")))
		row.set_meta("unlock_id", str(unlock.get("id", "")))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(row)
		var badge := TextureRect.new()
		badge.name = "VictoryUnlockBadge_%d" % unlock_index
		badge.texture = game._cached_texture(BADGE_PATH)
		badge.custom_minimum_size = Vector2(18, 18)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		var label := Label.new()
		label.name = "VictoryUnlockLabel_%d" % unlock_index
		label.text = "%s · %s" % [str(category_titles.get(str(unlock.get("category", "")), "Новое")), str(unlock.get("title", unlock.get("id", "")))]
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_DESCRIPTION,
			ui._readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 10 if ultra_compact else 11, 10, 15),
			SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
		))
		label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
