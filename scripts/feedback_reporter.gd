class_name FeedbackReporter
extends Node

signal report_finished(success: bool, message: String, local_path: String)

const CONFIG_PATH := "user://feedback_config.cfg"
const BUNDLED_CONFIG_PATH := "res://feedback_webhook.cfg"
const CONFIG_SECTION := "feedback"
const WEBHOOK_KEY := "webhook_url"
const BUNDLED_WEBHOOK_KEY := "discord_webhook_url"
const LOCAL_ROOT := "user://feedback"
const ENV_WEBHOOK := "FANTASYDISK_FEEDBACK_WEBHOOK"
# A Discord webhook is a credential, even when split or base64-encoded. It must
# never be embedded in source or an export. Until a server-side relay exists,
# network delivery is an explicit developer override and player builds preserve
# reports under user://feedback instead.
# Вложение в Discord уходит ужатым JPG, а не полноразмерным PNG: скрин 1600x970 в
# PNG весит ~9.8 МБ, и multipart-тело пробивает лимит загрузки вебхука (~8–10 МБ
# на не-бустнутом сервере) → HTTP 413 «Payload Too Large» → «Ошибка отправки»
# (SCRUM-460). Downscale до 1280px по длинной стороне + JPG q0.72 даёт ~150–250 КБ.
const UPLOAD_FILENAME := "fantasydisk_feedback.jpg"
const UPLOAD_MAX_DIM := 1280
const UPLOAD_JPG_QUALITY := 0.72

# SCRUM-547: у тестеров отправка падала с «нет ответа (result 13)» = RESULT_TIMEOUT —
# сервер не успевал ответить за жёсткие 12 с, и единственная попытка без ретрая сразу
# сохраняла локально, до нас фидбек не доходил. Поднимаем таймаут и добавляем ретрай с
# бэкоффом на временных (сетевых/таймаут/5xx/429) ошибках; 4xx (кроме 429) НЕ ретраим —
# это не временная ошибка. Финальный провал, как и раньше, сохраняет локальный снапшот.
const REQUEST_TIMEOUT := 25.0
const MAX_ATTEMPTS := 3
# Пауза перед попытками №2 и №3 (попытка №1 — без задержки). Нарастающий бэкофф,
# чтобы не долбить сервер и пережить короткую деградацию сети.
const RETRY_BACKOFF_SECONDS := [2.0, 5.0]
# При 429 без заголовка Retry-After и как потолок ожидания при больших Retry-After.
const RATE_LIMIT_FALLBACK_SECONDS := 3.0
const RATE_LIMIT_MAX_WAIT_SECONDS := 15.0
# Временные результаты HTTPRequest — их имеет смысл ретраить (в отличие от, например,
# RESULT_BODY_SIZE_LIMIT_EXCEEDED или явного HTTP 4xx).
const TRANSIENT_RESULTS := [
	HTTPRequest.RESULT_TIMEOUT,
	HTTPRequest.RESULT_CANT_CONNECT,
	HTTPRequest.RESULT_CANT_RESOLVE,
	HTTPRequest.RESULT_CONNECTION_ERROR,
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
	HTTPRequest.RESULT_NO_RESPONSE,
]
# Результаты «нет сети/не достучались» — для отдельного, более точного сообщения.
const NO_NETWORK_RESULTS := [
	HTTPRequest.RESULT_CANT_CONNECT,
	HTTPRequest.RESULT_CANT_RESOLVE,
	HTTPRequest.RESULT_CONNECTION_ERROR,
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
]

var _pending_text := ""
var _pending_metadata := {}
var _pending_screenshot: Image = null
var _request: HTTPRequest = null
var _pending_webhook_url := ""
var _attempt := 0


func submit_report(text: String, screenshot: Image, metadata: Dictionary) -> void:
	_pending_text = text.strip_edges()
	_pending_metadata = metadata.duplicate(true)
	_pending_screenshot = _normalized_screenshot(screenshot)
	var webhook_resolution := _webhook_resolution()
	var webhook_url := str(webhook_resolution.get("url", ""))
	if webhook_url == "":
		var local_path := save_local_report(_pending_text, _pending_screenshot, _pending_metadata)
		report_finished.emit(false, _configuration_failure_message(
			str(webhook_resolution.get("error", "missing")), local_path != ""), local_path)
		return

	_post_to_webhook(webhook_url)


