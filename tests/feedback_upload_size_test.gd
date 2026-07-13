extends SceneTree

const Reporter := preload("res://scripts/feedback_reporter.gd")

func _init() -> void:
	var ok := true
	# Имитируем тяжёлый retina-скрин (реальный фото-скрин в PNG весит ~9–10 МБ и
	# пробивал лимит вебхука; синтетика жмётся лучше, но проверяем JPG/multipart-инвариант).
	var big := Image.create(3200, 1940, false, Image.FORMAT_RGBA8)
	for y in range(0, 1940, 2):
		big.fill_rect(Rect2i(0, y, 3200, 1), Color(randf(), randf(), randf(), 1.0))
	var png_size := big.save_png_to_buffer().size()
	var jpg := Reporter._upload_image_buffer(big)
	var meta := {"version": "0.1.6", "screen": "Combat"}
	var body := Reporter.multipart_payload("тест отправки", big, meta, "----BOUND123")
	var relay_body := Reporter._relay_upload_body(
		Reporter._new_report_uuid(), "тест отправки", big, meta)
	var text_only_body := Reporter._relay_upload_body(
		Reporter._new_report_uuid(), "текст без скриншота", big, meta, false)
	var text_only_debug := Reporter.discord_json_payload("текст без скриншота", meta)
	print("PNG full bytes:     %d (%.1f МБ)" % [png_size, png_size / 1048576.0])
	print("JPG upload bytes:   %d (%.0f КБ)" % [jpg.size(), jpg.size() / 1024.0])
	print("multipart body:     %d (%.0f КБ)" % [body.size(), body.size() / 1024.0])
	print("relay JSON body:    %d (%.0f КБ)" % [relay_body.size(), relay_body.size() / 1024.0])
	print("text-only relay:    %d bytes" % text_only_body.size())
	# Оригинал не должен мутировать (resize делает duplicate).
	if big.get_width() != 3200 or big.get_height() != 1940:
		push_error("ОРИГИНАЛ МУТИРОВАН"); ok = false
	if jpg.size() > 500 * 1024:
		push_error("JPG слишком большой"); ok = false
	if body.size() > 1024 * 1024:
		push_error("multipart > 1 МБ — всё ещё рискует пробить лимит"); ok = false
	if relay_body.size() > 1024 * 1024:
		push_error("relay JSON > 1 МБ — base64 overhead пробил лимит"); ok = false
	var text_only_json = JSON.parse_string(text_only_body.get_string_from_utf8())
	if not text_only_json is Dictionary \
			or (text_only_json as Dictionary).get("screenshot_jpeg_base64", "missing") != null:
		push_error("text-only relay не содержит явный null screenshot"); ok = false
	if text_only_body.size() >= 2048 or text_only_debug.size() >= 2048:
		push_error("text-only transport неожиданно кодирует тяжёлое изображение"); ok = false
	print("RESULT: PASS" if ok else "RESULT: FAIL")
	quit(0 if ok else 1)
