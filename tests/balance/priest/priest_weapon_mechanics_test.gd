extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса priest.
# Домен владения: class/priest (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_priest_identity_modes()
	await _test_priest_weapon_mechanics()
	_finish("[balance/priest] PASSED")


func _check_priest_identity_modes() -> void:
	var priest_modes := {}
	for priest_weapon_id in ProgressionData.weapon_ids("priest"):
		var priest_mode := str(ProgressionData.weapon("priest", priest_weapon_id).get("attack_mode", ""))
		if priest_modes.has(priest_mode):
			_fail("Expected Priest weapons to use three distinct attack modes.")
			return
		priest_modes[priest_mode] = true
	for required_priest_mode in ["priest_sanctify", "priest_ward", "priest_dual_toll"]:
		if not priest_modes.has(required_priest_mode):
			_fail("Expected Priest to include unique %s attack mode." % required_priest_mode)
			return


func _test_priest_weapon_mechanics() -> void:
	var priest_weapons := ProgressionData.weapon_ids("priest")
	if priest_weapons != ["priest_reliquary", "priest_censer", "priest_chime"]:
		_fail("Expected Priest to expose exactly reliquary/censer/chime weapons.")
		return
	var expected_modes := {
		"priest_reliquary": "priest_sanctify",
		"priest_censer": "priest_ward",
		"priest_chime": "priest_dual_toll",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("priest", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Priest weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("priest").size() != 5:
		_fail("Expected Priest to have 5 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "PriestWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var priest := player_scene.instantiate()
		holder.add_child(priest)
		priest.global_position = Vector2(860, 720)
		await process_frame
		priest.call("configure_character", "priest", weapon_id)
		var weapon: Node = priest.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Priest %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = priest.global_position + Vector2(180, 0)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_player_hp := float(priest.get("health"))
		# SCRUM-927/928/929: оружейный сустейн кита выпилен — атака НЕ лечит
		# Священника (сустейн класса — trait «Молитва боя», SCRUM-925).
		var dp: Dictionary = priest.get("derived_parameters")
		dp["regeneration"] = 0.0
		priest.set("derived_parameters", dp)
		priest.set("health", maxf(1.0, before_player_hp - 18.0))
		var wounded_hp := float(priest.get("health"))
		# Замораживаем ПАССИВ Священника на время замера: player._process заново
		# считает derived (регенерация возвращается) и тикает _apply_regeneration —
		# это КЛАССОВЫЙ сустейн (regen), не оружейный. Изолируем именно heal оружия:
		# tween'ы оружия живут на дереве независимо от set_process узла игрока.
		priest.set_process(false)
		priest.set_physics_process(false)
		weapon.call("_attack")
		await create_timer(0.85).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Priest weapon %s to damage its target." % weapon_id)
			return
		if float(priest.get("health")) > wounded_hp + 0.01:
			_fail("Expected Priest weapon %s to deal damage WITHOUT healing (kit sustain removed)." % weapon_id)
			return
		priest.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
