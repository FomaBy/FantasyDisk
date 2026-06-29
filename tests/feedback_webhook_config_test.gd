extends SceneTree

const Reporter := preload("res://scripts/feedback_reporter.gd")

var _errors: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)


func _init() -> void:
	_check(Reporter._is_valid_webhook_url("https://discord.com/api/webhooks/123456789/abcdef"),
		"discord.com webhook URL should be accepted")
	_check(Reporter._is_valid_webhook_url("https://discordapp.com/api/webhooks/123456789/abcdef"),
		"discordapp.com webhook URL should be accepted")
	_check(not Reporter._is_valid_webhook_url(""),
		"empty webhook URL should be rejected")
	_check(not Reporter._is_valid_webhook_url("https://discord.com/api/webhooks/XXXX/YYYY"),
		"example placeholder webhook URL should be rejected")
	_check(not Reporter._is_valid_webhook_url("https://example.com/api/webhooks/123/abc"),
		"non-Discord webhook URL should be rejected")

	var missing_msg := Reporter._configuration_failure_message("missing")
	var invalid_msg := Reporter._configuration_failure_message("invalid")
	_check("не настроен" in missing_msg, "missing config message should name missing build config")
	_check("некорректен" in invalid_msg, "invalid config message should name invalid build config")
	_check(not ("discord.com/api/webhooks" in missing_msg), "missing message must not expose webhook URL")
	_check(not ("discord.com/api/webhooks" in invalid_msg), "invalid message must not expose webhook URL")
	_check(missing_msg.length() <= 90, "missing message should fit status label: %s" % missing_msg)
	_check(invalid_msg.length() <= 90, "invalid message should fit status label: %s" % invalid_msg)

	if _errors.is_empty():
		print("Feedback webhook config test passed.")
		quit(0)
	else:
		for e in _errors:
			push_error("Feedback webhook config: %s" % e)
		quit(1)
