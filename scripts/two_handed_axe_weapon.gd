class_name TwoHandedAxeWeapon
extends "res://scripts/berserk_weapon.gd"

const AXE_VFX_SCENE := preload("res://scenes/vfx/BerserkAxeCleaveVfx.tscn")

# FAN-3934: bounded cleave reuse — один переиспользуемый экземпляр эффекта вместо
# instantiate на каждый взмах. Если прошлый ещё занят (каденция быстрее длительности),
# создаём одноразовый, как раньше: ни один взмах не теряет визуал.
var _cleave_effect: BerserkAxeCleaveVfx


func _show_sweep_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	# Keep the accepted sweep feedback and all shared hit geometry unchanged.
	super._show_sweep_area(owner_node, attack_direction)
	if owner_node == null or not is_instance_valid(owner_node): return
	var effect: BerserkAxeCleaveVfx = null
	if is_instance_valid(_cleave_effect) and not _cleave_effect.is_queued_for_deletion() and not _cleave_effect.is_busy():
		effect = _cleave_effect
	else:
		effect = AXE_VFX_SCENE.instantiate() as BerserkAxeCleaveVfx
		if effect == null: return
		var scene := get_tree().current_scene
		if scene == null: scene = get_tree().root
		scene.add_child(effect)
		_cleave_effect = effect
	effect.configure(owner_node.global_position, attack_direction, attack_range, sweep_degrees, windup_time + swing_time, visual_color)
