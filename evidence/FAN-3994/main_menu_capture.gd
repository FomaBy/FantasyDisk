extends Node2D

## FAN-3994: screenshot of the installed app's real main menu (the shipped
## `res://scenes/Main.tscn` as the game starts it) to record the version
## label the player sees. Launched the FAN-3985 way (override.cfg main scene
## in an ad-hoc resealed clone of the installed app, isolated user dir).
## User arguments after `--`: --capture=<absolute png path> [--frames=<n>]

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

var _capture := ""
var _frames := 120


func _ready() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	if _capture.is_empty():
		return
	await get_tree().process_frame
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for _i in range(30):
		await get_tree().process_frame
	# The shipped path: Main._ready() -> ui._show_main_menu(). Call it again
	# explicitly so the capture is the main menu whatever screen the profile
	# state opened first.
	var ui = main.get("ui")
	if ui != null and ui.has_method("_show_main_menu"):
		ui.call("_show_main_menu")
	for _i in range(_frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var ok := image != null and image.save_png(_capture) == OK
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var labels: Array[String] = []
	_collect_version_labels(main, version, labels)
	print("main_menu_capture: saved=%s version=%s executable=%s labels=%s" % [ok, version, OS.get_executable_path(), labels])
	get_tree().quit(0 if ok and not labels.is_empty() else 1)


func _collect_version_labels(node: Node, version: String, out: Array[String]) -> void:
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text.contains(version):
		out.append("%s: %s" % [node.get_path(), (node as Label).text])
	for child in node.get_children():
		_collect_version_labels(child, version, out)
