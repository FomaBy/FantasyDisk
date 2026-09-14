extends SceneTree

# FAN-3934 read-only diagnostic (round-4): measures the retained-object cost of
# each enemy kind's full-frame SpriteFrames set. Random initial-enemy
# composition in the P3 contour loads a random subset of these once per run;
# this quantifies how much variance each kind contributes. No seeds are used in
# acceptance runs; this is a task-owned cost table only.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rows := []
	var dir := DirAccess.open("res://data/animation/enemy")
	var files := DirAccess.get_files_at("res://data/animation/enemy")
	files.sort()
	await process_frame
	var base := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for file_name in files:
		if not String(file_name).ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/enemy/" + file_name))
		if not parsed is Dictionary:
			continue
		var frames_path := str((parsed as Dictionary).get("frames", ""))
		if frames_path == "" or not ResourceLoader.exists(frames_path):
			rows.append({"kind": String(file_name).get_basename(), "frames": frames_path, "delta": -1})
			continue
		var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var frames: SpriteFrames = load(frames_path)
		await process_frame
		var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var animations := 0
		var total_frames := 0
		if frames != null:
			for animation in frames.get_animation_names():
				animations += 1
				total_frames += int(frames.get_frame_count(animation))
		rows.append({
			"kind": String(file_name).get_basename(),
			"frames": frames_path,
			"delta": after - before,
			"animations": animations,
			"frames_count": total_frames,
		})
	var summary := {
		"base_objects": base,
		"final_objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"total_delta_all_enemy_kinds": int(Performance.get_monitor(Performance.OBJECT_COUNT)) - base,
		"per_kind": rows,
	}
	DirAccess.make_dir_recursive_absolute("res://evidence/p3-object-budget-rework/round4")
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/round4/enemy_frames_cost.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "  ") + "\n")
	f.close()
	for row in rows:
		print("FAN3934_KIND_COST %s delta=%d anims=%d frames=%d" % [row["kind"], row["delta"], row.get("animations", -1), row.get("frames_count", -1)])
	quit(0)
