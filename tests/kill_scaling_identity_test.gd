extends SceneTree

# Kill-scaling identity: убийства НЕ дают скрытых стаков силы и не лечат.
#
# SCRUM-894 переписал ассасинскую часть: нечитаемый Shadow Momentum
# (kill_growth_* стаки за убийства) УДАЛЁН из кита — его заменил явный
# «Рывок темпа» Теневых кинжалов (flurry_tempo_*: короткий бафф скорости и
# уворота ПОСЛЕ серии по врагам, bounded duration + внутренний кулдаун, без
# перманентного аптайма). Этот тест держит инварианты:
#   1) ни одно оружие Ассасина не несёт kill_growth_*;
#   2) убийства не дают Ассасину ни стаков, ни лечения;
#   3) «Рывок темпа» ограничен (нет стакинга, нет аптайма > duration/cooldown,
#      не трогает attack_speed, не лечит) и чистится при смене оружия;
#   4) классы без sustain-идентичности не получают kill-стаков и лечения от убийств.
#
# Запуск: Godot --headless --path . --script res://tests/kill_scaling_identity_test.gd

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
	_test_assassin_shadow_momentum_removed(errors)
	await _test_kills_grant_no_stacks_or_heal(errors)
	await _test_flurry_tempo_bounded(errors)
	await _test_non_sustain_classes_do_not_gain_kill_growth(errors)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		push_error("Kill-scaling identity test failed with %d errors." % errors.size())
		quit(1)
		return
	print("Kill-scaling identity test passed.")
	quit(0)


func _test_assassin_shadow_momentum_removed(errors: Array) -> void:
	for weapon_id in ["chakrams", "shadow_daggers", "venom_wire"]:
		var config: Dictionary = ProgressionData.weapon("assassin", str(weapon_id))
		if str(config.get("kill_growth_role", "")) != "":
			errors.append("SCRUM-894: %s всё ещё несёт kill_growth_role (Shadow Momentum должен быть удалён)." % weapon_id)
		for key in config.keys():
			if str(key).begins_with("kill_growth_"):
				errors.append("SCRUM-894: %s несёт остаточный ключ %s." % [weapon_id, key])
	var daggers: Dictionary = ProgressionData.weapon("assassin", "shadow_daggers")
	if float(daggers.get("flurry_tempo_duration", 0.0)) <= 0.0:
		errors.append("SCRUM-894: у Теневых кинжалов нет «Рывка темпа» (flurry_tempo_duration).")
	if float(daggers.get("flurry_tempo_cooldown", 0.0)) < float(daggers.get("flurry_tempo_duration", 0.0)):
		errors.append("SCRUM-894: кулдаун «Рывка темпа» меньше длительности — перманентный аптайм.")


