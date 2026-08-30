extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра brood_mother.
# Домен владения: actor/brood_mother (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("brood_mother")


func _run_actor_checks() -> void:
	_assert_boss_pack("brood_mother", ["skill_brood_spawn", "skill_web_zone"], {})
	_assert_boss_scene_full_frame("brood_mother", "res://scenes/BossBroodMother.tscn", "brood_mother:brood_spawn:windup", "skill_brood_spawn", "_play_boss_skill_visual", ["skill_web_zone", "cast", Vector2.RIGHT], "skill_web_zone")
	_assert_static_sprite_path("res://scenes/BossBroodMother.tscn", "Sprite2D", "res://assets/sprites/bosses/boss_brood_mother.png")
