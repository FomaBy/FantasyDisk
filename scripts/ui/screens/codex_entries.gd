extends "res://scripts/ui/screens/codex.gd"

# FAN-3824: модуль распределённого UI-класса — Кодекс: сборка списков записей по вкладкам.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _build_codex_characters(list: VBoxContainer) -> void:
	var characters: Array = CODEX_DATA.characters()
	for character in codex_unlock_presenter.unread_first(characters, Callable(codex_unlock_presenter, "character_unread_refs")):
		var unread_refs: Array = codex_unlock_presenter.character_unread_refs(character)
		var body_lines := [
			str(character["playstyle"]),
			"Сильное: %s" % character["strengths"],
			"Слабое: %s" % character["weaknesses"],
		]
		for weapon in character["weapons"]:
			body_lines.append("• %s — %s" % [weapon["title"], weapon["description"]])
			var ultimate: Dictionary = (weapon as Dictionary).get("ultimate", {})
			if not ultimate.is_empty():
				body_lines.append("   Ульта «%s» — %s" % [ultimate.get("title", ""), ultimate.get("description", "")])
		var texture: Texture2D = null
		if str(character["sprite"]) != "" and ResourceLoader.exists(str(character["sprite"])):
			texture = game._cached_texture(str(character["sprite"]))
		var row := _codex_entry_panel(list, {
			"codex_entry_id": str(character["id"]),
			"codex_entry_category": "characters",
			"title": str(character["title"]),
			"summary": str(character["playstyle"]),
			"texture": texture,
			"texture_path": str(character["sprite"]),
			"image_policy": CodexImageFit.POLICY_CHARACTER,
			"covered_portrait": true,
			"chips": ["Герой"],
			"body_lines": body_lines,
			"sections": _codex_character_sections(character),
		}, unread_refs)
		_codex_portrait(row, str(character["sprite"]), _codex_entry_portrait_size(), CodexImageFit.POLICY_CHARACTER)
		_codex_add_entry_name(row, str(character["title"]))




func _build_codex_monsters(list: VBoxContainer) -> void:
	var kind_titles := {"standard": "Обычные Монстры", "elite": "Элитные Монстры", "mini_elite": "Мини-элитки (свита Возвышения)", "boss": "Боссы"}
	var monsters := []
	for kind in ["standard", "elite", "mini_elite", "boss"]:
		for monster in CODEX_DATA.monsters():
			if str(monster["kind"]) == kind:
				monsters.append(monster)
	for monster in monsters:
		var kind := str(monster["kind"])
		var unread_refs: Array = codex_unlock_presenter.monster_unread_refs(monster)
		var body_lines := [str(monster["behavior"])]
		for ability in monster["abilities"]:
			body_lines.append("✦ %s — %s" % [ability["title"], ability["description"]])
		var texture: Texture2D = null
		if str(monster["sprite"]) != "" and ResourceLoader.exists(str(monster["sprite"])):
			texture = game._cached_texture(str(monster["sprite"]))
		var row := _codex_entry_panel(list, {
			"codex_entry_id": str(monster["id"]),
			"codex_entry_category": "bosses" if kind == "boss" else "monsters",
			"title": str(monster["title"]),
			"summary": str(monster["behavior"]),
			"texture": texture,
			"texture_path": str(monster["sprite"]),
			"image_policy": CodexImageFit.POLICY_MONSTER,
			"covered_portrait": false,
			"chips": [str(kind_titles[kind])],
			"body_lines": body_lines,
			"sections": _codex_monster_sections(monster),
		}, unread_refs)
		_codex_portrait(row, str(monster["sprite"]), _codex_entry_portrait_size(), CodexImageFit.POLICY_MONSTER)
		_codex_add_entry_name(row, str(monster["title"]))




