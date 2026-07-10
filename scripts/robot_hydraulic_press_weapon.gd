class_name RobotHydraulicPressWeapon
extends "res://scripts/class_weapon.gd"

## Scene-specific Animator bridge for SCRUM-917. The inherited ClassWeapon
## remains the sole owner of hit geometry, damage and compression displacement.

const COMPRESSION_VFX_SCENE := preload("res://scenes/vfx/RobotHydraulicPressCompressionVfx.tscn")


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
