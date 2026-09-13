extends SceneTree

# FAN-3934 causal diagnostic: controlled FullFrameBody consumer lifecycle.
# Steps: baseline, first consumer (kind A), second same-kind consumer,
# additional kind (B), release one A, release last A (B held), release B.
# Marginal OBJECT_COUNT recorded at each step; frame instance IDs prove
# sharing. Task-owned diagnostic; not the acceptance workload.

const BITER := "res://scenes/EnemyBiter.tscn"      # kind A (small_biter)
const SHIELD := "res://scenes/EnemyShieldbearer.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var shield_path := SHIELD
	if not ResourceLoader.exists(shield_path):
		var candidates: Array = []
		_collect("res://scenes", "EnemyShield", candidates)
		if candidates.is_empty():
			_collect("res://scenes", "Shieldbearer", candidates)
		if candidates.is_empty():
			printerr("FAN3934_LIFECYCLE_ERROR: no shieldbearer scene")
			quit(1)
			return
		shield_path = candidates[0]
	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	var steps: Array[Dictionary] = []
	var step := func(label: String) -> void:
		await process_frame
		await process_frame
		steps.append({"step": label, "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))})
	var frames_of := func(enemy: Node) -> Dictionary:
		var body = enemy.get_node_or_null("FullFrameBody")
		if body == null: return {}
		var frames = body.get("sprite_frames")
		return {"path": str(frames.resource_path), "instance": frames.get_instance_id()} if frames != null else {}
	await step.call("baseline")
	var a1: Node = load("res://scenes/EnemyBiter.tscn").instantiate()
	holder.add_child(a1)
	await step.call("first consumer kind A (small_biter)")
	var f1: Dictionary = frames_of.call(a1)
	var a2: Node = load("res://scenes/EnemyBiter.tscn").instantiate()
	holder.add_child(a2)
	await step.call("second same-kind consumer A")
	var f2: Dictionary = frames_of.call(a2)
	var b1: Node = load(shield_path).instantiate()
	holder.add_child(b1)
	await step.call("additional kind B (shieldbearer)")
	var f3: Dictionary = frames_of.call(b1)
	a1.queue_free()
	await step.call("release one A (A2 still live)")
	a2.queue_free()
	await step.call("release last A (B still live)")
	b1.queue_free()
	await step.call("release last B")
	var report := {
		"kind": "consumer-lifecycle-diagnostic",
		"candidate_sha": _git("HEAD"),
		"frames": {"a1": f1, "a2": f2, "b1": f3},
		"a1_instance_equals_a2": f1.get("instance", 0) == f2.get("instance", 1),
		"steps": steps,
	}
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/frame-residency-causal/lifecycle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ") + "\n")
	f.close()
	print("FAN3934_LIFECYCLE_DONE")
	quit(0)

func _collect(dir_path: String, needle: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null: return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_collect(path, needle, out)
		elif name.ends_with(".tscn") and name.contains(needle):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()

func _git(rev: String) -> String:
	var output: Array = []
	if OS.execute("git", ["rev-parse", rev], output, true) != 0 or output.is_empty():
		return "unavailable"
	return String(output[0]).strip_edges()
