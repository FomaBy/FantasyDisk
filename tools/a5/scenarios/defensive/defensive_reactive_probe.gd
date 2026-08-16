extends SceneTree

# Usage: python3 tools/godot_gate.py --headless --path . --script \
#   res://tools/a5/scenarios/defensive/defensive_reactive_probe.gd

const Pack := preload("res://tools/a5/scenarios/defensive/defensive_family_pack.gd")
const Runtime := preload("res://tools/a5/scenarios/defensive/defensive_runtime.gd")


func _initialize() -> void:
	await process_frame
	var fragment := Runtime.run(root)
	var verdict := Pack.evaluate_fragment(fragment)
	fragment["verdict"] = "green" if bool(verdict.get("ok", false)) else "red"
	if not bool(verdict.get("ok", false)):
		for error_value in verdict.get("errors", []):
			push_error("FAN-1514: %s" % error_value)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Pack.FRAGMENT_DIR))
	var file := FileAccess.open(Pack.FRAGMENT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("FAN-1514 cannot write %s" % Pack.FRAGMENT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(fragment, "\t", true, true) + "\n")
	file.close()
	print("FAN-1514 defensive/reactive probe passed; fragment written.")
	quit(0)
