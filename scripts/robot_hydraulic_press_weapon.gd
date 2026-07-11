class_name RobotHydraulicPressWeapon
extends "res://scripts/class_weapon.gd"

## Scene-specific Animator bridge for SCRUM-917. The inherited ClassWeapon
## remains the sole owner of hit geometry, damage and compression displacement.

const COMPRESSION_VFX_SCENE := preload("res://scenes/vfx/RobotHydraulicPressCompressionVfx.tscn")
const PRESS_CONSTELLATION_FINAL_MECHANICS := {"press_axis_second_jaw": "press"}


func _fire_robot_compression_line(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# Preserve the accepted SCRUM-916 gameplay path unchanged.
	super._fire_robot_compression_line(owner_node, target, direction)
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var aim := direction.normalized()
	if aim.length_squared() <= 0.001:
		return
	var corridor_width := suppression_width
	if _owner_mod("press_corridor_bonus") > 0.0:
		corridor_width *= 1.30
	var start := owner_node.global_position + aim * 28.0
	# Damage/control query measures attack_range forward FROM `start`; the new
	# visual therefore spans the same full 430px instead of inheriting the old
	# cosmetic beam endpoint that was 28px short.
	var finish := start + aim * attack_range
	var effect := COMPRESSION_VFX_SCENE.instantiate() as RobotHydraulicPressCompressionVfx
	if effect == null:
		return
	_projectile_parent().add_child(effect)
	effect.configure(start, finish, corridor_width, beam_width, grenade_delay, visual_color)
	_register_effect(effect)
	_schedule_constellation_second_jaw(owner_node, start, finish, aim, corridor_width)


func _schedule_constellation_second_jaw(owner_node: Node2D, start: Vector2, finish: Vector2, direction: Vector2, corridor_width: float) -> Dictionary:
	if owner_node == null or not owner_node.has_method("constellation_weapon_mechanic"):
		return {"triggered": false}
	var mechanic_raw = owner_node.call("constellation_weapon_mechanic", weapon_id, "press_axis_second_jaw")
	if not mechanic_raw is Dictionary or (mechanic_raw as Dictionary).is_empty():
		return {"triggered": false}
	var result := _constellation_event("press", null, 0.0, {"corridor_width": corridor_width})
	if not bool(result.get("triggered", false)) or not is_inside_tree():
		return result
	var params: Dictionary = (mechanic_raw as Dictionary).get("params", {})
	var ratio := clampf(float(params.get("second_jaw_damage_ratio", 0.42)), 0.0, 1.0)
	var jaw_width := maxf(corridor_width * 0.46, beam_width)
	var jaw_tween := create_tween()
	jaw_tween.tween_interval(maxf(grenade_delay, 0.08) + 0.035)
	jaw_tween.tween_callback(Callable(self, "_resolve_constellation_second_jaw").bind(owner_node.get_instance_id(), start, finish, direction, jaw_width, ratio))
	return result


func _resolve_constellation_second_jaw(owner_id: int, start: Vector2, finish: Vector2, direction: Vector2, jaw_width: float, damage_ratio: float) -> void:
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node) or _effects_shutdown:
		return
	var jaw := AttackVfx.beam(_projectile_parent(), start, finish, maxf(jaw_width * 0.36, beam_width), Color(visual_color.r, visual_color.g, visual_color.b, 0.72))
	_register_effect(jaw)
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	var base_damage := _rolled_damage(owner_node) * damage_ratio
	for enemy in TARGET_QUERY.enemies(self):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var offset := enemy_node.global_position - start
		var forward := offset.dot(direction)
		if forward < -CONTACT_STUCK_HIT_BACK_ALLOWANCE or forward > start.distance_to(finish):
			continue
		if absf(offset.dot(perpendicular)) > jaw_width * 0.5:
			continue
		_damage_enemy(enemy_node, base_damage)


func constellation_second_jaw_preview(corridor_width: float) -> Dictionary:
	return {"jaw_count": 1, "jaw_width": maxf(corridor_width * 0.46, beam_width), "damage_ratio": 0.42}
