extends SceneTree

# FAN-3934 read-only diagnostic (round-3 grant): measures the retained-object
# cost of the eagerly loaded weapon-ultimate executor scripts and the effect of
# lazy residency on cold activation.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_dir := "res://data/ultimates/schema/v1/packages"
	var executor_root := "res://scripts/ultimates/executors/packages"
	var dirs := [executor_root]
	# Discover the actual executor root from the discovery script's constants.
	var discovery := load("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
	var instance = discovery.new()
	for prop in ["DATA_ROOT", "EXECUTOR_ROOT"]:
		if instance.get(prop) != null:
			print("FAN3934_RESIDENCY ", prop, "=", instance.get(prop))
	DirAccess.open("res://").list_dir_begin()
	DirAccess.open("res://").list_dir_end()
	var exec_root := str(instance.get("EXECUTOR_ROOT"))
	var files: Array = []
	_collect(exec_root, ".gd", files)
	await process_frame
	var base := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var scripts: Array = []
	for path in files:
		if String(path).get_file() == "_readme.gd" or String(path).contains("/_"):
			continue
		var script = load(String(path))
		if script != null:
			scripts.append(script)
	await process_frame
	await process_frame
	var loaded := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var result := {
		"executor_files": files.size(),
		"scripts_loaded": scripts.size(),
		"base_objects": base,
		"after_load_objects": loaded,
		"retained_objects": loaded - base,
		"per_script": float(loaded - base) / float(maxi(scripts.size(), 1)),
	}
	# Keep a strong reference so nothing is collected before we measure.
	result["reference_held"] = scripts.size()
	print("FAN3934_RESIDENCY_RESULT " + JSON.stringify(result))
	quit(0)

func _collect(dir_path: String, suffix: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_collect(path, suffix, out)
		elif name.ends_with(suffix):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
