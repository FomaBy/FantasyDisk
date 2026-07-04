extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")


class TestEnemy:
	extends Node2D

	var health := 30.0
	var max_health := 30.0

	func take_damage(amount: float) -> void:
		health -= maxf(amount, 0.0)


func _initialize() -> void:
	var errors: Array = []
	await _test_assassin_kill_growth_configs(errors)
	await _test_shadow_momentum_caps_and_never_heals(errors)
	await _test_shadow_momentum_expiry_and_exclusions(errors)
	await _test_non_sustain_classes_do_not_gain_kill_growth(errors)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		push_error("Kill-scaling identity test failed with %d errors." % errors.size())
		quit(1)
		return
	print("Kill-scaling identity test passed.")
	quit(0)


func _test_assassin_kill_growth_configs(errors: Array) -> void:
	var shadow: Dictionary = ProgressionData.weapon("assassin", "shadow_daggers")
	var venom: Dictionary = ProgressionData.weapon("assassin", "venom_wire")
	var chakrams: Dictionary = ProgressionData.weapon("assassin", "chakrams")
	for config in [shadow, venom]:
		if str(config.get("kill_growth_role", "")) != "shadow_momentum":
			errors.append("Expected %s to use shadow_momentum kill growth." % config.get("id", "unknown"))
		if int(config.get("kill_growth_max_stacks", 0)) != 6:
			errors.append("Expected %s kill growth cap to be exactly 6 stacks." % config.get("id", "unknown"))
		if float(config.get("kill_growth_attack_speed_cap", 0.0)) > 0.121:
			errors.append("Expected %s attack-speed kill growth cap <= 12%%." % config.get("id", "unknown"))
	if str(chakrams.get("kill_growth_role", "")) != "":
		errors.append("Expected chakrams to keep boomerang/crit identity without kill-growth role.")


