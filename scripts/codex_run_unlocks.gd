extends RefCounted

# Ordered, run-local Codex journal. Persistence remains in CodexUnlockState.


static func record(metrics: Dictionary, category: String, content_id: String, title: String, icon_path := "", owner_character_id := "") -> Dictionary:
	var result := metrics.duplicate(true)
	var id := content_id.strip_edges()
	if id == "":
		return result
	var unlocks: Array = result.get("new_unlocks", [])
	for raw_unlock in unlocks:
		var unlock := raw_unlock as Dictionary
		if str(unlock.get("category", "")) == category and str(unlock.get("id", "")) == id:
			return result
	unlocks.append({
		"category": category,
		"id": id,
		"title": title.strip_edges() if title.strip_edges() != "" else id,
		"icon_path": icon_path.strip_edges(),
		"owner_character_id": owner_character_id.strip_edges(),
	})
	result["new_unlocks"] = unlocks
	return result
