extends "res://tests/support/runtime_smoke_helpers.gd"

# FAN-4003: XP/gold still on the ground when a fight is won are banked through
# the ordinary pickup path (multipliers once per drop, gold counter, queued
# level-ups) before the snapshot; a lost fight grants none of them. Spawn-time
# merging keeps live pickup nodes under the per-type cap without changing the
# total reward compared with unmerged drops.

const COMBAT_PICKUPS_PATH := "res://scripts/combat_pickups.gd"
const ProgressionDataScript := preload("res://scripts/progression_data.gd")
const XP_MULT := 1.55
const MONEY_MULT := 1.62
const FAR := Vector2(1900.0, 0.0)


func _initialize() -> void:
	await _test_victory_banks_ground_pickups()
	await _test_defeat_grants_no_ground_pickups()
	await _test_merge_cap_preserves_total_reward()
	_finish("[combat_pickup_victory_collection] PASSED")


func _start_fight() -> Node:
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	# gain_money credits gold_collected on the current scene, as in the game.
	current_scene = main
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_start_combat", false, "battle")
	await process_frame
	var player = main.get("current_player")
	if player == null:
		_fail("FAN-4003: combat did not spawn a player.")
		return main
	var mods := player.get("run_modifiers") as Dictionary
	mods["xp_gain_multiplier"] = XP_MULT
	mods["money_gain_multiplier"] = MONEY_MULT
	# Freeze the timer path: the test ends the fight explicitly.
	main.set("round_time_left", 9999.0)
	return main


func _gain(amount: int, multiplier: float) -> int:
	return maxi(1, int(round(float(amount) * multiplier)))


# The fixed drop set: some far from the player (merging nearby), one inside
# pickup radius that _update_pickups collects in the same frame as the victory.
func _drop_set(player_pos: Vector2) -> Array:
	var drops: Array = []
	for index in range(24):
		drops.append(["xp", 1 + index % 3, player_pos + FAR + Vector2(float(index % 4) * 8.0, float(index / 4) * 70.0)])
	for index in range(9):
		drops.append(["money", 2 + index % 2, player_pos - FAR + Vector2(float(index) * 12.0, 0.0)])
	drops.append(["xp", 2, player_pos])
	drops.append(["money", 3, player_pos])
	return drops


func _apply_xp(state: Dictionary, gained: int) -> void:
	state["xp"] = int(state["xp"]) + gained
	while int(state["xp"]) >= int(state["xp_to_next"]):
		state["xp"] = int(state["xp"]) - int(state["xp_to_next"])
		state["level"] = int(state["level"]) + 1
		state["xp_to_next"] = ProgressionDataScript.next_xp_requirement(int(state["xp_to_next"]))


func _test_victory_banks_ground_pickups() -> void:
	# Control: same fight, no drops — isolates the node completion reward.
	var control := await _start_fight()
	if _failure_reported:
		control.queue_free()
		return
	var control_metrics_before := int((control.get("run_metrics") as Dictionary).get("gold_collected", 0))
	var control_pending_before := int(control.get("pending_level_ups"))
	control.get("combat").call("_end_combat", true)
	var control_snapshot := (control.get("run_player_snapshot") as Dictionary).duplicate(true)
	var control_gold_delta := int((control.get("run_metrics") as Dictionary).get("gold_collected", 0)) - control_metrics_before
	var control_pending_delta := int(control.get("pending_level_ups")) - control_pending_before
	control.queue_free()
	await process_frame

	var main := await _start_fight()
	if _failure_reported:
		main.queue_free()
		return
	var player = main.get("current_player")
	var metrics_before := int((main.get("run_metrics") as Dictionary).get("gold_collected", 0))
	var pending_before := int(main.get("pending_level_ups"))
	var expected_money := 0
	var expected_xp_gains: Array = []
	for drop in _drop_set(player.global_position):
		main.call("_spawn_pickup", drop[0], drop[1], drop[2])
		if drop[0] == "money":
			expected_money += _gain(int(drop[1]), MONEY_MULT)
		else:
			expected_xp_gains.append(_gain(int(drop[1]), XP_MULT))
	# Same frame as the victory: the in-radius pickups are collected first and
	# must not be paid a second time by the victory sweep.
	main.get("combat").call("_update_pickups", 0.0)
	main.get("combat").call("_end_combat", true)
	var snapshot := main.get("run_player_snapshot") as Dictionary
	var gold_delta := int((main.get("run_metrics") as Dictionary).get("gold_collected", 0)) - metrics_before
	var pending_delta := int(main.get("pending_level_ups")) - pending_before

	if int(snapshot.get("money", 0)) != int(control_snapshot.get("money", 0)) + expected_money:
		_fail("FAN-4003: victory snapshot money %d != control %d + ground %d." % [int(snapshot.get("money", 0)), int(control_snapshot.get("money", 0)), expected_money])
	if gold_delta != control_gold_delta + expected_money:
		_fail("FAN-4003: gold_collected delta %d != control %d + ground %d." % [gold_delta, control_gold_delta, expected_money])
	var expected := {"xp": int(control_snapshot.get("xp", 0)), "xp_to_next": int(control_snapshot.get("xp_to_next", 0)), "level": int(control_snapshot.get("level", 0))}
	for gained in expected_xp_gains:
		_apply_xp(expected, int(gained))
	if int(snapshot.get("level", 0)) != int(expected["level"]) or int(snapshot.get("xp", 0)) != int(expected["xp"]):
		_fail("FAN-4003: victory snapshot level/xp %d/%d != expected %d/%d." % [int(snapshot.get("level", 0)), int(snapshot.get("xp", 0)), int(expected["level"]), int(expected["xp"])])
	var expected_new_levels := int(expected["level"]) - int(control_snapshot.get("level", 0))
	if expected_new_levels <= 0:
		_fail("FAN-4003: fixture must cause at least one end-of-fight level-up.")
	if pending_delta != control_pending_delta + expected_new_levels:
		_fail("FAN-4003: pending level-ups delta %d != control %d + %d." % [pending_delta, control_pending_delta, expected_new_levels])
	if not bool(main.get("level_up_return_to_map")):
		_fail("FAN-4003: end-of-fight level-ups must be offered on the next screen (level_up_return_to_map).")
	for pickup in main.get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
			_fail("FAN-4003: a ground pickup survived the won fight.")
			break
	main.queue_free()
	await process_frame


