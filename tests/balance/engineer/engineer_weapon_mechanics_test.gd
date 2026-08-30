extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса engineer.
# Домен владения: class/engineer (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_engineer_identity_modes()
	await _test_engineer_weapon_mechanics()
	_finish("[balance/engineer] PASSED")


func _check_engineer_identity_modes() -> void:
	var engineer_modes := {}
	for engineer_weapon_id in ProgressionData.weapon_ids("engineer"):
		var engineer_mode := str(ProgressionData.weapon("engineer", engineer_weapon_id).get("attack_mode", ""))
		if engineer_modes.has(engineer_mode):
			_fail("Expected Engineer weapons to use three distinct attack modes.")
			return
		engineer_modes[engineer_mode] = true
	for required_engineer_mode in ["engineer_sentry_link", "engineer_orbit_drone", "engineer_pressure_mines"]:
		if not engineer_modes.has(required_engineer_mode):
			_fail("Expected Engineer to include unique %s attack mode." % required_engineer_mode)
			return


func _test_engineer_weapon_mechanics() -> void:
	var engineer_weapons := ProgressionData.weapon_ids("engineer")
	if engineer_weapons != ["engineer_sentry_wrench", "engineer_repair_drone", "engineer_pressure_mines"]:
		_fail("Expected Engineer to expose exactly sentry wrench/repair drone/pressure mines weapons.")
		return
	var expected_modes := {
		"engineer_sentry_wrench": "engineer_sentry_link",
		"engineer_repair_drone": "engineer_orbit_drone",  # SCRUM-906
		"engineer_pressure_mines": "engineer_pressure_mines",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("engineer", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Engineer weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("engineer").size() != 5:
		_fail("Expected Engineer to have 5 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "EngineerWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var engineer := player_scene.instantiate()
		holder.add_child(engineer)
		engineer.global_position = Vector2(860, 720)
		await process_frame
		engineer.call("configure_character", "engineer", weapon_id)
		var weapon: Node = engineer.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Engineer %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = engineer.global_position + Vector2(180, 0)
		var second_enemy := enemy_scene.instantiate()
		holder.add_child(second_enemy)
		second_enemy.set("max_health", 100000.0)
		second_enemy.set("health", 100000.0)
		second_enemy.global_position = engineer.global_position + Vector2(240, 45)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_second_hp := float(second_enemy.get("health"))
		weapon.call("_attack")
		if weapon_id == "engineer_repair_drone":
			# SCRUM-906: орбитальный дрон бьёт КОНТАКТОМ — приклеиваем цели к
			# дрону на ~0.7с (по одному хиту на цель за per-enemy кулдаун).
			var drone: Node2D = null
			for device in get_nodes_in_group("engineer_devices"):
				if (device as Node).has_meta("orbit_drone"):
					drone = device as Node2D
					break
			if drone == null:
				_fail("Expected Engineer orbit drone to deploy.")
				return
			for _glue_frame in range(40):
				if is_instance_valid(drone):
					enemy.set("global_position", drone.global_position)
					second_enemy.set("global_position", drone.global_position + Vector2(18, 0))
				await process_frame
		elif weapon_id == "engineer_pressure_mines":
			# SCRUM-907: мины ложатся в случайное кольцо и лежат вечно — ведём
			# врага на мину (враг подрывает сразу, без safe-окна).
			var mine: Node2D = null
			for device in get_nodes_in_group("engineer_devices"):
				if (device as Node).has_meta("persistent_mine"):
					mine = device as Node2D
					break
			if mine == null:
				_fail("Expected Engineer pressure mines to deploy.")
				return
			enemy.set("global_position", mine.global_position)
			await create_timer(0.45).timeout
		else:
			await create_timer(1.35).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Engineer weapon %s to damage its primary target." % weapon_id)
			return
		if weapon_id in ["engineer_sentry_wrench", "engineer_repair_drone"] and float(second_enemy.get("health")) >= before_second_hp:
			_fail("Expected Engineer weapon %s to affect a secondary target." % weapon_id)
			return
		engineer.queue_free()
		enemy.queue_free()
		second_enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
