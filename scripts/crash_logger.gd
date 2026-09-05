extends Node

const INCIDENT_DIRECTORY := "user://logs/incidents"
const INCIDENT_PREFIX := "incident_"
const INCIDENT_SUFFIX := ".json"
const TEMP_SUFFIX := ".tmp"
const MAX_BREADCRUMBS := 50
const MAX_PENDING_INCIDENTS := 64
const MAX_INCIDENTS := 20
const MAX_RETAINED_BYTES := 1024 * 1024
const MAX_RECORD_BYTES := 64 * 1024
const MAX_ERROR_TEXT_CHARS := 4096
const MAX_ERROR_FIELD_CHARS := 2048
const MAX_BACKTRACE_FRAMES := 64
const MAX_BREADCRUMB_FIELD_CHARS := 96
const DEBUG_SELF_TEST_FLAG := "--crash-logger-self-test"
const DEBUG_OUTPUT_PREFIX := "--crash-logger-output="
const SELF_TEST_ERROR := "FAN-3905 deterministic crash logger self-test"


class IncidentSink:
	extends Logger

	var _mutex := Mutex.new()
	var _redaction_mutex := Mutex.new()
	var _breadcrumbs: Array[Dictionary] = []
	var _pending: Array[Dictionary] = []
	var _suppressed_thread_id := 0
	var _dropped_pending := 0
	var _authorization_pattern: RegEx
	var _bearer_pattern: RegEx
	var _credential_pattern: RegEx
	var _home_path_pattern: RegEx


	func _init() -> void:
		_authorization_pattern = RegEx.create_from_string(
			r"(?i)(\bauthorization\s*[:=]\s*)(?:bearer\s+)?(?:\"[^\"]*\"|'[^']*'|[^\s,;}\]]+)"
		)
		_bearer_pattern = RegEx.create_from_string(
			r"(?i)(\bbearer\s+)(?:\"[^\"]*\"|'[^']*'|[^\s,;}\]]+)"
		)
		_credential_pattern = RegEx.create_from_string(
			r"(?i)((?:^|[\s{,])[\"']?(?:password|passwd|token|secret|api[_-]?key)[\"']?\s*[:=]\s*)(?:\"[^\"]*\"|'[^']*'|[^\s,;}\]]+)"
		)
		_home_path_pattern = RegEx.create_from_string(
			r"(?i)([A-Z]:[\\/][^\s]+|/(Users|home)/[^\s]+)"
		)


	func _log_message(_message: String, _error: bool) -> void:
		# Raw stderr/print messages do not carry structured engine error identity.
		# Capturing them would duplicate _log_error and turn printerr() into incidents.
		pass


	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		editor_notify: bool,
		error_type: int,
		script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		var record := {
			"error": {
				"type": _error_type_name(error_type),
				"text": _error_text(code, rationale),
				"function": _bounded(_redact(function), MAX_BREADCRUMB_FIELD_CHARS),
				"file": _safe_source_path(file),
				"line": maxi(line, 0),
				"code": _bounded(_redact(code), MAX_ERROR_FIELD_CHARS),
				"rationale": _bounded(_redact(rationale), MAX_ERROR_FIELD_CHARS),
				"editor_notify": editor_notify,
			},
			"script_backtrace": _serialize_backtraces(script_backtraces),
		}
		_enqueue(record)


	func record_breadcrumb(class_id: String, weapon_id: String, event: String, frame: int) -> void:
		var breadcrumb := {
			"class": _bounded(_redact(class_id), MAX_BREADCRUMB_FIELD_CHARS),
			"weapon": _bounded(_redact(weapon_id), MAX_BREADCRUMB_FIELD_CHARS),
			"event": _bounded(_redact(event), MAX_BREADCRUMB_FIELD_CHARS),
			"frame": maxi(frame, 0),
		}
		_mutex.lock()
		_breadcrumbs.append(breadcrumb)
		while _breadcrumbs.size() > MAX_BREADCRUMBS:
			_breadcrumbs.pop_front()
		_mutex.unlock()


	func capture_for_test(
		error_text: String,
		frames: Array[Dictionary],
		code := "",
		rationale := "",
	) -> void:
		var safe_frames: Array[Dictionary] = []
		for raw_frame in frames.slice(0, MAX_BACKTRACE_FRAMES):
			var frame: Dictionary = raw_frame
			safe_frames.append({
				"file": _safe_source_path(str(frame.get("file", ""))),
				"function": _bounded(_redact(str(frame.get("function", ""))), MAX_BREADCRUMB_FIELD_CHARS),
				"line": maxi(int(frame.get("line", 0)), 0),
			})
		var traces: Array[Dictionary] = []
		if not safe_frames.is_empty():
			traces.append({"language": "GDScript", "frames": safe_frames})
		_enqueue({
			"error": {
				"type": "script",
				"text": _bounded(_redact(error_text), MAX_ERROR_TEXT_CHARS),
				"function": "capture_for_test",
				"file": "res://tests/crash_logger_test.gd",
				"line": 0,
				"code": _bounded(_redact(code if not code.is_empty() else error_text), MAX_ERROR_FIELD_CHARS),
				"rationale": _bounded(_redact(rationale), MAX_ERROR_FIELD_CHARS),
				"editor_notify": false,
			},
			"script_backtrace": _backtrace_payload(traces),
		})


	func take_pending() -> Array[Dictionary]:
		_mutex.lock()
		var result: Array[Dictionary] = _pending.duplicate(true)
		_pending.clear()
		_mutex.unlock()
		return result


	func breadcrumb_snapshot() -> Array[Dictionary]:
		_mutex.lock()
		var result: Array[Dictionary] = _breadcrumbs.duplicate(true)
		_mutex.unlock()
		return result


	func clear_breadcrumbs() -> void:
		_mutex.lock()
		_breadcrumbs.clear()
		_mutex.unlock()


	func set_capture_suppressed(value: bool) -> void:
		_mutex.lock()
		_suppressed_thread_id = OS.get_thread_caller_id() if value else 0
		_mutex.unlock()


	func _enqueue(record: Dictionary) -> void:
		_mutex.lock()
		if _suppressed_thread_id == OS.get_thread_caller_id():
			_mutex.unlock()
			return
		record["breadcrumbs"] = _breadcrumbs.duplicate(true)
		if _pending.size() >= MAX_PENDING_INCIDENTS:
			_pending.pop_front()
			_dropped_pending += 1
		if _dropped_pending > 0:
			record["dropped_pending_before"] = _dropped_pending
			_dropped_pending = 0
		_pending.append(record)
		_mutex.unlock()


	func _serialize_backtraces(script_backtraces: Array[ScriptBacktrace]) -> Dictionary:
		var traces: Array[Dictionary] = []
		var remaining := MAX_BACKTRACE_FRAMES
		for backtrace in script_backtraces:
			if backtrace == null or backtrace.is_empty() or remaining <= 0:
				continue
			var frames: Array[Dictionary] = []
			var frame_count := mini(backtrace.get_frame_count(), remaining)
			for index in range(frame_count):
				frames.append({
					"file": _safe_source_path(backtrace.get_frame_file(index)),
					"function": _bounded(
						_redact(backtrace.get_frame_function(index)),
						MAX_BREADCRUMB_FIELD_CHARS,
					),
					"line": maxi(backtrace.get_frame_line(index), 0),
				})
			remaining -= frames.size()
			if not frames.is_empty():
				traces.append({
					"language": _bounded(backtrace.get_language_name(), 32),
					"frames": frames,
				})
		return _backtrace_payload(traces)


	func _backtrace_payload(traces: Array[Dictionary]) -> Dictionary:
		if traces.is_empty():
			return {
				"available": false,
				"status": "unavailable: engine callback supplied no script frames",
				"traces": [],
			}
		return {"available": true, "status": "captured", "traces": traces}


	func _error_text(code: String, rationale: String) -> String:
		var parts: Array[String] = []
		if not code.strip_edges().is_empty():
			parts.append(code.strip_edges())
		if not rationale.strip_edges().is_empty() and rationale.strip_edges() != code.strip_edges():
			parts.append(rationale.strip_edges())
		return _bounded(_redact(" — ".join(parts)), MAX_ERROR_TEXT_CHARS)


	func _redact(value: String) -> String:
		_redaction_mutex.lock()
		var result := value
		if _authorization_pattern != null:
			result = _authorization_pattern.sub(result, "$1<redacted>", true)
		if _bearer_pattern != null:
			result = _bearer_pattern.sub(result, "$1<redacted>", true)
		if _credential_pattern != null:
			result = _credential_pattern.sub(result, "$1<redacted>", true)
		if _home_path_pattern != null:
			result = _home_path_pattern.sub(result, "<redacted-path>", true)
		_redaction_mutex.unlock()
		return result


	static func _safe_source_path(value: String) -> String:
		var normalized := value.replace("\\", "/")
		if normalized.begins_with("res://") or normalized.begins_with("user://"):
			return _bounded(normalized, 256)
		return "<external>" if not normalized.is_empty() else ""


	static func _bounded(value: String, limit: int) -> String:
		if value.length() <= limit:
			return value
		return value.substr(0, maxi(limit - 1, 0)) + "…"


	static func _error_type_name(error_type: int) -> String:
		match error_type:
			Logger.ERROR_TYPE_SCRIPT:
				return "script"
			Logger.ERROR_TYPE_SHADER:
				return "shader"
			_:
				return "engine"


