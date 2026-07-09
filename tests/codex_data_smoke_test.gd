extends SceneTree

# Smoke-тест codex_data.gd (был непокрыт). Валидирует 5 проекций кодекса
# (characters/monsters/artifacts/ascensions/stats): обязательные поля,
# уникальность id, целостность kind/abilities у монстров, согласованность
# персонажей с реестром и базовую player-facing адекватность текста.
# content_registry_consistency_test уже сверяет спрайт-ПУТИ — тут структура ДАННЫХ.
# Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/codex_data_smoke_test.gd

const CodexData := preload("res://scripts/codex_data.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

const VALID_MONSTER_KINDS := ["standard", "elite", "mini_elite", "boss"]
const SCRUM_956_ARTIFACT_TITLES := {
	"red_whetstone": "Точильный камень",
	"field_kit": "Полевой бинт",
	"magnetic_buckle": "Магнитный талисман",
	"fast_boots": "Легкие сапоги",
	"quickstring": "Быстрая струна",
	"hawk_lens": "Линза охоты",
}
const SCRUM_956_SHOP_TITLES := {
	"shop_weapon_cooldown": "Масло темпа",
	"shop_artifact": "Пыльный артефакт",
}


func _initialize() -> void:
	var errors: Array = []

	_check_monsters(errors)
	_check_characters(errors)
	_check_artifacts(errors)
	_check_ascensions(errors)
	_check_stats(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Codex data smoke: %s" % e)
		push_error("Codex data smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Codex data smoke test passed (%d монстров, %d персонажей, %d артефактов, %d вознесений, %d статов)." % [
		CodexData.monsters().size(), CodexData.characters().size(), CodexData.artifacts().size(),
		CodexData.ascensions().size(), CodexData.stats().size()])
	quit(0)


# Текст для игрока: непустой, не равен сырому id, без явных «null»/токенов.
func _player_text_ok(text: String, id: String) -> bool:
	if text.strip_edges() == "":
		return false
	if text == id:
		return false
	var low := text.to_lower()
	return not (low == "null" or low.begins_with("res://"))


func _check_monsters(errors: Array) -> void:
	var monsters := CodexData.monsters()
	if monsters.size() < 20:
		errors.append("monsters() подозрительно мал (%d) — гейт прошёл бы вакуумно" % monsters.size())
	var seen := {}
	var kind_counts := {"standard": 0, "elite": 0, "mini_elite": 0, "boss": 0}
	for entry in monsters:
		var monster: Dictionary = entry
		var mid := str(monster.get("id", ""))
		if mid == "" or seen.has(mid):
			errors.append("монстр с пустым/дублирующимся id '%s'" % mid)
			continue
		seen[mid] = true
		var kind := str(monster.get("kind", ""))
		if not VALID_MONSTER_KINDS.has(kind):
			errors.append("монстр '%s': недопустимый kind '%s'" % [mid, kind])
		else:
			kind_counts[kind] += 1
		if not _player_text_ok(str(monster.get("title", "")), mid):
			errors.append("монстр '%s': негодный title" % mid)
		var abilities: Array = monster.get("abilities", [])
		if abilities.is_empty():
			errors.append("монстр '%s': нет abilities" % mid)
		var ability_ids := {}
		for ability in abilities:
			var ab: Dictionary = ability
			var aid := str(ab.get("id", ""))
			if aid == "" or ability_ids.has(aid):
				errors.append("монстр '%s': пустая/дублирующаяся способность '%s'" % [mid, aid])
				continue
			ability_ids[aid] = true
			if not _player_text_ok(str(ab.get("title", "")), aid):
				errors.append("монстр '%s'/способность '%s': негодный title" % [mid, aid])
			if not _player_text_ok(str(ab.get("description", "")), aid):
				errors.append("монстр '%s'/способность '%s': негодное описание" % [mid, aid])
	for kind in VALID_MONSTER_KINDS:
		if kind_counts[kind] <= 0:
			errors.append("в кодексе нет монстров kind '%s' — неполный ростер" % kind)


func _check_characters(errors: Array) -> void:
	var characters := CodexData.characters()
	var registry_ids := ProgressionData.character_ids()
	if characters.size() != registry_ids.size():
		errors.append("characters() (%d) != character_ids реестра (%d)" % [characters.size(), registry_ids.size()])
	var seen := {}
	for entry in characters:
		var ch: Dictionary = entry
		var cid := str(ch.get("id", ""))
		if cid == "" or seen.has(cid):
			errors.append("персонаж с пустым/дублирующимся id '%s'" % cid)
			continue
		seen[cid] = true
		if not _player_text_ok(str(ch.get("title", "")), cid):
			errors.append("персонаж '%s': негодный title" % cid)
		if str(ch.get("sprite", "")) == "":
			errors.append("персонаж '%s': пустой sprite" % cid)
		var weapons: Array = ch.get("weapons", [])
		if weapons.is_empty():
			errors.append("персонаж '%s': нет weapons в проекции кодекса" % cid)
		for weapon in weapons:
			var w: Dictionary = weapon
			if str(w.get("id", "")) == "" or str(w.get("title", "")) == "":
				errors.append("персонаж '%s': оружие без id/title" % cid)


func _check_artifacts(errors: Array) -> void:
	var artifacts := CodexData.artifacts()
	if artifacts.size() < 40:
		errors.append("artifacts() подозрительно мал (%d)" % artifacts.size())
	var seen := {}
	var sources := {}
	var projected_titles := {}
	for entry in artifacts:
		var art: Dictionary = entry
		var aid := str(art.get("id", ""))
		if aid == "" or seen.has(aid):
			errors.append("артефакт с пустым/дублирующимся id '%s'" % aid)
			continue
		seen[aid] = true
		sources[str(art.get("source", ""))] = true
		var title := str(art.get("title", ""))
		projected_titles[aid] = title
		if not _player_text_ok(title, aid):
			errors.append("артефакт '%s': негодный title" % aid)
		# SCRUM-963: player-facing титулы локализованы — латиница в title запрещена
		# (id остаются латиницей, но игроку не показываются).
		if _has_latin(title):
			errors.append("артефакт '%s': латиница в title '%s'" % [aid, title])
		# SCRUM-963: у каждого финального артефакта — СВОЯ иконка artifact_<id>.png;
		# fallback-иконка (buff_power) допустима только как dev-страховка кода.
		if str(art.get("source", "")) == "artifact":
			var icon_path := "res://assets/sprites/ui/icons/artifacts/artifact_%s.png" % aid
			if not ResourceLoader.exists(icon_path):
				errors.append("артефакт '%s': нет уникальной иконки %s (fallback запрещён)" % [aid, icon_path])
	# Проекция объединяет ARTIFACTS (source=artifact) и SHOP_ITEMS (source=shop).
	for src in ["artifact", "shop"]:
		if not sources.has(src):
			errors.append("в artifacts() нет ни одной записи source '%s'" % src)
	for artifact_id in SCRUM_956_ARTIFACT_TITLES:
		var expected_title := str(SCRUM_956_ARTIFACT_TITLES[artifact_id])
		if str(projected_titles.get(artifact_id, "")) != expected_title:
			errors.append("SCRUM-956: '%s' должен называться '%s', получено '%s'" % [artifact_id, expected_title, str(projected_titles.get(artifact_id, "<нет>"))])
	for shop_id in SCRUM_956_SHOP_TITLES:
		var expected_shop_title := str(SCRUM_956_SHOP_TITLES[shop_id])
		if str(projected_titles.get(shop_id, "")) != expected_shop_title:
			errors.append("SCRUM-956: '%s' должен называться '%s', получено '%s'" % [shop_id, expected_shop_title, str(projected_titles.get(shop_id, "<нет>"))])
	if projected_titles.has("dusty_artifact"):
		errors.append("SCRUM-956: выдуманный id 'dusty_artifact' запрещён; Пыльный артефакт = shop_artifact")


func _has_latin(text: String) -> bool:
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			return true
	return false


func _check_ascensions(errors: Array) -> void:
	var ascensions := CodexData.ascensions()
	if ascensions.is_empty():
		errors.append("ascensions() пуст")
	for entry in ascensions:
		var asc: Dictionary = entry
		var aid := str(asc.get("id", ""))
		if aid == "":
			errors.append("вознесение с пустым id")
			continue
		if int(asc.get("level", -1)) < 0:
			errors.append("вознесение '%s': отрицательный/отсутствующий level" % aid)
		if not _player_text_ok(str(asc.get("title", "")), aid):
			errors.append("вознесение '%s': негодный title" % aid)


func _check_stats(errors: Array) -> void:
	var stats := CodexData.stats()
	if stats.is_empty():
		errors.append("stats() пуст")
	var seen := {}
	for entry in stats:
		var st: Dictionary = entry
		var sid := str(st.get("id", ""))
		if sid == "" or seen.has(sid):
			errors.append("стат с пустым/дублирующимся id '%s'" % sid)
			continue
		seen[sid] = true
		if not _player_text_ok(str(st.get("title", "")), sid):
			errors.append("стат '%s': негодный title" % sid)
		if str(st.get("type", "")) == "":
			errors.append("стат '%s': пустой type" % sid)
