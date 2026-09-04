extends SceneTree

## FAN-3919 fixed-fixture baseline: the pre-refactor spawn loop resolved every
## entry before checking its inner quota. Keep this executable count beside the
## replacement regression so the hot-path reduction remains comparable.

const CACHE := preload("res://scripts/encounters/encounter_scene_cache.gd")

var errors: Array[String] = []


class CountingResolver extends RefCounted:
	var calls: Array[String] = []

	func resolve(path: String) -> PackedScene:
		calls.append(path)
		return PackedScene.new()


func _initialize() -> void:
	var plan := _plan()
	var resolver := CountingResolver.new()
	_legacy_full_capacity_wave(plan, resolver)
	_expect(resolver.calls.size() == 2,
		"pre-refactor full-cap fixture must resolve each of its two entries")
	var cache := CACHE.new()
	_expect(cache.prepare(plan, Callable(resolver, "resolve")), "cold validated plan must prepare")
	_expect(resolver.calls.size() == 4 and cache.resolution_count() == 2,
		"cold preparation must resolve each canonical scene exactly once")
	_expect(cache.prepare(plan, Callable(resolver, "resolve")) and resolver.calls.size() == 4,
		"warm preparation must retain the bounded plan cache without a second resolution")
	_expect(cache.scene_for(plan, "res://scenes/Enemy.tscn") != null,
		"prepared plan must return its cached PackedScene")
	var changed_plan := plan.duplicate(true)
	changed_plan["node_seed"] = 4243
	_expect(cache.scene_for(changed_plan, "res://scenes/Enemy.tscn") == null,
		"plan identity changes must not borrow a previous encounter cache")
	var wrong_root := plan.duplicate(true)
	wrong_root["entries"][0]["scene"] = "res://scripts/enemy.gd"
	_expect(not cache.prepare(wrong_root, Callable(resolver, "resolve")) and resolver.calls.size() == 4,
		"wrong-root plans must fail before resolution")
	var missing_scene := plan.duplicate(true)
	missing_scene["entries"][0]["scene"] = "res://scenes/FAN3919Missing.tscn"
	_expect(not cache.prepare(missing_scene, Callable(resolver, "resolve")) and resolver.calls.size() == 4,
		"missing scenes must fail before resolution")
	cache.clear()
	_expect(cache.scene_for(plan, "res://scenes/Enemy.tscn") == null,
		"clearing the encounter boundary must release the cached plan")
	if not errors.is_empty():
		for error in errors:
			push_error("encounter-prewarm baseline: " + error)
		quit(1)
		return
	print("FAN-3919 operation count: baseline full-cap=2; cold plan=2; warm plan=0.")
	quit(0)


func _plan() -> Dictionary:
	return {
		"node_seed": 4242,
		"total_count": 4,
		"entries": [
			{"scene": "res://scenes/Enemy.tscn", "count": 3},
			{"scene": "res://scenes/EnemyShooter.tscn", "count": 1},
		],
	}


func _legacy_full_capacity_wave(plan: Dictionary, resolver: CountingResolver) -> void:
	var remaining := 0
	for entry: Dictionary in plan.get("entries", []):
		var scene := resolver.resolve(str(entry.get("scene", "")))
		for _index in range(mini(int(entry.get("count", 0)), remaining)):
			if scene == null:
				return


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