var _sink: IncidentSink
var _output_directory := INCIDENT_DIRECTORY
var _last_incident_path := ""
var _sequence := 0
var _build_identity_cache: Dictionary = {}


func _ready() -> void:
	_output_directory = _debug_output_directory()
	_prepare_output_directory()
	_sink = IncidentSink.new()
	OS.add_logger(_sink)
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group("player"):
		_watch_player(node)
	if OS.is_debug_build() and OS.get_cmdline_user_args().has(DEBUG_SELF_TEST_FLAG):
		call_deferred("_run_debug_self_test")


func _process(_delta: float) -> void:
	_flush_pending()


func _exit_tree() -> void:
	if _sink != null:
		_flush_pending()
		OS.remove_logger(_sink)


func _on_node_added(node: Node) -> void:
	_watch_player(node)


func _watch_player(node: Node) -> void:
	if not node.has_signal("weapon_cast_observed") or not node.has_signal("weapon_animation_event"):
		return
	var cast_callback := _on_weapon_cast_observed.bind(node)
	if not node.is_connected("weapon_cast_observed", cast_callback):
		node.connect("weapon_cast_observed", cast_callback)
	var animation_callback := _on_weapon_animation_event.bind(node)
	if not node.is_connected("weapon_animation_event", animation_callback):
		node.connect("weapon_animation_event", animation_callback)


