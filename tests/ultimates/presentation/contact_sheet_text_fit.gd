extends RefCounted


static func scaled_font_size(size: Vector2i, ratio: float, minimum: int) -> int:
	return maxi(minimum, int(size.y * ratio))


static func centered_rect(text: String, sheet_size: Vector2i, y: float, font_size: int) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(Vector2((float(sheet_size.x) - text_size.x) * 0.5, y), text_size)


static func centered_in_rect(text: String, bounds: Rect2, y: float, font_size: int) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(Vector2(bounds.get_center().x - text_size.x * 0.5, y), text_size)


static func fitted_font_size(text: String, preferred: int, minimum: int, max_width: float) -> int:
	var font_size := preferred
	while font_size > minimum and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		font_size -= 1
	return font_size


static func check_fits(errors: Array[String], resolution: String, text: String, text_rect: Rect2, bounds: Rect2, bounds_name: String) -> void:
	if not bounds.encloses(text_rect):
		errors.append("%s text \"%s\" bounds %s must stay inside %s %s" % [resolution, text, text_rect, bounds_name, bounds])
