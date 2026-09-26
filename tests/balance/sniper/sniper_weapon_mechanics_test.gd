extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса sniper.
# Домен владения: class/sniper (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_sniper_identity_modes()
	await _test_sniper_weapon_mechanics()
	_finish("[balance/sniper] PASSED")


func _check_sniper_identity_modes() -> void:
	var sniper_modes := {}
	for sniper_weapon_id in ProgressionData.weapon_ids("sniper"):
		var sniper_mode := str(ProgressionData.weapon("sniper", sniper_weapon_id).get("attack_mode", ""))
		if sniper_modes.has(sniper_mode):
			_fail("Expected Sniper weapons to use three distinct attack modes.")
			return
		sniper_modes[sniper_mode] = true
	for required_sniper_mode in ["sniper_lockshot", "sniper_kill_zone", "sniper_split_round"]:
		if not sniper_modes.has(required_sniper_mode):
			_fail("Expected Sniper to include unique %s attack mode." % required_sniper_mode)
			return


func _test_sniper_weapon_mechanics() -> void:
	var sniper_weapons := ProgressionData.weapon_ids("sniper")
	if sniper_weapons != ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"]:
		_fail("Expected Sniper to expose exactly deadeye/scope/shatter weapons.")
		return
	var expected_modes := {
		"sniper_deadeye_rifle": "sniper_lockshot",
		"sniper_spotter_scope": "sniper_kill_zone",
		"sniper_shatter_rounds": "sniper_split_round",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("sniper", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Sniper weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("sniper").size() != 5:
		_fail("Expected Sniper to have 5 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "SniperWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var sniper := player_scene.instantiate()
		holder.add_child(sniper)
		sniper.global_position = Vector2(860, 720)
		await process_frame
		sniper.call("configure_character", "sniper", weapon_id)
		var weapon: Node = sniper.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Sniper %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = sniper.global_position + Vector2(220, 0)
		await process_frame
		var before_hp := float(enemy.get("health"))
		weapon.call("_attack")
		# SCRUM-932: у Прицела Наводчика отложенный артиллерийский снаряд
		# (grenade_delay ~1с до падения) — как у метеора, ждём дольше окна.
		var damage_window := 0.90
		if weapon_id == "sniper_spotter_scope":
			damage_window = float(weapon.get("grenade_delay")) + 0.55
		await create_timer(damage_window).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Sniper weapon %s to damage its target." % weapon_id)
			return
		sniper.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
