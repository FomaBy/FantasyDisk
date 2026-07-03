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

	# SCRUM-848: встроенный дефолтный вебхук — фидбек работает из коробки. Контракт:
	# 1) встроенный URL собирается из base64-чанков и валиден;
	# 2) пустые env/cfg → резолюция отдаёт встроенный (не «Ошибка сборки»);
	# 3) оверрайды сохраняют приоритет: env > bundled > user > builtin;
	# 4) невалидный оверрайд игнорируется и падает дальше до встроенного.
	var builtin_url := Reporter._builtin_webhook_url()
	_check(Reporter._is_valid_webhook_url(builtin_url),
		"builtin webhook URL must decode into a valid Discord webhook")
	var fallback: Dictionary = Reporter._resolve_from("", "", "")
	_check(str(fallback.get("source", "")) == "builtin" and str(fallback.get("error", "x")) == "",
		"empty sources must resolve to the builtin webhook without error")
	_check(str(fallback.get("url", "")) == builtin_url,
		"builtin fallback must return the decoded builtin URL")
	var env_win: Dictionary = Reporter._resolve_from(
		"https://discord.com/api/webhooks/111/aaa", "https://discord.com/api/webhooks/222/bbb", "")
	_check(str(env_win.get("source", "")) == "env" and str(env_win.get("url", "")).ends_with("/111/aaa"),
		"env override must win over bundled and builtin")
	var bundled_win: Dictionary = Reporter._resolve_from("", "https://discord.com/api/webhooks/222/bbb", "")
	_check(str(bundled_win.get("source", "")) == "bundled",
		"bundled cfg override must win over user cfg and builtin")
	var user_win: Dictionary = Reporter._resolve_from("", "", "https://discord.com/api/webhooks/333/ccc")
	_check(str(user_win.get("source", "")) == "user",
		"user cfg override must win over builtin")
	var invalid_fallthrough: Dictionary = Reporter._resolve_from(
		"https://discord.com/api/webhooks/XXXX/YYYY", "https://example.com/api/webhooks/1/a", "")
	_check(str(invalid_fallthrough.get("source", "")) == "builtin" and str(invalid_fallthrough.get("error", "x")) == "",
		"invalid overrides must fall through to builtin instead of failing the send")

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
