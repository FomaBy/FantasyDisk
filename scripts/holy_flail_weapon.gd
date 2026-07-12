class_name HolyFlailWeapon
extends "res://scripts/berserk_weapon.gd"

## Scene-specific Animator bridge for SCRUM-924. The inherited BerserkWeapon
## remains the sole owner of spiral damage, timing, geometry and deduplication.

const SPIRAL_VFX_SCENE := preload("res://scenes/vfx/HolyFlailSpiralVfx.tscn")
const HOLY_FLAIL_CONSTELLATION_FINAL_MECHANICS := {"flail_return_control_pulse": "return"}

var _spiral_vfx: HolyFlailSpiralVfx = null


func _finish_swing() -> void:
	# The head has completed its out-and-back lifecycle at this exact callback.
	# Resolve at most one return pulse before the inherited swing state is reset.
	constellation_return_pulse()
	super._finish_swing()


func constellation_return_pulse() -> Dictionary:
	var owner_node := _owner_node()
	var mechanic := _constellation_mechanic(owner_node, "flail_return_control_pulse")
	if owner_node == null or mechanic.is_empty():
		return {"triggered": false}
	var result := _constellation_event(owner_node, "return", {"pulses_this_attack": 1})
	if not bool(result.get("triggered", false)):
		return result
	var params: Dictionary = mechanic.get("params", {})
	var ratio := clampf(float(params.get("pulse_damage_ratio", 0.38)), 0.0, 1.0)
	var control_seconds := maxf(float(params.get("stagger_seconds", 0.55)), 0.0)
	var radius := _effective_circle_radius() * 0.62
	AttackVfx.ring_pulse(get_tree().current_scene if get_tree().current_scene != null else get_tree().root, owner_node.global_position, radius, Color(0.88, 0.92, 1.0, 0.38), false)
	var pulse_damage := _rolled_damage(owner_node) * ratio
	for enemy in TARGET_QUERY.in_radius(self, owner_node.global_position, radius):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		_call_take_damage(enemy_node, pulse_damage, {"damage_type": "physical", "constellation_final": "flail_return_control_pulse"})
		var boss_factor := clampf(float(params.get("boss_factor", 0.25)), 0.0, 1.0) if TARGET_QUERY.is_epic_displacement_immune(enemy_node) else 1.0
		StatusEffects.apply_status(enemy_node, "constellation_flail_return_stagger", {"duration": control_seconds * boss_factor, "speed_multiplier": 0.78, "marker_color": Color(0.88, 0.92, 1.0, 1.0)})
	return result


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