func _test_kills_grant_no_stacks_or_heal(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var assassin := await _new_player(holder, "assassin", "shadow_daggers")
	var base_params: Dictionary = assassin.get("derived_parameters")
	var base_attack_speed := float(base_params.get("attack_speed", 0.0))
	var base_move_speed := float(base_params.get("move_speed", 0.0))
	assassin.set("health", float(assassin.get("max_health")) - 18.0)
	var health_before := float(assassin.get("health"))

	for index in range(8):
		var enemy := _new_enemy(holder)
		assassin.call("on_enemy_killed", enemy)
		enemy.queue_free()
	await process_frame

	var mods: Dictionary = assassin.get("run_modifiers")
	var params: Dictionary = assassin.get("derived_parameters")
	if float(mods.get("kill_momentum_stacks", 0.0)) != 0.0:
		errors.append("Убийства дали kill-стаки Ассасину — Shadow Momentum должен быть удалён.")
	if float(mods.get("flurry_tempo_active", 0.0)) != 0.0:
		errors.append("Убийства активировали «Рывок темпа» — бафф положен только за серию по врагам.")
	_assert_close(errors, float(params.get("attack_speed", 0.0)), base_attack_speed, 0.02, "attack speed after kills")
	_assert_close(errors, float(params.get("move_speed", 0.0)), base_move_speed, 0.02, "move speed after kills")
	_assert_close(errors, float(assassin.get("health")), health_before, 0.05, "kills no-heal")
	holder.queue_free()
	await process_frame


func _test_flurry_tempo_bounded(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var assassin := await _new_player(holder, "assassin", "shadow_daggers")
	var config: Dictionary = assassin.get("weapon_config")
	var duration := float(config.get("flurry_tempo_duration", 0.0))
	var base_params: Dictionary = assassin.get("derived_parameters")
	var base_attack_speed := float(base_params.get("attack_speed", 0.0))
	var base_move_speed := float(base_params.get("move_speed", 0.0))
	assassin.set("health", float(assassin.get("max_health")) - 12.0)
	var health_before := float(assassin.get("health"))

	assassin.call("trigger_flurry_tempo")
	var boosted: Dictionary = assassin.get("derived_parameters")
	var boosted_move := float(boosted.get("move_speed", 0.0))
	if boosted_move <= base_move_speed:
		errors.append("«Рывок темпа» не поднял move_speed.")
	if boosted_move > base_move_speed * 1.26:
		errors.append("«Рывок темпа» поднял move_speed выше страховочного капа +25%: %.2f -> %.2f." % [base_move_speed, boosted_move])
	_assert_close(errors, float(boosted.get("attack_speed", 0.0)), base_attack_speed, 0.02, "tempo attack speed")
	_assert_close(errors, float(assassin.get("health")), health_before, 0.05, "tempo no-heal")

	# Стакинга нет: повторный триггер в окне не наращивает бафф.
	assassin.call("trigger_flurry_tempo")
	_assert_close(errors, float((assassin.get("derived_parameters") as Dictionary).get("move_speed", 0.0)), boosted_move, 0.02, "tempo no-stack")

	# Истечение: бафф спадает, кулдаун блокирует мгновенный retrigger.
	assassin.call("_update_flurry_tempo", duration + 0.1)
	var expired: Dictionary = assassin.get("run_modifiers")
	if float(expired.get("flurry_tempo_active", 0.0)) != 0.0:
		errors.append("«Рывок темпа» не истёк после duration.")
	_assert_close(errors, float((assassin.get("derived_parameters") as Dictionary).get("move_speed", 0.0)), base_move_speed, 0.02, "tempo expiry move speed")
	assassin.call("trigger_flurry_tempo")
	if float((assassin.get("run_modifiers") as Dictionary).get("flurry_tempo_active", 0.0)) != 0.0:
		errors.append("«Рывок темпа» перезапустился в кулдауне — перманентный аптайм.")

	# Смена оружия чистит бафф.
	assassin.call("_update_flurry_tempo", float(config.get("flurry_tempo_cooldown", 0.0)))
	assassin.call("trigger_flurry_tempo")
	assassin.call("equip_weapon", "venom_wire")
	await process_frame
	var swapped_mods: Dictionary = assassin.get("run_modifiers")
	if float(swapped_mods.get("flurry_tempo_active", 0.0)) != 0.0:
		errors.append("«Рывок темпа» пережил смену оружия.")
	_assert_close(errors, float(swapped_mods.get("flurry_tempo_speed_bonus", 0.0)), 0.0, 0.001, "weapon-swap tempo bonus")
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
		if float(mods.get("kill_momentum_stacks", 0.0)) != 0.0:
			errors.append("Expected %s to have no kill momentum stacks." % class_id)
		# «Рывок темпа» — data-driven: у оружий без flurry_tempo_* ключей триггер no-op.
		player.call("trigger_flurry_tempo")
		if float((player.get("run_modifiers") as Dictionary).get("flurry_tempo_active", 0.0)) != 0.0:
			errors.append("Expected %s trigger_flurry_tempo to be a no-op without config keys." % class_id)
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
	# Далеко за радиусами всех оружий: авто-атака экипированного оружия не должна
	# случайно попадать по стендовым врагам (иначе «Рывок темпа» и drain-лечение
	# срабатывают легитимно и шумят в kill-инвариантах).
	enemy.global_position = Vector2(4200, 3200)
	return enemy


func _assert_close(errors: Array, actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) > tolerance:
		errors.append("%s expected %.4f, got %.4f." % [label, expected, actual])
