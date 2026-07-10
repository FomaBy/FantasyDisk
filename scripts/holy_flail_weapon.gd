class_name HolyFlailWeapon
extends "res://scripts/berserk_weapon.gd"

## Scene-specific Animator bridge for SCRUM-924. The inherited BerserkWeapon
## remains the sole owner of spiral damage, timing, geometry and deduplication.

const SPIRAL_VFX_SCENE := preload("res://scenes/vfx/HolyFlailSpiralVfx.tscn")

var _spiral_vfx: HolyFlailSpiralVfx = null


func _show_spiral_step_area(owner_node: Node2D, arm_angle: float, front_radius: float) -> void:
	# Preserve the exact SCRUM-923 hit-zone overlay and baseline combat feedback.
	super._show_spiral_step_area(owner_node, arm_angle, front_radius)
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var full_radius := _effective_circle_radius()
	var start_radius := full_radius * clampf(spiral_start_radius_ratio, 0.05, 1.0)
	var denominator := maxf(full_radius - start_radius, 0.001)
	var normalized_progress := clampf((front_radius - start_radius) / denominator, 0.0, 1.0)
	var step_index := clampi(int(round(normalized_progress * float(spiral_steps))) - 1, 0, spiral_steps - 1)
	if _spiral_vfx == null or not is_instance_valid(_spiral_vfx) or step_index == 0:
		if _spiral_vfx != null and is_instance_valid(_spiral_vfx):
			_spiral_vfx.queue_free()
		_spiral_vfx = SPIRAL_VFX_SCENE.instantiate() as HolyFlailSpiralVfx
		if _spiral_vfx == null:
			return
		var scene := get_tree().current_scene
		if scene == null:
			scene = get_tree().root
		scene.add_child(_spiral_vfx)
	_spiral_vfx.apply_step(
		owner_node.global_position,
		arm_angle,
		front_radius,
		full_radius,
		step_index,
		visual_color
	)
