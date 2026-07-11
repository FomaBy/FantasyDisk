class_name TwoHandedAxeWeapon
extends "res://scripts/berserk_weapon.gd"

const AXE_VFX_SCENE := preload("res://scenes/vfx/BerserkAxeCleaveVfx.tscn")


func _show_sweep_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	# Keep the accepted sweep feedback and all shared hit geometry unchanged.
	super._show_sweep_area(owner_node, attack_direction)
	if owner_node == null or not is_instance_valid(owner_node): return
	var effect := AXE_VFX_SCENE.instantiate() as BerserkAxeCleaveVfx
	if effect == null: return
	var scene := get_tree().current_scene
	if scene == null: scene = get_tree().root
	scene.add_child(effect)
	effect.configure(owner_node.global_position, attack_direction, attack_range, sweep_degrees, windup_time + swing_time, visual_color)
