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
	var expected_resolver_calls := resolver.calls.size()
	var wrong_root := plan.duplicate(true)
	wrong_root["entries"][0]["scene"] = "res://scripts/enemy.gd"
	_expect_rejected_without_resolution(cache, resolver, wrong_root, expected_resolver_calls,
		"wrong-root plans")
	var missing_scene := plan.duplicate(true)
	missing_scene["entries"][0]["scene"] = "res://scenes/FAN3919Missing.tscn"
	_expect_rejected_without_resolution(cache, resolver, missing_scene, expected_resolver_calls,
		"missing scenes")
	var malformed_entries_values: Array = ["not-an-array", {"scene": "res://scenes/Enemy.tscn"}, null, 7]
	for malformed_entries: Variant in malformed_entries_values:
		var malformed_plan := plan.duplicate(true)
		malformed_plan["entries"] = malformed_entries
		_expect_rejected_without_resolution(cache, resolver, malformed_plan, expected_resolver_calls,
			"non-Array entries")
	var non_dictionary_entry := plan.duplicate(true)
	non_dictionary_entry["entries"] = ["not-a-dictionary"]
	_expect_rejected_without_resolution(cache, resolver, non_dictionary_entry, expected_resolver_calls,
		"non-Dictionary entries")
	var non_string_scene := plan.duplicate(true)
	non_string_scene["entries"][0]["scene"] = 7
	_expect_rejected_without_resolution(cache, resolver, non_string_scene, expected_resolver_calls,
		"non-String scene paths")
	var non_integer_count := plan.duplicate(true)
	non_integer_count["entries"][0]["count"] = "three"
	_expect_rejected_without_resolution(cache, resolver, non_integer_count, expected_resolver_calls,
		"non-integer entry counts")
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


func _expect_rejected_without_resolution(cache, resolver: CountingResolver, plan: Dictionary,
		expected_resolver_calls: int, label: String) -> void:
	_expect(not cache.prepare(plan, Callable(resolver, "resolve")), label + " must fail before resolution")
	_expect(resolver.calls.size() == expected_resolver_calls and cache.resolution_count() == 0,
		label + " must make zero resolver calls")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
