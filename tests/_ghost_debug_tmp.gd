extends SceneTree

func _initialize() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate()
	holder.add_child(enemy)
	enemy.call("_update_movement_animation", 0.1)
	var rig: Node = enemy.get_node_or_null("RigRoot")
	print("rig=", rig, " inside_tree=", rig != null and rig.is_inside_tree())
	enemy.call("take_damage", 9999.0)
	print("holder children: ", holder.get_children())
	quit(0)
