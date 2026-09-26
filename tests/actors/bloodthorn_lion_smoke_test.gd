extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра bloodthorn_lion.
# Домен владения: actor/bloodthorn_lion (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("bloodthorn_lion")


func _run_actor_checks() -> void:
	_assert_boss_pack("bloodthorn_lion", ["skill_spike_ring", "skill_rift_zone"], {"idle": 1, "move": 7, "attack": 6, "hit": 6, "death": 6, "skill_spike_ring": 6, "skill_rift_zone": 6})
	_assert_boss_scene_full_frame("bloodthorn_lion", "res://scenes/BossBloodthornLion.tscn", "bloodthorn_lion:spike_ring:windup", "skill_spike_ring", "_play_boss_skill_visual", ["skill_spike_ring", "cast", Vector2.RIGHT], "skill_spike_ring")
	_assert_static_sprite_path("res://scenes/BossBloodthornLion.tscn", "Sprite2D", "res://assets/sprites/bosses/boss_bloodthorn_lion.png")
