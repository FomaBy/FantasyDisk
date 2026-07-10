extends SceneTree

# SCRUM-888/905: focused-тест турелей «Часовой турели» (engineer_sentry_wrench).
# Гарды:
#   - развёртка по атаке создаёт турель (engineer_devices + player_weapon_effects)
#     с боезапасом 15 (SCRUM-905);
#   - предел парка реального Инженера = 2 + floor(summon_amount/4) (база ~12.5 →
#     5); при полном парке деплой ПРОПУСКАЕТСЯ — старейшая НЕ заменяется;
#   - турель автострельбой наносит урон БЛИЖАЙШЕМУ врагу в радиусе;
#   - урон снаряда скейлится от Лидерства (summon_role-фактор);
#   - чистка при завершении боя/уходе оружия — без осиротевших турелей.
#
# Запуск: Godot --headless --path . --script res://tests/engineer_turret_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")


class TestEnemy:
	extends Node2D

	var health := 100000.0
	var max_health := 100000.0
	var damage_taken := 0.0

	func take_damage(amount: float) -> void:
		damage_taken += maxf(amount, 0.0)
		health -= maxf(amount, 0.0)


func _initialize() -> void:
	var errors: Array = []
	await _test_turret_deploy_and_limit(errors)
	await _test_turret_damages_nearest_and_scales(errors)
	await _test_turret_cleanup(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Engineer turret: %s" % error)
		push_error("Engineer turret test failed: %d errors." % errors.size())
		quit(1)
		return
	print("Engineer turret test passed (deploy/limit/nearest/scale/cleanup).")
	quit()


func _alive_turrets() -> Array:
	var alive: Array = []
	for device in get_nodes_in_group("engineer_devices"):
		if device != null and is_instance_valid(device) and device.has_method("try_fire"):
			alive.append(device)
	return alive


func _make_engineer(holder: Node2D, position: Vector2) -> Node2D:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate() as Node2D
	holder.add_child(player)
	player.global_position = position
	return player


func _test_turret_deploy_and_limit(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player := _make_engineer(holder, Vector2(400, 400))
	await process_frame
	player.call("configure_character", "engineer", "engineer_sentry_wrench")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		errors.append("Expected Engineer sentry wrench to attach a weapon.")
		holder.queue_free()
		await process_frame
		return
	weapon.set_process(false)

	if int(weapon.get("max_summons")) != 2:
		errors.append("Expected turret base max_summons of 2, got %d." % int(weapon.get("max_summons")))
	if int(weapon.get("sentry_shot_magazine")) != 15:
		errors.append("Expected sentry_shot_magazine of 15, got %d." % int(weapon.get("sentry_shot_magazine")))

	# Реальный Инженер: summon_amount ~12.5 → предел парка 2 + 3 = 5.
	var expected_limit := int(weapon.call("_engineer_turret_limit", player))
	if expected_limit != 5:
		errors.append("Expected real-engineer turret limit of 5 (2 + floor(sa/4)), got %d." % expected_limit)

	weapon.call("_fire_engineer_sentry_link", player, Vector2.RIGHT)
	await process_frame
	var first_wave := _alive_turrets()
	if first_wave.size() != 1:
		errors.append("Expected 1 turret after first deploy, got %d." % first_wave.size())
	var first_turret: Node = first_wave[0] if not first_wave.is_empty() else null
	if first_turret != null and not first_turret.is_in_group("player_weapon_effects"):
		errors.append("Expected deployed turret to be tracked in player_weapon_effects.")
	if first_turret != null and int(first_turret.call("shots_left")) != 15:
		errors.append("Expected fresh turret magazine of 15, got %s." % first_turret.call("shots_left"))

	# Добиваем парк до предела и пробуем сверх: деплой пропускается, старейшая ЖИВА.
	for deploy_index in range(expected_limit + 2):
		player.global_position = Vector2(520.0 + 40.0 * float(deploy_index), 400)
		weapon.call("_fire_engineer_sentry_link", player, Vector2.RIGHT)
	await process_frame
	await process_frame
	var final_wave := _alive_turrets()
	if final_wave.size() != expected_limit:
		errors.append("Expected turret park capped at %d, got %d." % [expected_limit, final_wave.size()])
	if first_turret == null or not is_instance_valid(first_turret):
		errors.append("Expected the OLDEST turret to survive: full park must SKIP deploys, not retire.")

	holder.queue_free()
	await process_frame


func _test_turret_damages_nearest_and_scales(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player := _make_engineer(holder, Vector2(400, 900))
	await process_frame
	player.call("configure_character", "engineer", "engineer_sentry_wrench")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		errors.append("Expected Engineer sentry wrench to attach for damage test.")
		holder.queue_free()
		await process_frame
		return
	weapon.set_process(false)
	weapon.set("amp_pulse_interval", 0.05)
	weapon.set("sentry_splash_radius", 0.0)
	weapon.set("sentry_splash_damage_multiplier", 0.0)
	var params: Dictionary = player.get("derived_parameters")
	params["damage"] = 10.0
	params["crit_chance"] = 0.0
	params["summon_amount"] = 0.0
	params["leadership"] = 0.0
	player.set("derived_parameters", params)

	var near_enemy := TestEnemy.new()
	holder.add_child(near_enemy)
	near_enemy.add_to_group("enemies")
	near_enemy.global_position = player.global_position + Vector2(150, 0)
	var far_enemy := TestEnemy.new()
	holder.add_child(far_enemy)
	far_enemy.add_to_group("enemies")
	# Вне радиуса турели (attack_range 560 от точки развёртки player+92).
	far_enemy.global_position = player.global_position + Vector2(700, 0)
	await process_frame

	weapon.call("_fire_engineer_sentry_link", player, Vector2.RIGHT)
	for _frame in range(40):
		await process_frame
	if float(near_enemy.damage_taken) <= 0.01:
		errors.append("Expected turret autofire to damage the nearest enemy, got %.2f." % near_enemy.damage_taken)
	if float(far_enemy.damage_taken) > 0.01:
		errors.append("Expected turret to ignore enemies outside its radius, far got %.2f." % far_enemy.damage_taken)

	# Скейл урона от атрибута: Лидерство поднимает summon_role-фактор снаряда.
	var low_rolled := float(weapon.call("_rolled_damage", player))
	params["leadership"] = 10.0
	player.set("derived_parameters", params)
	var high_rolled := float(weapon.call("_rolled_damage", player))
	if high_rolled < low_rolled * 1.4:
		errors.append("Expected Leadership to scale turret shot damage (low %.2f, high %.2f)." % [low_rolled, high_rolled])

	holder.queue_free()
	await process_frame


func _test_turret_cleanup(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player := _make_engineer(holder, Vector2(400, 1400))
	await process_frame
	player.call("configure_character", "engineer", "engineer_sentry_wrench")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		errors.append("Expected Engineer sentry wrench to attach for cleanup test.")
		holder.queue_free()
		await process_frame
		return
	weapon.set_process(false)
	weapon.call("_fire_engineer_sentry_link", player, Vector2.RIGHT)
	player.global_position = Vector2(520, 1400)
	weapon.call("_fire_engineer_sentry_link", player, Vector2.RIGHT)
	await process_frame
	if _alive_turrets().size() != 2:
		errors.append("Expected 2 turrets before cleanup, got %d." % _alive_turrets().size())

	# Конец боя: main.gd чистит группу player_weapon_effects — турели уходят.
	for effect in get_nodes_in_group("player_weapon_effects"):
		if effect != null and is_instance_valid(effect):
			effect.queue_free()
	await process_frame
	await process_frame
	if not _alive_turrets().is_empty():
		errors.append("Expected battle-end group cleanup to free all turrets, %d left." % _alive_turrets().size())

	# Осиротевшая турель (оружие исчезло) самоуничтожается на следующем тике.
	weapon.call("_fire_engineer_sentry_link", player, Vector2.RIGHT)
	await process_frame
	if _alive_turrets().size() != 1:
		errors.append("Expected a fresh turret before weapon removal, got %d." % _alive_turrets().size())
	player.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if not _alive_turrets().is_empty():
		errors.append("Expected turrets to be freed together with their weapon, %d left." % _alive_turrets().size())

	holder.queue_free()
	await process_frame
