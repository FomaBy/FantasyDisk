extends RefCounted

# Focused persistence/domain helper for Codex discovery and unread state.
# MetaProgression keeps the public compatibility surface and delegates here.

const CODEX_DATA := preload("res://scripts/codex_data.gd")
const DISCOVERY_CATEGORIES := {
	"characters": "discovered_characters",
	"monsters": "discovered_monsters",
	"bosses": "discovered_bosses",
	"artifacts": "discovered_artifacts",
	"weapons": "discovered_weapons",
}
const UNREAD_SAVE_KEY := "codex_unread"
const UNREAD_CATEGORIES := ["characters", "monsters", "bosses", "artifacts", "weapons"]


static func weapon_id(character_id: String, content_id: String) -> String:
	var owner := character_id.strip_edges()
	var weapon := content_id.strip_edges()
	if owner == "" or weapon == "":
		return ""
	return "%s/%s" % [owner, weapon]


static func canonical_ids(category: String) -> Dictionary:
	var ids := {}
	match category:
		"characters":
			for entry in CODEX_DATA.characters():
				ids[str(entry.get("id", ""))] = true
		"monsters", "bosses":
			var wants_boss := category == "bosses"
			for entry in CODEX_DATA.monsters():
				if (str(entry.get("kind", "")) == "boss") == wants_boss:
					ids[str(entry.get("id", ""))] = true
		"artifacts":
			for entry in CODEX_DATA.artifacts():
				ids[str(entry.get("id", ""))] = true
		"weapons":
			for entry in CODEX_DATA.characters():
				var character_id := str(entry.get("id", ""))
				for weapon in entry.get("weapons", []):
					ids[weapon_id(character_id, str((weapon as Dictionary).get("id", "")))] = true
	return ids


static func normalized_id_list(raw, category := "") -> Array:
	var result := []
	if not (raw is Array):
		return result
	var canonical := canonical_ids(category) if category != "" else {}
	for value in raw:
		var id := str(value).strip_edges()
		if id != "" and (category == "" or canonical.has(id)) and not result.has(id):
			result.append(id)
	return result


static func normalized_unread(raw) -> Dictionary:
	var normalized := {}
	if not (raw is Dictionary):
		return normalized
	for category in UNREAD_CATEGORIES:
		var values = raw.get(category, [])
		if not (values is Array):
			continue
		var canonical := canonical_ids(category)
		var ids := []
		for value in values:
			var id := str(value).strip_edges()
			if id != "" and canonical.has(id) and not ids.has(id):
				ids.append(id)
		if not ids.is_empty():
			normalized[category] = ids
	return normalized


static func discovered_ids(state: Dictionary, category: String) -> Array:
	var save_key := str(DISCOVERY_CATEGORIES.get(category, ""))
	return normalized_id_list(state.get(save_key, []), category) if save_key != "" else []


static func is_discovered(state: Dictionary, category: String, content_id: String) -> bool:
	return discovered_ids(state, category).has(content_id.strip_edges())


static func unread_ids(state: Dictionary, category: String) -> Array:
	if not UNREAD_CATEGORIES.has(category):
		return []
	var unread := normalized_unread(state.get(UNREAD_SAVE_KEY, {}))
	return (unread.get(category, []) as Array).duplicate()


static func is_unread(state: Dictionary, category: String, content_id: String) -> bool:
	return unread_ids(state, category).has(content_id.strip_edges())


static func has_unread(state: Dictionary, categories := []) -> bool:
	var requested: Array = categories if categories is Array and not (categories as Array).is_empty() else UNREAD_CATEGORIES
	for category in requested:
		if not unread_ids(state, str(category)).is_empty():
			return true
	return false


static func record_unread(state: Dictionary, category: String, content_id: String) -> Dictionary:
	var id := content_id.strip_edges()
	if not UNREAD_CATEGORIES.has(category) or not canonical_ids(category).has(id):
		return state
	var unread := normalized_unread(state.get(UNREAD_SAVE_KEY, {}))
	var ids: Array = (unread.get(category, []) as Array).duplicate()
	if not ids.has(id):
		ids.append(id)
		unread[category] = ids
	state[UNREAD_SAVE_KEY] = unread
	return state


static func mark_read(state: Dictionary, category: String, content_id: String) -> Dictionary:
	var unread := normalized_unread(state.get(UNREAD_SAVE_KEY, {}))
	var ids: Array = (unread.get(category, []) as Array).duplicate()
	var id := content_id.strip_edges()
	if not ids.has(id):
		return state
	ids.erase(id)
	if ids.is_empty():
		unread.erase(category)
	else:
		unread[category] = ids
	state[UNREAD_SAVE_KEY] = unread
	return state


static func record_discovery(state: Dictionary, category: String, content_id: String) -> Dictionary:
	var save_key := str(DISCOVERY_CATEGORIES.get(category, ""))
	var id := content_id.strip_edges()
	if save_key == "" or not canonical_ids(category).has(id):
		return state
	var ids := normalized_id_list(state.get(save_key, []), category)
	if ids.has(id):
		return state
	ids.append(id)
	state[save_key] = ids
	return record_unread(state, category, id)
