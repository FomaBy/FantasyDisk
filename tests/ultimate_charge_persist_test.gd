extends SceneTree

# SCRUM-872: накопленная шкала ульты переносится между узлами/раундами через
# run_player_snapshot (store -> restore), с clamp по ultimate_max_charge.
# Активация ульты (activate_ultimate) и run-reset по-прежнему обнуляют заряд —
# это поведение player.gd, здесь фиксируем только контракт снапшота.

const CombatDirector := preload("res://scripts/combat_director.gd")


class StubGame extends RefCounted:
	var run_player_snapshot := {}
	var selected_character_id := "berserk"
	var selected_weapon_id := ""


class StubPlayer extends Node:
	var character_id := "berserk"
	var weapon_id := ""
	var health := 42.0
	var max_health := 100.0
	var stats := {}
	var run_modifiers := {}
	var artifacts := []
	var xp := 3
	var xp_to_next := 5
	var level := 2
	var money := 7
	var ultimate_charge := 0.0
	var ultimate_max_charge := 100.0

	func configure_character(id: String, _weapon := "") -> void:
		character_id = id


func _initialize() -> void:
	var errors: Array[String] = []
	_test_store_includes_charge(errors)
	_test_restore_transfers_charge(errors)
	_test_full_charge_survives_multiple_battles(errors)
	_test_restore_clamps_to_max(errors)
	_test_restore_defaults_to_zero(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Ultimate charge persist: %s" % error)
		quit(1)
		return
	print("ultimate_charge_persist_test passed.")
	quit(0)


func _test_store_includes_charge(errors: Array[String]) -> void:
	var game := StubGame.new()
	var combat := CombatDirector.new(game)
	var player := StubPlayer.new()
	player.ultimate_charge = 63.5
	combat._store_player_snapshot(player)
	var stored := float(game.run_player_snapshot.get("ultimate_charge", -1.0))
	if not is_equal_approx(stored, 63.5):
		errors.append("store should persist ultimate_charge 63.5, got %f" % stored)
	player.free()


func _test_restore_transfers_charge(errors: Array[String]) -> void:
	var game := StubGame.new()
	var combat := CombatDirector.new(game)
	var donor := StubPlayer.new()
	donor.ultimate_charge = 63.5
	combat._store_player_snapshot(donor)
	donor.free()
	var fresh := StubPlayer.new()
	combat._restore_player_snapshot(fresh)
	if not is_equal_approx(fresh.ultimate_charge, 63.5):
		errors.append("restore should transfer charge 63.5 to fresh player, got %f" % fresh.ultimate_charge)
	fresh.free()


func _test_full_charge_survives_multiple_battles(errors: Array[String]) -> void:
	var game := StubGame.new()
	var combat := CombatDirector.new(game)
	var first_battle := StubPlayer.new()
	first_battle.ultimate_charge = first_battle.ultimate_max_charge
	combat._store_player_snapshot(first_battle)
	first_battle.free()

	var second_battle := StubPlayer.new()
	combat._restore_player_snapshot(second_battle)
	if not is_equal_approx(second_battle.ultimate_charge, second_battle.ultimate_max_charge):
		errors.append("second battle should retain 100%% charge, got %f" % second_battle.ultimate_charge)
	combat._store_player_snapshot(second_battle)
	second_battle.free()

	var third_battle := StubPlayer.new()
	combat._restore_player_snapshot(third_battle)
	if not is_equal_approx(third_battle.ultimate_charge, third_battle.ultimate_max_charge):
		errors.append("third battle should retain 100%% charge, got %f" % third_battle.ultimate_charge)
	third_battle.free()


func _test_restore_clamps_to_max(errors: Array[String]) -> void:
	var game := StubGame.new()
	var combat := CombatDirector.new(game)
	game.run_player_snapshot = {
		"character_id": "berserk", "weapon_id": "",
		"health": 42.0, "max_health": 100.0,
		"stats": {}, "run_modifiers": {}, "artifacts": [],
		"xp": 0, "xp_to_next": 5, "level": 1, "money": 0,
		"ultimate_charge": 150.0,
	}
	var player := StubPlayer.new()
	combat._restore_player_snapshot(player)
	if not is_equal_approx(player.ultimate_charge, player.ultimate_max_charge):
		errors.append("restore should clamp 150 to max %f, got %f" % [player.ultimate_max_charge, player.ultimate_charge])
	player.free()


func _test_restore_defaults_to_zero(errors: Array[String]) -> void:
	var game := StubGame.new()
	var combat := CombatDirector.new(game)
	game.run_player_snapshot = {
		"character_id": "berserk", "weapon_id": "",
		"health": 42.0, "max_health": 100.0,
		"stats": {}, "run_modifiers": {}, "artifacts": [],
		"xp": 0, "xp_to_next": 5, "level": 1, "money": 0,
	}
	var player := StubPlayer.new()
	player.ultimate_charge = 33.0
	combat._restore_player_snapshot(player)
	if not is_zero_approx(player.ultimate_charge):
		errors.append("restore without snapshot key should default to 0, got %f" % player.ultimate_charge)
	player.free()