func _on_weapon_cast_observed(event: Dictionary, player: Node) -> void:
	if _skip_non_combat_player(player):
		return
	_record_combat_breadcrumb(
		str(player.get("character_id")),
		str(event.get("weapon_id", player.get("weapon_id"))),
		"activation:%s" % str(event.get("phase", "observed")),
	)


func _on_weapon_animation_event(event: Dictionary, player: Node) -> void:
	if _skip_non_combat_player(player):
		return
	var phase := str(event.get("phase", "observed"))
	var event_name := "finish:%s" % phase if phase == "release" else "phase:%s" % phase
	_record_combat_breadcrumb(
		str(event.get("character_id", player.get("character_id"))),
		str(event.get("weapon_id", player.get("weapon_id"))),
		event_name,
	)


func _skip_non_combat_player(player: Node) -> bool:
	return player == null or not is_instance_valid(player) \
		or str(player.get_meta("player_lifecycle_role", "")) == "menu_snapshot"


func _record_combat_breadcrumb(class_id: String, weapon_id: String, event: String) -> void:
	if _sink != null:
		_sink.record_breadcrumb(class_id, weapon_id, event, Engine.get_process_frames())


func _flush_pending() -> void:
	if _sink == null:
		return
	var pending := _sink.take_pending()
	for record in pending:
		_write_incident(record)


