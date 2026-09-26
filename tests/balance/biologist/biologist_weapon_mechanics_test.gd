extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса biologist.
# Домен владения: class/biologist (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_biologist_identity_modes()
	await _test_biologist_weapon_mechanics()
	_finish("[balance/biologist] PASSED")


func _check_biologist_identity_modes() -> void:
	var biologist_modes := {}
	for biologist_weapon_id in ProgressionData.weapon_ids("biologist"):
		var biologist_mode := str(ProgressionData.weapon("biologist", biologist_weapon_id).get("attack_mode", ""))
		if biologist_modes.has(biologist_mode):
			_fail("Expected Biologist weapons to use three distinct attack modes.")
			return
		biologist_modes[biologist_mode] = true
	for required_biologist_mode in ["bio_spore_bloom", "bio_sample_dart", "bio_symbiote_web"]:
		if not biologist_modes.has(required_biologist_mode):
			_fail("Expected Biologist to include unique %s attack mode." % required_biologist_mode)
			return


func _test_biologist_weapon_mechanics() -> void:
	var biologist_weapons := ProgressionData.weapon_ids("biologist")
	if biologist_weapons != ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"]:
		_fail("Expected Biologist to expose exactly spore lens/sample injector/symbiote seed weapons.")
		return
	var expected_modes := {
		"biologist_spore_lens": "bio_spore_bloom",
		"biologist_sample_injector": "bio_sample_dart",
		"biologist_symbiote_seed": "bio_symbiote_web",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("biologist", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Biologist weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("biologist").size() != 5:
		_fail("Expected Biologist to have 5 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "BiologistWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var biologist := player_scene.instantiate()
		holder.add_child(biologist)
		biologist.global_position = Vector2(860, 720)
		await process_frame
		biologist.call("configure_character", "biologist", weapon_id)
		var weapon: Node = biologist.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Biologist %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = biologist.global_position + Vector2(180, 0)
		var second_enemy := enemy_scene.instantiate()
		holder.add_child(second_enemy)
		second_enemy.set("max_health", 100000.0)
		second_enemy.set("health", 100000.0)
		second_enemy.global_position = biologist.global_position + Vector2(230, 50)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_second_hp := float(second_enemy.get("health"))
		weapon.call("_attack")
		await create_timer(0.90).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Biologist weapon %s to damage its primary target." % weapon_id)
			return
		if weapon_id == "biologist_symbiote_seed" and float(second_enemy.get("health")) >= before_second_hp:
			_fail("Expected Biologist symbiote web to damage a linked nearby target.")
			return
		biologist.queue_free()
		enemy.queue_free()
		second_enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
