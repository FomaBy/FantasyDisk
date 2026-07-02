extends SceneTree
## SCRUM-810 — smoke-тест реестра глифов ввода (input_glyph_registry.gd).
##
## Гейтит:
##  - анти-вакуум (набор глифов не усох);
##  - каждый глиф × размер имеет существующий ресурс, текстура грузится,
##    размер PNG == заявленному, углы прозрачны (нет запечённого фона);
##  - JOY_BUTTON_*/JOY_AXIS_*/клавиши маппятся на реальные глифы;
##  - null-safety аксессоров на неизвестных индексах/именах.
##
## Проверка пикселей углов выполняется только если Image доступен (headless без
## RenderingDevice может вернуть null) — ассет-провенанс углов также гарантируется
## генератором; тут это регрессионная страховка, не источник ложных красных.
##
## Запуск: Godot --headless --path . --script res://tests/input_glyph_assets_test.gd

const Reg := preload("res://scripts/ui/input_glyph_registry.gd")


func _initialize() -> void:
	var errors: Array = []

	if Reg.ALL_GLYPHS.size() < 20:
		errors.append("ALL_GLYPHS подозрительно мал (%d)" % Reg.ALL_GLYPHS.size())
	if Reg.SIZES.is_empty():
		errors.append("SIZES пуст")

	var corner_checks := 0
	for glyph in Reg.ALL_GLYPHS:
		for size in Reg.SIZES:
			var isize := int(size)
			var path := Reg.path_for(str(glyph), isize)
			if path == "" or not ResourceLoader.exists(path):
				errors.append("глиф '%s'@%d → нет ресурса '%s'" % [glyph, isize, path])
				continue
			if not Reg.has_glyph(str(glyph), isize):
				errors.append("has_glyph('%s',%d) == false при существующем пути" % [glyph, isize])
			var tex: Texture2D = Reg.texture_for(str(glyph), isize)
			if tex == null:
				errors.append("texture_for('%s',%d) == null" % [glyph, isize])
				continue
			if tex.get_width() != isize or tex.get_height() != isize:
				errors.append("'%s'@%d размер %dx%d != %d" % [
					glyph, isize, tex.get_width(), tex.get_height(), isize])
			var img: Image = tex.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				var w := img.get_width()
				var h := img.get_height()
				var corners := [Vector2i(0, 0), Vector2i(w - 1, 0),
					Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]
				for c in corners:
					if img.get_pixelv(c).a > 0.0:
						errors.append("'%s'@%d угол %s непрозрачен (запечённый фон?)" % [glyph, isize, c])
						break
				corner_checks += 1

	# --- Покрытие геймпад-кнопок ---
	var required_buttons := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
		JOY_BUTTON_START, JOY_BUTTON_BACK,
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK,
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
	for b in required_buttons:
		if Reg.texture_for_joy_button(int(b), 32) == null:
			errors.append("texture_for_joy_button(%d) == null" % b)

	# --- Оси (триггеры + движение) ---
	for ax in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT,
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if Reg.texture_for_axis(int(ax), 32) == null:
			errors.append("texture_for_axis(%d) == null" % ax)

	# --- Клавиатурные глифы ---
	for k in ["esc", "enter", "space", "wasd", "arrows", "generic"]:
		if Reg.texture_for_key(k, 32) == null:
			errors.append("texture_for_key('%s') == null" % k)

	# --- null-safety на мусоре ---
	if Reg.texture_for_joy_button(9999, 32) != null:
		errors.append("неизвестная JoyButton должна давать null")
	if Reg.texture_for_axis(9999, 32) != null:
		errors.append("неизвестная JoyAxis должна давать null")
	if Reg.texture_for_key("nope", 32) != null:
		errors.append("неизвестная клавиша должна давать null")
	if Reg.texture_for("nonexistent_glyph", 32) != null:
		errors.append("неизвестный глиф должен давать null")
	if Reg.path_for("nonexistent_glyph", 32) != "":
		errors.append("path_for мусора должен быть пустым")

	if not errors.is_empty():
		for e in errors:
			push_error("input_glyph: %s" % e)
		push_error("input_glyph_assets_test: %d ошибок." % errors.size())
		quit(1)
		return
	print("input_glyph_assets_test passed (%d глифов × %d размера, %d углов проверено)." % [
		Reg.ALL_GLYPHS.size(), Reg.SIZES.size(), corner_checks])
	quit(0)
