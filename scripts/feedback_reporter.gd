class_name FeedbackReporter
extends Node

signal report_finished(success: bool, message: String, local_path: String)

const CONFIG_PATH := "user://feedback_config.cfg"
const CONFIG_SECTION := "feedback"
const WEBHOOK_KEY := "webhook_url"
const LOCAL_ROOT := "user://feedback"
const ENV_WEBHOOK := "FANTASYDISK_FEEDBACK_WEBHOOK"
const SCREENSHOT_FILENAME := "fantasydisk_feedback.png"

var _pending_text := ""
var _pending_metadata := {}
var _pending_screenshot: Image = null
var _request: HTTPRequest = null


func submit_report(text: String, screenshot: Image, metadata: Dictionary) -> void:
	_pending_text = text.strip_edges()
	_pending_metadata = metadata.duplicate(true)
	_pending_screenshot = _normalized_screenshot(screenshot)
	var webhook_url := _webhook_url()
	if webhook_url == "":
		var local_path := save_local_report(_pending_text, _pending_screenshot, _pending_metadata)
		report_finished.emit(false, "Вебхук не настроен. Отчет сохранен локально.", local_path)
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
	DirAccess.make_dir_recursive_absolute(absolute_dir)

	var report_file := FileAccess.open("%s/report.txt" % report_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(_report_body(text, metadata))
		report_file.close()

	var safe_screenshot := _normalized_screenshot(screenshot)
	safe_screenshot.save_png("%s/screenshot.png" % report_dir)
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
		"attachments": [{"id": 0, "filename": SCREENSHOT_FILENAME}],
	})
	_append_utf8(body, "--%s\r\n" % boundary)
	_append_utf8(body, "Content-Disposition: form-data; name=\"payload_json\"\r\n")
	_append_utf8(body, "Content-Type: application/json\r\n\r\n")
	_append_utf8(body, "%s\r\n" % payload_json)

	_append_utf8(body, "--%s\r\n" % boundary)
	_append_utf8(body, "Content-Disposition: form-data; name=\"files[0]\"; filename=\"%s\"\r\n" % SCREENSHOT_FILENAME)
	_append_utf8(body, "Content-Type: image/png\r\n\r\n")
	body.append_array(_normalized_screenshot(screenshot).save_png_to_buffer())
	_append_utf8(body, "\r\n--%s--\r\n" % boundary)
	return body


func _post_to_webhook(webhook_url: String) -> void:
	if _request != null and is_instance_valid(_request):
		_request.queue_free()
	_request = HTTPRequest.new()
	_request.name = "FeedbackHTTPRequest"
	_request.process_mode = Node.PROCESS_MODE_ALWAYS
	_request.timeout = 12.0
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)

	var boundary := "----FantasyDiskFeedback%s" % str(Time.get_unix_time_from_system()).replace(".", "")
	var body := multipart_payload(_pending_text, _pending_screenshot, _pending_metadata, boundary)
	# User-Agent ОБЯЗАТЕЛЕН: без него Discord/Cloudflare возвращает HTTP 403 (SCRUM-362).
	var headers := [
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
		"User-Agent: FantasyDisk-Feedback/1.0",
	]
	var error := _request.request_raw(webhook_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		var local_path := save_local_report(_pending_text, _pending_screenshot, _pending_metadata)
		report_finished.emit(false, "Сеть недоступна. Отчет сохранен локально.", local_path)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if _request != null and is_instance_valid(_request):
		_request.queue_free()
	_request = null
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		report_finished.emit(true, "Отчет отправлен разработчику.", "")
		return
	var local_path := save_local_report(_pending_text, _pending_screenshot, _pending_metadata)
	report_finished.emit(false, "Ошибка отправки. Отчет сохранен локально.", local_path)


func _webhook_url() -> String:
	# Источник URL по приоритету (SCRUM-362):
	# 1) env (дев-машина); 2) res://feedback_webhook.cfg (бандлится в сборку — у
	# тестеров; ключ discord_webhook_url); 3) user://feedback_config.cfg (legacy/override).
	var env_url := OS.get_environment(ENV_WEBHOOK).strip_edges()
	if env_url != "":
		return env_url
	var bundled := ConfigFile.new()
	if bundled.load("res://feedback_webhook.cfg") == OK:
		var u := str(bundled.get_value("feedback", "discord_webhook_url", "")).strip_edges()
		if u != "":
			return u
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		var u2 := str(config.get_value(CONFIG_SECTION, WEBHOOK_KEY, "")).strip_edges()
		if u2 != "":
			return u2
	return ""


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