static func webhook_config_template_path() -> String:
	return ProjectSettings.globalize_path(CONFIG_PATH)


static func feedback_folder_path() -> String:
	return ProjectSettings.globalize_path(LOCAL_ROOT)


static func save_local_report(text: String, screenshot: Image, metadata: Dictionary) -> String:
	var timestamp := _timestamp_for_path()
	var report_dir := "%s/%s" % [LOCAL_ROOT, timestamp]
	var absolute_dir := ProjectSettings.globalize_path(report_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return ""

	var report_file := FileAccess.open("%s/report.txt" % report_dir, FileAccess.WRITE)
	if report_file == null:
		return ""
	report_file.store_string(_report_body(text, metadata))
	var report_error := report_file.get_error()
	report_file.close()
	if report_error != OK:
		return ""

	var safe_screenshot := _normalized_screenshot(screenshot)
	if safe_screenshot.save_png("%s/screenshot.png" % report_dir) != OK:
		return ""
	return absolute_dir


static func discord_content(text: String, metadata: Dictionary) -> String:
	var body := _report_body(text, metadata)
	if body.length() > 1800:
		body = body.substr(0, 1790) + "\n..."
	return body


static func multipart_payload(text: String, screenshot: Image, metadata: Dictionary, boundary: String) -> PackedByteArray:
	var body := PackedByteArray()
	var payload_json := JSON.stringify({
		"content": discord_content(text, metadata),
		"attachments": [{"id": 0, "filename": UPLOAD_FILENAME}],
	})
	_append_utf8(body, "--%s\r\n" % boundary)
	_append_utf8(body, "Content-Disposition: form-data; name=\"payload_json\"\r\n")
	_append_utf8(body, "Content-Type: application/json\r\n\r\n")
	_append_utf8(body, "%s\r\n" % payload_json)

	_append_utf8(body, "--%s\r\n" % boundary)
	_append_utf8(body, "Content-Disposition: form-data; name=\"files[0]\"; filename=\"%s\"\r\n" % UPLOAD_FILENAME)
	_append_utf8(body, "Content-Type: image/jpeg\r\n\r\n")
	body.append_array(_upload_image_buffer(screenshot))
	_append_utf8(body, "\r\n--%s--\r\n" % boundary)
	return body


static func _upload_image_buffer(screenshot: Image) -> PackedByteArray:
	# Ужимаем скрин перед отправкой в Discord, чтобы тело запроса не пробивало лимит
	# вебхука (SCRUM-460). Локальная копия в save_local_report остаётся полным PNG.
	var img := _normalized_screenshot(screenshot)
	var longest := maxi(img.get_width(), img.get_height())
	if longest > UPLOAD_MAX_DIM:
		var ratio := float(UPLOAD_MAX_DIM) / float(longest)
		img = img.duplicate() as Image  # resize мутирует на месте — не трогаем оригинал
		img.resize(
			maxi(1, int(round(img.get_width() * ratio))),
			maxi(1, int(round(img.get_height() * ratio))),
			Image.INTERPOLATE_BILINEAR)
	return img.save_jpg_to_buffer(UPLOAD_JPG_QUALITY)


func _post_to_webhook(webhook_url: String) -> void:
	# Стартуем серию попыток: одна сетевая отправка = _dispatch_request(); ретраи по
	# таймеру внутри, без промежуточных эмитов report_finished — сигнал уходит ровно один
	# раз за submit_report (success или финальный провал после всех попыток).
	_pending_webhook_url = webhook_url
	_attempt = 0
	_dispatch_request()


func _dispatch_request() -> void:
	_attempt += 1
	if _request != null and is_instance_valid(_request):
		_request.queue_free()
	_request = HTTPRequest.new()
	_request.name = "FeedbackHTTPRequest"
	# Форма ставит игру на паузу (push_pause): и сам запрос, и таймер ретрая должны
	# тикать на паузе, иначе отправка/ретрай «зависнут» до снятия паузы.
	_request.process_mode = Node.PROCESS_MODE_ALWAYS
	_request.timeout = REQUEST_TIMEOUT
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)

	var boundary := "----FantasyDiskFeedback%s" % str(Time.get_unix_time_from_system()).replace(".", "")
	var body := multipart_payload(_pending_text, _pending_screenshot, _pending_metadata, boundary)
	# User-Agent ОБЯЗАТЕЛЕН: без него Discord/Cloudflare возвращает HTTP 403 (SCRUM-362).
	var headers := [
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
		"User-Agent: FantasyDisk-Feedback/1.0",
	]
	var error := _request.request_raw(_pending_webhook_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		# Не удалось даже стартовать запрос (нет сети/занят клиент) — это временный сбой:
		# ретраим по той же логике, что и таймаут, чтобы пережить короткую недоступность.
		_request.queue_free()
		_request = null
		if _attempt < MAX_ATTEMPTS:
			_schedule_retry(_backoff_for_attempt())
		else:
			_finalize_failure(HTTPRequest.RESULT_CANT_CONNECT, 0)


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, _body: PackedByteArray) -> void:
	if _request != null and is_instance_valid(_request):
		_request.queue_free()
	_request = null
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		report_finished.emit(true, "Отчет отправлен разработчику.", "")
		return

	if _attempt < MAX_ATTEMPTS and _is_retryable(result, response_code):
		var delay := _backoff_for_attempt()
		# 429 Too Many Requests — уважаем Retry-After, иначе рискуем баном вебхука.
		if response_code == 429:
			delay = maxf(delay, _retry_after_seconds(headers))
		_schedule_retry(delay)
		return

	_finalize_failure(result, response_code)


