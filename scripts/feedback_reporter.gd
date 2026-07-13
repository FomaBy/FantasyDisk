class_name FeedbackReporter
extends Node

signal report_finished(success: bool, message: String, local_path: String)
signal report_finished_for_request(request_id: int, success: bool, message: String, local_path: String)

const CONFIG_PATH := "user://feedback_config.cfg"
const BUNDLED_CONFIG_PATH := "res://feedback_webhook.cfg"
const CONFIG_SECTION := "feedback"
const WEBHOOK_KEY := "webhook_url"
const BUNDLED_WEBHOOK_KEY := "discord_webhook_url"
const RELAY_CONFIG_KEY := "relay_session_url"
const RELAY_PROJECT_SETTING := "feedback/relay_session_url"
const PRIVACY_OPERATOR_SETTING := "feedback/privacy_operator_name"
const PRIVACY_CONTACT_SETTING := "feedback/privacy_contact_url"
const PRIVACY_RETENTION_SETTING := "feedback/privacy_retention_notice"
const PRIVACY_POLICY_SETTING := "feedback/privacy_policy_url"
const LOCAL_ROOT := "user://feedback"
const INSTALLATION_ID_PATH := "user://feedback_installation_id.txt"
const ENV_WEBHOOK := "FANTASYDISK_FEEDBACK_WEBHOOK"
const ENV_RELAY := "FANTASYDISK_FEEDBACK_RELAY_URL"
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
const RELAY_SCHEMA_VERSION := 2
const MAX_DESCRIPTION_CHARS := 4000
const MAX_SESSION_REFRESHES := 1
const MAX_RESPONSE_BYTES := 64 * 1024
const PHASE_NONE := &""
const PHASE_RELAY_SESSION := &"relay_session"
const PHASE_RELAY_UPLOAD := &"relay_upload"
const PHASE_DISCORD_DEBUG := &"discord_debug"
const METADATA_KEYS := [
	"version",
	"character",
	"weapon",
	"ascension",
	"current_act",
	"route_stage",
	"route_scaling_stage",
	"current_node_type",
	"combat_active",
	"boss_active",
	"screen",
	"resolution",
	"os",
	"timestamp",
]

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

var _request: HTTPRequest = null
var _request_owner_id := 0
var _request_phase: StringName = PHASE_NONE
var _next_request_id := 1
var _active_request_id := 0
var _active_report := {}


func submit_report(
	text: String,
	screenshot: Image,
	metadata: Dictionary,
	completion := Callable(),
	include_screenshot := true) -> int:
	var request_id := _begin_report(text, screenshot, metadata, completion, include_screenshot)
	if not _is_submission_content_valid(
			str(_active_report.get("text", "")),
			bool(_active_report.get("include_screenshot", true))):
		_finish_report(
			request_id,
			false,
			"Для отчета без скриншота добавьте описание.",
			"")
		return request_id
	if not _is_description_within_limit(str(_active_report.get("text", ""))):
		var oversized_local_path := save_local_report(
			str(_active_report.get("text", "")),
			_active_report.get("screenshot") as Image,
			_active_report.get("metadata", {}) as Dictionary,
			str(_active_report.get("report_id", "")),
			bool(_active_report.get("include_screenshot", true)))
		var suffix := " Отчет сохранен локально." if oversized_local_path != "" \
			else " Локальное сохранение также не удалось."
		_finish_report(request_id, false,
			"Описание длиннее %d символов.%s" % [MAX_DESCRIPTION_CHARS, suffix],
			oversized_local_path)
		return request_id
	var delivery := _delivery_resolution()
	var delivery_url := str(delivery.get("url", ""))
	if delivery_url == "":
		var local_path := save_local_report(
			str(_active_report.get("text", "")),
			_active_report.get("screenshot") as Image,
			_active_report.get("metadata", {}) as Dictionary,
			str(_active_report.get("report_id", "")),
			bool(_active_report.get("include_screenshot", true)))
		_finish_report(request_id, false, _configuration_failure_message(
			str(delivery.get("error", "missing")), local_path != ""), local_path)
		return request_id

	if str(delivery.get("mode", "")) == "relay":
		_start_relay(delivery_url, request_id)
	else:
		_post_to_webhook(delivery_url, request_id)
	return request_id


