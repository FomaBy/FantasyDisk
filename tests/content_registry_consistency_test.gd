extends SceneTree

# SCRUM-200: гейт консистентности контента — канонические ID и ресурс-пути
# реестра/кода сверяются с фактическими ассетами (ResourceLoader.exists).
# Отдельный изолированный файл (анти-коллизия с занятыми тест/код-файлами).
# Динамические/осознанные расхождения — в ALLOWLIST с причиной.

const ProgressionData := preload("res://scripts/progression_data.gd")
const CodexData := preload("res://scripts/codex_data.gd")

const ARTIFACT_ICON_DIR := "res://assets/sprites/ui/icons/artifacts/"

# Осознанные исключения (placeholder/динамика) — путь -> причина. Пусто = строгий гейт.
const ALLOWLIST := {}


func _initialize() -> void:
	var missing: Array = []
	var id_errors: Array = []

	# Защита от вакуумного прохода: данные реестра не должны быть пустыми.
	var checked := 0
	checked += ProgressionData.character_ids().size()
	checked += CodexData.MONSTERS.size()
	checked += ProgressionData.ARTIFACTS.size()
	if ProgressionData.character_ids().size() < 9 or CodexData.MONSTERS.size() < 20 or ProgressionData.ARTIFACTS.size() < 40:
		push_error("Registry suspiciously small: %d chars, %d monsters, %d artifacts — gate would pass vacuously." % [
			ProgressionData.character_ids().size(), CodexData.MONSTERS.size(), ProgressionData.ARTIFACTS.size()])
		quit(1)
		return

	_check_character_assets(missing, id_errors)
	_check_weapon_assets(missing, id_errors)
	_check_codex_monster_assets(missing, id_errors)
	_check_artifact_icons(missing, id_errors)

	# Фильтруем осознанные исключения.
	var real_missing: Array = []
	for item in missing:
		if ALLOWLIST.has(str(item["path"])):
			continue
		real_missing.append(item)

	if not id_errors.is_empty():
		for err in id_errors:
			push_error("Registry ID error: %s" % err)
	if not real_missing.is_empty():
		for item in real_missing:
			push_error("Missing resource: %s (%s '%s')" % [item["path"], item["kind"], item["id"]])

	if not real_missing.is_empty() or not id_errors.is_empty():
		push_error("Content registry consistency: %d missing resources, %d id errors." % [real_missing.size(), id_errors.size()])
		quit(1)
		return
	print("Content registry consistency test passed (%d allowlisted)." % ALLOWLIST.size())
	quit(0)


func _exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


func _add_missing(arr: Array, kind: String, id: String, path: String) -> void:
	if not _exists(path):
		arr.append({"kind": kind, "id": id, "path": path})


func _check_character_assets(missing: Array, id_errors: Array) -> void:
	var seen := {}
	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		if cid == "" or seen.has(cid):
			id_errors.append("duplicate/empty character id '%s'" % cid)
			continue
		seen[cid] = true
		var config: Dictionary = ProgressionData.character_config(cid)
		_add_missing(missing, "character", cid, str(config.get("sprite_path", "")))


func _check_weapon_assets(missing: Array, id_errors: Array) -> void:
	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		var weapon_ids: Array = ProgressionData.weapon_ids(cid)
		if weapon_ids.is_empty():
			id_errors.append("character '%s' has no weapons" % cid)
			continue
		for weapon_id in weapon_ids:
			var wid := str(weapon_id)
			var weapon: Dictionary = ProgressionData.weapon(cid, wid)
			if weapon.is_empty():
				id_errors.append("weapon '%s/%s' missing definition" % [cid, wid])
				continue
			_add_missing(missing, "weapon", "%s/%s" % [cid, wid], str(weapon.get("scene_path", "")))


func _check_codex_monster_assets(missing: Array, id_errors: Array) -> void:
	var seen := {}
	for entry in CodexData.MONSTERS:
		var monster: Dictionary = entry
		var mid := str(monster.get("id", ""))
		if mid == "" or seen.has(mid):
			id_errors.append("duplicate/empty codex monster id '%s'" % mid)
			continue
		seen[mid] = true
		_add_missing(missing, "monster", mid, str(monster.get("sprite", "")))


func _check_artifact_icons(missing: Array, id_errors: Array) -> void:
	var seen := {}
	for entry in ProgressionData.ARTIFACTS:
		var artifact: Dictionary = entry
		var aid := str(artifact.get("id", ""))
		if aid == "" or seen.has(aid):
			id_errors.append("duplicate/empty artifact id '%s'" % aid)
			continue
		seen[aid] = true
		_add_missing(missing, "artifact", aid, "%sartifact_%s.png" % [ARTIFACT_ICON_DIR, aid])