func _test_defeat_grants_no_ground_pickups() -> void:
	var main := await _start_fight()
	if _failure_reported:
		main.queue_free()
		return
	var player = main.get("current_player")
	var money_before := int(player.get("money"))
	var xp_before := int(player.get("xp"))
	var level_before := int(player.get("level"))
	var gold_before := int((main.get("run_metrics") as Dictionary).get("gold_collected", 0))
	for drop in _drop_set(player.global_position):
		if (drop[2] as Vector2).distance_to(player.global_position) > 1.0:
			main.call("_spawn_pickup", drop[0], drop[1], drop[2])
	main.get("combat").call("_end_combat", false)
	var snapshot := main.get("run_player_snapshot") as Dictionary
	if int(snapshot.get("money", -1)) != money_before or int(snapshot.get("xp", -1)) != xp_before or int(snapshot.get("level", -1)) != level_before:
		_fail("FAN-4003: defeat must not grant ground pickups (money %d->%d, xp %d->%d, level %d->%d)." % [money_before, int(snapshot.get("money", -1)), xp_before, int(snapshot.get("xp", -1)), level_before, int(snapshot.get("level", -1))])
	if int((main.get("run_metrics") as Dictionary).get("gold_collected", 0)) != gold_before:
		_fail("FAN-4003: defeat must not add ground gold to gold_collected.")
	main.queue_free()
	await process_frame


func _test_merge_cap_preserves_total_reward() -> void:
	var main := await _start_fight()
	if _failure_reported:
		main.queue_free()
		return
	var player = main.get("current_player")
	# Keep the hero out of reach of every drop in this fixed dense scenario.
	player.global_position = Vector2(80.0, 80.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4003
	var raw_xp := 0
	var raw_money := 0
	var expected_money := 0
	var drop_count := {"xp": 0, "money": 0}
	for index in range(1500):
		var position := Vector2(rng.randf_range(600.0, 4000.0), rng.randf_range(400.0, 2200.0))
		var xp_amount := 1 + rng.randi_range(0, 4)
		main.call("_spawn_pickup", "xp", xp_amount, position + Vector2(-10.0, 0.0))
		raw_xp += xp_amount
		drop_count["xp"] += 1
		if index % 4 != 0:
			var money_amount := 1 + rng.randi_range(0, 3)
			main.call("_spawn_pickup", "money", money_amount, position + Vector2(10.0, 0.0))
			raw_money += money_amount
			expected_money += _gain(money_amount, MONEY_MULT)
			drop_count["money"] += 1
	var nodes := {"xp": 0, "money": 0}
	var carried := {"xp": 0, "money": 0}
	var carried_drops := {"xp": 0, "money": 0}
	for pickup in main.get_tree().get_nodes_in_group("pickups"):
		var kind := str(pickup.get("pickup_type"))
		nodes[kind] += 1
		carried[kind] += int(pickup.get("amount"))
		for drop_amount in (pickup.call("drop_counts") as Dictionary).keys():
			carried_drops[kind] += int(pickup.call("drop_counts")[drop_amount])
	var cap := int((load(COMBAT_PICKUPS_PATH) as Script).get_script_constant_map().get("PICKUP_LIVE_CAP_PER_TYPE", 0))
	print("[combat_pickup_victory_collection] dense scenario: drops xp=%d money=%d -> live nodes xp=%d money=%d (cap %d per type)" % [drop_count["xp"], drop_count["money"], nodes["xp"], nodes["money"], cap])
	if nodes["xp"] > cap or nodes["money"] > cap:
		_fail("FAN-4003: live pickup nodes xp=%d money=%d exceed cap %d." % [nodes["xp"], nodes["money"], cap])
	if carried["xp"] != raw_xp or carried["money"] != raw_money:
		_fail("FAN-4003: merged raw totals changed (xp %d/%d, money %d/%d)." % [carried["xp"], raw_xp, carried["money"], raw_money])
	if carried_drops["xp"] != drop_count["xp"] or carried_drops["money"] != drop_count["money"]:
		_fail("FAN-4003: merged nodes lost drops (xp %d/%d, money %d/%d)." % [carried_drops["xp"], drop_count["xp"], carried_drops["money"], drop_count["money"]])
	var money_before := int(player.get("money"))
	main.get("combat").call("_collect_all_ground_pickups")
	if int(player.get("money")) - money_before != expected_money:
		_fail("FAN-4003: merged money paid %d != unmerged per-drop total %d." % [int(player.get("money")) - money_before, expected_money])
	main.queue_free()
	await process_frame
