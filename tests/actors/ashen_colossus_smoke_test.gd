extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра ashen_colossus.
# Домен владения: actor/ashen_colossus (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("ashen_colossus")


func _run_actor_checks() -> void:
	_assert_boss_pack("ashen_colossus", ["skill_molten_slam", "skill_armor_pulse"], {"idle": 1, "move": 7, "attack": 6, "hit": 6, "death": 6, "skill_molten_slam": 6, "skill_armor_pulse": 6})
	_assert_boss_scene_full_frame("ashen_colossus", "res://scenes/BossAshenColossus.tscn", "ashen_colossus:molten_slam:windup", "skill_molten_slam", "_play_boss_skill_visual", ["skill_molten_slam", "attack", Vector2.RIGHT], "skill_molten_slam")
	_assert_static_sprite_path("res://scenes/BossAshenColossus.tscn", "Sprite2D", "res://assets/sprites/bosses/boss_ashen_colossus.png")