func _write_incident(record: Dictionary) -> void:
	_sink.set_capture_suppressed(true)
	var path := _write_incident_suppressed(record)
	_sink.set_capture_suppressed(false)
	if not path.is_empty():
		_last_incident_path = path


func _write_incident_suppressed(record: Dictionary) -> String:
	if not _prepare_output_directory():
		return ""
	var enriched := record.duplicate(true)
	enriched["schema_version"] = 1
	enriched["timestamp_utc"] = Time.get_datetime_string_from_system(true, true) + "Z"
	enriched["build_version"] = str(ProjectSettings.get_setting("application/config/version", "unknown"))
	var identity := _build_identity()
	for key in identity:
		enriched[key] = identity[key]
	var payload := _bounded_record_payload(enriched)
	if payload.is_empty():
		return ""
	_rotate_for(payload.size())
	var timestamp := str(enriched["timestamp_utc"]).replace(":", "-")
	var final_path := ""
	while final_path.is_empty() or FileAccess.file_exists(final_path):
		_sequence += 1
		var filename := "%s%s_%06d%s" % [INCIDENT_PREFIX, timestamp, _sequence, INCIDENT_SUFFIX]
		final_path = _path_join(_output_directory, filename)
	var temp_path := final_path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(payload)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return ""
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(final_path),
	)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return ""
	return ProjectSettings.globalize_path(final_path)


func _bounded_record_payload(record: Dictionary) -> PackedByteArray:
	var payload := JSON.stringify(record).to_utf8_buffer()
	if payload.size() <= MAX_RECORD_BYTES:
		return payload
	var reduced := record.duplicate(true)
	reduced["truncated"] = true
	var error: Dictionary = reduced.get("error", {})
	error["text"] = str(error.get("text", "")).substr(0, 1024)
	error["code"] = str(error.get("code", "")).substr(0, 512)
	error["rationale"] = str(error.get("rationale", "")).substr(0, 512)
	reduced["error"] = error
	var backtrace: Dictionary = reduced.get("script_backtrace", {})
	var traces: Array = backtrace.get("traces", [])
	for trace_value in traces:
		var trace: Dictionary = trace_value
		trace["frames"] = (trace.get("frames", []) as Array).slice(0, 16)
	backtrace["traces"] = traces
	reduced["script_backtrace"] = backtrace
	reduced["breadcrumbs"] = (reduced.get("breadcrumbs", []) as Array).slice(-20)
	payload = JSON.stringify(reduced).to_utf8_buffer()
	if payload.size() <= MAX_RECORD_BYTES:
		return payload
	reduced["breadcrumbs"] = []
	backtrace["traces"] = []
	backtrace["available"] = false
	backtrace["status"] = "truncated to preserve record byte limit"
	payload = JSON.stringify(reduced).to_utf8_buffer()
	return payload if payload.size() <= MAX_RECORD_BYTES else PackedByteArray()


func _build_identity() -> Dictionary:
	if not _build_identity_cache.is_empty():
		return _build_identity_cache
	var executable := OS.get_executable_path()
	var app_name := str(ProjectSettings.get_setting("application/config/name", "FantasyDisk"))
	var candidates := [
		executable.get_base_dir().path_join("../Resources/%s.pck" % app_name),
		executable.get_basename() + ".pck",
	]
	for candidate in candidates:
		var absolute_candidate := ProjectSettings.globalize_path(str(candidate)).simplify_path()
		if FileAccess.file_exists(absolute_candidate):
			var digest := FileAccess.get_sha256(absolute_candidate)
			if not digest.is_empty():
				_build_identity_cache = {
					"build_sha256": digest,
					"build_sha256_source": "exported project pack",
				}
				return _build_identity_cache
	var source_digest := FileAccess.get_sha256("res://scripts/crash_logger.gd")
	_build_identity_cache = {
		"build_sha256": source_digest if not source_digest.is_empty() else "unavailable",
		"build_sha256_source": "res://scripts/crash_logger.gd" if not source_digest.is_empty() else "unavailable",
	}
	return _build_identity_cache


