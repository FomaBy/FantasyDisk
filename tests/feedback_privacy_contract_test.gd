extends SceneTree

const Reporter := preload("res://scripts/feedback_reporter.gd")

var _errors: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _init() -> void:
	_check(str(ProjectSettings.get_setting(Reporter.RELAY_PROJECT_SETTING, "")) == "",
		"Production relay endpoint must remain empty during the privacy gate.")
	for setting in [
		Reporter.PRIVACY_OPERATOR_SETTING,
		Reporter.PRIVACY_CONTACT_SETTING,
		Reporter.PRIVACY_RETENTION_SETTING,
		Reporter.PRIVACY_POLICY_SETTING,
	]:
		_check(ProjectSettings.has_setting(setting), "Missing public disclosure setting: %s" % setting)
		_check(str(ProjectSettings.get_setting(setting, "")) == "",
			"Unapproved disclosure value must not be invented in project defaults: %s" % setting)

	var raw_metadata := {
		"version": "0.2.1",
		"screen": "Combat",
		"os": "macOS",
		"password": "secret",
		"nested": {"unsafe": true},
		"long": "x".repeat(500),
	}
	var sanitized := Reporter._sanitize_metadata(raw_metadata)
	_check(sanitized == {"version": "0.2.1", "screen": "Combat", "os": "macOS"},
		"Client metadata allowlist did not fail closed: %s" % str(sanitized))
	_check(Reporter.METADATA_KEYS.size() == 14,
		"Privacy disclosure allowlist changed without updating its exact contract.")

	var report_id := Reporter._new_report_uuid()
	var report_path := Reporter.save_local_report(
		"text-only local privacy test",
		Image.create(64, 36, false, Image.FORMAT_RGBA8),
		{"version": "test", "screen": "privacy"},
		report_id,
		false)
	_check(report_path != "" and FileAccess.file_exists("%s/report.txt" % report_path),
		"Text-only local fallback did not create report.txt.")
	_check(not FileAccess.file_exists("%s/screenshot.png" % report_path),
		"Text-only local fallback violated screenshot opt-out.")
	var report_text := FileAccess.get_file_as_string("%s/report.txt" % report_path)
	_check("Скриншот: не включен" in report_text,
		"Local text-only report does not record the opt-out state.")

	if _errors.is_empty():
		print("Feedback privacy contract test passed (fail-closed disclosure, metadata, local opt-out).")
		quit(0)
	else:
		for error in _errors:
			push_error("Feedback privacy contract: %s" % error)
		quit(1)
