extends SceneTree

# FAN-3934 bounded diagnosis: print the runtime vsync/max-fps state and a
# 3-second wall-clock FPS sample, to compare baseline-base vs dev-base
# conditions under identical probes.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var vsync := DisplayServer.window_get_vsync_mode()
	var info := {
		"vsync_mode": vsync,
		"max_fps_engine": Engine.max_fps,
		"display_server": DisplayServer.get_name(),
		"window_size": DisplayServer.window_get_size(),
	}
	var started := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - started < 3000000:
		await process_frame
		frames += 1
	info["wall_fps"] = frames / 3.0
	print("FAN3934_VSYNC " + JSON.stringify(info))
	quit(0)