func _rotate_for(incoming_bytes: int) -> void:
	var entries: Array[Dictionary] = []
	var total_bytes := 0
	for filename in DirAccess.get_files_at(_output_directory):
		if not filename.begins_with(INCIDENT_PREFIX) or not filename.ends_with(INCIDENT_SUFFIX):
			continue
		var path := _path_join(_output_directory, filename)
		var file := FileAccess.open(path, FileAccess.READ)
		var size := 0
		if file != null:
			size = file.get_length()
			file.close()
		entries.append({"name": filename, "path": path, "size": size})
		total_bytes += size
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	while not entries.is_empty() and (
		entries.size() >= MAX_INCIDENTS or total_bytes + incoming_bytes > MAX_RETAINED_BYTES
	):
		var oldest: Dictionary = entries.pop_front()
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(str(oldest["path"]))) == OK:
			total_bytes -= int(oldest["size"])


func _prepare_output_directory() -> bool:
	var absolute_directory := ProjectSettings.globalize_path(_output_directory)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return false
	for filename in DirAccess.get_files_at(_output_directory):
		if filename.begins_with(INCIDENT_PREFIX) and filename.ends_with(TEMP_SUFFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path_join(_output_directory, filename)))
	return true


func _debug_output_directory() -> String:
	if not OS.is_debug_build():
		return INCIDENT_DIRECTORY
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(DEBUG_OUTPUT_PREFIX):
			var requested := argument.trim_prefix(DEBUG_OUTPUT_PREFIX).strip_edges()
			if not requested.is_empty():
				return requested
	return INCIDENT_DIRECTORY


func _run_debug_self_test() -> void:
	_self_test_parent()
	_flush_pending()
	if _last_incident_path.is_empty():
		print("CRASH_LOGGER_SELF_TEST_FAILED")
		get_tree().quit(2)
		return
	print("CRASH_LOGGER_SELF_TEST incident=%s" % _last_incident_path)
	get_tree().quit(0)


func _self_test_parent() -> void:
	_self_test_leaf()


func _self_test_leaf() -> void:
	push_error(SELF_TEST_ERROR)


func configure_output_directory_for_tests(path: String) -> bool:
	if not OS.is_debug_build() or path.strip_edges().is_empty():
		return false
	_flush_pending()
	_output_directory = path.strip_edges()
	_last_incident_path = ""
	_sequence = 0
	_build_identity_cache.clear()
	return _prepare_output_directory()


func record_breadcrumb_for_tests(class_id: String, weapon_id: String, event: String, frame: int) -> void:
	if OS.is_debug_build() and _sink != null:
		_sink.record_breadcrumb(class_id, weapon_id, event, frame)


func capture_error_for_tests(
	error_text: String,
	frames: Array[Dictionary] = [],
	code := "",
	rationale := "",
) -> void:
	if OS.is_debug_build() and _sink != null:
		_sink.capture_for_test(error_text, frames, code, rationale)


func flush_pending_for_tests() -> void:
	if OS.is_debug_build():
		_flush_pending()


func breadcrumb_snapshot_for_tests() -> Array[Dictionary]:
	return _sink.breadcrumb_snapshot() if OS.is_debug_build() and _sink != null else []


func clear_breadcrumbs_for_tests() -> void:
	if OS.is_debug_build() and _sink != null:
		_sink.clear_breadcrumbs()


func last_incident_path_for_tests() -> String:
	return _last_incident_path if OS.is_debug_build() else ""


func incident_paths_for_tests() -> PackedStringArray:
	var result := PackedStringArray()
	if not OS.is_debug_build():
		return result
	for filename in DirAccess.get_files_at(_output_directory):
		if filename.begins_with(INCIDENT_PREFIX) and filename.ends_with(INCIDENT_SUFFIX):
			result.append(ProjectSettings.globalize_path(_path_join(_output_directory, filename)))
	result.sort()
	return result


static func _path_join(directory: String, filename: String) -> String:
	return directory.trim_suffix("/").path_join(filename)
