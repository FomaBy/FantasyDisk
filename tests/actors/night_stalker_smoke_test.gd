extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра night_stalker.
# Домен владения: actor/night_stalker (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("night_stalker")


func _run_actor_checks() -> void:
	_assert_elite_pack("night_stalker", ["skill_shadow_strike", "skill_phase_dash"], {"idle": 4, "move": 8, "attack": 7, "hit": 6, "death": 7, "skill_shadow_strike": 7, "skill_phase_dash": 7}, ["attack"], true)
	_assert_elite_scene_full_frame("night_stalker", "res://scenes/EliteStalker.tscn", "night_stalker:shadow_strike:windup", "skill_shadow_strike")
	_assert_static_sprite_path("res://scenes/EliteStalker.tscn", "Body", "res://assets/sprites/elites/night_stalker.png")
	_assert_elite_attack_phase("night_stalker", "res://scenes/EliteStalker.tscn", "shadow_strike")


func _check_elite_windup_pose(rig: Node2D) -> void:
	var windup_pelvis := rig.get_node("Pelvis") as Node2D
	if windup_pelvis.position.y <= 2.0 or windup_pelvis.scale.y >= 0.94:
		_fail("Expected Night Stalker windup to crouch before shadow strike.")


func _check_elite_strike_pose(rig: Node2D) -> void:
	var strike_pelvis := rig.get_node("Pelvis") as Node2D
	if strike_pelvis.position.x <= 1.0:
		_fail("Expected night_stalker strike to lunge/gesture forward.")
