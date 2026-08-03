extends SceneTree

# Smoke-тест codex_data.gd. Валидирует 6 player-facing проекций кодекса
# (characters/monsters/artifacts/ascensions/characteristics/attributes): поля,
# уникальность id, целостность kind/abilities у монстров, согласованность
# персонажей с реестром и базовую player-facing адекватность текста.
# content_registry_consistency_test уже сверяет спрайт-ПУТИ — тут структура ДАННЫХ.
# Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/codex_data_smoke_test.gd

const CodexData := preload("res://scripts/codex_data.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")

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
const SCRUM_1021_EXPECTED_DEPENDENCIES := {
	"damage": ["strength"],
	"magic_damage": ["intelligence"],
	"crit_chance": ["agility"],
	"crit_damage_multiplier": ["agility"],
	"attack_speed": ["agility", "perception", "energy", "endurance"],
	"dodge": ["agility"],
	"move_speed": ["agility"],
	"defense": ["endurance"],
	"absorb": ["endurance"],
	"health_point": ["endurance"],
	"summon_amount": ["intelligence", "energy", "knowledge", "leadership"],
	"regeneration": ["knowledge"],
	"vampiric_amount": [],
	"vampiric_chance": [],
	"dot_damage": ["knowledge"],
	"dot_speed": ["agility", "energy", "knowledge"],
	"aoe_radius": ["intelligence", "perception", "knowledge", "leadership"],
	"knockback_power": ["strength"],
	"ultimate_multiplier": ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"],
	"pickup_radius": ["perception"],
}


