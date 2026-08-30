extends "res://tests/runtime_smoke_test.gd"


func _initialize() -> void:
	_test_class_weapon_configs()
	_test_class_weapon_mode_registry()
	_test_all_weapon_variants_equip()
	await _test_weapon_effect_cleanup()
	await _test_all_playable_classes()
	await _test_weapon_aiming()
	await _test_ultimate_framework()

	_finish("Runtime weapon mechanics smoke suite passed.")
