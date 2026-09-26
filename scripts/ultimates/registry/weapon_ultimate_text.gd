class_name WeaponUltimateText
extends RefCounted

## Canonical localized truth for the 51 weapon ultimates.
##
## The catalog owns identity (`class_id`, `weapon_id`, `identity.*`); this table
## owns the player-facing title and mechanics line for exactly the same 51
## pairs. HUD, Codex and the pause dossier read it through
## `WeaponUltimateRegistry`, so the selected weapon ultimate — never the legacy
## class ultimate — is what every runtime surface shows. A missing, extra,
## empty or duplicated record is a validation error, never a silent fallback.

const TEXT_PATH := "res://data/ultimates/text/ru.json"
const EXPECTED_SCHEMA_VERSION := 1

static var _cache: Dictionary = {}
static var _cache_loaded := false


static func clear_cache_for_tests() -> void:
	_cache.clear()
	_cache_loaded = false


## key -> {"title": String, "description": String}. Empty when the table is
## missing or malformed; validate_records() reports why.
static func records() -> Dictionary:
	if not _cache_loaded:
		_cache = _read_records(TEXT_PATH)
		_cache_loaded = true
	return _cache.duplicate(true)


## Прямой доступ для потребителя, у которого уже есть выбранная пара и нет
## своего экземпляра реестра (досье паузы). Источник тот же самый файл.
static func text_for(class_id: String, weapon_id: String) -> Dictionary:
	var record = records().get("%s/%s" % [class_id, weapon_id])
	return record if record is Dictionary else {}


## Falsifies the table against the exact catalog pairs the registry resolved.
static func validate_records(profile_keys: Array, text_records: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if text_records.is_empty():
		errors.append("text.missing: %s" % TEXT_PATH)
		return errors
	var expected := {}
	for raw_key in profile_keys:
		expected[str(raw_key)] = true
	var titles := {}
	for raw_key in expected.keys():
		var key := str(raw_key)
		var record = text_records.get(key)
		if not record is Dictionary:
			errors.append("text.pair.missing: %s" % key)
			continue
		var entry := record as Dictionary
		for field in ["title", "description"]:
			if str(entry.get(field, "")).strip_edges().is_empty():
				errors.append("text.%s.empty: %s" % [field, key])
		var title := str(entry.get("title", ""))
		if titles.has(title):
			errors.append("text.title.duplicate: %s == %s" % [key, str(titles[title])])
		elif not title.is_empty():
			titles[title] = key
	for raw_key in text_records.keys():
		var key := str(raw_key)
		if not expected.has(key):
			errors.append("text.pair.extra: %s" % key)
	return errors


static func _read_records(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var document := parsed as Dictionary
	if int(document.get("schema_version", 0)) != EXPECTED_SCHEMA_VERSION:
		return {}
	var profiles = document.get("profiles")
	if not profiles is Dictionary:
		return {}
	var records_by_key := {}
	for raw_key in (profiles as Dictionary).keys():
		var entry = (profiles as Dictionary)[raw_key]
		if not entry is Dictionary:
			continue
		records_by_key[str(raw_key)] = {
			"title": str((entry as Dictionary).get("title", "")),
			"description": str((entry as Dictionary).get("description", "")),
		}
	return records_by_key
