extends SceneTree

# FAN-1046: stale HTTP completions/retry timers must never complete a newer
# report, and closing the overlay must be able to cancel the exact owner.

const Reporter := preload("res://scripts/feedback_reporter.gd")

class MissingConfigReporter:
	extends Reporter

	func _delivery_resolution() -> Dictionary:
		return {"mode": "", "url": "", "source": "", "error": "missing"}


var _errors: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _init() -> void:
	var public_reporter: Node = MissingConfigReporter.new()
	root.add_child(public_reporter)
	var public_calls := {"count": 0, "local_path": ""}
	var public_callback := func(_success: bool, _message: String, local_path: String) -> void:
		public_calls["count"] = int(public_calls["count"]) + 1
		public_calls["local_path"] = local_path
	var public_id: int = public_reporter.submit_report(
		"public fallback", _image(Color.DARK_GRAY), {"sequence": 0}, public_callback)
	_check(public_id > 0, "Public submit_report did not return a request id.")
	_check(not public_reporter.is_request_active(public_id),
		"Synchronous local fallback remained active after completion.")
	_check(int(public_calls["count"]) == 1,
		"Public synchronous fallback callback must run exactly once.")
	_check(str(public_calls["local_path"]) != "",
		"Public synchronous fallback did not preserve a local report.")
	public_reporter.queue_free()

	var text_only_reporter: Node = MissingConfigReporter.new()
	root.add_child(text_only_reporter)
	var text_only_result := {"local_path": ""}
	var text_only_id: int = text_only_reporter.submit_report(
		"privacy opt-out fallback", _image(Color.DIM_GRAY), {"screen": "test"},
		func(_success: bool, _message: String, local_path: String) -> void:
			text_only_result["local_path"] = local_path,
		false)
	_check(not text_only_reporter.is_request_active(text_only_id),
		"Text-only local fallback remained active after completion.")
	var text_only_path := str(text_only_result["local_path"])
	_check(text_only_path != "" and FileAccess.file_exists("%s/report.txt" % text_only_path),
		"Text-only local fallback did not preserve report.txt.")
	_check(not FileAccess.file_exists("%s/screenshot.png" % text_only_path),
		"Screenshot opt-out still wrote a local screenshot.png.")
	text_only_reporter.queue_free()

	var oversized_reporter: Node = MissingConfigReporter.new()
	root.add_child(oversized_reporter)
	var oversized_result := {"count": 0, "message": "", "local_path": ""}
	var oversized_id: int = oversized_reporter.submit_report(
		"x".repeat(Reporter.MAX_DESCRIPTION_CHARS + 1), _image(Color.GRAY), {},
		func(_success: bool, message: String, local_path: String) -> void:
			oversized_result["count"] = int(oversized_result["count"]) + 1
			oversized_result["message"] = message
			oversized_result["local_path"] = local_path
	)
	_check(not oversized_reporter.is_request_active(oversized_id),
		"Oversized description should fail before any network request.")
	_check(int(oversized_result["count"]) == 1 \
			and str(Reporter.MAX_DESCRIPTION_CHARS) in str(oversized_result["message"]),
		"Oversized description did not return the client limit message exactly once.")
	_check(str(oversized_result["local_path"]) != "",
		"Oversized description was not preserved in local fallback.")
	oversized_reporter.queue_free()

	var reporter: Node = Reporter.new()
	root.add_child(reporter)
	var calls := {"first": 0, "second": 0, "signals": 0}
	reporter.report_finished_for_request.connect(func(_request_id: int, _success: bool, _message: String, _local_path: String) -> void:
		calls["signals"] = int(calls["signals"]) + 1
	)

	var first_callback := func(_success: bool, _message: String, _local_path: String) -> void:
		calls["first"] = int(calls["first"]) + 1
	var first_id: int = reporter._begin_report(
		"first", _image(Color.RED), {"sequence": 1}, first_callback)
	var second_callback := func(_success: bool, _message: String, _local_path: String) -> void:
		calls["second"] = int(calls["second"]) + 1
	var second_id: int = reporter._begin_report(
		"second", _image(Color.BLUE), {"sequence": 2}, second_callback)
	_check(second_id > first_id, "Request ids must increase monotonically.")
	_check(not reporter.is_request_active(first_id), "Superseded request remained active.")
	_check(reporter.is_request_active(second_id), "Newest request did not become active.")
	var opted_out_id: int = reporter._begin_report(
		"snapshot opt-out", _image(Color.WHITE), {"screen": "test"}, Callable(), false)
	_check(opted_out_id > second_id \
		and not bool(reporter._active_report.get("include_screenshot", true)) \
		and reporter._active_report.get("screenshot") == null,
		"Opt-out request snapshot retained screenshot state or bytes.")
	second_id = reporter._begin_report(
		"second", _image(Color.BLUE), {"sequence": 2}, second_callback)
	reporter._transition_phase(second_id, Reporter.PHASE_DISCORD_DEBUG)

	# A stale completion is a no-op and cannot consume the newer callback.
	reporter._finish_report(first_id, true, "stale", "")
	_check(int(calls["first"]) == 0 and int(calls["second"]) == 0,
		"Stale completion invoked a report callback.")
	_check(reporter.is_request_active(second_id), "Stale completion invalidated the active request.")

	# A stale HTTP node must not free the active request node.
	var stale_request := HTTPRequest.new()
	reporter.add_child(stale_request)
	var current_request := HTTPRequest.new()
	reporter.add_child(current_request)
	reporter._request = current_request
	reporter._request_owner_id = second_id
	reporter._request_phase = Reporter.PHASE_DISCORD_DEBUG
	reporter._on_request_completed(
		HTTPRequest.RESULT_SUCCESS, 204, PackedStringArray(), PackedByteArray(), first_id, stale_request)
	_check(reporter._request == current_request, "Stale HTTP completion disposed the active HTTPRequest.")
	_check(reporter.is_request_active(second_id), "Stale HTTP completion finished the active report.")

	# Stale retry timeouts are generation-guarded too.
	var attempt_before := int(reporter._active_report.get("attempt", 0))
	reporter._on_retry_timeout(first_id)
	_check(int(reporter._active_report.get("attempt", 0)) == attempt_before,
		"Stale retry timeout dispatched a newer report attempt.")

	reporter._on_request_completed(
		HTTPRequest.RESULT_SUCCESS, 204, PackedStringArray(), PackedByteArray(), second_id, current_request)
	_check(int(calls["first"]) == 0, "Superseded request callback was invoked.")
	_check(int(calls["second"]) == 1, "Owning callback must run exactly once.")
	_check(int(calls["signals"]) == 1, "Request-specific signal must emit exactly once.")
	_check(not reporter.is_request_active(second_id), "Completed request remained active.")
	reporter._finish_report(second_id, true, "duplicate", "")
	_check(int(calls["second"]) == 1 and int(calls["signals"]) == 1,
		"Duplicate completion emitted more than once.")

	# request_id alone is insufficient for the two-phase relay: a late SESSION
	# callback for the same report must not dispose or finish the active UPLOAD.
	var phased_calls := {"count": 0}
	var phased_id: int = reporter._begin_report(
		"phased", _image(Color.PURPLE), {"sequence": 3},
		func(_success: bool, _message: String, _local_path: String) -> void:
			phased_calls["count"] = int(phased_calls["count"]) + 1
	)
	reporter._transition_phase(phased_id, Reporter.PHASE_RELAY_UPLOAD)
	var stale_session_request := HTTPRequest.new()
	reporter.add_child(stale_session_request)
	var upload_request := HTTPRequest.new()
	reporter.add_child(upload_request)
	reporter._request = upload_request
	reporter._request_owner_id = phased_id
	reporter._request_phase = Reporter.PHASE_RELAY_UPLOAD
	reporter._on_request_completed(
		HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
		JSON.stringify({"schema_version": Reporter.RELAY_SCHEMA_VERSION, "expires_in": 600, "token": "stale"}).to_utf8_buffer(),
		phased_id, stale_session_request, Reporter.PHASE_RELAY_SESSION)
	_check(reporter._request == upload_request,
		"Stale same-report SESSION completion disposed the UPLOAD HTTPRequest.")
	_check(reporter._active_phase() == Reporter.PHASE_RELAY_UPLOAD,
		"Stale same-report SESSION completion changed the active relay phase.")
	_check(int(phased_calls["count"]) == 0,
		"Stale same-report SESSION completion finished the report.")
	var attempt_before_phase_timer := int(reporter._active_report.get("attempt", 0))
	reporter._on_retry_timeout(phased_id, Reporter.PHASE_RELAY_SESSION)
	_check(int(reporter._active_report.get("attempt", 0)) == attempt_before_phase_timer,
		"Stale same-report SESSION retry timer dispatched during UPLOAD.")
	reporter._on_request_completed(
		HTTPRequest.RESULT_SUCCESS, 202, PackedStringArray(), PackedByteArray(),
		phased_id, upload_request, Reporter.PHASE_RELAY_UPLOAD)
	_check(int(phased_calls["count"]) == 1,
		"Owning relay UPLOAD completion did not finish exactly once.")

	# A retry creates another HTTPRequest in the same phase. A late completion
	# from the previous attempt must be rejected by request identity, not merely
	# by request_id+phase.
	var retry_calls := {"count": 0}
	var retry_id: int = reporter._begin_report(
		"same phase retry", _image(Color.ORANGE), {"sequence": 4},
		func(_success: bool, _message: String, _local_path: String) -> void:
			retry_calls["count"] = int(retry_calls["count"]) + 1
	)
	reporter._transition_phase(retry_id, Reporter.PHASE_RELAY_UPLOAD)
	var old_upload_attempt := HTTPRequest.new()
	reporter.add_child(old_upload_attempt)
	var current_upload_attempt := HTTPRequest.new()
	reporter.add_child(current_upload_attempt)
	reporter._request = current_upload_attempt
	reporter._request_owner_id = retry_id
	reporter._request_phase = Reporter.PHASE_RELAY_UPLOAD
	reporter._on_request_completed(
		HTTPRequest.RESULT_SUCCESS, 202, PackedStringArray(), PackedByteArray(),
		retry_id, old_upload_attempt, Reporter.PHASE_RELAY_UPLOAD)
	_check(reporter._request == current_upload_attempt,
		"Stale same-phase retry completion disposed the owning HTTPRequest.")
	_check(reporter.is_request_active(retry_id) and int(retry_calls["count"]) == 0,
		"Stale same-phase retry completion finished the active report.")
	reporter._on_request_completed(
		HTTPRequest.RESULT_SUCCESS, 202, PackedStringArray(), PackedByteArray(),
		retry_id, current_upload_attempt, Reporter.PHASE_RELAY_UPLOAD)
	_check(int(retry_calls["count"]) == 1,
		"Owning same-phase retry completion did not finish exactly once.")

	var cancel_calls := {"count": 0}
	var cancel_callback := func(_success: bool, _message: String, _local_path: String) -> void:
		cancel_calls["count"] = int(cancel_calls["count"]) + 1
	var cancel_id: int = reporter._begin_report("cancel", _image(Color.GREEN), {}, cancel_callback)
	_check(not reporter.cancel_active_report(cancel_id + 1), "Wrong owner id cancelled the active request.")
	_check(reporter.is_request_active(cancel_id), "Wrong owner id invalidated the active request.")
	_check(reporter.cancel_active_report(cancel_id), "Owning request could not be cancelled.")
	reporter._finish_report(cancel_id, false, "late", "")
	_check(int(cancel_calls["count"]) == 0, "Cancelled request invoked its completion callback.")
	_check(reporter._active_report.is_empty(), "Cancelled request retained its payload snapshot.")

	reporter.queue_free()
	if _errors.is_empty():
		print("Feedback request lifecycle test passed (identity, stale callbacks, retry guard, cancellation).")
		quit(0)
	else:
		for error in _errors:
			push_error("Feedback request lifecycle: %s" % error)
		push_error("Feedback request lifecycle test: %d errors." % _errors.size())
		quit(1)


func _image(color: Color) -> Image:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image
