extends "res://tests/runtime_smoke_test.gd"


func _initialize() -> void:
	_test_berserk_weapon_configs()
	_test_class_weapon_configs()
	_test_class_weapon_mode_registry()
	_test_all_weapon_variants_equip()
	await _test_weapon_effect_cleanup()
	await _test_all_playable_classes()
	await _test_soldier_weapon_mechanics()
	await _test_thief_weapon_mechanics()
	await _test_elementalist_weapon_mechanics()
	await _test_sniper_weapon_mechanics()
	await _test_priest_weapon_mechanics()
	await _test_biologist_weapon_mechanics()
	await _test_robot_weapon_mechanics()
	await _test_engineer_weapon_mechanics()
	await _test_weapon_aiming()
	await _test_class_weapon_rework()
	await _test_unique_class_identity_patterns()
	await _test_ultimate_framework()

	print("Runtime weapon mechanics smoke suite passed.")
	quit()
