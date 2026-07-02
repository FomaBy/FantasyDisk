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

	# SCRUM-720: контракт хранения фидбека. Локальный фолбэк и пользовательский конфиг
	# ОБЯЗАНЫ жить в user:// (вне репозитория) — иначе отчёты (текст игрока + скриншоты)
	# и URL-конфиг утекут в исходное дерево. Bundled-конфиг — read-only res:// (его
	# release-сборка генерирует из секрета). Гейтим префиксы, чтобы регрессия пути
	# (напр. LOCAL_ROOT → "res://feedback") падала здесь, а не в проде.
	_check(Reporter.LOCAL_ROOT.begins_with("user://"),
		"feedback local fallback root must stay under user:// (got %s)" % Reporter.LOCAL_ROOT)
	_check(Reporter.CONFIG_PATH.begins_with("user://"),
		"feedback user config must stay under user:// (got %s)" % Reporter.CONFIG_PATH)
	_check(Reporter.BUNDLED_CONFIG_PATH.begins_with("res://"),
		"bundled webhook config must be a read-only res:// resource (got %s)" % Reporter.BUNDLED_CONFIG_PATH)
	# Локальный отчёт-тело строится только из текста+метаданных игрока и НЕ должно нести
	# подстроку вебхука (структурная гарантия: reporter не инжектит секрет в фолбэк).
	var sample_body := Reporter._report_body("краш на боссе", {"версия": "0.2.0", "класс": "berserk"})
	_check(not ("discord.com/api/webhooks" in sample_body) and not ("discordapp.com/api/webhooks" in sample_body),
		"local report body must never embed a webhook URL")
	_check("краш на боссе" in sample_body, "local report body must keep the player's description")

	if _errors.is_empty():
		print("Feedback webhook config test passed.")
		quit(0)
	else:
		for e in _errors:
			push_error("Feedback webhook config: %s" % e)
		quit(1)