func _is_retryable(result: int, response_code: int) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		return TRANSIENT_RESULTS.has(result)
	# Ответ получен, но код ошибочный: 429 и 5xx — временные, прочие 4xx — нет.
	if response_code == 429:
		return true
	return response_code >= 500 and response_code < 600


func _schedule_retry(delay_seconds: float) -> void:
	var tree := get_tree()
	if tree == null:
		# Без дерева таймер не создать — не зависаем, проваливаемся сразу.
		_finalize_failure(HTTPRequest.RESULT_TIMEOUT, 0)
		return
	# process_always=true: таймер тикает даже на паузе (форма фидбека ставит игру на паузу).
	var timer := tree.create_timer(maxf(delay_seconds, 0.0), true)
	timer.timeout.connect(_dispatch_request, CONNECT_ONE_SHOT)


func _finalize_failure(result: int, response_code: int) -> void:
	var local_path := save_local_report(_pending_text, _pending_screenshot, _pending_metadata)
	report_finished.emit(false, _failure_message(result, response_code, local_path != ""), local_path)


func _failure_message(result: int, response_code: int, local_saved := true) -> String:
	# Понятные, различимые сообщения (короткие — помещаются в FeedbackStatusLabel).
	var suffix := " Отчет сохранен локально." if local_saved else " Локальное сохранение также не удалось."
	if response_code >= 400:
		return "Ошибка сервера (код %d).%s" % [response_code, suffix]
	if NO_NETWORK_RESULTS.has(result):
		return "Не удалось связаться с сервером (нет сети).%s" % suffix
	if result == HTTPRequest.RESULT_TIMEOUT or result == HTTPRequest.RESULT_NO_RESPONSE:
		return "Сервер не ответил (таймаут после %d попыток).%s" % [MAX_ATTEMPTS, suffix]
	if response_code > 0:
		return "Ошибка отправки (код %d).%s" % [response_code, suffix]
	return "Ошибка отправки (нет ответа, result %d).%s" % [result, suffix]


