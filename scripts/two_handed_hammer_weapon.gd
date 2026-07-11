class_name TwoHandedHammerWeapon
extends "res://scripts/berserk_weapon.gd"

const HAMMER_VFX_SCENE := preload("res://scenes/vfx/BerserkHammerSlamVfx.tscn")


func _show_circle_area(owner_node: Node2D) -> void:
	if owner_node == null or not is_instance_valid(owner_node): return
	var center := owner_node.global_position
	var visual_scale := Vector2.ONE
	# SCRUM-1043 backend may expose these protected geometry hooks. Fallbacks
	# preserve current runtime until that independently-owned fix lands.
	if has_method("_circle_attack_center"):
		center = call("_circle_attack_center", owner_node)
	if has_method("_circle_attack_visual_scale"):
		visual_scale = call("_circle_attack_visual_scale")
	var effect := HAMMER_VFX_SCENE.instantiate() as BerserkHammerSlamVfx
	if effect == null: return
	var scene := get_tree().current_scene
	if scene == null: scene = get_tree().root
	scene.add_child(effect)
	effect.configure(center, _effective_circle_radius(), visual_scale, visual_color)
