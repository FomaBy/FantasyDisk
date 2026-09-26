extends SceneTree

# FAN-3934 read-only diagnostic: measures the marginal OBJECT_COUNT cost of one
# riftling-summon enemy instance (the P3 allocation owner candidate) in
# isolation, plus the effect of removing its per-instance extras at runtime
# (health bar node, ground circle, full-frame body) — all via runtime node
# removal, no production edits.

const BATCH := 8

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0]) if args.size() > 0 else "plain"
	var scene_path := "res://scenes/EnemyBiter.tscn"
	var scene: PackedScene = load(scene_path)
	await process_frame
	var base := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var base_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	var spawned: Array[Node] = []
	for i in range(BATCH):
		var enemy := scene.instantiate()
		holder.add_child(enemy)
		spawned.append(enemy)
	await create_timer(1.0).timeout
	var with_enemies := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes_with := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var per_enemy_objects := float(with_enemies - base) / float(BATCH)
	var per_enemy_nodes := float(nodes_with - base_nodes) / float(BATCH)
	var result := {
		"scene": scene_path,
		"mode": mode,
		"batch": BATCH,
		"base_objects": base,
		"base_nodes": base_nodes,
		"with_enemies_objects": with_enemies,
		"with_enemies_nodes": nodes_with,
		"per_enemy_objects": per_enemy_objects,
		"per_enemy_nodes": per_enemy_nodes,
		"per_enemy_non_node": per_enemy_objects - per_enemy_nodes,
	}
	if mode == "stripped":
		for enemy in spawned:
			for extra in ["HealthBar", "GroundCircle", "FullFrameBody", "Body"]:
				var child := enemy.get_node_or_null(extra)
				if child != null:
					child.queue_free()
		await process_frame
		await process_frame
		var stripped := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var nodes_stripped := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		result["stripped_objects"] = stripped
		result["stripped_nodes"] = nodes_stripped
		result["per_enemy_stripped_objects"] = float(stripped - base) / float(BATCH)
		result["per_enemy_stripped_non_node"] = float(stripped - base - (nodes_stripped - base_nodes)) / float(BATCH)
	print("FAN3934_PER_ENEMY_RESULT " + JSON.stringify(result))
	quit(0)

func _fail(reason: String) -> void:
	printerr("FAN3934_PER_ENEMY_ERROR: " + reason)
	quit(1)