static func _configuration_failure_message(error: String, local_saved := true) -> String:
	var suffix := " Отчет сохранен локально." if local_saved else " Локальное сохранение также не удалось."
	if error == "invalid":
		return "Вебхук фидбека некорректен.%s" % suffix
	return "Вебхук фидбека не настроен.%s" % suffix


func _backoff_for_attempt() -> float:
	# _attempt уже инкрементнут на текущую попытку; пауза перед СЛЕДУЮЩЕЙ берётся по
	# индексу совершённых попыток (1→RETRY_BACKOFF_SECONDS[0], 2→[1], ...).
	var idx := _attempt - 1
	if idx >= 0 and idx < RETRY_BACKOFF_SECONDS.size():
		return float(RETRY_BACKOFF_SECONDS[idx])
	return float(RETRY_BACKOFF_SECONDS[RETRY_BACKOFF_SECONDS.size() - 1]) if not RETRY_BACKOFF_SECONDS.is_empty() else 0.0


func _retry_after_seconds(headers: PackedStringArray) -> float:
	for header in headers:
		var lower := header.to_lower()
		if lower.begins_with("retry-after:"):
			var value := header.substr(header.find(":") + 1).strip_edges()
			if value.is_valid_float() or value.is_valid_int():
				return clampf(float(value), 0.0, RATE_LIMIT_MAX_WAIT_SECONDS)
			break
	return RATE_LIMIT_FALLBACK_SECONDS


func _webhook_resolution() -> Dictionary:
	return _resolve_from(
		OS.get_environment(ENV_WEBHOOK),
		_config_webhook_value(BUNDLED_CONFIG_PATH, BUNDLED_WEBHOOK_KEY),
		_config_webhook_value(CONFIG_PATH, WEBHOOK_KEY))


static func _config_webhook_value(path: String, key: String) -> String:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return ""
	return str(config.get_value(CONFIG_SECTION, key, ""))


# Источник URL по приоритету: env (dev/CI) → локальный bundled override →
# user://feedback_config.cfg (legacy). Невалидный override не блокирует следующий
# источник; если валидного URL нет, отчет остается локально. Чистая функция,
# юнит-тестируется без файлов и env.
static func _resolve_from(env_url: String, bundled_url: String, user_url: String) -> Dictionary:
	var overrides := [[env_url, "env"], [bundled_url, "bundled"], [user_url, "user"]]
	for entry in overrides:
		var url: String = str(entry[0]).strip_edges()
		if url == "":
			continue
		if _is_valid_webhook_url(url):
			return {"url": url, "source": str(entry[1]), "error": ""}
		push_warning("Feedback: некорректный webhook-оверрайд (%s) проигнорирован." % str(entry[1]))
	return {"url": "", "source": "", "error": "missing"}


static func _is_valid_webhook_url(url: String) -> bool:
	var clean := url.strip_edges()
	if clean == "":
		return false
	if "XXXX" in clean or "YYYY" in clean or "..." in clean:
		return false
	return clean.begins_with("https://discord.com/api/webhooks/") or clean.begins_with("https://discordapp.com/api/webhooks/")


static func _report_body(text: String, metadata: Dictionary) -> String:
	var lines := [
		"FantasyDisk feedback report",
		"",
		"Описание:",
		text.strip_edges() if text.strip_edges() != "" else "(без описания)",
		"",
		"Метаданные:",
	]
	for key in metadata.keys():
		lines.append("- %s: %s" % [str(key), str(metadata[key])])
	return "\n".join(lines)


static func _timestamp_for_path() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(dt["year"]),
		int(dt["month"]),
		int(dt["day"]),
		int(dt["hour"]),
		int(dt["minute"]),
		int(dt["second"]),
	]


static func _normalized_screenshot(screenshot: Image) -> Image:
	if screenshot != null and screenshot.get_width() > 0 and screenshot.get_height() > 0:
		return screenshot
	var fallback := Image.create(32, 18, false, Image.FORMAT_RGBA8)
	fallback.fill(Color(0.02, 0.025, 0.04, 1.0))
	return fallback


static func _append_utf8(target: PackedByteArray, text: String) -> void:
	target.append_array(text.to_utf8_buffer())
