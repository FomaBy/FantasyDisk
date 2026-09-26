extends RefCounted
class_name EnemyAnimationPriority

const HIT_ANIMATION_DURATION := 0.18
var _hit_animation_left := 0.0


func register_hit(is_living: bool) -> void:
	if is_living:
		_hit_animation_left = HIT_ANIMATION_DURATION


func blocks_locomotion(delta: float, elite_attack_state: String) -> bool:
	_hit_animation_left = maxf(_hit_animation_left - delta, 0.0)
	return elite_attack_state != "idle" or _hit_animation_left > 0.0