func is_request_active(request_id: int) -> bool:
	return request_id > 0 and request_id == _active_request_id


func cancel_active_report(request_id := 0) -> bool:
	if _active_request_id == 0:
		return false
	if request_id > 0 and request_id != _active_request_id:
		return false
	var cancelled_id := _active_request_id
	_active_request_id = 0
	_active_report = {}
	if _request_owner_id == cancelled_id:
		_dispose_request(_request)
	return true


func _begin_report(
	text: String,
	screenshot: Image,
	metadata: Dictionary,
	completion := Callable(),
	include_screenshot := true) -> int:
	# Only one report is allowed in flight. Superseding a request first invalidates
	# its identity, so a late HTTP signal or retry timer cannot observe new payload.
	cancel_active_report()
	var request_id := _next_request_id
	_next_request_id += 1
	_active_request_id = request_id
	var screenshot_enabled := bool(include_screenshot)
	_active_report = {
		"text": text.strip_edges(),
		"metadata": _sanitize_metadata(metadata),
		"include_screenshot": screenshot_enabled,
		# Captured screenshots are never mutated by the UI. Keep that stable image
		# reference instead of duplicating up to 32 MiB at 4K; upload resizing already
		# duplicates only when it actually needs to mutate the image. An opted-out
		# report never retains the source image in the request snapshot.
		"screenshot": _normalized_screenshot(screenshot) if screenshot_enabled else null,
		"report_id": _new_report_uuid(),
		"installation_id": _installation_id(),
		"phase": PHASE_NONE,
		"webhook_url": "",
		"relay_session_url": "",
		"relay_upload_url": "",
		"relay_body": PackedByteArray(),
		"discord_body": PackedByteArray(),
		"discord_content_type": "",
		"access_token": "",
		"session_refreshes": 0,
		"attempt": 0,
		"completion": completion,
	}
	return request_id


static func webhook_config_template_path() -> String:
	return ProjectSettings.globalize_path(CONFIG_PATH)


static func feedback_folder_path() -> String:
	return ProjectSettings.globalize_path(LOCAL_ROOT)


