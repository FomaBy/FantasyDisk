extends RefCounted
## Isolated captain-wave catalog. Registration is owned by FAN-1455.

const CONTRACT_VERSION := 1
const CATALOG_PATH := "res://data/encounters/features/captains/captains.json"

static var _cache: Dictionary = {}
static var _enabled_override_set := false
static var _enabled_override := false


static func catalog() -> Dictionary:
	if not _cache.is_empty():
		return _cache.duplicate(true)
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("CaptainCatalog: missing %s" % CATALOG_PATH)
		return _empty_catalog()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or int(parsed.get("schema_version", 0)) != CONTRACT_VERSION:
		push_error("CaptainCatalog: incompatible captain-wave catalog")
		return _empty_catalog()
	_cache = (parsed as Dictionary).duplicate(true)
	return _cache.duplicate(true)


static func _empty_catalog() -> Dictionary:
	return {"schema_version": CONTRACT_VERSION, "enabled": false, "roles": []}


static func is_enabled() -> bool:
	if _enabled_override_set:
		return _enabled_override
	return bool(catalog().get("enabled", false))


static func set_enabled_override(value: bool) -> void:
	_enabled_override_set = true
	_enabled_override = value


static func clear_enabled_override() -> void:
	_enabled_override_set = false
	_enabled_override = false


static func all_roles() -> Array:
	var roles: Array = []
	for entry in catalog().get("roles", []):
		if entry is Dictionary:
			roles.append((entry as Dictionary).duplicate(true))
	roles.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return roles


static func role(role_id: String) -> Dictionary:
	for entry in all_roles():
		if str(entry.get("id", "")) == role_id:
			return entry
	return {}


static func compatible_roles(active_tags: Array) -> Array:
	if not active_tags.has("normal_battle"):
		return []
	var active_decks: Array = active_tags.filter(func(tag): return str(tag).begins_with("deck:"))
	var result: Array = []
	for entry in all_roles():
		var blocked := false
		for tag in entry.get("incompatible_tags", []):
			if active_tags.has(tag):
				blocked = true
				break
		if blocked:
			continue
		var supported: Array = entry.get("compatibility_tags", [])
		if not supported.has("normal_battle"):
			continue
		if not active_decks.is_empty() and not active_decks.any(func(tag): return supported.has(tag)):
			continue
		result.append(entry)
	return result


static func _reset_for_tests() -> void:
	_cache = {}
	clear_enabled_override()
