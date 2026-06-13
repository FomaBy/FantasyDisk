extends "res://tests/runtime_smoke_test.gd"


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for boss/elite smoke.")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await _test_elite_flow(main_scene)
	await _test_elite_unique_attacks()
	await _test_enemy_stage_scaling_and_elite_rewards(main_scene)
	await _test_epic_elite_boss_scale_hitbox()
	await _test_elite_phase2_escalation()
	await _test_boss_zone_wave_safe_corridor()
	await _test_elite_boss_presentation(main_scene)
	await _test_boss_hud_omits_timer(main_scene)
	await _test_mini_elite_roster(main_scene)
	await _test_new_boss_roster(main_scene)
	await _test_victory_flow(main)

	main.queue_free()
	await process_frame
	print("Runtime boss/elite smoke suite passed.")
	quit()