static func save_local_report(
	text: String,
	screenshot: Image,
	metadata: Dictionary,
	report_id := "",
	include_screenshot := true) -> String:
	var timestamp := _timestamp_for_path()
	var report_dir := "%s/%s" % [LOCAL_ROOT, _local_report_folder(timestamp, str(report_id))]
	var absolute_dir := ProjectSettings.globalize_path(report_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return ""

	var report_file := FileAccess.open("%s/report.txt" % report_dir, FileAccess.WRITE)
	if report_file == null:
		return ""
	report_file.store_string(_report_body(text, _sanitize_metadata(metadata), bool(include_screenshot)))
	var report_error := report_file.get_error()
	report_file.close()
	if report_error != OK:
		return ""

	if bool(include_screenshot):
		var safe_screenshot := _normalized_screenshot(screenshot)
		if safe_screenshot.save_png("%s/screenshot.png" % report_dir) != OK:
			return ""
	return absolute_dir


static func discord_content(text: String, metadata: Dictionary, include_screenshot := true) -> String:
	var body := _report_body(text, _sanitize_metadata(metadata), include_screenshot)
	if body.length() > 1800:
		body = body.substr(0, 1790) + "\n..."
	return body


static func multipart_payload(text: String, screenshot: Image, metadata: Dictionary, boundary: String) -> PackedByteArray:
	var body := PackedByteArray()
	var payload_json := JSON.stringify({
		"content": discord_content(text, metadata),
		"allowed_mentions": {"parse": []},
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


static func discord_json_payload(text: String, metadata: Dictionary) -> PackedByteArray:
	return JSON.stringify({
		"content": discord_content(text, metadata, false),
		"allowed_mentions": {"parse": []},
		"attachments": [],
	}).to_utf8_buffer()


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


func _post_to_webhook(webhook_url: String, request_id: int) -> void:
	# Стартуем серию попыток: одна сетевая отправка = _dispatch_request(); ретраи по
	# таймеру внутри, без промежуточных эмитов report_finished — сигнал уходит ровно один
	# раз за submit_report (success или финальный провал после всех попыток).
	if not is_request_active(request_id):
		return
	_active_report["webhook_url"] = webhook_url
	if bool(_active_report.get("include_screenshot", true)):
		var boundary := "----FantasyDiskFeedback%s" % str(_active_report.get("report_id", "")).replace("-", "")
		_active_report["discord_content_type"] = "multipart/form-data; boundary=%s" % boundary
		_active_report["discord_body"] = multipart_payload(
			str(_active_report.get("text", "")),
			_active_report.get("screenshot") as Image,
			_active_report.get("metadata", {}) as Dictionary,
			boundary)
	else:
		_active_report["discord_content_type"] = "application/json"
		_active_report["discord_body"] = discord_json_payload(
			str(_active_report.get("text", "")),
			_active_report.get("metadata", {}) as Dictionary)
	_transition_phase(request_id, PHASE_DISCORD_DEBUG)
	_dispatch_request(request_id, PHASE_DISCORD_DEBUG)


func _start_relay(session_url: String, request_id: int) -> void:
	if not is_request_active(request_id):
		return
	_active_report["relay_session_url"] = session_url
	_active_report["relay_upload_url"] = session_url.trim_suffix("/v1/session") + "/v1/feedback"
	_active_report["relay_body"] = _relay_upload_body(
		str(_active_report.get("report_id", "")),
		str(_active_report.get("text", "")),
		_active_report.get("screenshot") as Image,
		_active_report.get("metadata", {}) as Dictionary,
		bool(_active_report.get("include_screenshot", true)))
	_transition_phase(request_id, PHASE_RELAY_SESSION)
	_dispatch_request(request_id, PHASE_RELAY_SESSION)


func _transition_phase(request_id: int, phase: StringName) -> void:
	if not is_request_active(request_id):
		return
	_active_report["phase"] = phase
	_active_report["attempt"] = 0


func _active_phase() -> StringName:
	return StringName(str(_active_report.get("phase", "")))


func _is_active_phase(request_id: int, phase: StringName) -> bool:
	return is_request_active(request_id) and _active_phase() == phase


func _dispatch_request(request_id: int, expected_phase := PHASE_DISCORD_DEBUG) -> void:
	var phase := StringName(expected_phase)
	if not _is_active_phase(request_id, phase):
		return
	_active_report["attempt"] = int(_active_report.get("attempt", 0)) + 1
	_dispose_request(_request)
	var request := HTTPRequest.new()
	request.name = "FeedbackHTTPRequest"
	# Форма ставит игру на паузу (push_pause): и сам запрос, и таймер ретрая должны
	# тикать на паузе, иначе отправка/ретрай «зависнут» до снятия паузы.
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = REQUEST_TIMEOUT
	request.body_size_limit = MAX_RESPONSE_BYTES
	add_child(request)
	_request = request
	_request_owner_id = request_id
	_request_phase = phase
	request.request_completed.connect(_on_request_completed.bind(request_id, request, phase))

	var request_spec := _request_spec_for_phase(phase)
	var error := request.request_raw(
		str(request_spec.get("url", "")),
		request_spec.get("headers", PackedStringArray()) as PackedStringArray,
		HTTPClient.METHOD_POST,
		request_spec.get("body", PackedByteArray()) as PackedByteArray)
	if error != OK:
		# Не удалось даже стартовать запрос (нет сети/занят клиент) — это временный сбой:
		# ретраим по той же логике, что и таймаут, чтобы пережить короткую недоступность.
		_dispose_request(request)
		if not _is_active_phase(request_id, phase):
			return
		if int(_active_report.get("attempt", 0)) < MAX_ATTEMPTS:
			_schedule_retry(_backoff_for_attempt(), request_id, phase)
		else:
			_finalize_failure(HTTPRequest.RESULT_CANT_CONNECT, 0, request_id)


func _request_spec_for_phase(phase: StringName) -> Dictionary:
	if phase == PHASE_RELAY_SESSION:
		return {
			"url": str(_active_report.get("relay_session_url", "")),
			"headers": PackedStringArray([
				"Content-Type: application/json",
				"User-Agent: FantasyDisk-Feedback/1.0",
			]),
			"body": _relay_session_body(
				str(_active_report.get("installation_id", "")),
				str(ProjectSettings.get_setting("application/config/version", "dev"))),
		}
	if phase == PHASE_RELAY_UPLOAD:
		return {
			"url": str(_active_report.get("relay_upload_url", "")),
			"headers": PackedStringArray([
				"Content-Type: application/json",
				"User-Agent: FantasyDisk-Feedback/1.0",
				"Authorization: Bearer %s" % str(_active_report.get("access_token", "")),
				"X-Feedback-Installation: %s" % str(_active_report.get("installation_id", "")),
				"Idempotency-Key: %s" % str(_active_report.get("report_id", "")),
			]),
			"body": _active_report.get("relay_body", PackedByteArray()),
		}
	return {
		"url": str(_active_report.get("webhook_url", "")),
		"headers": PackedStringArray([
			"Content-Type: %s" % str(_active_report.get("discord_content_type", "application/json")),
			"User-Agent: FantasyDisk-Feedback/1.0",
		]),
		"body": _active_report.get("discord_body", PackedByteArray()),
	}


func _on_request_completed(
		result: int,
		response_code: int,
		headers: PackedStringArray,
		body: PackedByteArray,
		request_id: int,
		request: HTTPRequest,
		expected_phase := PHASE_DISCORD_DEBUG) -> void:
	var phase := StringName(expected_phase)
	var owns_attempt := request == _request \
		and _request_owner_id == request_id \
		and _request_phase == phase
	_dispose_request(request)
	if not owns_attempt or not _is_active_phase(request_id, phase):
		return
	if phase == PHASE_RELAY_SESSION:
		_handle_relay_session_response(result, response_code, headers, body, request_id)
		return
	if phase == PHASE_RELAY_UPLOAD:
		_handle_relay_upload_response(result, response_code, headers, request_id)
		return
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_finish_report(request_id, true, "Отчет отправлен разработчику.", "")
		return
	_retry_or_finalize(result, response_code, headers, request_id, phase)


func _handle_relay_session_response(
		result: int,
		response_code: int,
		headers: PackedStringArray,
		body: PackedByteArray,
		request_id: int) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var token := _parse_relay_session_token(body)
		if token == "":
			_finalize_failure(HTTPRequest.RESULT_SUCCESS, 502, request_id)
			return
		_active_report["access_token"] = token
		_transition_phase(request_id, PHASE_RELAY_UPLOAD)
		_dispatch_request(request_id, PHASE_RELAY_UPLOAD)
		return
	_retry_or_finalize(result, response_code, headers, request_id, PHASE_RELAY_SESSION)


func _handle_relay_upload_response(
		result: int,
		response_code: int,
		headers: PackedStringArray,
		request_id: int) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_finish_report(request_id, true, "Отчет отправлен разработчику.", "")
		return
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 401 \
			and int(_active_report.get("session_refreshes", 0)) < MAX_SESSION_REFRESHES:
		_active_report["session_refreshes"] = int(_active_report.get("session_refreshes", 0)) + 1
		_active_report["access_token"] = ""
		_transition_phase(request_id, PHASE_RELAY_SESSION)
		_dispatch_request(request_id, PHASE_RELAY_SESSION)
		return
	_retry_or_finalize(result, response_code, headers, request_id, PHASE_RELAY_UPLOAD)


func _retry_or_finalize(
		result: int,
		response_code: int,
		headers: PackedStringArray,
		request_id: int,
		phase: StringName) -> void:

	if int(_active_report.get("attempt", 0)) < MAX_ATTEMPTS and _is_retryable(result, response_code):
		var delay := _backoff_for_attempt()
		if response_code == 429 or response_code == 409 or response_code == 503:
			delay = maxf(delay, _retry_after_seconds(headers))
		_schedule_retry(delay, request_id, phase)
		return

	_finalize_failure(result, response_code, request_id)


func _is_retryable(result: int, response_code: int) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		return TRANSIENT_RESULTS.has(result)
	# Relay возвращает 409, пока первый idempotent delivery ещё выполняется.
	if response_code == 409 or response_code == 429:
		return true
	return response_code >= 500 and response_code < 600


func _schedule_retry(delay_seconds: float, request_id: int, expected_phase := PHASE_DISCORD_DEBUG) -> void:
	var phase := StringName(expected_phase)
	if not _is_active_phase(request_id, phase):
		return
	var tree := get_tree()
	if tree == null:
		# Без дерева таймер не создать — не зависаем, проваливаемся сразу.
		_finalize_failure(HTTPRequest.RESULT_TIMEOUT, 0, request_id)
		return
	# process_always=true: таймер тикает даже на паузе (форма фидбека ставит игру на паузу).
	var timer := tree.create_timer(maxf(delay_seconds, 0.0), true)
	timer.timeout.connect(_on_retry_timeout.bind(request_id, phase), CONNECT_ONE_SHOT)


func _on_retry_timeout(request_id: int, expected_phase := PHASE_DISCORD_DEBUG) -> void:
	var phase := StringName(expected_phase)
	if _is_active_phase(request_id, phase):
		_dispatch_request(request_id, phase)


func _finalize_failure(result: int, response_code: int, request_id: int) -> void:
	if not is_request_active(request_id):
		return
	var local_path := save_local_report(
		str(_active_report.get("text", "")),
		_active_report.get("screenshot") as Image,
		_active_report.get("metadata", {}) as Dictionary,
		str(_active_report.get("report_id", "")),
		bool(_active_report.get("include_screenshot", true)))
	_finish_report(request_id, false, _failure_message(result, response_code, local_path != ""), local_path)


func _finish_report(request_id: int, success: bool, message: String, local_path: String) -> void:
	if not is_request_active(request_id):
		return
	var completion: Callable = _active_report.get("completion", Callable()) as Callable
	_active_request_id = 0
	_active_report = {}
	if _request_owner_id == request_id:
		_dispose_request(_request)
	report_finished_for_request.emit(request_id, success, message, local_path)
	report_finished.emit(success, message, local_path)
	if completion.is_valid():
		completion.call(success, message, local_path)


func _dispose_request(request: HTTPRequest) -> void:
	if request != null and is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	if _request == request:
		_request = null
		_request_owner_id = 0
		_request_phase = PHASE_NONE


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
		return "Сервис фидбека некорректен.%s" % suffix
	if error == "privacy_incomplete":
		return "Онлайн-фидбек отключен: политика конфиденциальности не настроена.%s" % suffix
	return "Сервис фидбека не настроен.%s" % suffix


func _backoff_for_attempt() -> float:
	# Attempt уже инкрементнут на текущую попытку; пауза перед СЛЕДУЮЩЕЙ берётся по
	# индексу совершённых попыток (1→RETRY_BACKOFF_SECONDS[0], 2→[1], ...).
	var idx := int(_active_report.get("attempt", 0)) - 1
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


func _relay_resolution() -> Dictionary:
	return _resolve_relay_from(
		OS.get_environment(ENV_RELAY),
		str(ProjectSettings.get_setting(RELAY_PROJECT_SETTING, "")),
		_config_webhook_value(CONFIG_PATH, RELAY_CONFIG_KEY))


func _delivery_resolution() -> Dictionary:
	var privacy_complete := _privacy_disclosure_complete()
	var relay := _relay_resolution()
	if str(relay.get("url", "")) != "":
		if not privacy_complete:
			return {"mode": "", "url": "", "source": "", "error": "privacy_incomplete"}
		return {"mode": "relay", "url": str(relay["url"]), "source": str(relay["source"]), "error": ""}
	# A raw Discord webhook is a developer credential. Release builds must never
	# consult or transmit it, even if a user config or environment accidentally
	# survives on the build machine.
	if OS.is_debug_build():
		var webhook := _webhook_resolution()
		if str(webhook.get("url", "")) != "":
			# The debug transport is still real network disclosure. Never let it
			# contradict an overlay that says online delivery is disabled.
			if not privacy_complete:
				return {"mode": "", "url": "", "source": "", "error": "privacy_incomplete"}
			return {"mode": "discord_debug", "url": str(webhook["url"]), "source": str(webhook["source"]), "error": ""}
	return {"mode": "", "url": "", "source": "", "error": str(relay.get("error", "missing"))}


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


static func _resolve_relay_from(env_url: String, project_url: String, user_url: String) -> Dictionary:
	var overrides := [[env_url, "env"], [project_url, "project"], [user_url, "user"]]
	var saw_invalid := false
	for entry in overrides:
		var url: String = str(entry[0]).strip_edges()
		if url == "":
			continue
		if _is_valid_relay_session_url(url):
			return {"url": url, "source": str(entry[1]), "error": ""}
		saw_invalid = true
		push_warning("Feedback: некорректный relay endpoint (%s) проигнорирован." % str(entry[1]))
	return {"url": "", "source": "", "error": "invalid" if saw_invalid else "missing"}


static func _resolve_delivery_from(
		relay_urls: Array,
		webhook_urls: Array,
		debug_build: bool,
		privacy_complete := true) -> Dictionary:
	var relay := _resolve_relay_from(
		str(relay_urls[0]) if relay_urls.size() > 0 else "",
		str(relay_urls[1]) if relay_urls.size() > 1 else "",
		str(relay_urls[2]) if relay_urls.size() > 2 else "")
	if str(relay.get("url", "")) != "":
		if not bool(privacy_complete):
			return {"mode": "", "url": "", "error": "privacy_incomplete"}
		return {"mode": "relay", "url": str(relay["url"]), "error": ""}
	if debug_build:
		var direct := _resolve_from(
			str(webhook_urls[0]) if webhook_urls.size() > 0 else "",
			str(webhook_urls[1]) if webhook_urls.size() > 1 else "",
			str(webhook_urls[2]) if webhook_urls.size() > 2 else "")
		if str(direct.get("url", "")) != "":
			if not bool(privacy_complete):
				return {"mode": "", "url": "", "error": "privacy_incomplete"}
			return {"mode": "discord_debug", "url": str(direct["url"]), "error": ""}
	return {"mode": "", "url": "", "error": str(relay.get("error", "missing"))}


static func _is_valid_webhook_url(url: String) -> bool:
	var clean := url.strip_edges()
	if clean == "":
		return false
	if "XXXX" in clean or "YYYY" in clean or "..." in clean:
		return false
	return clean.begins_with("https://discord.com/api/webhooks/") or clean.begins_with("https://discordapp.com/api/webhooks/")


static func _is_valid_relay_session_url(url: String) -> bool:
	var clean := url.strip_edges()
	if clean == "" or clean != url or not clean.begins_with("https://"):
		return false
	if "XXXX" in clean or "YYYY" in clean or "..." in clean:
		return false
	if "?" in clean or "#" in clean or "@" in clean or "\\" in clean \
			or "\r" in clean or "\n" in clean or "\t" in clean:
		return false
	var authority_and_path := clean.substr("https://".length())
	var slash := authority_and_path.find("/")
	if slash <= 0:
		return false
	var authority := authority_and_path.substr(0, slash)
	if authority == "" or authority.begins_with(":") or " " in authority:
		return false
	return authority_and_path.substr(slash) == "/v1/session"


static func _relay_session_body(installation_id: String, client_version: String) -> PackedByteArray:
	return JSON.stringify({
		"schema_version": RELAY_SCHEMA_VERSION,
		"installation_id": installation_id,
		"client_version": client_version,
	}).to_utf8_buffer()


static func _relay_upload_body(
		report_id: String,
		text: String,
		screenshot: Image,
		metadata: Dictionary,
		include_screenshot := true) -> PackedByteArray:
	var encoded_screenshot = null
	if bool(include_screenshot):
		encoded_screenshot = Marshalls.raw_to_base64(_upload_image_buffer(screenshot))
	return JSON.stringify({
		"schema_version": RELAY_SCHEMA_VERSION,
		"report_id": report_id,
		"description": text.strip_edges(),
		"metadata": _sanitize_metadata(metadata),
		"screenshot_jpeg_base64": encoded_screenshot,
	}).to_utf8_buffer()


static func _parse_relay_session_token(body: PackedByteArray) -> String:
	if body.is_empty() or body.size() > MAX_RESPONSE_BYTES:
		return ""
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return ""
	var response := parsed as Dictionary
	if int(response.get("schema_version", 0)) != RELAY_SCHEMA_VERSION:
		return ""
	if int(response.get("expires_in", 0)) <= 0:
		return ""
	var token := str(response.get("token", ""))
	if not _is_safe_session_token(token):
		return ""
	return token


static func _is_safe_session_token(token: String) -> bool:
	if token == "" or token.length() > 4096:
		return false
	var parts := token.split(".", false)
	if parts.size() != 2:
		return false
	for part in parts:
		if part == "":
			return false
		for character in part:
			if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_":
				return false
	return true


static func _is_description_within_limit(text: String) -> bool:
	return text.strip_edges().length() <= MAX_DESCRIPTION_CHARS


static func _is_submission_content_valid(text: String, include_screenshot: bool) -> bool:
	return include_screenshot or not text.strip_edges().is_empty()


func _privacy_disclosure_complete() -> bool:
	return _privacy_configuration_complete(
		str(ProjectSettings.get_setting(PRIVACY_OPERATOR_SETTING, "")),
		str(ProjectSettings.get_setting(PRIVACY_CONTACT_SETTING, "")),
		str(ProjectSettings.get_setting(PRIVACY_RETENTION_SETTING, "")),
		str(ProjectSettings.get_setting(PRIVACY_POLICY_SETTING, "")))


static func _privacy_configuration_complete(
		operator_name: String,
		contact_url: String,
		retention_notice: String,
		policy_url: String) -> bool:
	var operator_clean := operator_name.strip_edges()
	var retention_clean := retention_notice.strip_edges()
	return not operator_clean.is_empty() \
		and operator_clean.length() <= 120 \
		and not retention_clean.is_empty() \
		and retention_clean.length() <= 500 \
		and _is_valid_public_https_url(contact_url) \
		and _is_valid_public_https_url(policy_url)


static func _is_valid_public_https_url(url: String) -> bool:
	var clean := url.strip_edges()
	if clean != url or not clean.begins_with("https://"):
		return false
	if "@" in clean or "\\" in clean or "\r" in clean or "\n" in clean or "\t" in clean:
		return false
	var authority_and_path := clean.substr("https://".length())
	var delimiter_positions := [authority_and_path.find("/"), authority_and_path.find("?"), authority_and_path.find("#")]
	var authority_end := authority_and_path.length()
	for position in delimiter_positions:
		if int(position) >= 0:
			authority_end = mini(authority_end, int(position))
	var authority := authority_and_path.substr(0, authority_end)
	return not authority.is_empty() and not authority.begins_with(":") and not " " in authority


static func _sanitize_metadata(metadata: Dictionary) -> Dictionary:
	var sanitized := {}
	for key in METADATA_KEYS:
		if not metadata.has(key):
			continue
		var value = metadata[key]
		if value == null or typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			continue
		if typeof(value) == TYPE_STRING and str(value).length() > 160:
			value = str(value).substr(0, 160)
		sanitized[key] = value
	return sanitized


static func _new_report_uuid() -> String:
	return _format_uuid_v4(Crypto.new().generate_random_bytes(16))


static func _format_uuid_v4(random_bytes: PackedByteArray) -> String:
	if random_bytes.size() != 16:
		return ""
	var bytes := random_bytes.duplicate()
	bytes[6] = (int(bytes[6]) & 0x0f) | 0x40
	bytes[8] = (int(bytes[8]) & 0x3f) | 0x80
	var hex := ""
	for value in bytes:
		hex += "%02x" % int(value)
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]


static func _is_uuid_v4(value: String) -> bool:
	var clean := value.to_lower()
	if clean.length() != 36 or clean[8] != "-" or clean[13] != "-" \
			or clean[18] != "-" or clean[23] != "-":
		return false
	var compact := clean.replace("-", "")
	if compact.length() != 32 or compact[12] != "4" or not compact[16] in ["8", "9", "a", "b"]:
		return false
	for character in compact:
		if not character in "0123456789abcdef":
			return false
	return true


static func _installation_id() -> String:
	if FileAccess.file_exists(INSTALLATION_ID_PATH):
		var existing := FileAccess.get_file_as_string(INSTALLATION_ID_PATH).strip_edges().to_lower()
		if _is_uuid_v4(existing):
			return existing
	var generated := _new_report_uuid()
	var file := FileAccess.open(INSTALLATION_ID_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(generated)
		file.close()
	return generated


static func _local_report_folder(timestamp: String, report_id: String) -> String:
	return "%s_%s" % [timestamp, report_id] if _is_uuid_v4(report_id) else timestamp


static func _report_body(text: String, metadata: Dictionary, include_screenshot := true) -> String:
	var lines := [
		"FantasyDisk feedback report",
		"",
		"Описание:",
		text.strip_edges() if text.strip_edges() != "" else "(без описания)",
		"",
		"Скриншот: %s" % ("включен" if bool(include_screenshot) else "не включен"),
		"",
		"Метаданные:",
	]
	for key in METADATA_KEYS:
		if metadata.has(key):
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
