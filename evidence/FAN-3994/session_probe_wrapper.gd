extends Node

## FAN-3994 fallback launcher for `tools/ultimate_session_lifecycle_probe.gd`
## inside the installed release app. The probe extends SceneTree (the editor
## gate starts it with `--script`, which official export templates refuse), so
## when `application/run/main_loop_type` cannot name a script this wrapper —
## the override.cfg main scene — installs the probe script on the live
## SceneTree and starts it. User argument after `--`: --probe=<absolute .gd>.


func _ready() -> void:
	var probe_path := ""
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--probe="):
			probe_path = arg.trim_prefix("--probe=")
	if probe_path.is_empty():
		push_error("session_probe_wrapper: --probe=<absolute path> is required")
		get_tree().quit(2)
		return
	var script := load(probe_path) as Script
	if script == null:
		push_error("session_probe_wrapper: cannot load %s" % probe_path)
		get_tree().quit(2)
		return
	var tree := get_tree()
	tree.set_script(script)
	print("session_probe_wrapper: installed %s on %s (exe %s)" % [probe_path, tree, OS.get_executable_path()])
	tree.call_deferred("_initialize")
