extends SceneTree

# SCRUM-547: регресс-гейт политики ретрая/таймаута отправки фидбека.
# Баг у тестеров: «нет ответа (result 13)» = RESULT_TIMEOUT — единственная попытка с
# жёстким таймаутом 12 с падала и сразу сохраняла локально, до нас фидбек не доходил.
# Здесь фиксируем НОВЫЙ контракт reporter'а (чистые decision-хелперы, без сети):
#   1. таймаут поднят и вынесен в const (>= 20 с);
#   2. ретраятся именно временные ошибки (timeout/сеть/5xx/429), а 4xx (кроме 429) — нет;
#   3. сообщения об ошибке различимы (нет сети / таймаут после N / код сервера);
#   4. бэкофф нарастающий, при 429 уважается Retry-After (с потолком).
#
# Запуск: Godot --headless --path . --script res://tests/feedback_retry_policy_test.gd

const Reporter := preload("res://scripts/feedback_reporter.gd")

var _errors: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)


func _init() -> void:
	var r: Node = Reporter.new()

	# --- 1. Таймаут поднят и не равен старому хардкоду 12 с ---
	_check(Reporter.REQUEST_TIMEOUT >= 20.0,
		"REQUEST_TIMEOUT слишком мал (%.1f), ожидалось >= 20 с" % Reporter.REQUEST_TIMEOUT)
	_check(Reporter.MAX_ATTEMPTS >= 2,
		"MAX_ATTEMPTS=%d — без ретрая (ожидалось >= 2)" % Reporter.MAX_ATTEMPTS)

	# --- 2. Какие исходы ретраятся ---
	# RESULT_TIMEOUT (=13, тот самый симптом) — временный, ретраим.
	_check(r._is_retryable(HTTPRequest.RESULT_TIMEOUT, 0),
		"RESULT_TIMEOUT должен ретраиться (это и есть баг тестеров)")
	for res in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE,
			HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
			HTTPRequest.RESULT_NO_RESPONSE]:
		_check(r._is_retryable(res, 0), "result %d должен ретраиться (временная сетевая ошибка)" % res)
	# Успешный транспорт, но серверные коды.
	_check(r._is_retryable(HTTPRequest.RESULT_SUCCESS, 429), "HTTP 429 должен ретраиться (rate-limit)")
	_check(r._is_retryable(HTTPRequest.RESULT_SUCCESS, 500), "HTTP 500 должен ретраиться (5xx временно)")
	_check(r._is_retryable(HTTPRequest.RESULT_SUCCESS, 503), "HTTP 503 должен ретраиться (5xx временно)")
	# НЕ ретраить: 4xx (кроме 429) и явный отказ тела/размера.
	_check(not r._is_retryable(HTTPRequest.RESULT_SUCCESS, 400), "HTTP 400 НЕ должен ретраиться")
	_check(not r._is_retryable(HTTPRequest.RESULT_SUCCESS, 403), "HTTP 403 НЕ должен ретраиться (UA/доступ)")
	_check(not r._is_retryable(HTTPRequest.RESULT_SUCCESS, 413), "HTTP 413 НЕ должен ретраиться (тело велико — дело SCRUM-460)")
	_check(not r._is_retryable(HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, 0),
		"RESULT_BODY_SIZE_LIMIT_EXCEEDED НЕ должен ретраиться")

	# --- 3. Различимые сообщения ---
	var msg_timeout: String = r._failure_message(HTTPRequest.RESULT_TIMEOUT, 0)
	_check("таймаут" in msg_timeout.to_lower(),
		"сообщение таймаута без слова 'таймаут': %s" % msg_timeout)
	_check(str(Reporter.MAX_ATTEMPTS) in msg_timeout,
		"сообщение таймаута не упоминает число попыток (%d): %s" % [Reporter.MAX_ATTEMPTS, msg_timeout])
	var msg_net: String = r._failure_message(HTTPRequest.RESULT_CANT_CONNECT, 0)
	_check("сет" in msg_net.to_lower(), "сообщение 'нет сети' не про сеть: %s" % msg_net)
	_check(msg_net != msg_timeout, "сообщения 'нет сети' и 'таймаут' не должны совпадать")
	var msg_server: String = r._failure_message(HTTPRequest.RESULT_SUCCESS, 500)
	_check("500" in msg_server, "сообщение серверной ошибки не содержит код 500: %s" % msg_server)
	# Все сообщения должны сообщать про локальное сохранение (контракт fallback'а).
	for m in [msg_timeout, msg_net, msg_server]:
		_check("локальн" in m.to_lower(), "сообщение не упоминает локальное сохранение: %s" % m)
		_check(m.length() <= 90, "сообщение длиннее 90 символов (не влезет в статус-лейбл): %s" % m)

	# --- 4. Бэкофф нарастающий ---
	r._active_report = {"attempt": 1}
	var b1: float = r._backoff_for_attempt()
	r._active_report = {"attempt": 2}
	var b2: float = r._backoff_for_attempt()
	_check(b1 >= 0.0 and b2 >= b1,
		"бэкофф не нарастает: попытка1=%.1f попытка2=%.1f" % [b1, b2])

	# --- 4b. Retry-After на 429 ---
	var ra: float = r._retry_after_seconds(PackedStringArray(["Retry-After: 4", "X-Foo: bar"]))
	_check(absf(ra - 4.0) < 0.01, "Retry-After:4 не распознан, получено %.2f" % ra)
	var ra_cap: float = r._retry_after_seconds(PackedStringArray(["retry-after: 999"]))
	_check(ra_cap <= Reporter.RATE_LIMIT_MAX_WAIT_SECONDS + 0.01,
		"Retry-After без потолка: %.1f > %.1f" % [ra_cap, Reporter.RATE_LIMIT_MAX_WAIT_SECONDS])
	var ra_none: float = r._retry_after_seconds(PackedStringArray(["X-Foo: bar"]))
	_check(ra_none >= 0.0, "Retry-After fallback отрицателен: %.2f" % ra_none)

	r.free()

	if _errors.is_empty():
		print("Feedback retry policy test passed (timeout=%.0fс, attempts=%d, retryable/messages/backoff/Retry-After зелёные)." % [
			Reporter.REQUEST_TIMEOUT, Reporter.MAX_ATTEMPTS])
		quit(0)
	else:
		for e in _errors:
			push_error("Feedback retry policy: %s" % e)
		push_error("Feedback retry policy test: %d ошибок." % _errors.size())
		quit(1)
