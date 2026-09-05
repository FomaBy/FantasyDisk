extends RefCounted
## EncounterSceneCache owns the resolved scenes for one canonical encounter
## plan. It deliberately has no global lifetime: EncounterAdapter clears it at
## the combat boundary so feature-specific scenes cannot leak into later runs.

const ENEMY_SCENE_ROOT := "res://scenes/"

var _prepared_plan: Dictionary = {}
var _scenes_by_path: Dictionary = {}
var _resolution_count := 0


func prepare(plan: Dictionary, resolver := Callable()) -> bool:
	if is_prepared_for(plan):
		return true
	clear()
	if not _is_valid_plan(plan):
		return false
	var resolved := {}
	for entry: Dictionary in plan["entries"]:
		var path := str(entry["scene"])
		var scene := _resolve(path, resolver)
		if scene == null:
			clear()
			return false
		resolved[path] = scene
	_prepared_plan = plan.duplicate(true)
	_scenes_by_path = resolved
	return true


func scene_for(plan: Dictionary, path: String) -> PackedScene:
	if not is_prepared_for(plan):
		return null
	return _scenes_by_path.get(path) as PackedScene


func is_prepared_for(plan: Dictionary) -> bool:
	return not _prepared_plan.is_empty() and plan == _prepared_plan


func resolution_count() -> int:
	return _resolution_count


func clear() -> void:
	_prepared_plan.clear()
	_scenes_by_path.clear()
	_resolution_count = 0


func _resolve(path: String, resolver: Callable) -> PackedScene:
	_resolution_count += 1
	if resolver.is_valid():
		return resolver.call(path) as PackedScene
	return ResourceLoader.load(path, "PackedScene") as PackedScene


func _is_valid_plan(plan: Dictionary) -> bool:
	var entries: Variant = plan.get("entries")
	if not (entries is Array) or entries.is_empty():
		return false
	var seen: Dictionary = {}
	var total_count: int = 0
	for entry: Variant in entries:
		if not (entry is Dictionary):
			return false
		var entry_data: Dictionary = entry as Dictionary
		var raw_path: Variant = entry_data.get("scene")
		var raw_count: Variant = entry_data.get("count")
		if not (raw_path is String) or not (raw_count is int):
			return false
		var path: String = raw_path
		var count: int = raw_count
		if not path.begins_with(ENEMY_SCENE_ROOT) or not path.ends_with(".tscn") \
				or seen.has(path) or count < 1 or not ResourceLoader.exists(path, "PackedScene"):
			return false
		seen[path] = true
		total_count += count
	return total_count == int(plan.get("total_count", -1))
