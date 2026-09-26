extends SceneTree

# FAN-3934 read-only diagnostic: per-subtree marginal object cost of one
# EnemyBiter (boss riftling summon) instance. Frees exactly one child subtree
# per run and reports the OBJECT_COUNT delta, attributing the ~47 non-node
# objects per enemy to a concrete owner.

const BATCH := 8
const SCENE_PATH := "res://scenes/EnemyBiter.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var target := String(args[0])
	var scene: PackedScene = load(SCENE_PATH)
	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	var spawned: Array[Node] = []
	for i in range(BATCH):
		var enemy := scene.instantiate()
		holder.add_child(enemy)
		spawned.append(enemy)
	await create_timer(1.0).timeout
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var before_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var freed := 0
	for enemy in spawned:
		var child := enemy.get_node_or_null(target)
		if child != null:
			child.queue_free()
			freed += 1
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var after_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("FAN3934_SUBTREE_RESULT " + JSON.stringify({
		"target": target, "freed": freed,
		"objects_before": before, "objects_after": after,
		"delta_objects": before - after,
		"delta_nodes": before_nodes - after_nodes,
		"per_instance_objects": float(before - after) / float(maxi(freed, 1)),
		"per_instance_non_node": float(before - after - (before_nodes - after_nodes)) / float(maxi(freed, 1)),
	}))
	quit(0)