func _build_codex_artifacts(list: VBoxContainer) -> void:
	var artifacts: Array = CODEX_DATA.artifacts()
	for artifact in artifacts:
		var unread_refs: Array = codex_unlock_presenter.artifact_unread_refs(artifact)
		var artifact_definition: Dictionary = game.PROGRESSION_DATA.artifact_definition(str(artifact["id"]))
		var locked := _codex_artifact_locked(artifact_definition)
		var tier_text := _artifact_tier_text(artifact_definition)
		var affinity_note := _artifact_affinity_note(artifact_definition)
		# Чипы: редкость + класс-владелец; сырой id игроку не показывается
		# (SCRUM-963), товары магазина помечены источником вместо редкости.
		var chips := []
		if str(artifact.get("source", "")) == "shop":
			chips.append("Магазин")
		else:
			chips.append(tier_text)
		if not affinity_note.is_empty():
			var class_names := PackedStringArray()
			for class_id in artifact_definition.get("class_affinity", []):
				class_names.append(str(CLASS_RU.get(str(class_id), class_id)))
			chips.append(", ".join(class_names))
		if locked:
			chips.append("Заперто")
		var body_lines := []
		var summary := str(artifact["description"])
		if locked:
			summary = _codex_artifact_unlock_condition(artifact_definition)
			body_lines.append(summary)
		else:
			body_lines.append(str(artifact["description"]))
			if not affinity_note.is_empty():
				body_lines.append(str(affinity_note["text"]))
		var icon_texture := _artifact_icon_texture(str(artifact["id"]))
		var icon_path := _artifact_icon_path(str(artifact["id"]))
		var row := _codex_entry_panel(list, {
			"codex_entry_id": str(artifact["id"]),
			"codex_entry_category": "artifacts",
			"title": str(artifact["title"]),
			"summary": summary,
			"texture": icon_texture,
			"texture_path": icon_path,
			"image_policy": CodexImageFit.POLICY_ARTIFACT,
			"texture_tint": CODEX_LOCKED_SILHOUETTE_TINT if locked else Color.WHITE,
			"covered_portrait": false,
			"chips": chips,
			"body_lines": body_lines,
			"sections": _codex_artifact_sections(artifact, artifact_definition, locked),
		}, unread_refs)
		_codex_icon_slot(row, icon_texture, _codex_entry_portrait_size(), "CodexArtifactIconSlot", CodexImageFit.POLICY_ARTIFACT, icon_path)
		if locked:
			# Запертая запись: силуэт иконки, дим ряда, вместо эффекта — условие.
			var slot_texture := row.get_node_or_null("CodexArtifactIconSlot/CodexArtifactIconSlotTexture") as TextureRect
			if slot_texture != null:
				slot_texture.self_modulate = CODEX_LOCKED_SILHOUETTE_TINT
			var entry_button := row.get_meta("entry_button", null) as Button
			if entry_button != null:
				entry_button.modulate = CODEX_LOCKED_ROW_TINT
		_codex_add_entry_name(row, str(artifact["title"]))




func _build_codex_ascensions(list: VBoxContainer) -> void:
	for entry in CODEX_DATA.ascensions():
		var ascension_texture: Texture2D = game._cached_texture(str(HUD_V2_ICON_PATHS["ascension"]))
		var row := _codex_entry_panel(list, {
			"title": "%d. %s" % [entry["level"], entry["title"]],
			"summary": str(entry["description"]),
			"texture": ascension_texture,
			"covered_portrait": false,
			"chips": ["Возвышение", "ур. %d" % entry["level"]],
			"body_lines": [str(entry["description"])],
			"sections": _codex_ascension_sections(entry),
		})
		_codex_icon_slot(row, ascension_texture, _codex_entry_portrait_size(), "CodexAscensionIconSlot")
		_codex_add_entry_name(row, "%d. %s" % [entry["level"], entry["title"]])




# FAN-1080: вкладка «Летопись» — реализация в scripts/ui/lore_screens.gd.
func _build_codex_chronicle(list: VBoxContainer) -> void:
	LoreScreens.build_chronicle(self, list)




func _build_codex_stats(list: VBoxContainer, stat_type: String) -> void:
	var type_titles := {"base": "Базовая характеристика", "derived": "Производный атрибут"}
	var related_titles := {"base": "Связанные атрибуты", "derived": "Связанные характеристики"}
	var entries: Array = CODEX_DATA.characteristics() if stat_type == "base" else CODEX_DATA.attributes()
	for stat in entries:
		var stat_id := str(stat["id"])
		# FAN-1927: канонические оси несут icon_id реестра (axis id != derived id).
		var icon_id := str(stat.get("icon_id", stat_id))
		var row := _codex_entry_panel(list, {
			"title": str(stat["title"]),
			"summary": str(stat["description"]),
			"texture": game.UIIconRegistry.texture_for(icon_id),
			"covered_portrait": false,
			"chips": [str(type_titles.get(stat_type, "Параметр"))],
			"related_title": str(related_titles.get(stat_type, "Связанные параметры")),
			"related": stat.get("related", []),
			"body_lines": [
				str(stat["description"]),
				"Влияет на: %s" % stat["influences"] if str(stat["influences"]) != "" else "",
			],
			"sections": _codex_stat_sections(stat),
		})
		_codex_icon_slot(row, game.UIIconRegistry.texture_for(icon_id), _codex_entry_portrait_size(), "CodexStatIconSlot")
		_codex_add_entry_name(row, str(stat["title"]))