func _test_shadow_momentum_caps_and_never_heals(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var assassin := await _new_player(holder, "assassin", "shadow_daggers")
	var base_params: Dictionary = assassin.get("derived_parameters")
	var base_attack_speed := float(base_params.get("attack_speed", 0.0))
	var base_crit_damage := float(base_params.get("crit_damage_multiplier", 0.0))
	assassin.set("health", float(assassin.get("max_health")) - 18.0)
	var health_before := float(assassin.get("health"))

	for index in range(8):
		var enemy := _new_enemy(holder)
		assassin.call("on_enemy_killed", enemy)
		enemy.queue_free()
	await process_frame

	var mods: Dictionary = assassin.get("run_modifiers")
	var params: Dictionary = assassin.get("derived_parameters")
	if int(mods.get("kill_momentum_stacks", 0.0)) != 6:
		errors.append("Expected shadow momentum to cap at 6 stacks after 8 kills, got %s." % mods.get("kill_momentum_stacks", null))
	_assert_close(errors, float(mods.get("kill_momentum_attack_speed_bonus", 0.0)), 0.12, 0.001, "attack-speed bonus cap")
	_assert_close(errors, float(mods.get("kill_momentum_crit_damage_bonus", 0.0)), 0.09, 0.001, "crit-damage bonus cap")
	if float(params.get("attack_speed", 0.0)) < base_attack_speed * 1.10:
		errors.append("Expected shadow momentum to noticeably raise attack speed.")
	if float(params.get("crit_damage_multiplier", 0.0)) <= base_crit_damage:
		errors.append("Expected shadow momentum to raise crit damage multiplier.")
	_assert_close(errors, float(assassin.get("health")), health_before, 0.05, "shadow momentum no-heal")
	holder.queue_free()
	await process_frame


func _test_shadow_momentum_expiry_and_exclusions(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var assassin := await _new_player(holder, "assassin", "venom_wire")
	var base_attack_speed := float((assassin.get("derived_parameters") as Dictionary).get("attack_speed", 0.0))

	var boss := _new_enemy(holder)
	boss.add_to_group("bosses")
	assassin.call("on_enemy_killed", boss)
	var elite := _new_enemy(holder)
	elite.add_to_group("elite_enemies")
	assassin.call("on_enemy_killed", elite)
	if int((assassin.get("run_modifiers") as Dictionary).get("kill_momentum_stacks", 0.0)) != 0:
		errors.append("Expected boss/elite kills to be excluded from shadow momentum.")

	for index in range(2):
		assassin.call("on_enemy_killed", _new_enemy(holder))
	if int((assassin.get("run_modifiers") as Dictionary).get("kill_momentum_stacks", 0.0)) != 2:
		errors.append("Expected two normal kills to grant two shadow momentum stacks.")
	assassin.call("equip_weapon", "shadow_daggers")
	await process_frame
	var swapped_mods: Dictionary = assassin.get("run_modifiers")
	if int(swapped_mods.get("kill_momentum_stacks", 0.0)) != 0:
		errors.append("Expected shadow momentum to clear on weapon swap.")
	_assert_close(errors, float(swapped_mods.get("kill_momentum_attack_speed_bonus", 0.0)), 0.0, 0.001, "weapon-swap attack bonus")
	base_attack_speed = float((assassin.get("derived_parameters") as Dictionary).get("attack_speed", 0.0))
	for index in range(2):
		assassin.call("on_enemy_killed", _new_enemy(holder))
	assassin.call("_update_kill_growth", 6.2)
	var expired_mods: Dictionary = assassin.get("run_modifiers")
	if int(expired_mods.get("kill_momentum_stacks", 0.0)) != 0:
		errors.append("Expected shadow momentum to expire after duration.")
	_assert_close(errors, float(expired_mods.get("kill_momentum_attack_speed_bonus", 0.0)), 0.0, 0.001, "expired attack bonus")
	_assert_close(errors, float((assassin.get("derived_parameters") as Dictionary).get("attack_speed", 0.0)), base_attack_speed, 0.02, "expired attack speed")

	var chakram_assassin := await _new_player(holder, "assassin", "chakrams")
	chakram_assassin.call("on_enemy_killed", _new_enemy(holder))
	if int((chakram_assassin.get("run_modifiers") as Dictionary).get("kill_momentum_stacks", 0.0)) != 0:
		errors.append("Expected chakrams to avoid shadow momentum stacks.")
	holder.queue_free()
	await process_frame


func _test_non_sustain_classes_do_not_gain_kill_growth(errors: Array) -> void:
	var cases := {
		"doctor": "restore_potion",
		"priest": "priest_censer",
		"knight": "tower_shield",
	}
	var holder := Node2D.new()
	root.add_child(holder)
	for class_id in cases.keys():
		var player := await _new_player(holder, class_id, str(cases[class_id]))
		player.set("health", float(player.get("max_health")) - 12.0)
		var health_before := float(player.get("health"))
		player.call("on_enemy_killed", _new_enemy(holder))
		var mods: Dictionary = player.get("run_modifiers")
		if int(mods.get("kill_momentum_stacks", 0.0)) != 0:
			errors.append("Expected %s to have no shadow momentum stacks." % class_id)
		_assert_close(errors, float(player.get("health")), health_before, 0.05, "%s kill-growth no-heal" % class_id)
	holder.queue_free()
	await process_frame


func _new_player(holder: Node, class_id: String, weapon_id: String) -> Node2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.global_position = Vector2(640, 420)
	await process_frame
	if not player.has_method("configure_character"):
		push_error("Kill-scaling identity test cannot load Player.configure_character; Player script likely failed to parse.")
		quit(1)
		return player
	player.call("configure_character", class_id, weapon_id)
	return player


func _new_enemy(holder: Node) -> TestEnemy:
	var enemy := TestEnemy.new()
	holder.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(720, 420)
	return enemy


func _assert_close(errors: Array, actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) > tolerance:
		errors.append("%s expected %.4f, got %.4f." % [label, expected, actual])
