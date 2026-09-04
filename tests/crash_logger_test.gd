extends SceneTree

const CrashLoggerScript := preload("res://scripts/crash_logger.gd")
const TEST_ROOT := "user://logs/fan3905-unit"
const CONCURRENT_RECORDS := 16


class CaptureWorker:
	var service: Node


	func _init(target: Node) -> void:
		service = target


	func run(index: int) -> void:
		var frames: Array[Dictionary] = [{
			"file": "res://tests/crash_logger_test.gd",
			"function": "CaptureWorker.run",
			"line": index + 1,
		}]
		service.call(
			"capture_error_for_tests",
			"concurrent-%02d" % index,
			frames,
		)


var _errors: Array[String] = []


func _init() -> void:
	_clean_directory(TEST_ROOT)
	call_deferred("_start_tests")


func _start_tests() -> void:
	var service: Node = root.get_node_or_null("CrashLogger")
	if service == null:
		service = CrashLoggerScript.new()
		root.add_child(service)
	_run_tests(service)


func _run_tests(service: Node) -> void:
	_check(service.configure_output_directory_for_tests(TEST_ROOT), "test output directory was not accepted")

	_check(service.incident_paths_for_tests().is_empty(), "a clean session created an incident file")
	_test_short_breadcrumb_ring(service)
	_test_full_breadcrumb_ring(service)
	_check(service.incident_paths_for_tests().is_empty(), "breadcrumb-only activity created an incident file")
	_test_unavailable_stack_and_redaction(service)
	_test_concurrent_records_and_rotation(service)

	_clean_directory(TEST_ROOT)
	if _errors.is_empty():
		print("crash_logger_test: PASS (clean session, ordered 50-ring, bounds, redaction, concurrency, rotation)")
		quit(0)
		return
	for error in _errors:
		push_error("crash_logger_test: %s" % error)
	print("crash_logger_test: FAIL (%d)" % _errors.size())
	quit(1)


func _test_short_breadcrumb_ring(service: Node) -> void:
	service.clear_breadcrumbs_for_tests()
	for index in range(3):
		service.record_breadcrumb_for_tests("class_%d" % index, "weapon_%d" % index, "event_%d" % index, 10 + index)
	var snapshot: Array = service.breadcrumb_snapshot_for_tests()
	_check(snapshot.size() == 3, "short session did not preserve every breadcrumb")
	for index in range(snapshot.size()):
		var entry: Dictionary = snapshot[index]
		_check(int(entry.get("frame", -1)) == 10 + index, "short-session frame order changed at %d" % index)


func _test_full_breadcrumb_ring(service: Node) -> void:
	service.clear_breadcrumbs_for_tests()
	for index in range(55):
		service.record_breadcrumb_for_tests("berserk", "weapon_%02d" % index, "event_%02d" % index, index)
	var snapshot: Array = service.breadcrumb_snapshot_for_tests()
	_check(snapshot.size() == 50, "55 events retained %d entries instead of exactly 50" % snapshot.size())
	for index in range(snapshot.size()):
		var expected := index + 5
		var entry: Dictionary = snapshot[index]
		_check(int(entry.get("frame", -1)) == expected, "ring frame %d is not ordered newest-50 value %d" % [index, expected])
		_check(str(entry.get("event", "")) == "event_%02d" % expected, "ring event %d changed identity" % index)


func _test_unavailable_stack_and_redaction(service: Node) -> void:
	var no_frames: Array[Dictionary] = []
	service.capture_error_for_tests(
		"password=visible token:abc /Users/example/private/file",
		no_frames,
	)
	service.flush_pending_for_tests()
	var paths: PackedStringArray = service.incident_paths_for_tests()
	_check(paths.size() == 1, "one captured error produced %d files" % paths.size())
	if paths.is_empty():
		return
	var path := str(paths[0])
	var payload := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(payload)
	_check(parsed is Dictionary, "incident is not complete JSON")
	if not parsed is Dictionary:
		return
	var record: Dictionary = parsed
	var backtrace: Dictionary = record.get("script_backtrace", {})
	_check(not bool(backtrace.get("available", true)), "missing engine stack was presented as available")
	_check("unavailable" in str(backtrace.get("status", "")), "missing stack has no honest unavailable status")
	_check(str(record.get("timestamp_utc", "")).ends_with("Z"), "incident lacks a UTC timestamp")
	_check(str(record.get("build_version", "")) == str(ProjectSettings.get_setting("application/config/version")), "incident build version differs from project version")
	_check(str(record.get("build_sha256", "")).length() == 64, "incident lacks a 64-character immutable SHA-256")
	_check(payload.to_lower().find("visible") == -1 and payload.to_lower().find("token:abc") == -1, "credential-like values were not redacted")
	_check(payload.find("/Users/example") == -1, "personal home path was not redacted")
	_check(payload.to_utf8_buffer().size() <= CrashLoggerScript.MAX_RECORD_BYTES, "incident exceeded the record byte limit")
	_clean_incident_files(TEST_ROOT)


func _test_concurrent_records_and_rotation(service: Node) -> void:
	var threads: Array[Thread] = []
	var workers: Array[CaptureWorker] = []
	for index in range(CONCURRENT_RECORDS):
		var worker := CaptureWorker.new(service)
		var thread := Thread.new()
		workers.append(worker)
		threads.append(thread)
		_check(thread.start(worker.run.bind(index)) == OK, "thread %d did not start" % index)
	for thread in threads:
		thread.wait_to_finish()
	service.flush_pending_for_tests()

	var paths: PackedStringArray = service.incident_paths_for_tests()
	_check(paths.size() == CONCURRENT_RECORDS, "concurrent callbacks produced %d/%d complete records" % [paths.size(), CONCURRENT_RECORDS])
	var seen := {}
	for path_value in paths:
		var path := str(path_value)
		var payload := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(payload)
		_check(parsed is Dictionary, "concurrent record %s is interleaved or incomplete" % path.get_file())
		_check(payload.to_utf8_buffer().size() <= CrashLoggerScript.MAX_RECORD_BYTES, "concurrent record exceeded byte limit")
		if parsed is Dictionary:
			seen[str((parsed as Dictionary).get("error", {}).get("text", ""))] = true
	for index in range(CONCURRENT_RECORDS):
		_check(seen.has("concurrent-%02d" % index), "concurrent record %d was lost" % index)

	for index in range(10):
		service.capture_error_for_tests("rotation-%02d" % index)
	service.flush_pending_for_tests()
	paths = service.incident_paths_for_tests()
	_check(paths.size() == CrashLoggerScript.MAX_INCIDENTS, "rotation retained %d files instead of %d" % [paths.size(), CrashLoggerScript.MAX_INCIDENTS])
	var retained_bytes := 0
	for path_value in paths:
		var file := FileAccess.open(str(path_value), FileAccess.READ)
		if file != null:
			retained_bytes += file.get_length()
			file.close()
	_check(retained_bytes <= CrashLoggerScript.MAX_RETAINED_BYTES, "rotation retained %d bytes above the limit" % retained_bytes)


func _clean_incident_files(directory: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		return
	for filename in DirAccess.get_files_at(directory):
		if filename.begins_with(CrashLoggerScript.INCIDENT_PREFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))


func _clean_directory(directory: String) -> void:
	_clean_incident_files(directory)
	var absolute := ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
