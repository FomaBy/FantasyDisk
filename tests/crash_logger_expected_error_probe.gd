extends SceneTree

const CrashLoggerScript := preload("res://scripts/crash_logger.gd")
const EXPECTED_ERROR := "FAN-3905 deterministic expected-error probe"
const OUTPUT_PREFIX := "--crash-logger-output="

var _service: Node
var _output_path := ""


func _init() -> void:
	_output_path = _output_directory()
	if _output_path.is_empty():
		print("CRASH_LOGGER_EXPECTED_ERROR_PROBE_FAILED missing output directory")
		quit(2)
		return
	call_deferred("_start_probe")


func _start_probe() -> void:
	_service = root.get_node_or_null("CrashLogger")
	if _service == null:
		_service = CrashLoggerScript.new()
		root.add_child(_service)
	if not _service.configure_output_directory_for_tests(_output_path):
		print("CRASH_LOGGER_EXPECTED_ERROR_PROBE_FAILED output directory rejected")
		quit(2)
		return
	_run_probe()


func _run_probe() -> void:
	_expected_error_parent()
	await process_frame
	await process_frame
	var incident_path: String = _service.last_incident_path_for_tests()
	if incident_path.is_empty():
		print("CRASH_LOGGER_EXPECTED_ERROR_PROBE_FAILED no incident")
		quit(2)
		return
	if not _incident_has_expected_stack(incident_path):
		print("CRASH_LOGGER_EXPECTED_ERROR_PROBE_FAILED missing meaningful stack")
		quit(2)
		return
	print("CRASH_LOGGER_EXPECTED_ERROR_PROBE incident=%s" % incident_path)
	quit(0)


func _incident_has_expected_stack(incident_path: String) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(incident_path))
	if not parsed is Dictionary:
		return false
	var functions := {}
	var meaningful_frames := 0
	var backtrace: Dictionary = (parsed as Dictionary).get("script_backtrace", {})
	for trace_value in backtrace.get("traces", []):
		var trace: Dictionary = trace_value
		for frame_value in trace.get("frames", []):
			var frame: Dictionary = frame_value
			if not str(frame.get("file", "")).begins_with("res://"):
				continue
			meaningful_frames += 1
			functions[str(frame.get("function", ""))] = true
	return meaningful_frames >= 2 \
		and functions.has("_expected_error_leaf") \
		and functions.has("_expected_error_parent")


func _expected_error_parent() -> void:
	_expected_error_leaf()


func _expected_error_leaf() -> void:
	push_error(EXPECTED_ERROR)


func _output_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			return argument.trim_prefix(OUTPUT_PREFIX).strip_edges()
	return ""
