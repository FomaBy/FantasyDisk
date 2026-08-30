extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса elementalist.
# Домен владения: class/elementalist (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_elementalist_identity_modes()
	await _test_elementalist_weapon_mechanics()
	_finish("[balance/elementalist] PASSED")


func _check_elementalist_identity_modes() -> void:
	var elementalist_modes := {}
	for elementalist_weapon_id in ProgressionData.weapon_ids("elementalist"):
		var elementalist_mode := str(ProgressionData.weapon("elementalist", elementalist_weapon_id).get("attack_mode", ""))
		if elementalist_modes.has(elementalist_mode):
			_fail("Expected Elementalist weapons to use three distinct attack modes.")
			return
		elementalist_modes[elementalist_mode] = true
	for required_elementalist_mode in ["elemental_orbit", "prism_rift", "meteor_shards"]:
		if not elementalist_modes.has(required_elementalist_mode):
			_fail("Expected Elementalist to include unique %s attack mode." % required_elementalist_mode)
			return


func _test_elementalist_weapon_mechanics() -> void:
	var elementalist_weapons := ProgressionData.weapon_ids("elementalist")
	if elementalist_weapons != ["elementalist_orb_ring", "elementalist_prism_focus", "elementalist_meteor_core"]:
		_fail("Expected Elementalist to expose exactly orb/prism/meteor weapons.")
		return
	var expected_modes := {
		"elementalist_orb_ring": "elemental_orbit",
		"elementalist_prism_focus": "prism_rift",
		"elementalist_meteor_core": "meteor_shards",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("elementalist", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Elementalist weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("elementalist").size() != 5:
		_fail("Expected Elementalist to have 5 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "ElementalistWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var elementalist := player_scene.instantiate()
		holder.add_child(elementalist)
		elementalist.global_position = Vector2(860, 720)
		await process_frame
		elementalist.call("configure_character", "elementalist", weapon_id)
		var weapon: Node = elementalist.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Elementalist %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = elementalist.global_position + Vector2(160, 0)
		await process_frame
		var before_hp := float(enemy.get("health"))
		weapon.call("_attack")
		# SCRUM-950: у метеора долгий телеграф+падение (grenade_delay — полная
		# задержка до удара), ждём дольше стандартного окна.
		var damage_window := 0.95
		if weapon_id == "elementalist_meteor_core":
			damage_window = float(weapon.get("grenade_delay")) + 0.55
		await create_timer(damage_window).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Elementalist weapon %s to damage its target." % weapon_id)
			return
		elementalist.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
