extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса thief.
# Домен владения: class/thief (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_thief_identity_modes()
	await _test_thief_weapon_mechanics()
	_finish("[balance/thief] PASSED")


func _check_thief_identity_modes() -> void:
	var thief_modes := {}
	for thief_weapon_id in ProgressionData.weapon_ids("thief"):
		var thief_mode := str(ProgressionData.weapon("thief", thief_weapon_id).get("attack_mode", ""))
		if thief_modes.has(thief_mode):
			_fail("Expected Thief weapons to use three distinct attack modes.")
			return
		thief_modes[thief_mode] = true
	for required_thief_mode in ["coin_ricochet", "shadow_backstab", "smoke_bomb"]:
		if not thief_modes.has(required_thief_mode):
			_fail("Expected Thief to include unique %s attack mode." % required_thief_mode)
			return


func _test_thief_weapon_mechanics() -> void:
	var thief_weapons := ProgressionData.weapon_ids("thief")
	if thief_weapons != ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]:
		_fail("Expected Thief to expose exactly coin pouch/shadow cloak/smoke bomb weapons.")
		return
	var expected_modes := {
		"thief_coin_pouch": "coin_ricochet",
		"thief_shadow_cloak": "shadow_backstab",
		"thief_smoke_bomb": "smoke_bomb",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("thief", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Thief weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("thief").size() != 5:
		_fail("Expected Thief to have 5 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "ThiefWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var thief := player_scene.instantiate()
		holder.add_child(thief)
		thief.global_position = Vector2(860, 720)
		await process_frame
		thief.call("configure_character", "thief", weapon_id)
		var weapon: Node = thief.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Thief %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		# SCRUM-897: для дыма враг ближе — облако садится на цель, и герой обязан
		# оказаться ВНУТРИ зоны (уклонение дыма позиционное).
		var enemy_offset := Vector2(120, 0) if weapon_id == "thief_smoke_bomb" else Vector2(180, 0)
		enemy.global_position = thief.global_position + enemy_offset
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_money := int(thief.get("money"))
		var before_position: Vector2 = thief.global_position
		weapon.call("_attack")
		await create_timer(0.85).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Thief weapon %s to damage its target." % weapon_id)
			return
		if weapon_id == "thief_shadow_cloak":
			if thief.global_position.distance_to(before_position) > 0.01:
				_fail("Expected Thief poison dagger to strike without moving the player body.")
				return
			# SCRUM-897: встроенное окно паралича-яда (контроль без телепорта).
			if not StatusEffects.has_status(enemy, "poison_paralysis"):
				_fail("Expected Thief poison dagger to apply its paralysis window.")
				return
		if weapon_id == "thief_coin_pouch" and int(thief.get("money")) <= before_money:
			_fail("Expected Thief coin pouch to add stolen money instantly on hit.")
			return
		if weapon_id == "thief_smoke_bomb":
			# SCRUM-897: после детонации бонус уклонения живёт только внутри облака.
			if float(thief.call("smoke_cloud_dodge_bonus")) <= 0.0:
				_fail("Expected Thief smoke cloud to grant dodge while standing inside.")
				return
			var inside_position: Vector2 = thief.global_position
			thief.global_position = inside_position + Vector2(4000, 0)
			if float(thief.call("smoke_cloud_dodge_bonus")) > 0.0:
				_fail("Expected Thief smoke dodge to stop outside the cloud.")
				return
			thief.global_position = inside_position
		thief.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