func _initialize() -> void:
	var errors: Array = []

	_check_monsters(errors)
	_check_characters(errors)
	_check_artifacts(errors)
	_check_ascensions(errors)
	_check_stat_split(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Codex data smoke: %s" % e)
		push_error("Codex data smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Codex data smoke test passed (%d монстров, %d персонажей, %d артефактов, %d возвышений, %d характеристик, %d атрибутов)." % [
		CodexData.monsters().size(), CodexData.characters().size(), CodexData.artifacts().size(),
		CodexData.ascensions().size(), CodexData.characteristics().size(), CodexData.attributes().size()])
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


func _projection_ids(entries: Array) -> Array:
	var result := []
	for entry in entries:
		result.append(str((entry as Dictionary).get("id", "")))
	return result


func _related_ids(entry: Dictionary) -> Array:
	var result := []
	for related_entry in entry.get("related", []):
		result.append(str((related_entry as Dictionary).get("id", "")))
	return result


func _check_stat_projection(entries: Array, expected_ids: Array, expected_type: String, other_ids: Array, errors: Array) -> void:
	var ids := _projection_ids(entries)
	if ids != expected_ids:
		errors.append("%s projection ids/order %s != canonical %s" % [expected_type, str(ids), str(expected_ids)])
	var seen := {}
	for entry in entries:
		var st: Dictionary = entry
		var sid := str(st.get("id", ""))
		if sid == "" or seen.has(sid):
			errors.append("%s: пустой/дублирующийся id '%s'" % [expected_type, sid])
			continue
		seen[sid] = true
		if other_ids.has(sid):
			errors.append("%s: запись '%s' попала в обе секции" % [expected_type, sid])
		if str(st.get("type", "")) != expected_type:
			errors.append("%s: '%s' имеет type '%s'" % [expected_type, sid, str(st.get("type", ""))])
		var title := str(st.get("title", ""))
		var description := str(st.get("description", ""))
		if not _player_text_ok(title, sid) or _has_latin(title):
			errors.append("%s: '%s' имеет не русское player-facing имя '%s'" % [expected_type, sid, title])
		if not _player_text_ok(description, sid) or _has_latin(description):
			errors.append("%s: '%s' имеет не русское player-facing описание '%s'" % [expected_type, sid, description])
		var influences := str(st.get("influences", ""))
		if influences == "" or _has_latin(influences):
			errors.append("%s: '%s' имеет пустое/не русское влияние '%s'" % [expected_type, sid, influences])
		var formula := str(st.get("formula", ""))
		if formula == "" or _has_latin(formula):
			errors.append("%s: '%s' имеет пустую/не русскую player-facing формулу '%s'" % [expected_type, sid, formula])
		for related_entry in st.get("related", []):
			var related: Dictionary = related_entry
			var related_id := str(related.get("id", ""))
			if not other_ids.has(related_id):
				errors.append("%s: '%s' ссылается на некорректную связанную запись '%s'" % [expected_type, sid, related_id])
			if not _player_text_ok(str(related.get("title", "")), related_id) or _has_latin(str(related.get("title", ""))):
				errors.append("%s: '%s' показывает негодный related title для '%s'" % [expected_type, sid, related_id])


# FAN-1927: ручная (независимая от AttributeContract) карта «ось реестра →
# runtime-параметры»; ожидаемые базовые зависимости оси = объединение строк
# audited-матрицы SCRUM-1021 её параметров в порядке BASE_STAT_ORDER.
const FAN1927_AXIS_PARAMETERS := {
	"damage_flat": ["damage", "magic_damage"],
	"damage": ["damage", "magic_damage"],
	"max_health": ["health_point"],
	"crit_damage": ["crit_damage_multiplier"],
	"vampiric": ["vampiric_amount"],
	"ultimate_power": ["ultimate_multiplier"],
}


func _axis_expected_dependencies(axis_id: String) -> Array:
	var parameters: Array = FAN1927_AXIS_PARAMETERS.get(axis_id, [axis_id])
	var dependency_set := {}
	for parameter_value in parameters:
		for base_id_value in SCRUM_1021_EXPECTED_DEPENDENCIES.get(str(parameter_value), []):
			dependency_set[str(base_id_value)] = true
	var expected := []
	for base_id_value in StatFormulas.BASE_STAT_ORDER:
		if dependency_set.has(str(base_id_value)):
			expected.append(str(base_id_value))
	return expected


func _check_stat_split(errors: Array) -> void:
	var characteristics := CodexData.characteristics()
	var attributes := CodexData.attributes()
	var base_ids: Array = Array(StatFormulas.BASE_STAT_ORDER)
	var derived_ids: Array = Array(StatFormulas.DERIVED_STAT_ORDER)
	# FAN-1887/FAN-1927: единственный oracle player-facing осей — реестр
	# ProgressionData.ATTRIBUTE_REGISTRY (id/порядок/названия); derived-алиасы
	# ("Урон"/"Магический урон" как отдельные записи) запрещены.
	var registry_ids: Array = []
	var registry_names := {}
	for entry_value in ProgressionData.ATTRIBUTE_REGISTRY:
		var registry_entry := entry_value as Dictionary
		registry_ids.append(str(registry_entry.get("id", "")))
		registry_names[str(registry_entry.get("id", ""))] = str(registry_entry.get("name", ""))
	if characteristics.is_empty():
		errors.append("characteristics() пуст")
	if attributes.is_empty():
		errors.append("attributes() пуст")
	_check_stat_projection(characteristics, base_ids, "base", registry_ids, errors)
	_check_stat_projection(attributes, registry_ids, "derived", base_ids, errors)
	if registry_ids.size() != 16:
		errors.append("FAN-1887: player-facing атрибутов %d != 16" % registry_ids.size())
	for removed_id in ["attack_range", "range_multiplier", "projectile_speed", "dot_speed", "aura_radius", "buff_power", "absorb", "knockback_power", "knockback_distance", "vampiric_chance", "magic_damage", "health_point", "crit_damage_multiplier", "vampiric_amount", "ultimate_multiplier"]:
		if registry_ids.has(removed_id):
			errors.append("FAN-1887/FAN-1927: derived-алиас/внутренний параметр '%s' попал в player-facing атрибуты кодекса" % removed_id)
	# FAN-1927: канонические названия реестра на записях кодекса; alias-титулы
	# «Урон»/«Магический урон» не существуют как самостоятельные оси.
	var attribute_titles := {}
	for attribute in attributes:
		attribute_titles[str((attribute as Dictionary).get("title", ""))] = true
		var axis_id := str((attribute as Dictionary).get("id", ""))
		if str((attribute as Dictionary).get("title", "")) != str(registry_names.get(axis_id, "")):
			errors.append("FAN-1927: титул кодекса '%s' != каноническому имени реестра '%s'" % [(attribute as Dictionary).get("title", ""), registry_names.get(axis_id, "")])
	for forbidden_title in ["Урон", "Магический урон"]:
		if attribute_titles.has(forbidden_title):
			errors.append("FAN-1927: alias-титул '%s' остался самостоятельной осью кодекса" % forbidden_title)
	for required_title in ["Добавление урона", "Увеличение урона"]:
		if not attribute_titles.has(required_title):
			errors.append("FAN-1927: каноническая ось '%s' отсутствует в кодексе" % required_title)
	# SCRUM-1021: assert the full runtime dependency matrix, not merely that
	# related ids have the opposite type. This catches generic prose omissions
	# (ultimate_multiplier must expose all eight) and lexical false positives.
	if SCRUM_1021_EXPECTED_DEPENDENCIES.size() != derived_ids.size():
		errors.append("SCRUM-1021 expected matrix has %d rows, canonical derived order has %d" % [SCRUM_1021_EXPECTED_DEPENDENCIES.size(), derived_ids.size()])
	for derived_id_value in derived_ids:
		var derived_id := str(derived_id_value)
		var expected_row: Array = SCRUM_1021_EXPECTED_DEPENDENCIES.get(derived_id, [])
		var canonical_dependencies: Array = StatFormulas.DERIVED_BASE_DEPENDENCIES.get(derived_id, [])
		if canonical_dependencies != expected_row:
			errors.append("SCRUM-1021 canonical matrix '%s' %s != audited runtime matrix %s" % [derived_id, str(canonical_dependencies), str(expected_row)])
	for attribute in attributes:
		var attribute_dict := attribute as Dictionary
		var attribute_id := str(attribute_dict.get("id", ""))
		var expected_dependencies := _axis_expected_dependencies(attribute_id)
		var actual_dependencies := _related_ids(attribute_dict)
		if actual_dependencies != expected_dependencies:
			errors.append("SCRUM-1021/FAN-1927 ось '%s' related %s != exact runtime matrix %s" % [attribute_id, str(actual_dependencies), str(expected_dependencies)])
	for characteristic in characteristics:
		var characteristic_dict := characteristic as Dictionary
		var characteristic_id := str(characteristic_dict.get("id", ""))
		var expected_attributes := []
		for axis_id_value in registry_ids:
			var axis_id := str(axis_id_value)
			if _axis_expected_dependencies(axis_id).has(characteristic_id):
				expected_attributes.append(axis_id)
		var actual_attributes := _related_ids(characteristic_dict)
		if actual_attributes != expected_attributes:
			errors.append("SCRUM-1021/FAN-1927 base '%s' inverse related %s != %s" % [characteristic_id, str(actual_attributes), str(expected_attributes)])
	for characteristic in characteristics:
		if (characteristic as Dictionary).get("related", []).is_empty():
			errors.append("base: '%s' не имеет ни одного связанного атрибута из канонических формул" % str((characteristic as Dictionary).get("id", "")))
	var expected_compat := characteristics + attributes
	if CodexData.stats() != expected_compat:
		errors.append("stats() compatibility projection не равен characteristics + attributes")
