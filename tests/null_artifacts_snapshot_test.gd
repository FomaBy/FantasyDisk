extends SceneTree

# SCRUM-651: defensive guards for legacy/corrupt player snapshots where
# artifacts is present but null instead of an Array.

const CombatDirector := preload("res://scripts/combat_director.gd")
const MainScene := preload("res://scripts/main.gd")


class StubGame extends RefCounted:
	var run_player_snapshot := {}


class StubPlayer extends Node:
	var character_id := "berserk"
	var weapon_id := "axe"
	var health := 42.0
	var max_health := 100.0
	var stats := {}
	var run_modifiers := {}
	var artifacts = null
	var xp := 3
	var xp_to_next := 5
	var level := 2
	var money := 7


func _initialize() -> void:
	var errors: Array[String] = []
	_test_combat_snapshot_null_artifacts(errors)
	_test_run_metrics_null_artifacts(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Null artifacts snapshot: %s" % error)
		quit(1)
		return
	print("Null artifacts snapshot test passed.")
	quit(0)


func _test_combat_snapshot_null_artifacts(errors: Array[String]) -> void:
	var game := StubGame.new()
	var combat := CombatDirector.new(game)
	var player := StubPlayer.new()
	combat._store_player_snapshot(player)
	var artifacts = game.run_player_snapshot.get("artifacts")
	if not (artifacts is Array):
		errors.append("combat snapshot artifacts should be Array, got %s" % typeof(artifacts))
	elif not (artifacts as Array).is_empty():
		errors.append("combat snapshot null artifacts should become empty Array")
	player.free()


func _test_run_metrics_null_artifacts(errors: Array[String]) -> void:
	var main := MainScene.new()
	main.reset_run_metrics()
	main.capture_run_metrics_finals({"level": 2, "artifacts": null})
	var artifacts = main.run_metrics.get("artifacts")
	if not (artifacts is Array):
		errors.append("run metrics artifacts should be Array, got %s" % typeof(artifacts))
	elif not (artifacts as Array).is_empty():
		errors.append("run metrics null artifacts should become empty Array")
	main.free()
