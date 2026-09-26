extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса soldier.
# Домен владения: class/soldier (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_soldier_identity_modes()
	await _test_soldier_weapon_mechanics()
	_finish("[balance/soldier] PASSED")


func _check_soldier_identity_modes() -> void:
	var soldier_modes := {}
	for soldier_weapon_id in ProgressionData.weapon_ids("soldier"):
		var mode := str(ProgressionData.weapon("soldier", soldier_weapon_id).get("attack_mode", ""))
		if soldier_modes.has(mode):
			_fail("Expected Soldier weapons to use three distinct attack modes.")
			return
		soldier_modes[mode] = true
	for required_soldier_mode in ["arquebus_shot", "grenade_fuse", "bayonet_cone"]:
		if not soldier_modes.has(required_soldier_mode):
			_fail("Expected Soldier to include unique %s attack mode." % required_soldier_mode)
			return


func _test_soldier_weapon_mechanics() -> void:
	var soldier_weapons := ProgressionData.weapon_ids("soldier")
	if soldier_weapons != ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]:
		_fail("Expected Soldier to expose exactly rifle/grenade/bayonet weapons.")
		return
	var expected_modes := {
		"soldier_rifle": "arquebus_shot",
		"soldier_grenade": "grenade_fuse",
		"soldier_bayonet": "bayonet_cone",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("soldier", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Soldier weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
		if ProgressionData.ascension_levels("soldier").size() != 5:
			_fail("Expected Soldier to have 5 ascension levels.")
			return

	var holder := Node2D.new()
	holder.name = "SoldierWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var soldier := player_scene.instantiate()
		holder.add_child(soldier)
		soldier.global_position = Vector2(800, 700)
		await process_frame
		soldier.call("configure_character", "soldier", weapon_id)
		var weapon: Node = soldier.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Soldier %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		var offset := Vector2(220, 0)
		if weapon_id == "soldier_bayonet":
			offset = Vector2(140, 0)
		enemy.global_position = soldier.global_position + offset
		await process_frame
		var before_hp := float(enemy.get("health"))
		weapon.call("_attack")
		# SCRUM-937: у гранаты медленный полёт + фитиль — урон приходит заметно позже.
		var damage_wait := 2.4 if weapon_id == "soldier_grenade" else 0.85
		await create_timer(damage_wait).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Soldier weapon %s to damage its target." % weapon_id)
			return
		soldier.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
